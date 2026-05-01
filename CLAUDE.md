# CLAUDE.md

> **Also read `AGENTS.md`** — it contains shared instructions for all AI agents working in this repo.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A multi-agent orchestration toolkit for Claude Code — 38 OSS-publishable skills in `skills/`, plus 2 personal skills in `claude_docs/.claude/skills/` that aren't part of the public bundle. Skills are symlinked to `~/.claude/skills/` for global availability.

The toolkit targets Claude Code as the primary host but the SKILL.md format is platform-agnostic — Claude.ai, Copilot CLI, Codex, and Gemini CLI all consume it. Skills should describe work in terms of capabilities ("read the file", "run the command") rather than Claude-Code-specific tool names where reasonable, so the same skill body works across hosts.

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
- **`skills/workflows/`** (12) — context-manager, deployment-checklist, sync-skills, mermaid-charts, nano-banana, railway-deploy, plan-builder, settings-consolidator, llm-wiki, playwright, repo-deep-dive, ui-brief.
- **`claude_docs/.claude/skills/`** (2, **not in OSS bundle**) — personal skills that depend on private infrastructure: `hive-cli` (private platform repo), `env-setup` (1Password "Key Madness" vault). Excluded when cutting the public release.

## Key Design Decisions

- **File ownership is exclusive** — no two agent roles can own the same file. The orchestrator resolves conflicts before spawning. The canonical ownership map lives in the orchestrator skill.
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
