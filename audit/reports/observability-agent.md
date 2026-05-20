# Audit: observability-agent

**Path:** skills/roles/observability-agent/SKILL.md
**Version:** 1.1.0
**Category:** roles
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields. Semver valid. owns block has 4 directories — `src/telemetry/`, `src/logging/`, `monitoring/`, `alerts/`. None overlap with backend/frontend/qe/perf/security. shared_read is `src/` (specific, good). No compatibility/metadata. |
| Description quality | 3 | 187 chars — under 200 target. Action verb "Sets up". Lists capabilities (logging, monitoring, metrics, alerting). Trigger contexts narrow as intended. |
| Progressive disclosure | 5 | Body 131 lines. references/monitoring-patterns.md 180 lines (well-organized by stack). Body links references at line 73 with explicit when-to-read. |
| Instruction clarity | 5 | Imperative voice throughout. Numbered steps 0–5. Process steps include concrete thresholds (error rate > 1%, p95 > 2s). Validation checklist inline at lines 124–128. |
| Coordination | 5 | Owns block clear and non-overlapping. Off-limits explicit. `composes_with` lists 3 collaborators. Coordination rules with backend-agent (line 116) explicitly call out "you provide the module, they import" — clean handoff. Coordination with infrastructure-agent and frontend-agent also explicit. |
| Completeness | 5 | monitoring-patterns.md exists with concrete Python/Node templates, Docker health checks, alert rules. Step 0 contracts present. Validation checklist inline. Health check coordination explicit. |
| Anti-patterns | 5 | Clean. No hardcoded paths. WHY explained. No emojis. |

**Average:** 4.6

## Findings

### Critical (must fix to ship)

None.

### Important (should fix)

- Description 187 chars is fine but `"Composed by orchestrator during multi-agent builds. Not user-invocable."` is redundant — SKILL.md:5 — drop to tighten further (current is OK but the redundancy is across all role agents).
- Missing `compatibility` string — SKILL.md frontmatter — add `compatibility: "Claude Code; requires Bash for instrumentation tooling"`.
- Self-referential pipeline blockquote — SKILL.md:20 — "Reports to `qe-agent` via `qa-report.json`" is template-bleed; observability-agent doesn't write that file.

### Nits (won't block ship)

- No `metadata` block.
- Validation checklist inline (lines 124–128) vs in references/validation-checklist.md — inconsistent with backend/frontend/qe/security/infra pattern. Most role agents have a dedicated file.
- monitoring-patterns.md covers Python+Node but not Go/Java/Ruby — could note these are TODO or follow same patterns.
- "Right-sizing" not explicit — body doesn't say "skip alerting for prototype builds" or similar.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Fix self-referential pipeline blockquote — SKILL.md:20 — change "Reports to `qe-agent` via `qa-report.json`" to "Provides instrumentation that `qe-agent` validates as part of QA". Effort: small.
2. Move inline validation checklist to references/validation-checklist.md — SKILL.md:124–128 — extract to dedicated file for ecosystem consistency. Effort: small.
3. Add `compatibility` field — SKILL.md frontmatter — declare host requirement. Effort: small.

## Dead links / broken references

None. `references/monitoring-patterns.md` exists. All `composes_with` targets (backend-agent, infrastructure-agent, frontend-agent) exist.
