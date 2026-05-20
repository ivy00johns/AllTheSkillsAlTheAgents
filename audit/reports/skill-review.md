# Audit: skill-review

**Path:** skills/meta/skill-review/SKILL.md
**Version:** 1.1.0
**Category:** meta
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields present; valid semver (1.1.0); description 585 chars (under 1024 ceiling); no angle brackets; allowed-tools hyphenated; argument-hint present and concrete ("skill-name or 'all'"); owns block correctly empty; shared_read declared (`["skills/"]`); composes_with lists real skills (skill-update, skill-writer). |
| Description quality | 4 | Action verb ("Review"), describes two modes, 10+ trigger phrase variants ("audit skills", "review this skill", "health check skills", "is this skill any good", "bulk review", "what needs fixing"). 585 chars overshoots 200-char target but stays under 1024. The "100-line rule" reference is stale — house style is now 500 lines (per frontmatter-spec.md L226) — should be updated. |
| Progressive disclosure | 5 | Body 143 lines / ~1149 words — within all guidelines. Three references all linked from the body with explicit "when to read" context. audit-checklist.md (100 lines) linked at L141 and L62. deep-review-rubric.md (155 lines) linked at L142 and L84. report-format.md (210 lines) linked at L143 and L116. All under 300-line TOC threshold. |
| Instruction clarity | 5 | Two-mode dispatch (Mode A bulk / Mode B deep dive) clearly distinguished with explicit decision logic in Phase 0. Numbered phases (A1/A2/A3, B1/B2/B3) with imperative voice. Each phase explains WHY (e.g., "Optimize for speed" in Mode A vs "Take time" in Mode B). Output Handoff section provides explicit user-facing message template. |
| Coordination | 5 | composes_with: skill-update, skill-writer — accurate (skill-update consumes skill-review's JSON sidecar per L125-127; skill-writer's frontmatter-spec.md is the authoritative reference). spawned_by empty (correct — user-invoked). No ownership overlaps (owns is empty). |
| Completeness | 5 | All 3 reference files exist and are well-structured. report-format.md provides the exact output schema (referenced by this audit run). deep-review-rubric.md has 1-5 scoring per dimension with verdict thresholds. audit-checklist.md has both per-skill and ecosystem-level checks plus the anti-pattern list. |
| Anti-patterns | 5 | Guidelines section actively prevents nitpicking ("Don't nitpick style if the skill is functionally sound"). Imperative voice throughout. No emojis. Mode A explicitly tells the reviewer NOT to read reference contents unless checking for orphans — guards against over-reading. WHY explained for low-impact checks. |

**Average:** 4.86

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Description references "the 100-line rule" — SKILL.md:6 — but house style is now 500 lines (per `references/frontmatter-spec.md` L226 and `audit-checklist.md` L33). Proposed fix: change "adherence to the 100-line rule" to "adherence to the 500-line/5000-word body guidelines" in the description.

### Nits (won't block ship)
- Description at 585 chars overshoots 200-char target. SKILL.md:6 — could trim some of the trigger-phrase enumeration (10+ variants is generous); aim for ~350-400 chars with the strongest 5 variants.
- Phase 4 (Report) at L114 doesn't follow the A1/A2/A3 / B1/B2/B3 naming convention — calling it "Phase 4" is jarring after Mode A phases A1-A3 and Mode B phases B1-B3. Consider renaming to "C: Report" or "Shared Phase: Report".
- L96 mentions "If `/skill-creator` is available, use its eval infrastructure" — skill-creator is referenced but not in composes_with at L15. Either add it to composes_with or note in body that it's an external/optional integration.
- L121 conditional file paths ("repo root or user-specified path") — could be a one-line CLI flag example for clarity: `skill-review --scope=all --output=reports/`.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Update the stale "100-line rule" reference in the description** — SKILL.md:6 — change "100-line rule" to "500-line/5000-word body guidelines" to match current house style. Effort: trivial.
2. **Trim description from 585 → ~400 chars** — SKILL.md:6 — keep the strongest 5 trigger variants ("audit skills", "review this skill", "bulk review", "deep review", "what needs fixing"); drop "is this skill any good", "scan all skills", "check my skills". Effort: small.
3. **Add skill-creator to composes_with (or document as external)** — SKILL.md:15 — change to `composes_with: ["skill-update", "skill-writer", "skill-creator"]` since L96-103 explicitly invoke it. Alternatively add a body note that skill-creator is an optional external plugin. Effort: trivial.

## Dead links / broken references
- None. All 3 reference files (audit-checklist.md, deep-review-rubric.md, report-format.md) exist. composes_with targets (skill-update, skill-writer) both exist locally. `frontmatter-spec.md` reference at L68 resolves to `skills/meta/skill-writer/references/frontmatter-spec.md` (linked via skill-writer). `/skill-creator` is an external skill present in the available-skills plugin list — referenced but not declared in composes_with (see nit above).
