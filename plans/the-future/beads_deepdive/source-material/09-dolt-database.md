# 09 -- Dolt Database Reference

Part of the [Beads Deep Dive](00-INDEX.md) series.
Generated 2026-03-17 from steveyegge/beads v0.61.0.

---

## What Dolt Is

Dolt is "Git for data" -- a MySQL-compatible relational database with built-in
version control. Every table mutation can be committed to an immutable DAG of
content-addressed snapshots, giving the database a complete audit trail, branch
and merge semantics, and distributed replication via push/pull -- all using the
same mental model as Git, but for SQL data.

Standard MySQL client drivers connect over the wire protocol, meaning any
language with a MySQL library can talk to Dolt without modification. Beads uses
the pure-Go `go-sql-driver/mysql` package (no CGO required).

---

## Architecture

### On-Disk Layout

```
.beads/dolt/                     # Server root (dbPath)
    .dolt/                       # Server-level Dolt metadata
    <database>/                  # One directory per database
        .dolt/
            noms/                # Content-addressed chunk store
                LOCK             # File-level lock (stale after crash)
                manifest         # Root of the chunk tree
                ...chunks...
            config               # CLI remote config (survives server restart)
        ...working-copy tables...
```

Content is stored as content-addressed chunks in the `noms/` directory. Each
Dolt commit records a root hash pointing into this chunk store. Parent pointers
form an immutable directed acyclic graph (DAG), exactly like Git's commit graph
but for table data.

### SQL Engine

Dolt embeds `go-mysql-server`, an open-source MySQL-compatible SQL engine
written in Go. This engine implements:

- Standard SQL parsing and execution (SELECT, INSERT, UPDATE, DELETE)
- Transaction isolation via MVCC (multi-version concurrency control)
- MySQL wire protocol server (`dolt sql-server`)
- Dolt-specific stored procedures (DOLT_COMMIT, DOLT_PUSH, etc.)
- Dolt-specific system tables (`dolt_log`, `dolt_diff`, `dolt_branches`, etc.)

### Deployment Modes

Dolt supports two deployment modes:

| Mode | Writer Model | Connection | Use Case |
|------|-------------|------------|----------|
| Server | Multi-writer via MySQL protocol | TCP (go-sql-driver/mysql) | Production, Gas Town |
| Embedded | Single-writer, file-level locking | In-process (no CGO in beads) | Legacy, not used by beads |

**Beads uses server mode exclusively.** All code paths go through
`dolt sql-server`. The embedded mode (direct file access) was removed from
beads as of the server-only refactor. The `New()` constructor in
`internal/storage/dolt/store.go` always calls `newServerMode()`.

---

## Concurrency Model

Dolt's concurrency model operates at two layers, each with distinct semantics.

### Layer 1: SQL Transactions (MVCC)

Within a single `dolt sql-server`, SQL transactions use multi-version
concurrency control with **cell-level three-way merge**. This is the most
important characteristic for understanding beads' multi-agent architecture.

**Cell-level merge** means that Dolt tracks changes at the granularity of
individual cells (row + column intersections), not entire rows. When two
concurrent transactions modify the same row:

- If they touch **different columns**: the changes auto-merge cleanly. Agent A
  can update `status` while Agent B updates `description` on the same issue,
  and both writes succeed.

- If they touch the **same column**: the last writer wins. Dolt raises MySQL
  Error 1213 (serialization failure / deadlock detected). The losing
  transaction must retry.

This cell-level granularity is dramatically more permissive than row-level
locking. In practice, it means that dozens of agents can work on different
fields of overlapping issue sets without conflicts.

### Layer 2: Commit Graph (Global Lock)

`CALL DOLT_COMMIT()` acquires a global lock to update the commit DAG. This
lock is brief (milliseconds) and serializes only the act of creating a new
commit node in the DAG -- the actual data writes happen during the SQL
transaction, not during commit. At hundreds of operations per second, this
lock is not a practical bottleneck.

### The Beads Pattern: All-On-Main

Beads uses a single-branch, all-agents-on-main pattern. Every agent writes
directly to the `main` branch using explicit transaction discipline:

```
BEGIN
  INSERT/UPDATE/DELETE (working set changes)
COMMIT (SQL transaction -- makes changes durable)
CALL DOLT_ADD(<specific tables>)
CALL DOLT_COMMIT('-m', message, '--author', author)
```

This is implemented in `runDoltTransaction()` in
`internal/storage/dolt/transaction.go`. The key sequence is:

1. `BEGIN` -- start SQL transaction
2. Execute all writes within the transaction
3. `sqlTx.Commit()` -- commit the SQL transaction (makes changes visible)
4. `CALL DOLT_ADD(table)` -- stage only the tables modified in this transaction
5. `CALL DOLT_COMMIT('-m', ...)` -- create a versioned commit

**Critical: Do NOT call `tx.Commit()` after `DOLT_COMMIT()`.** The 2026-02-23
production incident (see below) was caused in part by a redundant `tx.Commit()`
after `DOLT_COMMIT()` that left the connection in a broken state.

Source: `internal/storage/dolt/transaction.go`, `runDoltTransaction()`.

---

## Cell-Level Merge: Detailed Semantics

Consider two agents working concurrently on issue `bd-abc`:

| Agent A | Agent B | Result |
|---------|---------|--------|
| Updates `status` to `in_progress` | Updates `description` to new text | Both succeed (different cells) |
| Updates `status` to `in_progress` | Updates `status` to `blocked` | Conflict -- Error 1213, retry required |
| Updates `priority` to 1 | Creates new issue `bd-xyz` | Both succeed (different rows) |
| Inserts dependency A->B | Inserts dependency C->D | Both succeed (different rows) |
| Inserts dependency A->B | Inserts dependency A->B | Idempotent check in beads code |

For metadata tables (`config`, `metadata`), conflicts are more common because
many operations touch the same keys. Beads handles metadata merge conflicts
during federation with an automatic "theirs" resolution strategy (GH#2466).

---

## Stored Procedures

Dolt exposes version control operations as MySQL stored procedures. These are
the primary interface between beads and Dolt's version control layer.

### Core Version Control

| Procedure | Signature | Purpose |
|-----------|-----------|---------|
| `DOLT_COMMIT` | `CALL DOLT_COMMIT('-m', msg, '--author', author)` | Create a versioned commit from staged changes |
| `DOLT_ADD` | `CALL DOLT_ADD(table_name)` | Stage a specific table for commit |
| `DOLT_PUSH` | `CALL DOLT_PUSH(remote, branch)` | Push commits to a remote |
| `DOLT_PULL` | `CALL DOLT_PULL(remote)` | Pull and merge from a remote |
| `DOLT_FETCH` | `CALL DOLT_FETCH(remote)` | Fetch refs without merging |
| `DOLT_MERGE` | `CALL DOLT_MERGE(branch)` | Three-way merge of a branch |

### Branch and Remote Management

| Procedure | Signature | Purpose |
|-----------|-----------|---------|
| `DOLT_BRANCH` | `CALL DOLT_BRANCH(name)` | Create a new branch |
| `DOLT_CHECKOUT` | `CALL DOLT_CHECKOUT(branch)` | Switch branches (session-level) |
| `DOLT_REMOTE` | `CALL DOLT_REMOTE('add', name, url)` | Add a remote |
| `DOLT_REMOTE` | `CALL DOLT_REMOTE('remove', name)` | Remove a remote |
| `DOLT_CONFLICTS_RESOLVE` | `CALL DOLT_CONFLICTS_RESOLVE('--theirs', table)` | Auto-resolve merge conflicts |

### Utility

| Procedure | Signature | Purpose |
|-----------|-----------|---------|
| `DOLT_HASHOF` | `SELECT DOLT_HASHOF('HEAD')` | Get commit hash for a ref |

### System Tables

| Table | Purpose |
|-------|---------|
| `dolt_log` | Commit history (hash, author, date, message) |
| `dolt_branches` | Branch names |
| `dolt_remotes` | Remote names and URLs (in-memory, lost on restart) |
| `dolt_diff(from, to, table)` | Table function returning cell-level diffs |
| `dolt_history_<table>` | All historical versions of a table |
| `dolt_status` | Uncommitted changes |
| `dolt_conflicts` | Active merge conflicts |

### Important Behavioral Notes

- `DOLT_CHECKOUT` is **session-level**: it changes the branch for the current
  MySQL connection only. This is why beads sets `MaxOpenConns=1` in tests
  that use branch isolation.

- `dolt_remotes` is **in-memory**: its contents are lost when the server
  restarts. Beads calls `syncCLIRemotesToSQL()` on store open to re-register
  CLI-level remotes (persisted in `.dolt/config`) into the SQL server.

- `DOLT_COMMIT` with `-A` (add-all) stages everything in the working set,
  which can sweep up stale changes from other connections. Beads uses
  explicit `DOLT_ADD(table)` for only the modified tables (GH#2455).

---

## MySQL Compatibility

### Supported Features

Dolt supports the vast majority of MySQL's SQL surface:

- **DDL**: CREATE TABLE, ALTER TABLE, DROP TABLE, CREATE INDEX, CREATE VIEW
- **DML**: SELECT, INSERT, UPDATE, DELETE, REPLACE, INSERT ON DUPLICATE KEY
- **Transactions**: BEGIN, COMMIT, ROLLBACK, SAVEPOINT
- **Indexes**: B-tree indexes, compound indexes, unique constraints
- **Views**: CREATE VIEW, CREATE OR REPLACE VIEW (used by `ready_issues`, `blocked_issues`)
- **Recursive CTEs**: WITH RECURSIVE (used by `ready_issues` view for transitive blocking)
- **JSON**: JSON column type, JSON_EXTRACT, JSON_UNQUOTE, JSON_OBJECT
- **Time travel**: `SELECT ... AS OF 'commit-hash'` (unique to Dolt)
- **Stored procedures**: Dolt-specific (DOLT_COMMIT, etc.)
- **Information schema**: INFORMATION_SCHEMA.COLUMNS, TABLES, etc.
- **Auto-increment**: Supported but not used by beads (uses hash-based or counter IDs)

### Not Supported (or Limited)

| Feature | Status | Beads Impact |
|---------|--------|-------------|
| Foreign key enforcement | Supported but beads omits FK on `depends_on_id` intentionally | App-level enforcement for cross-rig references |
| FULLTEXT indexes | Not supported | Text search uses `LIKE '%pattern%'` |
| Table partitioning | Not supported | Not needed at beads scale |
| Window functions | Limited support | Not used by beads |
| Generated columns | Not supported | Not used |
| Distributed transactions (XA) | Not supported | Single-server model |
| Triggers | Partial support | Not used |

### Known Dolt Query Engine Bugs (Relevant to Beads)

- **mergeJoinIter panic** (`go-mysql-server#3413`): Three-table JOINs can
  trigger a panic in Dolt's join iterator. Beads works around this by using
  LEFT JOIN + IS NULL instead of NOT EXISTS, and subqueries instead of
  multi-table JOINs in the `ready_issues` and `blocked_issues` views.

---

## Performance Profile

### Benchmark Data

From `internal/storage/dolt/dolt_benchmark_test.go` and production telemetry:

| Operation | Scale | Approximate Latency |
|-----------|-------|-------------------|
| GetReadyWork | 10K issues with dependencies | ~30ms |
| CreateIssue (single) | With DOLT_COMMIT | ~2.5ms |
| GetIssue (warm cache) | Single row lookup | <1ms |
| SearchIssues | 100 issues, text match | ~5ms |
| Cycle detection | 5K dependency edges | ~70ms |
| BulkCreateIssues | 100 issues in transaction | ~50ms |
| Commit (DOLT_COMMIT) | Per-commit overhead | ~1-2ms |
| Log (dolt_log) | 20 commits | ~2ms |

### Throughput

| Metric | Value | Notes |
|--------|-------|-------|
| Write throughput (single branch) | Hundreds tx/sec | Cell-level merge enables this |
| Beads actual write rate | ~20 writes/sec | 20x headroom vs. capacity |
| Concurrent reads | Linear scaling with pool size | Default pool: 10 connections |
| Push/pull | Network-bound | ~1-10 Mbps depending on remote backend |

### Connection Pool

Default configuration: `MaxOpenConns = 10`. Each pool connection gets its own
Dolt session (independent working set, independent branch state). This is
critical for understanding why `DOLT_CHECKOUT` is dangerous in pooled mode
and why beads pins a single connection for transaction + DOLT_COMMIT sequences.

---

## Known Critical Issues

### Stale LOCK Files

| Aspect | Detail |
|--------|--------|
| **Symptom** | Server won't start; SIGSEGV (nil pointer in `DoltDB.SetCrashOnFatalError`) or "database is locked" |
| **Cause** | Dolt creates `<db>/.dolt/noms/LOCK` when opening a database. If the process is killed (SIGKILL, OOM), the file persists |
| **Impact** | Server completely unable to start |
| **Mitigation** | `CleanStaleNomsLocks()` in `internal/storage/dolt/noms_lock.go` removes stale LOCK files before server start. Also available via `bd doctor --fix` |
| **Source** | `internal/storage/dolt/noms_lock.go` |

### DOLT_COMMIT Staging Sweep (GH#2455)

| Aspect | Detail |
|--------|--------|
| **Symptom** | Wrong data appearing in commits; `issue_prefix` in config table gets corrupted |
| **Cause** | Using `DOLT_COMMIT('-Am', ...)` (add-all mode) stages ALL dirty tables in the session's working set, including stale changes from other concurrent operations |
| **Impact** | Data corruption -- config values from one operation leak into another's commit |
| **Mitigation** | Beads now uses explicit `DOLT_ADD(table)` for each table modified in the current transaction, followed by `DOLT_COMMIT('-m', ...)` (without `-A`) |
| **Source** | `internal/storage/dolt/transaction.go`, lines 112-125 |

### Wisp Data Loss

| Aspect | Detail |
|--------|--------|
| **Symptom** | Wisps (ephemeral issues) silently disappear |
| **Cause** | When all writes in a transaction go to the `wisps` table (which is in `dolt_ignore`), `DOLT_COMMIT` returns "nothing to commit". Previously, this error left the Go `sql.Tx` in a broken state, and the subsequent `tx.Commit()` failed silently |
| **Impact** | Complete loss of wisp data for the transaction |
| **Mitigation** | The SQL transaction is now committed BEFORE `DOLT_COMMIT`, ensuring wisp writes are persisted regardless of whether `DOLT_COMMIT` finds anything to stage |
| **Source** | `internal/storage/dolt/transaction.go`, comment at `hq-3paz0m` |

### Metadata Merge Conflicts (GH#2466)

| Aspect | Detail |
|--------|--------|
| **Symptom** | Federation sync fails with unresolvable conflicts |
| **Cause** | Both towns write to the same metadata keys (e.g., `last_sync_*`), creating cell-level conflicts during merge |
| **Impact** | Federation sync blocked until manual resolution |
| **Mitigation** | Auto-resolve metadata conflicts with "theirs" strategy |

### SQL Timeout on Large Push

| Aspect | Detail |
|--------|--------|
| **Symptom** | `CALL DOLT_PUSH(remote, branch)` times out through the SQL connection |
| **Cause** | Large pushes to SSH remotes exceed the MySQL connection's read/write timeout |
| **Impact** | Push fails; data not synchronized |
| **Mitigation** | Git-protocol remotes (SSH, git+https) are routed to CLI subprocess (`dolt push`) instead of SQL stored procedure. CLI timeout: 5 minutes (`cliExecTimeout`) |
| **Source** | `internal/storage/dolt/federation.go`, `isPeerGitProtocolRemote()` |

### Lost Updates (Repeatable-Read Gap)

| Aspect | Detail |
|--------|--------|
| **Symptom** | Field updates silently overwritten by concurrent agents |
| **Cause** | Under MVCC repeatable-read isolation, a read-then-write pattern can miss concurrent updates if the read snapshot is stale |
| **Impact** | High-contention fields (e.g., `agent_state`, `status`) can lose updates |
| **Mitigation** | Check-before-update pattern for high-contention fields; retry on Error 1213 |

### Server Hang Under Load (2026-02-23 Production Incident)

| Aspect | Detail |
|--------|--------|
| **Symptom** | Dolt server becomes completely unresponsive; all agents blocked |
| **Cause** | Combination of: redundant `tx.Commit()` after `DOLT_COMMIT()`; ~15 databases on one server; 20 processes each with connection pool of 10 (= 200 potential connections); `autocommit: false` |
| **Impact** | Total cascade failure across all agents |
| **Mitigation** | Removed redundant `tx.Commit()`; upgraded Dolt 1.82.2 to 1.82.4; reduced concurrent database count |
| **Reproduction** | Simple repro does NOT reproduce -- requires full production conditions (many databases, many concurrent connections, sustained write load) |

---

## Server Configuration

### Beads Defaults

| Setting | Value | Notes |
|---------|-------|-------|
| Port | 3307 (DefaultSQLPort) | Configurable via `BEADS_DOLT_SERVER_PORT` env var or `metadata.json` |
| Host | 127.0.0.1 | Configurable via `BEADS_DOLT_SERVER_HOST` |
| User | root | Configurable via `metadata.json` |
| Password | (empty) | Set via `BEADS_DOLT_PASSWORD` env var (never in files) |
| MaxOpenConns | 10 | Connection pool size |
| Read timeout | 30s | For SQL queries |
| Write timeout | 30s | For SQL mutations |
| CLI exec timeout | 5 min | For dolt push/pull/fetch via subprocess |
| Branch | main | Hardcoded; all agents on main |

### Gas Town Recommendations

For multi-agent deployments (20+ concurrent agents):

| Setting | Recommended | Reason |
|---------|-------------|--------|
| max_connections | 100+ | 20 agents * 10 pool connections = 200 potential connections |
| read_timeout | 60s | Ready-work queries on large graphs can be slow |
| write_timeout | 120s | Push/pull operations need headroom |
| Databases per server | <5 | Production incident showed ~15 databases caused contention |

### Telemetry Opt-Out

Dolt phones home to `doltremoteapi.dolthub.com` by default. To disable:

```bash
dolt config --global --add metrics.disabled true
```

### Auto-Start Behavior

When beads cannot reach a Dolt server and auto-start is enabled, it launches
`dolt sql-server` as a subprocess. The auto-start decision follows a priority
chain (highest wins):

| Priority | Condition | Result |
|----------|-----------|--------|
| 1 | `BEADS_TEST_MODE=1` | Always disabled |
| 2 | `BEADS_DOLT_AUTO_START=0` | Always disabled |
| 3 | `metadata.json` has explicit `dolt_server_port` | Disabled (prevents shadow databases) |
| 4 | Caller sets `Config.AutoStart = true` | Enabled |
| 5 | `config.yaml` has `dolt.auto-start: false` | Disabled |
| 6 | Default | Enabled (standalone user) |

Source: `internal/storage/dolt/open.go`, `resolveAutoStart()`.

Reference counting (`autoStartRefs` in `store.go`) ensures the server is
stopped only when the last `DoltStore` referencing it is closed.

---

## Retry and Resilience

### Exponential Backoff

All SQL operations are wrapped in `withRetry()`, which uses exponential backoff
with a maximum elapsed time of 30 seconds. Retryable errors include:

| Error Pattern | MySQL Error | Cause |
|---------------|-------------|-------|
| `driver: bad connection` | -- | Stale connection pool entry |
| `invalid connection` | -- | Connection invalidated |
| `broken pipe` | -- | Network interruption |
| `connection reset` | -- | TCP reset |
| `connection refused` | -- | Server briefly unavailable |
| `database is read only` | -- | Dolt under load |
| `lost connection` | 2013 | Mid-query disconnect |
| `gone away` | 2006 | Idle connection timeout |
| `i/o timeout` | -- | Network timeout |
| `unknown database` | 1049 | Dolt catalog race after CREATE DATABASE |
| `no root value found` | -- | Dolt internal race after CREATE DATABASE |

Source: `internal/storage/dolt/store.go`, `isRetryableError()`.

### Circuit Breaker

A file-backed circuit breaker provides cross-process fail-fast behavior when
the Dolt server is down. State is shared via JSON files in `/tmp/`.

| Parameter | Value |
|-----------|-------|
| Failure threshold | 5 consecutive connection failures |
| Failure window | 60 seconds |
| Cooldown (open duration) | 5 seconds |
| State file | `/tmp/beads-dolt-circuit-<host>-<port>.json` |

States: `closed` (normal) -> `open` (rejecting, after threshold) -> probe
(after cooldown, active TCP health check) -> `closed` (if probe succeeds).

The breaker only tracks **connection-level** errors (TCP failures, driver
disconnects). Query-level errors (syntax, missing table) do not trip it.

OTel metrics: `bd.db.circuit_trips`, `bd.db.circuit_rejected`.

Source: `internal/storage/dolt/circuit.go`.

### Lock Error Handling

Dolt lock contention errors (`database is locked`, `lock file`, `noms lock`)
are detected by `isLockError()` and wrapped with actionable guidance directing
users to restart the server or run `bd doctor --fix`.

---

## The Production Incident (2026-02-23)

This incident is worth documenting in detail because it reveals the
interaction between Dolt's concurrency model and Go's `database/sql` package
under production conditions.

### Timeline

~20 concurrent Claude Code agents were running against a shared Dolt server.
The server became completely unresponsive -- no queries returned, no new
connections succeeded, all agents blocked indefinitely.

### Root Causes

1. **Redundant `tx.Commit()` after `DOLT_COMMIT()`**: The transaction code
   called `DOLT_COMMIT()` inside an open SQL transaction, then called
   `tx.Commit()` on the Go side. When `DOLT_COMMIT()` returned "nothing to
   commit" (all writes to dolt-ignored tables), the Go `sql.Tx` was left in
   a broken state. The subsequent `tx.Commit()` failed silently, leaving the
   connection in an unusable state that was returned to the pool.

2. **~15 databases on one server**: Each database adds overhead to the server's
   internal state management. Combined with many connections, this exceeded
   Dolt's internal capacity.

3. **200 potential connections**: 20 OS processes, each with a connection pool
   of 10 = 200 connections that could be simultaneously active. This exceeded
   the server's ability to manage concurrent sessions.

4. **`autocommit: false`**: The Dolt server was running with autocommit
   disabled, meaning every connection started an implicit transaction. Combined
   with the broken `tx.Commit()` pattern, this created a buildup of abandoned
   transactions.

### Fix

- Removed the redundant `tx.Commit()` call
- Upgraded Dolt from 1.82.2 to 1.82.4
- Restructured transaction flow: SQL commit FIRST, then DOLT_COMMIT

### Reproduction

A simple reproduction test does NOT trigger the hang. The failure requires the
full production conditions: many databases, many concurrent connections from
separate OS processes, sustained write load, and the specific broken
transaction pattern. This makes it a classic "works on my machine" concurrency
bug.

---

## Alternatives Considered

Dolt occupies a unique niche: cell-level merge + version control +
MySQL-compatible wire protocol. No other database provides all three:

| Database | Cell-Level Merge | Version Control | MySQL Compatible |
|----------|-----------------|----------------|-----------------|
| **Dolt** | Yes | Yes | Yes |
| LiteFS | No (single-writer) | No | SQLite only |
| CockroachDB | No (row-level) | No | PostgreSQL wire |
| EventStoreDB | N/A (append-only) | N/A | Custom protocol |
| Git + SQLite | No | Yes (file-level) | No |
| PostgreSQL | No (row-level) | No | PostgreSQL wire |

The cell-level merge capability is what makes the multi-agent, all-on-main
pattern viable. Without it, beads would need a much more complex coordination
protocol (explicit locking, message passing, or conflict-free replicated data
types).

---

## Schema Reference

Beads' Dolt schema (version 8) defines the following tables:

| Table | Primary Key | Purpose |
|-------|-------------|---------|
| `issues` | `id VARCHAR(255)` | All issue types (tasks, epics, agents, gates, etc.) |
| `wisps` | `id VARCHAR(255)` | Ephemeral issues (mirrors `issues` schema, in `dolt_ignore`) |
| `dependencies` | `(issue_id, depends_on_id)` | Dependency graph edges |
| `wisp_dependencies` | `(issue_id, depends_on_id)` | Wisp dependency edges (in `dolt_ignore`) |
| `labels` | `(issue_id, label)` | Issue labels |
| `wisp_labels` | `(issue_id, label)` | Wisp labels (in `dolt_ignore`) |
| `comments` | `id CHAR(36) UUID` | Issue comments |
| `wisp_comments` | `id CHAR(36) UUID` | Wisp comments (in `dolt_ignore`) |
| `events` | `id CHAR(36) UUID` | Audit trail (status changes, field updates) |
| `wisp_events` | `id CHAR(36) UUID` | Wisp events (in `dolt_ignore`) |
| `config` | `key VARCHAR(255)` | Project configuration (issue_prefix, compaction settings) |
| `metadata` | `key VARCHAR(255)` | Internal state (last_sync times, project_id) |
| `child_counters` | `parent_id` | Sequential child ID generation |
| `issue_snapshots` | `id CHAR(36) UUID` | Compaction snapshots |
| `compaction_snapshots` | `id CHAR(36) UUID` | Compaction archive |
| `repo_mtimes` | `repo_path` | Multi-repo file change tracking |
| `routes` | `prefix VARCHAR(32)` | Prefix-to-path routing |
| `issue_counter` | `prefix VARCHAR(255)` | Sequential ID generation (counter mode) |
| `interactions` | `id VARCHAR(32)` | Agent audit log |
| `federation_peers` | `name VARCHAR(255)` | Federation peer credentials |

### Views

| View | Purpose |
|------|---------|
| `ready_issues` | Open issues with no active blockers (recursive CTE for transitive blocking) |
| `blocked_issues` | Issues with at least one active blocker (with count) |

Schema source: `internal/storage/dolt/schema.go`.
Migrations: `internal/storage/dolt/migrations/` (001 through 011).
