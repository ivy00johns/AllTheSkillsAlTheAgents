# Audit: contract-author

**Path:** skills/contracts/contract-author/SKILL.md
**Version:** 1.3.0
**Category:** contracts
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields present and correct: name (kebab-case), version (1.3.0 valid semver), description (983 chars — under 1024 ceiling but well over 200 char target), no angle brackets, allowed-tools hyphenated, owns block complete with directories/patterns/shared_read, composes_with + spawned_by both populated and accurate. Minor: shared_read is `["*"]` which is a wildcard — works but somewhat loose. |
| Description quality | 4 | Strong action verb ("Generate"), clear when-to-use ("before any implementation begins in multi-agent builds"), 5+ keyword variants ("write the API contract", "define the shared types", "spec out the endpoints", "create the OpenAPI", "author the contract"), tells what's bundled (6 templates). 983 chars overshoots the 200-char target by ~5x but stays under the 1024 hard ceiling. Could be ~30% shorter without losing trigger coverage. |
| Progressive disclosure | 5 | Body 235 lines / ~1680 words — well within the 5000-word / 500-line guideline. 6 templates live in references/ and are explicitly linked from the body with "when to read" context (TS → typescript-template.ts, Python → pydantic-template.py, etc.). No reference >300 lines. No duplicate content between body and refs. |
| Instruction clarity | 5 | Numbered Process steps 0a through 9 with imperative voice ("Read project config", "Extract entities", "Author API contract"). Each step explains WHY (e.g., "specification problems cause ~42% of multi-agent failures", "prevents missing entities that only become apparent during implementation"). The 0a/0b decimal split is unusual but readable. Quality Checklist at step 9 gives an actionable handoff bar. |
| Coordination | 5 | Owns `contracts/` and `schemas/` directories which aligns with the v1.1 resolved-conflicts table (contracts/ resolved to contract-author). owns.patterns = openapi.yaml/asyncapi.yaml. No overlap with other agents. composes_with lists real local skills (backend-agent, frontend-agent, contract-auditor, qe-agent). spawned_by ["orchestrator"] is accurate. |
| Completeness | 5 | All 6 referenced template files exist: openapi-template.yaml (251 lines), data-layer-template.yaml (150), pydantic-template.py (142), asyncapi-template.yaml (110), typescript-template.ts (98), json-schema-template.json (87). Output section enumerates exact deliverable paths. Per-stack right-sizing guidance keeps templates from being applied dogmatically. |
| Anti-patterns | 5 | Explicit "Anti-Pattern" callout against speculative contract authoring. Right-Sizing section actively guards against over-engineering ("personal habit tracker with SQLite doesn't need JWT auth"). No hardcoded project specifics. MUSTs are bounded ("Required sections (non-negotiable)") with rationale. |

**Average:** 4.71

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- Description is 983 chars — within Anthropic's 1024 hard ceiling but ~5x the 200-char house target. SKILL.md:5 — proposed fix: trim the "Use this skill when..." sentence by removing the redundant "Bundles 6 templates: OpenAPI, AsyncAPI, Pydantic, TypeScript, JSON Schema, and a data-layer YAML — pick the one matching the project's stack." (move to body, where it already exists in slightly different form). That alone drops ~150 chars and brings the description closer to a tight trigger paragraph.

### Nits (won't block ship)
- `owns.shared_read: ["*"]` — wildcard works but is unusual. SKILL.md:12 — consider listing the directories the skill actually reads (`["plans/", "docs/", "src/"]`) so future ownership audits can spot conflicts.
- Step numbering uses "0a / 0b / 1 / 2 ..." instead of a cleaner "1. Read project config / 2. Extract entities / 3. Start with shared types / ...". SKILL.md:46-66 — renumber 0a → 1 and shift, so "Quality Checklist" becomes step 10 instead of 9.
- Field ownership table at L143-149 is rendered as a fenced code block but isn't tagged as a language — consider tagging as `markdown` or moving to actual table syntax for better rendering.
- Frontmatter has `requires_claude_code: true` even though the skill's `allowed-tools` are all generic (Read, Write, Edit, Glob, Grep). SKILL.md:7 — strictly true since it's invoked from orchestrator and writes to a workspace, but worth verifying the skill genuinely needs CLI-only features.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Trim description by ~150 chars** — SKILL.md:5 — remove the trailing "Bundles 6 templates..." sentence (already covered in body's Process section). Brings the description from 983 → ~830 chars, closer to the 200-char target. Effort: small.
2. **Replace `owns.shared_read: ["*"]` with explicit directory list** — SKILL.md:12 — change to `["plans/", "docs/", "src/", "tests/"]` (or the project's actual source dirs). Effort: small.
3. **Renumber Process steps to remove 0a/0b** — SKILL.md:46-181 — promote 0a → 1, 0b → 2, and shift the rest down by 2. Quality Checklist becomes step 10. Effort: small (find-and-replace).

## Dead links / broken references
- None. All 6 referenced template files exist under `references/`. Cross-skill `composes_with` entries (backend-agent, frontend-agent, contract-auditor, qe-agent) all exist under `skills/roles/` and `skills/contracts/`. spawned_by ["orchestrator"] resolves.
