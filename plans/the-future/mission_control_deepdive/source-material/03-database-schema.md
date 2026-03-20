# 03 — Database Schema: SQLite WAL, Migrations, Tables, and Seed Logic

This document provides a complete inventory of Mission Control's data layer: the SQLite configuration, the full schema across 27 migrations, every table and index, the admin seed logic, type definitions, helper functions, and data retention configuration. All paths reference `~/AI/mission-control/`.

---

## SQLite Configuration

**Source:** `src/lib/db.ts` lines 19-34

Mission Control uses `better-sqlite3` as its SQLite driver. On first connection, four PRAGMAs are applied:

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = 1000;
PRAGMA foreign_keys = ON;
```

| PRAGMA | Value | Purpose |
|--------|-------|---------|
| `journal_mode` | `WAL` | Write-Ahead Logging for better concurrent read/write performance. Multiple readers can proceed while a single writer commits. |
| `synchronous` | `NORMAL` | Reduced fsync frequency. Acceptable durability trade-off for WAL mode -- data survives process crashes but not OS crashes mid-write. |
| `cache_size` | `1000` | 1000 pages (~4 MB at default page size). Moderate cache for a dashboard workload. |
| `foreign_keys` | `ON` | Enforces referential integrity. Critical because several tables use `ON DELETE CASCADE`. |

### Single-Writer Constraint

SQLite in WAL mode supports exactly one writer at a time. All other writers queue behind a write lock. Mission Control runs as a single Next.js server process, so this is a natural fit. However, this means:

1. All mutations serialize through one connection.
2. Bulk operations (e.g., the `PUT /api/tasks` bulk status update) use `db.transaction()` to batch writes atomically.
3. Background tasks (scheduler, webhook delivery) share the same `db` singleton and therefore compete for the write lock.
4. The `getDatabase()` singleton pattern (see below) guarantees a single connection per process.

---

## Database Path Resolution

**Source:** `src/lib/config.ts` lines 46-53

```typescript
const defaultDataDir = path.join(normalizedCwd, '.data')

export const config = {
  dataDir: process.env.MISSION_CONTROL_DATA_DIR || defaultDataDir,
  dbPath:
    process.env.MISSION_CONTROL_DB_PATH ||
    path.join(defaultDataDir, 'mission-control.db'),
  // ...
}
```

Default path: `<project-root>/.data/mission-control.db`

The `normalizedCwd` logic handles Next.js standalone builds where `process.cwd()` ends with `.next/standalone` -- it resolves two directories up to find the true project root.

The directory is created lazily by `ensureDirExists(dirname(DB_PATH))` on first `getDatabase()` call.

---

## The getDatabase() Singleton Pattern

**Source:** `src/lib/db.ts` lines 14-35, 547-559

```typescript
let db: Database.Database | null = null;

export function getDatabase(): Database.Database {
  if (!db) {
    ensureDirExists(dirname(DB_PATH));
    db = new Database(DB_PATH);

    db.pragma('journal_mode = WAL');
    db.pragma('synchronous = NORMAL');
    db.pragma('cache_size = 1000');
    db.pragma('foreign_keys = ON');

    initializeSchema();
  }
  return db;
}
```

Key behaviors:

1. **Lazy initialization** -- the database file is not opened until the first call to `getDatabase()`.
2. **Server-side only** -- at module load time, `if (typeof window === 'undefined')` guards the initial `getDatabase()` call.
3. **Schema + migrations** -- `initializeSchema()` runs `runMigrations(db)` then `seedAdminUserFromEnv(db)`, then lazy-imports the webhook listener and scheduler (skipping the scheduler during `next build`).
4. **Process cleanup** -- `closeDatabase()` is registered on `exit`, `SIGINT`, and `SIGTERM`.

---

## schema.sql: The Base Schema

**Source:** `src/lib/schema.sql` (122 lines)

This file defines the initial 8 tables and all their indexes. It is executed by migration `001_init`. Here is the full schema:

```sql
-- Tasks Table - Core Kanban task management
CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'inbox',
    priority TEXT NOT NULL DEFAULT 'medium',
    assigned_to TEXT,
    created_by TEXT NOT NULL DEFAULT 'system',
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
    due_date INTEGER,
    estimated_hours INTEGER,
    actual_hours INTEGER,
    tags TEXT,       -- JSON array of tags
    metadata TEXT    -- JSON for additional data
);

CREATE TABLE IF NOT EXISTS agents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL,
    session_key TEXT UNIQUE,
    soul_content TEXT,
    status TEXT NOT NULL DEFAULT 'offline',
    last_seen INTEGER,
    last_activity TEXT,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
    config TEXT      -- JSON for agent-specific configuration
);

CREATE TABLE IF NOT EXISTS comments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    author TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    parent_id INTEGER,
    mentions TEXT,   -- JSON array of @mentioned agents
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS activities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id INTEGER NOT NULL,
    actor TEXT NOT NULL,
    description TEXT NOT NULL,
    data TEXT,       -- JSON with additional context
    created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    recipient TEXT NOT NULL,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    source_type TEXT,
    source_id INTEGER,
    read_at INTEGER,
    delivered_at INTEGER,
    created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS task_subscriptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    agent_name TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    UNIQUE(task_id, agent_name),
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS standup_reports (
    date TEXT PRIMARY KEY,
    report TEXT NOT NULL,   -- JSON
    created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE TABLE IF NOT EXISTS quality_reviews (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    reviewer TEXT NOT NULL,
    status TEXT NOT NULL,   -- approved | rejected
    notes TEXT,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
);
```

### Base Indexes (from schema.sql)

| Index | Table | Column(s) |
|-------|-------|-----------|
| `idx_tasks_status` | tasks | status |
| `idx_tasks_assigned_to` | tasks | assigned_to |
| `idx_tasks_created_at` | tasks | created_at |
| `idx_comments_task_id` | comments | task_id |
| `idx_comments_created_at` | comments | created_at |
| `idx_activities_created_at` | activities | created_at |
| `idx_activities_type` | activities | type |
| `idx_notifications_recipient` | notifications | recipient |
| `idx_notifications_created_at` | notifications | created_at |
| `idx_agents_session_key` | agents | session_key |
| `idx_agents_status` | agents | status |
| `idx_task_subscriptions_task_id` | task_subscriptions | task_id |
| `idx_task_subscriptions_agent_name` | task_subscriptions | agent_name |
| `idx_standup_reports_created_at` | standup_reports | created_at |
| `idx_quality_reviews_task_id` | quality_reviews | task_id |
| `idx_quality_reviews_reviewer` | quality_reviews | reviewer |

---

## All 27 Migrations

**Source:** `src/lib/migrations.ts`

The migration system uses a `schema_migrations` table with a text `id` primary key and `applied_at` timestamp. Each migration runs inside a `db.transaction()`.

```sql
CREATE TABLE IF NOT EXISTS schema_migrations (
    id TEXT PRIMARY KEY,
    applied_at INTEGER NOT NULL DEFAULT (unixepoch())
)
```

### Migration Catalog

| # | ID | What It Does |
|---|------|-------------|
| 1 | `001_init` | Reads and executes `schema.sql` -- creates the 8 base tables (tasks, agents, comments, activities, notifications, task_subscriptions, standup_reports, quality_reviews) plus all base indexes. |
| 2 | `002_quality_reviews` | Creates `quality_reviews` table (idempotent -- already in schema.sql). Adds indexes on `task_id` and `reviewer`. |
| 3 | `003_quality_review_status_backfill` | Converts all existing tasks with `status = 'review'` to `status = 'quality_review'` to enforce the Aegis QA gate. |
| 4 | `004_messages` | Creates the `messages` table for inter-agent communication with `conversation_id`, `from_agent`, `to_agent`, `content`, `message_type`, `metadata`, `read_at`. Indexes on `(conversation_id, created_at)` and `(from_agent, to_agent)`. |
| 5 | `005_users` | Creates `users` table (username, display_name, password_hash, role) and `user_sessions` table (token, user_id, expires_at, ip_address, user_agent). Adds indexes on username, session token, user_id, and expires_at. |
| 6 | `006_workflow_templates` | Creates `workflow_templates` table for reusable agent task templates (name, model, task_prompt, timeout_seconds, agent_role, tags, use_count). Indexes on name and created_by. |
| 7 | `007_audit_log` | Creates `audit_log` table (action, actor, actor_id, target_type, target_id, detail JSON, ip_address, user_agent). Indexes on action, actor, and created_at. |
| 8 | `008_webhooks` | Creates `webhooks` table (name, url, secret, events JSON, enabled) and `webhook_deliveries` table (webhook_id, event_type, payload, status_code, response_body, error, duration_ms). Indexes on webhook_id, created_at, and enabled. |
| 9 | `009_pipelines` | Creates `workflow_pipelines` (name, steps JSON, use_count) and `pipeline_runs` (pipeline_id, status, current_step, steps_snapshot JSON, triggered_by). Indexes on pipeline_id, status, and pipeline name. |
| 10 | `010_settings` | Creates `settings` table (key TEXT PRIMARY KEY, value, description, category, updated_by). Index on category. |
| 11 | `011_alert_rules` | Creates `alert_rules` table (name, entity_type, condition_field/operator/value, action_type, action_config JSON, cooldown_minutes, trigger_count). Indexes on enabled and entity_type. |
| 12 | `012_super_admin_tenants` | Creates three tables for multi-tenant management: `tenants` (slug, linux_user, plan_tier, status, openclaw_home, workspace_root, gateway_port, dashboard_port, config JSON), `provision_jobs` (tenant_id, job_type, status, dry_run, request/plan/result JSON), and `provision_events` (job_id, level, step_key, message, data JSON). Multiple indexes. |
| 13 | `013_tenant_owner_gateway` | Adds `owner_gateway TEXT` column to `tenants`. Backfills from gateways table if it exists, otherwise uses env var `MC_DEFAULT_OWNER_GATEWAY`. Adds index on owner_gateway. |
| 14 | `014_auth_google_approvals` | Adds OAuth columns to `users`: `provider`, `provider_user_id`, `email`, `avatar_url`, `is_approved`, `approved_by`, `approved_at`. Creates `access_requests` table for pending Google sign-in approvals. Indexes on email+provider, status, provider, and email. |
| 15 | `015_missing_indexes` | Adds five performance indexes: `notifications(read_at)`, `notifications(recipient, read_at)`, `activities(actor)`, `activities(entity_type, entity_id)`, `messages(read_at)`. |
| 16 | `016_direct_connections` | Creates `direct_connections` table (agent_id FK, tool_name, tool_version, connection_id UNIQUE, status, last_heartbeat, metadata JSON). Indexes on agent_id, connection_id, status. |
| 17 | `017_github_sync` | Creates `github_syncs` table (repo, last_synced_at, issue_count, sync_direction, status, error). Indexes on repo and created_at. |
| 18 | `018_token_usage` | Creates `token_usage` table (model, session_id, input_tokens, output_tokens). Indexes on session_id, created_at, and model. |
| 19 | `019_webhook_retry` | Adds retry columns to `webhook_deliveries`: `attempt`, `next_retry_at`, `is_retry`, `parent_delivery_id`. Adds `consecutive_failures` to `webhooks`. Partial index on `next_retry_at WHERE next_retry_at IS NOT NULL`. |
| 20 | `020_claude_sessions` | Creates `claude_sessions` table for tracking local Claude Code sessions (session_id, project_slug, project_path, model, git_branch, message counts, token counts, estimated_cost, is_active, scanned_at). Partial index on `is_active WHERE is_active = 1`. |
| 21 | `021_workspace_isolation_phase1` | Creates `workspaces` table (slug UNIQUE, name). Seeds default workspace (id=1). Adds `workspace_id INTEGER NOT NULL DEFAULT 1` to 9 tables: users, user_sessions, tasks, agents, comments, activities, notifications, quality_reviews, standup_reports. Workspace indexes on all 9 tables. |
| 22 | `022_workspace_isolation_phase2` | Extends workspace isolation to 6 more tables: messages, alert_rules, direct_connections, github_syncs, workflow_pipelines, pipeline_runs. Adds workspace_id column and indexes. |
| 23 | `023_workspace_isolation_phase3` | Extends workspace isolation to 4 more tables: workflow_templates, webhooks, webhook_deliveries, token_usage. Adds workspace_id column and indexes. |
| 24 | `024_projects_support` | Creates `projects` table (workspace_id, name, slug, description, ticket_prefix, ticket_counter, status). Adds `project_id` and `project_ticket_no` columns to tasks. Seeds a "General" default project per workspace. Backfills all existing tasks into the default project and assigns sequential ticket numbers. |
| 25 | `025_token_usage_task_attribution` | Adds `task_id INTEGER` column to `token_usage` for per-task cost attribution. Indexes on `task_id` and compound `(workspace_id, task_id, created_at)`. |
| 26 | `026_task_outcome_tracking` | Adds outcome tracking columns to `tasks`: `outcome` (success/failed/partial/abandoned), `error_message`, `resolution`, `feedback_rating`, `feedback_notes`, `retry_count`, `completed_at`. Indexes on outcome, completed_at, and compound `(workspace_id, outcome, completed_at)`. |
| 27 | `027_agent_api_keys` | Creates `agent_api_keys` table (agent_id FK, workspace_id, name, key_hash UNIQUE, key_prefix, scopes JSON, expires_at, revoked_at, created_by, last_used_at). Indexes on agent_id, workspace_id, expires_at, revoked_at. |

---

## Complete Table Inventory

After all 27 migrations, the database contains these tables:

| Table | Added In | Purpose |
|-------|----------|---------|
| `schema_migrations` | Migration runner | Tracks applied migration IDs |
| `tasks` | 001 (+ 024, 026) | Core Kanban task management |
| `agents` | 001 | Agent squad registry |
| `comments` | 001 | Threaded task discussions |
| `activities` | 001 | Real-time activity stream |
| `notifications` | 001 | @mentions and alerts |
| `task_subscriptions` | 001 | Task follower subscriptions |
| `standup_reports` | 001 | Archived daily standups |
| `quality_reviews` | 001/002 | Aegis QA gate reviews |
| `messages` | 004 | Inter-agent messaging |
| `users` | 005 (+ 014) | Human operator accounts |
| `user_sessions` | 005 | Auth session tokens |
| `workflow_templates` | 006 | Reusable agent task templates |
| `audit_log` | 007 | Security/admin audit trail |
| `webhooks` | 008 (+ 019) | Webhook endpoint configs |
| `webhook_deliveries` | 008 (+ 019) | Webhook delivery history |
| `workflow_pipelines` | 009 | Multi-step pipeline definitions |
| `pipeline_runs` | 009 | Pipeline execution records |
| `settings` | 010 | Key-value settings store |
| `alert_rules` | 011 | Conditional alert rules |
| `tenants` | 012 (+ 013) | Multi-tenant management |
| `provision_jobs` | 012 | Tenant provisioning jobs |
| `provision_events` | 012 | Provisioning event log |
| `access_requests` | 014 | Google OAuth approval queue |
| `direct_connections` | 016 | CLI tool connections |
| `github_syncs` | 017 | GitHub issue sync history |
| `token_usage` | 018 (+ 025) | LLM token consumption records |
| `claude_sessions` | 020 | Local Claude Code session tracking |
| `workspaces` | 021 | Workspace isolation |
| `projects` | 024 | Project containers for tasks |
| `agent_api_keys` | 027 | Per-agent API key credentials |

**Total: 31 tables** (including `schema_migrations`)

---

## Table Relationship Diagram

```
workspaces (1)
  |
  +-- users (N) ................. workspace_id FK
  |     +-- user_sessions (N) ... user_id FK → users(id) CASCADE
  |
  +-- projects (N) .............. workspace_id FK
  |     +-- tasks (N) ........... project_id FK → projects(id)
  |           +-- comments (N) .. task_id FK → tasks(id) CASCADE
  |           |     +-- comments  parent_id FK → comments(id) SET NULL
  |           +-- quality_reviews task_id FK → tasks(id) CASCADE
  |           +-- task_subscriptions task_id FK → tasks(id) CASCADE
  |
  +-- agents (N) ................ workspace_id FK
  |     +-- direct_connections .. agent_id FK → agents(id) CASCADE
  |     +-- agent_api_keys ..... agent_id FK → agents(id) CASCADE
  |
  +-- activities (N) ............ workspace_id FK
  +-- notifications (N) ......... workspace_id FK
  +-- messages (N) .............. workspace_id FK
  +-- standup_reports (N) ....... workspace_id FK
  +-- alert_rules (N) ........... workspace_id FK
  +-- workflow_templates (N) .... workspace_id FK
  +-- workflow_pipelines (N) .... workspace_id FK
  |     +-- pipeline_runs (N) ... pipeline_id FK → workflow_pipelines(id) CASCADE
  +-- webhooks (N) .............. workspace_id FK
  |     +-- webhook_deliveries .. webhook_id FK → webhooks(id) CASCADE
  +-- token_usage (N) ........... workspace_id FK
  +-- github_syncs (N) .......... workspace_id FK

tenants (standalone, super-admin scope)
  +-- provision_jobs (N) ........ tenant_id FK → tenants(id) CASCADE
        +-- provision_events (N)  job_id FK → provision_jobs(id) CASCADE

access_requests ................. approved_user_id FK → users(id) SET NULL
audit_log ....................... standalone (no workspace scope)
claude_sessions ................. standalone
settings ........................ standalone
```

---

## Admin Seed Logic

**Source:** `src/lib/db.ts` lines 77-149

### resolveSeedAuthPassword()

The seed password resolution follows this priority:

1. **`AUTH_PASS_B64`** (env var) -- base64-decoded. Validated with a strict regex and round-trip verification (`decode → encode === original`). Falls through on invalid base64 or empty decode.
2. **`AUTH_PASS`** (env var) -- plain text fallback.
3. **Returns `null`** if neither is set.

### seedAdminUserFromEnv()

Called after migrations on every startup:

1. **Skips during `next build`** -- `process.env.NEXT_PHASE === 'phase-production-build'`.
2. **Only seeds when user table is empty** -- `SELECT COUNT(*) FROM users` must return 0.
3. **Skips if no password** -- logs a warning suggesting `AUTH_PASS` or `AUTH_PASS_B64`.
4. **Rejects insecure defaults** -- checks against a hardcoded set: `admin`, `password`, `change-me-on-first-login`, `changeme`, `testpass123`. Logs a warning and refuses to seed.
5. **Creates the admin user** -- username from `AUTH_USER` env (default: `admin`), display name is capitalized username, role is `admin`, password is bcrypt-hashed via `hashPassword()`.

```typescript
const INSECURE_PASSWORDS = new Set([
  'admin',
  'password',
  'change-me-on-first-login',
  'changeme',
  'testpass123',
])
```

---

## db_helpers: Utility Functions

**Source:** `src/lib/db.ts` lines 299-484

| Helper | Signature | Purpose |
|--------|-----------|---------|
| `logActivity` | `(type, entity_type, entity_id, actor, description, data?, workspaceId?)` | Inserts into `activities` and broadcasts `activity.created` via eventBus. |
| `createNotification` | `(recipient, type, title, message, source_type?, source_id?, workspaceId?)` | Inserts into `notifications` and broadcasts `notification.created`. |
| `parseMentions` | `(text: string): string[]` | Delegates to `parseMentionTokens()` from `src/lib/mentions.ts`. |
| `updateAgentStatus` | `(agentName, status, activity?, workspaceId?)` | Updates `agents` set status/last_seen/last_activity, broadcasts `agent.status_changed`, logs activity. |
| `getRecentActivities` | `(limit?: number): Activity[]` | Returns latest N activities ordered by created_at DESC. |
| `getUnreadNotifications` | `(recipient, workspaceId?): Notification[]` | Returns notifications where `read_at IS NULL` for a given recipient. |
| `markNotificationRead` | `(notificationId, workspaceId?)` | Sets `read_at` to current timestamp. |
| `ensureTaskSubscription` | `(taskId, agentName, workspaceId?)` | `INSERT OR IGNORE` into `task_subscriptions`. |
| `getTaskSubscribers` | `(taskId, workspaceId?): string[]` | Returns agent names subscribed to a task (joins through tasks for workspace scoping). |

### Standalone Functions

| Function | Purpose |
|----------|---------|
| `logAuditEvent(event)` | Inserts into `audit_log`. Broadcasts `audit.security` for login_failed, user_created, user_deleted, password_change. |
| `appendProvisionEvent(event)` | Inserts into `provision_events` for tenant provisioning. |

---

## Type Definitions

**Source:** `src/lib/db.ts` lines 161-297

```typescript
export interface Task {
  id: number; title: string; description?: string;
  status: 'inbox' | 'assigned' | 'in_progress' | 'review' | 'quality_review' | 'done';
  priority: 'low' | 'medium' | 'high' | 'urgent';
  project_id?: number; project_ticket_no?: number;
  project_name?: string; project_prefix?: string; ticket_ref?: string;
  assigned_to?: string; created_by: string;
  created_at: number; updated_at: number; due_date?: number;
  estimated_hours?: number; actual_hours?: number;
  outcome?: 'success' | 'failed' | 'partial' | 'abandoned';
  error_message?: string; resolution?: string;
  feedback_rating?: number; feedback_notes?: string;
  retry_count?: number; completed_at?: number;
  tags?: string; metadata?: string;  // both JSON strings
}

export interface Agent {
  id: number; name: string; role: string;
  session_key?: string; soul_content?: string;
  status: 'offline' | 'idle' | 'busy' | 'error';
  last_seen?: number; last_activity?: string;
  created_at: number; updated_at: number;
  config?: string;  // JSON string
}

export interface Comment {
  id: number; task_id: number; author: string;
  content: string; created_at: number;
  parent_id?: number; mentions?: string;  // JSON string
}

export interface Activity {
  id: number; type: string; entity_type: string;
  entity_id: number; actor: string;
  description: string; data?: string;  // JSON string
  created_at: number;
}

export interface Message {
  id: number; conversation_id: string;
  from_agent: string; to_agent?: string;
  content: string; message_type: string;
  metadata?: string; read_at?: number; created_at: number;
}

export interface Notification {
  id: number; recipient: string; type: string;
  title: string; message: string;
  source_type?: string; source_id?: number;
  read_at?: number; delivered_at?: number; created_at: number;
}

export interface Tenant {
  id: number; slug: string; display_name: string;
  linux_user: string; plan_tier: string;
  status: 'pending' | 'provisioning' | 'active' | 'suspended' | 'error';
  openclaw_home: string; workspace_root: string;
  gateway_port?: number; dashboard_port?: number;
  config?: string; created_by: string;
  owner_gateway?: string;
  created_at: number; updated_at: number;
}

export interface ProvisionJob {
  id: number; tenant_id: number;
  job_type: 'bootstrap' | 'update' | 'decommission';
  status: 'queued' | 'approved' | 'running' | 'completed' | 'failed' | 'rejected' | 'cancelled';
  dry_run: 0 | 1; requested_by: string;
  approved_by?: string; runner_host?: string;
  idempotency_key?: string;
  request_json?: string; plan_json?: string;
  result_json?: string; error_text?: string;
  started_at?: number; completed_at?: number;
  created_at: number; updated_at: number;
}

export interface ProvisionEvent {
  id: number; job_id: number;
  level: 'info' | 'warn' | 'error';
  step_key?: string; message: string;
  data?: string; created_at: number;
}
```

---

## Data Retention Configuration

**Source:** `src/lib/config.ts` lines 78-87

```typescript
retention: {
  activities:       Number(process.env.MC_RETAIN_ACTIVITIES_DAYS       || '90'),
  auditLog:         Number(process.env.MC_RETAIN_AUDIT_DAYS            || '365'),
  logs:             Number(process.env.MC_RETAIN_LOGS_DAYS             || '30'),
  notifications:    Number(process.env.MC_RETAIN_NOTIFICATIONS_DAYS    || '60'),
  pipelineRuns:     Number(process.env.MC_RETAIN_PIPELINE_RUNS_DAYS    || '90'),
  tokenUsage:       Number(process.env.MC_RETAIN_TOKEN_USAGE_DAYS      || '90'),
  gatewaySessions:  Number(process.env.MC_RETAIN_GATEWAY_SESSIONS_DAYS || '90'),
}
```

| Data Type | Env Var | Default | Cleaned By |
|-----------|---------|---------|------------|
| Activities | `MC_RETAIN_ACTIVITIES_DAYS` | 90 days | `POST /api/cleanup` |
| Audit Log | `MC_RETAIN_AUDIT_DAYS` | 365 days | `POST /api/cleanup` |
| Log Files | `MC_RETAIN_LOGS_DAYS` | 30 days | Scheduler |
| Notifications | `MC_RETAIN_NOTIFICATIONS_DAYS` | 60 days | `POST /api/cleanup` |
| Pipeline Runs | `MC_RETAIN_PIPELINE_RUNS_DAYS` | 90 days | `POST /api/cleanup` |
| Token Usage | `MC_RETAIN_TOKEN_USAGE_DAYS` | 90 days | `POST /api/cleanup` (DB + JSON file) |
| Gateway Sessions | `MC_RETAIN_GATEWAY_SESSIONS_DAYS` | 90 days | `POST /api/cleanup` (filesystem) |

Setting any value to `0` disables retention for that category (keeps data forever).

---

## Hive Implementation Notes

For a system inspired by this architecture:

1. **WAL mode is essential** for a dashboard with SSE streaming and background tasks. The single-writer model works because all mutations go through one Next.js process.
2. **The migration system is minimal and effective** -- plain TypeScript functions with string IDs, run in order, each wrapped in a transaction. No rollback support; migrations are append-only.
3. **workspace_id was retrofitted** across three phases (migrations 021-023) rather than designed in from the start. A Hive implementation should add workspace isolation from day one.
4. **The projects system** (migration 024) includes automatic ticket numbering via an atomic counter pattern: increment `ticket_counter` in a transaction, then use that number for the new task's `project_ticket_no`.
5. **JSON columns** (tags, metadata, config, steps, etc.) are stored as `TEXT` and parsed in application code. SQLite's `json_extract()` is never used -- all filtering is done after deserialization.
6. **All timestamps are Unix epoch seconds** (via `unixepoch()` default), not milliseconds. The application converts to/from JS timestamps where needed.
