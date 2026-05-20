# Audit: deployment-checklist

**Path:** skills/workflows/deployment-checklist/SKILL.md
**Version:** 1.1.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields valid; description 416 chars (under 1024 ceiling, over 200 target); `allowed-tools` hyphenated; no `<`/`>`; field order correct. `composes_with` lists 4 agents that all exist (infrastructure-agent, qe-agent, security-agent, observability-agent). `spawned_by: ["orchestrator"]` valid. Empty `owns` block fields are workflow-skill noise but harmless. |
| Description quality | 5 | Action verb "Run"; 8 explicit trigger phrases ("pre-deploy check", "ready to ship", "is this ready for prod", "deploy readiness", etc.) covering both formal and conversational invocations; pushy and concrete. |
| Progressive disclosure | 5 | Body 76 lines / well under 2000 words; one reference file (pre-deploy.md, 157 lines) linked at line 41 with explicit "Run through in order"; no duplication — body has Quick Reference (1-line summary), reference has bash commands + checklists. Clean split. |
| Instruction clarity | 5 | Imperative voice; clear Inputs / Coordination / Process / Output sections; explicit gate at line 35 ("If qa-report.json shows gate_decision.proceed: false, do not proceed"); structured output template (lines 55-76). |
| Coordination | 5 | Three coordination contracts spelled out (qe-agent gate, infrastructure-agent boundary, orchestrator handoff); explicit verb-level boundary ("validates their output but does not modify infrastructure files"). All 4 composes_with targets resolve. Reciprocal with orchestrator spawn. |
| Completeness | 4 | Reference exists, well-organized into 7 sections with bash commands + checklists. One concern: many bash commands in pre-deploy.md hardcode specific paths (`cd frontend && npm run build`, `cd backend && python -m py_compile main.py`) and ports (`localhost:8000`, `localhost:5173`). For a project that doesn't match this shape, the commands need adaptation guidance. |
| Anti-patterns | 4 | One anti-pattern: hardcoded project structure assumed (frontend/ + backend/ split, port 8000 backend / 5173 frontend, npm + pip + alembic stack). Useful as concrete example but smuggles in a specific project shape. The checklist itself is generic; the bash commands are not. |

**Average:** 4.6

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- **Bash commands in `references/pre-deploy.md` assume a specific project structure** (frontend/ + backend/ split, alembic migrations, ports 8000/5173, npm + pip stack). — references/pre-deploy.md:7-19, :86-99, :104-113, :125-139 — proposed fix: add a header note ("commands assume a frontend/backend split; adapt to your stack") and/or restructure as stack-conditional sections (TypeScript stack / Python stack / Go stack).
- Description 416 chars vs 200-char target — could trim the "Use this skill when..." middle clause (already redundant with trigger list). — SKILL.md:4-5

### Nits (won't block ship)
- Empty `owns` block on workflow skill is noise. — SKILL.md:9-12
- `cd frontend && npm run build` etc. use `cd` chained with `&&` — this won't work in a Bash tool that resets cwd; should use `(cd frontend && ...)` subshell or `npm --prefix frontend run build`. Minor.
- The "Output" template (lines 55-76) is solid but could move to a `references/report-template.md` if the report grows.
- Reference file pre-deploy.md is 157 lines; no TOC, but well-sectioned with H2 headers so navigation is fine.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Add stack-agnostic guidance to bash commands in pre-deploy.md** — references/pre-deploy.md:7-19, :86-99, :104-113, :125-139 — either add a header note that commands are templates needing adaptation, or restructure into conditional sub-sections per stack (TS / Python / Go / monorepo). Currently a project not matching the frontend+backend Python+npm assumption gets misleading commands.
2. **Trim description to ≤200 chars** — SKILL.md:4-5 — drop the "Use this skill when preparing for deployment, running pre-deploy checks..." sentence since it duplicates the trigger list.
3. **Fix `cd X && ...` chains to subshells** — references/pre-deploy.md:9, :13, :15, :17 — change `cd frontend && npm run build` to `(cd frontend && npm run build)` or `npm --prefix frontend run build` so it works in tool environments with non-persistent cwd.

## Dead links / broken references
- None. `references/pre-deploy.md` exists and is linked. All `composes_with` targets (infrastructure-agent, qe-agent, security-agent, observability-agent) exist. `spawned_by: ["orchestrator"]` resolves.
