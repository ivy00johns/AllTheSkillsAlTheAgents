# Audit: playwright

**Path:** skills/workflows/playwright/SKILL.md
**Version:** 1.2.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields; semver 1.2.0; canonical hyphenated `allowed-tools`; description uses YAML `\|` literal block; all 3 `composes_with` targets resolve (qe-agent, frontend-agent, deployment-checklist); both `spawned_by` parents resolve and orchestrator/qe-agent both reference playwright back. |
| Description quality | 4 | 616 chars — under 1024 ceiling, ~3× the 200-char target. Action verb "Run"; 10 explicit trigger phrases in quotes; cross-reference to qe-agent integration testing. Trimmable. |
| Progressive disclosure | 5 | Body 84 lines / well under any threshold. Three references — `setup.md` (188), `screenshot-workflow.md` (144), `selectors-guide.md` (74) — each linked from the body with explicit purpose (lines 82–84). Body delegates aggressively rather than duplicating. |
| Instruction clarity | 5 | Imperative voice; two clearly-named modes (Report / Spot-Check); numbered 5-step workflow; concrete shell snippets for setup/version check. Spot-Check section explains the human-in-the-loop pause discipline. |
| Coordination | 5 | Stateless skill; empty owns correct; reciprocal `spawned_by` ↔ orchestrator/qe-agent verified (qe-agent SKILL.md:14 lists playwright in `composes_with` and the body at line 74 explicitly invokes via "/playwright skill"). |
| Completeness | 5 | All three reference files exist; full workflow (`navigate → interact → assert → screenshot`) defined; troubleshooting quick checklist + reference link; output directory convention specified (`playwright-screenshots/` and `playwright-results/` both gitignored). |
| Anti-patterns | 5 | No emojis; no hardcoded project paths (uses generic `playwright-screenshots/<run-id>/`); MUSTs are absent; no body/reference duplication. |

**Average:** 4.86

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Description is 616 chars — trimmable to ~300. The 10 quoted trigger phrases are good but overlap heavily ("browser test" / "test in chrome" / "e2e test"). — SKILL.md:5 — proposed fix: consolidate to 4–5 canonical trigger phrases and keep the qe-agent integration mention.

### Nits (won't block ship)
- `compatibility` field absent; skill requires Bash + npm + Chromium + macOS/Linux. For Linux there's a specific `install-deps` step (line 75). Declaring this in `compatibility` would set expectations. — SKILL.md:8
- Setup section duplicates content from `references/setup.md` (lines 38–49) — the `npx playwright --version` check and install commands appear in both. Acceptable as "scannable quick path" but slight duplication. — SKILL.md:38–49 vs references/setup.md
- "Spot-Check Mode" is described twice: once briefly in the Two Modes section (line 28–30), then again at line 63–65. Slight redundancy. — SKILL.md:28–30,63–65
- The qe-agent handoff section at line 67–69 references "Phase 2 (Integration Verification)" — this is qe-agent-specific terminology; cross-check that qe-agent uses that exact phase label.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Trim description from 616 → ~300 chars — SKILL.md:5 — collapse the 10 trigger phrases to 4–5 distinct ones; keep "Also use when qe-agent needs browser-level integration testing" line. Effort: small.
2. Add `compatibility` field — SKILL.md:8 — declare "Claude Code; requires Bash, Node/npm, Chromium (auto-installed); on Linux requires `playwright install-deps`." Effort: small.
3. Resolve the two Spot-Check Mode sections — SKILL.md:28–30,63–65 — merge into one section, or trim line 63–65 to a one-liner that links to references/screenshot-workflow.md. Effort: small.

## Dead links / broken references
- None. All 3 reference files exist. All 3 `composes_with` targets resolve. Both `spawned_by` parents reference playwright back.
