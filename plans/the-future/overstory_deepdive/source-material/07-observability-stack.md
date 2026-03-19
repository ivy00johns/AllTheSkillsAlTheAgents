# 07 — Observability Stack

## Overview

Overstory has a comprehensive observability system built on SQLite. When you're
running 10+ agents, you need to know: what's happening, what went wrong, how
much it's costing, and what happened in what order.

## Event Store (`events.db`)

The central event database tracks every significant agent action.

### Event Types

```typescript
type EventType =
  | "tool_start" | "tool_end"      // Tool call begin/end with timing
  | "session_start" | "session_end" // Agent lifecycle
  | "mail_sent" | "mail_received"  // Communication
  | "spawn"                        // Agent spawning
  | "error"                        // Failures
  | "turn_start" | "turn_end"     // Conversation turns
  | "progress" | "result"         // Work output
  | "custom"                       // Extension point
```

### Stored Event Schema

```typescript
interface StoredEvent {
  id: number;                 // Auto-increment
  runId: string | null;       // Groups events by coordinator run
  agentName: string;
  sessionId: string | null;
  eventType: EventType;
  toolName: string | null;    // For tool_start/tool_end
  toolArgs: string | null;    // Filtered tool arguments
  toolDurationMs: number | null;
  level: EventLevel;          // debug | info | warn | error
  data: string | null;        // JSON payload
  createdAt: string;          // ISO timestamp
}
```

### Smart Arg Filtering

Tool arguments are filtered before storage (`src/events/tool-filter.ts`):
- File paths are preserved (useful for debugging)
- Large content bodies are truncated
- Sensitive data is redacted
- Irrelevant args are dropped

### Event Store Interface

```typescript
interface EventStore {
  insert(event: InsertEvent): number;
  correlateToolEnd(agentName, toolName): { startId, durationMs } | null;
  getByAgent(agentName, opts?): StoredEvent[];
  getByRun(runId, opts?): StoredEvent[];
  getErrors(opts?): StoredEvent[];
  getTimeline(opts): StoredEvent[];
  getToolStats(opts?): ToolStats[];
  purge(opts): number;
  close(): void;
}
```

## Metrics Store (`metrics.db`)

Token usage, cost tracking, and session metrics.

### Session Metrics

```typescript
interface SessionMetrics {
  agentName: string;
  taskId: string;
  capability: string;
  startedAt: string;
  completedAt: string | null;
  durationMs: number;
  exitCode: number | null;
  mergeResult: ResolutionTier | null;
  parentAgent: string | null;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheCreationTokens: number;
  estimatedCostUsd: number | null;
  modelUsed: string | null;
  runId: string | null;
}
```

### Token Snapshots

Point-in-time token usage for live agents:

```typescript
interface TokenSnapshot {
  agentName: string;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheCreationTokens: number;
  estimatedCostUsd: number | null;
  modelUsed: string | null;
  createdAt: string;
  runId: string | null;
}
```

### Runtime-Agnostic Pricing

`src/metrics/pricing.ts` calculates costs across runtimes. Each runtime
parses its own transcript format, but the cost calculation is centralized.

### Transcript Parsing

`src/metrics/transcript.ts` parses Claude Code's JSONL transcript files
to extract token usage after sessions complete.

## CLI Observability Commands

### `ov status`

Shows all active agents, worktrees, and states at a glance.

```bash
ov status           # Current run's agents
ov status --all     # All runs
ov status --json    # Machine-readable
ov status --verbose # Extra per-agent detail
```

### `ov dashboard`

Live TUI dashboard that polls and refreshes continuously:

```bash
ov dashboard                   # Default 2s interval
ov dashboard --interval 1000   # 1s polling
ov dashboard --all             # Show all runs
```

Displays agent states, durations, recent activity, and health status
in a terminal-friendly table format.

### `ov inspect <agent>`

Deep inspection of a single agent — tool calls, mail, events, tmux output:

```bash
ov inspect builder-1
ov inspect builder-1 --follow          # Continuous polling
ov inspect builder-1 --limit 50       # Last 50 tool calls
ov inspect builder-1 --no-tmux        # Skip tmux capture
```

### `ov trace <target>`

Chronological event timeline for an agent or task:

```bash
ov trace builder-1
ov trace builder-1 --since 2026-03-18T10:00:00
ov trace builder-1 --limit 200
```

### `ov errors`

Aggregated error view across all agents:

```bash
ov errors
ov errors --agent builder-1
ov errors --run run-2026-03-18T10:00:00
ov errors --since 2026-03-18T10:00:00
```

### `ov replay`

Interleaved chronological replay across multiple agents — see what
happened when, across the entire fleet:

```bash
ov replay
ov replay --run run-2026-03-18T10:00:00
ov replay --agent builder-1 --agent builder-2
ov replay --since 2026-03-18T10:00:00 --limit 500
```

### `ov feed`

Unified real-time event stream:

```bash
ov feed --follow               # Live tail
ov feed --follow --interval 1000
ov feed --agent builder-1
ov feed --since 2026-03-18T10:00:00
```

### `ov costs`

Token usage and cost analysis:

```bash
ov costs                       # Summary for recent sessions
ov costs --live                # Real-time token usage for active agents
ov costs --self                # Current orchestrator session cost
ov costs --agent builder-1     # Single agent breakdown
ov costs --run run-xxx         # Full run breakdown
ov costs --bead task-123       # Cost per task
ov costs --by-capability       # Group by capability with subtotals
ov costs --last 50             # Last 50 sessions
```

### `ov logs`

Query NDJSON logs across agents:

```bash
ov logs --agent builder-1
ov logs --level error
ov logs --since 2026-03-18T10:00:00
ov logs --follow               # Live tail
```

### `ov metrics`

Session metrics summary:

```bash
ov metrics --last 20
```

### `ov run`

Manage coordinator runs:

```bash
ov run                         # Current run status
ov run list --last 10          # Recent runs
ov run show run-xxx            # Run details with agents
ov run complete                # Mark current run as completed
```

## Watchdog System (Three Tiers)

### Tier 0: Mechanical Daemon (`src/watchdog/daemon.ts`)

Background process that periodically checks agent health:

```bash
ov watch --interval 30000 --background
```

Checks:
- **Process alive** — is the tmux session still running?
- **PID alive** — is the Claude Code process still running?
- **Activity** — has the agent done anything recently?
- **State** — is the recorded state consistent with reality?

Actions: warn → nudge → escalate → terminate (progressive)

### Tier 1: AI Triage (`src/watchdog/triage.ts`)

Ephemeral AI analysis for ambiguous situations. When Tier 0 can't determine
if an agent is truly stuck or just thinking:

- Captures tmux pane content
- Sends to Claude (headless `--print`) for analysis
- Claude classifies: working, stuck, errored, completed
- Result drives the next action

### Tier 2: Monitor Agent (`src/watchdog/` + `agents/monitor.md`)

A persistent Claude Code session that patrols the fleet:

```bash
ov monitor start               # Spawns a Claude Code monitor
ov monitor stop
ov monitor status
```

The monitor agent:
- Reads all state (sessions, mail, events, metrics)
- Analyzes fleet health patterns
- Sends recommendations to the coordinator
- Can detect systemic issues (e.g., all builders stuck on same dependency)

### Health State Machine

```typescript
interface HealthCheck {
  agentName: string;
  timestamp: string;
  processAlive: boolean;
  tmuxAlive: boolean;
  pidAlive: boolean | null;
  lastActivity: string;
  state: AgentState;
  action: "none" | "escalate" | "terminate" | "investigate";
  reconciliationNote: string | null;  // Mismatch between observed and recorded
}
```

## Logging System

### Multi-Format Logger (`src/logging/logger.ts`)

Outputs both human-readable (ANSI colors) and machine-readable (NDJSON) formats:

```typescript
interface LogEvent {
  timestamp: string;
  level: "debug" | "info" | "warn" | "error";
  event: string;
  agentName: string | null;
  data: Record<string, unknown>;
}
```

### Secret Redaction (`src/logging/sanitizer.ts`)

Automatically redacts sensitive patterns before logging:
- API keys
- Tokens
- Passwords
- Connection strings

### Console Reporter (`src/logging/reporter.ts`)

ANSI-colored terminal output with consistent formatting:
- Agent names get stable colors
- State transitions are highlighted
- Timestamps are formatted consistently

### Visual Theme (`src/logging/theme.ts`)

Canonical color scheme for states, events, and separators.
All UI elements reference this theme for consistency.

## Doctor System

`ov doctor` runs 11 categories of health checks:

```bash
ov doctor                      # All checks
ov doctor --category config    # Single category
ov doctor --fix                # Auto-fix fixable issues
ov doctor --verbose            # Show passing checks too
```

Categories: dependencies, config, structure, databases, consistency,
agents, merge, logs, version, ecosystem, providers.

Each check returns pass/warn/fail with actionable messages.
Auto-fixable issues can be resolved with `--fix`.
