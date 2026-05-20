# Audit: work-item-brief

**Path:** skills/workflows/work-item-brief/SKILL.md
**Version:** 1.0.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields present; semver 1.0.0; no `<`/`>` in field values. Description measured at 635 chars (well under 1024). `allowed-tools` hyphenated. `owns.patterns: ["briefs/**/*.md"]` is meaningful and won't conflict with agent roles. `composes_with: ["grill-me", "plan-builder", "contract-author"]` — all 3 exist. |
| Description quality | 5 | 635 chars. Starts with action verb "Produce". 6 trigger phrases ("make a work-item brief", "write the agent brief", "agent-ready ticket", "make this dispatchable", "package this for an agent", "brief this"). Includes FORBIDDEN and REQUIRED callouts — distinctive and signal-rich. |
| Progressive disclosure | 5 | Body 92 lines / ~750 words — excellent. Three references (afk-hitl-rubric 56 lines, brief-format 109 lines, out-of-scope-pattern 79 lines) all linked from body with explicit "when to read" guidance (line 34, line 69, line 73). No reference >300 lines so no TOC needed. |
| Instruction clarity | 5 | Strong imperative voice ("Produce", "Strip", "Classify", "Save"). Six-step process. Forbidden list comes BEFORE required sections — correct priority. AFK/HITL classification explained with rubric reference. Closing reminder reinforces the load-bearing rule. |
| Coordination | 5 | All 3 `composes_with` targets exist. `owns.patterns: ["briefs/**/*.md"]` — doesn't conflict with any agent role's owns. "Composition" section (line 84-88) explicitly names handoff with grill-me / plan-builder / contract-author. |
| Completeness | 5 | All 3 reference files exist and are linked. `brief-format.md` includes a full worked example (subscription cancellation with grace period). `afk-hitl-rubric.md` has 4 worked scenarios. `out-of-scope-pattern.md` shows directory layout and file shape. Closing reminder ties everything together. |
| Anti-patterns | 5 | MUST/FORBIDDEN usage is justified (load-bearing rule against file paths/line numbers, repeated in closing reminder for emphasis). No hardcoded paths beyond conventional `briefs/` and `out-of-scope/`. No body↔reference duplication — body summarizes rules, references hold templates and worked examples. Reference's "anti-pattern" example (brief-format.md:96-107) shows the failure mode concretely. |

**Average:** 5.0

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- None.

### Nits (won't block ship)
- The repeated "FORBIDDEN" rule (body §"The Forbidden List", §"Key Interfaces Pattern", §"Closing Reminder", and `references/brief-format.md` §"Forbidden") is intentional emphasis but borders on triplication. Could be tightened by removing the §"Closing Reminder" and trusting the readers — they've seen it twice. (Stylistic preference; the current form is defensible as load-bearing rule reinforcement.)
- "AFK/HITL classification" — the abbreviation "AFK" (Away From Keyboard) and "HITL" (Human In The Loop) is jargon-heavy. Body line 22 announces "Using work-item-brief to package this for an agent" without explaining either. A one-line expansion in body line 45 or in the description would lower the cognitive cost.
- `references/brief-format.md:101` example uses `tests/cancel.test.ts` as a NEGATIVE example of brief content — clear in context, but a casual reader might miss that this is the anti-pattern block.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Expand AFK/HITL abbreviations on first use. — `skills/workflows/work-item-brief/SKILL.md:45` — change "AFK/HITL classification" to "AFK (Away From Keyboard) / HITL (Human In The Loop) classification" on first appearance. effort: small.
2. Optionally trim the §"Closing Reminder" if you trust the triple-mention is overkill. — `skills/workflows/work-item-brief/SKILL.md:90-92` — keep one strong rule statement in §"The Forbidden List" and the closing reminder, drop one if both feel like nagging. (Optional — current pattern works.) effort: small.
3. Add a clear "ANTI-PATTERN" or "DO NOT" header to the negative example in brief-format.md. — `skills/workflows/work-item-brief/references/brief-format.md:96-107` — the section is titled "Anti-pattern (what NOT to do)" but the code block could use an inline `# WRONG` comment for scanability. effort: small.

## Dead links / broken references
- None. All 3 references (`brief-format.md`, `afk-hitl-rubric.md`, `out-of-scope-pattern.md`) exist and are linked. All 3 `composes_with` targets (grill-me, plan-builder, contract-author) exist.
