# Phase 1: Foundation Shell

**Version:** 0.1.0-draft
**Date:** 2026-03-20
**Status:** Design
**Duration:** 2-3 weeks
**Dependencies:** None (entry point)
**Parent:** `00-master-architecture-spec.md`

---

## 1. Phase Objective

Deliver a launchable Tauri v2 desktop application containing an empty but fully functional dashboard shell: block registry, global and per-block state management, SSE streaming skeleton with self-healing reconnection, SQLite persistence, layout system with presets and save/restore, and basic chrome (window frame, nav rail, system tray). Every subsequent phase plugs into the infrastructure established here.

At the end of this phase, a developer can launch the app, see a resizable panel layout with a nav rail listing available block types, observe an SSE connection establishing and processing mock events, and close/reopen the app with the layout intact.

---

## 2. Scope

### In Scope

- Tauri v2 project scaffolding (Rust backend + React 19 frontend + TypeScript 5)
- Block registry implementation (Wave Terminal pattern: type string to ViewModel + Component)
- Zustand store for global orchestrator state (build status, agent fleet, approvals, connection)
- Jotai atom factories for per-block state isolation
- `react-resizable-panels` layout system with preset layouts and persistence
- SSE streaming skeleton (EventSource connection, reconnection with exponential backoff, 50ms event batching)
- 5-second full state snapshot refresh mechanism
- SQLite database setup (rusqlite) with initial schema
- Tauri IPC bridge (invoke commands, emit events)
- Basic chrome: window frame, nav rail sidebar, status bar, system tray icon
- Mock event source for development (generates fake agent events)
- Project-level tooling: ESLint, Prettier, Vitest, Cargo test

### Out of Scope

- Actual block implementations (Phase 2)
- Agent subprocess management (Phase 3)
- AG-UI protocol adapter (Phase 3)
- WebSocket terminal connections (Phase 3)
- Plugin architecture (Phase 7)

---

## 3. Project Structure

```
agentic-ui-dashboard/
  src-tauri/
    Cargo.toml
    tauri.conf.json
    build.rs
    src/
      main.rs                      # Tauri entry point
      lib.rs                       # App setup, state initialization
      commands/
        mod.rs
        build.rs                   # start_build, pause_build, get_build_status
        layout.rs                  # save_layout, load_layout, list_layouts
        blocks.rs                  # list_block_types, get_block_state
        system.rs                  # get_system_info, health_check
      db/
        mod.rs
        connection.rs              # SQLite connection pool (WAL mode)
        migrations/
          mod.rs
          001_initial_schema.sql   # Core tables
          002_seed_layouts.sql     # Default layout presets
      events/
        mod.rs
        bus.rs                     # tokio::broadcast event bus
        sse.rs                     # axum SSE endpoint
        mock.rs                    # Mock event generator for dev
      process/                     # Stub directory for Phase 3
        mod.rs                     # Empty module with placeholder types
      plugins/                     # Stub directory for Phase 7
        mod.rs                     # Empty module with placeholder types
      state.rs                     # AppState struct (shared via Tauri managed state)
      types.rs                     # Shared Rust types (AgentRole, ProcessStatus, etc.)

  src/
    main.tsx                       # React entry point
    App.tsx                        # Root component with providers
    vite-env.d.ts
    blocks/
      registry.ts                  # Block registry (Map<string, BlockDefinition>)
      types.ts                     # BlockDefinition, BlockConfig, SerializedBlock interfaces
      placeholder/
        PlaceholderBlock.tsx        # Default placeholder block for testing registry
        atoms.ts                   # Placeholder atom factory
    state/
      orchestrator-store.ts        # Zustand global store
      atoms/
        index.ts                   # Atom factory exports
        agent-output-atoms.ts      # Agent output block atoms (stub for Phase 2)
        dag-atoms.ts               # DAG block atoms (stub for Phase 2)
        log-viewer-atoms.ts        # Log viewer block atoms (stub for Phase 2)
    streaming/
      sse-client.ts                # SSE connection manager with reconnection
      event-router.ts              # Route events to Zustand store + block atoms
      event-types.ts               # AG-UI event type definitions
      mock-source.ts               # Client-side mock event generator
    layout/
      DashboardLayout.tsx          # react-resizable-panels wrapper
      presets.ts                   # Layout preset definitions
      LayoutPersistence.ts         # Save/restore to localStorage + SQLite
    components/
      NavRail.tsx                  # Sidebar with block type list
      BlockContainer.tsx           # Block wrapper (header bar, controls, error boundary)
      StatusBar.tsx                # Connection status, build phase, sync indicator
      AppShell.tsx                 # Top-level layout (nav rail + panels + status bar)
      EmptyState.tsx               # Shown when no blocks are placed
      WindowControls.tsx           # Tauri window frame controls
    hooks/
      useBlock.ts                  # Block lifecycle hook (create, dispose, serialize)
      useSSE.ts                    # SSE connection hook with status tracking
      useTauriCommand.ts           # Typed Tauri invoke wrapper
      useLayoutPersistence.ts      # Auto-save layout on change
    lib/
      tauri-ipc.ts                 # Typed wrappers around Tauri invoke/emit
      utils.ts                     # Shared utilities
    styles/
      globals.css                  # Tailwind base + custom properties
      nav-rail.css                 # Nav rail specific styles

  index.html
  package.json
  tsconfig.json
  tsconfig.node.json
  vite.config.ts
  tailwind.config.ts
  eslint.config.js
  .prettierrc
```

---

## 4. Dependency Manifests

### Cargo.toml

```toml
[package]
name = "agentic-ui-dashboard"
version = "0.1.0"
edition = "2021"

[dependencies]
tauri = { version = "2", features = ["tray-icon", "devtools"] }
tauri-plugin-shell = "2"
tauri-plugin-window-state = "2"
tokio = { version = "1", features = ["full"] }
rusqlite = { version = "0.31", features = ["bundled"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
axum = { version = "0.7", features = ["sse"] }
axum-extra = { version = "0.9", features = ["typed-header"] }
tower-http = { version = "0.5", features = ["cors"] }
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1", features = ["v4", "serde"] }
anyhow = "1"
thiserror = "1"
tracing = "0.1"
tracing-subscriber = "0.3"

[build-dependencies]
tauri-build = { version = "2", features = [] }

[features]
default = ["custom-protocol"]
custom-protocol = ["tauri/custom-protocol"]
```

### package.json

```json
{
  "name": "agentic-ui-dashboard",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "eslint src/",
    "format": "prettier --write src/",
    "tauri": "tauri"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "@tauri-apps/api": "^2.0.0",
    "@tauri-apps/plugin-shell": "^2.0.0",
    "@tauri-apps/plugin-window-state": "^2.0.0",
    "zustand": "^5.0.0",
    "jotai": "^2.10.0",
    "react-resizable-panels": "^2.1.0",
    "lucide-react": "^0.460.0",
    "sonner": "^1.7.0",
    "clsx": "^2.1.0"
  },
  "devDependencies": {
    "@tauri-apps/cli": "^2.0.0",
    "typescript": "^5.6.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "vite": "^6.0.0",
    "@vitejs/plugin-react": "^4.3.0",
    "vitest": "^2.1.0",
    "@testing-library/react": "^16.0.0",
    "@testing-library/jest-dom": "^6.6.0",
    "tailwindcss": "^4.0.0",
    "@tailwindcss/vite": "^4.0.0",
    "eslint": "^9.0.0",
    "prettier": "^3.4.0",
    "prettier-plugin-tailwindcss": "^0.6.0"
  }
}
```

---

## 5. Block Registry

The block registry is the central extension point for the entire dashboard. It maps type identifier strings to their definition objects, following Wave Terminal's proven pattern. Every visual panel in the dashboard is a registered block type.

### TypeScript Interfaces

```typescript
// src/blocks/types.ts

import { type ComponentType } from "react";

/**
 * Configuration passed to a block when it is created.
 * Contains both static config (from layout presets) and
 * dynamic config (from user interaction or events).
 */
export interface BlockConfig {
  /** Unique instance ID for this block placement */
  instanceId: string;
  /** Block type identifier (must match a registry key) */
  blockType: string;
  /** Arbitrary config properties (agentId, filters, etc.) */
  props: Record<string, unknown>;
}

/**
 * Serialized block state for persistence.
 * Stored in SQLite and used to restore blocks after app restart.
 */
export interface SerializedBlock {
  instanceId: string;
  blockType: string;
  config: BlockConfig;
  state: Record<string, unknown>;
  serializedAt: string; // ISO 8601
}

/**
 * Block definition registered in the block registry.
 * Each block type provides its own atom factory, component,
 * and lifecycle hooks.
 *
 * TAtoms is the shape of the Jotai atoms returned by createAtoms.
 */
export interface BlockDefinition<TAtoms = unknown> {
  /** Unique type identifier (kebab-case) */
  type: string;

  /** Human-readable display name */
  displayName: string;

  /** Icon identifier (lucide-react icon name) */
  icon: string;

  /** Short description shown in block picker */
  description: string;

  /** Factory function that creates Jotai atoms for a block instance */
  createAtoms: (config: BlockConfig) => TAtoms;

  /** React component that renders the block */
  Component: ComponentType<BlockComponentProps<TAtoms>>;

  /** Serialize block atoms to a persistable object */
  serialize?: (atoms: TAtoms) => Record<string, unknown>;

  /** Restore block atoms from serialized state */
  deserialize?: (atoms: TAtoms, data: Record<string, unknown>) => void;

  /** Cleanup function called when block is removed */
  dispose?: (atoms: TAtoms) => void;

  /** Minimum panel size (percentage) for this block type */
  minSize?: number;

  /** Whether this block type can have multiple instances */
  allowMultiple?: boolean;
}

/**
 * Props passed to every block component.
 */
export interface BlockComponentProps<TAtoms = unknown> {
  atoms: TAtoms;
  config: BlockConfig;
  isActive: boolean;
}
```

### Registry Implementation

```typescript
// src/blocks/registry.ts

import { type BlockDefinition, type BlockConfig } from "./types";

class BlockRegistryImpl {
  private definitions = new Map<string, BlockDefinition>();
  private instances = new Map<string, { atoms: unknown; config: BlockConfig }>();

  /**
   * Register a block type definition.
   * Throws if a type with the same ID is already registered.
   */
  register<TAtoms>(definition: BlockDefinition<TAtoms>): void {
    if (this.definitions.has(definition.type)) {
      throw new Error(
        `Block type "${definition.type}" is already registered`
      );
    }
    this.definitions.set(definition.type, definition as BlockDefinition);
  }

  /**
   * Resolve a block type string to its definition.
   * Returns undefined if not found.
   */
  resolve(type: string): BlockDefinition | undefined {
    return this.definitions.get(type);
  }

  /**
   * Create a new block instance. Calls the definition's createAtoms factory
   * and stores the instance for lifecycle management.
   */
  createInstance(config: BlockConfig): unknown {
    const definition = this.definitions.get(config.blockType);
    if (!definition) {
      throw new Error(`Unknown block type: "${config.blockType}"`);
    }

    const atoms = definition.createAtoms(config);
    this.instances.set(config.instanceId, { atoms, config });
    return atoms;
  }

  /**
   * Dispose a block instance. Calls the definition's dispose hook
   * and removes the instance from tracking.
   */
  disposeInstance(instanceId: string): void {
    const instance = this.instances.get(instanceId);
    if (!instance) return;

    const definition = this.definitions.get(instance.config.blockType);
    if (definition?.dispose) {
      definition.dispose(instance.atoms);
    }
    this.instances.delete(instanceId);
  }

  /**
   * Serialize a block instance for persistence.
   */
  serializeInstance(instanceId: string): Record<string, unknown> | null {
    const instance = this.instances.get(instanceId);
    if (!instance) return null;

    const definition = this.definitions.get(instance.config.blockType);
    if (!definition?.serialize) return null;

    return definition.serialize(instance.atoms);
  }

  /**
   * Get all registered block type IDs and their display metadata.
   */
  listTypes(): Array<{
    type: string;
    displayName: string;
    icon: string;
    description: string;
  }> {
    return Array.from(this.definitions.values()).map((d) => ({
      type: d.type,
      displayName: d.displayName,
      icon: d.icon,
      description: d.description,
    }));
  }

  /**
   * Check if a block type is registered.
   */
  has(type: string): boolean {
    return this.definitions.has(type);
  }
}

/** Singleton block registry */
export const BlockRegistry = new BlockRegistryImpl();
```

---

## 6. Zustand Store (Global App State)

The Zustand store holds all cross-block, application-level state. Blocks read from it via selectors with `useShallow` to prevent unnecessary re-renders. The store is updated in two ways: (1) batch event processing from the SSE stream, and (2) direct user actions via the `actions` object.

```typescript
// src/state/orchestrator-store.ts

import { create } from "zustand";
import { subscribeWithSelector } from "zustand/middleware";
import { useShallow } from "zustand/react/shallow";

// --- Type definitions ---

export type BuildStatus = "idle" | "running" | "paused" | "completed" | "failed";
export type AgentStatus = "queued" | "spawning" | "running" | "waiting" | "completed" | "failed";
export type ConnectionStatus = "connected" | "reconnecting" | "disconnected";
export type ApprovalDecision = "approved" | "rejected" | "escalated";

export type AgentRole =
  | "backend"
  | "frontend"
  | "infrastructure"
  | "qe"
  | "security"
  | "docs"
  | "observability"
  | "db-migration"
  | "performance";

export interface AgentState {
  id: string;
  role: AgentRole;
  status: AgentStatus;
  currentStep: string;
  progress: number; // 0-100
  tokenUsage: number;
  cost: number;
  startedAt: string | null; // ISO 8601
  completedAt: string | null;
  error: string | null;
}

export interface Approval {
  id: string;
  buildId: string;
  agentId: string | null;
  gateType: "qa_gate" | "contract_mismatch" | "security";
  status: "pending" | "approved" | "rejected" | "escalated";
  payload: Record<string, unknown>;
  decision: ApprovalDecision | null;
  decidedBy: string | null;
  decidedAt: string | null;
  createdAt: string;
}

// --- Store shape ---

export interface OrchestratorState {
  // Build state
  buildId: string | null;
  buildPhase: number; // 0-14 (0 = not started)
  buildStatus: BuildStatus;

  // Agent fleet
  agents: AgentState[];
  activeAgentId: string | null;

  // Approvals
  pendingApprovals: Approval[];
  approvalHistory: Approval[];

  // Layout
  activeLayoutId: string;
  activePanelId: string | null;

  // Connection
  connectionStatus: ConnectionStatus;
  lastSyncAt: string | null; // ISO 8601
  reconnectAttempts: number;

  // Actions
  actions: {
    // Build control
    setBuildState: (state: Partial<Pick<OrchestratorState, "buildId" | "buildPhase" | "buildStatus">>) => void;

    // Agent fleet
    upsertAgent: (agent: AgentState) => void;
    removeAgent: (agentId: string) => void;
    selectAgent: (agentId: string | null) => void;

    // Approvals
    addApproval: (approval: Approval) => void;
    resolveApproval: (approvalId: string, decision: ApprovalDecision, decidedBy: string) => void;

    // Layout
    switchLayout: (layoutId: string) => void;
    setActivePanel: (panelId: string | null) => void;

    // Connection
    setConnectionStatus: (status: ConnectionStatus) => void;
    recordSync: () => void;
    incrementReconnectAttempts: () => void;
    resetReconnectAttempts: () => void;

    // Bulk state replacement (for STATE_SNAPSHOT events)
    applySnapshot: (snapshot: StateSnapshot) => void;
  };
}

export interface StateSnapshot {
  buildId: string | null;
  buildPhase: number;
  buildStatus: BuildStatus;
  agents: AgentState[];
  pendingApprovals: Approval[];
}

// --- Store creation ---

export const useOrchestratorStore = create<OrchestratorState>()(
  subscribeWithSelector((set, get) => ({
    // Initial state
    buildId: null,
    buildPhase: 0,
    buildStatus: "idle",
    agents: [],
    activeAgentId: null,
    pendingApprovals: [],
    approvalHistory: [],
    activeLayoutId: "overview",
    activePanelId: null,
    connectionStatus: "disconnected",
    lastSyncAt: null,
    reconnectAttempts: 0,

    actions: {
      setBuildState: (partial) => set(partial),

      upsertAgent: (agent) =>
        set((state) => {
          const index = state.agents.findIndex((a) => a.id === agent.id);
          if (index === -1) {
            return { agents: [...state.agents, agent] };
          }
          const updated = [...state.agents];
          updated[index] = agent;
          return { agents: updated };
        }),

      removeAgent: (agentId) =>
        set((state) => ({
          agents: state.agents.filter((a) => a.id !== agentId),
          activeAgentId:
            state.activeAgentId === agentId ? null : state.activeAgentId,
        })),

      selectAgent: (agentId) => set({ activeAgentId: agentId }),

      addApproval: (approval) =>
        set((state) => ({
          pendingApprovals: [...state.pendingApprovals, approval],
        })),

      resolveApproval: (approvalId, decision, decidedBy) =>
        set((state) => {
          const approval = state.pendingApprovals.find(
            (a) => a.id === approvalId
          );
          if (!approval) return state;

          const resolved: Approval = {
            ...approval,
            status: decision,
            decision,
            decidedBy,
            decidedAt: new Date().toISOString(),
          };

          return {
            pendingApprovals: state.pendingApprovals.filter(
              (a) => a.id !== approvalId
            ),
            approvalHistory: [...state.approvalHistory, resolved],
          };
        }),

      switchLayout: (layoutId) => set({ activeLayoutId: layoutId }),
      setActivePanel: (panelId) => set({ activePanelId: panelId }),

      setConnectionStatus: (status) => set({ connectionStatus: status }),
      recordSync: () =>
        set({ lastSyncAt: new Date().toISOString() }),
      incrementReconnectAttempts: () =>
        set((state) => ({
          reconnectAttempts: state.reconnectAttempts + 1,
        })),
      resetReconnectAttempts: () => set({ reconnectAttempts: 0 }),

      applySnapshot: (snapshot) =>
        set({
          buildId: snapshot.buildId,
          buildPhase: snapshot.buildPhase,
          buildStatus: snapshot.buildStatus,
          agents: snapshot.agents,
          pendingApprovals: snapshot.pendingApprovals,
          lastSyncAt: new Date().toISOString(),
        }),
    },
  }))
);

// --- Selector helpers ---

/**
 * Selector hook that returns only the agents array with shallow comparison.
 * Prevents re-render when unrelated store fields change.
 */
export function useAgents() {
  return useOrchestratorStore(useShallow((s) => s.agents));
}

/**
 * Selector hook for a single agent by ID.
 * Uses reference equality on the agent object.
 */
export function useAgent(agentId: string) {
  return useOrchestratorStore(
    (s) => s.agents.find((a) => a.id === agentId) ?? null
  );
}

export function useBuildStatus() {
  return useOrchestratorStore(
    useShallow((s) => ({
      buildId: s.buildId,
      buildPhase: s.buildPhase,
      buildStatus: s.buildStatus,
    }))
  );
}

export function useConnectionStatus() {
  return useOrchestratorStore(
    useShallow((s) => ({
      connectionStatus: s.connectionStatus,
      lastSyncAt: s.lastSyncAt,
      reconnectAttempts: s.reconnectAttempts,
    }))
  );
}
```

---

## 7. Jotai Atom Factories

Each block type defines an atom factory function that creates isolated Jotai atoms for a single block instance. This ensures blocks never share state accidentally and can be independently serialized/disposed.

```typescript
// src/state/atoms/index.ts

import { atom, type Atom, type WritableAtom } from "jotai";
import type { BlockConfig } from "../../blocks/types";

/**
 * Base atom set that every block type extends.
 * Provides common lifecycle atoms.
 */
export interface BaseBlockAtoms {
  /** Whether this block is currently visible/rendered */
  isVisibleAtom: WritableAtom<boolean, [boolean], void>;
  /** Whether this block has errored */
  errorAtom: WritableAtom<string | null, [string | null], void>;
  /** Timestamp of last data update */
  lastUpdatedAtom: WritableAtom<number, [number], void>;
}

export function createBaseAtoms(): BaseBlockAtoms {
  return {
    isVisibleAtom: atom(true),
    errorAtom: atom<string | null>(null),
    lastUpdatedAtom: atom(0),
  };
}

// --- Stub atom factories for Phase 2 block types ---

/**
 * Agent output block atoms.
 * Full implementation in Phase 2 when xterm.js is integrated.
 */
export interface AgentOutputAtoms extends BaseBlockAtoms {
  logsAtom: WritableAtom<string[], [string[]], void>;
  statusAtom: WritableAtom<string, [string], void>;
  agentIdAtom: Atom<string>;
  isFollowingAtom: WritableAtom<boolean, [boolean], void>;
  searchQueryAtom: WritableAtom<string, [string], void>;
}

export function createAgentOutputAtoms(config: BlockConfig): AgentOutputAtoms {
  const agentId = config.props.agentId as string;
  return {
    ...createBaseAtoms(),
    logsAtom: atom<string[]>([]),
    statusAtom: atom<string>("idle"),
    agentIdAtom: atom(agentId),
    isFollowingAtom: atom(true),
    searchQueryAtom: atom(""),
  };
}

/**
 * DAG visualization block atoms.
 * Full implementation in Phase 2 when React Flow is integrated.
 */
export interface DagVisualizationAtoms extends BaseBlockAtoms {
  nodesAtom: WritableAtom<unknown[], [unknown[]], void>;
  edgesAtom: WritableAtom<unknown[], [unknown[]], void>;
  selectedNodeAtom: WritableAtom<string | null, [string | null], void>;
  layoutDirectionAtom: WritableAtom<"TB" | "LR", ["TB" | "LR"], void>;
  animatingNodesAtom: WritableAtom<Set<string>, [Set<string>], void>;
}

export function createDagVisualizationAtoms(_config: BlockConfig): DagVisualizationAtoms {
  return {
    ...createBaseAtoms(),
    nodesAtom: atom<unknown[]>([]),
    edgesAtom: atom<unknown[]>([]),
    selectedNodeAtom: atom<string | null>(null),
    layoutDirectionAtom: atom<"TB" | "LR">("TB"),
    animatingNodesAtom: atom<Set<string>>(new Set()),
  };
}

/**
 * Log viewer block atoms.
 * Full implementation in Phase 2 when @melloware/react-logviewer is integrated.
 */
export interface LogViewerAtoms extends BaseBlockAtoms {
  logLinesAtom: WritableAtom<string[], [string[]], void>;
  filtersAtom: WritableAtom<Record<string, string>, [Record<string, string>], void>;
  followModeAtom: WritableAtom<boolean, [boolean], void>;
  searchQueryAtom: WritableAtom<string, [string], void>;
}

export function createLogViewerAtoms(_config: BlockConfig): LogViewerAtoms {
  return {
    ...createBaseAtoms(),
    logLinesAtom: atom<string[]>([]),
    filtersAtom: atom<Record<string, string>>({}),
    followModeAtom: atom(true),
    searchQueryAtom: atom(""),
  };
}
```

---

## 8. SSE Connection Manager

The SSE client manages the EventSource connection to the Rust backend's axum SSE endpoint. It handles reconnection with exponential backoff, `Last-Event-ID` tracking for resumption, and 50ms event batching to prevent render jank from high-frequency event streams.

```typescript
// src/streaming/sse-client.ts

import type { OrchestratorEvent } from "./event-types";

export interface SSEClientConfig {
  /** SSE endpoint URL */
  url: string;
  /** Batch window in milliseconds (default 50) */
  batchWindowMs?: number;
  /** Maximum reconnection attempts before giving up (default 20) */
  maxReconnectAttempts?: number;
  /** Base delay for exponential backoff in ms (default 1000) */
  baseReconnectDelayMs?: number;
  /** Maximum backoff delay in ms (default 30000) */
  maxReconnectDelayMs?: number;
  /** Callback invoked with each batch of events */
  onEventBatch: (events: OrchestratorEvent[]) => void;
  /** Callback invoked on connection status change */
  onStatusChange: (status: "connected" | "reconnecting" | "disconnected") => void;
  /** Callback invoked on unrecoverable error */
  onError: (error: Error) => void;
}

export class SSEClient {
  private eventSource: EventSource | null = null;
  private lastEventId: string | null = null;
  private reconnectAttempts = 0;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private pendingEvents: OrchestratorEvent[] = [];
  private flushTimer: ReturnType<typeof setTimeout> | null = null;
  private disposed = false;
  private config: Required<SSEClientConfig>;

  constructor(config: SSEClientConfig) {
    this.config = {
      batchWindowMs: 50,
      maxReconnectAttempts: 20,
      baseReconnectDelayMs: 1000,
      maxReconnectDelayMs: 30000,
      ...config,
    };
  }

  /**
   * Open the SSE connection. If a Last-Event-ID is available,
   * it is sent as a header for resumption.
   */
  connect(): void {
    if (this.disposed) return;
    this.cleanup();

    const url = this.lastEventId
      ? `${this.config.url}?lastEventId=${encodeURIComponent(this.lastEventId)}`
      : this.config.url;

    this.eventSource = new EventSource(url);

    this.eventSource.onopen = () => {
      this.reconnectAttempts = 0;
      this.config.onStatusChange("connected");
    };

    this.eventSource.onmessage = (event: MessageEvent) => {
      if (event.lastEventId) {
        this.lastEventId = event.lastEventId;
      }

      try {
        const parsed = JSON.parse(event.data) as OrchestratorEvent;
        this.enqueueEvent(parsed);
      } catch (err) {
        console.warn("Failed to parse SSE event:", event.data, err);
      }
    };

    // Listen for specific AG-UI event types
    for (const eventType of [
      "state_snapshot",
      "run_started",
      "run_finished",
      "text_message_content",
      "tool_call_start",
      "tool_call_end",
      "state_delta",
    ]) {
      this.eventSource.addEventListener(eventType, (event: Event) => {
        const messageEvent = event as MessageEvent;
        if (messageEvent.lastEventId) {
          this.lastEventId = messageEvent.lastEventId;
        }
        try {
          const parsed = JSON.parse(messageEvent.data) as OrchestratorEvent;
          parsed.eventType = eventType;
          this.enqueueEvent(parsed);
        } catch (err) {
          console.warn(`Failed to parse ${eventType} event:`, messageEvent.data, err);
        }
      });
    }

    this.eventSource.onerror = () => {
      this.eventSource?.close();
      this.eventSource = null;
      this.scheduleReconnect();
    };
  }

  /**
   * Enqueue an event into the 50ms batch window.
   * When the window expires, all accumulated events are flushed
   * together in a single callback.
   */
  private enqueueEvent(event: OrchestratorEvent): void {
    this.pendingEvents.push(event);

    if (!this.flushTimer) {
      this.flushTimer = setTimeout(() => {
        const batch = this.pendingEvents.splice(0);
        this.flushTimer = null;

        if (batch.length > 0) {
          this.config.onEventBatch(batch);
        }
      }, this.config.batchWindowMs);
    }
  }

  /**
   * Schedule a reconnection attempt with exponential backoff.
   * Delay = min(base * 2^attempts, maxDelay) + random jitter.
   */
  private scheduleReconnect(): void {
    if (this.disposed) return;

    if (this.reconnectAttempts >= this.config.maxReconnectAttempts) {
      this.config.onStatusChange("disconnected");
      this.config.onError(
        new Error(`SSE reconnection failed after ${this.reconnectAttempts} attempts`)
      );
      return;
    }

    this.config.onStatusChange("reconnecting");
    this.reconnectAttempts++;

    const delay = Math.min(
      this.config.baseReconnectDelayMs * Math.pow(2, this.reconnectAttempts - 1),
      this.config.maxReconnectDelayMs
    );
    const jitter = Math.random() * delay * 0.1; // 10% jitter

    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.connect();
    }, delay + jitter);
  }

  /**
   * Clean up the current connection and pending timers.
   */
  private cleanup(): void {
    if (this.eventSource) {
      this.eventSource.close();
      this.eventSource = null;
    }
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.flushTimer) {
      clearTimeout(this.flushTimer);
      this.flushTimer = null;
    }
  }

  /**
   * Permanently disconnect and dispose resources.
   * The client cannot be reconnected after this.
   */
  disconnect(): void {
    this.disposed = true;
    this.cleanup();
    // Flush any remaining events
    if (this.pendingEvents.length > 0) {
      this.config.onEventBatch(this.pendingEvents.splice(0));
    }
    this.config.onStatusChange("disconnected");
  }

  /**
   * Get current connection info for debugging.
   */
  getStatus(): {
    connected: boolean;
    lastEventId: string | null;
    reconnectAttempts: number;
  } {
    return {
      connected: this.eventSource?.readyState === EventSource.OPEN,
      lastEventId: this.lastEventId,
      reconnectAttempts: this.reconnectAttempts,
    };
  }
}
```

### Event Router

The event router receives batched events from the SSE client and dispatches them to the Zustand store (for global state updates) and to individual block Jotai atoms (for per-block updates).

```typescript
// src/streaming/event-router.ts

import { useOrchestratorStore } from "../state/orchestrator-store";
import type { OrchestratorEvent, StateSnapshotEvent, AgentStateEvent } from "./event-types";

/**
 * Process a batch of SSE events. Called from the SSE client's
 * onEventBatch callback every 50ms.
 *
 * Strategy:
 * 1. If batch contains a STATE_SNAPSHOT, apply it and skip deltas
 *    that precede it (snapshot is authoritative).
 * 2. Otherwise, apply each event as a delta update.
 */
export function processEventBatch(events: OrchestratorEvent[]): void {
  const store = useOrchestratorStore.getState();
  const { actions } = store;

  // Check for state snapshot (takes precedence)
  const snapshotIndex = events.findLastIndex(
    (e) => e.eventType === "state_snapshot"
  );

  if (snapshotIndex !== -1) {
    const snapshot = events[snapshotIndex] as StateSnapshotEvent;
    actions.applySnapshot(snapshot.state);
    // Process only events AFTER the snapshot
    const postSnapshotEvents = events.slice(snapshotIndex + 1);
    for (const event of postSnapshotEvents) {
      applyDeltaEvent(event, actions);
    }
  } else {
    // All delta events
    for (const event of events) {
      applyDeltaEvent(event, actions);
    }
  }

  actions.recordSync();
}

function applyDeltaEvent(
  event: OrchestratorEvent,
  actions: ReturnType<typeof useOrchestratorStore.getState>["actions"]
): void {
  switch (event.eventType) {
    case "run_started": {
      const e = event as AgentStateEvent;
      actions.upsertAgent({
        id: e.agentId,
        role: e.agentRole,
        status: "running",
        currentStep: "initializing",
        progress: 0,
        tokenUsage: 0,
        cost: 0,
        startedAt: new Date().toISOString(),
        completedAt: null,
        error: null,
      });
      break;
    }

    case "run_finished": {
      const e = event as AgentStateEvent;
      const outcome = e.outcome;

      if (outcome === "interrupt") {
        actions.addApproval({
          id: e.runId ?? crypto.randomUUID(),
          buildId: useOrchestratorStore.getState().buildId ?? "",
          agentId: e.agentId,
          gateType: (e.interrupt?.reason as "qa_gate" | "contract_mismatch" | "security") ?? "qa_gate",
          status: "pending",
          payload: e.interrupt?.payload ?? {},
          decision: null,
          decidedBy: null,
          decidedAt: null,
          createdAt: new Date().toISOString(),
        });
      }

      actions.upsertAgent({
        id: e.agentId,
        role: e.agentRole,
        status:
          outcome === "success"
            ? "completed"
            : outcome === "error"
              ? "failed"
              : "waiting",
        currentStep: outcome === "success" ? "done" : "awaiting decision",
        progress: outcome === "success" ? 100 : 0,
        tokenUsage: 0,
        cost: 0,
        startedAt: null,
        completedAt:
          outcome === "success" ? new Date().toISOString() : null,
        error: outcome === "error" ? (e.error?.message ?? "Unknown error") : null,
      });
      break;
    }

    case "state_delta": {
      const e = event as AgentStateEvent;
      const existing = useOrchestratorStore
        .getState()
        .agents.find((a) => a.id === e.agentId);
      if (existing) {
        actions.upsertAgent({
          ...existing,
          ...e.delta,
        });
      }
      break;
    }

    default:
      // Other event types will be handled by block-specific routers
      // in Phase 2 (text_message_content -> agent-output block, etc.)
      break;
  }
}
```

### Event Type Definitions

```typescript
// src/streaming/event-types.ts

import type { AgentRole, AgentStatus, BuildStatus } from "../state/orchestrator-store";

/**
 * Base event shape. All SSE events extend this.
 */
export interface OrchestratorEvent {
  /** AG-UI event type identifier */
  eventType: string;
  /** Unique event ID (used for Last-Event-ID tracking) */
  id?: string;
  /** Agent that produced this event */
  agentId: string;
  /** Agent role */
  agentRole: AgentRole;
  /** Current build phase */
  phaseId?: number;
  /** Timestamp in milliseconds */
  timestamp: number;
}

export interface StateSnapshotEvent extends OrchestratorEvent {
  eventType: "state_snapshot";
  state: {
    buildId: string | null;
    buildPhase: number;
    buildStatus: BuildStatus;
    agents: Array<{
      id: string;
      role: AgentRole;
      status: AgentStatus;
      currentStep: string;
      progress: number;
      tokenUsage: number;
      cost: number;
      startedAt: string | null;
      completedAt: string | null;
      error: string | null;
    }>;
    pendingApprovals: Array<{
      id: string;
      buildId: string;
      agentId: string | null;
      gateType: string;
      status: string;
      payload: Record<string, unknown>;
      createdAt: string;
    }>;
  };
}

export interface AgentStateEvent extends OrchestratorEvent {
  eventType: "run_started" | "run_finished" | "state_delta";
  runId?: string;
  outcome?: "success" | "error" | "interrupt";
  interrupt?: {
    reason: string;
    payload: Record<string, unknown>;
  };
  error?: {
    message: string;
    code?: string;
  };
  delta?: Partial<{
    status: AgentStatus;
    currentStep: string;
    progress: number;
    tokenUsage: number;
    cost: number;
  }>;
}

export interface TextMessageEvent extends OrchestratorEvent {
  eventType: "text_message_content";
  messageId: string;
  content: string;
}

export interface ToolCallEvent extends OrchestratorEvent {
  eventType: "tool_call_start" | "tool_call_args" | "tool_call_result" | "tool_call_end";
  toolCallId: string;
  toolName?: string;
  args?: string;
  result?: string;
}
```

---

## 9. 5-Second Full State Refresh

The Rust backend runs a tokio interval task that emits a `STATE_SNAPSHOT` event every 5 seconds on the broadcast channel. This guarantees that any missed SSE events are recovered within at most 5 seconds, making the dashboard self-healing.

```rust
// src-tauri/src/events/bus.rs (relevant excerpt)

use tokio::sync::broadcast;
use tokio::time::{interval, Duration};
use serde_json::Value as JsonValue;

pub struct EventBus {
    tx: broadcast::Sender<BusEvent>,
}

#[derive(Clone, Debug)]
pub struct BusEvent {
    pub event_type: String,
    pub payload: JsonValue,
    pub agent_id: Option<String>,
    pub timestamp: i64,
}

impl EventBus {
    pub fn new(capacity: usize) -> Self {
        let (tx, _) = broadcast::channel(capacity);
        Self { tx }
    }

    pub fn subscribe(&self) -> broadcast::Receiver<BusEvent> {
        self.tx.subscribe()
    }

    pub fn emit(&self, event: BusEvent) -> Result<usize, broadcast::error::SendError<BusEvent>> {
        self.tx.send(event)
    }

    /// Start the 5-second full state snapshot refresh task.
    /// Runs on the tokio runtime and emits STATE_SNAPSHOT events.
    pub fn start_snapshot_refresh(
        &self,
        state_provider: impl Fn() -> JsonValue + Send + Sync + 'static,
    ) {
        let tx = self.tx.clone();
        tokio::spawn(async move {
            let mut ticker = interval(Duration::from_secs(5));
            loop {
                ticker.tick().await;
                let snapshot = state_provider();
                let event = BusEvent {
                    event_type: "state_snapshot".to_string(),
                    payload: snapshot,
                    agent_id: None,
                    timestamp: chrono::Utc::now().timestamp_millis(),
                };
                // Ignore send errors (no subscribers)
                let _ = tx.send(event);
            }
        });
    }
}
```

---

## 10. SQLite Database Setup

### Connection Setup

```rust
// src-tauri/src/db/connection.rs

use rusqlite::{Connection, Result};
use std::path::Path;

/// Initialize SQLite database with WAL mode and migrations.
pub fn initialize_database(db_path: &Path) -> Result<Connection> {
    let conn = Connection::open(db_path)?;

    // Enable WAL mode for concurrent read/write
    conn.pragma_update(None, "journal_mode", "WAL")?;
    conn.pragma_update(None, "synchronous", "NORMAL")?;
    conn.pragma_update(None, "foreign_keys", "ON")?;

    // Run migrations
    run_migrations(&conn)?;

    Ok(conn)
}

fn run_migrations(conn: &Connection) -> Result<()> {
    // Create migrations tracking table
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );"
    )?;

    let applied: Vec<i32> = {
        let mut stmt = conn.prepare("SELECT version FROM schema_migrations ORDER BY version")?;
        stmt.query_map([], |row| row.get(0))?
            .collect::<Result<Vec<i32>>>()?
    };

    let migrations: Vec<(i32, &str, &str)> = vec![
        (1, "initial_schema", include_str!("migrations/001_initial_schema.sql")),
        (2, "seed_layouts", include_str!("migrations/002_seed_layouts.sql")),
    ];

    for (version, name, sql) in migrations {
        if !applied.contains(&version) {
            conn.execute_batch(sql)?;
            conn.execute(
                "INSERT INTO schema_migrations (version, name) VALUES (?1, ?2)",
                rusqlite::params![version, name],
            )?;
        }
    }

    Ok(())
}
```

### Initial Schema Migration

```sql
-- src-tauri/src/db/migrations/001_initial_schema.sql

-- Build sessions
CREATE TABLE IF NOT EXISTS builds (
    id TEXT PRIMARY KEY,
    plan_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'running', 'paused', 'completed', 'failed')),
    current_phase INTEGER DEFAULT 0,
    started_at DATETIME,
    completed_at DATETIME,
    metadata TEXT  -- JSON
);
CREATE INDEX IF NOT EXISTS idx_builds_status ON builds(status);

-- Agent instances per build
CREATE TABLE IF NOT EXISTS agents (
    id TEXT PRIMARY KEY,
    build_id TEXT NOT NULL REFERENCES builds(id),
    role TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'spawning', 'running', 'waiting', 'completed', 'failed')),
    worktree_path TEXT,
    pid INTEGER,
    started_at DATETIME,
    completed_at DATETIME,
    exit_code INTEGER,
    token_usage INTEGER DEFAULT 0,
    cost_cents INTEGER DEFAULT 0,
    error TEXT
);
CREATE INDEX IF NOT EXISTS idx_agents_build ON agents(build_id);
CREATE INDEX IF NOT EXISTS idx_agents_status ON agents(status);

-- Dashboard layouts
CREATE TABLE IF NOT EXISTS layouts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    panels TEXT NOT NULL,       -- JSON (PanelConfig tree)
    is_default BOOLEAN DEFAULT FALSE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Block layout state
CREATE TABLE IF NOT EXISTS blocks (
    id TEXT PRIMARY KEY,
    layout_id TEXT NOT NULL REFERENCES layouts(id),
    block_type TEXT NOT NULL,
    config TEXT NOT NULL,       -- JSON (BlockConfig)
    serialized_state TEXT,     -- JSON (for restore)
    position_index INTEGER,
    size_percent REAL,
    is_collapsed BOOLEAN DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_blocks_layout ON blocks(layout_id);

-- Event log (append-only, for replay)
CREATE TABLE IF NOT EXISTS event_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    build_id TEXT NOT NULL REFERENCES builds(id),
    agent_id TEXT,
    event_type TEXT NOT NULL,
    payload TEXT NOT NULL,      -- JSON (AG-UI event)
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_events_build ON event_log(build_id);
CREATE INDEX IF NOT EXISTS idx_events_agent ON event_log(agent_id);
CREATE INDEX IF NOT EXISTS idx_events_type ON event_log(event_type);
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON event_log(timestamp);

-- Approval queue
CREATE TABLE IF NOT EXISTS approvals (
    id TEXT PRIMARY KEY,
    build_id TEXT NOT NULL REFERENCES builds(id),
    agent_id TEXT,
    gate_type TEXT NOT NULL
        CHECK (gate_type IN ('qa_gate', 'contract_mismatch', 'security')),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected', 'escalated')),
    payload TEXT NOT NULL,      -- JSON
    decision TEXT,
    decided_by TEXT,
    decided_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_approvals_build ON approvals(build_id);
CREATE INDEX IF NOT EXISTS idx_approvals_status ON approvals(status);

-- Audit log (append-only)
CREATE TABLE IF NOT EXISTS audit_log (
    id TEXT PRIMARY KEY,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_id TEXT,
    agent_id TEXT,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT,
    old_value TEXT,    -- JSON
    new_value TEXT,    -- JSON
    metadata TEXT      -- JSON
);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_resource ON audit_log(resource_type, resource_id);
```

### Seed Layouts Migration

```sql
-- src-tauri/src/db/migrations/002_seed_layouts.sql

INSERT OR IGNORE INTO layouts (id, name, panels, is_default) VALUES
(
    'overview',
    'Overview',
    '{"direction":"horizontal","children":[{"blockType":"dag-visualization","size":60},{"direction":"vertical","size":40,"children":[{"blockType":"log-viewer","size":50},{"blockType":"placeholder","size":50}]}]}',
    TRUE
),
(
    'agent-focus',
    'Agent Focus',
    '{"direction":"horizontal","children":[{"blockType":"agent-output","size":50},{"direction":"vertical","size":50,"children":[{"blockType":"log-viewer","size":50},{"blockType":"dag-visualization","size":50}]}]}',
    FALSE
),
(
    'monitoring',
    'Monitoring',
    '{"direction":"horizontal","children":[{"blockType":"dag-visualization","size":40},{"direction":"vertical","size":60,"children":[{"blockType":"log-viewer","size":50},{"blockType":"placeholder","size":50}]}]}',
    FALSE
);
```

---

## 11. Tauri IPC Bridge

Tauri commands define the bridge between the React frontend and the Rust backend. Each command is an async function annotated with `#[tauri::command]` and registered in the Tauri builder.

```rust
// src-tauri/src/commands/build.rs

use crate::state::AppState;
use serde::{Deserialize, Serialize};

#[derive(Serialize)]
pub struct BuildInfo {
    pub id: String,
    pub status: String,
    pub current_phase: i32,
    pub started_at: Option<String>,
}

#[tauri::command]
pub async fn start_build(
    state: tauri::State<'_, AppState>,
    plan_id: String,
) -> Result<BuildInfo, String> {
    let db = state.db.lock().map_err(|e| e.to_string())?;
    let build_id = uuid::Uuid::new_v4().to_string();

    db.execute(
        "INSERT INTO builds (id, plan_id, status, started_at) VALUES (?1, ?2, 'running', datetime('now'))",
        rusqlite::params![build_id, plan_id],
    ).map_err(|e| e.to_string())?;

    Ok(BuildInfo {
        id: build_id,
        status: "running".to_string(),
        current_phase: 1,
        started_at: Some(chrono::Utc::now().to_rfc3339()),
    })
}

#[tauri::command]
pub async fn pause_build(
    state: tauri::State<'_, AppState>,
    build_id: String,
) -> Result<(), String> {
    let db = state.db.lock().map_err(|e| e.to_string())?;
    db.execute(
        "UPDATE builds SET status = 'paused' WHERE id = ?1 AND status = 'running'",
        rusqlite::params![build_id],
    ).map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
pub async fn get_build_status(
    state: tauri::State<'_, AppState>,
    build_id: String,
) -> Result<BuildInfo, String> {
    let db = state.db.lock().map_err(|e| e.to_string())?;
    db.query_row(
        "SELECT id, status, current_phase, started_at FROM builds WHERE id = ?1",
        rusqlite::params![build_id],
        |row| {
            Ok(BuildInfo {
                id: row.get(0)?,
                status: row.get(1)?,
                current_phase: row.get(2)?,
                started_at: row.get(3)?,
            })
        },
    ).map_err(|e| e.to_string())
}
```

```rust
// src-tauri/src/commands/layout.rs

use crate::state::AppState;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub struct LayoutInfo {
    pub id: String,
    pub name: String,
    pub panels: String, // JSON
    pub is_default: bool,
}

#[tauri::command]
pub async fn list_layouts(
    state: tauri::State<'_, AppState>,
) -> Result<Vec<LayoutInfo>, String> {
    let db = state.db.lock().map_err(|e| e.to_string())?;
    let mut stmt = db.prepare(
        "SELECT id, name, panels, is_default FROM layouts ORDER BY name"
    ).map_err(|e| e.to_string())?;

    let layouts = stmt.query_map([], |row| {
        Ok(LayoutInfo {
            id: row.get(0)?,
            name: row.get(1)?,
            panels: row.get(2)?,
            is_default: row.get(3)?,
        })
    }).map_err(|e| e.to_string())?
    .collect::<Result<Vec<_>, _>>()
    .map_err(|e| e.to_string())?;

    Ok(layouts)
}

#[tauri::command]
pub async fn save_layout(
    state: tauri::State<'_, AppState>,
    layout: LayoutInfo,
) -> Result<(), String> {
    let db = state.db.lock().map_err(|e| e.to_string())?;
    db.execute(
        "INSERT OR REPLACE INTO layouts (id, name, panels, is_default, updated_at)
         VALUES (?1, ?2, ?3, ?4, datetime('now'))",
        rusqlite::params![layout.id, layout.name, layout.panels, layout.is_default],
    ).map_err(|e| e.to_string())?;
    Ok(())
}
```

```rust
// src-tauri/src/commands/system.rs

use serde::Serialize;

#[derive(Serialize)]
pub struct SystemInfo {
    pub version: String,
    pub uptime_secs: f64,
    pub db_size_bytes: u64,
}

#[tauri::command]
pub async fn health_check() -> Result<SystemInfo, String> {
    Ok(SystemInfo {
        version: env!("CARGO_PKG_VERSION").to_string(),
        uptime_secs: 0.0, // TODO: track actual uptime
        db_size_bytes: 0,
    })
}
```

### Frontend IPC Wrappers

```typescript
// src/lib/tauri-ipc.ts

import { invoke } from "@tauri-apps/api/core";

export interface BuildInfo {
  id: string;
  status: string;
  current_phase: number;
  started_at: string | null;
}

export interface LayoutInfo {
  id: string;
  name: string;
  panels: string; // JSON
  is_default: boolean;
}

export const tauriCommands = {
  startBuild: (planId: string) =>
    invoke<BuildInfo>("start_build", { planId }),

  pauseBuild: (buildId: string) =>
    invoke<void>("pause_build", { buildId }),

  getBuildStatus: (buildId: string) =>
    invoke<BuildInfo>("get_build_status", { buildId }),

  listLayouts: () =>
    invoke<LayoutInfo[]>("list_layouts"),

  saveLayout: (layout: LayoutInfo) =>
    invoke<void>("save_layout", { layout }),

  healthCheck: () =>
    invoke<{ version: string; uptime_secs: number; db_size_bytes: number }>(
      "health_check"
    ),
};
```

---

## 12. Layout System

### DashboardLayout Component

```tsx
// src/layout/DashboardLayout.tsx

import { PanelGroup, Panel, PanelResizeHandle } from "react-resizable-panels";
import { BlockContainer } from "../components/BlockContainer";
import { BlockRegistry } from "../blocks/registry";
import { useOrchestratorStore } from "../state/orchestrator-store";
import type { PanelNode } from "./presets";

interface DashboardLayoutProps {
  layout: PanelNode;
}

export function DashboardLayout({ layout }: DashboardLayoutProps) {
  const activeLayoutId = useOrchestratorStore((s) => s.activeLayoutId);

  return (
    <PanelGroup
      direction={layout.direction ?? "horizontal"}
      autoSaveId={`dashboard-layout-${activeLayoutId}`}
    >
      {layout.children?.map((child, index) => (
        <PanelNode key={child.id ?? index} node={child} index={index} />
      ))}
    </PanelGroup>
  );
}

function PanelNode({ node, index }: { node: PanelNode; index: number }) {
  // If the node has children, it is a group; otherwise it is a leaf block.
  if (node.children && node.children.length > 0) {
    return (
      <>
        {index > 0 && (
          <PanelResizeHandle className="w-1 bg-gray-200 hover:bg-blue-400 transition-colors" />
        )}
        <Panel defaultSize={node.size ?? 50} minSize={node.minSize ?? 10}>
          <PanelGroup direction={node.direction ?? "vertical"}>
            {node.children.map((child, childIndex) => (
              <PanelNode
                key={child.id ?? childIndex}
                node={child}
                index={childIndex}
              />
            ))}
          </PanelGroup>
        </Panel>
      </>
    );
  }

  // Leaf node: render a block
  const definition = BlockRegistry.resolve(node.blockType ?? "placeholder");

  return (
    <>
      {index > 0 && (
        <PanelResizeHandle className="w-1 bg-gray-200 hover:bg-blue-400 transition-colors" />
      )}
      <Panel
        defaultSize={node.size ?? 50}
        minSize={node.minSize ?? definition?.minSize ?? 10}
        collapsible={node.collapsible ?? true}
      >
        <BlockContainer
          blockType={node.blockType ?? "placeholder"}
          config={node.config ?? {}}
        />
      </Panel>
    </>
  );
}
```

### Layout Presets

```typescript
// src/layout/presets.ts

export interface PanelNode {
  id?: string;
  /** Block type for leaf nodes */
  blockType?: string;
  /** Arbitrary config passed to the block */
  config?: Record<string, unknown>;
  /** Panel size as percentage */
  size?: number;
  /** Minimum panel size as percentage */
  minSize?: number;
  /** Whether the panel can be collapsed */
  collapsible?: boolean;
  /** Direction for group nodes */
  direction?: "horizontal" | "vertical";
  /** Child panels (makes this a group) */
  children?: PanelNode[];
}

export const LAYOUT_PRESETS: Record<string, { name: string; layout: PanelNode }> = {
  overview: {
    name: "Overview",
    layout: {
      direction: "horizontal",
      children: [
        {
          id: "dag-main",
          blockType: "dag-visualization",
          size: 60,
          minSize: 30,
        },
        {
          direction: "vertical",
          size: 40,
          children: [
            {
              id: "log-main",
              blockType: "log-viewer",
              size: 50,
              minSize: 20,
            },
            {
              id: "placeholder-main",
              blockType: "placeholder",
              size: 50,
              minSize: 20,
            },
          ],
        },
      ],
    },
  },

  "agent-focus": {
    name: "Agent Focus",
    layout: {
      direction: "horizontal",
      children: [
        {
          id: "terminal-main",
          blockType: "agent-output",
          size: 50,
          minSize: 25,
        },
        {
          direction: "vertical",
          size: 50,
          children: [
            {
              id: "log-side",
              blockType: "log-viewer",
              size: 50,
            },
            {
              id: "dag-side",
              blockType: "dag-visualization",
              size: 50,
            },
          ],
        },
      ],
    },
  },

  review: {
    name: "Review",
    layout: {
      direction: "horizontal",
      children: [
        {
          id: "diff-main",
          blockType: "diff-viewer",
          size: 60,
          minSize: 30,
        },
        {
          direction: "vertical",
          size: 40,
          children: [
            {
              id: "contract-side",
              blockType: "contract-compliance",
              size: 50,
            },
            {
              id: "approval-side",
              blockType: "approval-queue",
              size: 50,
            },
          ],
        },
      ],
    },
  },

  monitoring: {
    name: "Monitoring",
    layout: {
      direction: "horizontal",
      children: [
        {
          id: "metrics-main",
          blockType: "metrics",
          size: 40,
        },
        {
          direction: "vertical",
          size: 60,
          children: [
            {
              id: "timeline-side",
              blockType: "timeline",
              size: 50,
            },
            {
              id: "log-side",
              blockType: "log-viewer",
              size: 50,
            },
          ],
        },
      ],
    },
  },
};
```

### Layout Persistence

`react-resizable-panels` supports `autoSaveId` which automatically persists panel sizes to `localStorage`. For cross-session persistence (surviving cache clears), layouts are also saved to SQLite via Tauri IPC on every resize settle.

```typescript
// src/layout/LayoutPersistence.ts

import { tauriCommands, type LayoutInfo } from "../lib/tauri-ipc";
import { LAYOUT_PRESETS, type PanelNode } from "./presets";

/**
 * Load a layout from SQLite, falling back to preset definitions.
 */
export async function loadLayout(layoutId: string): Promise<PanelNode> {
  try {
    const layouts = await tauriCommands.listLayouts();
    const saved = layouts.find((l) => l.id === layoutId);
    if (saved) {
      return JSON.parse(saved.panels) as PanelNode;
    }
  } catch {
    // Tauri not available (dev mode) or DB error — fall back to preset
  }

  const preset = LAYOUT_PRESETS[layoutId];
  if (preset) return preset.layout;

  // Ultimate fallback: overview preset
  return LAYOUT_PRESETS.overview.layout;
}

/**
 * Save a layout configuration to SQLite.
 * Called on debounced panel resize and on layout switch.
 */
export async function saveLayout(
  layoutId: string,
  name: string,
  layout: PanelNode
): Promise<void> {
  try {
    await tauriCommands.saveLayout({
      id: layoutId,
      name,
      panels: JSON.stringify(layout),
      is_default: layoutId === "overview",
    });
  } catch (err) {
    console.warn("Failed to save layout to SQLite:", err);
    // localStorage persistence via autoSaveId still works as fallback
  }
}
```

---

## 13. Basic Chrome Components

### Nav Rail

```tsx
// src/components/NavRail.tsx

import { BlockRegistry } from "../blocks/registry";
import { useOrchestratorStore } from "../state/orchestrator-store";
import { useShallow } from "zustand/react/shallow";
import { icons } from "lucide-react";
import { clsx } from "clsx";

export function NavRail() {
  const blockTypes = BlockRegistry.listTypes();
  const { activeLayoutId, switchLayout, pendingApprovals } =
    useOrchestratorStore(
      useShallow((s) => ({
        activeLayoutId: s.activeLayoutId,
        switchLayout: s.actions.switchLayout,
        pendingApprovals: s.pendingApprovals,
      }))
    );

  return (
    <nav className="flex flex-col w-14 bg-gray-900 text-gray-400 border-r border-gray-700">
      {/* Layout switcher */}
      <div className="flex flex-col items-center gap-1 py-3 border-b border-gray-700">
        {["overview", "agent-focus", "review", "monitoring"].map((layoutId) => (
          <button
            key={layoutId}
            onClick={() => switchLayout(layoutId)}
            className={clsx(
              "w-10 h-10 rounded-lg flex items-center justify-center text-xs transition-colors",
              activeLayoutId === layoutId
                ? "bg-blue-600 text-white"
                : "hover:bg-gray-800 hover:text-white"
            )}
            title={layoutId}
          >
            {layoutId.charAt(0).toUpperCase()}
          </button>
        ))}
      </div>

      {/* Block type list */}
      <div className="flex flex-col items-center gap-1 py-3 flex-1 overflow-y-auto">
        {blockTypes.map((bt) => {
          const LucideIcon = icons[bt.icon as keyof typeof icons];
          return (
            <button
              key={bt.type}
              className="w-10 h-10 rounded-lg flex items-center justify-center hover:bg-gray-800 hover:text-white transition-colors relative"
              title={bt.displayName}
            >
              {LucideIcon ? <LucideIcon size={18} /> : <span className="text-xs">{bt.icon}</span>}
              {bt.type === "approval-queue" && pendingApprovals.length > 0 && (
                <span className="absolute top-0 right-0 w-4 h-4 bg-red-500 text-white text-[10px] rounded-full flex items-center justify-center">
                  {pendingApprovals.length}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* Bottom: settings */}
      <div className="flex flex-col items-center gap-1 py-3 border-t border-gray-700">
        <button className="w-10 h-10 rounded-lg flex items-center justify-center hover:bg-gray-800 hover:text-white transition-colors">
          <icons.Settings size={18} />
        </button>
      </div>
    </nav>
  );
}
```

### Status Bar

```tsx
// src/components/StatusBar.tsx

import { useConnectionStatus, useBuildStatus } from "../state/orchestrator-store";
import { clsx } from "clsx";

export function StatusBar() {
  const { connectionStatus, lastSyncAt, reconnectAttempts } = useConnectionStatus();
  const { buildPhase, buildStatus } = useBuildStatus();

  const statusColor = {
    connected: "bg-green-500",
    reconnecting: "bg-yellow-500",
    disconnected: "bg-red-500",
  }[connectionStatus];

  const buildLabel = buildStatus === "idle"
    ? "No active build"
    : `Phase ${buildPhase}/14 - ${buildStatus}`;

  return (
    <footer className="flex items-center justify-between h-7 px-3 bg-gray-900 text-gray-400 text-xs border-t border-gray-700">
      <div className="flex items-center gap-2">
        <span className={clsx("w-2 h-2 rounded-full", statusColor)} />
        <span>
          {connectionStatus === "reconnecting"
            ? `Reconnecting (attempt ${reconnectAttempts})...`
            : connectionStatus}
        </span>
        {lastSyncAt && (
          <span className="text-gray-600">
            Last sync: {new Date(lastSyncAt).toLocaleTimeString()}
          </span>
        )}
      </div>

      <div className="flex items-center gap-4">
        <span>{buildLabel}</span>
        <span className="text-gray-600">v{__APP_VERSION__}</span>
      </div>
    </footer>
  );
}

declare const __APP_VERSION__: string;
```

---

## 14. Tauri Application Entry Point

```rust
// src-tauri/src/lib.rs

mod commands;
mod db;
mod events;
mod process;
mod plugins;
mod state;
mod types;

use std::sync::Mutex;
use crate::db::connection::initialize_database;
use crate::events::bus::EventBus;
use crate::state::AppState;

pub fn run() {
    let app_data_dir = dirs::data_dir()
        .expect("Failed to get app data directory")
        .join("agentic-ui-dashboard");
    std::fs::create_dir_all(&app_data_dir).expect("Failed to create data dir");

    let db_path = app_data_dir.join("dashboard.db");
    let db = initialize_database(&db_path).expect("Failed to initialize database");
    let event_bus = EventBus::new(1024);

    let app_state = AppState {
        db: Mutex::new(db),
        event_bus,
    };

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_window_state::Builder::new().build())
        .manage(app_state)
        .invoke_handler(tauri::generate_handler![
            commands::build::start_build,
            commands::build::pause_build,
            commands::build::get_build_status,
            commands::layout::list_layouts,
            commands::layout::save_layout,
            commands::system::health_check,
        ])
        .setup(|app| {
            let state = app.state::<AppState>();
            // Start the 5-second snapshot refresh on the tokio runtime
            let event_bus = &state.event_bus;
            event_bus.start_snapshot_refresh(|| {
                // TODO: collect full state from process manager + DB
                serde_json::json!({
                    "buildId": null,
                    "buildPhase": 0,
                    "buildStatus": "idle",
                    "agents": [],
                    "pendingApprovals": []
                })
            });
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("Error while running Tauri application");
}
```

```rust
// src-tauri/src/state.rs

use std::sync::Mutex;
use rusqlite::Connection;
use crate::events::bus::EventBus;

pub struct AppState {
    pub db: Mutex<Connection>,
    pub event_bus: EventBus,
}
```

---

## 15. Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|-------------|
| AC-1 | Tauri app launches with empty dashboard shell | Manual: `cargo tauri dev` opens window with nav rail, empty panels, and status bar |
| AC-2 | Block registry can register and resolve block types | Unit test: register placeholder, resolve by type string, verify Component is returned |
| AC-3 | Block registry rejects duplicate type registrations | Unit test: second `register()` with same type throws |
| AC-4 | Zustand store initializes with default state | Unit test: store has `buildStatus: "idle"`, `agents: []`, `connectionStatus: "disconnected"` |
| AC-5 | Zustand actions correctly mutate state | Unit test: `upsertAgent`, `resolveApproval`, `applySnapshot` produce expected state |
| AC-6 | SSE connection establishes and receives mock events | Integration test: mock SSE server emits events, `onEventBatch` callback fires within 50ms |
| AC-7 | SSE reconnects with exponential backoff on disconnect | Integration test: kill mock server, verify reconnection attempts with increasing delay |
| AC-8 | SSE `Last-Event-ID` is sent on reconnection | Integration test: verify query parameter includes last received event ID |
| AC-9 | Event batching accumulates events within 50ms window | Unit test: send 10 events in 20ms, verify single batch callback with all 10 |
| AC-10 | 5-second state snapshot refreshes Zustand store | Integration test: wait 5s, verify `lastSyncAt` updates and `agents` array matches snapshot |
| AC-11 | SQLite database creates all tables on first launch | Integration test: launch app, verify all 7 tables exist in `dashboard.db` |
| AC-12 | SQLite migrations are idempotent | Integration test: run migrations twice, verify no errors and table count unchanged |
| AC-13 | Layout persists across app restarts | Manual: resize panels, close app, reopen, verify sizes restored |
| AC-14 | Layout presets load correct panel configurations | Unit test: each preset key resolves to valid `PanelNode` tree with expected block types |
| AC-15 | Nav rail shows all registered block types | Manual: register 3+ block types, verify all appear in nav rail with icons |
| AC-16 | Status bar shows connection status and build phase | Manual: verify green dot when connected, yellow when reconnecting, red when disconnected |
| AC-17 | Tauri IPC commands execute and return data | Integration test: `start_build` returns `BuildInfo`, `list_layouts` returns preset layouts |

---

## 16. Testing Strategy

### Unit Tests (Vitest)

- **Block registry:** Registration, resolution, duplicate rejection, instance lifecycle (create/serialize/dispose)
- **Zustand store:** All actions produce correct state transitions. Snapshot application replaces agents array. Approval resolution moves items between pending and history.
- **SSE client:** Event batching (mock timers), reconnection scheduling (mock timers), `Last-Event-ID` tracking
- **Event router:** `processEventBatch` correctly routes `state_snapshot`, `run_started`, `run_finished`, `state_delta` events
- **Layout presets:** All presets parse to valid `PanelNode` trees

### Integration Tests

- **SSE end-to-end:** Spin up mock axum SSE server, connect client, verify events flow through to store
- **SQLite migrations:** Create fresh database, run all migrations, verify schema matches expectations
- **Tauri IPC:** Call each command via `invoke`, verify database mutations and return values

### Rust Tests (Cargo test)

- **EventBus:** Subscribe/emit/receive cycle, lagged receiver recovery
- **Database migrations:** Fresh database setup, migration idempotency
- **Command handlers:** Each Tauri command with mock state

---

## 17. Risk Considerations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Tauri v2 setup complexity on different OS | Medium | Document exact prerequisites per platform. Use `tauri init` scaffolding. CI tests on macOS, Linux, Windows. |
| `react-resizable-panels` layout persistence conflicts with SQLite persistence | Low | Use `autoSaveId` for fast local persistence, SQLite as durable backup. Load priority: localStorage first, SQLite fallback. |
| SSE connection blocked by corporate proxies | Medium | Detect proxy via failed connection, surface clear error in status bar. Document proxy configuration requirements. |
| Zustand + Jotai confusion (when to use which) | Low | Document boundary rule: Zustand = cross-block, Jotai = within-block. Enforce via code review and lint rules. |
| SQLite WAL mode file locking on network drives | Low | Document that `dashboard.db` must be on local filesystem, never on NFS/SMB. |
| Mock event source diverges from real event shapes | Medium | Define shared TypeScript types for events used by both mock and real sources. Validate events against schemas in tests. |

---

## 18. Definition of Done

Phase 1 is complete when all 17 acceptance criteria pass, unit and integration test suites are green, the Tauri app launches cleanly on macOS (primary) and Linux (secondary), and a developer unfamiliar with the project can run `cargo tauri dev` and see a functional (if empty) dashboard shell with working layout persistence and SSE status indicator.
