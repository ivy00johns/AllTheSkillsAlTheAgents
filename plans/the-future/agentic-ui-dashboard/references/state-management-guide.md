# State Management Guide

Reference for the Zustand + Jotai hybrid state management architecture. Covers when to use which library, store design patterns, performance optimization, SSE integration, cross-block communication, persistence, testing, and anti-patterns.

---

## 1. When to Use Which

The dashboard uses two state management libraries. This is intentional, not accidental.

### Zustand: Cross-Block Shared State

Use Zustand for state that multiple blocks read or that represents the global application context.

**Examples:**
- Active build phase and status
- Agent fleet state (all agents, their statuses)
- Currently selected agent ID
- Pending approvals queue
- Active layout and panel configuration
- Connection status (connected/reconnecting/disconnected)

### Jotai: Within-Block Local State

Use Jotai atoms for state that belongs to a single block instance and is not read by other blocks.

**Examples:**
- Terminal buffer content for a specific agent-output block
- Log viewer scroll position and search query
- DAG node positions and animation state
- Diff viewer current file model
- Metrics chart selected time window

### Decision Flowchart

```
Is this state read by more than one block?
  ├── YES → Zustand
  └── NO → Is this state part of the block's internal rendering?
            ├── YES → Jotai atom
            └── NO → Is this a UI micro-state (hover, focus, local toggle)?
                      ├── YES → React useState
                      └── NO → Zustand (err on the side of discoverability)
```

### Why Not Just One?

- **Zustand only:** Per-block state would require deeply nested selectors, and 20 blocks updating their atoms at 50ms intervals would thrash the single store.
- **Jotai only:** No centralized place for cross-block coordination. React Flow also uses Zustand internally, so Zustand is already in the dependency tree.
- **The hybrid** gives each block isolated reactivity (Jotai) while maintaining a single source of truth for shared state (Zustand). This is exactly how Wave Terminal structures their state.

---

## 2. Zustand Store Design

### OrchestratorState Interface

```typescript
import { create } from 'zustand';
import { immer } from 'zustand/middleware/immer';
import { persist } from 'zustand/middleware';

interface OrchestratorState {
  // -- Build state --
  buildId: string | null;
  buildPhase: number;                    // 1-14
  buildStatus: BuildStatus;              // 'idle' | 'running' | 'paused' | 'completed' | 'failed'

  // -- Agent fleet --
  agents: AgentState[];
  activeAgentId: string | null;

  // -- Approvals --
  pendingApprovals: Approval[];
  approvalHistory: Approval[];
  selectedApprovalId: string | null;

  // -- Layout --
  activeLayout: string;                  // Layout ID
  activePanelId: string | null;

  // -- Connection --
  connectionStatus: ConnectionStatus;    // 'connected' | 'reconnecting' | 'disconnected'
  lastSyncAt: Date | null;

  // -- File selection (cross-block) --
  selectedFile: string | null;

  // -- Actions --
  startBuild: (planId: string) => void;
  pauseBuild: () => void;
  resumeBuild: () => void;
  cancelBuild: () => void;

  selectAgent: (agentId: string) => void;
  updateAgentStatus: (agentId: string, update: Partial<AgentState>) => void;
  addAgent: (agent: AgentState) => void;

  addPendingApproval: (approval: Approval) => void;
  resolveApproval: (approvalId: string, decision: string) => void;
  selectApproval: (approvalId: string) => void;

  switchLayout: (layoutId: string) => void;
  setConnectionStatus: (status: ConnectionStatus) => void;
  setSelectedFile: (filePath: string | null) => void;

  // Bulk update from SSE events
  applyStateSnapshot: (snapshot: OrchestratorStateSnapshot) => void;
  applyStateDelta: (delta: Partial<OrchestratorStateSnapshot>) => void;
}
```

### Store Creation with Slices

Split the store into logical slices for maintainability. Each slice manages a subset of state and actions.

```typescript
// store/index.ts
const useOrchestratorStore = create<OrchestratorState>()(
  immer((set, get) => ({
    // Build slice
    buildId: null,
    buildPhase: 0,
    buildStatus: 'idle' as BuildStatus,

    startBuild: (planId) => {
      set((state) => {
        state.buildId = planId;
        state.buildStatus = 'running';
        state.buildPhase = 1;
      });
      // Side effect: send REST request to backend
      fetch('/api/builds', {
        method: 'POST',
        body: JSON.stringify({ planId }),
      });
    },

    pauseBuild: () => {
      set((state) => { state.buildStatus = 'paused'; });
      fetch(`/api/builds/${get().buildId}/pause`, { method: 'POST' });
    },

    resumeBuild: () => {
      set((state) => { state.buildStatus = 'running'; });
      fetch(`/api/builds/${get().buildId}/resume`, { method: 'POST' });
    },

    cancelBuild: () => {
      set((state) => { state.buildStatus = 'failed'; });
      fetch(`/api/builds/${get().buildId}/cancel`, { method: 'POST' });
    },

    // Agent slice
    agents: [],
    activeAgentId: null,

    selectAgent: (agentId) => {
      set((state) => { state.activeAgentId = agentId; });
    },

    updateAgentStatus: (agentId, update) => {
      set((state) => {
        const agent = state.agents.find((a) => a.id === agentId);
        if (agent) Object.assign(agent, update);
      });
    },

    addAgent: (agent) => {
      set((state) => { state.agents.push(agent); });
    },

    // Approval slice
    pendingApprovals: [],
    approvalHistory: [],
    selectedApprovalId: null,

    addPendingApproval: (approval) => {
      set((state) => { state.pendingApprovals.push(approval); });
    },

    resolveApproval: (approvalId, decision) => {
      set((state) => {
        const idx = state.pendingApprovals.findIndex((a) => a.id === approvalId);
        if (idx !== -1) {
          const resolved = { ...state.pendingApprovals[idx], decision, decidedAt: new Date() };
          state.pendingApprovals.splice(idx, 1);
          state.approvalHistory.push(resolved);
        }
      });
    },

    selectApproval: (approvalId) => {
      set((state) => { state.selectedApprovalId = approvalId; });
    },

    // Layout slice
    activeLayout: 'overview',
    activePanelId: null,

    switchLayout: (layoutId) => {
      set((state) => { state.activeLayout = layoutId; });
    },

    // Connection slice
    connectionStatus: 'disconnected' as ConnectionStatus,
    lastSyncAt: null,

    setConnectionStatus: (status) => {
      set((state) => { state.connectionStatus = status; });
    },

    // File selection
    selectedFile: null,

    setSelectedFile: (filePath) => {
      set((state) => { state.selectedFile = filePath; });
    },

    // Bulk updates from SSE
    applyStateSnapshot: (snapshot) => {
      set((state) => {
        state.buildId = snapshot.buildId;
        state.buildPhase = snapshot.buildPhase;
        state.buildStatus = snapshot.buildStatus;
        state.agents = snapshot.agents;
        state.pendingApprovals = snapshot.pendingApprovals;
        state.lastSyncAt = new Date(snapshot.timestamp);
        state.connectionStatus = 'connected';
      });
    },

    applyStateDelta: (delta) => {
      set((state) => {
        if (delta.buildPhase !== undefined) state.buildPhase = delta.buildPhase;
        if (delta.buildStatus !== undefined) state.buildStatus = delta.buildStatus;
        if (delta.agents) {
          for (const updated of delta.agents) {
            const idx = state.agents.findIndex((a) => a.id === updated.id);
            if (idx !== -1) {
              Object.assign(state.agents[idx], updated);
            } else {
              state.agents.push(updated);
            }
          }
        }
        if (delta.pendingApprovals) {
          state.pendingApprovals = delta.pendingApprovals;
        }
        state.lastSyncAt = new Date();
      });
    },
  }))
);

export { useOrchestratorStore };
```

### Why immer Middleware

The `immer` middleware lets us write mutations directly (`state.buildPhase = 3`) instead of spreading nested objects. This is much more readable for complex state shapes and prevents accidental mutation bugs.

---

## 3. Zustand Performance

### useShallow for Multi-Value Selectors

When selecting multiple values from the store, use `useShallow` to prevent re-renders when unrelated state changes.

```typescript
import { useShallow } from 'zustand/react/shallow';

// GOOD: only re-renders when buildPhase OR buildStatus changes
const { buildPhase, buildStatus } = useOrchestratorStore(
  useShallow((s) => ({
    buildPhase: s.buildPhase,
    buildStatus: s.buildStatus,
  }))
);

// BAD: re-renders on EVERY store change because a new object is created each time
const { buildPhase, buildStatus } = useOrchestratorStore((s) => ({
  buildPhase: s.buildPhase,
  buildStatus: s.buildStatus,
}));
```

### Single-Value Selectors (No useShallow Needed)

For selecting a single primitive, a simple selector is sufficient. Zustand uses `Object.is` by default.

```typescript
// GOOD: simple selector for a single value
const activeAgentId = useOrchestratorStore((s) => s.activeAgentId);

// GOOD: custom equality for derived values
const agentCount = useOrchestratorStore(
  (s) => s.agents.filter((a) => a.status === 'running').length
);
```

### Subscription Outside React

For event handlers and non-React code, use `subscribe` or `getState`.

```typescript
// One-time read (no subscription)
const currentPhase = useOrchestratorStore.getState().buildPhase;

// Subscribe to changes
const unsubscribe = useOrchestratorStore.subscribe(
  (state) => state.connectionStatus,
  (status) => {
    if (status === 'disconnected') {
      showReconnectionBanner();
    }
  }
);
```

### Avoiding Re-Render Cascades

The most common performance issue: selecting an array or object that creates a new reference on every store update.

```typescript
// BAD: creates a new array reference every time any store state changes
const runningAgents = useOrchestratorStore((s) =>
  s.agents.filter((a) => a.status === 'running')
);

// GOOD: memoize outside Zustand with useMemo
const agents = useOrchestratorStore(useShallow((s) => s.agents));
const runningAgents = useMemo(
  () => agents.filter((a) => a.status === 'running'),
  [agents]
);

// ALSO GOOD: use a stable selector with custom equality
const runningAgentIds = useOrchestratorStore(
  (s) => s.agents.filter((a) => a.status === 'running').map((a) => a.id),
  (a, b) => a.length === b.length && a.every((id, i) => id === b[i])
);
```

---

## 4. Jotai Atom Patterns

### Basic Atoms

```typescript
import { atom } from 'jotai';

// Primitive atom: read/write
const logsAtom = atom<string[]>([]);

// Read in component
const logs = useAtomValue(logsAtom);

// Write in component
const setLogs = useSetAtom(logsAtom);
setLogs(['line 1', 'line 2']);
```

### Derived Atoms (Read-Only)

Derived atoms compute values from other atoms. They re-compute only when their dependencies change.

```typescript
const logsAtom = atom<string[]>([]);
const searchQueryAtom = atom('');

// Derived: filtered logs
const filteredLogsAtom = atom((get) => {
  const logs = get(logsAtom);
  const query = get(searchQueryAtom);
  if (!query) return logs;
  return logs.filter((line) => line.toLowerCase().includes(query.toLowerCase()));
});

// Derived: log count
const logCountAtom = atom((get) => get(logsAtom).length);
```

### Write-Only Atoms (Actions)

Atoms that only have a write function act as actions.

```typescript
const logsAtom = atom<string[]>([]);

// Write-only atom: append with auto-trim
const appendLogAtom = atom(null, (get, set, newLine: string) => {
  const MAX_LINES = 10_000;
  const current = get(logsAtom);
  if (current.length >= MAX_LINES) {
    set(logsAtom, [...current.slice(1), newLine]);
  } else {
    set(logsAtom, [...current, newLine]);
  }
});

// Usage
const appendLog = useSetAtom(appendLogAtom);
appendLog('New log line from agent');
```

### Atom Families (Parameterized Atoms)

When you need an atom per entity (e.g., per agent), use a factory pattern.

```typescript
import { atomFamily } from 'jotai/utils';

// Atom family: one status atom per agent
const agentStatusAtomFamily = atomFamily((agentId: string) =>
  atom<AgentStatus>('idle')
);

// Usage: get the atom for a specific agent
const statusAtom = agentStatusAtomFamily('backend-agent');
const status = useAtomValue(statusAtom);
```

### Atom with Async Default

For atoms that need to load initial data.

```typescript
const savedLayoutAtom = atom(async () => {
  const layout = await invoke<string>('load_layout', { layoutId: 'default' });
  return layout ? JSON.parse(layout) : defaultLayout;
});
```

### Store for Non-React Access

Jotai requires a store reference for access outside React components (event handlers, SSE processors).

```typescript
import { createStore } from 'jotai';

// Create a global store instance
export const jotaiStore = createStore();

// Use in React tree
import { Provider } from 'jotai';

<Provider store={jotaiStore}>
  <App />
</Provider>

// Access outside React
jotaiStore.set(logsAtom, ['line 1', 'line 2']);
const currentLogs = jotaiStore.get(logsAtom);
```

---

## 5. Jotai with React Flow

React Flow uses Zustand internally for its node/edge state. When building custom nodes that read from Jotai atoms, be aware of the two state systems interacting.

### The Interaction

```
React Flow's internal Zustand store
  └── manages: node positions, selection, viewport, edges

Our Zustand store
  └── manages: agent statuses, build phase, active agent

Our Jotai atoms (per block)
  └── manages: DAG node data, animation state, layout direction
```

### Custom Node Pattern

Custom nodes read agent data from our Zustand store (via selectors) and visual state from Jotai atoms. React Flow handles positioning.

```tsx
const AgentTaskNode = memo(({ data, id }: NodeProps<AgentTaskData>) => {
  // From our Zustand store: agent status
  const status = useOrchestratorStore(
    (s) => s.agents.find((a) => a.id === data.agentId)?.status
  );

  // From Jotai: animation state for this node
  const isAnimating = useAtomValue(
    useMemo(() => atom((get) => get(animatingNodesAtom).has(id)), [id])
  );

  // React Flow handles: position, dragging, selection
  // We only handle: visual appearance based on status

  return (
    <motion.div animate={{ borderColor: statusColor(status) }}>
      <Handle type="target" position={Position.Top} />
      <span>{data.label}</span>
      <Handle type="source" position={Position.Bottom} />
    </motion.div>
  );
});
```

### Why This Matters

If you put node data into React Flow's internal store (via `setNodes` with data changes), React Flow triggers a re-render of all nodes unless you use `React.memo` and stable references. By keeping agent status in our Zustand store and reading it via selector inside the memo'd node, only the affected node re-renders.

---

## 6. SSE to State Flow

The complete data flow from SSE event to rendered component.

### Pipeline

```
EventSource (browser)
  │
  ▼
pendingEvents array (buffer)
  │
  ├── 50ms batch timer fires
  │
  ▼
Zustand store batch update (applyStateDelta / applyStateSnapshot)
  │
  ├── Cross-block selectors re-evaluate
  │   └── Components subscribed to changed selectors re-render
  │
  ▼
Jotai atom routing (per-agent events → block atoms)
  │
  ├── Block-local atom updates
  │   └── Block components subscribed to changed atoms re-render
  │
  ▼
UI renders at next animation frame
```

### Implementation

```typescript
// sse-processor.ts
const pendingEvents: OrchestratorEvent[] = [];
let flushTimer: ReturnType<typeof setTimeout> | null = null;

const BATCH_WINDOW_MS = 50; // 50ms default, tunable

function onSSEMessage(rawEvent: MessageEvent): void {
  try {
    const event = JSON.parse(rawEvent.data) as OrchestratorEvent;
    pendingEvents.push(event);

    if (!flushTimer) {
      flushTimer = setTimeout(flushEvents, BATCH_WINDOW_MS);
    }
  } catch (err) {
    console.error('Failed to parse SSE event:', err);
    // Skip invalid events, do not crash the event loop
  }
}

function flushEvents(): void {
  flushTimer = null;
  if (pendingEvents.length === 0) return;

  const batch = pendingEvents.splice(0, pendingEvents.length);

  // 1. Process state snapshots first (they replace everything)
  const snapshots = batch.filter((e) => e.type === 'STATE_SNAPSHOT');
  if (snapshots.length > 0) {
    // Use the latest snapshot only
    const latest = snapshots[snapshots.length - 1] as StateSnapshotEvent;
    useOrchestratorStore.getState().applyStateSnapshot(latest.state);
  }

  // 2. Process deltas
  const deltas = batch.filter((e) => e.type === 'STATE_DELTA');
  for (const delta of deltas as StateDeltaEvent[]) {
    useOrchestratorStore.getState().applyStateDelta(delta.delta);
  }

  // 3. Route remaining events to block atoms
  const otherEvents = batch.filter(
    (e) => e.type !== 'STATE_SNAPSHOT' && e.type !== 'STATE_DELTA'
  );
  for (const event of otherEvents) {
    routeToBlockAtom(event);
  }
}
```

### Routing to Block Atoms

```typescript
// block-event-router.ts
function routeToBlockAtom(event: OrchestratorEvent): void {
  const { agentId, type } = event;

  switch (type) {
    case 'TEXT_MESSAGE_CONTENT': {
      const atoms = findAgentOutputAtoms(agentId);
      if (atoms) {
        jotaiStore.set(atoms.appendLogAtom, (event as TextMessageContentEvent).content);
      }
      break;
    }

    case 'RUN_STARTED': {
      const atoms = findAgentOutputAtoms(agentId);
      if (atoms) {
        jotaiStore.set(atoms.statusAtom, 'running');
      }
      // Also add node to DAG if not present
      addDagNodeIfMissing(agentId, event.agentRole);
      break;
    }

    case 'RUN_FINISHED': {
      const finished = event as RunFinishedEvent;
      const atoms = findAgentOutputAtoms(agentId);
      if (atoms) {
        jotaiStore.set(
          atoms.statusAtom,
          finished.outcome === 'success' ? 'completed' : finished.outcome
        );
      }
      if (finished.outcome === 'interrupt') {
        // Handled by Zustand (cross-block: approval queue)
        useOrchestratorStore.getState().addPendingApproval(
          interruptToApproval(finished)
        );
      }
      break;
    }

    case 'TOOL_CALL_START':
    case 'TOOL_CALL_ARGS':
    case 'TOOL_CALL_RESULT':
    case 'TOOL_CALL_END': {
      // Route to agent's log viewer
      const atoms = findLogViewerAtoms(agentId);
      if (atoms) {
        jotaiStore.set(atoms.appendLogAtom, formatToolCallEvent(event));
      }
      break;
    }

    case 'RAW': {
      routeCustomEvent(event as RawEvent);
      break;
    }
  }
}
```

### Dynamic Batch Window

Tune the batch window based on user activity for optimal responsiveness vs. efficiency.

```typescript
function getDynamicBatchWindow(): number {
  const hasFocus = document.hasFocus();
  const isIdle = Date.now() - lastUserInteraction > 30_000;

  if (!hasFocus) return 200;    // Background tab: batch aggressively
  if (isIdle) return 100;       // Idle user: moderate batching
  return 50;                    // Active user: responsive batching
}
```

---

## 7. Cross-Block Communication

All cross-block communication flows through Zustand. This is a hard rule. See the block architecture guide for the rationale.

### Pattern: Selection Propagation

The most common cross-block pattern: clicking an agent in one block selects it in all blocks.

```typescript
// In DAG block: user clicks a node
function onNodeClick(nodeId: string, data: AgentTaskData) {
  useOrchestratorStore.getState().selectAgent(data.agentId);
}

// In agent-output block: respond to selection change
function AgentOutputBlock({ atoms, config }: AgentOutputBlockProps) {
  const activeAgentId = useOrchestratorStore((s) => s.activeAgentId);

  useEffect(() => {
    if (activeAgentId && activeAgentId !== config.params.agentId) {
      // Switch terminal to the newly selected agent
      switchTerminalAgent(atoms, activeAgentId);
    }
  }, [activeAgentId]);

  // ...
}
```

### Pattern: Event Broadcasting

When an event should affect multiple blocks (e.g., QA gate interrupt affects DAG, kanban, and approval queue).

```typescript
// SSE event handler: interrupt received
// 1. Zustand handles the cross-block state
useOrchestratorStore.getState().addPendingApproval(approval);

// 2. Each block reads from Zustand via its own selector:

// DAG block: reads agent status → node turns yellow
const status = useOrchestratorStore((s) =>
  s.agents.find((a) => a.id === agentId)?.status
);

// Kanban block: reads agent status → card moves to "waiting" column
const agents = useOrchestratorStore(useShallow((s) => s.agents));

// Approval queue: reads pending approvals → new card appears
const pending = useOrchestratorStore(useShallow((s) => s.pendingApprovals));
```

### Pattern: File Selection Chain

File tree click → Zustand → diff viewer loads file.

```typescript
// file-tree block
function onFileClick(filePath: string) {
  useOrchestratorStore.getState().setSelectedFile(filePath);
}

// diff-viewer block
function DiffViewerBlock({ atoms }: DiffViewerBlockProps) {
  const selectedFile = useOrchestratorStore((s) => s.selectedFile);

  useEffect(() => {
    if (selectedFile) {
      loadFileDiff(atoms, selectedFile);
    }
  }, [selectedFile]);
}
```

---

## 8. Persistence

### Zustand persist Middleware

For Zustand state that should survive app restarts (layout, preferences, not live build state).

```typescript
import { persist, createJSONStorage } from 'zustand/middleware';

const usePreferencesStore = create<PreferencesState>()(
  persist(
    (set) => ({
      theme: 'dark' as Theme,
      fontSize: 13,
      activeLayout: 'overview',
      recentBuilds: [] as string[],

      setTheme: (theme: Theme) => set({ theme }),
      setFontSize: (size: number) => set({ fontSize: size }),
    }),
    {
      name: 'dashboard-preferences',
      storage: createJSONStorage(() => localStorage),
      // Only persist specific fields
      partialState: (state) => ({
        theme: state.theme,
        fontSize: state.fontSize,
        activeLayout: state.activeLayout,
        recentBuilds: state.recentBuilds,
      }),
    }
  )
);
```

### Custom Storage for Tauri

For desktop persistence via SQLite instead of localStorage.

```typescript
import { invoke } from '@tauri-apps/api/core';

const tauriStorage = {
  getItem: async (name: string): Promise<string | null> => {
    return invoke<string | null>('get_setting', { key: name });
  },
  setItem: async (name: string, value: string): Promise<void> => {
    await invoke('set_setting', { key: name, value });
  },
  removeItem: async (name: string): Promise<void> => {
    await invoke('remove_setting', { key: name });
  },
};

const usePreferencesStore = create<PreferencesState>()(
  persist(
    (set) => ({ /* ... */ }),
    {
      name: 'dashboard-preferences',
      storage: createJSONStorage(() => tauriStorage),
    }
  )
);
```

### Jotai Atom Serialization

Jotai atoms do not have built-in persistence. Block serialization is handled by the block lifecycle (see block architecture guide, section 7).

```typescript
// Serialize: read atoms from the Jotai store and convert to JSON
function serializeBlockAtoms(atoms: AgentOutputAtoms): SerializedBlockState {
  return {
    version: 1,
    data: {
      logs: jotaiStore.get(atoms.logsAtom).slice(-1000), // last 1K lines
      isFollowing: jotaiStore.get(atoms.isFollowingAtom),
      rendererType: jotaiStore.get(atoms.rendererTypeAtom),
    },
    timestamp: Date.now(),
  };
}

// Deserialize: create atoms and populate from saved data
function deserializeBlockAtoms(
  saved: SerializedBlockState,
  config: BlockConfig
): AgentOutputAtoms {
  const atoms = createAgentOutputAtoms(config);

  if (saved.version === 1) {
    jotaiStore.set(atoms.logsAtom, (saved.data.logs as string[]) ?? []);
    jotaiStore.set(atoms.isFollowingAtom, (saved.data.isFollowing as boolean) ?? true);
    jotaiStore.set(atoms.rendererTypeAtom, (saved.data.rendererType as string) ?? 'canvas');
  }

  return atoms;
}
```

---

## 9. Testing

### Testing Zustand Stores

Reset the store between tests to prevent state leakage.

```typescript
import { act } from '@testing-library/react';

// Reset store to initial state before each test
beforeEach(() => {
  act(() => {
    useOrchestratorStore.setState({
      buildId: null,
      buildPhase: 0,
      buildStatus: 'idle',
      agents: [],
      activeAgentId: null,
      pendingApprovals: [],
      approvalHistory: [],
      connectionStatus: 'disconnected',
      lastSyncAt: null,
      selectedFile: null,
      activeLayout: 'overview',
      activePanelId: null,
      selectedApprovalId: null,
    });
  });
});

describe('OrchestratorStore', () => {
  it('adds an agent and selects it', () => {
    const agent: AgentState = {
      id: 'backend-agent-1',
      role: 'backend-agent',
      status: 'running',
      currentStep: 'Generating API routes',
      progress: 25,
      tokenUsage: 1500,
      cost: 0.05,
      startedAt: new Date(),
      completedAt: null,
      error: null,
    };

    act(() => {
      useOrchestratorStore.getState().addAgent(agent);
      useOrchestratorStore.getState().selectAgent('backend-agent-1');
    });

    const state = useOrchestratorStore.getState();
    expect(state.agents).toHaveLength(1);
    expect(state.activeAgentId).toBe('backend-agent-1');
  });

  it('applies state snapshot from SSE', () => {
    const snapshot: OrchestratorStateSnapshot = {
      buildId: 'build-123',
      buildPhase: 3,
      buildStatus: 'running',
      agents: [
        { id: 'be-1', role: 'backend-agent', status: 'completed', /* ... */ },
        { id: 'fe-1', role: 'frontend-agent', status: 'running', /* ... */ },
      ],
      pendingApprovals: [],
      metrics: {},
      timestamp: Date.now(),
    };

    act(() => {
      useOrchestratorStore.getState().applyStateSnapshot(snapshot);
    });

    const state = useOrchestratorStore.getState();
    expect(state.buildPhase).toBe(3);
    expect(state.agents).toHaveLength(2);
    expect(state.connectionStatus).toBe('connected');
  });

  it('resolves approval and moves to history', () => {
    const approval: Approval = {
      id: 'approval-1',
      buildId: 'build-123',
      agentId: 'backend-agent-1',
      agentRole: 'backend-agent',
      gateType: 'quality_gate',
      payload: {},
      status: 'pending',
      createdAt: new Date(),
    };

    act(() => {
      useOrchestratorStore.getState().addPendingApproval(approval);
    });
    expect(useOrchestratorStore.getState().pendingApprovals).toHaveLength(1);

    act(() => {
      useOrchestratorStore.getState().resolveApproval('approval-1', 'approved');
    });
    expect(useOrchestratorStore.getState().pendingApprovals).toHaveLength(0);
    expect(useOrchestratorStore.getState().approvalHistory).toHaveLength(1);
  });
});
```

### Testing Jotai Atoms

Use a test store or the `@testing-library/react` `renderHook` with a Provider.

```typescript
import { createStore } from 'jotai';
import { renderHook, act } from '@testing-library/react';

describe('AgentOutput atoms', () => {
  let store: ReturnType<typeof createStore>;
  let atoms: AgentOutputAtoms;

  beforeEach(() => {
    store = createStore();
    atoms = createAgentOutputAtoms({
      id: 'test-block',
      blockType: 'agent-output',
      params: { agentId: 'backend-agent' },
      layoutId: 'test',
    });
  });

  it('appends log lines with auto-trim', () => {
    // Write 15K lines
    for (let i = 0; i < 15_000; i++) {
      const current = store.get(atoms.logsAtom);
      if (current.length >= 10_000) {
        store.set(atoms.logsAtom, [...current.slice(1), `line ${i}`]);
      } else {
        store.set(atoms.logsAtom, [...current, `line ${i}`]);
      }
    }

    expect(store.get(atoms.logsAtom)).toHaveLength(10_000);
    expect(store.get(atoms.logsAtom)[9999]).toBe('line 14999');
  });

  it('serializes and deserializes correctly', () => {
    store.set(atoms.logsAtom, ['line 1', 'line 2', 'line 3']);
    store.set(atoms.isFollowingAtom, false);

    const serialized = serializeBlockAtoms(atoms);
    expect(serialized.version).toBe(1);
    expect(serialized.data.logs).toHaveLength(3);

    // Recreate from serialized
    const restored = deserializeBlockAtoms(serialized, atoms.configAtom);
    expect(store.get(restored.logsAtom)).toEqual(['line 1', 'line 2', 'line 3']);
    expect(store.get(restored.isFollowingAtom)).toBe(false);
  });
});
```

### Testing SSE Event Processing

```typescript
describe('SSE Event Processing', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    resetAllStores();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('batches events within 50ms window', () => {
    // Simulate 3 events arriving within 50ms
    onSSEMessage(createMessageEvent({ type: 'STATE_DELTA', ... }));
    onSSEMessage(createMessageEvent({ type: 'TEXT_MESSAGE_CONTENT', ... }));
    onSSEMessage(createMessageEvent({ type: 'TOOL_CALL_START', ... }));

    // Events not yet processed
    expect(useOrchestratorStore.getState().buildPhase).toBe(0);

    // Advance timer past batch window
    vi.advanceTimersByTime(50);

    // Now all 3 events are processed
    expect(useOrchestratorStore.getState().buildPhase).toBe(3);
  });

  it('processes STATE_SNAPSHOT before deltas', () => {
    // Delta arrives first, then snapshot
    onSSEMessage(createMessageEvent({
      type: 'STATE_DELTA',
      delta: { buildPhase: 5 },
    }));
    onSSEMessage(createMessageEvent({
      type: 'STATE_SNAPSHOT',
      state: { buildPhase: 3, agents: [...] },
    }));

    vi.advanceTimersByTime(50);

    // Snapshot should be applied first, then delta
    // But since snapshot replaces everything, final state comes from snapshot processing order
    // In practice, snapshot wins because it's processed first in the flush function
    expect(useOrchestratorStore.getState().buildPhase).toBe(3);
  });
});
```

---

## 10. Anti-Patterns

### Do Not: Subscribe to the Entire Store

```typescript
// BAD: component re-renders on every store change
function MyComponent() {
  const store = useOrchestratorStore();
  return <div>{store.buildPhase}</div>;
}

// GOOD: subscribe to only what you need
function MyComponent() {
  const buildPhase = useOrchestratorStore((s) => s.buildPhase);
  return <div>{buildPhase}</div>;
}
```

### Do Not: Derive Arrays Without Memoization

```typescript
// BAD: new array reference on every render, triggers children re-render
function AgentList() {
  const running = useOrchestratorStore((s) =>
    s.agents.filter((a) => a.status === 'running')
  );
  return running.map((a) => <AgentCard key={a.id} agent={a} />);
}

// GOOD: memoize derived arrays
function AgentList() {
  const agents = useOrchestratorStore(useShallow((s) => s.agents));
  const running = useMemo(
    () => agents.filter((a) => a.status === 'running'),
    [agents]
  );
  return running.map((a) => <AgentCard key={a.id} agent={a} />);
}
```

### Do Not: Mutate Atoms Directly Outside the Store

```typescript
// BAD: direct mutation bypasses Jotai's subscription system
const logs = jotaiStore.get(atoms.logsAtom);
logs.push('new line'); // mutates the array in place, Jotai does not detect the change

// GOOD: set a new value
const logs = jotaiStore.get(atoms.logsAtom);
jotaiStore.set(atoms.logsAtom, [...logs, 'new line']);
```

### Do Not: Use Jotai for Cross-Block State

```typescript
// BAD: Block A writes to an atom, Block B reads it
// This creates hidden coupling and breaks block independence
const sharedAtom = atom<string | null>(null);
// Block A: store.set(sharedAtom, 'backend-agent')
// Block B: const value = useAtomValue(sharedAtom)

// GOOD: Use Zustand for cross-block state
// Block A: useOrchestratorStore.getState().selectAgent('backend-agent')
// Block B: const agentId = useOrchestratorStore((s) => s.activeAgentId)
```

### Do Not: Use Zustand for High-Frequency Block-Local Updates

```typescript
// BAD: terminal output updating global store at 100Hz
// Every log line triggers all store subscribers to re-evaluate
useOrchestratorStore.getState().appendLog(agentId, logLine);

// GOOD: use Jotai atoms for high-frequency block-local state
jotaiStore.set(blockAtoms.logsAtom, [...currentLogs, logLine]);
// Only the block subscribed to this atom re-renders
```

### Do Not: Create Atoms Inside Components

```typescript
// BAD: new atom created every render, subscriptions leak
function MyBlock() {
  const myAtom = atom(0); // new atom each render!
  const value = useAtomValue(myAtom);
  return <div>{value}</div>;
}

// GOOD: create atoms once, outside the component (or in createAtoms factory)
const myAtom = atom(0);
function MyBlock() {
  const value = useAtomValue(myAtom);
  return <div>{value}</div>;
}
```

### Do Not: Forget React.memo on React Flow Nodes and @dnd-kit Cards

```typescript
// BAD: every node re-renders when ANY node changes
function AgentNode({ data }: NodeProps) {
  return <div>{data.label}</div>;
}
const nodeTypes = { agent: AgentNode };

// GOOD: memo prevents cascade
const AgentNode = memo(({ data }: NodeProps) => {
  return <div>{data.label}</div>;
});
const nodeTypes = { agent: AgentNode };
```

### Do Not: Put nodeTypes Inside a Component

```typescript
// BAD: new object reference every render, React Flow re-registers all nodes
function DagBlock() {
  const nodeTypes = { agent: AgentNode }; // new object each render!
  return <ReactFlow nodeTypes={nodeTypes} />;
}

// GOOD: stable reference at module scope
const nodeTypes = { agent: AgentNode };
function DagBlock() {
  return <ReactFlow nodeTypes={nodeTypes} />;
}
```
