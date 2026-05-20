# Audit: skill-update

**Path:** skills/meta/skill-update/SKILL.md
**Version:** 1.1.0
**Category:** meta
**Verdict:** NEEDS WORK

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 3 | All required fields present; valid semver; no angle brackets; allowed-tools hyphenated. owns.directories = `["skills/"]` is a meta-level claim (this skill writes across all skill dirs to apply edits) — but it conflicts ideologically with the agent ownership model (which is for project source, not the skill repo). composes_with lists real skills. Description 595 chars (under ceiling, over target). |
| Description quality | 2 | Action verb ("Plan and apply"), 9 keyword variants — good triggers. BUT: references stale `skill-deep-review` and `skill-audit` skill names which are both archived (now consolidated into `skill-review` with two modes). This makes the description trigger on phrases that reference dead skills, and confuses users about the current workflow. 595 chars overshoots 200-char target by ~3x. |
| Progressive disclosure | 5 | Body 142 lines / ~1017 words — within all guidelines. Two references (plan-format.md at 128 lines, validation-checklist.md at 80 lines) linked from the body with explicit "when to read" context (L72 and L105). Both under 300-line TOC threshold. |
| Instruction clarity | 5 | Numbered Steps 1-5 with imperative voice ("Parse the Feedback", "Draft the Edit Plan", "Walk the User Through Edits"). Each step has sub-bullets. Impact/Effort scoring (1-3) explicit. Explicit edit-application rules at L86-91 (read before editing, one logical change per call). Error Handling and Guidelines sections concrete. |
| Coordination | 4 | composes_with: skill-review, skill-writer, sync-skills — all real. spawned_by empty (correct, user-invoked). owns.directories `["skills/"]` is broad — could conflict with skill-writer's claim (which is empty) or any future skill that wants to claim a slice. Probably correct as a meta-level claim but worth a body comment. |
| Completeness | 4 | Both reference files exist. validation-checklist.md is concrete. plan-format.md provides the bullet schema. BUT: body references `skill-deep-review` and `skill-audit` at L5, L24, L29, L33, L45 — these skill names no longer exist in the active ecosystem (both in archive/). Five stale references erode trust in the doc. |
| Anti-patterns | 4 | Guidelines section explicitly warns against batch reformatting and pure-style edits ("Skip pure style preferences"). Imperative voice. Read-before-edit rule named at L87. No emojis. Minor: L100 says "warn over ~100 lines when content could move to references" but house style is 200/500 lines — slight inconsistency with the broader spec. |

**Average:** 3.86

## Findings

### Critical (must fix to ship)
- Body and description reference `skill-deep-review` and `skill-audit` — both archived — 5 instances at SKILL.md:5, L24, L29, L33, L45. Proposed fix: replace all references with `skill-review` (the consolidated skill that now covers both modes). Description rewrite: `Plan and apply changes to an existing skill in one workflow. Reads a skill-review report (Mode A bulk or Mode B deep dive) or inline findings, drafts an edit list...`

### Important (should fix)
- L100 says "warn over ~100 lines when content could move to references" — SKILL.md:100 — inconsistent with house style (200/500 lines per validation-checklist.md and frontmatter-spec.md). Update to match: "≤5,000 words and ≤500 lines (soft warnings); flag past ~200 lines when content could move to references."
- owns.directories `["skills/"]` may collide with the agent-ownership model — SKILL.md:10 — add a body comment noting this is a meta-level write claim (the skill needs to edit any SKILL.md to apply review fixes), and explicitly carve out that this doesn't apply to project source directories.

### Nits (won't block ship)
- Description 595 chars overshoots 200-char target. SKILL.md:5 — after replacing stale skill names, also trim trigger-phrase list to 5 strongest variants.
- Validation step 4 at L99 references the frontmatter spec by full path `skills/meta/skill-writer/references/frontmatter-spec.md` — fine, but inconsistent with how other skills reference siblings (some use relative `references/`). Either form works; consistency would be nice.
- Step 5 sync command at L120 is a hardcoded bash path — `skills/workflows/sync-skills/scripts/sync-skills.sh --to-all` — currently correct but if sync-skills moves, this breaks. Could invoke as `/sync-skills` slash command instead for robustness.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Replace all 5 stale references to `skill-deep-review` and `skill-audit` with `skill-review`** — SKILL.md:5, 24, 29, 33, 45 — both old skills are in `skills/archive/`; the active replacement is `skill-review` with two modes (--scope=all bulk, --scope=<name> deep). Effort: small (find-and-replace + adjust phrasing).
2. **Update line-count guidance to match house style** — SKILL.md:100 — change "warn over ~100 lines" to "≤5,000 words and ≤500 lines (soft warnings); flag past ~200 lines when content could move to references" to align with validation-checklist.md and frontmatter-spec.md. Effort: trivial.
3. **Document the meta-level scope of `owns.directories: ["skills/"]`** — SKILL.md:10 — add a body comment (perhaps in Guidelines) noting this is a meta-skill claim that doesn't participate in the agent-role ownership map. Effort: small.

## Dead links / broken references
- `skill-deep-review` referenced at SKILL.md:5, 24, 33, 45 — **broken** (skill is in `skills/archive/skill-deep-review/`, not in active ecosystem).
- `skill-audit` referenced at SKILL.md:5, 24, 29, 33, 45 — **broken** (skill is in `skills/archive/skill-audit/`).
- All other references resolve: plan-format.md, validation-checklist.md, frontmatter-spec.md, composes_with targets (skill-review, skill-writer, sync-skills).
