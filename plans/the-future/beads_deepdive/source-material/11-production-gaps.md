# 11 -- Production Gap Analysis

Part of the [Beads Deep Dive](00-INDEX.md) series.
Generated 2026-03-17 from steveyegge/beads v0.61.0.

---

## Overview

This document catalogs every gap between the current Beads implementation and
what Gas Town needs for production use with 20-30 concurrent agents. Each gap
includes a severity rating, root cause analysis, current state of any fix, the
residual exposure, and a concrete remediation path.

Severity scale:
- **CRITICAL** -- Blocks production deployment or causes data loss/corruption.
- **HIGH** -- Significant operational risk or missing capability.
- **MEDIUM** -- Friction or risk under specific conditions.
- **LOW** -- Polish, documentation, or minor inconsistency.

---

## CRITICAL -- Must Fix Before Production

### 1. Dolt Server Concurrency Under Load

**Severity: CRITICAL**

**What happened:** On 2026-02-23, the shared Dolt server became unresponsive
under approximately 20 concurrent agents. The server stopped accepting new
connections and existing transactions hung indefinitely.

**Root causes identified:**

1. **Redundant `tx.Commit()` after `DOLT_COMMIT()`:** The DoltStore was issuing
   a SQL transaction commit followed by a Dolt version-control commit in the
   same connection, creating unnecessary lock contention. The Dolt commit
   procedure already commits the SQL transaction internally.

2. **Shared server, many databases:** Approximately 15 databases were running on
   a single `dolt sql-server` instance. Each database maintains its own write
   lock and catalog metadata, multiplying the coordination overhead.

3. **Connection pool exhaustion:** Default `MaxOpenConns = 10` per DoltStore
   instance (see `store.go` line 197-199). With 15 databases, each potentially
   opened by multiple agents, the theoretical connection count reaches 200+
   against a single server with no documented `max_connections` tuning.

4. **`autocommit=false` in connection string:** Disabling autocommit forces
   every statement into an explicit transaction, increasing the window during
   which Dolt holds locks.

**Current fix:** The redundant `tx.Commit()` was removed. Dolt was upgraded
to a version with improved lock contention handling. A simplified reproduction
test was written but does NOT reproduce the issue under clean conditions --
meaning the failure requires real production conditions (multiple databases,
concurrent agents, mixed read/write workloads).

**Residual gap:**
- No connection pool tuning guidance exists. `max_connections`, `back_log`, and
  idle timeout settings for the Dolt server are undocumented for multi-project
  deployments.
- The circuit breaker (`store.go`, `breaker` field) provides fail-fast behavior
  but does not implement backpressure or connection limiting.
- No load testing has been performed under production-representative conditions
  (20+ agents, 10+ databases, mixed read/write).

**Remediation:**
1. Load test with production conditions: 20+ concurrent connections across 10+
   databases on a single Dolt server.
2. Document Dolt server tuning parameters (`max_connections`, `back_log`,
   `interactive_timeout`, `wait_timeout`) for Gas Town deployments.
3. Implement connection pool limits in the DoltStore wrapper layer. Consider a
   shared pool across all DoltStore instances connecting to the same server.
4. Add a queue/backpressure mechanism: when the pool is exhausted, queue
   requests rather than failing immediately.
5. Add OTel metrics for pool utilization: `bd.db.pool_active`, `bd.db.pool_idle`,
   `bd.db.pool_wait_ms`.

**Source:** `internal/storage/dolt/store.go` (lines 80-103, 197-199, 211-215),
`internal/doltserver/`.

---

### 2. MCP Multi-Repo Data Corruption Risk

**Severity: CRITICAL (P0/P1)**

**What happened:** The beads-mcp Python server uses `os.environ` mutations to
route `bd` CLI subprocess calls to the correct project workspace. However,
`os.environ` changes do not persist across FastMCP tool calls -- the MCP
protocol creates a fresh execution context for each tool invocation.

The consequence: write operations (create, update, close) can silently route to
the wrong project database when the MCP server handles multiple projects. An
agent working on Project A could write issues into Project B's database.

**Current fix (partial):** Three mitigations were implemented in
`integrations/beads-mcp/src/beads_mcp/server.py`:

1. **`_workspace_context` module-level dict** (line 78): A Python dict that
   persists across MCP tool calls within a single server process. Stores
   `BEADS_WORKING_DIR` and `BEADS_DB` values set by the `context()` tool.

2. **`@with_workspace` decorator** (line 169): Wraps all tool functions.
   Extracts `workspace_root` from tool call kwargs, falls back to the persistent
   `_workspace_context`, then to `os.environ`. Sets a `ContextVar` for the
   duration of each request.

3. **`BEADS_REQUIRE_CONTEXT=1` guard** (line 210-224): When enabled, write
   operations fail if no workspace context has been set. However, this guard is
   **opt-in and disabled by default** for backward compatibility.

**Residual gap:**
- Without `BEADS_REQUIRE_CONTEXT=1`, there is no enforcement. An agent that
  forgets to call `context(workspace_root='...')` will silently route writes
  to whatever workspace happens to be in the environment.
- The `_workspace_context` dict is global to the server process. If two
  concurrent tool calls for different projects race, the last `context()` call
  wins for both.
- `ContextVar` provides per-asyncio-task isolation, but this assumes FastMCP
  dispatches each tool call in a separate task. If tool calls are serialized
  on a single task, the isolation breaks.

**Remediation (choose one):**
1. **Enable `BEADS_REQUIRE_CONTEXT=1` by default.** This is the minimum viable
   fix. All write tools already have the `@with_workspace` decorator; making
   the guard mandatory prevents silent misrouting.
2. **Run a separate MCP server instance per project.** Eliminates the shared
   state problem entirely. Each server process has exactly one workspace.
3. **Fork beads-mcp with per-request workspace isolation.** Use asyncio
   `ContextVar` with a request-scoped workspace token. Require `workspace_root`
   as a mandatory parameter on every write tool, not just `context()`.

**Source:** `integrations/beads-mcp/src/beads_mcp/server.py` (lines 78,
169-224, 587-671).

---

### 3. No Encryption at Rest

**Severity: CRITICAL**

**What:** All data is stored as plain-text SQL in the Dolt database files under
`.beads/dolt/`. There is no built-in encryption, no access control layer, and
no audit logging beyond Dolt's version history.

**Current state:** The project documentation acknowledges this is "designed for
development/internal use." Security relies entirely on filesystem permissions
on the `.beads/` directory.

**Exposure:**
- Any process with filesystem read access to `.beads/dolt/` can read all issue
  data, including descriptions, comments, agent states, and metadata.
- Federation peer credentials are stored with AES encryption in the
  `federation_peers` metadata table, but the AES key is derived from a random
  `credentialKey` stored in the DoltStore struct (line 122 of `store.go`) --
  which is regenerated each session, meaning the encrypted credentials are only
  usable by the current process.
- No per-user or per-agent access control. The `actor` field in all Storage
  interface methods is a plain string -- no authentication, no authorization.
- Dolt's MySQL protocol connection defaults to `root` with no password
  (`ServerUser: "root"`, `ServerPassword: ""` in Config struct, lines 172-173).

**Remediation:**
1. Enable Dolt SQL server with password authentication (`--user` and
   `--password` flags on `dolt sql-server`).
2. Implement encryption at rest for the Dolt data directory (OS-level or
   Dolt-native if/when supported).
3. Build an RBAC model: map agent identities to roles with permissions on issue
   operations (read, write, admin).
4. Add structured audit logging beyond Dolt commit history: who accessed what,
   when, from where, and whether the access was authorized.

**Source:** `internal/storage/dolt/store.go` (lines 112-157, 159-200).

---

### 4. Federation Commands Require CGO Build

**Severity: CRITICAL for multi-town deployments**

**What:** The federation CLI commands (sync, status, add-peer, remove-peer,
list-peers) are fully implemented in `cmd/bd/federation.go`, but they are
guarded by a `//go:build cgo` build tag. The non-CGO build
(`cmd/bd/federation_nocgo.go`) provides only a stub that prints "Federation
requires CGO and Dolt backend."

The standard `brew install` and `npm install -g` distributions may or may not
include CGO builds depending on platform. Users who install via these channels
may find federation commands unavailable.

Additionally, the `FederationStore` interface (`internal/storage/federation.go`)
provides only four methods: `AddFederationPeer`, `GetFederationPeer`,
`ListFederationPeers`, and `RemoveFederationPeer`. The actual sync, push, and
pull operations are routed through the `SyncStore` and `RemoteStore`
interfaces, meaning the federation subsystem is spread across three interfaces
with no unified entry point.

**Residual gap:**
- The sync command works through `ds.Sync(ctx, peer, strategy)` which delegates
  to the `SyncStore` interface -- but testing of actual cross-town federation
  sync is minimal.
- Conflict resolution via `--strategy ours|theirs` is implemented but untested
  at scale.
- No automated federation sync (cron, daemon, or formula-driven).

**Remediation:**
1. Ensure official release binaries include CGO federation support (the
   GoReleaser workflow with zig cross-compilation should handle this).
2. Document which installation methods include federation.
3. Build integration tests for cross-town sync with real Dolt databases.
4. Implement a federation sync daemon (formula-driven, see Build Plan Phase 2b).
5. Add `bd federation push` and `bd federation pull` as explicit aliases for
   clarity.

**Source:** `cmd/bd/federation.go` (CGO build), `cmd/bd/federation_nocgo.go`
(stub), `internal/storage/federation.go` (interface).

---

## HIGH -- Should Fix

### 5. Witness System Immature

**Severity: HIGH**

**What:** Beads provides the raw primitives for agent health monitoring --
heartbeat fields (`last_activity`, `agent_state`) on agent beads, the `bd agent`
subcommand for managing agent state, and the `bd stale` command for detecting
idle agents. However, there is no built-in patrol loop, no automatic dead
detection, no recovery actions, and no escalation policies.

The Witness is entirely external: Gas Town's `gt` orchestrator is expected to
implement the patrol loop by periodically calling `bd stale` and acting on the
results.

**Gap:**
- No configurable heartbeat intervals (the interval is whatever the agent
  happens to write).
- No automatic dead detection threshold (must be configured externally).
- No built-in recovery actions (restart, reassign, escalate).
- No distributed witness (single point of failure if the patrol agent crashes).
- No health check protocol beyond activity timestamps.

**Remediation:**
1. Build a built-in Witness daemon with configurable intervals (default 30s
   heartbeat, 3 missed = dead).
2. Define recovery action chain: warn, restart agent session, reassign work to
   ready pool, alert human.
3. Package as a formula: `mol-witness-patrol.formula.toml`.
4. Support distributed witness (multiple patrol agents with leader election or
   sharded responsibility).

**Source:** `cmd/bd/agent.go`, `cmd/bd/stale.go`, `internal/types/types.go`
(agent state fields).

---

### 6. Error Handling Inconsistency

**Severity: HIGH**

**What:** The codebase uses three distinct error handling patterns, documented
in `docs/ERROR_HANDLING.md`:

| Pattern | Behavior | Used When |
|---------|----------|-----------|
| A: Exit immediately | `os.Exit(1)` | Fatal errors, validation failures |
| B: Warn and continue | `fmt.Fprintf(stderr)` + continue | Optional/auxiliary operations |
| C: Silent ignore | Error swallowed | "Best effort" cleanup paths |

The problem is inconsistent application. Some storage-layer errors are treated
as fatal in one command and silently ignored in another. The `docs/ERROR_HANDLING.md`
document acknowledges this and notes that a centralization audit was filed as
`bd-bwk2`.

**Gap:**
- Unpredictable failure modes: the same underlying error (e.g., Dolt lock
  contention) may cause an immediate exit in `bd create` but a silent
  continuation in `bd update`.
- No structured error types in the storage layer. Errors are plain
  `fmt.Errorf` wrappers with string matching for retry decisions (see
  `isRetryableError()` in `store.go`).
- The sentinel errors (`ErrAlreadyClaimed`, `ErrNotFound`, etc. in
  `storage.go`) cover only 4 cases.

**Remediation:**
1. Complete the `bd-bwk2` audit: categorize every error path in `cmd/bd/` by
   pattern and verify correctness.
2. Introduce structured error types in the storage layer (e.g.,
   `StorageError` with `Code`, `Retryable`, `Severity` fields).
3. Centralize CLI error handling: all commands should go through a single
   `handleError(err)` function that decides exit vs. warn vs. ignore based on
   error type.

**Source:** `docs/ERROR_HANDLING.md`, `internal/storage/storage.go` (lines 18-29),
`internal/storage/dolt/store.go` (`isRetryableError()`).

---

### 7. Cross-Project Dependencies Not Supported

**Severity: HIGH**

**What:** Each Beads database is isolated by design. The `dependencies` table
has no foreign key on `depends_on_id` specifically to allow the
`external:<rig>:<id>` soft reference format (documented in `schema.go`). However,
these references are purely informational -- there is no enforcement, no
cross-project blocking, and no cross-project `bd ready` resolution.

**Current state:** An issue in database A can declare `depends_on:
external:rig-b:gt-42`, but:
- `bd ready` in database A will not check whether `gt-42` is actually closed
  in database B.
- There is no command to resolve external references.
- The formula engine cannot express cross-project dependencies.

**Gap:** Gas Town convoys (cross-rig coordinated work) cannot use Beads
dependency tracking for inter-rig synchronization.

**Remediation:**
1. Implement federation-aware dependency resolution: when checking blockers,
   query peer databases for external reference status.
2. Add `bd dep check-external` command to validate external references.
3. Support cross-project blocking in `bd ready` via federation peers.
4. Add cross-project dependency types to the formula DSL.

**Source:** `internal/storage/dolt/schema.go` (line 93-94 comment about missing
FK), `internal/storage/dependency_queries.go`.

---

### 8. Dolt Phones Home by Default

**Severity: HIGH for security-conscious deployments**

**What:** Dolt contacts `doltremoteapi.dolthub.com` by default even when no
remotes are configured. This is Dolt's usage telemetry system. While it can be
disabled, the default is opt-in telemetry, which may violate security policies
in corporate or air-gapped environments.

**Opt-out methods:**
- `dolt config --global --add metrics.disabled true`
- Environment variable: `DOLT_DISABLE_EVENT_FLUSH=1`
- Environment variable: `DOLT_DISABLE_REFLINK_COPY=1` (separate but related)

**Gap:** Beads does not disable Dolt telemetry by default. No documentation
warns users about this behavior. Gas Town deployments handling sensitive project
data may inadvertently leak metadata to DoltHub servers.

**Remediation:**
1. Add `DOLT_DISABLE_EVENT_FLUSH=1` to the environment when Beads auto-starts
   a Dolt server (in `internal/doltserver/`).
2. Document the opt-out in `SECURITY.md` and `FEDERATION-SETUP.md`.
3. For Gas Town: set both variables in the shared Dolt server launch script.

---

### 9. ClaimIssue Not Implemented in Embedded Mode

**Severity: HIGH**

**What:** The `EmbeddedDoltStore` at
`internal/storage/embeddeddolt/store.go:483` implements `ClaimIssue` as:

```go
func (s *EmbeddedDoltStore) ClaimIssue(ctx context.Context, id string, actor string) error {
    panic("embeddeddolt: ClaimIssue not implemented")
}
```

This is a hard panic, not a graceful error. Any code path that reaches
`ClaimIssue` in embedded mode will crash the process.

The DoltStore (server mode) implementation at
`internal/storage/dolt/issues.go:260` uses a proper compare-and-swap pattern
with `WHERE assignee = '' OR assignee IS NULL` for atomic claiming. The
embedded store has no equivalent.

**Additional unimplemented methods in EmbeddedDoltStore** (same file, nearby
lines):
- `DeleteIssuesBySourceRepo` (line 475)
- `UpdateIssueID` (line 479)
- `PromoteFromEphemeral` (line 487)
- `RenameCounterPrefix` (line 493)

**Gap:** Cannot use atomic claiming, issue promotion, or bulk deletion in
embedded/test mode. Tests that exercise claiming logic must use a real Dolt
server, complicating CI.

**Remediation:**
1. Implement CAS claiming in embedded mode using the same SQL pattern as
   DoltStore.
2. Implement the remaining stubbed methods or formally deprecate embedded mode
   for production use.
3. At minimum, replace `panic()` with a proper error return
   (`errors.New("not implemented")`) to prevent process crashes.

**Source:** `internal/storage/embeddeddolt/store.go` (lines 475-494),
`internal/storage/dolt/issues.go` (lines 257-316).

---

## MEDIUM -- Nice to Have

### 10. No RBAC / Access Control

**Severity: MEDIUM**

**What:** The `actor` parameter on all Storage interface methods
(`CreateIssue`, `UpdateIssue`, `CloseIssue`, etc.) is a plain string with no
authentication or authorization. Any caller can pass any actor string. There is
no per-agent or per-role access control.

**Impact:** In a Gas Town deployment, any agent can read, modify, or delete any
issue regardless of its role. A Polecat (worker) agent could modify Mayor
(coordinator) issues. There is no way to restrict agents to their own scope.

**Remediation:**
1. Define a role model: admin, coordinator, worker, observer.
2. Map agent identities to roles via configuration.
3. Enforce permissions at the storage interface boundary.
4. Log authorization decisions for audit.

---

### 11. Counter-Mode ID Collisions on Parallel Branches

**Severity: MEDIUM**

**What:** The `issue_counter` table (`internal/storage/dolt/schema.go`, line
207) provides sequential IDs for projects that prefer `prefix-1`, `prefix-2`
style IDs over hash-based IDs. However, the counter is stored as a single row
in a SQL table, which means:

- Parallel Dolt branches can increment the counter independently, creating
  divergent ID sequences.
- After merging branches, the counter value may not reflect the highest issued
  ID, leading to potential ID reuse.
- There is no CLI command to inspect or reseed the counter.

**Impact:** Only affects projects using counter-mode IDs (not the default).
Hash-based IDs (the default) are collision-free by design.

**Remediation:**
1. Document the collision scenario in the counter-mode documentation.
2. Add `bd config seed-counter <value>` to manually reseed after branch merges.
3. Consider a max-of-branches strategy for counter resolution during merge.

---

### 12. Single-Level Redirects Only

**Severity: MEDIUM**

**What:** The `.beads/redirect` file system allows one level of indirection:
a project's `.beads/redirect` can point to a shared `.beads/` directory.
However, redirect chains (A's redirect points to B, B's redirect points to C)
are explicitly blocked.

The `FollowRedirect()` function in `internal/beads/beads.go` follows exactly
one redirect and stops.

**Impact:** Limits organizational flexibility. Some Gas Town configurations
might benefit from hierarchical redirect structures (e.g., team-level shared
databases that redirect to a town-level database).

**Remediation:**
1. Support multi-level redirects with cycle detection (max depth 5).
2. Or document the architectural reasoning for single-level-only: simplicity,
   debuggability, avoiding redirect loops.

---

### 13. No Gate Timeout Enforcement

**Severity: MEDIUM**

**What:** Gate issues have a `Timeout` field (`time.Duration` in
`internal/types/types.go`, line 99) that specifies the maximum wait time
before escalation. However, this field is purely informational -- neither the
storage layer nor any built-in daemon evaluates whether a gate has timed out.

The `bd gate check` command (if it existed) or `bd gate eval` must be called
explicitly to evaluate gate conditions. Timer-type gates are documented
("timer - Expires after timeout, Phase 2") but there is no enforcement loop.

The `bd gate list` command displays the timeout value (lines 142-146 of
`gate.go`), and `bd gate show` displays it (lines 260-262), but neither
takes action on expiration.

**Impact:** Gates with timeouts silently ignore their deadlines unless an
external process monitors them.

**Remediation:**
1. Build a gate evaluator daemon (see Build Plan Phase 2c).
2. Evaluate all gate types: timer (elapsed check), `gh:run` (API call to GitHub),
   `gh:pr` (API call to GitHub), bead (cross-rig status check).
3. Auto-close satisfied gates.
4. Escalate timed-out gates per configured policy.

**Source:** `internal/types/types.go` (lines 97-99), `cmd/bd/gate.go`.

---

### 14. FAQ Version Stale

**Severity: LOW**

**What:** `docs/FAQ.md` line 61 reads:

> Current status: Alpha (v0.9.11)

The actual current version is v0.61.0, approximately 50 major versions ahead.
This gives users a misleading impression of project maturity.

**Remediation:** Update `docs/FAQ.md` to reflect the current version.

**Source:** `docs/FAQ.md` (line 61).

---

## Feature Maturity Matrix

This matrix summarizes the production readiness of every major Beads subsystem.

| Feature | Status | Notes |
|---------|--------|-------|
| Core CRUD (create/read/update/close/delete) | Stable | Battle-tested with 20+ agents |
| Dependency graph (22 types, ready_issues view) | Stable | Kahn's topological sort, cycle detection |
| Hash-based collision-free IDs | Stable | Default mode, SHA-256 content hashing |
| Dolt embedded mode (auto-start server) | Stable | Reference-counted lifecycle management |
| Dolt server mode (single host, single project) | Stable | Recently hardened after concurrency incident |
| Shared Dolt server (multi-project) | Stable as of v0.60 | Requires tuning guidance for 10+ databases |
| Molecules / Wisps / Protos | Stable | Full chemistry metaphor, ephemeral routing |
| Formulas (TOML/JSON templates) | Functional | Less battle-tested than manual issue creation |
| MCP server (single repo) | Stable | FastMCP-based, full CRUD coverage |
| Claude Code plugin | Stable | 30+ slash commands |
| Linear / Jira / GitHub integrations | Functional | Import paths tested, ongoing maintenance |
| OpenTelemetry instrumentation | Functional | Opt-in, traces + metrics on storage layer |
| Go library API (beads.Storage interface) | Functional | Pre-1.0, interface may change |
| Federation add-peer | Functional | CGO-only, credential encryption |
| Federation sync / status | Functional | CGO-only, implemented but lightly tested |
| Federation push / pull (via Dolt remotes) | Functional | Delegates to RemoteStore/SyncStore interfaces |
| MCP multi-repo routing | Broken (P0/P1) | `_workspace_context` workaround, guard disabled by default |
| Embedded Dolt (in-process, no server) | In progress | 5+ methods panic with "not implemented" |
| Encryption at rest | Not implemented | Relies on filesystem permissions |
| RBAC / Access control | Not implemented | Actor is an unauthenticated string |
| Cross-project dependencies | Not supported | Soft references only, no enforcement |
| Gate timeout enforcement | Not implemented | Field exists, no evaluation loop |
| Distributed witness | Not implemented | Primitives exist, no built-in patrol |

---

## Risk Summary

**Deployment scenario: 30 concurrent agents across 5-10 projects on a shared
Dolt server.**

| Risk | Likelihood | Impact | Mitigation Available? |
|------|------------|--------|-----------------------|
| Dolt server unresponsive under load | Medium | Critical (all agents blocked) | Partial (fix applied, not load-tested) |
| MCP writes to wrong project | High (multi-repo) | Critical (data corruption) | Yes (enable BEADS_REQUIRE_CONTEXT=1) |
| Data readable by any local process | Certain | High (data leak) | No (must implement encryption) |
| Federation sync fails silently | Medium | High (towns diverge) | Partial (sync command exists, untested at scale) |
| Agent dies, no automatic recovery | High | Medium (work stalls) | No (must build witness) |
| Gate deadline missed | Medium | Medium (workflow stalls) | No (must build evaluator) |
| Counter ID collision after branch merge | Low | Medium (duplicate IDs) | Partial (use hash mode instead) |

---

## Prioritized Fix Order

If time is limited, fix in this order:

1. **Enable `BEADS_REQUIRE_CONTEXT=1` by default** in MCP server. (1 hour)
2. **Dolt server connection tuning** -- document and apply settings. (1 day)
3. **Load test** with production conditions. (2 days)
4. **Replace panics in EmbeddedDoltStore** with proper errors. (2 hours)
5. **Disable Dolt telemetry** in auto-start path. (30 minutes)
6. **Error handling audit** (`bd-bwk2`). (3-5 days)
7. **Gate evaluator daemon**. (1 week)
8. **Built-in Witness agent**. (1-2 weeks)
9. **Cross-project dependency resolution**. (2-3 weeks)
10. **Encryption at rest + RBAC**. (4-6 weeks)
