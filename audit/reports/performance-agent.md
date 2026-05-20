# Audit: performance-agent

**Path:** skills/roles/performance-agent/SKILL.md
**Version:** 1.2.0
**Category:** roles
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields. Semver valid. owns block has `tests/performance/` and `load-tests/` — matches orchestrator/file-ownership.md carve-out. shared_read uses `*`. No compatibility/metadata. |
| Description quality | 3 | 207 chars over 200 target. Action verbs ("Designs and executes"). Lists capabilities (perf tests, load tests, benchmarks). Intentionally narrow as spawned-only. |
| Progressive disclosure | 5 | Body 137 lines. references/k6-patterns.md 140 lines, focused on one tool. Body links references at line 77 with explicit when-to-read. |
| Instruction clarity | 5 | Imperative voice. Numbered steps 0–4. Test scenario types defined precisely (smoke/load/stress/soak with VU counts and duration). Report template in step 4. |
| Coordination | 5 | Owns matches orchestrator/file-ownership.md `tests/performance/` carve-out. Off-limits explicit at line 52. `composes_with` lists 3 collaborators. Coordination rules explicitly note carve-out from qe-agent (line 122) and report-don't-fix boundary with backend-agent (line 123) and infrastructure-agent (line 124). |
| Completeness | 5 | k6-patterns.md exists with concrete templates for smoke/load/stress/soak. Step 0 contracts present. Report template in step 4. Validation checklist inline at lines 130–134. |
| Anti-patterns | 4 | k6-patterns.md uses `/api/v1/sessions` (mild project-specific). Body falls back to `references/k6-patterns.md` for all tools — says "follow the equivalent patterns adapted to that tool's syntax" which is reasonable but leaves Locust/JMeter/Artillery without their own templates. Overall clean. |

**Average:** 4.4

## Findings

### Critical (must fix to ship)

None.

### Important (should fix)

- Description 207 chars exceeds 200-char target — SKILL.md:5 — drop "Composed by orchestrator during multi-agent builds".
- k6-patterns.md hardcoded endpoint `/api/v1/sessions` — references/k6-patterns.md:35, 48, 135 — replace with `${RESOURCE_PATH}` placeholders so the template is project-agnostic.
- Missing `compatibility` string — SKILL.md frontmatter — add `compatibility: "Claude Code; requires Bash + k6 (or Locust/JMeter/Artillery)"`.

### Nits (won't block ship)

- No `metadata` block.
- Validation checklist inline (lines 130–134) instead of in references/validation-checklist.md — most other role agents have a dedicated validation-checklist.md reference. Either fine but inconsistent.
- Self-referential pipeline blockquote at line 20 — "Reports to `qe-agent` via `qa-report.json`" template-bleed; performance-agent writes a performance report that feeds QE's score, not the json itself.
- "Right-sizing" not explicit — body doesn't say "skip soak tests for prototype builds".

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Replace hardcoded endpoints with placeholders in k6-patterns.md — references/k6-patterns.md:35, 48, 135 — use `${RESOURCE_PATH}`. Effort: small.
2. Tighten description to ≤200 chars — SKILL.md:5 — drop redundant clause. Effort: small.
3. Move inline validation checklist to references/validation-checklist.md for consistency — SKILL.md:130–134 — extract to dedicated file. Effort: small.

## Dead links / broken references

None. `references/k6-patterns.md` exists. All `composes_with` targets (backend-agent, infrastructure-agent, qe-agent) exist.
