# 11 — Convergence Analysis

## The Core Thesis

AllTheSkillsAllTheAgents and Overstory are **two halves of the same system.**
Skills define WHAT agents should do and HOW to coordinate (prompts, contracts,
quality gates). Overstory provides the infrastructure to ACTUALLY DO IT
(worktrees, messaging, merging, monitoring, multi-runtime).

Neither is complete alone. Together, they could be something unprecedented.

## What Skills Has That Overstory Lacks

### 1. Contract-First Architecture (Critical Gap)

**Skills:** Has a full contract system with 6 template formats (OpenAPI,
AsyncAPI, Pydantic, TypeScript, JSON Schema, YAML data-layer). The
contract-author skill generates contracts before any agent is spawned.
The contract-auditor verifies implementations match.

**Overstory:** Has spec files (`.overstory/specs/*.md`) but they're
free-form markdown. No machine-readable contracts. No contract verification.
The lead writes specs, but there's no enforcement that the builder's output
matches the spec's interface.

**Impact:** This is the #1 gap. Skills' research shows ~42% of multi-agent
failures come from specification problems. Overstory has the infrastructure
to enforce contracts (via hooks, guards, and the mail system) but doesn't
define what contracts look like.

### 2. Structured QA Gating (Critical Gap)

**Skills:** Has a formal QA report JSON schema with scores for correctness,
completeness, code quality, security, and contract conformance. The
orchestrator blocks the build when critical scores are low. The QE agent
is mandatory, not optional.

**Overstory:** Has quality gates (configurable commands like `bun test`,
`tsc --noEmit`) but they're pass/fail. There's no structured report,
no scoring rubric, no nuanced assessment. A build either passes the
commands or it doesn't.

**Impact:** Quality gates catch mechanical failures (syntax errors, test
failures) but miss design problems, contract violations, and security
issues. The skills' QA system catches a much broader class of problems.

### 3. Formal Workflow Discipline

**Skills:** The superpowers system enforces workflow patterns:
- Brainstorm before building (forced intent exploration)
- TDD (tests before implementation)
- Systematic debugging (structured error investigation)
- Verification before completion (evidence before assertions)
- Plan → execute → review checkpoint cycle

**Overstory:** Agents have workflow guidance in their base definitions
(e.g., lead's three-phase workflow) but nothing enforces it. A builder
could skip tests, a lead could skip review, and nothing would intervene.

**Impact:** Overstory's watchdog catches process failures (stalls, crashes)
but not quality failures (bad code, skipped reviews). Skills' workflow
discipline catches quality failures but has no infrastructure to enforce them.

### 4. Skill Self-Improvement Cycle

**Skills:** Has a meta-skill ecosystem for maintaining and improving skills:
skill-audit → skill-deep-review → skill-improvement-plan → skill-updater.
This is a closed loop for continuous improvement of the agent system itself.

**Overstory:** Has mulch for recording expertise but no mechanism for
automatically improving agent definitions based on outcome analysis.

### 5. Design Intelligence

**Skills:** The brainstorming skill and plan-builder provide structured
design thinking before implementation. The frontend-design skill brings
specific UI design intelligence (anti-generic-AI aesthetics).

**Overstory:** Scouts explore the codebase but don't do design thinking.
The lead's task complexity assessment is mechanical, not creative.

## What Overstory Has That Skills Lack

### 1. Actual Runtime Infrastructure (Critical Gap for Skills)

**Overstory:** Manages real processes — git worktrees, tmux sessions,
subprocess lifecycle. Agents actually run in parallel, isolated, with
real file system boundaries.

**Skills:** Relies entirely on Claude Code's Agent tool for spawning.
This means:
- No real isolation (subagents share the parent's working directory)
- No persistent state between agent sessions
- No process monitoring
- No automatic cleanup

### 2. Persistent Communication (Critical Gap for Skills)

**Overstory:** SQLite mail with typed protocol messages, threading,
broadcast groups, priority levels. Messages survive restarts.

**Skills:** Agents communicate through the Agent tool's return values.
There's no persistent message history, no broadcast, no threading,
no priority. If an agent crashes, its messages are lost.

### 3. Automated Merge Pipeline (Critical Gap for Skills)

**Overstory:** 4-tier automated conflict resolution with learning.
Agents work on branches, branches get merged automatically.

**Skills:** Acknowledges the merge problem but provides no solution.
File ownership prevents conflicts (in theory), but when conflicts
do occur, the user must resolve them manually.

### 4. Multi-Runtime Support

**Overstory:** 9 runtime adapters. Mixed fleets. Model routing.
Runtime-agnostic cost tracking.

**Skills:** Claude Code only (with hints about Gemini CLI compatibility
in the runtime detection tree, but no actual adapter code).

### 5. Organizational Learning

**Overstory:** Mulch integration means agents learn from experience.
Merge patterns are recorded and consulted. Session insights are auto-extracted.

**Skills:** Each build starts from scratch. There's no mechanism for
accumulating knowledge across builds.

### 6. Fleet Observability

**Overstory:** Event store, dashboard, inspector, trace, replay, feed,
costs, doctor, 3-tier watchdog.

**Skills:** No observability. The user watches agents manually and hopes
for the best.

### 7. Agent Identity and Continuity

**Overstory:** Persistent agent CVs, session checkpointing, handoff
protocol. An agent's knowledge persists across sessions.

**Skills:** Agents are fully ephemeral. The context-manager skill has
a handoff protocol (write a YAML file), but there's no infrastructure
to actually use it.

## What Both Have But Implement Differently

### Agent Role Definitions

| Aspect | Skills | Overstory |
|--------|--------|-----------|
| Format | YAML frontmatter + markdown | Markdown sections |
| Location | `~/.claude/skills/` | `agents/*.md` at repo root |
| Metadata | Rich (version, dependencies, tools, ownership) | Minimal (in manifest.json) |
| Discovery | Triggered by Claude's skill system | Loaded by ov sling |
| Customization | Project profile layer | Canopy profile layer |

### File Ownership

| Aspect | Skills | Overstory |
|--------|--------|-----------|
| Defined in | SKILL.md frontmatter `owns.directories` | `--files` flag on `ov sling` |
| Enforcement | Orchestrator checks before spawning | Guard rules + path boundaries |
| Granularity | Directory + glob pattern | Explicit file list |
| Conflict resolution | Orchestrator resolves at design time | Lead resolves at decomposition time |

### Quality Assurance

| Aspect | Skills | Overstory |
|--------|--------|-----------|
| Mechanism | QE agent with structured JSON report | Quality gate commands |
| Scoring | 5-dimension rubric (1-5 scale) | Pass/fail per command |
| Contract checking | Built into QA report | Not implemented |
| Gate rules | Structured (proceed/block + reasons) | Command exit code |

## The Convergence Opportunity

### What a Combined System Would Look Like

```
Layer 1: Skills (WHAT and HOW to think)
  - Contract-first architecture
  - QA report schema and gate rules
  - Workflow discipline (brainstorm, TDD, verify)
  - Role definitions with rich metadata
  - Design intelligence

Layer 2: Overstory (HOW to execute)
  - Git worktree management
  - SQLite mail + protocol messages
  - 4-tier merge resolution
  - 3-tier watchdog monitoring
  - Multi-runtime adapters
  - Event store + observability

Layer 3: Mulch/Seeds/Canopy (HOW to remember)
  - Organizational learning
  - Issue tracking
  - Prompt versioning and profiles

Layer 4: Platform (HOW to scale) [from the-future plan]
  - Control Plane API
  - Operator Console
  - Evidence Store
  - Policy Compiler
  - Router with scorecards
```

### Specific Integration Points

1. **Skills' contract-author → Overstory's spec system**
   Replace free-form spec markdown with machine-readable contracts.
   The contract-author skill generates them, `ov sling` deploys them
   as part of the overlay, the contract-auditor verifies them at merge time.

2. **Skills' QA schema → Overstory's quality gates**
   Replace pass/fail commands with structured QA reports. The QE agent
   produces `qa-report.json`, Overstory's hooks parse it and block merges
   when scores are below threshold.

3. **Skills' workflow discipline → Overstory's guard rules**
   Enforce TDD via guards: the builder's `worker_done` message isn't
   accepted unless tests exist and pass. Enforce brainstorming via the
   scout workflow: the lead can't spawn builders until a scout has reported.

4. **Overstory's mail → Skills' inter-agent communication**
   Replace the Agent tool's ephemeral returns with persistent, typed
   messages. Contract changes use the `decision_gate` protocol type.
   QA reports use a new `qa_report` protocol type.

5. **Overstory's watchdog → Skills' context-manager**
   When the watchdog detects context approaching limits, it triggers
   the context-manager's handoff protocol automatically — write the
   checkpoint, spawn the continuation agent, transfer the context.

6. **Overstory's mulch → Skills' self-improvement cycle**
   Merge outcomes feed into mulch. Mulch patterns inform skill-audit.
   skill-improvement-plan generates agent definition updates.
   The cycle closes: agents get better at their jobs over time.
