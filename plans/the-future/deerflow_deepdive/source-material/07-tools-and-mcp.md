# 07 -- Tools, MCP, and Skills

## What It Does

DeerFlow assembles a unified tool list from five distinct sources before each agent invocation:

1. **Config tools** -- user-defined tools declared in `config.yaml`, resolved via Python reflection at startup.
2. **Built-in tools** -- hard-coded tools shipped with the harness (`present_files`, `ask_clarification`, conditionally `view_image` and `task`).
3. **MCP tools** -- tools loaded asynchronously from external MCP servers, cached in-process, and optionally deferred behind `tool_search`.
4. **Sandbox tools** -- file and shell tools (`ls`, `read_file`, `write_file`, `str_replace`, `bash`) that execute inside a local or container sandbox. These are technically config tools (declared in `config.yaml`) but form a distinct logical category.
5. **The `task` tool** -- sub-agent delegation, only injected when `subagent_enabled=True` at runtime.

Alongside tools, DeerFlow has a **skills system**: Markdown files with YAML frontmatter that inject workflow instructions into the system prompt. Skills are not tools -- they are prompt augmentations that guide the agent's behavior for domain-specific tasks.

A **deferred tool loading** mechanism (`tool_search`) lets the system hide large numbers of MCP tool schemas from the model context, exposing only tool names in the system prompt and loading full schemas on demand.

## How It Works

### Tool Assembly

The entry point is `get_available_tools()` in `tools/tools.py`. It accepts optional filters (`groups`, `include_mcp`, `model_name`, `subagent_enabled`) and returns a flat `list[BaseTool]`. The assembly order:

1. **Config tools**: iterate `config.tools`, call `resolve_variable(tool.use, BaseTool)` for each. This uses Python's `importlib.import_module()` to resolve a `"module.path:variable_name"` string to a live tool instance.
2. **Built-in tools**: start with `[present_file_tool, ask_clarification_tool]`. Conditionally append `view_image_tool` if the model's config has `supports_vision: true`. Conditionally extend with `[task_tool]` if `subagent_enabled`.
3. **MCP tools**: call `get_cached_mcp_tools()`, which lazily initializes via `initialize_mcp_tools()` if not yet loaded. When `tool_search.enabled` is true, MCP tools are registered in a `DeferredToolRegistry` instead of being returned directly, and `tool_search` is added to the built-in list.
4. **Return**: `loaded_tools + builtin_tools + mcp_tools`.

The deferred registry is **reset at the top of every `get_available_tools()` call** via `reset_deferred_registry()` to prevent stale tool references from a previous invocation.

### Config Tools

Defined in the `[tools]` section of `config.yaml`. Each entry has three required fields:

| Field   | Purpose                                                          | Example                                       |
|---------|------------------------------------------------------------------|-----------------------------------------------|
| `name`  | Unique identifier                                                | `web_search`                                  |
| `group` | Category for filtering                                           | `web`, `file:read`, `file:write`, `bash`      |
| `use`   | Python variable path resolved via `resolve_variable()`           | `deerflow.community.tavily.tools:web_search_tool` |

Extra keys on the tool entry (e.g., `max_results`, `timeout`) are passed through to the tool's Pydantic model via `ConfigDict(extra="allow")`.

Tool groups are declared in `[tool_groups]` and used to filter which tools an agent receives. The default groups are `web`, `file:read`, `file:write`, and `bash`.

The `resolve_variable()` function in `reflection/resolvers.py` splits on `:`, imports the module via `import_module()`, then uses `getattr()` to grab the tool. It validates that the result is a `BaseTool` instance and provides actionable error messages when dependencies are missing (e.g., "Install it with `uv add langchain-google-genai`").

### Built-in Tools

Located in `tools/builtins/`. Each is a `@tool`-decorated function:

| Tool                | Registered Name      | Purpose                                                                                   |
|---------------------|----------------------|-------------------------------------------------------------------------------------------|
| `present_file_tool` | `present_files`      | Makes output files visible to the user as artifacts. Normalizes paths to `/mnt/user-data/outputs/*` contract. Returns a `Command` that updates `artifacts` state. |
| `ask_clarification_tool` | `ask_clarification` | Triggers `ClarificationMiddleware` interrupt. Has `return_direct=True` -- the tool call itself is intercepted by middleware before it reaches execution. Accepts typed clarification categories: `missing_info`, `ambiguous_requirement`, `approach_choice`, `risk_confirmation`, `suggestion`. |
| `view_image_tool`   | `view_image`         | Reads an image file, base64-encodes it, and stores it in `viewed_images` state for vision model consumption. Only bound when the selected model has `supports_vision: true`. |
| `task_tool`         | `task`               | Delegates work to a subagent (`general-purpose` or `bash` type). Creates a `SubagentExecutor`, runs it asynchronously, then polls for completion in-process using `get_stream_writer()` to emit progress events (`task_started`, `task_running`, `task_completed`, `task_failed`, `task_timed_out`). Subagents receive their own tool set via recursive `get_available_tools(subagent_enabled=False)` to prevent nesting. |
| `tool_search`       | `tool_search`        | Deferred tool discovery. Only added when `tool_search.enabled` and MCP tools exist. See Deferred Tool Loading below. |
| `setup_agent`       | `setup_agent`        | Creates custom agent configurations (SOUL.md + config.yaml). Exported from builtins but not included in `BUILTIN_TOOLS` or `SUBAGENT_TOOLS` -- used in a separate agent-creation flow. |

### MCP Integration

The MCP subsystem lives in `mcp/` with four files:

**`client.py`** -- Builds `MultiServerMCPClient` configuration from `ExtensionsConfig`. Supports three transport types: `stdio` (command + args + env), `sse` (url + headers), and `http` (url + headers). Server definitions live in `extensions_config.json` (not `config.yaml`), keyed under `mcpServers`.

**`tools.py`** -- `get_mcp_tools()` is the async entry point. It reads `ExtensionsConfig.from_file()` fresh each time (to pick up Gateway API changes across process boundaries), builds the server config, injects initial OAuth headers, attaches tool interceptors, then calls `client.get_tools()` to fetch tools from all servers. The `tool_name_prefix=True` flag namespaces tool names by server to avoid collisions.

**`cache.py`** -- Manages a module-level `_mcp_tools_cache` singleton with an `asyncio.Lock`. `initialize_mcp_tools()` runs once; `get_cached_mcp_tools()` handles lazy initialization including the tricky case where the event loop is already running (LangGraph Studio) by spinning up a `ThreadPoolExecutor` to run `asyncio.run()` in a new thread. The cache tracks the config file's `mtime` and auto-invalidates when the extensions config is modified on disk.

**`oauth.py`** -- `OAuthTokenManager` handles `client_credentials` and `refresh_token` grant types. Tokens are cached with expiry tracking and a configurable `refresh_skew_seconds` buffer. A `build_oauth_tool_interceptor()` creates a per-request interceptor that injects fresh `Authorization` headers into tool calls. Initial headers are also injected at connection time via `get_initial_oauth_headers()`.

### Skills System

Skills are Markdown files with YAML frontmatter stored in `skills/public/` and `skills/custom/`. They are **not tools** -- they are prompt injections.

**Loader** (`skills/loader.py`): `load_skills()` walks `public/` and `custom/` directories looking for `SKILL.md` files. It uses `os.walk()` with deterministic sorting and hidden-directory filtering. After loading, it checks `ExtensionsConfig.from_file()` to determine each skill's enabled/disabled state.

**Parser** (`skills/parser.py`): `parse_skill_file()` extracts YAML frontmatter via regex (`^---\n(.*?)\n---`), then does simple line-by-line `key: value` parsing (not full YAML parsing). Required fields: `name`, `description`. Optional: `license`.

**Validation** (`skills/validation.py`): `_validate_skill_frontmatter()` performs stricter checking -- full `yaml.safe_load()`, allowed property whitelist (`name`, `description`, `license`, `allowed-tools`, `metadata`, `compatibility`, `version`, `author`), name format validation (hyphen-case, max 64 chars), description length limit (max 1024 chars, no angle brackets).

**Prompt injection** (`agents/lead_agent/prompt.py`): `get_skills_prompt_section()` loads enabled skills and generates a `<skill_system>` XML block listing each skill's name, description, and container file path. The agent is instructed to use `read_file` on the skill path when a query matches, then follow the skill's instructions. This is the "progressive loading" pattern -- frontmatter metadata is always in the prompt, but the full skill body is only loaded when the agent decides to read it.

**Enable/disable via API**: `PUT /api/skills/{skill_name}` updates `extensions_config.json` and reloads the cached config. The frontend settings UI calls this endpoint.

**Install from artifacts**: `POST /api/skills/install` accepts a thread ID and virtual path to a `.skill` file (ZIP archive). It extracts safely (rejects absolute paths, directory traversal, symlinks; enforces 512MB size limit), validates frontmatter, and copies to `skills/custom/`.

### Deferred Tool Loading

When `tool_search.enabled: true` in `config.yaml`, MCP tools are hidden from the model but remain available for execution:

1. `get_available_tools()` creates a `DeferredToolRegistry` and registers all MCP tools in it.
2. `tool_search` is added to the built-in tools list.
3. `DeferredToolFilterMiddleware` intercepts `wrap_model_call` and removes deferred tool schemas from `request.tools` before `bind_tools` -- the model never sees their JSON schemas.
4. The system prompt includes an `<available-deferred-tools>` block listing only tool names (via `get_deferred_tools_prompt_section()`).
5. The model calls `tool_search(query)` to discover tools. The registry supports three query forms: `"select:name1,name2"` for exact match, `"+keyword rest"` for required-name + ranking, and free regex search against name + description. Results are capped at `MAX_RESULTS = 5`.
6. `tool_search` returns tool definitions in OpenAI function-calling JSON format (via `convert_to_openai_function()`). Once the model has seen a tool's schema, it can call it -- `ToolNode` holds all tools (including deferred) for execution routing.

## Key Files

| File | Purpose |
|------|---------|
| `tools/tools.py` | `get_available_tools()` -- main assembly function |
| `tools/builtins/__init__.py` | Exports all built-in tools |
| `tools/builtins/present_file_tool.py` | File artifact presentation |
| `tools/builtins/clarification_tool.py` | User clarification interrupt |
| `tools/builtins/view_image_tool.py` | Base64 image loading for vision models |
| `tools/builtins/task_tool.py` | Sub-agent delegation with async polling |
| `tools/builtins/tool_search.py` | `DeferredToolRegistry` + `tool_search` tool |
| `tools/builtins/setup_agent_tool.py` | Custom agent creation (SOUL.md writer) |
| `reflection/resolvers.py` | `resolve_variable()` and `resolve_class()` |
| `config/tool_config.py` | `ToolConfig` and `ToolGroupConfig` Pydantic models |
| `config/tool_search_config.py` | `ToolSearchConfig` (enabled flag) |
| `config/skills_config.py` | `SkillsConfig` (path, container_path) |
| `config/extensions_config.py` | `ExtensionsConfig`, `McpServerConfig`, `SkillStateConfig` |
| `mcp/client.py` | `build_server_params()`, `build_servers_config()` |
| `mcp/tools.py` | `get_mcp_tools()` -- async MCP tool loading |
| `mcp/cache.py` | `initialize_mcp_tools()`, `get_cached_mcp_tools()`, mtime staleness |
| `mcp/oauth.py` | `OAuthTokenManager`, token interceptor |
| `skills/loader.py` | `load_skills()`, directory walking |
| `skills/parser.py` | `parse_skill_file()`, frontmatter extraction |
| `skills/types.py` | `Skill` dataclass |
| `skills/validation.py` | `_validate_skill_frontmatter()`, allowed properties |
| `agents/lead_agent/prompt.py` | `get_skills_prompt_section()`, `get_deferred_tools_prompt_section()` |
| `agents/middlewares/deferred_tool_filter_middleware.py` | Strips deferred schemas from model binding |
| `app/gateway/routers/skills.py` | REST API: list, get, update, install skills |

All paths are relative to `backend/packages/harness/deerflow/` unless prefixed with `app/`.

## Design Decisions

**Why five-source assembly instead of a single tool registry.** Each source has a different lifecycle. Config tools are static after startup. Built-in tools depend on runtime flags (vision support, subagent mode). MCP tools are async, cached, and can change when the extensions config file is modified. Keeping them separate makes the conditional logic in `get_available_tools()` straightforward -- each source is appended independently with its own guards.

**Why deferred tool loading.** When multiple MCP servers expose dozens of tools, sending all their JSON schemas to the model wastes context tokens and degrades tool selection accuracy. The deferred pattern sends only tool names (~20 tokens total) and loads full schemas on demand. The tradeoff is an extra round-trip when the model needs a deferred tool, but this is typically cheaper than binding 50+ tool schemas on every turn.

**Why Markdown skills instead of code-based definitions.** Skills are prompt-level workflow instructions, not executable code. Markdown is human-readable, version-controllable, and can be authored by non-developers. The YAML frontmatter provides just enough structured metadata for discovery and filtering. The progressive loading pattern (frontmatter in prompt, body loaded via `read_file`) keeps baseline token costs low.

**Why reflection-based tool resolution.** The `use: "module.path:variable_name"` pattern lets users add community tools or custom tools without modifying DeerFlow source code. A new tool is just a Python module that exports a `BaseTool` instance. The resolver provides clear error messages with install commands when dependencies are missing, which matters because different LLM providers require different packages.

## Gotchas

- **MCP tools are async.** `get_mcp_tools()` is an `async def` that must run in an event loop. The cache layer handles the case where the loop is already running (LangGraph Studio) by spawning a `ThreadPoolExecutor` thread to call `asyncio.run()`. This is the only place in the codebase where sync-to-async bridging happens for tool loading.

- **Deferred tools live in ToolNode but are hidden from model binding.** `DeferredToolFilterMiddleware` removes deferred schemas from `request.tools` in `wrap_model_call`, but the `ToolNode` that executes tool calls still holds references to all tools (including deferred). This split is intentional: the model discovers tools via `tool_search`, then the execution layer can route the call.

- **`reset_deferred_registry()` runs on every `get_available_tools()` call.** This prevents stale references when MCP tools are reloaded due to config changes. Without this reset, a tool that was removed from an MCP server could remain discoverable via `tool_search`.

- **Skills can be installed from thread artifacts.** `POST /api/skills/install` takes a `.skill` file (ZIP archive) from a thread's output directory and extracts it to `skills/custom/`. The extraction includes security checks: path traversal rejection, symlink skipping, and a 512MB uncompressed size limit. Skills installed this way appear immediately in the next `load_skills()` call.

- **The parser uses simple line splitting, not full YAML.** `parser.py` splits frontmatter on `\n` and `:` rather than using `yaml.safe_load()`. This means multi-line YAML values or nested structures in frontmatter will not parse correctly in the loader path. The validation path (`validation.py`) does use proper `yaml.safe_load()` but is only invoked during skill installation, not during routine loading.

- **`ExtensionsConfig.from_file()` is called repeatedly instead of using the cached singleton.** Both `get_available_tools()` and `load_skills()` deliberately call `ExtensionsConfig.from_file()` instead of `get_extensions_config()` to pick up changes made by the Gateway API, which runs in a separate process. The comment "always read the latest configuration from disk" appears in three places.

- **`task_tool` prevents recursive nesting.** When a subagent calls `get_available_tools()`, it passes `subagent_enabled=False`, which excludes `task_tool` from the returned list. This is a hard guard against infinite delegation chains.
