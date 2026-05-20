# Audit: diagnose-loop

**Path:** skills/workflows/diagnose-loop/SKILL.md
**Version:** 1.0.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields valid; description 603 chars (under 1024 ceiling, over 200 target); `allowed-tools` hyphenated; no `<`/`>`; field order correct. `composes_with: ["playwright", "qe-agent"]` — both exist. Empty `owns` block fields harmless workflow noise. |
| Description quality | 5 | Action verb implicit ("Disciplined bug-diagnosis loop"); 9+ explicit trigger phrases including conversational ones ("staring at this for an hour", "I can't reproduce it", "it sometimes fails"); explains the core thesis (Phase 1 IS the skill). Pushy and load-bearing. |
| Progressive disclosure | 5 | Body 84 lines / under 2000 words; two reference files + one script all linked from body with explicit "when to read" guidance (lines 45, 65); no duplication — body has the phase structure, references have concrete recipes and worked examples. Reference files (feedback-loop-recipes 187 lines, hypothesis-format 71 lines) are well-sectioned. |
| Instruction clarity | 5 | Imperative voice; 6-phase numbered structure with explicit "Phase 1 IS the skill" emphasis; 10 ranked loop construction methods; explicit anti-pattern at end ("Forbidden: Skipping Phase 1"). Each phase explains the why (e.g., "Reading code without a loop is guessing with extra steps"). |
| Coordination | 4 | `composes_with: ["playwright", "qe-agent"]` — both exist. Phase 1 method 5 references `playwright` skill (line 38); Phase 5 references `architecture-rescue` as follow-up (line 73) but architecture-rescue is NOT in composes_with — should be added. `spawned_by: []` reasonable for a user-invoked diagnostic. |
| Completeness | 5 | All referenced files (`references/feedback-loop-recipes.md`, `references/hypothesis-format.md`, `scripts/hitl-loop.template.sh`) exist and are linked. 10 recipe methods each have when/loop/sharpen subsections. 3 worked hypothesis examples. Cleanup checklist explicit (`grep -r '\[DEBUG-xxxx\]'`). |
| Anti-patterns | 5 | No hardcoded project details; one explicit forbidden anti-pattern with rationale (line 84); ranked methods avoid kitchen-sink approach (use cheapest that works); explicit tradeoff caveat at top (line 20) gives the LLM permission to skip phases for trivial bugs. |

**Average:** 4.7

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- **`composes_with` missing `architecture-rescue`** — SKILL.md:14 vs :73 — line 73 explicitly recommends invoking architecture-rescue as a follow-up when a missing seam blocks Phase 5; should declare reciprocally.
- Description 603 chars vs 200 target — could trim the methodology preamble (Phase enumeration repeats in body) and keep the trigger keywords. — SKILL.md:4-5

### Nits (won't block ship)
- Empty `owns` block fields are workflow-skill noise. — SKILL.md:9-12
- `mattpocock` attribution at line 20 lacks a URL.
- Reference `feedback-loop-recipes.md` is 187 lines without a TOC — close to but under the 300-line threshold. Section headers are clear (1-10 numbered) so navigation is fine.
- "Adapted from mattpocock's `diagnose` pattern" is the only attribution; could include a URL.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Add `architecture-rescue` to `composes_with`** — SKILL.md:14 — change `composes_with: ["playwright", "qe-agent"]` to `composes_with: ["playwright", "qe-agent", "architecture-rescue"]`. Body line 73 explicitly recommends invoking it; frontmatter should reflect.
2. **Trim description to ≤200 chars** — SKILL.md:4-5 — keep action verb + trigger phrases; move the phase enumeration ("reproduce, hypothesize, instrument, fix, regression-test, cleanup") to the body where it's already explained.
3. **Add URL to mattpocock attribution** — SKILL.md:20 — link the upstream `diagnose` pattern for provenance.

## Dead links / broken references
- None. All three files in references/ + scripts/ exist and are linked. `composes_with` targets exist. Cross-skill reference to `architecture-rescue` (body line 73) resolves but is missing from composes_with.
