# 04 — API Surface: Complete Endpoint Catalog

This document catalogs every REST endpoint in Mission Control's API -- 83 route files exposing 120+ individual HTTP method handlers. All paths reference `~/AI/mission-control/src/app/api/`.

---

## API Route Pattern

Every endpoint follows the same structural pattern:

```typescript
export async function METHOD(request: NextRequest) {
  // 1. Auth gate
  const auth = requireRole(request, 'viewer' | 'operator' | 'admin')
  if ('error' in auth) return NextResponse.json({ error: auth.error }, { status: auth.status })

  // 2. Rate limit (mutations/heavy operations)
  const rateCheck = mutationLimiter(request)
  if (rateCheck) return rateCheck

  // 3. Validate body (POST/PUT with Zod schemas)
  const validated = await validateBody(request, schema)
  if ('error' in validated) return validated.error

  // 4. Execute business logic
  // 5. Return JSON response
}
```

### Role Hierarchy

| Role | Level | Can Access |
|------|-------|-----------|
| `viewer` | Lowest | Read-only endpoints |
| `operator` | Mid | Create/update/delete operations |
| `admin` | Highest | User management, settings, webhooks, cleanup, super-admin |

Auth is checked via `requireRole()` from `src/lib/auth.ts`. It reads the `mc-session` cookie or `Authorization: Bearer <token>` header, validates against `user_sessions`, and checks the role hierarchy. Agent API keys (prefixed `mca_`) are also accepted and resolved against `agent_api_keys`.

---

## Validation Schemas

**Source:** `src/lib/validation.ts`

| Schema | Used By | Key Fields |
|--------|---------|------------|
| `createTaskSchema` | `POST /api/tasks` | title (1-500), description (max 5000), status enum, priority enum, project_id, assigned_to, due_date, estimated/actual hours, outcome, error_message, resolution, feedback_rating (1-5), retry_count, tags[], metadata{} |
| `updateTaskSchema` | `PUT /api/tasks/[id]` | All createTaskSchema fields, all optional (`.partial()`) |
| `bulkUpdateTaskStatusSchema` | `PUT /api/tasks` | tasks[]: array of {id, status} (1-100 items) |
| `createAgentSchema` | `POST /api/agents` | name (1-100), openclaw_id (kebab-case), role, session_key, soul_content (max 50k), status enum, config{}, template, gateway_config{}, write_to_gateway, provision_openclaw_workspace, openclaw_workspace_path |
| `createWebhookSchema` | `POST /api/webhooks` | name (1-200), url (valid URL), events[], generate_secret |
| `createAlertSchema` | `POST /api/alerts` | name (1-200), entity_type enum (agent/task/session/activity), condition_field/operator/value, action_type, action_config{}, cooldown_minutes (1-10080) |
| `notificationActionSchema` | `POST /api/notifications` | action: 'mark-delivered', agent (required) |
| `integrationActionSchema` | `POST /api/integrations` | action: test/pull/pull-all, integrationId?, category? |
| `createPipelineSchema` | `POST /api/pipelines` | name, description, steps[]: {template_id, on_failure} (min 2 steps) |
| `createWorkflowSchema` | `POST /api/workflows` | name, task_prompt, description?, model (default 'sonnet'), timeout_seconds (default 300), agent_role?, tags[] |
| `createCommentSchema` | `POST /api/tasks/[id]/comments` | content (required), task_id?, parent_id? |
| `createMessageSchema` | `POST /api/agents/message` | to (required), message (required) |
| `updateSettingsSchema` | `PUT /api/settings` | settings: Record<string, unknown> |
| `gatewayConfigUpdateSchema` | `PUT /api/gateway-config` | updates: Record<string, unknown> |
| `qualityReviewSchema` | `POST /api/quality-review` | taskId, reviewer (default 'aegis'), status: approved/rejected, notes (required) |
| `spawnAgentSchema` | `POST /api/spawn` | task, model, label (all required), timeoutSeconds (10-3600, default 300) |
| `createUserSchema` | `POST /api/auth/users` | username, password (min 12), display_name?, role enum (admin/operator/viewer), provider (local/google), email? |
| `accessRequestActionSchema` | `POST /api/auth/access-requests` | request_id, action: approve/reject, role enum, note? |
| `connectSchema` | `POST /api/connect` | tool_name (1-100), tool_version?, agent_name (1-100), agent_role?, metadata? |
| `githubSyncSchema` | `POST /api/github` | action: sync/comment/close/status, repo (owner/repo format)?, labels?, state?, assignAgent?, issueNumber?, body?, comment? |

---

## Rate Limiting Tiers

**Source:** `src/lib/rate-limit.ts`

| Limiter | Window | Max Requests | Bypassed by `MC_DISABLE_RATE_LIMIT=1` | Usage |
|---------|--------|-------------|---------------------------------------|-------|
| `loginLimiter` | 60s | 5 | **No** (critical) | `POST /api/auth/login` |
| `mutationLimiter` | 60s | 60 | Yes | Most POST/PUT/DELETE endpoints |
| `readLimiter` | 60s | 120 | Yes | `GET /api/logs`, `GET /api/memory`, `GET /api/tasks/regression` |
| `heavyLimiter` | 60s | 10 | Yes | `POST /api/spawn`, `GET /api/search`, `GET /api/export`, `POST /api/backup`, `POST /api/cleanup` |

Client IP extraction uses `x-forwarded-for` (rightmost untrusted IP when `MC_TRUSTED_PROXIES` is set) or `x-real-ip` fallback.

---

## Complete Endpoint Catalog

### Auth Domain

**Directory:** `auth/`

| Method | Path | Role | Rate Limit | Validation | Description |
|--------|------|------|-----------|------------|-------------|
| POST | `/api/auth/login` | none | loginLimiter | raw body | Authenticate with username/password. Sets `mc-session` cookie. Audits failures. |
| POST | `/api/auth/logout` | none | none | none | Destroy session, clear cookie. Audits logout. |
| GET | `/api/auth/me` | viewer | none | none | Return current user profile (id, username, display_name, role, provider, email, avatar_url, workspace_id). |
| PATCH | `/api/auth/me` | authenticated | none | raw body | Self-service password change (requires current_password + new_password min 8) and/or display_name update. |
| POST | `/api/auth/google` | none | none | raw body | Google OAuth login. Verifies ID token, creates/updates user, handles pending approvals via `access_requests` table. |
| GET | `/api/auth/users` | admin | none | none | List all users in current workspace. |
| POST | `/api/auth/users` | admin | mutationLimiter | createUserSchema | Create new user. Password min 12 chars. |
| PUT | `/api/auth/users` | admin | none | raw body | Update user (display_name, role, password, is_approved, email, avatar_url). Cannot change own role. |
| DELETE | `/api/auth/users` | admin | none | raw body `{id}` | Delete user. Cannot delete self. |
| GET | `/api/auth/access-requests` | admin | none | query: `status` | List Google OAuth access requests. |
| POST | `/api/auth/access-requests` | admin | mutationLimiter | accessRequestActionSchema | Approve or reject an access request. Creates user on approval. |

### Agent Domain

**Directory:** `agents/`

| Method | Path | Role | Rate Limit | Validation | Description |
|--------|------|------|-----------|------------|-------------|
| GET | `/api/agents` | viewer | none | query: status, role, limit, offset | List agents with parsed config, task stats, pagination. |
| POST | `/api/agents` | operator | mutationLimiter | createAgentSchema | Create agent. Supports templates, gateway write-back, OpenClaw workspace provisioning. |
| PUT | `/api/agents` | operator | mutationLimiter | raw body | Update single agent by name (status, last_activity, config, session_key, soul_content, role). |
| GET | `/api/agents/[id]` | viewer | none | none | Get single agent by ID or name. Config enriched from workspace. |
| PUT | `/api/agents/[id]` | operator | none | raw body | Update agent config. Unified MC + gateway save with rollback on DB failure after gateway write. |
| DELETE | `/api/agents/[id]` | admin | none | none | Delete agent by ID or name. |
| GET | `/api/agents/[id]/heartbeat` | viewer | none | none | Heartbeat check: returns mentions, assigned tasks, unread notifications, urgent activities. Updates agent to idle. |
| POST | `/api/agents/[id]/heartbeat` | operator | none | raw body (optional) | Enhanced heartbeat: accepts connection_id, token_usage reporting, returns work items. |
| POST | `/api/agents/[id]/wake` | operator | none | raw body (optional) | Wake agent via OpenClaw `sessions_send`. Optional custom message. |
| GET | `/api/agents/[id]/soul` | viewer | none | none | Get SOUL.md content (workspace file > DB fallback). Lists available templates. |
| PUT | `/api/agents/[id]/soul` | operator | none | raw body | Update SOUL content. Supports template loading with placeholder replacement. Syncs to workspace file. |
| PATCH | `/api/agents/[id]/soul` | none | none | query: `template` | List/get SOUL templates from templates directory. |
| GET | `/api/agents/[id]/attribution` | viewer (self or admin+privileged) | none | query: hours, section | Identity + audit trail + mutations + cost attribution report for an agent. Self-scoped by default. |
| GET | `/api/agents/[id]/diagnostics` | viewer (self or admin+privileged) | none | query: hours, section | Self-diagnostics: summary KPIs, task metrics, error analysis, activity breakdown, trends, token usage. |
| GET | `/api/agents/[id]/memory` | viewer | none | none | Get agent's working memory (scratchpad stored in DB). Auto-creates column if missing. |
| PUT | `/api/agents/[id]/memory` | operator | none | raw body | Update working memory. Supports append mode with timestamp headers. |
| DELETE | `/api/agents/[id]/memory` | operator | none | none | Clear working memory to empty string. |
| GET | `/api/agents/[id]/keys` | admin | none | none | List API keys for an agent (key_hash never exposed, only key_prefix). |
| POST | `/api/agents/[id]/keys` | admin | none | raw body | Create API key. Returns raw key (only shown once). Scopes: viewer, operator, admin, agent:self, agent:diagnostics, etc. Supports expires_at or expires_in_days. |
| DELETE | `/api/agents/[id]/keys` | admin | none | raw body `{key_id}` | Revoke (soft-delete) an API key by setting revoked_at. |
| GET | `/api/agents/comms` | viewer | none | query: limit, offset, since, agent | Inter-agent communication timeline, graph edges, per-agent sent/received stats. Filters out human/system messages. |
| GET | `/api/agents/sync` | admin | none | none | Preview sync diff between openclaw.json and MC agent registry. |
| POST | `/api/agents/sync` | admin | none | none | Execute agent config sync from openclaw.json. |
| POST | `/api/agents/message` | operator | mutationLimiter | createMessageSchema | Send direct message to agent via OpenClaw `sessions_send`. Creates notification. |

### Task Domain

**Directory:** `tasks/`

| Method | Path | Role | Rate Limit | Validation | Description |
|--------|------|------|-----------|------------|-------------|
| GET | `/api/tasks` | viewer | none | query: status, assigned_to, priority, project_id, limit, offset | List tasks with project join, JSON field parsing, pagination. |
| POST | `/api/tasks` | operator | mutationLimiter | createTaskSchema | Create task. Validates @mentions, resolves project, allocates ticket number atomically. Duplicate title check. |
| PUT | `/api/tasks` | operator | mutationLimiter | bulkUpdateTaskStatusSchema | Bulk status update (drag-and-drop). Enforces Aegis approval for `done` status. |
| GET | `/api/tasks/[id]` | viewer | none | none | Get single task with project join. |
| PUT | `/api/tasks/[id]` | operator | mutationLimiter | updateTaskSchema | Update task fields. Validates @mentions, enforces Aegis gate for `done`, handles project reassignment with new ticket numbers. |
| DELETE | `/api/tasks/[id]` | operator | mutationLimiter | none | Delete task (cascades comments). |
| GET | `/api/tasks/[id]/comments` | viewer | none | none | Get threaded comments for a task. Builds parent/reply tree structure. |
| POST | `/api/tasks/[id]/comments` | operator | mutationLimiter | createCommentSchema | Add comment. Validates @mentions, notifies subscribers, ensures subscriptions. |
| POST | `/api/tasks/[id]/broadcast` | operator | none | raw body `{message}` | Broadcast message to all task subscribers via OpenClaw `sessions_send`. |
| GET | `/api/tasks/queue` | operator | none | query: agent (required), max_capacity | Poll next task for an agent. Returns in-progress task, claims from inbox/assigned queue with atomic pickup and retry loop. Priority: critical > high > medium > low, then due_date, then created_at. |
| GET | `/api/tasks/outcomes` | viewer | none | query: timeframe (day/week/month/all) | Outcome analytics: success/failed/partial/abandoned rates by agent, by priority, common errors, avg retry count, avg resolution time. |
| GET | `/api/tasks/regression` | viewer | readLimiter | query: beta_start (required), lookback_seconds | A/B regression analysis: compares p95 latency and intervention rate between baseline and post-beta windows. |

### Monitoring Domain

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/status` | viewer | none | System status hub. Query param `action`: `overview` (system health, processes, sessions), `dashboard` (aggregated stats), `gateway` (OpenClaw gateway status), `models` (available LLM models), `health` (disk/memory/gateway checks), `capabilities` (feature detection). |
| GET | `/api/activities` | viewer | none | Activity stream with entity enrichment. Supports `?stats` for hourly timeline, actor leaderboard, activity-by-type breakdown. Query: type, actor, entity_type, limit, offset, since. |
| GET | `/api/notifications` | viewer | none | Get notifications for a recipient. Query: recipient (required), unread_only, type, limit, offset. Enriches with source entity details. |
| PUT | `/api/notifications` | operator | mutationLimiter | Mark notifications read. Body: `{ids: number[]}` or `{recipient, markAllRead: true}`. |
| DELETE | `/api/notifications` | admin | mutationLimiter | Delete notifications. Body: `{ids: number[]}` or `{recipient, olderThan}`. |
| POST | `/api/notifications` | operator | mutationLimiter | Mark notifications as delivered to agent. Uses notificationActionSchema. |
| GET | `/api/notifications/deliver` | viewer | none | Delivery statistics: total/delivered/undelivered counts, agents with pending notifications. |
| POST | `/api/notifications/deliver` | operator | none | Notification delivery daemon: polls undelivered, sends via OpenClaw `sessions_send`. Supports agent_filter, limit, dry_run. |
| GET | `/api/sessions` | viewer | none | List active sessions. Reads from OpenClaw gateway session stores, falls back to local Claude + Codex sessions from disk. Deduplicates by session ID. |
| GET | `/api/sessions/[id]/control` | viewer | none | _(Route exists but not detailed in read -- session control endpoint)_ |
| GET | `/api/tokens` | viewer | none | Token usage data. Action param: `list` (paginated records), `stats` (model/session/agent breakdowns), `agent-costs` (per-agent with daily timeline), `task-costs` (per-task attribution), `export` (JSON or CSV download), `trends` (hourly 24h chart). |
| POST | `/api/tokens` | operator | none | Record token usage manually. Body: model, sessionId, inputTokens, outputTokens, operation, duration, taskId. |
| GET | `/api/standup` | viewer | none | Standup report history. Query: limit, offset. |
| POST | `/api/standup` | operator | none | Generate daily standup report. Body: date?, agents?. Aggregates completed/in-progress/assigned/review/blocked tasks per agent, team accomplishments, overdue tasks. Persists to `standup_reports`. |
| GET | `/api/events` | viewer | none | **SSE stream** (Server-Sent Events). Streams real-time DB mutations via eventBus. 30s heartbeat. Content-Type: `text/event-stream`. |
| GET | `/api/mentions` | viewer | none | _(Route exists for mention autocomplete)_ |

### Webhook Domain

**Directory:** `webhooks/`

| Method | Path | Role | Rate Limit | Validation | Description |
|--------|------|------|-----------|------------|-------------|
| GET | `/api/webhooks` | admin | none | none | List webhooks with delivery stats (total, successful, failed). Masks secrets. Shows circuit breaker status. |
| POST | `/api/webhooks` | admin | mutationLimiter | createWebhookSchema | Create webhook. Auto-generates HMAC secret. |
| PUT | `/api/webhooks` | admin | mutationLimiter | raw body | Update webhook (name, url, events, enabled, regenerate_secret, reset_circuit). |
| DELETE | `/api/webhooks` | admin | mutationLimiter | raw body `{id}` | Delete webhook and its deliveries. |
| POST | `/api/webhooks/test` | admin | none | raw body `{id}` | Send test ping event to a webhook. |
| POST | `/api/webhooks/retry` | admin | none | raw body `{delivery_id}` | Manually retry a failed delivery. Increments attempt counter. |
| GET | `/api/webhooks/deliveries` | admin | none | query: webhook_id, limit, offset | List delivery history with webhook metadata. |
| GET | `/api/webhooks/verify-docs` | viewer | none | none | Returns HMAC-SHA256 signature verification documentation and Node.js example code. |

### Alert Domain

| Method | Path | Role | Rate Limit | Validation | Description |
|--------|------|------|-----------|------------|-------------|
| GET | `/api/alerts` | viewer | none | none | List all alert rules. |
| POST | `/api/alerts` | operator | mutationLimiter | createAlertSchema (or `{action:'evaluate'}`) | Create alert rule, or evaluate all enabled rules against current data. Supports entity types: agent, task, session, activity. Operators: equals, not_equals, greater_than, less_than, contains, count_above, count_below, age_minutes_above. |
| PUT | `/api/alerts` | operator | mutationLimiter | raw body | Update alert rule fields. |
| DELETE | `/api/alerts` | admin | mutationLimiter | raw body `{id}` | Delete alert rule. |

### Settings & Config

| Method | Path | Role | Rate Limit | Validation | Description |
|--------|------|------|-----------|------------|-------------|
| GET | `/api/settings` | admin | none | none | List all settings grouped by category (retention, gateway, general). Merges stored values with defaults. |
| PUT | `/api/settings` | admin | mutationLimiter | updateSettingsSchema | Upsert one or more settings. Audit logged with old/new values. |
| DELETE | `/api/settings` | admin | mutationLimiter | raw body `{key}` | Reset a setting to default by deleting it. |
| GET | `/api/gateway-config` | viewer | none | none | _(Gateway configuration reader)_ |
| PUT | `/api/gateway-config` | operator | none | gatewayConfigUpdateSchema | _(Gateway configuration updater)_ |

### Scheduler & Cron

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/scheduler` | admin | none | Get built-in scheduler status (auto_backup, auto_cleanup, agent_heartbeat). |
| POST | `/api/scheduler` | admin | none | Manually trigger a scheduled task. Body: `{task_id}`. |
| GET | `/api/cron?action=list` | admin | none | List OpenClaw cron jobs from `~/.openclaw/cron/jobs.json`. |
| GET | `/api/cron?action=logs&job=ID` | admin | none | Get execution logs for a specific cron job. |
| POST | `/api/cron` (action=toggle) | admin | none | Enable/disable a cron job. |
| POST | `/api/cron` (action=trigger) | admin | none | Manually trigger a cron job via OpenClaw CLI. Requires `MISSION_CONTROL_ALLOW_COMMAND_TRIGGER=1`. |
| POST | `/api/cron` (action=add) | admin | none | Add a new cron job. Body: name, schedule (cron expr), command, model?. |
| POST | `/api/cron` (action=remove) | admin | none | Remove a cron job. |

### Audit & Logs

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/audit` | admin | none | Query audit log. Filters: action, actor, since, until, limit (max 10000), offset. |
| GET | `/api/logs?action=recent` | viewer | readLimiter | Read recent log entries from OpenClaw log files. Filters: level, session, search, source, limit. Supports pipe-delimited, JSON, and journal log formats. |
| GET | `/api/logs?action=sources` | viewer | readLimiter | List available log file sources. |
| GET | `/api/logs?action=tail` | viewer | readLimiter | Tail log entries since a given timestamp. |
| POST | `/api/logs` (action=add) | operator | mutationLimiter | Add a custom log entry. |

### Memory & Search

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/memory?action=tree` | viewer | readLimiter | Build file tree of the memory directory. Respects `MEMORY_ALLOWED_PREFIXES`. Excludes symlinks. |
| GET | `/api/memory?action=content&path=...` | viewer | readLimiter | Read file content from memory directory. Path-traversal protected via `resolveWithin()` + symlink checks. |
| GET | `/api/memory?action=search&query=...` | viewer | readLimiter | Full-text search across .md and .txt files in memory directory. Skips files >1MB. |
| POST | `/api/memory` (action=save) | operator | mutationLimiter | Save/overwrite file content. |
| POST | `/api/memory` (action=create) | operator | mutationLimiter | Create new file with mkdir -p for parent dirs. 409 if file exists. |
| DELETE | `/api/memory` (action=delete) | admin | mutationLimiter | Delete a file from memory directory. |
| GET | `/api/search?q=...` | viewer | heavyLimiter | Global cross-entity search. Searches: tasks, agents, activities, audit_log, messages, webhooks, pipelines. Results ranked by relevance (title match > content match) then recency. Min query length: 2 chars. |

### Export, Backup, Cleanup

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/export?type=...&format=...` | admin | heavyLimiter | Export data as CSV or JSON. Types: audit, tasks, activities, pipelines. Supports since/until filters. Max 50,000 rows. Audit logged. |
| GET | `/api/backup` | admin | none | List backup files from `.data/backups/` directory. |
| POST | `/api/backup` | admin | heavyLimiter | Create SQLite backup via `db.backup()`. Auto-prunes to 10 most recent. Audit logged. |
| DELETE | `/api/backup` | admin | none | Delete a specific backup file. Body: `{name}`. Validates no path traversal. |
| GET | `/api/cleanup` | admin | none | Preview what would be cleaned. Shows retention policy, stale counts per table, token file stats, gateway session stats. |
| POST | `/api/cleanup` | admin | heavyLimiter | Execute retention cleanup. Body: `{dry_run?: boolean}`. Deletes from activities, audit_log, notifications, pipeline_runs based on retention days. Also cleans token usage file and gateway session stores. Audit logged. |

### Direct CLI Connections

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/connect` | viewer | none | List all direct connections with agent details. |
| POST | `/api/connect` | operator | none | Register CLI connection. Auto-creates agent if name doesn't exist. Deactivates previous connections for same agent. Returns connection_id + helper URLs (SSE, heartbeat, token report). |
| DELETE | `/api/connect` | operator | none | Disconnect by connection_id. Sets agent offline if no other active connections. |

### Chat (Conversations & Messages)

**Directory:** `chat/`

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/chat/conversations` | viewer | none | List chat conversations. |
| GET | `/api/chat/messages` | viewer | none | List messages in a conversation. |
| POST | `/api/chat/messages` | operator | none | Send a chat message. |
| GET | `/api/chat/messages/[id]` | viewer | none | Get a specific message. |
| PUT | `/api/chat/messages/[id]` | operator | none | Update/edit a message. |
| DELETE | `/api/chat/messages/[id]` | operator | none | Delete a message. |

### Claude Code Sessions

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/claude/sessions` | viewer | none | List Claude Code sessions synced from local `~/.claude` directory. |

### Workflows & Pipelines

| Method | Path | Role | Rate Limit | Validation | Description |
|--------|------|------|-----------|------------|-------------|
| GET | `/api/workflows` | viewer | none | none | List workflow templates sorted by use_count DESC. |
| POST | `/api/workflows` | operator | mutationLimiter | createWorkflowSchema | Create workflow template. |
| PUT | `/api/workflows` | operator | none | raw body | Update template. Empty field updates = usage tracking increment. |
| DELETE | `/api/workflows` | operator | none | raw body `{id}` | Delete workflow template. |
| GET | `/api/pipelines` | viewer | none | none | List pipelines with enriched step names, run counts (total/completed/failed/running). |
| POST | `/api/pipelines` | operator | mutationLimiter | createPipelineSchema | Create pipeline. Validates all template_ids exist. Min 2 steps. |
| PUT | `/api/pipelines` | operator | none | raw body | Update pipeline fields. |
| DELETE | `/api/pipelines` | operator | none | raw body `{id}` | Delete pipeline. |
| GET | `/api/pipelines/run` | viewer | none | query: pipeline_id, id, limit | List pipeline runs or get specific run. Enriched with pipeline names. |
| POST | `/api/pipelines/run` (action=start) | operator | none | raw body | Start pipeline execution. Spawns first step via OpenClaw CLI. |
| POST | `/api/pipelines/run` (action=advance) | operator | none | raw body | Advance running pipeline: mark current step completed/failed, spawn next step. Handles on_failure: stop/continue. |
| POST | `/api/pipelines/run` (action=cancel) | operator | none | raw body | Cancel a running pipeline. Marks remaining steps as skipped. |

### Projects

**Directory:** `projects/`

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/projects` | viewer | none | List active projects (or all with `?includeArchived=1`). |
| POST | `/api/projects` | operator | mutationLimiter | Create project. Auto-generates slug and normalizes ticket prefix. |
| GET | `/api/projects/[id]` | viewer | none | Get single project. |
| PATCH | `/api/projects/[id]` | operator | mutationLimiter | Update project (name, description, ticket_prefix, status). Default project cannot be archived. |
| DELETE | `/api/projects/[id]` | admin | mutationLimiter | Archive (default) or hard-delete project. Hard delete moves tasks to "General" project. Default project cannot be deleted. |
| GET | `/api/projects/[id]/tasks` | viewer | none | List all tasks for a project with ticket_ref formatting. |

### Quality Review

| Method | Path | Role | Rate Limit | Validation | Description |
|--------|------|------|-----------|------------|-------------|
| GET | `/api/quality-review` | viewer | none | query: taskId or taskIds (comma-separated) | Get quality reviews for task(s). Batch mode returns latest review per task. |
| POST | `/api/quality-review` | operator | mutationLimiter | qualityReviewSchema | Submit quality review (approved/rejected). Aegis approval auto-advances task to `done` status. |

### Spawn

| Method | Path | Role | Rate Limit | Validation | Description |
|--------|------|------|-----------|------------|-------------|
| GET | `/api/spawn` | viewer | none | query: limit | Get spawn history from OpenClaw log files. |
| POST | `/api/spawn` | operator | heavyLimiter | spawnAgentSchema | Spawn ephemeral agent via ClawdBot `sessions_spawn`. Includes tools.profile compatibility fallback for older OpenClaw versions. |

### Workload

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/workload` | viewer | none | _(Workload distribution view)_ |

### Integrations & GitHub

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/integrations` | viewer | none | _(Integration status)_ |
| POST | `/api/integrations` | operator | none | Integration actions: test, pull, pull-all. |
| GET | `/api/github` | viewer | none | _(GitHub sync status)_ |
| POST | `/api/github` | operator | none | GitHub sync actions: sync, comment, close, status. Validates repo as owner/repo format. |

### Gateways

**Directory:** `gateways/`

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/gateways` | viewer | none | List configured gateways. |
| POST | `/api/gateways` | admin | none | Create/manage gateway. |
| GET | `/api/gateways/health` | viewer | none | Gateway health check. |
| POST | `/api/gateways/connect` | operator | none | Connect to a gateway. |

### Docs Browser

**Directory:** `docs/`

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/docs` | viewer | none | List documentation files. |
| GET | `/api/docs/tree` | viewer | none | Documentation file tree. |
| GET | `/api/docs/content` | viewer | none | Read documentation file content. |
| GET | `/api/docs/search` | viewer | none | Search documentation. |

### Local Development

**Directory:** `local/`

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET/POST | `/api/local/flight-deck` | varies | none | Local development flight deck. |
| GET/POST | `/api/local/terminal` | varies | none | Local terminal access. |

### Releases

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/releases/check` | viewer | none | Check for Mission Control updates. |

### Super Admin (Multi-Tenant)

**Directory:** `super/`

| Method | Path | Role | Rate Limit | Description |
|--------|------|------|-----------|-------------|
| GET | `/api/super/tenants` | admin | none | List tenants with latest provisioning status. |
| POST | `/api/super/tenants` | admin | none | Create tenant and queue bootstrap provisioning job. |
| POST | `/api/super/tenants/[id]/decommission` | admin | none | Decommission a tenant. |
| GET | `/api/super/provision-jobs` | admin | none | List provisioning jobs. Query: tenant_id, status, limit. |
| POST | `/api/super/provision-jobs` | admin | none | Queue additional provisioning job for existing tenant. Body: tenant_id, job_type (bootstrap/update/decommission), dry_run, plan_json. |
| GET | `/api/super/provision-jobs/[id]` | admin | none | Get specific provision job details. |
| POST | `/api/super/provision-jobs/[id]/run` | admin | none | Execute/approve a provision job. |

---

## Error Handling Patterns

All endpoints follow consistent error response shapes:

```typescript
// Validation error (400)
{ error: 'Validation failed', details: ['field: message'] }

// Auth error (401)
{ error: 'Not authenticated' }

// Forbidden (403)
{ error: 'Admin access required' }
// or role-specific: 'Aegis approval is required to move task to done.'

// Not found (404)
{ error: 'Agent not found' }

// Conflict (409)
{ error: 'Agent name already exists' }
// or: 'Task with this title already exists'

// Rate limit (429)
{ error: 'Too many requests. Please try again later.' }
// or login-specific: 'Too many login attempts. Try again in a minute.'

// Server error (500)
{ error: 'Failed to fetch agents' }  // Generic per-endpoint
```

All errors are logged via `logger.error()` (pino) with structured context including the error object and endpoint path.

---

## Hive Implementation Notes

1. **The role system is simple but effective** -- three levels (viewer/operator/admin) with a single `requireRole()` guard. No fine-grained permissions, no resource-level ACLs. For a Hive implementation, consider whether `operator` is too broad a bucket.

2. **Rate limiting is IP-based, in-memory** -- no Redis, no distributed state. The `Map<string, RateLimitEntry>` is cleaned up every 60 seconds. This works for single-process deployments but would need adaptation for horizontal scaling.

3. **The SSE endpoint (`/api/events`)** is the real-time backbone. All mutations broadcast through `eventBus`, and the SSE stream forwards everything. Webhook delivery also listens on the same bus.

4. **Workspace isolation is query-level** -- every query includes `WHERE workspace_id = ?`. There is no middleware-level isolation; each endpoint is responsible for scoping. A Hive implementation should consider middleware enforcement.

5. **The task queue endpoint (`/api/tasks/queue`)** implements a simple priority-based claim mechanism with an atomic UPDATE + retry loop for race safety. This is not a distributed queue -- it relies on SQLite's write serialization.

6. **The Aegis gate** is enforced at both `PUT /api/tasks/[id]` and `PUT /api/tasks` (bulk). Moving a task to `done` requires a quality_review record with `status = 'approved'` and `reviewer = 'aegis'`. The `POST /api/quality-review` endpoint auto-advances the task when Aegis approves.

7. **Pipeline execution** is semi-automated: the API spawns each step via OpenClaw CLI and waits for explicit `advance` calls. There is no background polling -- the caller (or a cron job) must drive the pipeline forward.
