# 03 -- Storage Engine Reference

This document provides a comprehensive reference for the Beads storage engine,
which is built on top of Dolt (a versioned, MySQL-compatible database). All
storage operations go through a single struct -- `DoltStore` -- that manages
connection lifecycle, schema evolution, retries, circuit breaking, caching, and
Dolt-specific version control semantics.

**Key source files:**

| File | Purpose |
|------|---------|
| `internal/storage/dolt/store.go` | DoltStore struct, New(), connection, retry, exec/query wrappers |
| `internal/storage/dolt/schema.go` | DDL schema, ready_issues/blocked_issues views |
| `internal/storage/dolt/migrations.go` | Migration registry and runner |
| `internal/storage/dolt/open.go` | NewFromConfig, resolveAutoStart |
| `internal/storage/dolt/queries.go` | GetReadyWork, GetBlockedIssues, computeBlockedIDs |
| `internal/storage/dolt/transaction.go` | RunInTransaction, doltTransaction |
| `internal/storage/dolt/dependencies.go` | Dependency CRUD, DetectCycles, IsBlocked |
| `internal/storage/dolt/issues.go` | Issue CRUD, ClaimIssue, CloseIssue |
| `internal/storage/dolt/credentials.go` | Federation credential encryption |
| `internal/storage/dolt/ephemeral_routing.go` | Wisp routing, IsEphemeralID, IsInfraType |
| `internal/storage/dolt/wisps.go` | Wisp table operations (dolt_ignore'd tables) |
| `internal/storage/dolt/errors.go` | Error classification and wrapping |
| `internal/storage/dolt/circuit.go` | Cross-process circuit breaker |
| `internal/doltserver/doltserver.go` | Server lifecycle: Start, Stop, EnsureRunning |

---

## 1. DoltStore Struct

**File:** `internal/storage/dolt/store.go:112-157`

```go
type DoltStore struct {
    db            *sql.DB
    dbPath        string       // .beads/dolt/ (server root)
    beadsDir      string       // .beads/ directory
    database      string       // Database name within Dolt
    closed        atomic.Bool
    connStr       string       // MySQL DSN for reconnection
    mu            sync.RWMutex // Protects concurrent access
    readOnly      bool
    credentialKey []byte       // AES key for federation credential encryption

    // Per-invocation caches
    customStatusCache   []string
    customStatusCached  bool
    customTypeCache     []string
    customTypeCached    bool
    infraTypeCache      map[string]bool
    infraTypeCached     bool
    blockedIDsCache     []string
    blockedIDsCacheMap  map[string]bool
    blockedIDsCached    bool
    blockedIDsCacheIncludesWisps bool
    cacheMu             sync.Mutex

    // OTel span attribute cache
    spanAttrsOnce  sync.Once
    spanAttrsCache []attribute.KeyValue

    // Circuit breaker
    breaker *circuitBreaker

    // Version control config
    committerName  string
    committerEmail string
    remote         string // Default: "origin"
    branch         string // Always: "main"
    remoteUser     string
    remotePassword string
    serverMode     bool   // Always true (embedded mode removed)

    autoStartedServerDir string // Set when this store auto-started a server
}
```

### Compile-Time Interface Checks

```go
var _ storage.DoltStorage      = (*DoltStore)(nil)
var _ storage.RawDBAccessor    = (*DoltStore)(nil)
var _ storage.StoreLocator     = (*DoltStore)(nil)
var _ storage.LifecycleManager = (*DoltStore)(nil)
var _ storage.PendingCommitter = (*DoltStore)(nil)
```

---

## 2. Config Struct

**File:** `internal/storage/dolt/store.go:160-200`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `Path` | string | required | Dolt data directory (e.g., `.beads/dolt/`) |
| `BeadsDir` | string | `filepath.Dir(Path)` | `.beads/` directory |
| `Database` | string | `configfile.DefaultDoltDatabase` | Database name; test mode derives from path hash |
| `CommitterName` | string | `$GIT_AUTHOR_NAME` or `"beads"` | Git-style committer |
| `CommitterEmail` | string | `$GIT_AUTHOR_EMAIL` or `"beads@local"` | Git-style email |
| `Remote` | string | `"origin"` | Default remote for push/pull |
| `ReadOnly` | bool | false | Skips schema init when true |
| `ServerHost` | string | `$BEADS_DOLT_SERVER_HOST` or `"127.0.0.1"` | Server bind address |
| `ServerPort` | int | resolved chain (see below) | MySQL protocol port |
| `ServerUser` | string | `"root"` | MySQL user |
| `ServerPassword` | string | `$BEADS_DOLT_PASSWORD` | MySQL password |
| `ServerTLS` | bool | false | Required for Hosted Dolt |
| `RemoteUser` | string | `$DOLT_REMOTE_USER` | Remote auth for push/pull |
| `RemotePassword` | string | `$DOLT_REMOTE_PASSWORD` | Remote auth password |
| `CreateIfMissing` | bool | **false** | CREATE DATABASE only when explicitly requested |
| `AutoStart` | bool | resolved (see resolveAutoStart) | Transparent server auto-start |
| `MaxOpenConns` | int | 10 (1 for test isolation) | Connection pool size |

---

## 3. New() Entry Point

**File:** `internal/storage/dolt/store.go:639-658`

```
New(ctx, cfg)
  |
  +-> applyConfigDefaults(cfg)
  |     |-> Derive database name (test mode: fnv hash of path)
  |     |-> Fill committer name/email from env or defaults
  |     |-> Resolve ServerPort via env > doltserver.DefaultConfig > 0
  |     |-> BEADS_TEST_MODE guard: force port=1 if would hit DefaultSQLPort(3307)
  |
  +-> PANIC if BEADS_TEST_MODE=1 && ServerPort == DefaultSQLPort (3307)
  |
  +-> newServerMode(ctx, cfg)
```

The `BEADS_TEST_MODE` panic is a hard guard ensuring tests never connect to the
production Dolt server. This was added after repeated incidents of test database
pollution ("Clown Shows #12-#18").

---

## 4. newServerMode() Connection Sequence

**File:** `internal/storage/dolt/store.go:662-832`

### Step-by-step:

1. **Circuit breaker check** -- If the breaker is open, return `ErrCircuitOpen`
   immediately (fail-fast).

2. **Fail-fast TCP dial** (500ms timeout) -- Probes the server before initiating
   MySQL protocol. Gives a clear error if the server is down.

3. **Auto-start on dial failure** -- If `cfg.AutoStart && isLocalHost`:
   - Call `doltserver.EnsureRunningDetailed(beadsDir)`
   - If `startedByUs`, increment `autoStartRefs` for cleanup tracking
   - Update `cfg.ServerPort` to the ephemeral port assigned by the OS
   - Retry TCP dial with 2s timeout

4. **openServerConnection** -- Opens MySQL connection pool:
   - `ValidateDatabaseName` (prevents SQL injection via backtick escaping)
   - Test database firewall: refuse to CREATE test-named databases on production port
   - `SHOW DATABASES` + iterate for exact match (avoids LIKE wildcard issues with `_`)
   - If missing and `CreateIfMissing=false`: return `databaseNotFoundError`
   - If missing and `CreateIfMissing=true`: `CREATE DATABASE IF NOT EXISTS`
   - `Ping` with exponential backoff (100ms initial, 10s max) for catalog registration race (GH-1851)

5. **Schema initialization** with 5s retry:
   - Exponential backoff (100ms initial) to handle transient "no root value found" race
   - Calls `initSchema` (see Section 10)

6. **initCredentialKey** -- Loads AES encryption key from
   `.beads-credential-key` file, or generates a new random 32-byte key.
   Used for encrypting federation peer passwords at rest.

7. **verifyProjectIdentity** -- Compares `_project_id` from local
   `metadata.json` against the database `metadata` table. A mismatch means
   cross-project data leakage -- refuses to connect with diagnostic message.

8. **syncCLIRemotesToSQL** -- After a server restart, `dolt_remotes` is empty
   (not persisted across sessions). CLI remotes survive in `.dolt/config`.
   Re-registers them so `DOLT_PUSH`/`DOLT_PULL` work.

---

## 5. DSN Format

**File:** `internal/storage/dolt/store.go:886-911`

```
user[:pass]@tcp(host:port)/[database]?parseTime=true&timeout=5s&readTimeout=10s&writeTimeout=10s[&tls=true]
```

Timeout parameters prevent agents from blocking forever when the Dolt server
hangs:
- `timeout=5s` -- TCP connect timeout
- `readTimeout=10s` -- I/O read timeout (hung queries)
- `writeTimeout=10s` -- I/O write timeout

For push/pull operations, `execWithLongTimeout` opens a **one-shot connection**
with `readTimeout=5m` to accommodate network I/O to git remotes.

---

## 6. Transaction Pattern

**File:** `internal/storage/dolt/transaction.go:55-128`

The Dolt commit pattern within transactions:

```
BEGIN
  -> writes (INSERT/UPDATE/DELETE)
  -> DOLT_ADD(table1)
  -> DOLT_ADD(table2)
  -> DOLT_COMMIT('-m', msg, '--author', author)
  -> tx.Commit()    // SQL transaction commit
```

### Critical: Redundant tx.Commit() Bug

There was a production hang incident caused by calling `tx.Commit()` after
`DOLT_COMMIT()`. When `DOLT_COMMIT` returned "nothing to commit" (all writes
were to dolt_ignore'd tables), the Go `sql.Tx` was left in a broken state and
`Commit()` failed silently, losing wisp data (hq-3paz0m).

The fix: `sqlTx.Commit()` is called **after** the `fn()` callback returns, and
`DOLT_COMMIT` runs on the **same pinned connection** after the SQL commit.

### GH#2455: Selective Table Staging

The old `DOLT_COMMIT('-Am', ...)` approach staged ALL dirty tables in the
session's working set, including config. This swept up stale `issue_prefix`
changes from concurrent operations, corrupting the config table.

The fix: `doltAddAndCommit` explicitly stages only the tables that were modified,
excluding `config` unless the caller explicitly intends to commit config changes
(via `CommitWithConfig`).

---

## 7. Retry and Circuit Breaker

### withRetry

**File:** `internal/storage/dolt/store.go:304-344`

- Exponential backoff via `cenkalti/backoff/v4`
- `MaxElapsedTime = 30s`
- Checks circuit breaker before each attempt
- Records connection failures/successes to the breaker
- Stops retrying if the breaker trips open

### Retryable Errors

**File:** `internal/storage/dolt/store.go:219-277`

| Error Pattern | Cause |
|---------------|-------|
| `driver: bad connection` | MySQL driver stale pool connection |
| `invalid connection` | MySQL driver invalid state |
| `broken pipe` | Network blip |
| `connection reset` | Network blip |
| `connection refused` | Server restart (transient) |
| `database is read only` | Dolt read-only mode under load |
| `lost connection` | MySQL error 2013 (mid-query disconnect) |
| `gone away` | MySQL error 2006 (idle timeout) |
| `i/o timeout` | Go net package timeout |
| `unknown database` | Dolt catalog race after CREATE DATABASE (GH-1851) |
| `no root value found` | Dolt internal race after CREATE DATABASE |

### Circuit Breaker

**File:** `internal/storage/dolt/circuit.go`

- Trips after sustained connection failures
- **Fail-fast rejects** while open (returns `ErrCircuitOpen`)
- Cross-process coordination via file-based state
- Records OTel metrics: `bd.db.circuit_trips`, `bd.db.circuit_rejected`

---

## 8. Key Methods

### execContext

**File:** `internal/storage/dolt/store.go:453-481`

All writes. Wraps every operation in `BEGIN`/`COMMIT` for durability. Applies
OTel span instrumentation, `withRetry`, and `wrapLockError`.

### queryContext

**File:** `internal/storage/dolt/store.go:497-522`

All reads. Uses `withRetry`. Closes previous `*sql.Rows` on retry to avoid
connection leaks.

### withWriteTx / withReadTx

**File:** `internal/storage/dolt/store.go:417-449`

```go
func (s *DoltStore) withWriteTx(ctx, fn func(tx *sql.Tx) error) error {
    tx, _ := s.db.BeginTx(ctx, nil)
    defer tx.Rollback()
    if err := fn(tx); err != nil { return err }
    return tx.Commit()
}
```

`withReadTx` is identical but acquires `RLock` instead of full lock.

### Commit

**File:** `internal/storage/dolt/store.go:1346-1406`

1. Pin a single connection (`s.db.Conn(ctx)`)
2. Query `dolt_status` for dirty tables
3. `DOLT_ADD(table)` each dirty table **except** `config` (GH#2455)
4. `DOLT_COMMIT('-m', message, '--author', author)`
5. "Nothing to commit" is a no-op (returns nil)

### Close

**File:** `internal/storage/dolt/store.go:1251-1283`

1. `s.closed.Store(true)`
2. Lock mutex
3. `s.db.Close()` with timeout (`doltutil.CloseWithTimeout`)
4. `autoStartRelease(serverDir)` -- stops auto-started server at refcount 0
5. Clean up 0-byte noms LOCK files (left behind by crashed embedded Dolt)

### execWithLongTimeout

**File:** `internal/storage/dolt/store.go:921-942`

Opens a **one-shot** `*sql.DB` connection with `readTimeout=5m`. Used for
`DOLT_PUSH`/`DOLT_PULL` which perform network I/O and can exceed the default
10s read timeout. Wraps the query in an explicit transaction so merge operations
succeed under autocommit.

### doltAddAndCommit

**File:** `internal/storage/dolt/store.go:1431-1448`

Pins a connection, calls `DOLT_ADD(table)` for each table in the list, then
`DOLT_COMMIT('-m', msg, '--author', author)`. Used instead of `DOLT_COMMIT('-Am')`
to avoid sweeping up stale working set changes (GH#2455).

---

## 9. Connection Pool Configuration

**File:** `internal/storage/dolt/store.go:953-961`

```go
maxOpen := 10                    // Default
if cfg.MaxOpenConns > 0 {
    maxOpen = cfg.MaxOpenConns   // Override (1 for test isolation)
}
db.SetMaxOpenConns(maxOpen)
db.SetMaxIdleConns(min(5, maxOpen))
db.SetConnMaxLifetime(5 * time.Minute)
```

Setting `MaxOpenConns=1` in tests ensures branch isolation because
`DOLT_CHECKOUT` is session-level.

---

## 10. Schema Initialization

**File:** `internal/storage/dolt/schema.go`, `internal/storage/dolt/store.go:1075-1174`

`currentSchemaVersion = 8`

### Fast Path

If `config.schema_version >= currentSchemaVersion`, skip all ~20 DDL statements.
Still recreates wisp tables since they are `dolt_ignore`'d and do not persist
across server sessions.

### Full Path

1. Execute all `CREATE TABLE IF NOT EXISTS` statements from `schema` constant
2. `INSERT IGNORE` default config values (compaction settings)
3. Apply index migrations (e.g., `CREATE INDEX idx_issues_issue_type`)
4. Drop FK on `depends_on_id` (allows external references `external:<rig>:<id>`)
5. Create views: `ready_issues`, `blocked_issues`
6. `RunMigrations(db)` -- execute all numbered migrations
7. Update `schema_version` in config table
8. `DOLT_ADD('config')` + `DOLT_COMMIT`

### Core Tables

| Table | Purpose |
|-------|---------|
| `issues` | Primary work items (VARCHAR(255) PK) |
| `dependencies` | Edge schema (composite PK: issue_id, depends_on_id) |
| `labels` | Tag associations (composite PK: issue_id, label) |
| `comments` | Discussion threads (UUID PK) |
| `events` | Audit trail (UUID PK) |
| `config` | Key-value configuration |
| `metadata` | Key-value metadata |
| `child_counters` | Sequential child ID allocation per parent |
| `issue_counter` | Sequential ID mode counter per prefix |
| `issue_snapshots` | Compaction snapshots |
| `compaction_snapshots` | Compaction history |
| `repo_mtimes` | Multi-repo last-modified tracking |
| `routes` | Prefix-to-path routing |
| `interactions` | Agent audit log |
| `federation_peers` | Peer credential storage (encrypted passwords) |

### Dolt-Ignored Tables (Wisp Tables)

These tables exist only in the working set and are **never committed to Dolt
history**. They must be recreated every server session.

| Table | Purpose |
|-------|---------|
| `wisps` | Ephemeral/infra-type issues |
| `wisp_labels` | Labels for wisps |
| `wisp_dependencies` | Dependencies for wisps |
| `wisp_events` | Events for wisps |
| `wisp_comments` | Comments for wisps |

---

## 11. Migration System

**File:** `internal/storage/dolt/migrations.go`

11 numbered migrations, all **idempotent** (safe to run multiple times):

| # | Name | What It Does |
|---|------|--------------|
| 001 | `wisp_type_column` | `ADD COLUMN wisp_type` to issues table |
| 002 | `spec_id_column` | `ADD COLUMN spec_id` to issues table |
| 003 | `orphan_detection` | Diagnostic scan for orphaned children (read-only) |
| 004 | `wisps_table` | Add `dolt_ignore` patterns, `CREATE TABLE wisps` |
| 005 | `wisp_auxiliary_tables` | `CREATE TABLE wisp_labels, wisp_dependencies, wisp_events, wisp_comments` |
| 006 | `issue_counter_table` | `CREATE TABLE issue_counter` for sequential ID mode |
| 007 | `infra_to_wisps` | Migrate infra-type issues (agent, rig, role, message) to wisps table |
| 008 | `wisp_dep_type_index` | `ADD INDEX` on wisp_dependencies type column |
| 009 | `cleanup_autopush_metadata` | Remove stale autopush keys from metadata table |
| 010 | `uuid_primary_keys` | Convert `AUTO_INCREMENT` to `CHAR(36)` UUID PKs (federation-safe) |
| 011 | `add_no_history_column` | `ADD COLUMN no_history` to issues and wisps tables |

After all migrations, `RunMigrations` stages migration-affected tables with
explicit `DOLT_ADD(table)` for each table (not `-Am`) and commits.

---

## 12. Auto-Start Lifecycle

**File:** `internal/doltserver/doltserver.go`

### State Files

All state files live in the `.beads/` directory (or `~/.beads/shared-server/`
in shared mode):

| File | Content |
|------|---------|
| `dolt-server.pid` | Server process ID |
| `dolt-server.port` | Actual listening port |
| `dolt-server.log` | Server stdout/stderr |
| `dolt-server.lock` | `flock` exclusive lock for startup serialization |

### Start()

**File:** `internal/doltserver/doltserver.go:506-693`

1. `flock` exclusive lock on `dolt-server.lock` (non-blocking)
   - If locked by another process: block until available, then double-check `IsRunning`
2. Re-check `IsRunning` after lock (double-check pattern)
3. `KillStaleServers(beadsDir)` -- kill orphans **inside the lock** to prevent
   race where one process kills a server another is starting (GH#2430)
4. `exec.LookPath("dolt")` -- ensure binary exists
5. `ensureDoltIdentity()` -- set dolt global user.name/email from git config
6. `ensureDoltInit(doltDir)` -- `dolt init` if `.dolt/` missing; write `.bd-dolt-ok` marker
7. Port selection:
   - Explicit port: `reclaimPort` for conflict detection/adoption
   - Ephemeral: `allocateEphemeralPort` via `net.Listen(":0")`, retry up to 10 times for TOCTOU
8. `exec.Command("dolt", "sql-server", "-H", host, "-P", port)` with `cmd.Dir = doltDir`
9. 200ms alive check -- if process died immediately, retry with new port
10. Write PID and port files
11. `waitForReady(host, port, 10*time.Second)` -- TCP poll until accepting connections

### Stop()

**File:** `internal/doltserver/doltserver.go:777-805`

1. `FlushWorkingSet(host, port)` -- connects to server, iterates all databases,
   commits uncommitted changes via `DOLT_COMMIT('-Am', 'auto-flush: ...')`
2. `gracefulStop(pid, 5*time.Second)` -- SIGTERM then SIGKILL
3. Remove PID and port files

### EnsureRunning()

**File:** `internal/doltserver/doltserver.go:444-488`

1. `IsRunning` check -- reads PID file, verifies process alive and is a dolt process
2. `hasExplicitPort` check -- if `metadata.json` has explicit `dolt_server_port`,
   suppress auto-start (external/shared server)
3. `Start()` if not running

### Reference Counting

**File:** `internal/storage/dolt/store.go:71-103`

```go
var autoStartRefs struct {
    mu sync.Mutex
    m  map[string]int  // serverDir -> refcount
}
```

- `autoStartAcquire(serverDir)` increments count on store creation
- `autoStartRelease(serverDir)` decrements on `Close()`; stops server at 0
- Prevents test-started servers from leaking (GH#2542)

---

## 13. Port Resolution Priority

**File:** `internal/doltserver/doltserver.go:299-370`

| Priority | Source | Notes |
|----------|--------|-------|
| 1 | `BEADS_DOLT_SERVER_PORT` env var | Highest -- manual override |
| 2 | Port file (`.beads/dolt-server.port`) | Written by Start(), gitignored |
| 3 | `config.yaml` `dolt.port` or global config | Git-tracked, could propagate |
| 4 | `metadata.json` `dolt_server_port` | **Deprecated** (cross-project leakage GH#2372) |
| 5 | 0 (ephemeral) | Start() allocates from OS |

Shared mode: fixed port 3308 (avoids Gas Town conflict on 3307).

---

## 14. Shadow Database Prevention (3 Layers)

1. **CreateIfMissing=false default** -- Normal open paths never create databases.
   Only explicit init, migration, or new-board creation sets this to true.

2. **Project identity check** -- `verifyProjectIdentity()` compares
   `_project_id` from `metadata.json` against the database's `metadata` table.
   A mismatch means the client connected to the wrong project's server.

3. **Explicit port suppression in resolveAutoStart** -- When `metadata.json`
   specifies an explicit `dolt_server_port`, auto-start is suppressed. This
   prevents bd from launching a different server when the configured server is
   temporarily unreachable.

---

## 15. resolveAutoStart Priority

**File:** `internal/storage/dolt/open.go:116-138`

| Priority | Condition | Result |
|----------|-----------|--------|
| 1 | `BEADS_TEST_MODE=1` | **false** (tests own server lifecycle) |
| 2 | `BEADS_DOLT_AUTO_START=0` | **false** (explicit env opt-out) |
| 3 | `explicitPort == true` | **false** (metadata.json has explicit port) |
| 4 | `current == true` (caller request) | **true** (caller option wins) |
| 5 | `dolt.auto-start` in config.yaml = "false"/"0"/"off" | **false** |
| 6 | default | **true** (standalone user safe default) |

---

## 16. Wisp Routing

**File:** `internal/storage/dolt/ephemeral_routing.go`

Every storage function checks `isActiveWisp(ctx, issueID)` first and routes to
the appropriate table pair:

| Normal Table | Wisp Table |
|--------------|------------|
| `issues` | `wisps` |
| `dependencies` | `wisp_dependencies` |
| `labels` | `wisp_labels` |
| `events` | `wisp_events` |
| `comments` | `wisp_comments` |

An issue is routed to wisps if:
- It has the `-wisp-` pattern in its ID (`IsEphemeralID`)
- It exists in the wisps table (explicit-ID ephemerals, GH#2053)
- Its `issue_type` is an infrastructure type (agent, rig, role, message)
- It has `ephemeral=true` or `no_history=true`

The wisps table is `dolt_ignore`'d and **recreated every server session**
(GH#2271).

---

## 17. OTel Instrumentation

**File:** `internal/storage/dolt/store.go:346-409`

Every `execContext` and `queryContext` call creates an OTel span with:
- `db.system = "dolt"`
- `db.readonly` = store read-only flag
- `db.server_mode = true`
- `db.operation` = "exec" or "query"
- `db.statement` = truncated SQL (max 300 chars)

Metrics:
- `bd.db.retry_count` -- retried operations
- `bd.db.lock_wait_ms` -- lock acquisition time
- `bd.db.circuit_trips` -- breaker trip events
- `bd.db.circuit_rejected` -- requests rejected by open breaker

---

## 18. ready_issues View

**File:** `internal/storage/dolt/schema.go:273-311`

```sql
CREATE OR REPLACE VIEW ready_issues AS
WITH RECURSIVE
  blocked_directly AS (
    SELECT DISTINCT d.issue_id
    FROM dependencies d
    WHERE d.type = 'blocks'
      AND EXISTS (
        SELECT 1 FROM issues blocker
        WHERE blocker.id = d.depends_on_id
          AND blocker.status NOT IN ('closed', 'pinned')
      )
  ),
  blocked_transitively AS (
    SELECT issue_id, 0 as depth FROM blocked_directly
    UNION ALL
    SELECT d.issue_id, bt.depth + 1
    FROM blocked_transitively bt
    JOIN dependencies d ON d.depends_on_id = bt.issue_id
    WHERE d.type = 'parent-child' AND bt.depth < 50
  )
SELECT i.*
FROM issues i
LEFT JOIN blocked_transitively bt ON bt.issue_id = i.id
WHERE i.status = 'open'
  AND (i.ephemeral = 0 OR i.ephemeral IS NULL)
  AND bt.issue_id IS NULL
  AND (i.defer_until IS NULL OR i.defer_until <= NOW())
  AND NOT EXISTS (
    SELECT 1 FROM dependencies d_parent
    JOIN issues parent ON parent.id = d_parent.depends_on_id
    WHERE d_parent.issue_id = i.id
      AND d_parent.type = 'parent-child'
      AND parent.defer_until IS NOT NULL
      AND parent.defer_until > NOW()
  );
```

Key design choices:
- Uses `LEFT JOIN` (not `NOT EXISTS`) to avoid Dolt `mergeJoinIter` panic
- `NOT IN ('closed', 'pinned')` so custom statuses are automatically included
- Recursive CTE with depth limit 50 propagates blocked status through parent-child edges
- Deferred parents also defer their children

---

## 19. blocked_issues View

**File:** `internal/storage/dolt/schema.go:315-341`

```sql
CREATE OR REPLACE VIEW blocked_issues AS
SELECT i.*,
    (SELECT COUNT(*) FROM dependencies d
     WHERE d.issue_id = i.id AND d.type = 'blocks'
       AND EXISTS (
         SELECT 1 FROM issues blocker
         WHERE blocker.id = d.depends_on_id
           AND blocker.status NOT IN ('closed', 'pinned')
       )) as blocked_by_count
FROM issues i
WHERE i.status NOT IN ('closed', 'pinned')
  AND EXISTS (
    SELECT 1 FROM dependencies d
    WHERE d.issue_id = i.id AND d.type = 'blocks'
      AND EXISTS (
        SELECT 1 FROM issues blocker
        WHERE blocker.id = d.depends_on_id
          AND blocker.status NOT IN ('closed', 'pinned')
      ));
```

Uses correlated subquery (not three-table JOIN) to avoid the Dolt `mergeJoinIter`
panic.

---

## 20. Error Classification

**File:** `internal/storage/dolt/errors.go`

### Sentinel Errors

| Error | Usage |
|-------|-------|
| `ErrTransaction` | Transaction begin/commit/rollback failure |
| `ErrQuery` | Database query failure |
| `ErrScan` | Row scan failure |
| `ErrExec` | INSERT/UPDATE/DELETE failure |
| `ErrStoreClosed` | Operation on closed store |
| `ErrCircuitOpen` | Circuit breaker is open |

### Lock Error Wrapping

`isLockError` detects: "database is locked", "lock file", "noms lock",
"locked by another dolt process". `wrapLockError` adds actionable guidance:
restart server or run `bd doctor --fix`.

### Test Database Firewall

**File:** `internal/storage/dolt/store.go:51-69`

Pattern-based firewall prevents test databases from being created on production:

```go
var testDatabasePrefixes = []string{
    "testdb_", "beads_test", "beads_pt", "beads_vr", "doctest_", "doctortest_",
}
```

If `isTestDatabaseName(cfg.Database) && cfg.ServerPort == DefaultSQLPort` in
`openServerConnection`, the connection is **refused** with a reference to
`DOLT-WAR-ROOM.md`.
