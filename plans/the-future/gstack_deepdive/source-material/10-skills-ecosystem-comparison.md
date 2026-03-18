# 10 — gstack vs AllTheSkillsAllTheAgents

## Two Philosophies

| Dimension | gstack | AllTheSkillsAllTheAgents |
|-----------|--------|------------------------|
| **Core metaphor** | Virtual engineering team (one person, many hats) | Agent team builder (many agents, orchestrated) |
| **Agent count** | 1 (single Claude session) | 2–6+ (parallel subagents) |
| **Skill count** | 13 | 21 |
| **Focus** | Quality of output | Coordination of agents |
| **Browser** | Yes (50+ commands, persistent daemon) | No |
| **Eval system** | Yes (3-tier, diff-based) | No |
| **Cognitive patterns** | Yes (41 patterns across 3 modes) | No |
| **Design review** | Yes (80 items, AI slop detection) | No |
| **Contract system** | No | Yes (types + API + data layer) |
| **File ownership** | No (single agent owns everything) | Yes (strict per-agent) |
| **QA gate** | Health score (0–100) | qa-report.json (structured, gates build) |
| **Persistence** | Review dashboard (JSONL) | None (stateless skills) |
| **Template system** | Yes (code-driven generation) | No (static SKILL.md) |
| **Skill validation** | Yes (static + E2E + LLM-judge) | No |

## Where gstack Is Stronger

### 1. Quality Intelligence
gstack knows HOW to think about code quality, design, architecture. The
cognitive patterns produce genuinely different reviews from different
perspectives. AllTheSkillsAllTheAgents has `code-reviewer` but it uses a
rubric, not perspective shifts.

### 2. Browser Interaction
gstack can QA a running app — navigate pages, fill forms, take screenshots,
verify visual design, import cookies for auth. AllTheSkillsAllTheAgents
has zero browser capability.

### 3. Eval System
gstack can validate its own skills work correctly. Diff-based test selection
keeps costs manageable. AllTheSkillsAllTheAgents has no way to test whether
its skills produce correct output.

### 4. Template Accuracy
gstack's SKILL.md files are generated from source code. When a browse command
changes, the docs update automatically. AllTheSkillsAllTheAgents' SKILL.md
files are hand-maintained and can drift.

### 5. Design Intelligence
80-item design audit, AI slop detection, design system inference, DESIGN.md
export, design regression tracking. AllTheSkillsAllTheAgents has nothing
comparable.

### 6. Shipping Workflow
`/ship` is a complete release pipeline: tests → version → changelog → PR.
AllTheSkillsAllTheAgents has `deployment-checklist` but no equivalent
integrated shipping skill.

## Where AllTheSkillsAllTheAgents Is Stronger

### 1. Multi-Agent Orchestration
The orchestrator skill runs a 14-phase build playbook coordinating 2–6 agents.
gstack is fundamentally single-agent.

### 2. Contract-First Architecture
Shared types, API contracts, data layer contracts. Prevents ~42% of multi-agent
failures. gstack has no equivalent — it doesn't need one because it's single-agent.

### 3. File Ownership
Strict per-agent file ownership prevents merge conflicts in parallel builds.
gstack has one agent that owns everything.

### 4. Role Specialization
9 specialized agent roles (backend, frontend, infrastructure, etc.) with
validation checklists. gstack's agents are specialized by *function*
(review, QA, ship) not by *code domain*.

### 5. QA Gate Protocol
Structured `qa-report.json` with schema validation, gate rules
(contract_conformance < 3 = blocked), and mandatory QE agent spawning.
gstack's health score is simpler (0–100, weighted).

### 6. Context Management
Handoff protocol at ~80% context, continuation agents with structured
YAML handoff files. gstack has no equivalent — single-agent sessions
don't usually hit context limits.

### 7. Progressive Disclosure
Three-level loading: metadata (~100 tokens) → SKILL.md body (<500 lines) →
references (unlimited). gstack's skills are flat Markdown.

## Overlapping Capabilities

| Capability | gstack | AllTheSkillsAllTheAgents |
|-----------|--------|------------------------|
| Code review | `/review` (cognitive, auto-fix) | `code-reviewer` (rubric-based, read-only) |
| QA testing | `/qa` (browser, find-fix-verify) | `qe-agent` (contract conformance) |
| Documentation | `/document-release` (auto-update) | `docs-agent` (generate from scratch) |
| Security | In `/review` (SQL injection, etc.) | `security-agent` (OWASP audit) |
| Performance | In `/ship` coverage audit | `performance-agent` (load testing) |
| Deployment | In `/ship` (PR creation) | `deployment-checklist` (pre-deploy) |

## The Gap

**gstack has the brain but not the hands.** It knows how to review, QA, design,
and ship — but only through one agent at a time. It can't parallelize.

**AllTheSkillsAllTheAgents has the hands but not the brain.** It can coordinate
5 agents in parallel — but those agents use rubrics, not cognitive patterns.
They can't browse, can't detect AI slop, can't infer design systems.

**The convergence:** gstack's quality intelligence running inside
AllTheSkillsAllTheAgents' multi-agent architecture, orchestrated by gastown,
with beads tracking the work. That's the mega-system.
