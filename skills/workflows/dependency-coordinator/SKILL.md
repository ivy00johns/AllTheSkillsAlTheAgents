---
name: dependency-coordinator
version: 1.0.0
description: |
  Author the cross-package dependency manifest before dispatching parallel implementation agents. Use PROACTIVELY in monorepos when multiple agents will independently write package.json/requirements.txt/Cargo.toml files, to prevent cross-agent transitive version drift (e.g. one agent pulls esbuild ~0.19, another ~0.25, install fails). Pairs with contract-author in the same orchestrator phase. Triggers on: "set up workspace dependency pinning", "before parallel agent dispatch", "monorepo dependency policy", "shared dependency overrides", "pnpm.overrides", "lock dependency versions across packages", or any orchestrated build where ≥2 agents will own ≥1 package.json each.
type: contract
---

# Dependency Coordinator

Authors the cross-package dependency manifest in a monorepo so parallel implementation agents can fill in their own `package.json` (or equivalent) without producing version drift on shared transitive deps. **Run before any agent that will write a package manifest is dispatched.**

## Why this skill exists

Specification problems cause ~42% of multi-agent failures (per orchestrator skill). The `contract-author` skill prevents that for API/data/event boundaries — but does NOT cover the package manifest. Without a coordinated dep manifest, parallel agents pin conflicting transitive versions (most commonly: esbuild via vite + drizzle-kit + vitest), and `pnpm install` / `pip install` / `cargo build` fails partway through with a postinstall version mismatch.

This skill sits next to `contract-author` in the orchestrator's Phase 4 (the contracts phase), authoring a different kind of contract: **the dependency contract**.

## Role

You are the **dependency coordinator**. You read the project's tech-stack profile (from `.claude/profile.yaml` or the plan), enumerate every shared transitive dependency that's likely to drift, and emit:

1. A root manifest with overrides/resolutions pinning shared transitives to one version.
2. Per-package manifest templates that consumer agents fill in (rather than authoring from scratch).
3. A human-readable `DEPENDENCIES.md` documenting the version policy.

## Inputs

- **Tech stack profile** — from `.claude/profile.yaml` or the plan document. Specifically: language, runtime, package manager, test framework, build tools, ORM, web framework, UI framework.
- **Workspace shape** — list of `apps/*` and `packages/*` to be created (from the plan's component list).
- **Pinning policy (optional)** — strict (one version per dep) or flexible (caret ranges with overrides only on known-conflict deps). Default: flexible.

## Process

### Step 1: Enumerate shared transitives

For the detected stack, list dependencies that frequently cause cross-package version drift. The reference table in `references/known-conflict-deps.md` covers the most common stacks; consult it before authoring.

Common JavaScript/TypeScript drift sources:
- `esbuild` (pulled by vite, drizzle-kit, vitest, tsx — each pins a different version range)
- `typescript` (every package's devDeps; drifts if not pinned at root)
- `@types/node` (drifts; pin one major)
- `zod` (peer-dep tension with @anthropic-ai/sdk — current SDK wants ^3.25 || ^4)
- `react` / `react-dom` (peer-dep tension with @types/react)

Common Python drift sources:
- `pydantic` v1 vs v2 (FastAPI auto-pulls v2; legacy code sometimes wants v1)
- `httpx` (versions matter for async test clients)
- `sqlalchemy` v1 vs v2

### Step 2: Pick a target version per shared transitive

For each shared transitive, pick the version that satisfies the most demanding consumer. Examples:
- `vite@^5.4` requires `esbuild@^0.21` → pin esbuild=0.21.5 if drizzle-kit (which wants ^0.19) is also in the workspace.
- `@anthropic-ai/sdk@^0.92` peers `zod@^3.25 || ^4.0` → pin zod=3.25.0+ (or 4.x) workspace-wide.

Document the pinning rationale in `DEPENDENCIES.md` so a future maintainer knows WHY each override exists.

### Step 3: Author the root manifest

Output the root manifest with the overrides/resolutions block:

**pnpm:**
```json
{
  "pnpm": {
    "overrides": {
      "esbuild": "0.21.5",
      "zod": "3.25.0"
    }
  }
}
```

**npm:**
```json
{
  "overrides": {
    "esbuild": "0.21.5"
  }
}
```

**yarn:**
```json
{
  "resolutions": {
    "esbuild": "0.21.5"
  }
}
```

**Python (Poetry):**
```toml
[tool.poetry.dependencies]
pydantic = "^2.0"  # workspace-wide; sub-packages MUST inherit
```

### Step 4: Author per-package manifest templates

For each `apps/*` and `packages/*` that an agent will own, emit a `package.json.template` (or equivalent) that includes:

- The package's own deps + devDeps appropriate to its role.
- A header comment listing which version pins are inherited from root.
- The standard scripts (`build`, `typecheck`, `test`, `lint`) wired to the workspace's tools.

Example template for a backend service package in a TypeScript pnpm workspace:

```json
{
  "name": "@<scope>/<package-name>",
  "version": "0.1.0",
  "type": "module",
  "main": "src/index.ts",
  "types": "src/index.ts",
  "exports": { ".": "./src/index.ts" },
  "scripts": {
    "test": "vitest run",
    "typecheck": "tsc --noEmit",
    "build": "tsc"
  },
  "dependencies": {
    "<TODO: package-specific deps>": ""
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.5.0",
    "vitest": "^1.6.0"
  }
}
```

The agent that owns this package replaces the `<TODO>` block with package-specific deps but does NOT alter the dev-deps row. This is enforced by convention (skill instructions to the consuming agent) and verifiable by `contract-auditor` post-hoc.

### Step 5: Author `DEPENDENCIES.md`

Document the version policy in human-readable form. Include:

- The pinned versions table with rationale per pin.
- The per-package boundaries (which package owns which deps).
- The escalation procedure when an agent needs a dep that isn't yet listed.
- The migration playbook for bumping a pin.

See `references/dependencies-md-template.md` for the template.

### Step 6: Emit a "dispatch advisory"

Before the orchestrator dispatches implementation agents, emit a short advisory string that goes into each agent's prompt:

```
Workspace dependency policy:
- Root package.json includes pnpm.overrides — DO NOT modify.
- Use the per-package template at packages/<your-package>/package.json.template as the starting point.
- For new deps not in the template, ADD them to your package's deps but DO NOT pin shared transitives (esbuild, typescript, @types/node, zod) — root overrides handle those.
- If a dep you need conflicts with an override, escalate to the orchestrator before authoring.
```

The orchestrator pastes this into every implementation agent's prompt verbatim.

## Right-sizing

Match output complexity to the project:

- **Single-package project** — skip this skill entirely. There's no cross-agent drift surface.
- **2–3 package monorepo** — author overrides + DEPENDENCIES.md only; skip per-package templates (the agents can read the existing root for cues).
- **4+ packages with parallel agent dispatch** — full output: root overrides + per-package templates + DEPENDENCIES.md + dispatch advisory.
- **Polyglot monorepo (e.g. TS + Python)** — emit one manifest per language (root `package.json` overrides + workspace-level `pyproject.toml` constraints).

## Coordination

- **You vs. contract-author** — `contract-author` owns API/data/event boundaries. You own the dependency boundary. Both run in the orchestrator's Phase 4. Run `contract-author` first (it determines which packages exist), then you (you pin their deps).
- **You vs. infrastructure-agent** — `infrastructure-agent` owns Dockerfiles, CI, deploy configs. You own the package manifests they install from. Your output is upstream of theirs; they pick up the pinned versions automatically.
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

- `references/known-conflict-deps.md` — table of frequently-drift transitives per stack (TS/Python/Go/Rust)
- `references/dependencies-md-template.md` — DEPENDENCIES.md template

## Composes with

- `contract-author` — runs immediately before this skill
- `infrastructure-agent` — consumes the pinned manifests
- `contract-auditor` — verifies post-hoc that no agent broke the pin policy
- `orchestrator` — runs this skill in Phase 4 (contracts)
