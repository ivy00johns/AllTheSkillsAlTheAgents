# Audit: code-review-agent

**Path:** skills/roles/code-review-agent/SKILL.md
**Version:** 1.2.0
**Category:** roles
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields. Semver valid. owns.directories and owns.patterns are EMPTY arrays — intentional for a read-only audit role (matches body line 20 "Owns: none"). shared_read uses `*`. No compatibility/metadata. Line 141 references `allowed_tools` (underscore) in body prose, but the frontmatter field correctly uses `allowed-tools` (hyphen) — body prose should match canonical form. |
| Description quality | 3 | 218 chars over 200 target. Action verb "Reviews". Lists dimensions (quality, correctness, security, conventions). Intentionally narrow. |
| Progressive disclosure | 5 | Body 151 lines (within 150 guideline edge). references/review-rubric.md 72 lines, well-organized by dimension. Body links references at line 49 with explicit when-to-read. |
| Instruction clarity | 5 | Imperative voice. Numbered steps 1–4. Step 2 "Understand Context" explicitly mentions wiki-research integration. Step 4 includes a complete report template. Review Priorities (lines 130–137) provide clear ordering. |
| Coordination | 5 | Owns explicitly empty (read-only). Off-limits implicit via empty ownership + "never modify code" rule. `composes_with` lists 5 collaborators including wiki-research (line 14). "Feeding into QE and Security Workflows" section (lines 146–150) is the clearest QE/security handoff among all role agents. Routes findings via orchestrator (line 150). |
| Completeness | 5 | review-rubric.md exists with scoring criteria + severity definitions. Report template inline at step 4. Step 0 (Read Contracts) is implicit via Step 2 "Read the relevant contracts". |
| Anti-patterns | 4 | Body references `allowed_tools` (underscore alias) at line 141 instead of canonical `allowed-tools` — minor doc-frontmatter mismatch. No hardcoded paths. No emojis. Otherwise clean. |

**Average:** 4.4

## Findings

### Critical (must fix to ship)

None.

### Important (should fix)

- Body uses `allowed_tools` (underscore) at SKILL.md:141 — frontmatter correctly uses canonical `allowed-tools` (hyphen) at line 13. Either harmonize the body prose to match or drop the parenthetical entirely.
- Missing explicit "Step 0: Read Contracts" — SKILL.md:46–49 — Process starts at Step 1 "Read the Rubric". Step 2 mentions contracts but the contract-first pattern suggests Step 0 should be explicit. Promote Step 2's contract-reading bullet to Step 0.
- Self-referential pipeline blockquote — SKILL.md:20 — "Reports to `qe-agent` via `qa-report.json`" — code-review-agent produces a review report, doesn't write qa-report.json directly.

### Nits (won't block ship)

- No `metadata` block.
- No `compatibility` string.
- Description 218 chars over 200 target.
- "Right-sizing" not explicit — body doesn't say "skip code review for prototype builds".
- Report template uses `[brackets]` placeholders instead of `${PLACEHOLDER}` convention seen elsewhere.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Harmonize allowed-tools doc reference — SKILL.md:141 — change `(allowed_tools: Read, Grep, Glob)` to `(allowed-tools: Read, Grep, Glob)` to match canonical frontmatter form. Effort: small.
2. Promote contract-reading to Step 0 — SKILL.md:46–60 — restructure so Process starts with "0. Read Contracts and Project Profile" matching other role agents. Effort: small.
3. Fix self-referential pipeline blockquote — SKILL.md:20 — reword to "Review report feeds into `qe-agent`'s `correctness`, `code_quality`, and `contract_conformance` scores". Effort: small.

## Dead links / broken references

None. `references/review-rubric.md` exists. All `composes_with` targets (wiki-research, qe-agent, security-agent, backend-agent, frontend-agent) exist as directories.
