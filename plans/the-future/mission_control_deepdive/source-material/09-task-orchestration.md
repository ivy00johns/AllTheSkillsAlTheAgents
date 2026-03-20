# 09 — Task Orchestration: Kanban, Aegis Quality Gates, Pipelines, and Dispatch

This document dissects Mission Control's task lifecycle from inbox to done, covering the six-column Kanban state machine, the Aegis quality gate, task queue polling, regression detection, threaded comments, pipelines, workflows, projects, the background scheduler, and workload signals.

---

## The Kanban State Machine

Mission Control implements a six-column Kanban board encoded as a `status` enum on the `tasks` table:

```
inbox → assigned → in_progress → review → quality_review → done
```

The schema definition lives in `src/lib/schema.sql`:

```sql
status TEXT NOT NULL DEFAULT 'inbox'
  -- inbox, assigned, in_progress, review, quality_review, done
```

### Status Transitions

There is no hard-coded state machine enforcing valid transitions. Any status value from the enum is accepted by the API, with two critical exceptions:

1. **Transition to `done` requires Aegis approval** -- checked via `hasAegisApproval()` in both `src/app/api/tasks/route.ts` (PUT bulk) and `src/app/api/tasks/[id]/route.ts` (PUT single). If approval is missing, the API returns `403 Forbidden`.

2. **Auto-normalization on create and update** -- handled by `src/lib/task-status.ts`:
   - On create: if `status=inbox` but `assigned_to` is set, status auto-promotes to `assigned`
   - On update: if assigning someone to an `inbox` task (without explicit status change), status auto-promotes to `assigned`. Conversely, clearing `assigned_to` on an `assigned` task demotes back to `inbox`.

```typescript
// src/lib/task-status.ts
export function normalizeTaskCreateStatus(
  requestedStatus: TaskStatus | undefined,
  assignedTo: string | undefined
): TaskStatus {
  const status = requestedStatus ?? 'inbox'
  if (status === 'inbox' && hasAssignee(assignedTo)) return 'assigned'
  return status
}
```

### Drag-and-Drop Bulk Update

The PUT handler on `/api/tasks` supports batch status changes (designed for Kanban drag-and-drop):

```typescript
// src/app/api/tasks/route.ts
const bulkUpdateTaskStatusSchema = z.object({
  tasks: z.array(z.object({
    id: z.number().int().positive(),
    status: z.enum(['inbox', 'assigned', 'in_progress', 'review', 'quality_review', 'done']),
  })).min(1).max(100),
})
```

Each task in the batch is checked for Aegis approval before transitioning to `done`. When a task reaches `done`, `completed_at` is set via `COALESCE(completed_at, ?)` to preserve any earlier timestamp.

---

## Task Data Model

The full task record spans the following fields (from `src/lib/validation.ts` `createTaskSchema` and the SQL schema):

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `id` | INTEGER PK | auto | Auto-increment |
| `title` | TEXT | required | max 500 chars, must be unique per workspace |
| `description` | TEXT | null | max 5000 chars, supports @mentions |
| `status` | TEXT enum | `inbox` | Six-column Kanban |
| `priority` | TEXT enum | `medium` | `critical`, `high`, `medium`, `low` |
| `project_id` | INTEGER FK | resolved | Falls back to "general" project |
| `project_ticket_no` | INTEGER | auto | Auto-incremented per project |
| `assigned_to` | TEXT | null | Agent name or user |
| `created_by` | TEXT | `system` | Actor who created the task |
| `created_at` | INTEGER | `unixepoch()` | Unix seconds |
| `updated_at` | INTEGER | `unixepoch()` | Unix seconds |
| `due_date` | INTEGER | null | Unix timestamp |
| `estimated_hours` | INTEGER | null | |
| `actual_hours` | INTEGER | null | |
| `outcome` | TEXT enum | null | `success`, `failed`, `partial`, `abandoned` |
| `error_message` | TEXT | null | max 5000 chars |
| `resolution` | TEXT | null | max 5000 chars |
| `feedback_rating` | INTEGER | null | 1-5 scale |
| `feedback_notes` | TEXT | null | max 5000 chars |
| `retry_count` | INTEGER | 0 | Incremented on retries |
| `completed_at` | INTEGER | null | Set automatically when status=done |
| `tags` | TEXT (JSON) | `[]` | JSON array of strings |
| `metadata` | TEXT (JSON) | `{}` | Arbitrary key/value, used for GitHub sync |
| `workspace_id` | INTEGER | required | Multi-tenant isolation |

### Priority Levels

Four priority levels, ordered by urgency: `critical > high > medium > low`. The task queue uses a SQL CASE expression for priority ranking:

```sql
CASE priority
  WHEN 'critical' THEN 0
  WHEN 'high' THEN 1
  WHEN 'medium' THEN 2
  WHEN 'low' THEN 3
  ELSE 4
END
```

### Ticket References

Tasks get a formatted ticket reference like `PA-001` composed from the project's `ticket_prefix` and the task's `project_ticket_no`. The formatter is:

```typescript
function formatTicketRef(prefix?: string | null, num?: number | null): string | undefined {
  if (!prefix || typeof num !== 'number') return undefined
  return `${prefix}-${String(num).padStart(3, '0')}`
}
```

---

## Task Creation Flow

`POST /api/tasks` in `src/app/api/tasks/route.ts`:

```
Client POST → auth (operator role) → rate limit → validate body (Zod)
  → duplicate title check → resolve @mentions (reject if unresolved)
  → resolve project_id (fallback to "general")
  → transaction {
      increment project.ticket_counter
      INSERT task with allocated ticket_no
    }
  → log activity → subscribe creator → notify mentioned users
  → notify assignee (if set) → SELECT created task with project join
  → eventBus.broadcast('task.created', parsedTask) → SSE → browser
  → return 201 with task JSON
```

Key design decisions:

- **Title uniqueness** is enforced per workspace (409 Conflict on duplicate)
- **Project resolution** is automatic -- if no `project_id` is provided, the system finds the first active project (preferring one with slug `general`)
- **Ticket counter** is incremented atomically within a transaction via `UPDATE projects SET ticket_counter = ticket_counter + 1`
- **@mention validation** is strict -- unresolved mentions return 400 with `missing_mentions` array
- **SSE broadcast** happens after insert via the `eventBus` singleton (see Event Bus section)

---

## Task Assignment and Agent Dispatch

Assignment happens through the PUT endpoint on individual tasks (`src/app/api/tasks/[id]/route.ts`). When `assigned_to` changes:

1. Status auto-promotes from `inbox` to `assigned` (unless explicit status provided)
2. The new assignee gets a subscription to the task via `ensureTaskSubscription()`
3. A notification is created for the new assignee
4. An activity log entry records the change

There is no push-based dispatch. Agents pull work from the queue.

---

## Task Queue Polling

`GET /api/tasks/queue` in `src/app/api/tasks/queue/route.ts` is the primary mechanism for agents to request work.

### Request

```
GET /api/tasks/queue?agent=my-agent&max_capacity=3
  -- or --
GET /api/tasks/queue  (with x-agent-name header)
```

### Algorithm

```
1. Check for existing in_progress task for this agent
   → If found: return it with reason="continue_current"

2. Count agent's in_progress tasks
   → If count >= max_capacity: return null with reason="at_capacity"

3. Atomic pickup loop (up to 5 attempts for race safety):
   a. SELECT candidate from tasks WHERE status IN ('assigned', 'inbox')
      AND (assigned_to IS NULL OR assigned_to = agent)
      ORDER BY priority ASC, due_date ASC NULLS LAST, created_at ASC
   b. UPDATE tasks SET status='in_progress', assigned_to=agent
      WHERE id=candidate AND status IN ('assigned', 'inbox')
      AND (assigned_to IS NULL OR assigned_to = agent)
   c. If UPDATE changed rows → return task with reason="assigned"
   d. If UPDATE changed 0 rows → retry (another agent grabbed it)

4. No candidates found → return null with reason="no_tasks_available"
```

### Response Shape

```json
{
  "task": { ... } | null,
  "reason": "continue_current" | "assigned" | "at_capacity" | "no_tasks_available",
  "agent": "agent-name",
  "timestamp": 1710000000
}
```

### Race Safety

The 5-attempt loop with a `WHERE status IN ('assigned', 'inbox')` guard on the UPDATE prevents double-assignment. If another agent claimed the task between SELECT and UPDATE, the `changes` count is 0 and the loop retries with the next candidate.

---

## Task Broadcasting

`POST /api/tasks/[id]/broadcast` in `src/app/api/tasks/[id]/broadcast/route.ts` sends a message to all task subscribers via their active OpenClaw gateway sessions:

1. Looks up all subscribers for the task (excluding the sender)
2. For each subscriber that is an agent with a `session_key`:
   - Calls `runOpenClaw(['gateway', 'sessions_send', '--session', key, '--message', msg])` with a 10-second timeout
   - Creates a notification in the database
3. Returns `{ sent, skipped }` counts

---

## Task Outcomes

`GET /api/tasks/outcomes` in `src/app/api/tasks/outcomes/route.ts` provides analytics over completed tasks:

- Supports timeframe filtering: `?timeframe=day|week|month|all`
- Aggregates by outcome (`success`, `failed`, `partial`, `abandoned`, `unknown`)
- Breaks down by agent and by priority
- Computes success rate, average retry count, average time-to-resolution
- Lists top 10 common error messages

This powers the outcomes dashboard for monitoring agent reliability.

---

## Task Regression Detection

`GET /api/tasks/regression` in `src/app/api/tasks/regression/route.ts` implements a before/after comparison for detecting quality regressions after deployments.

### Parameters

- `beta_start` (required): Unix timestamp or ISO date marking the cutover point
- `lookback_seconds` (optional, default 7 days): How far back to build the baseline window

### Algorithm

1. Build two windows: **baseline** (before beta_start) and **post** (after beta_start)
2. For each window, compute:
   - **Latency** p50, p95, avg (seconds from `created_at` to `completed_at`)
   - **Intervention rate**: tasks with `retry_count > 0` OR `outcome in (failed, partial, abandoned)` OR non-empty `error_message`
3. Return deltas: `p95_latency_seconds` and `intervention_rate` changes

### Metric Definitions

```json
{
  "p95_task_latency_seconds": "95th percentile of (completed_at - created_at) for done tasks",
  "intervention_rate": "intervened_task_count / sample_size where intervened = retry_count>0 OR outcome in {failed,partial,abandoned} OR error_message not empty"
}
```

---

## Threaded Comments

Comments live in the `comments` table (`src/lib/schema.sql`) and support threaded replies via `parent_id`:

```sql
CREATE TABLE IF NOT EXISTS comments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    author TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    parent_id INTEGER,                    -- For nested replies
    mentions TEXT,                         -- JSON array of @mentioned agents
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE SET NULL
);
```

### Comment API

`src/app/api/tasks/[id]/comments/route.ts`:

- **GET**: Returns comments organized into thread structure via two-pass algorithm (first pass builds map, second pass assigns replies to parents)
- **POST**: Creates comment with @mention resolution:
  1. Validates parent_id exists (if threaded reply)
  2. Resolves @mentions via `resolveMentionRecipients()` -- rejects unresolved mentions with 400
  3. Inserts comment with parsed mention tokens
  4. Auto-subscribes: author, all mentioned users, and task assignee
  5. Notifies all subscribers (except author), with mention-specific vs generic notification text

### @mention Resolution

`src/lib/mentions.ts` parses `@handle` tokens using the regex `/(^|[^A-Za-z0-9._-])@([A-Za-z0-9][A-Za-z0-9._-]{0,63})/g` and resolves them against both the `users` and `agents` tables. Agents can be mentioned by their display name, kebab-case name, or `openclawId` from their config.

---

## Aegis Quality Gates

The quality review system implements a mandatory gate before tasks can reach `done`.

### The `quality_reviews` Table

```sql
CREATE TABLE IF NOT EXISTS quality_reviews (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    reviewer TEXT NOT NULL,          -- e.g., "aegis"
    status TEXT NOT NULL,            -- 'approved' | 'rejected'
    notes TEXT,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    workspace_id INTEGER,
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);
```

### The `hasAegisApproval()` Guard

This function appears in both the bulk update handler and the single-task update handler:

```typescript
function hasAegisApproval(db, taskId, workspaceId): boolean {
  const review = db.prepare(`
    SELECT status FROM quality_reviews
    WHERE task_id = ? AND reviewer = 'aegis' AND workspace_id = ?
    ORDER BY created_at DESC LIMIT 1
  `).get(taskId, workspaceId)
  return review?.status === 'approved'
}
```

It checks the **most recent** review by the `aegis` reviewer. If no approved review exists, any attempt to move a task to `done` returns 403:

```json
{ "error": "Aegis approval is required to move task to done." }
```

### Quality Review API

`POST /api/quality-review` (`src/app/api/quality-review/route.ts`):

```typescript
const qualityReviewSchema = z.object({
  taskId: z.number(),
  reviewer: z.string().default('aegis'),
  status: z.enum(['approved', 'rejected']),
  notes: z.string().min(1, 'Notes are required for quality reviews'),
})
```

When Aegis approves a task, the API **auto-advances** the task to `done`:

```typescript
if (status === 'approved' && reviewer === 'aegis') {
  db.prepare('UPDATE tasks SET status = ?, updated_at = unixepoch() WHERE id = ?')
    .run('done', taskId)
  eventBus.broadcast('task.status_changed', { id: taskId, status: 'done' })
}
```

### Manual vs Automated Approval

The reviewer field defaults to `'aegis'` but can be any string. The `hasAegisApproval()` guard specifically checks for `reviewer = 'aegis'`, meaning:

- Manual reviews by other reviewers are logged but don't unlock the `done` transition
- Only the `aegis` reviewer (typically an automated quality agent) can gate completion
- Multiple reviews are supported -- only the most recent from `aegis` matters

### Batch Status Checking

`GET /api/quality-review?taskIds=1,2,3` returns the latest review for each task, enabling the Kanban board to show approval indicators on multiple cards at once.

---

## The Four-Layer Evaluation Stack (Implicit)

While not implemented as a dedicated subsystem, the task data model supports a four-layer evaluation approach:

1. **Output evals**: Tasks have `outcome` (success/failed/partial/abandoned), `feedback_rating` (1-5), and `feedback_notes` -- these capture whether the output met expectations.

2. **Trace evals**: The regression endpoint (`/api/tasks/regression`) computes convergence-like metrics: p50/p95 latency and intervention rates over sliding windows. A convergence score > 3.0 can be derived from the success rate.

3. **Component evals**: Token usage tracking (`src/lib/task-costs.ts`) provides per-task cost breakdowns by model, with timeline data. The `TaskCostReport` structure aggregates by task, agent, and project.

4. **Drift detection**: The regression endpoint's baseline/post comparison with configurable lookback windows implements drift detection. The `intervention_rate` delta provides a 4-week baseline comparison.

---

## Projects

Projects provide multi-project grouping with unique ticket prefixes.

### Project Data Model

From `src/app/api/projects/route.ts`:

| Field | Type | Notes |
|-------|------|-------|
| `id` | INTEGER PK | |
| `workspace_id` | INTEGER | Multi-tenant isolation |
| `name` | TEXT | Display name |
| `slug` | TEXT | URL-safe, max 64 chars, generated via `slugify()` |
| `description` | TEXT | Optional |
| `ticket_prefix` | TEXT | Uppercase, max 12 chars, e.g., "PA" |
| `ticket_counter` | INTEGER | Auto-incremented per task creation |
| `status` | TEXT | `active` or archived |

### Ticket Numbering

Each project maintains its own `ticket_counter`. When a task is created:

1. The system resolves the project (explicit `project_id` or fallback to "general")
2. Atomically increments `ticket_counter` on the project
3. Assigns the new counter value as `project_ticket_no` on the task
4. The frontend displays this as `{ticket_prefix}-{padded_number}`, e.g., `PA-001`

### Slug and Prefix Generation

```typescript
function slugify(input: string): string {
  return input.trim().toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 64)
}

function normalizePrefix(input: string): string {
  return input.trim().toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 12)
}
```

Uniqueness is enforced on both `slug` and `ticket_prefix` within a workspace (409 Conflict on collision).

---

## Pipelines and Workflows

### Workflow Templates

Workflow templates (`workflow_templates` table) are reusable task definitions:

| Field | Type | Notes |
|-------|------|-------|
| `name` | TEXT | Required |
| `description` | TEXT | Optional |
| `model` | TEXT | Default `'sonnet'` |
| `task_prompt` | TEXT | The prompt sent to the agent |
| `timeout_seconds` | INTEGER | Default 300 |
| `agent_role` | TEXT | Optional role constraint |
| `tags` | TEXT (JSON) | Array of strings |
| `use_count` | INTEGER | Incremented on each use |
| `last_used_at` | INTEGER | Timestamp of last use |

### Pipelines (DAG Structure)

Pipelines (`workflow_pipelines` table) chain workflow templates into sequential execution:

```typescript
interface PipelineStep {
  template_id: number
  on_failure: 'stop' | 'continue'  // Controls failure propagation
}
```

The `steps` field stores a JSON array of these step definitions. Each step references a workflow template by ID.

### Pipeline Run Tracking

`pipeline_runs` table tracks execution state:

| Field | Type | Notes |
|-------|------|-------|
| `pipeline_id` | INTEGER FK | Parent pipeline |
| `status` | TEXT | `pending`, `running`, `completed`, `failed`, `cancelled` |
| `current_step` | INTEGER | Index of currently executing step |
| `steps_snapshot` | TEXT (JSON) | Full step state array |
| `started_at` | INTEGER | |
| `completed_at` | INTEGER | |
| `triggered_by` | TEXT | Actor who started the run |

### Pipeline Execution (`src/app/api/pipelines/run/route.ts`)

**Start**: `POST /api/pipelines/run { action: "start", pipeline_id: N }`

1. Loads pipeline and resolves all template IDs
2. Creates `RunStepState[]` snapshot with first step marked `running`
3. Inserts `pipeline_runs` record
4. Spawns first step via `runOpenClaw(['agent', '--message', prompt, '--timeout', N, '--json'])`
5. Returns run state with spawn result

**Advance**: `POST /api/pipelines/run { action: "advance", run_id: N, success: bool }`

1. Marks current step as completed/failed
2. If failed and `on_failure === 'stop'`: marks remaining steps as `skipped`, sets run to `failed`
3. If more steps remain: marks next step as `running`, spawns it
4. If all steps done: marks run as `completed`

**Cancel**: `POST /api/pipelines/run { action: "cancel", run_id: N }`

Marks all pending/running steps as `skipped` and sets run status to `cancelled`.

---

## The Scheduler

`src/lib/scheduler.ts` implements a background job scheduler with configurable intervals.

### Architecture

```
initScheduler() → registers 5 tasks → starts 60-second tick loop
                                        ↓
                                    tick() checks each task:
                                      - Is it running? Skip
                                      - Is nextRun > now? Skip
                                      - Is setting disabled? Skip
                                      - Otherwise: execute and reschedule
```

### Registered Tasks

| Task ID | Name | Interval | Default Enabled | Setting Key |
|---------|------|----------|-----------------|-------------|
| `auto_backup` | Auto Backup | 24h (at ~3AM UTC) | Configurable | `general.auto_backup` |
| `auto_cleanup` | Auto Cleanup | 24h (at ~4AM UTC) | Configurable | `general.auto_cleanup` |
| `agent_heartbeat` | Agent Heartbeat Check | 5 minutes | Always on | `general.agent_heartbeat` |
| `webhook_retry` | Webhook Retry | 60 seconds | Always on | `webhooks.retry_enabled` |
| `claude_session_scan` | Claude Session Scan | 60 seconds | Always on | `general.claude_session_scan` |

### Job Descriptions

- **Auto Backup**: Uses `db.backup()` to create timestamped SQLite backups in a `backups/` directory. Prunes old backups based on `general.backup_retention_count` setting (default 10).

- **Auto Cleanup**: Deletes old records from `activities`, `audit_log`, `notifications`, `pipeline_runs` based on configurable retention periods. Also prunes token usage files and gateway sessions.

- **Agent Heartbeat**: Marks agents as `offline` if `last_seen` exceeds `general.agent_timeout_minutes` (default 10). Creates notifications for each agent marked offline.

- **Webhook Retry**: Calls `processWebhookRetries()` to pick up failed webhook deliveries with pending `next_retry_at` timestamps.

- **Claude Session Scan**: Calls `syncClaudeSessions()` to scan `~/.claude/projects/` for JSONL session files and upsert session data into the database.

### Scheduler API

`src/app/api/scheduler/route.ts`:

- `GET /api/scheduler`: Returns status of all scheduled tasks (enabled, lastRun, nextRun, running, lastResult)
- `POST /api/scheduler { task_id: "auto_backup" }`: Manually triggers a specific task

---

## Workload Signals

`GET /api/workload` in `src/app/api/workload/route.ts` provides real-time capacity metrics and a throttle recommendation.

### Response Structure

```typescript
{
  timestamp: number,
  workspace_id: number,
  capacity: CapacityMetrics,
  queue: QueueMetrics,
  agents: AgentMetrics,
  recommendation: Recommendation,
  thresholds: Thresholds,
}
```

### Capacity Metrics

| Metric | Source |
|--------|--------|
| `active_tasks` | COUNT of tasks in assigned/in_progress/review/quality_review |
| `tasks_last_5m` | Activities of type task_created/task_assigned in last 5 min |
| `errors_last_5m` | Activities matching `%error%` or `%fail%` in last 5 min |
| `error_rate_5m` | errors / total activities in the window |
| `completions_last_hour` | Tasks moved to done in last hour |
| `avg_completion_rate_per_hour` | Completions in last 24h / 24 |

### Queue Metrics

| Metric | Source |
|--------|--------|
| `total_pending` | Tasks in any non-done status |
| `by_status` | Breakdown by status column |
| `by_priority` | Breakdown by priority |
| `oldest_pending_age_seconds` | Age of oldest inbox/assigned task |
| `estimated_wait_seconds` | pending / completions_per_hour * 3600 |

### Recommendation Engine

Four levels with escalation logic:

| Level | Trigger Conditions | Suggested Delay | Submit OK? |
|-------|-------------------|-----------------|------------|
| `normal` | All metrics in bounds | 0ms | Yes |
| `throttle` | Error rate >= 10% OR queue >= 50 OR busy ratio >= 80% | 2000ms | Yes |
| `shed` | Error rate >= 25% OR queue >= 100 OR busy ratio >= 95% | 10000ms | No |
| `pause` | No agents online | 30000ms | No |

Thresholds are configurable via environment variables (`MC_WORKLOAD_QUEUE_DEPTH_NORMAL`, etc.).

---

## Event Bus and SSE

`src/lib/event-bus.ts` implements a singleton `ServerEventBus` extending Node.js `EventEmitter`:

```typescript
class ServerEventBus extends EventEmitter {
  broadcast(type: EventType, data: any): ServerEvent {
    const event = { type, data, timestamp: Date.now() }
    this.emit('server-event', event)
    return event
  }
}
```

### Event Types

```typescript
type EventType =
  | 'task.created' | 'task.updated' | 'task.deleted' | 'task.status_changed'
  | 'chat.message' | 'chat.message.deleted'
  | 'notification.created' | 'notification.read'
  | 'activity.created'
  | 'agent.updated' | 'agent.created' | 'agent.deleted' | 'agent.synced' | 'agent.status_changed'
  | 'audit.security'
  | 'connection.created' | 'connection.disconnected'
  | 'github.synced'
```

The bus uses `globalThis` to survive Next.js HMR in development. Max listeners is set to 50.

Every task mutation broadcasts an appropriate event, which SSE-connected browsers receive in real time. The webhook system also subscribes to this bus to deliver outbound webhooks.

---

## Task Cost Tracking

`src/lib/task-costs.ts` provides a comprehensive cost attribution system:

### `TaskCostReport` Structure

```typescript
interface TaskCostReport {
  summary: TokenStats           // Overall stats for attributed records
  tasks: TaskCostEntry[]        // Per-task breakdown, sorted by cost desc
  agents: Record<string, AgentTaskCostEntry>    // Per-agent aggregation
  projects: Record<string, ProjectTaskCostEntry> // Per-project aggregation
  unattributed: TokenStats      // Records without a task_id
}
```

Each `TaskCostEntry` includes:
- Stats (totalTokens, totalCost, requestCount, averages)
- Per-model breakdown
- Daily timeline (date, cost, tokens)
- Project reference with ticket ref

This enables questions like "How much did task PA-042 cost?" and "Which agent is most expensive?"

---

## Cron Occurrence Calculator

`src/lib/cron-occurrences.ts` provides a pure-function cron expression evaluator:

```typescript
export function getCronOccurrences(
  schedule: string,
  rangeStartMs: number,
  rangeEndMs: number,
  max = 1000
): CronOccurrence[]
```

It supports standard 5-field cron syntax with ranges, steps, and comma-separated values. This is used for visualizing recurring task schedules on the calendar view. The parser strips timezone suffixes (e.g., `0 9 * * 1 (America/New_York)`) before evaluation.

---

## Summary for The Hive

Key patterns to replicate:

1. **Quality gates as database queries, not middleware** -- The `hasAegisApproval()` function is a simple SELECT, checked at the point of transition. No middleware chain, no workflow engine.

2. **Optimistic concurrency on queue pickup** -- The 5-attempt atomic UPDATE loop is lightweight and effective for low-contention workloads.

3. **Event bus as the integration seam** -- All real-time features (SSE, webhooks, notifications) flow through a single EventEmitter singleton. Adding a new consumer means one `eventBus.on()` call.

4. **Workload signals as a read-only API** -- Agents voluntarily check `/api/workload` before submitting work. No enforced backpressure, just advisory signals.

5. **Pipelines are sequential, not DAG** -- Despite the term "DAG" in docs, the actual implementation is a strictly sequential step chain with per-step `on_failure: 'stop' | 'continue'` behavior.

6. **Projects are lightweight namespaces** -- Just a name, slug, and ticket counter. No permissions, no hierarchy, no inheritance.
