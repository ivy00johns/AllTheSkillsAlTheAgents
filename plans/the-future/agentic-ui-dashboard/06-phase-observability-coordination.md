# Phase 6 -- Observability + Coordination

**Version:** 0.1.0-draft
**Date:** 2026-03-20
**Status:** Design
**Dependencies:** Phase 3 (Agent Communication Layer)
**Duration:** 2 weeks
**Deliverables:** Langfuse integration, hcom collision detection, file ownership enforcement, trace visualization, OpenTelemetry Collector

---

## 1. Overview

Phase 6 instruments the entire orchestrator-agent pipeline with structured traces and builds the coordination layer that enforces exclusive file ownership -- the foundational constraint of the AllTheSkillsAllTheAgents architecture.

Three systems work in concert:

1. **Langfuse** -- Hierarchical trace visualization. Every build becomes a single session. Every agent becomes a trace. Every tool call, LLM invocation, and file write becomes a span. All linked by a shared `trace_id`.

2. **hcom** -- Inter-agent collision detection. When two agents edit the same file within a 30-second window, hcom detects the collision and alerts the dashboard. This is the safety net beneath the ownership enforcement layer.

3. **File ownership enforcement** -- Pre-write validation that blocks unauthorized file writes _before_ they happen. The ownership map comes from the contract definitions (which agent owns which directories). hcom catches anything that slips through.

**Why this phase matters:** Without observability, a 9-agent build is a black box. You can see what went in and what came out, but not _why_ agent 4 spent 3 minutes on a 10-line change, or _why_ agent 7's implementation drifted from the contract. Langfuse makes the reasoning chain visible. And without ownership enforcement, the contract-first architecture has no teeth -- any agent can write anywhere, causing merge conflicts and ownership violations that compound across phases.

---

## 2. Langfuse Integration

### 2.1 SDK Setup

The orchestrator and all agents share a single Langfuse configuration. The orchestrator generates a `trace_id` at build start, passes it to each agent via environment variables, and every agent instruments its work under that shared trace.

```typescript
// observability/langfuse-client.ts
import Langfuse from 'langfuse';

/**
 * Singleton Langfuse client.
 * Initialized once at orchestrator startup.
 * Agents receive connection details via environment variables.
 */
let langfuseInstance: Langfuse | null = null;

export function initLangfuse(config: LangfuseConfig): Langfuse {
  if (langfuseInstance) return langfuseInstance;

  langfuseInstance = new Langfuse({
    publicKey: config.publicKey,
    secretKey: config.secretKey,
    baseUrl: config.baseUrl ?? 'https://cloud.langfuse.com',

    // Async batching: buffer events and flush in background
    // ~0.1ms per trace/span call. Flush every 2 seconds.
    flushAt: 50,          // Flush after 50 events in buffer
    flushInterval: 2000,  // Or every 2 seconds, whichever comes first
    requestTimeout: 10000,

    // Shutdown hook: flush remaining events on process exit
    enabled: true,
  });

  // Graceful shutdown
  process.on('SIGTERM', async () => {
    await langfuseInstance?.shutdownAsync();
  });

  process.on('beforeExit', async () => {
    await langfuseInstance?.shutdownAsync();
  });

  return langfuseInstance;
}

export function getLangfuse(): Langfuse {
  if (!langfuseInstance) {
    throw new Error('Langfuse not initialized. Call initLangfuse() first.');
  }
  return langfuseInstance;
}

export interface LangfuseConfig {
  publicKey: string;
  secretKey: string;
  baseUrl?: string;
}
```

### 2.2 Shared trace_id Generation

The orchestrator generates one `trace_id` per build. This trace_id links every agent's work into a single hierarchical tree in Langfuse.

```typescript
// observability/trace-manager.ts
import { v4 as uuidv4 } from 'uuid';
import { getLangfuse } from './langfuse-client';

export interface BuildTraceContext {
  traceId: string;       // Shared across all agents
  sessionId: string;     // Langfuse session = one build
  buildId: string;
  planId: string;
}

/**
 * Create a new trace context for a build.
 * Called once by the orchestrator at build start.
 */
export function createBuildTraceContext(buildId: string, planId: string): BuildTraceContext {
  const traceId = `build_${buildId}`;
  const sessionId = buildId;

  // Create the root trace in Langfuse
  const langfuse = getLangfuse();
  langfuse.trace({
    id: traceId,
    name: `Build ${buildId}`,
    sessionId: sessionId,
    metadata: {
      buildId,
      planId,
      startedAt: new Date().toISOString(),
      agentCount: 0, // Updated as agents spawn
    },
    tags: ['build', `plan:${planId}`],
  });

  return { traceId, sessionId, buildId, planId };
}

/**
 * Environment variables passed to each agent subprocess.
 * Agents read these to connect to the shared trace.
 */
export function traceContextToEnv(ctx: BuildTraceContext): Record<string, string> {
  return {
    LANGFUSE_TRACE_ID: ctx.traceId,
    LANGFUSE_SESSION_ID: ctx.sessionId,
    LANGFUSE_BUILD_ID: ctx.buildId,
    LANGFUSE_PUBLIC_KEY: process.env.LANGFUSE_PUBLIC_KEY ?? '',
    LANGFUSE_SECRET_KEY: process.env.LANGFUSE_SECRET_KEY ?? '',
    LANGFUSE_BASE_URL: process.env.LANGFUSE_BASE_URL ?? 'https://cloud.langfuse.com',
  };
}
```

### 2.3 Hierarchical Span Structure

Every operation in the build creates a span under the shared trace. The hierarchy is:

```
Build (root trace)
  |
  +-- Phase 3: Contract Generation (span)
  |     |
  |     +-- contract-author execution (span, gen_ai.agent.name = "contract-author")
  |           |
  |           +-- LLM call (generation span, model = "claude-opus-4-20250514", tokens = {...})
  |           +-- Tool: file_write (span, gen_ai.tool.type = "file_write")
  |           +-- Tool: file_write (span)
  |
  +-- Phase 5: Parallel Implementation (span)
  |     |
  |     +-- backend-agent execution (span, gen_ai.agent.name = "backend-agent")
  |     |     |
  |     |     +-- LLM call (generation span)
  |     |     +-- Tool: file_read (span)
  |     |     +-- Tool: file_write (span)
  |     |     +-- LLM call (generation span)
  |     |     +-- Tool: bash (span)
  |     |
  |     +-- frontend-agent execution (span, gen_ai.agent.name = "frontend-agent")
  |     |     |
  |     |     +-- LLM call (generation span)
  |     |     +-- Tool: file_write (span)
  |     |     +-- ...
  |     |
  |     +-- infrastructure-agent execution (span)
  |     +-- db-migration-agent execution (span)
  |
  +-- Phase 8: QA Validation (span)
        |
        +-- qe-agent execution (span, gen_ai.agent.name = "qe-agent")
              |
              +-- Tool: run_tests (span)
              +-- Tool: contract_audit (span)
              +-- QA report generation (span)
```

### 2.4 Instrumentation Code

```typescript
// observability/instrumentor.ts
import { getLangfuse } from './langfuse-client';

/**
 * Instrument an agent execution.
 * Called when the orchestrator spawns an agent.
 */
export function instrumentAgentExecution(
  traceId: string,
  agentId: string,
  agentRole: string,
  phase: number,
  worktreePath: string,
): AgentInstrumentor {
  const langfuse = getLangfuse();

  // Create a span for this agent's entire execution
  const agentSpan = langfuse.span({
    traceId,
    name: `${agentRole}_execution`,
    metadata: {
      agentId,
      agentRole,
      phase,
      worktreePath,
      // OpenTelemetry GenAI Semantic Conventions
      'gen_ai.agent.name': agentRole,
      'gen_ai.operation.name': 'invoke_agent',
    },
    input: {
      role: agentRole,
      phase,
      worktree: worktreePath,
    },
  });

  return new AgentInstrumentor(langfuse, traceId, agentSpan, agentId, agentRole);
}

export class AgentInstrumentor {
  private tokenUsage = { prompt: 0, completion: 0, total: 0 };
  private toolCallCount = 0;
  private fileWriteCount = 0;
  private startTime = Date.now();

  constructor(
    private langfuse: Langfuse,
    private traceId: string,
    private agentSpan: any,       // Langfuse span object
    private agentId: string,
    private agentRole: string,
  ) {}

  /**
   * Record an LLM call (generation span).
   */
  recordLLMCall(params: {
    model: string;
    promptTokens: number;
    completionTokens: number;
    durationMs: number;
    input: string;
    output: string;
  }): void {
    this.langfuse.generation({
      traceId: this.traceId,
      parentObservationId: this.agentSpan.id,
      name: 'llm_call',
      model: params.model,
      modelParameters: {},
      input: params.input,
      output: params.output,
      usage: {
        promptTokens: params.promptTokens,
        completionTokens: params.completionTokens,
        totalTokens: params.promptTokens + params.completionTokens,
      },
      metadata: {
        'gen_ai.operation.name': 'chat',
        'gen_ai.request.model': params.model,
        durationMs: params.durationMs,
      },
    });

    this.tokenUsage.prompt += params.promptTokens;
    this.tokenUsage.completion += params.completionTokens;
    this.tokenUsage.total += params.promptTokens + params.completionTokens;
  }

  /**
   * Record a tool call (execute_tool span).
   */
  recordToolCall(params: {
    toolName: string;
    input: Record<string, any>;
    output: any;
    durationMs: number;
    success: boolean;
  }): void {
    this.langfuse.span({
      traceId: this.traceId,
      parentObservationId: this.agentSpan.id,
      name: `tool:${params.toolName}`,
      input: params.input,
      output: params.output,
      metadata: {
        'gen_ai.tool.type': params.toolName,
        'gen_ai.operation.name': 'execute_tool',
        durationMs: params.durationMs,
        success: params.success,
      },
      level: params.success ? 'DEFAULT' : 'ERROR',
    });

    this.toolCallCount++;
    if (params.toolName === 'file_write' || params.toolName === 'file_edit') {
      this.fileWriteCount++;
    }
  }

  /**
   * Record a file write (custom span with ownership metadata).
   */
  recordFileWrite(params: {
    filePath: string;
    linesChanged: number;
    ownerRole: string;
  }): void {
    this.langfuse.span({
      traceId: this.traceId,
      parentObservationId: this.agentSpan.id,
      name: `file_write:${params.filePath}`,
      input: { filePath: params.filePath },
      output: { linesChanged: params.linesChanged },
      metadata: {
        'gen_ai.operation.name': 'file_write',
        owner: params.ownerRole,
        writtenBy: this.agentRole,
        isOwnershipViolation: params.ownerRole !== this.agentRole,
      },
    });
  }

  /**
   * Finalize the agent execution span.
   * Called when the agent process exits.
   */
  finalize(params: {
    exitCode: number;
    error?: string;
  }): void {
    const durationMs = Date.now() - this.startTime;

    this.agentSpan.end({
      output: {
        exitCode: params.exitCode,
        error: params.error,
        tokenUsage: this.tokenUsage,
        toolCallCount: this.toolCallCount,
        fileWriteCount: this.fileWriteCount,
        durationMs,
      },
      level: params.exitCode === 0 ? 'DEFAULT' : 'ERROR',
      statusMessage: params.error ?? (params.exitCode === 0 ? 'success' : 'failed'),
    });

    // Update the root trace with agent summary
    this.langfuse.trace({
      id: this.traceId,
      metadata: {
        [`agent_${this.agentId}_duration_ms`]: durationMs,
        [`agent_${this.agentId}_tokens`]: this.tokenUsage.total,
        [`agent_${this.agentId}_exit_code`]: params.exitCode,
      },
    });
  }
}
```

### 2.5 Phase Span Instrumentation

```typescript
// observability/phase-instrumentor.ts
import { getLangfuse } from './langfuse-client';

/**
 * Instrument a build phase.
 * Wraps all agent executions within a phase under a single parent span.
 */
export function instrumentPhase(
  traceId: string,
  phaseNumber: number,
  phaseName: string,
  agentRoles: string[],
): PhaseInstrumentor {
  const langfuse = getLangfuse();

  const phaseSpan = langfuse.span({
    traceId,
    name: `Phase ${phaseNumber}: ${phaseName}`,
    metadata: {
      phaseNumber,
      phaseName,
      agentRoles,
      agentCount: agentRoles.length,
    },
    input: {
      phase: phaseNumber,
      name: phaseName,
      agents: agentRoles,
    },
  });

  return new PhaseInstrumentor(langfuse, traceId, phaseSpan, phaseNumber);
}

export class PhaseInstrumentor {
  private agentInstrumentors: AgentInstrumentor[] = [];
  private startTime = Date.now();

  constructor(
    private langfuse: Langfuse,
    private traceId: string,
    private phaseSpan: any,
    private phaseNumber: number,
  ) {}

  /**
   * Create a child agent instrumentor within this phase.
   */
  instrumentAgent(
    agentId: string,
    agentRole: string,
    worktreePath: string,
  ): AgentInstrumentor {
    const instrumentor = instrumentAgentExecution(
      this.traceId,
      agentId,
      agentRole,
      this.phaseNumber,
      worktreePath,
    );

    // Re-parent the agent span under the phase span
    // (Langfuse SDK handles this via parentObservationId)

    this.agentInstrumentors.push(instrumentor);
    return instrumentor;
  }

  /**
   * Finalize the phase span.
   */
  finalize(params: { success: boolean; qaReport?: any }): void {
    const durationMs = Date.now() - this.startTime;

    this.phaseSpan.end({
      output: {
        success: params.success,
        durationMs,
        agentCount: this.agentInstrumentors.length,
        qaReport: params.qaReport,
      },
      level: params.success ? 'DEFAULT' : 'ERROR',
    });
  }
}
```

### 2.6 Session Grouping

Langfuse sessions group multiple traces into a conversation-like view. For our use case, one build = one session. This lets operators browse builds chronologically and drill down into any phase or agent.

```typescript
// Integration with build lifecycle

async function startBuild(planId: string): Promise<Build> {
  const buildId = generateBuildId();

  // Create trace context (also creates Langfuse session)
  const traceCtx = createBuildTraceContext(buildId, planId);

  // Store context for later use
  buildTraceContexts.set(buildId, traceCtx);

  // Create Langfuse session explicitly (optional -- trace auto-creates sessions)
  getLangfuse().trace({
    id: traceCtx.traceId,
    sessionId: traceCtx.sessionId,
    name: `Build ${buildId}`,
    tags: ['build', `plan:${planId}`],
    metadata: {
      planId,
      buildId,
      startedAt: new Date().toISOString(),
    },
  });

  return {
    id: buildId,
    planId,
    traceId: traceCtx.traceId,
    status: 'running',
  };
}
```

---

## 3. hcom Collision Detection

### 3.1 Architecture

hcom provides inter-agent coordination through shell hooks and a SQLite event store. When an agent writes a file, a shell hook fires, recording the event. Other agents (and the dashboard) query the event store to detect collisions.

```
Agent A writes file X
    |
    v
Shell hook fires -> SQLite event store
    |
    v
Agent B queries recent events for file X
    |
    v
Collision detected (two writes within 30s by different agents)
    |
    v
Dashboard receives collision alert via SSE
```

### 3.2 Event Store Schema

hcom uses a SQLite database for event persistence. The schema for file edit tracking:

```sql
-- hcom event store (managed by hcom, queried by our integration)
CREATE TABLE IF NOT EXISTS file_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    agent_id TEXT NOT NULL,
    agent_role TEXT NOT NULL,
    event_type TEXT NOT NULL,        -- 'file_write', 'file_edit', 'file_delete'
    file_path TEXT NOT NULL,
    build_id TEXT,
    metadata TEXT                     -- JSON (line count, change summary, etc.)
);

CREATE INDEX IF NOT EXISTS idx_file_events_path_time
    ON file_events(file_path, timestamp);

CREATE INDEX IF NOT EXISTS idx_file_events_agent
    ON file_events(agent_id, timestamp);

CREATE INDEX IF NOT EXISTS idx_file_events_build
    ON file_events(build_id, timestamp);
```

### 3.3 Collision Detection Service

```typescript
// coordination/collision-detector.ts
import Database from 'better-sqlite3';

export interface CollisionEvent {
  id: string;
  filePath: string;
  agents: CollisionParticipant[];
  detectedAt: number;
  windowMs: number;
}

export interface CollisionParticipant {
  agentId: string;
  agentRole: string;
  timestamp: number;
  eventType: string;
}

export class CollisionDetector {
  private db: Database.Database;
  private readonly COLLISION_WINDOW_MS = 30_000; // 30 seconds
  private pollInterval: ReturnType<typeof setInterval> | null = null;
  private lastCheckedTimestamp = 0;
  private onCollision: ((collision: CollisionEvent) => void) | null = null;

  constructor(dbPath: string) {
    this.db = new Database(dbPath, { readonly: true });
  }

  /**
   * Start polling for collisions.
   * Polls every 5 seconds, checking for file edits within the collision window
   * that involve different agents.
   */
  startPolling(onCollision: (collision: CollisionEvent) => void): void {
    this.onCollision = onCollision;
    this.lastCheckedTimestamp = Date.now() - this.COLLISION_WINDOW_MS;

    this.pollInterval = setInterval(() => {
      this.checkForCollisions();
    }, 5_000); // Poll every 5 seconds

    // Initial check
    this.checkForCollisions();
  }

  stopPolling(): void {
    if (this.pollInterval) {
      clearInterval(this.pollInterval);
      this.pollInterval = null;
    }
  }

  /**
   * Query for collisions: files edited by multiple agents within the window.
   */
  private checkForCollisions(): void {
    const windowStart = new Date(Date.now() - this.COLLISION_WINDOW_MS).toISOString();

    // Find files with edits from multiple agents in the window
    const collisionQuery = this.db.prepare(`
      SELECT
        file_path,
        COUNT(DISTINCT agent_id) as agent_count,
        GROUP_CONCAT(DISTINCT agent_id) as agent_ids,
        GROUP_CONCAT(DISTINCT agent_role) as agent_roles
      FROM file_events
      WHERE timestamp >= ?
        AND event_type IN ('file_write', 'file_edit')
      GROUP BY file_path
      HAVING agent_count > 1
    `);

    const results = collisionQuery.all(windowStart);

    for (const row of results as any[]) {
      // Get detailed events for this file
      const detailQuery = this.db.prepare(`
        SELECT agent_id, agent_role, timestamp, event_type
        FROM file_events
        WHERE file_path = ?
          AND timestamp >= ?
          AND event_type IN ('file_write', 'file_edit')
        ORDER BY timestamp ASC
      `);

      const events = detailQuery.all(row.file_path, windowStart) as any[];

      const collision: CollisionEvent = {
        id: `collision_${row.file_path}_${Date.now()}`,
        filePath: row.file_path,
        agents: events.map(e => ({
          agentId: e.agent_id,
          agentRole: e.agent_role,
          timestamp: new Date(e.timestamp).getTime(),
          eventType: e.event_type,
        })),
        detectedAt: Date.now(),
        windowMs: this.COLLISION_WINDOW_MS,
      };

      this.onCollision?.(collision);
    }

    this.lastCheckedTimestamp = Date.now();
  }

  /**
   * Query recent edits to a specific file.
   * Used by the pre-write validation hook to check for pending collisions.
   */
  queryRecentEdits(filePath: string, windowMs?: number): CollisionParticipant[] {
    const window = windowMs ?? this.COLLISION_WINDOW_MS;
    const windowStart = new Date(Date.now() - window).toISOString();

    const query = this.db.prepare(`
      SELECT agent_id, agent_role, timestamp, event_type
      FROM file_events
      WHERE file_path = ?
        AND timestamp >= ?
        AND event_type IN ('file_write', 'file_edit')
      ORDER BY timestamp DESC
    `);

    const results = query.all(filePath, windowStart) as any[];

    return results.map(r => ({
      agentId: r.agent_id,
      agentRole: r.agent_role,
      timestamp: new Date(r.timestamp).getTime(),
      eventType: r.event_type,
    }));
  }

  dispose(): void {
    this.stopPolling();
    this.db.close();
  }
}
```

### 3.4 hcom Shell Hook Integration

Each agent subprocess gets a shell hook that records file writes to the hcom event store. This runs alongside (not instead of) the pre-write validation.

```bash
#!/usr/bin/env bash
# hooks/hcom-file-hook.sh
# Sourced in each agent's shell environment.
# Intercepts file write operations and records them to hcom event store.

# Environment variables set by orchestrator:
# HCOM_DB_PATH, HCOM_AGENT_ID, HCOM_AGENT_ROLE, HCOM_BUILD_ID

_hcom_record_file_event() {
  local event_type="$1"
  local file_path="$2"

  if [ -z "$HCOM_DB_PATH" ] || [ -z "$HCOM_AGENT_ID" ]; then
    return 0
  fi

  sqlite3 "$HCOM_DB_PATH" \
    "INSERT INTO file_events (agent_id, agent_role, event_type, file_path, build_id) \
     VALUES ('$HCOM_AGENT_ID', '$HCOM_AGENT_ROLE', '$event_type', '$file_path', '$HCOM_BUILD_ID');" \
    2>/dev/null &
}

# Note: This is a best-effort hook. The pre-write validation layer
# is the authoritative enforcement mechanism.
```

### 3.5 Dashboard Collision Alert

When the collision detector fires, the dashboard receives the event via the existing SSE pipeline and renders it as both a toast notification and a highlight in the file tree.

```typescript
// services/collision-handler.ts
import { useOrchestratorStore } from '../stores/orchestrator-store';
import { toast } from 'sonner';

export function handleCollisionEvent(collision: CollisionEvent): void {
  // 1. Show toast notification
  const agentNames = collision.agents
    .map(a => a.agentRole.replace('-agent', ''))
    .join(' and ');

  toast.warning(`File collision detected`, {
    description: `${agentNames} both modified ${collision.filePath} within ${collision.windowMs / 1000}s`,
    duration: 10_000,
    action: {
      label: 'View',
      onClick: () => {
        useOrchestratorStore.getState().openFileInDiffViewer(
          collision.agents[0].agentId,
          collision.filePath,
        );
      },
    },
  });

  // 2. Update file tree to show collision indicator
  useOrchestratorStore.getState().markFileCollision(
    collision.filePath,
    collision.agents.map(a => a.agentId),
  );

  // 3. Log to Langfuse as an event
  getLangfuse().event({
    traceId: getCurrentBuildTraceId(),
    name: 'file_collision_detected',
    metadata: {
      filePath: collision.filePath,
      agents: collision.agents,
      detectedAt: collision.detectedAt,
    },
    level: 'WARNING',
  });

  // 4. Record in audit trail
  recordAuditEvent({
    action: 'collision_detected',
    resourceType: 'file',
    resourceId: collision.filePath,
    metadata: collision,
  });
}
```

---

## 4. File Ownership Enforcement

### 4.1 Ownership Map

The ownership map defines which agent role owns which directories and file patterns. It is loaded from the orchestrator's contract definitions and reflects the exclusive ownership model from the skill ecosystem design spec.

```typescript
// coordination/ownership-map.ts

export interface OwnershipRule {
  pattern: string;          // Glob pattern or directory path
  ownerRole: string;        // Agent role that owns this path
  exclusive: boolean;       // Whether other agents are blocked (always true for now)
}

export interface OwnershipMap {
  rules: OwnershipRule[];
  buildId: string;
  generatedAt: number;
}

/**
 * Default ownership map for the 9 agent roles.
 * Loaded from contract definitions at build start.
 * Can be overridden per-project via ownership.yaml.
 */
const DEFAULT_OWNERSHIP_RULES: OwnershipRule[] = [
  // Backend agent
  { pattern: 'src/api/**',           ownerRole: 'backend-agent',        exclusive: true },
  { pattern: 'src/routes/**',        ownerRole: 'backend-agent',        exclusive: true },
  { pattern: 'src/middleware/**',    ownerRole: 'backend-agent',        exclusive: true },
  { pattern: 'src/services/**',     ownerRole: 'backend-agent',        exclusive: true },
  { pattern: 'src/controllers/**',  ownerRole: 'backend-agent',        exclusive: true },

  // Frontend agent
  { pattern: 'src/components/**',   ownerRole: 'frontend-agent',       exclusive: true },
  { pattern: 'src/pages/**',        ownerRole: 'frontend-agent',       exclusive: true },
  { pattern: 'src/hooks/**',        ownerRole: 'frontend-agent',       exclusive: true },
  { pattern: 'src/styles/**',       ownerRole: 'frontend-agent',       exclusive: true },
  { pattern: 'src/views/**',        ownerRole: 'frontend-agent',       exclusive: true },

  // Infrastructure agent
  { pattern: 'infra/**',            ownerRole: 'infrastructure-agent', exclusive: true },
  { pattern: 'terraform/**',        ownerRole: 'infrastructure-agent', exclusive: true },
  { pattern: 'docker/**',           ownerRole: 'infrastructure-agent', exclusive: true },
  { pattern: 'Dockerfile*',         ownerRole: 'infrastructure-agent', exclusive: true },
  { pattern: '.github/**',          ownerRole: 'infrastructure-agent', exclusive: true },
  { pattern: 'docker-compose*.yml', ownerRole: 'infrastructure-agent', exclusive: true },

  // QE agent
  { pattern: 'tests/**',            ownerRole: 'qe-agent',             exclusive: true },
  { pattern: '__tests__/**',        ownerRole: 'qe-agent',             exclusive: true },
  { pattern: 'e2e/**',              ownerRole: 'qe-agent',             exclusive: true },
  { pattern: 'cypress/**',          ownerRole: 'qe-agent',             exclusive: true },
  { pattern: 'playwright/**',       ownerRole: 'qe-agent',             exclusive: true },

  // Security agent
  { pattern: 'src/auth/**',         ownerRole: 'security-agent',       exclusive: true },
  { pattern: 'src/security/**',     ownerRole: 'security-agent',       exclusive: true },
  { pattern: '.env.example',        ownerRole: 'security-agent',       exclusive: true },

  // Docs agent
  { pattern: 'docs/**',             ownerRole: 'docs-agent',           exclusive: true },
  { pattern: 'README.md',           ownerRole: 'docs-agent',           exclusive: true },
  { pattern: 'CHANGELOG.md',        ownerRole: 'docs-agent',           exclusive: true },
  { pattern: 'API.md',              ownerRole: 'docs-agent',           exclusive: true },

  // Observability agent
  { pattern: 'src/monitoring/**',   ownerRole: 'observability-agent',  exclusive: true },
  { pattern: 'src/logging/**',      ownerRole: 'observability-agent',  exclusive: true },
  { pattern: 'src/metrics/**',      ownerRole: 'observability-agent',  exclusive: true },
  { pattern: 'otel-*',              ownerRole: 'observability-agent',  exclusive: true },
  { pattern: 'grafana/**',          ownerRole: 'observability-agent',  exclusive: true },

  // DB migration agent
  { pattern: 'migrations/**',       ownerRole: 'db-migration-agent',   exclusive: true },
  { pattern: 'prisma/**',           ownerRole: 'db-migration-agent',   exclusive: true },
  { pattern: 'src/models/**',       ownerRole: 'db-migration-agent',   exclusive: true },
  { pattern: 'src/schemas/**',      ownerRole: 'db-migration-agent',   exclusive: true },
  { pattern: 'drizzle/**',          ownerRole: 'db-migration-agent',   exclusive: true },

  // Performance agent
  { pattern: 'benchmarks/**',       ownerRole: 'performance-agent',    exclusive: true },
  { pattern: 'loadtest/**',         ownerRole: 'performance-agent',    exclusive: true },
  { pattern: 'k6/**',               ownerRole: 'performance-agent',    exclusive: true },
];

/**
 * Shared config files: no single agent owns these.
 * Changes require orchestrator approval.
 */
const SHARED_FILES = [
  'package.json',
  'tsconfig.json',
  'package-lock.json',
  'yarn.lock',
  'pnpm-lock.yaml',
];
```

### 4.2 Ownership Resolver

```typescript
// coordination/ownership-resolver.ts
import { minimatch } from 'minimatch';

export class OwnershipResolver {
  private rules: OwnershipRule[];
  private sharedFiles: Set<string>;

  constructor(rules: OwnershipRule[], sharedFiles: string[] = []) {
    // Sort rules by specificity (longer patterns first)
    this.rules = [...rules].sort((a, b) => b.pattern.length - a.pattern.length);
    this.sharedFiles = new Set(sharedFiles);
  }

  /**
   * Determine which agent role owns a given file path.
   * Returns null if no rule matches (unowned file).
   */
  getOwner(filePath: string): string | null {
    // Check shared files first
    if (this.sharedFiles.has(filePath)) {
      return null; // Shared files have no single owner
    }

    // Match against rules (most specific first)
    for (const rule of this.rules) {
      if (minimatch(filePath, rule.pattern, { dot: true })) {
        return rule.ownerRole;
      }
    }

    return null; // Unowned
  }

  /**
   * Check if an agent is allowed to write to a file.
   * Returns a validation result with details.
   */
  validateWrite(filePath: string, agentRole: string): WriteValidationResult {
    // Shared files require orchestrator approval
    if (this.sharedFiles.has(filePath)) {
      return {
        allowed: false,
        reason: 'shared_file',
        filePath,
        agentRole,
        ownerRole: null,
        message: `${filePath} is a shared file. Changes require orchestrator approval.`,
      };
    }

    const owner = this.getOwner(filePath);

    // Unowned files: allow (they might be new directories)
    if (owner === null) {
      return {
        allowed: true,
        reason: 'unowned',
        filePath,
        agentRole,
        ownerRole: null,
        message: `${filePath} has no ownership rule. Write allowed.`,
      };
    }

    // Matching owner: allow
    if (owner === agentRole) {
      return {
        allowed: true,
        reason: 'owner',
        filePath,
        agentRole,
        ownerRole: owner,
        message: `${agentRole} owns ${filePath}. Write allowed.`,
      };
    }

    // Non-matching owner: block
    return {
      allowed: false,
      reason: 'ownership_violation',
      filePath,
      agentRole,
      ownerRole: owner,
      message: `${agentRole} attempted to write ${filePath}, which is owned by ${owner}.`,
    };
  }
}

export interface WriteValidationResult {
  allowed: boolean;
  reason: 'owner' | 'unowned' | 'shared_file' | 'ownership_violation';
  filePath: string;
  agentRole: string;
  ownerRole: string | null;
  message: string;
}
```

### 4.3 Pre-Write Validation Hook

This middleware intercepts file write operations before they reach the filesystem. It runs in the orchestrator's process, wrapping the agent's tool execution.

```typescript
// coordination/pre-write-validator.ts
import { OwnershipResolver, WriteValidationResult } from './ownership-resolver';
import { CollisionDetector } from './collision-detector';
import { getLangfuse } from '../observability/langfuse-client';

export class PreWriteValidator {
  private resolver: OwnershipResolver;
  private collisionDetector: CollisionDetector;
  private violations: OwnershipViolation[] = [];

  constructor(
    resolver: OwnershipResolver,
    collisionDetector: CollisionDetector,
  ) {
    this.resolver = resolver;
    this.collisionDetector = collisionDetector;
  }

  /**
   * Validate a file write operation before it runs.
   *
   * Returns a validation result. If not allowed, the caller must
   * block the write and report the violation.
   *
   * Checks two things in sequence:
   * 1. Ownership: does this agent have the right to write this file?
   * 2. Collision: has another agent recently written to this file?
   */
  async validate(
    filePath: string,
    agentId: string,
    agentRole: string,
    buildId: string,
  ): Promise<PreWriteValidationResult> {
    // Step 1: Ownership check
    const ownershipResult = this.resolver.validateWrite(filePath, agentRole);

    if (!ownershipResult.allowed) {
      const violation: OwnershipViolation = {
        id: `violation_${Date.now()}_${filePath}`,
        type: ownershipResult.reason as 'ownership_violation' | 'shared_file',
        filePath,
        agentId,
        agentRole,
        ownerRole: ownershipResult.ownerRole,
        message: ownershipResult.message,
        timestamp: Date.now(),
        buildId,
      };

      this.violations.push(violation);

      // Log to Langfuse
      getLangfuse().event({
        traceId: `build_${buildId}`,
        name: 'ownership_violation',
        level: 'ERROR',
        metadata: violation,
      });

      return {
        allowed: false,
        reason: 'ownership_violation',
        violation,
      };
    }

    // Step 2: Collision check (even if ownership passes)
    const recentEdits = this.collisionDetector.queryRecentEdits(filePath);
    const otherAgentEdits = recentEdits.filter(e => e.agentId !== agentId);

    if (otherAgentEdits.length > 0) {
      // Collision detected -- warn but allow (ownership already validated)
      return {
        allowed: true,
        reason: 'collision_warning',
        collisionWarning: {
          filePath,
          otherAgents: otherAgentEdits,
          message: `Warning: ${otherAgentEdits[0].agentRole} edited ${filePath} ${Math.round((Date.now() - otherAgentEdits[0].timestamp) / 1000)}s ago.`,
        },
      };
    }

    return {
      allowed: true,
      reason: 'clean',
    };
  }

  getViolations(): OwnershipViolation[] {
    return [...this.violations];
  }
}

export interface OwnershipViolation {
  id: string;
  type: 'ownership_violation' | 'shared_file';
  filePath: string;
  agentId: string;
  agentRole: string;
  ownerRole: string | null;
  message: string;
  timestamp: number;
  buildId: string;
}

export interface PreWriteValidationResult {
  allowed: boolean;
  reason: 'clean' | 'ownership_violation' | 'collision_warning';
  violation?: OwnershipViolation;
  collisionWarning?: {
    filePath: string;
    otherAgents: CollisionParticipant[];
    message: string;
  };
}
```

### 4.4 Integration with Agent Tool Execution

The pre-write validator wraps the agent's `file_write` and `file_edit` tool calls at the orchestrator level. This happens before the tool output reaches the filesystem.

```typescript
// orchestrator/tool-interceptor.ts

/**
 * Wraps agent tool calls with pre-write validation.
 * Called by the process manager when it detects a tool_call event
 * from the agent subprocess.
 */
export class ToolInterceptor {
  constructor(
    private preWriteValidator: PreWriteValidator,
    private eventBus: EventBus,
  ) {}

  async interceptToolCall(
    agentId: string,
    agentRole: string,
    buildId: string,
    toolCall: ToolCallEvent,
  ): Promise<ToolCallInterceptResult> {
    // Only intercept file write operations
    if (!isFileWriteTool(toolCall.toolName)) {
      return { action: 'allow' };
    }

    const filePath = extractFilePath(toolCall);
    if (!filePath) {
      return { action: 'allow' };
    }

    const validation = await this.preWriteValidator.validate(
      filePath,
      agentId,
      agentRole,
      buildId,
    );

    if (!validation.allowed) {
      // Block the write
      this.eventBus.emit({
        type: 'OWNERSHIP_VIOLATION',
        agentId,
        agentRole,
        filePath,
        violation: validation.violation!,
      });

      return {
        action: 'block',
        reason: validation.violation!.message,
        violation: validation.violation,
      };
    }

    if (validation.collisionWarning) {
      // Allow but emit warning
      this.eventBus.emit({
        type: 'COLLISION_WARNING',
        agentId,
        agentRole,
        filePath,
        warning: validation.collisionWarning,
      });
    }

    return { action: 'allow' };
  }
}

function isFileWriteTool(toolName: string): boolean {
  return ['file_write', 'file_edit', 'Write', 'Edit', 'write_file', 'edit_file']
    .includes(toolName);
}

function extractFilePath(toolCall: ToolCallEvent): string | null {
  // Different agent frameworks name the parameter differently
  return toolCall.args?.file_path
    ?? toolCall.args?.filePath
    ?? toolCall.args?.path
    ?? null;
}

interface ToolCallInterceptResult {
  action: 'allow' | 'block';
  reason?: string;
  violation?: OwnershipViolation;
}
```

### 4.5 Dashboard Visualization of Ownership Violations

Ownership violations surface in two places:

1. **contract-compliance block** -- Violations appear in the violation list with severity CRITICAL and category "ownership".
2. **file-tree block** -- Files with violations get a red conflict indicator.

```typescript
// services/violation-router.ts

function routeOwnershipViolation(violation: OwnershipViolation): void {
  // Route to contract-compliance block
  const contractViolation: ContractViolation = {
    id: violation.id,
    severity: 'CRITICAL',
    category: 'ownership',
    message: violation.message,
    filePath: violation.filePath,
    agentId: violation.agentId,
    agentRole: violation.agentRole,
    suggestion: `Move this file write to the ${violation.ownerRole} agent.`,
    autoFixable: false,
  };

  // Update contract-compliance atoms
  // ... (atom update via event routing)

  // Route to file-tree block
  useOrchestratorStore.getState().markFileCollision(
    violation.filePath,
    [violation.agentId],
  );

  // Toast notification
  toast.error('Ownership violation', {
    description: violation.message,
    duration: 15_000,
  });
}
```

---

## 5. OpenTelemetry Collector Configuration

### 5.1 Collector Config

The OpenTelemetry Collector receives traces from all agents via OTLP, batches them, and exports to Langfuse (primary) and optionally Jaeger (debug).

```yaml
# otel-collector-config.yaml

receivers:
  otlp:
    protocols:
      http:
        endpoint: "0.0.0.0:4318"
        cors:
          allowed_origins:
            - "http://localhost:*"
            - "tauri://localhost"

exporters:
  otlp/langfuse:
    endpoint: "${LANGFUSE_BASE_URL}/api/public/otel/v1/traces"
    headers:
      Authorization: "Basic ${LANGFUSE_AUTH}"  # base64(publicKey:secretKey)
    tls:
      insecure: false
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s

  otlp/jaeger:
    endpoint: "localhost:4317"
    tls:
      insecure: true  # Local development only

  logging:
    verbosity: basic  # For debugging: set to 'detailed' for full spans

processors:
  batch:
    timeout: 2s
    send_batch_size: 100
    send_batch_max_size: 200

  # Add build_id as a resource attribute to all spans
  resource:
    attributes:
      - key: service.name
        value: "agentic-ui-dashboard"
        action: upsert
      - key: deployment.environment
        from_attribute: ENVIRONMENT
        action: upsert

  # Filter out health check spans to reduce noise
  filter:
    spans:
      exclude:
        match_type: strict
        span_names:
          - "health_check"
          - "ping"

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [resource, filter, batch]
      exporters: [otlp/langfuse, otlp/jaeger, logging]

  telemetry:
    logs:
      level: info
    metrics:
      address: "0.0.0.0:8888"  # Collector self-metrics
```

### 5.2 Docker Setup

```yaml
# docker-compose.otel.yaml

services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml:ro
    ports:
      - "4318:4318"    # OTLP HTTP receiver
      - "8888:8888"    # Collector metrics
    environment:
      - LANGFUSE_BASE_URL=${LANGFUSE_BASE_URL:-https://cloud.langfuse.com}
      - LANGFUSE_AUTH=${LANGFUSE_AUTH}  # base64(publicKey:secretKey)
      - ENVIRONMENT=${ENVIRONMENT:-development}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8888/metrics"]
      interval: 30s
      timeout: 10s
      retries: 3

  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"   # Jaeger UI
      - "4317:4317"     # OTLP gRPC receiver
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    profiles:
      - debug           # Only started with --profile debug
```

### 5.3 OpenTelemetry GenAI Semantic Conventions

All spans follow the OpenTelemetry GenAI Semantic Conventions for consistent attribute naming across agents and tools.

```typescript
// observability/otel-conventions.ts

/**
 * OpenTelemetry GenAI Semantic Convention attribute names.
 * Reference: https://opentelemetry.io/docs/specs/semconv/gen-ai/
 */
export const GenAIAttributes = {
  // Agent operations
  AGENT_NAME: 'gen_ai.agent.name',
  AGENT_DESCRIPTION: 'gen_ai.agent.description',
  OPERATION_NAME: 'gen_ai.operation.name',

  // LLM requests
  REQUEST_MODEL: 'gen_ai.request.model',
  REQUEST_MAX_TOKENS: 'gen_ai.request.max_tokens',
  REQUEST_TEMPERATURE: 'gen_ai.request.temperature',

  // LLM responses
  RESPONSE_MODEL: 'gen_ai.response.model',
  RESPONSE_FINISH_REASON: 'gen_ai.response.finish_reasons',

  // Token usage
  USAGE_PROMPT_TOKENS: 'gen_ai.usage.prompt_tokens',
  USAGE_COMPLETION_TOKENS: 'gen_ai.usage.completion_tokens',
  USAGE_TOTAL_TOKENS: 'gen_ai.usage.total_tokens',

  // Tool calls
  TOOL_TYPE: 'gen_ai.tool.type',
  TOOL_NAME: 'gen_ai.tool.name',
  TOOL_CALL_ID: 'gen_ai.tool.call.id',

  // Custom: build-specific attributes
  BUILD_ID: 'build.id',
  BUILD_PHASE: 'build.phase',
  AGENT_ROLE: 'agent.role',
  FILE_PATH: 'file.path',
  FILE_OWNER: 'file.owner',
} as const;

/**
 * Operation names for span naming.
 */
export const GenAIOperations = {
  CREATE_AGENT: 'create_agent',
  INVOKE_AGENT: 'invoke_agent',
  EXECUTE_TOOL: 'execute_tool',
  CHAT: 'chat',
} as const;
```

---

## 6. Trace Visualization in Dashboard

### 6.1 Approach: Embedded Link + Summary

The initial implementation links to the external Langfuse UI for full trace exploration. A summary panel in the dashboard provides build-level metrics without requiring the user to leave the app.

```typescript
// types/trace-summary.ts

export interface BuildTraceSummary {
  buildId: string;
  traceId: string;
  langfuseUrl: string;             // Deep link to Langfuse trace view

  // Timing
  totalDurationMs: number;
  phasesDuration: PhaseDuration[];
  agentDurations: AgentDuration[];

  // Cost
  totalTokens: number;
  totalCost: number;                // USD, estimated from token counts
  agentTokenBreakdown: AgentTokens[];

  // Volume
  totalToolCalls: number;
  totalFileWrites: number;
  totalLLMCalls: number;
  ownershipViolations: number;
  collisionsDetected: number;
}

export interface PhaseDuration {
  phase: number;
  name: string;
  durationMs: number;
  agentCount: number;
}

export interface AgentDuration {
  agentId: string;
  agentRole: string;
  durationMs: number;
  status: 'completed' | 'failed' | 'running';
}

export interface AgentTokens {
  agentId: string;
  agentRole: string;
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
  estimatedCostUsd: number;
}
```

### 6.2 Cost Estimation

```typescript
// observability/cost-estimator.ts

/**
 * Estimate USD cost from token usage.
 * Prices are approximate and should be configured per-model.
 */
const MODEL_PRICING: Record<string, { promptPer1K: number; completionPer1K: number }> = {
  'claude-opus-4-20250514':      { promptPer1K: 0.015,  completionPer1K: 0.075  },
  'claude-sonnet-4-20250514':    { promptPer1K: 0.003,  completionPer1K: 0.015  },
  'claude-3-5-haiku-20241022':   { promptPer1K: 0.001,  completionPer1K: 0.005  },
  'gpt-4o':                      { promptPer1K: 0.005,  completionPer1K: 0.015  },
  'gpt-4o-mini':                 { promptPer1K: 0.00015, completionPer1K: 0.0006 },
};

export function estimateCost(
  model: string,
  promptTokens: number,
  completionTokens: number,
): number {
  const pricing = MODEL_PRICING[model];
  if (!pricing) {
    // Unknown model: use a conservative estimate
    return (promptTokens + completionTokens) * 0.01 / 1000;
  }

  return (
    (promptTokens / 1000) * pricing.promptPer1K +
    (completionTokens / 1000) * pricing.completionPer1K
  );
}

/**
 * Aggregate cost across all agents in a build.
 */
export function aggregateBuildCost(
  agentTokens: AgentTokens[],
): { totalTokens: number; totalCostUsd: number } {
  let totalTokens = 0;
  let totalCostUsd = 0;

  for (const agent of agentTokens) {
    totalTokens += agent.totalTokens;
    totalCostUsd += agent.estimatedCostUsd;
  }

  return { totalTokens, totalCostUsd };
}
```

### 6.3 Trace Summary Block Component

```tsx
// blocks/trace-summary/TraceSummaryBlock.tsx
import React from 'react';
import { useAtomValue } from 'jotai';
import {
  BarChart, Bar, XAxis, YAxis, Tooltip,
  ResponsiveContainer, Cell,
} from 'recharts';
import { AGENT_ROLE_COLORS } from '../../constants/agent-colors';

export const TraceSummaryBlock = React.memo(function TraceSummaryBlock({
  atoms,
  config,
}: {
  atoms: ReturnType<typeof createTraceSummaryAtoms>;
  config: BlockConfig;
}) {
  const summary = useAtomValue(atoms.summaryAtom);

  if (!summary) {
    return <div className="p-4 text-gray-500 text-sm">No build trace data available.</div>;
  }

  // Prepare chart data
  const durationData = summary.agentDurations.map(a => ({
    name: a.agentRole.replace('-agent', ''),
    duration: Math.round(a.durationMs / 1000),
    fill: getAgentChartColor(a.agentRole),
  }));

  const tokenData = summary.agentTokenBreakdown.map(a => ({
    name: a.agentRole.replace('-agent', ''),
    prompt: a.promptTokens,
    completion: a.completionTokens,
    cost: a.estimatedCostUsd,
  }));

  return (
    <div className="trace-summary-block flex flex-col h-full overflow-auto">
      {/* Header with totals */}
      <div className="grid grid-cols-4 gap-3 p-4 border-b bg-gray-50">
        <MetricCard label="Duration" value={formatDuration(summary.totalDurationMs)} />
        <MetricCard label="Total Tokens" value={formatNumber(summary.totalTokens)} />
        <MetricCard label="Est. Cost" value={`$${summary.totalCost.toFixed(2)}`} />
        <MetricCard label="Tool Calls" value={String(summary.totalToolCalls)} />
      </div>

      {/* Quick stats row */}
      <div className="grid grid-cols-4 gap-3 p-4 border-b">
        <MetricCard label="LLM Calls" value={String(summary.totalLLMCalls)} />
        <MetricCard label="File Writes" value={String(summary.totalFileWrites)} />
        <MetricCard
          label="Violations"
          value={String(summary.ownershipViolations)}
          alert={summary.ownershipViolations > 0}
        />
        <MetricCard
          label="Collisions"
          value={String(summary.collisionsDetected)}
          alert={summary.collisionsDetected > 0}
        />
      </div>

      {/* Agent duration chart */}
      <div className="p-4 border-b">
        <h3 className="text-sm font-semibold mb-2">Agent Duration (seconds)</h3>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={durationData}>
            <XAxis dataKey="name" tick={{ fontSize: 10 }} />
            <YAxis tick={{ fontSize: 10 }} />
            <Tooltip />
            <Bar dataKey="duration">
              {durationData.map((entry, i) => (
                <Cell key={i} fill={entry.fill} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Token usage breakdown */}
      <div className="p-4 border-b">
        <h3 className="text-sm font-semibold mb-2">Token Usage by Agent</h3>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={tokenData}>
            <XAxis dataKey="name" tick={{ fontSize: 10 }} />
            <YAxis tick={{ fontSize: 10 }} />
            <Tooltip />
            <Bar dataKey="prompt" stackId="tokens" fill="#93c5fd" name="Prompt" />
            <Bar dataKey="completion" stackId="tokens" fill="#3b82f6" name="Completion" />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Langfuse link */}
      <div className="p-4">
        <a
          href={summary.langfuseUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="text-sm text-blue-600 hover:underline"
        >
          View full trace in Langfuse
        </a>
      </div>
    </div>
  );
});

function MetricCard({
  label,
  value,
  alert = false,
}: {
  label: string;
  value: string;
  alert?: boolean;
}) {
  return (
    <div className={`text-center p-2 rounded ${alert ? 'bg-red-50' : ''}`}>
      <div className="text-xs text-gray-500">{label}</div>
      <div className={`text-lg font-bold ${alert ? 'text-red-600' : 'text-gray-900'}`}>
        {value}
      </div>
    </div>
  );
}

function formatDuration(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  if (ms < 60_000) return `${(ms / 1000).toFixed(1)}s`;
  const mins = Math.floor(ms / 60_000);
  const secs = Math.round((ms % 60_000) / 1000);
  return `${mins}m ${secs}s`;
}

function formatNumber(n: number): string {
  if (n < 1000) return String(n);
  if (n < 1_000_000) return `${(n / 1000).toFixed(1)}K`;
  return `${(n / 1_000_000).toFixed(1)}M`;
}
```

---

## 7. Data Flow Integration

### 7.1 End-to-End Data Flow

```
Orchestrator starts build
    |
    +-- createBuildTraceContext() --> Langfuse trace (root)
    |
    +-- For each phase:
    |     |
    |     +-- instrumentPhase() --> Langfuse span (phase)
    |     |
    |     +-- For each agent:
    |           |
    |           +-- spawn agent subprocess
    |           |     (pass LANGFUSE_* env vars + HCOM_* env vars)
    |           |
    |           +-- instrumentAgentExecution() --> Langfuse span (agent)
    |           |
    |           +-- Agent runs, producing tool calls:
    |                 |
    |                 +-- Tool call intercepted by ToolInterceptor
    |                 |     |
    |                 |     +-- PreWriteValidator.validate()
    |                 |     |     |
    |                 |     |     +-- OwnershipResolver.validateWrite()
    |                 |     |     |     |
    |                 |     |     |     +-- ALLOWED: proceed
    |                 |     |     |     +-- BLOCKED: emit OWNERSHIP_VIOLATION event
    |                 |     |     |
    |                 |     |     +-- CollisionDetector.queryRecentEdits()
    |                 |     |           |
    |                 |     |           +-- NO COLLISION: proceed
    |                 |     |           +-- COLLISION: emit COLLISION_WARNING event
    |                 |     |
    |                 |     +-- If allowed: tool runs, hcom records event
    |                 |
    |                 +-- recordToolCall() --> Langfuse span (tool)
    |                 +-- recordLLMCall() --> Langfuse generation (llm)
    |                 +-- recordFileWrite() --> Langfuse span (file_write)
    |
    +-- SSE pipeline sends events to dashboard
    |     |
    |     +-- OWNERSHIP_VIOLATION --> contract-compliance block + file-tree block + toast
    |     +-- COLLISION_WARNING --> file-tree block + toast
    |     +-- Trace data --> trace-summary block (aggregated)
    |
    +-- Build completes
          |
          +-- Flush Langfuse
          +-- Generate BuildTraceSummary
          +-- Store summary in SQLite
```

### 7.2 SSE Events for Observability

| Event Type | Payload | Destination |
|------------|---------|-------------|
| `RAW` (ownership_violation) | `OwnershipViolation` | contract-compliance, file-tree, toast |
| `RAW` (collision_warning) | `CollisionEvent` | file-tree, toast |
| `RAW` (trace_summary_update) | `Partial<BuildTraceSummary>` | trace-summary block |
| `STATE_DELTA` (agent_tokens) | `{ agentId, tokenUsage }` | trace-summary block |

---

## 8. Block Registration

```typescript
// blocks/registry-phase6.ts
import { BlockRegistry } from '../core/block-registry';
import { atom } from 'jotai';
import { TraceSummaryBlock } from './trace-summary/TraceSummaryBlock';

export function registerPhase6Blocks() {
  BlockRegistry.set('trace-summary', {
    type: 'trace-summary',
    displayName: 'Build Trace',
    icon: 'activity',
    createAtoms: createTraceSummaryAtoms,
    Component: TraceSummaryBlock,
  });
}

function createTraceSummaryAtoms() {
  return {
    summaryAtom: atom<BuildTraceSummary | null>(null),
    isLoadingAtom: atom<boolean>(false),
  };
}
```

---

## 9. Configuration

### 9.1 Environment Variables

```bash
# .env.observability

# Langfuse connection
LANGFUSE_PUBLIC_KEY=pk-lf-xxxxxxxx
LANGFUSE_SECRET_KEY=sk-lf-xxxxxxxx
LANGFUSE_BASE_URL=https://cloud.langfuse.com
# For self-hosted: LANGFUSE_BASE_URL=http://localhost:3000

# hcom configuration
HCOM_DB_PATH=/tmp/hcom/events.db
HCOM_COLLISION_WINDOW_MS=30000
HCOM_POLL_INTERVAL_MS=5000

# OpenTelemetry Collector
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_SERVICE_NAME=agentic-ui-dashboard
```

### 9.2 Ownership Configuration File

Projects can override the default ownership map:

```yaml
# ownership.yaml (project root)

# Override default rules
rules:
  - pattern: "src/api/**"
    owner: backend-agent
  - pattern: "src/components/**"
    owner: frontend-agent
  # ... custom rules

# Files that multiple agents can modify (requires orchestrator approval)
shared:
  - package.json
  - tsconfig.json
  - .gitignore

# Files that no agent should touch
forbidden:
  - .env
  - credentials.json
  - "*.key"
  - "*.pem"
```

---

## 10. Testing Strategy

### 10.1 Unit Tests

```typescript
// __tests__/ownership-resolver.test.ts
describe('OwnershipResolver', () => {
  const resolver = new OwnershipResolver(DEFAULT_OWNERSHIP_RULES, SHARED_FILES);

  it('resolves ownership for known paths', () => {
    expect(resolver.getOwner('src/api/users.ts')).toBe('backend-agent');
    expect(resolver.getOwner('src/components/Button.tsx')).toBe('frontend-agent');
    expect(resolver.getOwner('tests/api.test.ts')).toBe('qe-agent');
    expect(resolver.getOwner('migrations/001_init.sql')).toBe('db-migration-agent');
  });

  it('returns null for unowned paths', () => {
    expect(resolver.getOwner('random/unknown/path.txt')).toBeNull();
  });

  it('returns null for shared files', () => {
    expect(resolver.getOwner('package.json')).toBeNull();
  });

  it('validates writes correctly', () => {
    const result = resolver.validateWrite('src/api/users.ts', 'backend-agent');
    expect(result.allowed).toBe(true);
    expect(result.reason).toBe('owner');

    const violation = resolver.validateWrite('src/api/users.ts', 'frontend-agent');
    expect(violation.allowed).toBe(false);
    expect(violation.reason).toBe('ownership_violation');
    expect(violation.ownerRole).toBe('backend-agent');
  });

  it('blocks shared file writes', () => {
    const result = resolver.validateWrite('package.json', 'backend-agent');
    expect(result.allowed).toBe(false);
    expect(result.reason).toBe('shared_file');
  });

  it('allows writes to unowned paths', () => {
    const result = resolver.validateWrite('new-dir/new-file.ts', 'backend-agent');
    expect(result.allowed).toBe(true);
    expect(result.reason).toBe('unowned');
  });

  it('matches most specific rule first', () => {
    // If both "src/**" and "src/api/**" exist, the more specific wins
    const owner = resolver.getOwner('src/api/deep/nested/file.ts');
    expect(owner).toBe('backend-agent');
  });
});

// __tests__/collision-detector.test.ts
describe('CollisionDetector', () => {
  let detector: CollisionDetector;
  let db: Database.Database;

  beforeEach(() => {
    db = new Database(':memory:');
    db.exec(`
      CREATE TABLE file_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        agent_id TEXT NOT NULL,
        agent_role TEXT NOT NULL,
        event_type TEXT NOT NULL,
        file_path TEXT NOT NULL,
        build_id TEXT,
        metadata TEXT
      );
    `);
    // Inject the in-memory db into detector
    detector = new CollisionDetector(':memory:');
  });

  it('detects collisions when two agents edit same file within window', () => {
    // Insert two edits from different agents within 30s
    db.prepare(`
      INSERT INTO file_events (agent_id, agent_role, event_type, file_path, timestamp)
      VALUES (?, ?, 'file_write', ?, datetime('now', '-10 seconds'))
    `).run('agent-1', 'backend-agent', 'src/shared.ts');

    db.prepare(`
      INSERT INTO file_events (agent_id, agent_role, event_type, file_path, timestamp)
      VALUES (?, ?, 'file_write', ?, datetime('now', '-5 seconds'))
    `).run('agent-2', 'frontend-agent', 'src/shared.ts');

    const collisions: CollisionEvent[] = [];
    detector.startPolling(c => collisions.push(c));

    // After poll interval fires...
    expect(collisions).toHaveLength(1);
    expect(collisions[0].filePath).toBe('src/shared.ts');
    expect(collisions[0].agents).toHaveLength(2);
  });

  it('does not detect collision for same agent editing same file', () => {
    db.prepare(`
      INSERT INTO file_events (agent_id, agent_role, event_type, file_path, timestamp)
      VALUES (?, ?, 'file_write', ?, datetime('now', '-10 seconds'))
    `).run('agent-1', 'backend-agent', 'src/api.ts');

    db.prepare(`
      INSERT INTO file_events (agent_id, agent_role, event_type, file_path, timestamp)
      VALUES (?, ?, 'file_write', ?, datetime('now', '-5 seconds'))
    `).run('agent-1', 'backend-agent', 'src/api.ts');

    const edits = detector.queryRecentEdits('src/api.ts');
    const uniqueAgents = new Set(edits.map(e => e.agentId));
    expect(uniqueAgents.size).toBe(1); // Same agent, no collision
  });
});

// __tests__/pre-write-validator.test.ts
describe('PreWriteValidator', () => {
  it('blocks writes to files owned by another agent', async () => {
    const mockDetector = { queryRecentEdits: () => [] } as any;
    const validator = new PreWriteValidator(
      new OwnershipResolver(DEFAULT_OWNERSHIP_RULES, SHARED_FILES),
      mockDetector,
    );

    const result = await validator.validate(
      'src/components/Button.tsx',
      'backend-agent-1',
      'backend-agent',
      'build-123',
    );

    expect(result.allowed).toBe(false);
    expect(result.reason).toBe('ownership_violation');
    expect(result.violation?.ownerRole).toBe('frontend-agent');
  });

  it('allows writes to owned files', async () => {
    const mockDetector = { queryRecentEdits: () => [] } as any;
    const validator = new PreWriteValidator(
      new OwnershipResolver(DEFAULT_OWNERSHIP_RULES, SHARED_FILES),
      mockDetector,
    );

    const result = await validator.validate(
      'src/api/users.ts',
      'backend-agent-1',
      'backend-agent',
      'build-123',
    );

    expect(result.allowed).toBe(true);
    expect(result.reason).toBe('clean');
  });

  it('warns on collision even when ownership passes', async () => {
    const mockDetector = {
      queryRecentEdits: () => [{
        agentId: 'other-backend-agent',
        agentRole: 'backend-agent',
        timestamp: Date.now() - 5000,
        eventType: 'file_write',
      }],
    } as any;

    const validator = new PreWriteValidator(
      new OwnershipResolver(DEFAULT_OWNERSHIP_RULES, SHARED_FILES),
      mockDetector,
    );

    const result = await validator.validate(
      'src/api/users.ts',
      'backend-agent-1',
      'backend-agent',
      'build-123',
    );

    expect(result.allowed).toBe(true);
    expect(result.reason).toBe('collision_warning');
    expect(result.collisionWarning).toBeDefined();
  });
});

// __tests__/instrumentor.test.ts
describe('AgentInstrumentor', () => {
  it('records LLM calls with correct attributes', () => {
    const mockLangfuse = createMockLangfuse();
    const mockSpan = { id: 'span-1' };
    const instrumentor = new AgentInstrumentor(
      mockLangfuse, 'trace-1', mockSpan, 'agent-1', 'backend-agent'
    );

    instrumentor.recordLLMCall({
      model: 'claude-opus-4-20250514',
      promptTokens: 1000,
      completionTokens: 500,
      durationMs: 3000,
      input: 'Write a function...',
      output: 'function add(a, b) { return a + b; }',
    });

    expect(mockLangfuse.generation).toHaveBeenCalledWith(
      expect.objectContaining({
        traceId: 'trace-1',
        model: 'claude-opus-4-20250514',
        usage: { promptTokens: 1000, completionTokens: 500, totalTokens: 1500 },
      })
    );
  });

  it('aggregates token usage across multiple LLM calls', () => {
    const mockLangfuse = createMockLangfuse();
    const mockSpan = { id: 'span-1', end: jest.fn() };
    const instrumentor = new AgentInstrumentor(
      mockLangfuse, 'trace-1', mockSpan, 'agent-1', 'backend-agent'
    );

    instrumentor.recordLLMCall({
      model: 'm', promptTokens: 100, completionTokens: 50,
      durationMs: 1, input: '', output: '',
    });
    instrumentor.recordLLMCall({
      model: 'm', promptTokens: 200, completionTokens: 100,
      durationMs: 1, input: '', output: '',
    });

    instrumentor.finalize({ exitCode: 0 });

    // Verify the finalize span includes aggregated totals
    expect(mockSpan.end).toHaveBeenCalledWith(
      expect.objectContaining({
        output: expect.objectContaining({
          tokenUsage: { prompt: 300, completion: 150, total: 450 },
        }),
      })
    );
  });
});
```

### 10.2 Integration Tests

```typescript
// __tests__/integration/observability-pipeline.test.ts
describe('Observability Pipeline', () => {
  it('creates hierarchical trace: build -> phase -> agent -> tool', async () => {
    const mockLangfuse = createMockLangfuse();
    initLangfuse(testConfig);

    // Simulate a mini-build
    const ctx = createBuildTraceContext('build-1', 'plan-1');
    const phaseInstr = instrumentPhase(ctx.traceId, 5, 'Implementation', ['backend-agent']);
    const agentInstr = phaseInstr.instrumentAgent('be-1', 'backend-agent', '/tmp/worktree');

    agentInstr.recordLLMCall({
      model: 'claude-opus-4-20250514',
      promptTokens: 500,
      completionTokens: 200,
      durationMs: 2000,
      input: 'test prompt',
      output: 'test response',
    });

    agentInstr.recordToolCall({
      toolName: 'file_write',
      input: { file_path: 'src/api/users.ts' },
      output: { success: true },
      durationMs: 50,
      success: true,
    });

    agentInstr.finalize({ exitCode: 0 });
    phaseInstr.finalize({ success: true });

    // Verify trace hierarchy
    expect(mockLangfuse.trace).toHaveBeenCalledWith(
      expect.objectContaining({ id: 'build_build-1', sessionId: 'build-1' })
    );
    expect(mockLangfuse.span).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'Phase 5: Implementation' })
    );
    expect(mockLangfuse.span).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'backend-agent_execution' })
    );
    expect(mockLangfuse.generation).toHaveBeenCalledWith(
      expect.objectContaining({ name: 'llm_call', model: 'claude-opus-4-20250514' })
    );
  });
});

// __tests__/integration/ownership-enforcement-e2e.test.ts
describe('Ownership Enforcement E2E', () => {
  it('blocks unauthorized write and surfaces violation in dashboard', async () => {
    const resolver = new OwnershipResolver(DEFAULT_OWNERSHIP_RULES, SHARED_FILES);
    const detector = new CollisionDetector(testDbPath);
    const validator = new PreWriteValidator(resolver, detector);
    const eventBus = new MockEventBus();
    const interceptor = new ToolInterceptor(validator, eventBus);

    // Simulate frontend-agent trying to write backend file
    const result = await interceptor.interceptToolCall(
      'frontend-1',
      'frontend-agent',
      'build-1',
      {
        toolName: 'file_write',
        args: { file_path: 'src/api/users.ts', content: '...' },
      },
    );

    expect(result.action).toBe('block');
    expect(result.violation?.ownerRole).toBe('backend-agent');

    // Verify event was emitted
    expect(eventBus.lastEvent.type).toBe('OWNERSHIP_VIOLATION');
  });
});
```

### 10.3 E2E Tests

```typescript
// e2e/observability.spec.ts
test.describe('Observability', () => {
  test('trace summary shows after build completes', async ({ page }) => {
    await page.goto('/dashboard');

    // Start a mock build
    await page.click('[data-testid="start-build"]');

    // Wait for build to complete (mock: fast)
    await page.waitForSelector('[data-build-status="completed"]', { timeout: 30_000 });

    // Open trace summary block
    await page.click('[data-testid="add-block"]');
    await page.click('[data-block-type="trace-summary"]');

    // Verify summary content
    await expect(page.locator('.trace-summary-block')).toContainText('Duration');
    await expect(page.locator('.trace-summary-block')).toContainText('Total Tokens');
    await expect(page.locator('.trace-summary-block')).toContainText('Est. Cost');
    await expect(page.locator('.trace-summary-block a')).toHaveAttribute('href', /langfuse/);
  });

  test('ownership violation shows toast and updates compliance block', async ({ page }) => {
    await page.goto('/dashboard?layout=review');

    // Inject an ownership violation event via mock SSE
    await injectSSEEvent(page, {
      type: 'RAW',
      payload: {
        type: 'ownership_violation',
        filePath: 'src/api/users.ts',
        agentId: 'frontend-1',
        agentRole: 'frontend-agent',
        ownerRole: 'backend-agent',
        message: 'frontend-agent attempted to write src/api/users.ts, owned by backend-agent',
      },
    });

    // Verify toast appears
    await expect(page.locator('[data-sonner-toast]')).toContainText('Ownership violation');

    // Verify contract-compliance block shows the violation
    await expect(page.locator('[data-block="contract-compliance"]'))
      .toContainText('CRITICAL');
    await expect(page.locator('[data-block="contract-compliance"]'))
      .toContainText('frontend-agent attempted to write');
  });
});
```

---

## 11. Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|-------------|
| AC-1 | All agent executions appear in Langfuse as hierarchical traces under shared trace_id | Integration test: verify trace/span hierarchy |
| AC-2 | Build appears as a single session in Langfuse with all agents as child traces | Integration test: verify sessionId on all spans |
| AC-3 | LLM calls record model, token usage, and timing | Unit test: verify generation span attributes |
| AC-4 | Tool calls record name, input, output, and success/failure | Unit test: verify tool span attributes |
| AC-5 | hcom detects file edit collisions within 30 seconds | Integration test: two agents edit same file, verify collision event |
| AC-6 | Pre-write validation blocks unauthorized file writes | Unit test: frontend-agent write to backend path returns `{ allowed: false }` |
| AC-7 | Ownership violations appear in dashboard with full details | E2E test: inject violation event, verify toast + compliance block |
| AC-8 | Collision warnings appear as toast notifications + file tree highlights | E2E test: inject collision event, verify UI update |
| AC-9 | OpenTelemetry Collector routes traces to Langfuse | Docker integration test: send OTLP trace, verify in Langfuse |
| AC-10 | Build-level cost/token summary available in trace-summary block | E2E test: complete build, verify summary renders |
| AC-11 | Token usage aggregated per agent and per build | Unit test: verify aggregation math |
| AC-12 | Langfuse deep link opens correct trace in external browser | E2E test: verify link URL structure |
| AC-13 | Shared files (package.json) are blocked with "shared_file" reason | Unit test: verify shared file validation |
| AC-14 | Unowned files are allowed for any agent | Unit test: verify unowned path returns `{ allowed: true }` |
| AC-15 | Ownership map can be overridden per-project via ownership.yaml | Unit test: load custom config, verify rule override |
| AC-16 | Langfuse SDK adds <1ms overhead per span (async batching) | Benchmark: measure span creation latency |
| AC-17 | Collision detector polls at configurable interval (default 5s) | Unit test: verify poll interval configuration |
| AC-18 | Violations and collisions are recorded in audit trail | Integration test: verify audit_log table entries |

---

## 12. Risk Considerations

| Risk | Severity | Probability | Mitigation |
|------|----------|------------|------------|
| Langfuse Cloud free tier limits exceeded during development | Low | Medium | Self-host Langfuse locally for dev. Cloud for production. |
| Langfuse self-hosting requires 16 CPU, 40GB+ RAM for HA | Medium | Low | Start with single-node non-HA. Scale up when needed. |
| hcom SQLite event store grows unbounded | Medium | Medium | Prune events older than 24 hours. Archive to main build database. |
| hcom polling misses collisions between poll intervals | Low | Medium | 5s poll interval covers most cases. Pre-write validation is primary defense. |
| Ownership map rules conflict or overlap | Medium | Medium | Rule specificity sort (longest pattern wins). Validation at load time. |
| OpenTelemetry Collector adds latency to trace pipeline | Low | Low | Batch processor with 2s timeout. Async export. |
| Token cost estimates drift from actual pricing | Low | High | Make pricing configurable via JSON. Document as estimates. |
| Multiple agents writing to unowned paths creates implicit conflicts | Medium | Medium | Log warnings for unowned path writes. Suggest adding ownership rules. |
| Langfuse SDK buffer overflow under high event volume | Low | Low | Configure `flushAt: 50` and `flushInterval: 2000`. Monitor queue size. |

---

## 13. Dependencies

### NPM Packages (New in Phase 6)

| Package | Version | Purpose | Size |
|---------|---------|---------|------|
| `langfuse` | latest | Langfuse TypeScript SDK | ~50KB |
| `better-sqlite3` | latest | SQLite client for hcom event queries | ~2MB (native addon) |
| `minimatch` | latest | Glob pattern matching for ownership rules | ~10KB |
| `recharts` | latest | Charts for trace summary block | ~300KB (may already be included from Phase 2) |

### Docker Images (Development)

| Image | Purpose |
|-------|---------|
| `otel/opentelemetry-collector-contrib` | OTLP trace collection and routing |
| `jaegertracing/all-in-one` | Debug trace visualization (optional, --profile debug) |

### Phase 3 Dependencies

- AG-UI event adapter (for routing observability events to dashboard)
- SSE streaming pipeline (for delivering violation/collision events)
- Process manager (for intercepting tool calls via ToolInterceptor)
- Event bus (for broadcasting events to dashboard and Langfuse)

---

## 14. Implementation Order

| Week | Day 1-2 | Day 3-4 | Day 5 |
|------|---------|---------|-------|
| **Week 1** | Langfuse SDK setup + trace/span creation + agent instrumentor | Ownership map + resolver + pre-write validator | Tool interceptor + violation event routing |
| **Week 2** | hcom collision detector + shell hooks + dashboard alerts | OpenTelemetry Collector Docker setup + config | Trace summary block + cost estimation + integration testing |
