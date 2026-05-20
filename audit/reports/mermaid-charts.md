# Audit: mermaid-charts

**Path:** skills/workflows/mermaid-charts/SKILL.md
**Version:** 2.3.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields; semver 2.3.0; canonical hyphenated `allowed-tools`; no `<`/`>` in frontmatter (multiline block-scalar `>` is structural, not a value); all 9 `composes_with` targets resolve (`docs-agent`, `backend-agent`, `frontend-agent`, `skill-writer`, `project-profiler`, `orchestrator`, `infrastructure-agent`, `contract-author`, `observability-agent`). |
| Description quality | 4 | 954 chars — under 1024 ceiling but far above 200-char target. Strong trigger coverage with explicit catch-all ("Even if the user doesn't say 'mermaid' explicitly"). Action verb "Create". Could trim ~300 chars by deleting the redundant action verb list. |
| Progressive disclosure | 5 | Body 106 lines; eight reference files split by chart type plus styling/complexity/advanced. `advanced-patterns.md` is 355 lines and has a TOC (lines 5–13). Every reference is linked from the body with explicit purpose. |
| Instruction clarity | 5 | Strong imperative voice. "Core Principle: Diagrams Are Arguments" (line 41) frames decision-making; numbered 6-step workflow (lines 64–69); decision table by question (lines 51–58) makes chart-type selection deterministic. |
| Coordination | 5 | `owns.directories: []`, `owns.patterns: []`, `shared_read: ["*"]` — correct for a stateless workflow skill; 9 plausible `composes_with` collaborators all resolve. |
| Completeness | 5 | All 8 referenced files exist (chart-types/{flowchart, sequence, state, er, mindmap, other}.md + styling.md + complexity-and-output.md + advanced-patterns.md). Pre-delivery checklist (lines 87–94) is concrete and testable. |
| Anti-patterns | 5 | No emojis; no hardcoded paths; few MUSTs (only soft "should"); no duplicate content between body and references — body delegates to references rather than duplicating. |

**Average:** 4.86

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Description is 954 chars — close to the 1024 ceiling. Action-verb list overlap ("visualize, diagram, chart, map, or illustrate") could collapse to one phrase. — SKILL.md:4–15 — proposed fix: cut "Even if the user doesn't say 'mermaid' explicitly" paragraph and consolidate trigger verbs to a single shortlist; target ~400 chars.

### Nits (won't block ship)
- Line 22 declares `shared_read: ["*"]` which is unusual — most workflow skills omit `shared_read` entirely or scope it. The intent (read anything) is clear, but the wildcard might trip a strict ownership validator. Acceptable. — SKILL.md:22
- `references/chart-types/other.md` covers 7 diagram subtypes in 43 lines — likely terse. Not blocking; users who need depth can search.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Trim description from 954 → ~400 chars — SKILL.md:4–15 — collapse the action-verb enumeration ("visualize, diagram, chart, map, or illustrate") into one verb, drop the "Even if the user doesn't say 'mermaid' explicitly" line (already covered by the broader catch-all), keep the trigger-phrase list. Effort: small.
2. Consider replacing `shared_read: ["*"]` with empty array or removing the field entirely — SKILL.md:22 — wildcard is unusual; if intent is "stateless, read anything," the empty default communicates that more cleanly. Effort: small.
3. Add `compatibility:` field — SKILL.md:18 — skill mentions `mmdc` rendering (line 78 references complexity-and-output.md output formats); declaring "Works in any host; rendering to SVG/PNG requires mmdc" would help cross-platform parsers. Effort: small.

## Dead links / broken references
- None. All 8 reference files exist. All 9 `composes_with` targets resolve to real `SKILL.md` files.
