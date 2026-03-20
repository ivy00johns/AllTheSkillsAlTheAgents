# Phase 2: Core Visualization Blocks

**Version:** 0.1.0-draft
**Date:** 2026-03-20
**Status:** Design
**Duration:** 2-3 weeks
**Dependencies:** Phase 1 (Foundation Shell)
**Parent:** `00-master-architecture-spec.md`

---

## 1. Phase Objective

Implement the three most critical visual blocks in the dashboard: **Agent Output** (xterm.js terminal), **DAG Visualization** (React Flow task graph), and **Log Viewer** (structured log streaming). These three blocks represent the primary user-facing surfaces for monitoring an agentic build. By the end of this phase, all three blocks render live data from mock SSE events, operate within the Phase 1 layout system, and meet the performance budgets defined in the master spec.

---

## 2. Scope

### In Scope

- **Agent Output block** (`agent-output`): xterm.js terminal integration with WebGL/DOM renderer switching, ring buffer, serialize/restore, search
- **DAG Visualization block** (`dag-visualization`): React Flow with custom node types, dagre layout, Motion animations, progressive disclosure detail panel
- **Log Viewer block** (`log-viewer`): `@melloware/react-logviewer` with SSE streaming, ANSI colors, virtual scrolling, auto-follow, search/filter
- Block registration in the Phase 1 registry for all three types
- Jotai atom factory implementations (full, replacing Phase 1 stubs)
- Event subscription wiring: SSE events route to correct block atoms
- Mock event generators that produce realistic agent output, state transitions, and log entries

### Out of Scope

- Real agent subprocess connections (Phase 3)
- WebSocket terminal I/O for interactive sessions (Phase 3)
- Approval queue block (Phase 4)
- Diff viewer / Monaco editor (Phase 5)
- Metrics, kanban, timeline blocks (Phase 8)

---

## 3. New Dependencies

### package.json additions

```json
{
  "dependencies": {
    "@xterm/xterm": "^5.5.0",
    "@xterm/addon-webgl": "^0.18.0",
    "@xterm/addon-fit": "^0.10.0",
    "@xterm/addon-serialize": "^0.13.0",
    "@xterm/addon-search": "^0.15.0",
    "react-xtermjs": "^2.0.0",
    "@xyflow/react": "^12.4.0",
    "@dagrejs/dagre": "^1.1.0",
    "motion": "^12.0.0",
    "@melloware/react-logviewer": "^6.2.0"
  }
}
```

### New File Structure

```
src/
  blocks/
    agent-output/
      AgentOutputBlock.tsx        # Main terminal block component
      AgentOutputHeader.tsx       # Search bar, status badge, renderer indicator
      TerminalManager.ts          # WebGL context tracking, renderer switching
      atoms.ts                    # Full Jotai atom factory
      registration.ts             # Block registry registration
    dag-visualization/
      DagVisualizationBlock.tsx   # Main React Flow wrapper
      nodes/
        AgentTaskNode.tsx          # Custom node: agent task
        PhaseNode.tsx              # Custom node: build phase group
        GateNode.tsx               # Custom node: QA gate checkpoint
      edges/
        AnimatedEdge.tsx           # Custom edge with SVG particle animation
      DetailPanel.tsx              # Slide-out panel for selected node details
      DagLayout.ts                # dagre layout computation
      atoms.ts                    # Full Jotai atom factory
      registration.ts             # Block registry registration
    log-viewer/
      LogViewerBlock.tsx          # Main log viewer component
      LogViewerToolbar.tsx        # Filter bar, agent selector, search
      LogParser.ts                # JSON detection + pretty-print
      atoms.ts                    # Full Jotai atom factory
      registration.ts             # Block registry registration
    register-all.ts               # Import and register all block types
  streaming/
    block-event-router.ts         # Route events to block-specific atom updaters
    mock/
      mock-agent-output.ts        # Generate fake terminal output
      mock-dag-events.ts          # Generate fake agent state transitions
      mock-log-stream.ts          # Generate fake structured log entries
```

---

## 4. Agent Output Block (`agent-output`)

### Overview

The agent output block displays a live terminal view of an individual agent's stdout/stderr. It uses xterm.js for accurate terminal emulation, including ANSI escape codes, cursor positioning, and color output. The block manages the critical WebGL context budget: only visible terminals use the WebGL renderer (for GPU-accelerated 60fps rendering), while hidden terminals fall back to the DOM renderer (zero WebGL contexts consumed).

### WebGL Context Management Strategy

Browsers enforce a hard limit of 8-16 active WebGL contexts per page. With 20 agents, naive allocation exhausts this instantly. The strategy:

1. Track a global count of active WebGL contexts via a singleton `TerminalManager`.
2. When a terminal becomes visible and the WebGL budget allows (threshold: 4 active), attach `WebglAddon`. Otherwise, use the default DOM canvas renderer.
3. When a terminal becomes hidden, serialize its buffer state via `SerializeAddon`, then dispose the WebGL addon to release the context.
4. When a hidden terminal becomes visible again, restore from serialized state, then conditionally attach WebGL.

```typescript
// src/blocks/agent-output/TerminalManager.ts

import { WebglAddon } from "@xterm/addon-webgl";
import { SerializeAddon } from "@xterm/addon-serialize";
import type { Terminal } from "@xterm/xterm";

/** Maximum WebGL contexts to allocate for terminals */
const MAX_WEBGL_CONTEXTS = 4;

interface ManagedTerminal {
  instanceId: string;
  terminal: Terminal;
  serializeAddon: SerializeAddon;
  webglAddon: WebglAddon | null;
  serializedState: string | null;
  isVisible: boolean;
}

class TerminalManagerImpl {
  private terminals = new Map<string, ManagedTerminal>();
  private webglCount = 0;

  /**
   * Register a terminal instance for management.
   * Called when a terminal block mounts.
   */
  register(instanceId: string, terminal: Terminal): void {
    const serializeAddon = new SerializeAddon();
    terminal.loadAddon(serializeAddon);

    this.terminals.set(instanceId, {
      instanceId,
      terminal,
      serializeAddon,
      webglAddon: null,
      serializedState: null,
      isVisible: false,
    });
  }

  /**
   * Called when a terminal block becomes visible (panel expanded,
   * tab selected, etc.). Attempts to attach WebGL renderer.
   */
  setVisible(instanceId: string): void {
    const managed = this.terminals.get(instanceId);
    if (!managed || managed.isVisible) return;

    managed.isVisible = true;

    // Restore serialized state if available
    if (managed.serializedState) {
      managed.terminal.reset();
      managed.terminal.write(managed.serializedState);
      managed.serializedState = null;
    }

    // Attempt WebGL attachment
    if (this.webglCount < MAX_WEBGL_CONTEXTS) {
      this.attachWebgl(managed);
    }
    // Otherwise: DOM renderer stays active (functional, just slower)
  }

  /**
   * Called when a terminal block becomes hidden (panel collapsed,
   * tab switched, layout change). Serializes state and releases WebGL.
   */
  setHidden(instanceId: string): void {
    const managed = this.terminals.get(instanceId);
    if (!managed || !managed.isVisible) return;

    managed.isVisible = false;

    // Serialize current terminal state
    managed.serializedState = managed.serializeAddon.serialize();

    // Release WebGL context
    if (managed.webglAddon) {
      this.detachWebgl(managed);

      // Redistribute freed WebGL context to another visible terminal
      // that is currently using DOM renderer
      for (const [, other] of this.terminals) {
        if (other.isVisible && !other.webglAddon && this.webglCount < MAX_WEBGL_CONTEXTS) {
          this.attachWebgl(other);
          break;
        }
      }
    }
  }

  /**
   * Unregister a terminal (block disposed).
   */
  unregister(instanceId: string): void {
    const managed = this.terminals.get(instanceId);
    if (!managed) return;

    if (managed.webglAddon) {
      this.detachWebgl(managed);
    }
    managed.terminal.dispose();
    this.terminals.delete(instanceId);
  }

  /**
   * Get the current WebGL context allocation for diagnostics.
   */
  getStats(): { totalTerminals: number; webglActive: number; maxWebgl: number } {
    return {
      totalTerminals: this.terminals.size,
      webglActive: this.webglCount,
      maxWebgl: MAX_WEBGL_CONTEXTS,
    };
  }

  private attachWebgl(managed: ManagedTerminal): void {
    try {
      const webglAddon = new WebglAddon();
      webglAddon.onContextLoss(() => {
        // WebGL context was lost (GPU resource pressure).
        // Fall back to DOM renderer gracefully.
        this.detachWebgl(managed);
      });
      managed.terminal.loadAddon(webglAddon);
      managed.webglAddon = webglAddon;
      this.webglCount++;
    } catch (err) {
      // WebGL not available or context limit reached externally.
      // Terminal continues with DOM renderer.
      console.warn(`Failed to attach WebGL for ${managed.instanceId}:`, err);
    }
  }

  private detachWebgl(managed: ManagedTerminal): void {
    if (managed.webglAddon) {
      managed.webglAddon.dispose();
      managed.webglAddon = null;
      this.webglCount--;
    }
  }
}

/** Singleton terminal manager */
export const TerminalManager = new TerminalManagerImpl();
```

### Jotai Atoms

```typescript
// src/blocks/agent-output/atoms.ts

import { atom, type WritableAtom, type Atom } from "jotai";
import type { Terminal } from "@xterm/xterm";
import type { BlockConfig } from "../types";
import { createBaseAtoms, type BaseBlockAtoms } from "../../state/atoms";

export interface AgentOutputAtoms extends BaseBlockAtoms {
  /** Agent ID this terminal is bound to */
  agentIdAtom: Atom<string>;
  /** Agent execution status */
  statusAtom: WritableAtom<AgentTerminalStatus, [AgentTerminalStatus], void>;
  /** Reference to the xterm.js Terminal instance */
  terminalRefAtom: WritableAtom<Terminal | null, [Terminal | null], void>;
  /** Whether auto-scroll is following new output */
  isFollowingAtom: WritableAtom<boolean, [boolean], void>;
  /** Current search query for the search addon */
  searchQueryAtom: WritableAtom<string, [string], void>;
  /** Whether this terminal currently has a WebGL renderer */
  hasWebglAtom: WritableAtom<boolean, [boolean], void>;
  /** Total lines written to this terminal */
  lineCountAtom: WritableAtom<number, [number], void>;
  /** Ring buffer overflow indicator (lines dropped) */
  droppedLinesAtom: WritableAtom<number, [number], void>;
}

export type AgentTerminalStatus = "idle" | "connecting" | "streaming" | "paused" | "completed" | "error";

export function createAgentOutputAtoms(config: BlockConfig): AgentOutputAtoms {
  const agentId = (config.props.agentId as string) ?? "unknown";

  return {
    ...createBaseAtoms(),
    agentIdAtom: atom(agentId),
    statusAtom: atom<AgentTerminalStatus>("idle"),
    terminalRefAtom: atom<Terminal | null>(null),
    isFollowingAtom: atom(true),
    searchQueryAtom: atom(""),
    hasWebglAtom: atom(false),
    lineCountAtom: atom(0),
    droppedLinesAtom: atom(0),
  };
}
```

### Block Component

```tsx
// src/blocks/agent-output/AgentOutputBlock.tsx

import React, { useEffect, useRef, useCallback } from "react";
import { useAtom, useAtomValue, useSetAtom } from "jotai";
import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import { SearchAddon } from "@xterm/addon-search";
import "@xterm/xterm/css/xterm.css";
import { TerminalManager } from "./TerminalManager";
import { AgentOutputHeader } from "./AgentOutputHeader";
import type { AgentOutputAtoms } from "./atoms";
import type { BlockComponentProps } from "../types";

const RING_BUFFER_SIZE = 5000;

const TERMINAL_OPTIONS = {
  theme: {
    background: "#1a1b26",
    foreground: "#c0caf5",
    cursor: "#c0caf5",
    selectionBackground: "#33467c",
    black: "#15161e",
    red: "#f7768e",
    green: "#9ece6a",
    yellow: "#e0af68",
    blue: "#7aa2f7",
    magenta: "#bb9af7",
    cyan: "#7dcfff",
    white: "#a9b1d6",
  },
  fontSize: 13,
  fontFamily: '"JetBrains Mono", "Fira Code", "Cascadia Code", monospace',
  scrollback: RING_BUFFER_SIZE,
  cursorBlink: false,
  convertEol: true,
  allowProposedApi: true,
};

export const AgentOutputBlock = React.memo(function AgentOutputBlock({
  atoms,
  config,
  isActive,
}: BlockComponentProps<AgentOutputAtoms>) {
  const containerRef = useRef<HTMLDivElement>(null);
  const terminalRef = useRef<Terminal | null>(null);
  const fitAddonRef = useRef<FitAddon | null>(null);
  const searchAddonRef = useRef<SearchAddon | null>(null);

  const agentId = useAtomValue(atoms.agentIdAtom);
  const [isFollowing, setIsFollowing] = useAtom(atoms.isFollowingAtom);
  const setTerminalRef = useSetAtom(atoms.terminalRefAtom);
  const setLineCount = useSetAtom(atoms.lineCountAtom);
  const searchQuery = useAtomValue(atoms.searchQueryAtom);

  // Initialize terminal on mount
  useEffect(() => {
    if (!containerRef.current) return;

    const terminal = new Terminal(TERMINAL_OPTIONS);
    const fitAddon = new FitAddon();
    const searchAddon = new SearchAddon();

    terminal.loadAddon(fitAddon);
    terminal.loadAddon(searchAddon);
    terminal.open(containerRef.current);
    fitAddon.fit();

    terminalRef.current = terminal;
    fitAddonRef.current = fitAddon;
    searchAddonRef.current = searchAddon;
    setTerminalRef(terminal);

    // Register with terminal manager for WebGL lifecycle
    TerminalManager.register(config.instanceId, terminal);
    TerminalManager.setVisible(config.instanceId);

    // Track line count
    let lineCount = 0;
    terminal.onLineFeed(() => {
      lineCount++;
      setLineCount(lineCount);
    });

    // Auto-follow: scroll to bottom on new data
    terminal.onWriteParsed(() => {
      if (isFollowing) {
        terminal.scrollToBottom();
      }
    });

    // Resize observer for fit
    const resizeObserver = new ResizeObserver(() => {
      requestAnimationFrame(() => fitAddon.fit());
    });
    resizeObserver.observe(containerRef.current);

    return () => {
      resizeObserver.disconnect();
      TerminalManager.unregister(config.instanceId);
      terminal.dispose();
      terminalRef.current = null;
      setTerminalRef(null);
    };
  }, []); // Mount once

  // Handle visibility changes
  useEffect(() => {
    if (isActive) {
      TerminalManager.setVisible(config.instanceId);
      // Re-fit after becoming visible (size may have changed)
      requestAnimationFrame(() => fitAddonRef.current?.fit());
    } else {
      TerminalManager.setHidden(config.instanceId);
    }
  }, [isActive, config.instanceId]);

  // Handle search query changes
  useEffect(() => {
    if (!searchAddonRef.current) return;
    if (searchQuery) {
      searchAddonRef.current.findNext(searchQuery, {
        caseSensitive: false,
        regex: false,
      });
    } else {
      searchAddonRef.current.clearDecorations();
    }
  }, [searchQuery]);

  // Scroll event handler: disable auto-follow when user scrolls up
  const handleScroll = useCallback(() => {
    if (!terminalRef.current) return;
    const term = terminalRef.current;
    const isAtBottom =
      term.buffer.active.viewportY >= term.buffer.active.baseY;
    if (!isAtBottom && isFollowing) {
      setIsFollowing(false);
    }
  }, [isFollowing, setIsFollowing]);

  return (
    <div className="flex flex-col h-full bg-[#1a1b26]">
      <AgentOutputHeader
        atoms={atoms}
        agentId={agentId}
        onScrollToBottom={() => {
          terminalRef.current?.scrollToBottom();
          setIsFollowing(true);
        }}
      />
      <div
        ref={containerRef}
        className="flex-1 overflow-hidden"
        onScroll={handleScroll}
      />
    </div>
  );
});
```

### Block Registration

```typescript
// src/blocks/agent-output/registration.ts

import { BlockRegistry } from "../registry";
import { createAgentOutputAtoms } from "./atoms";
import { AgentOutputBlock } from "./AgentOutputBlock";
import { TerminalManager } from "./TerminalManager";

BlockRegistry.register({
  type: "agent-output",
  displayName: "Agent Output",
  icon: "Terminal",
  description: "Live terminal output from an agent process. Displays stdout/stderr with full ANSI color support, search, and auto-follow.",
  createAtoms: createAgentOutputAtoms,
  Component: AgentOutputBlock,
  serialize: (atoms) => {
    // Serialization handled by TerminalManager (SerializeAddon)
    return {};
  },
  dispose: (atoms) => {
    // TerminalManager.unregister is called in component cleanup
  },
  minSize: 15,
  allowMultiple: true,
});
```

### Writing Data to Terminals

Data arrives from the SSE event stream as `text_message_content` events. The block-level event router writes directly to the xterm.js Terminal instance referenced in the Jotai atom.

```typescript
// Excerpt from src/streaming/block-event-router.ts

import { getDefaultStore } from "jotai";
import type { TextMessageEvent } from "./event-types";
import type { AgentOutputAtoms } from "../blocks/agent-output/atoms";

const jotaiStore = getDefaultStore();

/**
 * Route a text_message_content event to the correct terminal.
 * Writes directly to the xterm.js Terminal instance.
 */
function routeTextMessage(
  event: TextMessageEvent,
  atomsMap: Map<string, AgentOutputAtoms>
): void {
  const atoms = atomsMap.get(event.agentId);
  if (!atoms) return;

  const terminal = jotaiStore.get(atoms.terminalRefAtom);
  if (!terminal) return;

  // Write output to terminal (preserves ANSI escape codes)
  terminal.write(event.content);
}
```

---

## 5. DAG Visualization Block (`dag-visualization`)

### Overview

The DAG block renders the build task graph as an interactive directed acyclic graph using React Flow. Each node represents either a build phase, an agent task, or a QA gate. Edges show dependencies and data flow. Node appearance animates in response to status changes (queued, running, completed, failed, waiting) using Motion for GPU-accelerated transitions.

### Custom Node Types

Three custom node types are registered with React Flow:

| Node Type | Purpose | Visual |
|-----------|---------|--------|
| `agentTask` | Individual agent execution | Rounded rectangle with role icon, status badge, progress bar |
| `phase` | Build phase container | Larger rectangle with phase number, acts as visual group |
| `gate` | QA quality gate | Diamond shape with pass/fail indicator |

### AgentTaskNode Implementation

```tsx
// src/blocks/dag-visualization/nodes/AgentTaskNode.tsx

import React from "react";
import { Handle, Position, type NodeProps } from "@xyflow/react";
import { motion, AnimatePresence } from "motion/react";
import { useOrchestratorStore } from "../../../state/orchestrator-store";
import type { AgentStatus } from "../../../state/orchestrator-store";

export interface AgentTaskData {
  agentId: string;
  role: string;
  label: string;
}

const STATUS_COLORS: Record<AgentStatus, string> = {
  queued: "#6b7280",     // gray-500
  spawning: "#8b5cf6",   // violet-500
  running: "#3b82f6",    // blue-500
  waiting: "#eab308",    // yellow-500
  completed: "#22c55e",  // green-500
  failed: "#ef4444",     // red-500
};

const STATUS_BG: Record<AgentStatus, string> = {
  queued: "rgba(107, 114, 128, 0.1)",
  spawning: "rgba(139, 92, 246, 0.1)",
  running: "rgba(59, 130, 246, 0.15)",
  waiting: "rgba(234, 179, 8, 0.15)",
  completed: "rgba(34, 197, 94, 0.1)",
  failed: "rgba(239, 68, 68, 0.15)",
};

/**
 * Custom React Flow node for agent tasks.
 * MUST be wrapped in React.memo to prevent re-renders from
 * unrelated node position changes.
 */
export const AgentTaskNode = React.memo(function AgentTaskNode({
  data,
  selected,
}: NodeProps & { data: AgentTaskData }) {
  // Use a granular selector to only re-render when THIS agent's status changes
  const agent = useOrchestratorStore(
    (s) => s.agents.find((a) => a.id === data.agentId),
    (a, b) => a?.status === b?.status && a?.progress === b?.progress
  );

  const status: AgentStatus = agent?.status ?? "queued";
  const progress = agent?.progress ?? 0;
  const borderColor = STATUS_COLORS[status];
  const bgColor = STATUS_BG[status];

  return (
    <>
      <Handle type="target" position={Position.Top} className="!w-2 !h-2" />

      <motion.div
        initial={false}
        animate={{
          scale: status === "running" ? 1.03 : 1,
          borderColor,
          backgroundColor: bgColor,
          boxShadow:
            status === "running"
              ? `0 0 12px ${borderColor}40`
              : selected
                ? `0 0 0 2px ${borderColor}`
                : "0 1px 3px rgba(0,0,0,0.2)",
        }}
        transition={{ duration: 0.3, ease: "easeInOut" }}
        className="rounded-lg border-2 px-4 py-3 min-w-[160px] cursor-pointer"
      >
        {/* Header: role label */}
        <div className="flex items-center justify-between mb-1">
          <span className="text-sm font-semibold text-gray-200 truncate">
            {data.label}
          </span>
          <StatusBadge status={status} />
        </div>

        {/* Current step (if running) */}
        <AnimatePresence mode="wait">
          {agent?.currentStep && status === "running" && (
            <motion.div
              key={agent.currentStep}
              initial={{ opacity: 0, y: -4 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 4 }}
              className="text-xs text-gray-400 truncate mb-2"
            >
              {agent.currentStep}
            </motion.div>
          )}
        </AnimatePresence>

        {/* Progress bar (running and spawning only) */}
        {(status === "running" || status === "spawning") && (
          <div className="w-full h-1 bg-gray-700 rounded-full overflow-hidden">
            <motion.div
              className="h-full rounded-full"
              style={{ backgroundColor: borderColor }}
              animate={{ width: `${progress}%` }}
              transition={{ duration: 0.5, ease: "easeOut" }}
            />
          </div>
        )}
      </motion.div>

      <Handle type="source" position={Position.Bottom} className="!w-2 !h-2" />
    </>
  );
});

/**
 * Animated status badge pill.
 */
const StatusBadge = React.memo(function StatusBadge({
  status,
}: {
  status: AgentStatus;
}) {
  return (
    <motion.span
      animate={{
        backgroundColor: STATUS_COLORS[status],
        opacity: status === "running" ? [1, 0.6, 1] : 1,
      }}
      transition={
        status === "running"
          ? { opacity: { repeat: Infinity, duration: 1.5 } }
          : { duration: 0.3 }
      }
      className="inline-block w-2 h-2 rounded-full flex-shrink-0"
    />
  );
});
```

### PhaseNode and GateNode

```tsx
// src/blocks/dag-visualization/nodes/PhaseNode.tsx

import React from "react";
import { Handle, Position, type NodeProps } from "@xyflow/react";
import { motion } from "motion/react";

export interface PhaseData {
  phaseNumber: number;
  phaseName: string;
  status: "pending" | "active" | "completed";
}

export const PhaseNode = React.memo(function PhaseNode({
  data,
}: NodeProps & { data: PhaseData }) {
  const borderColor =
    data.status === "completed"
      ? "#22c55e"
      : data.status === "active"
        ? "#3b82f6"
        : "#4b5563";

  return (
    <>
      <Handle type="target" position={Position.Top} className="!w-3 !h-3" />
      <motion.div
        animate={{ borderColor }}
        transition={{ duration: 0.3 }}
        className="rounded-xl border-2 border-dashed px-6 py-4 bg-gray-800/50 min-w-[200px]"
      >
        <div className="text-xs text-gray-500 uppercase tracking-wider">
          Phase {data.phaseNumber}
        </div>
        <div className="text-sm font-medium text-gray-300 mt-1">
          {data.phaseName}
        </div>
      </motion.div>
      <Handle type="source" position={Position.Bottom} className="!w-3 !h-3" />
    </>
  );
});
```

```tsx
// src/blocks/dag-visualization/nodes/GateNode.tsx

import React from "react";
import { Handle, Position, type NodeProps } from "@xyflow/react";
import { motion } from "motion/react";
import { ShieldCheck, ShieldAlert, ShieldQuestion } from "lucide-react";

export interface GateData {
  gateId: string;
  gateName: string;
  status: "pending" | "passed" | "failed" | "reviewing";
}

const GATE_CONFIG = {
  pending: { color: "#6b7280", Icon: ShieldQuestion },
  passed: { color: "#22c55e", Icon: ShieldCheck },
  failed: { color: "#ef4444", Icon: ShieldAlert },
  reviewing: { color: "#eab308", Icon: ShieldQuestion },
};

export const GateNode = React.memo(function GateNode({
  data,
}: NodeProps & { data: GateData }) {
  const { color, Icon } = GATE_CONFIG[data.status];

  return (
    <>
      <Handle type="target" position={Position.Top} className="!w-2 !h-2" />
      <motion.div
        animate={{
          borderColor: color,
          rotate: 45,
          boxShadow:
            data.status === "reviewing"
              ? `0 0 16px ${color}60`
              : "0 1px 3px rgba(0,0,0,0.3)",
        }}
        transition={{ duration: 0.3 }}
        className="w-16 h-16 border-2 bg-gray-900 flex items-center justify-center"
      >
        <motion.div animate={{ rotate: -45 }}>
          <Icon size={20} color={color} />
        </motion.div>
      </motion.div>
      <div className="absolute -bottom-6 left-1/2 -translate-x-1/2 text-xs text-gray-400 whitespace-nowrap">
        {data.gateName}
      </div>
      <Handle type="source" position={Position.Bottom} className="!w-2 !h-2" />
    </>
  );
});
```

### Animated Edges (SVG Particles)

Edges connecting nodes use custom SVG particle animation to show data flow direction. This uses explicit SVG `<circle>` elements animated along the edge path, NOT CSS `stroke-dasharray` (which renders poorly at scale).

```tsx
// src/blocks/dag-visualization/edges/AnimatedEdge.tsx

import React, { useId } from "react";
import { BaseEdge, getBezierPath, type EdgeProps } from "@xyflow/react";
import { motion } from "motion/react";

export const AnimatedEdge = React.memo(function AnimatedEdge({
  sourceX,
  sourceY,
  targetX,
  targetY,
  sourcePosition,
  targetPosition,
  data,
  ...rest
}: EdgeProps & { data?: { isActive?: boolean } }) {
  const uniqueId = useId();
  const [edgePath] = getBezierPath({
    sourceX,
    sourceY,
    targetX,
    targetY,
    sourcePosition,
    targetPosition,
  });

  const isActive = data?.isActive ?? false;

  return (
    <>
      <BaseEdge
        path={edgePath}
        style={{
          stroke: isActive ? "#3b82f6" : "#4b5563",
          strokeWidth: isActive ? 2 : 1,
          opacity: isActive ? 1 : 0.5,
        }}
        {...rest}
      />
      {isActive && (
        <g>
          <defs>
            <path id={`edge-path-${uniqueId}`} d={edgePath} />
          </defs>
          {/* Three particles at staggered offsets */}
          {[0, 0.33, 0.66].map((offset) => (
            <motion.circle
              key={offset}
              r={3}
              fill="#3b82f6"
              filter="url(#glow)"
              initial={{ offsetDistance: `${offset * 100}%` }}
              animate={{ offsetDistance: ["0%", "100%"] }}
              transition={{
                duration: 2,
                repeat: Infinity,
                ease: "linear",
                delay: offset * 2,
              }}
              style={{ offsetPath: `path('${edgePath}')` }}
            />
          ))}
        </g>
      )}
    </>
  );
});
```

### dagre Layout Computation

```typescript
// src/blocks/dag-visualization/DagLayout.ts

import dagre from "@dagrejs/dagre";
import type { Node, Edge } from "@xyflow/react";

export interface DagLayoutOptions {
  /** Layout direction: top-to-bottom or left-to-right */
  rankdir: "TB" | "LR";
  /** Horizontal separation between nodes (px) */
  nodesep: number;
  /** Vertical separation between ranks (px) */
  ranksep: number;
  /** Separation between edges (px) */
  edgesep: number;
}

const DEFAULT_OPTIONS: DagLayoutOptions = {
  rankdir: "TB",
  nodesep: 60,
  ranksep: 80,
  edgesep: 20,
};

/**
 * Compute node positions using dagre hierarchical layout.
 *
 * Returns new node array with updated position fields.
 * Does NOT mutate input nodes.
 *
 * Performance: <10ms for 50 nodes, <100ms for 500 nodes.
 */
export function computeDagLayout(
  nodes: Node[],
  edges: Edge[],
  options: Partial<DagLayoutOptions> = {}
): Node[] {
  const opts = { ...DEFAULT_OPTIONS, ...options };

  const graph = new dagre.graphlib.Graph();
  graph.setDefaultEdgeLabel(() => ({}));
  graph.setGraph({
    rankdir: opts.rankdir,
    nodesep: opts.nodesep,
    ranksep: opts.ranksep,
    edgesep: opts.edgesep,
    marginx: 20,
    marginy: 20,
  });

  // Estimate node dimensions based on type
  for (const node of nodes) {
    const width = node.type === "phase" ? 220 : node.type === "gate" ? 80 : 180;
    const height = node.type === "phase" ? 80 : node.type === "gate" ? 80 : 70;
    graph.setNode(node.id, { width, height });
  }

  for (const edge of edges) {
    graph.setEdge(edge.source, edge.target);
  }

  dagre.layout(graph);

  return nodes.map((node) => {
    const nodeWithPosition = graph.node(node.id);
    if (!nodeWithPosition) return node;

    // dagre provides center coordinates; React Flow uses top-left
    const width = nodeWithPosition.width ?? 180;
    const height = nodeWithPosition.height ?? 70;

    return {
      ...node,
      position: {
        x: nodeWithPosition.x - width / 2,
        y: nodeWithPosition.y - height / 2,
      },
    };
  });
}
```

### Jotai Atoms

```typescript
// src/blocks/dag-visualization/atoms.ts

import { atom, type WritableAtom } from "jotai";
import type { Node, Edge } from "@xyflow/react";
import type { BlockConfig } from "../types";
import { createBaseAtoms, type BaseBlockAtoms } from "../../state/atoms";

export interface DagVisualizationAtoms extends BaseBlockAtoms {
  /** React Flow node array */
  nodesAtom: WritableAtom<Node[], [Node[]], void>;
  /** React Flow edge array */
  edgesAtom: WritableAtom<Edge[], [Edge[]], void>;
  /** Currently selected node ID (for detail panel) */
  selectedNodeAtom: WritableAtom<string | null, [string | null], void>;
  /** Layout direction (top-to-bottom or left-to-right) */
  layoutDirectionAtom: WritableAtom<"TB" | "LR", ["TB" | "LR"], void>;
  /** Set of node IDs currently animating a state transition */
  animatingNodesAtom: WritableAtom<Set<string>, [Set<string>], void>;
  /** Whether the detail panel is open */
  detailPanelOpenAtom: WritableAtom<boolean, [boolean], void>;
  /** Zoom level */
  zoomAtom: WritableAtom<number, [number], void>;
}

export function createDagVisualizationAtoms(_config: BlockConfig): DagVisualizationAtoms {
  return {
    ...createBaseAtoms(),
    nodesAtom: atom<Node[]>([]),
    edgesAtom: atom<Edge[]>([]),
    selectedNodeAtom: atom<string | null>(null),
    layoutDirectionAtom: atom<"TB" | "LR">("TB"),
    animatingNodesAtom: atom<Set<string>>(new Set()),
    detailPanelOpenAtom: atom(false),
    zoomAtom: atom(1),
  };
}
```

### DAG Block Component

```tsx
// src/blocks/dag-visualization/DagVisualizationBlock.tsx

import React, { useCallback, useMemo, useEffect } from "react";
import {
  ReactFlow,
  Background,
  Controls,
  MiniMap,
  useNodesState,
  useEdgesState,
  type OnNodesChange,
  type OnEdgesChange,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import { useAtom, useAtomValue, useSetAtom } from "jotai";
import { AnimatePresence } from "motion/react";
import { AgentTaskNode } from "./nodes/AgentTaskNode";
import { PhaseNode } from "./nodes/PhaseNode";
import { GateNode } from "./nodes/GateNode";
import { AnimatedEdge } from "./edges/AnimatedEdge";
import { DetailPanel } from "./DetailPanel";
import { computeDagLayout } from "./DagLayout";
import type { DagVisualizationAtoms } from "./atoms";
import type { BlockComponentProps } from "../types";

/**
 * CRITICAL: nodeTypes and edgeTypes must be defined outside
 * the component to prevent React Flow from re-registering
 * them on every render.
 */
const nodeTypes = {
  agentTask: AgentTaskNode,
  phase: PhaseNode,
  gate: GateNode,
};

const edgeTypes = {
  animated: AnimatedEdge,
};

export const DagVisualizationBlock = React.memo(function DagVisualizationBlock({
  atoms,
  config,
  isActive,
}: BlockComponentProps<DagVisualizationAtoms>) {
  const [nodes, setNodes, onNodesChange] = useNodesState([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState([]);
  const [selectedNode, setSelectedNode] = useAtom(atoms.selectedNodeAtom);
  const [detailPanelOpen, setDetailPanelOpen] = useAtom(atoms.detailPanelOpenAtom);
  const layoutDirection = useAtomValue(atoms.layoutDirectionAtom);

  // Sync nodes/edges from Jotai atoms (updated by event router)
  const atomNodes = useAtomValue(atoms.nodesAtom);
  const atomEdges = useAtomValue(atoms.edgesAtom);

  useEffect(() => {
    if (atomNodes.length === 0) return;
    const layoutedNodes = computeDagLayout(atomNodes, atomEdges, {
      rankdir: layoutDirection,
    });
    setNodes(layoutedNodes);
    setEdges(atomEdges);
  }, [atomNodes, atomEdges, layoutDirection, setNodes, setEdges]);

  // Handle node click for progressive disclosure
  const onNodeClick = useCallback(
    (_event: React.MouseEvent, node: { id: string }) => {
      setSelectedNode(node.id);
      setDetailPanelOpen(true);
    },
    [setSelectedNode, setDetailPanelOpen]
  );

  const onPaneClick = useCallback(() => {
    setSelectedNode(null);
    setDetailPanelOpen(false);
  }, [setSelectedNode, setDetailPanelOpen]);

  // MiniMap node color based on type
  const miniMapNodeColor = useCallback((node: { type?: string }) => {
    switch (node.type) {
      case "phase":
        return "#6b7280";
      case "gate":
        return "#eab308";
      default:
        return "#3b82f6";
    }
  }, []);

  return (
    <div className="relative h-full w-full bg-gray-950">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onNodeClick={onNodeClick}
        onPaneClick={onPaneClick}
        nodeTypes={nodeTypes}
        edgeTypes={edgeTypes}
        defaultEdgeOptions={{ type: "animated" }}
        fitView
        fitViewOptions={{ padding: 0.2 }}
        minZoom={0.3}
        maxZoom={2}
        proOptions={{ hideAttribution: true }}
        className="bg-gray-950"
      >
        <Background color="#333" gap={20} />
        <Controls
          showInteractive={false}
          className="!bg-gray-800 !border-gray-700 !shadow-lg [&>button]:!bg-gray-800 [&>button]:!border-gray-700 [&>button]:!text-gray-400 [&>button:hover]:!bg-gray-700"
        />
        <MiniMap
          nodeColor={miniMapNodeColor}
          maskColor="rgba(0, 0, 0, 0.7)"
          className="!bg-gray-900 !border-gray-700"
        />
      </ReactFlow>

      {/* Progressive disclosure: detail panel slides in from right */}
      <AnimatePresence>
        {detailPanelOpen && selectedNode && (
          <DetailPanel
            nodeId={selectedNode}
            onClose={() => {
              setSelectedNode(null);
              setDetailPanelOpen(false);
            }}
          />
        )}
      </AnimatePresence>
    </div>
  );
});
```

### Detail Panel (Progressive Disclosure)

```tsx
// src/blocks/dag-visualization/DetailPanel.tsx

import React from "react";
import { motion } from "motion/react";
import { X } from "lucide-react";
import { useAgent } from "../../state/orchestrator-store";

interface DetailPanelProps {
  nodeId: string;
  onClose: () => void;
}

/**
 * Slide-in panel that shows Layer 2 detail for a selected DAG node.
 * Layer 1: Visible on the node itself (status, progress)
 * Layer 2: This panel (current step, reasoning, tools used, timing)
 * Layer 3: Full trace (future: links to Langfuse, Phase 6)
 */
export const DetailPanel = React.memo(function DetailPanel({
  nodeId,
  onClose,
}: DetailPanelProps) {
  const agent = useAgent(nodeId);

  return (
    <motion.div
      initial={{ x: "100%", opacity: 0 }}
      animate={{ x: 0, opacity: 1 }}
      exit={{ x: "100%", opacity: 0 }}
      transition={{ type: "spring", damping: 25, stiffness: 200 }}
      className="absolute top-0 right-0 h-full w-80 bg-gray-900 border-l border-gray-700 shadow-xl z-10 overflow-y-auto"
    >
      <div className="flex items-center justify-between p-4 border-b border-gray-700">
        <h3 className="text-sm font-semibold text-gray-200">
          {agent?.role ?? nodeId}
        </h3>
        <button
          onClick={onClose}
          className="p-1 rounded hover:bg-gray-800 text-gray-400 hover:text-gray-200 transition-colors"
        >
          <X size={16} />
        </button>
      </div>

      {agent ? (
        <div className="p-4 space-y-4">
          {/* Status section */}
          <Section title="Status">
            <KeyValue label="Status" value={agent.status} />
            <KeyValue label="Progress" value={`${agent.progress}%`} />
            <KeyValue label="Current Step" value={agent.currentStep || "N/A"} />
          </Section>

          {/* Timing section */}
          <Section title="Timing">
            <KeyValue
              label="Started"
              value={agent.startedAt ? new Date(agent.startedAt).toLocaleTimeString() : "Not started"}
            />
            <KeyValue
              label="Completed"
              value={agent.completedAt ? new Date(agent.completedAt).toLocaleTimeString() : "In progress"}
            />
          </Section>

          {/* Resource usage */}
          <Section title="Resources">
            <KeyValue label="Token Usage" value={agent.tokenUsage.toLocaleString()} />
            <KeyValue label="Cost" value={`$${(agent.cost / 100).toFixed(2)}`} />
          </Section>

          {/* Error section (if failed) */}
          {agent.error && (
            <Section title="Error">
              <pre className="text-xs text-red-400 bg-red-950/30 p-2 rounded overflow-x-auto whitespace-pre-wrap">
                {agent.error}
              </pre>
            </Section>
          )}
        </div>
      ) : (
        <div className="p-4 text-sm text-gray-500">
          No agent data available for this node.
        </div>
      )}
    </motion.div>
  );
});

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div>
      <h4 className="text-xs font-medium text-gray-500 uppercase tracking-wider mb-2">
        {title}
      </h4>
      <div className="space-y-1">{children}</div>
    </div>
  );
}

function KeyValue({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between text-sm">
      <span className="text-gray-400">{label}</span>
      <span className="text-gray-200">{value}</span>
    </div>
  );
}
```

### DAG Block Registration

```typescript
// src/blocks/dag-visualization/registration.ts

import { BlockRegistry } from "../registry";
import { createDagVisualizationAtoms } from "./atoms";
import { DagVisualizationBlock } from "./DagVisualizationBlock";

BlockRegistry.register({
  type: "dag-visualization",
  displayName: "Task Graph",
  icon: "GitBranch",
  description: "Interactive DAG showing build phases, agent tasks, and QA gates with animated state transitions and progressive-disclosure detail panel.",
  createAtoms: createDagVisualizationAtoms,
  Component: DagVisualizationBlock,
  minSize: 25,
  allowMultiple: false,
});
```

---

## 6. Log Viewer Block (`log-viewer`)

### Overview

The log viewer block displays structured log output from agents using `@melloware/react-logviewer`. It handles 100MB+ log volumes via Virtua-based virtual scrolling, renders ANSI color codes, supports auto-follow during streaming, and provides search/filter capabilities including per-agent filtering and JSON pretty-printing.

### Jotai Atoms

```typescript
// src/blocks/log-viewer/atoms.ts

import { atom, type WritableAtom } from "jotai";
import type { BlockConfig } from "../types";
import { createBaseAtoms, type BaseBlockAtoms } from "../../state/atoms";

export type LogLevel = "debug" | "info" | "warn" | "error" | "trace";

export interface LogLine {
  /** Unique line ID */
  id: string;
  /** Timestamp (ISO 8601) */
  timestamp: string;
  /** Source agent ID */
  agentId: string;
  /** Log level */
  level: LogLevel;
  /** Raw log content (may contain ANSI codes) */
  content: string;
  /** Whether this line was detected as JSON */
  isJson: boolean;
}

export interface LogFilters {
  /** Filter by agent IDs (empty = all agents) */
  agentIds: string[];
  /** Minimum log level to display */
  minLevel: LogLevel;
  /** Text search query */
  searchQuery: string;
}

export interface LogViewerAtoms extends BaseBlockAtoms {
  /** All log lines (append-only during streaming) */
  logLinesAtom: WritableAtom<LogLine[], [LogLine[]], void>;
  /** Active filter configuration */
  filtersAtom: WritableAtom<LogFilters, [LogFilters], void>;
  /** Whether auto-follow is active */
  followModeAtom: WritableAtom<boolean, [boolean], void>;
  /** Search query for in-log text search */
  searchQueryAtom: WritableAtom<string, [string], void>;
  /** Currently selected agent for filtering (null = all) */
  selectedAgentIdAtom: WritableAtom<string | null, [string | null], void>;
  /** Whether JSON log lines are expanded */
  jsonExpandedAtom: WritableAtom<boolean, [boolean], void>;
  /** Total line count (for display without reading entire array) */
  totalLinesAtom: WritableAtom<number, [number], void>;
}

export function createLogViewerAtoms(_config: BlockConfig): LogViewerAtoms {
  return {
    ...createBaseAtoms(),
    logLinesAtom: atom<LogLine[]>([]),
    filtersAtom: atom<LogFilters>({
      agentIds: [],
      minLevel: "info",
      searchQuery: "",
    }),
    followModeAtom: atom(true),
    searchQueryAtom: atom(""),
    selectedAgentIdAtom: atom<string | null>(null),
    jsonExpandedAtom: atom(false),
    totalLinesAtom: atom(0),
  };
}
```

### Log Parser

```typescript
// src/blocks/log-viewer/LogParser.ts

import type { LogLine, LogLevel } from "./atoms";

/**
 * Parse a raw log string into a structured LogLine.
 * Detects JSON payloads and extracts log level.
 */
export function parseLogLine(
  raw: string,
  agentId: string,
  timestamp?: string
): LogLine {
  const now = timestamp ?? new Date().toISOString();
  const trimmed = raw.trim();

  // Attempt JSON detection
  let isJson = false;
  if (
    (trimmed.startsWith("{") && trimmed.endsWith("}")) ||
    (trimmed.startsWith("[") && trimmed.endsWith("]"))
  ) {
    try {
      JSON.parse(trimmed);
      isJson = true;
    } catch {
      // Not valid JSON, treat as plain text
    }
  }

  // Extract log level from common patterns
  const level = detectLogLevel(trimmed);

  return {
    id: `${agentId}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    timestamp: now,
    agentId,
    level,
    content: raw,
    isJson,
  };
}

/**
 * Pretty-print a JSON log line with indentation.
 */
export function prettyPrintJson(content: string): string {
  try {
    const parsed = JSON.parse(content.trim());
    return JSON.stringify(parsed, null, 2);
  } catch {
    return content;
  }
}

const LEVEL_PATTERNS: [RegExp, LogLevel][] = [
  [/\b(ERROR|ERR|FATAL|CRIT)\b/i, "error"],
  [/\b(WARN|WARNING)\b/i, "warn"],
  [/\b(INFO|INF)\b/i, "info"],
  [/\b(DEBUG|DBG)\b/i, "debug"],
  [/\b(TRACE|TRC)\b/i, "trace"],
];

function detectLogLevel(text: string): LogLevel {
  for (const [pattern, level] of LEVEL_PATTERNS) {
    if (pattern.test(text)) return level;
  }
  return "info";
}

const LEVEL_PRIORITY: Record<LogLevel, number> = {
  trace: 0,
  debug: 1,
  info: 2,
  warn: 3,
  error: 4,
};

/**
 * Filter log lines based on active filters.
 */
export function filterLogLines(
  lines: LogLine[],
  filters: {
    agentIds: string[];
    minLevel: LogLevel;
    searchQuery: string;
  }
): LogLine[] {
  const minPriority = LEVEL_PRIORITY[filters.minLevel];

  return lines.filter((line) => {
    // Agent filter
    if (filters.agentIds.length > 0 && !filters.agentIds.includes(line.agentId)) {
      return false;
    }
    // Level filter
    if (LEVEL_PRIORITY[line.level] < minPriority) {
      return false;
    }
    // Search filter
    if (
      filters.searchQuery &&
      !line.content.toLowerCase().includes(filters.searchQuery.toLowerCase())
    ) {
      return false;
    }
    return true;
  });
}
```

### Log Viewer Component

```tsx
// src/blocks/log-viewer/LogViewerBlock.tsx

import React, { useMemo, useCallback } from "react";
import { LazyLog, ScrollFollow } from "@melloware/react-logviewer";
import { useAtom, useAtomValue, useSetAtom } from "jotai";
import { LogViewerToolbar } from "./LogViewerToolbar";
import { filterLogLines, prettyPrintJson } from "./LogParser";
import type { LogViewerAtoms } from "./atoms";
import type { BlockComponentProps } from "../types";

export const LogViewerBlock = React.memo(function LogViewerBlock({
  atoms,
  config,
  isActive,
}: BlockComponentProps<LogViewerAtoms>) {
  const logLines = useAtomValue(atoms.logLinesAtom);
  const filters = useAtomValue(atoms.filtersAtom);
  const [followMode, setFollowMode] = useAtom(atoms.followModeAtom);
  const jsonExpanded = useAtomValue(atoms.jsonExpandedAtom);
  const totalLines = useAtomValue(atoms.totalLinesAtom);

  // Apply filters to log lines
  const filteredLines = useMemo(
    () => filterLogLines(logLines, filters),
    [logLines, filters]
  );

  // Convert log lines to a single text blob for LazyLog
  // (LazyLog expects a text string or URL, not an array)
  const logText = useMemo(() => {
    return filteredLines
      .map((line) => {
        const prefix = `[${line.timestamp.slice(11, 23)}] [${line.agentId}] [${line.level.toUpperCase().padEnd(5)}]`;
        const content =
          line.isJson && jsonExpanded
            ? prettyPrintJson(line.content)
            : line.content;
        return `${prefix} ${content}`;
      })
      .join("\n");
  }, [filteredLines, jsonExpanded]);

  const handleScrollToEnd = useCallback(
    (isAtEnd: boolean) => {
      if (isAtEnd && !followMode) {
        setFollowMode(true);
      } else if (!isAtEnd && followMode) {
        setFollowMode(false);
      }
    },
    [followMode, setFollowMode]
  );

  return (
    <div className="flex flex-col h-full bg-gray-950">
      <LogViewerToolbar
        atoms={atoms}
        totalLines={totalLines}
        filteredLines={filteredLines.length}
      />

      <div className="flex-1 overflow-hidden">
        <ScrollFollow
          startFollowing={followMode}
          render={({ follow, onScroll }) => (
            <LazyLog
              text={logText}
              follow={follow}
              onScroll={onScroll}
              extraLines={1}
              enableSearch
              caseInsensitive
              enableHotKeys
              enableLineNumbers
              selectableLines
              style={{
                backgroundColor: "#0a0a0f",
                color: "#c0caf5",
                fontFamily: '"JetBrains Mono", "Fira Code", monospace',
                fontSize: "12px",
              }}
              lineClassName="hover:bg-gray-900/50"
              highlightLineClassName="bg-blue-950/30"
            />
          )}
        />
      </div>
    </div>
  );
});
```

### Log Viewer Toolbar

```tsx
// src/blocks/log-viewer/LogViewerToolbar.tsx

import React from "react";
import { useAtom, useSetAtom } from "jotai";
import { Search, Filter, ArrowDown, Braces } from "lucide-react";
import { useAgents } from "../../state/orchestrator-store";
import { clsx } from "clsx";
import type { LogViewerAtoms, LogLevel } from "./atoms";

const LOG_LEVELS: LogLevel[] = ["trace", "debug", "info", "warn", "error"];

interface LogViewerToolbarProps {
  atoms: LogViewerAtoms;
  totalLines: number;
  filteredLines: number;
}

export const LogViewerToolbar = React.memo(function LogViewerToolbar({
  atoms,
  totalLines,
  filteredLines,
}: LogViewerToolbarProps) {
  const [filters, setFilters] = useAtom(atoms.filtersAtom);
  const [followMode, setFollowMode] = useAtom(atoms.followModeAtom);
  const [jsonExpanded, setJsonExpanded] = useAtom(atoms.jsonExpandedAtom);
  const [selectedAgentId, setSelectedAgentId] = useAtom(atoms.selectedAgentIdAtom);
  const agents = useAgents();

  return (
    <div className="flex items-center gap-2 px-3 py-2 border-b border-gray-800 bg-gray-900/50">
      {/* Agent filter dropdown */}
      <select
        value={selectedAgentId ?? "all"}
        onChange={(e) => {
          const value = e.target.value === "all" ? null : e.target.value;
          setSelectedAgentId(value);
          setFilters({
            ...filters,
            agentIds: value ? [value] : [],
          });
        }}
        className="h-7 px-2 text-xs bg-gray-800 border border-gray-700 rounded text-gray-300 focus:outline-none focus:border-blue-500"
      >
        <option value="all">All agents</option>
        {agents.map((a) => (
          <option key={a.id} value={a.id}>
            {a.role}
          </option>
        ))}
      </select>

      {/* Level filter */}
      <div className="flex items-center gap-1">
        <Filter size={12} className="text-gray-500" />
        {LOG_LEVELS.map((level) => (
          <button
            key={level}
            onClick={() => setFilters({ ...filters, minLevel: level })}
            className={clsx(
              "px-1.5 py-0.5 text-[10px] rounded uppercase",
              filters.minLevel === level
                ? "bg-blue-600 text-white"
                : "text-gray-500 hover:text-gray-300 hover:bg-gray-800"
            )}
          >
            {level}
          </button>
        ))}
      </div>

      {/* Search */}
      <div className="flex items-center gap-1 flex-1 max-w-[200px]">
        <Search size={12} className="text-gray-500" />
        <input
          type="text"
          placeholder="Search logs..."
          value={filters.searchQuery}
          onChange={(e) => setFilters({ ...filters, searchQuery: e.target.value })}
          className="h-6 w-full px-2 text-xs bg-gray-800 border border-gray-700 rounded text-gray-300 placeholder-gray-600 focus:outline-none focus:border-blue-500"
        />
      </div>

      {/* JSON expand toggle */}
      <button
        onClick={() => setJsonExpanded(!jsonExpanded)}
        className={clsx(
          "p-1 rounded transition-colors",
          jsonExpanded
            ? "bg-blue-600 text-white"
            : "text-gray-500 hover:text-gray-300 hover:bg-gray-800"
        )}
        title="Expand JSON log lines"
      >
        <Braces size={14} />
      </button>

      {/* Auto-follow toggle */}
      <button
        onClick={() => setFollowMode(!followMode)}
        className={clsx(
          "p-1 rounded transition-colors",
          followMode
            ? "bg-blue-600 text-white"
            : "text-gray-500 hover:text-gray-300 hover:bg-gray-800"
        )}
        title={followMode ? "Auto-follow: ON" : "Auto-follow: OFF"}
      >
        <ArrowDown size={14} />
      </button>

      {/* Line count */}
      <span className="text-[10px] text-gray-600 ml-auto whitespace-nowrap">
        {filteredLines === totalLines
          ? `${totalLines} lines`
          : `${filteredLines}/${totalLines} lines`}
      </span>
    </div>
  );
});
```

### Log Viewer Registration

```typescript
// src/blocks/log-viewer/registration.ts

import { BlockRegistry } from "../registry";
import { createLogViewerAtoms } from "./atoms";
import { LogViewerBlock } from "./LogViewerBlock";

BlockRegistry.register({
  type: "log-viewer",
  displayName: "Structured Logs",
  icon: "FileText",
  description: "Streaming log viewer with ANSI color support, virtual scrolling for 100MB+ logs, auto-follow, per-agent filtering, JSON detection and pretty-printing, and text search.",
  createAtoms: createLogViewerAtoms,
  Component: LogViewerBlock,
  minSize: 15,
  allowMultiple: true,
});
```

---

## 7. Event Subscription Patterns

Each block type subscribes to specific SSE event types. The block-level event router (extending the Phase 1 event router) dispatches events to the appropriate Jotai atom updaters based on event type and `agentId`.

```typescript
// src/streaming/block-event-router.ts

import { getDefaultStore } from "jotai";
import type { OrchestratorEvent, TextMessageEvent } from "./event-types";
import type { AgentOutputAtoms } from "../blocks/agent-output/atoms";
import type { DagVisualizationAtoms } from "../blocks/dag-visualization/atoms";
import type { LogViewerAtoms, LogLine } from "../blocks/log-viewer/atoms";
import { parseLogLine } from "../blocks/log-viewer/LogParser";

const jotaiStore = getDefaultStore();

/**
 * Registry of active block atom sets, keyed by instanceId.
 * Blocks register their atoms when mounted and unregister when disposed.
 */
interface BlockAtomRegistry {
  agentOutput: Map<string, AgentOutputAtoms>;    // keyed by agentId
  dagVisualization: DagVisualizationAtoms | null;
  logViewer: Map<string, LogViewerAtoms>;         // keyed by instanceId
}

const registry: BlockAtomRegistry = {
  agentOutput: new Map(),
  dagVisualization: null,
  logViewer: new Map(),
};

export function registerBlockAtoms(
  blockType: string,
  instanceId: string,
  atoms: unknown,
  agentId?: string
): void {
  switch (blockType) {
    case "agent-output":
      if (agentId) {
        registry.agentOutput.set(agentId, atoms as AgentOutputAtoms);
      }
      break;
    case "dag-visualization":
      registry.dagVisualization = atoms as DagVisualizationAtoms;
      break;
    case "log-viewer":
      registry.logViewer.set(instanceId, atoms as LogViewerAtoms);
      break;
  }
}

export function unregisterBlockAtoms(blockType: string, instanceId: string, agentId?: string): void {
  switch (blockType) {
    case "agent-output":
      if (agentId) registry.agentOutput.delete(agentId);
      break;
    case "dag-visualization":
      registry.dagVisualization = null;
      break;
    case "log-viewer":
      registry.logViewer.delete(instanceId);
      break;
  }
}

/**
 * Route an SSE event to block-specific atom updaters.
 * Called after the global Zustand store has been updated.
 */
export function routeEventToBlocks(event: OrchestratorEvent): void {
  switch (event.eventType) {
    case "text_message_content": {
      const e = event as TextMessageEvent;

      // Route to agent-output terminal
      const outputAtoms = registry.agentOutput.get(e.agentId);
      if (outputAtoms) {
        const terminal = jotaiStore.get(outputAtoms.terminalRefAtom);
        if (terminal) {
          terminal.write(e.content);
        }
      }

      // Route to all log viewers as a new log line
      const logLine = parseLogLine(e.content, e.agentId);
      for (const [, logAtoms] of registry.logViewer) {
        const current = jotaiStore.get(logAtoms.logLinesAtom);
        jotaiStore.set(logAtoms.logLinesAtom, [...current, logLine]);
        jotaiStore.set(logAtoms.totalLinesAtom, current.length + 1);
      }
      break;
    }

    case "run_started":
    case "run_finished":
    case "state_delta": {
      // DAG block rebuilds from Zustand agent state
      // No direct atom update needed; DagVisualizationBlock reads from
      // useOrchestratorStore and rebuilds nodes/edges in an effect.
      //
      // The AgentTaskNode selector triggers re-render when agent status
      // changes in the Zustand store.
      break;
    }

    default:
      break;
  }
}
```

### DAG Node/Edge Synchronization

The DAG block derives its React Flow nodes and edges from the Zustand agent list. A synchronization function converts the agent fleet into the graph structure.

```typescript
// src/blocks/dag-visualization/dag-sync.ts

import type { Node, Edge } from "@xyflow/react";
import type { AgentState } from "../../state/orchestrator-store";

/**
 * Build phases and their agent roles.
 * Simplified for initial implementation; full 14-phase mapping
 * will be defined when real orchestrator integration happens in Phase 3.
 */
const PHASE_AGENTS: Record<number, string[]> = {
  1: [],                       // Contract generation (orchestrator only)
  2: ["backend", "frontend", "infrastructure", "db-migration"],  // Parallel implementation
  3: ["qe"],                   // QA validation
  4: ["security"],             // Security audit
  5: ["docs"],                 // Documentation
  6: ["observability"],        // Instrumentation
  7: ["performance"],          // Performance testing
};

/**
 * Convert the Zustand agent fleet into React Flow nodes and edges.
 * Called whenever the agent list changes.
 */
export function buildDagGraph(
  agents: AgentState[],
  buildPhase: number
): { nodes: Node[]; edges: Edge[] } {
  const nodes: Node[] = [];
  const edges: Edge[] = [];

  // Create phase nodes
  for (const [phaseStr, roles] of Object.entries(PHASE_AGENTS)) {
    const phase = parseInt(phaseStr);
    const phaseAgents = agents.filter((a) => roles.includes(a.role));
    const phaseStatus =
      phase < buildPhase
        ? "completed"
        : phase === buildPhase
          ? "active"
          : "pending";

    const phaseNodeId = `phase-${phase}`;
    nodes.push({
      id: phaseNodeId,
      type: "phase",
      position: { x: 0, y: 0 }, // dagre will compute
      data: {
        phaseNumber: phase,
        phaseName: `Phase ${phase}`,
        status: phaseStatus,
      },
    });

    // Create agent task nodes within this phase
    for (const agent of phaseAgents) {
      nodes.push({
        id: agent.id,
        type: "agentTask",
        position: { x: 0, y: 0 },
        data: {
          agentId: agent.id,
          role: agent.role,
          label: agent.role.replace("-", " "),
        },
      });

      // Edge from phase to agent
      edges.push({
        id: `${phaseNodeId}-${agent.id}`,
        source: phaseNodeId,
        target: agent.id,
        type: "animated",
        data: { isActive: agent.status === "running" },
      });
    }

    // Edge from previous phase to this phase
    if (phase > 1) {
      const prevPhaseId = `phase-${phase - 1}`;
      edges.push({
        id: `${prevPhaseId}-${phaseNodeId}`,
        source: prevPhaseId,
        target: phaseNodeId,
        type: "animated",
        data: { isActive: phase === buildPhase },
      });
    }

    // Add QA gate after phases that have agents
    if (phaseAgents.length > 0) {
      const gateId = `gate-${phase}`;
      nodes.push({
        id: gateId,
        type: "gate",
        position: { x: 0, y: 0 },
        data: {
          gateId,
          gateName: `QA Gate ${phase}`,
          status:
            phase < buildPhase
              ? "passed"
              : phase === buildPhase
                ? "reviewing"
                : "pending",
        },
      });

      // Edges: agents -> gate
      for (const agent of phaseAgents) {
        edges.push({
          id: `${agent.id}-${gateId}`,
          source: agent.id,
          target: gateId,
          type: "animated",
          data: { isActive: agent.status === "running" },
        });
      }

      // Edge: gate -> next phase
      const nextPhaseId = `phase-${phase + 1}`;
      if (PHASE_AGENTS[phase + 1] !== undefined) {
        edges.push({
          id: `${gateId}-${nextPhaseId}`,
          source: gateId,
          target: nextPhaseId,
          type: "animated",
          data: { isActive: false },
        });
      }
    }
  }

  return { nodes, edges };
}
```

---

## 8. Performance Optimizations

### Memoization Strategy

| Component | Technique | Reason |
|-----------|-----------|--------|
| `AgentTaskNode` | `React.memo` + Zustand selector with custom equality | Prevents ALL nodes re-rendering when one agent changes |
| `PhaseNode` | `React.memo` | Immutable data props |
| `GateNode` | `React.memo` | Immutable data props |
| `AnimatedEdge` | `React.memo` | Only re-render when `isActive` changes |
| `AgentOutputBlock` | `React.memo` | Terminal manages its own state |
| `LogViewerBlock` | `React.memo` + `useMemo` for filtered lines | Avoid recomputing filters on unrelated state changes |
| `DetailPanel` | `React.memo` | Only re-render for selected agent changes |

### Render Budget

| Operation | Target | Measurement |
|-----------|--------|-------------|
| Agent status change (1 of 20) | <8ms total (1 node re-render) | React DevTools Profiler |
| dagre re-layout (20 nodes) | <5ms | `performance.now()` around `computeDagLayout` |
| dagre re-layout (50 nodes) | <10ms | Same |
| Terminal write (100 chars) | <1ms | xterm.js internal |
| Log line append (1 line to 10K) | <1ms | Virtual scroll (no DOM change) |
| SSE batch flush (10 events) | <5ms total processing | `performance.now()` around `processEventBatch` |

### WebGL Context Budget

| Scenario | WebGL Contexts | DOM Renderers |
|----------|----------------|---------------|
| 1 visible terminal | 1 | 0 |
| 4 visible terminals | 4 | 0 |
| 5 visible terminals | 4 | 1 |
| 4 visible + 16 hidden | 4 | 0 (hidden = serialized, no renderer) |
| 0 visible (DAG focus layout) | 0 | 0 |

---

## 9. Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|-------------|
| AC-1 | Agent output block displays live terminal output from mock agent events | Integration test: emit 100 `text_message_content` events, verify terminal buffer contains all content |
| AC-2 | Terminal renders ANSI color codes correctly | Visual test: emit ANSI-colored output (red errors, green success), verify color rendering |
| AC-3 | Terminal switches between WebGL and DOM renderer based on visibility | Unit test: set 5 terminals visible, verify only 4 have WebGL. Hide one, verify freed context redistributed. |
| AC-4 | Terminal serialize/restore preserves buffer content across hide/show | Integration test: write 100 lines, hide terminal, restore, verify content matches |
| AC-5 | Terminal search addon highlights matching text | Manual: type search query, verify highlights appear in terminal buffer |
| AC-6 | Auto-follow scrolls to bottom on new data | Manual: stream output, verify scroll stays at bottom. Scroll up manually, verify auto-follow disables. |
| AC-7 | DAG block shows task graph with correct node types | Integration test: create agents for 3 phases, verify `agentTask`, `phase`, and `gate` nodes all render |
| AC-8 | DAG node status transitions animate smoothly | Visual test: change agent status from `queued` to `running`, verify scale/color/glow animation plays |
| AC-9 | Clicking a DAG node opens the detail panel | Integration test: simulate node click, verify `DetailPanel` renders with correct agent data |
| AC-10 | Adding/removing agents triggers smooth dagre re-layout | Integration test: add 3 agents, verify layout. Remove 1, verify re-layout without position jumps. |
| AC-11 | Edge particles animate along active edges | Visual test: set edge as active, verify SVG circle elements animate along bezier path |
| AC-12 | Log viewer streams logs from SSE with ANSI colors | Integration test: emit `text_message_content` events, verify log lines appear with color rendering |
| AC-13 | Log viewer auto-follow keeps scroll at bottom during streaming | Manual: stream 1000 lines, verify scroll stays at bottom. Scroll up, verify auto-follow indicator changes. |
| AC-14 | Log viewer per-agent filtering works | Integration test: emit logs from 3 agents, select 1 agent in filter, verify only that agent's logs shown |
| AC-15 | Log viewer JSON detection and pretty-print works | Integration test: emit JSON log line, enable JSON expand, verify formatted output |
| AC-16 | Log viewer level filtering works | Integration test: emit logs at all levels, set filter to "warn", verify only warn and error shown |
| AC-17 | All three blocks work together in the Phase 1 layout system | Manual: load "Overview" preset, verify DAG + log viewer render. Switch to "Agent Focus", verify terminal + log viewer + DAG. |
| AC-18 | Resizing panels triggers terminal re-fit | Manual: resize panel containing terminal, verify terminal columns/rows adjust |

---

## 10. Testing Strategy

### Unit Tests (Vitest)

- **TerminalManager:** Context counting, visibility toggling, redistribution on hide/show, `MAX_WEBGL_CONTEXTS` enforcement
- **DagLayout:** `computeDagLayout` produces valid positions for 5, 20, and 50 node graphs. Verify no overlapping positions.
- **LogParser:** `parseLogLine` correctly detects JSON, extracts log levels from various formats. `filterLogLines` correctly applies agent, level, and search filters.
- **dag-sync:** `buildDagGraph` produces correct node/edge structure from agent fleet state. Phase/gate/agent relationships are correct.
- **Atom factories:** Each factory creates atoms with correct initial values and types.

### Integration Tests (Vitest + Testing Library)

- **AgentOutputBlock:** Mount component, write to terminal via atom, verify content rendered. Test hide/show lifecycle with mock TerminalManager.
- **DagVisualizationBlock:** Mount component, set nodes/edges in atoms, verify React Flow renders correct number of nodes. Simulate click, verify detail panel opens.
- **LogViewerBlock:** Mount component, append log lines to atom, verify they appear in rendered output. Test filter changes.
- **Event routing:** Emit mock events through `routeEventToBlocks`, verify correct atoms are updated.

### Visual Regression Tests

- Terminal color theme rendering
- DAG node status animations (screenshot at each state)
- Detail panel slide-in animation
- Edge particle animation (recorded as video clip for manual review)

### Performance Tests

- dagre layout with 50 nodes: measure time, assert <10ms
- dagre layout with 200 nodes: measure time, assert <50ms
- Append 10,000 log lines: verify virtual scroll handles it without frame drops
- Write 5,000 lines to terminal: verify ring buffer evicts correctly

---

## 11. Risk Considerations

| Risk | Severity | Mitigation |
|------|----------|------------|
| xterm.js WebGL context loss during GPU pressure | High | `onContextLoss` handler falls back to DOM renderer. TerminalManager tracks and redistributes. |
| React Flow performance with many custom nodes | Medium | All node types use `React.memo`. Zustand selectors use custom equality. `nodeTypes` defined outside component. |
| Motion animations conflicting with React Flow internal positioning | Medium | Animate only visual properties (scale, borderColor, boxShadow, opacity), never `position` or `transform`. Layout is exclusively dagre's job. |
| @melloware/react-logviewer memory growth with 100K+ lines | Medium | Virtual scrolling handles rendering. Consider implementing a maximum line buffer with eviction if memory becomes an issue. |
| CSS-in-JS conflicts between xterm.js, React Flow, and Tailwind | Low | xterm.js uses its own scoped CSS. React Flow styles imported separately. Tailwind utility classes do not conflict. |
| dagre layout instability (nodes jump on re-layout) | Medium | Compare new positions with old positions and apply Motion `layout` animations for smooth transitions instead of instant jumps. |
| EventSource `onmessage` vs named event listeners precedence | Low | Use named event listeners for typed events (`state_snapshot`, `run_started`, etc.). `onmessage` catches untyped events only. |

---

## 12. Mock Event Generators

For development and testing without a real orchestrator, mock generators produce realistic event streams.

```typescript
// src/streaming/mock/mock-agent-output.ts

import type { AgentRole } from "../../state/orchestrator-store";

const SAMPLE_OUTPUT: Record<string, string[]> = {
  backend: [
    "\x1b[36m[backend]\x1b[0m Analyzing contract: api-contract.yaml\n",
    "\x1b[36m[backend]\x1b[0m Found 12 endpoints to implement\n",
    "\x1b[33m[backend]\x1b[0m Generating route handlers...\n",
    "\x1b[32m[backend]\x1b[0m Created src/routes/users.ts (4 endpoints)\n",
    "\x1b[32m[backend]\x1b[0m Created src/routes/posts.ts (5 endpoints)\n",
    "\x1b[32m[backend]\x1b[0m Created src/routes/auth.ts (3 endpoints)\n",
    "\x1b[36m[backend]\x1b[0m Running type validation...\n",
    "\x1b[32m[backend]\x1b[0m All types match contract. 0 violations.\n",
  ],
  frontend: [
    "\x1b[35m[frontend]\x1b[0m Scaffolding React components from contract...\n",
    "\x1b[35m[frontend]\x1b[0m Generating API client hooks (react-query)\n",
    "\x1b[32m[frontend]\x1b[0m Created src/hooks/useUsers.ts\n",
    "\x1b[32m[frontend]\x1b[0m Created src/hooks/usePosts.ts\n",
    "\x1b[35m[frontend]\x1b[0m Building component tree...\n",
  ],
  qe: [
    '{"level":"info","agent":"qe","msg":"Starting QA validation","timestamp":"2026-03-20T10:00:00Z"}\n',
    '{"level":"info","agent":"qe","msg":"Running contract conformance checks","checks":12}\n',
    '{"level":"warn","agent":"qe","msg":"Endpoint /api/posts/:id missing error response schema","severity":"medium"}\n',
    '{"level":"info","agent":"qe","msg":"Security scan complete","score":4,"max":5}\n',
    '{"level":"info","agent":"qe","msg":"QA report generated","path":"qa-report.json"}\n',
  ],
};

/**
 * Generate a stream of mock text events for a given agent role.
 * Returns an async generator that yields events at realistic intervals.
 */
export async function* mockAgentOutputStream(
  agentId: string,
  role: AgentRole
): AsyncGenerator<{ agentId: string; content: string }> {
  const lines = SAMPLE_OUTPUT[role] ?? SAMPLE_OUTPUT.backend;

  for (const line of lines) {
    // Random delay between 100ms and 500ms to simulate real output
    await new Promise((r) => setTimeout(r, 100 + Math.random() * 400));
    yield { agentId, content: line };
  }
}
```

---

## 13. Definition of Done

Phase 2 is complete when all 18 acceptance criteria pass, all three blocks register in the Phase 1 block registry, the mock event generators drive realistic output through the SSE pipeline to the blocks, performance benchmarks meet the targets defined in Section 8, and the three blocks operate correctly within the `react-resizable-panels` layout system with the four preset layouts. A developer can launch the app, see the DAG with animated mock agents, read streaming terminal output, and browse filtered structured logs simultaneously.
