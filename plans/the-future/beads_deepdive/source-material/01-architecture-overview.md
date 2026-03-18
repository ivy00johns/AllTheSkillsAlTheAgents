# 01 -- Architecture Overview

Part of the [Beads Deep Dive](00-INDEX.md) series.
Generated 2026-03-17 from steveyegge/beads v0.61.0.

---

## Three-Layer Architecture

Beads is a vertically integrated system with three clean layers. Each layer
communicates with the one below it through a narrow interface.

```
Claude Code / MCP tools (Python)
    | subprocess (bd CLI invocations)
bd CLI (Cobra, Go)
    | Storage interface (11 sub-interfaces composed into DoltStorage)
internal/storage/dolt (DoltStore)
    | MySQL wire protocol (go-sql-driver/mysql, pure Go)
dolt sql-server (auto-started or external)
    | version-controlled SQL engine
.beads/dolt/ (on-disk Dolt database)
    | Dolt remotes (push/pull via remotesapi or git protocol)
DoltHub / S3 / GCS / filesystem (federation)
```

### Layer 1: Integration Layer (Python / TypeScript)

The top layer consists of tools that invoke `bd` as a subprocess:

| Component | Language | Location | Purpose |
|-----------|----------|----------|---------|
| beads-mcp | Python (FastMCP) | `integrations/beads-mcp/` | MCP server exposing bd operations as tools |
| claude-code plugin | TypeScript | `claude-plugin/` | 30+ slash commands for Claude Code |
| claude-code integration | Shell/YAML | `integrations/claude-code/` | Claude Code command definitions |
| junie integration | -- | `integrations/junie/` | JetBrains Junie integration |
| recipes | Go templates | `internal/recipes/` | AI tool integration recipes |

All integrations invoke the `bd` binary as a subprocess. There is no Go library
linkage from the integration layer -- the CLI is the contract.

### Layer 2: CLI Layer (Go / Cobra)

The middle layer is a Cobra CLI application with 120+ commands spread across
~329 `.go` files in `cmd/bd/`. The CLI handles:

- Command parsing and routing
- Store lifecycle (open, auto-start, close)
- Actor identity resolution
- Persistent pre-run and post-run hooks (auto-commit, telemetry, tips)
- Signal handling and graceful shutdown

Key architectural detail: the CLI uses **PersistentPreRunE** on the root command
to open the database store, and **PersistentPostRun** to close it. Commands that
only read data open the store in read-only mode (defined in the `readOnlyCommands`
map in `cmd/bd/main.go`).

### Layer 3: Storage Layer (Go / Dolt)

The bottom layer is the `DoltStore` implementation in `internal/storage/dolt/`.
It connects to a `dolt sql-server` via the MySQL wire protocol (pure Go, no CGO
required) and manages:

- Schema initialization and migrations (11 numbered migrations)
- Issue CRUD with wisp routing (ephemeral vs. persistent)
- Dependency graph operations
- Version control (commit, push, pull, merge)
- Federation (peer-to-peer sync)
- Circuit breaker and retry logic for transient failures
- Connection pooling and transaction management

---

## Three Execution Modes

The system supports three modes of operation, configured via `metadata.json`
and environment variables.

### Mode 1: Embedded (Auto-Start)

The default for standalone users. When `bd` cannot connect to a Dolt server,
it automatically starts one.

```
bd CLI --> DoltStore.New() --> TCP connect fails --> doltserver.EnsureRunning()
    --> starts `dolt sql-server` as subprocess
    --> writes PID file and port file to .beads/
    --> retries TCP connect --> success
```

Auto-start behavior is controlled by a priority chain (highest wins):

| Priority | Source | Effect |
|----------|--------|--------|
| 1 | `BEADS_TEST_MODE=1` | Always disable auto-start |
| 2 | `BEADS_DOLT_AUTO_START=0` | Always disable auto-start |
| 3 | `metadata.json` has explicit `dolt_server_port` | Disable (prevents shadow databases) |
| 4 | Caller sets `Config.AutoStart = true` | Enable |
| 5 | `config.yaml` `dolt.auto-start: false` | Disable |
| 6 | Default | Enable (standalone user) |

Source: `internal/storage/dolt/open.go`, `resolveAutoStart()`.

Reference counting (`autoStartRefs` in `store.go`) ensures the server is stopped
only when the last `DoltStore` referencing it is closed.

### Mode 2: External Server

For shared or remote Dolt servers. The user runs `dolt sql-server` externally
and configures `metadata.json`:

```json
{
  "dolt_mode": "server",
  "dolt_server_host": "127.0.0.1",
  "dolt_server_port": 3307,
  "dolt_server_user": "root",
  "dolt_database": "beads"
}
```

Auto-start is suppressed when an explicit port is configured.

### Mode 3: Shared Server (Gas Town / Multi-Project)

Gas Town manages a single `dolt sql-server` that serves multiple project
databases. Each project (rig) has its own database name derived from the
issue prefix (e.g., `beads_gt` for prefix `gt-`).

```
Gas Town (gt)
    |
    +--> Rig 1: .beads/metadata.json --> dolt_database: "beads_rig1"
    +--> Rig 2: .beads/metadata.json --> dolt_database: "beads_rig2"
    +--> Rig 3: .beads/redirect --> points to shared .beads/
```

Gas Town sets `GT_ROOT` in the environment, which disables auto-start.

---

## Storage Interface Architecture

The storage layer uses interface segregation. The base `Storage` interface
provides core CRUD operations. The full `DoltStorage` interface composes
11 sub-interfaces:

```go
// From internal/storage/storage.go
type DoltStorage interface {
    Storage              // Core CRUD, dependencies, labels, work queries, comments, events, stats, config, transactions, lifecycle
    VersionControl       // Commit, branch, merge, diff, log
    HistoryViewer        // Time-travel queries (AS OF, dolt_history_*)
    RemoteStore          // Push, pull, fetch, remote management
    SyncStore            // Git-to-Dolt sync operations
    FederationStore      // Peer-to-peer push/pull with credential management
    BulkIssueStore       // Batch import/export operations
    DependencyQueryStore // Advanced dependency graph queries
    AnnotationStore      // Issue annotations (labels, comments) bulk ops
    ConfigMetadataStore  // Config and metadata key-value stores
    CompactionStore      // AI-powered compaction operations
    AdvancedQueryStore   // Complex filtered queries, stale detection
}
```

Additional interfaces are available via type assertion:

| Interface | Purpose |
|-----------|---------|
| `RawDBAccessor` | Direct `*sql.DB` access for diagnostics and migrations |
| `StoreLocator` | Filesystem path information (`.beads/` and `.beads/dolt/`) |
| `LifecycleManager` | Check if store is closed |
| `PendingCommitter` | Commit dirty (uncommitted) changes |

Source: `internal/storage/storage.go`.

---

## Ten Key Design Decisions

### 1. Single Wide `issues` Table (~50 columns)

All issue variants -- tasks, bugs, epics, molecules, agents, gates, events,
messages -- share one table with sparse columns. A task uses `title`, `description`,
`status`, `priority`. An agent bead uses `hook_bead`, `role_bead`, `agent_state`,
`last_activity`. A gate uses `await_type`, `await_id`, `timeout_ns`, `waiters`.

**Rationale:** Avoids joins, simplifies the schema, enables uniform queries across
all issue types. The `ready_issues` view works identically for tasks, molecules,
and agent work items.

**Trade-off:** ~30 columns are NULL/empty for any given issue. At the scale beads
operates (thousands of issues, not millions), this is acceptable.

### 2. Dolt as Version Control for SQL

Every write operation becomes a versioned Dolt commit. This gives beads:
- **Time-travel queries** via `AS OF` and `dolt_history_*` system tables
- **Branch and merge** for experimentation and conflict resolution
- **Federation** via Dolt remotes without building a separate sync protocol
- **Audit trail** for free (every change is a commit with author and message)

**Rationale:** Using Dolt eliminates the need for a separate sync protocol,
separate audit log, and separate versioning system. One database does all three.

### 3. Auto-Start Server Management

Transparent to users. When `bd` cannot reach a Dolt server, it starts one
automatically, writes PID and port files, and manages lifecycle via reference
counting.

**Rationale:** Zero-configuration experience for standalone users. No need to
run `dolt sql-server` manually.

**Guard rails:** Test mode forces port 1 (immediate fail) to prevent test
databases leaking onto production. Explicit port configuration suppresses
auto-start to prevent shadow databases.

Source: `internal/storage/dolt/store.go` (lines 80-103, 637-698),
`internal/doltserver/`.

### 4. Interface Segregation (11 Sub-Interfaces)

The `DoltStorage` interface is composed of 11 focused sub-interfaces. Components
depend only on the operations they need.

**Rationale:** CLI commands that only read data can depend on `Storage` alone.
Federation code depends on `FederationStore`. Compaction depends on `CompactionStore`.
This makes testing easier and dependencies explicit.

### 5. Redirect Files for Shared Databases

A `.beads/redirect` file (plain text containing a path) lets crew directories
point at a shared `.beads/` directory. This avoids symlinks, which interact
poorly with Git and many tools.

```
project-a/.beads/redirect  -->  "../shared/.beads"
project-b/.beads/redirect  -->  "../shared/.beads"
shared/.beads/dolt/         -->  actual Dolt database
```

The redirect system preserves the source directory's `dolt_database` name via
`SourceDatabaseInfo` to prevent identity loss when the redirect target serves
multiple databases.

Source: `internal/beads/beads.go`, `ResolveRedirect()`, `FollowRedirect()`.

### 6. Content Hashing for Deduplication

`ComputeContentHash()` on the `Issue` struct produces a deterministic SHA-256
hash of all substantive fields (excluding ID, timestamps, and compaction metadata).
Identical content produces identical hashes across all clones.

**Rationale:** Enables deduplication during federation sync. Two Gas Towns that
independently create the same issue (e.g., from the same formula) can detect
the duplicate via content hash.

Source: `internal/types/types.go`, lines 133-211.

### 7. Hash-Based IDs for Distributed Generation

Issue IDs are generated locally without central coordination. The default mode
uses a hash-based scheme: `<prefix>-<short-hash>` (e.g., `bd-x8f2k`). An
alternative counter mode (`issue_counter` table) provides sequential IDs for
projects that prefer them.

**Rationale:** Collision-free in practice for the scale beads operates at.
No need for a central ID authority, which would be a single point of failure
in a federated system.

### 8. No Foreign Key on `depends_on_id`

The `dependencies` table has a foreign key on `issue_id` (must reference
`issues.id`) but deliberately omits a foreign key on `depends_on_id`.

**Rationale:** Cross-rig references use the format `external:<rig>:<id>`.
These reference issues in another Gas Town's database. A foreign key would
prevent storing these references.

Source: `internal/storage/dolt/schema.go`, line 93-94 comment.

### 9. Wisp/Issues Split

Ephemeral beads (wisps) are stored in a `wisps` table that mirrors the `issues`
table schema exactly. The `wisps` table is registered in Dolt's `dolt_ignore`
system table, so it is never committed to version history.

**Rationale:** Wisps are high-churn data (heartbeats, pings, patrol reports)
that would bloat Dolt's commit history. Separating them keeps history clean
while using the same query and mutation paths.

The routing decision is made at write time: if `issue.Ephemeral == true`, the
issue goes to the `wisps` table. Reads check both tables transparently.

Source: `internal/storage/dolt/wisps.go`, `internal/storage/dolt/migrations/004_wisps_table.go`.

### 10. UUID Primary Keys for Federation

The `comments`, `events`, `issue_snapshots`, and `compaction_snapshots` tables
use UUID primary keys (`CHAR(36) DEFAULT (UUID())`). The `issues` table uses
string IDs with project-specific prefixes.

**Rationale:** UUIDs prevent primary key collisions when merging data from
multiple Gas Towns during federation sync. Issue IDs use prefixes instead
because they need to be human-readable and project-scoped.

Source: `internal/storage/dolt/schema.go`, `internal/storage/dolt/migrations/010_uuid_primary_keys.go`.

---

## File Organization

```
beads/
|-- beads.go                    # Public API (thin re-export layer)
|-- beads_test.go               # Public API tests
|-- cmd/bd/                     # CLI application (~329 .go files)
|   |-- main.go                 # Root command, persistent lifecycle hooks
|   |-- create.go               # Issue creation with routing
|   |-- ready.go                # Blocker-aware work queries
|   |-- close.go                # Gate satisfaction, epic guards
|   |-- show.go                 # Issue display with formatting
|   |-- update.go               # Field updates
|   |-- agent.go                # Agent bead management
|   |-- swarm.go                # Swarm coordination
|   |-- compact.go              # AI-powered compaction
|   |-- version.go              # Version reporting (v0.61.0)
|   |-- vc.go                   # Version control commands (commit, push, pull)
|   |-- backup.go               # Backup and restore
|   |-- federation.go           # Federation commands (peer add/remove/sync)
|   |-- wisp.go                 # Ephemeral bead creation
|   |-- slot.go                 # Exclusive access primitives
|   |-- doctor/                 # Diagnostic and repair tools
|   |-- protocol/               # Protocol definitions
|   |-- setup/                  # First-run setup
|   `-- ...
|-- internal/
|   |-- types/types.go          # All data structures (Issue, Dependency, etc.)
|   |-- storage/
|   |   |-- storage.go          # Storage + DoltStorage interfaces (11 sub-interfaces)
|   |   `-- dolt/
|   |       |-- schema.go       # Complete SQL DDL, views, defaults (schema version 8)
|   |       |-- store.go        # DoltStore struct, New(), retry, circuit breaker
|   |       |-- open.go         # Config resolution, auto-start logic
|   |       |-- issues.go       # Issue CRUD with wisp routing
|   |       |-- dependencies.go # Dependency graph operations
|   |       |-- federation.go   # Push/pull/fetch between peers
|   |       |-- wisps.go        # Wisp table routing helpers
|   |       `-- migrations/     # 11 numbered migrations (001-011)
|   |-- beads/beads.go          # Database discovery, redirect resolution
|   |-- doltserver/             # Server lifecycle (Start/Stop/EnsureRunning)
|   |-- formula/                # Formula DSL parser, compiler, control flow
|   |-- molecules/              # Template molecule loader
|   |-- compact/                # AI-powered compaction engine
|   |-- routing/                # User role detection, issue routing
|   |-- config/                 # Viper config management
|   |-- configfile/             # metadata.json schema and I/O
|   |-- recipes/                # AI tool integration recipes
|   |-- hooks/                  # Git hook system
|   |-- audit/                  # Interaction logging
|   |-- idgen/                  # ID generation (hash and counter modes)
|   |-- query/                  # Advanced query building
|   |-- templates/              # Issue templates
|   |-- validation/             # Input validation
|   |-- ui/                     # Terminal UI helpers
|   |-- utils/                  # Shared utilities
|   |-- git/                    # Git integration
|   |-- github/                 # GitHub integration
|   |-- gitlab/                 # GitLab integration
|   |-- jira/                   # Jira import
|   |-- linear/                 # Linear import
|   |-- tracker/                # Pivotal Tracker import
|   |-- telemetry/              # OpenTelemetry instrumentation
|   |-- timeparsing/            # Natural language time parsing
|   |-- lockfile/               # File-based locking
|   |-- debug/                  # Debug utilities
|   `-- testutil/               # Test helpers
|-- integrations/
|   |-- beads-mcp/              # Python MCP server (FastMCP)
|   |-- claude-code/            # Claude Code integration commands
|   `-- junie/                  # JetBrains Junie integration
|-- claude-plugin/              # Claude Code plugin
|   |-- agents/                 # Agent definitions
|   |-- commands/               # Slash command definitions
|   `-- skills/                 # Skill definitions
|-- examples/                   # Usage examples
|-- docs/                       # 50+ documentation files
|-- scripts/                    # Build and release scripts
|-- tests/                      # Integration and script tests
`-- website/                    # Documentation website
```

---

## Data Lifecycle

An issue progresses through a defined lifecycle, with Dolt providing
version control at each stage.

```
CREATE --> LIVE --> CLOSE --> DECAY --> COMPACT --> FLATTEN
  |         |        |         |         |           |
  Dolt    active    done     DELETE   AI-SUMMARIZE  SQUASH
  commit   work     bead     rows     via Claude    all history
                            >30d     to 3-section   to 1 commit
                                     summary
```

### Stage 1: CREATE

A new issue is created via `bd create` or the integration layer. The storage
layer generates an ID, computes a content hash, inserts the row, and creates
a Dolt commit.

### Stage 2: LIVE

The issue is actively worked. Status transitions between `open`, `in_progress`,
`blocked`, `hooked` (attached to an agent), and `deferred`. Each mutation
creates a Dolt commit with an event in the `events` table.

### Stage 3: CLOSE

The issue is closed via `bd close`. The `closed_at` timestamp is set, the
`close_reason` is recorded, and the `closed_by_session` tracks which Claude
Code session closed it. Epic issues have a guard: they cannot be closed until
all children are closed.

### Stage 4: DECAY

After a configurable retention period (default: 30 days for tier 1), closed
issues become candidates for compaction. The `compact_tier1_days` config
controls this threshold.

### Stage 5: COMPACT

AI-powered compaction (`internal/compact/`) uses Claude to summarize the
issue's full history into a three-section summary: what was done, what was
learned, and what to remember. The original content is archived in
`compaction_snapshots`. The `compaction_level` field tracks how many times
an issue has been compacted.

### Stage 6: FLATTEN

For mature issues (tier 2, default: 90 days), Dolt's version history can be
squashed to a single commit to reclaim storage space. The
`compact_tier2_commits` config controls the commit threshold.

---

## Transaction and Concurrency Model

### Transactions

The `RunInTransaction` method provides atomic multi-operation support:

```go
store.RunInTransaction(ctx, "bd: create parent and child", func(tx Transaction) error {
    tx.CreateIssue(ctx, parent, actor)   // all-or-nothing
    tx.CreateIssue(ctx, child, actor)    // rolls back on error
    tx.AddDependency(ctx, dep, actor)    // committed together
    return nil
})
```

Each transaction maps to a SQL `BEGIN`/`COMMIT` pair on the Dolt server.
The Dolt commit (version control commit) happens after the SQL transaction
commits successfully.

### Retry with Exponential Backoff

All SQL operations are wrapped in `withRetry()`, which retries transient
errors using exponential backoff (max 30 seconds). Retryable errors include:

| Error Pattern | Cause |
|--------------|-------|
| `driver: bad connection` | MySQL connection pool stale entry |
| `invalid connection` | Connection invalidated |
| `broken pipe` | Network interruption |
| `connection reset` | TCP reset |
| `connection refused` | Server briefly unavailable |
| `database is read only` | Dolt under load |
| `lost connection` | Mid-query disconnect (MySQL 2013) |
| `gone away` | Idle connection timeout (MySQL 2006) |
| `i/o timeout` | Network timeout |
| `unknown database` | Dolt catalog race after CREATE DATABASE |
| `no root value found` | Dolt internal race after CREATE DATABASE |

Source: `internal/storage/dolt/store.go`, `isRetryableError()`.

### Circuit Breaker

A circuit breaker (`store.go`, `breaker` field) provides fail-fast behavior
when the Dolt server is known to be down. The breaker:

1. Tracks connection-level failures and successes
2. Trips open after repeated failures
3. Rejects requests immediately when open (`ErrCircuitOpen`)
4. Resets on successful operations

OTel metrics track breaker behavior: `bd.db.circuit_trips` and
`bd.db.circuit_rejected`.

### Lock Error Handling

Dolt lock contention errors (`database is locked`, `lock file`, `noms lock`)
are detected and wrapped with actionable guidance directing users to restart
the Dolt server or run `bd doctor --fix`.

Source: `internal/storage/dolt/store.go`, `isLockError()`, `wrapLockError()`.

---

## Configuration System

Configuration is layered with clear precedence:

| Priority | Source | Example |
|----------|--------|---------|
| 1 (highest) | Environment variables | `BEADS_DOLT_SERVER_PORT=3307` |
| 2 | CLI flags | `--json`, `--verbose` |
| 3 | Project config.yaml | `.beads/config.yaml` via Viper |
| 4 | Project metadata.json | `.beads/metadata.json` (schema: `configfile.Config`) |
| 5 (lowest) | Compiled defaults | `DefaultSQLPort = 3307`, `DefaultDoltDatabase = "beads"` |

The `configfile.Config` struct (`internal/configfile/configfile.go`) defines
the `metadata.json` schema with fields for database name, Dolt connection
mode, server host/port/user, TLS, data directory, project ID, and more.

The Viper-based config system (`internal/config/`) provides `config.yaml`
support for user preferences like `dolt.auto-start`, sort policies, and
display options.

---

## Observability

Beads instruments the storage layer with OpenTelemetry:

| Instrument | Type | Description |
|-----------|------|-------------|
| `bd.db.retry_count` | Counter | SQL operations retried due to transient errors |
| `bd.db.lock_wait_ms` | Histogram | Time spent waiting for Dolt access lock |
| `bd.db.circuit_trips` | Counter | Circuit breaker trip events |
| `bd.db.circuit_rejected` | Counter | Requests rejected by open circuit breaker |

Every SQL operation (`execContext`, `queryContext`, `queryRowContext`) creates
an OTel span under the `github.com/steveyegge/beads/storage/dolt` tracer.
Span attributes include `db.system=dolt`, `db.readonly`, `db.server_mode`,
`db.operation`, and a truncated `db.statement` (max 300 chars).

The telemetry system is initialized via `internal/telemetry/` and uses the
global OTel delegating provider pattern -- instruments are registered at init
time and forward to the real provider once `telemetry.Init()` runs.

Source: `internal/storage/dolt/store.go`, lines 346-398.

---

## Test Architecture

### Test Database Isolation

A pattern-based firewall prevents test databases from reaching production:

```go
var testDatabasePrefixes = []string{
    "testdb_", "beads_test", "beads_pt", "beads_vr", "doctest_", "doctortest_",
}
```

In `BEADS_TEST_MODE=1`:
- Auto-start is disabled
- Port is forced to 1 (immediate fail) if it would hit DefaultSQLPort (3307)
- Database names are derived from path hashes for isolation
- A hard panic fires if a test tries to connect to the production port

Source: `internal/storage/dolt/store.go`, lines 48-69, 615-655.

### Connection Pool

Default pool size: 10 connections (`MaxOpenConns`). Tests can set `MaxOpenConns=1`
for branch isolation (Dolt's `DOLT_CHECKOUT` is session-level, so branch changes
on one connection should not affect others).
