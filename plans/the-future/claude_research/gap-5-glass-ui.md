# The Hive glass-ui: a definitive frontend component library guide

**The nine screens of The Hive's glass-ui require exactly 19 core npm packages, each chosen to satisfy distinct rendering demands ranging from GPU-accelerated terminal emulation to live DAG animation.** This report maps every screen to its canonical library stack as of March 2026, with version numbers, API patterns, performance boundaries, and integration code. The key architectural finding: three packages have undergone major renames since 2024 — `xterm` → `@xterm/xterm`, `reactflow` → `@xyflow/react`, and `framer-motion` → `motion` — and using the old names will pull deprecated or unmaintained code. The complete stack runs on Next.js 16.2 with React 19.2, Tailwind CSS 4.2, and Zustand 5.0, all of which shipped breaking changes from their previous major versions.

---

## 1. The Glass: GPU-accelerated terminal multiplexing at browser limits

The Glass screen demands the heaviest rendering workload in glass-ui: **4–8 concurrent PTY terminal streams**, each receiving potentially high-throughput output from agent workers. The canonical terminal emulation library is `@xterm/xterm` **v6.0.0** (published December 22, 2025), maintained by Daniel Imms at Microsoft under the `xtermjs` GitHub organization (~20,100 stars). The old `xterm` package (v5.3.0) is officially deprecated with a notice directing users to the scoped `@xterm/*` namespace.

**The renderer hierarchy matters enormously for multiplexer performance.** The WebGL renderer addon (`@xterm/addon-webgl` v0.19.0) uses GPU texture atlases for character caching, reducing CPU overhead dramatically compared to the built-in DOM renderer. The Canvas renderer (`@xterm/addon-canvas` v0.7.0) has been removed in xterm.js v6.0.0, leaving two options: WebGL for performance-critical visible terminals, and DOM as the automatic fallback. Chrome enforces a hard limit of **16 active WebGL contexts** per renderer process (8 on Android), which means The Glass's 4–8 terminal panels are safely within budget on desktop browsers but leave no room for other WebGL-consuming components on the same page.

```typescript
import { Terminal } from '@xterm/xterm';
import { WebglAddon } from '@xterm/addon-webgl';
import { FitAddon } from '@xterm/addon-fit';
import '@xterm/xterm/css/xterm.css';

const term = new Terminal({ cursorBlink: true });
const fitAddon = new FitAddon();
term.loadAddon(fitAddon);
term.open(containerElement);

try {
  const webgl = new WebglAddon();
  webgl.onContextLoss(() => webgl.dispose()); // graceful fallback
  term.loadAddon(webgl);
} catch { /* falls back to DOM renderer */ }

fitAddon.fit(); // call on every container resize via ResizeObserver
```

The `@xterm/addon-fit` (v0.11.0) is non-negotiable for responsive layouts — it recalculates terminal dimensions (cols × rows) whenever the container changes size. Pair it with a `ResizeObserver` on each panel's container element, not a window resize listener.

### Flow control prevents buffer overflow in high-throughput agents

The official xterm.js documentation prescribes a **HIGH/LOW watermark pattern** for managing output buffers. The `write()` method is non-blocking — it queues data into an internal buffer with a 50MB hard cap, beyond which data is silently discarded. For agent workers producing rapid output (build logs, test suites), implement backpressure:

```typescript
const HIGH = 100_000; // 100K chars — pause the PTY
const LOW  = 10_000;  // 10K chars — resume the PTY
let watermark = 0;

ptyProcess.onData(chunk => {
  watermark += chunk.length;
  terminal.write(chunk, () => {
    watermark = Math.max(watermark - chunk.length, 0);
    if (watermark < LOW) ptyProcess.resume();
  });
  if (watermark > HIGH) ptyProcess.pause();
});
```

For WebSocket transport between the Fastify backend and browser, this pattern extends with an ACK protocol: the client sends acknowledgment messages after processing batches, and the server tracks pending ACKs to pause/resume the underlying `node-pty` (v1.1.0, Microsoft) process.

### The multiplexer layout uses nested resizable panels

`react-resizable-panels` **v4.7.3** (~5.5M weekly downloads, maintained by Brian Vaughn, former React core team) provides the split-pane layout. Nest horizontal and vertical `PanelGroup` components to create a tmux-style grid:

```tsx
import { Panel, PanelGroup, PanelResizeHandle } from 'react-resizable-panels';

<PanelGroup direction="vertical" autoSaveId="glass-layout">
  <Panel defaultSize={50}>
    <PanelGroup direction="horizontal">
      <Panel><TerminalPane workerId="w1" /></Panel>
      <PanelResizeHandle />
      <Panel><TerminalPane workerId="w2" /></Panel>
    </PanelGroup>
  </Panel>
  <PanelResizeHandle />
  <Panel defaultSize={50}>
    <PanelGroup direction="horizontal">
      <Panel><TerminalPane workerId="w3" /></Panel>
      <PanelResizeHandle />
      <Panel><TerminalPane workerId="w4" /></Panel>
    </PanelGroup>
  </Panel>
</PanelGroup>
```

The `autoSaveId` prop persists layout ratios to localStorage. Each terminal instance consumes approximately **15–25MB** of browser memory (80×24 with 1,000-line scrollback), so 8 terminals total roughly 120–200MB. At continuous high-throughput output, expect approximately **30fps with 2 instances and 15fps with 4** due to main-thread parsing contention — xterm.js is 100% main-thread bound as of v6. For inactive terminals receiving no output, the cost is essentially zero.

**Memory management is critical for long-running sessions.** Every `useEffect` cleanup must call `terminal.dispose()`, close the WebSocket, and disconnect the `ResizeObserver`. The WebGL addon specifically had GPU memory leak issues (fixed in recent versions) that required explicit addon disposal before terminal disposal. The `@xterm/headless` package (v6.0.0) enables server-side terminal state tracking for reconnection scenarios without any DOM dependency.

The React wrapper `react-xtermjs` (v1.0.9, ~4,300 weekly downloads, Qovery) offers `useXTerm` hook and `<XTerm />` component patterns, but at ~50 lines of wrapper code, a custom hook gives more control over addon loading, WebSocket lifecycle, and cleanup — the recommended approach for production multiplexer use.

---

## 2. The Comb: live DAG visualization with animated state transitions

The Comb renders a directed acyclic graph of task dependencies with nodes that animate through lifecycle states in real time. **React Flow** (`@xyflow/react` **v12.10.1**) is the dominant React graph library with ~35,600 GitHub stars and active development by the Berlin-based xyflow team. The old `reactflow` package name is deprecated — v12 migrated to the `@xyflow/react` scope with breaking API changes.

The key v12 migration changes that affect The Comb: node dimensions moved to `node.measured.width` / `node.measured.height` (critical for dagre layout integration), the internal store renamed `nodeInternals` to `nodeLookup`, and the package requires an explicit style import from `@xyflow/react/dist/style.css`. React Flow includes built-in virtualization — only visible nodes and edges render to DOM — making it performant for 100+ node graphs with proper optimization.

### Automatic DAG layout with dagre

`@dagrejs/dagre` (the scoped, maintained package — the unscoped `dagre` v0.8.5 is 6+ years stale) computes hierarchical positions synchronously. The integration pattern creates a dagre graph, feeds in node dimensions and edge relationships, runs `dagre.layout()`, and maps the computed coordinates back to React Flow node positions:

```typescript
import dagre from '@dagrejs/dagre';
import { type Node, type Edge } from '@xyflow/react';

const getLayoutedElements = (nodes: Node[], edges: Edge[], direction = 'TB') => {
  const g = new dagre.graphlib.Graph().setDefaultEdgeLabel(() => ({}));
  g.setGraph({ rankdir: direction, nodesep: 50, ranksep: 100 });

  nodes.forEach(node => g.setNode(node.id, { width: 200, height: 60 }));
  edges.forEach(edge => g.setEdge(edge.source, edge.target));
  dagre.layout(g);

  return nodes.map(node => {
    const pos = g.node(node.id);
    return {
      ...node,
      position: { x: pos.x - 100, y: pos.y - 30 }, // center offset
      targetPosition: direction === 'LR' ? 'left' : 'top',
      sourcePosition: direction === 'LR' ? 'right' : 'bottom',
    };
  });
};
```

Dagre handles 100–500 node DAGs in sub-second time. For graphs exceeding 500 nodes, `elkjs` provides async layout computation with more sophisticated algorithms, though dagre's simplicity and synchronous API make it the default choice for typical task graphs.

### Animating node state transitions

The package formerly known as Framer Motion has rebranded to **`motion`** (v12.38.0, ~8.1M weekly downloads, ~30,600 stars). The import path changed from `framer-motion` to `motion/react`:

```tsx
import { memo } from 'react';
import { motion } from 'motion/react';
import { Handle, Position, type NodeProps } from '@xyflow/react';

const statusStyles = {
  submitted:  { bg: '#6b7280', shadow: 'none' },       // gray
  running:    { bg: '#f59e0b', shadow: '0 0 12px #f59e0b' }, // amber
  completed:  { bg: '#10b981', shadow: 'none' },       // green
  dead_brood: { bg: '#ef4444', shadow: '0 0 8px #ef4444' },  // red
};

const TaskNode = memo(({ data }: NodeProps) => {
  const style = statusStyles[data.status] ?? statusStyles.submitted;
  return (
    <motion.div
      animate={{ backgroundColor: style.bg, boxShadow: style.shadow }}
      transition={{ duration: 0.3 }}
      className="px-4 py-2 rounded-lg border border-white/10"
    >
      <Handle type="target" position={Position.Top} />
      <div className="text-sm font-mono">{data.label}</div>
      {data.status === 'running' && (
        <motion.div
          className="absolute inset-0 rounded-lg border-2 border-amber-400"
          animate={{ opacity: [1, 0], scale: [1, 1.15] }}
          transition={{ duration: 1.5, repeat: Infinity }}
        />
      )}
      <Handle type="source" position={Position.Bottom} />
    </motion.div>
  );
});
```

**Every custom node must be wrapped in `React.memo`** — this is React Flow's single most important optimization. Without it, every node re-renders on any graph state change. The `nodeTypes` object must be defined outside the component or memoized to prevent React Flow from re-registering node types on every render. For continuous pulse animations, prefer CSS `@keyframes` over Motion — CSS animations are GPU-accelerated with zero JavaScript overhead, critical when 20+ nodes might pulse simultaneously.

React Flow's `node.hidden` boolean enables progressive disclosure — completed subtask branches can be collapsed to reduce visual noise. The Zustand store for The Comb should use `useShallow` from `zustand/react/shallow` when selecting multiple values to prevent unnecessary re-renders cascading through the graph.

---

## 3. The Yard: fleet dashboard with real-time SSE streaming

The Yard's fleet overview combines metrics cards, a worker status grid, and utilization charts. **Recharts** (`recharts` **v3.8.0**, ~7.1M weekly downloads, ~26,800 stars) serves all charting needs. Note that recharts underwent a **major v3 rewrite** — the API changed significantly from v2, removing the `react-smooth` dependency and the `CategoricalChartState` API in favor of hooks like `useActiveTooltipLabel` and `useXAxisScale`.

```tsx
import { LineChart, Line, XAxis, YAxis, ResponsiveContainer, Tooltip } from 'recharts';

<ResponsiveContainer width="100%" height={200}>
  <LineChart data={costTimeSeries}>
    <XAxis dataKey="hour" stroke="#d4a017" />
    <YAxis stroke="#d4a017" />
    <Tooltip contentStyle={{ background: '#1a1a0e', border: '1px solid #d4a017' }} />
    <Line type="monotone" dataKey="costPerHour" stroke="#f59e0b" dot={false} />
  </LineChart>
</ResponsiveContainer>
```

Recharts is SVG-based and handles up to ~1,000 data points smoothly; beyond that, implement a sliding window. For the fleet utilization strip chart, use a `BarChart` with small `barSize` values and conditional `Cell` fill colors per worker status. Recharts is the default charting library in shadcn/ui, making it the path-of-least-resistance choice for dashboard components.

**Toast notifications for Sting alerts use `sonner`** (v2.0.7, ~10.3M weekly downloads, maintained by Emil Kowalski). It has zero dependencies, ships with TypeScript types, and integrates trivially with Next.js App Router — place `<Toaster theme="dark" />` in the root layout, then call `toast.error('Worker w3 heartbeat lost')` from anywhere. Sonner is the default toast in shadcn/ui and is used in production by Vercel and Cursor.

### SSE integration with Zustand for live fleet state

The recommended pattern uses a single persistent SSE connection at the application level, feeding into a Zustand store that components subscribe to via selectors:

```typescript
import { create } from 'zustand';

interface YardStore {
  workers: Record<string, WorkerStatus>;
  metrics: { costPerHour: number; activeCount: number; p95Latency: number };
  connectSSE: () => () => void;
}

export const useYardStore = create<YardStore>((set, get) => ({
  workers: {},
  metrics: { costPerHour: 0, activeCount: 0, p95Latency: 0 },
  connectSSE: () => {
    const es = new EventSource('/api/hivemind/stream');
    es.addEventListener('worker-heartbeat', (e) => {
      const data = JSON.parse(e.data);
      set(state => ({
        workers: { ...state.workers, [data.id]: { ...state.workers[data.id], ...data } }
      }));
    });
    es.addEventListener('metrics-tick', (e) => {
      set({ metrics: JSON.parse(e.data) });
    });
    return () => es.close();
  },
}));
```

The Next.js App Router SSE route handler uses the Web Streams API with `ReadableStream`, setting `export const dynamic = 'force-dynamic'` to prevent caching, and including `X-Accel-Buffering: no` for Nginx proxying. The worker status grid renders 20–30 workers as a CSS Grid (`grid-cols-6`) with `animate-pulse` on running workers' heartbeat indicators and opacity reduction for stale heartbeats (>30 seconds old).

---

## 4. The Comb store pattern and the useShallow imperative

The Comb's Zustand store demonstrates a pattern shared across all screens that consume real-time events. Zustand v5 (`zustand` **v5.0.11**, ~24M weekly downloads, ~57,200 stars, pmndrs collective) was a cleanup release from v4 — no new features, but it dropped React <18 support, removed the `use-sync-external-store` shim in favor of native `useSyncExternalStore`, and tightened TypeScript constraints on `setState`.

The **`useShallow` hook** (imported from `zustand/react/shallow`) wraps selectors to perform shallow comparison on returned objects, preventing re-renders when individual fields haven't changed. This is mandatory when selecting multiple values:

```typescript
import { useShallow } from 'zustand/react/shallow';

// Without useShallow: re-renders on ANY store change
const { nodes, edges } = useCombStore(state => ({ nodes: state.nodes, edges: state.edges }));

// With useShallow: re-renders only when nodes or edges actually change
const { nodes, edges } = useCombStore(
  useShallow(state => ({ nodes: state.nodes, edges: state.edges }))
);
```

The recommended architecture is **one Zustand store per screen domain** — `useYardStore`, `useCombStore`, `useGlassStore`, `useKeeperStore` — with a single cross-cutting `useHivemindStore` for the SSE connection and shared event bus. Zustand stores live outside the React tree (no providers required), which means they can be initialized, subscribed to, and updated from non-React code like SSE handlers.

---

## 5. The Waggle: tree browsing and code editing for the skill registry

The Waggle combines a hierarchical skill browser with an embedded code editor. **`react-arborist`** (v3.4.3, ~115,500 weekly downloads, 3,430 stars, maintained by Brim Data) provides a **virtualized-by-default tree view** that efficiently handles 10,000+ nodes by rendering only visible rows. It supports built-in search filtering, drag-and-drop reordering, inline rename editing, and full keyboard navigation.

```tsx
import { Tree } from 'react-arborist';

<Tree
  data={skillHierarchy}
  width={300}
  height={600}
  rowHeight={28}
  searchTerm={searchQuery}
  searchMatch={(node, term) =>
    node.data.name.toLowerCase().includes(term.toLowerCase())
  }
  onSelect={(nodes) => setSelectedSkill(nodes[0]?.data)}
>
  {({ node, style, dragHandle }) => (
    <div style={style} ref={dragHandle} className="flex items-center gap-2">
      <span className={node.isInternal ? 'text-amber-400' : 'text-gray-400'}>
        {node.isOpen ? '▾' : '▸'}
      </span>
      <span>{node.data.name}</span>
    </div>
  )}
</Tree>
```

**`@monaco-editor/react`** (v4.7.0, ~3.7M weekly downloads, 4,655 stars, maintained by Suren Atoyan) wraps the VS Code editor engine for React. It loads Monaco from CDN by default (zero bundle impact) and supports custom themes defined via the `beforeMount` callback. For SKILL.md files with YAML frontmatter, configure `defaultLanguage="markdown"` — Monaco's built-in Markdown tokenizer handles standard content, and YAML frontmatter blocks can be enhanced with a custom Monarch tokenizer rule.

The three-level loading architecture maps naturally to the tree + editor pattern. **Level 1** (name + description) loads as the tree data for instant browsing. **Level 2** (full SKILL.md content) fetches on node selection, populating the Monaco editor. **Level 3** (reference files, binary requirements) loads on-demand when the user expands a detail panel. This progressive disclosure keeps the initial API payload small while giving operators full inspection capability when needed.

For the custom dark amber theme:
```typescript
monaco.editor.defineTheme('hive-dark', {
  base: 'vs-dark',
  inherit: true,
  rules: [
    { token: 'keyword', foreground: 'FFB300' },
    { token: 'string', foreground: 'FFCA28' },
    { token: 'comment', foreground: '6B7280', fontStyle: 'italic' },
  ],
  colors: {
    'editor.background': '#0A0A0A',
    'editor.foreground': '#FFD54F',
    'editorCursor.foreground': '#F59E0B',
    'editor.selectionBackground': '#3E2723',
  },
});
```

Monaco must be loaded with `dynamic(() => import(...), { ssr: false })` in Next.js since it requires DOM access. The full Monaco bundle is ~2–4MB; for production, use language subsetting to include only Markdown, YAML, and JSON tokenizers.

---

## 6. The Keeper: human-in-the-loop approvals with diff review

The Keeper screen presents agent actions requiring human approval, showing proposed changes with risk indicators and countdown deadlines. Two libraries anchor this screen: Monaco's **`DiffEditor`** component for code change review, and Vercel's **AI Elements** for structured approval UI patterns.

The DiffEditor renders side-by-side or inline diffs of proposed changes:

```tsx
import { DiffEditor } from '@monaco-editor/react';

<DiffEditor
  height="400px"
  original={currentFileContent}
  modified={proposedFileContent}
  language="typescript"
  theme="hive-dark"
  options={{ readOnly: true, renderSideBySide: true }}
/>
```

**AI SDK 6** (`ai` v6.0.116, `@ai-sdk/react` v3.0.118) now includes native tool approval via `requireApproval: true` on tool definitions. The `addToolApprovalResponse` function from `useChat` handles approve/reject actions. Vercel's new **AI Elements** library (`ai-elements` CLI v1.8.4) provides copy-and-own components including a `Confirmation` component specifically designed for approval workflows, with `ConfirmationRequest`, `ConfirmationAccepted`, `ConfirmationRejected`, and `ConfirmationActions` subcomponents.

Approval cards should be color-coded by risk level (red border-left for destructive operations, amber for configuration changes, green for routine actions) with a countdown timer component that escalates visual urgency as deadlines approach. React 19's `useOptimistic` hook provides the idiomatic pattern for immediate UI feedback on approve/reject actions, automatically reverting if the server call fails.

For the Kanban-style approval queue, **`@dnd-kit/core`** (v6.3.1) and **`@dnd-kit/sortable`** (v10.0.0, ~8.9M weekly downloads, ~16,700 stars) enable drag-and-drop prioritization. The new `@dnd-kit/dom` rewrite (v0.3.2) is still in early development — stick with the stable v6/v10 packages for production. The Kanban pattern uses `DndContext` with `closestCorners` collision detection, each column as a `useDroppable` zone containing a `SortableContext` with `verticalListSortingStrategy`.

---

## 7. The Trail: distributed trace visualization backed by ClickHouse

The Trail renders execution traces as a waterfall timeline. **ClickHouse's acquisition of Langfuse on January 16, 2026** (alongside a $400M Series D at ~$15B valuation) confirmed the convergence of LLM observability and columnar analytics. Langfuse v3 already ran on ClickHouse internally; the acquisition keeps it open-source under MIT and ensures tight integration between The Hive's trace data and ClickHouse's query engine.

For the timeline component, `react-calendar-timeline` (v0.30.0-beta.3) has undergone a TypeScript rewrite with built-in virtualization, but its beta status and maintenance uncertainty make it a calculated risk. The library renders groups (workers) and items (spans) on a scrollable timeline with custom item renderers, which maps well to a trace waterfall. For a true OpenTelemetry-style span waterfall with parent-child nesting, a **custom implementation** using positioned `div` elements is often more reliable — calculate `left = (span.startTime - trace.startTime) / trace.duration * 100%` and `width = span.duration / trace.duration * 100%`, with indentation levels derived from the span parent chain.

ClickHouse queries for trace data should leverage `toStartOfInterval` for time bucketing and `WITH FILL` for continuous time series without gaps:

```sql
SELECT
  trace_id, span_id, parent_span_id,
  name AS operation_name,
  timestamp AS start_time,
  duration_ns / 1e6 AS duration_ms,
  status_code
FROM traces
WHERE trace_id = {traceId:String}
ORDER BY start_time ASC;
```

Recharts handles the latency histogram and error rate sparkline charts on the Trail overview. For the detail waterfall view, the custom SVG/div approach provides the fidelity needed to show nested span relationships with proper indentation and timing marks — this is the approach used by Jaeger UI and SigNoz.

---

## 8. The Yield: cost dashboards with ClickHouse time-series queries

The Yield screen displays cost-per-hour, token consumption by model, and budget burn-down projections. All charts use **recharts** `ComposedChart` for mixed bar + line visualizations, with `ResponsiveContainer` for fluid sizing. The core ClickHouse query pattern for cost aggregation:

```sql
SELECT
  toStartOfInterval(timestamp, INTERVAL 1 HOUR) AS hour,
  caste, model,
  sum(prompt_tokens * prompt_cost_per_token 
    + completion_tokens * completion_cost_per_token) AS total_cost,
  sum(total_tokens) AS token_count
FROM llm_usage
WHERE timestamp >= now() - INTERVAL 7 DAY
GROUP BY hour, caste, model
ORDER BY hour ASC WITH FILL
  FROM toStartOfHour(now() - INTERVAL 7 DAY)
  TO toStartOfHour(now())
  STEP INTERVAL 1 HOUR;
```

**The Yield should poll, not stream.** Cost data aggregates over intervals (minutes to hours) and doesn't change at sub-second frequency. A 30-second polling interval via `@tanstack/react-query` or SWR with `refreshInterval: 30_000` is simpler, more cache-friendly, and avoids holding an SSE connection open for infrequently changing data. Budget burn-down charts project exhaustion by fitting a linear regression to the last 24 hours of spend and extrapolating to the budget ceiling — recharts' `ReferenceLine` component marks the projected exhaustion timestamp.

---

## 9. The Smoker: single-terminal CLI bridge

The Smoker is architecturally identical to a single Glass terminal panel. The same `@xterm/xterm` v6.0.0 + `@xterm/addon-webgl` + `@xterm/addon-fit` stack connects via WebSocket to a Fastify route that spawns a `node-pty` process running the operator's CLI tool. The WebSocket handler on the server is straightforward:

```typescript
fastify.get('/smoker/terminal', { websocket: true }, (socket, req) => {
  const pty = require('node-pty').spawn('bash', ['-l'], {
    name: 'xterm-256color',
    cols: 80, rows: 30,
    cwd: process.env.HOME,
    env: { ...process.env, TERM: 'xterm-256color' },
  });
  pty.onData(data => socket.send(data));       // stdout → browser
  socket.on('message', msg => pty.write(msg)); // browser → stdin
  socket.on('close', () => pty.kill());
  pty.onExit(() => socket.close());
});
```

The client component mirrors The Glass but without the multiplexer complexity — a single `useEffect` initializing one `Terminal` instance with WebGL rendering, FitAddon, and bidirectional WebSocket data flow. Resize events propagate from `ResizeObserver` → `fitAddon.fit()` → `terminal.onResize` → WebSocket resize message → `ptyProcess.resize(cols, rows)` on the server.

---

## 10. The Queen: orchestrator chat with routing visualization

The Queen screen combines a streaming chat interface with a panel showing which worker caste was selected and why. **`@assistant-ui/react`** (v0.12.17, ~271,700 weekly downloads, 8,300 stars, Y Combinator-backed, maintained by Simon Farshid) provides the chat UI as Radix-style composable primitives — not a monolithic widget. It includes thread management, message branching (edit-and-fork like ChatGPT), streaming with auto-scroll, and the critical `makeAssistantToolUI` API for rendering tool calls as custom inline components.

```tsx
import { AssistantRuntimeProvider } from '@assistant-ui/react';
import { useChatRuntime } from '@assistant-ui/react-ai-sdk';
import { Thread } from '@/components/assistant-ui/thread';

export default function QueenChat() {
  const runtime = useChatRuntime({ api: '/api/queen/chat' });
  return (
    <AssistantRuntimeProvider runtime={runtime}>
      <Thread />
    </AssistantRuntimeProvider>
  );
}
```

The routing visualization panel uses `makeAssistantToolUI` to render inline annotations when the Queen makes routing decisions — showing the selected caste, confidence score, and reasoning. Clicking a task reference in the Queen's response can navigate to The Comb via Next.js router, passing the task ID as a query parameter for the DAG to highlight.

assistant-ui complements rather than replaces Vercel AI SDK — the `@assistant-ui/react-ai-sdk` (v1.1.20) bridge package connects assistant-ui's runtime to AI SDK's `useChat` transport layer. assistant-ui provides the UI components; AI SDK provides the streaming protocol and model integrations. For The Queen, this separation lets the routing visualization and chat interface evolve independently.

---

## 11. Architecture: Next.js 16 patterns for an SPA-style admin dashboard

**Next.js 16.2.0** (released March 18, 2026) ships with Turbopack as the default bundler for both dev and production, React Compiler 1.0 as a stable opt-in, and React 19.2 features including the `<Activity>` component. The glass-ui architecture should leverage several App Router patterns.

**Route groups** organize the nine screens without affecting URL structure. A `(hive)` route group contains all screens under a shared dashboard layout with the navigation sidebar:

```
app/
├── (hive)/
│   ├── layout.tsx           // Dashboard shell, SSE connection init
│   ├── yard/page.tsx
│   ├── glass/page.tsx
│   ├── comb/page.tsx
│   ├── waggle/page.tsx
│   ├── keeper/page.tsx
│   ├── smoker/page.tsx
│   ├── trail/page.tsx
│   ├── yield/page.tsx
│   └── queen/page.tsx
└── layout.tsx               // Root layout with Toaster, theme
```

**Code splitting is automatic** — each `page.tsx` is a separate chunk. For heavy client components like Monaco Editor and React Flow, use `next/dynamic` with `{ ssr: false }` to prevent server-side rendering and reduce initial bundle size. React 19.2's `<Activity>` component enables **tab pre-rendering**: keep previously visited screens alive but hidden (`mode="hidden"`) so switching back is instant without re-fetching data or re-initializing terminal connections.

### The SSE subscription strategy

Use a **single persistent SSE connection** initialized in the `(hive)/layout.tsx` dashboard shell, feeding into a shared `useHivemindStore`. Named SSE event types (`worker-heartbeat`, `task-update`, `approval-request`, `metrics-tick`, `alert`) let each screen's Zustand store subscribe to relevant slices. This avoids the HTTP/1.1 six-connection-per-domain limit that per-screen SSE connections would hit, while keeping payload sizes manageable through event type filtering. The Zustand `subscribe()` API handles the SSE → store bridge outside React's render cycle:

```typescript
// In layout.tsx useEffect:
const cleanup = useHivemindStore.getState().connectSSE();
return cleanup;
```

Components in each screen then select only their needed state via `useShallow`, ensuring that a worker heartbeat event doesn't trigger re-renders in The Comb or The Queen.

### Render budget targets by screen

- **The Glass** (terminals): Target **30fps** sustained during active output, dropping to idle when output pauses. The WebGL renderer handles this within budget for 4 panels; 8 panels may see ~15fps during simultaneous high-throughput output.
- **The Comb** (DAG): Target **60fps** for pan/zoom interactions, **30fps** during node state transition animations. React.memo on custom nodes is the single biggest optimization lever.
- **The Yard** (dashboard): Target **60fps** — lightweight DOM updates from SSE events, chart re-renders on 5–10 second intervals.
- **The Keeper** (approvals): Target **60fps** — mostly static UI with optimistic update transitions.
- **The Trail** (timeline): Target **30fps** during timeline scrolling with virtualized span rendering.
- **The Queen** (chat): Target **60fps** — streaming text rendering is lightweight.

---

## The amber/void design system in Tailwind CSS 4

Tailwind CSS **v4.2.1** (January 2025 rewrite with Rust-based Oxide engine, 2–5x faster builds) uses CSS-first configuration via `@theme` blocks rather than `tailwind.config.js`:

```css
@import "tailwindcss";

@theme {
  --color-void-950: oklch(0.05 0.01 270);
  --color-void-900: oklch(0.08 0.015 270);
  --color-void-800: oklch(0.12 0.02 265);
  --color-void-700: oklch(0.18 0.02 260);

  --color-amber-400: oklch(0.78 0.18 70);
  --color-amber-500: oklch(0.70 0.16 65);
  --color-amber-600: oklch(0.60 0.14 60);

  --color-hive-bg: oklch(0.06 0.01 270);
  --color-hive-surface: oklch(0.10 0.015 270 / 0.8);
  --color-hive-border: oklch(0.25 0.02 270 / 0.4);
  --color-hive-text: oklch(0.90 0.04 80);
  --color-hive-accent: oklch(0.78 0.18 70);

  --font-mono: 'JetBrains Mono', monospace;
  --font-sans: 'Inter', sans-serif;
}

@custom-variant dark (&.dark);
```

This gives utility classes like `bg-void-950`, `text-amber-400`, `border-hive-border` throughout the component library. The dark-mode-only dashboard uses a `dark` class on `<html>` managed by `next-themes` (v0.4.x).

---

## Complete package manifest for glass-ui

| Package | npm name | Version | Purpose | Screen(s) |
|---|---|---|---|---|
| Next.js | `next` | 16.2.0 | Framework | All |
| React | `react` | 19.2.4 | UI library | All |
| TypeScript | `typescript` | 5.7.x | Type safety | All |
| Zustand | `zustand` | 5.0.11 | State management | All |
| Tailwind CSS | `tailwindcss` | 4.2.1 | Styling | All |
| xterm.js | `@xterm/xterm` | 6.0.0 | Terminal emulation | Glass, Smoker |
| WebGL addon | `@xterm/addon-webgl` | 0.19.0 | GPU terminal rendering | Glass, Smoker |
| Fit addon | `@xterm/addon-fit` | 0.11.0 | Terminal resizing | Glass, Smoker |
| Headless xterm | `@xterm/headless` | 6.0.0 | Server-side terminal state | Glass (server) |
| Resizable panels | `react-resizable-panels` | 4.7.3 | Split-pane layouts | Glass, Waggle, Trail |
| React Flow | `@xyflow/react` | 12.10.1 | DAG visualization | Comb |
| dagre | `@dagrejs/dagre` | latest | DAG auto-layout | Comb |
| Motion | `motion` | 12.38.0 | Animation | Comb, Keeper |
| Recharts | `recharts` | 3.8.0 | Charts | Yard, Trail, Yield |
| Sonner | `sonner` | 2.0.7 | Toast notifications | Yard (alerts) |
| React Arborist | `react-arborist` | 3.4.3 | Tree view | Waggle |
| Monaco Editor | `@monaco-editor/react` | 4.7.0 | Code/diff editor | Waggle, Keeper |
| assistant-ui | `@assistant-ui/react` | 0.12.17 | Chat interface | Queen |
| AI SDK bridge | `@assistant-ui/react-ai-sdk` | 1.1.20 | Chat runtime | Queen |
| AI SDK React | `@ai-sdk/react` | 3.0.118 | Streaming hooks | Queen, Keeper |
| dnd-kit core | `@dnd-kit/core` | 6.3.1 | Drag-and-drop | Keeper |
| dnd-kit sortable | `@dnd-kit/sortable` | 10.0.0 | Sortable lists | Keeper |
| Calendar timeline | `react-calendar-timeline` | 0.30.0-beta.3 | Trace timeline | Trail |
| node-pty | `node-pty` | 1.1.0 | Server-side PTY | Glass, Smoker (server) |
| next-themes | `next-themes` | 0.4.x | Theme switching | All |
| clsx | `clsx` | 2.1.x | Classname utility | All |
| tailwind-merge | `tailwind-merge` | 3.x | Class merging | All |

## Conclusion: three renames, one acquisition, and a rendering wall

The most actionable finding across this research is that **three foundational packages renamed between 2024 and 2026**, and using their old names imports deprecated, unmaintained code: `xterm` → `@xterm/xterm`, `reactflow` → `@xyflow/react`, and `framer-motion` → `motion` (import path `motion/react`). Any existing code or tutorial referencing the old names needs updating.

The **WebGL context ceiling of 16 per Chrome renderer process** is the hard performance wall for The Glass. With 8 terminal panels using WebGL and The Comb's React Flow canvas potentially using WebGL for large graph rendering, the budget is tight. A mitigation strategy — DOM renderer fallback for backgrounded terminals — should be designed from day one.

The Langfuse-ClickHouse acquisition reshapes The Trail and The Yield: trace data and cost metrics now naturally converge in ClickHouse's columnar engine, with `toStartOfInterval` and `WITH FILL` providing the time-series primitives needed for both timeline waterfalls and cost dashboards. This eliminates the need for a separate time-series database.

Finally, the **React Compiler** shipping stable in Next.js 16 potentially obsoletes much of the manual `React.memo` / `useMemo` / `useCallback` optimization work — but not for React Flow custom nodes, where `React.memo` remains explicitly required by the library's internal rendering architecture. The compiler is opt-in and should be enabled, but React Flow node components must still carry their memo wrappers.