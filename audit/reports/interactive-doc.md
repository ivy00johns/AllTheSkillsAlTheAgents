# Audit: interactive-doc

**Path:** skills/workflows/interactive-doc/SKILL.md
**Version:** 1.0.0
**Category:** workflows
**Verdict:** NEEDS WORK

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 2 | **HARD FAIL: description is 1417 chars — exceeds the 1024 hard ceiling.** Only the three required fields are present (`name`, `version`, `description`); missing `allowed-tools`, `requires_claude_code`, `composes_with`. No `<`/`>`. Multiline `|` form correct. |
| Description quality | 4 | Action verb "Use this skill" (weak — should be the action itself); 10+ trigger phrases ("interactive doc", "wiki page", "Obsidian doc", "explainer", "render this research", "architecture diagram", etc.); explains two workflows (A render existing, B create both); audience-clear. Strong content but length violation. |
| Progressive disclosure | 3 | Body 186 lines / under 2000 words — at the upper edge of comfortable. Five reference files (1351 lines total) all linked at body line 178-186 with "when to read" guidance. Body has some duplication with house-style.md (the "House style essentials (always apply)" section at lines 150-161 partially overlaps `references/house-style.md`). house-style.md is 404 lines without a TOC — exceeds the 300-line threshold. |
| Instruction clarity | 5 | Imperative voice; clear Workflow A vs B distinction; explicit "cardinal rule" callout (line 41); numbered steps for each workflow; walk-throughs (lines 124-148); anti-patterns enumerated with explanations. An LLM following these steps would produce correct output. |
| Coordination | 2 | **No `composes_with` declared in frontmatter** despite body mentioning `conversation_search` and "thariq's site" (line 164). No `spawned_by`. No `owns`. Workflow skill, but the composition signal is missing — other skills can't discover this. |
| Completeness | 4 | All 5 reference files exist and are linked from body line 178-186. Evals file present at `evals/evals.json` with 4 worked prompts (excellent — most skills don't have evals). One minor issue: body line 164 references "thariq's site" as a canonical example without a URL or context — dead pointer for any reader who doesn't have that prior context. |
| Anti-patterns | 4 | One real anti-pattern: hardcoded "thariq's site" pointer (line 164) — assumes reader knows who thariq is. Hardcoded "Hive" examples throughout (architecture-map.md uses "Hive orchestrator" pervasively in worked samples) — these are useful as samples but are very specific to one project. Otherwise no excessive MUST/NEVER, well-documented anti-patterns. |

**Average:** 3.4

## Findings

### Critical (must fix to ship)
- **Description exceeds Anthropic's 1024-char hard ceiling (currently 1417 chars).** — SKILL.md:4-5 — proposed fix: trim by ~400 chars by removing the "Output is always a pair: a fully-substantive `.md`..." final-paragraph summary (already in body) and consolidating the trigger phrase list (drop a few redundant ones).

### Important (should fix)
- **Missing `composes_with`, `allowed-tools`, `requires_claude_code` in frontmatter** — SKILL.md:1-6 — body references `conversation_search`, mentions Mermaid rendering, references thariq's index pattern; should declare composition. Also: `allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep"]` minimum.
- **`references/house-style.md` is 404 lines with no TOC** — references/house-style.md — exceeds the 300-line "needs TOC" threshold per audit-checklist.md. Add an H2 TOC at the top.
- **"thariq's site" reference without context or URL** — SKILL.md:164 — generalize to "an index page pattern" or add the URL.
- **Hardcoded "Hive" worked examples throughout references** — references/architecture-map.md, references/concept-explainer.md, etc. — useful as samples but smells of one-project bias. Add a disclaimer or anonymize.

### Nits (won't block ship)
- "Especially trigger when..." sentence in description (~150 chars) repeats triggers from earlier in the description — drop. — SKILL.md:4-5
- "House style essentials (always apply)" section (SKILL.md:150-161) duplicates content from `references/house-style.md`. Minor duplication.
- Empty `owns` block could be intentionally omitted (it's already absent — well done) for non-agent workflow.
- `evals/evals.json` is great but is the only skill in this batch with one — consider promoting this pattern to a house-style convention.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Trim description from 1417 → ≤1024 chars (≤200 preferred)** — SKILL.md:4-5 — delete the final "Output is always a pair: a fully-substantive `.md`..." sentence (~280 chars; the body fully explains this), drop the "Especially trigger when..." redundant trigger restatement (~150 chars). This is a HARD FAIL blocker per spec.
2. **Add missing standard frontmatter fields** — SKILL.md:1-6 — add `allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep"]`, `requires_claude_code: true`, `composes_with: ["mermaid-charts", "wiki-research"]` (if relevant), `metadata.category: workflows`.
3. **Add a TOC to `references/house-style.md`** — references/house-style.md:1 — file is 404 lines; H2 TOC at the top with links to anchors (CSS variables, Typography, Standard components, etc.).

## Dead links / broken references
- "thariq's site" reference at SKILL.md:164 has no URL — opaque to anyone without prior context.
- All 5 references/*.md files exist and are linked from SKILL.md:178-186.
- No `composes_with` declared so nothing to verify there; body mentions `conversation_search` (a built-in tool) and other skills only obliquely.
