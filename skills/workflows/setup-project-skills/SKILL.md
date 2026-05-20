---
name: setup-project-skills
version: 1.0.0
description: |
  Bootstrap per-repo configuration that other Skill-Madness skills consume: domain doc layout (CONTEXT.md location, ADR directory), preferred contract format (OpenAPI vs Pydantic vs TS), default role-agent set for orchestrator dispatch, work-item tracker (Beads / GitHub / local markdown). Writes a docs/agents/ directory + adds an '## Agent skills' block to CLAUDE.md or AGENTS.md (never both, never overwriting). Other skills check for this config and prompt the user to run THIS skill if it's missing. Run once per repository. Trigger on: 'setup project skills', 'configure project skills', 'bootstrap this repo for Skill-Madness', '/setup-project-skills', 'initialize agent config'.
disable-model-invocation: true
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: ["docs/agents/"]
  patterns: []
  shared_read: []
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
composes_with: ["project-profiler", "sync-skills"]
spawned_by: []
---

# setup-project-skills

Explicit-invocation only. Run once per repository.

> **What this writes:** a `docs/agents/` directory containing three config files (`domain-docs.md`, `contract-format.md`, `work-item-tracker.md`) plus an `## Agent skills` block appended to either `CLAUDE.md` or `AGENTS.md`. Never both. Never overwrites an existing `## Agent skills` block without explicit confirmation.

This skill bootstraps the per-repo configuration that the rest of the Skill-Madness toolkit reads at runtime. Downstream skills like `maintain-context`, `contract-author`, and the orchestrator look in `docs/agents/` for these files and fail loud if they are missing.

## The three questions

Ask one at a time. For each question, look at the repo first and recommend an answer; then ask the user to confirm or override. Do not present the menu cold — recommend, then ask.

### Q1 — Domain doc layout

Single-context project or multi-context monorepo? Where does `CONTEXT.md` live?

- **Single-context** (default for most repos) — `CONTEXT.md` at repo root, ADRs in `docs/adr/`.
- **Multi-context monorepo** — `CONTEXT.md` per app at `apps/<app>/CONTEXT.md`, ADRs at `apps/<app>/docs/adr/`.

Recommend `single-context` unless you see an `apps/`, `packages/`, or `services/` directory with multiple sibling projects.

### Q2 — Contract format preference

Which contract format does this repo use for integration boundaries?

- **OpenAPI** — REST APIs, YAML/JSON specs
- **Pydantic** — Python services, models as contracts
- **TypeScript interfaces** — TS-only repos, types as contracts
- **JSON Schema** — language-agnostic, event schemas, config validation

Recommend based on detected stack: Python project → Pydantic; TS-only → TypeScript; mixed or HTTP-heavy → OpenAPI; event-driven → JSON Schema.

### Q3 — Work-item tracker

Where does this project track work items?

- **Beads** — `bd` CLI present or already in use
- **GitHub issues** — repo lives on GitHub, no other tracker visible
- **GitLab issues** — repo lives on GitLab
- **Local markdown** — `briefs/` or `tasks/` directory, no remote tracker

Recommend by checking remote URL (`git remote -v`), presence of `.beads/` or `bd` CLI, and existing `briefs/` or `tasks/` directories.

## Output

For each answer, copy the matching template from `references/templates/` into `docs/agents/`:

- Q1 → `references/templates/domain-docs-{single|multi}.md` → `docs/agents/domain-docs.md`
- Q2 → `references/templates/contract-format-{openapi|pydantic|ts|jsonschema}.md` → `docs/agents/contract-format.md`
- Q3 → `references/templates/work-item-tracker-{beads|github|gitlab|local}.md` → `docs/agents/work-item-tracker.md`

After copying, fill in repo-specific paths if the template has placeholders.

## Update CLAUDE.md or AGENTS.md

Append an `## Agent skills` block. Choose the target file by this rule, in order:

1. If only one of `CLAUDE.md` or `AGENTS.md` exists, use it.
2. If both exist, ask the user which one to update. Never write to both.
3. If neither exists, ask the user which to create. Default to `AGENTS.md` (host-agnostic).

If the target file already has an `## Agent skills` heading, stop and ask: "An `## Agent skills` block already exists in `<file>`. Replace it, leave it alone, or merge new entries?" Never silently overwrite.

The block to append:

```markdown
## Agent skills

This repository is configured for the Skill-Madness toolkit. Agent skills read configuration from `docs/agents/`:

- `docs/agents/domain-docs.md` — where `CONTEXT.md` and ADRs live
- `docs/agents/contract-format.md` — preferred contract format
- `docs/agents/work-item-tracker.md` — work-item tracker for this repo

To re-run setup, invoke `/setup-project-skills`.
```

## Failure-loud contract for downstream skills

Skills that consume this config MUST fail loud when it is missing. Pattern for downstream skill authors:

```text
This action needs docs/agents/<config-file>. Run /setup-project-skills first.
```

Example downstream uses:

- `maintain-context` reads `docs/agents/domain-docs.md` to know whether `CONTEXT.md` lives at the root or per-app.
- `contract-author` reads `docs/agents/contract-format.md` to pick the right template.
- `orchestrator` reads `docs/agents/work-item-tracker.md` to know where to log work items.

Do not silently fall back to defaults. Surface the missing config and name this skill in the error.

## Idempotence

Running this skill twice on the same repo must not destroy existing config.

1. Before writing any file in `docs/agents/`, check if it exists.
2. If it does, read it and ask: **keep / replace / update specific values**.
3. For the `## Agent skills` block in `CLAUDE.md` / `AGENTS.md`, apply the same rule: never silently overwrite. Ask first.

A second run on an already-configured repo should produce zero file changes if the user picks "keep" for every prompt. That is the success condition for idempotence — the skill is safe to invoke repeatedly without surprises.

## Compose with

- `project-profiler` — run it first if `CLAUDE.md` does not yet exist; it generates the stack profile this skill annotates.
- `sync-skills` — once `docs/agents/` is configured, sync skills globally so they can read this config from any project.
