# Wave Gate

Between every wave of parallel agents, the orchestrator runs the project's install + typecheck + test loop from a clean state. This is non-negotiable.

## Why

Parallel agents writing independent files — different package manifests, different test setups, different framework conventions — produce latent integration bugs that grep-based per-agent validation cannot catch. Examples seen in the wild: missing workspace dep declarations (the import resolves locally but breaks the moment a clean install runs), framework decorators that don't escape encapsulation (every test 500s), deprecated runtime invocations that pass linting but error at execution, host-side port collisions in compose files, omitted compile config files (the typechecker prints help instead of typechecking).

## The gate

After every wave of parallel agents reports done, BEFORE declaring the wave complete or dispatching the next wave, run the project's three integrated checks. Use whatever the project's stack provides — the gate is **install + typecheck + test from a clean state**, not a specific tool:

| Stack signal | Install | Typecheck/lint | Test |
|---|---|---|---|
| `pnpm-workspace.yaml` | `pnpm install` | `pnpm -r run typecheck` | `pnpm -r run test` |
| `package.json` (npm/yarn) | `npm ci` / `yarn install` | `npm run typecheck` (per package) | `npm test` |
| `pyproject.toml` + Poetry | `poetry install` | `poetry run mypy .` or `poetry run ruff check .` | `poetry run pytest` |
| `pyproject.toml` + uv | `uv sync` | `uv run mypy .` | `uv run pytest` |
| `Cargo.toml` workspace | `cargo fetch` | `cargo check --workspace` | `cargo test --workspace` |
| `go.mod` | `go mod download` | `go vet ./...` | `go test ./...` |
| `Gemfile` | `bundle install` | `bundle exec rubocop` | `bundle exec rspec` |
| `pom.xml` / `build.gradle` | `mvn -B verify` (covers all three) | — | — |

For polyglot monorepos, run the gate for every language present (Node + Python both, etc.).

## On failure

If any step fails, the wave is **not complete**. Route each specific failure back to the responsible agent (via SendMessage if the runtime supports it, otherwise spawn a fix subagent with the agent role) with the exact error output. Repeat until all three steps pass.

Agent self-validation can be bypassed by grep tricks, missing files, or unran tests. The integrated gate cannot — if install fails, the workspace is broken, full stop. Catching it here is 30 minutes of fix work; catching it when the human runs the project is a credibility hit and a damaged handoff.

**The orchestrator does not declare "build complete" without a clean integrated gate.** This applies whether or not a QE agent is in the loop — the wave gate is the orchestrator's own check, not delegated.
