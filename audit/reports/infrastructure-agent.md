# Audit: infrastructure-agent

**Path:** skills/roles/infrastructure-agent/SKILL.md
**Version:** 1.1.0
**Category:** roles
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields present; semver valid; owns block has directories + patterns; shared_read uses `*` (broad but documented as appropriate). No `compatibility` or `metadata`. Field order has disable-model-invocation before description (OK). |
| Description quality | 3 | 215 chars — over 200 target, under 1024 ceiling. Action verb "Builds" present. Trigger contexts narrow ("Orchestrator-dispatched only") which is intentional. Lacks variants. |
| Progressive disclosure | 5 | Body 103 lines — under 150 line target. References/validation-checklist.md 78 lines. Body links references at line 102. |
| Instruction clarity | 4 | Imperative voice. Numbered steps 0–6. Process sections (1–6) are terse — one-liners that may not guide a fresh LLM to a complete artifact (e.g., "Makefile: up, down, build, logs, clean, dev"). Step 0 Read Contracts present. WHY explained for some items (e.g., port collision preflight in checklist), but body is light on WHY. |
| Coordination | 5 | Owns matches orchestrator/file-ownership.md exactly. Off-limits explicit at line 53. `composes_with` lists 5 collaborators — all exist. Coordination rules with deployment-checklist (96), observability-agent (97), qe-agent (98) clearly stated. |
| Completeness | 5 | validation-checklist.md exists, linked at line 102. Includes critical "host-port collision preflight" — concrete and load-bearing. All sections present including observability wiring. |
| Anti-patterns | 5 | Clean. No hardcoded paths (uses placeholders like `${BACKEND_PORT}`). No excessive MUST/NEVER. No emojis. Body lean (anti kitchen-sink). |

**Average:** 4.4

## Findings

### Critical (must fix to ship)

None.

### Important (should fix)

- Process steps too terse — SKILL.md:66–88 — sections 1–6 are 1–2 lines each. Add 2–3 concrete sub-bullets each so a fresh LLM produces complete artifacts (e.g., for "Docker Configuration" specify base image guidance, multistage pattern, USER directive).
- Description 215 chars exceeds 200-char target — SKILL.md:5 — drop "Composed by orchestrator during multi-agent builds" (redundant with "Orchestrator-dispatched only").
- Missing `compatibility` string — SKILL.md frontmatter — add `compatibility: "Claude Code; requires Bash + docker CLI + lsof for port preflight"`.

### Nits (won't block ship)

- No `metadata` block (author/category/tags).
- "Right-sizing" not explicit in body — checklist has port-collision-preflight but body itself doesn't say "skip k8s/terraform for simple projects" (line 36 mentions "not needed for simple projects" but no right-sizing heading).
- shared_read uses `*` — broad; explicit list would be more auditable (e.g., `["src/", "contracts/", "tests/"]`).

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Expand terse process steps — SKILL.md:66–88 — flesh out steps 1–6 with concrete sub-bullets so a fresh agent produces complete configs. Effort: medium.
2. Tighten description to ≤200 chars — SKILL.md:5 — remove redundant "Composed by orchestrator..." clause. Effort: small.
3. Add `compatibility` field — SKILL.md frontmatter — declare Bash + docker CLI requirement. Effort: small.

## Dead links / broken references

None. `references/validation-checklist.md` exists. All `composes_with` targets (backend-agent, frontend-agent, qe-agent, deployment-checklist, observability-agent) exist.
