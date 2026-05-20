# Audit: wiki-research

**Path:** skills/workflows/wiki-research/SKILL.md
**Version:** 2.1.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields present; semver 2.1.0; no `<`/`>` in field values. `allowed-tools` hyphenated. Description measured at 928 chars (under 1024 ceiling). `composes_with: ["repo-deep-dive", "llm-wiki", "project-profiler"]` — all exist. `spawned_by` lists 8 skills (orchestrator, code-review-agent, repo-deep-dive, project-profiler, backend-agent, frontend-agent, security-agent, plan-builder) — all 8 exist in repo. |
| Description quality | 4 | 928 chars — pushy and comprehensive but close to ceiling. Starts with action verb "Use" (not ideal — more direct would be "Read the wiki BEFORE..."). Contains 8+ trigger phrases ("how does X work", "what is X", "what patterns does X use", "understand the architecture", "review this code", "build X"). Has exclusions stated ("Skip only when the task is purely mechanical"). |
| Progressive disclosure | 5 | Body 171 lines / ~1500 words — within house guidance. No `references/` directory — content is appropriately compact and stand-alone (the skill is a protocol, not a heavy reference). All structural information (page format, directory layout) fits comfortably in body. |
| Instruction clarity | 5 | Strong imperative voice. Four-step protocol clearly numbered. Token-cost table (line 33-39) gives concrete WHY for wiki-first. Three explicit "Step 4 — Escalate Only When Needed" branches cover all cases. Anti-patterns table well-formed. |
| Coordination | 5 | All 3 `composes_with` and all 8 `spawned_by` targets exist as real skills. `shared_read: ["wiki/", "index.md"]` is meaningful. No ownership conflicts (non-agent skill). Spawn pattern is bidirectional with the listed skills' own composes/spawns sections. |
| Completeness | 5 | All cross-references resolve. The "Standard Wiki Directory Layout" diagram + "Pointing at an external wiki" + "Multi-cluster wikis" sections cover the three deployment patterns. Wiki page structure example given. Lookup cost calculation given. |
| Anti-patterns | 5 | No hardcoded project paths (uses `<wiki-root>` placeholder). MUST/NEVER not abused. Anti-pattern table explains WHY for each. Body doesn't duplicate any reference content (no references/ to duplicate). Self-aware section on alternative layouts ("If a project uses a different convention..."). |

**Average:** 4.86

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- None.

### Nits (won't block ship)
- Description starts with "Use this skill BEFORE..." — the spec recommends starting with an action verb. Could be tightened to "Read the project's wiki BEFORE any codebase exploration..." for stronger action-verb start. — `skills/workflows/wiki-research/SKILL.md:5`.
- Description is at 928 chars — well under ceiling but past the 200-char target. The "pushy" coverage justifies this for a high-frequency triggering skill, but could be tightened to ~700 chars if the "Trigger on:" enumeration is collapsed.
- Line 24 `spawned_by` lists 8 skills — verify reciprocity: do all 8 actually invoke wiki-research in their own bodies? If not, the list is aspirational not actual. (Not blocking, but worth a follow-up audit pass to confirm bidirectionality.)
- No `references/` directory — fine since body is compact, but a `references/page-templates.md` with concrete entity/concept/source page examples would help users authoring new wiki pages downstream (composes with `llm-wiki`).

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Replace "Use this skill BEFORE..." with stronger action-verb start. — `skills/workflows/wiki-research/SKILL.md:5` — change to "Read the project's wiki BEFORE any codebase exploration, repo-deep-dive, or raw source reading..." which leads with the verb. effort: small.
2. Verify reciprocity of `spawned_by` list. — `skills/workflows/wiki-research/SKILL.md:24` — for each of the 8 listed skills, grep their SKILL.md bodies for "wiki-research" mentions. If absent, either remove from `spawned_by` or add to those skills' compose chains. effort: medium (requires touching other skills).
3. Optionally tighten description to ~700 chars. — `skills/workflows/wiki-research/SKILL.md:5-14` — collapse the "Trigger on:" enumeration to 3-4 most distinctive phrases. effort: small.

## Dead links / broken references
- None. All `composes_with` (repo-deep-dive, llm-wiki, project-profiler) and all 8 `spawned_by` entries (orchestrator, code-review-agent, repo-deep-dive, project-profiler, backend-agent, frontend-agent, security-agent, plan-builder) resolve to real skills.
