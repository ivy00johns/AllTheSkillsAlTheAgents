# The Future Platform — Specification Overview

**19,662 lines across 17 documents. Start here.**

---

## What This Is

A complete specification for a clean-sheet AI agent orchestration platform — one that no one has built yet. It synthesizes the best ideas from five existing systems, each brilliant at one thing but none complete:

| Platform | Author | What It Does Best | What It Can't Do |
|----------|--------|-------------------|------------------|
| **Beads** | Steve Yegge | Dolt-backed durable work state, 22 dependency types, SQL-queryable task graph, federation | No quality intelligence. Tracks work but can't assess it. |
| **Gas Town** | Steve Yegge | 20-30+ concurrent agents, 8 worker roles, convoy orchestration, batch-then-bisect merge queue | No contracts. No design intelligence. Quality = "it compiles." |
| **Overstory** | Jaymin West | 9 runtime adapters, SQLite mail (~1-5ms), 4-tier merge resolution, hook-driven orchestrator | No structured QA. No cognitive patterns. No browser verification. |
| **gstack** | Garry Tan | 41 cognitive patterns, 80-item design audit, AI slop detection, 3-tier eval system | Single-session. Claude-only. Stateless. Can't scale past 1 agent. |
| **ATSA** | johns | Contract-first architecture, exclusive file ownership, 5-dimension QA scoring, 14-phase playbook | Pure prompt engineering. No runtime. No merge system. No persistence. |

**The structural gap:** Infrastructure platforms (Beads, Gas Town, Overstory) can run 30+ agents but have no quality brain. Intelligence platforms (gstack, ATSA) can make one agent think like a staff engineer but can't orchestrate a fleet. No one has unified both.

**What we're building:** An operating system for autonomous software delivery. One person describes what they want. The system decomposes it into tracked work, generates contracts, dispatches 30+ agents across multiple LLMs, runs cognitive review on every change, merges through a quality-gated pipeline, and produces verifiable evidence — not assertions.

---

## Architecture at a Glance

```
┌──────────────────────────────────────────────────────────────┐
│  Layer 1: Skill / Prompt Layer                                │
│  What agents know. How they think. Progressive disclosure.    │
├──────────────────────────────────────────────────────────────┤
│  Layer 2: Orchestration Layer                                 │
│  Who does what. Dispatch, lifecycle, coordination hierarchy.  │
├──────────────────────────────────────────────────────────────┤
│  Layer 3: Quality Layer                                       │
│  Whether the work is good enough. Review, audit, evals.       │
├──────────────────────────────────────────────────────────────┤
│  Layer 4: Work Layer                                          │
│  What needs doing. Issues, dependencies, merge queue.         │
├──────────────────────────────────────────────────────────────┤
│  Layer 5: Runtime Layer                                       │
│  Where agents execute. Multi-LLM adapters, isolation, comms.  │
└──────────────────────────────────────────────────────────────┘
```

**Tech stack:** TypeScript/Bun, Dolt SQL Server, SQLite (WAL mode), Commander.js CLI, tmux, Playwright, Handlebars templates.

---

## Eight Things No One Else Has

1. **Durable Work State** — Dolt-backed, versioned, SQL-queryable, federable (from Beads)
2. **Contract-First Architecture** — Machine-readable contracts before code, preventing integration failures (from ATSA)
3. **Cognitive Quality Intelligence** — 41 named thinking frameworks that activate latent LLM knowledge (from gstack)
4. **Runtime Neutrality** — 9+ adapters for mixed fleets: Claude leads + Pi builders + Codex scouts (from Overstory)
5. **Self-Validating Pipeline** — 3-tier evals, design audit, AI slop detection (from gstack)
6. **Persistent Agent Identity** — CVs accumulate across sessions, scorecards drive routing (from Gas Town)
7. **Intelligent Merge Resolution** — 4-tier conflict resolution with history-informed learning (from Overstory)
8. **Federation** — Multi-instance sync via Dolt remotes, portable agent identity (from Beads)

---

## Document Map

### Tier 1 — Vision & Strategy
*Read these first. They frame everything else.*

| # | Document | Lines | What You'll Learn |
|---|----------|------:|-------------------|
| 01 | [Product Charter](01-product-charter.md) | 537 | The problem (5 partial solutions), the vision (one unified platform), 8 value propositions, success metrics, design principles |
| 02 | [Naming System](02-naming-system.md) | 867 | 5 naming theme candidates (Forge, Harbor, Grove, Hive, Studio) scored across 7 criteria, with complete 29-concept vocabulary mapping for each |

### Tier 2 — Architecture
*The backbone. Read these to understand how the system is structured.*

| # | Document | Lines | What You'll Learn |
|---|----------|------:|-------------------|
| 03 | [System Architecture](03-system-architecture.md) | 1,093 | 5-layer model with interfaces between layers, data store decisions (Dolt vs SQLite vs git), deployment topologies, 8 non-negotiable constraints |
| 04 | [Role Taxonomy](04-role-taxonomy.md) | 1,094 | 13 agent roles (7 core + 6 extended), depth-limited hierarchy (max 3), per-role tool guards, identity model, lifecycle state machine |
| 05 | [Data Model](05-data-model.md) | 1,187 | ~50-column work item schema, 22 dependency types, status state machine, MEOW workflow templates (formula → protomolecule → molecule → wisp), ready queue algorithm |
| 05b | [Platform Comparison](05-platform-comparison.md) | 452 | Side-by-side comparison of all 5 source platforms — roles, work abstractions, naming, storage, agent counts |
| 06 | [Communication Model](06-communication-model.md) | 1,215 | SQLite mail bus, 15 typed protocol messages, broadcast groups, hook-driven injection, progressive nudge escalation, convoy coordination, handoff protocol |
| 07 | [Merge System](07-merge-system.md) | 1,185 | Batch-then-bisect merge queue, 4-tier conflict resolution (clean → auto → AI → reimagine), pre-merge pipeline, post-merge learning |

### Tier 3 — Subsystem Specs
*Deep specs for each subsystem. Read based on interest or review assignment.*

| # | Document | Lines | What You'll Learn |
|---|----------|------:|-------------------|
| 08 | [Skill System](08-skill-system.md) | 594 | 3-layer skill model (base + domain + overlay), SKILL.md anatomy, progressive disclosure, template generation, guard rules, composition validation |
| 09 | [Orchestration Engine](09-orchestration-engine.md) | 1,372 | Coordinator loop, 7-phase build playbook, sling dispatch mechanism, agent lifecycle, worktree isolation, circuit breaker, runtime degradation (fleet → subagents → sequential) |
| 10 | [Quality Intelligence](10-quality-intelligence.md) | 696 | 41 cognitive patterns (CEO/Eng/Design modes), 80-item design audit, AI slop detection, 3-tier eval system, QA gate schema, Browse CLI, expertise store |
| 11 | [Runtime Adapters](11-runtime-adapters.md) | 1,670 | RuntimeAdapter TypeScript interface, 9 adapter specs (Claude, Pi, Codex, Gemini, Cursor, Copilot, Windsurf, Sapling, OpenCode), auto-detection, mixed fleet config, fallback chains |
| 12 | [Work Tracker](12-work-tracker.md) | 1,240 | Full Dolt SQL schemas, 22 dependency types with scheduling semantics, ready queue CTE, atomic claim, formula engine (cook/pour/wisp), gate system, wisp routing, compaction |
| 13 | [Observability](13-observability.md) | 1,513 | 4 SQLite databases (mail, sessions, events, metrics), 3-tier watchdog, dashboard mockup, audit trail, OTel integration, expertise store, alerting rules |
| 14 | [Federation](14-federation.md) | 891 | Dolt remote protocol, 3 sovereignty tiers, peer-to-peer and hub-and-spoke topologies, cell-level merge, cross-instance work routing, agent portability |
| 15 | [Contract System](15-contract-system.md) | 1,191 | 6 contract types (OpenAPI, AsyncAPI, TypeScript, Pydantic, JSON Schema, data layer), contract lifecycle, file ownership enforcement, audit scoring rubric |

### Tier 4 — Build Program
*The execution plan. Read when ready to start building.*

| # | Document | Lines | What You'll Learn |
|---|----------|------:|-------------------|
| 16 | [Build Program](16-build-program.md) | 594 | 7 phases over 14 weeks, Gantt chart with dependencies, per-phase deliverables/acceptance criteria/team sizing, risk register, ~$280-550 total estimated cost |
| 17 | [Repo Bootstrap](17-repo-bootstrap.md) | 2,271 | Complete first-commit blueprint — directory structure, package.json, tsconfig.json, full types.ts, CLI setup, database modules, CLAUDE.md for self-building, CI/CD, contributing guide |

---

## Build Plan Summary

| Phase | Weeks | What You Get | Cost Est. |
|-------|-------|-------------|-----------|
| **0: Foundation** | 1-2 | CLI skeleton, Dolt + SQLite, shared types, config | $15-25 |
| **1: Work Layer** | 2-4 | Durable issue tracker with dependency graph and formulas | $30-60 |
| **2: Orchestration** | 4-6 | Multi-agent builds — spawn, dispatch, coordinate, merge | $50-100 |
| **3: Quality** | 6-8 | Cognitive review, contract enforcement, design audit, evals | $40-70 |
| **4: Merge & Integration** | 8-10 | Batch-then-bisect queue, 4-tier resolution, convoys | $45-75 |
| **5: Runtime Neutrality** | 10-12 | Mixed LLM fleets with fallback chains | $40-80 |
| **6: Federation & Scale** | 12-14 | Multi-instance sync, watchdog, dashboard, production monitoring | $80-150 |
| **Total** | **14 weeks** | **Complete platform** | **$280-550** |

**MVP at Phase 2** (~$50-100, 6 weeks): multi-agent builds with durable work tracking.
**Dogfooding from Phase 2**: the platform builds itself from Phase 3 onward.
**Critical path**: Phase 0 → 1 → 2 → 3 → 4 → 6 (Phases 3 and 5 can overlap).

---

## Review Plan

### If you have 15 minutes
Read **01-product-charter.md** sections 1-3 (the problem, the vision, eight value propositions). This gives you the full picture of why this platform needs to exist and what makes it different.

### If you have 1 hour
Read the Tier 1 docs (01, 02) plus **03-system-architecture.md** sections 1, 3, and 8 (layer overview, data store decisions, non-negotiables). This covers vision + architecture.

### If you have a half day
Read Tier 1 (01, 02) + Tier 2 (03-07). This is the complete architectural foundation — you'll understand every major design decision.

### For a full technical review
Work through the tiers in order. Each tier builds on the previous:

1. **Tier 1** (01-02): Align on vision and naming before reading specs
2. **Tier 2** (03-07): Validate architecture decisions and cross-references
3. **Tier 3** (08-15): Deep-dive each subsystem — these can be reviewed in parallel by different reviewers
4. **Tier 4** (16-17): Validate build sequence and bootstrap feasibility

### Key decisions to validate

| Decision | Where It's Specified | Why It Matters |
|----------|---------------------|----------------|
| Dolt as primary data store | 03 §3, 12 §2 | Core durability bet — if Dolt performance doesn't hold, the architecture shifts |
| Depth-limited hierarchy (max 3) | 04 §3 | Prevents runaway agent spawning but limits flexibility |
| File ownership is exclusive | 03 §4, 15 §4 | Prevents merge conflicts but requires careful upfront planning |
| FIFO merge queue (not priority) | 07 §1 | Simpler and avoids starvation, but high-priority work waits |
| Hook-driven orchestrator | 09 §1 | Your session IS the orchestrator — no daemon, but ties coordination to session liveness |
| Quality gates block merges | 03 §8, 10 §8 | Ensures quality but could bottleneck throughput |
| Contract-first (always) | 15 §1 | Prevents integration failures but adds upfront overhead |
| TypeScript/Bun | 03 §7 | Matches Overstory/gstack ecosystem but not Gas Town/Beads (Go) |

---

## Research Foundation

The specs are synthesized from 60+ research documents across 6 deep dives:

```
plans/the-future/
├── spec/                    ← You are here (17 specification documents)
├── beads_deepdive/          ← 12 docs on Dolt-backed work state
├── gastown_deepdive/        ← 12 docs on multi-agent orchestration
├── overstory_deepdive/      ← 12 docs on runtime adapters and merge
├── gstack_deepdive/         ← 13 docs on cognitive patterns and quality
├── codex_research/          ← 10 docs on system atlas and gap analysis
└── claude_research/         ← Claude platform analysis
```

Every design decision traces back to a specific source platform and research document. The spec documents include provenance tables where applicable.

---

## Open Questions

### Resolved

1. ~~**Platform name**~~ → **The Hive.** Confirmed 2026-03-20. See `claude_research/project-names.md` for the complete naming vocabulary.
2. ~~**Dolt vs SQLite-only**~~ → **Service-hosted architecture.** PostgreSQL + Valkey + ClickHouse alongside Dolt for the work graph. Resolved 2026-03-20 based on gap research alignment with scaffold.
4. ~~**Formula language**~~ → **TOML.** Both source systems (Beads, Gastown) use TOML. Spec already uses TOML with complete examples.

### Still Open

3. **Browser binary** — Ship compiled Chromium (~58MB) or require system install?
5. **Agent team pricing** — Claude Code Agent Teams vs tmux-based fleet (cost model differs)
6. **Federation scope for 1.0** — Full federation or defer to post-1.0?
7. **Eval rubric calibration** — LLM-as-judge rubrics need real-world calibration data

---

## Architecture Decisions (Resolved 2026-03-20)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Deployment model | Service-hosted (Fastify, Postgres+Valkey+ClickHouse, Docker) | Gap research built on scaffold, not spec |
| Dashboard process | `platform serve` — TypeScript serves HTTP directly | Zero new architecture with existing Fastify services |
| AG-UI protocol | External only — adapter at dashboard boundary | Internal events stay Hive-native; AG-UI for external consumers |
| Platform name | **The Hive** | Confirmed. Build target: `~/AI/The-Hive` |
| Dashboard DB | The Glass reads spec DBs + maintains own UI DB | Clean separation; Glass can be rebuilt without touching operational data |

See `spec-revision/00-master-revision-plan.md` for full decision rationale.

---

*This overview was generated from the complete spec set. For detailed technical content, follow the document map above.*
