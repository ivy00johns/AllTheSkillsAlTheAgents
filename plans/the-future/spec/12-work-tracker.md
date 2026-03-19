# 12 — Work Tracker

**Document type:** System specification
**Status:** DRAFT
**Date:** 2026-03-18
**Scope:** Issue tracking, work management, dependency scheduling, and formula-driven workflow for the unified platform
**Depends on:** `01-product-charter.md` (vision), `03-system-architecture.md` (runtime), `04-role-taxonomy.md` (agent roles), `05-data-model.md` (entities)
**Source platforms:** Beads (Dolt-backed tracker, formula engine, dependency graph), Gas Town (two-tier architecture, convoy tracking, HOP), Overstory Seeds (git-native alternative)

---

## 1. Work Tracker Overview

The work tracker is the central nervous system of the platform. Every unit of work — from a one-line bug fix to a multi-sprint feature — flows through it. Every agent gets its assignments from it. Every dependency, every gate, every approval, every status transition is recorded in it. When an agent asks "what should I work on next?", the work tracker answers.

### Design Principles

**1. Dolt-backed for durability, versioning, federation, and SQL queryability.** The tracker stores all state in a Dolt database — a MySQL-compatible relational database with built-in version control. Every mutation is committed to an immutable DAG. You can query any historical state with `AS OF <timestamp>`. You can federate across instances with push/pull. You can run arbitrary SQL against it.

**2. Two-tier architecture.** Fleet-level databases handle cross-project coordination: convoys, agent identity, fleet-wide settings. Project-level databases handle per-project work: items, dependencies, formulas, evidence. Join queries across tiers provide fleet-wide visibility without coupling project-level data.

**3. Agent-aware.** Agents are first-class entities in the tracker, not external consumers. An agent's identity, state, current assignment, capabilities, and work history are all stored as work items (with the `gt:agent` label). The same schema that tracks "fix the login bug" also tracks "backend-agent is working on task wi-a3b7."

**4. Formula-driven.** Reusable workflow templates (formulas) instantiate into tracked work hierarchies. A formula describes "how to do a standard build" or "how to run a patrol loop." Cooking a formula creates a molecule — a live workflow with real work items, dependencies, and gates. This eliminates the gap between "deciding what to do" and "tracking the doing."

**5. Hash-based IDs for conflict-free creation.** When multiple agents or instances create work items simultaneously, hash-based IDs (derived from title + timestamp + random salt) prevent merge conflicts. No central ID counter. No coordination required.

---

## 2. Dolt SQL Server Configuration

The work tracker runs on a Dolt SQL Server — a MySQL-compatible database with version control semantics. All agents connect over the MySQL wire protocol using standard client drivers.

### Server Settings

| Setting | Default | Env Override | Description |
|---------|---------|--------------|-------------|
| Port | 3307 | `PLATFORM_DOLT_PORT` | MySQL-compatible port (avoids conflict with MySQL 3306) |
| Host | 127.0.0.1 | `PLATFORM_DOLT_HOST` | Bind address |
| User | root | `PLATFORM_DOLT_USER` | MySQL user |
| Password | (empty) | `PLATFORM_DOLT_PASSWORD` | Never stored in files |
| MaxOpenConns | 10 | -- | Connection pool size per client |
| Read timeout | 30s | -- | SQL query timeout |
| Write timeout | 30s | -- | SQL mutation timeout |
| Branch | main | -- | All agents work on main (single-branch model) |

### Operational Behavior

**Auto-start daemon.** When a platform command cannot reach a Dolt server and auto-start is enabled, it launches `dolt sql-server` as a subprocess. Reference counting ensures the server stops only when the last client disconnects. Disabled in test mode and when an explicit server port is configured (prevents shadow databases).

**Connection pooling.** Each pool connection gets its own Dolt session with independent working set and branch state. The pool supports concurrent agent access — 20 agents with 10 connections each = 200 potential connections.

**Cell-level merge (MVCC).** Dolt tracks changes at individual cell granularity (row + column intersection), not entire rows. Two agents can update different columns on the same work item simultaneously without conflict. Agent A updates `status` while Agent B updates `description` — both succeed. Same-column conflicts raise MySQL Error 1213 and require retry.

**Auto-restart on crash.** Stale LOCK files from unclean shutdowns are detected and removed before server start. The `platform doctor --fix` command handles recovery.

**Per-project database.** Each project gets its own Dolt repository (database directory). Fleet-level coordination uses a separate database.

### Commit Pattern

All mutations follow a strict sequence:

```sql
BEGIN;
  INSERT/UPDATE/DELETE ...;          -- data changes
COMMIT;                              -- SQL transaction (makes changes durable)
CALL DOLT_ADD('work_items');         -- stage specific table
CALL DOLT_COMMIT('-m', 'message');   -- create versioned commit
```

Critical: SQL transaction commits BEFORE `DOLT_COMMIT`. This prevents data loss for ephemeral items (wisps) when `DOLT_COMMIT` finds nothing to stage.

---

## 3. Complete Work Item Schema

All work item variants share a single wide table (~50 columns) with sparse usage per variant. This avoids join overhead for the most common queries and simplifies the dependency graph — every node is the same type.

### Identity Columns

```sql
CREATE TABLE work_items (
    id              VARCHAR(255) PRIMARY KEY,
    content_hash    VARCHAR(64),          -- SHA-256 of canonical content for dedup
```

### Content Columns

```sql
    title               VARCHAR(500) NOT NULL,
    description         TEXT NOT NULL,
    design              TEXT NOT NULL,         -- Architecture/design notes
    acceptance_criteria TEXT NOT NULL,         -- Completion criteria
    notes               TEXT NOT NULL,         -- Free-form notes
    spec_id             VARCHAR(1024),        -- External specification reference
```

### Workflow Columns

```sql
    status          VARCHAR(32) NOT NULL DEFAULT 'open',
    priority        INT NOT NULL DEFAULT 2,        -- 0 (critical) through 4 (lowest)
    item_type       VARCHAR(32) NOT NULL DEFAULT 'task',
    assignee        VARCHAR(255),
    owner           VARCHAR(255) DEFAULT '',       -- Human owner for attribution
    estimated_minutes INT,
```

### Timestamp Columns

```sql
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by      VARCHAR(255) DEFAULT '',
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    closed_at       DATETIME,                      -- Set iff status = 'closed'
    closed_by_session VARCHAR(255) DEFAULT '',
    close_reason    TEXT DEFAULT '',
    due_at          DATETIME,                      -- Deadline
    defer_until     DATETIME,                      -- Hidden from ready queue until this time
```

### External Integration Columns

```sql
    external_ref    VARCHAR(255),          -- e.g., 'gh-9', 'jira-ABC'
    source_system   VARCHAR(255) DEFAULT '',
    source_repo     VARCHAR(512) DEFAULT '',
    metadata        JSON DEFAULT (JSON_OBJECT()),  -- Arbitrary extension data
```

### Compaction Columns

```sql
    compaction_level     INT DEFAULT 0,
    compacted_at         DATETIME,
    compacted_at_commit  VARCHAR(64),       -- Git commit hash at compaction time
    original_size        INT,               -- Pre-compaction content size in bytes
```

### Messaging Columns

```sql
    sender      VARCHAR(255) DEFAULT '',
    ephemeral   TINYINT(1) DEFAULT 0,      -- If true, stored in wisps table
    no_history  TINYINT(1) DEFAULT 0,      -- In wisps table but NOT GC-eligible
    wisp_type   VARCHAR(32) DEFAULT '',    -- TTL classification
```

### Context Columns

```sql
    pinned      TINYINT(1) DEFAULT 0,      -- Persistent context, not a work item
    is_template TINYINT(1) DEFAULT 0,      -- Read-only formula template
```

### Economics Columns (HOP)

```sql
    crystallizes  TINYINT(1) DEFAULT 0,    -- Work that compounds vs evaporates
    mol_type      VARCHAR(32) DEFAULT '',   -- swarm, patrol, work
    work_type     VARCHAR(32) DEFAULT 'mutex', -- mutex or open_competition
    quality_score DOUBLE,                   -- 0.0-1.0, set on merge review
```

### Event Columns

```sql
    event_kind  VARCHAR(32) DEFAULT '',    -- e.g., 'patrol.muted', 'agent.started'
    actor       VARCHAR(255) DEFAULT '',
    target      VARCHAR(255) DEFAULT '',
    payload     TEXT DEFAULT '',            -- Event-specific JSON
```

### Gate Columns

```sql
    await_type  VARCHAR(32) DEFAULT '',    -- gh:run, gh:pr, timer, human, mail
    await_id    VARCHAR(255) DEFAULT '',   -- Condition identifier
    timeout_ns  BIGINT DEFAULT 0,          -- Max wait time (nanoseconds)
    waiters     TEXT DEFAULT '',            -- Notification targets
```

### Agent Columns

```sql
    hook_bead      VARCHAR(255) DEFAULT '',  -- Current work on agent's hook (0..1)
    role_bead      VARCHAR(255) DEFAULT '',  -- Role definition reference
    agent_state    VARCHAR(32) DEFAULT '',   -- idle, spawning, running, working, stuck, done, stopped, dead
    last_activity  DATETIME,                 -- Updated on each action (timeout detection)
    role_type      VARCHAR(32) DEFAULT '',   -- Application-defined role classification
    rig            VARCHAR(255) DEFAULT ''   -- Rig name (empty for fleet-level agents)
);
```

### Indexes

```sql
CREATE INDEX idx_wi_status      ON work_items(status);
CREATE INDEX idx_wi_priority    ON work_items(priority);
CREATE INDEX idx_wi_item_type   ON work_items(item_type);
CREATE INDEX idx_wi_assignee    ON work_items(assignee);
CREATE INDEX idx_wi_created_at  ON work_items(created_at);
CREATE INDEX idx_wi_spec_id     ON work_items(spec_id);
CREATE INDEX idx_wi_external    ON work_items(external_ref);
```

### Status Constants

| Status | Description |
|--------|-------------|
| `open` | Default. Eligible for ready queue |
| `active` | Currently being worked |
| `blocked` | Waiting on a dependency |
| `deferred` | Deliberately put on ice |
| `closed` | Done. Requires `closed_at` timestamp |
| `pinned` | Persistent context marker, not a work item |
| `hooked` | Work attached to an agent's hook |

### Item Type Constants

| Type | Description |
|------|-------------|
| `task` | Default. General work item |
| `bug` | Bug report. Required: steps to reproduce, acceptance criteria |
| `feature` | Feature request. Required: acceptance criteria |
| `epic` | Parent container. Cannot close until all children close |
| `chore` | Maintenance/cleanup |
| `decision` | ADR-style decision record |
| `message` | Inter-agent communication |
| `molecule` | Workflow coordination (internal) |
| `gate` | Async wait condition (internal) |
| `event` | Operational audit trail |

### Supporting Tables

```sql
CREATE TABLE labels (
    item_id VARCHAR(255) NOT NULL REFERENCES work_items(id) ON DELETE CASCADE,
    label   VARCHAR(255) NOT NULL,
    PRIMARY KEY (item_id, label)
);

CREATE TABLE comments (
    id         CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    item_id    VARCHAR(255) NOT NULL REFERENCES work_items(id) ON DELETE CASCADE,
    author     VARCHAR(255) NOT NULL,
    text       TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE events (
    id         CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    item_id    VARCHAR(255) NOT NULL REFERENCES work_items(id) ON DELETE CASCADE,
    event_type VARCHAR(32) NOT NULL,  -- created, updated, status_changed, claimed, etc.
    actor      VARCHAR(255) NOT NULL,
    old_value  TEXT,
    new_value  TEXT,
    comment    TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE config (
    `key`  VARCHAR(255) PRIMARY KEY,
    value  TEXT NOT NULL
);

CREATE TABLE interactions (
    id         VARCHAR(32) PRIMARY KEY,
    kind       VARCHAR(64) NOT NULL,
    created_at DATETIME NOT NULL,
    actor      VARCHAR(255),
    item_id    VARCHAR(255),
    model      VARCHAR(255),
    prompt     TEXT,
    response   TEXT,
    error      TEXT,
    tool_name  VARCHAR(255),
    exit_code  INT,
    parent_id  VARCHAR(32),
    label      VARCHAR(64),
    reason     TEXT,
    extra      JSON
);

CREATE TABLE federation_peers (
    name               VARCHAR(255) PRIMARY KEY,
    remote_url         VARCHAR(1024) NOT NULL,
    username           VARCHAR(255),
    password_encrypted BLOB,
    sovereignty        VARCHAR(8) DEFAULT '',
    last_sync          DATETIME,
    created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

---

## 4. ID Generation

### Hash-Based IDs

Work item IDs are derived from content hashes to prevent merge conflicts when multiple agents or instances create items simultaneously.

**Algorithm:**

```
input  = title + ISO8601_timestamp + random_bytes(8)
hash   = SHA256(input)
id     = prefix + "-" + hash[0:4]
```

**Examples:**

| Entity | Prefix | Example ID |
|--------|--------|------------|
| Work item | `wi` | `wi-a1b2` |
| Agent | `ag` | `ag-c3d4` |
| Convoy | `cv` | `cv-e5f6` |
| Formula/molecule | `mol` | `mol-g7h8` |
| Wisp | `wisp` | `wisp-i9j0` |

### Why Hashes

**No central counter.** Counter-based IDs (`wi-1`, `wi-2`, `wi-3`) require a single authority to issue sequential numbers. With federation and offline operation, there is no single authority.

**Merge-safe.** When two agents create items simultaneously, their hashes differ with overwhelming probability. No coordination needed. No conflict on merge.

**Deterministic dedup.** The `content_hash` column (SHA-256 of canonical fields) enables deduplication across federated instances. Two instances creating the same work item independently will produce the same content hash.

### Collision Handling

If a 4-character hash collides with an existing ID, extend the hash length incrementally: try 5 characters, then 6, up to the full 64-character hash. In practice, 4 characters provide ~65,000 unique IDs per prefix before expected collisions — sufficient for any single project.

### Hierarchical IDs

Child items use dot-separated IDs: `wi-a1b2.design`, `wi-a1b2.implement`, `wi-a1b2.gate-review`. This encodes the parent-child relationship in the ID itself and makes dependency trees human-readable.

---

## 5. Dependency System (22 Types)

Dependencies are typed directed edges between work items. They control scheduling, track provenance, model entity relationships, and coordinate inter-agent work. The dependency table stores all 22 types in a single schema.

### Dependency Table Schema

```sql
CREATE TABLE dependencies (
    item_id       VARCHAR(255) NOT NULL,
    depends_on_id VARCHAR(255) NOT NULL,
    type          VARCHAR(32) NOT NULL DEFAULT 'blocks',
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by    VARCHAR(255) NOT NULL,
    metadata      JSON DEFAULT (JSON_OBJECT()),
    thread_id     VARCHAR(255) DEFAULT '',
    PRIMARY KEY (item_id, depends_on_id),
    CONSTRAINT fk_dep_item FOREIGN KEY (item_id)
        REFERENCES work_items(id) ON DELETE CASCADE,
    INDEX idx_dep_item (item_id),
    INDEX idx_dep_target (depends_on_id),
    INDEX idx_dep_target_type (depends_on_id, type),
    INDEX idx_dep_thread (thread_id)
);
```

No FK on `depends_on_id` — deliberately dropped to allow cross-project references using the `external:<project>:<id>` format.

### Hard Blockers (Affect Ready Queue)

These 4 types prevent work from being scheduled. They are checked by `AffectsReadyWork()` and drive the `ready_items` view.

| Type | Semantics | Example |
|------|-----------|---------|
| `blocks` | A blocks B: B cannot start until A is closed | "Design must complete before implementation" |
| `parent-child` | Hierarchical containment. Blocked status propagates transitively up the tree (depth limit 50) | "Epic contains tasks" |
| `conditional-blocks` | B runs only if A fails. Failure determined by presence of keywords in close reason: `failed`, `rejected`, `wontfix`, `canceled`, `abandoned`, `blocked`, `error`, `timeout`, `aborted` | "Rollback plan activates only if deployment fails" |
| `waits-for` | Fanout gate: parent waits for dynamic children to complete. Metadata: `{"gate": "all-children"\|"any-children", "spawner_id": "..."}` | "Integration test waits for all unit test suites" |

### Soft Dependencies (Inform Ordering)

These 8 types do NOT block scheduling but capture relationships for navigation, provenance, and knowledge.

| Type | Semantics |
|------|-----------|
| `related` | Loose relationship, no scheduling impact |
| `discovered-from` | Origin tracking: agent found new work while on another item |
| `replies-to` | Conversation threading. Uses `thread_id` for grouping |
| `relates-to` | Knowledge graph edge |
| `duplicates` | Deduplication link |
| `supersedes` | Version chain link |
| `tracks` | Non-blocking cross-project reference (convoy tracking) |
| `until` | Active until target closes (e.g., muted patrol until issue resolved) |

### Entity Dependencies (HOP Foundation)

These 5 types model who-did-what relationships for attribution, approval, and skill tracking.

| Type | Semantics | Metadata |
|------|-----------|----------|
| `authored-by` | Creator relationship | -- |
| `assigned-to` | Assignment relationship | -- |
| `approved-by` | Approval relationship | -- |
| `attests` | Skill attestation: X attests Y has skill Z | `{"skill": "go", "level": "expert", "date": "2026-03-18T...", "evidence": "wi-a1b2"}` |
| `delegated-from` | Work delegated from parent; completion cascades up | -- |

### Remaining Types

| Type | Semantics |
|------|-----------|
| `caused-by` | Audit trail: triggered by target |
| `validates` | Approval/validation relationship |

### Extensibility

Any non-empty string up to 50 characters is a valid dependency type. Only the 22 named types above are "well-known." Custom dependency types are permitted — the system is extensible without schema changes.

### Cycle Detection

Before adding a `blocks` dependency, a recursive CTE checks whether the proposed edge would create a cycle:

```sql
WITH RECURSIVE reachable AS (
    SELECT ? AS node, 0 AS depth
    UNION ALL
    SELECT d.depends_on_id, r.depth + 1
    FROM reachable r
    JOIN dependencies d ON d.item_id = r.node
    WHERE d.type = 'blocks' AND r.depth < 100
)
SELECT COUNT(*) FROM reachable WHERE node = ?;
-- If COUNT > 0, the edge would create a cycle. Reject it.
```

Cross-type validation: tasks can only block tasks, epics can only block epics. This prevents confusing scheduling behavior from mixed-type blocking.

---

## 6. Ready Queue Algorithm

The ready queue is the core scheduling algorithm. It answers the question: "Which work items are available for an agent to pick up right now?"

### The `ready_items` View

```sql
CREATE OR REPLACE VIEW ready_items AS
WITH RECURSIVE
  blocked_directly AS (
    -- Base case: items with at least one active blocker
    SELECT DISTINCT d.item_id
    FROM dependencies d
    WHERE d.type = 'blocks'
      AND EXISTS (
        SELECT 1 FROM work_items blocker
        WHERE blocker.id = d.depends_on_id
          AND blocker.status NOT IN ('closed', 'pinned')
      )
  ),
  blocked_transitively AS (
    -- Seed: directly blocked items
    SELECT item_id, 0 AS depth
    FROM blocked_directly

    UNION ALL

    -- Recursive: propagate blocked status through parent-child edges
    SELECT d.item_id, bt.depth + 1
    FROM blocked_transitively bt
    JOIN dependencies d ON d.depends_on_id = bt.item_id
    WHERE d.type = 'parent-child'
      AND bt.depth < 50
  )
SELECT wi.*
FROM work_items wi
LEFT JOIN blocked_transitively bt ON bt.item_id = wi.id
WHERE wi.status = 'open'
  AND (wi.ephemeral = 0 OR wi.ephemeral IS NULL)
  AND bt.item_id IS NULL
  AND (wi.defer_until IS NULL OR wi.defer_until <= NOW())
  AND NOT EXISTS (
    SELECT 1 FROM dependencies d_parent
    JOIN work_items parent ON parent.id = d_parent.depends_on_id
    WHERE d_parent.item_id = wi.id
      AND d_parent.type = 'parent-child'
      AND parent.defer_until IS NOT NULL
      AND parent.defer_until > NOW()
  );
```

### Readiness Criteria

An item is "ready" when ALL of the following are true:

1. Status is `open`
2. Not ephemeral (wisps are excluded from the main queue)
3. Not directly blocked by any non-closed, non-pinned item via a `blocks` dependency
4. Not transitively blocked via `parent-child` chain (up to depth 50)
5. Not deferred (`defer_until` is null or in the past)
6. Not a child of a deferred parent

### Runtime Ready Work Computation

The view is a SQL-level approximation. At runtime, the `computeBlockedIDs` function is the authoritative source of truth. It:

1. Collects active item IDs from both `work_items` and `wisps` tables
2. Loads all blocking dependencies (`blocks`, `waits-for`, `conditional-blocks`)
3. Evaluates `waits-for` gates: for `all-children`, blocked while ANY child remains active; for `any-children`, blocked while NO child has closed
4. Caches the result (invalidated on dependency/status changes)

### Sort Policies

| Policy | Behavior |
|--------|----------|
| `hybrid` (default) | Recent items (48h) sorted by priority, older items sorted by age. Prevents starvation |
| `priority` | Always sort by priority first, then creation date |
| `oldest` | Always sort by creation date (oldest first) |

### The `blocked_items` View

```sql
CREATE OR REPLACE VIEW blocked_items AS
SELECT wi.*,
    (SELECT COUNT(*)
     FROM dependencies d
     WHERE d.item_id = wi.id
       AND d.type = 'blocks'
       AND EXISTS (
         SELECT 1 FROM work_items blocker
         WHERE blocker.id = d.depends_on_id
           AND blocker.status NOT IN ('closed', 'pinned')
       )
    ) AS blocked_by_count
FROM work_items wi
WHERE wi.status NOT IN ('closed', 'pinned')
  AND EXISTS (
    SELECT 1 FROM dependencies d
    WHERE d.item_id = wi.id
      AND d.type = 'blocks'
      AND EXISTS (
        SELECT 1 FROM work_items blocker
        WHERE blocker.id = d.depends_on_id
          AND blocker.status NOT IN ('closed', 'pinned')
      )
  );
```

---

## 7. Atomic Claim (Compare-and-Swap)

When an agent picks up a work item, the claim must be atomic. Two agents requesting the same item at the same instant must result in exactly one success and one failure. No double-dispatch. No lost updates.

### Claim Operation

```sql
-- Inside a transaction:
UPDATE work_items
SET assignee = :agent_id,
    status = 'active',
    updated_at = CURRENT_TIMESTAMP
WHERE id = :item_id
  AND status = 'open'
  AND (assignee = '' OR assignee IS NULL);
-- Check affected rows:
--   1 = success (item claimed)
--   0 = item was already claimed or not open
```

### Full Sequence

1. `BEGIN` transaction
2. Read the item inside the transaction (consistent snapshot)
3. Execute conditional `UPDATE` with `WHERE (assignee='' OR assignee IS NULL)`
4. Check `RowsAffected()`:
   - `0` -> query current assignee in same transaction -> return "already claimed by X"
   - `1` -> record `claimed` event in events table
5. `DOLT_ADD('work_items', 'events')`
6. `DOLT_COMMIT('-m', 'claim wi-a1b2 by agent-name', '--author', author)`
7. Commit transaction
8. Invalidate blocked IDs cache (status changed)

The conditional UPDATE is a compare-and-swap. Cell-level merge in Dolt ensures two concurrent claims see exactly one succeed. The loser gets `RowsAffected=0` and can immediately try the next ready item.

### Release Operation

```sql
UPDATE work_items
SET assignee = NULL,
    status = 'open',
    updated_at = CURRENT_TIMESTAMP
WHERE id = :item_id
  AND assignee = :agent_id;
```

---

## 8. Formula Engine

The formula engine transforms declarative workflow templates into tracked work item hierarchies. It implements a chemistry metaphor for lifecycle management.

### The Chemistry Metaphor

| Phase | Name | Synced via Git | ID Prefix | Description |
|-------|------|----------------|-----------|-------------|
| Solid | Protomolecule | Yes | `mol-` | Frozen template. `is_template=true`. Reusable |
| Liquid | Molecule | Yes | project prefix | Full epic + all child step items. Durable |
| Vapor | Wisp | No | `wisp-` | Ephemeral. Root epic only (unless `pour=true`) |

### Phase Transitions

```
Formula (.formula.toml)
    |
    v
[platform tracker cook --persist] --> Protomolecule (solid, template)
    |
    v
[platform tracker pour <proto-id>] --> Molecule (liquid, persistent, full materialization)
    |
    v
[platform tracker wisp <proto-id>] --> Wisp (vapor, ephemeral, local-only)
    |
    |--[squash]--> Promotes wisp to persistent molecule
    |--[burn]---> Discards wisp without record
```

### Formula TOML Syntax

```toml
formula = "standard-build"
description = "Standard multi-agent build workflow"
version = 1
type = "workflow"
phase = "liquid"

[vars]
project_name = { description = "Project name", required = true }
run_security = { description = "Include security scan", default = "true" }

[[steps]]
id = "design"
title = "Design {{project_name}}"
description = "Create architecture design document"
type = "task"
priority = 1

[[steps]]
id = "implement"
title = "Implement {{project_name}}"
description = "Build the implementation"
type = "task"
depends_on = ["design"]

[[steps]]
id = "test"
title = "Test {{project_name}}"
description = "Run test suite"
type = "task"
depends_on = ["implement"]

[[steps]]
id = "security-scan"
title = "Security scan for {{project_name}}"
type = "task"
depends_on = ["implement"]
condition = "{{run_security}}"

[[steps]]
id = "review"
title = "Review {{project_name}}"
type = "task"
depends_on = ["test", "security-scan"]
waits_for = "all-children"

  [steps.gate]
  type = "gh:pr"
  id = "{{project_name}}-pr"
  timeout = "24h"
```

### Formula Types

| Type | Description |
|------|-------------|
| `workflow` | Standard step sequence that becomes an item hierarchy (default) |
| `expansion` | Reusable macro with target placeholders (`{target}`, `{target.title}`) |
| `aspect` | Cross-cutting concern with before/after/around advice rules (AOP) |

### Built-in Formulas

| Formula | Phase | Description |
|---------|-------|-------------|
| `standard-build` | liquid | Multi-phase build: design, implement, test, review, deploy |
| `patrol` | vapor | Recurring operational loop: heartbeat, health check, report |
| `review-cycle` | liquid | Code review workflow: assign, review, approve/reject, revise |
| `migration` | liquid | Database migration: plan, backup, migrate, verify, rollback-plan |

### Cooking Pipeline

The transformation pipeline runs in a fixed order:

1. **Parse and resolve inheritance** — Load formula, resolve `extends` chain, merge vars/steps/compose
2. **Apply control flow** — Expand loops, wire fork-join branches, add gate conditions
3. **Apply advice** — Insert before/after/around steps matching target globs (AOP)
4. **Apply inline expansions** — Replace steps with `expand` field by referenced expansion templates
5. **Apply compose expansions** — Process `compose.expand` (specific targets) and `compose.map` (glob matching)
6. **Apply aspects** — Load and apply aspect formulas referenced in `compose.aspects`
7. **Filter by condition** — Remove steps whose `condition` evaluates to false
8. **Materialize** — Convert resolved steps into work items with IDs, dependencies, and metadata

### Variable System

Variables support type validation, enums, regex patterns, and defaults:

```toml
[vars]
environment = { description = "Target env", required = true, enum = ["staging", "production"] }
replicas = { description = "Replica count", default = "3", type = "int" }
skip_tests = { description = "Skip tests", default = "false", type = "bool" }
service_name = { description = "Service", required = true, pattern = "^[a-z][a-z0-9-]*$" }
```

Substitution syntax: `{{variable_name}}` in titles, descriptions, and text fields.

---

## 9. Gate System

Gates are async wait conditions that block workflow steps until external events complete. They are created as work items of type `gate` linked to their parent step via a `blocks` dependency.

### Gate Types

| Type | Condition | Resolved When | Escalated When |
|------|-----------|---------------|----------------|
| `gate:gh-run` | GitHub Actions workflow | Run completes with `conclusion=success` | `conclusion` in (failure, canceled) |
| `gate:gh-pr` | Pull request | PR state is `MERGED` | PR `CLOSED` without merge |
| `gate:timer` | Clock-based delay | `current_time > created_at + timeout` | Never (timers resolve, not escalate) |
| `gate:human` | Manual approval | Explicit `platform tracker gate resolve <id>` | Never (human decides) |
| `gate:mail` | Agent message response | Response received via mail system | Timeout exceeded |
| `gate:contract` | Contract verification | Contract validation passes | Validation fails |
| `gate:bead` | Cross-project work item | Target item status becomes `closed` | (not implemented) |

### Gate Schema (on work_items table)

Gates use the shared `await_type`, `await_id`, `timeout_ns`, and `waiters` columns on the work items table.

### Gate Lifecycle

1. **Creation.** During formula cooking, a step with a `gate` field generates a sibling gate item. The gate blocks the step via a `blocks` dependency.
2. **Polling.** A patrol molecule (or cron job) periodically calls `platform tracker gate check` to evaluate open gates.
3. **Resolution.** When a gate's condition is met, the gate item is closed. This unblocks the dependent step, which enters the ready queue.
4. **Escalation.** When a gate's timeout expires without resolution, the system creates an escalation wisp and notifies waiters.

### Polling Mechanism

```bash
# Check all open gates
platform tracker gate check

# Check specific gate types
platform tracker gate check --type gh-run
platform tracker gate check --type timer

# Preview without making changes
platform tracker gate check --dry-run
```

For `gh:run` gates, the checker shells out to `gh run view <id>` to query status. For `gh:pr` gates, it uses `gh pr view <number>`. For timer gates, it compares timestamps. For `bead` gates, it opens the target project's database read-only and checks status.

---

## 10. HOP (Entity Tracking)

HOP (Human Ontological Platform) tracks agent and human identity, capabilities, work history, and quality scores. Entities are stored as work items with the `gt:agent` label — the same table, same schema, same dependency graph.

### Entity Model

Agents are regular work items with dedicated columns:

```sql
-- Agent-specific fields on work_items table:
-- hook_bead:     Current work attached to agent (0..1 cardinality)
-- role_bead:     Role definition reference (required for agents)
-- agent_state:   State machine value
-- last_activity: Updated on each action (timeout detection)
-- role_type:     Application-defined classification
-- rig:           Project name (empty for fleet-level agents)
```

### Agent State Machine

```
idle -> spawning -> running/working -> done -> idle
                        |
                     stuck -> (needs intervention)
                        |
                     dead  (set by Witness on heartbeat timeout)
```

| State | Description |
|-------|-------------|
| `idle` | Waiting for work |
| `spawning` | Starting up |
| `running` | Executing (general) |
| `working` | Actively working on a task |
| `stuck` | Blocked, needs help |
| `done` | Completed current work |
| `stopped` | Cleanly shut down |
| `dead` | Died without clean shutdown (set externally by monitor) |

### Agent ID Format

Agent IDs encode topology: `<prefix>-<rig>-<role>-<name>`

| Example | Role | Rig | Pattern |
|---------|------|-----|---------|
| `ag-mayor` | mayor | (none) | Fleet-level singleton |
| `ag-myproject-witness` | witness | myproject | One per project |
| `ag-myproject-backend-nux` | backend | myproject | Named agent in project |

### Slot Architecture

| Slot | Field | Cardinality | Purpose |
|------|-------|-------------|---------|
| `hook` | `hook_bead` | 0..1 | Current work attached to agent |
| `role` | `role_bead` | 1 | Role definition reference |

The `hook` slot enforces exclusive access. To change work: clear the current hook, then set the new one. This prevents an agent from silently dropping work.

### Entity Reference (URI)

```
hop://<platform>/<org>/<id>
```

Example: `hop://platform/acme/backend-agent-nux`

### Capability Tracking

Skill attestations use the `attests` dependency type with structured metadata:

```json
{
  "skill": "go",
  "level": "expert",
  "date": "2026-03-18T10:00:00Z",
  "evidence": "wi-a1b2",
  "notes": "Successfully implemented concurrent worker pool"
}
```

---

## 11. Wisp Routing

Wisps are ephemeral work items for orchestration overhead that would otherwise pollute the version-controlled history.

### Problem

Without wisps, a fleet of 20 agents generating heartbeats, patrol reports, and health checks creates ~6,000 rows per day in the work items table. Every one of those rows is committed to Dolt history, synced via federation, and visible in `platform tracker list`. This is noise.

### Solution

The `wisps` table mirrors the `work_items` schema exactly but is registered in `dolt_ignore` — never committed to version history. Ephemeral items are routed to wisps at write time based on the `ephemeral` flag.

```sql
-- wisps table has identical schema to work_items
-- Plus parallel tables: wisp_labels, wisp_dependencies, wisp_events, wisp_comments
-- All registered in dolt_ignore (never committed)
```

### Wisp Types and TTLs

| Category | Types | TTL | Description |
|----------|-------|-----|-------------|
| High-churn, low forensic value | `heartbeat`, `ping` | 6 hours | Liveness signals |
| Operational state | `patrol`, `gc_report` | 24 hours | Cycle reports |
| Significant events | `recovery`, `error`, `escalation` | 7 days | Events worth investigating |

### Lifecycle

1. **Creation.** `ephemeral=true` routes the item to the wisps table
2. **Active.** Wisps participate in the dependency graph alongside regular items. Cross-table cycles (regular -> wisp -> regular) are detected
3. **GC.** TTL-based garbage collection removes wisps past their expiration. Items with `no_history=true` are exempt from GC but still stored in the wisps table
4. **Promotion.** `squash` promotes a wisp to a regular work item (moves from wisps to work_items table)
5. **Discard.** `burn` deletes a wisp without record

### Impact

With wisps: ~6,000 rows/day of orchestration noise becomes ~400 durable rows/day (only significant events). Git history stays clean. Federation bandwidth drops. Query performance improves.

---

## 12. Compaction Strategy

Over time, the work items table accumulates thousands of closed items with verbose descriptions. Compaction reduces active table size without losing information.

### Trigger Criteria

| Tier | Eligibility | Reduction | Max Tokens |
|------|-------------|-----------|------------|
| Tier 1 | Closed 30+ days | ~70% | 1,024 |
| Tier 2 | Closed 90+ days AND already Tier 1 | Further reduction | (future) |

### Process

1. **Identify candidates.** Query closed items older than threshold with `compaction_level < target_tier`
2. **Summarize.** Send the item's title, description, design, acceptance criteria, and notes to an LLM with a compression prompt
3. **Validate size.** If the summary is larger than the original, skip compaction and add a warning comment
4. **Apply.** Replace `description` with the summary, clear `design`, `notes`, `acceptance_criteria`
5. **Record.** Set `compaction_level`, `compacted_at`, `compacted_at_commit` (git hash), `original_size`
6. **Snapshot.** Store the original content in `compaction_snapshots` for recovery

### Original Preservation

The original content is preserved in three ways:
- `compaction_snapshots` table (JSON blob of full original)
- `issue_snapshots` table (structured archive)
- Dolt history: queryable via `SELECT * FROM work_items AS OF '<commit-hash>' WHERE id = 'wi-a1b2'`

### Configuration

```sql
INSERT INTO config (`key`, value) VALUES
  ('compaction_enabled', 'false'),
  ('compact_tier1_days', '30'),
  ('compact_tier2_days', '90'),
  ('compact_batch_size', '50'),
  ('compact_parallel_workers', '5'),
  ('auto_compact_enabled', 'false');
```

### Batch Processing

Compaction runs in a semaphore-bounded goroutine pool (default concurrency: 5). Retry strategy: exponential backoff from 1 second, max 3 retries. Retryable errors: HTTP 429, 5xx, network timeouts.

---

## 13. CLI Reference

### CRUD Operations

```bash
# Create a work item
platform tracker create <title> \
  [--type bug|feature|task|epic|chore|decision] \
  [--priority 0-4] \
  [--description "..."] \
  [--design "..."] \
  [--acceptance "..."] \
  [--assignee agent-name] \
  [--labels "label1,label2"] \
  [--parent wi-a1b2] \
  [--due "+2d" | "2026-04-01"] \
  [--defer "+1d"] \
  [--estimate 120] \
  [--ephemeral] \
  [--external-ref "gh-42"]

# Show a work item
platform tracker show <id> [--json]

# Update fields
platform tracker update <id> \
  [--status active] \
  [--assignee agent-name] \
  [--priority 1] \
  [--title "New title"] \
  [--description "Updated desc"]

# Close (with reason)
platform tracker close <id> [--reason "Completed successfully"]
platform tracker close <id> --force          # Force close epic with open children

# Reopen
platform tracker reopen <id>

# Delete
platform tracker delete <id>

# List with filters
platform tracker list \
  [--status open|active|blocked|closed] \
  [--assignee me|agent-name|none] \
  [--priority 0-2] \
  [--type task|bug|feature] \
  [--labels "urgent,backend"] \
  [--parent wi-a1b2] \
  [--all] \
  [--sort priority|oldest|created] \
  [--limit 20] \
  [--json]

# Search
platform tracker search "login timeout" [--limit 10]

# Count
platform tracker count [--status open] [--type bug]
```

### Dependency Management

```bash
# Add a blocking dependency (A blocks B)
platform tracker dep add <source-id> --blocks <target-id>

# Add other dependency types
platform tracker dep add <source-id> --relates-to <target-id>
platform tracker dep add <source-id> --parent-child <target-id>
platform tracker dep add <source-id> --discovered-from <target-id>

# Remove a dependency
platform tracker dep remove <source-id> --blocks <target-id>

# Show dependency tree
platform tracker dep tree <id> [--depth 5] [--reverse]

# Detect cycles
platform tracker dep cycles
```

### Ready Queue and Claims

```bash
# Show ready work (open, unblocked, undeferred)
platform tracker ready \
  [--limit 10] \
  [--priority 0-2] \
  [--assignee me|none] \
  [--type task] \
  [--sort priority|hybrid|oldest] \
  [--labels "backend"]

# Show blocked items with blocker details
platform tracker blocked [--parent wi-a1b2]

# Atomic claim (compare-and-swap)
platform tracker claim <id>

# Release a claim
platform tracker release <id>

# Show current/in-progress items
platform tracker current [--assignee me]
```

### Formula Operations

```bash
# List available formulas
platform tracker formula list

# Cook a formula into a protomolecule (frozen template)
platform tracker cook <formula-name> \
  [--persist] \
  [--var project_name=myproject] \
  [--var environment=staging]

# Pour a protomolecule into a live molecule
platform tracker pour <proto-id> \
  [--var project_name=myproject]

# Create an ephemeral wisp from a protomolecule
platform tracker wisp <proto-id>

# Molecule operations
platform tracker mol show <mol-id>
platform tracker mol status <mol-id>     # Computed status from child items
platform tracker mol ready <mol-id>      # Ready items within molecule
platform tracker mol squash <wisp-id>    # Promote wisp to persistent
platform tracker mol burn <wisp-id>      # Discard wisp
```

### Gate Operations

```bash
# List open gates
platform tracker gate list [--all]

# Check and auto-resolve gates
platform tracker gate check [--type gh-run|gh-pr|timer|bead] [--dry-run]

# Manually resolve a gate
platform tracker gate resolve <gate-id>

# Show gate details
platform tracker gate show <gate-id>

# Register for notification when gate clears
platform tracker gate add-waiter <gate-id> <waiter-address>
```

### Agent Operations

```bash
# Set agent state (auto-creates agent if needed)
platform tracker agent state <agent-id> <state>

# Update heartbeat (last_activity only)
platform tracker agent heartbeat <agent-id>

# Show agent details
platform tracker agent show <agent-id> [--json]

# Slot management
platform tracker slot set <agent-id> hook <item-id>
platform tracker slot clear <agent-id> hook
platform tracker slot show <agent-id>

# Swarm coordination
platform tracker swarm validate <epic-id> [--verbose]
platform tracker swarm create <epic-id> [--coordinator agent-id]
platform tracker swarm status <swarm-id>
platform tracker swarm list
```

### Import/Export

```bash
# Import from JSON or CSV
platform tracker import <file.json|file.csv>

# Export
platform tracker export [--format json|csv|sql] [--status open] [--all]

# Backup
platform tracker backup export
platform tracker backup restore <backup-file>
```

### History and Maintenance

```bash
# Show change history for an item
platform tracker history <id>

# Compact old items (LLM-powered summarization)
platform tracker compact [--days 90] [--dry-run] [--auto]

# Garbage collection (decay + compact + dolt gc)
platform tracker gc [--older-than 90] [--dry-run]

# Health checks
platform tracker doctor [--fix] [--deep]

# Raw SQL access
platform tracker sql "SELECT COUNT(*) FROM work_items WHERE status = 'open'"

# Dolt version control
platform tracker dolt log [--limit 20]
platform tracker dolt diff
platform tracker dolt push [origin] [main]
platform tracker dolt pull [origin]
```

### Query Language

```bash
# AST-based query with boolean operators
platform tracker query "status=open AND priority<2"
platform tracker query "(type=bug OR type=task) AND assignee=none"
platform tracker query "NOT status=closed AND created>30d"
platform tracker query "label=urgent AND priority=0"
```

---

## 14. Two-Tier Architecture

The work tracker operates at two levels, each with its own Dolt database. This separates fleet-wide coordination from project-specific work while enabling cross-tier queries for full visibility.

### Fleet-Level Database

Stores cross-project entities and coordination:

| Entity | Description |
|--------|-------------|
| Agent identity | All agent items with state, capabilities, hook assignments |
| Convoys | Multi-project efforts as first-class tracked entities |
| Fleet settings | Global configuration, routing rules, federation peers |
| Cross-project dependencies | `tracks` and `external:` dependencies linking projects |

### Project-Level Database

Stores per-project work:

| Entity | Description |
|--------|-------------|
| Work items | All tasks, bugs, features, epics for this project |
| Dependencies | Intra-project blocking, parent-child, and soft dependencies |
| Formulas | Project-specific workflow templates |
| Evidence | Comments, events, audit trail, compaction snapshots |
| Wisps | Ephemeral orchestration items (dolt_ignore'd) |

### Cross-Tier References

Dependencies between tiers use the `external:<project>:<id>` format. No FK constraint on the target — the reference is resolved at query time by opening the target project's database.

```sql
-- Fleet-level query: show all agents and their current work
SELECT
    a.id AS agent_id,
    a.agent_state,
    a.hook_bead,
    a.role_type,
    a.rig AS project,
    a.last_activity
FROM work_items a
WHERE EXISTS (
    SELECT 1 FROM labels l
    WHERE l.item_id = a.id AND l.label = 'gt:agent'
)
ORDER BY a.last_activity DESC;

-- Cross-tier: convoy tracking
SELECT
    c.id AS convoy_id,
    c.title AS convoy_name,
    d.depends_on_id AS tracked_item,
    d.type
FROM work_items c
JOIN dependencies d ON c.id = d.item_id
WHERE d.type = 'tracks'
ORDER BY c.created_at DESC;
```

### Federation

Each database can be federated independently. Fleet-level databases sync across deployment instances. Project-level databases sync with their project's collaborators. Push/pull operations use Dolt's built-in replication with cell-level three-way merge.

Conflict resolution for metadata tables uses an automatic "theirs" strategy — the incoming data wins. This prevents federation sync from blocking on trivial metadata conflicts (last_sync timestamps, etc.).

### Routing

When a command receives an item ID with a prefix that does not match the current project, the routing system:

1. Checks the `routes` table for a prefix-to-path mapping
2. If found, opens the target project's database for the operation
3. If not found, checks for `external:` format and handles accordingly

This enables seamless cross-project operations: `platform tracker show external:backend:wi-a1b2` transparently opens the backend project's database.
