# Audit: skill-writer

**Path:** skills/meta/skill-writer/SKILL.md
**Version:** 1.2.0
**Category:** meta
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields present; valid semver (1.2.0); no angle brackets; description 376 chars (within 1024 ceiling); allowed-tools hyphenated; owns block present (correctly empty for a meta skill that doesn't claim filesystem ownership); composes_with lists real skills (project-profiler, orchestrator). spawned_by empty (correct — this is a user-facing skill). |
| Description quality | 4 | Action verb ("Generate"), 4+ trigger contexts ("create a skill", "new agent", "write a SKILL.md", "needs to add a role"), keyword variants present, plus an "Also use when" exclusion clause for reviewing existing skills. 376 chars overshoots the 200-char target but stays well under 1024. Could be tightened by ~100 chars without losing trigger coverage. |
| Progressive disclosure | 5 | Body 131 lines / ~819 words — well within all guidelines. Two references (frontmatter-spec.md at 247 lines, description-patterns.md at 83 lines) both linked from the body with explicit "when to read" guidance ("See `references/frontmatter-spec.md` for the complete field reference", "See `references/description-patterns.md` for templates"). frontmatter-spec.md is below the 300-line TOC threshold. |
| Instruction clarity | 5 | Numbered steps (Step 1-5) with imperative voice ("Choose the Skill Type", "Write the Frontmatter", "Validate the Skill"). Skill-type selection table at L52-59 is crisp. Body-structure list at L75-90 is well organized with sub-bullets for agent-role specifics. Common Mistakes section at L119-126 names anti-patterns with one-line rationales. |
| Coordination | 4 | composes_with: project-profiler and orchestrator — accurate (project-profiler generates CLAUDE.md which feeds skill design; orchestrator dispatches skill creation when needed). spawned_by empty is correct. Missing: could include skill-review and skill-update in composes_with since those skills explicitly reference skill-writer's frontmatter-spec.md as authoritative. |
| Completeness | 5 | Both reference files exist: frontmatter-spec.md (247 lines, the canonical spec referenced by every other meta skill), description-patterns.md (83 lines). Validate-the-Skill checklist at Step 5 is concrete. Skill directory structure illustrated. v1.1 resolved-conflicts table referenced. |
| Anti-patterns | 5 | Common Mistakes section explicitly enumerates 6 anti-patterns including "Hardcoded project details — Global skills never change per project. Use profile.yaml." Body uses imperative voice throughout. No emojis. No excessive MUST/NEVER. No hardcoded paths. |

**Average:** 4.71

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Description at 376 chars is ~1.9x the 200-char house target. SKILL.md:5 — proposed fix: trim "Also use when reviewing existing skills for spec compliance." (covered by skill-review) and tighten the keyword list. Target: under 250 chars while keeping the action verb + 3 trigger contexts + keyword variants.

### Nits (won't block ship)
- composes_with should include `skill-review` and `skill-update` — SKILL.md:14 — both reference skill-writer's frontmatter-spec.md as authoritative; updating composes_with would make the composition graph more accurate.
- "Skill Directory Structure" diagram at L31-37 shows `templates/` as a subdirectory of `references/` but no actual skill in this repo nests templates inside references. SKILL.md:31-37 — either remove the templates/ subdirectory line or document why nesting is recommended.
- Common Mistakes section references "v1.1 resolved conflicts table" at L125 without a direct link to where the table lives (it's in frontmatter-spec.md §Resolved Conflicts). Add the section anchor: `references/frontmatter-spec.md#resolved-conflicts-v10--v11`.
- Step 5 Validate checklist references "v1.1 resolved conflicts" but doesn't tell the writer to actually `git grep` or check ownership against existing skills — could add a concrete command.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Trim description to under 250 chars** — SKILL.md:5 — remove "Also use when reviewing existing skills for spec compliance." (skill-review's job) and consolidate keyword variants. Target ≤250 chars. Effort: small.
2. **Add skill-review and skill-update to composes_with** — SKILL.md:14 — change to `composes_with: ["project-profiler", "orchestrator", "skill-review", "skill-update"]`. Effort: trivial.
3. **Link to frontmatter-spec.md's Resolved Conflicts section directly** — SKILL.md:125 — change "Check the v1.1 resolved conflicts table" to "Check `references/frontmatter-spec.md` §Resolved Conflicts (v1.0 → v1.1)". Effort: trivial.

## Dead links / broken references
- None. Both `references/frontmatter-spec.md` and `references/description-patterns.md` exist. `composes_with` targets (project-profiler, orchestrator) both exist locally.
