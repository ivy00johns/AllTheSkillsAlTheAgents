# Agentic UI Dashboard — Master Architecture Specification

**Version:** 0.1.0-draft
**Date:** 2026-03-19
**Status:** Design
**Author:** Research synthesis from 6 parallel deep-dive agents + orchestrator analysis

---

## 1. Vision

Build the first open-source **live animated agent orchestration dashboard** — a purpose-built system that bridges CLI agent output to web UIs at scale, displaying 20+ simultaneous agent processes with live DAG state, structured traces, and human-in-the-loop approval flows.

This fills the gap identified across the entire agentic UI landscape: no existing open-source tool provides real-time animated DAG visualization with progressive-disclosure drill-down into terminal output, structured traces, and approval queues. Every existing project (Composio AO, Mission Control, Dorothy, Mozzie, VibeGrid) picks 1-2 of these capabilities and punts the rest.

**The dashboard is the control plane for the AllTheSkillsAllTheAgents orchestrator** — monitoring 9 agent roles executing 14-phase builds with contract-first architecture, exclusive file ownership, and QA-gated releases.

---

## 2. Goals

### Must Have (P0)
- Display 5-20 simultaneous agent processes with real-time status
- Live DAG visualization of task graph with animated state transitions
- Terminal output per agent (xterm.js) with intelligent multiplexing
- Structured log streaming per agent with ANSI color support
- Human-in-the-loop approval flows for QA gates
- Progressive disclosure: index → detail → deep dive
- Agent code change review (diff viewer)
- SSE-based streaming with self-healing reconnection

### Should Have (P1)
- Tauri v2 desktop shell (5-10x lighter than Electron)
- Block-based layout (typed views that rearrange/collapse/restore)
- Plugin architecture (8 swappable slots)
- Reactions system (YAML-declarative CI self-correction)
- File ownership enforcement with collision detection
- Observability via Langfuse + OpenTelemetry
- RBAC (Viewer/Operator/Admin)

### Could Have (P2)
- Kanban board for agent state tracking
- Real-time metrics dashboard (tokens/sec, cost/task)
- Execution timeline (swim lanes per agent)
- Memory knowledge graph visualization
- Multi-gateway agent discovery
- Framework adapters (CrewAI, LangGraph, AutoGen)

### Won't Have (this version)
- Mobile client
- Multi-tenant SaaS deployment
- Voice/audio agent interaction
- Distributed multi-server deployment (single-machine first)
- Agent-to-agent direct communication (orchestrator mediates)

---

## 3. System Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                    TAURI v2 SHELL                         │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │              REACT FRONTEND                       │    │
│  │                                                   │    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐            │    │
│  │  │  Block   │ │  Block   │ │  Block   │  ...      │    │
│  │  │ Registry │ │ Registry │ │ Registry │           │    │
│  │  │          │ │          │ │          │           │    │
│  │  │ agent-   │ │   dag-   │ │ approval │           │    │
│  │  │ output   │ │  visual  │ │  -queue  │           │    │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘           │    │
│  │       │             │            │                │    │
│  │  ┌────▼─────────────▼────────────▼────────┐       │    │
│  │  │         ZUSTAND + JOTAI STATE           │       │    │
│  │  │    (app state)    (block state)         │       │    │
│  │  └────────────────┬───────────────────────┘       │    │
│  │                   │                               │    │
│  │  ┌────────────────▼───────────────────────┐       │    │
│  │  │         AG-UI EVENT ADAPTER             │       │    │
│  │  │    SSE streams + REST control + WS      │       │    │
│  │  └────────────────┬───────────────────────┘       │    │
│  └───────────────────┼───────────────────────────────┘    │
│                      │ Tauri IPC (invoke + emit)          │
│  ┌───────────────────▼───────────────────────────────┐    │
│  │              RUST BACKEND                          │    │
│  │                                                    │    │
│  │  ┌────────────┐ ┌────────────┐ ┌──────────────┐   │    │
│  │  │  Process   │ │   Plugin   │ │  Event Bus   │   │    │
│  │  │  Manager   │ │  Registry  │ │  (tokio)     │   │    │
│  │  └──────┬─────┘ └──────┬─────┘ └──────┬───────┘   │    │
│  │         │              │              │            │    │
│  │  ┌──────▼──────────────▼──────────────▼───────┐    │    │
│  │  │           AGENT SUBPROCESS POOL             │    │    │
│  │  │  ┌───────┐ ┌───────┐ ┌───────┐             │    │    │
│  │  │  │Agent 1│ │Agent 2│ │Agent N│  (node-pty)  │    │    │
│  │  │  └───────┘ └───────┘ └───────┘             │    │    │
│  │  └────────────────────────────────────────────┘    │    │
│  └────────────────────────────────────────────────────┘    │
│                                                          │
│  ┌────────────────────────────────────────────────────┐    │
│  │              PERSISTENCE LAYER                      │    │
│  │  SQLite (sessions, blocks, audit) + File system     │    │
│  └────────────────────────────────────────────────────┘    │
│                                                          │
│  ┌────────────────────────────────────────────────────┐    │
│  │              OBSERVABILITY                          │    │
│  │  Langfuse (traces) + hcom (coordination)            │    │
│  └────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

### Component Boundaries

| Component | Responsibility | Technology | Communicates Via |
|-----------|---------------|-----------|-----------------|
| Tauri Shell | Window management, system tray, native APIs | Tauri v2 + Rust | IPC (invoke/emit) |
| React Frontend | UI rendering, block layout, user interaction | React 19 + TypeScript | Tauri IPC, AG-UI events |
| Block Registry | Dynamic view type registration and lifecycle | TypeScript | React component tree |
| State Layer | Global app state + per-block reactive state | Zustand + Jotai | React subscriptions |
| AG-UI Adapter | Protocol translation, event routing, reconnection | TypeScript | SSE, REST, WebSocket |
| Rust Backend | Process management, plugin resolution, event bus | Rust + Tokio | Tauri IPC, subprocess stdio |
| Process Manager | Spawn/monitor/kill agent subprocesses | Rust + node-pty | Unix pipes, PTY |
| Plugin Registry | Resolve runtime/agent/workspace/tracker plugins | Rust | Plugin interfaces |
| Persistence | Session state, block content, audit trail | SQLite (rusqlite) | SQL queries |
| Observability | Traces, spans, collision detection | Langfuse SDK + hcom | OTLP, SQLite events |

---

## 4. Technology Stack

### Desktop Shell
| Technology | Version | Purpose | Rationale |
|-----------|---------|---------|-----------|
| **Tauri v2** | 2.x | Desktop framework | 30-50MB idle vs Electron's 200-300MB. Jean (Coolify) proves production-ready. Rust backend enables type-safe orchestration. |
| **Rust** | 1.75+ | Backend language | Tokio async runtime, no GC pauses during phase transitions, deterministic behavior |
| **Tokio** | 1.x | Async runtime | Handles thousands of concurrent tasks (agent subprocesses, SSE streams, IPC) |

### Frontend
| Technology | Version | Weekly Downloads | Purpose |
|-----------|---------|-----------------|---------|
| **React** | 19.x | — | UI framework. Jean proves React 19 + Tauri v2 works. |
| **TypeScript** | 5.x | — | Type safety across frontend |
| **Zustand** | 5.x | — | App-level state (React Flow uses it internally) |
| **Jotai** | 2.x | — | Per-block reactive state (Wave Terminal's approach) |
| **React Flow** | 12.x | 35.7K stars | DAG visualization with virtualized rendering |
| **dagre** | 2.0.0 | 1M/week | Hierarchical DAG layout algorithm |
| **Motion** | 12.x | 33M/week | State transition animations (GPU-accelerated, 120fps) |
| **react-resizable-panels** | 4.7.x | 2.7M/week | Nested panel layout with persistence |
| **react-xtermjs** | latest | — | Terminal emulation (xterm.js wrapper) |
| **@melloware/react-logviewer** | latest | 11K/week | Virtualized log streaming with ANSI colors |
| **@monaco-editor/react** | latest | 380K/week | Code diff viewer (DiffEditor component) |
| **react-arborist** | latest | — | Virtualized file tree (10K+ nodes) |
| **@dnd-kit** | latest | — | Kanban drag-and-drop |
| **sonner** | latest | 13M/week | Toast notifications |
| **recharts** | latest | 3.6M/week | Real-time metrics charts |
| **react-calendar-timeline** | latest | 248K/week | Execution history swim lanes |

### Communication
| Technology | Purpose | Rationale |
|-----------|---------|-----------|
| **AG-UI Protocol** | Agent↔frontend events | 17 event types, interrupt lifecycle, adopted by Google/LangChain/AWS/Microsoft |
| **SSE (EventSource)** | Server→client streaming | Auto-reconnect, HTTP/2 multiplexing, industry standard for LLM streaming |
| **REST** | Control commands | Stateless pause/resume/cancel/approve/reject |
| **WebSocket** | Interactive terminals | Bidirectional terminal I/O (xterm.js requires this) |

### Persistence
| Technology | Purpose | Rationale |
|-----------|---------|-----------|
| **SQLite** (rusqlite) | Sessions, blocks, audit trail | Zero operational overhead, single-file backup, Mission Control validates at 20+ agents |
| **File system** | Agent worktrees, skill files | Git-native isolation (Composio AO's proven approach) |

### Observability
| Technology | Purpose | Rationale |
|-----------|---------|-----------|
| **Langfuse** | Hierarchical trace visualization | 18K stars, MIT, OTLP endpoint, multi-agent tracing via shared trace_id |
| **hcom** | Inter-agent coordination | Collision detection (20-30s window), agent lifecycle, transcript sharing |
| **OpenTelemetry** | Instrumentation standard | GenAI Semantic Conventions for create_agent, invoke_agent, execute_tool spans |

---

## 5. Architecture Decisions

### ADR-01: AG-UI Protocol for Agent Communication

**Decision:** Adopt AG-UI's 17 event types + interrupt lifecycle as the primary agent↔frontend protocol. Extend with custom events via RAW type for multi-agent orchestration.

**Context:** Need standardized real-time communication between 9 agent roles and the dashboard. Options: custom WebSocket protocol, AG-UI, gRPC streaming, custom SSE format.

**Consequences:**
- (+) Standardized event types cover 90% of our needs (lifecycle, text, tool calls, state, reasoning)
- (+) CopilotKit React hooks provide production-ready integration
- (+) Adopted by Google, LangChain, AWS, Microsoft — ecosystem support
- (+) Interrupt outcome maps perfectly to QA gate approval flows
- (-) Single-agent-centric — requires orchestrator pattern for multi-agent
- (-) No batch approval — sequential interrupts for multiple pending reviews
- (-) Known React hook bugs (#1809, #2315, #2939) — monitor CopilotKit releases

**Multi-agent workaround:** Single orchestrator AG-UI stream multiplexes events from all 9 agents. Each event includes `agentId` field. Frontend routes events to appropriate block's Jotai atom.

```typescript
// Event routing pattern
interface OrchestratorEvent extends AGUIEvent {
  agentId: string;        // "backend-agent", "frontend-agent", etc.
  agentRole: AgentRole;   // Enum of 9 roles
  phaseId: number;        // Current build phase (1-14)
}
```

### ADR-02: Block Architecture (Wave Terminal Pattern)

**Decision:** Implement a typed block registry where each dashboard view is a registered block type with independent ViewModel and ViewComponent.

**Context:** Need flexible, extensible dashboard that can display 9+ different view types simultaneously and add new types without core changes.

**Consequences:**
- (+) New block types (future: memory graph, cost tracker) require zero core changes
- (+) Each block has independent Jotai atoms — no state coupling
- (+) Blocks can be rearranged, collapsed, restored, persisted
- (+) Wave Terminal validates this at production scale with 40+ contributors
- (-) More complex than simple component composition
- (-) Requires careful lifecycle management (dispose on close, serialize on hide)

**Registry pattern:**
```typescript
interface BlockDefinition<TState = any> {
  type: string;
  displayName: string;
  icon: string;
  createAtoms: (config: BlockConfig) => TState;
  Component: React.ComponentType<{ atoms: TState; config: BlockConfig }>;
  serialize?: (atoms: TState) => SerializedBlock;
  deserialize?: (data: SerializedBlock) => TState;
  dispose?: (atoms: TState) => void;
}

const BlockRegistry = new Map<string, BlockDefinition>();

// Registration
BlockRegistry.set('agent-output', {
  type: 'agent-output',
  displayName: 'Agent Output',
  icon: 'terminal',
  createAtoms: (config) => ({
    logs: atom<string[]>([]),
    status: atom<AgentStatus>('idle'),
    agentId: atom(config.agentId),
  }),
  Component: AgentOutputBlock,
  serialize: (atoms) => ({ /* ... */ }),
  deserialize: (data) => ({ /* ... */ }),
  dispose: (atoms) => { /* cleanup xterm instance */ },
});
```

### ADR-03: Tauri v2 Over Electron

**Decision:** Use Tauri v2 with Rust backend for the desktop shell. Pure web (Next.js) as secondary deployment target.

**Context:** Need desktop application for monitoring local agent processes. Options: Electron, Tauri v2, pure web, NW.js.

**Consequences:**
- (+) 30-50MB memory idle vs Electron's 200-300MB (5-10x improvement)
- (+) <0.5s startup vs 1-2s
- (+) Rust backend: type-safe, Tokio async, no GC pauses
- (+) Jean (Coolify) proves Tauri v2 + React 19 is production-ready
- (+) Built-in HTTP server for remote web access
- (-) Smaller plugin ecosystem than Electron
- (-) Fewer developers experienced with Tauri
- (-) WebView limitations vs Chromium (no DevTools in production)

**Fallback plan:** If Tauri blocks progress on a critical feature, the frontend is pure React — can wrap in Electron with minimal changes. The Rust backend communicates via HTTP/WebSocket, not Tauri-specific APIs, to preserve this option.

### ADR-04: Zustand + Jotai Hybrid State Management

**Decision:** Zustand for global app state, Jotai atoms for per-block reactive state.

**Context:** Need state management that handles 20+ agent blocks with independent state, React Flow integration, and high-frequency SSE updates without jank.

**Consequences:**
- (+) React Flow uses Zustand internally — zero impedance mismatch
- (+) Jotai atoms give each block isolated, fine-grained reactivity (Wave Terminal's approach)
- (+) Both are ~1KB — minimal bundle impact
- (+) Zustand selectors with `useShallow` prevent cascading re-renders
- (-) Two state libraries is more complex than one
- (-) Team must understand when to use which

**Boundary rule:** Zustand owns cross-block state (active panel, selected agent, build phase, approval queue). Jotai owns within-block state (terminal buffer, log lines, DAG node positions, animation state).

### ADR-05: SSE + 5-Second Refresh Hybrid Streaming

**Decision:** SSE for real-time event streaming with a 5-second full-state refresh for self-healing. REST for control commands. WebSocket only for interactive terminals.

**Context:** Need reliable streaming from 20+ agent processes to the dashboard. Options: pure WebSocket, pure SSE, SSE+REST hybrid, gRPC streaming.

**Consequences:**
- (+) SSE auto-reconnects with `Last-Event-ID` — no custom reconnection logic
- (+) 5-second refresh recovers from missed patches (Composio AO's proven pattern)
- (+) HTTP/2 multiplexing handles 20+ simultaneous streams efficiently
- (+) Industry-standard (OpenAI, Anthropic, Composio AO all use SSE)
- (-) SSE is unidirectional — need separate REST endpoints for control
- (-) Nginx buffers SSE by default — requires specific configuration

**Production config (Nginx):**
```nginx
location /api/events {
    proxy_buffering off;
    chunked_transfer_encoding off;
    proxy_cache off;
    proxy_set_header Connection '';
    proxy_http_version 1.1;
}
```

### ADR-06: Langfuse + hcom for Observability and Coordination

**Decision:** Langfuse for hierarchical trace visualization. hcom for inter-agent collision detection and coordination. Custom file ownership enforcement layer on top.

**Context:** Need to observe multi-agent builds as unified traces and prevent file ownership violations.

**Consequences:**
- (+) Langfuse: shared `trace_id` groups all agents into single hierarchical tree
- (+) Langfuse: async SDK batching adds ~0.1ms overhead
- (+) hcom: collision detection catches unauthorized file edits within 20-30s
- (+) OpenTelemetry GenAI conventions provide standards-based instrumentation
- (-) Langfuse self-hosting is heavy (16 CPU, 40GB+ RAM for HA)
- (-) hcom is detection-only — doesn't prevent writes, only alerts
- (-) hcom is polling-based, not async push

**Mitigation:** Start with Langfuse Cloud (free tier). Self-host when scale justifies infrastructure. Build file ownership enforcement as a pre-write validation layer, with hcom as the alerting fallback.

### ADR-07: Aegis-Inspired Quality Gates

**Decision:** Implement 4-layer quality evaluation with automated approve/reject/escalate based on scores, integrated with AG-UI interrupt lifecycle.

**Context:** Need automated QA gating that blocks builds on critical issues while allowing human escalation for borderline cases.

**Scoring rules:**
- All scores ≥ 3 → auto-approve → AG-UI `RUN_FINISHED(outcome: "success")`
- Any score < 2 → auto-reject → AG-UI `RUN_FINISHED(outcome: "error")`
- Scores 2-3 → human review → AG-UI `RUN_FINISHED(outcome: "interrupt", reason: "quality_gate")`

**4-layer evaluation:**
| Layer | Checks | Maps To |
|-------|--------|---------|
| Output | Has result, valid schema, no secrets | `qa-report.json` existence + schema validation |
| Trace | Covers requirements, logical steps, tool use | Contract conformance score |
| Component | Function signatures match, correct parameters | API contract diff (curl vs fetch) |
| Drift | Consistent with baseline, token usage normal | Performance regression detection |

### ADR-08: Plugin Architecture (8 Swappable Slots)

**Decision:** Adopt Composio AO's plugin pattern with 8 interface-based, registry-resolved plugin slots.

**Context:** Need extensibility without requiring dashboard code changes for new runtimes, agent types, or integrations.

**Slots:**
| Slot | Interface | Default | Purpose |
|------|-----------|---------|---------|
| Runtime | `RuntimePlugin` | tmux | Process isolation strategy |
| Agent | `AgentPlugin` | claude-code | Agent binary/protocol |
| Workspace | `WorkspacePlugin` | git-worktree | File isolation strategy |
| Tracker | `TrackerPlugin` | github-issues | Task tracking integration |
| SCM | `SCMPlugin` | github | Source control integration |
| Notifier | `NotifierPlugin` | desktop | Alert delivery |
| Dashboard | `DashboardPlugin` | tauri-web | UI deployment target |
| Observability | `ObservabilityPlugin` | langfuse | Trace collection |

**Resolution order:** Config YAML → environment variables → auto-detection → defaults.

### ADR-09: Reactions System (YAML-Declarative Automation)

**Decision:** Implement Composio AO's reactions pattern for automated event response, proven at 84.6% CI self-correction rate.

**Context:** Need automated handling of CI failures, QA rejections, and contract mismatches without human intervention for known-fixable issues.

**Configuration:**
```yaml
reactions:
  ci-failed:
    auto: true
    action: send-to-agent      # Inject CI logs into agent context
    retries: 2                  # Max self-correction attempts
    escalateAfter: 2            # Human escalation after N failures

  qa-gate-failed:
    auto: true
    action: fix-and-revalidate  # Agent fixes, QE re-runs
    retries: 3
    escalateAfter: 3

  contract-mismatch:
    auto: false
    action: notify-orchestrator # Always human decision
    escalateAfter: 0

  changes-requested:
    auto: true
    action: send-to-agent       # PR review feedback to agent
    escalateAfter: 30m          # Time-based escalation

  approved-and-green:
    auto: true
    action: auto-merge          # CI green + approved → merge
```

### ADR-10: SQLite for Persistence

**Decision:** SQLite (via rusqlite in Rust backend) for all dashboard persistence: sessions, block state, audit trail, configuration.

**Context:** Need persistent storage for dashboard state, session history, and audit logging. Options: PostgreSQL, SQLite, file-based JSON, IndexedDB.

**Consequences:**
- (+) Zero operational overhead (no separate database server)
- (+) Single-file backup (`cp dashboard.db dashboard.db.bak`)
- (+) WAL mode allows concurrent read/write on single machine
- (+) Mission Control validates SQLite at 20+ agents with 460 tests
- (-) Can't scale horizontally (single-machine only)
- (-) Limited to one writer at a time (WAL relaxes this)

**Schema design principle:** Append-only audit trail (never delete, mark as archived). Block state uses JSON columns for flexible schema evolution.

---

## 6. Block Architecture (Detailed Design)

### Block Types

| Type ID | Display Name | Primary Component | State Atoms | Data Source |
|---------|-------------|------------------|-------------|-------------|
| `agent-output` | Agent Output | xterm.js terminal | logs, status, agentId, terminalRef | WebSocket (terminal I/O) |
| `dag-visualization` | Task Graph | React Flow + dagre | nodes, edges, selectedNode, layoutDirection | Zustand (agent status updates) |
| `approval-queue` | Approval Queue | Custom cards | pendingApprovals, selectedApproval, history | AG-UI interrupt events |
| `log-viewer` | Structured Logs | @melloware/react-logviewer | logLines, filters, followMode, searchQuery | SSE stream per agent |
| `diff-viewer` | Code Changes | Monaco DiffEditor | originalCode, modifiedCode, language, selectedFile | Agent file change events |
| `contract-compliance` | Contract Status | Custom table + badges | endpoints, scores, violations, lastCheck | Contract auditor output |
| `file-tree` | File Explorer | react-arborist | treeData, expandedNodes, activeAgentFiles | File system events |
| `metrics` | Metrics | recharts | dataPoints, timeWindow, selectedMetric | SSE metrics stream |
| `kanban` | Agent Kanban | @dnd-kit | columns, cards, dragState | Agent status changes |
| `timeline` | Execution Timeline | react-calendar-timeline | groups, items, timeRange | Session history |
| `chat` | Agent Chat | Custom (or assistant-ui) | messages, inputValue, isStreaming | AG-UI text events |

### Block Lifecycle

```
┌─────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ CREATED  │────▶│  ACTIVE  │────▶│  HIDDEN  │────▶│ DISPOSED │
│          │     │          │     │          │     │          │
│ Registry │     │ Rendered │     │ Serialzd │     │ Cleanup  │
│ lookup   │     │ atoms    │     │ state    │     │ atoms    │
│ atoms    │     │ subscr   │     │ saved    │     │ unsub    │
│ created  │     │ active   │     │ unrendr  │     │ removed  │
└─────────┘     └──────────┘     └──────────┘     └──────────┘
                     ▲                │
                     └────────────────┘
                      (restore from serialized)
```

**Key lifecycle operations:**
- **Created:** Registry resolves type → `createAtoms()` initializes state
- **Active:** Component rendered, subscriptions active, receiving events
- **Hidden:** Component unmounted, state serialized to SQLite, subscriptions paused
- **Disposed:** Atoms cleaned up, terminal instances disposed, listeners removed
- **Restore:** Deserialize from SQLite → recreate atoms → render component

### Block Layout System

Uses `react-resizable-panels` for the layout grid:

```typescript
interface DashboardLayout {
  id: string;
  name: string;          // "Default", "DAG Focus", "Terminal Grid", etc.
  panels: PanelConfig[];
  savedAt: Date;
}

interface PanelConfig {
  id: string;
  blockType: string;     // Registry type ID
  blockConfig: Record<string, any>;  // Agent ID, filters, etc.
  size: number;          // Percentage or pixel
  minSize?: number;
  collapsible?: boolean;
  children?: PanelConfig[];  // Nested panels
}
```

**Preset layouts:**
| Layout | Description |
|--------|-------------|
| **Overview** | DAG (60%) + Kanban sidebar (20%) + Metrics (20%) |
| **Agent Focus** | Terminal (50%) + Logs (25%) + Diff (25%) |
| **Review** | Diff viewer (60%) + Contract compliance (20%) + Approval queue (20%) |
| **Monitoring** | Metrics (40%) + Timeline (30%) + Log viewer (30%) |
| **Custom** | User-defined arrangements |

---

## 7. Event and Data Flow Architecture

### SSE Event Pipeline

```
Agent Subprocess (stdout/stderr)
    │
    ▼
Rust Process Manager (capture, tag with agentId + timestamp)
    │
    ▼
Event Bus (tokio broadcast channel)
    │
    ├──▶ SSE Endpoint (/api/events)
    │       │
    │       ▼
    │    AG-UI Event Adapter (convert to AG-UI event types)
    │       │
    │       ▼
    │    EventSource (browser) ──▶ Zustand Store ──▶ Block Atoms
    │
    ├──▶ SQLite (append to event_log table for replay)
    │
    └──▶ Langfuse SDK (emit as OTLP spans, batched async)
```

### AG-UI Event Mapping

| Orchestrator Event | AG-UI Event Type | Payload |
|-------------------|-----------------|---------|
| Agent spawned | `RUN_STARTED` | `{ runId, agentId, agentRole, phase }` |
| Agent output chunk | `TEXT_MESSAGE_CONTENT` | `{ messageId, agentId, content }` |
| Agent tool call | `TOOL_CALL_START` → `TOOL_CALL_ARGS` → `TOOL_CALL_RESULT` → `TOOL_CALL_END` | Tool name, args, result |
| Agent state change | `STATE_DELTA` | `{ agentId, status, progress, currentStep }` |
| Agent completed | `RUN_FINISHED` | `{ runId, outcome: "success" }` |
| QA gate block | `RUN_FINISHED` | `{ runId, outcome: "interrupt", interrupt: { reason: "quality_gate", payload: qaReport } }` |
| Agent error | `RUN_FINISHED` | `{ runId, outcome: "error", error: { message, code } }` |
| Agent thinking | `REASONING_MESSAGE_CONTENT` | `{ messageId, agentId, content }` |
| Full state sync | `STATE_SNAPSHOT` | `{ agents: [...], phases: [...], approvals: [...] }` |
| QA report | `RAW` | `{ type: "qa-report", payload: qaReportJson }` |

### 5-Second Full Refresh

Every 5 seconds, the backend emits a `STATE_SNAPSHOT` event containing the complete orchestrator state. This ensures:
- Missed SSE patches are recovered
- New clients get immediate full state
- Dashboard is self-healing after network glitches

```typescript
// Backend: 5-second refresh timer
setInterval(async () => {
  const fullState = await orchestrator.getFullState();
  eventBus.emit({
    type: 'STATE_SNAPSHOT',
    state: fullState,
  });
}, 5000);
```

### Frontend Event Processing

```typescript
// Batched event processing (50ms window)
const pendingEvents: OrchestratorEvent[] = [];
let flushTimer: number | null = null;

eventSource.onmessage = (event) => {
  pendingEvents.push(JSON.parse(event.data));

  if (!flushTimer) {
    flushTimer = setTimeout(() => {
      // Batch-update Zustand store
      useOrchestratorStore.setState((prev) => {
        return applyEventBatch(prev, pendingEvents);
      });

      // Route to block-specific Jotai atoms
      for (const event of pendingEvents) {
        routeToBlockAtom(event);
      }

      pendingEvents.length = 0;
      flushTimer = null;
    }, 50); // 50ms batch window
  }
};
```

---

## 8. State Management Architecture

### Zustand Store (Global App State)

```typescript
interface OrchestratorState {
  // Build state
  buildId: string | null;
  buildPhase: number;           // 1-14
  buildStatus: 'idle' | 'running' | 'paused' | 'completed' | 'failed';

  // Agent fleet
  agents: AgentState[];
  activeAgentId: string | null;

  // Approvals
  pendingApprovals: Approval[];
  approvalHistory: Approval[];

  // Layout
  activeLayout: string;
  activePanelId: string | null;

  // Connection
  connectionStatus: 'connected' | 'reconnecting' | 'disconnected';
  lastSyncAt: Date | null;

  // Actions
  startBuild: (planId: string) => void;
  pauseBuild: () => void;
  approveGate: (approvalId: string, decision: ApprovalDecision) => void;
  selectAgent: (agentId: string) => void;
  switchLayout: (layoutId: string) => void;
}

interface AgentState {
  id: string;
  role: AgentRole;
  status: 'queued' | 'spawning' | 'running' | 'waiting' | 'completed' | 'failed';
  currentStep: string;
  progress: number;           // 0-100
  tokenUsage: number;
  cost: number;
  startedAt: Date | null;
  completedAt: Date | null;
  error: string | null;
}
```

### Jotai Atoms (Per-Block State)

```typescript
// Each block type defines its own atom factory
function createAgentOutputAtoms(config: { agentId: string }) {
  const logsAtom = atom<string[]>([]);
  const statusAtom = atom<AgentStatus>('idle');
  const terminalRefAtom = atom<Terminal | null>(null);
  const isFollowingAtom = atom(true);
  const searchQueryAtom = atom('');

  return { logsAtom, statusAtom, terminalRefAtom, isFollowingAtom, searchQueryAtom };
}

function createDagVisualizationAtoms() {
  const nodesAtom = atom<Node[]>([]);
  const edgesAtom = atom<Edge[]>([]);
  const selectedNodeAtom = atom<string | null>(null);
  const layoutDirectionAtom = atom<'TB' | 'LR'>('TB');
  const animatingNodesAtom = atom<Set<string>>(new Set());

  return { nodesAtom, edgesAtom, selectedNodeAtom, layoutDirectionAtom, animatingNodesAtom };
}
```

### React Flow Integration

React Flow uses Zustand internally. Custom nodes MUST follow these rules:

```typescript
// RULE 1: Custom nodes must be React.memo
const AgentTaskNode = React.memo(({ data }: NodeProps<AgentTaskData>) => {
  // RULE 2: Use Zustand selectors with shallow comparison
  const status = useOrchestratorStore(
    (s) => s.agents.find(a => a.id === data.agentId)?.status,
    (a, b) => a === b
  );

  return (
    // RULE 3: Wrap in motion.div for state animations
    <motion.div
      animate={{
        scale: status === 'running' ? 1.05 : 1,
        borderColor: statusColor(status),
      }}
      transition={{ duration: 0.3 }}
    >
      <Handle type="target" position={Position.Top} />
      <div className="agent-node">
        <span>{data.label}</span>
        <StatusBadge status={status} />
      </div>
      <Handle type="source" position={Position.Bottom} />
    </motion.div>
  );
});

// RULE 4: nodeTypes must be defined outside component (or useMemo)
const nodeTypes = {
  agentTask: AgentTaskNode,
  phase: PhaseNode,
  gate: GateNode,
};
```

---

## 9. Process Management (Rust Backend)

### Agent Subprocess Architecture

```rust
use tokio::process::Command;
use tokio::sync::broadcast;

struct ProcessManager {
    processes: HashMap<String, ManagedProcess>,
    event_tx: broadcast::Sender<ProcessEvent>,
}

struct ManagedProcess {
    id: String,
    role: AgentRole,
    child: tokio::process::Child,
    status: ProcessStatus,
    started_at: chrono::DateTime<chrono::Utc>,
    stdout_buffer: RingBuffer<String>,  // Last 5000 lines
    stderr_buffer: RingBuffer<String>,
}

enum ProcessEvent {
    Spawned { id: String, role: AgentRole },
    Output { id: String, stream: StdStream, data: String, timestamp: u64 },
    StatusChanged { id: String, from: ProcessStatus, to: ProcessStatus },
    Exited { id: String, code: i32, duration_ms: u64 },
    Error { id: String, error: String },
}

impl ProcessManager {
    async fn spawn_agent(&mut self, role: AgentRole, config: AgentConfig) -> Result<String> {
        let id = generate_agent_id(&role);
        let child = Command::new(&config.binary)
            .args(&config.args)
            .current_dir(&config.worktree_path)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;

        // Capture stdout/stderr in background tasks
        let stdout = child.stdout.take().unwrap();
        let stderr = child.stderr.take().unwrap();
        self.spawn_output_reader(id.clone(), StdStream::Stdout, stdout);
        self.spawn_output_reader(id.clone(), StdStream::Stderr, stderr);

        self.event_tx.send(ProcessEvent::Spawned { id: id.clone(), role })?;
        Ok(id)
    }

    fn spawn_output_reader(&self, id: String, stream: StdStream, reader: impl AsyncRead) {
        let tx = self.event_tx.clone();
        tokio::spawn(async move {
            let mut lines = BufReader::new(reader).lines();
            while let Some(line) = lines.next_line().await? {
                tx.send(ProcessEvent::Output {
                    id: id.clone(),
                    stream,
                    data: line,
                    timestamp: now_millis(),
                })?;
            }
            Ok::<_, anyhow::Error>(())
        });
    }
}
```

### Tauri IPC Bridge

```rust
#[tauri::command]
async fn start_build(
    state: tauri::State<'_, AppState>,
    plan_id: String,
) -> Result<BuildId, String> {
    let build = state.orchestrator.start_build(&plan_id).await
        .map_err(|e| e.to_string())?;
    Ok(build.id)
}

#[tauri::command]
async fn approve_gate(
    state: tauri::State<'_, AppState>,
    approval_id: String,
    decision: ApprovalDecision,
) -> Result<(), String> {
    state.orchestrator.approve_gate(&approval_id, decision).await
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
async fn get_agent_terminal_data(
    state: tauri::State<'_, AppState>,
    agent_id: String,
) -> Result<Vec<String>, String> {
    let buffer = state.process_manager.get_output_buffer(&agent_id)
        .map_err(|e| e.to_string())?;
    Ok(buffer)
}
```

---

## 10. Streaming Architecture (Detailed)

### SSE Endpoint

```rust
// Rust backend SSE endpoint
async fn sse_events(
    State(app): State<AppState>,
    Query(params): Query<SSEParams>,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let mut rx = app.event_bus.subscribe();

    let stream = async_stream::stream! {
        // Send initial state snapshot
        let state = app.orchestrator.get_full_state().await;
        yield Ok(Event::default()
            .event("state_snapshot")
            .data(serde_json::to_string(&state).unwrap()));

        // Stream events
        loop {
            match rx.recv().await {
                Ok(event) => {
                    let ag_ui_event = convert_to_ag_ui(event);
                    yield Ok(Event::default()
                        .event(&ag_ui_event.event_type)
                        .data(serde_json::to_string(&ag_ui_event).unwrap())
                        .id(ag_ui_event.id.to_string()));
                }
                Err(broadcast::error::RecvError::Lagged(n)) => {
                    // Client fell behind — send full state snapshot
                    let state = app.orchestrator.get_full_state().await;
                    yield Ok(Event::default()
                        .event("state_snapshot")
                        .data(serde_json::to_string(&state).unwrap()));
                }
                Err(_) => break,
            }
        }
    };

    Sse::new(stream).keep_alive(
        axum::response::sse::KeepAlive::new()
            .interval(Duration::from_secs(15))
            .text("ping")
    )
}
```

### WebSocket for Interactive Terminals

```rust
// WebSocket endpoint for terminal I/O
async fn ws_terminal(
    ws: WebSocketUpgrade,
    Path(agent_id): Path<String>,
    State(app): State<AppState>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| async move {
        let (mut ws_tx, mut ws_rx) = socket.split();
        let process = app.process_manager.get_process(&agent_id).unwrap();

        // Forward terminal output → WebSocket
        let mut output_rx = process.subscribe_output();
        let send_task = tokio::spawn(async move {
            while let Ok(data) = output_rx.recv().await {
                ws_tx.send(Message::Binary(data.into())).await.ok();
            }
        });

        // Forward WebSocket input → terminal stdin
        let stdin = process.stdin();
        let recv_task = tokio::spawn(async move {
            while let Some(Ok(msg)) = ws_rx.next().await {
                if let Message::Binary(data) = msg {
                    stdin.write_all(&data).await.ok();
                }
            }
        });

        tokio::select! {
            _ = send_task => {},
            _ = recv_task => {},
        }
    })
}
```

---

## 11. Observability Architecture

### Instrumentation Points

```
Build Started
├── Phase N Started
│   ├── Agent Spawned (create_agent span)
│   │   ├── Tool Call (execute_tool span)
│   │   ├── LLM Call (generation span)
│   │   ├── File Write (custom span + hcom event)
│   │   └── Agent Output (text span)
│   ├── Agent Completed
│   └── QA Gate Evaluated
├── Phase N Completed
└── Build Completed
```

### Langfuse Integration

```typescript
// Orchestrator generates shared trace_id for entire build
const traceId = `build_${buildId}`;

// Each agent uses the same trace_id
const agentTrace = langfuse.trace({
  id: `${traceId}_${agentRole}`,
  name: `${agentRole}_execution`,
  traceId: traceId,
  sessionId: buildId,
  metadata: { phase, role: agentRole, worktree: worktreePath },
});

// Tool calls become child spans
const toolSpan = agentTrace.span({
  name: 'file_write',
  input: { path: filePath },
  metadata: { owner: agentRole },
});
```

### hcom Collision Detection

```typescript
// Pre-write validation hook
async function validateFileOwnership(filePath: string, agentId: string): Promise<void> {
  const expectedOwner = getFileOwner(filePath); // From contract
  if (agentId !== expectedOwner) {
    throw new FileOwnershipViolation(filePath, agentId, expectedOwner);
  }

  // Check for recent collisions via hcom
  const recentEdits = await hcom.queryEvents({
    filter: `file:${filePath}`,
    window: '30s',
  });

  if (recentEdits.length > 0 && recentEdits.some(e => e.agentId !== agentId)) {
    throw new CollisionDetected(filePath, agentId, recentEdits);
  }
}
```

### OpenTelemetry Configuration

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: "0.0.0.0:4318"

exporters:
  otlp/langfuse:
    endpoint: "https://cloud.langfuse.com/api/public/otel"
    headers:
      Authorization: "Basic ${LANGFUSE_PUBLIC_KEY}:${LANGFUSE_SECRET_KEY}"

  otlp/jaeger:
    endpoint: "localhost:4317"

processors:
  batch:
    timeout: 2s
    send_batch_size: 100

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/langfuse, otlp/jaeger]
```

---

## 12. Security Model

### RBAC Roles

| Permission | Viewer | Operator | Admin |
|-----------|--------|----------|-------|
| View dashboard | Yes | Yes | Yes |
| View agent output | Yes | Yes | Yes |
| View metrics/costs | Yes | Yes | Yes |
| Start/pause builds | No | Yes | Yes |
| Approve QA gates | No | Yes | Yes |
| Send commands to agents | No | Yes | Yes |
| Manage agent configs | No | No | Yes |
| Manage plugins | No | No | Yes |
| View audit trail | No | No | Yes |
| Manage users/roles | No | No | Yes |

### Authentication

- Session-based for dashboard UI (httpOnly cookie)
- API key-based for CLI/programmatic access (SHA-256 hashed in SQLite)
- Ed25519 device identity for agent WebSocket connections (Mission Control's approach)

### Audit Trail Schema

```sql
CREATE TABLE audit_log (
    id TEXT PRIMARY KEY,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_id TEXT,
    agent_id TEXT,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT,
    old_value TEXT,    -- JSON
    new_value TEXT,    -- JSON
    metadata TEXT      -- JSON (IP, session, etc.)
);

CREATE INDEX idx_audit_timestamp ON audit_log(timestamp);
CREATE INDEX idx_audit_resource ON audit_log(resource_type, resource_id);
```

---

## 13. Database Schema (Core Tables)

```sql
-- Build sessions
CREATE TABLE builds (
    id TEXT PRIMARY KEY,
    plan_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    current_phase INTEGER DEFAULT 0,
    started_at DATETIME,
    completed_at DATETIME,
    metadata TEXT  -- JSON
);

-- Agent instances per build
CREATE TABLE agents (
    id TEXT PRIMARY KEY,
    build_id TEXT NOT NULL REFERENCES builds(id),
    role TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued',
    worktree_path TEXT,
    pid INTEGER,
    started_at DATETIME,
    completed_at DATETIME,
    exit_code INTEGER,
    token_usage INTEGER DEFAULT 0,
    cost_cents INTEGER DEFAULT 0,
    error TEXT
);

-- Block layout state
CREATE TABLE blocks (
    id TEXT PRIMARY KEY,
    layout_id TEXT NOT NULL,
    block_type TEXT NOT NULL,
    config TEXT NOT NULL,      -- JSON
    serialized_state TEXT,     -- JSON (for restore)
    position_index INTEGER,
    size_percent REAL,
    is_collapsed BOOLEAN DEFAULT FALSE
);

-- Dashboard layouts
CREATE TABLE layouts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    panels TEXT NOT NULL,       -- JSON (PanelConfig tree)
    is_default BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Event log (append-only, for replay)
CREATE TABLE event_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    build_id TEXT NOT NULL REFERENCES builds(id),
    agent_id TEXT,
    event_type TEXT NOT NULL,
    payload TEXT NOT NULL,      -- JSON (AG-UI event)
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Approval queue
CREATE TABLE approvals (
    id TEXT PRIMARY KEY,
    build_id TEXT NOT NULL REFERENCES builds(id),
    agent_id TEXT,
    gate_type TEXT NOT NULL,    -- 'qa_gate', 'contract_mismatch', 'security'
    status TEXT NOT NULL DEFAULT 'pending',
    payload TEXT NOT NULL,      -- JSON (QA report, diff, etc.)
    decision TEXT,              -- 'approved', 'rejected', 'escalated'
    decided_by TEXT,
    decided_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Plugin configuration
CREATE TABLE plugins (
    slot TEXT NOT NULL,
    name TEXT NOT NULL,
    config TEXT,               -- JSON
    is_active BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (slot, name)
);

-- Reactions configuration
CREATE TABLE reactions (
    id TEXT PRIMARY KEY,
    event_type TEXT NOT NULL,
    auto BOOLEAN DEFAULT FALSE,
    action TEXT NOT NULL,
    retries INTEGER DEFAULT 0,
    escalate_after TEXT,       -- Duration or count
    config TEXT                -- JSON (additional params)
);
```

---

## 14. Performance Budget

### Memory Budget (20 Agents)

| Component | Per Agent | 20 Agents | Notes |
|-----------|-----------|-----------|-------|
| DAG node (React Flow) | ~2KB | 40KB | Node object + React fiber |
| Terminal buffer (xterm.js) | 1-5MB | 20-100MB | 10K lines scrollback each |
| Log viewer (virtualized) | 100KB-1MB | 2-20MB | Only visible lines in DOM |
| Monaco editor (shared) | — | 15MB | Single instance, swap models |
| Zustand store | ~10KB | ~200KB | Global state |
| Jotai atoms per block | ~5KB | ~500KB | 100 atoms across 20 blocks |
| SQLite WAL | — | 10-50MB | Depends on event volume |
| **Total** | — | **48-186MB** | Safe for desktop |

### CPU/FPS Targets

| Scenario | Target | Constraint |
|----------|--------|-----------|
| 20 DAG nodes, status animation | 60 FPS | React.memo + Motion GPU |
| 50 DAG nodes, layout change | 60 FPS | dagre <10ms compute |
| 4 visible terminals, active output | 30 FPS | xterm.js main-thread I/O |
| 8 hidden terminals, buffering | 0 FPS (headless) | @xterm/headless |
| 20 SSE streams, 50ms batch | 60 FPS | Zustand batch update |
| Full state snapshot (5s) | <100ms | JSON parse + store update |
| Kanban drag (20 cards) | 60 FPS | React.memo on AgentCard |

### Hard Limits

| Limit | Value | Source |
|-------|-------|--------|
| WebGL contexts per page | 8-16 | Browser limit |
| Visible xterm.js terminals | 4-8 | Main-thread I/O |
| Monaco editor instances | 1 | Global state conflicts |
| SSE connections per domain | 6 (HTTP/1.1) or 100+ (HTTP/2) | Browser limit |
| dagre layout nodes | ~500 before >100ms | Algorithm complexity |
| react-arborist nodes | 10,000+ | Virtualized |

---

## 15. Phase Roadmap (Overview)

Detailed specifications for each phase are in separate documents.

| Phase | Name | Duration | Dependencies | Deliverable |
|-------|------|----------|-------------|-------------|
| **1** | Foundation Shell | 2-3 weeks | None | Tauri v2 + block registry + state + SSE skeleton |
| **2** | Core Visualization Blocks | 2-3 weeks | Phase 1 | Agent-output, DAG, log-viewer blocks |
| **3** | Agent Communication Layer | 2-3 weeks | Phase 1 | AG-UI adapter, Rust process manager, streaming |
| **4** | Approval + Quality Gates | 2 weeks | Phase 3 | Interrupt flow, Aegis gates, approval-queue block |
| **5** | Code Review + Contracts | 2 weeks | Phase 2 | DiffEditor, contract-compliance, file-tree blocks |
| **6** | Observability + Coordination | 2 weeks | Phase 3 | Langfuse, hcom, file ownership enforcement |
| **7** | Extensibility | 2 weeks | Phase 4 | Plugin slots, reactions, framework adapters |
| **8** | Dashboard Polish | 2-3 weeks | All above | Kanban, metrics, timeline, RBAC, perf tuning |

**Parallelism:** Phases 2 and 3 can run concurrently. Phases 4, 5, 6 can partially overlap. Phases 7 and 8 are sequential.

**Total estimated duration:** 14-19 weeks (3.5-5 months)

### Phase Dependency Graph

```
Phase 1 (Foundation)
    ├──▶ Phase 2 (Visualization)
    │       └──▶ Phase 5 (Code Review)
    │
    └──▶ Phase 3 (Communication)
            ├──▶ Phase 4 (Approval Gates)
            │       └──▶ Phase 7 (Extensibility)
            │
            └──▶ Phase 6 (Observability)
                        └──▶ Phase 8 (Polish)
```

---

## 16. Risk Register

| ID | Risk | Severity | Probability | Mitigation |
|----|------|----------|------------|------------|
| R1 | Terminal WebGL context exhaustion (8-16 limit) | High | High | DOM renderer for hidden terminals, WebGL for visible only. Max 4 WebGL terminals. |
| R2 | Monaco global state with multiple editors | High | High | Single DiffEditor instance, swap models on selection. Never create >1 editor. |
| R3 | AG-UI multi-agent gap causes protocol workarounds | Medium | High | Orchestrator pattern: single AG-UI stream with agentId routing. Custom middleware layer. |
| R4 | SSE buffering by reverse proxies | Medium | Medium | Document Nginx config requirements. Test with proxy in CI. |
| R5 | Tauri v2 ecosystem blocks critical feature | Medium | Low | Frontend is pure React — can wrap in Electron if needed. Rust backend uses HTTP, not Tauri-specific APIs. |
| R6 | @dnd-kit cascading re-renders at scale | Medium | Medium | React.memo + Zustand selectors. Performance test at 50+ cards. |
| R7 | Langfuse self-hosting resource footprint | Medium | Medium | Start with Langfuse Cloud. Self-host only when scale justifies 40GB+ RAM. |
| R8 | hcom detection-only (no prevention) | Medium | High | Build pre-write validation layer. hcom is alerting fallback, not primary defense. |
| R9 | AG-UI interrupt bugs (#1809, #2315, #2939) | Medium | Medium | Monitor CopilotKit releases. Build fallback REST-based approval flow. |
| R10 | 50ms SSE batch window feels sluggish | Low | Medium | Tune dynamically: 16ms for active user, 50ms for background, 200ms for idle. |

---

## 17. Success Criteria

### Functional
- [ ] Display 20 simultaneous agent processes with real-time status updates
- [ ] Live DAG visualization animates state transitions in <300ms
- [ ] Terminal output streams with <100ms latency for visible agents
- [ ] QA gate approval flow works end-to-end (block → review → approve/reject → resume)
- [ ] Dashboard recovers from network disconnect within 5 seconds (SSE auto-reconnect + state snapshot)
- [ ] Block layout persists across app restarts
- [ ] All 11 block types render and receive data correctly

### Performance
- [ ] 60 FPS with 20 active DAG nodes and 4 visible terminals
- [ ] <200MB memory with 20 agents (terminal buffers at 5K lines each)
- [ ] <1s app startup (Tauri v2)
- [ ] <100ms panel switch (lazy loading)
- [ ] <50ms event-to-render latency (SSE → store → component)

### Quality
- [ ] Zero file ownership violations in 100-build test
- [ ] QA gate correctly blocks on scores <2, auto-approves on ≥3
- [ ] Audit trail captures all state changes with before/after values
- [ ] E2E test suite covers all 11 block types + approval flow

---

## 18. Open Questions

| # | Question | Impact | Decision Needed By |
|---|----------|--------|-------------------|
| Q1 | Should the web deployment target be a separate Next.js app or the same React app served via Tauri's built-in HTTP server? | Architecture | Phase 1 |
| Q2 | Do we need PTY multiplexing (node-pty) or is stdout/stderr pipe capture sufficient for Claude Code agents? | Process management | Phase 3 |
| Q3 | Should the reactions system live in the Rust backend or as a TypeScript module in the frontend? | Code organization | Phase 7 |
| Q4 | What's the maximum number of agents we should design for? 20? 50? 200? | Performance targets | Phase 1 |
| Q5 | Should we support agent-to-agent direct messaging or always mediate through the orchestrator? | Communication design | Phase 3 |
| Q6 | Is Langfuse Cloud acceptable for initial deployment or must everything be local? | Observability | Phase 6 |
| Q7 | Should we adopt CopilotKit's React SDK or build a lighter AG-UI client from the protocol spec? | Frontend dependency | Phase 3 |

---

## 19. Glossary

| Term | Definition |
|------|-----------|
| **AG-UI** | Agent-User Interaction Protocol — standardized event-based communication between AI agents and frontends |
| **Block** | A typed, self-contained UI view unit in the dashboard (terminal, DAG, logs, diff, etc.) |
| **Block Registry** | Map of block type IDs to their ViewModel/Component definitions |
| **DAG** | Directed Acyclic Graph — visual representation of task dependencies |
| **Gate** | A quality checkpoint that blocks build progress until criteria are met |
| **Interrupt** | AG-UI mechanism where an agent pauses execution and requests human input |
| **Jotai** | Atomic state management library for per-block reactive state |
| **Reactions** | YAML-configured automated responses to events (CI failure, QA rejection) |
| **SSE** | Server-Sent Events — unidirectional HTTP streaming protocol |
| **State Snapshot** | Full orchestrator state sent every 5 seconds for self-healing |
| **Zustand** | Lightweight state management for global app state |

---

## 20. Document Index

| Document | Purpose |
|----------|---------|
| `00-master-architecture-spec.md` | This document — system-level architecture |
| `01-phase-foundation-shell.md` | Phase 1: Tauri v2 + block registry + state + SSE |
| `02-phase-core-visualization.md` | Phase 2: Agent-output, DAG, log-viewer blocks |
| `03-phase-agent-communication.md` | Phase 3: AG-UI adapter, Rust process manager, streaming |
| `04-phase-approval-quality-gates.md` | Phase 4: Interrupt flow, Aegis gates, approval queue |
| `05-phase-code-review-contracts.md` | Phase 5: DiffEditor, contract compliance, file tree |
| `06-phase-observability-coordination.md` | Phase 6: Langfuse, hcom, file ownership |
| `07-phase-extensibility.md` | Phase 7: Plugin slots, reactions, framework adapters |
| `08-phase-dashboard-polish.md` | Phase 8: Kanban, metrics, timeline, RBAC |
| `references/component-stack-guide.md` | React component details, gotchas, integration patterns |
| `references/ag-ui-integration-guide.md` | AG-UI protocol integration specifics |
| `references/block-architecture-guide.md` | Block registry implementation guide |
| `references/state-management-guide.md` | Zustand + Jotai patterns and optimization |
