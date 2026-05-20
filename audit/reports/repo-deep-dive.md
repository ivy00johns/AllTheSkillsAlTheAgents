# Audit: repo-deep-dive

**Path:** skills/workflows/repo-deep-dive/SKILL.md
**Version:** 1.2.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields present; semver 1.2.0; no `<`/`>` in field values (the `>-` is a YAML block scalar marker, not a value). `allowed-tools` is hyphenated canonical form. `composes_with` lists five real skills (all exist in repo). `owns` block correctly empty for non-agent skill (`shared_read: ["*"]` is reasonable for a read-only analyzer). |
| Description quality | 5 | 891 chars — well under 1024 ceiling but well above the 200 "tight scannable" target. Starts with action verb ("Perform"). 8+ trigger contexts/keyword variants ("deep dive", "deep research", "analyze this repo", "break down this codebase", "technical reference", "how does this project work"). Pushy without overshooting. |
| Progressive disclosure | 5 | Body is 96 lines / ~700 words — excellent. Three reference files (document-template 194 lines, phases 74 lines, parallelization 48 lines), all linked from body with explicit "when to read" guidance ("Read `references/phases.md` for the detailed instructions..."). No reference >300 lines so no TOC required. |
| Instruction clarity | 5 | Imperative voice throughout ("Turn a Claude Deep Research document...", "Read the deep-research doc"). Four phases clearly numbered with one-line summaries in body, full detail in `references/phases.md`. Explains WHY (e.g., grounds analysis in why project exists). |
| Coordination | 5 | `composes_with: ["project-profiler", "plan-builder", "mermaid-charts", "wiki-research", "llm-wiki"]` — all 5 exist. Non-agent skill so no ownership conflicts. Mentions mermaid-charts skill in body (line 80) consistent with `composes_with`. |
| Completeness | 5 | All three reference files exist, all linked from body. Document template covers all 12-14 doc types. Anti-pattern section names the silent-output-directory mistake. Phase 4 in `phases.md` references `mermaid-charts` skill which exists. |
| Anti-patterns | 5 | None detected. No hardcoded project names (uses `{project}` placeholders). MUST/NEVER usage is rare and justified ("Forbidden:" anti-pattern is explained with rationale). No duplicate content between body and references — body summarizes, references detail. Self-aware tradeoff disclosure at line 28. |

**Average:** 5.0

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- None.

### Nits (won't block ship)
- `references/document-template.md` line 91-98 prescribes ASCII box-drawing art for architecture diagrams, but the SKILL.md body line 80 says "use the `mermaid-charts` skill... instead of ASCII art." Inconsistent guidance — the template should be updated to show mermaid as the preferred form, with ASCII as a fallback. (Inconsistency, not a defect.)
- `references/document-template.md` line 167-170 uses "AllTheSkills" — old project name (project was renamed to Skill Madness per MEMORY.md). Should be `{reference-project}` or "Skill Madness". Minor staleness.
- Description is 891 chars — within ceiling but well above the 200-char target. Could be tightened but the trigger coverage is strong, so leaving it is defensible for a "pushy" trigger surface.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Replace ASCII architecture diagram example in `references/document-template.md:90-98` with a mermaid `flowchart TB` example to match the SKILL.md body's mermaid-first guidance. — `skills/workflows/repo-deep-dive/references/document-template.md:90-98` — swap the ASCII block for a mermaid fence with two subgraphs. effort: small.
2. Replace hardcoded "AllTheSkills" reference name with `{reference-project}` placeholder. — `skills/workflows/repo-deep-dive/references/document-template.md:167,170` — find/replace `AllTheSkills` → `{reference-project}`. effort: small.
3. Optional polish: tighten description to ≤500 chars by collapsing the duplicate keyword cluster ("deep dive", "deep research" appear once in the "Use this skill" sentence and again in the "Also trigger" sentence). — `skills/workflows/repo-deep-dive/SKILL.md:4-13` — merge the two trigger sentences. effort: small.

## Dead links / broken references
- None. All three references (`phases.md`, `document-template.md`, `parallelization.md`) exist and are linked. All 5 `composes_with` targets (project-profiler, plan-builder, mermaid-charts, wiki-research, llm-wiki) exist in the repo.
