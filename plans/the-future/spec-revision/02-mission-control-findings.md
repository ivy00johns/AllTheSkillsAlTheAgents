# 02 — Mission Control Findings: What The Hive Should Steal, Adapt, and Surpass

**Source:** Mission Control v1.3.0 (builderz-labs) — 13-document technical deep dive
**Analyzed:** 2026-03-20
**Cross-referenced against:** The Hive platform spec (docs 01-17), Agentic UI Dashboard spec

---

## Context and Scope

Mission Control is a production-deployed, MIT-licensed agent orchestration dashboard with 2,700+ GitHub stars, 83 API routes, 31 tables, and 460+ tests built in 15 days. It represents the most feature-complete open-source agent dashboard available as of early 2026.

The Hive spec (docs 01-17) is a clean-sheet backend platform — CLI-driven, Dolt-backed, TypeScript/Bun — with no web dashboard specified. The Agentic UI Dashboard spec (plans/the-future/agentic-ui-dashboard/) is the companion dashboard spec — Tauri v2, React 19, AG-UI protocol.

This analysis extracts everything Mission Control has proven works at production scale and maps it to The Hive's architecture, identifying specific spec updates, new sections needed, and conflicts to resolve.

---

## Section 1: Top 10 Patterns to Steal (Ranked by Impact)

### 1. The `requireRole()` Discriminated Union (Impact: Critical)

**Source:** MC doc 12, `src/lib/auth.ts`

The pattern: a single function that returns either `{ user: User }` or `{ error: string; status: 401 | 403 }`. TypeScript narrows `auth.user` to `User` (non-undefined) after the guard check. Zero type assertions. Multi-principal support (session cookie, agent API key, system API key) is transparent to callers. Role hierarchy is numeric integers, not string comparison.

MC has run this against 83 API routes. Zero auth bypass bugs reported.

**Hive relevance:** The Hive's API surface (Phase 6 dashboard, spec doc 16) will need this exact pattern. The current spec (docs 09, 13, 15) discusses auth in terms of `workspace_id` scoping and agent identity but has no concrete API guard pattern. The discriminated union approach is the right primitive.

**Adaptation:** Extend role hierarchy to include `agent < operator < admin < fleet_admin`. Add scope-based permissions alongside roles (MC already starts this with `auth_scopes`). Apply as middleware in the Hive's future REST API layer rather than per-route boilerplate.

---

### 2. Dual-Channel Real-Time Architecture: SSE for DB Mutations + WebSocket for Agent Events (Impact: Critical)

**Source:** MC docs 07, 02, `src/lib/event-bus.ts`, `src/lib/use-server-events.ts`, `src/lib/websocket.ts`

The pattern: two independent real-time channels with separate failure domains. SSE (`/api/events`) delivers local database mutations to the browser — task CRUD, agent status changes, chat messages. WebSocket connects to the agent gateway for live session events — logs, spawn results, cron status. Both feed into a single Zustand store.

The server-side event bus is a singleton `EventEmitter` stored on `globalThis` to survive Next.js HMR. All mutations call `eventBus.broadcast(type, data)`. SSE forwarding and webhook dispatch both subscribe to the same bus. Adding a new consumer is one `eventBus.on()` call.

The `useSmartPoll` hook provides the resilience layer: visibility-aware, connection-aware polling that pauses when SSE is active and resumes when it drops. It always fires an initial fetch on mount (SSE delivers deltas, not initial state).

**Hive relevance:** The Agentic UI Dashboard spec uses SSE via the AG-UI adapter. The Hive platform spec (doc 13, Observability) defines four SQLite databases (mail, sessions, events, metrics) but has no browser push mechanism. MC proves the SSE + EventEmitter pattern works at production scale for agent dashboards.

**Adaptation:** The Hive's `events.db` (spec doc 13) should feed an SSE endpoint. The globalThis singleton trick is essential for dev-mode stability. The three-channel hierarchy (SSE primary, WebSocket for gateway, polling as fallback) should be adopted verbatim in the Agentic UI Dashboard spec.

---

### 3. Database-Backed Webhook Retry with Circuit Breaker (Impact: High)

**Source:** MC docs 10, 12, `src/lib/webhooks.ts`

The pattern: a `webhook_deliveries` table tracks every delivery attempt with `next_retry_at`, `attempt`, `is_retry`, `parent_delivery_id`. A scheduler runs `processWebhookRetries()` every 60 seconds, picking deliveries where `next_retry_at <= now`. The critical detail: `next_retry_at` is cleared *before* re-delivery to prevent double-processing. Retry schedule: `[30s, 5m, 30m, 2h, 8h]` with ±20% jitter. Circuit breaker: `consecutive_failures >= MAX_RETRIES` sets `enabled = 0`. Reset is manual via `PUT /api/webhooks { reset_circuit: true }`.

**Hive relevance:** The Hive spec (doc 09, Orchestration) has a circuit breaker for agent calls but it's described at the concept level. Doc 16 (Build Program) doesn't include webhook/integration delivery infrastructure. The Hive needs outbound event delivery for external integrations, and this pattern is production-proven.

**Adaptation:** Generalize beyond webhooks. The Hive should use this circuit breaker pattern for ALL external integrations: LLM provider failures, tool call failures, agent heartbeat failures. Add half-open state with probe requests for automatic recovery (MC only has open/closed).

---

### 4. Workspace Isolation Designed-In from Day One (Impact: High)

**Source:** MC docs 03, 05, all API routes

The lesson: MC retrofitted `workspace_id` across 31 tables in three migration phases (021, 022, 023). Every query in every route had to be updated.

**Hive relevance:** The Hive spec (doc 12, Work Tracker) uses a two-tier database architecture (fleet-level and project-level). This IS the right isolation model. But the spec should explicitly state that all project-level tables include `workspace_id` from migration 001, not as an afterthought.

---

### 5. Priority-Based Task Queue with Atomic Pickup (Impact: High)

**Source:** MC docs 09, 04, `src/app/api/tasks/queue/route.ts`

The pattern: `GET /api/tasks/queue?agent=name` runs a 5-attempt atomic pickup loop. Step 1: check if agent has an existing in-progress task (return it). Step 2: check max_capacity. Step 3: SELECT candidate ordered by priority. Step 4: UPDATE WHERE status IN ('inbox', 'assigned') AND (assignee IS NULL OR assignee = agent). If 0 rows changed, another agent grabbed it — retry.

**Hive relevance:** The Hive spec (doc 12, Work Tracker §5) has the ready queue algorithm as a SQL CTE and atomic claim via compare-and-swap. MC's queue is conceptually identical but battle-tested. The 5-attempt retry loop is the specific detail the Hive spec should incorporate verbatim.

---

### 6. Structured Logging with Pino (Impact: High)

**Source:** MC docs 11, 12, `src/lib/logger.ts`

The pattern: a `createLogger(module)` factory that produces a pino child logger. Dev mode detects `pino-pretty` availability at runtime. Production always outputs JSON.

**Adaptation:** Adopt Pino directly. Add correlation IDs (missing in MC) — every log entry should include `traceId`, `agentId`, `taskId`.

---

### 7. Aegis Quality Gate as a Database Query (Impact: High)

**Source:** MC docs 09, 10, `src/lib/validation.ts`

The pattern: `hasAegisApproval()` is a single SELECT. Moving a task to `done` without a matching approved review returns HTTP 403. The gate is checked at the point of transition, not as middleware.

**Adaptation:** The Hive's QA gate should be a direct Dolt query. CRITICAL findings always block. Security score < 3 always blocks.

---

### 8. Ed25519 Device Identity with localStorage Persistence (Impact: Medium-High)

**Source:** MC docs 05, 07, 12, `src/lib/device-identity.ts`

The pattern: `getOrCreateDeviceIdentity()` uses Web Crypto API (Ed25519, no npm deps) to generate a key pair. Device ID = SHA-256 of raw public key. Keys stored as base64url in localStorage. Challenge-response for WebSocket handshake.

**Adaptation:** Adopt verbatim for the Agentic UI Dashboard. Extend to CLI agents — each agent instance should generate an Ed25519 key pair stored in `~/.platform/agent-identity/`.

---

### 9. useSmartPoll — Visibility-Aware, Connection-Aware Polling (Impact: Medium)

**Source:** MC docs 06, 07, 12, `src/lib/use-smart-poll.ts`

The pattern: polling that pauses when the browser tab is hidden (Page Visibility API), fires immediately when tab becomes visible, optionally pauses when SSE or WebSocket is active.

---

### 10. JSONL Session Transcript Scanning (Impact: Medium)

**Source:** MC docs 10, 12, `src/lib/claude-sessions.ts`

The pattern: scan `~/.claude/projects/` for JSONL session files. Parse line-by-line, skip invalid lines. Extract: sessionId, model, git branch, message counts, tool uses, token counts, cost estimate.

**Adaptation:** Extend to multiple agent runtimes beyond Claude Code. Add file watchers instead of 60-second polling.

---

## Section 2: Spec Sections That Need Updating

### Spec Doc 05 — Data Model: Add Task Outcome Tracking Fields

**Recommended update:** Add to `work_items` schema:
- `outcome` (enum: success/failed/partial/abandoned, nullable)
- `error_summary` (TEXT, nullable, max 5000)
- `resolution_notes` (TEXT, nullable, max 5000)
- `feedback_rating` (INT, 1-5, nullable)
- `retry_count` (INT, default 0)
- `completed_at` (TIMESTAMP, nullable, set atomically on terminal state transition)

### Spec Doc 09 — Orchestration Engine: Add Workload Signal API

**Recommended update:** Add a Workload Signals section. `GET /api/workload` returns `normal | throttle | shed | pause` based on fleet busy ratio, queue depth, and error rate.

### Spec Doc 09 — Orchestration Engine: Formalize Agent Stale Detection

**Recommended update:** Add heartbeat timeout mechanism. `runHeartbeatCheck()` runs every 5 minutes. Agents not seen for `agent_timeout_minutes` (default 10) marked offline.

### Spec Doc 10 — Quality Intelligence: Add Regression Detection Metrics

**Recommended update:** Add regression detection computing p50/p95 latency and intervention rate across baseline vs. post windows.

### Spec Doc 12 — Work Tracker: Formalize the Atomic Claim Pattern

**Recommended update:** Add the 5-attempt retry loop to the atomic claim section. Without it, concurrent agents will fail to claim tasks under contention.

### Spec Doc 13 — Observability: Add Per-Model, Per-Task Token Cost Attribution

**Recommended update:** Add `task_id` to `metrics.db` token_usage schema. Add cache-aware pricing: cache reads = 10% of input cost, cache creation = 125%.

### Spec Doc 13 — Observability: Specify Data Retention Policy

**Recommended update:** Configurable retention with defaults: activities 90 days, audit log 365 days, logs 30 days, notifications 60 days, token usage 90 days.

### Spec Doc 15 — Contract System: Add API Rate Limiting by Role

**Recommended update:** Four-tier rate limiter: login (5/min, critical/undisableable), mutation (60/min), heavy (10/min), read (120/min).

### Spec Doc 16 — Build Program: Add a Dashboard Phase

**Recommended update:** Add Phase 7 (or 6b) for the Web Dashboard. Reference the agentic-ui-dashboard spec. Deliverables: SSE event endpoint, REST API, auth system, real-time state management, panel routing.

---

## Section 3: New Spec Sections That Should Be Created

### New: Spec Doc 18 — API Surface Specification

- API route template (rate-limit → auth → validate → body → logic → events → response)
- Error envelope standardization: `{ data, meta, errors }`
- Auth model: session cookie, agent API key, system API key — three principals
- RBAC: viewer/operator/admin/fleet_admin hierarchy
- Rate limiting tiers
- OpenAPI 3.1 spec for all endpoints
- Workspace scoping enforcement
- SSE event catalog with payload schemas

### New: Spec Doc 19 — Dashboard API Contract

- SSE event catalog (16+ typed event channels)
- WebSocket protocol for agent gateway communication
- Panel data contracts
- Real-time update contracts
- Auth handshake contract: Ed25519 device identity → device token
- Smart polling configuration per panel

### New: Spec Doc 20 — Security Hardening Checklist

- scrypt password hashing (N=16384, 16-byte salt)
- Session tokens: 32 random bytes, 7-day TTL
- `sameSite: 'strict'` cookies + CSRF origin-vs-host check
- Constant-time comparison everywhere secrets are compared
- Two-person rule for destructive infrastructure operations
- Audit log requirements
- Security headers
- Host allowlist pattern
- Admin seeding with insecure-default detection
- Per-agent API keys with SHA-256 hashed storage

### New: Appendix — Event Catalog

All typed event channels with payload schemas, consumer mapping (SSE, webhooks, or both).

---

## Section 4: Architecture Decisions That Conflict with Current Spec

### Conflict 1: SQLite as Event Bus vs. Dolt/SQLite as Work State

**Recommendation:** Keep three distinct event channels:
1. **Inter-agent mail:** `mail.db` (SQLite WAL) — already in doc 06
2. **Browser push:** SSE EventSource backed by EventEmitter singleton — adopt MC's pattern
3. **External webhooks:** Database-backed delivery queue — adopt MC's webhook retry pattern

### Conflict 2: Hook-Driven Orchestrator vs. SSE/REST Push Architecture

**Recommendation:** No conflict. These are two different surfaces:
- Internal orchestration: hook-driven via mail.db — keep as specified
- Dashboard API: REST endpoints for the UI — adopt MC's patterns

### Conflict 3: Single-Wide Work Item Table vs. MC's Multi-Table Schema

**Recommendation:** Keep the Hive's single-wide-table design. Borrow MC's secondary tables as satellite tables: `quality_reviews`, `comments`, `audit_log`, `notifications`.

### Conflict 4: Stateless CLI Spec vs. Stateful Dashboard Requirements

**Recommendation:** Add `platform serve --port 3000` as a new CLI command that starts the HTTP server (Phase 6/7 deliverable).

---

## Summary Tables

### Spec Update Priority

| Priority | Document | Update |
|----------|----------|--------|
| P0 | Doc 05 — Data Model | Add outcome tracking fields |
| P0 | Doc 12 — Work Tracker | Add 5-attempt retry loop to atomic claim |
| P0 | Doc 13 — Observability | Add task_id to token_usage |
| P0 | Doc 16 — Build Program | Add dashboard server phase |
| P1 | Doc 09 — Orchestration | Add stale detection, workload signals |
| P1 | Doc 10 — Quality | Add regression detection |
| P1 | Doc 13 — Observability | Add data retention policy |
| P2 | Doc 15 — Contract System | Add rate limiting contract |

### New Spec Documents Needed

| Priority | Document | Purpose |
|----------|----------|---------|
| P0 | Doc 18 — API Surface | REST endpoints, auth model, rate limiting, error envelopes |
| P1 | Doc 19 — Dashboard API Contract | SSE events, WebSocket protocol, panel data contracts |
| P2 | Doc 20 — Security Hardening | Auth, CSRF, headers, audit, API keys |
| P3 | Appendix: Event Catalog | Typed event channels with payload schemas |

---

*Analysis based on Mission Control v1.3.0 (builderz-labs). Generated 2026-03-20.*
