# 19 -- UI Layer (The Glass)

**Document type:** Frontend specification
**Status:** DRAFT
**Date:** 2026-03-20
**Scope:** The Glass -- The Hive's observation dashboard
**Prerequisite reading:** 18-api-layer, 13-observability, 09-orchestration-engine

---

## 1. Vision

### The Glass-Sided Observation Hive

A glass-sided observation hive is a real beekeeping tool. One wall is
transparent. The beekeeper watches the colony work without opening the hive,
without smoking the bees, without disturbing anything. The colony does not know
it is being observed.

The Glass is The Hive's observation dashboard -- a React single-page application
served by `platform serve` that provides real-time visibility into agent
orchestration builds. It bridges CLI agent output to web UIs at scale,
displaying 5-20+ simultaneous Workers with live DAG state on The Frame,
structured traces on The Trail, and human-in-the-loop approval flows through
The Keeper.

### What The Glass Is Not

The Glass is not the orchestration engine. The Queen runs whether The Glass is
open or not. The Glass is not the CLI. The Smoker remains the primary operator
interface for starting builds, dispatching Workers, and managing The Yard. The
Glass is a window -- it reads operational state, renders it visually, and
provides a focused set of control actions (pause, resume, cancel, approve,
reject). If The Glass crashes, the build continues. If The Glass is rebuilt from
scratch, no operational data is lost.

### The Gap It Fills

No existing open-source tool provides real-time animated DAG visualization with
progressive-disclosure drill-down into terminal output, structured traces, and
approval queues for multi-agent orchestration. Every existing project picks 1-2
of these capabilities. The Glass provides all of them in a unified view driven
by The Hive's native event system.

---

## 2. Technology Stack

### 2.1 Core Architecture Decision

The Glass is a React SPA served by The Hive's Fastify server via
`platform serve`. There is no Tauri shell, no Rust backend, no Electron wrapper.
TypeScript serves HTTP directly. The platform's existing Fastify services host
the built React assets as static files and provide the API endpoints The Glass
consumes.

This decision eliminates an entire runtime (Rust/Tauri), a build toolchain
(Cargo), and a process management layer. The Glass is a directory of static
assets and a set of API routes -- nothing more.

### 2.2 Version-Pinned Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| React | 19.x | UI framework |
| Vite | 6.x | Build tooling (dev server + production bundler) |
| Zustand | 5.x | Global application state |
| Jotai | 2.x | Per-block reactive state (atoms) |
| @xyflow/react | 12.10.x | DAG visualization (The Frame) |
| @xterm/xterm | 6.0.x | Terminal emulation (A Window) |
| @xterm/addon-webgl | 0.19.x | GPU-accelerated terminal rendering |
| @monaco-editor/react | 4.x | Diff viewing (The Code) |
| recharts | 3.x | Metrics charts (The Yield) |
| motion | 12.x | Animation (state transitions, layout shifts) |
| react-resizable-panels | 2.x | Panel layout management |
| sonner | 2.x | Toast notifications (The Signal) |

### 2.3 Critical Package Renames

Three packages that The Glass depends on have undergone major renames. The old
names still exist on npm, still appear in tutorials, still autocomplete in
editors. Developers WILL install the wrong package if not warned.

| Old Name (DO NOT USE) | New Name (USE THIS) | Breaking Since |
|-----------------------|---------------------|----------------|
| `xterm` | `@xterm/xterm` v6.0.0 | 2024 |
| `reactflow` | `@xyflow/react` v12.10.1 | 2024 |
| `framer-motion` | `motion` v12.38.0 | 2025 |

The old packages receive no updates. The new packages have incompatible APIs.
Using the old names will produce runtime errors or missing features with no
helpful error message. CI must lint `package.json` for these old names and fail
the build if found.

### 2.4 What Is NOT in the Stack

| Excluded | Reason |
|----------|--------|
| Tauri / Electron | `platform serve` hosts The Glass directly. No desktop shell. |
| Next.js / Remix | SPA only. No SSR needed -- all data arrives via SSE/REST. |
| React Router (URL routing) | URL routing causes component remounts that destroy WebSocket and SSE connections. Zustand-driven panel switching instead. |
| Redux / MobX | Zustand + Jotai is lighter, integrates with @xyflow/react natively, and matches Wave Terminal's proven architecture. |
| Socket.IO | Raw WebSocket for terminal PTY I/O. SSE for everything else. Socket.IO's abstraction layer adds overhead with no benefit. |

### 2.5 Why No URL Routing

This is a deliberate architectural constraint, not an oversight. The Glass
maintains long-lived connections: an SSE stream for events, WebSocket
connections for terminal I/O. URL-based routing (React Router, TanStack Router)
triggers full component tree unmounts on navigation. Each unmount tears down
connections. Each remount re-establishes them. For a dashboard monitoring 20
Workers with active terminals, this creates visible flicker, lost event
windows, and reconnection storms.

Instead, The Glass uses Zustand-driven panel visibility. All panels mount once
at application startup. Navigation toggles CSS visibility and z-index, not React
mount/unmount. Connections persist for the lifetime of the browser tab.

---

## 3. Block Registry Architecture

### 3.1 The Wave Terminal Pattern

The Glass adopts Wave Terminal's block registry pattern. A central registry maps
view type strings to a ViewModel class and a React ViewComponent. Adding a new
view type to The Glass requires registering one entry -- no changes to core
layout, routing, or state management code.

```
BlockRegistry
  ├── "yard-view"      → { ViewModel: YardViewModel,     Component: YardView }
  ├── "window"         → { ViewModel: WindowViewModel,   Component: WindowView }
  ├── "frame-view"     → { ViewModel: FrameViewModel,    Component: FrameView }
  ├── "keeper"         → { ViewModel: KeeperViewModel,   Component: KeeperView }
  ├── "trail"          → { ViewModel: TrailViewModel,     Component: TrailView }
  ├── "yield"          → { ViewModel: YieldViewModel,     Component: YieldView }
  ├── "code"           → { ViewModel: CodeViewModel,      Component: CodeView }
  ├── "comb"           → { ViewModel: CombViewModel,      Component: CombView }
  └── "signal"         → { ViewModel: SignalViewModel,    Component: SignalView }
```

### 3.2 Block Types

Each block maps to a Hive concept from the naming vocabulary:

| Block Type | Hive Name | Purpose | Primary Data Source |
|------------|-----------|---------|---------------------|
| `yard-view` | **The Yard View** | Fleet overview -- all Workers at a glance. Name, status, current Cell, progress. Layer 1 index. | `GET /api/state` + SSE state deltas |
| `window` | **A Window** | Single Worker terminal output via @xterm/xterm. Live PTY stream. | `WS /api/terminal/:agentId` |
| `frame-view` | **The Frame View** | DAG visualization of The Frame (task graph). Cells as nodes, dependencies as edges, animated state transitions. | Zustand store (cells, dependencies) |
| `keeper` | **The Keeper** | Approval queue for Inspection gates. QA reports with per-dimension scores, blocker lists, diff previews. Approve/reject buttons. | SSE approval events + `GET /api/approval` |
| `trail` | **The Trail** | Execution traces, structured log viewer. Hierarchical span tree per Worker. | SSE trace events + `GET /api/traces` |
| `yield` | **The Yield** | Cost and token metrics. Charts for token/sec, cost/Cell, cumulative spend, model breakdown. | `GET /api/metrics` + SSE metric events |
| `code` | **The Code** | Diff viewer for Worker code changes. Monaco DiffEditor showing before/after per file. | `GET /api/files/:agentId/:path` |
| `comb` | **The Comb** | Contract compliance and file ownership visualization. Which Worker owns which files, violation alerts. | `GET /api/contracts` + SSE ownership events |
| `signal` | **The Signal** | Notifications and alerts. Stings (critical), Signals (informational). Toast overlay + history panel. | SSE alert events |

### 3.3 Block Lifecycle

Every block instance follows a four-state lifecycle:

```
CREATED ──→ ACTIVE ──→ HIDDEN ──→ DISPOSED
   │            │          │
   │            └──────────┘  (toggle visibility)
   │                 │
   └─────────────────┘        (reactivate from hidden)
```

| State | Description | Connections | Rendering | Memory |
|-------|-------------|-------------|-----------|--------|
| CREATED | Block instantiated, ViewModel initialized, Jotai atom created | Not yet established | Not rendered | Minimal |
| ACTIVE | Visible in layout, receiving data, fully interactive | Active (SSE subscription, WebSocket if terminal) | Full render cycle | Full working set |
| HIDDEN | Not visible but preserving state. Connections downgraded. | SSE: continues receiving (buffered). WebSocket: paused. | No render (CSS `display: none`) | State preserved, render tree detached |
| DISPOSED | Block removed from layout. All resources released. | Closed | None | Freed. Jotai atom garbage collected. |

**Key behavior:** A HIDDEN block does not unmount its React component -- it
hides it via CSS. This preserves scroll position, terminal buffer, and internal
state without paying render cost. When the user navigates back, the block
transitions to ACTIVE instantly with no data refetch.

### 3.4 Block State Independence

Each block owns a Jotai atom for its local state. A state update in one block's
atom triggers re-renders only within that block's component subtree. The Yard
View updating its Worker list does not cause The Frame View to re-render its DAG
nodes.

This is the critical performance property that makes The Glass viable at scale.
Without per-block atom isolation, a single SSE event updating one Worker's
status would cascade re-renders through every visible block.

---

## 4. Streaming Architecture

### 4.1 Three Protocols, Three Use Cases

The Glass uses three communication protocols. Each is chosen for its specific
transport characteristics. There is no "one protocol to rule them all."

```
┌─────────────────────────────────────────────────────────────┐
│                     THE GLASS (Browser)                      │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐   │
│  │   SSE    │    │   REST   │    │   WebSocket (per     │   │
│  │ Client   │    │  Client  │    │   visible terminal)  │   │
│  └────┬─────┘    └────┬─────┘    └──────────┬───────────┘   │
│       │               │                     │               │
└───────│───────────────│─────────────────────│───────────────┘
        │               │                     │
   ┌────▼─────┐    ┌────▼─────┐    ┌──────────▼───────────┐
   │  GET      │    │  POST    │    │  WS /api/terminal/   │
   │  /api/    │    │  /api/*  │    │  :agentId            │
   │  events   │    │          │    │                      │
   └────┬─────┘    └────┬─────┘    └──────────┬───────────┘
        │               │                     │
   ┌────▼───────────────▼─────────────────────▼───────────┐
   │              FASTIFY SERVER (platform serve)          │
   │                                                       │
   │  ┌─────────────────────────────────────────────────┐  │
   │  │          AG-UI ADAPTER LAYER                     │  │
   │  │  Internal Hive Events → AG-UI 17 Event Types    │  │
   │  └──────────────────────┬──────────────────────────┘  │
   │                         │                             │
   │  ┌──────────────────────▼──────────────────────────┐  │
   │  │          THE AIRWAY (Valkey Streams)             │  │
   │  │  Internal event bus — all Hive events flow here  │  │
   │  └─────────────────────────────────────────────────┘  │
   └───────────────────────────────────────────────────────┘
```

### 4.2 SSE -- The Primary Data Channel

**Endpoint:** `GET /api/events`
**Direction:** Server to client (unidirectional)
**Purpose:** Agent logs, state updates, approval notifications, trace events,
metric updates, file ownership changes, alert notifications.

SSE is the backbone. The Glass opens a single SSE connection on startup and
receives all event types multiplexed over it. Each event carries an `agentId`
field for client-side demultiplexing to the correct block.

**Why SSE over WebSocket for this channel:**

- Auto-reconnect is built into the `EventSource` API. No custom reconnection
  logic.
- `Last-Event-ID` header on reconnect tells the server exactly where the client
  left off.
- HTTP/2 multiplexes SSE streams without consuming additional TCP connections.
- The data flow is unidirectional (server to client). WebSocket's bidirectional
  capability is wasted overhead.
- Every LLM API provider (OpenAI, Anthropic, Google) converged on SSE for
  streaming. The tooling ecosystem is mature.

**Event format:**

```
id: 1742486400000-0042
event: TEXT_MESSAGE_CONTENT
data: {"agentId":"worker-backend-01","content":"Implementing UserService...","sequenceNum":42}

id: 1742486400050-0043
event: STATE_DELTA
data: {"agentId":"worker-backend-01","status":"active","currentCell":"cell-auth-service","progress":0.65}
```

### 4.3 REST -- Control Commands

**Base path:** `/api/*`
**Direction:** Client to server (request/response)
**Purpose:** All control actions -- pause, resume, cancel builds; approve or
reject Inspection gates; terminate Workers.

Control commands are stateless REST calls. They do not need persistent
connections. They do not need streaming. They need request/response semantics
with clear success/failure status codes.

The full REST API surface is defined in doc 18 (API Layer). The Glass consumes
these endpoints:

| Endpoint | Method | The Glass Uses It For |
|----------|--------|----------------------|
| `/api/state` | GET | Initial state load on startup (before SSE takes over) |
| `/api/builds` | POST | Starting a new build from The Glass |
| `/api/builds/:id/pause` | POST | Pause button |
| `/api/builds/:id/resume` | POST | Resume button |
| `/api/builds/:id/cancel` | POST | Cancel button |
| `/api/approval/:id/decide` | POST | The Keeper approve/reject |
| `/api/agents/:id/kill` | POST | Terminate a stuck Worker |
| `/api/metrics` | GET | Initial metrics snapshot for The Yield |
| `/api/files/:agentId` | GET | File list for The Code |
| `/api/files/:agentId/:path` | GET | Diff content for The Code |
| `/api/contracts` | GET | Contract list for The Comb |
| `/api/contracts/:id/compliance` | GET | Compliance detail for The Comb |
| `/api/layouts` | GET/POST | Load/save Glass layouts |
| `/api/layouts/:id` | PUT/DELETE | Update/delete layouts |

### 4.4 WebSocket -- Terminal I/O Only

**Endpoint:** `WS /api/terminal/:agentId`
**Direction:** Bidirectional
**Purpose:** Interactive terminal sessions. @xterm/xterm requires bidirectional
PTY I/O -- keystrokes flow from browser to agent process, terminal output flows
back.

WebSocket is used exclusively for terminal blocks (A Window). No other block
type uses WebSocket. This constraint exists because WebSocket connections do not
auto-reconnect, do not support `Last-Event-ID` resumption, and consume dedicated
resources on both client and server.

**Connection lifecycle:**

1. User opens A Window block for a specific Worker
2. The Glass opens `WS /api/terminal/{agentId}`
3. Server attaches to the Worker's PTY (tmux session)
4. Bidirectional byte stream flows until the block is HIDDEN or DISPOSED
5. HIDDEN blocks pause the WebSocket (stop sending, buffer server-side)
6. DISPOSED blocks close the WebSocket

### 4.5 AG-UI Adapter

The AG-UI adapter sits at the SSE boundary inside the Fastify server. It
translates internal Hive events (from The Airway / Valkey Streams) into the
AG-UI protocol's 17 standardized event types.

**Why AG-UI is external-only:**

Internal Hive events carry platform-specific fields (Colony ID, Cell references,
Worker Caste, The Comb ownership maps) that have no AG-UI equivalent. Forcing
all internal communication through AG-UI would mean losing this information or
stuffing it into untyped extension fields. Instead, The Airway carries native
Hive events. The AG-UI adapter translates at the boundary for external consumers
-- The Glass, third-party dashboards, CI integrations.

**Event type mapping:**

| Internal Hive Event | AG-UI Event Type | Notes |
|---------------------|------------------|-------|
| `worker.started` | `RUN_STARTED` | Includes `agentId`, `agentRole`, `phaseId` |
| `worker.output` | `TEXT_MESSAGE_CONTENT` | Streaming text chunks |
| `worker.completed` | `RUN_FINISHED` | `outcome: "success"` |
| `worker.failed` | `RUN_FINISHED` | `outcome: "error"`, includes error details |
| `worker.gate_blocked` | `RUN_FINISHED` | `outcome: "interrupt"`, `reason: "quality_gate"` |
| `tool.start` | `TOOL_CALL_START` | Tool name, arguments |
| `tool.args` | `TOOL_CALL_ARGS` | Streaming argument chunks |
| `tool.result` | `TOOL_CALL_RESULT` | Tool output |
| `tool.end` | `TOOL_CALL_END` | Duration, success/failure |
| `state.snapshot` | `STATE_SNAPSHOT` | Full `OrchestratorState` |
| `state.delta` | `STATE_DELTA` | Partial state update |
| `qa.report` | `RAW` | Full `qa-report.json` payload |
| `worker.reasoning` | `REASONING_CONTENT` | Model thinking (when available) |
| `file.changed` | `CUSTOM` | File ownership and change events |
| `alert.fired` | `CUSTOM` | Sting/Signal notifications |

**Extended envelope fields** (added to every AG-UI event for multi-Worker
multiplexing):

```typescript
interface HiveEventEnvelope {
  // Standard AG-UI fields
  type: string;
  timestamp: string;
  rawEvent: unknown;

  // Hive extensions for multi-agent routing
  agentId: string;        // Which Worker
  agentRole: string;      // Worker's Caste (backend, frontend, qe, etc.)
  phaseId: number;        // Current build phase (1-14)
  sequenceNum: number;    // Monotonic sequence for ordering
  colonyId: string;       // Which Colony instance
}
```

### 4.6 Self-Healing Reconnection

When the SSE connection drops (network interruption, server restart, laptop
sleep/wake), The Glass reconnects automatically using the `EventSource` API's
built-in retry mechanism. On reconnect, it sends the `Last-Event-ID` header
with the sequence number of the last received event.

The server responds with a full `STATE_SNAPSHOT` event followed by any events
the client missed since its last sequence number. The snapshot is delivered
within 5 seconds of reconnection. The Glass replaces its Zustand store contents
with the snapshot, then applies subsequent deltas normally.

**Reconnection sequence:**

```
1. SSE connection drops
2. EventSource auto-retries (default: immediate, then backoff)
3. Reconnect request includes Last-Event-ID: "1742486400000-0042"
4. Server sends STATE_SNAPSHOT (full OrchestratorState)
5. Server replays missed events since sequence 0042
6. The Glass replaces Zustand store with snapshot
7. Normal delta processing resumes
```

If the gap between the client's last event and the server's current state
exceeds the replay buffer (configurable, default 10,000 events), the server
sends only the `STATE_SNAPSHOT` without replay. The Glass starts fresh from
current state.

---

## 5. State Management

### 5.1 Two-Layer State Architecture

The Glass uses two state management libraries at two different scopes:

**Zustand** -- Global application state. One store for the entire Glass
instance. Contains the orchestrator state snapshot, build metadata, connection
status, and UI navigation state.

**Jotai** -- Per-block local state. Each block instance creates its own Jotai
atoms for state that is private to that block: scroll position, filter settings,
selected items, terminal buffer position.

This separation exists for performance. Zustand's selector-based subscription
model (with `useShallow`) prevents unnecessary re-renders at the application
level. Jotai's atomic model prevents cross-block render cascades. Together, they
ensure that an SSE event updating Worker #7's status re-renders only the
components that display Worker #7's data.

### 5.2 Zustand Store Shape

```typescript
interface OrchestratorState {
  // Build state
  buildId: string | null;
  buildPhase: number;
  buildStatus: 'idle' | 'planning' | 'active' | 'paused' | 'completed' | 'failed';

  // Fleet state
  agents: AgentState[];
  pendingApprovals: PendingApproval[];

  // Ownership
  fileOwnershipMap: Record<string, string>;  // filePath → agentId

  // Connection
  connectedClients: number;
  uptime: number;
  sseConnected: boolean;
  lastEventId: string | null;
}

interface AgentState {
  agentId: string;
  role: string;            // Caste: backend, frontend, qe, etc.
  status: 'spawning' | 'active' | 'blocked' | 'idle' | 'completed' | 'failed' | 'capped';
  currentCell: string | null;
  currentStep: string;
  progress: number;        // 0.0 - 1.0
  tokenUsage: number;
  cost: number;
  lastActivity: string;    // ISO timestamp
  contextUsagePct: number;
}

interface PendingApproval {
  approvalId: string;
  agentId: string;
  agentRole: string;
  cellId: string;
  qaReport: QAReport;
  requestedAt: string;     // ISO timestamp
  status: 'pending' | 'approved' | 'rejected';
}
```

### 5.3 State Initialization and Synchronization

On startup, The Glass fetches the current state via REST:

```
1. GET /api/state → full OrchestratorState
2. Populate Zustand store
3. Open SSE connection to GET /api/events
4. Apply incoming STATE_DELTA events as patches to Zustand store
```

This two-phase initialization ensures The Glass has a consistent baseline before
processing incremental updates. The REST call returns the same data shape as the
`STATE_SNAPSHOT` SSE event.

### 5.4 Per-Block Jotai Atoms

Each block instance creates atoms for its local concerns:

```typescript
// Example: A Window block (terminal)
const terminalAtoms = {
  scrollLocked: atom(true),       // Auto-scroll to bottom
  searchQuery: atom(''),          // Terminal search
  fontSize: atom(14),             // User preference
  lineCount: atom(0),             // Buffer statistics
};

// Example: The Frame View block (DAG)
const frameAtoms = {
  selectedNodeId: atom<string | null>(null),
  zoomLevel: atom(1.0),
  layoutDirection: atom<'TB' | 'LR'>('TB'),
  highlightedPath: atom<string[]>([]),
};

// Example: The Keeper block (approvals)
const keeperAtoms = {
  selectedApprovalId: atom<string | null>(null),
  filterStatus: atom<'all' | 'pending' | 'decided'>('pending'),
  sortOrder: atom<'newest' | 'oldest'>('newest'),
};
```

These atoms are created when a block enters the CREATED state and garbage
collected when it enters DISPOSED. They are never shared across blocks.

---

## 6. Approval Flow (The Keeper)

### 6.1 End-to-End Approval Lifecycle

The Keeper is the human-in-the-loop approval interface. It is not middleware --
it does not sit in the request path between Workers and The Queen. It is a
database query rendered as a UI, combined with the interrupt/resume lifecycle
defined in doc 09 (Orchestration Engine).

**Full lifecycle:**

```
1. QE Worker completes Inspection
     ↓
2. QE Worker writes qa-report.json to its worktree
     ↓
3. The Queen detects qa-report.json via hook-driven event
     ↓
4. The Queen evaluates auto-approve rules:
   - All scores >= 3 → auto-approve → Worker resumes (no human needed)
   - Any score < 2 → auto-reject → Worker terminated
   - Scores 2-3 → human review required → continue to step 5
     ↓
5. The Queen emits worker.gate_blocked event to The Airway
     ↓
6. AG-UI adapter translates to RUN_FINISHED with outcome: "interrupt"
     ↓
7. Worker enters "capped" state (suspended, no new Cells dispatched)
     ↓
8. SSE delivers interrupt event to The Glass
     ↓
9. The Keeper block shows PendingApproval with:
   - QA scores per dimension (contract conformance, security, etc.)
   - Blockers list (CRITICAL items that triggered review)
   - Diff preview (files changed by the Worker, via The Code)
   - Approve / Reject buttons
     ↓
10. Human clicks Approve or Reject
     ↓
11. The Glass sends POST /api/approval/:id/decide
    { decision: "approve" | "reject", reason: "..." }
     ↓
12. Fastify server writes decision to approval_history (operational DB)
     ↓
13. The Queen receives approval decision via The Airway
     ↓
14. Approve → Worker uncapped, resumes next Cell
    Reject → Worker terminated, Cell marked as Dead Brood
```

### 6.2 The Keeper UI

The Keeper renders pending approvals as a queue. Each approval card shows:

**Header:** Worker name, Caste, Cell being inspected, time waiting.

**QA Scores:** Five-dimension radar or bar chart:

| Dimension | Score | Threshold |
|-----------|-------|-----------|
| Contract Conformance | 0-5 | >= 3 to pass |
| Security | 0-5 | >= 3 to pass |
| Test Coverage | 0-5 | >= 2 to pass |
| Performance | 0-5 | >= 2 to pass |
| Code Quality | 0-5 | >= 2 to pass |

**Blockers:** List of CRITICAL items from the QA report. Each blocker shows the
file, line, and description.

**Diff Preview:** Inline Monaco DiffEditor showing the Worker's changes. Same
component as The Code block, rendered inline.

**Actions:** Approve (with optional comment) and Reject (with required reason).

### 6.3 Approval is Not Real-Time Blocking

A critical design property: The Keeper does not block in a request/response
cycle. When a Worker hits an Inspection gate, it enters the "capped" state and
stops. The approval sits in the database. The human may review it immediately or
hours later. The Worker remains capped until a decision arrives. Other Workers
continue their Cells unaffected.

This means The Glass can be closed and reopened without losing pending
approvals. The approval state lives in the operational database, not in
The Glass's memory.

---

## 7. Performance Constraints

### 7.1 Rendering Budget

| Metric | Target | Constraint |
|--------|--------|------------|
| DAG rendering (The Frame) | 60 FPS at 50 nodes | `React.memo` on EVERY custom @xyflow/react node -- mandatory, not optional |
| Visible terminals (A Window) | 30 FPS each, max 4 visible | @xterm/xterm is 100% main-thread bound. No worker thread offloading. |
| WebGL contexts | Max 16 per Chrome renderer process | Each @xterm/xterm WebGL addon consumes one context. Visible terminals get WebGL; hidden terminals use DOM renderer. |
| SSE event processing | 50ms batching window | Client-side: buffer incoming SSE events for 50ms, then apply as a batch to Zustand store. Prevents jank from 100+ events/second during active builds. |
| Total memory (8 terminals) | 120-200 MB | Terminal buffers at 1,000-line scrollback dominate. Each terminal: ~15-25 MB with WebGL. |

### 7.2 React.memo Is Mandatory

This is not a performance optimization. It is a correctness requirement for
@xyflow/react. Without `React.memo` on every custom node component, moving or
selecting a single DAG node triggers re-renders on ALL nodes. At 50 nodes, this
drops frame rate below 10 FPS and makes the DAG unusable.

Every custom node, every custom edge, and every custom handle component in
The Frame View MUST be wrapped in `React.memo` with a shallow comparison
function. This is enforced by lint rule.

### 7.3 Terminal Performance Model

@xterm/xterm v6 is entirely main-thread. There is no Web Worker support for
terminal rendering. The WebGL addon offloads glyph rendering to the GPU but
still processes escape sequences on the main thread.

**Practical limits:**

- 4 visible terminals at 30 FPS each: smooth, no jank
- 8 visible terminals: 15-20 FPS, noticeable lag on rapid output
- 16 visible terminals: WebGL context exhaustion, fallback to DOM renderer,
  significant performance degradation

The Glass enforces a soft limit of 4 visible Window blocks. Additional
terminals can exist in HIDDEN state (preserving their buffer) but are not
rendered. The Yard View provides status for all Workers without terminal
rendering overhead.

### 7.4 Progressive Disclosure for Fleet Scale

When monitoring more than 20 Workers, The Glass shifts from "show everything"
to "show what matters":

| Layer | Content | Token Budget | Trigger |
|-------|---------|-------------|---------|
| Layer 1 | Name, status, brief task description | ~800 tokens for 50+ Workers | Default in The Yard View |
| Layer 2 | Current step, reasoning log, tools in use | ~2K tokens per Worker | Click on Worker row |
| Layer 3 | Full trace, token usage, raw API calls, performance metrics | Unbounded | Explicit "deep dive" action |

Layer 1 is always visible. Layer 2 loads on demand via REST. Layer 3 opens
a dedicated Trail block for the selected Worker.

---

## 8. UI Database Schema

### 8.1 Separation Principle

The Glass maintains its own SQLite database, separate from all operational
databases (sessions, events, metrics, mail). This database stores only UI
concerns: saved layouts, block preferences, approval decision history (for
audit), and user settings.

**Why separate:**

- The Glass can be rebuilt, reset, or wiped without affecting any operational
  data. No build state, no Worker sessions, no QA reports are stored here.
- Operational databases are owned by The Queen and the Fastify services.
  The Glass reads them via API, never writes to them directly.
- The UI database can use aggressive WAL mode settings optimized for single-
  writer (The Glass) without conflicting with multi-writer operational DBs.

### 8.2 Schema

**`layouts` table** -- Saved workspace configurations.

```sql
CREATE TABLE layouts (
  id          TEXT PRIMARY KEY,           -- UUID
  name        TEXT NOT NULL,              -- User-facing name
  description TEXT,                       -- Optional description
  config      TEXT NOT NULL,              -- JSON: panel arrangement, block types, sizes
  is_default  INTEGER NOT NULL DEFAULT 0, -- 1 if this is the startup layout
  created_at  TEXT NOT NULL,              -- ISO 8601
  updated_at  TEXT NOT NULL               -- ISO 8601
);
```

**`block_state` table** -- Per-block persisted state.

```sql
CREATE TABLE block_state (
  block_id    TEXT PRIMARY KEY,           -- UUID (matches runtime block instance)
  block_type  TEXT NOT NULL,              -- Registry key: "yard-view", "window", etc.
  layout_id   TEXT NOT NULL REFERENCES layouts(id) ON DELETE CASCADE,
  state       TEXT NOT NULL,              -- JSON: serialized Jotai atom values
  position    TEXT NOT NULL,              -- JSON: { panel, index, width, height }
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
```

**`approval_history` table** -- Local record of approval decisions.

```sql
CREATE TABLE approval_history (
  id          TEXT PRIMARY KEY,           -- UUID
  approval_id TEXT NOT NULL,              -- References operational approval
  agent_id    TEXT NOT NULL,              -- Which Worker
  agent_role  TEXT NOT NULL,              -- Worker's Caste
  cell_id     TEXT NOT NULL,              -- Which Cell was inspected
  decision    TEXT NOT NULL,              -- 'approved' | 'rejected'
  reason      TEXT,                       -- Human-provided reason
  qa_scores   TEXT NOT NULL,              -- JSON: snapshot of scores at decision time
  decided_at  TEXT NOT NULL,              -- ISO 8601
  decided_by  TEXT NOT NULL DEFAULT 'keeper'  -- Future: RBAC user identity
);
```

**`preferences` table** -- User preferences and settings.

```sql
CREATE TABLE preferences (
  key         TEXT PRIMARY KEY,           -- Preference key (e.g., "theme", "terminal.fontSize")
  value       TEXT NOT NULL,              -- JSON-encoded value
  updated_at  TEXT NOT NULL               -- ISO 8601
);
```

### 8.3 What Is NOT Stored Here

- Worker session state (lives in `sessions.db`, read via API)
- Build events (live in `events.db`, delivered via SSE)
- QA reports (live in Worker worktrees, delivered via API)
- Token metrics (live in `metrics.db`, delivered via SSE + REST)
- File ownership maps (computed by The Queen, delivered via SSE)
- Approval decisions (canonical copy in operational DB; `approval_history`
  here is a local audit mirror)

---

## 9. Reverse Proxy Configuration

### 9.1 The SSE Buffering Problem

Reverse proxies (Nginx, Caddy, cloud load balancers) buffer HTTP responses by
default. This is correct for normal REST responses. It is catastrophic for SSE.
A buffered SSE stream delivers events in unpredictable bursts instead of
real-time, breaking the entire streaming architecture.

### 9.2 Nginx Configuration

When The Glass is served behind Nginx (production deployment), the following
directives are required on the SSE endpoint:

```nginx
location /api/events {
    proxy_pass http://localhost:3000;

    # Disable response buffering — required for SSE
    proxy_buffering off;

    # Tell upstream proxies not to buffer either
    add_header X-Accel-Buffering no;

    # Disable chunked encoding transformation
    chunked_transfer_encoding off;

    # Long-lived connection timeouts
    proxy_read_timeout 86400s;    # 24 hours
    proxy_send_timeout 86400s;

    # Disable request buffering for responsiveness
    proxy_request_buffering off;

    # HTTP/1.1 for keepalive
    proxy_http_version 1.1;
    proxy_set_header Connection '';
}
```

**For WebSocket terminal connections:**

```nginx
location /api/terminal/ {
    proxy_pass http://localhost:3000;

    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_read_timeout 86400s;
    proxy_send_timeout 86400s;
}
```

### 9.3 Caddy Configuration

Caddy handles SSE correctly by default (no response buffering). No special
configuration is needed beyond the standard reverse proxy directive. This makes
Caddy the simpler choice for deployments where Nginx's advanced features are not
required.

### 9.4 Cloud Load Balancers

AWS ALB, GCP Cloud Load Balancing, and Azure Application Gateway all support SSE
but require idle timeout configuration. Default idle timeouts (60 seconds) will
kill SSE connections during quiet build periods. Set idle timeout to at least
3600 seconds (1 hour) or implement a server-side heartbeat at 30-second
intervals.

The Hive's Fastify server sends a comment-line heartbeat every 30 seconds on
the SSE stream:

```
: heartbeat 1742486430000
```

This keeps the connection alive through any proxy or load balancer without
consuming client-side processing.

---

## 10. Build Integration

### 10.1 Where The Glass Lives in the Build Program

The Glass is built as part of Phase 6 (Federation and Scale) of The Hive's
build program (doc 16). It depends on:

- **Phase 0 (Foundation):** Fastify server skeleton, SQLite databases
- **Phase 2 (Orchestration):** Worker lifecycle, The Queen's coordinator loop,
  The Airway event bus
- **Phase 3 (Quality):** Inspection gates, QA report schema, approval interrupt
  protocol

The Glass's own build sequence:

| Step | Deliverable | Depends On |
|------|-------------|------------|
| 1 | Vite + React project scaffolding, served by Fastify | Phase 0 server |
| 2 | Block registry, layout system, UI database | None (self-contained) |
| 3 | SSE client, Zustand store, state synchronization | Phase 2 event bus |
| 4 | The Yard View (fleet overview) | SSE + state store |
| 5 | A Window (terminal blocks) | WebSocket terminal endpoint |
| 6 | The Frame View (DAG visualization) | State store (cells, dependencies) |
| 7 | The Keeper (approval queue) | Phase 3 approval interrupt protocol |
| 8 | The Trail, The Yield, The Code, The Comb, The Signal | Respective API endpoints |

### 10.2 Development Workflow

During development, Vite runs in dev mode with HMR (Hot Module Replacement),
proxying API requests to the Fastify server. In production, Vite builds static
assets that Fastify serves from a `dist/` directory.

```
Development:
  Vite dev server (:5173) → HMR for React components
  Fastify server (:3000)  → API endpoints + SSE + WebSocket
  Vite proxy config       → /api/* requests forwarded to :3000

Production:
  Fastify server (:3000)  → Serves dist/ static assets + API + SSE + WebSocket
```

---

## 11. Cross-Document References

The Glass depends on and is referenced by these specification documents:

| Document | Relationship |
|----------|-------------|
| **18 -- API Layer** | Defines all REST, SSE, and WebSocket endpoints that The Glass consumes. The Glass is the primary consumer of the API layer. |
| **13 -- Observability** | Defines the operational databases (sessions, events, metrics) that The Glass reads via API. The Glass is the visual rendering layer for observability data. |
| **09 -- Orchestration Engine** | Defines Worker lifecycle, The Queen's coordinator loop, and the interrupt/resume protocol that The Keeper visualizes. |
| **10 -- Quality Intelligence** | Defines Inspection gates, QA report schema, and the auto-approve/reject/escalate rules that The Keeper implements. |
| **15 -- Contract System** | Defines file ownership and contract compliance that The Comb visualizes. |
| **06 -- Communication Model** | Defines The Airway event bus that feeds SSE via the AG-UI adapter. |
| **12 -- Work Tracker** | Defines Cells and The Frame (task graph) that The Frame View renders as a DAG. |

---

## 12. Open Questions

| # | Question | Impact | Notes |
|---|----------|--------|-------|
| 1 | **RBAC for The Glass** -- Viewer (read-only), Operator (approve/reject, pause/resume), Admin (cancel, kill, configure). Where is the auth model defined? | High | Deferred to doc 18 or a dedicated security document. The Glass must support role-based UI (hide buttons for Viewers). |
| 2 | **Terminal buffer persistence** -- When The Glass reconnects after being closed, should it restore terminal scrollback? From where? | Medium | Options: (a) file system log per Worker, (b) ring buffer in Fastify memory, (c) accept loss on reconnect. Decision affects memory budget. |
| 3 | **Multi-Colony support** -- Can The Glass observe multiple Colonies simultaneously? | Low | Not in scope for 1.0. Single Colony assumed. Colony switcher is a future feature. |
| 4 | **Theming** -- Dark mode only, or light/dark toggle? | Low | Default to dark (terminal-native). Light mode as preference in UI database. |
| 5 | **Keyboard shortcuts** -- The Glass should be operable without a mouse for efficiency. Shortcut scheme TBD. | Low | Follow VS Code conventions where applicable. |

---

## 13. Design Principles Summary

1. **The Glass is a window, not a wall.** It observes. It does not obstruct.
   Builds run with or without it.

2. **Three protocols, not one.** SSE for streaming, REST for control, WebSocket
   for terminals. Each chosen for its transport characteristics.

3. **AG-UI at the boundary only.** Internal events stay Hive-native. AG-UI
   translation happens once, at the SSE endpoint, for external consumers.

4. **Per-block state isolation.** Jotai atoms prevent cross-block render
   cascades. One block updating does not re-render another.

5. **No URL routing.** Zustand-driven panel switching preserves long-lived
   connections. Navigation never triggers unmount/remount.

6. **The Keeper is a database query, not middleware.** Approval state lives in
   the operational database. The Glass renders it. The human decides. The Queen
   acts on the decision.

7. **The Glass can be destroyed and rebuilt.** Its own SQLite database contains
   only UI preferences and layout state. All operational data lives elsewhere.

8. **Performance is a constraint, not a goal.** 60 FPS at 50 DAG nodes, 4
   visible terminals at 30 FPS, 50ms SSE batching. These are hard limits that
   drive architectural decisions, not aspirational targets.
