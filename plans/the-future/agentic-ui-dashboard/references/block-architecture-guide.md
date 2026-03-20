# Block Architecture Guide

Reference for implementing the block registry pattern in the agentic UI dashboard. Based on Wave Terminal's proven approach, blocks are typed, self-contained UI view units with independent state, lifecycle management, and serialization.

---

## 1. Block Registry

The block registry is a `Map` that maps block type strings to their definitions. New block types can be added without modifying any core code.

### BlockDefinition Interface

```typescript
interface BlockConfig {
  id: string;                          // Unique instance ID (e.g., "agent-output-backend-1")
  blockType: string;                   // Registry type ID (e.g., "agent-output")
  params: Record<string, unknown>;     // Instance-specific config (e.g., { agentId: "backend-agent" })
  layoutId: string;                    // Which layout this block belongs to
}

interface BlockAtoms {
  // Base atoms every block gets
  lifecycleAtom: PrimitiveAtom<BlockLifecycle>;
  configAtom: PrimitiveAtom<BlockConfig>;
}

interface BlockDefinition<TAtoms extends BlockAtoms = BlockAtoms> {
  type: string;                        // Unique type ID, kebab-case
  displayName: string;                 // Human-readable name for UI
  icon: string;                        // Lucide icon name
  category: BlockCategory;             // For grouping in "add block" menu

  // Lifecycle hooks
  createAtoms: (config: BlockConfig) => TAtoms;
  Component: React.ComponentType<{ atoms: TAtoms; config: BlockConfig }>;
  serialize?: (atoms: TAtoms) => SerializedBlockState;
  deserialize?: (data: SerializedBlockState, config: BlockConfig) => TAtoms;
  dispose?: (atoms: TAtoms) => void;

  // Optional capabilities
  canMaximize?: boolean;               // Default: true
  canCollapse?: boolean;               // Default: true
  minWidth?: number;                   // Minimum panel width in pixels
  minHeight?: number;                  // Minimum panel height in pixels
}

type BlockCategory = 'agent' | 'visualization' | 'review' | 'monitoring' | 'management';

interface SerializedBlockState {
  version: number;                     // Schema version for migration
  data: Record<string, unknown>;       // Serialized atom values
  timestamp: number;                   // When serialized
}
```

### Map-Based Registry

```typescript
// registry.ts
const BlockRegistry = new Map<string, BlockDefinition>();

function registerBlock<T extends BlockAtoms>(definition: BlockDefinition<T>): void {
  if (BlockRegistry.has(definition.type)) {
    console.warn(`Block type "${definition.type}" is already registered. Overwriting.`);
  }
  BlockRegistry.set(definition.type, definition as BlockDefinition);
}

function getBlockDefinition(type: string): BlockDefinition | undefined {
  return BlockRegistry.get(type);
}

function getAllBlockTypes(): BlockDefinition[] {
  return Array.from(BlockRegistry.values());
}

function getBlockTypesByCategory(category: BlockCategory): BlockDefinition[] {
  return getAllBlockTypes().filter((b) => b.category === category);
}
```

### Registration

All block types are registered at application startup. Registration order does not matter.

```typescript
// blocks/index.ts -- register all block types
import { registerBlock } from '../registry';
import { agentOutputBlock } from './agent-output';
import { dagVisualizationBlock } from './dag-visualization';
import { approvalQueueBlock } from './approval-queue';
import { logViewerBlock } from './log-viewer';
import { diffViewerBlock } from './diff-viewer';
import { contractComplianceBlock } from './contract-compliance';
import { fileTreeBlock } from './file-tree';
import { metricsBlock } from './metrics';
import { kanbanBlock } from './kanban';
import { timelineBlock } from './timeline';
import { chatBlock } from './chat';

export function registerAllBlocks(): void {
  registerBlock(agentOutputBlock);
  registerBlock(dagVisualizationBlock);
  registerBlock(approvalQueueBlock);
  registerBlock(logViewerBlock);
  registerBlock(diffViewerBlock);
  registerBlock(contractComplianceBlock);
  registerBlock(fileTreeBlock);
  registerBlock(metricsBlock);
  registerBlock(kanbanBlock);
  registerBlock(timelineBlock);
  registerBlock(chatBlock);
}
```

---

## 2. Block Lifecycle

Every block instance transitions through four states.

```
CREATED ──▶ ACTIVE ──▶ HIDDEN ──▶ DISPOSED
                ▲          │
                └──────────┘
              (restore from hidden)
```

### State Machine

```typescript
type BlockLifecycle = 'created' | 'active' | 'hidden' | 'disposed';

interface BlockLifecycleTransition {
  from: BlockLifecycle;
  to: BlockLifecycle;
  action: string;
}

const validTransitions: BlockLifecycleTransition[] = [
  { from: 'created', to: 'active', action: 'mount' },
  { from: 'active', to: 'hidden', action: 'hide' },
  { from: 'active', to: 'disposed', action: 'close' },
  { from: 'hidden', to: 'active', action: 'restore' },
  { from: 'hidden', to: 'disposed', action: 'close' },
];

function canTransition(from: BlockLifecycle, to: BlockLifecycle): boolean {
  return validTransitions.some((t) => t.from === from && t.to === to);
}
```

### Created

Registry lookup resolves the block type. Atoms are created but the component is not yet mounted.

```typescript
function createBlockInstance(type: string, params: Record<string, unknown>): BlockInstance {
  const definition = getBlockDefinition(type);
  if (!definition) throw new Error(`Unknown block type: ${type}`);

  const config: BlockConfig = {
    id: `${type}-${generateId()}`,
    blockType: type,
    params,
    layoutId: useOrchestratorStore.getState().activeLayout,
  };

  const atoms = definition.createAtoms(config);
  store.set(atoms.lifecycleAtom, 'created');

  return { config, atoms, definition };
}
```

### Active

Component is mounted, subscriptions are active, the block receives events.

```typescript
function activateBlock(instance: BlockInstance): void {
  const { atoms } = instance;
  const current = store.get(atoms.lifecycleAtom);

  if (!canTransition(current, 'active')) {
    throw new Error(`Cannot transition block from "${current}" to "active"`);
  }

  store.set(atoms.lifecycleAtom, 'active');
  // Component will mount via React conditional rendering on lifecycle === 'active'
}
```

### Hidden

Component is unmounted. State is serialized to SQLite. Subscriptions are paused. The block can be restored later without data loss.

```typescript
async function hideBlock(instance: BlockInstance): Promise<void> {
  const { config, atoms, definition } = instance;
  const current = store.get(atoms.lifecycleAtom);

  if (!canTransition(current, 'hidden')) return;

  // Serialize state before unmounting
  if (definition.serialize) {
    const serialized = definition.serialize(atoms);
    await persistBlockState(config.id, serialized);
  }

  store.set(atoms.lifecycleAtom, 'hidden');
  // Component unmounts via React conditional rendering
}
```

### Disposed

Full cleanup. Atoms are removed, terminal instances disposed, event listeners detached. Irreversible.

```typescript
function disposeBlock(instance: BlockInstance): void {
  const { config, atoms, definition } = instance;

  if (definition.dispose) {
    definition.dispose(atoms);
  }

  store.set(atoms.lifecycleAtom, 'disposed');

  // Remove from block instance registry
  activeBlocks.delete(config.id);

  // Remove serialized state from SQLite
  deleteBlockState(config.id);
}
```

### Restore from Hidden

```typescript
async function restoreBlock(blockId: string): Promise<BlockInstance> {
  const savedState = await loadBlockState(blockId);
  if (!savedState) throw new Error(`No saved state for block: ${blockId}`);

  const definition = getBlockDefinition(savedState.blockType);
  if (!definition) throw new Error(`Unknown block type: ${savedState.blockType}`);

  const config = savedState.config;

  // Recreate atoms from serialized state
  const atoms = definition.deserialize
    ? definition.deserialize(savedState.state, config)
    : definition.createAtoms(config);

  store.set(atoms.lifecycleAtom, 'active');

  const instance = { config, atoms, definition };
  activeBlocks.set(config.id, instance);

  return instance;
}
```

---

## 3. Atom Factories

Each block type defines an atom factory function that creates isolated Jotai atoms for that instance. Atoms are scoped to the block -- no block shares atoms with another.

### Pattern

```typescript
import { atom, type PrimitiveAtom } from 'jotai';

interface AgentOutputAtoms extends BlockAtoms {
  logsAtom: PrimitiveAtom<string[]>;
  statusAtom: PrimitiveAtom<AgentStatus>;
  terminalRefAtom: PrimitiveAtom<Terminal | null>;
  isFollowingAtom: PrimitiveAtom<boolean>;
  searchQueryAtom: PrimitiveAtom<string>;
  rendererTypeAtom: PrimitiveAtom<'webgl' | 'canvas' | 'headless'>;
}

function createAgentOutputAtoms(config: BlockConfig): AgentOutputAtoms {
  return {
    // Base atoms
    lifecycleAtom: atom<BlockLifecycle>('created'),
    configAtom: atom<BlockConfig>(config),

    // Block-specific atoms
    logsAtom: atom<string[]>([]),
    statusAtom: atom<AgentStatus>('idle'),
    terminalRefAtom: atom<Terminal | null>(null),
    isFollowingAtom: atom(true),
    searchQueryAtom: atom(''),
    rendererTypeAtom: atom<'webgl' | 'canvas' | 'headless'>('canvas'),
  };
}
```

### Derived Atoms

Use derived atoms for computed values that depend on multiple source atoms.

```typescript
// Derived atom: log line count
const logCountAtom = atom((get) => get(logsAtom).length);

// Derived atom: filtered logs based on search
function createFilteredLogsAtom(logsAtom: PrimitiveAtom<string[]>, searchAtom: PrimitiveAtom<string>) {
  return atom((get) => {
    const logs = get(logsAtom);
    const query = get(searchAtom);
    if (!query) return logs;
    return logs.filter((line) => line.toLowerCase().includes(query.toLowerCase()));
  });
}
```

### Write-Only Atoms

Use write-only atoms for actions that update multiple atoms atomically.

```typescript
// Write-only atom: append log line and auto-trim
function createAppendLogAtom(logsAtom: PrimitiveAtom<string[]>) {
  const MAX_LINES = 10_000;

  return atom(null, (get, set, newLine: string) => {
    const current = get(logsAtom);
    const updated =
      current.length >= MAX_LINES
        ? [...current.slice(current.length - MAX_LINES + 1), newLine]
        : [...current, newLine];
    set(logsAtom, updated);
  });
}
```

---

## 4. Block Container

Every block is wrapped in a `BlockContainer` component that provides consistent chrome: header bar, controls, collapse/maximize, error boundary.

```tsx
import { memo } from 'react';
import { useAtomValue, useSetAtom } from 'jotai';
import { Maximize2, Minimize2, X, ChevronDown, ChevronRight } from 'lucide-react';

interface BlockContainerProps {
  config: BlockConfig;
  atoms: BlockAtoms;
  children: React.ReactNode;
}

const BlockContainer = memo(({ config, atoms, children }: BlockContainerProps) => {
  const lifecycle = useAtomValue(atoms.lifecycleAtom);
  const definition = getBlockDefinition(config.blockType)!;
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [isMaximized, setIsMaximized] = useState(false);

  if (lifecycle === 'disposed' || lifecycle === 'hidden') return null;

  return (
    <div
      className={`flex flex-col border border-gray-200 rounded-lg overflow-hidden bg-white
        ${isMaximized ? 'fixed inset-4 z-50 shadow-2xl' : 'h-full'}`}
    >
      {/* Header bar */}
      <div className="flex items-center justify-between px-3 py-1.5 bg-gray-50 border-b border-gray-200">
        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsCollapsed(!isCollapsed)}
            className="p-0.5 hover:bg-gray-200 rounded"
          >
            {isCollapsed ? <ChevronRight size={14} /> : <ChevronDown size={14} />}
          </button>
          <Icon name={definition.icon} size={14} />
          <span className="text-sm font-medium text-gray-700">{definition.displayName}</span>
          {config.params.agentId && (
            <span className="text-xs text-gray-500">({config.params.agentId as string})</span>
          )}
        </div>

        <div className="flex items-center gap-1">
          {definition.canMaximize !== false && (
            <button
              onClick={() => setIsMaximized(!isMaximized)}
              className="p-0.5 hover:bg-gray-200 rounded"
            >
              {isMaximized ? <Minimize2 size={14} /> : <Maximize2 size={14} />}
            </button>
          )}
          <button
            onClick={() => disposeBlock({ config, atoms, definition })}
            className="p-0.5 hover:bg-red-100 rounded text-gray-400 hover:text-red-500"
          >
            <X size={14} />
          </button>
        </div>
      </div>

      {/* Block content */}
      {!isCollapsed && (
        <div className="flex-1 overflow-hidden">
          <BlockErrorBoundary blockId={config.id}>
            {children}
          </BlockErrorBoundary>
        </div>
      )}
    </div>
  );
});

BlockContainer.displayName = 'BlockContainer';
```

### BlockErrorBoundary

Wraps each block's content to isolate errors. One block crashing should not take down the entire dashboard.

```tsx
class BlockErrorBoundary extends Component<
  { blockId: string; children: React.ReactNode },
  { hasError: boolean; error?: Error }
> {
  state = { hasError: false };

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error(`Block ${this.props.blockId} crashed:`, error, info);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="flex flex-col items-center justify-center h-full gap-3 p-4 text-center">
          <p className="text-sm text-red-600">This block encountered an error.</p>
          <button
            onClick={() => this.setState({ hasError: false })}
            className="px-3 py-1 text-xs bg-gray-100 rounded hover:bg-gray-200"
          >
            Retry
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
```

---

## 5. Cross-Block Communication

Blocks NEVER communicate directly with each other. All cross-block communication goes through the Zustand store. This is a hard architectural rule.

### Why Not Direct

- Direct coupling makes blocks un-reorderable and un-removable
- Testing requires instantiating dependent blocks
- State becomes unpredictable when blocks are hidden/disposed

### Pattern: Zustand as Message Bus

```typescript
// Block A (DAG) wants to tell Block B (agent-output) which agent was selected
// Block A dispatches to Zustand:
useOrchestratorStore.getState().selectAgent('backend-agent');

// Block B reads from Zustand:
const activeAgentId = useOrchestratorStore((s) => s.activeAgentId);

// Block B reacts to the change via a useEffect:
useEffect(() => {
  if (activeAgentId) {
    switchTerminalToAgent(activeAgentId);
  }
}, [activeAgentId]);
```

### Common Cross-Block Patterns

| Source Block | Action | Zustand State | Consuming Block |
|-------------|--------|---------------|-----------------|
| dag-visualization | Click node | `activeAgentId` | agent-output, log-viewer |
| approval-queue | Click approval | `selectedApproval` | diff-viewer, contract-compliance |
| kanban | Drag card | `agents[].status` | dag-visualization (node color update) |
| file-tree | Click file | `selectedFile` | diff-viewer (load file model) |
| metrics | Click agent name | `activeAgentId` | agent-output, log-viewer |

---

## 6. Layout Integration

Blocks compose inside `react-resizable-panels`. Each panel renders a `BlockContainer` wrapping the block's component.

### Rendering a Layout

```tsx
function DashboardLayout({ layout }: { layout: DashboardLayoutConfig }) {
  return (
    <PanelGroup
      direction={layout.direction}
      autoSaveId={`layout-${layout.id}`}
    >
      {layout.panels.map((panel, i) => (
        <React.Fragment key={panel.id}>
          {i > 0 && (
            <PanelResizeHandle
              className={
                layout.direction === 'horizontal'
                  ? 'w-1 bg-gray-200 hover:bg-blue-400 transition-colors'
                  : 'h-1 bg-gray-200 hover:bg-blue-400 transition-colors'
              }
            />
          )}
          <Panel
            defaultSize={panel.defaultSize}
            minSize={panel.minSize ?? 10}
            collapsible={panel.collapsible}
          >
            {panel.children ? (
              // Nested panel group
              <DashboardLayout layout={panel as DashboardLayoutConfig} />
            ) : (
              // Leaf panel: render a block
              <BlockRenderer config={panel.blockConfig} />
            )}
          </Panel>
        </React.Fragment>
      ))}
    </PanelGroup>
  );
}
```

### BlockRenderer

Resolves the block type from the registry and renders it with atoms.

```tsx
function BlockRenderer({ config }: { config: BlockConfig }) {
  const [instance, setInstance] = useState<BlockInstance | null>(null);

  useEffect(() => {
    const inst = createBlockInstance(config.blockType, config.params);
    activateBlock(inst);
    setInstance(inst);

    return () => {
      // Hide on unmount (panel collapse/layout switch), don't dispose
      hideBlock(inst);
    };
  }, [config.blockType, config.id]);

  if (!instance) return <LoadingSpinner />;

  const { definition, atoms } = instance;
  const Component = definition.Component;

  return (
    <BlockContainer config={config} atoms={atoms}>
      <Component atoms={atoms} config={config} />
    </BlockContainer>
  );
}
```

### Preset Layouts

```typescript
const presetLayouts: Record<string, DashboardLayoutConfig> = {
  overview: {
    id: 'overview',
    name: 'Overview',
    direction: 'horizontal',
    panels: [
      {
        id: 'dag-main',
        defaultSize: 60,
        blockConfig: { id: 'dag-1', blockType: 'dag-visualization', params: {}, layoutId: 'overview' },
      },
      {
        id: 'sidebar',
        defaultSize: 40,
        direction: 'vertical',
        children: true,
        panels: [
          {
            id: 'kanban-side',
            defaultSize: 50,
            blockConfig: { id: 'kanban-1', blockType: 'kanban', params: {}, layoutId: 'overview' },
          },
          {
            id: 'metrics-side',
            defaultSize: 50,
            blockConfig: { id: 'metrics-1', blockType: 'metrics', params: {}, layoutId: 'overview' },
          },
        ],
      },
    ],
  },

  agentFocus: {
    id: 'agent-focus',
    name: 'Agent Focus',
    direction: 'horizontal',
    panels: [
      {
        id: 'terminal-main',
        defaultSize: 50,
        blockConfig: { id: 'term-1', blockType: 'agent-output', params: { agentId: null }, layoutId: 'agent-focus' },
      },
      {
        id: 'detail-side',
        defaultSize: 50,
        direction: 'vertical',
        children: true,
        panels: [
          {
            id: 'logs-side',
            defaultSize: 50,
            blockConfig: { id: 'logs-1', blockType: 'log-viewer', params: { agentId: null }, layoutId: 'agent-focus' },
          },
          {
            id: 'diff-side',
            defaultSize: 50,
            blockConfig: { id: 'diff-1', blockType: 'diff-viewer', params: {}, layoutId: 'agent-focus' },
          },
        ],
      },
    ],
  },

  review: {
    id: 'review',
    name: 'Review',
    direction: 'horizontal',
    panels: [
      {
        id: 'diff-main',
        defaultSize: 60,
        blockConfig: { id: 'diff-review', blockType: 'diff-viewer', params: {}, layoutId: 'review' },
      },
      {
        id: 'review-side',
        defaultSize: 40,
        direction: 'vertical',
        children: true,
        panels: [
          {
            id: 'contract-side',
            defaultSize: 50,
            blockConfig: { id: 'contract-1', blockType: 'contract-compliance', params: {}, layoutId: 'review' },
          },
          {
            id: 'approval-side',
            defaultSize: 50,
            blockConfig: { id: 'approval-1', blockType: 'approval-queue', params: {}, layoutId: 'review' },
          },
        ],
      },
    ],
  },
};
```

---

## 7. Persistence

Block state is persisted to SQLite so blocks survive app restarts and layout switches.

### Serialize to SQLite

```typescript
async function persistBlockState(blockId: string, state: SerializedBlockState): Promise<void> {
  await invoke('persist_block_state', {
    blockId,
    stateJson: JSON.stringify(state),
    timestamp: Date.now(),
  });
}

// Rust backend
#[tauri::command]
async fn persist_block_state(
    state: tauri::State<'_, AppState>,
    block_id: String,
    state_json: String,
    timestamp: i64,
) -> Result<(), String> {
    state.db.execute(
        "INSERT OR REPLACE INTO blocks (id, serialized_state, updated_at) VALUES (?1, ?2, ?3)",
        params![block_id, state_json, timestamp],
    ).map_err(|e| e.to_string())?;
    Ok(())
}
```

### Deserialize on Restore

```typescript
async function loadBlockState(blockId: string): Promise<SavedBlockData | null> {
  const result = await invoke<string | null>('load_block_state', { blockId });
  if (!result) return null;
  return JSON.parse(result) as SavedBlockData;
}

interface SavedBlockData {
  blockType: string;
  config: BlockConfig;
  state: SerializedBlockState;
}
```

### What Gets Serialized

Each block type decides what to serialize. Guidelines:

| Data Type | Serialize? | Reason |
|-----------|-----------|--------|
| Terminal buffer (last 5K lines) | Yes | Restore output on reopen |
| Log viewer position | Yes | Return to same scroll position |
| DAG node positions | Yes | Preserve user-arranged layout |
| Search queries | No | Ephemeral UI state |
| WebSocket connections | No | Cannot serialize; reconnect on restore |
| Active tool call state | No | Will be resent via STATE_SNAPSHOT |

### Layout Serialization

Entire layouts (which blocks, what sizes, what arrangement) are also persisted.

```typescript
async function saveLayout(layout: DashboardLayoutConfig): Promise<void> {
  await invoke('save_layout', {
    layoutId: layout.id,
    layoutJson: JSON.stringify(layout),
  });
}

async function loadLayout(layoutId: string): Promise<DashboardLayoutConfig | null> {
  const result = await invoke<string | null>('load_layout', { layoutId });
  if (!result) return null;
  return JSON.parse(result) as DashboardLayoutConfig;
}
```

---

## 8. Adding New Block Types

Step-by-step guide for creating a new block type.

### Step 1: Define Atom Interface

```typescript
// blocks/my-new-block/atoms.ts
import { atom, type PrimitiveAtom } from 'jotai';
import type { BlockAtoms, BlockConfig, BlockLifecycle } from '../types';

interface MyNewBlockAtoms extends BlockAtoms {
  dataAtom: PrimitiveAtom<MyDataType[]>;
  filterAtom: PrimitiveAtom<string>;
  selectedItemAtom: PrimitiveAtom<string | null>;
}

function createMyNewBlockAtoms(config: BlockConfig): MyNewBlockAtoms {
  return {
    lifecycleAtom: atom<BlockLifecycle>('created'),
    configAtom: atom<BlockConfig>(config),
    dataAtom: atom<MyDataType[]>([]),
    filterAtom: atom(''),
    selectedItemAtom: atom<string | null>(null),
  };
}
```

### Step 2: Build the Component

```tsx
// blocks/my-new-block/component.tsx
import { memo } from 'react';
import { useAtomValue, useSetAtom } from 'jotai';

interface MyNewBlockProps {
  atoms: MyNewBlockAtoms;
  config: BlockConfig;
}

const MyNewBlock = memo(({ atoms, config }: MyNewBlockProps) => {
  const data = useAtomValue(atoms.dataAtom);
  const filter = useAtomValue(atoms.filterAtom);
  const setFilter = useSetAtom(atoms.filterAtom);

  const filteredData = useMemo(
    () => data.filter((item) => matchesFilter(item, filter)),
    [data, filter]
  );

  return (
    <div className="h-full flex flex-col">
      <input
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
        placeholder="Filter..."
        className="px-2 py-1 border-b text-sm"
      />
      <div className="flex-1 overflow-auto">
        {filteredData.map((item) => (
          <MyDataRow key={item.id} item={item} />
        ))}
      </div>
    </div>
  );
});

MyNewBlock.displayName = 'MyNewBlock';
```

### Step 3: Define Serialization

```typescript
// blocks/my-new-block/serialization.ts
function serializeMyNewBlock(atoms: MyNewBlockAtoms): SerializedBlockState {
  return {
    version: 1,
    data: {
      filter: store.get(atoms.filterAtom),
      selectedItem: store.get(atoms.selectedItemAtom),
      // Do NOT serialize data -- it comes from SSE and will be re-populated
    },
    timestamp: Date.now(),
  };
}

function deserializeMyNewBlock(
  saved: SerializedBlockState,
  config: BlockConfig
): MyNewBlockAtoms {
  const atoms = createMyNewBlockAtoms(config);

  if (saved.version === 1) {
    store.set(atoms.filterAtom, (saved.data.filter as string) ?? '');
    store.set(atoms.selectedItemAtom, (saved.data.selectedItem as string) ?? null);
  }

  return atoms;
}
```

### Step 4: Define Disposal

```typescript
// blocks/my-new-block/dispose.ts
function disposeMyNewBlock(atoms: MyNewBlockAtoms): void {
  // Clean up any subscriptions, WebSocket connections, timers, etc.
  // Jotai atoms themselves are garbage-collected when unreferenced.
}
```

### Step 5: Register the Block

```typescript
// blocks/my-new-block/index.ts
import { type BlockDefinition } from '../types';

export const myNewBlock: BlockDefinition<MyNewBlockAtoms> = {
  type: 'my-new-block',
  displayName: 'My New Block',
  icon: 'layers',
  category: 'monitoring',
  createAtoms: createMyNewBlockAtoms,
  Component: MyNewBlock,
  serialize: serializeMyNewBlock,
  deserialize: deserializeMyNewBlock,
  dispose: disposeMyNewBlock,
  canMaximize: true,
  canCollapse: true,
  minWidth: 200,
  minHeight: 150,
};

// Then add to blocks/index.ts:
// registerBlock(myNewBlock);
```

### Step 6: Wire Up Event Routing

Add event handling for the new block type in the SSE event router.

```typescript
// In the event router
case 'RAW':
  if ((event as RawEvent).customType === 'my-data-update') {
    const blockAtoms = findBlockAtomsByType<MyNewBlockAtoms>('my-new-block');
    for (const atoms of blockAtoms) {
      store.set(atoms.dataAtom, (event as RawEvent).payload as MyDataType[]);
    }
  }
  break;
```

---

## 9. Block Type Reference

### agent-output

Terminal emulation for a single agent's output.

```typescript
interface AgentOutputAtoms extends BlockAtoms {
  logsAtom: PrimitiveAtom<string[]>;
  statusAtom: PrimitiveAtom<AgentStatus>;
  terminalRefAtom: PrimitiveAtom<Terminal | null>;
  isFollowingAtom: PrimitiveAtom<boolean>;
  searchQueryAtom: PrimitiveAtom<string>;
  rendererTypeAtom: PrimitiveAtom<'webgl' | 'canvas' | 'headless'>;
}
```

Component: xterm.js terminal with WebSocket connection. Params: `{ agentId: string }`. Dispose: release WebGL context, close WebSocket, dispose terminal.

### dag-visualization

Animated task dependency graph.

```typescript
interface DagVisualizationAtoms extends BlockAtoms {
  nodesAtom: PrimitiveAtom<Node[]>;
  edgesAtom: PrimitiveAtom<Edge[]>;
  selectedNodeAtom: PrimitiveAtom<string | null>;
  layoutDirectionAtom: PrimitiveAtom<'TB' | 'LR'>;
  animatingNodesAtom: PrimitiveAtom<Set<string>>;
}
```

Component: React Flow + dagre layout + Motion animations. Params: none. Node click updates `activeAgentId` in Zustand.

### approval-queue

Pending human approvals for QA gates.

```typescript
interface ApprovalQueueAtoms extends BlockAtoms {
  selectedApprovalAtom: PrimitiveAtom<string | null>;
  filterStatusAtom: PrimitiveAtom<'all' | 'pending' | 'resolved'>;
  sortOrderAtom: PrimitiveAtom<'newest' | 'oldest' | 'severity'>;
}
```

Component: card list with approve/reject/retry actions. Reads `pendingApprovals` and `approvalHistory` from Zustand.

### log-viewer

Structured log streaming with ANSI colors.

```typescript
interface LogViewerAtoms extends BlockAtoms {
  logLinesAtom: PrimitiveAtom<string[]>;
  filtersAtom: PrimitiveAtom<LogFilter>;
  followModeAtom: PrimitiveAtom<boolean>;
  searchQueryAtom: PrimitiveAtom<string>;
}
```

Component: @melloware/react-logviewer with ScrollFollow. Params: `{ agentId: string }`.

### diff-viewer

Side-by-side code diff for agent changes.

```typescript
interface DiffViewerAtoms extends BlockAtoms {
  originalCodeAtom: PrimitiveAtom<string>;
  modifiedCodeAtom: PrimitiveAtom<string>;
  languageAtom: PrimitiveAtom<string>;
  selectedFileAtom: PrimitiveAtom<string | null>;
}
```

Component: Monaco DiffEditor (SINGLE INSTANCE). Params: none. Swaps models when `selectedFile` changes in Zustand.

### contract-compliance

API contract conformance status.

```typescript
interface ContractComplianceAtoms extends BlockAtoms {
  endpointsAtom: PrimitiveAtom<EndpointCompliance[]>;
  scoresAtom: PrimitiveAtom<ComplianceScores>;
  violationsAtom: PrimitiveAtom<Violation[]>;
  lastCheckAtom: PrimitiveAtom<Date | null>;
}
```

Component: table with status badges. Receives data via RAW events with `customType: 'contract-compliance'`.

### file-tree

Project files with agent ownership indicators.

```typescript
interface FileTreeAtoms extends BlockAtoms {
  treeDataAtom: PrimitiveAtom<FileNode[]>;
  expandedNodesAtom: PrimitiveAtom<Set<string>>;
  activeAgentFilesAtom: PrimitiveAtom<Map<string, string>>; // filePath → agentId
}
```

Component: react-arborist tree. File click updates `selectedFile` in Zustand, which the diff-viewer consumes.

### metrics

Real-time performance metrics charts.

```typescript
interface MetricsAtoms extends BlockAtoms {
  dataPointsAtom: PrimitiveAtom<MetricPoint[]>;
  timeWindowAtom: PrimitiveAtom<number>; // seconds to display
  selectedMetricAtom: PrimitiveAtom<MetricType>;
}
```

Component: recharts LineChart inside ResponsiveContainer. Rolling window, animation disabled for real-time.

### kanban

Agent state columns with drag-and-drop.

```typescript
interface KanbanAtoms extends BlockAtoms {
  columnsAtom: PrimitiveAtom<KanbanColumn[]>;
  cardsAtom: PrimitiveAtom<KanbanCard[]>;
  dragStateAtom: PrimitiveAtom<DragState | null>;
}
```

Component: @dnd-kit SortableContext with React.memo cards. Drag updates agent status in Zustand.

### timeline

Execution history swim lanes.

```typescript
interface TimelineAtoms extends BlockAtoms {
  groupsAtom: PrimitiveAtom<TimelineGroup[]>;
  itemsAtom: PrimitiveAtom<TimelineItem[]>;
  timeRangeAtom: PrimitiveAtom<[number, number]>;
}
```

Component: react-calendar-timeline with per-agent swim lanes.

### chat

Agent conversation interface.

```typescript
interface ChatAtoms extends BlockAtoms {
  messagesAtom: PrimitiveAtom<ChatMessage[]>;
  inputValueAtom: PrimitiveAtom<string>;
  isStreamingAtom: PrimitiveAtom<boolean>;
}
```

Component: message list with input box. Receives TEXT_MESSAGE_CONTENT events, sends input via REST.
