# UI Dashboard Findings — Gap Analysis Against Platform Spec (Docs 01-17)

**Version:** 0.1.0
**Date:** 2026-03-20
**Status:** Draft
**Author:** Code analysis agent — synthesis of 12 dashboard docs, 4 reference guides, 2 research docs, 3 JSX mockups, and 17 platform spec documents
**Scope:** Identify what the current 17-document platform specification is missing to support the Agentic UI Dashboard plan

---

## 1. Executive Summary

The Agentic UI Dashboard plan introduces a parallel system — a Tauri v2 + React desktop application — that acts as the visual control plane for The Hive platform. The dashboard plan is architecturally complete and internally consistent. The platform spec (docs 01-17) is not.

The core problem: the platform spec describes a CLI-first, SQLite/Dolt-backed orchestration engine. It assumes all observation happens through `platform dashboard` (a TUI in Phase 6) and `platform events` CLI commands. The dashboard plan assumes a fully instrumented, real-time streaming orchestration layer with a formal event protocol (AG-UI), REST control endpoints, WebSocket terminal I/O, SSE event buses, and structured approval flows. These two views of the system share almost no interface definitions.

**Five structural gaps:**

1. The spec has no API surface definition. The dashboard assumes dozens of REST endpoints and an SSE event stream that do not appear anywhere in docs 01-17.
2. The spec's event model (events.db) is CLI-queryable only. The dashboard requires a push-streaming event bus with AG-UI protocol normalization. These are different systems.
3. The spec describes QA gates as a CLI command (`platform qa gate`). The dashboard requires a bidirectional interrupt/resume protocol (AG-UI interrupt lifecycle). The mechanics are incompatible.
4. The spec has no persistence concept for UI state. The dashboard requires SQLite schemas for sessions, block state, and approval history that have no counterpart in docs 01-17.
5. The 7-phase build program (spec doc 16) does not include the dashboard. A complete build requires either an 8th spec document or a restructured Phase 6.

---

## 2. Tech Stack Alignment and Divergence

### 2.1 Where They Align

Both plans converge on TypeScript as the primary language for shared business logic, SQLite for local persistence, and git worktrees for agent isolation. The dashboard plan's Rust backend (Tokio async, rusqlite, axum SSE) is a new runtime but compatible with the spec's TypeScript/Bun stack — they are separate processes communicating via HTTP/IPC, not competing runtimes.

The dashboard's observability choices (Langfuse + OpenTelemetry) extend the spec's existing OTel integration point (spec doc 13, section 7) without contradicting it. The dashboard adds the frontend visualization layer on top of what the spec already says to emit via OTLP.

The dashboard's plugin architecture (8 swappable slots: Runtime, Agent, Workspace, Tracker, SCM, Notifier, Dashboard, Observability) maps reasonably onto the spec's runtime adapter pattern (doc 11), though the naming and interface signatures differ.

### 2.2 Where They Diverge

**Primary language for the process management layer.** The spec assumes TypeScript/Bun throughout. The dashboard plan introduces Rust (Tokio + axum) as the process manager and HTTP server. The spec's `AgentRuntime` interface (doc 11) assumes TypeScript implementations. The dashboard's `ProcessManager` struct is Rust. These need a protocol bridge or the spec needs to acknowledge a polyglot architecture.

**State management model.** The spec stores agent state in `sessions.db` (SQLite), queried via CLI commands. The dashboard requires the same state exposed as live SSE streams and REST endpoints. These are not the same interface — the spec has no concept of push delivery.

**Bun vs. Node.js ecosystem.** The spec's package.json scaffold (doc 17) uses Bun as the runtime. The dashboard plan's `package.json` (Phase 1) targets Vite + Node.js toolchain. Tauri's build pipeline is Cargo + vite — it does not support Bun as the JavaScript runtime inside the Tauri webview. This is a toolchain split that needs an explicit decision: Bun for backend CLI, Node.js/Vite for dashboard frontend.

**Dashboard shell technology absent from spec.** The spec mentions a TUI dashboard (`platform dashboard` command, Phase 6). The dashboard plan adds Tauri v2 as an entirely separate delivery target with its own Rust binary, IPC bridge, and SQLite database. The spec has no section describing how these two dashboard modes (TUI vs. Tauri) relate or share state.

---

## 3. New Subsystems Introduced by the Dashboard Plan

The following subsystems appear in the dashboard plan but have zero coverage in docs 01-17. Each requires a new spec section.

### 3.1 AG-UI Protocol Adapter

The dashboard plan defines a complete event protocol: 17 AG-UI event types extended with `agentId`, `agentRole`, `phaseId`, and `sequenceNum` fields for multi-agent routing. The adapter sits between the Rust event bus and the SSE endpoint, normalizing internal `ProcessEvent` values into AG-UI format.

The spec's event types (doc 13, table: tool_start, tool_end, session_start, etc.) are structurally different from AG-UI event types (RUN_STARTED, TEXT_MESSAGE_CONTENT, TOOL_CALL_START, STATE_SNAPSHOT, etc.). Both need to exist — the spec's events are for internal observability storage, AG-UI events are for frontend consumption. The relationship between them is a translation layer that the spec never describes.

**Required:** A new spec section (candidate: doc 18 or an addendum to doc 13) defining the AG-UI adapter: what maps to what, what the extended event envelope looks like, and how multi-agent routing works over a single SSE stream.

### 3.2 SSE Streaming Layer and Event Bus

The spec's observability model is pull-based: agents write to `events.db`; the CLI or watchdog reads from it. The dashboard requires push delivery: a Tokio broadcast channel that SSE subscribers receive events from in real-time.

The dashboard plan specifies this precisely (Phase 1, Phase 3): a Rust `tokio::broadcast` channel as the event bus, an axum SSE endpoint that subscribes to it, 50ms event batching on the client side, and a 5-second full-state snapshot for self-healing reconnection.

The spec has no push delivery architecture anywhere. The `EventStore` interface (doc 13) is entirely query-based. This is a new subsystem — a streaming event bus — that sits alongside `events.db`, not replacing it.

**Required:** A new spec section defining the streaming event bus: the Rust broadcast channel, axum SSE endpoint design, `Last-Event-ID` reconnection semantics, snapshot delivery on reconnect, and the relationship between push-delivered events and `events.db` (are they the same events? mirrored? one-way derived?).

### 3.3 REST Control API

The dashboard plan assumes a REST API for all control commands. The current spec has only CLI commands (`platform fleet spawn`, `platform sling`, `platform qa gate`). The dashboard calls REST endpoints directly from the frontend:

- `POST /api/builds` — start a build
- `POST /api/builds/:id/pause` — pause
- `POST /api/builds/:id/resume` — resume
- `POST /api/builds/:id/cancel` — cancel
- `POST /api/approval/:id/decide` — approve/reject a QA gate
- `POST /api/agents/:id/kill` — terminate an agent

None of these exist in the spec. The spec has CLI verbs but no HTTP surface. The dashboard plan requires HTTP because it runs in a Tauri webview, which cannot execute subprocess CLI commands directly.

**Required:** A new spec section (or addendum to doc 09 Orchestration Engine) defining the REST control API: endpoint list, request/response schemas, authentication (RBAC), and the relationship between REST calls and CLI commands (are they wrappers? generated from the same underlying functions?).

### 3.4 Approval Flows and Interrupt Lifecycle

The spec's QA gate (doc 10, doc 15) is defined as a CLI command: `platform qa gate qa-report.json` returns PASS/BLOCK. There is no protocol for pausing an agent, waiting for human input, and resuming it. The agent either passes the gate and continues or fails and stops.

The dashboard plan defines a complete interrupt lifecycle: the backend emits `RUN_FINISHED` with `outcome: "interrupt"`, the agent process is suspended (no new tasks dispatched), the approval appears in the dashboard queue, the human approves or rejects, and the backend resumes or terminates the agent. The `PendingApproval` struct, `ApprovalStatus` enum, and the `process_qa_gate()` Rust function are all defined in Phase 4 but have no counterpart in the spec.

This is architecturally significant: the spec treats QA gates as synchronous checks. The dashboard treats them as asynchronous state transitions that can pause execution for minutes or hours while a human reviews. These are different models, and the spec needs to choose one.

**Required:** An update to doc 10 (Quality Intelligence) and doc 09 (Orchestration Engine) describing the interrupt/resume protocol: how an agent pauses at a gate, what state is preserved, how the resume signal propagates, and how this interacts with the existing handoff/checkpoint system.

### 3.5 Block Registry and Layout Persistence

The dashboard introduces a typed block registry (Wave Terminal pattern) with 11 block types, independent Jotai atom state per block, SQLite-backed layout and state persistence, and a block lifecycle state machine (CREATED → ACTIVE → HIDDEN → DISPOSED).

This entire subsystem has no relationship to anything in the current spec. The spec's "dashboard" is a TUI command. The block registry is a React architectural pattern.

**Required:** A new spec section (candidate: doc 18 — UI Layer) defining the block registry contract, the SQLite schema for block persistence, and the relationship between block state and the spec's existing `sessions.db` and `events.db`.

### 3.6 Plugin Architecture (8 Slots)

The dashboard plan specifies a formal plugin architecture with 8 swappable slots, each with a TypeScript interface, a 5-stage lifecycle (Initialize → Validate → Activate → Deactivate → Dispose), and YAML-driven configuration resolution.

The spec's runtime adapter pattern (doc 11) covers similar ground for the Runtime slot but does not generalize to the other 7 slots (Agent, Workspace, Tracker, SCM, Notifier, Dashboard, Observability). The two systems have different interface signatures and different lifecycle models.

**Required:** Either (a) a unification document showing how the spec's `AgentRuntime` interface maps to the dashboard's `RuntimePlugin` interface, or (b) a new spec section defining the 8-slot plugin system as the authoritative extensibility model, superseding doc 11's adapter pattern.

### 3.7 Reactions System

The dashboard plan defines a YAML-declarative reactions engine: named event triggers (ci-failed, qa-gate-failed, contract-mismatch, changes-requested, approved-and-green), configurable actions (send-to-agent, fix-and-revalidate, notify-orchestrator, auto-merge), retry counts, and time-based escalation.

This is a new subsystem with no equivalent in the spec. The spec handles CI failures through the watchdog (doc 13, 3-tier watchdog) and the nudge system, but these are reactive to agent state, not declarative automation rules tied to external events.

**Required:** A new spec section defining the reactions system: trigger event types, action vocabulary, retry semantics, escalation paths, and how reactions integrate with the existing watchdog and nudge escalation model.

---

## 4. Data Requirements the Spec Doesn't Expose

### 4.1 Real-Time Agent State (not just historical events)

The dashboard's Zustand store requires a continuously-updated snapshot of the full agent fleet: each agent's current status, current step description, token usage, cost, progress percentage, and blocking dependency. The spec's `sessions.db` contains this data structurally but it is not exposed as a live queryable snapshot — it is a historical record.

The `StateSnapshotEvent` defined in the dashboard's AG-UI reference requires:

```typescript
interface OrchestratorStateSnapshot {
  buildId: string;
  buildPhase: number;
  buildStatus: string;
  agents: AgentState[];
  pendingApprovals: PendingApproval[];
  fileOwnershipMap: Record<string, string>;
  connectedClients: number;
  uptime: number;
}
```

The spec's `sessions.db` schema has most of the raw fields but no aggregation layer that produces this shape. The `context_usage_pct`, `last_tool_call`, `pid`, `tmux_session`, and `work_item_id` columns map onto the `AgentState` fields, but there is no API that assembles them into a typed snapshot on demand.

**Gap:** The spec needs a "fleet snapshot" query defined — the SQL or TypeScript that produces the `OrchestratorStateSnapshot` shape from `sessions.db` + `work_items` — and an endpoint that exposes it.

### 4.2 File Ownership Map as a Live Dataset

The dashboard's contract-compliance block and file-tree block need real-time awareness of which agent owns which files and which files are currently being modified. The spec defines file ownership conceptually (doc 15, contract system) as a static map derived from contract definitions, but does not specify how ownership is materialized at runtime as a queryable data structure.

**Gap:** Doc 15 (Contract System) needs a section defining the runtime ownership registry: what data structure holds the current `filePath → agentId` map, how it is updated as agents claim work, how it is exposed to the dashboard, and how violations are surfaced as events.

### 4.3 Per-Agent Terminal Buffer

The dashboard's xterm.js terminal blocks require access to the captured stdout/stderr buffer for each agent — both the live stream (via WebSocket) and the historical buffer (for reconnection). The spec's `sessions.db` does not store terminal output. The spec's `events.db` stores `tool_end` events with truncated result summaries, not raw terminal output.

The dashboard plan defines this precisely: `stdout_buffer: RingBuffer<OutputLine>` (10,000 lines) and `stderr_buffer: RingBuffer<OutputLine>` (5,000 lines) in the Rust `ManagedProcess` struct. But this is in-memory only — there is no persistence definition for terminal buffers.

**Gap:** The spec needs to define where terminal output is persisted (SQLite? file system? in-memory only?) and how the dashboard reconnects to a buffer after a network interruption or after the dashboard is relaunched.

### 4.4 Code Change Diffs

The diff-viewer block requires before/after file content for every file modified by each agent. The spec uses git worktrees for isolation (doc 09), meaning diffs are available via `git diff` against the base branch. But the dashboard needs this as structured data: `FileChange` objects with `agentId`, `filePath`, `changeType`, `additions`, `deletions`, and the actual content pairs for Monaco DiffEditor.

**Gap:** A new data endpoint is needed — either a REST API that wraps `git diff` for a given agent's worktree, or a structured event type in the SSE stream that delivers file change notifications when an agent writes a file.

### 4.5 QA Report Structured Data

The dashboard's approval-queue block renders the full `qa-report.json` payload: scores per dimension, blockers list, aegis evaluation results. The spec defines the `qa-report.json` schema (doc 10) but does not define how this report reaches the dashboard.

**Gap:** The spec needs an event type definition for QA report delivery to the frontend, and the orchestrator needs a defined trigger point for converting a file write into an approval interrupt.

---

## 5. API Surface the Dashboard Assumes (Not in Spec)

### 5.1 SSE Streams

| Endpoint | Purpose | Defined In (Dashboard) |
|----------|---------|----------------------|
| `GET /api/events` | Multiplexed AG-UI event stream for all agents | Phase 1, Phase 3 |

### 5.2 REST Control Endpoints

| Endpoint | Method | Purpose | Defined In |
|----------|--------|---------|-----------|
| `/api/builds` | POST | Start a new build | Phase 1 |
| `/api/builds/:id/pause` | POST | Pause running build | Phase 1 |
| `/api/builds/:id/resume` | POST | Resume paused build | Phase 1 |
| `/api/builds/:id/cancel` | POST | Cancel build | Phase 1 |
| `/api/approval/:id/decide` | POST | Submit approval decision | Phase 4 |
| `/api/agents/:id` | GET | Get single agent state | Phase 3 |
| `/api/agents/:id/kill` | POST | Terminate agent | Phase 3 |
| `/api/agents/:id/stdin` | POST | Send input to interactive agent | Phase 3 |
| `/api/state` | GET | Full orchestrator state snapshot | Phase 3 |
| `/api/files/:agentId` | GET | List files changed by agent | Phase 5 |
| `/api/files/:agentId/:path` | GET | Get file diff for a specific path | Phase 5 |
| `/api/contracts` | GET | List all active contracts | Phase 5 |
| `/api/contracts/:id/compliance` | GET | Compliance status for a contract | Phase 5 |
| `/api/metrics` | GET | Current metrics snapshot | Phase 8 |
| `/api/layouts` | GET/POST | Manage dashboard layouts | Phase 1 |
| `/api/layouts/:id` | PUT/DELETE | Update/delete layout | Phase 1 |

### 5.3 WebSocket Connections

| Endpoint | Purpose | Defined In |
|----------|---------|-----------|
| `WS /api/terminal/:agentId` | Bidirectional PTY I/O for xterm.js | Phase 3 |

### 5.4 Tauri IPC Commands

| Command | Purpose | Defined In |
|---------|---------|-----------|
| `get_system_info` | CPU, memory, disk stats | Phase 1 |
| `save_layout` / `load_layout` | Layout persistence to SQLite | Phase 1 |
| `get_build_status` | Current build state | Phase 1 |
| `start_build` / `pause_build` | Build control | Phase 1 |
| `list_block_types` | Available block types from registry | Phase 1 |

---

## 6. Build Program Changes Required

### 6.1 Dependency Map

| Dashboard Phase | Requires from Spec |
|-----------------|--------------------|
| Phase 1 (Foundation Shell) | events.db schema (doc 13), sessions.db schema (doc 13) |
| Phase 2 (Core Visualization) | Agent state machine (doc 04, doc 09) |
| Phase 3 (Agent Communication) | Spawn mechanism (doc 09 sling), runtime adapter interface (doc 11) |
| Phase 4 (Approval + QA Gates) | QA gate schema (doc 10), qa-report.json (doc 10) |
| Phase 5 (Code Review + Contracts) | Contract system (doc 15), file ownership map |
| Phase 6 (Observability) | OTel integration (doc 13), Langfuse config |
| Phase 7 (Extensibility) | Plugin/adapter interfaces (doc 11) |
| Phase 8 (Dashboard Polish) | RBAC model (not in spec), audit trail schema (doc 13) |

### 6.2 Proposed Build Program Changes

**Recommendation: Parallel Track (Option B)**

```
Spec Track:    P0 -> P1 -> P2 -> P3 -> P4 -> P5 -> P6
                              |
Dashboard Track:              P0 -> P1 -> P2 -> P3 -> P4 -> P5 -> P6 -> P7 -> P8
```

Dashboard track starts after spec Phase 2 completion (~week 6). The two tracks converge at spec P6 / dashboard P8 for full integration testing.

### 6.3 New Work Items for Existing Spec Phases

**Add to Phase 2 (Orchestration Core):**
- HTTP server skeleton (axum) alongside the tmux/CLI interface
- SSE event endpoint (even if it emits only heartbeats initially)
- REST endpoint stubs for build control commands

**Add to Phase 3 (Quality Layer):**
- AG-UI event adapter (translate internal events to AG-UI format)
- Approval interrupt protocol (agent suspension at QA gate, resume on decision)
- Structured approval state in SQLite

**Add to Phase 4 (Merge & Integration):**
- File change event emission
- File ownership registry materialization

**Add to Phase 6 (Federation & Scale):**
- Tauri application build pipeline (Cargo + vite)
- Dashboard integration testing
- RBAC implementation (Viewer/Operator/Admin)

---

## 7. Architecture Decisions That Need Resolution

### 7.1 Single Process vs. Two Processes

The spec runs as TypeScript/Bun. The dashboard introduces Rust/Tauri. Decision needed: Is the Rust process manager (a) a standalone wrapper, (b) a replacement for TypeScript process spawning, or (c) optional?

### 7.2 SQLite Ownership

Both maintain SQLite databases. Decision needed: Does the dashboard (a) read the spec's databases plus its own, (b) extend the spec's databases with UI tables, or (c) maintain its own synced copy?

### 7.3 AG-UI as Canonical Event Protocol

Decision needed: Is AG-UI the internal event language (requiring doc 13 rewrite) or an external-facing protocol only (requiring a translation layer)?

### 7.4 RBAC — Completely Absent from Spec

The dashboard implements RBAC with three roles. The spec has no access control concept. Decision needed: define the access control model for the HTTP API.

### 7.5 The Naming Mismatch

The spec uses Hive naming (Workers, Cells, Convoys). The dashboard uses generic terms. The JSX mockups use Hive names (The Yard, The Glass, The Comb). Needs alignment once doc 02 naming decision is finalized.

---

## 8. New Spec Sections Needed

### 8.1 New Document: 18 — API Layer Specification

Complete HTTP API definition: REST endpoints, SSE event stream, WebSocket terminal protocol, authentication, RBAC, versioning, OpenAPI contract, relationship between HTTP API and CLI commands.

### 8.2 New Document: 19 — UI Layer Specification

Dashboard architecture: block registry, Tauri v2 structure, UI persistence SQLite schema, AG-UI protocol adoption, Zustand store shape, Jotai atom patterns, Hive naming mapping, plugin slot definitions.

### 8.3 Updates Required to Existing Documents

| Document | Required Updates |
|----------|-----------------|
| **doc 09: Orchestration Engine** | Add interrupt/resume protocol. Add HTTP server as parallel output channel. Define sling + Rust ProcessManager integration. |
| **doc 10: Quality Intelligence** | Define approval interrupt lifecycle. Describe QA report delivery to dashboard. Add PendingApproval schema. |
| **doc 13: Observability** | Add push delivery alongside pull queries. Define AG-UI translation layer. Add pending_approvals table. Define terminal buffer spec. |
| **doc 15: Contract System** | Add runtime ownership registry. Define file change event format. Add contract compliance API. |
| **doc 16: Build Program** | Add dashboard parallel track. Add HTTP/SSE to Phase 2. Add approval interrupt to Phase 3. Add RBAC to Phase 6. |
| **doc 17: Repo Bootstrap** | Add dashboard directory to repo structure. Add Tauri toolchain. Add `src/http/` for REST API. |

---

## 9. Spec Gap Quick Reference

| Gap Category | Severity | Where It Blocks | Spec Section Needed |
|-------------|----------|----------------|---------------------|
| No HTTP API surface | Critical | Dashboard Phase 3 | New doc 18 |
| No SSE push delivery | Critical | Dashboard Phase 1-2 real data | Update doc 13 + new doc 18 |
| QA gate is synchronous only | Critical | Dashboard Phase 4 approval flow | Update doc 09, doc 10 |
| No runtime file ownership registry | High | Dashboard Phase 5 compliance block | Update doc 15 |
| No terminal buffer persistence spec | High | Dashboard xterm reconnection | Update doc 13 |
| No RBAC anywhere | High | Dashboard Phase 8 security | New doc 18 or doc 19 |
| AG-UI not in spec | High | Event protocol undefined | Update doc 13 |
| Dashboard not in build program | High | Build sequence for Phase 7+ | Update doc 16 |
| SQLite ownership model undefined | Medium | Two systems writing overlapping data | New doc 18 or 19 |
| Single vs. two process architecture | Medium | Integration architecture ambiguous | Update doc 03 |
| Plugin slots vs. runtime adapters | Medium | Two competing extension models | Update doc 11 or new doc 19 |
| Naming mismatch | Low | Block types vs Hive screens | Update doc 02 resolution |
| Reactions system absent | Low | YAML automation not spec'd | New doc 19 section |
