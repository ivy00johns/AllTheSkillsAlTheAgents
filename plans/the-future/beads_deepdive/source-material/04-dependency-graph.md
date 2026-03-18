# 04 -- Dependency Graph Reference

This document provides a comprehensive reference for the Beads dependency graph
system. Dependencies are typed edges between issues (beads) that control work
scheduling, provenance tracking, entity relationships, and inter-agent
coordination.

**Key source files:**

| File | Purpose |
|------|---------|
| `internal/types/types.go` | Dependency type constants, AffectsReadyWork, metadata structs |
| `internal/storage/dolt/dependencies.go` | AddDependency, GetDependencies, DetectCycles, IsBlocked |
| `internal/storage/dolt/queries.go` | GetReadyWork, GetBlockedIssues, computeBlockedIDs |
| `internal/storage/issueops/dependencies.go` | AddDependencyInTx (validation, cycle detection) |
| `internal/storage/dependency_queries.go` | DependencyQueryStore interface |

---

## 1. Dependency Type Taxonomy

**File:** `internal/types/types.go:684-717`

There are 22 named dependency types organized into 8 categories.

### Workflow Types (affect ready work via `AffectsReadyWork()`)

| Type | Constant | Semantics |
|------|----------|-----------|
| `blocks` | `DepBlocks` | Hard prerequisite. B cannot start until A closes. |
| `parent-child` | `DepParentChild` | Hierarchical containment (epics). Blocked status propagates from parent to children. |
| `conditional-blocks` | `DepConditionalBlocks` | B runs only if A **fails**. Failure determined by `FailureCloseKeywords`. |
| `waits-for` | `DepWaitsFor` | Gate/fanout dependency. Metadata: `WaitsForMeta{Gate, SpawnerID}`. |

```go
func (d DependencyType) AffectsReadyWork() bool {
    return d == DepBlocks || d == DepParentChild ||
           d == DepConditionalBlocks || d == DepWaitsFor
}
```

### Association Types

| Type | Constant | Semantics |
|------|----------|-----------|
| `related` | `DepRelated` | Soft link, no scheduling impact |
| `discovered-from` | `DepDiscoveredFrom` | Provenance: agent found new work while on another issue |

### Graph Link Types

| Type | Constant | Semantics |
|------|----------|-----------|
| `replies-to` | `DepRepliesTo` | Conversation threading; `ThreadID` groups edges |
| `relates-to` | `DepRelatesTo` | Loose knowledge graph edges |
| `duplicates` | `DepDuplicates` | Deduplication link |
| `supersedes` | `DepSupersedes` | Version chain link |

### Entity Types (HOP Foundation)

| Type | Constant | Semantics |
|------|----------|-----------|
| `authored-by` | `DepAuthoredBy` | Creator relationship |
| `assigned-to` | `DepAssignedTo` | Assignment relationship |
| `approved-by` | `DepApprovedBy` | Approval relationship |
| `attests` | `DepAttests` | Skill attestation with `AttestsMeta{Skill, Level, Date, Evidence, Notes}` |

### Convoy Type

| Type | Constant | Semantics |
|------|----------|-----------|
| `tracks` | `DepTracks` | Non-blocking cross-project reference |

### Reference Types

| Type | Constant | Semantics |
|------|----------|-----------|
| `until` | `DepUntil` | Active until target closes (e.g., muted until issue resolved) |
| `caused-by` | `DepCausedBy` | Audit trail: triggered by target |
| `validates` | `DepValidates` | Approval/validation relationship |

### Delegation Type

| Type | Constant | Semantics |
|------|----------|-----------|
| `delegated-from` | `DepDelegatedFrom` | Completion cascades up the delegation chain |

### Type Validation

Any non-empty string up to 50 characters is a valid dependency type
(`IsValid()`). Only the 22 named constants return true from `IsWellKnown()`.
This allows custom/user-defined dependency types while preserving type safety for
built-in behavior.

---

## 2. Dependency Record Schema

**File:** `internal/storage/dolt/schema.go:93-108`

```sql
CREATE TABLE IF NOT EXISTS dependencies (
    issue_id       VARCHAR(255) NOT NULL,
    depends_on_id  VARCHAR(255) NOT NULL,
    type           VARCHAR(32)  NOT NULL DEFAULT 'blocks',
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by     VARCHAR(255) NOT NULL,
    metadata       JSON         DEFAULT (JSON_OBJECT()),
    thread_id      VARCHAR(255) DEFAULT '',
    PRIMARY KEY (issue_id, depends_on_id),
    INDEX idx_dependencies_issue (issue_id),
    INDEX idx_dependencies_depends_on (depends_on_id),
    INDEX idx_dependencies_depends_on_type (depends_on_id, type),
    INDEX idx_dependencies_thread (thread_id),
    CONSTRAINT fk_dep_issue FOREIGN KEY (issue_id)
        REFERENCES issues(id) ON DELETE CASCADE
);
```

Note: The FK on `depends_on_id` is **dropped** during schema init to allow
external references (`external:<rig>:<id>`). The `fk_dep_issue` constraint
on `issue_id` remains.

### Go Struct

**File:** `internal/types/types.go:628-640`

```go
type Dependency struct {
    IssueID     string         `json:"issue_id"`
    DependsOnID string         `json:"depends_on_id"`
    Type        DependencyType `json:"type"`
    CreatedAt   time.Time      `json:"created_at"`
    CreatedBy   string         `json:"created_by,omitempty"`
    Metadata    string         `json:"metadata,omitempty"`  // JSON blob
    ThreadID    string         `json:"thread_id,omitempty"` // Conversation root
}
```

---

## 3. Dependency Metadata Structs

### WaitsForMeta

**File:** `internal/types/types.go:747-753`

```go
type WaitsForMeta struct {
    Gate      string `json:"gate"`                  // "all-children" or "any-children"
    SpawnerID string `json:"spawner_id,omitempty"`  // Which step spawns children
}
```

| Gate | Semantics |
|------|-----------|
| `all-children` | Block until ALL direct children of spawner are closed (default) |
| `any-children` | Unblock when FIRST child completes |

### AttestsMeta

**File:** `internal/types/types.go:783-794`

```go
type AttestsMeta struct {
    Skill    string `json:"skill"`              // e.g., "go", "rust", "code-review"
    Level    string `json:"level"`              // e.g., "beginner", "expert", or numeric 1-5
    Date     string `json:"date"`               // RFC3339
    Evidence string `json:"evidence,omitempty"` // Issue ID, commit, PR reference
    Notes    string `json:"notes,omitempty"`
}
```

### FailureCloseKeywords

**File:** `internal/types/types.go:798-810`

Used by `conditional-blocks` to determine if the blocker failed:

```go
var FailureCloseKeywords = []string{
    "failed", "rejected", "wontfix", "won't fix",
    "canceled", "cancelled", "abandoned", "blocked",
    "error", "timeout", "aborted",
}
```

`IsFailureClose(closeReason)` checks if the close reason contains any keyword
(case-insensitive).

---

## 4. The ready_issues View (SQL)

**File:** `internal/storage/dolt/schema.go:273-311`

A recursive CTE that computes which issues are ready for work:

### CTE Structure

1. **blocked_directly** -- Issues with at least one active (non-closed,
   non-pinned) `blocks`-type dependency:

```sql
SELECT DISTINCT d.issue_id
FROM dependencies d
WHERE d.type = 'blocks'
  AND EXISTS (
    SELECT 1 FROM issues blocker
    WHERE blocker.id = d.depends_on_id
      AND blocker.status NOT IN ('closed', 'pinned')
  )
```

2. **blocked_transitively** -- Propagates blocked status through `parent-child`
   edges with depth limit 50:

```sql
SELECT issue_id, 0 as depth FROM blocked_directly
UNION ALL
SELECT d.issue_id, bt.depth + 1
FROM blocked_transitively bt
JOIN dependencies d ON d.depends_on_id = bt.issue_id
WHERE d.type = 'parent-child' AND bt.depth < 50
```

3. **Final SELECT** -- Filters to ready issues:
   - `status = 'open'`
   - `ephemeral = 0` (non-ephemeral)
   - `NOT IN blocked set` (via LEFT JOIN, not NOT EXISTS -- avoids Dolt `mergeJoinIter` panic)
   - `defer_until IS NULL OR defer_until <= NOW()`
   - Not a child of a deferred parent

Uses `NOT IN ('closed', 'pinned')` so custom statuses are automatically included
in the "active" set.

---

## 5. The blocked_issues View

**File:** `internal/storage/dolt/schema.go:315-341`

Issues with at least one open blocks-type blocker, plus `blocked_by_count` via
correlated subquery:

```sql
SELECT i.*,
    (SELECT COUNT(*)
     FROM dependencies d
     WHERE d.issue_id = i.id AND d.type = 'blocks'
       AND EXISTS (
         SELECT 1 FROM issues blocker
         WHERE blocker.id = d.depends_on_id
           AND blocker.status NOT IN ('closed', 'pinned')
       )) as blocked_by_count
FROM issues i
WHERE i.status NOT IN ('closed', 'pinned')
  AND EXISTS (...)
```

---

## 6. computeBlockedIDs -- The Authoritative Blocked Set

**File:** `internal/storage/dolt/queries.go:711-985`

This is the **single source of truth** for blocked status, used by both
`GetReadyWork` and `GetBlockedIssues`. The ready_issues view is a SQL-level
approximation; runtime queries use `computeBlockedIDs` for authoritative results.

### Algorithm

1. **Collect active issue IDs** from both `issues` and `wisps` tables (status
   `NOT IN ('closed', 'pinned')`)

2. **Load all blocking dependencies** from both `dependencies` and
   `wisp_dependencies` tables (types: `blocks`, `waits-for`, `conditional-blocks`)

3. **Filter direct blockers in Go:**
   - `blocks` and `conditional-blocks`: issue is blocked if both source AND
     target are active
   - `waits-for`: collected separately for gate evaluation

4. **waits-for gate evaluation:**
   - Load direct children of each spawner via `parent-child` edges
   - For `all-children` gate: blocked while ANY child remains active
   - For `any-children` gate: blocked while NO child has closed AND at least one
     child is active

5. **Cache the result** -- keyed by `includeWisps` flag. A full cache (wisps
   included) satisfies both modes. Invalidated on dependency changes.

### Cache Invalidation

`invalidateBlockedIDsCache()` is called after:
- `AddDependency`
- `RemoveDependency`
- `ClaimIssue` (status change)
- `CloseIssue` (status change)
- `UpdateIssue` with status field

---

## 7. Atomic Claim (ClaimIssue)

**File:** `internal/storage/dolt/issues.go:257-334`

```sql
UPDATE issues
SET assignee = ?, status = 'in_progress', updated_at = ?
WHERE id = ? AND (assignee = '' OR assignee IS NULL)
```

### Sequence:

1. `BeginTx`
2. Read old issue inside transaction (consistent snapshot)
3. Conditional `UPDATE` with `WHERE (assignee='' OR assignee IS NULL)`
4. Check `RowsAffected()`:
   - `0` -> query current assignee in same tx -> return `ErrAlreadyClaimed`
   - `1` -> record `claimed` event
5. `DOLT_ADD('issues', 'events')`
6. `DOLT_COMMIT('-m', 'bd: claim <id>', '--author', author)`
7. `tx.Commit()`
8. `invalidateBlockedIDsCache()`

This is a compare-and-swap operation. The conditional UPDATE ensures atomicity
without explicit locks -- two concurrent claims will see exactly one succeed and
one get `RowsAffected=0`.

---

## 8. Cycle Detection (DetectCycles)

**File:** `internal/storage/dolt/dependencies.go:671-755`

### Algorithm

1. Load ALL dependency records from both `dependencies` AND
   `wisp_dependencies` tables (detects cross-table cycles, e.g., permanent A ->
   wisp B -> permanent A)
2. Build adjacency list on `blocks` edges only
3. DFS with `recStack` (recursion stack) for back-edge detection
4. When a back-edge is found, extract the cycle path from the recursion stack
5. Fetch issue details for each node in the cycle (best-effort)
6. Return `[][]*Issue` -- each element is a cycle path

### Pre-Add Cycle Detection

**File:** `internal/storage/issueops/dependencies.go:118-145`

When adding a `blocks` dependency, `AddDependencyInTx` runs a recursive CTE
**within the transaction** to check if the proposed edge would create a cycle:

```sql
WITH RECURSIVE reachable AS (
    SELECT ? AS node, 0 AS depth
    UNION ALL
    SELECT d.depends_on_id, r.depth + 1
    FROM reachable r
    JOIN (
        SELECT issue_id, depends_on_id FROM dependencies WHERE type = 'blocks'
        UNION ALL
        SELECT issue_id, depends_on_id FROM wisp_dependencies WHERE type = 'blocks'
    ) d ON d.issue_id = r.node
    WHERE r.depth < 100
)
SELECT COUNT(*) FROM reachable WHERE node = ?
```

Parameters: start from `depends_on_id`, check if `issue_id` is reachable. If
`COUNT(*) > 0`, the edge would create a cycle and is rejected.

---

## 9. AddDependency

**File:** `internal/storage/dolt/dependencies.go:22-55`

### Sequence:

1. **Wisp routing:** if source is an active wisp, delegate to
   `addWispDependency`
2. **Pre-transaction target check:** determine if target is a wisp (must be done
   **before** opening tx to avoid connection pool deadlock with MaxOpenConns=1)
3. `withWriteTx`:
   - Call `issueops.AddDependencyInTx` with routing opts
   - `invalidateBlockedIDsCache()`
4. `doltAddAndCommit(ctx, ["dependencies"], "dependency: add <type> <src> -> <tgt>")`

### AddDependencyInTx Validation

**File:** `internal/storage/issueops/dependencies.go:47-176`

1. Auto-detect wisp routing if not provided
2. Validate source issue exists (query source table)
3. Validate target issue exists (skip for `external:` and cross-prefix refs)
4. Cross-type blocking validation (GH#1495): tasks can only block tasks, epics
   can only block epics
5. Cycle detection via recursive CTE (for `blocks` type only)
6. Check for existing dependency:
   - Same type: idempotent update (metadata only)
   - Different type: error with guidance to remove first
7. `INSERT INTO <writeTable> (...) VALUES (...)`

---

## 10. GetDependencies

**File:** `internal/storage/dolt/dependencies.go:89-106`

```sql
SELECT i.id FROM issues i
JOIN dependencies d ON i.id = d.depends_on_id
WHERE d.issue_id = ?
ORDER BY i.priority ASC, i.created_at DESC
```

Routes through `scanIssueIDs` which:
1. Collects all IDs from the result set
2. Closes rows (releases connection for MaxOpenConns=1 compatibility)
3. Batch-fetches issues via `GetIssuesByIDs`
4. Restores original ORDER BY (GH#1880)

---

## 11. GetDependentsWithMetadata

**File:** `internal/storage/dolt/dependencies.go:199-266`

Critical pattern for avoiding connection pool deadlock:

1. Query dependency records (issue_id, type, metadata, thread_id)
2. **Collect all results into a Go slice** (close rows before secondary query)
3. Batch-fetch issues via `GetIssuesByIDs` after rows are closed
4. Join results in Go

This two-phase approach prevents deadlock when `MaxOpenConns=1` -- having two
open `*sql.Rows` on the same connection would block.

---

## 12. GetDependencyTree

**File:** `internal/storage/dolt/dependencies.go:619-666`

Iterative DFS with `visited` map:

```go
func (s *DoltStore) buildDependencyTree(ctx, issueID, depth, maxDepth,
    reverse bool, visited map[string]bool, parentID string) ([]*TreeNode, error) {

    if depth >= maxDepth || visited[issueID] { return nil, nil }
    visited[issueID] = true

    issue, _ := s.GetIssue(ctx, issueID)
    var related []*Issue
    if reverse {
        related, _ = s.GetDependents(ctx, issueID)
    } else {
        related, _ = s.GetDependencies(ctx, issueID)
    }

    nodes := []*TreeNode{{Issue: *issue, Depth: depth, ParentID: parentID}}
    for _, rel := range related {
        children, _ := s.buildDependencyTree(ctx, rel.ID, depth+1, ...)
        nodes = append(nodes, children...)
    }
    return nodes, nil
}
```

Returns a flat `[]*TreeNode` (not a tree), where each node carries its `Depth`
and `ParentID` for rendering.

---

## 13. IsBlocked

**File:** `internal/storage/dolt/dependencies.go:761-812`

Uses `computeBlockedIDs` as the single source of truth (consistent with
`GetReadyWork`):

1. Call `computeBlockedIDs(ctx, true)` (populates cache)
2. Check `blockedIDsCacheMap[issueID]`
3. If blocked: supplemental query for blocker IDs (for display):

```sql
SELECT d.depends_on_id, d.type
FROM dependencies d
JOIN issues i ON d.depends_on_id = i.id
WHERE d.issue_id = ?
  AND d.type IN ('blocks', 'waits-for', 'conditional-blocks')
  AND i.status NOT IN ('closed', 'pinned')
```

Non-`blocks` types include the type annotation in the returned blocker string
(e.g., `"id (waits-for)"`).

---

## 14. GetNewlyUnblockedByClose

**File:** `internal/storage/dolt/dependencies.go:819-904`

Two-step algorithm (rewritten from a single complex query to avoid Dolt
query-planner issues):

**Step 1:** Find open/blocked issues that depend on the closed issue:

```sql
SELECT d.issue_id FROM dependencies d
JOIN issues i ON d.issue_id = i.id
WHERE d.depends_on_id = ?
  AND d.type = 'blocks'
  AND i.status NOT IN ('closed', 'pinned')
```

**Step 2:** Among candidates, find those with NO remaining open blockers:

```sql
SELECT DISTINCT d2.issue_id
FROM dependencies d2
JOIN issues blocker ON d2.depends_on_id = blocker.id
WHERE d2.issue_id IN (?)
  AND d2.type = 'blocks'
  AND d2.depends_on_id != ?         -- exclude the just-closed issue
  AND blocker.status NOT IN ('closed', 'pinned')
```

Issues NOT in the "still blocked" set are newly unblocked.

---

## 15. GetBlockingInfoForIssues

**File:** `internal/storage/dolt/dependencies.go:404-531`

Returns three maps for a batch of issue IDs:
- `blockedByMap map[string][]string` -- issueID -> IDs blocking it
- `blocksMap map[string][]string` -- issueID -> IDs it blocks
- `parentMap map[string]string` -- childID -> parentID

Two batched queries:

**Query 1** ("blocked by"): Dependencies where `issue_id IN (batch)` and type
is `blocks` or `parent-child`. Skips closed blockers. Separates `parent-child`
into `parentMap`.

**Query 2** ("blocks"): Dependencies where `depends_on_id IN (batch)`. Shows
what the displayed issues block. Skips `parent-child` edges in the blocks map.

---

## 16. GetDependencyCounts

**File:** `internal/storage/dolt/dependencies.go:534-616`

Two `COUNT(*) GROUP BY` queries per batch:

```sql
-- How many things block this issue
SELECT issue_id, COUNT(*) as cnt
FROM dependencies
WHERE issue_id IN (?) AND type = 'blocks'
GROUP BY issue_id

-- How many things this issue blocks
SELECT depends_on_id, COUNT(*) as cnt
FROM dependencies
WHERE depends_on_id IN (?) AND type = 'blocks'
GROUP BY depends_on_id
```

Returns `map[string]*DependencyCounts` with `DependencyCount` (blockers) and
`DependentCount` (things it blocks).

---

## 17. Batch Query Optimization

All IN-clause queries are batched using a `queryBatchSize` constant to avoid
Dolt query planner performance spikes with large ID sets (GH#2179). The
`doltBuildSQLInClause` helper constructs parameterized placeholder strings:

```go
for start := 0; start < len(ids); start += queryBatchSize {
    end := min(start + queryBatchSize, len(ids))
    batch := ids[start:end]
    placeholders, args := doltBuildSQLInClause(batch)
    query := fmt.Sprintf("SELECT ... WHERE id IN (%s)", placeholders)
    rows, _ := s.queryContext(ctx, query, args...)
    // process rows...
    _ = rows.Close()
}
```

This pattern appears in:
- `computeBlockedIDs` (spawner children, closed children queries)
- `getChildrenOfIssues` / `getChildrenWithParents`
- `getDependencyRecordsForIssuesDolt`
- `GetBlockingInfoForIssues`
- `GetDependencyCounts`
- `GetEpicsEligibleForClosure`
- `getIssuesByIDsDolt`
- `GetNewlyUnblockedByClose`

---

## 18. Cross-Prefix Dependencies

**File:** `internal/storage/dolt/dependencies.go:15-17`

```go
func isCrossPrefixDep(sourceID, targetID string) bool {
    return types.ExtractPrefix(sourceID) != types.ExtractPrefix(targetID)
}
```

When the source and target have different prefixes, they live in different rig
databases. Cross-rig deps use the `external:<rig>:<id>` format. For cross-prefix
dependencies:
- Target existence validation is skipped (the target is in another database)
- The FK on `depends_on_id` was dropped to allow these references

---

## 19. DependencyQueryStore Interface

**File:** `internal/storage/dependency_queries.go`

```go
type DependencyQueryStore interface {
    GetDependencyRecords(ctx, issueID) ([]*Dependency, error)
    GetDependencyRecordsForIssues(ctx, issueIDs) (map[string][]*Dependency, error)
    GetAllDependencyRecords(ctx) (map[string][]*Dependency, error)
    GetDependencyCounts(ctx, issueIDs) (map[string]*DependencyCounts, error)
    GetBlockingInfoForIssues(ctx, issueIDs) (blockedByMap, blocksMap, parentMap, error)
    IsBlocked(ctx, issueID) (bool, []string, error)
    GetNewlyUnblockedByClose(ctx, closedIssueID) ([]*Issue, error)
    DetectCycles(ctx) ([][]*Issue, error)
    FindWispDependentsRecursive(ctx, ids) (map[string]bool, error)
    RenameDependencyPrefix(ctx, oldPrefix, newPrefix) error
}
```

---

## 20. Wisp Dependency Routing

Every dependency function checks `isActiveWisp(ctx, issueID)` first:

| Normal Table | Wisp Table |
|--------------|------------|
| `dependencies` | `wisp_dependencies` |

For `AddDependency`, the target wisp check is done **before** opening the
transaction to avoid connection pool deadlock (documented as `bd-w2w`). With
`MaxOpenConns=1`, checking the target inside a transaction would require a second
connection that doesn't exist.

`DetectCycles` queries BOTH tables and builds a unified adjacency list, ensuring
cross-table cycles (permanent -> wisp -> permanent) are detected.

---

## 21. GetReadyWork -- Runtime Ready Work Calculation

**File:** `internal/storage/dolt/queries.go:112-317`

The runtime `GetReadyWork` does NOT use the `ready_issues` view. Instead it
performs Go-level filtering with `computeBlockedIDs` as the authoritative source:

1. Build WHERE clauses from `WorkFilter` (status, priority, type, assignee,
   labels, metadata, deferred)
2. Pre-compute `computeBlockedIDs(ctx, includeEphemeral)`
3. Get children of blocked parents (transitive blocking GH#1495)
4. Add batched `NOT IN` clauses for all blocked IDs
5. Sort by `SortPolicy`:
   - `priority`: `ORDER BY priority ASC, created_at DESC`
   - `oldest`: `ORDER BY created_at ASC`
   - `hybrid` (default): recent issues (48h) by priority, older by age (starvation prevention)
6. Query `issues` table, optionally also query `wisps` table if `IncludeEphemeral`

---

## 22. GetBlockedIssues -- Runtime Blocked Issue Calculation

**File:** `internal/storage/dolt/queries.go:324-484`

Uses separate single-table queries to avoid Dolt `joinIter` panic:

1. Get all active IDs from both `issues` and `wisps` tables
2. Get canonical blocked set via `computeBlockedIDs`
3. Include children of blocked parents (transitive blocking GH#1495)
4. Get blocking deps from both `dependencies` and `wisp_dependencies`
5. Batch-fetch all blocked issues via `GetIssuesByIDs`
6. Sort results by priority ASC, created_at DESC
7. Optional: filter to children of specified parent

---

## 23. Key Design Decisions

### LEFT JOIN vs NOT EXISTS

The `ready_issues` view uses `LEFT JOIN blocked_transitively bt ON bt.issue_id = i.id ... WHERE bt.issue_id IS NULL` instead of `NOT EXISTS (SELECT 1 FROM blocked_transitively WHERE ...)`. This is to avoid a Dolt `mergeJoinIter` panic (tracked at dolthub/go-mysql-server#3413).

### Two-Phase Row Processing

Multiple functions (GetDependenciesWithMetadata, GetDependentsWithMetadata,
scanIssueIDs) use a two-phase pattern:
1. Scan all IDs/metadata from the result set into a Go slice
2. Close the `*sql.Rows` (release the connection)
3. Batch-fetch full issue records via `GetIssuesByIDs`

This prevents connection pool deadlock when `MaxOpenConns=1` -- MySQL's protocol
requires closing one result set before starting another on the same connection.

### Explicit DOLT_ADD (GH#2455)

All dependency operations use `doltAddAndCommit(ctx, ["dependencies"], msg)`
instead of `DOLT_COMMIT('-Am', msg)`. The `-Am` approach staged ALL dirty tables
in the session's working set, sweeping up stale config changes from concurrent
operations.

### Cross-Type Blocking Validation (GH#1495)

Tasks can only block tasks; epics can only block epics. This prevents confusing
situations where blocking an epic with a task (or vice versa) would create
unexpected scheduling behavior.

### Batched IN Clauses

All queries with `IN (?)` clauses use batched processing to avoid Dolt query
planner performance spikes. Without batching, a single `IN` clause with hundreds
of IDs causes the planner to generate suboptimal execution plans.
