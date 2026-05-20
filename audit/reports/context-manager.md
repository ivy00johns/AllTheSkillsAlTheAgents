# Audit: context-manager

**Path:** skills/workflows/context-manager/SKILL.md
**Version:** 1.1.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields valid; description 481 chars (under 1024 ceiling, over 200 target); `allowed-tools` hyphenated; no `<`/`>`; field order correct; `owns.directories: [".claude/handoffs/"]` properly declared per the v1.1 resolved conflict (matches spec ownership table). Composes_with and spawned_by both list `orchestrator` (reciprocal). |
| Description quality | 4 | Action verb "Manage"; 8 explicit trigger phrases; clear use cases. Could be tighter (≤200 target) but well within ceiling. |
| Progressive disclosure | 5 | Body 106 lines / under 2000 words; one reference file (compaction-guide.md, 98 lines) linked at lines 48 and 98 with explicit "when to read" guidance; no duplicate content (body covers schema + protocol; reference covers strategies + good/bad examples). |
| Instruction clarity | 5 | Imperative voice; clear Inputs / When to Act / Protocol / Coordination sections; YAML schema specified inline; orchestrator-handoff steps numbered; explicit quality gate (line 105) for rejecting vague handoffs. |
| Coordination | 5 | `owns.directories: [".claude/handoffs/"]` matches the v1.1 resolved-conflict table in frontmatter-spec.md exactly. Off-limits section explicit ("src/, implementation code"). Boundary with orchestrator made explicit at line 106. `composes_with: ["orchestrator"]` reciprocal with `spawned_by: ["orchestrator"]`. |
| Completeness | 5 | One reference file exists and is linked. Handoff schema specified with full YAML structure. Good/bad continuation_context examples given in reference. Recovery procedure documented. |
| Anti-patterns | 5 | No hardcoded paths; MUST/NEVER rules have explicit rationale ("Handoff files are append-only — never modify a previous handoff"); no body/ref duplication; no kitchen sink. |

**Average:** 4.9

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Description 481 chars vs 200-char house-style target — could trim by dropping the "managing context limits, performing session handoffs, compacting conversation history" repetition (already covered by the trigger list). — SKILL.md:4-5

### Nits (won't block ship)
- The handoff YAML schema is inline in SKILL.md (lines 52-81); could move to `references/handoff-schema.yaml` so the body shrinks and the schema is machine-validatable. Not a blocker.
- `shared_read: ["*"]` is broad — could be tightened to specific roots that handoffs actually need to inspect. Minor.
- "Context Efficiency Tips" section (lines 91-98) is short and could be merged into the compaction-guide reference. Minor.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Trim description to ≤200 chars — SKILL.md:4-5 — remove the "managing context limits, performing session handoffs, compacting conversation history" middle clause (it's already covered by the trigger list that follows).
2. Move the inline handoff YAML schema (lines 52-81) into a referenced file like `references/handoff-schema.yaml` — SKILL.md:50-81 — makes the schema machine-validatable and trims SKILL.md body.
3. Consolidate "Context Efficiency Tips" (SKILL.md:91-98) into compaction-guide.md — SKILL.md:91-98 — minor duplication risk; reference is the natural home for tips.

## Dead links / broken references
- None. `references/compaction-guide.md` exists and is referenced at SKILL.md:48 and SKILL.md:98. `composes_with: ["orchestrator"]` resolves. `spawned_by: ["orchestrator"]` resolves.
