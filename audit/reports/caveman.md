# Audit: caveman

**Path:** skills/workflows/caveman/SKILL.md
**Version:** 1.0.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields valid; description multiline (`|`) ~620 chars (under 1024 ceiling, over 200-char target); no `<`/`>`; field order correct. `allowed-tools: []` is honest — caveman is a behavior mode, not a tool-invoking skill. Empty `owns` block redundant for non-agent workflow but harmless. |
| Description quality | 5 | Action verb "Cuts"; explicit trigger keywords (8+ variants including '/caveman'); explicitly states exit phrases ("stop caveman", "normal mode"); states auto-deactivation contexts (security warnings, irreversible actions, multi-step). Pushy and exemplary for a mode-flip skill. |
| Progressive disclosure | 5 | 59 lines total; no references needed — entire skill content is the behavior rules, examples included inline. Right size for the job. |
| Instruction clarity | 5 | Clear sections (Persistence, Drop, Keep, Pattern, Auto-clarity exception, Examples); imperative; concrete before/after examples; explicit list of what to drop and what to keep. An LLM following this would produce correct output. |
| Coordination | 4 | `composes_with: []` and `spawned_by: []` accurate — caveman is a standalone presentation-layer mode; no orchestration handoffs needed. Could mention "off during multi-step sequences" handoff back to normal mode but that's already covered. |
| Completeness | 5 | No external refs to validate; 3 before/after examples cover the common compression patterns; attribution to source (mattpocock/skills, MIT) present on line 20. |
| Anti-patterns | 5 | No hardcoded paths; the MUST/NEVER-style rule ("never compress inside fences") has clear rationale (technical accuracy first); no duplication; not a kitchen-sink; correctly declares `allowed-tools: []`. |

**Average:** 4.7

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Description is 620 chars vs the 200-char house-style target. The exit-phrase and auto-deactivation context could move to the body since both are restated there already. — SKILL.md:4-5

### Nits (won't block ship)
- Empty agent-role fields (`owns.directories: []`, `owns.patterns: []`, `owns.shared_read: []`) are noise on a workflow skill — drop them. — SKILL.md:9-12
- Section header "Drop" / "Keep" / "Pattern" works but a single H2 like "Compression rules" with subheads would scan better. Stylistic only.
- Attribution line uses a `>` blockquote and mentions "Adapted from mattpocock/skills `caveman` (MIT)" — would benefit from a URL for provenance. — SKILL.md:20

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Trim description to ≤200 chars — SKILL.md:4-5 — keep action verb + core trigger phrases ('caveman mode', 'be terse', 'compress', '/caveman', 'stop being verbose'); move the auto-deactivation enumeration into the body (it's already in the body anyway).
2. Remove empty `owns` block and the agent-role fields — SKILL.md:9-12 — caveman is a workflow skill; these fields apply only to agent roles.
3. Add a URL to the mattpocock attribution — SKILL.md:20 — change "Adapted from mattpocock/skills `caveman` (MIT)" to include the upstream repo URL for provenance.

## Dead links / broken references
- None. No reference files referenced; no `composes_with` or `spawned_by` to verify.
