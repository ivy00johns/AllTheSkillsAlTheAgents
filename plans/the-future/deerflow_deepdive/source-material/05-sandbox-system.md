# DeerFlow Sandbox System

## What It Does

DeerFlow isolates agent code execution in sandboxes -- containers or local processes where agents run bash commands, read/write files, and execute code. The system supports three sandbox modes:

- **Local** -- Commands run directly on the host filesystem via subprocess. A singleton `LocalSandbox` instance is shared across all threads. Virtual paths (`/mnt/user-data/...`) are translated to real host paths before execution and masked back in output to prevent host path leakage.
- **Docker/AIO** -- Each thread gets an isolated container running the `all-in-one-sandbox` image. The `AioSandboxProvider` manages container lifecycle with LRU eviction (default 3 replicas), idle timeout (default 600s), warm pool for fast reclaim, and cross-process file locking for deterministic sandbox IDs.
- **Kubernetes** -- A dedicated K8s Pod + NodePort Service per sandbox, provisioned on-demand by the provisioner FastAPI app. The `AioSandboxProvider` delegates to `RemoteSandboxBackend` when `provisioner_url` is configured.

## How It Works

### Sandbox Provider (`backend/packages/harness/deerflow/sandbox/`)

The `SandboxProvider` ABC defines the lifecycle interface:

```python
class SandboxProvider(ABC):
    def acquire(self, thread_id: str | None = None) -> str   # Returns sandbox_id
    def get(self, sandbox_id: str) -> Sandbox | None
    def release(self, sandbox_id: str) -> None
```

Provider resolution is config-driven. `get_sandbox_provider()` reads `config.sandbox.use` (a class path like `deerflow.sandbox.local:LocalSandboxProvider`) and resolves it via `deerflow.reflection.resolve_class()`. The provider is a module-level singleton with `shutdown_sandbox_provider()` for cleanup at app exit.

Two concrete providers exist:

1. **`LocalSandboxProvider`** (`sandbox/local/local_sandbox_provider.py`) -- Returns a singleton `LocalSandbox` with `id="local"`. The `release()` method is a no-op since the singleton persists across threads.
2. **`AioSandboxProvider`** (`community/aio_sandbox/aio_sandbox_provider.py`) -- Full lifecycle manager with in-process caching, warm pool, idle checker thread, cross-process file locking via `fcntl.flock`, and pluggable backends (local container vs. remote/K8s).

### The Sandbox ABC (`sandbox/sandbox.py`)

All sandboxes implement five abstract methods:

| Method | Purpose |
|--------|---------|
| `execute_command(command)` | Run bash, return stdout+stderr |
| `read_file(path)` | Read text file content |
| `list_dir(path, max_depth)` | Tree listing up to N levels |
| `write_file(path, content, append)` | Create or append to text file |
| `update_file(path, content: bytes)` | Write binary content |

`LocalSandbox` uses `subprocess.run()` with a 600-second timeout and shell detection (`/bin/zsh` > `/bin/bash` > `/bin/sh`). `AioSandbox` delegates to a running container over HTTP via the `agent_sandbox` client library.

### Virtual Path Mapping

Agents always see virtual paths. The three virtual directories are:

| Virtual Path | Host Path | Purpose |
|---|---|---|
| `/mnt/user-data/workspace/` | `{base_dir}/threads/{thread_id}/user-data/workspace/` | Agent working directory |
| `/mnt/user-data/uploads/` | `{base_dir}/threads/{thread_id}/user-data/uploads/` | User-uploaded files |
| `/mnt/user-data/outputs/` | `{base_dir}/threads/{thread_id}/user-data/outputs/` | Agent-generated artifacts |

The constant `VIRTUAL_PATH_PREFIX = "/mnt/user-data"` is defined in `config/paths.py`. The `Paths` class resolves `base_dir` with priority: constructor arg > `DEER_FLOW_HOME` env var > `cwd/.deer-flow` (if in backend/) > `$HOME/.deer-flow`.

For AIO/K8s sandboxes, these directories are volume-mounted into the container at their virtual paths, so no translation is needed. For local sandboxes, `tools.py` handles bidirectional translation: `replace_virtual_path()` converts virtual to host paths before execution, and `mask_local_paths_in_output()` converts host paths back to virtual paths in command output.

`ThreadDataMiddleware` (`agents/middlewares/thread_data_middleware.py`) runs in `before_agent` to compute the three paths for each thread. With `lazy_init=True` (default), it only computes paths without creating directories -- actual directory creation is deferred to `ensure_thread_directories_exist()` on first tool use.

### Sandbox Tools (`sandbox/tools.py`)

Five LangChain tools are exposed to the agent, each decorated with `@tool`:

| Tool | Function | Notes |
|------|----------|-------|
| `bash` | Execute shell command | Validates paths in local mode, replaces virtual paths in command text |
| `ls` | List directory (2-level tree) | Skills paths (`/mnt/skills/`) allowed read-only |
| `read_file` | Read text file, optional line range | Supports both user-data and skills paths |
| `write_file` | Write/append to file | User-data paths only, no skills write access |
| `str_replace` | Find-and-replace in file | Single or all occurrences, user-data paths only |

All tools call `ensure_sandbox_initialized()` for lazy sandbox acquisition -- on first tool call, a sandbox is acquired from the provider and stored in runtime state. Path security is enforced via `validate_local_tool_path()` which rejects path traversal (`..` segments) and restricts access to `/mnt/user-data/` (read-write) and `/mnt/skills/` (read-only). A system-path allowlist (`/bin/`, `/usr/bin/`, `/dev/`, etc.) permits standard executables in bash commands.

### K8s Provisioner (`docker/provisioner/app.py`)

A standalone FastAPI app (port 8002) that dynamically creates per-sandbox Kubernetes Pods + NodePort Services. The `AioSandboxProvider` calls this when `provisioner_url` is configured.

**Endpoints:**
- `POST /api/sandboxes` -- Create Pod + Service (idempotent)
- `DELETE /api/sandboxes/{sandbox_id}` -- Destroy Pod + Service
- `GET /api/sandboxes/{sandbox_id}` -- Get status + URL
- `GET /api/sandboxes` -- List all sandboxes
- `GET /health` -- Health check

**Pod spec:**
- Image: `enterprise-public-cn-beijing.cr.volces.com/vefaas-public/all-in-one-sandbox:latest` (configurable via `SANDBOX_IMAGE` env)
- Resources: requests 100m CPU / 256Mi mem, limits 1000m CPU / 1Gi mem, 500Mi ephemeral storage
- Readiness probe: `GET /v1/sandbox:8080`, initial delay 5s, period 5s
- Liveness probe: `GET /v1/sandbox:8080`, initial delay 10s, period 10s
- Security: `privileged=False`, `allow_privilege_escalation=True`
- Volumes: `/mnt/skills` (read-only hostPath from `SKILLS_HOST_PATH`), `/mnt/user-data` (read-write hostPath from `THREADS_HOST_PATH/{thread_id}/user-data`)
- Namespace: `deer-flow` (auto-created if missing)

NodePort is auto-allocated by K8s. The provisioner polls up to 10 seconds (20 attempts x 0.5s) to read the allocated port. Backend accesses sandboxes via `{NODE_HOST}:{NodePort}` where `NODE_HOST` defaults to `host.docker.internal`.

### SandboxMiddleware (`sandbox/middleware.py`)

Hooks into the agent lifecycle:

- **`before_agent`**: With `lazy_init=True` (default), does nothing -- sandbox is acquired on first tool call via `ensure_sandbox_initialized()`. With `lazy_init=False`, eagerly acquires a sandbox and stores the `sandbox_id` in agent state.
- **`after_agent`**: Releases the sandbox by calling `provider.release()`. Checks both state and runtime context for the sandbox_id. For `LocalSandboxProvider`, release is a no-op. For `AioSandboxProvider`, release parks the container in the warm pool (still running, no cold-start on next turn).

## Key Files

| File | Purpose |
|------|---------|
| `backend/packages/harness/deerflow/sandbox/sandbox.py` | `Sandbox` ABC -- five abstract methods |
| `backend/packages/harness/deerflow/sandbox/sandbox_provider.py` | `SandboxProvider` ABC + singleton management |
| `backend/packages/harness/deerflow/sandbox/tools.py` | Five agent tools + path validation/translation |
| `backend/packages/harness/deerflow/sandbox/middleware.py` | `SandboxMiddleware` -- acquire/release lifecycle |
| `backend/packages/harness/deerflow/sandbox/exceptions.py` | Exception hierarchy (6 classes) |
| `backend/packages/harness/deerflow/sandbox/local/local_sandbox.py` | `LocalSandbox` -- subprocess execution |
| `backend/packages/harness/deerflow/sandbox/local/local_sandbox_provider.py` | Singleton provider for local mode |
| `backend/packages/harness/deerflow/community/aio_sandbox/aio_sandbox.py` | `AioSandbox` -- HTTP client to container |
| `backend/packages/harness/deerflow/community/aio_sandbox/aio_sandbox_provider.py` | Full lifecycle: warm pool, idle timeout, LRU eviction |
| `backend/packages/harness/deerflow/config/sandbox_config.py` | `SandboxConfig` Pydantic model |
| `backend/packages/harness/deerflow/config/paths.py` | `Paths` class, `VIRTUAL_PATH_PREFIX`, path resolution |
| `backend/packages/harness/deerflow/agents/middlewares/thread_data_middleware.py` | `ThreadDataMiddleware` -- computes per-thread paths |
| `backend/app/gateway/path_utils.py` | Gateway-side virtual path resolution |
| `docker/provisioner/app.py` | K8s provisioner FastAPI app |

## Design Decisions

**Why three sandbox modes instead of just Docker.** Local mode is needed for development -- no Docker required, instant startup, direct filesystem access. Docker/AIO is the standard production mode with proper isolation. K8s mode exists for scalable multi-tenant deployments where the provisioner manages pod lifecycle independently of the backend process. The `AioSandboxProvider` handles both Docker and K8s through its pluggable backend abstraction (`LocalContainerBackend` vs `RemoteSandboxBackend`), selected by the presence of `provisioner_url` in config.

**Why lazy initialization by default.** Not every agent turn uses sandbox tools. Many turns are pure LLM reasoning or web search. Lazy init (`SandboxMiddleware.lazy_init=True`) defers container creation until `ensure_sandbox_initialized()` is called by the first tool invocation. This avoids cold-start latency and resource waste on turns that never need a sandbox. The warm pool further amortizes startup cost -- released sandboxes stay running and can be reclaimed without a cold-start.

**Why NodePort instead of ClusterIP for K8s sandboxes.** The backend runs inside a Docker container (not inside K8s), so it cannot reach ClusterIP services. NodePort exposes each sandbox on a host port that the backend container can reach via `host.docker.internal:{port}`. The provisioner architecture diagram in `app.py` makes this explicit: the backend connects directly to sandbox Pods via NodePort, bypassing the provisioner for actual sandbox operations.

## Gotchas

- **Virtual paths only exist inside sandboxes.** The gateway must map virtual paths to host paths for artifact access (file downloads, preview). `path_utils.py` in the gateway delegates to `Paths.resolve_virtual_path()` for this. If you access `/mnt/user-data/outputs/report.pdf` outside a sandbox context, you get a nonexistent path.
- **K8s provisioner has no autoscaling.** One pod per thread, no resource pooling, no HPA. The provisioner creates pods on demand and destroys them on request. There is no mechanism to share a sandbox pod across threads or to scale based on cluster load.
- **Sandbox image is from ByteDance's Volcengine registry** (`enterprise-public-cn-beijing.cr.volces.com/vefaas-public/all-in-one-sandbox:latest`). This is a China-region enterprise registry. Pulling from outside China may be slow or require mirror configuration. The image is configurable via `SANDBOX_IMAGE` env var in the provisioner and `sandbox.image` in app config.
- **Local sandbox leaks host paths without careful masking.** `mask_local_paths_in_output()` does regex-based replacement of host paths in command output, but edge cases (paths in binary output, encoded paths) could leak. The `validate_local_bash_command_paths()` function rejects commands with unsafe absolute paths but allows a hardcoded allowlist of system paths.
- **`allow_privilege_escalation=True` in K8s pods.** Despite `privileged=False`, the sandbox container can escalate privileges. This is likely required by the AIO sandbox image internals but is a security surface to audit for multi-tenant deployments.
- **Thread directories are created with `0o777` permissions.** `Paths.ensure_thread_dirs()` explicitly chmods directories to world-writable so container UIDs can write to mounted volumes. This is necessary but means any process on the host can access thread data.
