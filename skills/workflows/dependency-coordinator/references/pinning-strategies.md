# Dependency Pinning Strategies

Detailed recipes, lockfile patterns, and per-language nuances for the dependency-coordinator. The main `SKILL.md` covers when and why to pin; this document is the how.

## Step 1: Enumerate shared transitives

For the detected stack, list dependencies that frequently cause cross-package version drift. The reference table in `known-conflict-deps.md` covers the most common stacks; consult it before authoring.

### Common JavaScript / TypeScript drift sources

- `esbuild` — pulled by vite, drizzle-kit, vitest, tsx; each pins a different range
- `typescript` — every package's devDeps; drifts if not pinned at root
- `@types/node` — drifts across packages; pin one major
- `zod` — peer-dep tension with `@anthropic-ai/sdk` (currently wants `^3.25 || ^4`)
- `react` / `react-dom` — peer-dep tension with `@types/react`

### Common Python drift sources

- `pydantic` v1 vs v2 — FastAPI auto-pulls v2; legacy code sometimes wants v1
- `httpx` — versions matter for async test clients
- `sqlalchemy` v1 vs v2

### Common Go / Rust drift sources

Go drift is rarer because of `go.mod`'s single-version policy per module; the pain hits when two modules disagree on a major. Rust drift hits at the workspace `Cargo.toml` `[workspace.dependencies]` block; pin shared crates there.

## Step 2: Pick a target version per shared transitive

For each shared transitive, pick the version that satisfies the most demanding consumer. Examples:

- `vite@^5.4` requires `esbuild@^0.21` → pin `esbuild=0.21.5` if drizzle-kit (which wants `^0.19`) is also in the workspace.
- `@anthropic-ai/sdk@^0.92` peers `zod@^3.25 || ^4.0` → pin `zod=3.25.0+` (or 4.x) workspace-wide.

Document the pinning rationale in `DEPENDENCIES.md` so a future maintainer knows WHY each override exists.

## Step 3: Author the root manifest

Emit the overrides/resolutions block matching the workspace's package manager.

### pnpm

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

### npm

```json
{
  "overrides": {
    "esbuild": "0.21.5"
  }
}
```

### yarn

```json
{
  "resolutions": {
    "esbuild": "0.21.5"
  }
}
```

### Python (Poetry)

```toml
[tool.poetry.dependencies]
pydantic = "^2.0"  # workspace-wide; sub-packages MUST inherit
```

### Python (uv / pip-tools)

Use `constraints.txt` at the workspace root and reference it from every sub-package's `requirements.in`:

```text
pydantic==2.7.4
httpx==0.27.2
```

### Cargo

```toml
[workspace.dependencies]
serde = "1.0.210"
tokio = { version = "1.40", features = ["macros", "rt-multi-thread"] }
```

Then sub-crates use `serde.workspace = true`.

## Step 4: Author per-package manifest templates

For each `apps/*` and `packages/*` that an agent will own, emit a `package.json.template` (or equivalent) that includes:

- The package's own deps + devDeps appropriate to its role
- A header comment listing which version pins are inherited from root
- Standard scripts (`build`, `typecheck`, `test`, `lint`) wired to the workspace's tools

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

The agent that owns this package replaces the `<TODO>` block with package-specific deps but does NOT alter the dev-deps row. This is enforced by convention and verifiable post-hoc by `contract-auditor`.

## Step 5: Author `DEPENDENCIES.md`

Document the version policy in human-readable form. Include:

- Pinned versions table with rationale per pin
- Per-package boundaries (which package owns which deps)
- Escalation procedure when an agent needs a dep that isn't yet listed
- Migration playbook for bumping a pin

See `dependencies-md-template.md` for the template.

## Step 6: Emit a dispatch advisory

Before the orchestrator dispatches implementation agents, emit a short advisory string that goes into each agent's prompt:

```text
Workspace dependency policy:
- Root package.json includes pnpm.overrides — DO NOT modify.
- Use the per-package template at packages/<your-package>/package.json.template as the starting point.
- For new deps not in the template, ADD them to your package's deps but DO NOT pin shared transitives (esbuild, typescript, @types/node, zod) — root overrides handle those.
- If a dep you need conflicts with an override, escalate to the orchestrator before authoring.
```

The orchestrator pastes this into every implementation agent's prompt verbatim.

## Verification before agent dispatch

Run a dry install in the workspace root before dispatching agents:

- pnpm — `pnpm install --dry-run`
- npm — `npm install --dry-run`
- yarn — `yarn install --mode=update-lockfile --dry-run` (or omit if older yarn)
- Poetry — `poetry lock --check`
- uv — `uv lock --check`
- Cargo — `cargo check --workspace`

A failing dry install before any agent runs means the overrides block is wrong — fix it before dispatching.
