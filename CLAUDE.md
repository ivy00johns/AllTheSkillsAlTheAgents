# CLAUDE.md

> **Also read `AGENTS.md`** — it contains shared instructions for all AI agents working in this repo.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A multi-agent orchestration toolkit for Claude Code — 38 skills (~80 files) that enable contract-first parallel builds with declarative file ownership and QA-gated releases. Skills live in `skills/` and are symlinked to `~/.claude/skills/` for global availability.

## Install / Sync

Use the `/sync-skills` command to create symlinks from `~/.claude/skills/` back to this repo. This keeps skills always in sync — edits in either location are reflected immediately.

```bash
# Via slash command (recommended)
/sync-skills

# Manual: create category symlinks + flattened discovery symlinks
# See skills/workflows/sync-skills/SKILL.md for details
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

- **`skills/orchestrator/`** (1) — Entry point. 14-phase build playbook, runtime detection, contract-first coordination. References: phase-guide, team-sizing, circuit-breaker, handoff-protocol.
- **`skills/roles/`** (9) — Implementation agents (backend, frontend, infrastructure, qe, security, docs, observability, db-migration, performance). Each has a SKILL.md + reference files with validation checklists.
- **`skills/contracts/`** (2) — contract-author (generates contracts from templates) and contract-auditor (verifies implementations match). Templates: OpenAPI, AsyncAPI, Pydantic, TypeScript, JSON Schema.
- **`skills/meta/`** (8) — skill-writer, project-profiler, code-reviewer, skill-audit, skill-deep-review, skill-improvement-plan, skill-updater, wiki-research.
- **`skills/git/`** (5) — Git workflow conventions: git-commit, git-pr, git-pr-feedback, git-branch-cleanup, git-clean-worktrees.
- **`skills/workflows/`** (13) — context-manager, deployment-checklist, sync-skills, mermaid-charts, nano-banana, railway-deploy, plan-builder, settings-consolidator, env-setup, llm-wiki, playwright, hive-cli, repo-deep-dive.

See `docs/architecture.md` for a Mermaid diagram of how the categories relate.

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
- If using symlinks (default), edits are automatically reflected in both locations

## Source Material

- `skill-ecosystem-design-spec.md` — The full design blueprint (frontmatter convention, profile schema, ownership map, QA schema, handoff protocol, build order)
- `docs/initial/` — Original source documents that informed skill designs (backend, frontend, infrastructure, qe, specialist, orchestrator, tech-stacks, templates)
