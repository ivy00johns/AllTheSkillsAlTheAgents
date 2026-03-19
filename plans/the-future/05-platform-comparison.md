# 05 - Platform Comparison: Components, Roles, and Naming Conventions

Cross-reference of every platform we are drawing from — their components,
agent roles, work abstractions, naming patterns, and thematic choices.
Use this document when designing the naming system and role taxonomy for
the future platform.

## At a Glance

| Dimension | Gas Town | Overstory | gstack | ATSA (this repo) |
|-----------|----------|-----------|--------|-------------------|
| Author | Steve Yegge | Jaymin West | Garry Tan | johns |
| Language | Go (377k LoC) | TypeScript/Bun (96k LoC) | TypeScript/Bun | TypeScript |
| CLI | `gt` | `ov` | `browse` | slash commands |
| Theme | Mad Max / Waterworld / Slow Horses | Forest ecology (os-eco) | Corporate org chart | Technical/neutral |
| Naming style | Evocative nouns | Hierarchical verbs | Job titles as commands | `{domain}-agent` |
| Data plane | Beads (Dolt SQL) | Seeds (git-native JSON) | None (stateless) | Contracts (OpenAPI/JSON) |
| Storage | Dolt SQL Server | 4 SQLite DBs | Filesystem + JSONL | Filesystem |
| Agent count | 20-30+ concurrent | 10+ concurrent | 1 (single session) | N (parallel subagents) |
| Runtimes | 10+ (Claude, Gemini, Codex, Cursor, Pi, etc.) | 9 adapters | Claude Code only | Claude Code (+ degradation) |

---

## Gas Town — Role Taxonomy

**Theme:** Post-apocalyptic industrial town. Roles named after Mad Max
(Polecats, Guzzoline, Refinery), Waterworld (Deacon), and Slow Horses (Dogs).

### Town-Level Roles (Cross-Project)

| Role | Count | Purpose | Lifecycle | Key Commands |
|------|-------|---------|-----------|-------------|
| **Overseer** | 1 | Human operator, the boss | Permanent | Direct interaction |
| **Mayor** | 1 per town | Chief of staff, coordinates work, kicks off convoys | Persistent | `gt mayor attach/start` |
| **Deacon** | 1 per town | Town-level watchdog daemon, propagates DYFJ signal | Persistent | `gt deacon patrol` |
| **Boot** | 1 special Dog | Checks on Deacon every 5 min | Ephemeral (5m ticks) | Daemon-triggered |
| **Dogs** | N per town | Deacon's infrastructure crew (backup, compaction, cleanup) | Ephemeral tasks | 7 dog formulas |

### Rig-Level Roles (Per-Project)

| Role | Count | Purpose | Lifecycle | Key Commands |
|------|-------|---------|-----------|-------------|
| **Witness** | 1 per rig | Polecat supervisor, detects stuck/zombie agents | Persistent | `gt witness patrol` |
| **Refinery** | 1 per rig | Merge queue manager (Bors-style batch-then-bisect) | Persistent | `gt mq submit/list/process` |
| **Polecats** | N per rig | Ephemeral workers — receive work, do it, submit MR, die | Persistent identity, ephemeral sessions | `gt sling <bead> <rig>` |
| **Crew** | N per rig | Long-lived named agents for persistent collaboration | Persistent, user-managed | `gt crew add/attach` |

### Supervision Hierarchy

```
Overseer (You)
    |
    +-- Mayor -------------- Convoys, coordination
    |
    +-- Deacon ------------- Town-level watchdog
    |   +-- Boot ----------- Checks on Deacon
    |   +-- Dogs ----------- Infrastructure tasks
    |
    +-- Per-Rig:
        +-- Witness -------- Polecat supervisor
        |   +-- Polecats --- Ephemeral workers
        +-- Refinery ------- Merge queue
        +-- Crew ----------- Your personal agents
```

### Work Abstractions (MEOW Stack)

| Layer | Name | What It Is | Persistence |
|-------|------|-----------|-------------|
| 6 | **Formula** | TOML source definition of a workflow | Permanent (file) |
| 5 | **Protomolecule** | Frozen template made of beads | Permanent (beads in git) |
| 4 | **Molecule** | Active workflow instance (chain of beads) | Permanent (git-backed) |
| 3 | **Wisp** | Ephemeral molecule (not in git, burned after use) | Transient (DB only) |
| 2 | **Epic** | Hierarchical bead tree (parallel by default) | Permanent |
| 1 | **Bead** | Atomic work unit in Dolt SQL | Permanent |

Other named concepts: **Convoy** (multi-agent coordinated effort), **Rig** (one
managed project), **Guzzoline** (the pool of pending work), **Sling** (work
dispatch to a worker), **Hook Bead** (per-agent work queue).

---

## Overstory — Role Taxonomy

**Theme:** Forest ecology. The project name is a canopy metaphor. Ecosystem
tools are named Seeds, Mulch, and Canopy. Agent roles use generic hierarchy names.

### Agent Roles (Depth-Limited Hierarchy, max 3 levels)

| Role | Depth | Purpose | Can Spawn | Tools |
|------|-------|---------|-----------|-------|
| **Orchestrator** | 0 | Multi-repo coordinator of coordinators | Coordinators | Full |
| **Coordinator** | 0 | Single-project orchestrator | Leads | Full |
| **Lead** | 1 | Team coordination — decompose, delegate, verify | Scouts, Builders, Reviewers, Mergers | Full + `ov sling` |
| **Scout** | 2 (leaf) | Read-only codebase exploration | Nothing | Read, Glob, Grep, Bash (read-only) |
| **Builder** | 2 (leaf) | Implementation — code, tests, docs | Nothing | Read, Write, Edit, Glob, Grep, Bash |
| **Reviewer** | 2 (leaf) | Read-only validation, PASS/FAIL verdict | Nothing | Read, Glob, Grep, Bash (read-only) |
| **Merger** | 2 (leaf) | Merge conflict resolution specialist | Nothing | Full (merge-scoped) |
| **Monitor** | root (no worktree) | Continuous fleet health patrol | Nothing | Read-only + mail |

### Supervision Hierarchy

```
Orchestrator (multi-repo)
    +-- Coordinator (per-project)
        +-- Lead
        |   +-- Scout (read-only exploration)
        |   +-- Builder (implementation)
        |   +-- Reviewer (validation)
        |   +-- Merger (conflict resolution)
        +-- Monitor (fleet patrol, no worktree)
```

### Ecosystem Tools (os-eco)

| Tool | CLI | Purpose | Data Store |
|------|-----|---------|-----------|
| **Overstory** | `ov` | Orchestration — spawn, coordinate, merge, observe | SQLite (4 DBs) |
| **Seeds** | `sd` | Issue tracking — git-native, dependency-aware | `.seeds/` JSON files |
| **Mulch** | `ml` | Expertise — patterns, decisions, knowledge base | `.mulch/` records |
| **Canopy** | `cn` | Prompts — versioned, inheritable, profile-aware | `.canopy/` templates |

### Communication & Coordination

| Mechanism | How It Works |
|-----------|-------------|
| **Mail** | SQLite-backed message bus (~1-5ms), typed protocol messages |
| **Broadcast** | `@all`, `@builders`, `@scouts`, `@leads` group addresses |
| **Nudge** | Direct tmux injection for stalled agents (progressive escalation) |
| **Sling** | `ov sling` — creates worktree + tmux session + overlay |
| **Checkpoint** | JSON snapshot for context handoff on compaction/crash |

### Merge System (4 Tiers)

| Tier | Strategy | When |
|------|----------|------|
| 1 | Clean merge (no conflicts) | Default |
| 2 | Auto-resolve (non-overlapping) | Minor conflicts |
| 3 | AI-assisted resolution | Semantic conflicts |
| 4 | Reimagine (agent rewrites) | Irreconcilable |

---

## gstack — Role Taxonomy

**Theme:** Corporate engineering org chart. Each role is a slash command.
No orchestration — roles are invoked one at a time in a single Claude Code session.

### Planning Roles

| Role | Command | Patterns | Output |
|------|---------|----------|--------|
| **CEO / Founder** | `/plan-ceo-review` | 14 (Bezos, Grove, Munger, Horowitz...) | Strategic recommendations, scope decisions |
| **Eng Manager** | `/plan-eng-review` | 15 (McKinley, Brooks, Beck, Majors...) | ASCII architecture, state machines, test matrices |
| **Senior Designer** | `/plan-design-review` | 12 (Rams, Norman, Zhuo, Gebbia, Ive...) | 80-item design audit, AI slop detection, DESIGN.md |

### Implementation Roles

| Role | Command | Key Behavior |
|------|---------|-------------|
| **Staff Engineer** | `/review` | Two-pass (CRITICAL + INFORMATIONAL), enum tracing, fix-first |
| **Release Engineer** | `/ship` | 13-step automated pipeline, no confirmation dialogs |

### QA Roles

| Role | Command | Key Behavior |
|------|---------|-------------|
| **QA Lead** | `/qa` | 6-phase find-fix-verify with browser, health score 0-100 |
| **QA Reporter** | `/qa-only` | Same methodology, report-only, never touches code |
| **Designer Who Codes** | `/qa-design-review` | 80-item audit + CSS fixes + before/after screenshots |

### Support Roles

| Role | Command | Key Behavior |
|------|---------|-------------|
| **Retro Analyst** | `/retro` | Per-person breakdowns, velocity trends, hotspots |
| **Technical Writer** | `/document-release` | Auto-updates README, ARCHITECTURE, CHANGELOG |
| **Session Manager** | `/setup-browser-cookies` | Cookie import from Chrome/Arc/Brave/Edge |
| **Self-Updater** | `/gstack-upgrade` | Version check with snooze backoff |

### Unique Capabilities (No Equivalent Elsewhere)

- **Cognitive patterns** — 41 named patterns that activate latent LLM knowledge
- **AI slop detection** — 10 codified anti-patterns (purple gradients, 3-column grids, etc.)
- **Design system inference** — Extracts fonts, colors, spacing from live running site
- **Browser-native QA** — Playwright with persistent daemon, real authenticated sessions
- **Review readiness dashboard** — Gates `/ship` on completed reviews
- **3-tier eval system** — Free, E2E (~$3.85), LLM-judge (~$0.15)

---

## AllTheSkillsAllTheAgents (This Repo) — Role Taxonomy

**Theme:** Technical/neutral. Roles follow a `{domain}-agent` naming pattern.
Architecture is contract-first with declarative file ownership.

### Orchestration

| Component | Purpose |
|-----------|---------|
| **Orchestrator** | 14-phase build playbook, runtime detection, contract-first coordination |
| **Contract Author** | Generates contracts from templates (OpenAPI, AsyncAPI, Pydantic, TypeScript, JSON Schema) |
| **Contract Auditor** | Verifies implementations match contracts |

### Implementation Agents (9 roles)

| Agent | Owns | Key Concern |
|-------|------|-------------|
| **backend-agent** | `services/`, `packages/shared/` | REST/GraphQL APIs, business logic, data layers |
| **frontend-agent** | `apps/`, `packages/ui/` | React/Vue/Svelte, client-side state, routing |
| **infrastructure-agent** | `infra/`, CI/CD configs | Docker, Kubernetes, deployment scripts |
| **qe-agent** | `tests/`, QA reports | Contract conformance, integration, adversarial testing |
| **security-agent** | Security audit scope | OWASP compliance, auth review, vulnerability scanning |
| **docs-agent** | `docs/` | READMEs, API docs, changelogs, onboarding guides |
| **observability-agent** | Monitoring configs | Logging, metrics, tracing, health checks |
| **db-migration-agent** | `migrations/`, seed data | Schema evolution, seed data management |
| **performance-agent** | Load test scripts | k6, NeoLoad, benchmarks, baselines |

### Meta / Support Skills

| Skill | Purpose |
|-------|---------|
| **skill-writer** | Generates new SKILL.md files per frontmatter spec |
| **project-profiler** | Codebase analysis -> CLAUDE.md + profile.yaml |
| **code-reviewer** | Structured review with rubric scoring |
| **context-manager** | Session handoffs at ~80% context usage |
| **deployment-checklist** | Pre-deploy gate verification |

### Key Design Principles

- **File ownership is exclusive** — no two agents can own the same file
- **QE gates the build** — qa-report.json blocks on CRITICAL or low scores
- **Two-runtime degradation** — Agent Teams -> subagents -> sequential
- **Progressive disclosure** — frontmatter (~100 tokens), body on trigger, references on demand

---

## Cross-Platform Role Mapping

What each platform calls the same functional concern:

| Function | Gas Town | Overstory | gstack | ATSA |
|----------|----------|-----------|--------|------|
| **Top-level orchestrator** | Mayor | Orchestrator / Coordinator | (none — single session) | Orchestrator |
| **Work dispatcher** | Sling (`gt sling`) | Sling (`ov sling`) | (none) | Agent tool dispatch |
| **Implementation worker** | Polecat | Builder | (implicit — Claude does it) | backend/frontend/infra-agent |
| **Code reviewer** | (in Polecat workflow) | Reviewer | Staff Engineer (`/review`) | code-reviewer |
| **Merge manager** | Refinery | Merger + merge queue | Release Engineer (`/ship`) | (manual / git) |
| **Health monitor** | Witness + Deacon | Monitor + watchdog | (none) | (none) |
| **QA / testing** | (in Polecat workflow) | (in Builder workflow) | QA Lead (`/qa`) | qe-agent |
| **Design review** | (none) | (none) | Senior Designer (`/plan-design-review`) | (none) |
| **Strategic review** | (none) | (none) | CEO (`/plan-ceo-review`) | (none) |
| **Security audit** | (none) | (none) | (none) | security-agent |
| **Documentation** | (none) | (none) | Technical Writer (`/document-release`) | docs-agent |
| **Issue tracking** | Beads (`bd`) | Seeds (`sd`) | (none) | (none) |
| **Expertise/memory** | (none) | Mulch (`ml`) | (none) | (none) |
| **Prompt management** | Formulas (TOML) | Canopy (`cn`) | Templates (.tmpl) | SKILL.md files |
| **Browser automation** | (none) | (none) | `browse` (50+ commands, Playwright) | (none) |
| **Work unit** | Bead | Task (seed) | (none — stateless) | WorkItem |
| **Workflow template** | Formula -> Protomolecule -> Molecule | (none) | Skill templates | SKILL.md + contracts |
| **Ephemeral work** | Wisp | (none) | (none) | (none) |

---

## Naming Pattern Analysis

### What Works

| Pattern | Example | Why It Works |
|---------|---------|-------------|
| Metaphor consistency | Gas Town: everything is industrial/fuel | Names reinforce each other, memorable |
| Function-telegraphing | gstack: `/review`, `/ship`, `/qa` | Zero learning curve, self-documenting |
| Ecosystem coherence | Overstory: Seeds, Mulch, Canopy | Nature theme makes tool relationships intuitive |
| Short CLIs | `gt`, `ov`, `sd`, `ml`, `cn` | Fast to type, easy to compose in pipes |

### What Doesn't Work

| Pattern | Example | Why It Fails |
|---------|---------|-------------|
| Fossil fuel metaphor | Gas Town, Guzzoline, Refinery | Cognitive dissonance with green/future tech |
| Insider references | Polecat (Mad Max), Deacon (Waterworld) | Requires tribal knowledge to understand function |
| Generic hierarchy | Overstory: Coordinator, Lead, Builder | Functional but forgettable, no personality |
| Verbose agents | ATSA: `infrastructure-agent`, `observability-agent` | Accurate but long, no mnemonic hook |

---

## Functional Capabilities the Future Platform Needs

Synthesized from all four platforms — what roles/components must exist
regardless of what we name them:

### Core Roles (must have)

1. **Operator** — the human
2. **Coordinator** — top-level orchestrator that decomposes work
3. **Dispatcher** — routes work to the right worker with the right context
4. **Worker** — implements code (needs specialization: backend, frontend, infra, etc.)
5. **Reviewer** — validates work (code review, design review, QA)
6. **Merger** — manages branch integration and conflict resolution
7. **Monitor** — watches fleet health, detects stalls, escalates

### Extended Roles (high value, steal from specific platforms)

8. **Strategic Reviewer** — CEO-level product thinking (from gstack)
9. **Design Reviewer** — visual/UX audit with browser evidence (from gstack)
10. **Security Auditor** — OWASP compliance, auth review (from ATSA)
11. **QA with Browser** — find-fix-verify with real browser (from gstack)
12. **Technical Writer** — auto-update docs on release (from gstack)
13. **Maintenance Crew** — backup, compaction, cleanup (from Gas Town Dogs)

### Core Infrastructure (must have)

14. **Issue/Work Tracker** — durable state for tasks and dependencies
15. **Message Bus** — inter-agent communication
16. **Evidence Store** — screenshots, logs, traces, test results
17. **Expertise/Memory** — organizational learning across sessions
18. **Prompt/Skill System** — versioned, composable agent instructions
19. **Merge Queue** — automated branch integration with conflict resolution
20. **Policy Engine** — contracts, ownership, gates, escalation rules

---

## Sci-Fi Theme Candidates for Future Platform Naming

The naming system needs to cover ~20 concepts (13 roles + 7 infrastructure).
A good theme has enough vocabulary depth and clear metaphoric mapping to
each functional concern.

### Option A: Station (Space Station Operations)

NASA/Expanse feel. Disciplined, operational, professional.

| Function | Name | Reasoning |
|----------|------|-----------|
| Platform name | **Station** | Central hub, operational HQ |
| Operator | **Commander** | Obvious authority |
| Coordinator | **Flight Director** or **Mission Control** | Plans and sequences work |
| Dispatcher | **Capscom** | Communicates orders to crew |
| Worker (general) | **Specialist** | EVA Specialist, Systems Specialist |
| Reviewer | **Flight Surgeon** or **Inspector** | Validates before proceed |
| Merger | **Docking** | Bringing branches together |
| Monitor | **Telemetry** | Watches all systems |
| Work unit | **Mission** / **Sortie** | Discrete objective |
| Message bus | **Comms** | Inter-crew communication |
| Evidence store | **Ship's Log** | Permanent record |

### Option B: Forge (Crafting / Foundry Sci-Fi)

Creative, building-focused. Think Numenera or Destiny.

| Function | Name | Reasoning |
|----------|------|-----------|
| Platform name | **Forge** | Where things are made |
| Operator | **Archon** | Master smith, authority |
| Coordinator | **Crucible** | Where work is planned and shaped |
| Dispatcher | **Bellows** | Feeds work to the fire |
| Worker | **Smith** (Backend Smith, Interface Smith) | Crafters |
| Reviewer | **Assayer** | Tests purity/quality |
| Merger | **Alloy** | Combining separate works |
| Monitor | **Sentinel** | Watches the forge |
| Work unit | **Commission** / **Work** | Ordered creation |
| Message bus | **Herald** | Carries messages |
| Evidence store | **Codex** | Permanent record |

### Option C: Grove (Solarpunk / Ecological)

Green, organic, growth-focused. Extends Overstory's nature theme but goes further.

| Function | Name | Reasoning |
|----------|------|-----------|
| Platform name | **Grove** | Living, growing system |
| Operator | **Warden** | Steward of the grove |
| Coordinator | **Rootstock** | Foundation that feeds branches |
| Dispatcher | **Grafting** | Attaches work to workers |
| Worker | **Cultivator** / **Grafter** | Grows features |
| Reviewer | **Pruner** | Cuts what doesn't belong |
| Merger | **Harvest** | Gathering completed work |
| Monitor | **Mycelium** | Underground network sensing health |
| Work unit | **Seed** / **Graft** | Something that grows |
| Message bus | **Pollen** | Carries information |
| Evidence store | **Rings** (tree rings) | Growth record |

### Option D: Relay (Mass Effect / Network Sci-Fi)

Fast, networked, galactic scale. Sleek and modern.

| Function | Name | Reasoning |
|----------|------|-----------|
| Platform name | **Relay** | Connection point, speed |
| Operator | **Spectre** | Elite authority, acts independently |
| Coordinator | **Citadel** | Central governance hub |
| Dispatcher | **Beacon** | Sends signals to activate agents |
| Worker | **Operative** | Field agent doing the work |
| Reviewer | **Council** | Evaluates and judges |
| Merger | **Confluence** | Where streams join |
| Monitor | **Vigil** | Ancient watcher |
| Work unit | **Op** / **Mission** | Discrete objective |
| Message bus | **Quantum Link** | Instant communication |
| Evidence store | **Archive** | Permanent record |

### Option E: Weave (Quantum / Textile Sci-Fi)

Interconnected, pattern-based. Think Hyperion or quantum mechanics.

| Function | Name | Reasoning |
|----------|------|-----------|
| Platform name | **Weave** | Interconnected fabric of work |
| Operator | **Weaver** | Sees the whole pattern |
| Coordinator | **Loom** | Structures the work |
| Dispatcher | **Shuttle** | Carries thread through the warp |
| Worker | **Thread** / **Spindle** | Individual strand of work |
| Reviewer | **Inspector** | Checks the fabric |
| Merger | **Splice** | Joins threads |
| Monitor | **Tension** | Keeps the weave tight |
| Work unit | **Pattern** / **Filament** | Unit of creation |
| Message bus | **Weft** | Cross-thread communication |
| Evidence store | **Tapestry** | The completed record |

---

## Decision Criteria

When choosing a theme, weigh these factors:

| Criterion | Weight | Notes |
|-----------|--------|-------|
| **Vocabulary depth** | High | Need 20+ distinct, non-colliding names |
| **Function-telegraphing** | High | Names should hint at what things do |
| **Memorability** | High | Short, distinctive, easy to type as CLI commands |
| **Tone match** | Medium | Should match the product's identity (serious? playful? futuristic?) |
| **Extensibility** | Medium | Can we name future components without breaking the metaphor? |
| **Avoiding confusion** | Medium | Don't collide with existing tools (docker, k8s, git terminology) |
| **Green/future vibe** | Per user | Gas Town's fossil fuel metaphor is specifically what we're moving away from |

---

## Source Material Index

This analysis draws from the following deep dives:

| Deep Dive | Location | Docs |
|-----------|----------|------|
| Gas Town | `gastown_deepdive/source-material/` | 12 documents (01-12) |
| Beads | `beads_deepdive/source-material/` | 12 documents (01-12) |
| Overstory | `overstory_deepdive/source-material/` | 12 documents (01-12) |
| gstack | `gstack_deepdive/source-material/` | 13 documents (01-13) |
| Claude Research | `claude_research/` | Field guide to all four frameworks |
| Codex Research | `codex_research/overview/` | 9 documents (01-09) |
| Product Charter | `01-product-charter.md` | What we are building |
| System Architecture | `02-system-architecture.md` | Clean-sheet stack design |
| Build Program | `03-build-program.md` | Build order and phases |
| Repo Bootstrap | `04-repo-bootstrap.md` | Initial repo structure |
