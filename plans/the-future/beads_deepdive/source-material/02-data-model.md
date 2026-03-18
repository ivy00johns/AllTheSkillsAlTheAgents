# 02 -- Data Model

Part of the [Beads Deep Dive](00-INDEX.md) series.
Generated 2026-03-17 from steveyegge/beads v0.61.0.

---

## Overview

The beads data model centers on a single wide `issues` table (~50 columns) that
stores all issue variants. This document provides a complete column-by-column
reference, all supporting tables, views, type constants, and validation rules.

Primary source files:
- `internal/storage/dolt/schema.go` -- SQL DDL, views, defaults (schema version 8)
- `internal/types/types.go` -- Go struct definitions, constants, validation

---

## The `issues` Table

All issue variants share one table with sparse columns. The current schema
version is **8** (`currentSchemaVersion` in `schema.go`).

### Identity Columns

| Column | SQL Type | Default | Go Field | Purpose |
|--------|----------|---------|----------|---------|
| `id` | `VARCHAR(255)` PK | -- | `ID string` | Hash-based (`bd-x8f2k`) or counter-based (`bd-42`) |
| `content_hash` | `VARCHAR(64)` | -- | `ContentHash string` | SHA-256 of canonical content for dedup across clones |

### Content Columns

| Column | SQL Type | Default | Go Field | Purpose |
|--------|----------|---------|----------|---------|
| `title` | `VARCHAR(500) NOT NULL` | -- | `Title string` | Required. Max 500 chars |
| `description` | `TEXT NOT NULL` | -- | `Description string` | Full description body |
| `design` | `TEXT NOT NULL` | -- | `Design string` | Design/architecture notes |
| `acceptance_criteria` | `TEXT NOT NULL` | -- | `AcceptanceCriteria string` | Completion criteria |
| `notes` | `TEXT NOT NULL` | -- | `Notes string` | Free-form notes |
| `spec_id` | `VARCHAR(1024)` | -- | `SpecID string` | External specification reference |

### Workflow Columns

| Column | SQL Type | Default | Go Field | Purpose |
|--------|----------|---------|----------|---------|
| `status` | `VARCHAR(32) NOT NULL` | `'open'` | `Status Status` | Current state (see Status Constants below) |
| `priority` | `INT NOT NULL` | `2` | `Priority int` | 0 (P0/critical) through 4 (P4/lowest). 0 is valid, not "unset" |
| `issue_type` | `VARCHAR(32) NOT NULL` | `'task'` | `IssueType IssueType` | Type classification (see IssueType Constants below) |
| `assignee` | `VARCHAR(255)` | NULL | `Assignee string` | Currently assigned worker |
| `owner` | `VARCHAR(255)` | `''` | `Owner string` | Human owner for CV attribution (git author email) |
| `estimated_minutes` | `INT` | NULL | `EstimatedMinutes *int` | Effort estimate. Cannot be negative |

### Timestamp Columns

| Column | SQL Type | Default | Go Field | Purpose |
|--------|----------|---------|----------|---------|
| `created_at` | `DATETIME NOT NULL` | `CURRENT_TIMESTAMP` | `CreatedAt time.Time` | Row creation time |
| `created_by` | `VARCHAR(255)` | `''` | `CreatedBy string` | Who created this issue (GH#748) |
| `updated_at` | `DATETIME NOT NULL` | `CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` | `UpdatedAt time.Time` | Auto-updated on any change |
| `closed_at` | `DATETIME` | NULL | `ClosedAt *time.Time` | Set when status becomes `closed`. Invariant: set iff status=closed |
| `closed_by_session` | `VARCHAR(255)` | `''` | `ClosedBySession string` | Claude Code session that closed this issue |
| `close_reason` | `TEXT` | `''` | `CloseReason string` | Reason provided when closing (checked for failure keywords) |
| `due_at` | `DATETIME` | NULL | `DueAt *time.Time` | When this issue should be completed (GH#820) |
| `defer_until` | `DATETIME` | NULL | `DeferUntil *time.Time` | Hide from `bd ready` until this time (GH#820) |

### External Integration Columns

| Column | SQL Type | Default | Go Field | Purpose |
|--------|----------|---------|----------|---------|
| `external_ref` | `VARCHAR(255)` | NULL | `ExternalRef *string` | External system reference (e.g., `gh-9`, `jira-ABC`) |
| `source_system` | `VARCHAR(255)` | `''` | `SourceSystem string` | Adapter/system that created this issue (federation) |
| `source_repo` | `VARCHAR(512)` | `''` | `SourceRepo string` | Which repo owns this issue (multi-repo support) |
| `metadata` | `JSON` | `JSON_OBJECT()` | `Metadata json.RawMessage` | Arbitrary JSON for extension points (GH#1406) |

### Compaction Columns

| Column | SQL Type | Default | Go Field | Purpose |
|--------|----------|---------|----------|---------|
| `compaction_level` | `INT` | `0` | `CompactionLevel int` | How many times this issue has been compacted |
| `compacted_at` | `DATETIME` | NULL | `CompactedAt *time.Time` | When last compaction occurred |
| `compacted_at_commit` | `VARCHAR(64)` | NULL | `CompactedAtCommit *string` | Git commit hash at compaction time |
| `original_size` | `INT` | NULL | `OriginalSize int` | Pre-compaction content size in bytes |

### Messaging Columns

| Column | SQL Type | Default | Go Field | Purpose |
|--------|----------|---------|----------|---------|
| `sender` | `VARCHAR(255)` | `''` | `Sender string` | Who sent this (for message-type beads) |
| `ephemeral` | `TINYINT(1)` | `0` | `Ephemeral bool` | If true, stored in wisps table (not version-tracked) |
| `no_history` | `TINYINT(1)` | `0` | `NoHistory bool` | Stored in wisps table but NOT GC-eligible (GH#2619) |
| `wisp_type` | `VARCHAR(32)` | `''` | `WispType WispType` | Classification for TTL-based compaction (gt-9br) |

Validation: `ephemeral` and `no_history` are mutually exclusive.

### Context Columns

| Column | SQL Type | Default | Go Field | Purpose |
|--------|----------|---------|----------|---------|
| `pinned` | `TINYINT(1)` | `0` | `Pinned bool` | Persistent context marker. Not a work item. Status `pinned` |
| `is_template` | `TINYINT(1)` | `0` | `IsTemplate bool` | Read-only template molecule |

### Economics Columns (HOP)

| Column | SQL Type | Default | Go Field | Purpose |
|--------|----------|---------|----------|---------|
| `crystallizes` | `TINYINT(1)` | `0` | `Crystallizes bool` | Work that compounds (code, features) vs evaporates (ops, support). Affects CV weighting per Decision 006 |
| `mol_type` | `VARCHAR(32)` | `''` | `MolType MolType` | Molecule type: `swarm`, `patrol`, `work` |
| `work_type` | `VARCHAR(32)` | `'mutex'` | `WorkType WorkType` | Assignment model: `mutex` (exclusive) or `open_competition` (many submit, buyer picks) |
| `quality_score` | `DOUBLE` | NULL | `QualityScore *float32` | Aggregate quality 0.0-1.0, set by Refineries on merge |

### Event Columns

| Column | SQL Type | Default | Go Field | Purpose |
|--------|----------|---------|----------|---------|
| `event_kind` | `VARCHAR(32)` | `''` | `EventKind string` | Namespaced event type: `patrol.muted`, `agent.started` |
| `actor` | `VARCHAR(255)` | `''` | `Actor string` | Entity URI who caused this event |
| `target` | `VARCHAR(255)` | `''` | `Target string` | Entity URI or bead ID affected |
| `payload` | `TEXT` | `''` | `Payload string` | Event-specific JSON data |

### Gate Columns

| Column | SQL Type | Default | Go Field | Purpose |
|--------|----------|---------|----------|---------|
| `await_type` | `VARCHAR(32)` | `''` | `AwaitType string` | Condition type: `gh:run`, `gh:pr`, `timer`, `human`, `mail` |
| `await_id` | `VARCHAR(255)` | `''` | `AwaitID string` | Condition identifier (run ID, PR number, etc.) |
| `timeout_ns` | `BIGINT` | `0` | `Timeout time.Duration` | Max wait time before escalation (nanoseconds in SQL, Duration in Go) |
| `waiters` | `TEXT` | `''` | `Waiters []string` | Mail addresses to notify when gate clears |

### Agent Columns

| Column | SQL Type | Default | Go Field | Purpose |
|--------|----------|---------|----------|---------|
| `hook_bead` | `VARCHAR(255)` | `''` | `HookBead string` | Current work on agent's hook (0..1 cardinality) |
| `role_bead` | `VARCHAR(255)` | `''` | `RoleBead string` | Role definition bead (required for agent beads) |
| `agent_state` | `VARCHAR(32)` | `''` | `AgentState AgentState` | Self-reported agent state (see AgentState Constants) |
| `last_activity` | `DATETIME` | NULL | `LastActivity *time.Time` | Updated on each action (timeout detection) |
| `role_type` | `VARCHAR(32)` | `''` | `RoleType string` | Agent role type (application-defined) |
| `rig` | `VARCHAR(255)` | `''` | `Rig string` | Rig name (empty for town-level agents) |

### Indexes on `issues`

| Index Name | Columns |
|-----------|---------|
| `PRIMARY KEY` | `id` |
| `idx_issues_status` | `status` |
| `idx_issues_priority` | `priority` |
| `idx_issues_issue_type` | `issue_type` |
| `idx_issues_assignee` | `assignee` |
| `idx_issues_created_at` | `created_at` |
| `idx_issues_spec_id` | `spec_id` |
| `idx_issues_external_ref` | `external_ref` |

---

## The `dependencies` Table

The dependency table stores directed edges between issues. It is the foundation
of the blocking/ready work system and all relationship tracking.

| Column | SQL Type | Default | Go Field | Purpose |
|--------|----------|---------|----------|---------|
| `issue_id` | `VARCHAR(255) NOT NULL` | -- | `IssueID string` | Source issue (the one that depends) |
| `depends_on_id` | `VARCHAR(255) NOT NULL` | -- | `DependsOnID string` | Target issue (the one depended upon). **No FK** -- allows `external:<rig>:<id>` |
| `type` | `VARCHAR(32) NOT NULL` | `'blocks'` | `Type DependencyType` | Relationship type (see 22 types below) |
| `created_at` | `DATETIME NOT NULL` | `CURRENT_TIMESTAMP` | `CreatedAt time.Time` | When the dependency was created |
| `created_by` | `VARCHAR(255) NOT NULL` | -- | `CreatedBy string` | Who created it |
| `metadata` | `JSON` | `JSON_OBJECT()` | `Metadata string` | Type-specific edge data (similarity scores, approval details, skill proficiency) |
| `thread_id` | `VARCHAR(255)` | `''` | `ThreadID string` | Groups conversation edges for thread queries |

### Keys and Indexes

| Index | Columns | Type |
|-------|---------|------|
| `PRIMARY KEY` | `(issue_id, depends_on_id)` | Composite PK |
| `fk_dep_issue` | `issue_id` | FK -> `issues(id) ON DELETE CASCADE` |
| `idx_dependencies_issue` | `issue_id` | Index |
| `idx_dependencies_depends_on` | `depends_on_id` | Index |
| `idx_dependencies_depends_on_type` | `(depends_on_id, type)` | Compound index |
| `idx_dependencies_thread` | `thread_id` | Index |

Note: No FK on `depends_on_id`. This is deliberate -- cross-rig references
use the `external:<rig>:<id>` format, which would violate a foreign key constraint.

---

## All Other Tables

### `labels`

| Column | SQL Type | Notes |
|--------|----------|-------|
| `issue_id` | `VARCHAR(255) NOT NULL` | PK part 1, FK -> `issues(id) ON DELETE CASCADE` |
| `label` | `VARCHAR(255) NOT NULL` | PK part 2 |

Index: `idx_labels_label` on `label`.

### `comments`

| Column | SQL Type | Notes |
|--------|----------|-------|
| `id` | `CHAR(36) NOT NULL` | PK, `DEFAULT (UUID())` |
| `issue_id` | `VARCHAR(255) NOT NULL` | FK -> `issues(id) ON DELETE CASCADE` |
| `author` | `VARCHAR(255) NOT NULL` | |
| `text` | `TEXT NOT NULL` | |
| `created_at` | `DATETIME NOT NULL` | `DEFAULT CURRENT_TIMESTAMP` |

Indexes: `idx_comments_issue`, `idx_comments_created_at`.

### `events`

Audit trail for all issue mutations.

| Column | SQL Type | Notes |
|--------|----------|-------|
| `id` | `CHAR(36) NOT NULL` | PK, `DEFAULT (UUID())` |
| `issue_id` | `VARCHAR(255) NOT NULL` | FK -> `issues(id) ON DELETE CASCADE` |
| `event_type` | `VARCHAR(32) NOT NULL` | See EventType constants |
| `actor` | `VARCHAR(255) NOT NULL` | |
| `old_value` | `TEXT` | Previous field value |
| `new_value` | `TEXT` | New field value |
| `comment` | `TEXT` | Optional comment |
| `created_at` | `DATETIME NOT NULL` | `DEFAULT CURRENT_TIMESTAMP` |

Indexes: `idx_events_issue`, `idx_events_created_at`.

### `config`

Key-value configuration store.

| Column | SQL Type | Notes |
|--------|----------|-------|
| `` `key` `` | `VARCHAR(255)` | PK |
| `value` | `TEXT NOT NULL` | |

Default config entries (inserted via `INSERT IGNORE`):

| Key | Default Value |
|-----|---------------|
| `compaction_enabled` | `false` |
| `compact_tier1_days` | `30` |
| `compact_tier1_dep_levels` | `2` |
| `compact_tier2_days` | `90` |
| `compact_tier2_dep_levels` | `5` |
| `compact_tier2_commits` | `100` |
| `compact_batch_size` | `50` |
| `compact_parallel_workers` | `5` |
| `auto_compact_enabled` | `false` |

### `metadata`

Internal key-value store (separate from user-facing config).

| Column | SQL Type | Notes |
|--------|----------|-------|
| `` `key` `` | `VARCHAR(255)` | PK |
| `value` | `TEXT NOT NULL` | |

### `child_counters`

Tracks child issue numbering for hierarchical ID generation.

| Column | SQL Type | Notes |
|--------|----------|-------|
| `parent_id` | `VARCHAR(255)` | PK, FK -> `issues(id) ON DELETE CASCADE` |
| `last_child` | `INT NOT NULL` | `DEFAULT 0` |

### `issue_snapshots`

Archives original content during compaction.

| Column | SQL Type | Notes |
|--------|----------|-------|
| `id` | `CHAR(36) NOT NULL` | PK, `DEFAULT (UUID())` |
| `issue_id` | `VARCHAR(255) NOT NULL` | FK -> `issues(id) ON DELETE CASCADE` |
| `snapshot_time` | `DATETIME NOT NULL` | |
| `compaction_level` | `INT NOT NULL` | |
| `original_size` | `INT NOT NULL` | |
| `compressed_size` | `INT NOT NULL` | |
| `original_content` | `TEXT NOT NULL` | |
| `archived_events` | `TEXT` | |

Indexes: `idx_snapshots_issue`, `idx_snapshots_level`.

### `compaction_snapshots`

Stores full JSON snapshots for compaction recovery.

| Column | SQL Type | Notes |
|--------|----------|-------|
| `id` | `CHAR(36) NOT NULL` | PK, `DEFAULT (UUID())` |
| `issue_id` | `VARCHAR(255) NOT NULL` | FK -> `issues(id) ON DELETE CASCADE` |
| `compaction_level` | `INT NOT NULL` | |
| `snapshot_json` | `BLOB NOT NULL` | |
| `created_at` | `DATETIME NOT NULL` | `DEFAULT CURRENT_TIMESTAMP` |

Index: `idx_comp_snap_issue` on `(issue_id, compaction_level, created_at DESC)`.

### `repo_mtimes`

Tracks file modification times for multi-repo sync.

| Column | SQL Type | Notes |
|--------|----------|-------|
| `repo_path` | `VARCHAR(512)` | PK |
| `jsonl_path` | `VARCHAR(512) NOT NULL` | |
| `mtime_ns` | `BIGINT NOT NULL` | |
| `last_checked` | `DATETIME NOT NULL` | `DEFAULT CURRENT_TIMESTAMP` |

Index: `idx_repo_mtimes_checked`.

### `routes`

Prefix-to-path routing configuration.

| Column | SQL Type | Notes |
|--------|----------|-------|
| `prefix` | `VARCHAR(32)` | PK |
| `path` | `VARCHAR(512) NOT NULL` | |
| `created_at` | `DATETIME NOT NULL` | `DEFAULT CURRENT_TIMESTAMP` |
| `updated_at` | `DATETIME NOT NULL` | `DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` |

### `issue_counter`

Sequential ID generation for counter mode (GH#2002).

| Column | SQL Type | Notes |
|--------|----------|-------|
| `prefix` | `VARCHAR(255)` | PK |
| `last_id` | `INT NOT NULL` | `DEFAULT 0` |

### `interactions`

Agent audit log for AI tool invocations.

| Column | SQL Type | Notes |
|--------|----------|-------|
| `id` | `VARCHAR(32)` | PK |
| `kind` | `VARCHAR(64) NOT NULL` | |
| `created_at` | `DATETIME NOT NULL` | |
| `actor` | `VARCHAR(255)` | |
| `issue_id` | `VARCHAR(255)` | |
| `model` | `VARCHAR(255)` | |
| `prompt` | `TEXT` | |
| `response` | `TEXT` | |
| `error` | `TEXT` | |
| `tool_name` | `VARCHAR(255)` | |
| `exit_code` | `INT` | |
| `parent_id` | `VARCHAR(32)` | |
| `label` | `VARCHAR(64)` | |
| `reason` | `TEXT` | |
| `extra` | `JSON` | |

Indexes: `idx_interactions_kind`, `idx_interactions_created_at`,
`idx_interactions_issue_id`, `idx_interactions_parent_id`.

### `federation_peers`

Credentials and state for peer-to-peer Dolt remotes.

| Column | SQL Type | Notes |
|--------|----------|-------|
| `name` | `VARCHAR(255)` | PK |
| `remote_url` | `VARCHAR(1024) NOT NULL` | |
| `username` | `VARCHAR(255)` | |
| `password_encrypted` | `BLOB` | Encrypted with per-store random key |
| `sovereignty` | `VARCHAR(8)` | `DEFAULT ''` |
| `last_sync` | `DATETIME` | |
| `created_at` | `DATETIME NOT NULL` | `DEFAULT CURRENT_TIMESTAMP` |
| `updated_at` | `DATETIME NOT NULL` | `DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP` |

Index: `idx_federation_peers_sovereignty`.

### `wisps`

Mirror of the `issues` table schema. Registered in `dolt_ignore` so it is
never committed to Dolt version history. Created by migration
`004_wisps_table.go`.

The wisps table has the exact same columns and types as the `issues` table.
Ephemeral beads (`ephemeral=true`) are routed here at write time. The
auxiliary tables `wisp_labels`, `wisp_dependencies`, `wisp_events`, and
`wisp_comments` mirror their counterparts and are also `dolt_ignore`'d
(migration `005_wisp_auxiliary_tables.go`).

---

## Views

### `ready_issues`

A recursive CTE-based view that returns issues eligible for work. An issue is
"ready" when:

1. Status is `open`
2. Not ephemeral
3. Not directly blocked by any non-closed, non-pinned issue via `blocks` dependency
4. Not transitively blocked via `parent-child` chain (up to depth 50)
5. Not deferred (no `defer_until` in the future)
6. Not a child of a deferred parent

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
    SELECT issue_id, 0 as depth
    FROM blocked_directly
    UNION ALL
    SELECT d.issue_id, bt.depth + 1
    FROM blocked_transitively bt
    JOIN dependencies d ON d.depends_on_id = bt.issue_id
    WHERE d.type = 'parent-child'
      AND bt.depth < 50
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

Note: Uses `LEFT JOIN` instead of `NOT EXISTS` for the transitive block check
to avoid a Dolt `mergeJoinIter` panic. Uses `NOT IN ('closed', 'pinned')` rather
than listing active statuses explicitly so that custom statuses are automatically
included.

Source: `internal/storage/dolt/schema.go`, `readyIssuesView`.

### `blocked_issues`

Returns non-closed, non-pinned issues that have at least one active blocker.
Includes a `blocked_by_count` computed column.

```sql
CREATE OR REPLACE VIEW blocked_issues AS
SELECT
    i.*,
    (SELECT COUNT(*)
     FROM dependencies d
     WHERE d.issue_id = i.id
       AND d.type = 'blocks'
       AND EXISTS (
         SELECT 1 FROM issues blocker
         WHERE blocker.id = d.depends_on_id
           AND blocker.status NOT IN ('closed', 'pinned')
       )
    ) as blocked_by_count
FROM issues i
WHERE i.status NOT IN ('closed', 'pinned')
  AND EXISTS (
    SELECT 1 FROM dependencies d
    WHERE d.issue_id = i.id
      AND d.type = 'blocks'
      AND EXISTS (
        SELECT 1 FROM issues blocker
        WHERE blocker.id = d.depends_on_id
          AND blocker.status NOT IN ('closed', 'pinned')
      )
  );
```

Note: Uses subquery instead of three-table join to avoid Dolt `mergeJoinIter` panic.

Source: `internal/storage/dolt/schema.go`, `blockedIssuesView`.

---

## Status Constants

Defined in `internal/types/types.go`, lines 386-398.

| Constant | Value | Description |
|----------|-------|-------------|
| `StatusOpen` | `open` | Default. Eligible for `bd ready` |
| `StatusInProgress` | `in_progress` | Actively being worked |
| `StatusBlocked` | `blocked` | Waiting on a dependency |
| `StatusDeferred` | `deferred` | Deliberately put on ice for later |
| `StatusClosed` | `closed` | Done. Requires `closed_at` timestamp |
| `StatusPinned` | `pinned` | Persistent bead that stays open indefinitely. Not a work item |
| `StatusHooked` | `hooked` | Work attached to an agent's hook (GUPP) |

Custom statuses can be configured via `bd config set status.custom "status1,status2,..."`.
The `ready_issues` view uses `NOT IN ('closed', 'pinned')` to automatically include
custom statuses.

---

## IssueType Constants

Defined in `internal/types/types.go`, lines 425-470.

### Core Work Types (Built-in, Validated)

| Constant | Value | Description |
|----------|-------|-------------|
| `TypeBug` | `bug` | Bug report. Required sections: Steps to Reproduce, Acceptance Criteria |
| `TypeFeature` | `feature` | Feature request. Aliases: `enhancement`, `feat`. Required section: Acceptance Criteria |
| `TypeTask` | `task` | Default type. General work item. Required section: Acceptance Criteria |
| `TypeEpic` | `epic` | Parent container. Cannot close until all children are closed. Required section: Success Criteria |
| `TypeChore` | `chore` | Maintenance/cleanup. No required sections |
| `TypeDecision` | `decision` | ADR-style decision record. Aliases: `dec`, `adr`. Required sections: Decision, Rationale, Alternatives Considered |
| `TypeMessage` | `message` | Inter-agent communication. Re-promoted to built-in (GH#1347) |
| `TypeMolecule` | `molecule` | Molecule for swarm coordination (internal use) |

### System-Internal Type

| Constant | Value | Description |
|----------|-------|-------------|
| `TypeEvent` | `event` | Operational audit trail beads. Not in `IsValid()` but accepted by `IsBuiltIn()` |

### Custom Types

Gas Town types (`gate`, `convoy`, `merge-request`, `slot`, `agent`, `role`, `rig`)
are not built-in. They must be configured via `bd config set types.custom "gate,convoy,..."`.

---

## DependencyType Constants (22 Types)

Defined in `internal/types/types.go`, lines 680-717.

### Workflow Types (Affect Ready Work Calculation)

These types are checked by `AffectsReadyWork()` and influence the `ready_issues` view.

| Constant | Value | Semantics |
|----------|-------|-----------|
| `DepBlocks` | `blocks` | A blocks B: B cannot start until A is closed |
| `DepParentChild` | `parent-child` | Hierarchical containment. Blocking propagates transitively up the tree |
| `DepConditionalBlocks` | `conditional-blocks` | B runs only if A fails (close reason contains failure keywords) |
| `DepWaitsFor` | `waits-for` | Fanout gate: parent waits for dynamic children to complete |

### Association Types

| Constant | Value | Semantics |
|----------|-------|-----------|
| `DepRelated` | `related` | Loose relationship |
| `DepDiscoveredFrom` | `discovered-from` | Origin tracking |

### Graph Link Types

| Constant | Value | Semantics |
|----------|-------|-----------|
| `DepRepliesTo` | `replies-to` | Conversation threading. Uses `thread_id` for grouping |
| `DepRelatesTo` | `relates-to` | Knowledge graph edges |
| `DepDuplicates` | `duplicates` | Deduplication link |
| `DepSupersedes` | `supersedes` | Version chain link |

### Entity Types (HOP Foundation -- Decision 004)

| Constant | Value | Semantics |
|----------|-------|-----------|
| `DepAuthoredBy` | `authored-by` | Creator relationship |
| `DepAssignedTo` | `assigned-to` | Assignment relationship |
| `DepApprovedBy` | `approved-by` | Approval relationship |
| `DepAttests` | `attests` | Skill attestation: X attests Y has skill Z. Metadata: `AttestsMeta` |

### Convoy Tracking

| Constant | Value | Semantics |
|----------|-------|-----------|
| `DepTracks` | `tracks` | Non-blocking cross-project reference |

### Reference Types

| Constant | Value | Semantics |
|----------|-------|-----------|
| `DepUntil` | `until` | Active until target closes (e.g., muted patrol until issue resolved) |
| `DepCausedBy` | `caused-by` | Triggered by target (audit trail) |
| `DepValidates` | `validates` | Approval/validation relationship |

### Delegation Types

| Constant | Value | Semantics |
|----------|-------|-----------|
| `DepDelegatedFrom` | `delegated-from` | Work delegated from parent; completion cascades up |

### Dependency Validation

Any non-empty string up to 50 characters is valid (`IsValid()`). Only the 22
constants above are "well-known" (`IsWellKnown()`). Custom dependency types
are permitted -- the system is extensible.

### `waits-for` Metadata

The `waits-for` dependency type uses JSON metadata to specify gate behavior:

```go
type WaitsForMeta struct {
    Gate      string `json:"gate"`       // "all-children" or "any-children"
    SpawnerID string `json:"spawner_id"` // Optional: identifies which step spawns children
}
```

### `attests` Metadata

The `attests` dependency type uses JSON metadata for skill attestations:

```go
type AttestsMeta struct {
    Skill    string `json:"skill"`              // e.g., "go", "rust", "code-review"
    Level    string `json:"level"`              // "beginner", "intermediate", "expert", or 1-5
    Date     string `json:"date"`               // RFC3339 format
    Evidence string `json:"evidence,omitempty"` // Issue ID, commit, PR
    Notes    string `json:"notes,omitempty"`
}
```

### Failure Close Keywords

Used by `conditional-blocks`: if a close reason contains any of these
(case-insensitive), the issue is considered to have "failed":

`failed`, `rejected`, `wontfix`, `won't fix`, `canceled`, `cancelled`,
`abandoned`, `blocked`, `error`, `timeout`, `aborted`.

Source: `internal/types/types.go`, `FailureCloseKeywords`, `IsFailureClose()`.

---

## AgentState Constants

Defined in `internal/types/types.go`, lines 537-559.

| Constant | Value | Description |
|----------|-------|-------------|
| `StateIdle` | `idle` | Agent is waiting for work |
| `StateSpawning` | `spawning` | Agent is starting up |
| `StateRunning` | `running` | Agent is executing (general) |
| `StateWorking` | `working` | Agent is actively working on a task |
| `StateStuck` | `stuck` | Agent is blocked and needs help |
| `StateDone` | `done` | Agent completed its current work |
| `StateStopped` | `stopped` | Agent has cleanly shut down |
| `StateDead` | `dead` | Agent died without clean shutdown (timeout detection) |

Empty string is valid (non-agent beads have no agent state).

---

## MolType Constants

Defined in `internal/types/types.go`, lines 561-578.

| Constant | Value | Description |
|----------|-------|-------------|
| `MolTypeSwarm` | `swarm` | Coordinated multi-polecat work |
| `MolTypePatrol` | `patrol` | Recurring operational work (Witness, Deacon, etc.) |
| `MolTypeWork` | `work` | Regular polecat work (default) |

Empty string is valid (defaults to `work`).

---

## WorkType Constants

Defined in `internal/types/types.go`, lines 609-625.

| Constant | Value | Description |
|----------|-------|-------------|
| `WorkTypeMutex` | `mutex` | One worker, exclusive assignment (default) |
| `WorkTypeOpenCompetition` | `open_competition` | Many submit, buyer picks |

Empty string is valid (defaults to `mutex`).

---

## WispType Constants and TTLs

Defined in `internal/types/types.go`, lines 580-607.

### Category 1: High-Churn, Low Forensic Value (TTL: 6h)

| Constant | Value | Description |
|----------|-------|-------------|
| `WispTypeHeartbeat` | `heartbeat` | Liveness pings |
| `WispTypePing` | `ping` | Health check ACKs |

### Category 2: Operational State (TTL: 24h)

| Constant | Value | Description |
|----------|-------|-------------|
| `WispTypePatrol` | `patrol` | Patrol cycle reports |
| `WispTypeGCReport` | `gc_report` | Garbage collection reports |

### Category 3: Significant Events (TTL: 7d)

| Constant | Value | Description |
|----------|-------|-------------|
| `WispTypeRecovery` | `recovery` | Force-kill, recovery actions |
| `WispTypeError` | `error` | Error reports |
| `WispTypeEscalation` | `escalation` | Human escalations |

Empty string is valid (uses default TTL).

---

## EventType Constants

Defined in `internal/types/types.go`, lines 855-871.

| Constant | Value | Description |
|----------|-------|-------------|
| `EventCreated` | `created` | Issue created |
| `EventUpdated` | `updated` | Field updated |
| `EventStatusChanged` | `status_changed` | Status transition |
| `EventCommented` | `commented` | Comment added |
| `EventClosed` | `closed` | Issue closed |
| `EventReopened` | `reopened` | Issue reopened |
| `EventDependencyAdded` | `dependency_added` | Dependency created |
| `EventDependencyRemoved` | `dependency_removed` | Dependency removed |
| `EventLabelAdded` | `label_added` | Label applied |
| `EventLabelRemoved` | `label_removed` | Label removed |
| `EventCompacted` | `compacted` | Issue compacted |

---

## ComputeContentHash() Fields

The content hash includes these fields in stable order (null separator between each):

**Core fields:** Title, Description, Design, AcceptanceCriteria, Notes, SpecID,
Status, Priority, IssueType, Assignee, Owner, CreatedBy.

**Optional fields:** ExternalRef, SourceSystem, Pinned (flag), Metadata (raw JSON),
IsTemplate (flag).

**Bonded molecules:** For each BondRef: SourceID, BondType, BondPoint.

**HOP entity tracking:** Creator (EntityRef: Name, Platform, Org, ID).

**HOP validations:** For each Validation: Validator (EntityRef), Outcome,
Timestamp (RFC3339), Score.

**HOP economics:** QualityScore, Crystallizes (flag).

**Gate fields:** AwaitType, AwaitID, Timeout (duration), each Waiter.

**Slot fields:** Holder.

**Agent fields:** HookBead, RoleBead, AgentState, RoleType, Rig.

**Molecule/Work type:** MolType, WorkType.

**Event fields:** EventKind, Actor, Target, Payload.

**Excluded from hash:** ID, ContentHash, CreatedAt, UpdatedAt, ClosedAt,
ClosedBySession, CloseReason, DueAt, DeferUntil, CompactionLevel, CompactedAt,
CompactedAtCommit, OriginalSize, SourceRepo, Ephemeral, NoHistory, WispType,
LastActivity, Labels, Dependencies, Comments, IDPrefix, PrefixOverride.

Source: `internal/types/types.go`, `ComputeContentHash()`, lines 133-211.

---

## Validate() Rules

The `Validate()` method (and `ValidateWithCustom()`) enforces these invariants:

| Rule | Error |
|------|-------|
| Title is required | `title is required` |
| Title max 500 chars | `title must be 500 characters or less` |
| Priority 0-4 | `priority must be between 0 and 4` |
| Status must be valid (built-in or custom) | `invalid status: <value>` |
| IssueType must be valid (built-in or custom) | `invalid issue type: <value>` |
| EstimatedMinutes >= 0 if set | `estimated_minutes cannot be negative` |
| Status=closed requires closed_at | `closed issues must have closed_at timestamp` |
| Status!=closed requires no closed_at | `non-closed issues cannot have closed_at timestamp` |
| AgentState must be valid | `invalid agent state: <value>` |
| Metadata must be valid JSON if set | `metadata must be valid JSON` |
| Ephemeral and NoHistory are mutually exclusive | `ephemeral and no_history are mutually exclusive` |

`ValidateForImport()` relaxes type validation for federation trust: built-in
types are validated (catch typos like "tsak"), but non-built-in types from
source repos are trusted.

`SetDefaults()` applies: Status -> `open`, IssueType -> `task`. Priority 0
is not defaulted (P0 is valid).

Source: `internal/types/types.go`, lines 264-384.

---

## Schema Migrations

11 numbered migrations in `internal/storage/dolt/migrations/`:

| # | File | Purpose |
|---|------|---------|
| 001 | `001_wisp_type_column.go` | Add `wisp_type` column to issues |
| 002 | `002_spec_id_column.go` | Add `spec_id` column to issues |
| 003 | `003_orphan_detection.go` | Orphan dependency detection and cleanup |
| 004 | `004_wisps_table.go` | Create `wisps` table (dolt_ignore'd) with identical schema to issues |
| 005 | `005_wisp_auxiliary_tables.go` | Create `wisp_labels`, `wisp_dependencies`, `wisp_events`, `wisp_comments` |
| 006 | `006_issue_counter.go` | Create `issue_counter` table for sequential ID mode |
| 007 | `007_infra_to_wisps.go` | Migrate infrastructure types to wisps table |
| 008 | `008_wisp_dep_type_index.go` | Add compound index on wisp dependencies type |
| 009 | `009_cleanup_autopush_metadata.go` | Remove deprecated auto-push metadata entries |
| 010 | `010_uuid_primary_keys.go` | Migrate comments/events to UUID primary keys |
| 011 | `011_add_no_history_column.go` | Add `no_history` column to issues and wisps |

Schema initialization checks `currentSchemaVersion` (8) against the stored version
and skips re-initialization when they match, avoiding ~20 DDL statements per `bd`
invocation.

---

## Sort Policies

The `WorkFilter.SortPolicy` field controls how `bd ready` orders results.

| Policy | Value | Description |
|--------|-------|-------------|
| `SortPolicyHybrid` | `hybrid` | Default. Recent issues (48h) by priority, older by age |
| `SortPolicyPriority` | `priority` | Always sort by priority first, then creation date |
| `SortPolicyOldest` | `oldest` | Always sort by creation date (oldest first) |

Source: `internal/types/types.go`, lines 1003-1029.

---

## Go Struct Extensions (Not in SQL)

Several fields on the `Issue` struct exist only in Go and are not persisted
directly to the `issues` table:

| Go Field | Type | Purpose |
|----------|------|---------|
| `SourceRepo` | `string` | Which repo owns this issue (multi-repo). Tag: `json:"-"` |
| `IDPrefix` | `string` | Override prefix for ID generation. Tag: `json:"-"` |
| `PrefixOverride` | `string` | Completely replace config prefix. Tag: `json:"-"` |
| `Labels` | `[]string` | Populated for export/import from `labels` table |
| `Dependencies` | `[]*Dependency` | Populated for export/import from `dependencies` table |
| `Comments` | `[]*Comment` | Populated for export/import from `comments` table |
| `BondedFrom` | `[]BondRef` | Compound molecule lineage (stored in metadata JSON) |
| `Creator` | `*EntityRef` | HOP entity tracking (stored in metadata JSON) |
| `Validations` | `[]Validation` | HOP validation records (stored in metadata JSON) |
| `Holder` | `string` | Slot holder (stored in metadata JSON) |
| `SourceFormula` | `string` | Formula name where step was defined |
| `SourceLocation` | `string` | Path within formula: "steps[0]", "advice[0].after" |

---

## Composite Types

### `EntityRef`

HOP entity reference. Can be rendered as a URI: `hop://<platform>/<org>/<id>`.

```go
type EntityRef struct {
    Name     string `json:"name,omitempty"`     // "polecat/Nux", "mayor"
    Platform string `json:"platform,omitempty"` // "gastown", "github"
    Org      string `json:"org,omitempty"`      // "steveyegge"
    ID       string `json:"id,omitempty"`       // "polecat-nux"
}
```

### `Validation`

HOP validation record. Validators stake their reputation on approvals.

```go
type Validation struct {
    Validator *EntityRef `json:"validator"`
    Outcome   string     `json:"outcome"`   // accepted, rejected, revision_requested
    Timestamp time.Time  `json:"timestamp"`
    Score     *float32   `json:"score,omitempty"` // 0.0-1.0
}
```

### `BondRef`

Compound molecule lineage tracking.

```go
type BondRef struct {
    SourceID  string `json:"source_id"`            // Source proto or molecule ID
    BondType  string `json:"bond_type"`            // sequential, parallel, conditional, root
    BondPoint string `json:"bond_point,omitempty"` // Attachment site (issue ID or empty)
}
```

Bond type constants: `sequential` (B after A), `parallel` (B alongside A),
`conditional` (B only if A fails), `root` (primary component).

### ID Prefix Constants

| Constant | Value | Example ID | Purpose |
|----------|-------|-----------|---------|
| `IDPrefixMol` | `mol` | `bd-mol-x8f2k` | Persistent molecules |
| `IDPrefixWisp` | `wisp` | `bd-wisp-a3b7c` | Ephemeral wisps |
