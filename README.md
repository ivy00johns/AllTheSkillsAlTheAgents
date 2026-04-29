# Claude Code Skill Ecosystem

A complete multi-agent orchestration toolkit for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Drop these skills into `~/.claude/skills/` and Claude Code gains the ability to coordinate parallel agent builds with contract-first architecture, declarative file ownership, and QA-gated releases.

## What This Is

When you ask Claude Code to build a full-stack app, it works in a single session — one agent, one context window, one set of files. That works for small projects but breaks down when the codebase gets large enough that a single agent can't hold the full picture.

This skill ecosystem solves that by giving Claude Code a structured way to:

1. **Split work across parallel agents** with strict file ownership (no conflicts)
2. **Define machine-readable contracts** between agents before any code is written
3. **Validate integrations** with a QE agent that gates the build on a structured report
4. **Hand off context** when agents hit context limits, so work continues seamlessly

It's built on [Claude Code Skills](https://docs.anthropic.com/en/docs/claude-code/skills) — markdown files with YAML frontmatter that Claude loads on demand.

## Quick Start

### Install (copy to global skills directory)

```bash
cp -R skills/* ~/.claude/skills/
```

### Use It

Tell Claude Code to build something with multiple agents:

```text
"Build a chat app with React frontend and FastAPI backend — use an agent team"
```

The **orchestrator** skill triggers automatically. It reads your plan, sizes the team, authors contracts, spawns parallel agents, coordinates, and validates the integrated result.

### Or use individual skills standalone

Each agent role skill works on its own without the orchestrator:

```text
"Review this code for security vulnerabilities"     → security-agent
"Set up Docker and CI/CD for this project"           → infrastructure-agent
"Write performance tests with k6"                    → performance-agent
"Profile this codebase and generate a CLAUDE.md"     → project-profiler
```

## Architecture

```text
skills/
├── orchestrator/              # Lead coordinator — the entry point
│   ├── SKILL.md               # 14-phase build playbook, runtime detection
│   └── references/
│       ├── phase-guide.md     # Full phase-by-phase instructions
│       ├── team-sizing.md     # When to use 2 vs 3 vs 4+ agents
│       ├── circuit-breaker.md # Failure detection and recovery
│       └── handoff-protocol.md# Session continuation spec
│
├── roles/                     # Implementation agents (9 roles)
│   ├── backend-agent/         # API servers, business logic, data layers
│   ├── frontend-agent/        # UI, client-side state, presentation
│   ├── infrastructure-agent/  # Docker, CI/CD, deployment configs
│   ├── qe-agent/              # Contract conformance, integration, adversarial testing
│   ├── security-agent/        # OWASP audits, dependency scanning, auth review
│   ├── docs-agent/            # READMEs, API docs, architecture docs
│   ├── observability-agent/   # Logging, metrics, health checks, alerting
│   ├── db-migration-agent/    # Schema migrations, seed data
│   └── performance-agent/     # Load testing with k6 and NeoLoad
│
├── contracts/                 # Contract-first architecture
│   ├── contract-author/       # Generates API/data/event contracts before builds
│   │   └── references/        # OpenAPI, AsyncAPI, Pydantic, TypeScript, JSON Schema templates
│   └── contract-auditor/      # Verifies implementations match contracts
│
├── meta/                      # Skills that create and manage other skills
│   ├── skill-writer/          # Generates new SKILL.md files with proper frontmatter
│   ├── project-profiler/      # Analyzes codebases → generates CLAUDE.md + profile.yaml
│   └── code-reviewer/         # Structured code review with scoring rubric
│
└── workflows/                 # Cross-cutting process skills
    ├── context-manager/       # Compaction strategy, handoffs, token budgets
    └── deployment-checklist/  # Pre-deploy verification gates
```

## Key Concepts

### Contract-First Architecture

Before any implementation agent is spawned, the orchestrator creates machine-readable contracts that define every integration surface: API endpoints (exact URLs, methods, request/response shapes), data layer interfaces (function signatures, storage semantics), and shared type definitions. Agents build to these contracts independently — this is what makes parallel work reliable.

### File Ownership

Every file in the project is assigned to exactly one agent. No two agents can touch the same file. This eliminates merge conflicts and silent overwrites. The orchestrator enforces ownership before spawning agents.

### QA Gate

The QE agent outputs a structured JSON report (see `roles/qe-agent/references/qa-report-schema.json`). The orchestrator's gate rules block the build when critical issues exist or contract conformance scores below threshold. Agents cannot self-declare "done."

### Two-Runtime Strategy

Skills detect their runtime environment and degrade gracefully:

- **Agent Teams available** → native tmux split panes, parallel agents
- **Claude Code CLI only** → subagents via Task/Agent tool
- **claude.ai** → sequential mode, user coordinates

### Progressive Disclosure

Skills use three loading levels to manage context efficiently:

1. **Metadata** (name + description) — always in context (~100 tokens)
2. **SKILL.md body** — loaded when skill triggers (<500 lines)
3. **References** — loaded on demand (unlimited)

## Repo Structure

```text
.
├── README.md                          # This file
├── CLAUDE.md                          # Project guidance for Claude Code
├── AGENTS.md                          # Shared instructions for AI agents
└── skills/                            # The skill ecosystem (copy to ~/.claude/skills/)
    ├── orchestrator/
    ├── roles/
    ├── contracts/
    ├── meta/
    ├── git/
    └── workflows/
```

## Skill Inventory

| Skill | Type | Files | Description |
|-------|------|-------|-------------|
| orchestrator | coordinator | 5 | Lead coordinator for multi-agent builds |
| backend-agent | role | 2 | API servers, business logic, data layers |
| frontend-agent | role | 2 | UI, client-side state, presentation |
| infrastructure-agent | role | 2 | Docker, CI/CD, deployment |
| qe-agent | role | 4 | Testing, contract conformance, QA reports |
| security-agent | role | 2 | OWASP audits, vulnerability scanning |
| docs-agent | role | 2 | Documentation generation |
| observability-agent | role | 2 | Logging, metrics, health checks |
| db-migration-agent | role | 2 | Schema migrations, seed data |
| performance-agent | role | 3 | Load testing (k6, NeoLoad) |
| contract-author | contract | 6 | Generates integration contracts |
| contract-auditor | contract | 2 | Audits implementation vs contract |
| skill-writer | meta | 3 | Generates new SKILL.md files |
| project-profiler | meta | 2 | Codebase analysis → project profile |
| code-reviewer | meta | 2 | Structured code review |
| context-manager | workflow | 2 | Context management and handoffs |
| deployment-checklist | workflow | 2 | Pre-deployment verification |

**Total: 17 skills, 44 files**

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Claude Pro, Team, or Enterprise plan
- For parallel agent builds: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (optional — skills degrade gracefully without it)

## License

MIT
