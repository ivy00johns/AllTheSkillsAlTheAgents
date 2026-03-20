# 13 — Hive Component Mapping

A direct mapping between Mission Control's panels/features and The Hive's named components, analyzing what MC proves works, what it lacks, and the strategic build/fork/adapt verdict for each.

---

## The Master Mapping Table

| Hive Component | MC Equivalent | What MC Does Well | What The Hive Adds |
|---|---|---|---|
| **The Yard** | Dashboard + Agent Management | Agent lifecycle (register, heartbeat, auto-offline, sync from config), auto-discovery from `openclaw.json`, per-agent taskStats | Hierarchical agent topology, delegation chains, sub-agent trees rendered as a graph, fleet-wide agent comparison |
| **The Glass** | Session Inspector + Live Feed | Session metadata display, pause/terminate controls, JSONL transcript scanning, active session detection | Real PTY multiplexing via xterm.js -- watch agent terminals live. MC's single biggest architectural gap. |
| **The Comb** | Task Board (Kanban) + Memory Graph | 6-column Kanban (inbox, assigned, in_progress, review, quality_review, done), template-clone recurring tasks, Aegis quality gates, priority-based queue | DAG-based task graph with dependency edges, parallel/sequential visualization, critical path highlighting, not just linear columns |
| **The Waggle** | Skills Hub (Agent Config Sync) | SKILL.md sync from filesystem, workspace enrichment (identity.md, TOOLS.md, soul.md), relaxed JSON parsing, bidirectional config write-back | Deeper skill ecosystem: composability rules, eval-driven quality scoring, version pinning, dependency resolution between skills |
| **The Keeper** | Quality Gates (Aegis) | 4-layer eval stack (auto/manual/composite/escalation), quality review column, 403 on unapproved done transitions | Action-level approval (before dangerous tool calls like file deletion, deployment), not just task-level gates. Real-time intervention. |
| **The Smoker** | CLI Integration (`/api/connect`) | CLI-to-MC data reporting, JSONL session scanning, heartbeat with inline token_usage, connection lifecycle | Bidirectional command dispatch: send commands TO agents from the UI, stream terminal output back. MC is read-only from the CLI's perspective. |
| **The Trail** | Audit Trail + Security Audit + Log Viewer | Posture scoring, per-agent trust scores, audit_log table, activity feed with entity linking, Pino structured logging | Unified trace view correlating execution steps, tool calls, memory reads/writes, and security events in one timeline per agent per task |
| **The Yield** | Token Usage + Cost Dashboard + Agent Evals | Recharts dashboards, per-model/per-agent/per-task cost breakdowns, subscription-aware pricing, task outcome analytics | Fleet-relative percentile benchmarking (agent A is in the 90th percentile for token efficiency), automated coaching recommendations |
| **The Queen** | Gateway Management + Pipelines + Cron + Workspaces | Multi-gateway registration with health probes, OS-level gateway discovery, pipeline orchestration (2+ step DAGs), cron scheduling, workspace isolation | Automated task routing based on agent capabilities and load, intelligent work distribution, load balancing across agent fleet |
| **The Airway** | Event Bus (`eventBus`) | Singleton EventEmitter with HMR survival, SSE forwarding to browser clients, webhook dispatch on events, 16 typed event channels | Full event bus with pub/sub topics, message queuing with guaranteed delivery, cross-service event routing, event replay |
| **The Guard** | Webhook Circuit Breaker | Consecutive failure threshold (5 failures disables webhook), exponential backoff with jitter, delivery retry queue | System-wide circuit breakers for ALL integrations: LLM provider failures, tool call failures, agent health, not just webhooks |

---

## Detailed Analysis Per Component

### The Yard -- Fleet Overview

**MC Proves Works:**
- Agent lifecycle state machine: `offline -> online -> busy -> idle -> error -> offline` with automatic transitions on heartbeat timeout (configurable, default 10 minutes)
- Auto-discovery from configuration files eliminates manual agent registration
- Per-agent task statistics (total, in_progress, completed) computed on read
- Agent API keys with scoped permissions (viewer, operator, agent:self, agent:diagnostics) for zero-trust inter-agent access
- Workload signals API: computes fleet busy ratio, queue depth, error rate, and returns `normal/throttle/shed/pause` recommendations

**MC Lacks:**
- No topology visualization -- agents are a flat list, not a hierarchy
- No sub-agent relationship tracking -- MC doesn't know that agent-A spawned agent-B
- No delegation chain visibility -- when an agent delegates to another, the link isn't recorded
- No agent capability matching -- task routing is manual (assigned_to field), not intelligent

**Strategic Verdict:** **Adapt heavily.** The Yard should use MC's lifecycle state machine and auto-discovery as a foundation, but add a graph-based topology layer (using `@xyflow/react`, which MC already depends on) to visualize delegation chains and sub-agent trees.

---

### The Glass -- Multi-Terminal Observation

**MC Proves Works:**
- Session metadata scanning (model, tokens, tool calls, git branch, active status)
- JSONL transcript parsing with sidechain awareness (skips sub-agent messages)
- Session database with `is_active` tracking via 60-second polling
- Session details panel with basic metadata display

**MC Lacks:**
- **No real terminal output.** This is MC's biggest architectural gap. You can see session metadata but cannot watch what an agent is actually doing in real-time.
- No PTY multiplexing -- no xterm.js, no terminal streaming
- No real-time transcript tailing -- sessions are scanned periodically, not streamed
- No multi-pane terminal view -- no ability to watch multiple agents simultaneously

**Strategic Verdict:** **Build fresh.** The Glass is The Hive's killer feature that MC doesn't even attempt. Use xterm.js with WebSocket-backed PTY multiplexing. MC's JSONL scanning is useful for historical analysis but The Glass should provide live terminal observation.

---

### The Comb -- Task Graph + Shared Memory

**MC Proves Works:**
- 6-column Kanban board covering the full task lifecycle
- Task queue with priority-based assignment: `GET /api/tasks/queue?agent=name` picks the highest-priority unassigned task
- Automatic status normalization: assigning an agent auto-promotes inbox->assigned, removing assignment auto-demotes
- Task outcomes tracking: success/failed/partial/abandoned with error messages, retry counts, and resolution notes
- Regression metrics: baseline vs post p95 latency comparison for A/B analysis
- Quality gates: Aegis must approve before tasks can move to done
- Task comments with threading and @mention notifications
- Project-level organization with ticket references (e.g., CORE-012)

**MC Lacks:**
- No dependency relationships between tasks -- the Kanban is flat, not a DAG
- No parallel execution visualization -- can't see which tasks are running concurrently
- No critical path analysis -- can't identify which task is blocking completion
- No shared memory between tasks -- each task is isolated, no context passing
- No task decomposition -- a task can't be broken into subtasks with tracked dependencies

**Strategic Verdict:** **Build differently.** Keep MC's task status model and queue mechanics, but replace the Kanban with a DAG-based task graph. The Comb should visualize dependencies, parallel execution, and critical paths. Add shared memory (key-value context) that flows between dependent tasks.

---

### The Waggle -- Skill/Tool Registry

**MC Proves Works:**
- Bidirectional config sync: reads agent configs from filesystem, writes changes back
- Workspace enrichment: reads identity.md, TOOLS.md, soul.md from agent workspaces
- Relaxed JSON parsing for human-edited config files (comments, trailing commas)
- Change detection before write (only updates when config actually changed)
- Transactional batch sync with audit logging

**MC Lacks:**
- No skill versioning -- no semver, no pinning, no dependency resolution
- No skill composability rules -- MC doesn't track which skills can be used together
- No skill quality scoring -- no evals, no benchmarks, no performance tracking
- No skill marketplace or sharing mechanism
- No skill-level permissions (which agents can use which skills)

**Strategic Verdict:** **Build fresh with MC's sync patterns.** Adopt the bidirectional sync and workspace enrichment patterns from MC, but build a proper skill registry with versioning, composability rules, eval-driven quality scores, and per-agent skill permissions.

---

### The Keeper -- Human-in-the-Loop Approval

**MC Proves Works:**
- Quality review workflow: reviewers submit approved/rejected with notes
- Task status gate: 403 error when moving to done without Aegis approval
- Batch review lookup: `GET /api/quality-review?taskIds=1,2,3` for efficient UI rendering
- Quality review column in Kanban for visual tracking

**MC Lacks:**
- **Approval is task-level, not action-level.** MC gates task completion, but doesn't intercept dangerous tool calls (file deletion, deployment, database writes) before they execute.
- No real-time intervention -- no way to pause an agent mid-execution
- No approval policy engine -- rules are hardcoded (quality_review column), not configurable
- No approval delegation or escalation chains
- No approval SLA tracking

**Strategic Verdict:** **Build fresh.** The Keeper's action-level approval is fundamentally different from MC's task-level quality gates. Build a policy engine that intercepts tool calls matching configurable danger patterns, presents them to a human operator, and blocks execution until approved. This is The Hive's strongest safety differentiator.

---

### The Smoker -- CLI-Web Bridge

**MC Proves Works:**
- CLI connection lifecycle: POST `/api/connect` -> heartbeat loop -> DELETE `/api/connect`
- Auto-creates agent record on first connection
- Heartbeat carries inline token_usage for passive cost tracking
- Connection tracking (tool_name, tool_version, agent_name, status)
- SSE URL returned on connect for real-time event consumption

**MC Lacks:**
- **Communication is unidirectional.** The CLI reports data TO MC, but MC cannot send commands BACK to the CLI.
- No terminal output streaming from CLI to dashboard
- No command dispatch from dashboard to CLI
- No interactive session support
- No file transfer between dashboard and CLI

**Strategic Verdict:** **Adapt and extend.** Keep MC's connection lifecycle and heartbeat pattern, but add bidirectional WebSocket communication. The Smoker should let operators send commands to agents from the UI and stream terminal output back in real-time.

---

### The Trail -- Unified Trace/Observability

**MC Proves Works:**
- Activity feed with entity linking (type, entity_type, entity_id, actor)
- Audit log with security-specific events (posture scoring, trust scores)
- Per-agent attribution with section-based queries (identity, audit, mutations, cost)
- Timeframe-based filtering (hours parameter for recent history)
- Structured logging with Pino (JSON in production, pretty in dev)
- Webhook delivery tracking with attempt history

**MC Lacks:**
- **No unified timeline.** Audit events, activities, security events, and logs are in separate tables/views -- no correlated trace view.
- No trace IDs linking related events across systems
- No tool call recording with inputs/outputs
- No memory read/write tracking
- No execution flow visualization (step 1 -> tool call -> step 2)
- No performance flame chart or waterfall view

**Strategic Verdict:** **Build fresh with heavy inspiration from MC's data model.** Adopt MC's entity-linked activity model and structured logging, but build a unified trace view that correlates execution steps, tool calls, memory operations, and security events in a single timeline. Add OpenTelemetry-compatible trace IDs.

---

### The Yield -- Metrics Dashboard

**MC Proves Works:**
- Token cost tracking with model-specific pricing (input/output rates, cache-aware)
- Per-agent, per-task, per-project, and unattributed cost rollups
- Subscription-aware pricing (zero cost for flat-rate API providers)
- Timeline data for cost trend visualization
- Task outcome analytics (success/failed/partial/abandoned by agent and priority)
- Regression metrics (baseline vs post p95 latency)
- Recharts-based dashboard components

**MC Lacks:**
- No fleet-relative benchmarking -- can't compare agent A's efficiency to the fleet average
- No automated coaching -- identifies problems but doesn't suggest solutions
- No cost forecasting or budget alerts
- No quality-adjusted cost metrics (cost per successful task, not just cost per token)
- No SLA tracking (time-to-completion percentiles)

**Strategic Verdict:** **Adapt and extend.** Keep MC's cost tracking and Recharts dashboards, but add fleet-relative percentile benchmarking, automated coaching recommendations, and quality-adjusted metrics. The Yield should answer "which agents need help?" not just "how much did we spend?"

---

### The Queen -- Orchestrator Control Plane

**MC Proves Works:**
- Multi-gateway registration with host/port/token configuration
- Gateway health probes and connection testing
- OS-level gateway process discovery
- Pipeline orchestration (2+ step sequential execution with on_failure: stop/continue)
- Cron scheduling with natural language display
- Workspace isolation with multi-tenant support
- Workload signals for admission control (normal/throttle/shed/pause)

**MC Lacks:**
- **No automated task routing.** MC's task queue picks the highest-priority task for a NAMED agent -- it doesn't decide WHICH agent should get the task.
- No capability-based matching (agent A has skill X, task needs skill X)
- No load balancing across agents
- No intelligent work distribution
- No agent specialization awareness
- No cost-optimized routing (prefer cheaper agents when quality is equivalent)

**Strategic Verdict:** **Build fresh.** The Queen is fundamentally an orchestration engine that MC doesn't have. MC manages gateways and pipelines but doesn't automatically route work. Build an intelligent router that matches tasks to agents based on capabilities, load, cost, and historical performance.

---

### The Airway -- Event Bus

**MC Proves Works:**
- Singleton EventEmitter with globalThis HMR survival
- 16 typed event channels covering all major domain events
- SSE forwarding to browser clients for real-time UI updates
- Webhook dispatch triggered by event bus events
- Event type mapping for webhook consumers (e.g., `activity.created` -> `activity.task_created`)

**MC Lacks:**
- **Single-process only.** EventEmitter doesn't work across multiple server instances.
- No message persistence -- events are fire-and-forget
- No guaranteed delivery -- if a listener errors, the event is lost
- No pub/sub topics -- all listeners get all events
- No event replay for late-joining consumers
- No backpressure handling

**Strategic Verdict:** **Build fresh with MC's event type catalog.** Adopt MC's 16 event types as a starting point, but build on Redis Pub/Sub or NATS for multi-process support, message persistence, and guaranteed delivery. The Airway should be The Hive's nervous system, not just an in-process EventEmitter.

---

### The Guard -- Circuit Breakers

**MC Proves Works:**
- Webhook circuit breaker: consecutive failure counter, threshold-based disable
- Exponential backoff with jitter: `[30s, 5m, 30m, 2h, 8h]` schedule
- Database-backed retry queue surviving server restarts
- Delivery attempt tracking with parent-child relationships
- Automatic re-enable not implemented (deliberate: requires manual intervention)

**MC Lacks:**
- **Webhooks only.** MC has no circuit breakers for LLM provider failures, tool call failures, agent health, or database operations.
- No half-open state for automatic recovery testing
- No circuit breaker dashboard or visibility
- No configurable thresholds per integration
- No cascading failure prevention (one tripped breaker doesn't protect downstream systems)

**Strategic Verdict:** **Generalize MC's webhook circuit breaker.** The Guard should provide circuit breakers for every external integration: LLM providers (rate limits, outages), tool calls (file system, API failures), agent communication (heartbeat failures), and database operations. Add half-open state with probe requests for automatic recovery.

---

## Strategic Summary

### Build Verdict Per Component

| Component | Verdict | Rationale |
|-----------|---------|-----------|
| The Yard | **Adapt** | MC's lifecycle model works; add topology graph |
| The Glass | **Build fresh** | MC doesn't attempt real PTY multiplexing |
| The Comb | **Build differently** | Keep task model, replace Kanban with DAG |
| The Waggle | **Build fresh** | MC's sync patterns useful, skill ecosystem needs rethinking |
| The Keeper | **Build fresh** | Action-level approval is fundamentally different from task-level |
| The Smoker | **Adapt and extend** | Keep connection lifecycle, add bidirectional communication |
| The Trail | **Build fresh** | MC's data model useful, unified trace view is new |
| The Yield | **Adapt and extend** | Keep cost tracking, add fleet benchmarking |
| The Queen | **Build fresh** | MC has no intelligent routing |
| The Airway | **Build fresh** | EventEmitter doesn't scale; need real pub/sub |
| The Guard | **Generalize** | MC's webhook breaker pattern applied system-wide |

### The 7 Patterns to Adopt Directly

These code patterns from MC should be copied or closely adapted:

1. **`requireRole()` discriminated union** -- the auth guard pattern that gives TypeScript-safe user access
2. **`validateBody()` + Zod schemas** -- request validation with structured error messages
3. **API route template** (rate-limit -> auth -> validate -> logic -> events -> response) -- consistent endpoint structure
4. **Factory rate limiter** with critical flag and per-IP tracking
5. **Smart polling with Page Visibility API** -- the `useSmartPoll` hook for battery-aware dashboard panels
6. **Structured logging with Pino** -- JSON in production, pretty in dev, error-context-first
7. **Ed25519 device identity** with localStorage persistence and challenge-response signing

### The 7 Things The Hive Does That MC Doesn't Even Attempt

These are The Hive's competitive advantages -- features with no MC equivalent:

1. **Real PTY multiplexing** -- watch agent terminals live via xterm.js (The Glass)
2. **DAG-based task graphs** -- dependency visualization, critical path analysis (The Comb)
3. **Action-level approval gates** -- intercept dangerous tool calls before execution (The Keeper)
4. **Bidirectional command dispatch** -- send commands to agents from the UI (The Smoker)
5. **Unified trace correlation** -- execution, tools, memory, and security in one timeline (The Trail)
6. **Fleet-relative benchmarking** -- percentile ranking of agents with automated coaching (The Yield)
7. **Intelligent task routing** -- capability-based, load-aware work distribution (The Queen)

### Strategic Summary

The Hive should be built fresh, with heavy inspiration from Mission Control's proven patterns. MC validates the core feature requirements -- agent lifecycle management, task orchestration, cost tracking, webhook integration, and quality gates all work well and should be adopted. But MC's architecture is fundamentally single-process, read-mostly, and lacks the real-time bidirectional communication that defines a true agent orchestration platform.

The Hive's differentiators cluster around three themes: **live observation** (The Glass + The Trail), **intelligent automation** (The Queen + The Yield), and **safety at the action level** (The Keeper + The Guard). These are not incremental improvements over MC -- they represent architectural capabilities that require different foundations (WebSocket PTY streaming, pub/sub event routing, policy engines).

The correct approach: fork MC's code patterns (not its codebase), build The Hive's architecture from scratch with multi-process scalability, and validate against MC's feature set to ensure nothing proven is left behind.
