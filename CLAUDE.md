# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A multi-agent orchestration toolkit for Claude Code — 17 skills (44 files) that enable contract-first parallel builds with declarative file ownership and QA-gated releases. Skills live in `skills/` and are installed by copying to `~/.claude/skills/`.

## Install / Sync

```bash
# Install skills globally
cp -R skills/* ~/.claude/skills/

# After editing, sync back to repo
cp -R ~/.claude/skills/orchestrator ~/.claude/skills/roles ~/.claude/skills/contracts ~/.claude/skills/meta ~/.claude/skills/workflows skills/
```

## Skill Anatomy

Every skill follows this structure:

```text
skill-name/
├── SKILL.md              # YAML frontmatter + markdown instructions (<500 lines)
└── references/           # On-demand reference files (unlimited size)
```

All SKILL.md files use the frontmatter convention defined in `skills/meta/skill-writer/references/frontmatter-spec.md`. Required fields: `name` (kebab-case), `version` (semver), `description` (trigger text). Agent roles also declare `owns`, `allowed_tools`, `composes_with`, `spawned_by`.

## Skill Categories

- **`skills/orchestrator/`** — Entry point. 14-phase build playbook, runtime detection, contract-first coordination. References: phase-guide, team-sizing, circuit-breaker, handoff-protocol.
- **`skills/roles/`** — 9 implementation agents (backend, frontend, infrastructure, qe, security, docs, observability, db-migration, performance). Each has a SKILL.md + reference files with validation checklists.
- **`skills/contracts/`** — contract-author (generates contracts from templates) and contract-auditor (verifies implementations match). Templates: OpenAPI, AsyncAPI, Pydantic, TypeScript, JSON Schema.
- **`skills/meta/`** — skill-writer (generates new skills), project-profiler (codebase → CLAUDE.md + profile.yaml), code-reviewer (structured review with rubric).
- **`skills/workflows/`** — context-manager (handoffs at ~80% context) and deployment-checklist (pre-deploy gates).

## Key Design Decisions

- **File ownership is exclusive** — no two agent roles can own the same file. The orchestrator resolves conflicts before spawning. See the ownership map in `skill-ecosystem-design-spec.md` §6.
- **QE gates the build** — the qe-agent outputs `qa-report.json` per `skills/roles/qe-agent/references/qa-report-schema.json`. Build blocks on CRITICAL blockers or contract_conformance/security scores < 3.
- **Two-runtime degradation** — Agent Teams → subagents → sequential. Only the orchestrator needs this logic; role skills work standalone.
- **Progressive disclosure** — frontmatter (~100 tokens) always loaded, SKILL.md body loaded on trigger, references loaded on demand.
- **Descriptions are "pushy"** — skill descriptions intentionally over-enumerate trigger contexts to combat under-triggering.

## Editing Skills

When modifying a skill:

- Keep SKILL.md body under 500 lines; move detail to `references/`
- Description field is the primary trigger mechanism — include action verbs, specific contexts, and keyword variations
- `owns.directories` must not overlap with other agent roles
- Maintain the frontmatter convention (see `skills/meta/skill-writer/references/frontmatter-spec.md`)
- After editing, sync both directions: repo ↔ `~/.claude/skills/`

## Source Material

- `skill-ecosystem-design-spec.md` — The full design blueprint (frontmatter convention, profile schema, ownership map, QA schema, handoff protocol, build order)
- `docs/initial/` — Original source documents that informed skill designs (backend, frontend, infrastructure, qe, specialist, orchestrator, tech-stacks, templates)
