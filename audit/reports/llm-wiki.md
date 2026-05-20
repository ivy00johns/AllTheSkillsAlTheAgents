# Audit: llm-wiki

**Path:** skills/workflows/llm-wiki/SKILL.md
**Version:** 1.1.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields valid; description 846 chars (under 1024 ceiling, over 200 target); `allowed-tools` hyphenated; no `<`/`>`; field order correct. `composes_with: ["wiki-research", "repo-deep-dive", "project-profiler", "mermaid-charts"]` — all four exist. **One concern:** `owns.patterns: ["index.md", "log.md", "overview.md"]` is broad — these are common filenames; could conflict with `docs-agent` which owns README/CHANGELOG/CONTRIBUTING patterns. Probably OK because llm-wiki operates inside a wiki root, not project root, but the pattern declaration is ambiguous about scope. |
| Description quality | 5 | Action verb "Bootstrap and maintain"; 11+ trigger phrases including in-vault triggers ("add this article to the wiki", "what does the wiki say about X"); explicit exclusion ("This is distinct from RAG"). Pushy and contextually aware (covers both setup and in-wiki operations). |
| Progressive disclosure | 5 | Body 202 lines / under 2000 words — exactly at the 200-line soft threshold but justified by Setup + Ingest + Query + Lint mode coverage in one place. Two reference files linked from body (lines 143, 161, 174, 201-202) with explicit "when to read" guidance. Some inline expansion of operations (Setup steps 1-5 are inline; Ingest/Query/Lint are summarized with references). |
| Instruction clarity | 5 | Imperative voice; Entry Detection table (lines 39-46) routes to the correct mode; "Announce at start" pattern (line 33); numbered steps; concrete templates (index.md, log.md). The "Working Style" principles at line 187 explain the WHY. |
| Coordination | 4 | All 4 `composes_with` targets exist (wiki-research, repo-deep-dive, project-profiler, mermaid-charts). `spawned_by: []` reasonable for user-invoked. `owns.directories: []` empty but `owns.patterns` declared (unusual combination); patterns are scoped to wiki/* in usage but the YAML doesn't say that explicitly. |
| Completeness | 5 | Both reference files exist and are linked (3x for operations.md, once for wiki-schema-template.md). Schema template uses `{{PLACEHOLDER}}` form so it's machine-friendly. Operations.md is exhaustive (253 lines) covering Ingest/Query/Lint with citations and good practices. |
| Anti-patterns | 5 | No hardcoded paths (uses `<wiki-root>/` as a variable); MUST rules have rationale ("Never modify files in `raw/` — they are the immutable source of truth"); cross-references between modes; `qmd` suggestion at line 197 is optional and contextual. |

**Average:** 4.7

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- **`owns.patterns: ["index.md", "log.md", "overview.md"]` is unscoped** — SKILL.md:20 — these are common filenames that conflict with other projects' top-level files. Either tighten to `wiki/index.md`, `wiki/log.md`, `wiki/overview.md` (path-scoped), or document that these patterns apply only within wikis the skill owns.
- Description 846 chars vs 200-char target — could trim "Bootstrap and maintain LLM-powered personal knowledge bases (wikis) for any project or domain" preamble redundancy (the trigger list says the same). — SKILL.md:4-14
- `wiki/operations.md` doesn't have a TOC even though it's 253 lines (under 300 threshold but at the upper edge of comfortable scrolling). Headers are clear so navigation works.

### Nits (won't block ship)
- "Announce at start" pattern (line 33) is unusual; same as claude-design-brief — could normalize across skills.
- `qmd` recommendation at line 197 / operations.md:250 — useful but a third-party tool (github.com/tobi/qmd) with no version pin; could rot.
- `shared_read: ["raw/", "wiki/"]` is good but slightly redundant with owns.patterns; if owns.directories were `["wiki/"]` instead, this would compose better.
- The CLAUDE.md schema file in a wiki conflicts with the project-profiler-owned CLAUDE.md at project root (per v1.1 ownership table). Both can coexist (different paths) but a note would help.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Tighten `owns.patterns` to path-scoped form** — SKILL.md:20 — change `["index.md", "log.md", "overview.md"]` to `["wiki/index.md", "wiki/log.md", "wiki/overview.md"]` or move to `owns.directories: ["wiki/"]` with no patterns; current form is dangerously broad if read literally.
2. **Trim description to ≤200 chars** — SKILL.md:4-14 — preserve action verb, top 5 trigger phrases, and the "distinct from RAG" exclusion; drop the redundant in-wiki trigger restatement.
3. **Add a TOC to operations.md** — references/operations.md:1 — file is 253 lines covering 3 distinct workflows (Ingest, Query, Lint); a top-of-file ToC linking to each H2 would speed navigation.

## Dead links / broken references
- None. All 4 `composes_with` targets (wiki-research, repo-deep-dive, project-profiler, mermaid-charts) exist. Both reference files exist and are linked from SKILL.md.
