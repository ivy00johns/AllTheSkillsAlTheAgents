# Claude Code Skill Ecosystem

A complete multi-agent orchestration toolkit — **38 skills** spanning orchestration, role agents, contracts, git workflows, and developer workflows. Built for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) as the primary host, but the SKILL.md format is platform-agnostic so the same skills work on Claude.ai, Copilot CLI, Codex, and Gemini CLI.

Symlink these skills into `~/.claude/skills/` and Claude Code gains the ability to coordinate parallel agent builds with contract-first architecture, declarative file ownership, and QA-gated releases.

## What This Is

When you ask Claude Code to build a full-stack app, it works in a single session — one agent, one context window, one set of files. That works for small projects but breaks down when the codebase gets large enough that a single agent can't hold the full picture.

This skill ecosystem solves that by giving Claude Code a structured way to:

1. **Split work across parallel agents** with strict file ownership (no conflicts)
2. **Define machine-readable contracts** between agents before any code is written
3. **Validate integrations** with a QE agent that gates the build on a structured report
4. **Hand off context** when agents hit context limits, so work continues seamlessly

It's built on [Claude Code Skills](https://docs.anthropic.com/en/docs/claude-code/skills) — markdown files with YAML frontmatter that Claude loads on demand.

## Quick Start

### Install (symlink into Claude Code's global skills directory)

Clone the repo, then run the bundled sync script — it creates flattened symlinks at `~/.claude/skills/<skill-name>` so edits in the repo are instantly live in every session.

```bash
git clone https://github.com/<your-fork>/AllTheSkillsAllTheAgents.git
cd AllTheSkillsAllTheAgents
skills/workflows/sync-skills/scripts/sync-skills.sh --link --to-all
```

Or, from inside Claude Code, just run `/sync-skills` once the repo is cloned.

If you'd rather copy files than symlink (e.g., on a machine without repo access), use `--copy` instead of `--link`.

## Install to Other Tools

AllTheSkillsAllTheAgents skills are authored in the canonical SKILL.md format — a portable, platform-agnostic markdown + YAML frontmatter convention. The multi-tool installer translates these skills into 10 other tools' native formats, so the same skill library works everywhere: Cursor, Aider, Windsurf, OpenCode, Qwen Code, Gemini CLI, OpenClaw, Kimi Code, and GitHub Copilot.

### Supported Tools

| Tool | Scope | Format | Source |
|---|---|---|---|
| Claude Code | user | SKILL.md (passthrough) | — |
| GitHub Copilot | user | .md (passthrough) | direct copy |
| Cursor | project | .mdc with metadata | generated |
| Aider | project | single CONVENTIONS.md | accumulated |
| Windsurf | project | single .windsurfrules | accumulated |
| OpenCode | project | .md with mode field | generated |
| Qwen Code | project | .md with optional tools | generated |
| OpenClaw | user | 3-file split (SOUL/AGENTS/IDENTITY) | generated |
| Gemini CLI | user | extension manifest + SKILL.md | generated |
| Antigravity | user | community-skill SKILL.md | generated |
| Kimi Code | user | YAML config + system.md | generated |

### Two-Step Installation

```bash
# Step 1: Convert all skills to tool-specific formats
./scripts/convert.sh

# Step 2: Install into detected tools (interactive if TTY, auto if not)
./scripts/install.sh
```

See `scripts/README.md` for detailed flag documentation, per-tool examples, and the full convert/install/lint reference.

### Important: Lossy Conversion

Claude-Code-only frontmatter fields — `allowed_tools`, `owns`, `composes_with`, `spawned_by`, `requires_agent_teams` — are stripped when converting to other tools. You'll see a stderr warning per skill (`[copilot] stripped allowed_tools/owns from <slug>`). This is intentional and correct: these fields describe orchestration rules that only Claude Code's agent teams understand.

Skills marked `requires_claude_code: true` are skipped entirely for non-Claude-Code targets. See `contracts/installer/per-tool-output-spec.md` for the complete specification.

### CI Integration

Every commit runs `scripts/lint-skills.sh` via `.github/workflows/lint-skills.yml` to validate all 38 skills' frontmatter and cross-skill invariants. PRs to `main` block on any lint errors. The workflow produces a JUnit report (visible as GitHub Actions test results) for easy triage.

### Use It

Tell Claude Code to build something with multiple agents:

```text
"Build a chat app with React frontend and FastAPI backend — use an agent team"
```

The **orchestrator** skill triggers automatically. It reads your plan, sizes the team, authors contracts, spawns parallel agents, coordinates, and validates the integrated result.

### Or use individual skills standalone

Each agent role skill works on its own without the orchestrator:

```text
"Review this code for security vulnerabilities"      → security-agent
"Set up Docker and CI/CD for this project"           → infrastructure-agent
"Write performance tests with k6"                    → performance-agent
"Profile this codebase and generate a CLAUDE.md"     → project-profiler
```

## Architecture

```text
skills/
├── orchestrator/              # Lead coordinator — the entry point (1)
│   ├── SKILL.md               # 14-phase build playbook, runtime detection
│   └── references/
│       ├── phase-guide.md     # Full phase-by-phase instructions
│       ├── team-sizing.md     # When to use 2 vs 3 vs 4+ agents
│       ├── circuit-breaker.md # Failure detection and recovery
│       └── handoff-protocol.md# Session continuation spec
│
├── roles/                     # Implementation agents (9)
│   ├── backend-agent/         # API servers, business logic, data layers
│   ├── frontend-agent/        # UI, client-side state, presentation
│   ├── infrastructure-agent/  # Docker, CI/CD, deployment configs
│   ├── qe-agent/              # Contract conformance, integration, adversarial testing
│   ├── security-agent/        # OWASP audits, dependency scanning, auth review
│   ├── docs-agent/            # READMEs, API docs, architecture docs
│   ├── observability-agent/   # Logging, metrics, health checks, alerting
│   ├── db-migration-agent/    # Schema migrations, seed data
│   └── performance-agent/     # Load testing (k6 default; Locust/JMeter/Artillery patterns)
│
├── contracts/                 # Contract-first architecture (3)
│   ├── contract-author/       # Generates API/data/event contracts before builds
│   │   └── references/        # OpenAPI, AsyncAPI, Pydantic, TypeScript, JSON Schema, data-layer YAML
│   ├── contract-auditor/      # Verifies implementations match contracts
│   └── dependency-coordinator/# Cross-package dependency manifest (pnpm overrides, package.json templates)
│
├── meta/                      # Skills that create and manage other skills (8)
│   ├── skill-writer/          # Generates new SKILL.md files with proper frontmatter
│   ├── project-profiler/      # Analyzes codebases → generates CLAUDE.md + profile.yaml
│   ├── code-reviewer/         # Structured code review with scoring rubric
│   ├── skill-audit/           # Bulk scan for ecosystem-level consistency issues
│   ├── skill-deep-review/     # Single-skill deep dive with /skill-creator validation
│   ├── skill-improvement-plan/# Turns review reports into prioritized fix plans
│   ├── skill-updater/         # Executes improvement plans across SKILL.md files
│   └── wiki-research/         # Wiki-first protocol — read 3 pages before crawling source
│
├── git/                       # Git workflow conventions (5)
│   ├── git-commit/            # Conventional commits + branch naming
│   ├── git-pr/                # PR title/body format and gh CLI workflow
│   ├── git-pr-feedback/       # Triage and address PR review comments
│   ├── git-branch-cleanup/    # Prune merged + stale branches safely
│   └── git-clean-worktrees/   # Remove worktrees whose work is already on main
│
└── workflows/                 # Cross-cutting process skills (12)
    ├── context-manager/       # Compaction strategy, handoffs, token budgets
    ├── deployment-checklist/  # Pre-deploy verification gates
    ├── sync-skills/           # Symlink/copy skills to ~/.claude/skills/ and Cursor
    ├── plan-builder/          # Research/PRDs → orchestrator-ready build plans
    ├── repo-deep-dive/        # Full technical reference series for an OSS repo
    ├── settings-consolidator/ # Merge Claude Code permissions across projects
    ├── llm-wiki/              # Bootstrap + maintain LLM-powered knowledge bases
    ├── mermaid-charts/        # Expert-quality diagrams (15-30+ node systems)
    ├── playwright/            # Browser-based E2E + screenshots with visible Chrome
    ├── nano-banana/           # Google Gemini Imagen 4 image generation
    ├── railway-deploy/        # Deploy to Railway (Dockerfile, multi-service, GraphQL API)
    └── ui-brief/              # Opinionated UI design briefs (greenfield + rebuild)
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
└── skills/                            # The skill ecosystem — symlinked to ~/.claude/skills/
    ├── orchestrator/                  # 1 skill
    ├── roles/                         # 9 skills
    ├── contracts/                     # 2 skills
    ├── meta/                          # 8 skills
    ├── git/                           # 5 skills
    └── workflows/                     # 11 skills
```

## Skill Inventory

| # | Skill | Category | Description |
|---|-------|----------|-------------|
| 1 | orchestrator | coordinator | Lead coordinator for multi-agent builds (14-phase playbook) |
| 2 | backend-agent | role | API servers, business logic, data layers |
| 3 | frontend-agent | role | UI, client-side state, presentation |
| 4 | infrastructure-agent | role | Docker, CI/CD, deployment configs |
| 5 | qe-agent | role | Testing, contract conformance, QA gate report |
| 6 | security-agent | role | OWASP audits, dependency + auth review |
| 7 | docs-agent | role | READMEs, API docs, changelogs |
| 8 | observability-agent | role | Logging, metrics, health checks, alerting |
| 9 | db-migration-agent | role | Schema migrations, seed data |
| 10 | performance-agent | role | Load testing (k6 default; OSS alternatives) |
| 11 | contract-author | contract | Generates API / data layer / event contracts |
| 12 | contract-auditor | contract | Static audit: implementation vs contract |
| 13 | skill-writer | meta | Generates new SKILL.md files |
| 14 | project-profiler | meta | Codebase analysis → CLAUDE.md + profile.yaml |
| 15 | code-reviewer | meta | Structured code review with scoring rubric |
| 16 | skill-audit | meta | Bulk ecosystem-level skill quality scan |
| 17 | skill-deep-review | meta | Single-skill deep dive with /skill-creator |
| 18 | skill-improvement-plan | meta | Review report → prioritized fix plan |
| 19 | skill-updater | meta | Executes improvement plans across skills |
| 20 | wiki-research | meta | Wiki-first protocol (3 pages vs 100k tokens) |
| 21 | git-commit | git | Conventional commits + branch naming |
| 22 | git-pr | git | PR title/body format, gh CLI workflow |
| 23 | git-pr-feedback | git | Triage and address PR review comments |
| 24 | git-branch-cleanup | git | Prune merged and stale branches safely |
| 25 | git-clean-worktrees | git | Remove worktrees already merged to main |
| 26 | context-manager | workflow | Compaction strategy + handoff protocol |
| 27 | deployment-checklist | workflow | Pre-deployment verification gates |
| 28 | sync-skills | workflow | Symlink skills to Claude Code + Cursor |
| 29 | plan-builder | workflow | Research/PRDs → orchestrator-ready plans |
| 30 | repo-deep-dive | workflow | OSS repo → 12–14 doc technical reference |
| 31 | settings-consolidator | workflow | Merge Claude Code permissions across projects |
| 32 | llm-wiki | workflow | Bootstrap + maintain LLM-powered wikis |
| 33 | mermaid-charts | workflow | Expert mermaid diagrams (15–30+ nodes) |
| 34 | playwright | workflow | Browser E2E + screenshots, visible Chrome |
| 35 | nano-banana | workflow | Google Imagen 4 image generation |
| 36 | railway-deploy | workflow | Deploy to Railway (Docker, multi-service) |
| 37 | ui-brief | workflow | Opinionated UI design briefs (greenfield + rebuild) |
| 38 | dependency-coordinator | contract | Cross-package dependency manifest before parallel agent dispatch |

**Total: 38 skills.** All bodies under 500 lines. All frontmatter compliant; zero ownership conflicts; zero broken cross-references.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Claude Pro, Team, or Enterprise plan
- For parallel agent builds: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` (optional — skills degrade gracefully without it)

## License

MIT
