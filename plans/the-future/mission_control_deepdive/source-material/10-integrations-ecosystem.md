# 10 — Integrations Ecosystem: Webhooks, Gateways, GitHub, Claude Code, and Multi-Tenant Workspaces

This document covers Mission Control's outbound integration surface: the webhook delivery system with circuit breakers, multi-gateway management, GitHub issue sync, Claude Code session discovery, the integration registry with 1Password secret management, multi-tenant provisioning, and the alert rule engine.

---

## Webhook System

The webhook subsystem lives in `src/lib/webhooks.ts` with API routes in `src/app/api/webhooks/`. It implements event-driven delivery with HMAC signatures, exponential backoff retry, and circuit breaker protection.

### Architecture

```
Event Bus (server-event)
    ↓
initWebhookListener() — subscribes once at server startup
    ↓
fireWebhooksAsync(eventType, payload, workspaceId)
    ↓
SELECT enabled webhooks WHERE events JSON includes eventType
    ↓
deliverWebhook() for each matching webhook
    ↓
HTTP POST with HMAC signature → log delivery → handle retry/circuit breaker
```

### Event Type Mapping

The webhook system maps internal event bus events to webhook event types via `EVENT_MAP`:

```typescript
const EVENT_MAP: Record<string, string> = {
  'activity.created':        'activity',              // → activity.<type>
  'notification.created':    'notification',           // → notification.<type>
  'agent.status_changed':    'agent.status_change',
  'audit.security':          'security',               // → security.<action>
  'task.created':            'activity.task_created',
  'task.updated':            'activity.task_updated',
  'task.deleted':            'activity.task_deleted',
  'task.status_changed':     'activity.task_status_changed',
}
```

Dynamic sub-typing is applied: an `activity.created` event with `data.type = 'task_created'` becomes webhook event type `activity.task_created`. Agent error status changes fire an additional `agent.error` event.

### HMAC-SHA256 Signature Generation

Every delivery includes an `X-MC-Signature` header when the webhook has a secret configured:

```typescript
if (webhook.secret) {
  const sig = createHmac('sha256', webhook.secret).update(body).digest('hex')
  headers['X-MC-Signature'] = `sha256=${sig}`
}
```

Headers sent with every delivery:

| Header | Value |
|--------|-------|
| `Content-Type` | `application/json` |
| `User-Agent` | `MissionControl-Webhook/1.0` |
| `X-MC-Event` | The webhook event type |
| `X-MC-Signature` | `sha256={hmac}` (only if secret is set) |

### Signature Verification

`src/lib/webhooks.ts` exports a `verifyWebhookSignature()` helper for consumers:

```typescript
export function verifyWebhookSignature(
  secret: string,
  rawBody: string,
  signatureHeader: string | null | undefined
): boolean
```

Uses `crypto.timingSafeEqual()` for constant-time comparison. When the signature and expected buffers differ in length, it compares against a dummy buffer to avoid timing leaks.

### Exponential Backoff Retry

Retry schedule with jitter:

| Attempt | Base Delay | With Jitter (plus/minus 20%) |
|---------|-----------|------------------------------|
| 0 | 30s | 24s - 36s |
| 1 | 5m | 4m - 6m |
| 2 | 30m | 24m - 36m |
| 3 | 2h | 1h36m - 2h24m |
| 4 | 8h | 6h24m - 9h36m |

```typescript
const BACKOFF_SECONDS = [30, 300, 1800, 7200, 28800]

export function nextRetryDelay(attempt: number): number {
  const base = BACKOFF_SECONDS[Math.min(attempt, BACKOFF_SECONDS.length - 1)]
  const jitter = base * 0.2 * (2 * Math.random() - 1) // ±20%
  return Math.round(base + jitter)
}
```

Maximum retries default to 5, configurable via `MC_WEBHOOK_MAX_RETRIES` env var.

### Retry Processing

`processWebhookRetries()` is called by the scheduler every 60 seconds:

1. SELECT deliveries where `next_retry_at <= now` (batch limit 50)
2. Clear `next_retry_at` immediately (prevents double-processing)
3. Re-deliver each with `attempt + 1`
4. Failed re-deliveries schedule another retry (if attempts remain)

### Circuit Breaker

When a webhook exhausts all retries:

1. `consecutive_failures` counter is incremented on each failure
2. When `consecutive_failures >= MAX_RETRIES`, the webhook is **disabled** (`enabled = 0`)
3. A warning is logged: "Webhook circuit breaker tripped -- disabled after exhausting retries"

Reset is manual: `PUT /api/webhooks { id, reset_circuit: true }` clears the failure count and re-enables the webhook.

On success, `consecutive_failures` resets to 0.

### Delivery Payload

```json
{
  "event": "activity.task_created",
  "timestamp": 1710000000,
  "data": { ... }
}
```

### Webhook CRUD API

`src/app/api/webhooks/route.ts` (requires `admin` role):

- **GET**: Lists all webhooks with delivery stats (total, successful, failed counts). Secrets are masked to last 4 chars (`••••••abcd`). Includes `circuit_open` boolean.
- **POST**: Creates webhook with auto-generated 32-byte hex secret. Full secret shown only on creation response.
- **PUT**: Updates webhook fields. Supports `regenerate_secret` and `reset_circuit` flags.
- **DELETE**: Deletes webhook and all associated deliveries.

### Delivery History

`GET /api/webhooks/deliveries` returns paginated delivery logs with webhook name and URL, supporting `?webhook_id=N` filtering.

### Test Endpoint

`POST /api/webhooks/test` (`src/app/api/webhooks/test/route.ts`) sends a `test.ping` event with `allowRetry: false` -- no retry scheduling on failure, purely for connectivity testing.

---

## Gateway Management

Multi-gateway support lives in `src/app/api/gateways/route.ts`. The system can connect to multiple OpenClaw agent gateways simultaneously.

### Gateway Data Model

The `gateways` table is created lazily (via `ensureTable()` in the route handler, not in migrations):

```sql
CREATE TABLE IF NOT EXISTS gateways (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    host TEXT NOT NULL DEFAULT '127.0.0.1',
    port INTEGER NOT NULL DEFAULT 18789,
    token TEXT NOT NULL DEFAULT '',
    is_primary INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'unknown',
    last_seen INTEGER,
    latency INTEGER,
    sessions_count INTEGER NOT NULL DEFAULT 0,
    agents_count INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at INTEGER NOT NULL DEFAULT (unixepoch())
)
```

### Auto-Seeding

If no gateways exist on first GET, the system seeds a default from environment variables:

```typescript
const host = process.env.OPENCLAW_GATEWAY_HOST || '127.0.0.1'
const port = parseInt(process.env.OPENCLAW_GATEWAY_PORT || process.env.GATEWAY_PORT || '18789')
const token = process.env.OPENCLAW_GATEWAY_TOKEN || process.env.GATEWAY_TOKEN || ''
```

### Primary Gateway

Only one gateway can be primary (`is_primary = 1`). Setting a new primary unsets all others. The primary gateway cannot be deleted.

### Token Redaction

Tokens are always redacted in API responses (`'--------'`), with a `token_set` boolean indicating whether a token is configured.

### Gateway URL Construction

`src/lib/gateway-url.ts` provides `buildGatewayWebSocketUrl()`:

```typescript
export function buildGatewayWebSocketUrl(input: {
  host: string
  port: number
  browserProtocol?: string
}): string
```

Logic:
- Strips paths, search params, and hashes from pasted URLs
- Converts `http://` to `ws://` and `https://` to `wss://`
- For non-localhost hosts on `wss:`, omits port 18789 (assumes reverse proxy)
- For localhost, always includes the port

### WebSocket Connection

`src/lib/websocket.ts` implements the full gateway WebSocket lifecycle as a React hook (`useWebSocket()`):

**Protocol**: OpenClaw Gateway Protocol v3

**Handshake Flow**:
```
1. Client opens WebSocket to gateway URL
2. Gateway sends connect.challenge event with nonce
3. Client builds Ed25519-signed connect request:
   - Signs payload: v2|deviceId|clientId|clientMode|role|scopes|signedAt|token|nonce
   - Sends req { method: 'connect', params: { ... } }
4. Gateway responds with res { ok: true, result: { deviceToken: '...' } }
5. Client caches deviceToken for future reconnections
6. Heartbeat starts (30-second ping interval)
```

**Heartbeat**:
- Sends `req { method: 'ping' }` every 30 seconds
- Tracks missed pongs (`MAX_MISSED_PONGS = 3`)
- If 3 pongs missed, forces reconnect
- Falls back to passive mode if gateway doesn't support ping RPC

**Reconnection**:
- Exponential backoff: `min(2^attempts * 1000, 30000)` with 50% jitter
- Max 10 reconnect attempts
- Non-retryable errors (origin not allowed, signature invalid, rate limited) abort reconnection immediately

**Event Handling**: Processes `tick`, `log`, `chat.message`, `notification`, `agent.status` events from the gateway.

### Framework Adapters (Referenced)

The gateway system references support for multiple agent frameworks. The `INTEGRATIONS` registry in `src/app/api/integrations/route.ts` lists:
- OpenClaw (primary, deepest integration)
- Anthropic, OpenAI, OpenRouter (AI providers with connection testing)
- Generic gateway auth via `OPENCLAW_GATEWAY_TOKEN`

The actual framework adapter switching (CrewAI, LangGraph, AutoGen, Claude SDK) is handled at the gateway level, not in Mission Control itself.

---

## GitHub Sync

`src/app/api/github/route.ts` implements bidirectional GitHub integration.

### Inbound Sync (GitHub Issues to MC Tasks)

`POST /api/github { action: "sync", repo: "owner/repo" }`:

1. Fetches issues from GitHub API (`fetchIssues()` from `src/lib/github.ts`)
2. For each issue:
   - Checks for duplicate via `json_extract(metadata, '$.github_repo')` and `$.github_issue_number`
   - Maps priority from GitHub labels: `priority:critical` -> critical, `priority:high` -> high, etc.
   - Creates task with metadata linking back to GitHub:
     ```json
     {
       "github_repo": "owner/repo",
       "github_issue_number": 42,
       "github_issue_url": "https://github.com/...",
       "github_synced_at": "2026-03-20T...",
       "github_state": "open"
     }
     ```
   - Closed GitHub issues become tasks with `status: 'done'`
   - Broadcasts `task.created` event for each imported task
3. Records sync in `github_syncs` table
4. Broadcasts `github.synced` event with import/skip/error counts

### Outbound Actions

- **Comment**: `POST /api/github { action: "comment", repo, issueNumber, body }` -- posts a comment on a GitHub issue
- **Close**: `POST /api/github { action: "close", repo, issueNumber, comment? }` -- closes an issue, optionally with a closing comment, and updates local task metadata to `github_state: 'closed'`

### GitHub Stats

`GET /api/github?action=stats` returns user profile and repository overview:
- User: login, name, avatar, followers
- Repos: total count (excluding untouched forks), public/private split, total stars/forks/issues
- Top 6 languages by repo count
- Last 10 recently-pushed repos

### Sync History

`POST /api/github { action: "status" }` returns the last 20 sync records from `github_syncs`.

---

## Claude Code Integration

`src/lib/claude-sessions.ts` discovers and tracks local Claude Code sessions by scanning the filesystem.

### Session Discovery

Scans `~/.claude/projects/` for JSONL session transcripts:

```
~/.claude/projects/
  ├── -Users-johns-AI-project-a/
  │   ├── session1.jsonl
  │   └── session2.jsonl
  └── -Users-johns-AI-project-b/
      └── session3.jsonl
```

### JSONL Parsing

Each session file contains one JSON object per line. The parser extracts:

| Field | Source |
|-------|--------|
| `sessionId` | From entry's `sessionId` field |
| `projectSlug` | Directory name |
| `projectPath` | From entry's `cwd` field |
| `model` | From assistant message's `message.model` |
| `gitBranch` | From entry's `gitBranch` field |
| `userMessages` | Count of `type: 'user'` entries |
| `assistantMessages` | Count of `type: 'assistant'` entries |
| `toolUses` | Count of `tool_use` blocks in assistant content |
| `inputTokens` | Sum of `usage.input_tokens` + cache tokens |
| `outputTokens` | Sum of `usage.output_tokens` |
| `estimatedCost` | Calculated from per-model pricing table |
| `firstMessageAt` | Earliest timestamp |
| `lastMessageAt` | Latest timestamp |
| `lastUserPrompt` | Last user message content (first 500 chars) |
| `isActive` | `lastMessageAt` within last 5 minutes |

Sidechain messages (subagent work, `isSidechain: true`) are excluded from message counts.

### Cost Estimation

Per-model pricing (USD per token):

| Model | Input | Output |
|-------|-------|--------|
| `claude-opus-4-6` | $15/1M | $75/1M |
| `claude-sonnet-4-6` | $3/1M | $15/1M |
| `claude-haiku-4-5` | $0.80/1M | $4/1M |

Cache-read tokens are priced at 10% of input rate. Cache-creation tokens at 125%.

### Sync Cycle

`syncClaudeSessions()` is called by the scheduler every 60 seconds (first scan 5 seconds after startup):

1. Scans all sessions from disk
2. Marks all DB sessions as inactive
3. Upserts each discovered session using `ON CONFLICT(session_id) DO UPDATE`
4. Returns count: `Scanned N session(s), M active`

The `claude_sessions` table stores all parsed fields for API access.

---

## Integration Registry and 1Password

`src/app/api/integrations/route.ts` manages API keys and secrets for external services.

### Registered Integrations

| ID | Name | Category | Env Vars | Vault Item | Testable |
|----|------|----------|----------|------------|----------|
| `anthropic` | Anthropic | ai | `ANTHROPIC_API_KEY` | `openclaw-anthropic-api-key` | Yes |
| `openai` | OpenAI | ai | `OPENAI_API_KEY` | `openclaw-openai-api-key` | Yes |
| `openrouter` | OpenRouter | ai | `OPENROUTER_API_KEY` | `openclaw-openrouter-api-key` | Yes |
| `nvidia` | NVIDIA | ai | `NVIDIA_API_KEY` | `openclaw-nvidia-api-key` | No |
| `moonshot` | Moonshot / Kimi | ai | `MOONSHOT_API_KEY` | `openclaw-moonshot-api-key` | No |
| `ollama` | Ollama (Local) | ai | `OLLAMA_API_KEY` | `openclaw-ollama-api-key` | No |
| `brave` | Brave Search | search | `BRAVE_API_KEY` | `openclaw-brave-api-key` | No |
| `x_twitter` | X / Twitter | social | `X_COOKIES_PATH` | -- | No |
| `linkedin` | LinkedIn | social | `LINKEDIN_ACCESS_TOKEN` | -- | No |
| `telegram` | Telegram | messaging | `TELEGRAM_BOT_TOKEN` | `openclaw-telegram-bot-token` | Yes |
| `github` | GitHub | devtools | `GITHUB_TOKEN` | `openclaw-github-token` | Yes |
| `onepassword` | 1Password | security | `OP_SERVICE_ACCOUNT_TOKEN` | -- | No |
| `gateway` | Gateway Auth | infra | `OPENCLAW_GATEWAY_TOKEN` | `openclaw-openclaw-gateway-token` | No |

### .env File Management

The system reads and writes the `.env` file in the OpenClaw state directory (`$OPENCLAW_STATE_DIR/.env`). It uses a line-preserving parser that maintains comments, blank lines, and ordering:

```typescript
interface EnvLine {
  type: 'comment' | 'blank' | 'var'
  raw: string
  key?: string
  value?: string
}
```

Writes use atomic rename (`writeFile` to `.env.tmp`, then `rename` to `.env`).

### Protected Variables

These variables cannot be modified via the API:

```typescript
const BLOCKED_VARS = new Set([
  'PATH', 'HOME', 'USER', 'SHELL', 'LANG', 'TERM', 'PWD', 'LOGNAME', 'HOSTNAME',
])
const BLOCKED_PREFIXES = ['LD_', 'DYLD_']
```

### Connection Testing

Testable integrations can be verified via `POST /api/integrations { action: "test", integrationId: "github" }`:

- **Telegram**: `GET https://api.telegram.org/bot{token}/getMe`
- **GitHub**: `GET https://api.github.com/user`
- **Anthropic**: `GET https://api.anthropic.com/v1/models`
- **OpenAI**: `GET https://api.openai.com/v1/models`
- **OpenRouter**: `GET https://openrouter.ai/api/v1/models`

All tests use 5-second `AbortSignal.timeout`.

### 1Password Integration

`POST /api/integrations { action: "pull", integrationId: "anthropic" }` pulls a secret from 1Password:

1. Checks `op` CLI is available (via `which op`)
2. Reads `OP_SERVICE_ACCOUNT_TOKEN` from process env or the OpenClaw `.env`
3. Executes (no shell, via `execFileSync`):
   ```
   op item get {vaultItem} --vault {vaultName} --fields password --format json
   ```
4. Parses the JSON response to extract the value
5. Upserts the value into the `.env` file

**Batch pull**: `POST /api/integrations { action: "pull-all", category?: "ai" }` pulls all vault-backed integrations in a category (or all categories), writing the `.env` file once after all pulls complete.

All integration operations are audit-logged with IP address.

---

## Multi-Tenant Workspaces

The super admin system in `src/lib/super-admin.ts` and `src/app/api/super/tenants/route.ts` manages isolated tenant environments.

### Tenant Data Model

```sql
CREATE TABLE IF NOT EXISTS tenants (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    linux_user TEXT NOT NULL UNIQUE,
    plan_tier TEXT NOT NULL DEFAULT 'standard',
    status TEXT NOT NULL DEFAULT 'pending',
    openclaw_home TEXT NOT NULL,
    workspace_root TEXT NOT NULL,
    gateway_port INTEGER,
    dashboard_port INTEGER,
    config TEXT NOT NULL DEFAULT '{}',
    created_by TEXT NOT NULL DEFAULT 'system',
    owner_gateway TEXT,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);
```

### Tenant Statuses

```typescript
type TenantStatus = 'pending' | 'provisioning' | 'decommissioning' | 'active' | 'suspended' | 'error'
```

### Bootstrap Flow

`POST /api/super/tenants` creates a tenant and queues a bootstrap job:

```
1. Validate slug (3-32 chars, lowercase alphanumeric + dashes)
2. Validate linux_user (auto-generated as oc-{slug} if not provided)
3. Validate gateway_port (required, 1024-65535)
4. Compute paths:
   - openclaw_home = /home/{linux_user}/.openclaw
   - workspace_root = /home/{linux_user}/workspace
5. INSERT tenant (status='pending')
6. Build bootstrap plan (10 provision steps)
7. INSERT provision_job (status='queued', dry_run=true by default)
8. Append provision event
9. Audit log
```

### Bootstrap Plan (10 Steps)

```
1. create-linux-user        — useradd -m -s /bin/bash {user}
2. create-openclaw-state    — install -d -m 0750 {openclaw_home}
3. create-workspace-root    — install -d -m 0750 {workspace_root}
4. seed-openclaw-template   — cp -n {template} {openclaw_home}/openclaw.json
5. set-owner-home           — chown -R {user}:{user} /home/{user}
6. ensure-openclaw-tenants  — install -d /etc/openclaw-tenants
7. install-gateway-template — cp -n {template} /etc/systemd/system/openclaw-gateway@.service
8. install-tenant-env       — cp -f {artifact}/openclaw-gateway.env /etc/openclaw-tenants/{user}.env
9. systemd-daemon-reload    — systemctl daemon-reload
10. enable-start-gateway    — systemctl enable --now openclaw-gateway@{user}.service
```

All steps require root. Execution uses either a provisioner daemon (`MC_SUPER_PROVISION_MODE=daemon`) or sudo (`sudo -n`).

### Approve/Reject/Cancel Flow

Provision jobs follow a state machine:

```
queued → approved → running → completed
                            → failed
       → rejected → approved (can re-approve)
       → cancelled
```

```typescript
type ProvisionJobStatus = 'queued' | 'approved' | 'running' | 'completed' | 'failed' | 'rejected' | 'cancelled'
```

State transitions via `transitionProvisionJobStatus()`:

- **Approve**: From `queued`, `rejected`, or `failed`. Sets `approved_by`.
- **Reject**: From `queued`, `approved`, or `failed`.
- **Cancel**: From `queued`, `approved`, `failed`, or `rejected`.

Immutable states: `running`, `completed`, `cancelled`.

### Two-Person Rule

For live (non-dry-run) executions, `executeProvisionJob()` enforces:
1. The approver must be different from the requester
2. The execution runner must be different from the approver

```typescript
if (!dryRun) {
  if (approvedBy === requestedBy) {
    throw new Error('Two-person rule violation: live jobs require an approver different from the requester.')
  }
  if (approvedBy === actor) {
    throw new Error('Two-person rule violation: approver cannot be the execution runner for live jobs.')
  }
}
```

### Execution Safety

Live execution is disabled by default. Set `MC_SUPER_PROVISION_EXEC=true` to enable.

Dry-run mode skips all command execution but records the plan steps as `skipped`.

### Decommissioning

`createTenantDecommissionJob()` builds a decommission plan:

```
1. disable-stop-gateway     — systemctl disable --now openclaw-gateway@{user}
2. remove-tenant-env        — rm -f /etc/openclaw-tenants/{user}.env
3. remove-openclaw-state    — rm -rf {openclaw_home}     (optional)
4. remove-workspace-dir     — rm -rf {workspace_root}    (optional)
5. remove-linux-user        — userdel -r {user}          (optional)
```

Steps 3-5 are controlled by `remove_state_dirs` and `remove_linux_user` flags.

### Provision Events

Every step of every job is tracked in `provision_events`:

```sql
CREATE TABLE provision_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id INTEGER NOT NULL,
    level TEXT NOT NULL DEFAULT 'info',    -- info, warn, error
    step_key TEXT,                          -- e.g., 'create-linux-user'
    message TEXT NOT NULL,
    data TEXT,                             -- JSON
    created_at INTEGER NOT NULL DEFAULT (unixepoch())
);
```

---

## Alert Rules

`src/app/api/alerts/route.ts` implements configurable alert rules with cooldown periods.

### Alert Rule Data Model

```typescript
interface AlertRule {
  id: number
  name: string
  description: string | null
  enabled: number
  entity_type: string         // 'agent', 'task', 'session', 'activity'
  condition_field: string     // Column to evaluate
  condition_operator: string  // 'equals', 'not_equals', 'greater_than', 'less_than',
                              // 'contains', 'count_above', 'count_below', 'age_minutes_above'
  condition_value: string
  action_type: string         // 'notification'
  action_config: string       // JSON with recipient, etc.
  cooldown_minutes: number    // Default 60
  last_triggered_at: number | null
  trigger_count: number
  created_by: string
}
```

### Rule Evaluation

`POST /api/alerts { action: "evaluate" }` runs all enabled rules:

1. For each enabled rule, check cooldown (skip if triggered within `cooldown_minutes`)
2. Evaluate condition based on `entity_type`:
   - **agent**: Check agent table for count/value matches, age threshold on `last_seen`
   - **task**: Count tasks matching status/priority conditions
   - **session**: Count busy agents as session proxy
   - **activity**: Count activities in last hour matching type
3. On trigger: increment counter, set `last_triggered_at`, create notification

### SQL Injection Prevention

Column names are whitelisted per table:

```typescript
const SAFE_COLUMNS: Record<string, Set<string>> = {
  agents: new Set(['status', 'role', 'name', 'last_seen', 'last_activity']),
  tasks: new Set(['status', 'priority', 'assigned_to', 'title']),
  activities: new Set(['type', 'actor', 'entity_type']),
}
```

Unknown columns fall back to `id`.

---

## Summary for The Hive

Key patterns to replicate:

1. **Webhooks as event bus subscribers** -- The webhook system doesn't know about task/agent internals. It subscribes to the event bus and pattern-matches event types. Adding webhook support for a new event is just adding a mapping to `EVENT_MAP`.

2. **Circuit breakers at the persistence layer** -- The `consecutive_failures` counter and `enabled` flag live on the `webhooks` row itself. No external circuit breaker library. Reset is a simple UPDATE.

3. **Gateway as a WebSocket-first protocol** -- The entire gateway communication layer is WebSocket with a structured frame protocol (req/res/event types). HTTP is only used for the REST API.

4. **1Password as the secret source of truth** -- Secrets flow from 1Password vault items to the `.env` file. The API never stores secrets in the database -- they always live in the filesystem.

5. **Multi-tenant provisioning is a job queue with human approval** -- Not automated. Every tenant bootstrap goes through queued -> approved -> running. Dry-run by default. Two-person rule for live execution. This is infrastructure-as-code meets change management.

6. **GitHub sync is metadata-driven dedup** -- Duplicate detection uses `json_extract()` on the task's `metadata` field rather than a dedicated foreign key. This keeps the task schema clean and makes GitHub an optional concern.

7. **Claude session discovery is filesystem-first** -- No API calls to Claude. Direct JSONL file parsing from `~/.claude/projects/`. The 60-second scan cycle is lightweight (just `stat` checks and file reads for changed files).
