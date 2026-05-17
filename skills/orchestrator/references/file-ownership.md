# File Ownership Map

Directory ownership takes precedence over pattern ownership. Subdirectory carve-outs are explicit (e.g., performance-agent owns `tests/performance/` carved out from qe-agent's `tests/`). This table is the canonical ownership map — when in doubt, this overrides any individual role skill.

| Agent Role | Owns (Exclusive) | Shared Read | Never Touches |
|------------|-----------------|-------------|---------------|
| orchestrator | `.gitignore` | `contracts/`, `.claude/handoffs/`, `*` | `src/` |
| backend | `src/api/`, `src/services/`, `src/models/`, `src/middleware/`, `src/utils/` | `contracts/`, `shared/`, `src/types/` | `src/components/`, `src/pages/` |
| frontend | `src/components/`, `src/pages/`, `src/hooks/`, `src/styles/`, `public/` | `contracts/`, `shared/`, `src/types/` | `src/api/`, `src/services/` |
| infrastructure | `.github/workflows/`, `nginx/`, `k8s/`, `terraform/`, `scripts/deploy/`, `Dockerfile*`, `docker-compose*` | All (read-only) | `src/` |
| qe | `tests/` *(excl. `tests/performance/`)*, `e2e/`, `__tests__/`, `*.test.*`, `*.spec.*` | All (read-only) | `src/` (test files in `src/` owned by directory's agent) |
| performance | `tests/performance/`, `load-tests/` | All (read-only) | `src/` |

**Rule**: If two roles would touch the same file, resolve the conflict by assigning that file to exactly one role before spawning. Unresolvable conflicts → human decision.

## Contract-First Architecture

Contracts prevent the ~42% of multi-agent failures caused by specification problems. Before any agent is spawned:

1. **Shared types first** — single source of truth for all entities
2. **API contract** — exact URLs, methods, request/response JSON shapes, status codes
3. **Data layer contract** — function signatures, storage semantics, cascade behavior
4. **Cross-cutting concerns** — each assigned to exactly one agent

Use the `contract-author` skill and templates in `contracts/contract-author/references/`.
