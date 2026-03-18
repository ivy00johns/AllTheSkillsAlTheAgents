# 08 -- Integration Layer

Complete reference for beads integrations: the MCP server, Claude Code plugin,
AI tool recipes, community tools, the Go library API, direct SQL access, and
OpenTelemetry instrumentation.

Source: `integrations/beads-mcp/`, `integrations/claude-code/`,
`internal/recipes/`, `beads.go`, `internal/telemetry/`.

---

## 1. MCP Server (integrations/beads-mcp/)

### 1.1 Overview

The beads MCP server is a Python package published to PyPI as `beads-mcp`
(v0.61.0). It implements the Model Context Protocol using FastMCP and
communicates with the `bd` CLI entirely via subprocess calls. There is no
direct database access from the MCP server.

**Key design decision:** ALL operations shell out to the `bd` binary with
`--json` flag. The MCP server is a thin translation layer between MCP tool
calls and CLI invocations. This keeps the source of truth in one place (the Go
CLI) and avoids Python-side database drivers, connection management, or schema
knowledge.

**Package metadata:**

```
Name:            beads-mcp
Version:         0.61.0
Python:          >=3.10
License:         MIT
Dependencies:    fastmcp==3.1.1, pydantic==2.12.5, pydantic-settings==2.13.1
Build system:    hatchling
Entry point:     beads-mcp = beads_mcp.server:main
```

### 1.2 Communication Architecture

```
MCP Client (Claude, etc.)
    |
    v  stdio (JSON-RPC)
FastMCP Server (server.py)
    |
    v  function dispatch
tools.py (tool functions)
    |
    v  async call
bd_client.py (BdClientBase)
    |
    v  asyncio.create_subprocess_exec
bd CLI binary  (with --json flag)
    |
    v  embedded Dolt
.beads/dolt/ database
```

Every tool call becomes an `asyncio.create_subprocess_exec("bd", ..., "--json")`
call. The JSON output from `bd` is parsed by pydantic models and returned to
the MCP client.

### 1.3 Complete Tool List

| MCP Tool | Function | BD Command | Returns |
|----------|----------|------------|---------|
| `ready` | `beads_ready_work()` | `bd ready --limit N [filters]` | `list[Issue]` (compacted to `CompactedResult` when > threshold) |
| `list` | `beads_list_issues()` | `bd list [filters]` | `list[Issue]` (compacted to `CompactedResult` when > threshold) |
| `show` | `beads_show_issue()` | `bd show <id>` | `Issue` (full detail) |
| `create` | `beads_create_issue()` | `bd create <title> -p N -t TYPE [...]` | `Issue` (or `OperationResult` in compact mode) |
| `claim` | `beads_claim_issue()` | `bd update <id> --claim` | `Issue` (atomic compare-and-swap, fails if already claimed) |
| `update` | `beads_update_issue()` | `bd update <id> [fields]` | `Issue` or `list[Issue]` (routes to close/reopen for lifecycle changes) |
| `close` | `beads_close_issue()` | `bd close <id> --reason <r>` | `list[Issue]` (may include unblocked dependents) |
| `reopen` | `beads_reopen_issue()` | `bd reopen <id> [...]` | `list[Issue]` |
| `dep` | `beads_add_dependency()` | `bd dep add <from> <to> --type <t>` | `str` confirmation message |
| `stats` | `beads_stats()` | `bd stats` | `Stats` (total, open, in_progress, closed, blocked, ready, avg lead time) |
| `blocked` | `beads_blocked()` | `bd blocked [--parent P]` | `list[BlockedIssue]` |
| `context` | `beads_context()` | (set/init workspace) | `str` workspace confirmation |
| `admin/validate` | `beads_validate()` | `bd validate [--checks ...]` | `dict` with validation results per check |
| `admin/repair-deps` | `beads_repair_deps()` | `bd repair-deps [--fix]` | `dict` with orphans found/fixed |
| `admin/detect-pollution` | `beads_detect_pollution()` | `bd detect-pollution [--clean]` | `dict` with detected test issues |
| `admin/inspect-migration` | `beads_inspect_migration()` | `bd migrate --inspect` | `dict` with migration plan and DB state |
| `admin/schema-info` | `beads_get_schema_info()` | `bd info --json` | `dict` with tables, schema version, config |
| `admin/init` | `beads_init()` | `bd init [--prefix ...]` | `str` confirmation |
| `discover_tools` | (no bd call) | -- | `dict` of available tool names and descriptions |
| `get_tool_info` | (no bd call) | -- | `dict` with detailed schema for a specific tool |
| `quickstart` | `beads_quickstart()` | `bd quickstart` | `str` guide text |

### 1.4 Workspace Resolution

The MCP server must determine which beads database to operate against. This is
non-trivial because MCP tool calls do not carry persistent process state.

**Resolution order (matches Go CLI):**

1. `current_workspace` ContextVar -- Set by the `workspace_root` parameter on
   tool calls. Scoped per-request.
2. `_workspace_context` module-level dict -- Persistent across MCP tool calls.
   Set by the `context` tool. This is the workaround for `os.environ` not
   persisting across FastMCP calls.
3. `BEADS_WORKING_DIR` environment variable.
4. Auto-detect -- Walks up from CWD looking for `.beads/*.db` (via
   `_find_beads_db_in_tree()`). Follows `.beads/redirect` files for shared
   database scenarios.

**Redirect handling:** The MCP server implements its own redirect resolution
(`_resolve_beads_redirect()`), mirroring the Go CLI's behavior. Redirects are
critical for polecat/crew directories that share a central database.

### 1.5 Connection Pool

The MCP server maintains a connection pool of `BdClientBase` instances keyed
by canonical workspace path.

```python
_connection_pool: dict[str, BdClientBase] = {}
_pool_lock = asyncio.Lock()
```

**Path canonicalization:** `_canonicalize_path()` resolves symlinks, checks for
local `.beads` directories (submodule edge case), and falls back to git
toplevel. This ensures different paths pointing to the same project use the same
client.

**Health checking:** Before returning a cached client, `_health_check_client()`
verifies it is responsive. If unhealthy, the client is dropped from the pool
and reconnection is attempted.

**Reconnection with exponential backoff:** `_reconnect_client()` retries up to
3 times with backoff delays of 0.1s, 0.2s, 0.4s.

**Version checking:** On first connection to each workspace, `_check_version()`
verifies the `bd` CLI version is compatible with the MCP server.

### 1.6 Context Engineering

The MCP server implements aggressive context window optimization to keep
agent token usage low.

**Compaction settings (configurable via environment):**

| Variable | Default | Description |
|----------|---------|-------------|
| `BEADS_MCP_COMPACTION_THRESHOLD` | 20 | Compact results with more than N issues |
| `BEADS_MCP_PREVIEW_COUNT` | 5 | Show first N issues in preview when compacting |

When a `ready` or `list` call returns more issues than the threshold,
the response is wrapped in a `CompactedResult`:

```python
class CompactedResult(BaseModel):
    compacted: bool = True
    total_count: int
    preview: list[IssueMinimal]
    preview_count: int
    hint: str = "Use show(issue_id) for full issue details"
```

**Model hierarchy (context budget):**

| Model | Approx. Size | Fields | Use Case |
|-------|-------------|--------|----------|
| `BriefIssue` | ~80 bytes | 4 (id, title, status, priority) | Quick scanning |
| `IssueMinimal` | ~200 bytes | 8 (+ type, assignee, labels, counts) | List views |
| `Issue` | ~800-2000 bytes | 20+ (full detail with deps, description) | Show command |

**Lazy tool schema loading:** `discover_tools()` returns only names and
descriptions. `get_tool_info()` returns detailed parameter schemas on demand.
This avoids dumping all tool schemas into the context at session start.

### 1.7 Smart Update Routing

The `beads_update_issue()` function intercepts lifecycle status changes:

- Setting `status="closed"` automatically routes to `beads_close_issue()` to
  ensure approval workflows (gate checks, epic guards) are followed.
- Setting `status="open"` routes to `beads_reopen_issue()`.
- All other attribute updates proceed normally.

### 1.8 P0/P1 Bug: Multi-Repo Routing

**Problem:** `os.environ` changes do not persist across FastMCP tool calls.
When the MCP server switches workspace context via environment variable, the
next tool call loses that context.

**Workaround:** The `_workspace_context` module-level dict was added as
persistent storage. The `context` tool writes to this dict, and all subsequent
tool calls read from it.

**Remaining risk:** Without explicit `workspace_root` on every tool call, write
operations can route to the wrong project. The `BEADS_REQUIRE_CONTEXT=1`
environment variable enables a guard that rejects tool calls without explicit
workspace context, but it is opt-in and disabled by default.

---

## 2. Claude Code Plugin (integrations/claude-code/)

### 2.1 Plugin Hooks

Installed via `bd setup claude`, which modifies:
- `~/.claude/settings.json` (global hooks)
- `.claude/settings.local.json` (project hooks)

**Hooks:**

| Hook | Trigger | Command |
|------|---------|---------|
| `SessionStart` | New Claude Code session | `bd prime` |
| `PreCompact` | Before context compression | `bd prime` |

`bd prime` injects the full workflow context: current ready work, project
status, agent configuration, memories, and skill files. By running on
`PreCompact`, the context survives context window compression.

### 2.2 Slash Commands

The Claude Code plugin provides 30+ slash commands as markdown files in
`~/.claude/commands/`:

```
/beads:create      Create a new issue
/beads:ready       Show ready work
/beads:show        Show issue details
/beads:close       Close an issue
/beads:update      Update an issue
/beads:list        List issues
/beads:blocked     Show blocked issues
/beads:stats       Show statistics
/beads:dep         Add dependency
/beads:search      Search issues
/beads:graph       Show dependency graph
...
```

The primary slash command is `/plan-to-beads`, which converts Claude Code plan
files (`.md` format with phases) into beads epics with sequential task
dependencies.

### 2.3 @task-agent

The `@task-agent` is an autonomous agent pattern defined in the skill files.
Its control loop:

1. Find ready work (`bd ready`)
2. Claim an issue (`bd update <id> --claim`)
3. Execute the work (code changes, tests, etc.)
4. Discover new work (create child issues with `discovered-from` dependency)
5. Close the issue (`bd close <id>`)
6. Repeat from step 1

### 2.4 Skills System

The Claude Code plugin includes a `SKILL.md` file with 16 resource files
covering:

- Boundaries (what agents should and should not do)
- Patterns (coding patterns, review patterns)
- Chemistry (formula/molecule system usage)
- Agents (multi-agent coordination patterns)
- Gates (dependency gate system)
- Worktrees (parallel git worktree management)
- Memory (persistent memory system)
- And others

These files are loaded into the agent's context at session start and provide
the operational manual for how agents should interact with beads.

---

## 3. Recipes (internal/recipes/recipes.go)

Recipes define how beads workflow instructions are installed for different AI
tools. Managed via `bd setup <recipe>`.

### 3.1 Recipe Types

| Type | Description | Example |
|------|-------------|---------|
| `file` | Write template to a single file path | Cursor, Windsurf, Cody |
| `hooks` | Modify JSON settings to add hooks | Claude, Gemini |
| `section` | Inject a marked section into an existing file | Factory, Codex, Mux, OpenCode |
| `multifile` | Write multiple files | Aider, Junie |

### 3.2 Built-in Recipes

| Recipe | Type | Target Files |
|--------|------|-------------|
| `cursor` | file | `.cursor/rules/beads.mdc` |
| `windsurf` | file | `.windsurf/rules/beads.md` |
| `cody` | file | `.cody/rules/beads.md` |
| `kilocode` | file | `.kilocode/rules/beads.md` |
| `claude` | hooks | `~/.claude/settings.json` + `.claude/settings.local.json` |
| `gemini` | hooks | `~/.gemini/settings.json` + `.gemini/settings.json` (project) |
| `factory` | section | `AGENTS.md` |
| `codex` | section | `AGENTS.md` |
| `mux` | section | `AGENTS.md` |
| `opencode` | section | `AGENTS.md` |
| `aider` | multifile | `.aider.conf.yml` + `.aider/BEADS.md` + `.aider/README.md` |
| `junie` | multifile | `.junie/guidelines.md` + `.junie/mcp/mcp.json` |

### 3.3 User-Defined Recipes

Users can define custom recipes in `.beads/recipes.toml` (TOML format). User
recipes override built-in recipes with the same name.

```toml
[my-tool]
name = "My Custom Tool"
path = ".my-tool/rules.md"
type = "file"
description = "Custom tool integration"
```

---

## 4. Community Tools (docs/COMMUNITY_TOOLS.md)

The beads ecosystem includes 25+ community-developed tools:

### 4.1 Terminal UIs

| Tool | Description |
|------|-------------|
| Mardi Gras | TUI dashboard for beads |
| perles | Perl-based terminal UI |
| bdui | ncurses-based issue browser |

### 4.2 Web UIs

| Tool | Description |
|------|-------------|
| beads-ui | React-based web dashboard |
| BeadBoard | Kanban board view |

### 4.3 Editor Extensions

| Tool | Description |
|------|-------------|
| vscode-beads | VS Code extension |
| nvim-beads | Neovim plugin |

### 4.4 SDKs

| Tool | Description |
|------|-------------|
| `@herbcaudill/beads-sdk` | TypeScript SDK for beads |

### 4.5 Coordination

| Tool | Description |
|------|-------------|
| BeadHub | Coordination server for multi-agent setups |

---

## 5. Go Library API (beads.go)

The `beads` package provides a minimal public API for Go-based extensions.
Located at the repository root as `beads.go`.

### 5.1 Opening a Store

```go
// Embedded mode (always in-process, ignores server config)
store, err := beads.Open(ctx, beads.FindDatabasePath())

// Config-aware mode (respects metadata.json server settings)
store, err := beads.OpenFromConfig(ctx, beads.FindBeadsDir())
```

`Open()` calls `dolt.New()` with `CreateIfMissing: true`.
`OpenFromConfig()` calls `dolt.NewFromConfigWithOptions()` which reads
`metadata.json` and connects to the Dolt SQL server when `dolt_mode` is
`"server"`.

### 5.2 Discovery Functions

```go
// Find the beads database in the current directory tree
dbPath := beads.FindDatabasePath()

// Find the .beads/ directory
beadsDir := beads.FindBeadsDir()

// Find all beads databases on the system
databases := beads.FindAllDatabases()

// Check if current directory has a redirect
info := beads.GetRedirectInfo()
```

### 5.3 Core Operations

```go
store, _ := beads.Open(ctx, dbPath)
defer store.Close()

// Get ready work (blocker-aware)
ready, err := store.GetReadyWork(ctx, beads.WorkFilter{
    Limit:    10,
    Status:   "open",
    Priority: &priority,
})

// Create an issue
issue := &beads.Issue{
    Title:    "Fix the bug",
    Priority: 1,
    IssueType: beads.TypeBug,
    Status:   beads.StatusOpen,
}
err = store.CreateIssue(ctx, issue, "actor-name")

// Update, close, etc.
err = store.UpdateIssue(ctx, issue, "actor-name")
err = store.CloseIssue(ctx, issueID, "reason", "actor-name")
```

### 5.4 Exported Type Aliases

The `beads` package re-exports types from `internal/types`:

| Alias | Internal Type |
|-------|---------------|
| `Storage` | `beads.Storage` (interface) |
| `Transaction` | `beads.Transaction` (interface) |
| `Issue` | `types.Issue` |
| `Status` | `types.Status` |
| `IssueType` | `types.IssueType` |
| `Dependency` | `types.Dependency` |
| `DependencyType` | `types.DependencyType` |
| `Label` | `types.Label` |
| `Comment` | `types.Comment` |
| `Event` | `types.Event` |
| `EventType` | `types.EventType` |
| `BlockedIssue` | `types.BlockedIssue` |
| `TreeNode` | `types.TreeNode` |
| `IssueFilter` | `types.IssueFilter` |
| `WorkFilter` | `types.WorkFilter` |
| `StaleFilter` | `types.StaleFilter` |
| `DependencyCounts` | `types.DependencyCounts` |
| `IssueWithCounts` | `types.IssueWithCounts` |
| `IssueWithDependencyMetadata` | `types.IssueWithDependencyMetadata` |
| `SortPolicy` | `types.SortPolicy` |
| `EpicStatus` | `types.EpicStatus` |

### 5.5 Status and Type Constants

```go
// Statuses
beads.StatusOpen, beads.StatusInProgress, beads.StatusBlocked,
beads.StatusDeferred, beads.StatusClosed

// Issue types
beads.TypeBug, beads.TypeFeature, beads.TypeTask,
beads.TypeEpic, beads.TypeChore

// Dependency types
beads.DepBlocks, beads.DepRelated, beads.DepParentChild,
beads.DepDiscoveredFrom, beads.DepConditionalBlocks

// Sort policies
beads.SortPolicyHybrid, beads.SortPolicyPriority, beads.SortPolicyOldest
```

---

## 6. Direct SQL Access

### 6.1 bd sql

```
bd sql '<query>'
```

Executes raw SQL against the underlying Dolt database. Bypasses the storage
layer entirely. Uses `storage.RawDBAccessor` to get the underlying `*sql.DB`
handle.

**Supported output formats:**

- Default: ASCII table
- `--json`: JSON array of objects
- `--csv`: CSV with headers

**Examples:**

```bash
bd sql 'SELECT COUNT(*) FROM issues'
bd sql 'SELECT id, title FROM issues WHERE status = "open" LIMIT 5'
bd sql 'DELETE FROM dirty_issues WHERE issue_id = "bd-abc123"'
bd sql --csv 'SELECT id, title, status FROM issues'
```

**Warning:** Direct SQL bypasses audit trails, validation, dependency graph
updates, and hook execution. Use with caution.

### 6.2 bd query (SQL mode)

`bd query` with a SQL string (when it detects `SELECT` at the start) can
route to arbitrary SQL against Dolt:

```bash
bd query "SELECT * FROM issues WHERE priority = 0"
```

### 6.3 Extension Tables

Since the backing store is Dolt (MySQL-compatible SQL), you can add custom
tables and join them with beads tables:

```sql
-- Add a custom tracking table
CREATE TABLE deploy_tracking (
    issue_id VARCHAR(255) REFERENCES issues(id),
    deploy_env VARCHAR(50),
    deployed_at DATETIME,
    PRIMARY KEY (issue_id, deploy_env)
);

-- Query with join
SELECT i.id, i.title, d.deploy_env, d.deployed_at
FROM issues i
JOIN deploy_tracking d ON i.id = d.issue_id
WHERE d.deploy_env = 'production';
```

Extension tables are preserved across beads upgrades and migrations (they only
touch the core schema tables).

---

## 7. OpenTelemetry Integration

### 7.1 Configuration

Telemetry is opt-in with zero overhead when disabled. Controlled by environment
variables:

| Variable | Description |
|----------|-------------|
| `BD_OTEL_METRICS_URL` | OTLP HTTP endpoint for metrics push (e.g., `http://localhost:8428/opentelemetry/api/v1/push`) |
| `BD_OTEL_LOGS_URL` | OTLP HTTP endpoint for logs (reserved for future use) |
| `BD_OTEL_STDOUT` | Set to `"true"` to write spans and metrics to stderr (dev/debug) |

Either `BD_OTEL_METRICS_URL` or `BD_OTEL_STDOUT=true` must be set to activate
telemetry. When neither is set, no-op providers are installed (zero allocations,
zero overhead).

### 7.2 Span Structure

Every CLI command creates a root span:

```
bd.command.<name>
    attributes:
        bd.command = "<name>"
        bd.version = "<version>"
        bd.args = "<raw args>"
        bd.actor = "<resolved actor>"
```

All downstream operations (SQL queries, HTTP calls, etc.) are child spans of
the command span.

### 7.3 Metrics

Emitted as OTLP metrics (pushed to VictoriaMetrics or any OTLP receiver):

| Metric | Type | Description |
|--------|------|-------------|
| `bd.db.retry_count` | counter | Number of database retry attempts |
| `bd.db.lock_wait_ms` | histogram | Time spent waiting for database locks |
| `bd.command.duration_ms` | histogram | Total command execution time |

### 7.4 Recommended Local Stack

```
VictoriaMetrics :8428  -- metrics storage
VictoriaLogs    :9428  -- log storage
Grafana         :9429  -- dashboards
```

### 7.5 Lifecycle

1. `telemetry.Init()` in PersistentPreRun -- configures providers.
2. Command span started immediately after Init.
3. All storage operations are instrumented as child spans.
4. `telemetry.Shutdown()` in PersistentPostRun with 5-second timeout.

---

## 8. Integration Patterns

### 8.1 Subprocess Pattern (MCP Server)

The MCP server demonstrates the recommended integration pattern:

1. Shell out to `bd` with `--json` flag.
2. Parse JSON output with a schema-aware parser (pydantic).
3. Handle errors by inspecting stderr and return codes.
4. Maintain workspace context across calls.

This pattern works with any language and avoids tight coupling to beads
internals. The CLI's `--json` output is a stable contract.

### 8.2 Library Pattern (Go Extensions)

For Go programs that need direct database access:

```go
import "github.com/steveyegge/beads"

store, _ := beads.OpenFromConfig(ctx, beads.FindBeadsDir())
defer store.Close()

// Use store.GetReadyWork(), store.CreateIssue(), etc.
```

This avoids subprocess overhead but couples to beads' Go API surface.

### 8.3 SQL Pattern (Custom Queries)

For ad-hoc analysis or custom dashboards:

```bash
bd sql 'SELECT assignee, COUNT(*) as count FROM issues
        WHERE status = "open" GROUP BY assignee ORDER BY count DESC'
```

Or programmatically via Dolt's MySQL-compatible protocol when running in
server mode (connect with any MySQL client library).

### 8.4 Hook Pattern (Event-Driven)

Place executable scripts in `.beads/hooks/`:

```
.beads/hooks/
    post-create     # Runs after issue creation
    post-close      # Runs after issue closure
    post-update     # Runs after issue update
```

The hook runner passes the issue data as JSON to the script's stdin. Hooks
are executed synchronously after the database write.

---

## 9. MCP Server Pydantic Models (Reference)

### 9.1 Issue Model (Full)

```python
class Issue(BaseModel):
    id: str
    title: str
    description: str = ""
    design: str = ""
    acceptance_criteria: str = ""
    notes: str = ""
    status: IssueStatus
    priority: int = Field(ge=0, le=4)
    issue_type: IssueType
    assignee: str | None = None
    external_ref: str | None = None
    labels: list[str] = []
    dependencies: list[LinkedIssue] = []
    dependents: list[LinkedIssue] = []
    dependency_count: int = 0
    dependent_count: int = 0
    created_at: datetime | None = None
    updated_at: datetime | None = None
    closed_at: datetime | None = None
    created_by: str = ""
```

### 9.2 Status and Type Definitions

```python
# Built-in statuses: open, in_progress, blocked, deferred, closed
# Custom statuses supported via bd config set status.custom
IssueStatus = str

# Built-in types: bug, feature, task, epic, chore, decision
# Custom types supported via bd config set types.custom
IssueType = str

DependencyType = Literal["blocks", "related", "parent-child", "discovered-from"]
OperationAction = Literal["created", "updated", "claimed", "closed", "reopened"]
```

### 9.3 Operation Result

```python
class OperationResult(BaseModel):
    id: str
    action: OperationAction
    message: str | None = None
```

~97% smaller than returning a full Issue object for write confirmations.

### 9.4 Blocked Issue

```python
class BlockedIssue(BaseModel):
    id: str
    title: str
    status: IssueStatus
    priority: int
    blocked_by: list[str]
    blocked_by_count: int
```

### 9.5 Stats

```python
class Stats(BaseModel):
    total: int
    open: int
    in_progress: int
    closed: int
    blocked: int
    ready: int
    avg_lead_time_hours: float
```

---

## 10. Error Handling Across Layers

### 10.1 BD CLI Errors

The CLI uses `FatalError()` and `FatalErrorRespectJSON()` for error reporting.
In JSON mode, errors are formatted as:

```json
{"error": "message", "code": "ERROR_CODE"}
```

Exit code 1 for all errors.

### 10.2 MCP Server Errors

The MCP server defines three error classes:

| Error | Meaning |
|-------|---------|
| `BdNotFoundError` | `bd` binary not found in PATH |
| `BdCommandError` | `bd` command returned non-zero exit code (includes stderr and returncode) |
| `BdVersionError` | `bd` CLI version is incompatible with MCP server |

### 10.3 Dependency Sanitization

The MCP server's `_sanitize_issue_deps()` function handles a schema mismatch:
`bd list/ready/blocked --json` returns raw dependency records
(`issue_id`, `depends_on_id`, `type`, `created_at`) but the pydantic `Issue`
model expects enriched `LinkedIssue` objects (`id`, `title`, `status`, etc.).
The sanitizer replaces raw records with empty lists while preserving counts.

---

## 11. Deployment Topology

### 11.1 Single Developer

```
IDE -> Claude Code Plugin -> bd prime / slash commands
                          -> MCP Server -> bd CLI -> embedded Dolt
```

### 11.2 Multi-Agent (Gas Town)

```
Agent 1 -> MCP Server 1 -> bd CLI -> Dolt SQL Server (shared)
Agent 2 -> MCP Server 2 -> bd CLI -> Dolt SQL Server (shared)
...
Agent N -> MCP Server N -> bd CLI -> Dolt SQL Server (shared)
```

All agents connect to the same Dolt SQL server. The server handles
concurrency. Each agent has its own MCP server instance but they all
shell out to `bd` which connects to the shared server.

### 11.3 Federated (Multi-Town)

```
Town A -> Dolt remote push/pull -> DoltHub
Town B -> Dolt remote push/pull -> DoltHub
```

Each town has its own Dolt database with full local autonomy. Changes
are synchronized via Dolt's push/pull mechanism through DoltHub or
direct peer-to-peer remotes.
