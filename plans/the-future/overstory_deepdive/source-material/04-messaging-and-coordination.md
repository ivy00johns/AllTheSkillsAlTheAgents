# 04 — Messaging and Coordination

## SQLite Mail System

The mail system is Overstory's nervous system. Every inter-agent communication
flows through `mail.db` — a purpose-built SQLite database with WAL mode for
concurrent access from 10+ agent processes.

### Why Not Use the LLM's Built-in Communication?

Claude Code's Agent tool and experimental Agent Teams have their own
communication primitives, but Overstory built a custom mail system because:

1. **Runtime-neutral** — works with Pi, Codex, Gemini, etc., not just Claude
2. **Persistent** — messages survive session restarts and context compactions
3. **Queryable** — agents can search, filter, and paginate messages
4. **Typed** — protocol messages have structured payloads
5. **Observable** — the orchestrator can inspect all communication
6. **Fast** — ~1-5ms per query vs beads' slower git-based approach

### Message Schema

```typescript
interface MailMessage {
  id: string;                // "msg-" + nanoid(12)
  from: string;              // Agent name
  to: string;                // Agent name, "orchestrator", or broadcast address
  subject: string;
  body: string;
  priority: "low" | "normal" | "high" | "urgent";
  type: MailMessageType;
  threadId: string | null;   // Conversation threading
  payload: string | null;    // JSON-encoded structured data
  read: boolean;
  createdAt: string;         // ISO timestamp
}
```

### Semantic Message Types

Human-readable types for general communication:

| Type | Purpose | Example |
|------|---------|---------|
| `status` | Progress update | "Builder-1 is 60% complete" |
| `question` | Needs clarification | "Should I use REST or GraphQL?" |
| `result` | Work output | Scout findings, review verdict |
| `error` | Something went wrong | Build failure, missing dependency |

### Protocol Message Types

Machine-readable types for structured coordination:

| Type | Payload | Purpose |
|------|---------|---------|
| `worker_done` | `WorkerDonePayload` | Worker signals task completion |
| `merge_ready` | `MergeReadyPayload` | Branch verified and ready for merge |
| `merged` | `MergedPayload` | Branch was merged successfully |
| `merge_failed` | `MergeFailedPayload` | Merge failed, needs rework |
| `escalation` | `EscalationPayload` | Issue escalated to decision-maker |
| `health_check` | `HealthCheckPayload` | Watchdog probes agent liveness |
| `dispatch` | `DispatchPayload` | Coordinator dispatches work |
| `assign` | `AssignPayload` | Supervisor assigns to specific worker |
| `decision_gate` | `DecisionGatePayload` | Human-in-the-loop decision point |

### Protocol Payload Examples

**WorkerDonePayload:**
```typescript
{
  taskId: "task-abc123",
  branch: "worker/builder-1/task-abc123",
  exitCode: 0,
  filesModified: ["src/api/routes.ts", "src/api/routes.test.ts"]
}
```

**DispatchPayload:**
```typescript
{
  taskId: "task-xyz789",
  specPath: ".overstory/specs/task-xyz789.md",
  capability: "builder",
  fileScope: ["src/services/auth.ts", "src/middleware/jwt.ts"],
  skipScouts: false,
  skipReview: true,
  maxAgents: 3
}
```

**DecisionGatePayload:**
```typescript
{
  options: ["Proceed with REST", "Switch to GraphQL", "Escalate to human"],
  context: "API design decision: the existing codebase uses REST but the spec requests GraphQL",
  deadline: "2026-03-18T18:00:00Z"
}
```

## Mail Operations

### CLI Commands

```bash
# Send a message
ov mail send --to builder-1 --subject "Start task" \
  --body "Spec: .overstory/specs/task-1.md" \
  --type dispatch --priority normal

# Check inbox (unread messages, optionally inject into context)
ov mail check --agent builder-1 --inject

# List messages with filters
ov mail list --from builder-1 --to orchestrator --unread

# Read (mark as read)
ov mail read msg-abc123

# Reply in thread
ov mail reply msg-abc123 --body "Use REST, it matches existing patterns"

# Purge old messages
ov mail purge --days 7
ov mail purge --agent old-builder
ov mail purge --all
```

### The `--inject` Flag

`ov mail check --inject` is the key to the hook-driven orchestrator loop.
When called from the `UserPromptSubmit` hook, it:

1. Queries `mail.db` for unread messages to the orchestrator
2. Formats them as readable text
3. Outputs them to stdout — which gets injected into the Claude Code context

This is how the orchestrator "hears" from its agents without polling.

## Broadcast Groups

Messages can be sent to broadcast addresses that resolve to multiple agents:

| Address | Resolves To |
|---------|-------------|
| `@all` | All active agents |
| `@builders` | All agents with capability "builder" |
| `@scouts` | All agents with capability "scout" |
| `@leads` | All agents with capability "lead" |

Implemented in `src/mail/broadcast.ts` — resolves group addresses by
querying `sessions.db` for active agents matching the capability filter.

## The Nudge System

Sometimes agents stall — they're alive but not making progress. The nudge
system provides progressive intervention:

```bash
ov nudge builder-1 "Status check — are you blocked?"
ov nudge builder-1 --force  # Skip debounce
```

Nudges work by sending text directly into the agent's tmux session via
`tmux send-keys`. This is distinct from mail — it's a direct interrupt
that appears in the agent's conversation context.

For RPC-capable runtimes (Pi), nudges use `RuntimeConnection.followUp()`
instead of tmux send-keys.

### Progressive Escalation

The watchdog system uses escalation levels (stored on `AgentSession`):

```
Level 0: warn   — log a warning
Level 1: nudge  — send a tmux nudge
Level 2: escalate — send escalation mail to parent
Level 3: terminate — kill the agent process
```

The `nudgeIntervalMs` config controls time between escalation stages.

## Communication Patterns

### Worker Done → Review → Merge Ready Flow

```
Builder-1 completes work
  → sends: worker_done (to Lead)
      payload: { taskId, branch, exitCode, filesModified }

Lead receives worker_done
  → spawns Reviewer (or self-verifies)

Reviewer validates
  → sends: result (to Lead, "PASS" or "FAIL")

Lead receives PASS
  → sends: merge_ready (to Coordinator)
      payload: { branch, taskId, agentName, filesModified }

Coordinator receives merge_ready
  → runs: ov merge --branch <branch>
  → sends: merged (to Lead)
      payload: { branch, taskId, tier }
```

### Error Escalation Flow

```
Builder-1 hits an error
  → sends: error (to Lead)

Lead assesses
  → if retryable: sends instructions back to Builder-1
  → if not: sends escalation (to Coordinator)
      payload: { severity: "error", taskId, context }

Coordinator receives escalation
  → decides: retry, reassign, or ask human
```

### Coordinator Exit Detection

The coordinator checks exit triggers via `ov coordinator check-complete`:

1. **allAgentsDone** — queries sessions.db for any non-completed agents
2. **taskTrackerEmpty** — runs `sd ready` or `bd ready` and checks for work
3. **onShutdownSignal** — checks mail for shutdown-type messages

When all configured triggers are satisfied, the coordinator can self-terminate.
