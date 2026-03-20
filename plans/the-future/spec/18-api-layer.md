# 18 — API Layer

**Document type:** API surface specification
**Status:** DRAFT
**Date:** 2026-03-20
**Scope:** HTTP API surface for The Hive platform — REST endpoints, SSE event streaming, WebSocket terminal I/O, authentication, rate limiting, error handling
**Prerequisite reading:** `03-system-architecture.md` (5-layer model, data stores), `09-orchestration-engine.md` (coordinator loop, sling dispatch, agent lifecycle), `13-observability.md` (event system, sessions, metrics)
**Source material:** Mission Control v1.3.0 (83 API routes, auth patterns, rate limiting), Agentic UI Dashboard spec (endpoint catalog, AG-UI protocol, SSE/WS requirements)

---

## 1. Why an API Layer

### The CLI Is Not Enough

The Hive is designed as a CLI-first platform. The Smoker (`platform` CLI) is the beekeeper's primary tool — it starts builds, dispatches Workers, inspects The Comb, and queries The Airway. Every capability the platform offers is available through a CLI command.

But The Glass (the observation dashboard) runs in a browser. Browsers cannot shell out to `platform fleet status`. They need HTTP endpoints that return JSON. They need Server-Sent Events that push state changes in real time. They need WebSocket connections for bidirectional terminal I/O.

The API layer is a view and control surface on top of the same internal state that the CLI accesses. It does not replace The Airway (Valkey Streams event bus), The Comb (PostgreSQL + Dolt work state), or the orchestration engine. It exposes them to HTTP clients.

### Architecture Position

```
┌─────────────────────────────────────────────────────────────┐
│  The Glass (Browser Dashboard)                               │
│  React 19 + AG-UI protocol + xterm.js                        │
├──────────────┬──────────────────┬────────────────────────────┤
│  REST/JSON   │  SSE /api/events │  WS /api/terminal/:agentId │
├──────────────┴──────────────────┴────────────────────────────┤
│  API Layer (this document)                                    │
│  Fastify HTTP server — auth, rate limiting, routing           │
├──────────────────────────────────────────────────────────────┤
│  Service Layer (shared with CLI)                              │
│  buildService, agentService, workService, metricsService...   │
├──────────────────────────────────────────────────────────────┤
│  The Comb        │  The Airway      │  ClickHouse             │
│  PostgreSQL/Dolt │  Valkey Streams  │  Metrics/analytics       │
└──────────────────┴──────────────────┴─────────────────────────┘
```

The API layer sits between The Glass and the service layer. The Smoker (CLI) also calls the service layer directly. Neither surface is "the real one" — both are thin wrappers over the same functions.

### Starting the API

```bash
platform serve --port 3000
platform serve --port 3000 --host 0.0.0.0
platform serve --port 3000 --tls --cert ./certs/cert.pem --key ./certs/key.pem
```

`platform serve` starts a Fastify HTTP server with access to the same database connections, Valkey client, and service layer that the CLI uses. It does not spawn a separate runtime.

---

## 2. Authentication Model

### Three Principals

| Principal | Credential | Storage | Use Case |
|-----------|-----------|---------|----------|
| **Browser user** | Session cookie | PostgreSQL `sessions` table | The Glass dashboard |
| **Agent API key** | `X-Agent-Key` header | PostgreSQL `agent_keys` (SHA-256 hashed) | Per-Worker API access |
| **System API key** | `X-System-Key` header | PostgreSQL `system_keys` (SHA-256 hashed) | CI/CD, infrastructure |

All three resolve to the same `AuthContext` after authentication:

```typescript
interface AuthContext {
  principalType: 'user' | 'agent' | 'system';
  principalId: string;
  role: Role;
  workspaceId: string;
  sessionId?: string;       // browser sessions only
  agentId?: string;         // agent keys only
  scopes?: string[];        // optional fine-grained permissions
}

type Role = 'viewer' | 'operator' | 'admin' | 'fleet_admin';
```

### The `requireRole()` Guard

Authentication is enforced through a discriminated union pattern proven at production scale by Mission Control (83 routes, zero auth bypass bugs). TypeScript narrows the type after the guard check, eliminating `undefined` access.

```typescript
type AuthResult =
  | { ok: true; auth: AuthContext }
  | { ok: false; error: string; status: 401 | 403 };

function requireRole(request: FastifyRequest, minimumRole: Role): AuthResult;
```

### Role Hierarchy

Roles are numeric integers internally, enabling `>=` comparison. Each role inherits all permissions of lower roles.

| Role | Level | Capabilities |
|------|-------|-------------|
| `viewer` | 0 | Read all state, view The Glass |
| `operator` | 1 | Start/pause/resume builds, approve Inspections, dispatch Workers |
| `admin` | 2 | Manage API keys, configure workspace, kill Workers |
| `fleet_admin` | 3 | Multi-Colony federation, system keys, RBAC management |

### Session Management

Browser sessions use HTTP-only cookies: 32 random bytes, SHA-256 hashed in PostgreSQL, 7-day TTL, `sameSite: 'strict'`, `secure: true` in production.

### Agent API Keys

Per-Worker keys: 32 random bytes, displayed once, stored as SHA-256 hashes. Scoped to a workspace and fixed role. Each key record tracks `agentId`, `workspaceId`, `role`, `label`, `lastUsedAt`, `createdAt`, and optional `expiresAt`.

---

## 3. Rate Limiting

### Four-Tier Factory

Rate limits are tracked in Valkey using sliding window counters, enforced per principal.

| Tier | Budget | Window | Applies To | Disableable |
|------|--------|--------|-----------|-------------|
| `login` | 5 req | 1 min | `POST /api/auth/login` | **No** — always enforced |
| `mutation` | 60 req | 1 min | POST/PUT/PATCH/DELETE on state-changing endpoints | Yes (dev mode) |
| `heavy` | 10 req | 1 min | Expensive queries (full state, metrics aggregation) | Yes (dev mode) |
| `read` | 120 req | 1 min | GET endpoints | Yes (dev mode) |

Every response includes `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` headers. Exceeded budgets return HTTP 429 with a `Retry-After` header.

System API keys can be granted elevated limits. Agent API keys used by Workers during a build are exempt from the `read` tier (Workers query state frequently during coordination).

---

## 4. REST Endpoints

All endpoints use the `/api/v1/` prefix. Examples use the short form `/api/` for readability.

### Route Pipeline

```
Request → Rate limit (Valkey) → Auth (cookie/key) → Role guard → Validation (JSON Schema)
  → Handler (service layer) → Event emission (The Airway) → Response (standard envelope)
```

---

### 4.1 Authentication

**`POST /api/auth/login`** — Authenticate a browser user. Rate: `login`. Auth: none.

```json
// Request
{ "email": "keeper@thehive.dev", "password": "..." }

// Response 200 — sets hive_session cookie
{ "data": { "user": { "id": "usr_abc123", "email": "...", "displayName": "The Keeper", "role": "admin" } } }
```

**`POST /api/auth/logout`** — Destroy session. Rate: `mutation`. Auth: `viewer`. Clears cookie.

**`GET /api/auth/me`** — Return authenticated principal. Rate: `read`. Auth: `viewer`.

---

### 4.2 Builds

Builds are the primary unit of orchestrated work — The Queen dispatches a Swarm of Workers to execute a build plan across phases.

**`POST /api/builds`** — Start a new build. Rate: `mutation`. Auth: `operator`.

```json
// Request
{
  "description": "Implement user authentication module",
  "formulaPath": "formulas/auth-module.toml",
  "options": { "maxAgents": 10, "costCeiling": 50.00, "dryRun": false }
}

// Response 201
{ "data": { "buildId": "build_abc123", "status": "initializing", "phase": 0, "agents": [] } }
```

**`GET /api/builds/:id`** — Get build state. Rate: `read`. Auth: `viewer`.

```json
// Response 200
{
  "data": {
    "buildId": "build_abc123", "status": "running", "phase": 3, "phaseName": "Quality Gates",
    "agents": [{ "agentId": "agent_w01", "role": "backend-builder", "status": "working", "contextUsagePct": 42.5 }],
    "cellsSummary": { "total": 24, "completed": 18, "inProgress": 4, "blocked": 1, "remaining": 1 },
    "cost": { "totalTokens": 1250000, "estimatedCost": 12.50, "costCeiling": 50.00 }
  }
}
```

**`POST /api/builds/:id/pause`** — Pause build. Workers finish current Cell, accept no new work. Rate: `mutation`. Auth: `operator`.

**`POST /api/builds/:id/resume`** — Resume paused build. Rate: `mutation`. Auth: `operator`.

**`POST /api/builds/:id/cancel`** — Cancel build. All Workers terminated, in-progress Cells marked `abandoned`. Rate: `mutation`. Auth: `operator`.

---

### 4.3 Agents (Workers)

**`GET /api/agents`** — List Workers in current Yard. Rate: `read`. Auth: `viewer`.

Query params: `status`, `role`, `buildId`.

```json
// Response 200
{
  "data": [{
    "agentId": "agent_w01", "name": "backend-builder-01", "role": "backend-builder",
    "caste": "Builder", "status": "working", "buildId": "build_abc123",
    "currentCell": "cell_xyz", "contextUsagePct": 42.5, "tokensUsed": 85000,
    "cost": 0.85, "lastHeartbeat": "2026-03-20T14:32:30.000Z"
  }]
}
```

**`GET /api/agents/:id`** — Single Worker detail. Rate: `read`. Auth: `viewer`.

Returns all list fields plus: `runtime`, `model`, `depth`, `parentAgentId`, `childAgentIds`, `branchName`, `filesOwned`, `recentEvents[]`.

**`POST /api/agents/:id/kill`** — Terminate Worker (SIGTERM, 10s grace, SIGKILL). Current Cell marked `abandoned`. Rate: `mutation`. Auth: `admin`.

```json
// Request (optional)
{ "reason": "Agent stuck in retry loop", "reassignCell": true }
```

---

### 4.4 Approvals (Inspections)

When a Worker reaches a quality gate (an Inspection), the build suspends that Worker's pipeline and creates a pending approval for The Keeper.

**`GET /api/approvals`** — List Inspections. Rate: `read`. Auth: `viewer`.

Query params: `status` (`pending` | `approved` | `rejected` | `all`), `buildId`.

```json
// Response 200
{
  "data": [{
    "approvalId": "apr_abc123", "buildId": "build_abc123", "agentId": "agent_w01",
    "gateName": "qa-review", "cellId": "cell_xyz", "status": "pending",
    "qaReport": {
      "contractConformance": 4, "codeQuality": 3, "securityPosture": 4,
      "testCoverage": 3, "documentationCompleteness": 2,
      "overallVerdict": "CONDITIONAL_PASS", "criticalBlockers": [],
      "warnings": ["Documentation incomplete for auth module"]
    }
  }]
}
```

**`POST /api/approvals/:id/decide`** — Submit decision. Rate: `mutation`. Auth: `operator`.

```json
// Approve
{ "decision": "approved", "comment": "Looks good.", "conditions": [] }

// Reject with Rehatch (retry)
{ "decision": "rejected", "comment": "Missing input validation.", "rehatch": true }
```

---

### 4.5 Work Items (Cells)

Cells are the atomic units of work in The Frame (task graph). Each Cell is assigned to a single Worker with exclusive file ownership.

**`GET /api/work`** — List Cells with filtering. Rate: `read`. Auth: `viewer`.

Query params: `status`, `assignee`, `buildId`, `priority`, `limit` (default 50, max 200), `offset`.

```json
// Response 200
{
  "data": {
    "items": [{
      "cellId": "cell_xyz", "title": "Implement login endpoint", "status": "in_progress",
      "priority": "high", "assignee": "agent_w01", "buildId": "build_abc123",
      "dependencies": ["cell_abc", "cell_def"],
      "acceptanceCriteria": ["POST /auth/login returns JWT", "Returns 401 on invalid creds"],
      "estimatedTokens": 50000, "actualTokens": 38000
    }],
    "pagination": { "total": 24, "limit": 50, "offset": 0, "hasMore": false }
  }
}
```

**`POST /api/work`** — Create Cell. Rate: `mutation`. Auth: `operator`.

```json
// Request
{
  "title": "Add password reset endpoint", "priority": "normal", "buildId": "build_abc123",
  "dependencies": ["cell_xyz"],
  "acceptanceCriteria": ["Sends reset email with one-time token", "Token expires after 1 hour"],
  "fileScope": ["src/auth/reset.ts"], "contractRefs": ["contracts/auth-api.yaml"]
}
```

**`GET /api/work/:id`** — Full Cell detail including `outcome`, `errorSummary`, `retryCount`, `completedAt`, dependency graph. Rate: `read`. Auth: `viewer`.

**`PATCH /api/work/:id`** — Update mutable fields (priority, assignee). Rate: `mutation`. Auth: `operator`.

---

### 4.6 Fleet State

**`GET /api/state`** — Full orchestrator snapshot. The single query that answers "what is everything doing right now." Primary data source for The Yard View. Rate: `heavy`. Auth: `viewer`.

```json
// Response 200
{
  "data": {
    "buildId": "build_abc123", "buildStatus": "running", "buildPhase": 3,
    "agents": [{ "agentId": "agent_w01", "role": "backend-builder", "status": "working", "contextUsagePct": 42.5 }],
    "pendingApprovals": [{ "approvalId": "apr_abc123", "agentId": "agent_w02", "gateName": "qa-review" }],
    "fileOwnershipMap": { "src/auth/login.ts": "agent_w01", "src/ui/login-form.tsx": "agent_w02" },
    "mergeQueue": { "depth": 2, "headBranch": "build/abc123/agent_w03" },
    "cost": { "totalCost": 12.50, "costCeiling": 50.00, "projectedFinalCost": 28.00 },
    "workload": "normal", "connectedClients": 3, "uptime": 3600
  }
}
```

---

### 4.7 Files

File endpoints expose code changes each Worker has made in their git worktree.

**`GET /api/files/:agentId`** — List modified files. Rate: `read`. Auth: `viewer`.

```json
// Response 200
{
  "data": {
    "agentId": "agent_w01", "branchName": "build/abc123/agent_w01",
    "files": [
      { "path": "src/auth/login.ts", "changeType": "added", "additions": 85, "deletions": 0 },
      { "path": "src/auth/session.ts", "changeType": "modified", "additions": 12, "deletions": 5 }
    ],
    "summary": { "filesChanged": 2, "totalAdditions": 97, "totalDeletions": 5 }
  }
}
```

**`GET /api/files/:agentId/:path`** — Unified diff for a file. Path is URL-encoded. Rate: `read`. Auth: `viewer`.

Query params: `format` (`unified` | `side-by-side` | `raw`), `context` (lines, default 3).

Returns `diff` (unified diff string), `before` (full content or null), `after` (full content).

---

### 4.8 Contracts

**`GET /api/contracts`** — List active contracts. Rate: `read`. Auth: `viewer`.

Query params: `type` (`openapi`, `asyncapi`, `typescript`, `pydantic`, `json-schema`), `buildId`.

```json
// Response 200
{
  "data": [{
    "contractId": "contract_auth", "type": "openapi", "title": "User Authentication API",
    "path": "contracts/auth-api.yaml", "endpointCount": 5, "implementedCount": 3,
    "complianceScore": 0.60, "assignedAgents": ["agent_w01", "agent_w02"]
  }]
}
```

**`GET /api/contracts/:id/compliance`** — Compliance report. Rate: `heavy`. Auth: `viewer`.

Returns `overallCompliance`, per-endpoint status (`implemented` | `missing` | `drift`), drift details, `auditedAt`.

---

### 4.9 Metrics (The Yield)

**`GET /api/metrics`** — Metrics snapshot. Rate: `heavy`. Auth: `viewer`.

Query params: `buildId`, `window` (`1h` | `6h` | `24h` | `7d`).

```json
// Response 200
{
  "data": {
    "tokenUsage": {
      "totalInput": 850000, "totalOutput": 400000,
      "byAgent": { "agent_w01": { "input": 120000, "output": 55000 } },
      "byModel": { "claude-sonnet-4-20250514": { "input": 500000, "output": 250000 } }
    },
    "cost": { "total": 12.50, "cacheDiscount": 2.10 },
    "throughput": { "cellsCompleted": 18, "cellsPerHour": 12.0, "mergeSuccessRate": 0.93 },
    "quality": { "avgContractConformance": 3.8, "gatePassRate": 0.85, "retryRate": 0.12 },
    "timing": { "avgCellDurationMs": 180000, "p95CellDurationMs": 420000 }
  }
}
```

**`GET /api/metrics/cost`** — Cost projections and budget tracking. Rate: `read`. Auth: `viewer`.

```json
// Response 200
{
  "data": {
    "currentCost": 12.50, "costCeiling": 50.00, "burnRate": 4.20, "burnRateUnit": "per_hour",
    "projectedFinalCost": 28.00,
    "costByPhase": [{ "phase": 1, "cost": 3.20, "status": "completed" }],
    "cacheEfficiency": { "cacheHitRate": 0.35, "costSavedByCache": 2.10 }
  }
}
```

---

### 4.10 Layouts

Dashboard layout persistence for The Glass. Each layout defines which blocks are visible, their positions, and per-block settings.

**`GET /api/layouts`** — List saved layouts. Rate: `read`. Auth: `viewer`.

**`POST /api/layouts`** — Save layout. Rate: `mutation`. Auth: `viewer`.

```json
// Request
{
  "name": "QA Review Layout", "isDefault": false,
  "blocks": [
    { "blockType": "fleet-overview", "position": { "x": 0, "y": 0, "width": 12, "height": 4 }, "config": {} },
    { "blockType": "approval-queue", "position": { "x": 0, "y": 4, "width": 6, "height": 8 }, "config": {} },
    { "blockType": "terminal", "position": { "x": 6, "y": 4, "width": 6, "height": 8 }, "config": { "agentId": "agent_w01" } }
  ]
}
```

**`PUT /api/layouts/:id`** — Update layout. Rate: `mutation`. Auth: `viewer` (own) / `admin` (others).

**`DELETE /api/layouts/:id`** — Delete layout. Rate: `mutation`. Auth: `viewer` (own) / `admin` (others).

---

### 4.11 Workload Signals

**`GET /api/workload`** — Fleet workload signal. Rate: `read`. Auth: `viewer`.

```json
// Response 200
{
  "data": {
    "signal": "normal",
    "factors": { "fleetBusyRatio": 0.65, "queueDepth": 3, "errorRate": 0.02 },
    "thresholds": {
      "throttle": { "busyRatio": 0.85, "queueDepth": 10, "errorRate": 0.10 },
      "shed": { "busyRatio": 0.95, "queueDepth": 25, "errorRate": 0.25 },
      "pause": { "busyRatio": 1.0, "queueDepth": 50, "errorRate": 0.50 }
    }
  }
}
```

**Signal semantics:**

| Signal | Meaning | Client Behavior |
|--------|---------|----------------|
| `normal` | Fleet healthy | Full SSE delivery, no throttling |
| `throttle` | Approaching capacity | Reduce non-essential polling, batch UI updates |
| `shed` | At capacity | Defer layout saves, reduce metrics queries |
| `pause` | Overloaded | Show fleet health warning, minimal API calls |

---

## 5. SSE Event Stream

### `GET /api/events`

The primary real-time channel between the API layer and The Glass. All agent activity, build state changes, and system events flow through this single multiplexed stream. Rate: `read` (on connection). Auth: `viewer`.

### Why SSE, Not WebSocket

SSE handles everything The Glass needs for observation: one-directional server-to-client push. WebSocket's bidirectionality is only needed for terminal I/O (section 6). SSE provides automatic reconnection, `Last-Event-ID` for resumption, and works through HTTP proxies without upgrade negotiation.

### AG-UI Adapter

Internal Hive events travel through The Airway (Valkey Streams). The AG-UI adapter sits at the API boundary and translates Hive-native events into the AG-UI protocol format. Internal systems never speak AG-UI — it is an external-only wire format.

```
The Airway (Valkey Streams)       AG-UI Adapter            SSE Endpoint
───────────────────────       ──────────────────       ──────────────
  tool_end event          →    TOOL_CALL_END         →   SSE data: {...}
  session_start event     →    RUN_STARTED           →   SSE data: {...}
  task_completed event    →    STATE_DELTA            →   SSE data: {...}
  quality_gate event      →    RUN_FINISHED           →   SSE data: {...}
```

### Extended Event Envelope

AG-UI events carry multi-agent routing fields so a single SSE stream serves the entire fleet. The Glass routes events to the correct UI block using these fields.

```typescript
interface HiveEventEnvelope {
  // Standard AG-UI fields
  type: AgUiEventType;
  timestamp: string;

  // Hive multi-agent extensions
  agentId: string;             // which Worker emitted this
  agentRole: string;           // Caste of the Worker
  buildId: string;             // which build this belongs to
  phaseId: number;             // current build phase
  sequenceNum: number;         // monotonically increasing per-agent

  // Payload
  data: Record<string, unknown>;
}
```

### Event Types

| AG-UI Type | Hive Source | Payload |
|------------|-----------|---------|
| `RUN_STARTED` | `session_start` | Agent ID, role, model, runtime |
| `RUN_FINISHED` | `session_end` | Exit code, outcome (`complete` / `interrupt` / `error`) |
| `TEXT_MESSAGE_START` | Agent output begins | Message ID, role |
| `TEXT_MESSAGE_CONTENT` | Agent streaming | Content delta (text chunk) |
| `TEXT_MESSAGE_END` | Agent output complete | Final content |
| `TOOL_CALL_START` | `tool_start` | Tool name, arguments summary |
| `TOOL_CALL_END` | `tool_end` | Tool name, duration, success |
| `STATE_SNAPSHOT` | Periodic / reconnect | Full orchestrator state (see section 4.6) |
| `STATE_DELTA` | State change | Partial update: status change, Cell completion |
| `CUSTOM` | Platform events | Approval created, merge result, cost threshold |

### Reconnection Protocol

1. Client sends `Last-Event-ID: <sequenceNum>` header on reconnect
2. Server replays missed events from buffer (default 10,000 events)
3. If the requested sequence is outside the buffer, server sends a full `STATE_SNAPSHOT` first
4. Server always sends a `STATE_SNAPSHOT` within 5 seconds of any connection

### Wire Format

```
id: 42
event: TOOL_CALL_END
data: {"type":"TOOL_CALL_END","agentId":"agent_w01","agentRole":"backend-builder","buildId":"build_abc123","phaseId":3,"sequenceNum":42,"data":{"tool":"Edit","durationMs":1200,"success":true}}

```

### Client-Side Batching

The Glass batches incoming SSE events on a 50ms timer before triggering React re-renders. Without batching, rapid tool calls cause render thrashing.

---

## 6. WebSocket Terminal

### `WS /api/terminal/:agentId`

The only WebSocket endpoint in the API. Provides bidirectional PTY I/O between The Glass and a Worker's terminal session, rendered via xterm.js. Auth: session cookie or `X-Agent-Key` header. Minimum role: `viewer`.

### Why WebSocket Here

Terminal I/O is inherently bidirectional — the user types, the terminal responds. SSE cannot carry upstream data. This is the single use case that requires WebSocket.

### Message Protocol

| Direction | Frame Type | Content |
|-----------|-----------|---------|
| Server to Client | Binary | PTY stdout/stderr bytes |
| Client to Server | Binary | Keyboard input bytes |
| Server to Client | Text | JSON control messages |

### Control Messages

```json
{ "type": "connected", "agentId": "agent_w01", "bufferLines": 5000 }
{ "type": "resize", "cols": 120, "rows": 40 }
{ "type": "disconnected", "reason": "agent_terminated" }
{ "type": "error", "message": "Agent not found or not running" }
```

### Terminal Buffer

Each Worker maintains a ring buffer of recent output (default 10,000 stdout lines, 5,000 stderr lines). On WebSocket connection, the server replays the buffer so the user sees recent history. The buffer persists across WebSocket disconnects — reconnection is seamless.

---

## 7. Error Envelope

### Standard Response Format

Every API response uses the same envelope. Clients never need to guess the response shape.

```typescript
interface ApiResponse<T> {
  data: T | null;              // non-null on 2xx, null on 4xx/5xx
  meta: {
    requestId: string;         // UUID, always present
    timestamp: string;         // ISO 8601 UTC
  };
  errors: ApiError[];          // empty on 2xx, non-empty on 4xx/5xx
}

interface ApiError {
  code: string;
  message: string;
  field?: string;              // validation errors
  detail?: unknown;            // context (redacted in prod for 500s)
}
```

### Error Codes

| HTTP Status | Code | Meaning |
|------------|------|---------|
| 400 | `VALIDATION_ERROR` | Request body failed JSON Schema validation |
| 401 | `UNAUTHENTICATED` | Missing or invalid credentials |
| 403 | `FORBIDDEN` | Valid credentials, insufficient role |
| 404 | `NOT_FOUND` | Resource does not exist |
| 409 | `CONFLICT` | State conflict (e.g., pausing an already-paused build) |
| 422 | `UNPROCESSABLE` | Valid JSON, semantically invalid (e.g., nonexistent Cell reference) |
| 429 | `RATE_LIMITED` | Budget exceeded |
| 500 | `INTERNAL_ERROR` | Unhandled server error |
| 503 | `OVERLOADED` | Fleet in `shed` or `pause` workload state |

### Validation Error Example

```json
{
  "data": null,
  "meta": { "requestId": "req_ghi789", "timestamp": "2026-03-20T14:30:00.000Z" },
  "errors": [
    { "code": "VALIDATION_ERROR", "message": "Validation failed", "field": "options.maxAgents", "detail": "Must be between 1 and 30" },
    { "code": "VALIDATION_ERROR", "message": "Validation failed", "field": "formulaPath", "detail": "Required" }
  ]
}
```

---

## 8. API Versioning

### Version Prefix

All endpoints use `/api/v1/` as the canonical path. The short form `/api/builds` aliases to `/api/v1/builds`.

### Breaking Change Policy

A new version is created when response fields are removed/renamed, required request fields are added, or response semantics change. A new version is NOT created for additive changes (new fields, new endpoints, rate limit changes).

When `v2` is introduced, `v1` remains available for 6 months minimum with deprecation headers:

```
Sunset: Sat, 20 Sep 2026 00:00:00 GMT
Deprecation: true
Link: </api/v2/builds>; rel="successor-version"
```

---

## 9. Relationship to The Smoker (CLI)

### Shared Service Layer

The CLI and API both call the same service functions. Neither wraps the other.

```
platform build start auth-module.toml
  → CLI parser → buildService.create(opts) → CLI formatter

POST /api/builds { formulaPath: "auth-module.toml" }
  → Fastify handler → buildService.create(opts) → JSON envelope
```

### Command Parity

| CLI Command | API Endpoint | Service Function |
|------------|-------------|-----------------|
| `platform build start` | `POST /api/builds` | `buildService.create()` |
| `platform build pause` | `POST /api/builds/:id/pause` | `buildService.pause()` |
| `platform build resume` | `POST /api/builds/:id/resume` | `buildService.resume()` |
| `platform build cancel` | `POST /api/builds/:id/cancel` | `buildService.cancel()` |
| `platform fleet status` | `GET /api/state` | `stateService.snapshot()` |
| `platform fleet list` | `GET /api/agents` | `agentService.list()` |
| `platform inspect <id>` | `GET /api/agents/:id` | `agentService.get()` |
| `platform kill <id>` | `POST /api/agents/:id/kill` | `agentService.kill()` |
| `platform work list` | `GET /api/work` | `workService.list()` |
| `platform work create` | `POST /api/work` | `workService.create()` |
| `platform qa approve` | `POST /api/approvals/:id/decide` | `approvalService.decide()` |
| `platform metrics` | `GET /api/metrics` | `metricsService.snapshot()` |
| `platform costs` | `GET /api/metrics/cost` | `metricsService.costReport()` |

### What the API Adds Beyond CLI

- **SSE event stream** — CLI uses `platform events --follow` (polling); API provides push delivery
- **WebSocket terminal** — CLI uses `platform attach <id>` (tmux); API provides PTY over WebSocket
- **Layout persistence** — Dashboard-specific, no CLI equivalent
- **Workload signals** — CLI has `platform health`; API returns structured signals for client throttling

---

## 10. Endpoint Summary

| Method | Path | Role | Rate Tier |
|--------|------|------|-----------|
| POST | `/api/auth/login` | none | login |
| POST | `/api/auth/logout` | viewer | mutation |
| GET | `/api/auth/me` | viewer | read |
| POST | `/api/builds` | operator | mutation |
| GET | `/api/builds/:id` | viewer | read |
| POST | `/api/builds/:id/pause` | operator | mutation |
| POST | `/api/builds/:id/resume` | operator | mutation |
| POST | `/api/builds/:id/cancel` | operator | mutation |
| GET | `/api/agents` | viewer | read |
| GET | `/api/agents/:id` | viewer | read |
| POST | `/api/agents/:id/kill` | admin | mutation |
| GET | `/api/approvals` | viewer | read |
| POST | `/api/approvals/:id/decide` | operator | mutation |
| GET | `/api/work` | viewer | read |
| POST | `/api/work` | operator | mutation |
| GET | `/api/work/:id` | viewer | read |
| PATCH | `/api/work/:id` | operator | mutation |
| GET | `/api/state` | viewer | heavy |
| GET | `/api/files/:agentId` | viewer | read |
| GET | `/api/files/:agentId/:path` | viewer | read |
| GET | `/api/contracts` | viewer | read |
| GET | `/api/contracts/:id/compliance` | viewer | heavy |
| GET | `/api/metrics` | viewer | heavy |
| GET | `/api/metrics/cost` | viewer | read |
| GET | `/api/layouts` | viewer | read |
| POST | `/api/layouts` | viewer | mutation |
| PUT | `/api/layouts/:id` | viewer/admin | mutation |
| DELETE | `/api/layouts/:id` | viewer/admin | mutation |
| GET | `/api/workload` | viewer | read |
| GET | `/api/events` | viewer | read |
| WS | `/api/terminal/:agentId` | viewer | — |

**31 API surfaces:** 27 REST + 1 SSE stream + 1 WebSocket + 2 auth endpoints.

---

## 11. Cross-References

| Document | Relationship |
|----------|-------------|
| **03 — System Architecture** | API is an access surface, not a new layer. Sits between Layer 5 (Runtime) and external consumers. |
| **09 — Orchestration Engine** | Build endpoints map to coordinator loop. Approval interrupt extends QA gate as async HTTP protocol. |
| **10 — Quality Intelligence** | Approval flow exposes QA decisions as async HTTP, replacing synchronous `platform qa gate`. |
| **12 — Work Tracker** | Cell endpoints expose Dolt-backed work graph. Atomic claim (5-attempt retry) lives in shared service layer. |
| **13 — Observability** | SSE stream is push-delivery counterpart to `events.db` pull queries. Events flow through The Airway to AG-UI adapter. |
| **15 — Contract System** | Contract endpoints expose compliance data. File ownership registry materializes static map as live dataset. |
| **16 — Build Program** | API layer is Phase 6 deliverable. HTTP skeleton in Phase 2, SSE + auth functional by Phase 3. |

---

*This specification defines the API surface for The Hive platform. It is a view and control layer — the real work happens in The Comb, The Airway, and the service layer that both The Smoker and the API share.*
