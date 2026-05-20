# Audit: architecture-rescue

**Path:** skills/workflows/architecture-rescue/SKILL.md
**Version:** 1.0.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields present and valid; description uses double-quoted scalar (~747 chars, under 1024 ceiling but well over 200-char target); `owns` block with empty arrays + `shared_read: ["*"]` is unusual for a non-agent workflow but harmless; no `<`/`>` in frontmatter; field order follows house style. |
| Description quality | 4 | Starts with action verb "Find"; enumerates 8+ trigger phrases ('improve architecture', 'ball of mud', 'shallow modules' etc.); contains domain vocabulary (deletion test, two-adapter rule). Pushy and load-bearing. Could be tightened — currently spends ~300 chars on methodology before triggers. |
| Progressive disclosure | 5 | Body is 66 lines / well under 2000 words; two well-organized references (architecture-language.md, interface-design.md) linked from body with explicit "when to read" guidance (line 31, 52); no duplicate content. Exemplary. |
| Instruction clarity | 5 | Six numbered process steps, imperative voice ("Survey the tree", "Apply the tests", "Hand off"), each step explains the WHY; clear output format template (lines 56-64); explicit "do not skip to interface design" guardrail. |
| Coordination | 4 | `composes_with: ["grill-me", "maintain-context", "diagnose-loop"]` — all three exist. Process step 4 explicitly hands off to grill-me; step 5 to maintain-context. `spawned_by: []` reasonable. Empty `owns.directories` and `owns.patterns` plus `shared_read: ["*"]` is fine for a read-only workflow but could be omitted entirely since it's not an agent role. |
| Completeness | 5 | Both referenced files exist; both are linked from body with context; reference content matches what body promises (canonical vocabulary in architecture-language.md, Design-It-Twice in interface-design.md); examples thorough (UserService/BillingService example, S3Storage/LocalDiskStorage example). |
| Anti-patterns | 5 | No hardcoded project details; MUST/NEVER avoided; no duplicate body/refs; no kitchen-sink scope creep; tools declared (`Read`, `Grep`, `Glob`, `Write`) match what the process actually needs. |

**Average:** 4.6

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Description is 747 chars — well over the 200-char house-style target. Could trim methodology preamble ("Apply the deletion test...two-adapter rule...numbered candidates with locality/leverage benefits.") and keep the trigger keywords. — SKILL.md:4

### Nits (won't block ship)
- `owns:` block declared with empty `directories`/`patterns` and `shared_read: ["*"]` for a non-agent workflow is unnecessary — agent-role coordination fields could be omitted. — SKILL.md:8-11
- Reference architecture-language.md mentions "mattpocock's LANGUAGE.md" without a link; harmless attribution but a URL would help future readers. — references/architecture-language.md:5
- The output format code block (lines 56-64) uses ` ```text ` which is fine, but the inner `### N. <short name>` header could conflict if grilling output is concatenated into a doc whose H3s start elsewhere; nit only.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Trim description to ≤200 chars by removing methodology preamble — SKILL.md:4 — keep the trigger phrases ('ball of mud', 'shallow modules', 'deepen modules', etc.) and the action verb, drop the deletion-test/two-adapter-rule explanation since it's already in the body.
2. Remove the agent-role `owns` block entirely (this isn't an agent role) — SKILL.md:8-11 — workflows skills should omit `owns`/`shared_read` rather than declare empty arrays; cleaner frontmatter.
3. Add an attribution URL for Ousterhout's *A Philosophy of Software Design* and mattpocock's LANGUAGE.md — references/architecture-language.md:5, :45 — small, but standard for an OSS skill.

## Dead links / broken references
- None. Both referenced files exist. All three `composes_with` targets (grill-me, maintain-context, diagnose-loop) resolve to real skills.
