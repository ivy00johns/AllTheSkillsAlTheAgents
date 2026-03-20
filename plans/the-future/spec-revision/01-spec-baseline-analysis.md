# Spec Baseline Analysis — The Hive Platform
**Generated:** 2026-03-20
**Scope:** All 17 documents in `/plans/the-future/spec/` (00-overview through 17-repo-bootstrap, including 05-platform-comparison)
**Purpose:** Structured inventory of coverage, gaps, open questions, and cross-reference integrity for revision planning

---

## Coverage Rating Key

| Rating | Meaning |
|--------|---------|
| **Comprehensive** | All major aspects specified with schemas, algorithms, examples, and edge cases |
| **Adequate** | Core design documented; some implementation details thin or missing |
| **Thin** | High-level intent present but critical specifics absent |
| **Stub** | Section exists but content is placeholder or incomplete |

---

## Document Entries

---

### 00 — Overview (`00-overview.md`, 196 lines)

**Coverage:** Adequate

**Key topics covered:**
- Document map with line counts for all 17 docs
- 4-tier reading guide (15 min / 1 hour / half day / full technical review)
- Architecture-at-a-glance 5-layer diagram
- Build plan summary table (7 phases, cost estimates)
- 8 differentiating features with source attribution
- 7 explicit open questions
- Source platform comparison table with strengths/weaknesses
- Key decisions to validate with document references

**Gaps / TODOs:**
- No mention of the `agentic-ui-dashboard/` spec set. The relationship between the dashboard specs and this platform spec is undocumented.
- The "Eight Things No One Else Has" list claims items are uniquely attributed to source platforms, but some attributes appear in multiple sources.

**Open questions flagged:**
1. Platform name (5 candidates scored, no pick)
2. Dolt vs SQLite-only fallback
3. Browser binary (ship Chromium or require system install)
4. Formula language (TOML vs YAML vs custom DSL)
5. Agent team pricing model (Claude Code Agent Teams vs tmux fleet)
6. Federation scope for 1.0
7. Eval rubric calibration

**Broken cross-references:**
- 05b numbering inconsistency (uses "05b" label but file is `05-platform-comparison.md`)

---

### 01 — Product Charter (`01-product-charter.md`, 537 lines)

**Coverage:** Adequate

**Key topics covered:**
- Problem statement: 5 partial solutions and their specific failure modes
- Vision statement and positioning
- 8 value propositions mapped to source platform origins
- Success metrics (fleet utilization, merge success rate, quality gate pass rate, cost per feature)
- 10 design principles

**Gaps / TODOs:**
- Success metrics stated as goals but no measurement methodology
- "Contracts precede code" principle has no reference to contract lifecycle in doc 15

**Broken cross-references:**
- `02-system-architecture.md` → should be `03-system-architecture.md`
- `03-build-program.md` → should be `16-build-program.md`
- `04-repo-bootstrap.md` → should be `17-repo-bootstrap.md`

---

### 02 — Naming System (`02-naming-system.md`, 867 lines)

**Coverage:** Comprehensive

**Key topics covered:**
- 5 naming theme candidates: Forge, Harbor, Grove, Hive, Studio
- Scoring across 7 criteria
- Complete 29-concept vocabulary mapping for each theme
- Scoring matrix with weighted totals

**Gaps / TODOs:**
- No final name selected — no decision process or owner indicated
- No trademark/domain availability discussion

**Open questions:** Final platform name selection

---

### 03 — System Architecture (`03-system-architecture.md`, 1,093 lines)

**Coverage:** Comprehensive

**Key topics covered:**
- 5-layer model with TypeScript interface definitions for each layer boundary
- Data store decision rationale: Dolt + 4 SQLite DBs
- Deployment topologies: solo developer, small team, enterprise
- 8 non-negotiable constraints
- Technology stack justification

**Gaps / TODOs:**
- Interface definitions not reconciled with `types.ts` in doc 17
- Deployment topology configuration differences not specified
- No schema migration/upgrade path discussed

---

### 04 — Role Taxonomy (`04-role-taxonomy.md`, 1,094 lines)

**Coverage:** Comprehensive

**Key topics covered:**
- 13 roles: 7 core + 6 extended
- Depth-limited hierarchy (max 3)
- Per-role tool access matrix with bash guards
- Agent identity model: CV, scorecard, routing weights
- Lifecycle state machine

**Gaps / TODOs:**
- Extended roles (6 of 13) have thin specs — no tool matrix, no bash guards, no CV schema
- Role-to-skill mapping implicit, not formal
- "Crew" role bypass mechanism unspecified

---

### 05 — Data Model (`05-data-model.md`, 1,187 lines)

**Coverage:** Adequate

**Key topics covered:**
- ~50-column `work_items` schema
- 22 dependency types with scheduling semantics
- Status state machine (8 states)
- MEOW workflow: Formula → Protomolecule → Molecule → Wisp
- Ready queue algorithm, gate system schema, hash-based IDs

**Gaps / TODOs:**
- **Schema divergence:** Column named `body` here but `description` in doc 12 — must resolve before implementation
- Formula engine execution semantics thin (`cook` vs `pour` distinction unclear)
- `hooked` and `pinned` status semantics thin

**Open questions:** Formula language (TOML vs YAML vs custom DSL)

---

### 05b — Platform Comparison (`05-platform-comparison.md`, 452 lines)

**Coverage:** Adequate

**Gaps / TODOs:**
- **Naming theme inconsistency:** Lists 5 sci-fi candidates (Station, Forge, Grove, Relay, Weave) different from doc 02's set (Forge, Harbor, Grove, Hive, Studio). Only Forge and Grove overlap. One is stale.

---

### 06 — Communication Model (`06-communication-model.md`, 1,215 lines)

**Coverage:** Comprehensive

**Key topics covered:**
- SQLite `mail.db` full schema
- 15 typed protocol messages with JSON payload schemas
- Two-channel model: persistent (SQLite) + real-time (nudge/tmux)
- Broadcast groups, hook-driven injection, nudge escalation, handoff protocol, convoy coordination

**Gaps / TODOs:**
- Mail delivery guarantees not specified (at-least-once? exactly-once? best-effort?)
- `inject` message type security implications not addressed
- Message ordering within a session not specified
- Heartbeat timing (30s) may conflict with watchdog stall detection in doc 13

---

### 07 — Merge System (`07-merge-system.md`, 1,185 lines)

**Coverage:** Comprehensive

**Key topics covered:**
- Batch-then-bisect algorithm with worked example
- 4-tier conflict resolution flowchart
- Pre-merge pipeline, post-merge learning
- Convoy integration, FIFO queue ordering

**Gaps / TODOs:**
- Tier 4 "AI reimagine" invocation interface not specified (model, prompt, validation)
- Convoy failure path (what if one item fails all 4 tiers?)
- Non-binary failure modes in bisect not specified

---

### 08 — Skill System (`08-skill-system.md`, 594 lines)

**Coverage:** Adequate

**Key topics covered:**
- 3-layer skill model, SKILL.md frontmatter schema
- 500-line body limit, guard rule enforcement
- Cognitive pattern injection, template generation, progressive disclosure

**Gaps / TODOs:**
- Composition validation algorithm absent
- Skill versioning upgrade semantics absent
- Cognitive pattern YAML format not defined (referenced but never shown)
- Compatibility with existing ATSA SKILL.md format not addressed

---

### 09 — Orchestration Engine (`09-orchestration-engine.md`, 1,372 lines)

**Coverage:** Comprehensive

**Key topics covered:**
- 8-step coordinator loop, 7-phase build playbook
- Sling mechanism (12-step dispatch), agent lifecycle
- Runtime degradation: fleet → subagent → sequential
- Circuit breaker, context management, hook-driven orchestration

**Gaps / TODOs:**
- **Decomposition algorithm absent** — the Plan phase has no heuristics or prompt template
- Context continuation prompt template not shown
- Runtime degradation detection mechanism unspecified
- 7-phase build playbook naming collision with 16-build-program.md phases

---

### 10 — Quality Intelligence (`10-quality-intelligence.md`, 696 lines)

**Coverage:** Comprehensive

**Key topics covered:**
- 41 cognitive patterns (CEO/Engineering/Design modes)
- 80-item design audit, 10 AI slop detection anti-patterns
- QA gate schema (5 dimensions, 1-5 scale)
- 3-tier eval system with cost estimates
- Expertise store, Browse CLI

**Gaps / TODOs:**
- Pattern injection YAML format undefined in this doc AND in doc 08
- QA scoring rubrics not calibrated (what is a "3" vs "4" in security_posture?)
- Browse CLI daemon management (startup, crash, resources) not specified
- Slop detection sync vs async not specified

**Open questions:** Eval rubric calibration, browser binary decision

---

### 11 — Runtime Adapters (`11-runtime-adapters.md`, 1,670 lines)

**Coverage:** Adequate (core) / Thin (experimental)

**Key topics covered:**
- RuntimeAdapter TypeScript interface, 9 adapter specs
- Claude Code (stable), Pi CLI (beta), Codex/Gemini (experimental)
- Auto-detection, mixed fleet config, guard rule translation

**Gaps / TODOs:**
- 5 of 9 adapters are stubs (Cursor, Copilot, Windsurf, Sapling, OpenCode)
- No-runtime-detected fallback behavior absent
- Pi CLI RPC message format not shown
- Adapter testing strategy absent

---

### 12 — Work Tracker (`12-work-tracker.md`, 1,240 lines)

**Coverage:** Comprehensive

**Key topics covered:**
- Dolt SQL connection config, full work_items schema
- 22 dependency types, ready queue CTE, atomic claim SQL
- Formula engine, gate system, compaction, wisp routing, CLI reference

**Gaps / TODOs:**
- **Column `description` here vs `body` in doc 05** — must resolve
- Ready queue CTE performance optimization path not designed
- Gate criteria JSON schema undefined
- Wisp vs broadcast mail distinction unclear

---

### 13 — Observability (`13-observability.md`, 1,513 lines)

**Coverage:** Comprehensive

**Key topics covered:**
- 4 SQLite database schemas, 24 typed event types
- Session state machine, 3-tier watchdog
- Dashboard mockup, audit trail, OTel integration, expertise store, alerting

**Gaps / TODOs:**
- DB initialization path not defined
- AI triage (Tier 1) prompt template and output format absent
- metrics.db retention policy absent
- Watchdog 30s check vs 30s heartbeat may cause false positives
- OTel instrumented spans/metrics not listed

---

### 14 — Federation (`14-federation.md`, 891 lines)

**Coverage:** Adequate

**Key topics covered:**
- Dolt remote protocol, 3 sovereignty tiers, 6 backends
- Table-by-table federation classification, cross-instance routing
- Agent portability, content-addressed dedup

**Gaps / TODOs:**
- **Tier count inconsistency:** 3 tiers here vs T4 "anonymous" referenced in doc 16
- Conflict resolution for federated Dolt merges thin
- Peer discovery config format absent
- Agent data privacy implications not addressed
- Offline cross-instance dependency resolution absent

**Open questions:** Federation scope for 1.0

---

### 15 — Contract System (`15-contract-system.md`, 1,191 lines)

**Coverage:** Comprehensive

**Key topics covered:**
- 6 contract types with examples (OpenAPI, AsyncAPI, TypeScript, Pydantic, JSON Schema, Data Layer)
- Contract lifecycle (6 phases), file ownership system
- Contract authoring process, audit checks, versioning

**Gaps / TODOs:**
- Pydantic contracts included but platform is TypeScript — rationale unstated
- Contract distribution mechanism absent (registry? git? worktree copy?)
- Breaking change detection algorithm not specified
- File ownership enforcement implementation not in this doc or doc 07
- Data layer YAML contract type least specified

---

### 16 — Build Program (`16-build-program.md`, 594 lines)

**Coverage:** Adequate

**Key topics covered:**
- 7 phases with deliverables, effort estimates, acceptance criteria
- Mermaid Gantt chart, critical path analysis
- Parallelization opportunities, dogfooding acceleration
- Risk register (R1-R10), team sizing

**Gaps / TODOs:**
- Phase AC test locations and framework not referenced
- Cost estimates exclude infrastructure costs
- R9 skill format adapter not specified in doc 08
- **T4 sovereignty tier reference** not defined in doc 14
- No dashboard phase — dashboard spec exists separately but is unreferenced

---

### 17 — Repo Bootstrap (`17-repo-bootstrap.md`, 2,271 lines)

**Coverage:** Comprehensive

**Key topics covered:**
- Complete directory structure, config files (package.json, tsconfig, bunfig, biome)
- Full `src/core/types.ts` with all shared interfaces
- CLAUDE.md, AGENTS.md, GEMINI.md structures
- CI/CD workflow, contributing guide, module index files

**Gaps / TODOs:**
- types.ts WorkItemStatus must match doc 05 exactly
- CLAUDE.md doesn't link to doc 16 for phase acceptance criteria
- Directory skeleton includes all phases at Phase 0 (intent unclear)
- biome.json complexity threshold (25) may produce noise on complex functions

---

## Summary Table

| # | Document | Lines | Coverage | Critical Gaps | Open Questions |
|---|----------|------:|----------|--------------|----------------|
| 00 | Overview | 196 | Adequate | Dashboard spec relationship unstated | 7 |
| 01 | Product Charter | 537 | Adequate | 3 broken doc number refs | 0 |
| 02 | Naming System | 867 | Comprehensive | No final decision | 1 |
| 03 | System Architecture | 1,093 | Comprehensive | Interface-to-types.ts reconciliation | 1 |
| 04 | Role Taxonomy | 1,094 | Comprehensive | Extended role specs thin | 0 |
| 05 | Data Model | 1,187 | Adequate | `body` vs `description` column | 1 |
| 05b | Platform Comparison | 452 | Adequate | Naming candidates stale | 0 |
| 06 | Communication Model | 1,215 | Comprehensive | Mail delivery guarantees absent | 0 |
| 07 | Merge System | 1,185 | Comprehensive | AI reimagine invocation unspecified | 1 |
| 08 | Skill System | 594 | Adequate | Pattern YAML undefined; composition validation absent | 0 |
| 09 | Orchestration Engine | 1,372 | Comprehensive | Decomposition algorithm absent | 1 |
| 10 | Quality Intelligence | 696 | Comprehensive | Scoring rubrics uncalibrated | 2 |
| 11 | Runtime Adapters | 1,670 | Adequate | 5 of 9 adapters are stubs | 0 |
| 12 | Work Tracker | 1,240 | Comprehensive | Column divergence with doc 05 | 1 |
| 13 | Observability | 1,513 | Comprehensive | AI triage prompt absent; retention policy absent | 0 |
| 14 | Federation | 891 | Adequate | Tier count inconsistency (3 vs 4) | 1 |
| 15 | Contract System | 1,191 | Comprehensive | Contract distribution mechanism absent | 0 |
| 16 | Build Program | 594 | Adequate | No dashboard phase; T4 tier reference broken | 0 |
| 17 | Repo Bootstrap | 2,271 | Comprehensive | Phase-to-AC linkage in CLAUDE.md | 0 |

---

## Prioritized Critical Gaps

### P0 — Blockers (Must resolve before writing any code)

**P0-1: Column name divergence: `body` vs `description`**
- Documents: 05-data-model.md vs 12-work-tracker.md
- Risk: work_items schema disagrees on primary text field name. Any implementation reading both specs produces broken SQL.
- Resolution: Pick one name, update the other, update types.ts.

**P0-2: Sovereignty tier count: 3 tiers vs 4 tiers**
- Documents: 14-federation.md (3 tiers) vs 16-build-program.md Phase 6 (references T4: anonymous)
- Resolution: Either add T4 to doc 14 with full spec, or remove T4 from doc 16.

**P0-3: Naming theme candidate set inconsistency**
- Documents: 02-naming-system.md (Forge, Harbor, Grove, Hive, Studio) vs 05-platform-comparison.md (Station, Forge, Grove, Relay, Weave)
- Resolution: Update 05-platform-comparison.md to reference doc 02's candidates, or mark its naming section as superseded.

### P1 — High Priority (Resolve before Phase 2)

**P1-1: Cognitive pattern injection YAML format undefined**
- Documents: 10-quality-intelligence.md, 08-skill-system.md
- Resolution: Define the pattern YAML schema in doc 08, add reference from doc 10.

**P1-2: Mail delivery guarantees not specified**
- Documents: 06-communication-model.md
- Resolution: Specify guarantee level and required schema additions.

**P1-3: Contract distribution mechanism absent**
- Documents: 15-contract-system.md §2
- Resolution: Specify how contracts reach agent worktrees.

**P1-4: Decomposition algorithm absent from orchestration engine**
- Documents: 09-orchestration-engine.md §2
- Resolution: Add heuristics and prompt template for the Plan phase.

**P1-5: No-runtime-detected behavior undefined**
- Documents: 11-runtime-adapters.md
- Resolution: Add fallback behavior specification.

### P2 — Medium Priority (Resolve before Phase 3-4)

**P2-1:** QA scoring rubrics not calibrated
**P2-2:** Tier 4 merge resolution (AI reimagine) invocation unspecified
**P2-3:** Gate criteria JSON schema undefined
**P2-4:** Extended role specifications thin (6 of 13 roles)
**P2-5:** AI triage prompt template absent

### P3 — Lower Priority (Resolve before Phase 5-6)

**P3-1:** Broken cross-references in doc 01 (3 wrong doc numbers)
**P3-2:** metrics.db retention policy undefined
**P3-3:** Skill composition validation algorithm absent
**P3-4:** Context continuation prompt template missing
**P3-5:** Browse CLI daemon management unspecified

---

## Cross-Reference Integrity Summary

| Issue | Documents | Severity |
|-------|-----------|---------|
| `body` vs `description` column | 05 ↔ 12 | P0 — blocking |
| Sovereignty tier count (3 vs 4) | 14 ↔ 16 | P0 — blocking |
| Naming candidate set divergence | 02 ↔ 05b | P0 — stale content |
| Wrong document numbers | 01 §8 + footer | P3 — cosmetic |
| Session state machine canonical source | 04 ↔ 13 | P2 — verify identity |
| Pattern injection format | 08 ↔ 10 | P1 — missing spec |
| Heartbeat timing vs stall detection | 06 ↔ 13 | P2 — verify reconciliation |
| Build playbook vs build program phases | 09 ↔ 16 | P3 — naming collision |

---

*18 documents reviewed. 19 specific gaps identified and prioritized. 8 cross-reference issues catalogued.*
