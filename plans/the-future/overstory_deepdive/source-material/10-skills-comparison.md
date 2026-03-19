# 10 — Skills Ecosystem vs Overstory Comparison

## Shared DNA

AllTheSkillsAllTheAgents and Overstory were built by the same person for the
same goal: making AI coding agents work together effectively. They share core
philosophical DNA:

| Shared Principle | Skills | Overstory |
|------------------|--------|-----------|
| File ownership is exclusive | Declared in frontmatter `owns.directories` | Declared in overlay `fileScope` |
| Contracts before code | contract-author skill, templates | Spec files in `.overstory/specs/` |
| QA gates the build | QE agent with `qa-report.json` schema | Quality gates in config |
| Progressive complexity | Metadata → SKILL.md → references | Base def → profile → overlay |
| Runtime degradation | Agent Teams → subagents → sequential | 9 runtime adapters |
| Agent role specialization | 9 role skills + orchestrator | 10 agent definitions |

## But They Are Fundamentally Different Things

| Dimension | AllTheSkillsAllTheAgents | Overstory |
|-----------|------------------------|-----------|
| **What it is** | Prompt engineering toolkit (markdown files) | Runtime orchestration system (TypeScript CLI) |
| **Where it runs** | Inside Claude Code's context window | Outside, as infrastructure |
| **State** | Stateless — re-read every session | Stateful — 4 SQLite databases persist |
| **Communication** | Through Claude's Agent tool | SQLite mail system |
| **Isolation** | Claude Code's worktree feature | Git worktrees managed by `ov sling` |
| **Merge** | Manual or Claude Code's built-in | 4-tier automated resolution |
| **Monitoring** | None (user watches) | 3-tier watchdog + dashboard + events |
| **Cost tracking** | None | Transcript parsing + metrics.db |
| **Multi-runtime** | Claude Code only (+ Gemini/Codex hints) | 9 runtime adapters |
| **Expertise** | None (each session starts fresh) | Mulch integration |
| **Issue tracking** | None (user manages) | Seeds/Beads integration |
| **Agent identity** | None (agents are ephemeral) | Persistent CVs in identity.yaml |
| **Hooks** | Manual settings.json | Auto-deployed per-agent |

## The Skills Ecosystem — What It Does

### Architecture
```
~/.claude/skills/
├── orchestrator/         # Entry point — 14-phase build playbook
├── roles/                # 9 agent role definitions
├── contracts/            # Contract-first architecture
├── meta/                 # Skills that manage skills
└── workflows/            # Cross-cutting processes
```

### Role Skills (the agents)
Each role is a SKILL.md file with YAML frontmatter:

| Role | Purpose | Owns |
|------|---------|------|
| backend-agent | API servers, business logic | `src/api/`, `src/services/` |
| frontend-agent | UI, client-side state | `src/components/`, `src/pages/` |
| infrastructure-agent | Docker, CI/CD | `.github/workflows/`, `Dockerfile*` |
| qe-agent | Testing, QA reports | `tests/`, `e2e/`, `*.test.*` |
| security-agent | OWASP audits | `.github/security/` |
| docs-agent | Documentation | `docs/`, `README.md` |
| observability-agent | Logging, metrics | `src/telemetry/` |
| db-migration-agent | Schema migrations | `migrations/`, `prisma/` |
| performance-agent | Load testing | `tests/performance/` |

### The Orchestrator Skill
- Runtime detection (Agent Teams → subagents → sequential)
- File ownership map enforcement
- Contract-first build sequence
- QA gate with structured JSON report schema
- Agent prompt template (distilled, not full plan)
- Anti-patterns catalog
- Circuit breaker at 3 failures
- Context handoff protocol

### Contract System
- contract-author: generates contracts from templates (OpenAPI, AsyncAPI,
  Pydantic, TypeScript, JSON Schema)
- contract-auditor: verifies implementations match contracts
- Templates for every common contract format

### Meta Skills
- skill-writer: generates new SKILL.md files
- skill-audit: bulk ecosystem health scan
- skill-deep-review: single-skill quality analysis
- skill-improvement-plan: turns review results into action plans
- skill-updater: executes improvement plans
- skill-creator: creates, tests, and benchmarks skills
- project-profiler: analyzes codebases → CLAUDE.md + profile.yaml
- code-reviewer: structured review with rubric

### Workflow Skills
- context-manager: compaction strategy, handoffs at ~80% context
- deployment-checklist: pre-deploy verification gates
- sync-skills: symlinks between repo and `~/.claude/skills/`
- nano-banana: Gemini image generation
- plan-builder: structured plan creation
- mermaid-charts: diagram generation
- railway-deploy: Railway deployment automation
- settings-consolidator: consolidate Claude Code permissions

### The "Superpowers" System
Claude Code skills that layer on workflow discipline:
- brainstorming: explore intent before building
- writing-plans: structured plan creation
- executing-plans: plan execution with review checkpoints
- test-driven-development: TDD discipline
- systematic-debugging: structured debugging
- code-review: requesting and receiving reviews
- dispatching-parallel-agents: parallel subagent coordination
- git-worktrees: worktree management
- verification-before-completion: evidence before assertions
- finishing-a-development-branch: merge/PR/cleanup guidance
- subagent-driven-development: implementation plan execution

### The Platform Vision
AllTheSkillsAllTheAgents has evolved beyond skills. The `platform/` directory
scaffolds a future system with:
- Control Plane API (Go)
- Operator Console (React)
- Runtime Orchestrator (Go)
- Browser Automation (TypeScript)
- Review Engine
- Router (scorecards, worker selection)
- Shared contracts/schemas (JSON Schema)
- Local infrastructure (Docker Compose)
- SDK for client libraries

## Overstory — What It Does That Skills Don't

### Runtime Infrastructure
- **Git worktree management** — create, list, clean, branch management
- **Tmux session management** — spawn, detect readiness, send-keys, capture-pane
- **Process management** — headless subprocess lifecycle for non-tmux runtimes
- **Hook deployment** — auto-generate and deploy per-agent guard configs

### Persistent State
- **4 SQLite databases** with WAL mode and busy timeouts
- **Agent identity** — CVs that persist across sessions and tasks
- **Session checkpointing** — save progress before compaction/handoff
- **Run tracking** — group agents into coordinator runs

### Communication Infrastructure
- **Mail system** — typed messages with protocol payloads
- **Broadcast groups** — @all, @builders, @scouts, @leads
- **Nudge system** — progressive escalation via tmux send-keys
- **RPC connections** — direct stdin/stdout for Pi runtime

### Merge Infrastructure
- **FIFO merge queue** — first-done, first-merged
- **4-tier resolution** — clean → auto → AI → reimagine
- **Content loss prevention** — `hasContentfulCanonical()` check
- **Learning from history** — mulch-informed tier skipping

### Observability Infrastructure
- **Event store** — every tool call, mail, spawn, error recorded
- **Dashboard** — live TUI with polling
- **Inspector** — deep single-agent view
- **Trace/replay** — chronological event timelines
- **Feed** — real-time event stream
- **Costs** — token usage and cost analysis
- **Doctor** — 11-category health checks

### Multi-Runtime Infrastructure
- **9 runtime adapters** — plug-and-play agent runtimes
- **Mixed fleets** — different runtimes for different capabilities
- **Model routing** — per-capability model selection with provider support
- **Runtime-agnostic pricing** — cost tracking across all runtimes

## Skills — What They Do That Overstory Doesn't

### Contract Architecture
- **Machine-readable contracts** with templates for 6 formats
- **Contract auditing** with pact-style verification
- **Formal ownership maps** in YAML frontmatter

### Quality Engineering
- **Structured QA reports** with JSON schema and gate rules
- **LLM-as-judge rubrics** for automated quality assessment
- **OWASP security checklists**
- **Performance testing patterns** (k6, NeoLoad)

### Skill Ecosystem Management
- **Self-improving skill system** — audit, review, plan, update cycle
- **Frontmatter specification** — standardized skill metadata
- **Description pattern optimization** — "pushy" descriptions for reliable triggering
- **Skill evaluation benchmarking** — variance analysis

### Workflow Discipline
- **Brainstorming before building** — forced intent exploration
- **TDD enforcement** — tests before implementation
- **Systematic debugging** — structured error investigation
- **Verification before claims** — evidence before assertions

### Platform Vision
- **Control Plane API** design
- **Operator Console** concept
- **Evidence Store** architecture
- **Policy Compiler** specification
- **Router with scorecards**
- **Run Ledger + Analytics**
