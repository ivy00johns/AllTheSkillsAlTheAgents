# Component Stack Guide

Reference for every React component library in the agentic UI dashboard. Each section covers installation, usage patterns, integration with our architecture, critical gotchas, and performance notes.

---

## 1. React Flow (@xyflow/react)

**Purpose:** Live animated DAG showing agent task dependencies and state transitions.

### Installation

```bash
npm install @xyflow/react dagre @dagrejs/dagre
```

### Custom Node Implementation

Every custom node MUST be wrapped in `React.memo`. Without this, moving or selecting one node re-renders ALL nodes.

```tsx
import { memo } from 'react';
import { Handle, Position, type NodeProps } from '@xyflow/react';
import { motion } from 'motion/react';

interface AgentTaskData {
  label: string;
  agentId: string;
  role: AgentRole;
  status: AgentStatus;
}

const AgentTaskNode = memo(({ data }: NodeProps<AgentTaskData>) => {
  const status = useOrchestratorStore(
    (s) => s.agents.find((a) => a.id === data.agentId)?.status,
    (a, b) => a === b // equality check prevents re-render on unrelated store changes
  );

  return (
    <motion.div
      animate={{
        scale: status === 'running' ? 1.05 : 1,
        borderColor: statusColorMap[status ?? 'idle'],
      }}
      transition={{ type: 'spring', stiffness: 300, damping: 25 }}
      className="agent-node"
    >
      <Handle type="target" position={Position.Top} />
      <div className="flex items-center gap-2 px-3 py-2">
        <StatusBadge status={status} />
        <span className="text-sm font-medium">{data.label}</span>
      </div>
      <Handle type="source" position={Position.Bottom} />
    </motion.div>
  );
});

AgentTaskNode.displayName = 'AgentTaskNode';
```

### Zustand Integration Pattern

React Flow uses Zustand internally. Our app store also uses Zustand. Access data via selectors with `useShallow` to prevent cascading re-renders.

```tsx
import { useShallow } from 'zustand/react/shallow';

// GOOD: selector returns only the data this component needs
const { agents, activeAgentId } = useOrchestratorStore(
  useShallow((s) => ({
    agents: s.agents,
    activeAgentId: s.activeAgentId,
  }))
);

// BAD: subscribes to the entire store - re-renders on every state change
const store = useOrchestratorStore();
```

### dagre Layout Integration

dagre computes hierarchical positions. Map the computed positions back onto React Flow nodes after every topology change.

```tsx
import dagre from '@dagrejs/dagre';

function computeDagreLayout(
  nodes: Node[],
  edges: Edge[],
  direction: 'TB' | 'LR' = 'TB'
): Node[] {
  const g = new dagre.graphlib.Graph();
  g.setDefaultEdgeLabel(() => ({}));
  g.setGraph({
    rankdir: direction,
    nodesep: 60,
    ranksep: 80,
    edgesep: 20,
  });

  nodes.forEach((node) => {
    g.setNode(node.id, { width: 200, height: 60 });
  });
  edges.forEach((edge) => {
    g.setEdge(edge.source, edge.target);
  });

  dagre.layout(g);

  return nodes.map((node) => {
    const pos = g.node(node.id);
    return {
      ...node,
      position: { x: pos.x - 100, y: pos.y - 30 }, // center-align
    };
  });
}
```

Call `computeDagreLayout` only when the graph topology changes (nodes added/removed), not on every status update. dagre computes in <10ms for 50 nodes, but >100ms for 500+.

### Motion Animation Inside Nodes

Use `motion.div` from Motion (formerly Framer Motion) inside custom nodes for state transition animations.

```tsx
// Status pulse ring animation
<motion.div
  animate={{
    boxShadow:
      status === 'running'
        ? ['0 0 0 0 rgba(59,130,246,0.4)', '0 0 0 8px rgba(59,130,246,0)']
        : '0 0 0 0 rgba(0,0,0,0)',
  }}
  transition={{
    duration: 1.5,
    repeat: status === 'running' ? Infinity : 0,
    ease: 'easeOut',
  }}
/>
```

Rules for animation inside nodes:
- Use `transform` and `opacity` only for GPU-accelerated 60fps
- Never animate `width`, `height`, or layout-triggering properties
- Keep transition durations under 500ms for state changes
- Use `layout` prop sparingly inside React Flow nodes (can fight node positioning)

### Edge Customization and Animation

For animated edges (particles flowing along paths), use SVG marker animation, NOT CSS `stroke-dasharray`. CSS dash animation is janky at scale.

```tsx
import { BaseEdge, getBezierPath, type EdgeProps } from '@xyflow/react';

const AnimatedEdge = memo(({ id, sourceX, sourceY, targetX, targetY, ...props }: EdgeProps) => {
  const [edgePath] = getBezierPath({ sourceX, sourceY, targetX, targetY });

  return (
    <>
      <BaseEdge id={id} path={edgePath} />
      {/* SVG particle animation along the path */}
      <circle r="3" fill="#3b82f6">
        <animateMotion dur="2s" repeatCount="indefinite" path={edgePath} />
      </circle>
    </>
  );
});
```

### Minimap and Controls

```tsx
import { ReactFlow, MiniMap, Controls, Background } from '@xyflow/react';
import '@xyflow/react/dist/style.css';

function DagVisualization() {
  return (
    <ReactFlow
      nodes={nodes}
      edges={edges}
      nodeTypes={nodeTypes} // defined OUTSIDE component or in useMemo
      fitView
      minZoom={0.1}
      maxZoom={2}
    >
      <MiniMap
        nodeColor={(node) => statusColorMap[node.data.status]}
        maskColor="rgba(0,0,0,0.1)"
      />
      <Controls showInteractive={false} />
      <Background variant="dots" gap={16} />
    </ReactFlow>
  );
}
```

### Performance Rules

1. **`React.memo` on ALL custom nodes** -- mandatory, non-negotiable
2. **`nodeTypes` outside component** -- must be a stable reference. Define at module scope or in `useMemo` with empty deps
3. **Zustand selectors with equality checks** -- prevent store changes from cascading into node re-renders
4. **dagre layout on topology change only** -- not on status updates
5. **Batch node position updates** -- use `setNodes` once, not per-node
6. **Limit to ~500 nodes** -- beyond this, dagre layout exceeds 100ms (issue #4291)

### Known Issues

- **#4711 (frequent updates):** High-frequency `setNodes` calls cause jank. Batch into 50ms windows.
- **#4291 (500+ nodes):** Performance degrades. Use node grouping or pagination for large graphs.
- **#4884 (handle context):** Handle components can lose context when nodes unmount/remount rapidly. Use stable `id` props.

---

## 2. react-resizable-panels

**Purpose:** Nested resizable panel layout for the dashboard shell.

### Installation

```bash
npm install react-resizable-panels
```

### Basic Usage

```tsx
import { PanelGroup, Panel, PanelResizeHandle } from 'react-resizable-panels';

function DashboardLayout() {
  return (
    <PanelGroup direction="horizontal" autoSaveId="dashboard-main">
      {/* Left: DAG visualization */}
      <Panel defaultSize={60} minSize={30}>
        <DagVisualization />
      </Panel>

      <PanelResizeHandle className="w-1 bg-gray-300 hover:bg-blue-500 transition-colors" />

      {/* Right: sidebar panels */}
      <Panel defaultSize={40} minSize={20}>
        <PanelGroup direction="vertical" autoSaveId="dashboard-sidebar">
          <Panel defaultSize={50} minSize={20} collapsible>
            <ApprovalQueue />
          </Panel>

          <PanelResizeHandle className="h-1 bg-gray-300 hover:bg-blue-500 transition-colors" />

          <Panel defaultSize={50} minSize={20} collapsible>
            <AgentOutput />
          </Panel>
        </PanelGroup>
      </Panel>
    </PanelGroup>
  );
}
```

### Nested Layouts

Panels can contain `PanelGroup` children for arbitrarily deep nesting. This is how we implement preset layouts (Overview, Agent Focus, Review, Monitoring).

```tsx
// Two-level nesting: horizontal → vertical
<PanelGroup direction="horizontal">
  <Panel>
    <PanelGroup direction="vertical">
      <Panel><BlockA /></Panel>
      <PanelResizeHandle />
      <Panel><BlockB /></Panel>
    </PanelGroup>
  </Panel>
  <PanelResizeHandle />
  <Panel><BlockC /></Panel>
</PanelGroup>
```

### Dynamic Panel Add/Remove

Panels can be dynamically added or removed by conditionally rendering `<Panel>` components. React key management is critical -- use stable block IDs.

```tsx
function DynamicLayout({ panels }: { panels: PanelConfig[] }) {
  return (
    <PanelGroup direction="horizontal">
      {panels.map((panel, i) => (
        <React.Fragment key={panel.id}>
          {i > 0 && <PanelResizeHandle />}
          <Panel
            defaultSize={panel.size}
            minSize={panel.minSize ?? 10}
            collapsible={panel.collapsible}
          >
            <BlockContainer config={panel} />
          </Panel>
        </React.Fragment>
      ))}
    </PanelGroup>
  );
}
```

### Collapsible Panels

Use the `collapsible` prop with `ref` to programmatically expand/collapse.

```tsx
import { type ImperativePanelHandle } from 'react-resizable-panels';

const panelRef = useRef<ImperativePanelHandle>(null);

// Collapse programmatically
panelRef.current?.collapse();

// Expand programmatically
panelRef.current?.expand();

// Check collapsed state
panelRef.current?.isCollapsed();

<Panel ref={panelRef} collapsible defaultSize={30} collapsedSize={0}>
  <SidebarContent />
</Panel>
```

### Layout Persistence

`autoSaveId` persists panel sizes to `localStorage` automatically. Each `PanelGroup` needs a unique ID.

```tsx
<PanelGroup
  autoSaveId="dashboard-main-layout"
  onLayout={(sizes: number[]) => {
    // Optional: save to SQLite via Tauri IPC for cross-device persistence
    savePanelSizes('dashboard-main-layout', sizes);
  }}
>
```

### Pixel vs Percentage Sizing

By default, panels use percentage-based sizing. For fixed-width sidebars, use pixel-based constraints via CSS on the panel content, not on the Panel component itself. The `minSize` and `maxSize` props are always percentages.

### Gotchas

- `PanelResizeHandle` MUST be a direct child of `PanelGroup`, between two `Panel` components
- `autoSaveId` must be globally unique per `PanelGroup`
- Collapsing a panel to 0% removes it from the flow -- sibling panels expand to fill
- Nested `PanelGroup` components each need their own `autoSaveId`

---

## 3. xterm.js (via react-xtermjs)

**Purpose:** Terminal emulation for agent output streams.

### Installation

```bash
npm install react-xtermjs @xterm/xterm @xterm/addon-webgl @xterm/addon-canvas \
  @xterm/addon-fit @xterm/addon-search @xterm/addon-serialize @xterm/addon-web-links \
  @xterm/headless
```

### XTerm Component and Hook

```tsx
import { XTerm, useXTerm } from 'react-xtermjs';

function AgentTerminal({ agentId }: { agentId: string }) {
  const { instance, ref } = useXTerm({
    options: {
      cursorBlink: false,
      disableStdin: true, // read-only for agent output
      fontSize: 13,
      fontFamily: 'JetBrains Mono, monospace',
      theme: {
        background: '#1a1b26',
        foreground: '#c0caf5',
      },
      scrollback: 5000, // 5K lines per terminal, ~1-5MB
    },
  });

  useEffect(() => {
    if (!instance) return;
    const ws = new WebSocket(`ws://localhost:3001/ws/terminal/${agentId}`);
    ws.onmessage = (event) => instance.write(event.data);
    return () => ws.close();
  }, [instance, agentId]);

  return <div ref={ref} className="h-full w-full" />;
}
```

### Addon Setup

```tsx
import { WebglAddon } from '@xterm/addon-webgl';
import { CanvasAddon } from '@xterm/addon-canvas';
import { FitAddon } from '@xterm/addon-fit';
import { SearchAddon } from '@xterm/addon-search';
import { SerializeAddon } from '@xterm/addon-serialize';
import { WebLinksAddon } from '@xterm/addon-web-links';

function setupAddons(terminal: Terminal, useWebGL: boolean) {
  const fitAddon = new FitAddon();
  terminal.loadAddon(fitAddon);

  const searchAddon = new SearchAddon();
  terminal.loadAddon(searchAddon);

  const serializeAddon = new SerializeAddon();
  terminal.loadAddon(serializeAddon);

  terminal.loadAddon(new WebLinksAddon());

  // Renderer selection
  if (useWebGL) {
    try {
      terminal.loadAddon(new WebglAddon());
    } catch {
      // WebGL context exhausted, fall back to canvas
      terminal.loadAddon(new CanvasAddon());
    }
  }

  // Fit terminal to container on resize
  const observer = new ResizeObserver(() => fitAddon.fit());
  observer.observe(terminal.element!.parentElement!);

  return { fitAddon, searchAddon, serializeAddon, observer };
}
```

### WebGL vs DOM Renderer Selection

Browsers allow 8-16 WebGL contexts per page. Our dashboard may show 4-8 terminals simultaneously. Strategy: visible terminals get WebGL, hidden terminals get DOM or headless mode.

```tsx
// Track active WebGL contexts globally
const webglContextTracker = {
  active: 0,
  MAX_CONTEXTS: 8,

  canAllocate(): boolean {
    return this.active < this.MAX_CONTEXTS;
  },
  allocate(): boolean {
    if (!this.canAllocate()) return false;
    this.active++;
    return true;
  },
  release(): void {
    this.active = Math.max(0, this.active - 1);
  },
};

function getRendererStrategy(isVisible: boolean): 'webgl' | 'canvas' | 'headless' {
  if (!isVisible) return 'headless';
  if (webglContextTracker.canAllocate()) return 'webgl';
  return 'canvas';
}
```

### Headless Mode for Hidden Terminals

Non-visible terminals should use `@xterm/headless` to avoid DOM overhead entirely while still buffering output.

```tsx
import { Terminal as HeadlessTerminal } from '@xterm/headless';

function createHeadlessTerminal(agentId: string): HeadlessTerminal {
  const terminal = new HeadlessTerminal({
    scrollback: 5000,
    allowProposedApi: true,
  });

  const serializeAddon = new SerializeAddon();
  terminal.loadAddon(serializeAddon);

  // Buffer data from WebSocket
  const ws = new WebSocket(`ws://localhost:3001/ws/terminal/${agentId}`);
  ws.onmessage = (event) => terminal.write(event.data);

  return terminal;
}
```

### Serialize/Deserialize for State Preservation

When a terminal block transitions from Active to Hidden, serialize the buffer. When restoring, deserialize into the new terminal instance.

```tsx
// Serialize before hiding
function serializeTerminal(terminal: Terminal, serializeAddon: SerializeAddon): string {
  return serializeAddon.serialize();
}

// Deserialize on restore
function restoreTerminal(terminal: Terminal, serializedData: string): void {
  terminal.write(serializedData);
}
```

### Terminal Dispose and Cleanup

Failing to dispose terminals causes DOM listener leaks. Always clean up.

```tsx
useEffect(() => {
  return () => {
    if (instance) {
      webglContextTracker.release();
      observer.disconnect();
      instance.dispose(); // removes all DOM listeners and detaches
    }
  };
}, [instance]);
```

### Gotchas

- **Max 8-16 WebGL contexts** -- the single highest-severity risk. Track contexts globally.
- **Main-thread I/O** -- xterm.js renders on the main thread. Cap visible active terminals at 4-8.
- **Scrollback memory** -- 10K lines at ~500 bytes/line = ~5MB per terminal. Budget accordingly.
- **FitAddon requires visible container** -- calling `fit()` on a hidden terminal throws. Check visibility first.
- **ResizeObserver cleanup** -- disconnect the observer on unmount or you leak DOM listeners.

---

## 4. @melloware/react-logviewer

**Purpose:** Virtualized structured log streaming with ANSI color support.

### Installation

```bash
npm install @melloware/react-logviewer
```

### LazyLog Component with Stream Mode

```tsx
import { LazyLog, ScrollFollow } from '@melloware/react-logviewer';

function AgentLogViewer({ agentId }: { agentId: string }) {
  const logUrl = `http://localhost:3001/api/events/logs/${agentId}`;

  return (
    <ScrollFollow
      startFollowing
      render={({ follow, onScroll }) => (
        <LazyLog
          url={logUrl}
          stream
          follow={follow}
          onScroll={onScroll}
          enableSearch
          caseInsensitive
          selectableLines
          extraLines={1}
          enableHotKeys
          height="auto"
          style={{ height: '100%' }}
        />
      )}
    />
  );
}
```

### EventSource (SSE) and WebSocket Sources

LazyLog supports SSE via its `url` prop with `stream={true}`. For WebSocket sources, feed data through a custom `text` prop.

```tsx
function WebSocketLogViewer({ agentId }: { agentId: string }) {
  const [logText, setLogText] = useState('');

  useEffect(() => {
    const ws = new WebSocket(`ws://localhost:3001/ws/logs/${agentId}`);
    ws.onmessage = (event) => {
      setLogText((prev) => prev + event.data + '\n');
    };
    return () => ws.close();
  }, [agentId]);

  return (
    <LazyLog
      text={logText}
      follow
      enableSearch
      caseInsensitive
      selectableLines
    />
  );
}
```

### ANSI Color Support

LazyLog handles ANSI escape codes natively. Agent output with color codes (green for success, red for errors, yellow for warnings) renders correctly without additional configuration.

### Virtual Scroll Performance

The underlying Virtua-based virtual scroll handles 100MB+ of log data. Only visible lines exist in the DOM. No special configuration required beyond keeping the component mounted.

### Search Within Logs

`enableSearch={true}` adds a built-in search bar. Press Ctrl+F (or Cmd+F) to activate.

```tsx
<LazyLog
  enableSearch
  caseInsensitive
  enableHotKeys // Ctrl+F activates search
  highlightLineClassName="bg-yellow-200"
/>
```

### Gotchas

- `height="auto"` requires the parent container to have explicit height
- `stream` mode keeps the SSE connection open -- make sure to unmount the component to close it
- Extremely high-frequency log lines (>1000/sec) can overwhelm even the virtual scroller -- batch on the backend

---

## 5. @monaco-editor/react

**Purpose:** Code diff viewer for agent code changes.

### Installation

```bash
npm install @monaco-editor/react
```

### Editor and DiffEditor Components

```tsx
import Editor from '@monaco-editor/react';
import { DiffEditor } from '@monaco-editor/react';

// Read-only code viewer
function CodeViewer({ code, language }: { code: string; language: string }) {
  return (
    <Editor
      height="100%"
      language={language}
      value={code}
      options={{ readOnly: true, minimap: { enabled: false } }}
    />
  );
}

// Diff viewer for agent changes
function AgentDiffViewer({
  original,
  modified,
  language,
}: {
  original: string;
  modified: string;
  language: string;
}) {
  return (
    <DiffEditor
      height="100%"
      language={language}
      original={original}
      modified={modified}
      options={{
        readOnly: true,
        renderSideBySide: true,
        minimap: { enabled: false },
      }}
    />
  );
}
```

### SINGLE INSTANCE RULE

This is a hard constraint. Monaco Editor uses global state for themes, languages, and worker configuration. Creating multiple editor instances causes:
- Conflicting theme registration
- Memory leaks from unregistered language workers
- Global keybinding conflicts

**Solution: one Editor or DiffEditor mounted at a time. Swap file models, not editor instances.**

```tsx
import * as monaco from 'monaco-editor';

// Model cache: reuse models for files we've already opened
const modelCache = new Map<string, monaco.editor.ITextModel>();

function getOrCreateModel(filePath: string, content: string, language: string) {
  const uri = monaco.Uri.parse(`file://${filePath}`);
  let model = modelCache.get(filePath);

  if (!model || model.isDisposed()) {
    model = monaco.editor.createModel(content, language, uri);
    modelCache.set(filePath, model);
  } else {
    // Update content if changed
    if (model.getValue() !== content) {
      model.setValue(content);
    }
  }

  return model;
}

// Swap the active model on the single editor instance
function switchFile(editor: monaco.editor.IStandaloneCodeEditor, filePath: string, content: string, language: string) {
  const model = getOrCreateModel(filePath, content, language);
  editor.setModel(model);
}

// Dispose models for closed files
function disposeModel(filePath: string) {
  const model = modelCache.get(filePath);
  if (model && !model.isDisposed()) {
    model.dispose();
  }
  modelCache.delete(filePath);
}
```

### Language Auto-Detection

```tsx
import * as monaco from 'monaco-editor';

function detectLanguage(filePath: string): string {
  const ext = filePath.split('.').pop()?.toLowerCase();
  const map: Record<string, string> = {
    ts: 'typescript',
    tsx: 'typescript',
    js: 'javascript',
    jsx: 'javascript',
    py: 'python',
    rs: 'rust',
    json: 'json',
    yaml: 'yaml',
    yml: 'yaml',
    md: 'markdown',
    css: 'css',
    html: 'html',
    sql: 'sql',
    sh: 'shell',
    bash: 'shell',
  };
  return map[ext ?? ''] ?? 'plaintext';
}
```

### Streaming Code with stream-monaco

For displaying code as an agent writes it in real-time, use the stream-monaco pattern: append to the model buffer as chunks arrive.

```tsx
function streamCodeToEditor(
  editor: monaco.editor.IStandaloneCodeEditor,
  model: monaco.editor.ITextModel
) {
  // Append streamed content to end of model
  function appendChunk(chunk: string) {
    const lastLine = model.getLineCount();
    const lastColumn = model.getLineMaxColumn(lastLine);
    model.pushEditOperations(
      [],
      [
        {
          range: new monaco.Range(lastLine, lastColumn, lastLine, lastColumn),
          text: chunk,
        },
      ],
      () => null
    );
    // Auto-scroll to bottom
    editor.revealLine(model.getLineCount());
  }

  return { appendChunk };
}
```

### Gotchas

- **Single instance only** -- never mount two `<Editor>` or `<DiffEditor>` components simultaneously
- **Model disposal** -- undisposed models leak memory. Clean up when files are closed.
- **Web workers** -- Monaco spawns web workers for language services. These persist across component unmounts.
- **Bundle size** -- Monaco is ~2MB gzipped. Use `@monaco-editor/react`'s CDN loader or configure webpack/vite to chunk it.

---

## 6. react-arborist

**Purpose:** Virtualized file tree showing files being modified by agents.

### Installation

```bash
npm install react-arborist
```

### Basic Tree Component

```tsx
import { Tree, type NodeRendererProps } from 'react-arborist';

interface FileNode {
  id: string;
  name: string;
  isFolder: boolean;
  children?: FileNode[];
  ownerAgent?: string;
  status?: 'modified' | 'created' | 'deleted' | 'conflict';
}

function FileTreeBlock({ data }: { data: FileNode[] }) {
  return (
    <Tree
      data={data}
      width="100%"
      height={600}
      indent={20}
      rowHeight={28}
      openByDefault={false}
      disableDrag // read-only tree for our use case
    >
      {FileTreeNode}
    </Tree>
  );
}
```

### Custom Node Renderer

```tsx
function FileTreeNode({ node, style, dragHandle }: NodeRendererProps<FileNode>) {
  const data = node.data;

  return (
    <div
      style={style}
      ref={dragHandle}
      className={`flex items-center gap-2 px-2 py-1 cursor-pointer hover:bg-gray-100
        ${node.isSelected ? 'bg-blue-50' : ''}`}
      onClick={() => node.toggle()}
    >
      {/* Folder/file icon */}
      {data.isFolder ? (
        node.isOpen ? <ChevronDown size={14} /> : <ChevronRight size={14} />
      ) : (
        <FileIcon size={14} />
      )}

      {/* File name */}
      <span className="text-sm truncate">{data.name}</span>

      {/* Agent ownership indicator */}
      {data.ownerAgent && (
        <span
          className="ml-auto text-xs px-1 rounded"
          style={{ backgroundColor: agentColorMap[data.ownerAgent] }}
        >
          {data.ownerAgent}
        </span>
      )}

      {/* Status badge */}
      {data.status && (
        <StatusDot status={data.status} />
      )}
    </div>
  );
}
```

### Real-Time Updates

react-arborist responds to data prop changes. When an agent modifies a file, update the tree data in the Zustand store and the tree re-renders with only the changed nodes (virtualization handles performance).

```tsx
// In Zustand store
updateFileStatus: (filePath: string, status: FileStatus, agentId: string) => {
  set((state) => ({
    fileTree: updateNodeAtPath(state.fileTree, filePath, { status, ownerAgent: agentId }),
  }));
};
```

### Gotchas

- Virtualized to 10K+ nodes -- no performance concerns for typical project trees
- `height` prop is required and must be a number (not "100%"); use a container ref with `ResizeObserver` to compute
- Drag-and-drop is enabled by default -- set `disableDrag` for read-only trees
- Node IDs must be unique across the entire tree, not just within siblings

---

## 7. @dnd-kit

**Purpose:** Kanban board for agent state tracking (drag agents between columns).

### Installation

```bash
npm install @dnd-kit/core @dnd-kit/sortable @dnd-kit/utilities
```

### DndContext and SortableContext

```tsx
import {
  DndContext,
  closestCorners,
  type DragEndEvent,
  type DragStartEvent,
  DragOverlay,
} from '@dnd-kit/core';
import {
  SortableContext,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';

function KanbanBoard() {
  const [activeCard, setActiveCard] = useState<AgentCard | null>(null);
  const columns = useOrchestratorStore(useShallow((s) => s.kanbanColumns));

  function handleDragStart(event: DragStartEvent) {
    const card = findCardById(columns, event.active.id as string);
    setActiveCard(card ?? null);
  }

  function handleDragEnd(event: DragEndEvent) {
    const { active, over } = event;
    if (!over) return;
    moveCard(active.id as string, over.id as string);
    setActiveCard(null);
  }

  return (
    <DndContext
      collisionDetection={closestCorners}
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
    >
      <div className="flex gap-4 h-full overflow-x-auto">
        {columns.map((column) => (
          <KanbanColumn key={column.id} column={column} />
        ))}
      </div>

      {/* Drag overlay renders the card being dragged */}
      <DragOverlay>
        {activeCard ? <AgentCardComponent card={activeCard} /> : null}
      </DragOverlay>
    </DndContext>
  );
}
```

### useSortable and useDroppable

```tsx
import { useSortable } from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';

// Cards MUST be React.memo to prevent re-renders during drag
const SortableAgentCard = memo(({ card }: { card: AgentCard }) => {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } =
    useSortable({ id: card.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <div ref={setNodeRef} style={style} {...attributes} {...listeners}>
      <AgentCardComponent card={card} />
    </div>
  );
});
```

### Collision Detection Algorithms

- `closestCorners` -- best for kanban columns (detects which column the card is over)
- `closestCenter` -- better for grid layouts
- `rectIntersection` -- most precise but can feel "sticky"

### React.memo Requirement

Without `React.memo` on card components, dragging one card re-renders ALL cards in ALL columns. This is the most common performance issue with @dnd-kit.

### Gotchas

- Sortable items need unique string IDs
- `DragOverlay` should render a copy of the dragged item, not the item itself
- Column droppable areas need explicit height for reliable collision detection
- Touch devices need `TouchSensor` in addition to `PointerSensor`

---

## 8. Complementary Libraries

### sonner (Toast Notifications)

```bash
npm install sonner
```

```tsx
import { Toaster, toast } from 'sonner';

// In app root
<Toaster position="bottom-right" richColors closeButton />

// Usage patterns
toast.success('Build phase 3 completed');
toast.error('Agent backend-agent crashed');
toast.warning('QA gate requires review');

// Promise pattern for async actions
toast.promise(approveGate(approvalId), {
  loading: 'Approving gate...',
  success: 'Gate approved, agents resuming',
  error: 'Failed to approve gate',
});

// Persistent notification for interrupts
toast('QA Gate requires approval', {
  duration: Infinity, // stays until dismissed
  action: {
    label: 'Review',
    onClick: () => openApprovalQueue(),
  },
});
```

### recharts (Metrics Charts)

```bash
npm install recharts
```

```tsx
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, Tooltip } from 'recharts';

function TokensPerSecondChart({ data }: { data: MetricPoint[] }) {
  return (
    <ResponsiveContainer width="100%" height={200}>
      <LineChart data={data}>
        <XAxis dataKey="timestamp" tickFormatter={formatTime} />
        <YAxis />
        <Tooltip />
        <Line
          type="monotone"
          dataKey="tokensPerSec"
          stroke="#3b82f6"
          dot={false}
          isAnimationActive={false} // disable animation for real-time updates
        />
      </LineChart>
    </ResponsiveContainer>
  );
}
```

**Performance note:** Keep the rolling data window under 10K points. For real-time data, shift old points off the front as new ones arrive. Disable chart animation (`isAnimationActive={false}`) for real-time updates.

### react-calendar-timeline (Execution Timeline)

```bash
npm install react-calendar-timeline
```

```tsx
import Timeline from 'react-calendar-timeline';
import 'react-calendar-timeline/lib/Timeline.css';

function ExecutionTimeline({ agents }: { agents: AgentState[] }) {
  const groups = agents.map((agent) => ({
    id: agent.id,
    title: `${agent.role} (${agent.id})`,
  }));

  const items = agents.flatMap((agent) =>
    agent.phases.map((phase) => ({
      id: `${agent.id}-${phase.id}`,
      group: agent.id,
      title: phase.name,
      start_time: phase.startedAt,
      end_time: phase.completedAt ?? Date.now(),
      itemProps: {
        style: { background: phaseColorMap[phase.status] },
      },
    }))
  );

  return (
    <Timeline
      groups={groups}
      items={items}
      defaultTimeStart={moment().subtract(1, 'hour')}
      defaultTimeEnd={moment().add(1, 'hour')}
      canMove={false}
      canResize={false}
    />
  );
}
```

### Motion (Framer Motion successor)

```bash
npm install motion
```

```tsx
import { motion, AnimatePresence } from 'motion/react';

// State transition animation
<motion.div
  initial={{ opacity: 0, y: 20 }}
  animate={{ opacity: 1, y: 0 }}
  exit={{ opacity: 0, y: -20 }}
  transition={{ duration: 0.2 }}
>
  <AgentCard />
</motion.div>

// GPU acceleration rules:
// - Use transform (x, y, scale, rotate) and opacity only
// - Avoid animating width, height, top, left (triggers layout)
// - Use layout prop for automatic layout animations
// - Use will-change: transform for frequently animated elements

// AnimatePresence for enter/exit
<AnimatePresence mode="popLayout">
  {agents.map((agent) => (
    <motion.div
      key={agent.id}
      layout
      initial={{ opacity: 0, scale: 0.8 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.8 }}
    >
      <AgentCard agent={agent} />
    </motion.div>
  ))}
</AnimatePresence>
```

**Performance rules:**
- Only animate `transform` and `opacity` for GPU-accelerated rendering
- Use `layout` prop for automatic FLIP animations
- Set `transition={{ type: 'spring' }}` for natural-feeling state changes
- Keep animation durations under 300ms for status changes (user should not wait)
- Use `AnimatePresence` for enter/exit transitions
