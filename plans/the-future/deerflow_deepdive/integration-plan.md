# DeerFlow Integration Plan for The Hive

**Date:** 2026-03-21
**Status:** DRAFT
**Source:** 12-document deep dive of DeerFlow (ByteDance, ~58k LoC, 30k+ GitHub stars)
**Premise:** DeerFlow for capability, AllTheSkills for coordination, The Hive for infrastructure

---

## Executive Summary

DeerFlow is a production-grade agent harness built on LangGraph/LangChain with three patterns worth integrating into The Hive:

1. **Ordered middleware pipeline** — composable agent instrumentation (highest value)
2. **Confidence-scored persistent memory** — quality-gated memory with async extraction
3. **Deferred tool loading** — token-optimized MCP tool discovery

Three patterns to note but not port directly:
- Sub-agent thread pools (incompatible with Claude Code's Agent tool lifecycle)
- Python-specific sandbox (The Hive already has worktree isolation)
- IM channel integrations (Feishu/Slack/Telegram — orthogonal to The Hive's scope)

---

## Integration Phases

### Phase A: Middleware Pipeline for Agent Roles
**Priority:** P0 — Highest value, enables all other instrumentation
**Effort:** Medium (2-3 sessions)
**Depends on:** Phase 3 Quality Layer (done)

**What DeerFlow does:**
13 ordered middleware stages with 5 static hooks (`before_agent`, `after_agent`, `before_model`, `after_model`, `wrap_tool_call`). Order is load-bearing. Middleware can be disabled/reordered without touching agent code.

**Key middlewares to port:**
| DeerFlow Middleware | Hive Equivalent | Purpose |
|---|---|---|
| ThreadDataMiddleware | ContextMiddleware | Set up per-agent workspace paths |
| SandboxMiddleware | WorktreeMiddleware | Acquire/release worktree lifecycle |
| ToolErrorHandlingMiddleware | ErrorMiddleware | Convert tool exceptions to structured errors |
| SummarizationMiddleware | CompactionMiddleware | Compress history when tokens exceed threshold |
| TodoMiddleware | TaskMiddleware | Re-inject lost tasks after compaction |
| LoopDetectionMiddleware | LoopDetectionMiddleware | Detect/break repetitive tool loops (warn@3, stop@5) |
| SubagentLimitMiddleware | DepthGuardMiddleware | Enforce max concurrent sub-agents |
| MemoryMiddleware | LearningMiddleware | Queue conversation for async knowledge extraction |

**New Hive-specific middlewares (not in DeerFlow):**
| Middleware | Purpose |
|---|---|
| FileOwnershipMiddleware | Validate file changes against declared scope (AllTheSkills) |
| BudgetMiddleware | Check cost against per-agent/per-build budget |
| ContractConformanceMiddleware | Validate output against contracts |
| QAGateMiddleware | Score and gate quality before merge |
| AuditTrailMiddleware | Record all actions for compliance |

**TypeScript interface:**
```typescript
interface AgentMiddleware {
  readonly name: string;
  readonly order: number;  // Lower = earlier

  beforeAgent?(context: AgentContext): Promise<AgentContext>;
  afterAgent?(context: AgentContext, result: AgentResult): Promise<AgentResult>;
  beforeToolCall?(context: AgentContext, tool: ToolCall): Promise<ToolCall>;
  afterToolCall?(context: AgentContext, tool: ToolCall, result: ToolResult): Promise<ToolResult>;
}

interface MiddlewarePipeline {
  register(middleware: AgentMiddleware): void;
  execute(context: AgentContext, handler: AgentHandler): Promise<AgentResult>;
}
```

**Where it lives:** `apps/control-plane/src/services/middleware/`

**Acceptance criteria:**
- [ ] Pipeline executes middlewares in order (ascending by `order`)
- [ ] `afterAgent` hooks execute in reverse order (outermost first)
- [ ] Loop detection warns at 3 identical tool call hashes, force-stops at 5
- [ ] File ownership middleware rejects tool calls that write outside declared scope
- [ ] Budget middleware blocks agent when cost exceeds configured limit
- [ ] Middleware can be disabled via config without code changes
- [ ] Compaction middleware triggers when token count exceeds threshold

---

### Phase B: Loop Detection (Safety)
**Priority:** P0 — Safety mechanism, prevents runaway agents
**Effort:** Low (1 session)
**Depends on:** Phase A middleware pipeline

**What DeerFlow does:**
- Sliding window (size 20) of MD5 hashes of tool calls
- Hash is order-independent (tools sorted by name + args)
- Warn at 3 identical occurrences (inject SystemMessage)
- Force-stop at 5 identical occurrences (strip tool_calls, append notice)
- Per-thread tracking with LRU eviction (max 100 threads)

**Adaptation for The Hive:**
- Use SHA-256 instead of MD5 (consistent with Hive ID generation)
- Integrate as `LoopDetectionMiddleware` in the pipeline
- Report loop events to The Trail (audit trail)
- Escalate to watchdog on force-stop

**Where it lives:** `apps/control-plane/src/services/middleware/loop-detection.ts`

**Acceptance criteria:**
- [ ] Detects 3 identical consecutive tool call patterns, injects warning
- [ ] Force-stops at 5 identical patterns
- [ ] Hash is order-independent for parallel tool calls
- [ ] Events recorded in platform_events table
- [ ] Watchdog notified on force-stop

---

### Phase C: Deferred Tool Loading for MCP
**Priority:** P1 — Token optimization as MCP server count grows
**Effort:** Low-Medium (1-2 sessions)
**Depends on:** MCP server support in The Hive

**What DeerFlow does:**
- MCP tools registered in `DeferredToolRegistry` instead of bound to model
- `tool_search` meta-tool discovers tools by keyword
- System prompt lists tool names in `<available-deferred-tools>` block
- Search supports: exact match (`select:name1,name2`), ranking (`+keyword rest`), regex
- Results capped at 5

**Why it matters:**
- 50+ MCP tool schemas can consume 10K+ tokens of context
- Deferred loading preserves capability while reducing baseline cost
- Claude Code already supports this pattern via `ToolSearch`

**Adaptation for The Hive:**
- Implement as part of skill/tool assembly in the sling dispatch
- Include deferred tool list in agent overlay (CLAUDE.md / GEMINI.md)
- Track which tools agents actually discover and use (learning data)

**Where it lives:** `apps/control-plane/src/services/deferred-tools.ts`

**Acceptance criteria:**
- [ ] MCP tools with `deferred: true` excluded from agent's initial tool binding
- [ ] Tool names listed in `<available-deferred-tools>` block in overlay
- [ ] Agent can discover and call deferred tools via search
- [ ] Usage tracking records which deferred tools each role actually uses

---

### Phase D: Confidence-Scored Memory
**Priority:** P1 — Compounds over time, prevents memory pollution
**Effort:** Medium (2 sessions)
**Depends on:** Phase A middleware pipeline, LearningService (Phase 4, done)

**What DeerFlow does:**
- Three-tier memory: User Context, History, Facts
- Facts have `confidence` (0-1), `category`, `createdAt`, `source`
- Max 100 facts; lowest-confidence evicted when exceeded
- Confidence threshold (0.7) gates storage
- Async extraction via debounced queue (30s window)
- Token-budgeted injection (max 2000 tokens in system prompt)

**Adaptation for The Hive:**
- Extend LearningService with confidence scoring
- Categories: `preference`, `knowledge`, `context`, `behavior`, `goal`
- PostgreSQL table `agent_memories` instead of JSON file
- Async extraction via Valkey Streams (The Airway)
- Inject relevant memories into agent overlay during sling dispatch
- Per-agent and per-project memory scopes

**Schema:**
```sql
CREATE TABLE agent_memories (
  id TEXT PRIMARY KEY,
  agent_name TEXT,
  project_id TEXT,
  category TEXT NOT NULL CHECK (category IN ('preference', 'knowledge', 'context', 'behavior', 'goal')),
  content TEXT NOT NULL,
  confidence REAL NOT NULL DEFAULT 0.5 CHECK (confidence >= 0 AND confidence <= 1),
  source_thread TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_accessed_at TIMESTAMPTZ,
  access_count INT DEFAULT 0
);
```

**Where it lives:** `apps/control-plane/src/services/agent-memory.ts`

**Acceptance criteria:**
- [ ] Facts stored with 0-1 confidence score
- [ ] Extraction debounced (configurable window, default 30s)
- [ ] Low-confidence facts (< 0.7) not injected into prompts
- [ ] Max facts per agent (default 100), lowest-confidence evicted
- [ ] Token-budgeted injection (max 2000 tokens)
- [ ] Memory persists across sessions

---

### Phase E: DeerFlow as Research Sidecar
**Priority:** P2 — Valuable but requires DeerFlow deployment
**Effort:** Medium (2 sessions)
**Depends on:** Docker infrastructure (Phase 0, done)

**What DeerFlow provides:**
- Benchmark-competitive research (72.9 overall score, #1 citations)
- Web search + deep reading + citation tracking
- Code execution in sandboxed environments
- Multi-step research with iterative refinement

**Integration approach:**
- Deploy DeerFlow as a Docker service alongside The Hive
- HTTP bridge: The Hive's orchestrator delegates research tasks via DeerFlow's LangGraph API
- Results returned as structured context for builder agents
- Cost tracked via The Yield (metrics service)

**Where it lives:**
- `infra/compose.local.yml` — DeerFlow service definition
- `apps/control-plane/src/services/research-sidecar.ts` — HTTP client

**Acceptance criteria:**
- [ ] `docker compose up` includes DeerFlow service
- [ ] `platform research <query>` delegates to DeerFlow via HTTP
- [ ] Results returned as structured JSON with citations
- [ ] Cost recorded in metrics_snapshots

---

### Phase F: Virtual Path Abstraction
**Priority:** P2 — Important for multi-deployment topology
**Effort:** Low (1 session)
**Depends on:** Worktree service (Phase 2, done)

**What DeerFlow does:**
- Agent sees: `/mnt/user-data/{workspace,uploads,outputs}`
- Maps to actual paths based on deployment mode (local, Docker, K8s)
- Path traversal rejection via validation

**Adaptation for The Hive:**
- Agents see `{worktree}/` as their workspace
- Shared artifacts at `{project}/artifacts/`
- Upload/download via REST API at `/api/v1/threads/{id}/artifacts`
- Virtual paths in agent overlays resolve to actual worktree paths

**Where it lives:** `apps/control-plane/src/services/virtual-paths.ts`

---

## Non-Goals (Explicitly Out of Scope)

| DeerFlow Feature | Why Not |
|---|---|
| IM channels (Feishu/Slack/Telegram) | The Hive's interface is CLI + Dashboard, not chat |
| Python sandbox providers | The Hive uses git worktrees for isolation |
| LangGraph/LangChain dependency | The Hive is TypeScript-native |
| Sub-agent thread pools | Claude Code's Agent tool handles parallelism |
| DeerFlow's frontend (Next.js) | The Hive has The Glass (React 19) |

---

## Implementation Sequence

```
Phase A (Middleware Pipeline) ──→ Phase B (Loop Detection)
                              ──→ Phase D (Confidence Memory)

Phase C (Deferred Tools)      ──→ independent, start anytime

Phase E (Research Sidecar)    ──→ independent, start anytime

Phase F (Virtual Paths)       ──→ independent, start anytime
```

**Recommended order:** A → B → C → D → E → F

Phases C, E, and F can be parallelized with A/B/D since they have no dependencies.

---

## Key Design Decisions

1. **Middleware order is load-bearing** — ContextMiddleware must run first (sets up workspace), QAGateMiddleware must run last (needs complete output)
2. **Loop detection uses escalating intervention** — warn then stop, never just stop
3. **Memory extraction is async** — never blocks the agent conversation
4. **Confidence threshold gates injection** — low-quality memories don't pollute future prompts
5. **DeerFlow is a sidecar, not a dependency** — The Hive works without it; DeerFlow adds research capability
6. **File ownership middleware replaces DeerFlow's sandbox** — AllTheSkills' contract enforcement is more granular than container isolation
