# 10 — The AllTheSkillsAllTheAgents Ecosystem

Located at `/Users/johns/AI/AllTheSkillsAllTheAgents/`, this is a separate
repository containing a **17-skill multi-agent orchestration toolkit** for
Claude Code. It is independent of Gas Town but conceptually related.

## What It Is

A set of Claude Code Skills (markdown files with YAML frontmatter) that
enable Claude Code to coordinate parallel agent builds with:

- **Contract-first architecture** — machine-readable contracts before code
- **Declarative file ownership** — no two agents touch the same file
- **QA-gated releases** — structured test reports gate the build
- **Context handoffs** — work continues when agents hit context limits

## Repository Structure

```
AllTheSkillsAllTheAgents/
├── CLAUDE.md                    # Project instructions
├── AGENTS.md                    # Agent compatibility
├── README.md                    # Documentation
├── docs/
│   ├── architecture.md          # Mermaid diagrams
│   ├── skill-ecosystem-design-spec.md  # Full blueprint
│   ├── initial/                 # Source documents
│   └── superpowers/             # Superpowers skill docs
├── skills/
│   ├── orchestrator/            # Lead coordinator
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── phase-guide.md
│   │       ├── team-sizing.md
│   │       ├── circuit-breaker.md
│   │       └── handoff-protocol.md
│   ├── roles/                   # 9 implementation agents
│   │   ├── backend-agent/
│   │   ├── frontend-agent/
│   │   ├── infrastructure-agent/
│   │   ├── qe-agent/
│   │   ├── security-agent/
│   │   ├── docs-agent/
│   │   ├── observability-agent/
│   │   ├── db-migration-agent/
│   │   └── performance-agent/
│   ├── contracts/               # Contract-first architecture
│   │   ├── contract-author/
│   │   └── contract-auditor/
│   ├── meta/                    # Skills that manage skills
│   │   ├── skill-writer/
│   │   ├── project-profiler/
│   │   ├── code-reviewer/
│   │   ├── skill-audit/
│   │   ├── skill-deep-review/
│   │   ├── skill-improvement-plan/
│   │   └── skill-updater/
│   └── workflows/               # Cross-cutting processes
│       ├── context-manager/
│       ├── deployment-checklist/
│       ├── nano-banana/
│       ├── plan-builder/
│       ├── railway-deploy/
│       ├── settings-consolidator/
│       └── sync-skills/
└── claude_docs/
    └── plan-builder-workspace/
```

## Skill Categories

### 1. Orchestrator (Entry Point)

The lead coordinator for multi-agent builds. Takes a plan, sizes the team,
authors contracts, spawns parallel agents, coordinates, and validates.

**14-phase build playbook:**
1. Create feature branch
2. Read the plan
3. Size the team
4. Author contracts (critical phase)
5. Spawn agents in parallel
6. Spawn QE agent (mandatory)
7. Coordinate and validate
8. Gate on QA report

**Runtime detection:** Agent Teams → subagents → sequential mode

### 2. Roles (9 Implementation Agents)

| Role | Owns | Purpose |
|------|------|---------|
| backend-agent | `src/api/`, `src/services/`, `src/models/` | API, business logic, data |
| frontend-agent | `src/components/`, `src/pages/`, `public/` | UI, client state |
| infrastructure-agent | `.github/workflows/`, `Dockerfile*` | Docker, CI/CD |
| qe-agent | `tests/`, `e2e/`, `*.test.*` | Testing, contract conformance |
| security-agent | (read-only) | OWASP audits, auth review |
| docs-agent | (docs files) | READMEs, API docs |
| observability-agent | (logging/metrics) | Logging, health checks |
| db-migration-agent | (migrations) | Schema migrations, seeds |
| performance-agent | `tests/performance/` | Load testing (k6, NeoLoad) |

### 3. Contracts

- **contract-author** — generates API/data/event contracts before builds
  - Templates: OpenAPI, AsyncAPI, Pydantic, TypeScript, JSON Schema
- **contract-auditor** — verifies implementations match contracts

### 4. Meta Skills

- **skill-writer** — generates new SKILL.md files
- **project-profiler** — analyzes codebase → CLAUDE.md + profile.yaml
- **code-reviewer** — structured review with scoring rubric
- **skill-audit** — bulk quality scan across all skills
- **skill-deep-review** — single-skill deep dive
- **skill-improvement-plan** — prioritized fix plans from reviews
- **skill-updater** — executes improvement plans

### 5. Workflows

- **context-manager** — compaction strategy, handoffs at ~80% context
- **deployment-checklist** — pre-deploy verification gates
- **nano-banana** — Gemini Image Generation API integration
- **plan-builder** — plan construction workspace
- **railway-deploy** — Railway deployment automation
- **settings-consolidator** — merge Claude Code permissions across projects
- **sync-skills** — symlink skills to `~/.claude/skills/`

## Key Design Principles

### File Ownership is Exclusive

No two agent roles can own the same file. The orchestrator resolves
conflicts before spawning agents. This eliminates merge conflicts and
silent overwrites.

### QE Gates the Build

The QE agent outputs `qa-report.json`. Build blocks on:
- `gate_decision.proceed = false`
- Any blocker with `severity: CRITICAL`
- `scores.contract_conformance.score < 3`
- `scores.security.score < 3`

### Progressive Disclosure

Three loading levels to manage context efficiently:
1. **Metadata** (~100 tokens) — always in context
2. **SKILL.md body** (<500 lines) — loaded on trigger
3. **References** (unlimited) — loaded on demand

### Descriptions are "Pushy"

Skill descriptions intentionally over-enumerate trigger contexts to combat
under-triggering. The description field is the primary trigger mechanism.

## Skill Anatomy

Every skill follows this structure:

```
skill-name/
├── SKILL.md              # YAML frontmatter + markdown (<500 lines)
└── references/           # On-demand reference files (unlimited)
```

Frontmatter spec: `name` (kebab-case), `version` (semver),
`description` (trigger text). Agent roles also declare `owns`,
`allowed_tools`, `composes_with`, `spawned_by`.

## Installation

```bash
# Copy skills to Claude Code global directory
cp -R skills/* ~/.claude/skills/

# Or use symlinks (keeps them in sync)
/sync-skills
```

## Total: 17 skills, 44 files
