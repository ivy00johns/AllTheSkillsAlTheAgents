# Audit: docs-agent

**Path:** skills/roles/docs-agent/SKILL.md
**Version:** 1.1.0
**Category:** roles
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields. Semver valid. owns block has `docs/` directory + narrowed patterns (`README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`) per spec resolved-conflicts table (v1.1 narrowing of `*.md`). shared_read is `*`. No compatibility/metadata. |
| Description quality | 3 | 198 chars under 200 target. Action verb "Generates". Lists capabilities (project docs, API docs, READMEs, changelogs). Intentionally narrow as spawned-only. |
| Progressive disclosure | 5 | Body 115 lines. references/doc-templates.md 140 lines with templates for README + API endpoints. Body links references at lines 57 and 104. |
| Instruction clarity | 4 | Imperative voice. Numbered steps 1–4. Process steps are concise lists of what to include. Step 0 (Read Contracts) is NOT explicit — step 1 jumps directly to README. Inputs section mentions contracts but no dedicated "Read contracts first" step. |
| Coordination | 5 | Owns matches orchestrator/file-ownership.md (docs/, narrowed README/CHANGELOG/CONTRIBUTING). Off-limits explicit at line 51. `composes_with` lists 5 collaborators including mermaid-charts and contract-author. Coordination rules with backend/frontend/infrastructure (lines 98–100). |
| Completeness | 5 | doc-templates.md exists with README + API endpoint templates + quality checklist. Validation checklist inline at lines 108–112. Phase 14 hook explicit. |
| Anti-patterns | 5 | Clean. No hardcoded paths in body. Templates use bracketed placeholders. No emojis. |

**Average:** 4.4

## Findings

### Critical (must fix to ship)

None.

### Important (should fix)

- Missing "Step 0: Read Contracts" — SKILL.md:55 — Process starts at step 1 (README.md). Add `### 0. Read Contracts and Source` step matching the pattern of other role agents.
- Missing `compatibility` string — SKILL.md frontmatter — add `compatibility: "Claude Code"`.
- Self-referential pipeline blockquote — SKILL.md:20 — "Reports to `qe-agent` via `qa-report.json`" template-bleed.

### Nits (won't block ship)

- No `metadata` block.
- doc-templates.md uses project-specific endpoints `/sessions` (lines 54–56). Replace with generic placeholders like `/<resource>` for consistency.
- Validation: "Run `references/doc-templates.md` checklist before reporting done" (line 104) followed by inline checklist (108–112) — slightly redundant; either point at the doc-templates checklist or use inline.
- "Right-sizing" not explicit — body doesn't say "skip CHANGELOG for prototypes".

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Add Step 0: Read Contracts and Source — SKILL.md:53 — insert before step 1 to match all other role agents' Step 0 pattern. Effort: small.
2. Fix self-referential pipeline blockquote — SKILL.md:20 — reword to "Documentation feeds into `qe-agent`'s `completeness` score". Effort: small.
3. Replace project-specific endpoints in doc-templates.md — references/doc-templates.md:50, 54–56 — use `/<resource>` placeholders. Effort: small.

## Dead links / broken references

None. `references/doc-templates.md` exists. All `composes_with` targets exist as directories (mermaid-charts under skills/workflows/).
