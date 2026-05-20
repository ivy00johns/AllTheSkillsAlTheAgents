# Audit: ui-brief

**Path:** skills/workflows/ui-brief/SKILL.md
**Version:** 1.0.0
**Category:** workflows
**Verdict:** NEEDS WORK

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 3 | All required fields present; semver 1.0.0; no `<`/`>` in field values. `allowed-tools` hyphenated. **However, `composes_with` lists 4 skills that do not exist as in-repo skills:** `ui-ux-pro-max`, `frontend-design`, `brainstorming`, `ux-review`. (These DO appear in the user's plugin skill list as `frontend-design:frontend-design`, `superpowers:brainstorming`, but they are not native repo skills.) Only `frontend-agent`, `orchestrator`, `playwright` exist in repo. Spec doesn't explicitly forbid cross-plugin references but the audit checklist treats unresolvable composes_with as FAIL. |
| Description quality | 1 | Description is **1449 chars** (measured: `wc -c` on line 5), which exceeds Anthropic's 1024-char HARD CEILING. Per audit checklist this is a definitive FAIL. The content is otherwise strong (excellent trigger coverage, pushy, action-verb-led) but it must be trimmed by ~30% to ship. Score: 1. |
| Progressive disclosure | 4 | Body 186 lines / ~3000 words — within Anthropic's 5000-word guideline but past the 200-line/300-line house guidance. The 274-line `references/brief-template.md` is a reasonable reference. Body could be tightened — the long "How To Run" section (Steps 1-5) could move some of its prose into the template reference. |
| Instruction clarity | 5 | Strong imperative voice. Two-mode (Greenfield / Rebuild) split with clear hallmark phrases. Five-step flow with verification checklist at end. Explains WHY ("Generic briefs come from skipping this step"). Anti-patterns table is excellent. |
| Coordination | 2 | `composes_with` has 4 references to skills not in this repo (`ui-ux-pro-max`, `frontend-design`, `brainstorming`, `ux-review`). Even if interpreted as cross-plugin/external references, the spec doesn't define that semantic. Body text references these same names — if they're external, the body should disambiguate. |
| Completeness | 4 | Reference template exists (`brief-template.md`, 274 lines). Body line 181-186 references `THE-GAUNTLET.md` and `UI-CHALLENGE.md` as "examples of briefs that worked" — these are project-specific filenames at repos outside this codebase, so they may be unreadable for users running this skill. Body mentions "AllTheSkills repo root" (line 183) which is the OLD project name (renamed to Skill Madness). |
| Anti-patterns | 4 | One hardcoded old project name ("AllTheSkills repo root", line 183). Body uses MUST sparingly and with justification. No body↔reference duplication (template is structural skeleton, body is operational guide). Generally well-written and self-aware. |

**Average:** 3.29

**Verdict driver:** description_quality=1 (1449 chars > 1024 hard ceiling) and coordination=2 are below 3, pushing this to NEEDS WORK / borderline MAJOR REWORK. The body and instructions are excellent; the FAIL is entirely in frontmatter discipline.

## Findings

### Critical (must fix to ship)
- **Description exceeds 1024-char hard ceiling (1449 chars measured).** — `skills/workflows/ui-brief/SKILL.md:5` — `wc -c` confirms 1449 chars on the description line, which exceeds Anthropic's spec maximum (audit checklist: "Description >1024 chars (hard FAIL)"). Trim by ~30%. Suggested cuts: (1) collapse the long named-style enumeration "(bento-grid, glassmorphism, claymorphism, brutalism, neumorphism, minimalism, skeuomorphism)" into "named visual styles", (2) collapse the long reference-app enumeration "(Linear, Notion, Figma, Arc, Stripe, Vercel, Datadog, Bloomberg, Posthog, etc.)" into "named reference apps", (3) drop the "Also trigger before invoking ui-ux-pro-max / frontend-design / frontend-agent..." sentence which is redundant with the earlier trigger list.
- `composes_with` references skills that don't exist in this repo. — `skills/workflows/ui-brief/SKILL.md:14` — `ui-ux-pro-max`, `frontend-design`, `brainstorming`, `ux-review` are not present in `skills/`. Either (a) remove them from `composes_with`, (b) clarify in the spec that `composes_with` may reference external plugin skills (then prefix them, e.g., `plugin:frontend-design`), or (c) add them as in-repo skills. Per the current frontmatter spec, `composes_with` "lists real skill names" — these aren't.

### Important (should fix)
- Hardcoded old project name "AllTheSkills repo root" — should be "Skill Madness repo root" or removed. — `skills/workflows/ui-brief/SKILL.md:183`.
- Body length (186 lines) is at the warn threshold. The "How To Run" section (Steps 1-5) could move 30-40 lines into a `references/process-guide.md`. Optional optimization.

### Nits (won't block ship)
- Line 152 — "Show, do not narrate" is good advice but could be sharpened: it's the only mention; consider a one-liner in the Step 5 verification checklist.
- Anti-patterns table line 168 says "First-person plural ('we', 'the user') sparingly" — confusing because "the user" is third-person. Should be "first-person plural ('we', 'us')" or "second-person ('you')".

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **CRITICAL: Reduce description from 1449 → ≤1024 chars (target ≤800 for headroom).** — `skills/workflows/ui-brief/SKILL.md:5` — collapse the long named-style enumeration ("bento-grid, glassmorphism, claymorphism, brutalism, neumorphism, minimalism, skeuomorphism") into "named visual styles"; collapse the long reference-app enumeration ("Linear, Notion, Figma, Arc, Stripe, Vercel, Datadog, Bloomberg, Posthog, etc.") into "named reference apps"; drop the redundant "Also trigger before invoking..." sentence. effort: small.
2. Fix broken `composes_with` references. — `skills/workflows/ui-brief/SKILL.md:14` — either drop the four non-existent names (`ui-ux-pro-max`, `frontend-design`, `brainstorming`, `ux-review`) leaving only the in-repo skills (`orchestrator`, `frontend-agent`, `playwright`), OR add a frontmatter spec extension for external/plugin references (e.g., `composes_with_external: [...]`) and migrate the four names. effort: small-to-medium.
3. Replace "AllTheSkills repo root" with "Skill Madness repo root" (or remove the example). — `skills/workflows/ui-brief/SKILL.md:183` — find/replace. effort: small.

## Dead links / broken references
- `composes_with: ["ui-ux-pro-max", "frontend-design", "frontend-agent", "orchestrator", "ux-review", "playwright", "brainstorming"]` — 4 of 7 (`ui-ux-pro-max`, `frontend-design`, `ux-review`, `brainstorming`) do NOT exist as in-repo skills. They DO exist in the user's plugin ecosystem but the frontmatter spec treats `composes_with` as in-repo only.
- Body line 183 references "`THE-GAUNTLET.md` at the AllTheSkills repo root" — old project name; both the project name and the external file reference may be unreadable for users not on the original machine.
- Body line 184 references "`UI-CHALLENGE.md` at the MarketsBeRigged repo root" — same issue: external repo, may not be accessible to all users.
