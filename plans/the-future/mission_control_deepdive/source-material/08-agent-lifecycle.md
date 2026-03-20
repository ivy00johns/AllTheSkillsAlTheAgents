# 08 -- Agent Lifecycle

Agent registration, heartbeat protocol, sync from OpenClaw, SOUL content management, working memory, inter-agent communication, self-diagnostics, attribution, API keys, session discovery, templates, model catalog, spawn flow, and direct CLI integration.

---

## Agent Data Model

Agents are stored in the `agents` table in SQLite. The core fields:

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment ID |
| `name` | TEXT | Unique name (used as lookup key throughout) |
| `role` | TEXT | Agent role/theme (e.g., "operator strategist", "builder engineer") |
| `session_key` | TEXT | OpenClaw gateway session key for direct messaging |
| `soul_content` | TEXT | SOUL file content (agent identity/personality) |
| `working_memory` | TEXT | Per-agent scratchpad memory |
| `status` | TEXT | Current lifecycle state |
| `last_seen` | INTEGER | Unix timestamp of last heartbeat/activity |
| `last_activity` | TEXT | Description of last activity |
| `config` | TEXT (JSON) | Full OpenClaw agent configuration |
| `workspace_id` | INTEGER | Multi-tenant workspace isolation |
| `created_at` | INTEGER | Unix timestamp |
| `updated_at` | INTEGER | Unix timestamp |

---

## Agent Lifecycle States

Agents move through five states:

```
                  +--------+
                  | offline |<-------+
                  +----+---+        |
                       |            |
              register/connect      | timeout/disconnect
                       |            |
                  +----v---+        |
            +---->| online |--------+
            |     +----+---+
            |          |
            |     idle / heartbeat
            |          |
            |     +----v---+
            +---->|  idle  |--------+
            |     +----+---+        |
            |          |            |
            |     task assigned     | timeout
            |          |            |
            |     +----v---+        |
            +---->|  busy  |--------+
            |     +--------+
            |
            |     +--------+
            +---->| error  |--------+
                  +--------+        |
                       |            |
                  manual recovery   | timeout
                       |            |
                  +----v---+        |
                  | offline |<------+
                  +--------+

     retired (terminal, manual only)
```

| State | Meaning | Entry Condition |
|-------|---------|-----------------|
| `offline` | Not connected, not responding | Timeout, manual disconnect, or initial state |
| `online` | Connected and available | Registration or heartbeat with active connection |
| `idle` | Connected but no current work | Heartbeat with no assigned tasks |
| `busy` | Actively working on a task | Task assignment or status update |
| `error` | Encountered a failure | Error reported by agent or detected by system |
| `retired` | Permanently decommissioned | Manual admin action (not automated) |

### Stale Detection

The scheduler runs `runHeartbeatCheck()` every 5 minutes:

```typescript
// From src/lib/scheduler.ts
const timeoutMinutes = getSettingNumber('general.agent_timeout_minutes', 10)
const threshold = now - timeoutMinutes * 60

const staleAgents = db.prepare(`
  SELECT id, name, status, last_seen FROM agents
  WHERE status != 'offline' AND (last_seen IS NULL OR last_seen < ?)
`).all(threshold)
```

Agents that haven't been seen for 10 minutes (configurable) are automatically marked `offline`, logged in the activity feed, and trigger a notification.

---

## Agent Registration

### POST /api/agents

**Source:** `src/app/api/agents/route.ts`

**Auth:** `operator` role required

**Request body (validated by Zod):**

```typescript
const createAgentSchema = z.object({
  name: z.string().min(1).max(100),                    // Required
  openclaw_id: z.string().regex(/^[a-z0-9][a-z0-9-]*$/).max(100).optional(),
  role: z.string().min(1).max(100).optional(),          // Resolved from template if not provided
  session_key: z.string().max(200).optional(),
  soul_content: z.string().max(50000).optional(),
  status: z.enum(['online', 'offline', 'busy', 'idle', 'error']).default('offline'),
  config: z.record(z.string(), z.unknown()).default({}),
  template: z.string().max(100).optional(),             // Template type name
  gateway_config: z.record(z.string(), z.unknown()).optional(),
  write_to_gateway: z.boolean().optional(),             // Write config to openclaw.json
  provision_openclaw_workspace: z.boolean().optional(),  // Create workspace via OpenClaw CLI
  openclaw_workspace_path: z.string().min(1).max(500).optional(),
})
```

**Registration flow:**

1. **OpenClaw ID derivation:** If no `openclaw_id` provided, derives from name: lowercase, replace non-alphanumeric with `-`, trim hyphens
2. **Template resolution:** If `template` is specified, loads the template config and merges with provided config
3. **Duplicate check:** Agent name must be unique within the workspace
4. **OpenClaw workspace provisioning:** If `provision_openclaw_workspace: true`, runs `openclaw agents add {id} --name {name} --workspace {path} --non-interactive` via CLI (20s timeout)
5. **Database insert:** Writes to `agents` table with status defaulting to `offline`
6. **Activity logging:** `agent_created` activity recorded
7. **SSE broadcast:** `eventBus.broadcast('agent.created', parsedAgent)`
8. **Gateway write-back:** If `write_to_gateway: true`, writes the agent config to `openclaw.json`'s `agents.list` array

**Response:**
```json
{
  "agent": {
    "id": 5,
    "name": "Atlas",
    "role": "operator strategist",
    "status": "offline",
    "config": { ... },
    "taskStats": { "total": 0, "assigned": 0, "in_progress": 0, "completed": 0 }
  }
}
```

### GET /api/agents

Lists agents with optional filtering:

| Query Param | Description |
|------------|-------------|
| `status` | Filter by lifecycle state |
| `role` | Filter by role |
| `limit` | Max results (default 50, max 200) |
| `offset` | Pagination offset |

Each agent is enriched with:
- Parsed JSON config with workspace file enrichment (`identity.md`, `TOOLS.md`)
- Task statistics (total, assigned, in_progress, completed)

### PUT /api/agents/[id]

**Source:** `src/app/api/agents/[id]/route.ts`

Updates agent configuration with unified MC + gateway save. The `gateway_config` field is merged into the existing config, and if `write_to_gateway` is truthy (defaults to true when `gateway_config` is present), the config is also written to `openclaw.json`.

**Transactional save order:**
1. Write to gateway config file first
2. Update SQLite database
3. If DB update fails, attempt rollback of gateway config

### DELETE /api/agents/[id]

Requires `admin` role. Deletes the agent from SQLite and broadcasts `agent.deleted` event.

---

## Heartbeat Protocol

### GET /api/agents/[id]/heartbeat

**Source:** `src/app/api/agents/[id]/heartbeat/route.ts`

**Auth:** `viewer` role

A read-only heartbeat check that scans for work items and returns them. The agent checks in, and the server tells it what needs attention.

**Work item scan (last 4 hours):**

1. **@mentions** -- Searches `comments.mentions` for the agent's name in recent comments
2. **Assigned tasks** -- Finds tasks with `status IN ('assigned', 'in_progress')` assigned to this agent, ordered by priority
3. **Unread notifications** -- Calls `db_helpers.getUnreadNotifications()`
4. **Urgent activities** -- Scans for `task_created`, `task_assigned`, `high_priority_alert` activities mentioning this agent

**Side effects:**
- Updates agent status to `idle` with "Heartbeat check" activity
- Logs `agent_heartbeat` activity

**Response (no work):**
```json
{
  "status": "HEARTBEAT_OK",
  "agent": "Atlas",
  "checked_at": 1710000000,
  "message": "No work items found"
}
```

**Response (work found):**
```json
{
  "status": "WORK_ITEMS_FOUND",
  "agent": "Atlas",
  "checked_at": 1710000000,
  "work_items": [
    {
      "type": "assigned_tasks",
      "count": 3,
      "items": [
        { "id": 42, "title": "Fix auth bug", "status": "assigned", "priority": "high" }
      ]
    },
    {
      "type": "mentions",
      "count": 1,
      "items": [...]
    }
  ],
  "total_items": 4
}
```

### POST /api/agents/[id]/heartbeat

**Auth:** `operator` role

Enhanced heartbeat that accepts an optional body for inline token reporting and connection tracking.

**Request body (all optional):**
```json
{
  "connection_id": "uuid-of-direct-connection",
  "status": "busy",
  "last_activity": "Processing task #42",
  "token_usage": {
    "model": "anthropic/claude-sonnet-4-20250514",
    "inputTokens": 15000,
    "outputTokens": 3200,
    "taskId": 42
  }
}
```

**Inline token reporting:**
When `token_usage` is provided in the heartbeat body, the server:
1. Resolves the agent by ID or name
2. Creates a session ID as `{agent.name}:cli`
3. Validates the `taskId` exists in the workspace (if provided)
4. Inserts a `token_usage` record

This avoids a separate HTTP call for token reporting -- agents can piggyback token data on their regular heartbeat.

**Response:** Same as GET heartbeat, plus `token_recorded: boolean`.

---

## Agent Sync from OpenClaw

### Architecture

**Source:** `src/lib/agent-sync.ts`

Agent sync bridges the gap between OpenClaw's `openclaw.json` configuration file and Mission Control's SQLite database. It runs:

1. **On startup** -- `syncAgentsFromConfig('startup')` is called by the scheduler
2. **On demand** -- `POST /api/agents/sync` triggers a manual sync (requires `admin`)
3. **Preview mode** -- `GET /api/agents/sync` shows what would change without writing

### OpenClaw Agent Config Structure

```typescript
interface OpenClawAgent {
  id: string                    // Kebab-case identifier
  name?: string
  default?: boolean
  workspace?: string            // Path to agent workspace directory
  agentDir?: string
  model?: {
    primary?: string            // e.g., "anthropic/claude-opus-4-5"
    fallbacks?: string[]
  }
  identity?: {
    name?: string
    theme?: string              // Used as MC agent "role"
    emoji?: string
  }
  subagents?: any
  sandbox?: {
    mode?: 'all' | 'non-main'
    workspaceAccess?: 'rw' | 'ro' | 'none'
    scope?: string
    docker?: any
  }
  tools?: {
    allow?: string[]
    deny?: string[]
  }
  memorySearch?: any
}
```

### Sync Flow

```
openclaw.json
  |
  v
readOpenClawAgents()          -- Parse JSON, extract agents.list
  |
  v
for each agent:
  mapAgentToMC(agent)         -- Extract name, role, config JSON, soul_content
    |
    +-- enrichAgentConfigFromWorkspace()
    |     |
    |     +-- Read {workspace}/identity.md   -> parse name, theme, emoji
    |     +-- Read {workspace}/TOOLS.md      -> parse tool allow list
    |     +-- Merge workspace files with config (config wins on conflict)
    |
    +-- readWorkspaceFile(workspace, 'soul.md')  -> read SOUL content
  |
  v
Upsert to SQLite:
  - If agent name exists: compare config JSON + soul_content
    - If changed: UPDATE agents SET role, config, soul_content, updated_at
    - If unchanged: skip
  - If new: INSERT INTO agents (name, role, soul_content, status='offline', config)
  |
  v
Broadcast: eventBus.broadcast('agent.created', { type: 'sync', synced, created, updated })
Audit log: logAuditEvent({ action: 'agent_config_sync', ... })
```

### Workspace File Parsing

**`identity.md`** -- Parsed for structured metadata:
```markdown
# Agent Name
theme: operator strategist
emoji: compass
```
The parser extracts the first `#` heading as name, and `key: value` lines for theme and emoji.

**`TOOLS.md`** -- Parsed for tool allow lists:
```markdown
- `read`
- `write`
- `exec`
```
Supports `- tool_name`, `- \`tool_name\``, and bare `` `tool_name` `` formats.

### Bidirectional Sync

`writeAgentToConfig(agentConfig)` writes changes back to `openclaw.json`:
- Finds the agent by `id` in `agents.list`
- Deep-merges the update into the existing config (preserving fields not in the update)
- Writes the full file back with `JSON.stringify(parsed, null, 2) + '\n'`

---

## Claude Code Session Discovery

**Source:** `src/lib/claude-sessions.ts`

Discovers and tracks local Claude Code sessions by scanning `~/.claude/projects/` for JSONL session transcript files.

### Scan Flow

```
~/.claude/projects/
  |
  +-- -Users-johns-AI-project-a/
  |     +-- session-abc123.jsonl
  |     +-- session-def456.jsonl
  |
  +-- -Users-johns-AI-project-b/
        +-- session-ghi789.jsonl
```

Each JSONL file is parsed line-by-line to extract:

| Field | Source |
|-------|--------|
| `sessionId` | First `entry.sessionId` found |
| `model` | `entry.message.model` from assistant messages |
| `gitBranch` | `entry.gitBranch` |
| `projectPath` | `entry.cwd` |
| `userMessages` | Count of `type: 'user'` entries (excluding sidechains) |
| `assistantMessages` | Count of `type: 'assistant'` entries |
| `toolUses` | Count of `tool_use` content blocks in assistant messages |
| `inputTokens` | Sum of `usage.input_tokens + cache_read + cache_creation` |
| `outputTokens` | Sum of `usage.output_tokens` |
| `lastUserPrompt` | Last user message content (first 500 chars) |
| `isActive` | `lastMessageAt` within 5 minutes |

### Per-Token Pricing

```typescript
const MODEL_PRICING: Record<string, { input: number; output: number }> = {
  'claude-opus-4-6':   { input: 15 / 1_000_000, output: 75 / 1_000_000 },
  'claude-sonnet-4-6': { input: 3 / 1_000_000,  output: 15 / 1_000_000 },
  'claude-haiku-4-5':  { input: 0.8 / 1_000_000, output: 4 / 1_000_000 },
}

// Cost estimation includes cache adjustments:
// cache_read_tokens * input_price * 0.1   (90% discount)
// cache_creation_tokens * input_price * 1.25  (25% premium)
```

### Database Sync

`syncClaudeSessions()` upserts discovered sessions into the `claude_sessions` table:
- Runs every 60 seconds via the scheduler
- First scan runs 5 seconds after startup
- Marks all sessions inactive before scanning, then re-marks active ones
- Uses `ON CONFLICT(session_id) DO UPDATE` for idempotent upserts

### Codex Session Discovery

**Source:** `src/lib/codex-sessions.ts`

Similar to Claude sessions but scans `~/.codex/sessions/` for OpenAI Codex session files. Parses `session_meta`, `response_item`, and `event_msg` (token_count) JSONL entry types.

---

## Local Agent Discovery

Agents can be registered through three discovery mechanisms:

1. **OpenClaw sync** (`agent-sync.ts`) -- Reads `openclaw.json`, parses workspace files
2. **Claude Code session scan** (`claude-sessions.ts`) -- Discovers sessions from `~/.claude/projects/`
3. **Direct CLI connection** (`POST /api/connect`) -- Agents self-register

The scheduler coordinates automated discovery:

```typescript
// From src/lib/scheduler.ts - initScheduler()
syncAgentsFromConfig('startup')  // Immediate on startup

tasks.set('claude_session_scan', {
  intervalMs: 60_000,           // Every 60 seconds
  nextRun: now + 5_000,         // First scan 5s after startup
})
```

---

## SOUL Content

### GET /api/agents/[id]/soul

**Source:** `src/app/api/agents/[id]/soul/route.ts`

Retrieves the agent's SOUL content with source tracking:

**Resolution order:**
1. Read `soul.md` from the agent's workspace directory (if configured)
2. Fall back to `agents.soul_content` database column

**Response:**
```json
{
  "agent": { "id": 5, "name": "Atlas", "role": "operator strategist" },
  "soul_content": "# Atlas\n\nYou are the primary coordinator...",
  "source": "workspace",
  "available_templates": ["coordinator", "developer", "reviewer"],
  "updated_at": 1710000000
}
```

The `source` field tells the UI where the content came from: `"workspace"`, `"database"`, or `"none"`.

### PUT /api/agents/[id]/soul

**Auth:** `operator` role

Updates SOUL content with bidirectional sync:

1. If `template_name` is provided, loads the template from the configured templates directory and substitutes `{{AGENT_NAME}}`, `{{AGENT_ROLE}}`, `{{TIMESTAMP}}` placeholders
2. Writes to the agent's workspace `soul.md` file (if workspace is configured)
3. Updates the `agents.soul_content` database column
4. Logs `agent_soul_updated` activity with content length tracking

The response includes `saved_to_workspace: boolean` so the UI can show sync status.

---

## Working Memory

### GET/PUT/DELETE /api/agents/[id]/memory

**Source:** `src/app/api/agents/[id]/memory/route.ts`

Per-agent scratchpad memory stored in the `agents.working_memory` column.

**Key features:**

- **Append mode:** `PUT` with `{ append: true }` adds timestamped entries rather than replacing:
  ```
  ## 2026-03-20T10:30:00.000Z
  New memory entry here
  ```
- **Auto-migration:** If the `working_memory` column doesn't exist, the endpoint adds it via `ALTER TABLE`
- **Size tracking:** Response includes `size` (character count)

**Use case:** Agents use working memory as a scratchpad between sessions -- notes about ongoing tasks, learned preferences, coordination state.

---

## Agent Communications

### GET /api/agents/comms

**Source:** `src/app/api/agents/comms/route.ts`

Returns inter-agent communication data with three views:

1. **Messages timeline** -- Chronological list of agent-to-agent messages (human/system/operator messages filtered out)
2. **Communication graph** -- Edge list with message counts and last message timestamps per pair
3. **Per-agent stats** -- Sent/received counts per agent

**Query params:** `limit`, `offset`, `since` (unix timestamp), `agent` (filter to one agent)

**Response:**
```json
{
  "messages": [...],
  "total": 42,
  "graph": {
    "edges": [
      { "from_agent": "Atlas", "to_agent": "Forge", "message_count": 15, "last_message_at": 1710000000 }
    ],
    "agentStats": [
      { "agent": "Atlas", "sent": 20, "received": 15 }
    ]
  },
  "source": { "mode": "mixed", "seededCount": 10, "liveCount": 32 }
}
```

The `source.mode` field distinguishes between seeded demo data (`conv-multi-*` conversation IDs), live data, or both.

### POST /api/chat/messages

**Source:** `src/app/api/chat/messages/route.ts`

Sends a message with optional gateway forwarding:

1. **Persist** -- Inserts into `messages` table
2. **Notify** -- Creates notification for recipient
3. **Forward** (if `body.forward: true`) -- Delivers to the agent's live session via OpenClaw gateway:
   - Looks up agent's `session_key` in the DB
   - Falls back to scanning on-disk gateway session stores
   - Resolves `openclawId` from agent config or derives from name
   - Calls `openclaw gateway call agent` with idempotency key
4. **Coordinator mode** -- If `conversation_id` starts with `coord:`, the system creates visible status replies in the chat thread showing delivery status, and optionally waits for execution results

### POST /api/agents/message

**Source:** `src/app/api/agents/message/route.ts`

Simpler direct message endpoint that sends via OpenClaw's `sessions_send`:

```bash
openclaw gateway sessions_send --session {session_key} --message "Message from {from}: {message}"
```

Creates a notification and logs activity.

### Message Types

Messages use these types in the `message_type` column:

| Type | Description |
|------|-------------|
| `text` | Normal text message |
| `system` | System-generated message |
| `handoff` | Task handoff between agents |
| `status` | Status update (e.g., "I am coordinating...") |
| `command` | Command/instruction to an agent |

---

## Agent Attribution

### GET /api/agents/[id]/attribution

**Source:** `src/app/api/agents/[id]/attribution/route.ts`

Self-scoped cost and audit reports. By default, only the agent itself (or admin with `?privileged=1`) can access its own attribution data.

**Query params:**
- `hours` -- Time window (default: 24, max: 720 = 30 days)
- `section` -- Comma-separated: `identity`, `audit`, `mutations`, `cost`

**Sections:**

**`identity`** -- Agent profile with lifetime stats:
```json
{
  "id": 5,
  "name": "Atlas",
  "role": "operator strategist",
  "status": "online",
  "session_key": "***",
  "has_soul": true,
  "config_keys": ["openclawId", "model", "identity", "sandbox", "tools"],
  "lifetime_stats": {
    "tasks_total": 45,
    "tasks_completed": 38,
    "tasks_active": 3,
    "comments_authored": 127
  }
}
```

**`audit`** -- Activity trail with type aggregation:
```json
{
  "total_activities": 234,
  "by_type": {
    "agent_heartbeat": 100,
    "task_status_change": 50,
    "chat_message": 84
  },
  "activities": [...],
  "audit_log_entries": [...]
}
```

**`mutations`** -- Task changes, comments, status transitions attributed to this agent

**`cost`** -- Token usage per model with daily trend:
```json
{
  "by_model": [
    { "model": "claude-sonnet-4", "request_count": 150, "input_tokens": 500000, "output_tokens": 120000 }
  ],
  "total": { "input_tokens": 500000, "output_tokens": 120000, "requests": 150 },
  "daily_trend": [
    { "date": "2026-03-19", "input_tokens": 250000, "output_tokens": 60000, "requests": 75 }
  ]
}
```

---

## Agent Diagnostics

### GET /api/agents/[id]/diagnostics

**Source:** `src/app/api/agents/[id]/diagnostics/route.ts`

Self-optimization data: performance metrics, error analysis, and trend comparison so agents can improve themselves.

**Query params:**
- `hours` -- Time window (default: 24, max: 720)
- `section` -- Comma-separated: `summary`, `tasks`, `errors`, `activity`, `trends`, `tokens`

**Sections:**

**`summary`** -- High-level KPIs:
```json
{
  "tasks_completed": 12,
  "tasks_total": 45,
  "activity_count": 234,
  "error_count": 3,
  "error_rate_percent": 1.28
}
```

**`tasks`** -- Task completion breakdown by status and priority, throughput per day

**`errors`** -- Error frequency by type, recent error details with parsed data

**`activity`** -- Activity type distribution with hourly timeline for pattern detection

**`trends`** -- Multi-period comparison (current vs previous period of same length):
```json
{
  "current_period": { "activities": 234, "errors": 3, "tasks_completed": 12 },
  "previous_period": { "activities": 200, "errors": 1, "tasks_completed": 10 },
  "change": {
    "activities_pct": 17.0,
    "errors_pct": 200.0,
    "tasks_completed_pct": 20.0
  },
  "alerts": [
    { "level": "warning", "message": "Error count increased 200% vs previous period" }
  ]
}
```

**Automatic trend alerts:**

| Condition | Alert Level | Message |
|-----------|-------------|---------|
| Error increase > 50% | warning | "Error count increased {N}% vs previous period" |
| New errors (0 -> 3+) | warning | "New error pattern: {N} errors (none in previous period)" |
| Zero tasks completed (prev > 0) | info | "No tasks completed in current period (possible stall)" |
| Throughput drop > 50% | info | "Task throughput dropped {N}%" |
| Activity drop > 75% | warning | "Activity dropped {N}% -- agent may be stalled" |

**`tokens`** -- Token usage by model (same as attribution cost section)

---

## Agent API Keys

### GET/POST/DELETE /api/agents/[id]/keys

**Source:** `src/app/api/agents/[id]/keys/route.ts`

**Auth:** `admin` role required for all operations

Manages per-agent API keys for programmatic access. Keys are stored as SHA-256 hashes with a visible prefix.

**Key format:** `mca_{48-hex-chars}` (e.g., `mca_a1b2c3d4e5f6...`)

**Scopes:**

| Scope | Description |
|-------|-------------|
| `viewer` | Read-only access |
| `operator` | Read + write access |
| `admin` | Full access |
| `agent:self` | Self-scoped agent operations |
| `agent:diagnostics` | Access own diagnostics |
| `agent:attribution` | Access own attribution data |
| `agent:heartbeat` | Send heartbeats |
| `agent:messages` | Send/receive messages |

Default scopes if none specified: `['viewer', 'agent:self']`

**Expiry:** Optional, via `expires_at` (unix timestamp) or `expires_in_days` (1-3650).

**Revocation:** `DELETE` sets `revoked_at` timestamp (soft delete).

---

## Agent Templates

**Source:** `src/lib/agent-templates.ts`

Seven predefined agent archetypes provide starting configurations for new agents:

| Template | Model Tier | Tools | Description |
|----------|-----------|-------|-------------|
| `orchestrator` | Opus ($$$) | 23 | Primary coordinator with full tool access |
| `developer` | Sonnet ($$) | 21 | Full-stack builder with Docker bridge networking |
| `specialist-dev` | Sonnet ($$) | 15 | Focused developer for specific domains |
| `reviewer` | Haiku ($) | 7 | Read-only for code review and QA |
| `researcher` | Sonnet ($$) | 8 | Browser/web access, no code execution |
| `content-creator` | Haiku ($) | 9 | Write/edit access, no code execution |
| `security-auditor` | Sonnet ($$) | 10 | Read-only + bash for security scanning |

### Tool Groups

Templates compose tools from named groups:

```typescript
const TOOL_GROUPS = {
  coding:   ['read', 'write', 'edit', 'apply_patch', 'exec', 'bash', 'process'],
  browser:  ['browser', 'web'],
  memory:   ['memory_search', 'memory_get'],
  session:  ['agents_list', 'sessions_list', 'sessions_history',
             'sessions_send', 'sessions_spawn', 'session_status'],
  subagent: ['subagents', 'lobster', 'llm-task'],
  thinking: ['thinking', 'reactions', 'skills'],
  readonly: ['read', 'memory_search', 'memory_get', 'agents_list'],
}
```

### Model Fallback Chains

Each template defines fallback models for resilience:

**Opus fallbacks:**
```
anthropic/claude-opus-4-5
  -> anthropic/claude-sonnet-4-20250514
  -> moonshot/kimi-k2-thinking
  -> nvidia/moonshotai/kimi-k2-instruct
  -> openrouter/moonshotai/kimi-k2.5
  -> openai/codex-mini-latest
```

**Sonnet fallbacks:**
```
anthropic/claude-sonnet-4-20250514
  -> openrouter/anthropic/claude-sonnet-4
  -> moonshot/kimi-k2-thinking
  -> openrouter/moonshotai/kimi-k2.5
  -> nvidia/moonshotai/kimi-k2-instruct
  -> openai/codex-mini-latest
  -> ollama/qwen2.5-coder:14b
```

### `buildAgentConfig()`

Converts a template + overrides into a full `OpenClawAgentConfig`:

```typescript
buildAgentConfig(template, {
  id: 'my-agent',
  name: 'My Agent',
  workspace: '/path/to/workspace',
  emoji: '🔨',
  theme: 'custom builder',
  model: 'anthropic/claude-sonnet-4-20250514',
  workspaceAccess: 'rw',
  sandboxMode: 'all',
  dockerNetwork: 'bridge',
  subagentAllowAgents: ['helper-1', 'helper-2'],
})
```

### Sandbox Configurations

| Mode | Description |
|------|-------------|
| `all` | All commands run in sandbox |
| `non-main` | Only non-main branch commands are sandboxed |

| Workspace Access | Description |
|-----------------|-------------|
| `rw` | Read-write to workspace |
| `ro` | Read-only workspace |
| `none` | No workspace access |

Docker networking: `none` (isolated) or `bridge` (can access network).

---

## Model Catalog

**Source:** `src/lib/models.ts`

```typescript
export const MODEL_CATALOG: ModelConfig[] = [
  { alias: 'haiku',     name: 'anthropic/claude-3-5-haiku-latest',     provider: 'anthropic', costPer1k: 0.25 },
  { alias: 'sonnet',    name: 'anthropic/claude-sonnet-4-20250514',    provider: 'anthropic', costPer1k: 3.0 },
  { alias: 'opus',      name: 'anthropic/claude-opus-4-5',             provider: 'anthropic', costPer1k: 15.0 },
  { alias: 'deepseek',  name: 'ollama/deepseek-r1:14b',               provider: 'ollama',    costPer1k: 0.0 },
  { alias: 'groq-fast', name: 'groq/llama-3.1-8b-instant',            provider: 'groq',      costPer1k: 0.05 },
  { alias: 'groq',      name: 'groq/llama-3.3-70b-versatile',         provider: 'groq',      costPer1k: 0.59 },
  { alias: 'kimi',      name: 'moonshot/kimi-k2.5',                   provider: 'moonshot',  costPer1k: 1.0 },
  { alias: 'minimax',   name: 'minimax/minimax-m2.1',                 provider: 'minimax',   costPer1k: 0.3 },
]
```

**Providers supported:**

| Provider | Models | Cost Range |
|----------|--------|------------|
| **Anthropic** | Haiku, Sonnet, Opus | $0.25 - $15.00 / 1k tokens |
| **Ollama** (local) | DeepSeek R1 14B | Free |
| **Groq** | Llama 3.1 8B, Llama 3.3 70B | $0.05 - $0.59 / 1k tokens |
| **Moonshot** | Kimi K2.5 | $1.00 / 1k tokens |
| **MiniMax** | MiniMax M2.1 | $0.30 / 1k tokens |

Lookup functions: `getModelByAlias('sonnet')`, `getModelByName('anthropic/claude-sonnet-4-20250514')`, `getAllModels()`.

---

## The Spawn Flow

### POST /api/spawn

**Source:** `src/app/api/spawn/route.ts`

**Auth:** `operator` role, rate-limited by `heavyLimiter`

Spawns a new agent session via OpenClaw's `sessions_spawn` function.

**Request body:**
```typescript
const spawnAgentSchema = z.object({
  task: z.string().min(1),
  model: z.string().min(1),
  label: z.string().min(1),
  timeoutSeconds: z.number().min(10).max(3600).default(300),
})
```

**Spawn flow:**

1. Generate spawn ID: `spawn-{timestamp}-{random9}`
2. Construct spawn payload with tools profile from `OPENCLAW_TOOLS_PROFILE` env var (default: `coding`)
3. Execute via `clawdbot -c 'sessions_spawn({payload})'` (10s timeout)
4. **Compatibility fallback:** If the spawn fails with schema-related errors (`unknown field`, `unknown key`, `tools`, `profile`), retry without the `tools` field for backward compatibility with older OpenClaw versions
5. Parse stdout for session info
6. Return spawn result with compatibility metadata

**Response:**
```json
{
  "success": true,
  "spawnId": "spawn-1710000000-abc123def",
  "sessionInfo": "Session created: session-xyz",
  "task": "Fix the auth bug",
  "model": "anthropic/claude-sonnet-4-20250514",
  "label": "auth-fix",
  "timeoutSeconds": 300,
  "createdAt": 1710000000000,
  "stdout": "...",
  "stderr": "...",
  "compatibility": {
    "toolsProfile": "coding",
    "fallbackUsed": false
  }
}
```

### GET /api/spawn

Returns spawn history by scanning log files for `sessions_spawn` entries (best-effort).

---

## Direct CLI Integration

### POST /api/connect

**Source:** `src/app/api/connect/route.ts`

Registers a direct CLI connection, bypassing the OpenClaw gateway entirely.

**Request body:**
```typescript
const connectSchema = z.object({
  tool_name: z.string().min(1).max(100),    // e.g., "claude-code", "codex"
  tool_version: z.string().max(50).optional(),
  agent_name: z.string().min(1).max(100),
  agent_role: z.string().max(100).optional(),
  metadata: z.record(z.string(), z.unknown()).optional(),
})
```

**Registration flow:**

1. **Find or create agent** -- If `agent_name` doesn't exist in the DB, auto-creates it with status `online` and role from `agent_role` (default: `cli`)
2. **Set agent online** -- If agent exists, updates status to `online`
3. **Deactivate previous connections** -- All existing `connected` connections for this agent are set to `disconnected`
4. **Create new connection** -- Inserts into `direct_connections` table with a UUID `connection_id`
5. **Broadcast events** -- `connection.created` and optionally `agent.created`

**Response:**
```json
{
  "connection_id": "550e8400-e29b-41d4-a716-446655440000",
  "agent_id": 5,
  "agent_name": "my-cli-agent",
  "status": "connected",
  "sse_url": "/api/events",
  "heartbeat_url": "/api/agents/5/heartbeat",
  "token_report_url": "/api/tokens"
}
```

The response includes helper URLs so the CLI tool knows where to send heartbeats and token reports.

### DELETE /api/connect

Disconnects a connection by `connection_id`. If the agent has no other active connections, sets the agent to `offline`.

### GET /api/connect

Lists all direct connections with agent metadata.

### Connection Lifecycle

```
CLI Tool                    MC Backend
  |                             |
  | POST /api/connect           |
  |----------------------------->|
  |                             | Auto-create agent (if new)
  |                             | Deactivate old connections
  |                             | Create connection record
  |                             | Broadcast connection.created
  |<-----------------------------|
  | { connection_id, heartbeat_url, ... }
  |                             |
  | POST /api/agents/{id}/heartbeat (every N minutes)
  |----------------------------->|
  |                             | Update last_heartbeat
  |                             | Check for work items
  |<-----------------------------|
  | { status: HEARTBEAT_OK } or { work_items: [...] }
  |                             |
  | POST /api/tokens (report usage)
  |----------------------------->|
  |                             | Record token_usage
  |                             |
  | DELETE /api/connect         |
  |----------------------------->|
  |                             | Mark connection disconnected
  |                             | Set agent offline (if no other connections)
  |                             | Broadcast connection.disconnected
```

---

## Agent Wake

### POST /api/agents/[id]/wake

**Source:** `src/app/api/agents/[id]/wake/route.ts`

**Auth:** `operator` role

Sends a wake-up message to an agent's live gateway session:

```bash
openclaw gateway sessions_send --session {session_key} --message "{message}"
```

Default message: `"Wake up check-in for {name}. Please review assigned tasks and notifications."`

Custom messages can be provided in the request body.

Sets agent status to `idle` after wake.

---

## Architecture Decisions for The Hive

### Key patterns to replicate:

1. **Agent name as the universal key** -- Throughout the codebase, agents are looked up by name (not just ID). API endpoints accept both `id` (numeric) and `name` (string). The name is the coordination key for tasks, comments, mentions, and comms.

2. **Heartbeat as work queue** -- The heartbeat is not just a health check; it returns actionable work items. This makes polling-based agents productive -- they don't need a separate work queue.

3. **Inline token reporting** -- Piggybacking token usage on heartbeats eliminates a separate HTTP call. For agents that heartbeat every few minutes, this provides continuous cost tracking.

4. **Self-scoped diagnostics and attribution** -- By default, agents can only see their own data. This is both a security boundary and a design pattern: agents use their own diagnostics to self-optimize.

5. **Bidirectional SOUL sync** -- SOUL content flows both directions: workspace `soul.md` files and the database column stay in sync. The workspace file is the source of truth when present.

6. **Template-based provisioning** -- Seven archetypes cover 90% of use cases. Templates define not just the model but the full security posture: sandbox mode, workspace access, tool allowlists, Docker networking.

7. **Auto-create on connect** -- Direct CLI connections auto-create agents if they don't exist. This eliminates the chicken-and-egg problem of needing to register an agent before it can connect.

8. **Stale detection via scheduler** -- The 5-minute heartbeat check and 10-minute timeout (configurable) provide automatic offline detection without requiring agents to explicitly disconnect.

9. **Gateway write-back** -- Agent config changes in the UI are written back to `openclaw.json`, keeping the gateway config and MC database in sync.

10. **Multi-provider model catalog** -- Support for Anthropic, Ollama (local/free), Groq, Moonshot, and MiniMax provides cost-performance flexibility. Each template specifies fallback chains across providers.
