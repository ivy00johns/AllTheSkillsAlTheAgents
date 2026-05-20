# Audit: grill-me

**Path:** skills/workflows/grill-me/SKILL.md
**Version:** 1.0.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields valid; description 656 chars (under 1024 ceiling, over 200 target); double-quoted YAML scalar (contains apostrophes that need escaping/quoting); `allowed-tools` hyphenated; no `<`/`>`; field order correct. `composes_with: ["architecture-rescue", "maintain-context", "plan-builder"]` — all three exist. Empty `owns` fields harmless workflow noise. |
| Description quality | 5 | Action verb "Get"; 9 explicit trigger phrases including conversational ones ("I'm not sure what I want", "help me think this through"); explains methodology in one sentence; pushy. The depth-first / one-question-at-a-time discipline is encoded in the description. |
| Progressive disclosure | 5 | Body 27 lines — exceptionally tight. No references needed because the entire skill content fits on a screen. Right-sized for a methodology skill with a single core discipline. |
| Instruction clarity | 5 | Imperative voice; three numbered rules with rationale; explicit exit condition; output format specified ("paste into a plan or brief — one bullet per decision"). An LLM following these would produce correct output. |
| Coordination | 5 | `composes_with: ["architecture-rescue", "maintain-context", "plan-builder"]` — all three exist; body line 27 explicitly describes WHEN to compose with each. Symmetric: architecture-rescue's composes_with also lists grill-me. |
| Completeness | 5 | No external refs to validate. Three composition triggers documented inline. Exit condition + output format explicit. Could not be more complete for its scope. |
| Anti-patterns | 5 | No hardcoded paths; rules have rationale (not bare MUST/NEVER); explicitly avoids the batch-question anti-pattern (rule 1); explicitly avoids ask-when-code-knows anti-pattern (rule 3). No kitchen sink. |

**Average:** 4.9

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Description 656 chars vs 200-char target. The methodology preamble (depth-first / one-question-at-a-time / prefers code) is already in the body and could be cut from the description. — SKILL.md:4

### Nits (won't block ship)
- Empty `owns` block fields are workflow-skill noise. — SKILL.md:8-11
- The description uses double-quoted scalar with apostrophes inside — valid YAML but multiline `|` form would be cleaner.
- The "Compose with" line at the end could be `## Compose with` H2 for consistency with other skills.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Trim description to ≤200 chars** — SKILL.md:4 — keep action verb + trigger phrases; move the depth-first / one-question-at-a-time / code-vs-user methodology summary into the body (it's already there at lines 19-23).
2. **Remove empty `owns` block** — SKILL.md:8-11 — workflow skill; ownership fields don't apply.
3. **Convert description to multiline `|` YAML** — SKILL.md:4 — current double-quoted form with embedded apostrophes is harder to read than `description: |` block scalar form.

## Dead links / broken references
- None. All three `composes_with` targets exist. No `references/` directory needed.
