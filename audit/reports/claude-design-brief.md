# Audit: claude-design-brief

**Path:** skills/workflows/claude-design-brief/SKILL.md
**Version:** 1.3.0
**Category:** workflows
**Verdict:** NEEDS WORK

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 2 | **HARD FAIL: description is 1191 chars — exceeds the 1024 hard ceiling.** All other fields valid (`name`, `version`, `allowed-tools` hyphenated, no `<`/`>`); reserved `claude-` prefix is documented in body line 20 per spec, so that's WARN-cleared. Field order follows house style. Empty `owns.directories`/`patterns` with `shared_read: ["*"]` is the usual workflow-skill noise. |
| Description quality | 4 | Content is excellent — action verb, 11+ trigger phrases, explicit sibling-distinction from `ui-brief`, audience scope ("Works for any product type"). But the length violation undermines the score even though the content is good. |
| Progressive disclosure | 4 | Body 120 lines / well under 2000 words; 5 reference files + 3 direction-example files all linked from body with clear "when to read" guidance (lines 30, 55-59, 109-118); no duplicate content between body and refs. References themselves are well-scoped. |
| Instruction clarity | 5 | Five numbered steps under "How To Run", imperative voice ("Read the source material", "Decide The Defaults"), clear verification checklist (lines 92-101). The "decide for me" anti-pattern guidance is sharp. "Announce at start" pattern is good. |
| Coordination | 4 | `composes_with: ["ui-brief", "ui-ux-pro-max", "frontend-design", "brainstorming"]` — ui-brief exists, frontend-design exists as a plugin skill in available-skills, ui-ux-pro-max exists as a plugin skill. `brainstorming` exists as superpowers:brainstorming plugin. All resolve. Composition logic explained in anti-patterns.md. |
| Completeness | 3 | All 8 reference files (5 .md + 3 direction-examples) exist and are linked. **However: line 120 references `SovereignSampson/CLAUDE-DESIGN-PROMPT.md` — a hardcoded path to a project that only exists on the author's machine.** The path is not relative to the skill repo. For any other user this is a dead pointer. |
| Anti-patterns | 3 | **Hardcoded project details** at SKILL.md:120 ("A real worked example lives at `SovereignSampson/CLAUDE-DESIGN-PROMPT.md`"). The direction-example references also lean heavily on "Sovereign Sampson Navy Field / Blackout Dossier / Bone & Olive" — useful as a worked example, but inside the skill body all three named directions hardcode one specific project. Mitigated by being explicit that they're samples, but still smells of one-project bias. Otherwise no excessive MUST/NEVER, no kitchen-sink. |

**Average:** 3.6

## Findings

### Critical (must fix to ship)
- **Description exceeds Anthropic's 1024-char hard ceiling (currently 1191 chars).** — SKILL.md:4-5 — proposed fix: trim by ~170 chars by deleting the "Distinguish from `ui-brief`" sentence (it's repeated in `references/usage-modes.md`) and shrinking the trigger-phrase list from 11 to 5–6 canonical examples. Keep action verb, core trigger phrases, and the "Works for any product type" coda.
- **Dead/hardcoded reference to `SovereignSampson/CLAUDE-DESIGN-PROMPT.md`** — SKILL.md:120 — this path only resolves on the author's machine. Proposed fix: either (a) inline a 10-line scrubbed sample directly in the body, (b) link to a GitHub permalink with the worked example, or (c) drop the line and rely on the `direction-examples/` reference files which already provide worked samples.

### Important (should fix)
- The three direction-examples files use "Sovereign Sampson" names ("Navy Field", "Blackout Dossier", "Bone & Olive") throughout. The worked sample is useful, but the prose embeds project-specific details (ACU sticky donate, "Substack readers", etc.) that read as project trivia rather than skill teaching. — references/direction-examples/safe.md:17-32, bold.md:17-32, experimental.md:17-32 — proposed fix: keep the concrete palette/typography specs but rename to generic placeholders or wrap with a disclaimer that this is one worked project example.
- `references/variation-and-risks.md:33` mentions "GOP staffers + Substack readers" as the audience-conflict example — politically scoped to one project. Generalize the example.
- Empty `owns` block on a non-agent workflow is unnecessary. — SKILL.md:9-12

### Nits (won't block ship)
- The "Announce at start" pattern (line 26) is unusual and could be normalized across skills or moved to a house-style doc.
- Final check in `prompt-template.md:155-170` repeats the verification checklist from SKILL.md:92-101 — minor duplication between body and reference.
- `references/canvas-constraints.md` has 7 numbered limits but no TOC; fine because it's only 17 lines.
- `composes_with` lists `brainstorming` (a plugin skill) without scoping — fine since the plugin is widely available.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Trim description from 1191 → ≤1024 chars (≤200 preferred)** — SKILL.md:4-5 — delete the entire "Distinguish from `ui-brief`" sentence (~280 chars), trim the trigger-phrase list from 11 examples to ~6. This is a HARD FAIL blocker per spec.
2. **Remove the `SovereignSampson/CLAUDE-DESIGN-PROMPT.md` reference** — SKILL.md:120 — either delete the line entirely (refs/direction-examples already provide samples) or replace with a generic statement that the skill includes 3 worked direction samples in `references/direction-examples/`.
3. **Generalize "Sovereign Sampson"-coded examples** — references/direction-examples/{safe,bold,experimental}.md:17-32 + references/variation-and-risks.md:33 — keep the concrete palette/typography values but introduce them as "Worked sample (anonymized from a real political advocacy site)" rather than naming the specific project; replace "GOP staffers + Substack readers" with a generic audience-pair.

## Dead links / broken references
- `SovereignSampson/CLAUDE-DESIGN-PROMPT.md` (SKILL.md:120) — does not resolve from the skill repo; resolves only against `/Users/johns/Repos/political-and-activism/ukraine-foreign-policy/SovereignSampson/` on the author's machine.
- All `composes_with` targets resolve (ui-brief in workflows/, ui-ux-pro-max and frontend-design as plugin skills, brainstorming as superpowers plugin).
- All 5 references/*.md files exist. All 3 direction-examples files exist.
