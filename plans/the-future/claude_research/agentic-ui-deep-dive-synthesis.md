# Agentic UI Deep Dive: Unified Synthesis

**Date:** 2026-03-19
**Source:** 6 parallel research agents investigating Composio AO, Mission Control, AG-UI Protocol, Jean + Wave Terminal, React component stack, hcom + Langfuse
**Purpose:** Inform architecture decisions for the AllTheSkillsAllTheAgents orchestrator dashboard

---

## Executive Summary

After deep-diving into 10+ projects, 8+ component libraries, and 2 communication protocols, three architectural truths emerge:

1. **The stack has clear winners.** xterm.js + SSE + React Flow + Zustand + AG-UI is the backbone. No credible alternatives exist for any of these.
2. **The "agent desktop" paradigm is converging** on block/tile-based layouts with typed views, URL-addressable sessions, and progressive disclosure. Wave Terminal, Zellij, and Mission Control all point the same direction.
3. **The real unsolved problems are multi-agent multiplexing and firehose management at scale.** Displaying 20 agents is manageable. 200 is not. No existing tool handles this well.

**The gap worth filling** — a live animated DAG showing agent state transitions with progressive-disclosure drill-down into terminal output, structured traces, and approval queues — doesn't exist in open source.

---

## Architecture Decision Record

### Decision 1: Communication Protocol — AG-UI (Adopt + Extend)

**Verdict:** Adopt AG-UI's 17 event types + interrupt lifecycle. Extend with custom events for multi-agent orchestration.

**Why:**
- 17 event types cover lifecycle, text streaming, tool calls, state sync, reasoning
- Interrupt outcome (`RUN_FINISHED` with `outcome: "interrupt"`) maps perfectly to our QA gates and approval flows
- Adopted by Google, LangChain, AWS, Microsoft, Mastra, PydanticAI
- CopilotKit provides production React hooks: `useAgent()`, `useLangGraphInterrupt()`, `useCoAgent()`
- SSE transport recommended (auto-reconnect, HTTP/2 multiplexing, unidirectional — perfect for log streaming)

**Limitations to work around:**
- Single-agent-centric — no native multi-agent multiplexing. Use orchestrator pattern or proxy multiplexing for 9+ role agents
- No batch approval — sequential interrupts only. Build custom batching for QA gate reviews
- Python/TypeScript SDK wire incompatibilities on reasoning events
- `useLangGraphInterrupt` has known issues: sometimes doesn't resume (#1809), extra null-state execution (#2315), can't resume after page reload (#2939)

**Integration pattern:**
```
React Dashboard
    ↓ AG-UI Protocol (SSE)
AG-UI Adapter Layer (converts orchestrator events → AG-UI events)
    ↓
Claude Code Orchestrator (14 phases, 9 roles, QA gates)
```

**Event mapping:**
- Skill execution → `RUN_STARTED` / `RUN_FINISHED`
- Agent output → `TEXT_MESSAGE_CONTENT` (streaming)
- Tool calls → `TOOL_CALL_START` / `TOOL_CALL_ARGS` / `TOOL_CALL_RESULT` / `TOOL_CALL_END`
- QA gate block → `RUN_FINISHED` with `outcome: "interrupt"`, `reason: "quality_gate"`
- Agent state → `STATE_SNAPSHOT` / `STATE_DELTA`
- QA report → `RAW` event with `qa-report.json` payload

---

### Decision 2: Dashboard Shell — Block Architecture (Wave Terminal pattern)

**Verdict:** Adopt Wave Terminal's block registry pattern. Each dashboard view is a typed block that can be rearranged, collapsed, restored.

**Why:**
- Registry pattern maps view type strings → ViewModel + ViewComponent
- New block types (agent output, DAG, approval queue, diff viewer) require zero core changes
- `wsh`-style programmatic control lets agents push updates directly to UI blocks
- Persistent block state enables replay and audit trails
- Mission Control validates the approach: 32 panels work with lazy loading + progressive disclosure

**Block types for our dashboard:**
| Block Type | Purpose | Data Source |
|------------|---------|-------------|
| `agent-output` | Live terminal/log per agent | SSE stream per agent |
| `dag-visualization` | Task graph with agent status badges | Zustand store, React Flow |
| `approval-queue` | QA gate violations, approve/reject | AG-UI interrupt events |
| `contract-compliance` | OpenAPI endpoint compliance, security checks | Contract auditor output |
| `diff-viewer` | Agent code changes for review | Monaco DiffEditor |
| `metrics` | Tokens/sec, cost/task, latency | Recharts + SSE |
| `kanban` | Agent state columns | @dnd-kit + Zustand |
| `file-tree` | Files being modified by agents | react-arborist |
| `timeline` | Execution history swim lanes | react-calendar-timeline |

**Progressive disclosure (3 layers):**
- Layer 1: Index (~800 tokens for 50+ items) — agent name, status, brief task
- Layer 2: Details on click — current step, reasoning log, tools being used
- Layer 3: Deep dive on demand — full trace, token usage, raw API calls, performance metrics

---

### Decision 3: Desktop Shell — Tauri v2 over Electron

**Verdict:** Tauri v2 (Rust backend + React frontend) for desktop shell. Pure web as secondary target.

**Why:**
- 30-50MB memory idle vs Electron's 200-300MB
- <0.5s startup vs 1-2s
- Rust backend: type-safe orchestration, Tokio async runtime, no GC pauses
- Jean proves Tauri v2 + React 19 is production-ready
- Can run agents as local background threads (no network latency)
- System tray integration for background monitoring

**Trade-off:** Smaller plugin ecosystem than Electron. Worth it for the 5-10x memory savings when monitoring 20+ agents.

**Fallback:** Pure web (Next.js + SSE) works as secondary deployment target for remote access. Jean demonstrates this pattern with built-in HTTP server + WebSocket.

---

### Decision 4: State Management — Zustand (app) + Jotai (blocks)

**Verdict:** Hybrid approach. Zustand for global app state, Jotai atoms for per-block reactive state.

**Why:**
- React Flow uses Zustand internally — natural integration
- Zustand selectors with `useShallow` prevent cascading re-renders
- Jotai atoms give each block independent state (Wave Terminal's proven approach)
- Both are lightweight (~1KB each)

**Data flow:**
```
SSE Events → batch into 50ms windows → Zustand store → selective selectors → affected components re-render
                                      → Jotai atoms → per-block state updates
```

**Critical optimization:** `React.memo()` on all custom React Flow nodes + Zustand selectors with shallow comparison. Without this, moving one node re-renders ALL nodes.

---

### Decision 5: React Component Stack

| Use Case | Library | Confidence | Critical Gotcha |
|----------|---------|------------|-----------------|
| DAG visualization | React Flow + dagre | 99% | Must `React.memo` custom nodes |
| Layout panels | react-resizable-panels | 98% | None significant |
| Terminal emulation | react-xtermjs | 95% | **Max 8-16 WebGL contexts** — visible terminals get WebGL, rest get DOM |
| Log streaming | @melloware/react-logviewer | 98% | Virtua-based virtual scroll handles 100MB+ |
| Code diffs | @monaco-editor/react | 97% | **Single instance only** — swap models, don't create editors |
| File tree | react-arborist | 95% | Virtualized to 10K+ nodes |
| Task kanban | @dnd-kit | 95% | All items re-render on drag — needs `React.memo` |
| Notifications | sonner | 99% | 13M downloads/week, used by Cursor/Vercel |
| Metrics charts | recharts | 98% | Keep rolling window <10K points |
| Animations | Motion (Framer Motion) | 99% | GPU-accelerated, 120fps |
| State (app) | Zustand | 99% | React Flow uses it internally |
| State (blocks) | Jotai | 95% | Wave Terminal's proven approach |

**Memory budget for 20 agents:** 22-160MB (safe). Terminal buffers dominate at 1-5MB each.

**Performance ceiling:** 60 FPS at 50 DAG nodes with memoization. 4 visible terminals at 30 FPS each (main-thread I/O limited). SSE batching at 50ms prevents jank from 100+ events/sec.

---

### Decision 6: Streaming Architecture — SSE + REST Hybrid

**Verdict:** SSE for server→client streaming, REST for control commands, WebSocket only for interactive terminals.

**Why:**
- Composio AO validates: SSE + 5-second full refresh is both low-latency AND self-healing
- SSE auto-reconnects with `Last-Event-ID` — no custom reconnection logic
- Works with HTTP/2 multiplexing (critical for 20+ simultaneous streams)
- The entire LLM industry converged on SSE (OpenAI, Anthropic, Composio AO)

**Architecture:**
- SSE: Agent logs, traces, state updates (unidirectional, auto-reconnect)
- REST: Pause/resume/cancel agents, approve/reject gates (bidirectional, stateless)
- WebSocket: Interactive terminal sessions only (xterm.js requires bidirectional)

**Production caveat:** Nginx buffers SSE by default — requires `proxy_buffering off` and `chunked_transfer_encoding off`.

---

### Decision 7: Observability — Langfuse + hcom

**Verdict:** Langfuse for hierarchical trace visualization, hcom for inter-agent coordination and collision detection.

**Langfuse (observability):**
- OpenTelemetry-native OTLP endpoint
- Multi-agent tracing via shared `trace_id` — all agents appear in single hierarchical tree
- Async SDK batching: ~0.1ms overhead
- Self-hosting is heavy (16 CPU, 40GB+ RAM for HA) — consider cloud for smaller deployments

**hcom (coordination):**
- Collision detection: 20-30s window when two agents touch same file
- Agent lifecycle management: spawn, fork, resume, kill
- Transcript sharing across agents
- Limitation: detection-only, no locking — we must add file ownership enforcement

**Integration:**
```
Orchestrator (generates shared trace_id)
    ├→ Agent A: Langfuse spans (trace_id) + hcom events (file edits)
    ├→ Agent B: Langfuse spans (trace_id) + hcom events (file edits)
    └→ Unified View: Langfuse traces + hcom collision alerts + file ownership overlay
```

---

### Decision 8: Quality Gates — Aegis-Inspired + QA Report

**Verdict:** Adopt Mission Control's Aegis pattern for our existing QA gate.

**Aegis 4-layer evaluation maps to our system:**
| Aegis Layer | Our Equivalent |
|-------------|---------------|
| Output Layer | QA report: has result, valid schema |
| Trace Layer | Contract conformance score |
| Component Layer | Security score |
| Drift Layer | Performance baseline comparison |

**Automation rules:**
- All scores ≥ 3 → auto-approve (AG-UI `RUN_FINISHED` with `outcome: "success"`)
- Any score < 2 → auto-reject (AG-UI `RUN_FINISHED` with `outcome: "error"`)
- Scores 2-3 → human review (AG-UI `RUN_FINISHED` with `outcome: "interrupt"`, `reason: "quality_gate"`)

---

### Decision 9: Plugin Architecture — 8 Swappable Slots (Composio AO)

**Verdict:** Adopt Composio AO's plugin architecture pattern.

**Slots for our system:**
| Slot | Default | Alternatives |
|------|---------|-------------|
| Runtime | tmux | docker, k8s, process, worktree |
| Agent | claude-code | codex, aider, gemini-cli |
| Workspace | git-worktree | clone, container |
| Tracker | github-issues | linear, jira |
| SCM | github | gitlab, bitbucket |
| Notifier | desktop | slack, discord, webhook |
| Dashboard | tauri-web | web-only, terminal-only |
| Observability | langfuse | jaeger, datadog, console |

**Pattern:** Interface-based TypeScript, registry resolution at runtime. Convention-over-configuration — auto-detect defaults, override via YAML.

---

### Decision 10: Reactions System (Composio AO)

**Verdict:** Steal Composio AO's declarative YAML reactions. 84.6% CI self-correction rate proves the approach.

**For our system:**
```yaml
reactions:
  ci-failed:
    auto: true
    action: send-to-agent
    retries: 2
    escalateAfter: 2

  qa-gate-failed:
    auto: true
    action: fix-and-revalidate
    retries: 3
    escalateAfter: 3

  contract-mismatch:
    auto: false
    action: notify-orchestrator
    escalateAfter: 0  # always human
```

---

## Patterns to Steal (Summary)

| Source | Pattern | Why |
|--------|---------|-----|
| Composio AO | Plugin architecture (8 slots) | Everything swappable from day one |
| Composio AO | SSE + 5-sec refresh hybrid | Low-latency + self-healing |
| Composio AO | Reactions system (YAML) | 84.6% CI self-correction |
| Composio AO | Planner/Executor separation | Cost-effective dual-layer |
| Composio AO | Git worktree isolation | One agent = one branch = one PR |
| Mission Control | 32-panel lazy loading | Progressive disclosure at scale |
| Mission Control | Aegis quality gates (4-layer) | Automated review with human escalation |
| Mission Control | Framework adapter pattern | Normalized agent interface |
| Mission Control | SHA-256 bidirectional sync | Efficient disk ↔ database change detection |
| Mission Control | RBAC (Viewer/Operator/Admin) | Security model for dashboard |
| AG-UI | 17 event types | Standardized agent↔frontend communication |
| AG-UI | Interrupt outcome for HITL | QA gates as first-class protocol events |
| AG-UI | CopilotKit React hooks | Production-ready useAgent, useLangGraphInterrupt |
| Wave Terminal | Block registry pattern | Dynamic view types without core changes |
| Wave Terminal | `wsh` CLI programmatic control | Agents push data to specific UI blocks |
| Wave Terminal | WOS persistent block state | Replay, audit, session restore |
| Jean | Tauri v2 + Rust backend | 5-10x lighter than Electron |
| Jean | Magic commands + model routing | Templatized prompts with model selection |
| hcom | Collision detection (20s window) | File edit conflict alerting |
| hcom | Agent lifecycle management | spawn/fork/resume/kill |
| Langfuse | Multi-agent tracing (shared trace_id) | Single hierarchical tree across all agents |
| Langfuse | OpenTelemetry OTLP endpoint | Standards-based, vendor-neutral |

---

## What Nobody Has Built Yet (Our Opportunity)

1. **Live animated DAG** showing agent state transitions with progressive-disclosure drill-down into terminal output, structured traces, and approval queues
2. **Multi-agent multiplexing over AG-UI** — 20+ agents streaming events simultaneously with intelligent aggregation
3. **File ownership enforcement** integrated with collision detection (hcom detects, we prevent)
4. **Contract-first UI** — dashboard driven by typed integration contracts, not ad-hoc wiring
5. **QA gate visualization** — real-time scoring dashboard with auto-approve/reject/escalate based on Aegis-style 4-layer evaluation
6. **Firehose management at 200+ agents** — exception-based alerts + AI-generated summaries + semantic grouping + confidence indicators

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Terminal WebGL context exhaustion (8-16 limit) | High | DOM renderer for invisible terminals, WebGL for visible only |
| Monaco global state with multiple editors | High | Single instance, swap models on selection |
| SSE buffering by reverse proxies | Medium | `proxy_buffering off` in Nginx config |
| AG-UI multi-agent gap | Medium | Orchestrator pattern: single AG-UI stream, multiplex internally |
| Langfuse self-hosting resource footprint | Medium | Start with cloud, self-host when scale justifies 40GB+ RAM |
| @dnd-kit cascading re-renders | Medium | Aggressive `React.memo` + Zustand selectors |
| Tauri ecosystem maturity | Low-Medium | Fallback to Electron if Tauri blocks progress |
| hcom single-machine focus | Low | Sufficient for our use case; MQTT relay if needed |

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-3)
- Set up Tauri v2 + Rust + React project
- Implement block registry (Wave Terminal pattern)
- Create core block types: agent-output, dag-visualization, approval-queue
- Wire SSE streaming with AG-UI event adapter
- Zustand store + Jotai atoms for state management

### Phase 2: Agent Integration (Weeks 4-6)
- Agent subprocess management in Rust
- AG-UI interrupt flow for QA gates
- React Flow + dagre for live DAG visualization
- xterm.js terminals with WebGL/DOM switching
- Plugin slots (runtime, agent, workspace)

### Phase 3: Observability + Quality (Weeks 7-9)
- Langfuse integration (shared trace_id across agents)
- hcom collision detection + file ownership enforcement
- Aegis-style quality gates (4-layer evaluation)
- @melloware/react-logviewer for structured log streaming
- Reactions system (YAML-declarative automation)

### Phase 4: Polish + Scale (Weeks 10-12)
- 32-panel progressive disclosure (Mission Control pattern)
- Monaco DiffEditor for agent code review
- Kanban board for agent state tracking
- Performance optimization (batch SSE, memoize everything)
- RBAC (Viewer/Operator/Admin)
- E2E testing at 20+ agents

---

## Source Material

All research produced by 6 parallel agents on 2026-03-19:

1. **Composio AO** — Plugin architecture, SSE streaming, reactions, worktree isolation, planner/executor separation
2. **Mission Control** — 32-panel architecture, Aegis quality gates, framework adapters, SHA-256 sync, RBAC
3. **AG-UI Protocol** — 17 event types, interrupt lifecycle, CopilotKit hooks, transport architecture
4. **Jean + Wave Terminal** — Tauri v2, block registry, `wsh` CLI, persistent block state, magic commands
5. **React Component Stack** — React Flow, dagre, react-resizable-panels, xterm.js, Monaco, @dnd-kit, sonner, recharts, Motion, Zustand
6. **hcom + Langfuse** — Collision detection, agent lifecycle, OpenTelemetry tracing, multi-agent sessions, async SDK batching

Base research: `plans/the-future/claude_research/agentic-ui-landscape.md`
