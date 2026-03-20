# AG-UI Integration Guide

Reference for integrating the AG-UI (Agent-User Interaction) protocol into the agentic UI dashboard. Covers the full event type taxonomy, multi-agent multiplexing, interrupt lifecycle, transport configuration, frontend hooks, and testing patterns.

---

## 1. Protocol Overview

AG-UI defines 17 event types for standardized agent-to-frontend communication. The protocol is transport-agnostic but recommends SSE for server-to-client streaming. It was adopted by Google, LangChain, AWS, Microsoft, Mastra, and PydanticAI.

Our dashboard extends AG-UI for multi-agent orchestration by wrapping every event with agent routing metadata.

### Core Concepts

- **Run:** A single agent execution lifecycle (start to finish)
- **Event:** A typed message from agent to frontend
- **Interrupt:** A pause point where the agent requests human input before continuing
- **State:** Agent-side state that can be synced to the frontend via snapshots and deltas

### Base Event Type

```typescript
interface BaseAGUIEvent {
  type: AGUIEventType;
  runId: string;
  timestamp: number; // Unix ms
}

// Our extension for multi-agent routing
interface OrchestratorEvent extends BaseAGUIEvent {
  agentId: string;         // "backend-agent", "frontend-agent", etc.
  agentRole: AgentRole;    // Enum of 9 roles
  phaseId: number;         // Current build phase (1-14)
  sequenceNum: number;     // Monotonically increasing per agent
}
```

---

## 2. Event Type Reference

### Lifecycle Events

#### RUN_STARTED
Emitted when an agent begins execution.

```typescript
interface RunStartedEvent extends OrchestratorEvent {
  type: 'RUN_STARTED';
  runId: string;
  threadId?: string;   // Optional conversation thread
  metadata?: Record<string, unknown>;
}
```

**Frontend handling:** Create block atoms for the agent, add node to DAG, transition kanban card to "running" column.

#### RUN_FINISHED
Emitted when an agent completes, errors, or requests an interrupt.

```typescript
interface RunFinishedEvent extends OrchestratorEvent {
  type: 'RUN_FINISHED';
  outcome: 'success' | 'error' | 'interrupt';
  // Present when outcome === 'error'
  error?: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
  // Present when outcome === 'interrupt'
  interrupt?: {
    reason: string;          // 'quality_gate', 'approval_required', 'user_input'
    payload: unknown;        // QA report JSON, approval details, etc.
    resumeOptions?: string[]; // Suggested actions: ['approve', 'reject', 'retry']
  };
  // Present when outcome === 'success'
  result?: unknown;
}
```

**Frontend handling:**
- `outcome: "success"` -- animate DAG node to completed state, move kanban card
- `outcome: "error"` -- show error toast, highlight DAG node in red, log error details
- `outcome: "interrupt"` -- add to approval queue, show persistent notification, pause DAG animation

#### RUN_ERROR
Emitted for non-terminal errors during execution (agent can continue).

```typescript
interface RunErrorEvent extends OrchestratorEvent {
  type: 'RUN_ERROR';
  error: {
    code: string;
    message: string;
    recoverable: boolean;
  };
}
```

**Frontend handling:** Log to agent's log viewer, show warning toast if not recoverable.

### Text Events

#### TEXT_MESSAGE_START
Signals the beginning of a new text message from the agent.

```typescript
interface TextMessageStartEvent extends OrchestratorEvent {
  type: 'TEXT_MESSAGE_START';
  messageId: string;
  role: 'assistant';
}
```

#### TEXT_MESSAGE_CONTENT
Streaming text content chunk.

```typescript
interface TextMessageContentEvent extends OrchestratorEvent {
  type: 'TEXT_MESSAGE_CONTENT';
  messageId: string;
  content: string;   // UTF-8 text chunk
}
```

**Frontend handling:** Append to the agent's chat block or log viewer. Buffer chunks for 50ms before DOM update.

#### TEXT_MESSAGE_END
Signals the end of a text message.

```typescript
interface TextMessageEndEvent extends OrchestratorEvent {
  type: 'TEXT_MESSAGE_END';
  messageId: string;
}
```

### Tool Call Events

#### TOOL_CALL_START

```typescript
interface ToolCallStartEvent extends OrchestratorEvent {
  type: 'TOOL_CALL_START';
  toolCallId: string;
  toolName: string;       // 'file_write', 'bash', 'code_search', etc.
  parentMessageId: string;
}
```

**Frontend handling:** Add tool call indicator to the agent's output. For file_write, highlight the file in the file tree.

#### TOOL_CALL_ARGS
Streaming tool call arguments (may arrive in chunks for large arguments).

```typescript
interface ToolCallArgsEvent extends OrchestratorEvent {
  type: 'TOOL_CALL_ARGS';
  toolCallId: string;
  args: string;   // JSON string chunk
}
```

#### TOOL_CALL_RESULT

```typescript
interface ToolCallResultEvent extends OrchestratorEvent {
  type: 'TOOL_CALL_RESULT';
  toolCallId: string;
  result: string;   // Stringified result
  isError: boolean;
}
```

**Frontend handling:** For file operations, update the diff viewer. For bash commands, show output in the terminal block.

#### TOOL_CALL_END

```typescript
interface ToolCallEndEvent extends OrchestratorEvent {
  type: 'TOOL_CALL_END';
  toolCallId: string;
}
```

### State Events

#### STATE_SNAPSHOT
Full orchestrator state, emitted on connection and every 5 seconds.

```typescript
interface StateSnapshotEvent extends OrchestratorEvent {
  type: 'STATE_SNAPSHOT';
  state: OrchestratorStateSnapshot;
}

interface OrchestratorStateSnapshot {
  buildId: string;
  buildPhase: number;
  buildStatus: BuildStatus;
  agents: AgentState[];
  pendingApprovals: Approval[];
  metrics: BuildMetrics;
  timestamp: number;
}
```

**Frontend handling:** Replace the entire Zustand store state. This is the self-healing mechanism -- any missed delta is recovered here.

#### STATE_DELTA
Incremental state update.

```typescript
interface StateDeltaEvent extends OrchestratorEvent {
  type: 'STATE_DELTA';
  delta: Partial<OrchestratorStateSnapshot>;
}
```

**Frontend handling:** Merge delta into existing store state. Use immer or spread operators for immutable update.

### Reasoning Events

#### REASONING_MESSAGE_CONTENT
Agent's internal reasoning (chain-of-thought), if exposed.

```typescript
interface ReasoningMessageContentEvent extends OrchestratorEvent {
  type: 'REASONING_MESSAGE_CONTENT';
  messageId: string;
  content: string;
}
```

**Frontend handling:** Display in a collapsible "Thinking" section within the agent's output block. This is Layer 2 progressive disclosure content.

### Custom Events

#### RAW
Catch-all for custom event types not in the AG-UI spec.

```typescript
interface RawEvent extends OrchestratorEvent {
  type: 'RAW';
  customType: string;    // 'qa-report', 'contract-compliance', 'metrics-update', etc.
  payload: unknown;
}
```

**Frontend handling:** Route based on `customType` to the appropriate block handler.

### Event Type Enum

```typescript
enum AGUIEventType {
  // Lifecycle
  RUN_STARTED = 'RUN_STARTED',
  RUN_FINISHED = 'RUN_FINISHED',
  RUN_ERROR = 'RUN_ERROR',

  // Text
  TEXT_MESSAGE_START = 'TEXT_MESSAGE_START',
  TEXT_MESSAGE_CONTENT = 'TEXT_MESSAGE_CONTENT',
  TEXT_MESSAGE_END = 'TEXT_MESSAGE_END',

  // Tool calls
  TOOL_CALL_START = 'TOOL_CALL_START',
  TOOL_CALL_ARGS = 'TOOL_CALL_ARGS',
  TOOL_CALL_RESULT = 'TOOL_CALL_RESULT',
  TOOL_CALL_END = 'TOOL_CALL_END',

  // State
  STATE_SNAPSHOT = 'STATE_SNAPSHOT',
  STATE_DELTA = 'STATE_DELTA',

  // Reasoning
  REASONING_MESSAGE_CONTENT = 'REASONING_MESSAGE_CONTENT',

  // Custom
  RAW = 'RAW',

  // Step lifecycle (grouping related events)
  STEP_STARTED = 'STEP_STARTED',
  STEP_FINISHED = 'STEP_FINISHED',

  // Messages lifecycle
  MESSAGES_SNAPSHOT = 'MESSAGES_SNAPSHOT',
}
```

---

## 3. Multi-Agent Multiplexing

AG-UI is single-agent-centric. Our dashboard monitors 9+ agents simultaneously. The solution: a single SSE stream from the orchestrator that multiplexes events from all agents.

### Architecture

```
Agent 1 (backend)   ─┐
Agent 2 (frontend)  ─┤
Agent 3 (qe)        ─┼──▶ Rust Event Bus ──▶ AG-UI Adapter ──▶ Single SSE Stream
Agent 4 (security)  ─┤         (tokio broadcast)
...                  ─┘
```

### Event Routing on Frontend

```typescript
// Event router: SSE → Zustand store + per-agent Jotai atoms
function routeEvent(event: OrchestratorEvent): void {
  const { agentId, type } = event;

  // 1. Update global store for cross-block state
  switch (type) {
    case 'RUN_STARTED':
    case 'RUN_FINISHED':
    case 'STATE_SNAPSHOT':
    case 'STATE_DELTA':
      updateOrchestratorStore(event);
      break;
  }

  // 2. Route to agent-specific block atoms
  const blockAtoms = blockAtomRegistry.get(agentId);
  if (blockAtoms) {
    switch (type) {
      case 'TEXT_MESSAGE_CONTENT':
        appendToLogAtom(blockAtoms.logsAtom, event.content);
        break;
      case 'TOOL_CALL_START':
        updateToolCallAtom(blockAtoms.activeToolAtom, event);
        break;
      case 'RUN_FINISHED':
        if (event.outcome === 'interrupt') {
          addToApprovalQueue(event);
        }
        break;
    }
  }

  // 3. Route custom events to specialized blocks
  if (type === 'RAW') {
    routeCustomEvent(event as RawEvent);
  }
}
```

### Agent ID Convention

```typescript
type AgentRole =
  | 'backend-agent'
  | 'frontend-agent'
  | 'infrastructure-agent'
  | 'qe-agent'
  | 'security-agent'
  | 'docs-agent'
  | 'observability-agent'
  | 'db-migration-agent'
  | 'performance-agent';

// Agent ID format: {role}-{buildId}-{sequence}
// Example: "backend-agent-build_abc123-1"
```

### Sequence Number Guarantees

Each agent maintains a monotonically increasing sequence number. The frontend uses this to:
- Detect out-of-order delivery (reorder in the 50ms batch window)
- Detect gaps (request targeted replay from the backend)
- Merge concurrent updates correctly

```typescript
interface AgentEventBuffer {
  agentId: string;
  lastSequence: number;
  pending: OrchestratorEvent[];
}

function processWithSequenceCheck(
  buffer: AgentEventBuffer,
  event: OrchestratorEvent
): OrchestratorEvent[] {
  if (event.sequenceNum <= buffer.lastSequence) {
    return []; // duplicate, skip
  }

  if (event.sequenceNum > buffer.lastSequence + 1) {
    // Gap detected -- buffer and wait for missing events
    buffer.pending.push(event);
    buffer.pending.sort((a, b) => a.sequenceNum - b.sequenceNum);
    return [];
  }

  // In order -- process this event and any buffered sequential events
  const result = [event];
  buffer.lastSequence = event.sequenceNum;

  while (
    buffer.pending.length > 0 &&
    buffer.pending[0].sequenceNum === buffer.lastSequence + 1
  ) {
    const next = buffer.pending.shift()!;
    result.push(next);
    buffer.lastSequence = next.sequenceNum;
  }

  return result;
}
```

---

## 4. Interrupt Lifecycle

Interrupts are the mechanism for human-in-the-loop approval flows. When a QA gate blocks an agent, the agent emits an interrupt and pauses until the frontend sends a resume command.

### Step-by-Step Flow

```
1. Agent completes QA evaluation
2. QA scores fall in 2-3 range (human review required)
3. Backend emits: RUN_FINISHED { outcome: "interrupt", interrupt: { reason: "quality_gate", payload: qaReport } }
4. Frontend receives event via SSE
5. Frontend adds to approval queue (Zustand store)
6. Frontend shows persistent toast notification
7. DAG node shows "paused" animation
8. User reviews QA report in approval-queue block
9. User clicks "Approve" or "Reject"
10. Frontend sends REST: POST /api/approvals/{id}/decide { decision: "approved" }
11. Backend resumes agent execution
12. Backend emits: RUN_STARTED (new run for the resumed agent)
```

### Frontend Interrupt Handler

```typescript
function handleInterrupt(event: RunFinishedEvent): void {
  if (event.outcome !== 'interrupt' || !event.interrupt) return;

  const approval: Approval = {
    id: `approval_${event.runId}_${Date.now()}`,
    buildId: event.runId,
    agentId: event.agentId,
    agentRole: event.agentRole,
    gateType: event.interrupt.reason,
    payload: event.interrupt.payload,
    resumeOptions: event.interrupt.resumeOptions ?? ['approve', 'reject'],
    status: 'pending',
    createdAt: new Date(),
  };

  // Add to Zustand store
  useOrchestratorStore.getState().addPendingApproval(approval);

  // Show persistent notification
  toast('QA Gate requires review', {
    duration: Infinity,
    action: {
      label: 'Review',
      onClick: () => {
        useOrchestratorStore.getState().selectApproval(approval.id);
        useOrchestratorStore.getState().switchLayout('review');
      },
    },
  });
}
```

### Approval Decision API

```typescript
interface ApprovalDecision {
  approvalId: string;
  decision: 'approved' | 'rejected' | 'retry';
  comment?: string;
  decidedBy: string;
}

async function submitApprovalDecision(decision: ApprovalDecision): Promise<void> {
  await fetch(`/api/approvals/${decision.approvalId}/decide`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(decision),
  });

  // Optimistic update
  useOrchestratorStore.getState().resolveApproval(
    decision.approvalId,
    decision.decision
  );
}
```

### Known Interrupt Issues

Monitor these CopilotKit issues if using their hooks:
- **#1809:** `useLangGraphInterrupt` sometimes does not resume after approval
- **#2315:** Extra null-state execution after interrupt resolution
- **#2939:** Cannot resume after page reload (state lost)

**Mitigation:** Build a fallback REST-based approval flow that does not depend on CopilotKit's interrupt hooks. Store interrupt state in SQLite so it survives page reloads.

---

## 5. Transport Configuration

### SSE Setup

```typescript
function createEventSource(buildId: string): EventSource {
  const url = new URL('/api/events', window.location.origin);
  url.searchParams.set('buildId', buildId);

  const eventSource = new EventSource(url.toString());

  eventSource.onopen = () => {
    useOrchestratorStore.getState().setConnectionStatus('connected');
  };

  eventSource.onerror = (error) => {
    useOrchestratorStore.getState().setConnectionStatus('reconnecting');
    // EventSource auto-reconnects with exponential backoff
    // No manual reconnection logic needed
  };

  eventSource.onmessage = (event) => {
    const parsed = JSON.parse(event.data) as OrchestratorEvent;
    pendingEvents.push(parsed);
    scheduleBatchFlush();
  };

  return eventSource;
}
```

### Reconnection with Last-Event-ID

SSE natively supports reconnection via the `Last-Event-ID` header. The browser sends this automatically on reconnect.

```rust
// Backend: include event IDs for reconnection support
yield Ok(Event::default()
    .event(&event.event_type)
    .data(serde_json::to_string(&event).unwrap())
    .id(event.sequence_num.to_string()));  // Monotonic ID
```

On reconnection, the backend receives the `Last-Event-ID` header and replays events from that point:

```rust
async fn sse_events(
    State(app): State<AppState>,
    headers: HeaderMap,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let last_id = headers
        .get("Last-Event-ID")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.parse::<u64>().ok());

    let stream = async_stream::stream! {
        // Replay missed events if reconnecting
        if let Some(last_id) = last_id {
            let missed = app.event_log.get_events_since(last_id).await;
            for event in missed {
                yield Ok(convert_to_sse(event));
            }
        }

        // Then switch to live stream
        // ...
    };

    Sse::new(stream)
}
```

### Keep-Alive

SSE connections drop after idle timeouts (typically 30-60s on proxies). Send keep-alive comments.

```rust
Sse::new(stream).keep_alive(
    axum::response::sse::KeepAlive::new()
        .interval(Duration::from_secs(15))
        .text("ping")
)
```

### Nginx Configuration

SSE requires specific proxy settings to prevent buffering:

```nginx
location /api/events {
    proxy_pass http://localhost:3001;
    proxy_buffering off;
    chunked_transfer_encoding off;
    proxy_cache off;
    proxy_set_header Connection '';
    proxy_http_version 1.1;
    proxy_read_timeout 86400s;  # 24h, prevent premature close
}
```

### HTTP/2 for Concurrent Streams

HTTP/1.1 limits browsers to 6 concurrent SSE connections per domain. HTTP/2 multiplexes 100+ streams over a single connection. Always deploy behind an HTTP/2-capable proxy for multi-agent scenarios.

---

## 6. Frontend Hooks

### useAgent (Custom Implementation)

A lightweight hook for managing an agent's event stream. This can be used directly or replaced with CopilotKit's `useAgent()` if its bugs are resolved.

```typescript
function useAgent(agentId: string) {
  const [status, setStatus] = useState<AgentStatus>('idle');
  const [messages, setMessages] = useState<AgentMessage[]>([]);
  const [activeToolCall, setActiveToolCall] = useState<ToolCall | null>(null);
  const [interrupt, setInterrupt] = useState<InterruptPayload | null>(null);

  useEffect(() => {
    const unsubscribe = subscribeToAgentEvents(agentId, (event) => {
      switch (event.type) {
        case 'RUN_STARTED':
          setStatus('running');
          break;
        case 'TEXT_MESSAGE_CONTENT':
          setMessages((prev) => appendContent(prev, event));
          break;
        case 'TOOL_CALL_START':
          setActiveToolCall({ id: event.toolCallId, name: event.toolName, args: '' });
          break;
        case 'TOOL_CALL_ARGS':
          setActiveToolCall((prev) =>
            prev ? { ...prev, args: prev.args + event.args } : null
          );
          break;
        case 'TOOL_CALL_END':
          setActiveToolCall(null);
          break;
        case 'RUN_FINISHED':
          setStatus(event.outcome === 'success' ? 'completed' : event.outcome);
          if (event.outcome === 'interrupt') {
            setInterrupt(event.interrupt ?? null);
          }
          break;
      }
    });

    return unsubscribe;
  }, [agentId]);

  const resume = useCallback(
    async (decision: string) => {
      await fetch(`/api/agents/${agentId}/resume`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ decision }),
      });
      setInterrupt(null);
    },
    [agentId]
  );

  return { status, messages, activeToolCall, interrupt, resume };
}
```

### useInterruptQueue

Hook for the approval queue block.

```typescript
function useInterruptQueue() {
  const pendingApprovals = useOrchestratorStore(
    useShallow((s) => s.pendingApprovals)
  );
  const approvalHistory = useOrchestratorStore(
    useShallow((s) => s.approvalHistory)
  );

  const approve = useCallback(async (approvalId: string, comment?: string) => {
    await submitApprovalDecision({
      approvalId,
      decision: 'approved',
      comment,
      decidedBy: 'operator',
    });
  }, []);

  const reject = useCallback(async (approvalId: string, comment?: string) => {
    await submitApprovalDecision({
      approvalId,
      decision: 'rejected',
      comment,
      decidedBy: 'operator',
    });
  }, []);

  const retry = useCallback(async (approvalId: string) => {
    await submitApprovalDecision({
      approvalId,
      decision: 'retry',
      decidedBy: 'operator',
    });
  }, []);

  return {
    pending: pendingApprovals,
    history: approvalHistory,
    approve,
    reject,
    retry,
  };
}
```

### useCoAgentState

Hook for syncing agent-side state into a block's Jotai atoms.

```typescript
function useCoAgentState<T>(agentId: string, initialState: T) {
  const [state, setState] = useState<T>(initialState);

  useEffect(() => {
    const unsubscribe = subscribeToAgentEvents(agentId, (event) => {
      if (event.type === 'STATE_SNAPSHOT') {
        setState(event.state as T);
      } else if (event.type === 'STATE_DELTA') {
        setState((prev) => ({ ...prev, ...(event.delta as Partial<T>) }));
      }
    });

    return unsubscribe;
  }, [agentId]);

  return state;
}
```

---

## 7. Custom Event Types via RAW

The `RAW` event type is the escape hatch for domain-specific events not covered by the 17 standard types.

### QA Report Events

```typescript
interface QAReportRawEvent extends RawEvent {
  customType: 'qa-report';
  payload: {
    agentId: string;
    agentRole: AgentRole;
    scores: {
      output: number;          // 1-5
      contractConformance: number; // 1-5
      security: number;        // 1-5
      performance: number;     // 1-5
    };
    criticalBlockers: string[];
    warnings: string[];
    passedChecks: number;
    totalChecks: number;
  };
}
```

### Contract Compliance Events

```typescript
interface ContractComplianceRawEvent extends RawEvent {
  customType: 'contract-compliance';
  payload: {
    contractId: string;
    type: 'openapi' | 'asyncapi' | 'pydantic' | 'typescript';
    status: 'compliant' | 'violation' | 'partial';
    endpoints: {
      path: string;
      method: string;
      status: 'compliant' | 'violation' | 'missing';
      violations: string[];
    }[];
  };
}
```

### Metrics Update Events

```typescript
interface MetricsRawEvent extends RawEvent {
  customType: 'metrics-update';
  payload: {
    agentId: string;
    tokensPerSecond: number;
    totalTokens: number;
    costCents: number;
    latencyMs: number;
    timestamp: number;
  };
}
```

### Routing Custom Events

```typescript
function routeCustomEvent(event: RawEvent): void {
  switch (event.customType) {
    case 'qa-report':
      updateQAReportBlock(event.payload);
      break;
    case 'contract-compliance':
      updateContractComplianceBlock(event.payload);
      break;
    case 'metrics-update':
      updateMetricsBlock(event.payload);
      break;
    case 'file-ownership-violation':
      showFileOwnershipAlert(event.payload);
      break;
    case 'collision-detected':
      showCollisionWarning(event.payload);
      break;
    default:
      console.warn(`Unknown custom event type: ${event.customType}`);
  }
}
```

---

## 8. Error Handling

### RUN_ERROR vs RUN_FINISHED with error outcome

- `RUN_ERROR` -- non-terminal error. Agent continues execution. Show warning in log viewer.
- `RUN_FINISHED { outcome: "error" }` -- terminal error. Agent has stopped. Show error toast, highlight DAG node.

### Connection Drop Recovery

SSE auto-reconnects with `Last-Event-ID`. During reconnection:

```typescript
eventSource.onerror = () => {
  useOrchestratorStore.getState().setConnectionStatus('reconnecting');

  // Show unobtrusive indicator, not an error toast
  // SSE will auto-reconnect -- no manual intervention needed
};

eventSource.onopen = () => {
  useOrchestratorStore.getState().setConnectionStatus('connected');

  // The first event after reconnect should be STATE_SNAPSHOT
  // This recovers any missed events during disconnection
};
```

### Timeout Handling

If no events arrive for 30 seconds (including keep-alive pings), consider the connection dead and recreate:

```typescript
let lastEventTime = Date.now();

eventSource.onmessage = (event) => {
  lastEventTime = Date.now();
  // ... process event
};

const healthCheck = setInterval(() => {
  if (Date.now() - lastEventTime > 30_000) {
    eventSource.close();
    useOrchestratorStore.getState().setConnectionStatus('disconnected');
    // Recreate after a brief delay
    setTimeout(() => createEventSource(buildId), 1000);
  }
}, 5000);
```

### Retry Semantics

| Error Type | Retry Strategy |
|------------|----------------|
| SSE connection drop | Automatic (browser EventSource) |
| REST approval POST fails | Retry 3x with exponential backoff |
| Agent process crash | Reactions system handles (YAML config) |
| Invalid event JSON | Log and skip (do not crash the event loop) |
| Sequence gap detected | Wait 500ms, then request replay via REST |

---

## 9. State Synchronization

### STATE_SNAPSHOT (Full Sync)

Emitted every 5 seconds and on initial connection. Contains the complete orchestrator state.

```typescript
function handleStateSnapshot(snapshot: OrchestratorStateSnapshot): void {
  // Replace entire store state
  useOrchestratorStore.setState({
    buildId: snapshot.buildId,
    buildPhase: snapshot.buildPhase,
    buildStatus: snapshot.buildStatus,
    agents: snapshot.agents,
    pendingApprovals: snapshot.pendingApprovals,
    lastSyncAt: new Date(snapshot.timestamp),
  });

  // Update per-agent block atoms
  for (const agent of snapshot.agents) {
    const atoms = blockAtomRegistry.get(agent.id);
    if (atoms) {
      store.set(atoms.statusAtom, agent.status);
      store.set(atoms.progressAtom, agent.progress);
    }
  }
}
```

### STATE_DELTA (Incremental Sync)

Emitted on every state change. Contains only changed fields.

```typescript
function handleStateDelta(delta: Partial<OrchestratorStateSnapshot>): void {
  useOrchestratorStore.setState((prev) => {
    const next = { ...prev };

    if (delta.buildPhase !== undefined) next.buildPhase = delta.buildPhase;
    if (delta.buildStatus !== undefined) next.buildStatus = delta.buildStatus;

    if (delta.agents) {
      // Merge agent updates (delta.agents contains only changed agents)
      next.agents = prev.agents.map((existing) => {
        const update = delta.agents!.find((a) => a.id === existing.id);
        return update ? { ...existing, ...update } : existing;
      });
      // Add new agents not in previous state
      const existingIds = new Set(prev.agents.map((a) => a.id));
      const newAgents = delta.agents.filter((a) => !existingIds.has(a.id));
      next.agents = [...next.agents, ...newAgents];
    }

    if (delta.pendingApprovals) {
      next.pendingApprovals = delta.pendingApprovals;
    }

    next.lastSyncAt = new Date();
    return next;
  });
}
```

### Consistency Model

The 5-second snapshot ensures eventual consistency. Deltas provide low-latency updates between snapshots. If a delta is missed, the next snapshot corrects the state automatically. No manual conflict resolution is needed.

---

## 10. Testing

### Mock Event Stream

Create a mock SSE server for development and testing.

```typescript
// test-utils/mock-sse.ts
class MockEventSource {
  private listeners: Map<string, ((event: MessageEvent) => void)[]> = new Map();
  private timeline: { delay: number; event: OrchestratorEvent }[] = [];

  addEventListener(type: string, callback: (event: MessageEvent) => void) {
    const list = this.listeners.get(type) ?? [];
    list.push(callback);
    this.listeners.set(type, list);
  }

  emit(event: OrchestratorEvent) {
    const listeners = this.listeners.get('message') ?? [];
    const messageEvent = new MessageEvent('message', {
      data: JSON.stringify(event),
    });
    listeners.forEach((cb) => cb(messageEvent));
  }

  // Replay a scripted scenario
  async playScenario(scenario: OrchestratorEvent[]): Promise<void> {
    for (const event of scenario) {
      this.emit(event);
      await sleep(50); // simulate real timing
    }
  }

  close() {
    this.listeners.clear();
  }
}
```

### Test Scenarios

```typescript
// Scenario: full build lifecycle
const buildLifecycleScenario: OrchestratorEvent[] = [
  { type: 'STATE_SNAPSHOT', state: initialState, agentId: 'orchestrator', ... },
  { type: 'RUN_STARTED', agentId: 'backend-agent', ... },
  { type: 'RUN_STARTED', agentId: 'frontend-agent', ... },
  { type: 'TEXT_MESSAGE_CONTENT', agentId: 'backend-agent', content: 'Generating API routes...', ... },
  { type: 'TOOL_CALL_START', agentId: 'backend-agent', toolName: 'file_write', ... },
  { type: 'TOOL_CALL_END', agentId: 'backend-agent', ... },
  { type: 'RUN_FINISHED', agentId: 'backend-agent', outcome: 'interrupt',
    interrupt: { reason: 'quality_gate', payload: qaReport }, ... },
  // ... approval submitted via REST mock
  { type: 'RUN_STARTED', agentId: 'backend-agent', ... }, // resumed
  { type: 'RUN_FINISHED', agentId: 'backend-agent', outcome: 'success', ... },
  { type: 'RUN_FINISHED', agentId: 'frontend-agent', outcome: 'success', ... },
];
```

### Integration Test Pattern

```typescript
import { render, screen, waitFor } from '@testing-library/react';

describe('AG-UI Event Integration', () => {
  let mockSSE: MockEventSource;

  beforeEach(() => {
    mockSSE = new MockEventSource();
    // Inject mock into the SSE connection factory
    vi.spyOn(window, 'EventSource').mockImplementation(() => mockSSE as any);
  });

  it('handles full build lifecycle', async () => {
    render(<Dashboard buildId="test-build" />);

    await mockSSE.playScenario(buildLifecycleScenario);

    await waitFor(() => {
      expect(screen.getByText('backend-agent')).toBeInTheDocument();
      expect(screen.getByText('QA Gate requires review')).toBeInTheDocument();
    });
  });

  it('recovers from connection drop via STATE_SNAPSHOT', async () => {
    render(<Dashboard buildId="test-build" />);

    // Simulate partial events
    mockSSE.emit(runStartedEvent);
    mockSSE.emit(textContentEvent);

    // Simulate reconnection with state snapshot
    mockSSE.emit(stateSnapshotEvent);

    await waitFor(() => {
      // State should be fully recovered from snapshot
      const store = useOrchestratorStore.getState();
      expect(store.agents).toHaveLength(stateSnapshotEvent.state.agents.length);
    });
  });
});
```
