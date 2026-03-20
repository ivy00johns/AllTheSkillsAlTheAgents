# The complete landscape of agentic UI: terminals, dashboards, and everything between

**xterm.js is the undisputed foundation for browser terminals, React Flow dominates workflow visualization, and SSE beats WebSockets for log streaming — but no unified multi-agent dashboard standard exists yet.** The ecosystem is fragmenting rapidly across desktop orchestrators (Dorothy, Jean, Mozzie, VibeGrid), web dashboards (Composio AO, Mission Control), and commercial platforms (Devin, Cursor, Factory Droids), each reinventing the same core patterns. The critical gap is a purpose-built system that bridges CLI agent output to web UIs at scale — displaying 20+ simultaneous agent processes with live DAG state, structured traces, and human-in-the-loop approval flows. This report maps every building block, from low-level PTY multiplexing to high-level agent OS concepts, with concrete npm packages, architectural patterns, and integration guidance.

---

## Terminal-in-browser: xterm.js has no real competitor

**xterm.js** (~19,500 GitHub stars, **1.94M weekly npm downloads**) powers every major browser terminal implementation — VS Code, Replit, JupyterLab, Gitpod, Codespaces, Azure Cloud Shell, Portainer, and 100+ products. The v6 release reduced bundle size 30% (379KB → 265KB) while maintaining full VT100/xterm emulation.

The architecture spans four layers: a platform-agnostic escape sequence parser at the foundation, core terminal logic (buffers, input handling) in the middle, browser integration (DOM, viewport, accessibility) above that, and a stable public API on top. Data flows from `Terminal.write()` through the parser's state machine into buffer updates, then to the rendering service. Three rendering strategies exist — DOM (universal fallback), Canvas2D (`@xterm/addon-canvas`), and **WebGL** (`@xterm/addon-webgl`, recommended for production). The WebGL renderer uses a GPU texture atlas that caches rendered glyphs, delivering **5–35 MB/s processing throughput**.

For multi-agent systems, the critical constraint is that xterm.js is **100% main-thread bound**. Practical limits are **4–8 simultaneously visible and active terminals** before noticeable FPS degradation. Each terminal with 5,000 lines of scrollback consumes ~34MB. Worker isolation was explored (Issue #3368) but deemed a 30%+ rewrite effort. The pragmatic solution combines several patterns:

- Use `@xterm/headless` for off-screen agent terminals (no rendering cost)
- Only render terminals visible in the current viewport
- Use the `@xterm/addon-serialize` to capture/restore state when switching views
- Enforce `terminal.dispose()` rigorously — DOM listener leaks are a documented issue (Issue #1518)
- Monitor WebGL context limits (browsers cap at 8–16 contexts)

The standard server-side integration uses **node-pty** to spawn pseudo-terminals, with WebSocket carrying bidirectional terminal I/O. Replit's production architecture goes further: they maintain a **custom Rust PTY library** (`@replit/ruspty`) plus server-side `@xterm/headless` instances that let both the AI agent and user "see" terminal state simultaneously. This headless-on-server + rendered-in-browser pattern is the gold standard for agent-aware terminals.

The official addon ecosystem includes **11 packages**: Attach (WebSocket binding), Fit (auto-sizing), Web Links (clickable URLs), Search (buffer text search), WebGL (GPU rendering), Canvas (fallback), Unicode11 (extended width characters), Image (Sixel/iTerm2 inline images), Serialize (buffer export), Clipboard (OSC 52), and Ligatures. Custom addons implement a simple `ITerminalAddon` interface with `activate()` and `dispose()`.

**Alternatives are effectively nonexistent.** hterm (Chromium project) is tightly coupled to Chrome OS's Secure Shell extension — extractable but awkward, with minimal community. JupyterLab's terminal is just xterm.js with Jupyter WebSocket messaging. VS Code's terminal is upstream xterm.js with heavy IDE-specific modifications, not extractable. The only notable newer project is **DomTerm**, which can use either xterm.js or its own native renderer and supports detachable sessions.

---

## Multi-terminal web UIs and the tools that share terminals

Three categories of web terminal tools exist, each with different architectural approaches and integration potential for agent orchestration.

**Single-terminal sharing tools** represent the simplest tier. **ttyd** (~8K stars) is a C binary using libwebsockets + xterm.js that serves a terminal over HTTP with binary WebSocket frames — extremely lightweight but one command per instance. **WeTTY** (~4K stars) is Node.js + Socket.IO + xterm.js, SSH-focused, heavier but embeddable as a library. **GoTTY** (~18K stars, largely unmaintained) spawned the category — Julia Evans' **multi-gotty** fork demonstrates per-URL-path routing to different sessions, a pattern directly applicable to agent-per-URL architectures. For any of these, multi-terminal requires running multiple instances behind a reverse proxy or embedding multiple iframes.

**Terminal multiplexers with web clients** are far more interesting. **Zellij** (~23K stars) added a **built-in web client in v0.43.0** that is architecturally sophisticated: a single web server per machine serving multiple sessions to multiple clients, with browser clients appearing as regular Zellij users. The implementation uses **dual WebSocket channels** — one for terminal STDOUT/STDIN bytes, another for control messages (resize, config, session switching) — preventing blocking on heavy output. Sessions are URL-addressable (`https://127.0.0.1:8082/<session-name>`), meaning agent sessions become bookmarkable. Zellij's KDL layout files, WASM plugin system, floating/stacked panes, and session resurrection make it the most promising existing tool for direct integration as an agent terminal backend.

**Process output dashboards** solve the multi-process display problem without full terminal emulation. **mprocs** (~4K stars, Rust) runs multiple commands in parallel with a process list sidebar and switchable output panes — each process gets its own PTY. It exposes a **remote control TCP server** (`--server 127.0.0.1:4050`) accepting YAML commands, enabling programmatic orchestration. This sidebar-plus-detail-pane pattern maps directly to an agent fleet dashboard. **stmux** (Node.js) offers a layout DSL for terminal splitting and built-in error detection with system notifications. **Logdy** is a Go binary that captures any stdin/stdout and serves a reactive Vue.js web UI via WebSocket — pipe any command output through it for instant web visualization with JSON parsing, filtering, and search.

For React-based multi-terminal layouts, the split pane libraries are critical. **react-resizable-panels** (by Brian Vaughn, React core team) provides the most flexible API with pixel/percentage/rem sizing, collapsible panels, nested groups, and layout persistence. **allotment** (~3.7K stars) is derived directly from VS Code's split view code, making it the closest match for VS Code-like behavior. Both support dynamic pane addition/removal needed for spawning/destroying agent terminal panels.

---

## The emerging agent orchestration dashboard landscape

A new category of desktop orchestrators exploded in 2025–2026, each attacking the "manage multiple AI coding agents simultaneously" problem from a slightly different angle.

**Composio Agent Orchestrator** (3,100+ stars) has the most mature web dashboard. Built as a monorepo with `packages/core`, `packages/cli`, and `packages/web` (Next.js), it uses **SSE via `/api/events`** with a `useSessionEvents` hook that merges lightweight SSE patches with full session objects every 5 seconds. Terminal access per agent uses xterm.js over WebSocket. The architecture features **8 swappable plugin slots** (Runtime: tmux/docker/k8s; Agent: claude-code/codex/aider; Workspace: worktree/clone; Tracker: github/linear; etc.), with a Reactions system that automatically responds to GitHub events — CI failures get injected into agent sessions for self-correction (achieving **84.6% CI self-correction rate** in dogfooding). The dashboard displays Kanban-like lanes: Working, Pending, Review, Merge.

**Jean** (by the Coolify team, Apache 2.0) stands out for its **Tauri v2 + React 19 + Rust** architecture — dramatically lighter than Electron alternatives. It integrates xterm.js terminals, CodeMirror 6, a diff viewer (unified and side-by-side), file tree with preview, and AI chat with model selection. Critically, it includes a **built-in HTTP server + WebSocket** for remote web access, meaning it can be used from any browser via localhost, Cloudflare Tunnel, or Tailscale. Magic commands handle GitHub issue investigation, code review with finding tracking, merge conflict resolution, and PR generation.

**Dorothy** (MIT, 5 stars — very early) takes a maximalist approach: MCP-based orchestration with 40+ tools across 5 MCP servers, a Kanban task board with automatic agent assignment by skill, a 3D animated office visualization, Telegram/Slack remote control, GitHub/Jira polling for autonomous task spawning, and cron scheduling. **Mozzie** (open source, Electron) introduces a sophisticated **work item state machine** (`draft → ready → running → review → done → archived`) with dependency tracking, rejection feedback loops, and git worktree isolation per work item. **VibeGrid** (open source, Electron) differentiates with headless mode (agents run without visible terminal, full output capture), always-on-top status overlays, and workflow chaining with triggers.

**Mission Control** (1,800+ stars, MIT) is the most purpose-built agent fleet dashboard: Next.js + SQLite + WebSocket/SSE, with **31 panels**, 98 API routes, and 460 tests. It includes a memory knowledge graph visualization, six-column Kanban board, quality gates (Aegis) with automated review, multi-gateway with OS-level agent discovery, and framework adapters for OpenClaw, CrewAI, LangGraph, AutoGen, and Claude SDK. RBAC with viewer/operator/admin roles, audit trail, CSRF/CSP protections, and bidirectional GitHub Issues sync make it production-ready.

**AgentMux** ($29 one-time purchase) is the simplest — pure tmux with status indicators, batch commands, and mobile monitoring. **Supacode** is macOS-native (likely Swift). **hcom** provides cross-terminal agent messaging via Python + SQLite with collision detection (two agents editing same file within 20s triggers alerts), transcript reading, PTY screen viewing, event subscriptions, and a TUI dashboard — the most sophisticated inter-agent communication layer available.

---

## Workflow and DAG visualization for live agent state

**React Flow** (~35,600 stars) is the clear winner for agent task graph visualization. Nodes are plain React components — anything renderable in React can live inside a node, including progress bars, status indicators, live metrics, and even embedded terminals. The library uses **virtualized rendering** (only visible nodes hit the DOM) and Zustand internally for state management. Updating node `data` props triggers standard React re-renders, making live state updates natural.

The recommended integration for an agent DAG uses **dagre** (~5,300 stars, ~1M weekly npm downloads) for layout computation. Dagre implements Sugiyama-style layered layout with a dead-simple API — set graph direction, add nodes with dimensions, add edges, call `dagre.layout()`, map positions back to React Flow nodes. For compound/nested agent groups (e.g., a "research team" containing multiple sub-agents), upgrade to **elkjs** (~2,366 stars, ~1M weekly npm downloads), which supports subgraphs and offers hundreds of configuration options, though at significantly higher complexity. **d3-dag** (~1,800 stars) provides mathematically optimal layouts but is in light maintenance mode and designed for static, small-to-medium DAGs.

**Animating live state transitions** requires pairing React Flow with **Motion (formerly Framer Motion)** (~27K stars, ~33M weekly npm downloads). Since custom nodes are React components, wrapping inner content in `<motion.div>` enables declarative state-change animations — color transitions when an agent moves from "running" to "completed," scale pulses for active nodes, glow effects for agents needing attention. Motion uses the Web Animations API for 120fps performance, and its `MotionValue` updates don't trigger React re-renders. For edge animations showing data flow between agents, replace React Flow's default CSS `stroke-dasharray` animation (which causes CPU issues at 100+ edges) with custom SVG particle animations.

The data flow architecture: WebSocket events → Zustand store update → selective node data change → React Flow re-renders only affected node → Motion animates transition. Critical optimization: custom node components **must** be wrapped in `React.memo()` and declared outside the parent component, and Zustand selectors must use `useShallow` to prevent all-node re-renders on any change.

For inspiration from production orchestration platforms: **Temporal** provides the most sophisticated workflow UI with three views — Compact (linear progression with parallel stacking), Timeline (Gantt-like with duration and parallelism), and Full History (git-tree style). **Airflow** uses color-coded DAG topology (green=success, red=failed, yellow=running, gray=scheduled) with TaskGroups for hierarchical grouping. **Prefect** offers a Radar view for hierarchical task drill-down. All use polling-based updates rather than true real-time push. **No existing AI workflow tool provides true live animated DAG visualization** — this is a clear gap.

**G6 (AntV)** (~11,800 stars) deserves mention as an alternative to React Flow. Its v5.0 rewrite includes Rust+WASM layouts, WebGPU acceleration, built-in state management with automatic style transitions, and built-in animation specifications. If you don't need deep React ecosystem integration, G6 is the strongest single-library solution.

---

## Log streaming and agent trace visualization

For streaming logs from 20+ agent processes to a web UI, **SSE is the optimal protocol** — not WebSocket. Logs flow unidirectionally (server → client), SSE auto-reconnects with `Last-Event-ID` without custom logic, works with HTTP/2 multiplexing (critical for many simultaneous streams), and requires less server infrastructure than WebSocket. The entire LLM industry has converged on SSE (OpenAI, Anthropic, Composio AO all use it for streaming). For bidirectional needs (sending commands to agents), use a **hybrid approach**: SSE for log streaming + REST endpoints for control. One production caveat: Nginx buffers SSE by default — requires `proxy_buffering off` and `chunked_transfer_encoding off` configuration.

**Langfuse** (18,000+ stars, MIT, **14.8M SDK installs/month**) is the strongest open-source trace visualization platform. Self-hostable via Docker or Kubernetes (Next.js + PostgreSQL + ClickHouse), it provides hierarchical trace trees showing LLM calls, tool executions, and retriever steps with inputs/outputs/timing/costs; a timeline view for latency debugging; **agent graphs** visualizing workflows as directed graphs; and session views grouping multi-turn agentic conversations. It natively accepts OpenTelemetry traces via `/api/public/otel`, supports 50+ framework integrations, and uses custom trace IDs for grouping multi-agent executions into single traces. SDKs send tracing data asynchronously in batched background flushes with zero application latency impact.

**LangSmith** (proprietary, by LangChain) uses ClickHouse + PostgreSQL + Redis, with a `@traceable` decorator generating hierarchical run trees. **Helicone** (Apache v2.0, YC W23) takes a proxy approach — sits between app and LLM providers, adding only 50–80ms latency while capturing traces. **Arize Phoenix** (ELv2 license) is the most OTEL-native option, launches locally from pip at localhost:6006, and provides span-level visibility with embedding-based drift detection. **Braintrust** claims 80x faster queries than traditional DBs via its custom Brainstore database.

**OpenTelemetry GenAI Semantic Conventions** are rapidly maturing as the industry standard. Key span types now include `create_agent`, `invoke_agent` (with `gen_ai.agent.name`), and `execute_tool` (with `gen_ai.tool.type`). Standard attributes track model, token usage, and provider. Datadog natively supports these conventions as of v1.37+. The recommended instrumentation architecture: Agent processes export OTLP → OTel Collector → fan-out to Langfuse (AI-specific visualization), Jaeger (distributed trace debugging), Loki (log aggregation), and Prometheus (metrics).

For the React frontend, **@melloware/react-logviewer** (fork of react-lazylog) is purpose-built for streaming log display — loads from WebSocket or EventSource (SSE) sources with ANSI highlighting, virtual scrolling for performance, and auto-following via `<ScrollFollow>` HOC. **Dozzle** (18K+ stars, MIT, Go + Vue) serves as an excellent architectural reference for multi-source log viewing: SSE/WebSocket streaming, split-screen comparison, SQL queries via DuckDB WASM in-browser, and distributed agent mode via gRPC.

---

## CLI-to-web bridge: architectural patterns that scale

The core problem — taking stdout/stderr from 20+ simultaneous CLI processes and displaying them in a web UI — has three proven architectural patterns.

**Pattern A (Process Spawner + WebSocket Broadcaster)** is the canonical approach. Node.js spawns child processes via `child_process.spawn()` with `stdio: 'pipe'`, captures stdout/stderr as Readable Streams, tags each data event with `{processId, stream, data, timestamp}`, and broadcasts via Socket.io rooms. Each process ID maps to a room; clients join rooms for processes they want to watch. This pattern works for non-interactive agents (most AI agents) and scales well with a ring buffer per process (last 1,000–5,000 lines) for instant history on client subscribe. Batch small messages over 16–50ms windows to reduce WebSocket overhead.

**Pattern B (PTY Multiplexing)** is needed for full terminal emulation with ANSI codes, cursor control, and interactive programs. VS Code's production architecture provides the reference: a **dedicated Pty Host process** (separate Node.js process running all PTY instances) isolates shell I/O from the renderer, preventing misbehaving processes from freezing the UI. Named IPC channels handle communication. For remote development, a `RemoteTerminalBackend` communicates with a remote agent's `PtyService`, and `@xterm/headless` maintains terminal state for reconnection via `SerializeAddon`. The local echo optimization renders keystrokes dimmed before server confirmation when latency exceeds 30ms.

**Pattern C (Event Bus Decoupling)** scales to multi-server deployments. Each agent process publishes output to **Redis Pub/Sub** (fire-and-forget for real-time display) and **Redis Streams** (persistent, replayable history for reconnection). WebSocket servers subscribe to Redis channels using `PSUBSCRIBE agent:*` for dynamic agent discovery. Socket.io with `@socket.io/redis-adapter` handles multi-server broadcasting natively. On client reconnect, missed history is fetched from Redis Streams via `XRANGE`. NATS is a lighter alternative for pub/sub-only scenarios with subject-based routing (`agents.{id}.stdout`).

Key reference implementations to study: **Dockge** (Node.js/TypeScript + Vue + Socket.io) for reactive process management with real-time streaming. **Logdy** (Go binary + Vue) for instant stdout-to-web-UI streaming — supports multiple input modes including multi-port listening where each port maps to a different process. **pm2-gui** for monitoring ~100 Node.js processes via Socket.io + RPC. **Kubetail** for Kubernetes log streaming with WebSocket + container lifecycle tracking.

---

## React components: the complete toolkit for agent UIs

A well-composed agent dashboard draws from specific component categories, each with a clear winner.

**Terminal rendering**: `react-xtermjs` (Qovery) provides a `<XTerm>` component and `useXTerm()` hook supporting all xterm.js addons. For non-terminal agent output, `react-terminal-ui` is a zero-dependency "dumb component" where you manage state externally via `<TerminalOutput>` children.

**Streaming text**: **flowtoken** provides purpose-built LLM streaming animations (fadeIn, blur-in, typewriter, word pull-up, flip text) with an `AnimatedMarkdown` component that integrates directly with Vercel AI SDK's `useChat`. **prompt-kit** adds a `ResponseStream` component with "type" and "fade" modes, plus a `useTextStream` hook. **Vercel AI Elements** (March 2025) provides 25+ shadcn/ui-based components including `<Conversation>`, `<Message>`, `<MessageResponse>` (optimized for streaming markdown), `<Tool>` (loading states for tool calls), and `<Reasoning>` (collapsible thinking blocks).

**Layout**: **react-resizable-panels** (Brian Vaughn) supports deeply nested layouts with pixel-based sizing, collapsible panels, and `onLayoutChanged` for persistence. For VS Code-exact behavior, **allotment** derives directly from VS Code's split view code.

**Task management**: **@dnd-kit/core + @dnd-kit/sortable** is the modern standard — hooks-based API with multiple sensor types, collision detection algorithms, and full React 18+ compatibility. Each agent state ("Queued," "Running," "Completed," "Failed") maps to a sortable column.

**Execution timelines**: **react-calendar-timeline** (~248K weekly downloads) renders horizontal swim-lane timelines where rows = agents and items = task executions with drag-and-drop and zoom from minutes to years. **@svar-ui/react-gantt** (MIT core) handles task dependencies with 10,000+ task performance.

**Code and diffs**: **@monaco-editor/react** (~4K stars) wraps VS Code's editor engine with zero-config setup — the `DiffEditor` component shows before/after agent code changes with syntax highlighting for 50+ languages. For streaming code output, the **stream-monaco** library provides `appendCode()` with throttling and auto-scroll. For lightweight diffs, **react-diff-viewer** (Keploy fork) renders side-by-side and unified views.

**File trees**: **react-arborist** (~3.3K stars) provides virtualized rendering for 10,000+ nodes with drag-and-drop, inline renaming, multi-selection, and fully customizable node rendering — add git-status-like indicators showing which files agents are modifying in real-time.

**Agent chat/interaction**: **CopilotKit** (~32K stars) is the full-stack framework — provider wrapper, chat/sidebar/popup components, `useCopilotAction()` for frontend actions with generative UI, `useCoAgent()` for shared state between app and agent, and the AG-UI protocol with 16 real-time event types. **assistant-ui** (YC-backed) provides Radix-style composable primitives — message lists, composers, thread management with branching, attachment handling, and streaming text with auto-scroll. CopilotKit gives you the full agent framework; assistant-ui gives you the best chat UI primitives.

**Notifications and status**: **sonner** (~2KB, zero dependencies) for stacked toasts with promise-based patterns. **recharts** for real-time metrics charts (tokens/sec, cost/task). **XState** with `@statelyai/inspect` for state machine visualization of agent workflows.

---

## How commercial platforms display agent work

The commercial agent platforms reveal convergent UI patterns worth studying.

**Devin** (Cognition, ~$4B valuation) runs each task in an **isolated cloud VM** with a multi-pane display showing the agent's terminal, code editor, and browser simultaneously with <50ms latency via gRPC/WebSocket. Parent/child sessions nest in a sidebar. Devin Review groups PR changes logically rather than file-by-file. The shift from "fully autonomous" to "agent-native IDE" reflects the industry learning that developers want to observe and guide, not just delegate.

**Cursor** (AI-first VS Code fork) treats agents as **managed resources** visible in a sidebar — each with status, running plan, and accessible traces. Background Agents run in isolated worktrees triggered from GitHub/Slack/Linear. The aggregated diff view consolidates multi-file changes into a single reviewable surface. **Cursor Hooks** implement enforcement points: before MCP execution (allow/warn/deny/step-up approval), after command runs (audit). MCP Apps support renders interactive UIs directly in chat — charts from Amplitude, diagrams from Figma.

**Cosine's Genie** explicitly rejected forking VS Code, arguing legacy IDE architecture wasn't designed for AI agents that batch tasks and reason across entire codebases. Their purpose-built platform supports asynchronous delegation — assign via web/Slack/CLI/Jira, Genie works independently, user reviews output. Multi-agent mode decomposes tasks into subtasks with inter-agent communication.

**Factory's Droids** uses a three-column web interface (session, context, history) with specialized Droids (Code, QA) and custom Droid definitions via `.factory/droids/` markdown files with YAML frontmatter. The diff-based review pattern with agent reasoning alongside changes is strong, though reviewers criticized the interface for exposing too much complexity.

**Claude's computer use** runs in Docker containers with virtual X11 display (Xvfb + Mutter), using a screenshot-action loop where the agent sees screenshots, plans actions, executes, and re-evaluates. The key architectural innovation is treating the entire desktop as an API surface via `computer`, `str_replace_editor`, and `bash` tools.

---

## Human-in-the-loop and the AG-UI protocol

CopilotKit's **AG-UI Protocol** (adopted by Google, LangChain, AWS, Microsoft, Mastra, PydanticAI) defines the emerging standard for agent-frontend communication with **16 real-time event types**. The interrupt-aware lifecycle works as follows: an agent sends a `RUN_FINISHED` event with `outcome: "interrupt"` containing a payload describing what needs approval. The frontend renders an approval component. The user responds via `RunAgentInput` with a resume payload. In React, `useLangGraphInterrupt()` provides a declarative API — supply a condition and a render function that receives the event and a `resolve` callback.

Five approval workflow patterns have emerged across the ecosystem:

- **Inline approval cards** embedded in chat (CopilotKit, Devin): agent action summary with Accept/Reject buttons
- **Diff-based review** (Cursor, Factory): show exactly what will change, let users modify before approving
- **Queue-based aggregation** (Microsoft Agent Framework, enterprise systems): approval requests collect in a notification queue
- **Risk-graduated escalation** (Cursor Hooks): low-risk auto-approves, medium-risk shows notification, high-risk requires explicit approval
- **Timeout-based**: auto-reject or auto-approve after configurable period

**Google's A2UI** (Agent-to-UI, open-sourced December 2025) complements AG-UI by defining a format for agent-generated native UIs — agents send blueprints of native components (not opaque HTML) with renderers for Web, Flutter, and native mobile. AG-UI handles the communication pipes and state; A2UI handles what gets rendered.

---

## Wave Terminal's block architecture as an agent dashboard model

**Wave Terminal** (Apache 2.0, Go backend + TypeScript/React frontend + Electron) introduces a **block-based architecture** that maps directly to agent monitoring. Each "block" is a content unit — terminal, file preview, embedded Chromium web browser, AI chat, or code editor — arranged in a draggable tiled layout. The `wsh` CLI utility pushes data into Wave panes programmatically, meaning CI jobs or agent processes can open content in specific blocks.

The registry pattern maps view type strings to ViewModel classes. Workspaces save and restore automatically including scrollback buffers. The embedded web browser lives side-by-side with terminals — you could display a Grafana dashboard, GitHub PR, or custom React app alongside agent terminals. This architecture provides the conceptual model for an agent dashboard: replace "terminal block" with "agent output block," "browser block" with "agent web preview block," and add "DAG visualization block" and "approval queue block."

Microsoft's **Windows Agent Workspace** takes the agent desktop concept furthest: agents run in **separate Windows sessions** with per-agent accounts managed by group policy, MCP connectors registered in a Windows On-Device Registry, and visible/interruptible workspaces preventing silent automation.

---

## UX patterns that survive contact with 20+ agents

**Progressive disclosure is the defining UX pattern** for agent monitoring. The proven three-layer approach (from Anthropic's Claude Code Skills architecture): Layer 1 is an index (~800 tokens for 50+ items) showing agent name, status, and brief task description. Layer 2 is details loaded on click — current step, reasoning log, tools being used. Layer 3 is deep dive on demand — full trace, token usage, raw API calls, performance metrics. This same pattern applies to every level of the dashboard.

The "firehose problem" — too much information from too many agents — has five proven solutions. **Exception-based alerts** surface only anomalies, errors, and decision points while normal operation stays silent. **AI-generated summaries** (the multi-agent-dashboard project uses Haiku 3.5 to generate plain English summaries on task completion). **Pull-based monitoring** where users choose when to inspect rather than having every event push to screen. **Semantic grouping** where related changes are grouped logically (Devin Review groups PR changes by purpose, not by file). **Confidence indicators** highlighting uncertain actions while collapsing confident ones.

What developers actually want to see, based on patterns across successful products, follows a clear hierarchy: *Is the agent making progress?* (status indicator), *What did it change?* (diffs and file lists), *Why did it make that choice?* (reasoning transparency), *Does it need me?* (approval requests and errors), *How much did it cost?* (token and compute tracking), *Can I trust the output?* (test results and confidence scores). The **minimal viable monitoring** any agent UI needs is: status indicator (running/done/error/waiting), last action description, "needs attention" flag, and accept/reject controls.

---

## Recommended architecture for the orchestration framework

Given the existing ecosystem (OpenClaw gateway, Gastown fleet manager, Beads task memory, Composio AO parallel agents, Mastra framework, Babysitter process engine), the optimal UI architecture stacks these layers:

**Process layer**: `child_process.spawn()` for non-interactive agents, `node-pty` only for agents needing full terminal emulation. Each process wrapped in a `ManagedProcess` class emitting lifecycle events.

**Event bus**: Single-server deployments use Socket.io rooms directly (lowest latency). Multi-server deployments add Redis Pub/Sub for real-time streaming + Redis Streams for persistent history/replay on reconnect. Socket.io with `@socket.io/redis-adapter` handles multi-server broadcasting.

**Streaming layer**: SSE for server→client log/trace streaming (auto-reconnect, HTTP/2 multiplexing), REST endpoints for control commands (pause/resume/cancel), WebSocket exclusively for interactive terminal sessions (xterm.js).

**Instrumentation**: OpenTelemetry with GenAI Semantic Conventions from day one, exporting to Langfuse (self-hosted) for AI-specific trace visualization and Jaeger for distributed trace debugging.

**Frontend composition**: React with react-resizable-panels for layout, react-xtermjs for agent terminals (4–8 visible, rest headless), React Flow + dagre + Motion for live DAG visualization of Beads task graphs, @melloware/react-logviewer for streaming structured logs, @monaco-editor/react + DiffEditor for agent code changes, react-arborist for file tree, CopilotKit or assistant-ui for agent chat/interaction with HITL approval flows, @dnd-kit for task Kanban, react-calendar-timeline for execution history, recharts for metrics, and sonner for notifications.

**Block architecture** (Wave Terminal pattern): each dashboard "block" is a typed view (terminal, DAG, logs, diff, chat, metrics) that can be rearranged, collapsed, and restored. Zellij's URL-per-session pattern makes agent sessions bookmarkable and shareable.

---

## Conclusion

The agentic UI space is fragmenting fast — in 2025–2026 alone, at least 10 desktop orchestrators, 5+ commercial platforms, and dozens of component libraries emerged. Three architectural insights cut through the noise. First, **xterm.js + SSE + React Flow forms the technical backbone** — terminal emulation, log streaming, and workflow visualization all have clear, battle-tested winners. Second, **the "agent desktop" paradigm is converging** toward block/tile-based layouts with typed views, URL-addressable sessions, and progressive disclosure — Wave Terminal, Zellij's web client, and Microsoft's Agent Workspace all point the same direction. Third, **the real unsolved problems are inter-agent coordination visibility and firehose management at scale** — displaying 20 agents is manageable, 200 is not, and no existing tool handles this well.

The most immediately useful integration points for the described framework: Composio AO's plugin architecture and SSE dashboard pattern for Gastown visualization, Langfuse's OpenTelemetry-native tracing for Beads task graph observability, CopilotKit's AG-UI protocol for Babysitter's approval flows, Zellij's web client for terminal multiplexing, and Mission Control's 31-panel architecture as a reference implementation for the overall dashboard. The gap worth filling — a live animated DAG showing agent state transitions with progressive-disclosure drill-down into terminal output, structured traces, and approval queues — doesn't exist yet in open source.