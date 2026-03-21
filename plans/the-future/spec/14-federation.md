# 14 — Federation

**Document type:** System specification
**Status:** DRAFT
**Date:** 2026-03-18
**Scope:** Multi-instance synchronization, sovereignty model, and cross-instance coordination
**Depends on:** `05-data-model.md` (work items, dependencies, scorecards), `03-system-architecture.md` (runtime layer), `07-merge-system.md` (conflict resolution)
**Source platforms:** Beads (Dolt remote protocol, three-way merge, credential encryption), Gas Town (Wasteland network, wanted board, stamps/reputation), Overstory (multi-repo orchestration, agent portability)

---

## 1. Federation Philosophy

### Local-First Is Non-Negotiable

Everything works without a network connection. A single-user instance on a laptop with no internet is a fully functional platform. Federation is additive — it enables collaboration, shared reputation, and cross-instance work routing, but it is never required. An instance that has never synced is not degraded; it simply has a smaller world.

This is not a design preference. It is a hard constraint. AI agent orchestration must survive airplane mode, air-gapped networks, and development environments where outbound connections are forbidden. The moment federation becomes load-bearing for local operations, the architecture has failed.

### Sovereignty: Each Instance Controls What It Shares

No instance is compelled to share anything. Federation is opt-in at every level:

- **Which peers** to connect to (explicit peer registration)
- **Which tables** to sync (selective table inclusion)
- **Which branches** to expose (branch-level filtering)
- **Which direction** data flows (push-only, pull-only, or bidirectional)
- **Which sovereignty tier** governs the relationship (see Section 4)

An instance can federate with one peer for work items and a different peer for expertise, while keeping scorecards entirely private. The unit of sharing is the table, not the database.

### Content-Addressed: Dedup Is Automatic

All data is stored as content-addressed chunks (SHA-256). When two instances hold the same data, sync transfers zero bytes for that data. When they diverge, sync transfers only the differing chunks. This is not an optimization — it is the fundamental storage model inherited from Dolt.

Consequences:
- Initial sync of a large database is slow (network-bound). Subsequent syncs are fast (delta only).
- Identical work items created independently on two instances will share storage after sync.
- Compaction reduces chunk count over time, shrinking the sync payload.
- Tamper detection is free: any modification changes the hash chain.

### Git-for-Data: Dolt Brings Git Semantics to SQL Tables

Dolt is a MySQL-compatible database with built-in version control. Every mutation can be committed to an immutable DAG of content-addressed snapshots. Push, pull, fetch, merge, branch, and diff work exactly as they do in Git, but operate on rows and cells instead of files and lines.

This is the critical distinction from file-level sync systems. Two agents modifying different columns of the same row will auto-merge cleanly. Two instances modifying different rows in the same table will auto-merge cleanly. Conflicts arise only when two sides modify the same cell — and even then, resolution strategies can be applied automatically.

### Progressive Scale

Federation supports a natural growth path:

| Stage | Topology | Peers | Sync Model |
|-------|----------|-------|------------|
| Solo | None | 0 | Local only |
| Backup | Hub | 1 | Push-only to cloud storage |
| Team | Hub-and-spoke | 2-10 | Bidirectional via shared remote |
| Organization | Hub-and-spoke + peer | 10-50 | Mixed hub and direct peer links |
| Cross-org | Peer-to-peer mesh | 50+ | Selective sync, sovereignty tiers |

Each stage requires zero architectural changes. The same Dolt remote protocol handles all of them. The difference is configuration, not code.

---

## 2. Dolt Remote Protocol

### Push, Pull, Fetch

Federation operations map directly to Dolt's version control primitives:

| Operation | What It Does | Local Effect | Remote Effect |
|-----------|-------------|--------------|---------------|
| **Fetch** | Download remote refs without merging | Updates `peer/main` ref locally | None (read-only) |
| **Pull** | Fetch + three-way merge into local branch | Local branch incorporates remote changes | None |
| **Push** | Upload local commits to remote | None | Remote refs advance to include local commits |
| **Sync** | Auto-commit + fetch + merge + push | Full bidirectional synchronization | Full bidirectional synchronization |

### Three-Way Merge Semantics

Dolt performs three-way merge using the same algorithm as Git, but at cell granularity instead of line granularity.

```
                 Common Ancestor (CA)
                /                    \
        Local (Ours)            Remote (Theirs)
                \                    /
                  Merged Result (M)
```

**Merge algorithm:**
1. Find the common ancestor commit (most recent shared commit between local and remote)
2. Compute diff: `ours vs. ancestor` and `theirs vs. ancestor`
3. For each cell (row + column intersection):
   - Changed only in ours: apply our change
   - Changed only in theirs: apply their change
   - Changed in both, same value: no conflict (convergent edit)
   - Changed in both, different values: **conflict**
   - Deleted in one, modified in other: **conflict**
4. Apply all non-conflicting changes
5. Report conflicts for resolution

### Cell-Level Conflict Resolution

This is Dolt's most important advantage over file-level merge systems.

**Example — same row, different columns (auto-merges):**

| | `title` | `status` | `priority` |
|---|---|---|---|
| Ancestor | "Fix login" | "open" | 2 |
| Instance A | "Fix login bug" | "open" | 2 |
| Instance B | "Fix login" | "active" | 2 |
| **Merged** | **"Fix login bug"** | **"active"** | **2** |

No conflict. Instance A changed `title`, Instance B changed `status`. Both changes are preserved.

**Example — same row, same column (conflict):**

| | `status` |
|---|---|
| Ancestor | "open" |
| Instance A | "active" |
| Instance B | "blocked" |
| **Result** | **CONFLICT** |

Both sides changed `status`. Dolt flags this cell as conflicted.

### Branch Model

```
main ─────●─────●─────●─────●─────●───── (canonical)
                 ↑           ↑
            peer-a/main  peer-b/main      (remote tracking refs)
```

- `main` is the canonical branch. All agents write here. All federation syncs target here.
- `peer-name/main` is the remote tracking ref for each peer (like `origin/main` in Git).
- Feature branches are local-only by default. They can be exposed to peers via explicit configuration, but the default federation surface is `main` only.
- Before any pull, the platform auto-commits pending changes to ensure a clean working set for the merge operation.

---

## 3. Supported Backends

| Backend | URL Format | Use Case | Latency | Auth Mechanism |
|---------|-----------|----------|---------|----------------|
| **DoltHub** | `dolthub://org/repo` | Public/team sharing, open-source collaboration | High (network) | DoltHub OAuth / API key |
| **Amazon S3** | `s3://bucket/path` | Cloud team storage, AWS-native environments | Medium (network) | IAM roles / access keys |
| **Google Cloud Storage** | `gs://bucket/path` | Cloud team storage, GCP-native environments | Medium (network) | Service account / gcloud auth |
| **Filesystem** | `file:///path/to/backup` | Local backup, testing, air-gapped environments | Low (disk I/O) | OS file permissions |
| **SSH** | `ssh://host/path` | Private remote servers, self-hosted | Medium (network) | SSH key pairs |
| **HTTP(S)** | `https://host/path` | Custom Dolt remote servers, corporate proxies | Medium (network) | Basic auth / bearer token |

### Protocol Routing

Not all backends can be accessed through the SQL stored procedure path. The platform routes operations based on the remote URL protocol:

```
Is the remote SSH, git+https, or git:// ?
│
├─ YES → Route to CLI subprocess (dolt push/pull/fetch)
│        CLI inherits SSH keys and git credentials from the user environment
│
└─ NO → Does the peer have stored credentials AND is the server external?
        │
        ├─ YES → Route to CLI subprocess
        │        Credentials passed via cmd.Env (subprocess isolation)
        │
        └─ NO → Route to SQL stored procedure (CALL DOLT_PUSH/PULL/FETCH)
                 5-minute read timeout for large operations
```

This routing is transparent to the user. The CLI commands behave identically regardless of which path is used internally.

---

## 4. Sovereignty Tiers

Sovereignty tiers define the data-sharing relationship between two instances. Each peer relationship has a tier, and the tier governs what data flows and in which direction.

### Enforcement Timing

Phase 1 of the platform implements peer registration and selective table sync ONLY. Full sovereignty tier enforcement is deferred to Phase 2. The rationale: getting data flowing between instances is more valuable than perfecting the access control model. Enforce later, with production data to validate against.

**Tier 4 (anonymous/content-addressed) is explicitly deferred.** It requires a content-addressed identity system that has not been designed. The only production system with sovereignty tiers (Beads) has T4 marked as "NOT IMPLEMENTED." The Hive should implement Tiers 1-3 first, validate them at scale with real federation traffic, and then design T4 based on observed needs.

### Tier 1: Sovereign

Full local control. The instance shares nothing by default and selectively pushes specific tables or branches to specific peers.

| Aspect | Behavior |
|--------|----------|
| Sync direction | Selective push, selective pull |
| Table filtering | Explicit allowlist per peer |
| Incoming changes | Reviewed before merge (no auto-merge) |
| Conflict strategy | Always manual review |
| Best for | Independent developers, sensitive projects, air-gapped environments |

**Configuration:**
```sql
INSERT INTO federation_peers (name, remote_url, sovereignty)
VALUES ('partner-org', 's3://shared-bucket/partner', 'sovereign');

-- Selectively sync only work_items and dependencies
INSERT INTO federation_sync_rules (peer_name, table_name, direction)
VALUES ('partner-org', 'work_items', 'push'),
       ('partner-org', 'dependencies', 'bidirectional');
```

### Tier 2: Federated

Shared remote with automatic merge. Both instances push and pull from a common remote (DoltHub, S3, or similar). Non-conflicting changes merge automatically. Conflicts are resolved via configured strategy.

| Aspect | Behavior |
|--------|----------|
| Sync direction | Bidirectional |
| Table filtering | All federated tables (see Section 5) |
| Incoming changes | Auto-merge for non-conflicts |
| Conflict strategy | Configurable: last-write-wins, ours, theirs, or manual |
| Best for | Teams working on shared projects, organizational collaboration |

**Configuration:**
```sql
INSERT INTO federation_peers (name, remote_url, sovereignty)
VALUES ('team-hub', 'dolthub://org/project', 'federated');
```

### Tier 3: Replicated

One-way sync from a primary instance. The replica receives all changes but never pushes back. Used for read-only dashboards, monitoring, backup, and audit.

| Aspect | Behavior |
|--------|----------|
| Sync direction | Pull-only (primary → replica) |
| Table filtering | All tables or configured subset |
| Incoming changes | Applied without merge (fast-forward only) |
| Conflict strategy | N/A (no local writes to conflict) |
| Best for | Dashboards, monitoring, backup, compliance archives |

**Configuration:**
```sql
INSERT INTO federation_peers (name, remote_url, sovereignty)
VALUES ('production-primary', 'https://primary.internal/dolt', 'replicated');
```

---

## 5. What Federates (and What Doesn't)

Not all data should cross instance boundaries. The platform classifies every table into a federation category.

| Table | Federates? | Rationale |
|-------|-----------|-----------|
| `work_items` | Yes | Core coordination data. Cross-instance visibility into what needs doing. |
| `dependencies` | Yes | Cross-instance blocking. Instance A cannot assess readiness without knowing Instance B's blockers. |
| `agent_scorecards` | Yes | Portable reputation. An agent's track record travels with its identity across instances. |
| `expertise_store` | Yes | Shared learning. Patterns discovered by one instance benefit all federated peers. |
| `formulas` | Yes | Reusable workflows. A formula proven in one instance can be deployed in another. |
| `labels` | Yes | Consistent categorization across instances. |
| `comments` | Yes | Discussion context travels with the work item. |
| `merge_requests` | No | Instance-local merge queue state. Each instance runs its own merge pipeline. |
| `mail` | No | Instance-local agent communication. Messages are consumed locally and have no meaning elsewhere. |
| `sessions` | No | Instance-local runtime state. Session data is ephemeral and tied to local agent processes. |
| `events` | Configurable | Audit trail can be large. Selective sync by date range or event type. |
| `metrics` | Configurable | Cost and usage data may be sensitive. Opt-in per peer. |
| `credentials` | Never | Hard security boundary. Credentials never leave the instance, encrypted or not. |
| `config` | Configurable | Project configuration may or may not be relevant to peers. |
| `metadata` | No | Internal state (sync timestamps, counters). Instance-specific. |

### Sync Rule Schema

```sql
CREATE TABLE federation_sync_rules (
    peer_name       VARCHAR(255) NOT NULL,
    table_name      VARCHAR(255) NOT NULL,
    direction       VARCHAR(16) NOT NULL DEFAULT 'bidirectional'
                    CHECK (direction IN ('push', 'pull', 'bidirectional', 'none')),
    filter_expr     TEXT,              -- optional SQL WHERE clause for row-level filtering
    last_applied    DATETIME,
    PRIMARY KEY (peer_name, table_name),
    FOREIGN KEY (peer_name) REFERENCES federation_peers(name)
);
```

---

## 6. Multi-Instance Topology

### Peer-to-Peer

Each instance pushes and pulls directly to known peers. No central coordination point. Eventual consistency via Dolt three-way merge.

```
┌──────────┐         ┌──────────┐         ┌──────────┐
│Instance A│◄───────►│Instance B│◄───────►│Instance C│
└──────────┘         └──────────┘         └──────────┘
      ▲                                         ▲
      │                                         │
      │              ┌──────────┐               │
      └─────────────►│Instance D│◄──────────────┘
                     └──────────┘
```

**Characteristics:**
- No single point of failure. Any instance can go offline without affecting the rest.
- Each peer relationship is independent. Instance A can sync with B hourly and with D daily.
- Convergence time depends on the longest sync interval in the graph.
- N instances with full mesh = N*(N-1)/2 peer relationships. Practical limit: ~10-15 instances before management overhead dominates.
- Merge conflicts multiply with peer count. Each sync may introduce conflicts that must resolve before the next sync.

**Best for:** Small teams, geographically distributed developers, high-availability requirements.

### Hub-and-Spoke

All instances sync through a central remote (DoltHub, S3 bucket, or dedicated Dolt server). No direct peer-to-peer connections.

```
┌──────────┐         ┌──────────┐         ┌──────────┐
│Instance A│────────►│          │◄────────│Instance B│
└──────────┘         │  DoltHub │         └──────────┘
                     │  (hub)   │
┌──────────┐         │          │         ┌──────────┐
│Instance C│────────►│          │◄────────│Instance D│
└──────────┘         └──────────┘         └──────────┘
```

**Characteristics:**
- Simpler topology. Each instance has exactly one remote to manage.
- Central coordination. The hub is the single source of truth for the latest merged state.
- Single point of failure. If the hub is unavailable, no instance can sync (but all continue operating locally).
- Scales to hundreds of instances. Each instance syncs independently with the hub.
- Conflicts are serialized. The first pusher wins; subsequent pushers must pull, merge, and re-push.

**Best for:** Teams, organizations, open-source projects, any topology where a central remote is acceptable.

### Hybrid: Hub with Peer Shortcuts

Combines hub-and-spoke for organizational sync with direct peer links for low-latency collaboration.

```
┌──────────┐                              ┌──────────┐
│Instance A│◄────────────────────────────►│Instance B│
└──────────┘                              └──────────┘
      │                                         │
      ▼                                         ▼
┌──────────────────────────────────────────────────┐
│                  DoltHub (hub)                    │
└──────────────────────────────────────────────────┘
      ▲                                         ▲
      │                                         │
┌──────────┐                              ┌──────────┐
│Instance C│                              │Instance D│
└──────────┘                              └──────────┘
```

Instances A and B sync directly for fast iteration. All four instances sync through the hub for organizational convergence. The hub sees the merged result of A+B; C and D receive it on their next pull.

---

## 7. Sync Protocol

### Full Sync Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        SYNC (bidirectional)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Step 0: AUTO-COMMIT                                             │
│  ├─ Commit any pending local changes                             │
│  └─ Required: Dolt needs a clean working set for merge           │
│                                                                  │
│  Step 1: FETCH                                                   │
│  ├─ Download remote refs (commit hashes)                         │
│  ├─ Compare with local refs                                      │
│  ├─ Download missing content-addressed chunks                    │
│  └─ Update local tracking ref: peer/main                         │
│                                                                  │
│  Step 2: MERGE (three-way)                                       │
│  ├─ Find common ancestor (CA)                                    │
│  ├─ Compute diff: ours vs. CA                                    │
│  ├─ Compute diff: theirs vs. CA                                  │
│  ├─ Apply non-conflicting changes (cell-level auto-merge)        │
│  ├─ If conflicts exist:                                          │
│  │   ├─ Strategy specified? → Auto-resolve (ours/theirs)         │
│  │   └─ No strategy? → Pause, report conflicts for manual review │
│  └─ Commit merge result                                          │
│                                                                  │
│  Step 3: PUSH                                                    │
│  ├─ Compute local commits since last push                        │
│  ├─ Upload new content-addressed chunks                          │
│  ├─ Update remote refs                                           │
│  ├─ If remote has advanced since fetch:                          │
│  │   └─ Push fails → caller must re-pull and retry               │
│  └─ Push failure is NON-FATAL (logged, not blocking)             │
│                                                                  │
│  Step 4: RECORD                                                  │
│  └─ Store last_sync timestamp in metadata table                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Pull-Only Flow (Replicated Tier)

```
Step 0: AUTO-COMMIT (if not read-only)
Step 1: FETCH
Step 2: FAST-FORWARD (no merge — replica has no local changes)
Step 4: RECORD
```

No push. No merge conflicts. The replica is always a clean copy of the primary's state.

### Sync Result

Every sync operation returns a structured result:

```sql
CREATE TABLE sync_log (
    id              CHAR(36) PRIMARY KEY,        -- UUID
    peer_name       VARCHAR(255) NOT NULL,
    started_at      DATETIME NOT NULL,
    completed_at    DATETIME,
    fetched         BOOLEAN NOT NULL DEFAULT FALSE,
    merged          BOOLEAN NOT NULL DEFAULT FALSE,
    pushed          BOOLEAN NOT NULL DEFAULT FALSE,
    pulled_commits  INT NOT NULL DEFAULT 0,
    pushed_commits  INT NOT NULL DEFAULT 0,
    conflicts_found INT NOT NULL DEFAULT 0,
    conflicts_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    resolution_strategy VARCHAR(16),             -- 'ours', 'theirs', 'manual', NULL
    error_message   TEXT,                         -- fatal error (NULL = success)
    push_error      TEXT,                         -- non-fatal push error
    FOREIGN KEY (peer_name) REFERENCES federation_peers(name)
);
```

The distinction between `error_message` (fatal) and `push_error` (non-fatal) is important: a push failure does not roll back the fetch and merge. The local database has already incorporated the peer's changes even if pushing back fails.

---

## 8. Cross-Instance Work Routing

### The Problem

Instance A has a work item that requires expertise only available in Instance B's agent pool. Without federation, the human must manually copy the work item, wait for results, and copy them back. With federation, the platform handles this automatically.

### Routing Model

Work items gain an optional `route_to` field that specifies a target instance:

```sql
ALTER TABLE work_items ADD COLUMN route_to VARCHAR(255);
-- NULL = local work, 'peer-name' = route to that peer on next sync
```

### Routing Flow

```
Instance A                              Instance B
──────────                              ──────────
1. Create work item
   route_to = 'instance-b'
   status = 'routed'

2. SYNC with Instance B
   ─────── work item travels ──────►

                                        3. Coordinator sees routed item
                                           Checks: do we have a matching agent?
                                        4. YES: assign to local agent
                                           NO:  use best-match agent
                                        5. Agent completes work
                                           status = 'resolved'
                                           route_to = NULL

6. SYNC with Instance B
   ◄────── result travels back ────

7. See resolved work item
   with results from Instance B
```

### Routing Rules

- Routed items retain their original `id` and `content_hash`. They are the same work item, not a copy.
- The receiving instance's coordinator is responsible for dispatch. It uses the same assignment logic as local work.
- If the receiving instance has no suitable agent, the work item stays in `routed` status until the next sync, when it can be re-routed or recalled.
- Routing is not transitive. Instance B cannot re-route to Instance C without explicit configuration.
- Cross-instance work counts toward the completing agent's scorecard, which syncs back via federation.

---

## 9. Agent Portability

### Identity Travels with Federation

Agent identity is stored in the `work_items` table (type = 'agent') and the `agent_scorecards` table. Both tables are in the federated set. When two instances sync, they share agent identity and reputation data.

```sql
-- Agent identity in work_items
SELECT id, title, assignee, metadata
FROM work_items
WHERE type = 'agent';

-- Scorecard in agent_scorecards
SELECT agent_id, tasks_completed, avg_quality_score,
       avg_speed_score, specializations, last_active
FROM agent_scorecards;
```

### Portability Scenarios

**Scenario 1: Known agent, available locally**
Instance B receives work from Instance A, assigned to `builder-alpha`. Instance B has a local `builder-alpha` with the same identity. Work is assigned directly.

**Scenario 2: Known agent, not available locally**
Instance B receives work assigned to `builder-alpha` but has no local agent with that identity. Instance B creates a stub entry for `builder-alpha` and assigns the work to its best-match local agent (based on specialization overlap from the scorecard). Results are attributed to the local agent; the stub entry links back to the original.

**Scenario 3: Reputation precedes the agent**
Instance B has never seen `builder-alpha` but has its scorecard from a previous sync. When evaluating whether to accept routed work, Instance B can assess `builder-alpha`'s track record before the work arrives.

### Scorecard Sync

Scorecards use an append-and-merge model:

| Field | Merge Strategy | Rationale |
|-------|---------------|-----------|
| `tasks_completed` | Sum (CRDT counter) | Monotonically increasing across instances |
| `avg_quality_score` | Weighted average by task count | Fair aggregation across different workloads |
| `avg_speed_score` | Weighted average by task count | Same |
| `specializations` | Set union | Agent may specialize in different areas on different instances |
| `last_active` | Max (latest timestamp) | Most recent activity wins |
| `total_sessions` | Sum (CRDT counter) | Monotonically increasing |
| `failure_count` | Sum (CRDT counter) | Monotonically increasing |

---

## 10. Content-Addressed Dedup

### How It Works

All Dolt data is stored as content-addressed chunks. Each chunk's address is the SHA-256 hash of its contents. This provides automatic deduplication at the storage layer.

```
Chunk Store (noms/)
├── ab3f...  → [row data for work items 1-50]
├── c7d2...  → [row data for work items 51-100]
├── e91a...  → [schema metadata]
├── f4b8...  → [commit object pointing to ab3f, c7d2, e91a]
└── ...
```

### Sync Efficiency

When syncing between instances, the protocol compares chunk addresses:

```
Instance A chunks:  {ab3f, c7d2, e91a, f4b8, NEW1, NEW2}
Instance B chunks:  {ab3f, c7d2, e91a, f4b8, NEW3, NEW4}
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                     Shared — zero transfer

Transfer A→B: {NEW1, NEW2}  (only new chunks)
Transfer B→A: {NEW3, NEW4}  (only new chunks)
```

### Implications

- **Initial sync** of a large database transfers the full chunk store. This is network-bound at approximately 1-10 Mbps depending on the backend.
- **Subsequent syncs** transfer only new chunks. For typical agent workloads (dozens of work item updates per hour), this is kilobytes per sync.
- **Identical data** created independently on two instances (e.g., the same formula with the same content) will share chunks after sync, with zero additional transfer.
- **Compaction** periodically reorganizes chunks for efficiency, reducing the total chunk count and improving sync performance over time.
- **Tamper detection** is inherent. Any modification to chunk content changes its hash, breaking the chain. A corrupted or malicious chunk will fail verification during sync.

---

## 11. Security Model

### Credential Encryption

Federation credentials are encrypted at rest using AES-256-GCM. The encryption key is a random 32-byte value stored in a dedicated key file with owner-only permissions (0600).

```
.platform/
    .credential-key              # 32-byte random AES-256 key (mode 0600)
    dolt/
        <database>/
            .dolt/
                noms/            # Content-addressed chunk store
                config           # CLI remote config
```

**Key management:**
- Key is generated on first peer addition (random 32 bytes from crypto/rand)
- Key never leaves the local filesystem
- Key file permissions are enforced on every access (0600 / owner-only)
- If key is lost, all stored credentials must be re-entered

### Per-Backend Authentication

| Backend | Credential Type | Storage |
|---------|----------------|---------|
| DoltHub | OAuth token / API key | `federation_peers.password_encrypted` |
| S3 | AWS access key + secret | IAM role (preferred) or `federation_peers` |
| GCS | Service account JSON | gcloud auth (preferred) or `federation_peers` |
| SSH | SSH key pair | User's `~/.ssh/` directory |
| HTTP(S) | Username + password | `federation_peers.password_encrypted` |
| Filesystem | None | OS file permissions |

### Access Control

**Current implementation:**
- Table-level access control via `federation_sync_rules` (which tables sync with which peers)
- Direction control (push/pull/bidirectional/none) per table per peer
- Sovereignty tiers (see Section 4) govern the overall relationship

**Future (planned):**
- Row-level filtering via `filter_expr` in `federation_sync_rules` (SQL WHERE clause applied before push)
- Column-level exclusion for sensitive fields (e.g., strip `internal_notes` before syncing)
- Signed commits (cryptographic verification of data provenance)

### Audit Log

All sync operations are recorded in the `sync_log` table (see Section 7). This provides:
- Complete history of what was synced, when, and with whom
- Error and conflict records for forensic analysis
- Compliance evidence for regulated environments

### Hard Security Boundaries

The following data NEVER crosses instance boundaries, regardless of sovereignty tier or sync configuration:

| Data | Reason |
|------|--------|
| Credential key file | Encryption root of trust |
| `federation_peers.password_encrypted` | Peer authentication secrets |
| API keys and tokens in `config` | Service access credentials |
| Session tokens | Ephemeral runtime authentication |
| Local file paths | Environment-specific, potential information leak |

---

## 12. Conflict Resolution for Federated Data

### Cell-Level Merge (The Dolt Advantage)

Most sync operations produce zero conflicts because Dolt merges at cell granularity. Two instances modifying different aspects of the same work item will auto-merge cleanly.

**Auto-merge examples (no conflict):**

| Instance A Changes | Instance B Changes | Result |
|---|---|---|
| Updates `title` on item X | Updates `status` on item X | Both applied |
| Creates item Y | Creates item Z | Both items exist |
| Adds label "urgent" to item X | Adds dependency X→W | Both applied |
| Updates `priority` on item X | Adds comment to item X | Both applied |

**Conflict examples (requires resolution):**

| Instance A Changes | Instance B Changes | Conflict |
|---|---|---|
| Sets `status = "active"` on item X | Sets `status = "blocked"` on item X | Same cell |
| Deletes item X | Updates item X | Delete vs. modify |
| Sets `priority = 1` on item X | Sets `priority = 3` on item X | Same cell |

### Resolution Strategies

| Strategy | Behavior | Best For |
|----------|----------|----------|
| `ours` | Keep local value, discard remote | Sovereign instances, local authority |
| `theirs` | Accept remote value, discard local | Replicated instances, defer to primary |
| `last-write-wins` | Compare timestamps, keep most recent | Federated instances, general use |
| `manual` | Flag conflict, pause sync, wait for human | Critical data, cannot afford wrong resolution |

### Conflict-Free Data Types

Some fields can use conflict-free merge strategies that never produce conflicts:

| Field Type | Strategy | Example |
|------------|----------|---------|
| Counters | CRDT increment (sum both deltas) | `retry_count`, `sessions_completed`, `tasks_completed` |
| Sets | Union (keep all additions from both sides) | `labels`, `specializations` |
| Timestamps | Max (most recent) | `last_active`, `updated_at` |
| Append-only | Concatenate | `comments` (ordered by `created_at`) |

### Per-Table Default Strategies

| Table | Default Strategy | Rationale |
|-------|-----------------|-----------|
| `work_items` | `last-write-wins` | Most recent update reflects current state |
| `dependencies` | `union` | Both dependency additions are intentional |
| `labels` | `union` | Both label additions are intentional |
| `comments` | `append` | Comments are append-only; no conflicts possible |
| `agent_scorecards` | `crdt` | Counters sum, sets union, timestamps max |
| `expertise_store` | `last-write-wins` | Latest expertise entry is most relevant |
| `formulas` | `last-write-wins` | Most recent version wins |
| `metadata` | `theirs` | Sync metadata should converge to remote value |
| `config` | `manual` | Configuration changes require human review |

---

## 13. CLI Commands

### Remote Management

```bash
# Add a federation peer
platform federation remote add <name> <url> [--sovereignty sovereign|federated|replicated]
# Example:
platform federation remote add team-hub dolthub://org/project --sovereignty federated

# Add a peer with credentials
platform federation remote add partner s3://bucket/partner \
    --user admin --password        # password prompted interactively

# List all configured peers
platform federation remote list
# Output:
#   NAME         URL                          SOVEREIGNTY  LAST SYNC
#   team-hub     dolthub://org/project        federated    2026-03-18T14:30:00Z
#   partner      s3://bucket/partner          sovereign    2026-03-17T09:15:00Z
#   backup       file:///mnt/backup/dolt      replicated   never

# Remove a peer and its stored credentials
platform federation remote remove <name>
```

### Sync Operations

```bash
# Pull from a specific peer (fetch + merge)
platform federation pull [<remote>]
# Without argument: pull from all peers

# Push to a specific peer
platform federation push [<remote>]
# Without argument: push to all peers (except replicated)

# Full bidirectional sync (auto-commit + pull + push)
platform federation sync [<remote>]
# Without argument: sync with all peers

# Sync with conflict resolution strategy
platform federation sync team-hub --strategy theirs
```

### Conflict Resolution

```bash
# List current merge conflicts
platform federation conflicts list
# Output:
#   TABLE        ROW ID       COLUMN      OURS          THEIRS
#   work_items   wi-a1b2c3    status      active        blocked
#   work_items   wi-d4e5f6    priority    1             3

# Resolve a specific conflict
platform federation conflicts resolve wi-a1b2c3 --strategy ours
# Keeps local value ("active"), discards remote ("blocked")

# Resolve all conflicts for a table
platform federation conflicts resolve --table work_items --strategy theirs

# Resolve all conflicts
platform federation conflicts resolve --all --strategy last-write-wins
```

### Status and Diagnostics

```bash
# Show sync state with all remotes
platform federation status
# Output:
#   PEER         STATUS       AHEAD  BEHIND  CONFLICTS  LAST SYNC
#   team-hub     connected    3      7       0          2 minutes ago
#   partner      connected    0      0       0          1 hour ago
#   backup       unreachable  12     ?       0          2 days ago

# Show sync state with a specific peer
platform federation status team-hub

# Show sync history
platform federation log
# Output:
#   TIME                   PEER       PULLED  PUSHED  CONFLICTS  RESULT
#   2026-03-18T14:30:00Z   team-hub   7       3       0          success
#   2026-03-18T13:15:00Z   team-hub   2       5       1          resolved (theirs)
#   2026-03-17T09:15:00Z   partner    0       12      0          success

# Show detailed log for a specific sync
platform federation log --peer team-hub --limit 20

# Health check (connectivity, configuration, credential validity)
platform federation doctor
```

### Sync Rules

```bash
# Configure which tables sync with a peer
platform federation rules set team-hub work_items bidirectional
platform federation rules set team-hub credentials none
platform federation rules set team-hub events pull   # receive events but don't push ours

# List sync rules for a peer
platform federation rules list team-hub
# Output:
#   TABLE           DIRECTION       FILTER
#   work_items      bidirectional   -
#   dependencies    bidirectional   -
#   scorecards      bidirectional   -
#   events          pull            created_at > '2026-01-01'
#   credentials     none            -
```

---

## 14. Federation Peers Schema

```sql
CREATE TABLE federation_peers (
    name                VARCHAR(255) PRIMARY KEY,
    remote_url          VARCHAR(1024) NOT NULL,
    username            VARCHAR(255),
    password_encrypted  BLOB,
    sovereignty         VARCHAR(16) NOT NULL DEFAULT 'federated'
                        CHECK (sovereignty IN ('sovereign', 'federated', 'replicated')),
    auto_sync           BOOLEAN NOT NULL DEFAULT FALSE,
    sync_interval_sec   INT DEFAULT 3600,          -- default: 1 hour
    conflict_strategy   VARCHAR(16) DEFAULT 'last-write-wins'
                        CHECK (conflict_strategy IN (
                            'ours', 'theirs', 'last-write-wins', 'manual'
                        )),
    last_sync           DATETIME,
    last_sync_result    VARCHAR(16),                -- 'success', 'conflict', 'error'
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                        ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_federation_peers_sovereignty (sovereignty)
);
```

**Peer name constraints:** Must match `^[a-zA-Z][a-zA-Z0-9_-]*$` (start with letter, alphanumeric with hyphens and underscores, max 64 characters).

---

## 15. Distributed Reputation (Stamps)

### What Stamps Are

Stamps are multi-dimensional reputation attestations. When a Worker completes work and that work is reviewed, the reviewer (or coordinator) can stamp the Worker's contribution with a quality assessment. Unlike simple numeric scores, stamps capture which dimension of quality is being attested (code quality, speed, correctness, collaboration) and link to specific evidence.

### Yearbook Constraint

A Worker cannot stamp its own work. This is enforced at the database level:

```sql
CREATE TABLE stamps (
    id              CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    stamper_id      VARCHAR(255) NOT NULL,
    stampee_id      VARCHAR(255) NOT NULL,
    cell_id         VARCHAR(255) NOT NULL,      -- the work item being attested
    dimension       VARCHAR(64) NOT NULL,        -- 'quality', 'speed', 'correctness', 'collaboration'
    score           REAL NOT NULL CHECK (score BETWEEN 0.0 AND 1.0),
    evidence_id     VARCHAR(255),                -- link to review, merge, or audit record
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CHECK (stamper_id != stampee_id),            -- yearbook constraint
    INDEX idx_stamps_stampee (stampee_id),
    INDEX idx_stamps_cell (cell_id),
    INDEX idx_stamps_dimension (dimension)
);
```

The `CHECK (stamper_id != stampee_id)` constraint is the yearbook rule -- named because you cannot sign your own yearbook. This prevents reputation inflation and ensures that all reputation is externally validated.

### Trust Levels

Stamps accumulate into trust levels that determine an agent's privileges in federated operations:

| Level | Name | Criteria | Privileges |
|-------|------|----------|------------|
| 0 | Registered | Agent exists in the system | Can claim local work only |
| 1 | Participant | 5+ stamps with avg score > 0.3 | Can receive routed work from peers |
| 2 | Contributor | 20+ stamps with avg score > 0.5 | Can route work to other instances |
| 3 | Maintainer | 50+ stamps with avg score > 0.7, no security violations | Can approve cross-instance merges |

Trust levels are computed, not assigned. When stamps sync via federation, trust levels are recalculated at the receiving instance using its own thresholds.

### Phase 1 Bootstrapping

In Phase 1, stamps are local-only claims. They are stored in the stamps table, which is in the federated table set, but cross-Colony propagation happens only via explicit Dolt push/pull operations. There is no automatic stamp gossip protocol. This is intentional -- reputation propagation at scale requires careful design around Sybil resistance and trust transitivity, which are Phase 2 concerns.

---

## 16. Operational Concerns

### Automatic Sync Scheduling

Manual sync (`platform federation sync`) is always available. Automatic sync adds periodic synchronization:

```sql
-- Enable auto-sync with a peer every 30 minutes
UPDATE federation_peers
SET auto_sync = TRUE, sync_interval_sec = 1800
WHERE name = 'team-hub';
```

When auto-sync is enabled, the platform's background scheduler triggers sync at the configured interval. The scheduler respects:
- Backoff on repeated failures (exponential, max 1 hour)
- Skip if a sync is already in progress with this peer
- Skip if the peer is unreachable (checked via fetch before full sync)

### Bandwidth Considerations

| Scenario | Approximate Transfer | Notes |
|----------|---------------------|-------|
| Initial sync (empty → full) | Full database size | Network-bound, potentially gigabytes |
| Routine sync (hourly) | Kilobytes to low megabytes | Only new chunks since last sync |
| After compaction | May increase temporarily | Reorganized chunks have new hashes |
| Idle (no changes) | Near zero | Only ref comparison |

### Failure Modes

| Failure | Impact | Recovery |
|---------|--------|----------|
| Network interruption during fetch | No local changes | Retry on next sync |
| Network interruption during push | Local has remote changes, remote lacks local | Re-push on next sync |
| Conflict with no strategy | Sync pauses, conflicts reported | Manual resolution or retry with strategy |
| Credential expiration | Auth failure, sync blocked | Re-enter credentials via `remote add` |
| Corrupted chunk store | Sync fails with hash mismatch | Re-clone from peer or backup |
| Peer permanently offline | Sync attempts fail indefinitely | Remove peer or wait |

### Monitoring

The platform exposes federation metrics for observability:

| Metric | Type | Description |
|--------|------|-------------|
| `federation.sync.duration` | Histogram | Time to complete sync with each peer |
| `federation.sync.pulled_commits` | Counter | Total commits pulled across all peers |
| `federation.sync.pushed_commits` | Counter | Total commits pushed across all peers |
| `federation.sync.conflicts` | Counter | Total conflicts encountered |
| `federation.sync.errors` | Counter | Total sync errors |
| `federation.chunks.transferred` | Counter | Total chunks transferred |
| `federation.peers.reachable` | Gauge | Number of currently reachable peers |
