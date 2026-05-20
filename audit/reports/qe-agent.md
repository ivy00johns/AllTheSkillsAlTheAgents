# Audit: qe-agent

**Path:** skills/roles/qe-agent/SKILL.md
**Version:** 1.3.0
**Category:** roles
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields. Semver valid. owns block has directories, patterns, shared_read. shared_read uses `*`. composes_with includes `contract-auditor` (verify exists), `playwright` (verify exists). No compatibility/metadata block. Pattern ownership (`*.test.*`, `*.spec.*`) explicitly carved out in body (line 55) — directory ownership precedence noted. |
| Description quality | 4 | 256 chars — over 200 target but under ceiling. Action verb "Verifies". Three trigger contexts (contract conformance, integration, edge cases) + key role ("owns qa-report.json build gate"). Better than other role descriptions because it states the core capability. |
| Progressive disclosure | 5 | Body 124 lines. 4 well-organized reference files (qa-report-schema.md 63 lines, llm-judge-rubrics.md 64 lines, severity-thresholds.md 59 lines, validation-checklist.md 78 lines, qa-report-schema.json 102 lines). Body links each with explicit when-to-read (line 95–100). No duplicate content between body and references. |
| Instruction clarity | 5 | Imperative voice. Phases 1–4 + Static Analysis Mode. Explains WHY (e.g., "Stop on critical contract failures...no point integration testing broken interfaces"). Three-jobs-in-order at line 38. Crystal clear. |
| Coordination | 5 | Owns matches orchestrator/file-ownership.md (tests/ excl tests/performance/). Off-limits explicit at line 54 with carve-out note about `src/`-colocated tests. Coordinates with security-agent at line 41. `composes_with` lists 7 collaborators. |
| Completeness | 5 | All 5 reference files exist and linked. Schema JSON is canonical (machine-readable). Step 0/Phase 1 starts with contracts. Right-sizing addressed via tradeoff note at line 20 ("For prototype builds, skip the QA gate"). Off-limits explicit. Anti-pattern callout at line 117 ("Marking qa-report.json passing if any contract test was skipped"). |
| Anti-patterns | 5 | Clean. No hardcoded paths. WHY explained for MUST/NEVER (e.g., "Skipped tests are failures"). Validation-checklist uses placeholder vars but does have specific endpoint paths like `/api/v1/sessions` (mild project-specific bleed). |

**Average:** 4.7

## Findings

### Critical (must fix to ship)

None.

### Important (should fix)

- Description 256 chars exceeds 200-char target — SKILL.md:5 — tighten by removing "Composed by orchestrator during multi-agent builds" (redundant with "Orchestrator-dispatched only").
- Validation-checklist contains project-specific endpoint paths — references/validation-checklist.md:17, 40, 52, 56, 59, 64 — replace `/api/v1/sessions` with `${RESOURCE_PATH}` placeholders matching the rest of the file's pattern.
- Missing `compatibility` string — SKILL.md frontmatter — add e.g. `compatibility: "Claude Code; requires Bash + curl + python3 for JSON parsing"`.

### Nits (won't block ship)

- No `metadata` block.
- Pipeline-position blockquote at line 22 says "Reports to `qe-agent` via `qa-report.json`" — but QE *writes* the report, doesn't report to itself. Likely template artifact from other agents. Reword.
- shared_read uses `*` wildcard — broad; explicit list would be more auditable.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Fix self-referential pipeline blockquote — SKILL.md:22 — change "Reports to `qe-agent` via `qa-report.json`" to "Writes `qa-report.json` for the orchestrator". Effort: small.
2. Replace project-specific endpoints with placeholders — references/validation-checklist.md:17, 40, 52, 56, 59, 64 — change `/api/v1/sessions` to `${RESOURCE_PATH}`. Effort: small.
3. Tighten description to ≤200 chars — SKILL.md:5 — drop "Composed by orchestrator during multi-agent builds". Effort: small.

## Dead links / broken references

None. All 5 references (qa-report-schema.md, qa-report-schema.json, llm-judge-rubrics.md, severity-thresholds.md, validation-checklist.md) exist. All `composes_with` targets (backend-agent, frontend-agent, infrastructure-agent, security-agent, contract-auditor, performance-agent, playwright) exist as directories.
