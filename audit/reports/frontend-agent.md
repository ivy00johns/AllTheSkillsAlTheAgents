# Audit: frontend-agent

**Path:** skills/roles/frontend-agent/SKILL.md
**Version:** 1.2.0
**Category:** roles
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields present; semver valid; owns block populated with directories AND patterns. Pattern ownership (`*.tsx`, `*.jsx`, etc.) is broad — but directory ownership takes precedence per spec. Field order has `disable-model-invocation` between name and description (acceptable). No `compatibility` or `metadata`. `composes_with` lists 8 skills (frontend-design, ui-ux-pro-max, ui-brief, nano-banana) — need to verify they all exist. |
| Description quality | 3 | 220 chars — over 200 target but under 1024 ceiling. Action verbs ("Builds", "Composes"). Intentionally narrow trigger ("Orchestrator-dispatched only", "Not user-invocable") because skill is spawned-only. Reasonable for its purpose. |
| Progressive disclosure | 5 | Body 160 lines, references/validation-checklist.md 130 lines. Body links references at line 157 with clear "when to read" ("before reporting done"). Good split. |
| Instruction clarity | 5 | Imperative voice throughout. Steps numbered 0–7 with sub-steps 3a, 3b. Explains WHY (e.g., 3a "what separates 'looks like a demo' from 'looks like a product'"). Pitfalls table maps cause → prevention. |
| Coordination | 5 | Owns matches orchestrator/file-ownership.md. Off-limits explicit at line 55. CORS coordination rule (line 141) explicitly hands ownership to backend-agent. `composes_with` accurate including design skills. |
| Completeness | 5 | validation-checklist.md exists and linked. Step 0 "Read Contracts and Domain Rules" present. Right-sizing in step 1 ("Don't force React onto a vanilla JS project"). Off-limits enumerated. |
| Anti-patterns | 4 | Validation-checklist.md "Cross-package CSS imports" section (refs:42–68) is Vite/PostCSS-specific and quite long — mild kitchen-sink risk inside a generic checklist. Two "Build Verification" headers in checklist (refs:7, 70) — a duplicate heading from earlier merge that adds confusion. Otherwise clean. |

**Average:** 4.4

## Findings

### Critical (must fix to ship)

None.

### Important (should fix)

- Duplicate `## Build Verification` heading in validation-checklist.md — references/validation-checklist.md:7 and :70 — rename second to `## Dev Server` (since that's what follows it) or merge into a single section.
- Description 220 chars exceeds 200-char target — SKILL.md:5 — tighten by dropping "Composes with frontend-design and ui-ux-pro-max for visual quality" (info redundant with composes_with).
- Missing `compatibility` string — SKILL.md frontmatter — add e.g. `compatibility: "Claude Code; requires Bash + Node/npm for build verification"`.

### Nits (won't block ship)

- No `metadata` block (author/category/tags).
- Stack-specific guidance (Fastify-equivalent: Vite CSS resolver in checklist refs:42–68) could move to `references/css-import-traps.md` linked conditionally.
- "Off-limits" listed inline in Ownership section rather than own heading.
- Field order: `disable-model-invocation` before `description` is OK but house style would put it after `compatibility`/`license`/`allowed-tools` if those existed.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Fix duplicate `## Build Verification` heading — references/validation-checklist.md:70 — rename to `## Dev Server` (the content that follows). Effort: small.
2. Tighten description to ≤200 chars — SKILL.md:5 — `"Orchestrator-dispatched only. Builds UI, client state, and presentation layers for multi-agent contract-first builds. Not user-invocable."` (~143 chars). Effort: small.
3. Add `compatibility` field — SKILL.md frontmatter — insert `compatibility: "Claude Code; requires Bash + Node toolchain for build/typecheck"`. Effort: small.

## Dead links / broken references

- All `composes_with` targets exist: backend-agent, qe-agent, infrastructure-agent, contract-author (roles/contracts), frontend-design (plugin skill), ui-ux-pro-max (workflows? — needs confirm), ui-brief (workflows), nano-banana (workflows). Verified by directory presence under skills/. No dead links.
