# 12 — The Convergence Opportunity

## What Exists Today

Four systems, each solving a different piece of the puzzle:

| System | Lines | Language | What It Does | What It Can't Do |
|--------|-------|----------|-------------|-----------------|
| **gastown** | 377k+ | Go | Orchestrate 20–50+ agents | Think about quality |
| **beads** | 100k+ | Go | Track work + dependencies | Do the work |
| **gstack** | 30k+ | TypeScript | Quality reviews + browser QA | Scale past 1 agent |
| **AllTheSkills** | ~5k | Markdown | Define agent contracts + roles | Execute anything |

## What No One Has

An integrated system where:

1. **30 agents** work in parallel on different parts of a codebase
2. Each agent has a **headless browser** and can QA its own work
3. Every code change goes through **cognitive review** (not checklists)
4. All work is tracked as a **dependency graph** with semantic compaction
5. **Contracts** prevent 42% of integration failures before they happen
6. The **merge queue** runs automated review before landing code
7. **Design intelligence** catches AI slop and enforces design systems
8. The **eval system** validates the pipeline itself
9. **Multi-runtime** support means Claude, Gemini, Codex agents coexist
10. Everything is **completeness-first** — lakes get boiled

## The Mega-System Architecture

```
┌──────────────────────────────────────────────────────┐
│                    THE TOWN (gastown)                  │
│                                                        │
│  Mayor ←─ Orchestrates via convoys + beads            │
│  Deacon ←─ Health monitoring + plugin execution       │
│                                                        │
│  ┌─── Rig: Project A ────────────────────────────┐   │
│  │                                                │   │
│  │  Polecat-1 (claude)           Polecat-2 (gemini)│  │
│  │  ├── gstack /review loaded    ├── gstack /qa    │  │
│  │  ├── browse CLI available     ├── browse CLI    │  │
│  │  ├── cognitive patterns       ├── find-fix-verify│ │
│  │  └── beads integration        └── beads tracking│  │
│  │                                                │   │
│  │  Polecat-3 (claude)           Polecat-4 (codex) │  │
│  │  ├── backend-agent role       ├── frontend-agent│  │
│  │  ├── contracts consumed       ├── contracts     │  │
│  │  └── beads tracking           └── beads tracking│  │
│  │                                                │   │
│  │  Refinery                     Witness           │  │
│  │  ├── /review before merge     ├── Health monitor│  │
│  │  ├── Design lite check        ├── GUPP enforce  │  │
│  │  └── Contract conformance     └── Recovery      │  │
│  │                                                │   │
│  │  Beads (Dolt)                                  │   │
│  │  ├── All issues as dependency graph            │   │
│  │  ├── Review findings tracked                   │   │
│  │  ├── QA bugs tracked                           │   │
│  │  ├── Semantic compaction                       │   │
│  │  └── Gates for review → ship coordination      │   │
│  │                                                │   │
│  │  Contracts (AllTheSkills)                      │   │
│  │  ├── Shared types                              │   │
│  │  ├── API contract                              │   │
│  │  ├── Data layer contract                       │   │
│  │  └── File ownership map                        │   │
│  └────────────────────────────────────────────────┘   │
│                                                        │
│  Eval System (gstack)                                 │
│  ├── Validates agent behavior                         │
│  ├── Diff-based test selection                        │
│  ├── LLM-as-judge for quality                         │
│  └── Regression detection                             │
└──────────────────────────────────────────────────────┘
```

## The 10 Convergence Points

### 1. gstack browse CLI → gastown polecats
Every polecat gets a browse binary. Agents can navigate, screenshot,
fill forms, verify UI. The ref system works in any runtime.

**Impact:** Agents that can SEE. QA isn't a separate phase — every agent
validates its own UI changes before marking work complete.

### 2. gstack cognitive patterns → gastown agent templates
Polecat CLAUDE.md templates include cognitive patterns:
- Backend polecats think like McKinley (boring by default) + Kernighan
- Frontend polecats think like Rams (subtraction) + Norman (3 levels)
- QA polecats think like Grove (paranoid scanning) + Munger (inversion)

**Impact:** Every agent thinks deliberately, not generically.

### 3. gstack /review → gastown Refinery
The Refinery runs `/review` on every polecat's work before merging.
Two-pass review (CRITICAL + INFORMATIONAL), auto-fix, enum completeness.

**Impact:** No code lands without cognitive review. Merge quality
goes from "it compiles" to "a staff engineer approved this."

### 4. beads → gstack review persistence
Review findings, QA bugs, and design issues become beads:
- `/review` finding → `bd create --type bug --deps discovered-from:BD-42`
- `/qa` bug → bead with screenshots attached as notes
- Design issue → bead linked to design regression tracking

**Impact:** Nothing gets lost. Reviews produce tracked, prioritized work.

### 5. AllTheSkills contracts → gastown polecats
Contract-first architecture prevents integration failures:
- Shared types authored before agents spawn
- Each polecat receives its relevant contract
- Contract auditor validates before merge

**Impact:** 42% fewer integration bugs in parallel agent builds.

### 6. gstack eval system → gastown plugin
The eval system becomes a gastown plugin that validates agent behavior:
- Planted-bug fixtures test polecat review quality
- E2E evals run periodically via Deacon patrol
- Regression alerts when agent quality degrades

**Impact:** The pipeline validates itself. Quality is monitored, not assumed.

### 7. beads formulas → gstack workflows
gstack's hardcoded skill workflows become beads formulas:
- `/ship` as a formula with gates (review → test → version → PR)
- `/qa` as a formula with tiers (quick → standard → exhaustive)
- Review pipeline as a formula (CEO → Eng → Design → Ship)

**Impact:** Workflows become composable, trackable, and gate-aware.

### 8. gstack design intelligence → all agents
Design system inference runs once, saves DESIGN.md. All agents read it:
- Frontend polecats constrained to the design system
- QA polecats verify against the design system
- Refinery checks for design regression before merging

**Impact:** Visual consistency enforced across 30 agents.

### 9. gastown seance → gstack review history
When a polecat queries a previous session's decisions (seance),
it can also query the review dashboard and design regression data.

**Impact:** Past quality decisions inform future agent behavior.

### 10. Completeness principle → gastown scope decisions
The Mayor applies the completeness principle when breaking down work:
- "This feature is a lake. Assign all edge cases, don't cut corners."
- "This migration is an ocean. Scope to the critical path."

**Impact:** Scope decisions are principled, not arbitrary.

## What This System Can Do That Nothing Else Can

1. **30 agents building a full-stack app in parallel**, each with browser
   access, cognitive review patterns, and tracked work items

2. **Zero integration failures** from contracts + automated conformance checking

3. **Design consistency** across all agent output via inferred design system

4. **Self-validating pipeline** via eval system monitoring agent quality

5. **Persistent knowledge** across sessions via beads — nothing gets lost

6. **Autonomous quality gates** — merge queue runs cognitive review, not just
   "does it compile"

7. **Multi-runtime** — Claude, Gemini, Codex agents working together with
   the same quality standards

8. **Semantic compaction** — old work summarized, fresh work detailed,
   context managed automatically

9. **One-person operation** — tell the Mayor what you want, it orchestrates
   everything, you review the result

10. **Completeness by default** — AI compression means completeness is cheap,
    so every agent defaults to boiling the lake
