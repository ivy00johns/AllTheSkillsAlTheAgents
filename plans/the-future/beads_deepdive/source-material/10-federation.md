# 10 -- Federation Reference

Part of the [Beads Deep Dive](00-INDEX.md) series.
Generated 2026-03-17 from steveyegge/beads v0.61.0.

---

## Architecture

Federation enables peer-to-peer synchronization between independent Gas Town
deployments. Each town maintains its own Dolt database and shares updates via
Dolt remotes -- the same push/pull/merge mechanism that Dolt uses for version
control, repurposed for cross-town data synchronization.

```
Gas Town A                              Gas Town B
    |                                       |
  Dolt DB (beads_a)                   Dolt DB (beads_b)
    |                                       |
  DoltStore.Sync()                    DoltStore.Sync()
    |         (push/pull/merge)             |
    +-----------  Dolt Remote  -------------+
              (DoltHub, S3, GCS,
               local filesystem,
               HTTPS, SSH)
```

The key insight is that Dolt's content-addressed storage and three-way merge
make federation a natural extension of the database itself, rather than a
separate protocol. Two towns that both push and pull from a shared remote
converge to the same state through Dolt's merge semantics, including cell-level
auto-merge for non-conflicting changes.

---

## Supported Remote Backends

Dolt supports multiple remote storage backends, each with different
characteristics:

| Backend | URL Format | Auth | Notes |
|---------|-----------|------|-------|
| DoltHub | `dolthub://org/repo` | DoltHub token | Hosted by DoltHub, easiest setup |
| Google Cloud Storage | `gs://bucket/path` | GCS credentials | Requires gcloud auth |
| Amazon S3 | `s3://bucket/path` | AWS credentials | Requires AWS auth |
| Local filesystem | `file:///path/to/backup` | None | For local testing/backup |
| HTTPS | `https://host/path` | Basic auth | Dolt remotesapi protocol |
| SSH | `ssh://host/path` | SSH keys | Routes to CLI subprocess |
| Git protocol | `git+https://`, `git://` | Various | Routes to CLI subprocess |

---

## Protocol Routing

Federation operations must choose between two execution paths: the SQL stored
procedure path (CALL DOLT_PUSH/PULL/FETCH) and the CLI subprocess path
(`dolt push`/`pull`/`fetch`). The routing decision is made per-operation and
per-peer, based on the remote URL protocol and credential availability.

### Decision Flow

All push/pull/fetch operations in `internal/storage/dolt/federation.go` follow
this routing logic:

```
Is the peer a git-protocol remote? (SSH, git+https, git://)
    |
    YES --> Route to CLI subprocess (dolt push/pull/fetch)
    |       Reason: SQL server lacks SSH keys and git credentials
    |
    NO --> Does the peer have stored credentials AND is the server external?
        |
        YES --> Route to CLI subprocess
        |       Reason: withEnvCredentials() sets env vars on the bd client
        |       process, but the external server process cannot see them
        |
        NO --> Route to SQL stored procedure (CALL DOLT_PUSH/PULL/FETCH)
                with execWithLongTimeout (5-minute read timeout)
```

### isPeerGitProtocolRemote()

This function (at `federation.go` line 373) checks whether a peer's remote URL
uses a protocol that requires the git binary or SSH keys for network I/O.
Git-protocol URLs include:

- `ssh://...`
- `git+https://...`
- `git://...`

For these remotes, the SQL server process typically does not have access to SSH
keys or git credentials, so operations must be routed through a CLI subprocess
that inherits the calling user's credential environment.

The function also verifies that the remote is configured in the local CLI
directory (`CLIDir()`). If the CLI directory does not have the remote
configured, the operation cannot route to CLI and will attempt the SQL path
(which may fail for git-protocol remotes).

### shouldUseCLIForPeerCredentials()

This function (at `credentials.go` line 494) handles the secondary routing
case: non-git remotes where credentials are stored. CLI routing is used when
ALL of these conditions are true:

1. Peer credentials exist (resolved from `federation_peers` table)
2. Server is in server mode (not embedded)
3. Local CLI directory is available
4. The peer remote is configured in the local CLI directory

The rationale: when using `withEnvCredentials()`, the function sets
`DOLT_REMOTE_USER` and `DOLT_REMOTE_PASSWORD` as process-wide environment
variables. In embedded mode, the Dolt engine runs in-process and reads these
env vars directly. In server mode, the Dolt engine is a separate process that
cannot see the bd client's environment. CLI subprocess routing solves this by
passing credentials via `cmd.Env` on the subprocess.

---

## Sync Flow

The `Sync()` method (`federation.go` line 296) performs a full bidirectional
synchronization with a peer. The flow is:

### Step 1: Fetch

```
CALL DOLT_FETCH(peer)   -- or --   dolt fetch <peer>
```

Updates local refs (e.g., `peer/main`) without modifying the local branch.
This is a read-only operation from the local branch's perspective.

### Step 2: Merge

```
CALL DOLT_MERGE('peer/main')
```

Performs a three-way merge of the peer's branch into the local branch. Dolt's
cell-level merge handles most changes automatically:

- Different agents modifying different columns on the same row: auto-merges
- Different agents modifying different rows: auto-merges
- Same column, same row modified by both sides: conflict

### Step 3: Conflict Resolution

If conflicts exist and a strategy is specified (`--strategy ours|theirs`):

```
CALL DOLT_CONFLICTS_RESOLVE('--theirs', table)
CALL DOLT_COMMIT('-m', 'Resolve conflicts from <peer> using <strategy>')
```

If no strategy is specified and conflicts exist, the sync pauses and reports
the conflicting tables for manual resolution.

### Step 4: Push

```
CALL DOLT_PUSH(peer, main)   -- or --   dolt push <peer> main
```

Pushes local commits to the peer. Push failure is **non-fatal** -- the peer
may not accept pushes (e.g., read-only remote, permissions). The error is
recorded in `SyncResult.PushError` but does not fail the overall sync.

### Step 5: Record Sync Time

```
REPLACE INTO metadata (`key`, value) VALUES ('last_sync_<peer>', '<RFC3339>')
```

The last sync time is stored in the `metadata` table for scheduling purposes.
This is advisory only -- the sync protocol does not depend on it for
correctness.

### Pre-Sync: Auto-Commit

Before pulling (step 1 fetch + step 2 merge), beads auto-commits any pending
changes (GH#2474). Dolt requires a clean working set for merge operations:

```go
// PullFrom, line 50-56
if !s.readOnly {
    if err := s.Commit(ctx, "auto-commit before pull"); err != nil {
        if !isDoltNothingToCommit(err) {
            return nil, fmt.Errorf("failed to commit pending changes before pull: %w", err)
        }
    }
}
```

---

## Data Sovereignty Tiers

Federation supports configurable sovereignty tiers per peer, intended for
compliance with regional data regulations. Tiers are stored in the
`federation_peers` table's `sovereignty` column.

| Tier | Level | Description |
|------|-------|-------------|
| T1 | No restrictions | Public data, unrestricted sharing |
| T2 | Organization-level | Data stays within organization or region |
| T3 | Pseudonymous | Personally identifiable information removed before sharing |
| T4 | Anonymous | Maximum privacy; all identifying information stripped |

**Current implementation status:** The tier values are stored and validated
(must be T1, T2, T3, or T4 if provided), but the enforcement mechanism is
not implemented in the current codebase. The tier is metadata only -- no
filtering or redaction occurs during push/pull operations. Enforcement would
need to be added as a pre-push hook that inspects and possibly redacts data
based on the peer's sovereignty tier.

---

## federation_peers Table

```sql
CREATE TABLE IF NOT EXISTS federation_peers (
    name VARCHAR(255) PRIMARY KEY,
    remote_url VARCHAR(1024) NOT NULL,
    username VARCHAR(255),
    password_encrypted BLOB,
    sovereignty VARCHAR(8) DEFAULT '',
    last_sync DATETIME,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_federation_peers_sovereignty (sovereignty)
);
```

| Column | Type | Purpose |
|--------|------|---------|
| `name` | VARCHAR(255), PK | Unique peer name (used as Dolt remote name) |
| `remote_url` | VARCHAR(1024) | Dolt remote URL (dolthub://, s3://, http://, ssh://, etc.) |
| `username` | VARCHAR(255) | SQL username for authentication (nullable) |
| `password_encrypted` | BLOB | AES-256-GCM encrypted password (nullable) |
| `sovereignty` | VARCHAR(8) | Sovereignty tier: T1, T2, T3, T4, or empty |
| `last_sync` | DATETIME | Last successful sync time (nullable) |
| `created_at` | DATETIME | Row creation time |
| `updated_at` | DATETIME | Last modification time |

Peer names must match `^[a-zA-Z][a-zA-Z0-9_-]*$` (start with letter,
alphanumeric with hyphens and underscores, max 64 characters).

Source: `internal/storage/dolt/schema.go`, `internal/storage/dolt/credentials.go`.

---

## Credential Management

Federation credentials are handled with care to avoid plaintext storage:

### Encryption

Passwords are encrypted with AES-256-GCM before storage in the
`password_encrypted` BLOB column. The encryption key is a random 32-byte value
stored in `.beads/.beads-credential-key` with owner-only permissions (0600).

```
.beads/
    .beads-credential-key    # 32-byte random AES-256 key (0600 permissions)
    dolt/
        <database>/
            .dolt/...
```

**Key migration (v0.61):** The credential key file was moved from
`.beads/dolt/.beads-credential-key` to `.beads/.beads-credential-key` to avoid
creating ghost directories in shared-server mode (GH `bd-cby`). A transparent
migration reads from the old location and writes to the new one on first access.

**Legacy key migration:** Older versions derived the encryption key from
`SHA-256(dbPath + "beads-federation-key-v1")`, which was predictable. The
current version generates a random key and re-encrypts all existing passwords
on first run (`migrateCredentialKeys()`).

### Credential Flow

1. User adds a peer: `bd federation add-peer town-beta http://... --user admin`
2. Password is read from `--password` flag or interactive prompt
3. Password is encrypted with AES-256-GCM using the credential key
4. Encrypted password stored in `federation_peers` table
5. Dolt remote added via `CALL DOLT_REMOTE('add', name, url)`

At sync time:

1. `withPeerCredentials()` looks up the peer in `federation_peers`
2. Decrypts the password using the credential key
3. Routes to CLI or SQL path based on protocol routing rules
4. CLI path: credentials passed via `cmd.Env` (subprocess isolation)
5. SQL path: credentials set via process env vars under `federationEnvMutex`

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `BEADS_DOLT_PASSWORD` | Server connection password (never stored in files) |
| `DOLT_REMOTE_USER` | Remote auth username (for Hosted Dolt push/pull) |
| `DOLT_REMOTE_PASSWORD` | Remote auth password (for Hosted Dolt push/pull) |

For CLI subprocess operations, credentials are set on `cmd.Env` rather than
the process-global environment, preventing leaks to concurrent goroutines.

For SQL path operations, credentials must be set as process-global env vars
(the Dolt server reads them from the process environment). Access is serialized
by `federationEnvMutex`.

Source: `internal/storage/dolt/credentials.go`.

---

## CLI Surface

### Exposed Commands

The federation CLI is registered under `bd federation`:

| Command | Status | Description |
|---------|--------|-------------|
| `bd federation add-peer <name> <url>` | Implemented | Add a peer with optional credentials and sovereignty tier |
| `bd federation remove-peer <name>` | Implemented | Remove a peer and its credentials |
| `bd federation list-peers` | Implemented | List all configured peers |
| `bd federation sync [--peer name] [--strategy ours\|theirs]` | Implemented | Bidirectional sync with one or all peers |
| `bd federation status [--peer name]` | Implemented | Show sync status (ahead/behind, connectivity, conflicts) |

### add-peer Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--user` | `-u` | SQL username for authentication |
| `--password` | `-p` | SQL password (prompted interactively if `--user` set without `--password`) |
| `--sovereignty` | -- | Sovereignty tier (T1, T2, T3, T4) |

### sync Behavior

Without `--peer`, syncs with all configured remotes except `origin` (which is
typically the backup remote, not a federation peer). With `--peer`, syncs only
with the specified peer.

Without `--strategy`, merge conflicts cause the sync to pause and report the
conflicting tables. With `--strategy ours` or `--strategy theirs`, conflicts
are auto-resolved.

### Build Constraint

The federation commands require CGO (build tag `//go:build cgo`). A separate
`federation_nocgo.go` file provides a stub that prints a "federation requires
CGO" message when built without CGO. This is because the interactive password
prompt uses `golang.org/x/term`, which has CGO dependencies.

Source: `cmd/bd/federation.go`, `cmd/bd/federation_nocgo.go`.

---

## Key Internal Functions

### PushTo (federation.go line 22)

```go
func (s *DoltStore) PushTo(ctx context.Context, peer string) error
```

Routes to `doltCLIPushToPeer()` for git-protocol remotes and credential-bearing
external-server peers. Otherwise executes `CALL DOLT_PUSH(peer, branch)` with
`execWithLongTimeout` (5-minute read timeout).

### PullFrom (federation.go line 47)

```go
func (s *DoltStore) PullFrom(ctx context.Context, peer string) ([]storage.Conflict, error)
```

Auto-commits pending changes before pull (GH#2474). Routes to CLI or SQL based
on protocol routing. On pull error, checks for merge conflicts -- if conflicts
exist, returns them instead of the error (allowing the caller to resolve).

### Fetch (federation.go line 104)

```go
func (s *DoltStore) Fetch(ctx context.Context, peer string) error
```

Fetches refs without merging. Same routing logic as PushTo.

### ListRemotes (federation.go line 125)

```go
func (s *DoltStore) ListRemotes(ctx context.Context) ([]storage.RemoteInfo, error)
```

Queries `SELECT name, url FROM dolt_remotes`. Returns all configured remotes.

### syncCLIRemotesToSQL (federation.go line 155)

```go
func (s *DoltStore) syncCLIRemotesToSQL(ctx context.Context)
```

Called on store open. After a Dolt server restart, `dolt_remotes` (an in-memory
system table) is empty, but CLI-level remotes persist in `.dolt/config`. This
function reads CLI remotes and re-registers them in the SQL server so that
`CALL DOLT_PUSH/PULL/FETCH` can find them.

Also handles GH#2118: users who run `dolt remote add` in `.beads/dolt/`
(server root) instead of `.beads/dolt/<database>/` (database directory). The
function checks the server root for remotes and propagates them to the correct
database directory.

### migrateServerRootRemotes (federation.go line 193)

```go
func (s *DoltStore) migrateServerRootRemotes(cliDir string) []storage.RemoteInfo
```

Handles GH#2118. When users run `dolt remote add` in the wrong directory
(server root instead of database subdirectory), this function detects the
misplaced remotes and propagates them to the correct location.

### SyncStatus (federation.go line 230)

```go
func (s *DoltStore) SyncStatus(ctx context.Context, peer string) (*storage.SyncStatus, error)
```

Returns ahead/behind commit counts by comparing local `dolt_log` with the
peer's ref (`dolt_log AS OF CONCAT(peer, '/', branch)`). Also checks for
unresolved conflicts and retrieves the last sync time from metadata.

---

## Cross-Project Issue References

Cross-project references are **not supported by design**. Each beads database
is an isolated unit. There is no mechanism for cross-project blocking
dependencies or transitive queries across databases.

The `dependencies` table deliberately omits a foreign key on `depends_on_id`
(see `schema.go` line 93-94 comment), which allows storing soft references in
the `external:<rig>:<id>` format. However:

- These references are not enforced -- the referenced issue may not exist
- There is no mechanism to query across databases
- The `ready_issues` view cannot evaluate cross-project blockers
- Closing an external reference does not update the referencing database

In practice, cross-project coordination must happen at the Gas Town
orchestration layer, not at the beads data layer.

---

## Known Issues and Limitations

### 1. Sovereignty Enforcement Not Implemented

The sovereignty tier values (T1-T4) are stored in `federation_peers` but no
filtering or redaction occurs during push/pull. All data is shared regardless
of tier. Implementing enforcement would require a pre-push hook that inspects
outgoing data and redacts or blocks based on the peer's tier.

### 2. Conflict Resolution Limited to ours/theirs

The only conflict resolution strategies are `--strategy ours` (keep local) and
`--strategy theirs` (accept remote). There is no support for:

- Per-table strategies (e.g., "theirs" for metadata, "ours" for issues)
- Per-field strategies
- Custom merge functions
- Interactive conflict resolution

For federation, beads uses "theirs" for metadata conflicts (GH#2466) on the
assumption that metadata (sync timestamps, counters) should converge to the
remote's value.

### 3. No Trust or Signing Mechanism

There is no cryptographic verification of data received from peers. A malicious
peer could push arbitrary data (modified issue content, fabricated history)
without detection. Dolt commits include author strings but these are
self-reported and not signed.

### 4. No Bandwidth Optimization

Federation uses Dolt's native push/pull protocol, which transfers
content-addressed chunks. There is no:

- Delta compression between known states
- Selective sync (only specific tables or time ranges)
- Priority-based sync (critical issues first)
- Bandwidth throttling

For large databases, initial sync can be slow (network-bound at ~1-10 Mbps).

### 5. syncCLIRemotesToSQL Required After Every Restart

The `dolt_remotes` system table is in-memory only. Every time the Dolt server
restarts, all remote configurations are lost. Beads works around this by
calling `syncCLIRemotesToSQL()` on every store open, which re-registers CLI
remotes into the SQL server. This is fragile:

- If the CLI directory is not accessible, remotes are not restored
- If the remote was added only via SQL (never via CLI), it is permanently lost
- The function runs on every store open, adding startup latency

### 6. Credential Key Location Changed in v0.61

The credential key file moved from `.beads/dolt/.beads-credential-key` to
`.beads/.beads-credential-key` in v0.61. A migration handles the transition,
but this indicates that the shared-server mode (where `.beads/dolt/` is a
shared resource) is still being hardened. Further changes to file locations
should be expected.

### 7. Port File Moved in v0.61

Similarly, the Dolt server port file moved from `.beads/dolt/` to `.beads/`
in v0.61, further indicating that the boundary between per-project and
shared-server state is still being refined.

### 8. No Automatic Sync Scheduling

Federation sync must be triggered manually (`bd federation sync`) or by the
Gas Town orchestrator. There is no built-in scheduling, cron integration, or
event-driven sync trigger. The `last_sync` timestamp in `federation_peers` is
advisory only and not used by any automatic scheduling logic.

---

## SyncResult Structure

The `Sync()` method returns a `SyncResult` containing the full outcome:

```go
type SyncResult struct {
    Peer              string
    StartTime         time.Time
    EndTime           time.Time
    Fetched           bool       // Step 1 succeeded
    Merged            bool       // Step 2 succeeded
    Pushed            bool       // Step 4 succeeded
    PulledCommits     int        // Commits integrated from peer
    PushedCommits     int        // Commits sent to peer
    Conflicts         []Conflict // Merge conflicts encountered
    ConflictsResolved bool       // True if auto-resolved
    Error             error      // Fatal error (stops sync)
    PushError         error      // Non-fatal push error
}
```

The distinction between `Error` (fatal) and `PushError` (non-fatal) is
important: a push failure does not roll back the fetch and merge. The local
database has already incorporated the peer's changes even if pushing local
changes back fails.

---

## Diagnostic Commands

### bd federation status

Performs a live connectivity check by fetching from each peer, then displays:

- Remote URL
- Reachability (with error message if unreachable)
- Commits ahead/behind
- Last sync time
- Conflict status

### bd doctor federation

The `cmd/bd/doctor/federation.go` module provides diagnostic checks for
federation health, including remote configuration validation and connectivity
testing.

---

## Integration with Gas Town

In a Gas Town multi-agent deployment, federation operates at the town level.
Individual agents do not perform federation operations -- they write to the
local Dolt database. The Gas Town orchestrator (gt) is responsible for:

1. Configuring federation peers during town setup
2. Scheduling periodic syncs between towns
3. Handling sync failures and conflict resolution
4. Ensuring sovereignty compliance (when implemented)

The federation protocol is town-to-town, not agent-to-agent. Within a single
town, all agents share one Dolt database and coordinate via the cell-level
merge mechanism described in [09-dolt-database.md](09-dolt-database.md).
