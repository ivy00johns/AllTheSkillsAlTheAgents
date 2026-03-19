# 01 — Product Charter

**Document type:** Vision specification
**Status:** DRAFT
**Date:** 2026-03-18
**Scope:** Clean-sheet AI agent orchestration platform synthesizing five existing systems

---

## 1. The Problem

### Five Platforms, Five Partial Solutions

The frontier of AI-assisted software delivery is being explored simultaneously by five independent projects. Each has made genuine breakthroughs. None is complete.

| Platform | Author | Scale | Breakthrough | Critical Gap |
|----------|--------|-------|-------------|-------------|
| **Beads** | Steve Yegge | 225k LoC Go | Dolt-backed durable work state, 22 dependency types, SQL-queryable task graph, federation via DoltHub | No quality intelligence. Tracks work but cannot assess it. No contracts, no design awareness, no cognitive review patterns. |
| **Gas Town** | Steve Yegge | 377k LoC Go | 20-30+ concurrent agents with 8 worker roles, MEOW stack, convoy-based orchestration, batch-then-bisect merge queue, persistent agent identity | No contract system. No design intelligence. Quality is "it compiles and merges," not "a staff engineer reviewed this." 100% vibe coded, chaos-tolerant by design. |
| **Overstory** | Jaymin West | 96k LoC TypeScript | 9 runtime adapters, SQLite mail (~1-5ms), 4-tier merge resolution with learning, 3-tier watchdog, hook-driven orchestrator | No structured QA beyond pass/fail commands. No machine-readable contracts. No cognitive patterns. No browser-based verification. |
| **gstack** | Garry Tan | ~30k LoC TypeScript | 41 cognitive patterns across CEO/Eng/Design modes, 80-item design audit, AI slop detection, 3-tier eval system, compiled browser binary | Single-session. Claude-only. Stateless. Cannot scale past one agent. No persistent work tracking. No merge infrastructure. |
| **ATSA** | johns | ~5k LoC Markdown | Contract-first architecture with 6 template formats, exclusive file ownership, 5-dimension QA scoring, 14-phase build playbook, progressive disclosure | Pure prompt engineering. No runtime infrastructure. No process management. No merge system. No observability. No agent persistence. |

### The Fundamental Gap

These five platforms reveal a structural divide in the landscape:

**Infrastructure without intelligence:** Beads + Gas Town + Overstory can run 30+ agents in parallel with durable state, merge queues, and multi-runtime support. But the agents are cognitively generic. They build code without design awareness, merge without contract verification, and declare "done" without structured evidence.

**Intelligence without infrastructure:** gstack + ATSA can make a single agent think like a staff engineer, review like a design critic, and validate against machine-readable contracts. But they cannot run more than one agent, persist state across sessions, or resolve merge conflicts.

No existing platform combines orchestration infrastructure and quality intelligence. This is not an incremental gap. It is a category gap. The system that unifies them will be fundamentally different from anything that exists.

### Why This Gap Persists

The gap is not accidental. It reflects the backgrounds of the builders:

- **Yegge** (Beads, Gas Town) is an infrastructure engineer. He built the plumbing — durable state, supervision hierarchies, merge queues. Quality is someone else's problem.
- **West** (Overstory) is a systems architect. He built the runtime abstraction — adapters, messaging, conflict resolution. Quality is a pass/fail gate.
- **Tan** (gstack) is a product founder. He built the judgment — cognitive patterns, design audits, eval systems. Infrastructure is Claude Code's problem.
- **johns** (ATSA) is a process architect. He built the contracts and workflows — ownership maps, QA schemas, build playbooks. Everything is prompt engineering.

Each builder optimized for their own expertise. The convergence requires someone who values all four concerns equally: infrastructure, runtime, intelligence, and contracts.

---

## 2. The Vision

### One Person, Thirty Agents, Production-Grade

An operating system for autonomous software delivery.

You describe what you want. The system decomposes it into tracked work items with dependency graphs. It generates machine-readable contracts before any agent is spawned. It dispatches 30+ agents across multiple LLM runtimes — Claude for complex reasoning, Codex for sandboxed execution, Gemini for multi-modal tasks. Each agent works in an isolated git worktree with browser access for visual verification. Every code change goes through cognitive review using named thinking frameworks, not generic checklists. The merge queue runs contract conformance checks and design audits before landing code. Work state survives session crashes, context compaction, and model failures. The eval system validates the pipeline itself. And every action produces verifiable evidence, not assertions.

### Five Truths from Five Platforms

1. **Agents are persistent identities with track records** (Gas Town). An agent is not a session. It is a named entity with a CV that accumulates expertise across sessions. Past performance informs future routing. Identity survives crashes, compaction, and model switches.

2. **Work is durable and survives everything** (Beads). Every work item is a versioned record in a SQL-queryable database with 22 dependency types. Work state is not in the LLM's context window. It is in Dolt, backed by Git, queryable with SQL, and federable across instances.

3. **Quality is structural, not optional** (gstack + ATSA). Quality is not a phase at the end. It is compiled into the infrastructure. Contracts prevent integration failures. Cognitive patterns produce thoughtful reviews. Design audits catch AI slop. Eval systems validate the validators. The system cannot produce work that has not been verified.

4. **Any LLM can participate** (Overstory). The platform is not locked to one vendor. Nine runtime adapters mean Claude, Pi, Codex, Gemini, Cursor, Copilot, and future models can all participate in the same build. The right model is routed to the right task based on capability and cost.

5. **Contracts prevent integration failures** (ATSA). Machine-readable contracts — OpenAPI, AsyncAPI, Pydantic, TypeScript, JSON Schema — are generated before any implementation agent is spawned. Contract conformance is verified at merge time. Research shows ~42% of multi-agent failures stem from specification problems. Contracts eliminate this class of failure structurally.

---

## 3. Eight Unique Value Propositions

These are the capabilities that no single existing platform provides. Each is proven by at least one platform. The synthesis makes them multiplicative, not additive.

### 3.1 Durable Work State

**Source:** Beads (v0.61.0)

Every piece of work — tasks, bugs, reviews, design findings, QA results — is a record in a Dolt database. Dolt is version-controlled SQL: MySQL-compatible queries, Git-style branching, cell-level merge, content-addressed storage.

| Property | Implementation |
|----------|---------------|
| Persistence | Every write auto-commits to Dolt history |
| Queryability | Standard SQL — `SELECT * FROM issues WHERE priority = 1 AND status = 'open'` |
| Dependency tracking | 22 dependency types with topological sort (`bd ready` returns only unblocked work) |
| Token efficiency | `bd prime` generates ~80 lines (~1-2K tokens) of context vs. 10-50K for raw MCP schemas |
| Crash recovery | Work state is in the database, not the LLM context. Session crashes lose nothing. |
| Versioning | Full Git-style history. Any state is recoverable. Branching for speculative work. |

The key insight from Beads: **the tool does the computation, the agent consumes the result.** Topological sort, dependency analysis, and priority ranking happen server-side in SQL, not in the LLM's context window.

### 3.2 Contract-First Architecture

**Source:** ATSA

Machine-readable contracts are generated before any implementation agent is spawned. This is not optional and not skippable.

| Contract Type | Format | Prevents |
|--------------|--------|----------|
| API contracts | OpenAPI 3.1 | Endpoint mismatches, request/response shape disagreements |
| Event contracts | AsyncAPI 2.6 | Message format mismatches in async systems |
| Data model contracts | Pydantic / TypeScript | Type mismatches at integration boundaries |
| Schema contracts | JSON Schema | Validation rule disagreements |
| Ownership contracts | YAML ownership map | File conflicts between parallel agents |
| Data layer contracts | YAML data-layer | Database schema disagreements |

The contract-author skill generates contracts from templates. The contract-auditor verifies implementations at merge time. The orchestrator blocks spawning until contracts exist for all integration boundaries.

**Impact:** ~42% of multi-agent integration failures stem from specification problems. Contracts eliminate this class of failure before the first line of code is written.

### 3.3 Cognitive Quality Intelligence

**Source:** gstack

Instead of checklists ("check for SQL injection"), the system activates **latent knowledge of how great thinkers approach problems.** The instruction is "internalize these frameworks," not "enumerate these rules."

| Mode | Pattern Count | Examples | Output |
|------|--------------|---------|--------|
| CEO / Strategic | 14 | Bezos Doors, Grove Paranoid Scanning, Munger Inversion, Horowitz Wartime/Peacetime | Scope decisions, leverage analysis, threat identification |
| Engineering | 15 | McKinley Boring Default, Brooks Essential/Accidental, Beck Make Change Easy, Kernighan Debugging | Architecture diagrams, state machines, test matrices, edge case analysis |
| Design | 12 | Rams Subtraction, Norman 3 Levels, Tufte Data-Ink, Krug Don't Make Me Think | 80-item design audit across 10 categories, AI slop detection |

This works because LLMs have deep knowledge of these thinkers. Invoking "think like Dieter Rams" activates a coherent design philosophy — hundreds of implications, not five bullet points. Patterns are composable: Bezos Doors + Altman Leverage = "Is this a reversible high-leverage bet? Ship it fast."

**In the unified system:** Every agent receives cognitive patterns appropriate to its role. Backend agents think like McKinley (boring by default) + Kernighan (debugging clarity). Frontend agents think like Rams (subtraction) + Norman (three levels). QA agents think like Grove (paranoid scanning) + Munger (inversion).

### 3.4 Runtime Neutrality

**Source:** Overstory

The platform is not locked to any single LLM provider. Nine runtime adapters support mixed fleets where different models handle different tasks.

| Runtime | Adapter Size | Best For |
|---------|-------------|----------|
| Claude Code | ~400 lines | Complex reasoning, architectural decisions |
| Pi (Inflection) | ~250 lines | Fast iteration, routine implementation |
| Codex (OpenAI) | ~300 lines | Sandboxed execution, deterministic tasks |
| Gemini | ~350 lines | Multi-modal tasks, large context windows |
| Cursor | ~200 lines | IDE-integrated tasks |
| Copilot | ~200 lines | Inline completion, small edits |
| Sapling | ~200 lines | Specialized tasks |
| OpenCode | ~200 lines | Multi-provider via OpenRouter |
| Custom | Interface | Any future runtime |

The `AgentRuntime` interface is clean enough that new adapters are ~200-400 lines. Model routing is per-task: the system learns which runtime produces the best results for which task type.

**In the unified system:** Claude leads orchestration. Pi builders handle routine implementation. Codex scouts do sandboxed exploration. Gemini reviewers assess multi-modal output. The fleet is heterogeneous by design.

### 3.5 Self-Validating Pipeline

**Source:** gstack

The system validates itself, not just the code it produces.

| Tier | Method | Cost | Speed | What It Catches |
|------|--------|------|-------|----------------|
| 1 — Static | Parse SKILL.md commands against command registry | Free | <1s | Typos, removed commands, illegal flag combinations |
| 2 — E2E | Spawn real agent sessions, pipe prompts, record NDJSON output | ~$3.85/run | Minutes | Workflow failures, timeout patterns, tool call sequences |
| 3 — LLM-as-Judge | Planted-bug fixtures evaluated by judge model with structured rubrics | ~$0.15/run | Seconds | Review quality degradation, false negatives, missed patterns |

Diff-based test selection means changing one skill runs only its affected tests (~$0.30) instead of the full suite (~$4.00). Eval persistence enables trend analysis: "qa-quick regressed from 8/10 to 6/10 after the last change — investigate."

The blame protocol prevents lazy failure attribution: you cannot claim "pre-existing" without proving it by running the same eval on main.

**In the unified system:** The eval system runs as a continuous background process. Agent quality is monitored, trended, and alerted on. Regressions are detected automatically. The pipeline that validates code is itself validated.

### 3.6 Persistent Agent Identity

**Source:** Gas Town + Overstory

Agents are not ephemeral sessions. They are persistent identities with track records.

| Layer | Lifecycle | Contains |
|-------|-----------|----------|
| Identity | Permanent | Name, role, creation date, CV chain, cumulative expertise |
| Sandbox | Persists across sessions | Git worktree, configuration, cached context |
| Session | Ephemeral | Current context window, active tool calls |

Gas Town's Polecats have persistent identity backed by Beads. When a session crashes or context fills, the identity survives. The new session inherits the CV, checks its hook for pending work, and resumes. The "seance" protocol lets the new session resume the previous one to ask questions about unfinished work.

Overstory adds three-layer persistence (identity, sandbox, session) and agent CVs that accumulate expertise over time. Past merge success rates, review quality scores, and task completion times inform future routing decisions.

**In the unified system:** Worker scorecards drive dispatch. An agent that consistently passes QA gets fast-tracked. An agent that consistently fails gets reduced scope. Reputation is earned, not assumed.

### 3.7 Intelligent Merge Resolution

**Source:** Overstory + Gas Town

When 30 agents work on the same codebase, merge conflicts are inevitable. The system resolves them automatically through a 4-tier escalation.

| Tier | Strategy | When Used | Learning |
|------|----------|-----------|----------|
| 1 — Clean | Standard git merge (no conflicts) | Default path | Records outcome |
| 2 — Auto | Non-overlapping changes resolved automatically | Minor conflicts | Records pattern |
| 3 — AI-assisted | LLM analyzes semantic intent and resolves | Semantic conflicts | Injects past resolutions into prompt |
| 4 — Reimagine | Agent rewrites implementation from spec | Irreconcilable | Records for future avoidance |

Overstory's merge system learns from history. Tiers that consistently fail for certain file patterns are automatically skipped. Past successful resolutions are injected into AI prompts for similar conflicts. Conflict patterns are predicted before merges begin.

Gas Town's Refinery adds batch-then-bisect: merge multiple branches, if the batch fails, bisect to find the breaking branch. This is Bors-style merge queue logic adapted for AI-generated code.

**In the unified system:** The merge queue runs contract conformance checks and cognitive code review before landing. Merges are not just "does it compile" — they are "does it match the contract, pass the design audit, and survive a staff-engineer-level review."

### 3.8 Federation

**Source:** Beads + Gas Town

Multiple instances synchronize state via Dolt's native push/pull/merge mechanism. This is not a centralized service — it is peer-to-peer.

| Capability | Implementation |
|------------|---------------|
| Sync protocol | Dolt push/pull with cell-level three-way merge |
| Remote backends | DoltHub, S3, GCS, local filesystem, HTTPS, SSH |
| Conflict resolution | Cell-level auto-merge for non-conflicting changes, strategy selection for conflicts |
| Sovereignty tiers | T1 (public) through T4 (anonymous) — configurable per peer |
| Credential management | AES-256-GCM encrypted passwords, per-peer credential storage |
| Reputation | Gas Town's Wasteland: DoltHub-backed federated work marketplace with reputation stamps |
| Identity portability | Agent CVs and scorecards travel with the work |

**In the unified system:** A team runs multiple instances. Each instance has its own agents, its own builds, its own quality gates. Completed work syncs bidirectionally. Agent reputations are portable. A specialist who excels in one instance can be recruited by another.

---

## 4. Target Audience

### Primary: Stage 5-6 Developers

Current ATSA users. They already use Claude Code with skills and understand contract-first architecture. They want:

- Real runtime infrastructure instead of prompt engineering
- Persistent work state instead of ephemeral sessions
- Automated merge resolution instead of manual conflict fixing
- Multi-agent parallelism instead of sequential builds
- Observability into what agents are doing

**What they bring:** Deep understanding of contracts, quality gates, and workflow discipline. They will stress-test the contract system and QA pipeline.

### Secondary: Stage 7-8 Developers

Current Gas Town users. They already run 20-30 concurrent agents and understand the chaos. They want:

- Quality intelligence instead of "it compiles" verification
- Contract-driven coordination instead of hope-based integration
- Design awareness instead of AI slop
- Structured eval systems instead of manual spot-checking
- Cognitive review patterns instead of generic code review

**What they bring:** Battle-tested intuition about multi-agent failure modes, merge conflicts, and session recovery. They will stress-test the orchestration layer.

### Tertiary: Tool Builders

Engineers who will study the architecture and build:

- More accessible UIs on top of the platform
- Specialized adapters for new runtimes
- Domain-specific contract templates
- Custom eval fixtures for their industries
- Federation integrations with enterprise systems

**What they bring:** The long tail. Gas Town's real audience may be tool builders who take its patterns and make them accessible. The same applies here.

### Quaternary: Teams

Organizations that need coordinated AI-assisted development with:

- Audit trails (evidence-native architecture)
- Quality guarantees (structured QA reports with dimensional scoring)
- Compliance (sovereignty tiers, policy-driven behavior)
- Cost visibility (per-agent, per-task, per-runtime cost tracking)

**What they bring:** Enterprise requirements that push the platform toward production hardening.

---

## 5. What Success Looks Like

Success is measured by outcomes, not features. These metrics track whether the platform delivers on its promises.

### 5.1 Work Tracking Efficiency

| Metric | Definition | Target | Source |
|--------|-----------|--------|--------|
| Time to tracked work item | Seconds from user intent to work item in database with dependencies | <30s for decomposition, <5s for individual creation | Beads |
| Task evidence rate | % of completed tasks with attached evidence (screenshots, test results, contract diffs) | >95% | Platform (new) |
| Resume success rate | % of agent handoffs (context compaction, crash recovery) that successfully continue work | >90% | Gas Town GUPP |

### 5.2 Quality Metrics

| Metric | Definition | Target | Source |
|--------|-----------|--------|--------|
| Contract conformance rate | % of merged code that passes contract-auditor verification | >98% | ATSA |
| Merge rejection rate by gate | Rejections categorized by gate type (contract, design, review, test) | Trending down over time | Overstory + gstack |
| Design audit pass rate | % of UI changes passing 80-item design audit on first attempt | >80% | gstack |
| AI slop detection rate | % of slop patterns caught before merge (purple gradients, 3-column grids, etc.) | >95% | gstack |

### 5.3 Operational Metrics

| Metric | Definition | Target | Source |
|--------|-----------|--------|--------|
| Retry rate by worker profile | Retries per completed task, segmented by agent identity and runtime | <0.3 retries/task | Gas Town |
| Cost per successful work unit | Total LLM cost / successfully merged work items | Trending down over time | Overstory + Gas Town |
| Agent utilization rate | % of agent time spent on productive work vs. waiting, retrying, or stuck | >70% | Gas Town Witness |
| Mean time to conflict resolution | Average time from merge conflict detection to resolution | <60s for Tier 1-2, <300s for Tier 3 | Overstory |

### 5.4 Pipeline Validation Metrics

| Metric | Definition | Target | Source |
|--------|-----------|--------|--------|
| Eval regression rate | % of pipeline changes that degrade eval scores | <5% | gstack |
| False negative rate | % of real bugs that pass cognitive review undetected (measured via planted-bug fixtures) | <10% | gstack LLM-as-Judge |
| Gate escape rate | % of quality issues that pass all gates and are found in production | <2% | Platform (new) |

---

## 6. Design Principles

### 6.1 Clean-Sheet

This is not a fork of any existing platform. It is a new codebase built from first principles, informed by all five platforms.

- **Inspired by Beads** — not built on Dolt initially, but adopting its durability and query patterns
- **Inspired by Gas Town** — not using its Mad Max terminology, but adopting its supervision hierarchy and agent identity model
- **Inspired by Overstory** — not importing its TypeScript codebase, but adopting its runtime adapter interface and merge resolution tiers
- **Inspired by gstack** — not copying its skill files, but adopting its cognitive patterns and eval methodology
- **Inspired by ATSA** — not reusing its SKILL.md files, but adopting its contract templates and ownership semantics

The new platform takes the **architectural decisions** from each, not the **implementation details**.

### 6.2 Evidence-Native

Every agent action produces verifiable evidence. Not assertions — evidence.

| Action | Evidence Produced |
|--------|------------------|
| Code implementation | Git diff, test results, build output |
| Code review | Structured review document with findings, severity, and fix status |
| Design review | 80-item audit scorecard, screenshots (before/after), slop detection results |
| QA verification | qa-report.json with 5-dimension scores, reproduction steps, browser screenshots |
| Contract validation | Contract diff, conformance report, violation catalog |
| Merge | Merge strategy used, conflict details, resolution rationale |
| Agent handoff | Checkpoint JSON with unfinished work, context summary, successor instructions |

The system does not trust "done." It verifies. Evidence is a first-class object with links to the work that produced it, stored permanently in the evidence store.

### 6.3 Policy-Driven

Instead of relying on prompt engineering to constrain agent behavior, compile explicit policies from contracts, ownership maps, and quality requirements. Infrastructure prevents violations — agents cannot break rules because the system does not give them the opportunity.

| Policy Source | Enforcement Mechanism |
|--------------|----------------------|
| File ownership map | Guard rules that prevent writes outside owned directories |
| Contract specifications | Pre-merge hooks that run contract-auditor verification |
| Quality thresholds | Merge queue rejects work below configured QA scores |
| Workflow discipline | Protocol messages that enforce step ordering (brainstorm before build, test before merge) |
| Cost budgets | Rate limiting and runtime routing based on cost constraints |

Policies are declared, not coded. The policy compiler translates declarative rules into infrastructure-level enforcement.

### 6.4 Progressive Complexity

The system works with 1 agent or 30. It scales down to a personal tool and up to a team platform.

| Scale | Configuration | What Works |
|-------|--------------|------------|
| Solo (1 agent) | Single Claude Code session with skills | Contracts, cognitive patterns, QA reports, evidence |
| Small (2-5 agents) | Sequential subagent spawning | + File ownership, merge queue, basic monitoring |
| Medium (5-15 agents) | Parallel agents with tmux | + Mail system, watchdog, runtime mixing |
| Large (15-30+ agents) | Full orchestration with supervision hierarchy | + Federation, adaptive routing, worker scorecards |

No feature requires scale. Every feature available at 30 agents is also available at 1 (with appropriate simplification). Gas Town's graceful degradation — works with tmux or without, with patrol or manual slinging — is the model.

### 6.5 Self-Healing

When something goes wrong, the system diagnoses and corrects. Not just restarts — actual root cause analysis and corrective action.

| Failure Mode | Detection | Response |
|-------------|-----------|----------|
| Agent stuck (no progress) | Heartbeat timeout via watchdog | Progressive escalation: nudge, context injection, terminate + respawn with checkpoint |
| Agent in loop (repeating actions) | Pattern detection in tool call log | Terminate + respawn with anti-loop instruction and fresh context |
| Context exhaustion | Token usage monitoring | Automatic handoff via GUPP: checkpoint, spawn continuation, seance protocol |
| Merge conflict (irreconcilable) | Tier 3 failure | Escalate to Tier 4 (reimagine): respawn builder with spec + conflict context |
| Runtime failure (model API down) | Error classification | Failover to next adapter in the runtime preference chain |
| Quality regression | Eval score trending down | Reduce scope for affected agent, alert operator, adjust routing |
| Spawn loop | Circuit breaker (max respawns) | Block spawning, notify operator with diagnostic context |

Self-healing is not self-driving. The operator retains authority. But the system should handle the 80% of failures that have known remediation patterns, escalating only the 20% that require human judgment.

---

## 7. What We Are NOT Building

Clarity about scope prevents scope creep and sets accurate expectations.

### 7.1 Not a General-Purpose AI Assistant

This platform builds software. It does not answer questions, manage calendars, write emails, or chat. The agent roles are all software delivery roles: coordinator, builder, reviewer, merger, monitor, QA. There is no "assistant" mode.

OpenClaw occupies the general-purpose assistant niche. This platform does not compete with it.

### 7.2 Not a Replacement for Any Single Platform

This is a new synthesis, not a better version of Beads or Gas Town or Overstory or gstack or ATSA. Each existing platform will continue to evolve independently. Some may incorporate ideas from this platform. Some may diverge further. The relationship is inspiration, not competition.

### 7.3 Not Requiring All Features from Day One

The eight value propositions are the full vision. The initial build delivers a subset. The phased approach is:

| Phase | Scope | Value Propositions Delivered |
|-------|-------|----------------------------|
| 1 — Foundation | Work graph, contracts, single-agent execution | Durable work state, contract-first architecture |
| 2 — Intelligence | Cognitive patterns, QA pipeline, eval system | Cognitive quality intelligence, self-validating pipeline |
| 3 — Scale | Multi-agent orchestration, merge queue, monitoring | Persistent agent identity, intelligent merge resolution |
| 4 — Neutrality | Runtime adapters, mixed fleet routing | Runtime neutrality |
| 5 — Federation | Multi-instance sync, reputation, portable identity | Federation |

Each phase delivers standalone value. Phase 1 is useful without Phase 5. Phase 5 does not work without Phase 1.

### 7.4 Not a Hosted Service (Initially)

The platform is local-first. It runs on your machine, manages your agents, stores your work. There is no cloud service, no SaaS pricing, no vendor dependency.

Federation enables multi-instance sync, but each instance is sovereign. Your data stays on your machine unless you explicitly push it to a remote.

A hosted option may come later. But the architecture must be local-first, federable second, hosted third.

### 7.5 Not Simulating an Org Chart

Gas Town learned this lesson: operational coordination roles (dispatcher, merger, monitor) outperform SDLC personas (analyst, PM, architect, dev). The Mayor does not pretend to be a product manager — it is a dispatch system.

This platform uses operational roles. Agents have capabilities, not job titles. A "backend builder" is an agent with backend tools and ownership, not a persona pretending to be a backend engineer.

---

## 8. Architecture Preview

The full system architecture is specified in `02-system-architecture.md`. This section provides a conceptual preview for context.

### Layered Architecture

```
Layer 7: Operator Experience
  Control Plane API, Operator Console, Evidence Browser, Run Ledger

Layer 6: Organizational Learning
  Expertise Records, Merge Pattern Learning, Skill Self-Improvement, Agent CV Accumulation

Layer 5: Quality Assurance
  Contract Auditor, Cognitive Review, Design Audit, QA Reports, Eval System

Layer 4: Execution
  Git Worktree Isolation, Runtime Adapters, Mail System, Browser Automation

Layer 3: Dispatch
  Work Router, Agent Scorecards, Runtime Selection, Staggered Spawning

Layer 2: Policy
  Ownership Maps, Contract Enforcement, Quality Gates, Workflow Guards, Cost Budgets

Layer 1: Work Graph
  Durable Work State, Dependency Graph, Evidence Store, Checkpoint System
```

### Core Services

| Service | Responsibility | Inspired By |
|---------|---------------|-------------|
| **Work Graph Service** | CRUD for work items, dependency tracking, topological sort, evidence linking | Beads |
| **Policy Compiler** | Translates contracts, ownership maps, quality thresholds into enforceable rules | ATSA + Overstory |
| **Router** | Matches work items to agents based on capability, cost, and scorecard | Gas Town + Overstory |
| **Runtime Manager** | Manages agent lifecycle across adapters, handles failover | Overstory |
| **Merge Engine** | 4-tier conflict resolution with learning, contract verification at merge time | Overstory + Gas Town |
| **Quality Pipeline** | Cognitive review, design audit, QA reports, eval system | gstack + ATSA |
| **Evidence Store** | Permanent storage for screenshots, test results, review documents, contract diffs | Platform (new) |
| **Federation Service** | Peer-to-peer sync, reputation exchange, identity portability | Beads |

---

## 9. Open Questions

These are deliberate unknowns to be resolved during the build, not before it.

| Question | Options | Decision Deferred Until |
|----------|---------|------------------------|
| Primary implementation language | Go (match Beads/Gas Town), TypeScript (match Overstory/gstack), Rust (performance) | Phase 1 design |
| Database backend | Dolt (proven by Beads), SQLite (proven by Overstory), PostgreSQL (enterprise), hybrid | Phase 1 design |
| Naming theme | Station (space ops), Forge (crafting), Grove (solarpunk), Relay (network sci-fi), Weave (quantum/textile), neutral | Pre-Phase 1 |
| CLI design | Single binary (`xx`), multi-binary ecosystem (`xx`, `wg`, `ev`), subcommands (`xx work`, `xx agent`) | Phase 1 design |
| SKILL.md compatibility | Full ATSA format, agentskills.io standard, hybrid with migration | Phase 1 design |
| Browser integration | Compile Playwright binary (gstack approach), MCP browser server, native integration | Phase 2 design |
| Cost model | Free/OSS only, freemium with hosted federation, dual-license | Pre-Phase 5 |

---

## 10. Competitive Landscape

### What Exists and Where It Falls Short

| Category | Representative | Why It Is Not Enough |
|----------|---------------|---------------------|
| Agent frameworks | LangChain, CrewAI, AutoGen | SDK-level abstractions. No durable state, no merge system, no quality intelligence. |
| Coding agents | Claude Code, Cursor, Codex, Copilot | Single-session tools. No orchestration, no contracts, no persistent identity. |
| Task trackers | Linear, Jira, GitHub Issues | Human-centric. Not designed for agent consumption, no dependency graph for AI routing. |
| CI/CD | GitHub Actions, GitLab CI, Jenkins | Pipeline execution. No agent orchestration, no cognitive review, no adaptive routing. |
| AI orchestration | Gas Town, Overstory | Infrastructure without quality intelligence. |
| AI quality | gstack | Quality intelligence without infrastructure. |

### The Unfilled Niche

The system that combines:
- 30+ parallel agents (Gas Town)
- Each with browser access and cognitive review (gstack)
- Durable work state that survives crashes (Beads)
- Self-validating pipeline (gstack eval system)
- Runtime neutrality (Overstory)
- Contract-driven coordination (ATSA)
- Design-aware quality (gstack design intelligence)
- Federable state (Beads + Gas Town Wasteland)

This combination does not exist. Building it is the opportunity.

---

## 11. Source Material

This charter synthesizes findings from the following research:

| Source | Location | Documents |
|--------|----------|-----------|
| Gas Town deep dive | `gastown_deepdive/source-material/` | 12 documents covering architecture, roles, MEOW, GUPP, convoys, federation |
| Beads deep dive | `beads_deepdive/source-material/` | 12 documents covering data model, storage, dependencies, formulas, federation |
| Overstory deep dive | `overstory_deepdive/source-material/` | 12 documents covering agents, messaging, merge system, runtime adapters, watchdog |
| gstack deep dive | `gstack_deepdive/source-material/` | 13 documents covering cognitive patterns, eval system, design intelligence, browser |
| ATSA design spec | `docs/skill-ecosystem-design-spec.md` | Contract templates, ownership model, QA schema, build playbook |
| Claude research | `claude_research/` | Field guide covering OpenClaw, Gas Town, Beads, gstack, and ecosystem context |
| Platform comparison | `05-platform-comparison.md` | Cross-platform role mapping, naming analysis, functional requirements |

---

*This document defines the WHAT and WHY. The HOW is specified in `02-system-architecture.md`. The WHEN is specified in `03-build-program.md`. The WHERE (initial repo structure) is specified in `04-repo-bootstrap.md`.*
