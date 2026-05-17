---
name: dependency-coordinator
version: 1.0.0
disable-model-invocation: true
description: "Orchestrator-dispatched only. Authors the cross-package dependency manifest before parallel implementation agents are dispatched, preventing transitive version drift. Composed by orchestrator during multi-agent builds. Not user-invocable."
type: contract
---

# Dependency Coordinator

> **Pipeline position.** Runs after `plan-builder`, before `orchestrator` dispatches parallel agents. Pins inter-agent deps so concurrent work doesn't collide.

Authors the cross-package dependency manifest in a monorepo so parallel implementation agents can fill in their own `package.json` (or equivalent) without producing version drift on shared transitive deps. **Run before any agent that will write a package manifest is dispatched.**

## When this skill applies

This skill assumes a contract-first multi-agent build model:

- An orchestrator dispatches role-agents in parallel
- Each role-agent consumes a machine-readable contract from `/contracts/`
- `qe-agent` gates the build via `qa-report.json`

For single-agent or ad-hoc work, this skill is not the right tool.

## Why this skill exists

Specification problems cause ~42% of multi-agent failures (per orchestrator skill). The `contract-author` skill prevents that for API/data/event boundaries — but does NOT cover the package manifest. Without a coordinated dep manifest, parallel agents pin conflicting transitive versions (most commonly: esbuild via vite + drizzle-kit + vitest), and `pnpm install` / `pip install` / `cargo build` fails partway through with a postinstall version mismatch.

This skill sits next to `contract-author` in the orchestrator's Phase 4 (contracts), authoring a different kind of contract: **the dependency contract**.

## Role

You are the **dependency coordinator**. You read the project's tech-stack profile (from `.claude/profile.yaml` or the plan), enumerate every shared transitive dependency that's likely to drift, and emit:

1. A root manifest with overrides/resolutions pinning shared transitives to one version
2. Per-package manifest templates that consumer agents fill in (rather than authoring from scratch)
3. A human-readable `DEPENDENCIES.md` documenting the version policy
4. A short dispatch advisory the orchestrator pastes into each agent's prompt

## Inputs

- **Tech stack profile** — from `.claude/profile.yaml` or the plan document. Specifically: language, runtime, package manager, test framework, build tools, ORM, web framework, UI framework.
- **Workspace shape** — list of `apps/*` and `packages/*` to be created (from the plan's component list).
- **Pinning policy (optional)** — strict (one version per dep) or flexible (caret ranges with overrides only on known-conflict deps). Default: flexible.

## Process

The detailed recipes for each step live in `references/pinning-strategies.md` — read it before authoring. The flow is:

1. **Enumerate shared transitives** — for the detected stack, list deps known to drift (see `references/known-conflict-deps.md`).
2. **Pick a target version per transitive** — choose the version satisfying the most demanding consumer; record rationale.
3. **Author the root manifest** — emit the overrides/resolutions block matching the workspace's package manager (pnpm/npm/yarn/poetry/uv/cargo). Stack-specific templates are in `references/pinning-strategies.md`.
4. **Author per-package manifest templates** — one `package.json.template` (or equivalent) per workspace package, with a header comment listing inherited pins.
5. **Author `DEPENDENCIES.md`** — version policy in human-readable form, including rationale, per-package boundaries, escalation procedure, and migration playbook. See `references/dependencies-md-template.md`.
6. **Emit a dispatch advisory** — short string pasted verbatim into every implementation agent's prompt warning them not to modify root overrides.

After steps 1–6, run a dry install in the workspace root before dispatching agents (see `references/pinning-strategies.md` for the per-tool command). A failing dry install means the overrides block is wrong — fix it before dispatching.

## Right-sizing

Match output complexity to the project:

- **Single-package project** — skip this skill entirely. No cross-agent drift surface exists.
- **2–3 package monorepo** — author overrides + DEPENDENCIES.md only; skip per-package templates.
- **4+ packages with parallel agent dispatch** — full output: root overrides + per-package templates + DEPENDENCIES.md + dispatch advisory.
- **Polyglot monorepo (e.g. TS + Python)** — emit one manifest per language (root `package.json` overrides + workspace-level `pyproject.toml` constraints).

## Coordination

- **You vs. contract-author** — `contract-author` owns API/data/event boundaries. You own the dependency boundary. Both run in the orchestrator's Phase 4. Run `contract-author` first (it determines which packages exist), then you (you pin their deps).
- **You vs. infrastructure-agent** — `infrastructure-agent` owns Dockerfiles, CI, deploy configs. You own the package manifests they install from. Your output is upstream of theirs; they pick up pinned versions automatically.
- **Run order:** plan → contract-author → dependency-coordinator → implementation agents → contract-auditor (verifies no agent broke the pin policy).

## Output

| File | Required when | Format |
|---|---|---|
| Root `package.json` (or `pyproject.toml`, `Cargo.toml`) with overrides block | Always | Language-native |
| `packages/<each>/package.json.template` | 4+ packages | Language-native |
| `DEPENDENCIES.md` at workspace root | Always | Markdown |
| Dispatch advisory string | Always | Plain text — pasted into agent prompts |

## Quality checklist

- [ ] Every override has a rationale entry in DEPENDENCIES.md
- [ ] Per-package templates exist for every workspace package the orchestrator plans to spawn
- [ ] No template hardcodes a version that conflicts with a root override
- [ ] DEPENDENCIES.md lists the migration playbook for bumping a pin
- [ ] Dispatch advisory mentions: don't modify root, use templates, escalate on conflict
- [ ] Run `pnpm install --dry-run` (or equivalent) post-author — must succeed before agents are dispatched

## Anti-patterns to avoid

- **Empty overrides block** — if you can't identify any shared transitive worth pinning, don't emit an empty block. The skill's value is the pin, not the ceremony.
- **Pinning everything strict** — overshoots the goal and creates maintenance burden. Pin only deps that have demonstrated drift in this stack.
- **Authoring per-package package.json directly** — that's the implementation agent's job. You author TEMPLATES; agents fill them in.
- **Skipping DEPENDENCIES.md** — undocumented overrides are landmines for future maintainers.

## Reference files

- `references/pinning-strategies.md` — full recipes per stack: enumeration, version-pick logic, root manifest templates for pnpm/npm/yarn/Poetry/uv/Cargo, per-package template patterns, dry-install verification commands
- `references/known-conflict-deps.md` — table of frequently-drifting transitives per stack (TS/Python/Go/Rust)
- `references/dependencies-md-template.md` — DEPENDENCIES.md template

## Composes with

- `contract-author` — runs immediately before this skill
- `infrastructure-agent` — consumes the pinned manifests
- `contract-auditor` — verifies post-hoc that no agent broke the pin policy
- `orchestrator` — runs this skill in Phase 4 (contracts)
