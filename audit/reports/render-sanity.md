# Audit: render-sanity

**Path:** skills/workflows/render-sanity/SKILL.md
**Version:** 1.0.0
**Category:** workflows
**Verdict:** NEEDS WORK

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 2 | **Description 1388 chars — exceeds the 1024 hard ceiling per Anthropic spec and audit-checklist (hard FAIL).** Version 1.0.0 semver fine. `requires_claude_code: true` declared. `allowed-tools` (hyphen, canonical) correctly enumerates Playwright MCP tools. Missing optional fields: `requires_agent_teams`, `min_plan`, `metadata`, `compatibility`. `owns` block absent (acceptable for stateless workflow — but inconsistent with other workflows in this batch). |
| Description quality | 2 | Action verb "Catch" is present and the trigger surface is exceptionally explicit, but at 1388 chars it can't ship — the field is over the hard ceiling. Content is high-quality and would score 5 if trimmed; **scored 2 because the hard cap is a non-functional violation that blocks load on strict parsers.** |
| Progressive disclosure | 2 | **No `references/` directory.** Body 217 lines — within the 500-line soft guideline but dense (the four-check section alone runs ~80 lines). Several substantial blocks (Step 4 report template, Check 1 pattern table, "What this skill is NOT", "When invoked by other skills") could move to references. |
| Instruction clarity | 5 | Excellent. Strong imperative voice; numbered 5-step workflow; four named checks with concrete tables; explicit anti-pattern definitions ("not visual review", "not accessibility", etc.); explains WHY (the "rendered but broken" failure-mode framing in line 20). |
| Coordination | 2 | **Broken cross-skill references.** `composes_with` lists `ux-review` and `feature-dev`, and `spawned_by` lists `ux-review` — none of these exist in this repo's `skills/` (they're plugin-namespaced skills like `superpowers:feature-dev` and a separately-loaded `ux-review`). `qe-agent`, `orchestrator`, `frontend-agent`, `playwright` all resolve. Orchestrator does reciprocate (orchestrator/SKILL.md:22, 103, 191, 192, 211 reference render-sanity heavily as the post-build gate). |
| Completeness | 4 | Body is self-contained; report template is fully specified (lines 142–182); workflow steps are concrete. Missing: no references to externalize the dense check tables; no examples of completed reports. |
| Anti-patterns | 4 | One MUST-style "Refuse to pass a dead stack" (line 217) is justified. No emojis. No hardcoded project paths. "Kitchen sink" risk — the skill does four things — but they're tightly bound under one user-visible question ("did anyone actually click around"). Acceptable. |

**Average:** 3.00

## Findings

### Critical (must fix to ship)
- **Description 1388 chars exceeds the 1024 hard ceiling.** — SKILL.md:5 — proposed fix: trim to ~600 chars by collapsing the inline failure-mode enumeration into one summary clause; keep the trigger phrases and the "BEFORE the build is declared done" framing. The current body covers the detail.
- **`composes_with` includes `ux-review` and `feature-dev`, `spawned_by` includes `ux-review` — none exist in repo `skills/`.** — SKILL.md:14, 15 — proposed fix: either remove (since they're plugin-namespaced and won't resolve repo-locally) or qualify with the plugin namespace (e.g., `superpowers:feature-dev`). The audit checklist says cross-skill links pointing at nonexistent skills are a FAIL.

### Important (should fix)
- No `references/` directory despite the body being information-dense. Several blocks are extraction candidates: the visible-text smell pattern table (Check 1, lines 36–43), the report template (Step 4, lines 142–182), the "When invoked by other skills" section (lines 204–209). — SKILL.md (whole file) — proposed fix: create `references/report-template.md` and `references/smell-patterns.md`; trim body to ~120 lines.
- `owns` block absent. Workflows in this batch consistently declare empty `owns.directories/patterns` and `shared_read: ["*"]` for stateless skills. Inconsistency. — SKILL.md:after line 5 — proposed fix: add `owns: { directories: [], patterns: [], shared_read: ["*"] }` for consistency.

### Nits (won't block ship)
- `compatibility` field absent. Skill depends on Playwright MCP tools — this should be in `compatibility`. — SKILL.md:6
- The "What this skill is NOT" section (lines 193–201) is excellent disambiguation content but is itself ~10 lines that could be a one-line cross-reference to a dedicated "scope boundaries" reference.
- Step 2 (line 116) hardcodes a port list (`3000 3001 4000 4321 5173 8000 8080`) — this is reasonable for common dev stacks but could miss exotic ports. Worth a comment that the list is illustrative.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Trim description from 1388 → ≤1024 chars (target ~600)** — SKILL.md:5 — collapse the inline enumeration of failure modes ("stale mock IDs leaking…", "lone `?` / `—` / `undefined` / `Loading…`…", etc.) into one summary clause. Keep the action verb, the trigger-phrase list, and the "BEFORE the build is declared done" framing. **This is a hard-fail blocker.** Effort: small.
2. **Fix broken `composes_with` / `spawned_by` references** — SKILL.md:14, 15 — remove `ux-review` and `feature-dev` from `composes_with`; remove `ux-review` from `spawned_by`. If they should be retained for cross-platform parsers, qualify with their plugin namespace (e.g., `superpowers:feature-dev`). Effort: small.
3. **Externalize the dense Check 1 pattern table and Step 4 report template to `references/`** — SKILL.md:36–43, 142–182 — create `references/smell-patterns.md` (the universal smell pattern table) and `references/report-template.md` (the markdown skeleton). Body keeps a one-line "see references/smell-patterns.md for the full table" pointer at each check. Reduces body from 217 → ~120 lines. Effort: medium.

## Dead links / broken references
- `composes_with: ux-review` — no skill at `skills/**/ux-review/SKILL.md` in this repo. **Broken.**
- `composes_with: feature-dev` — no skill at `skills/**/feature-dev/SKILL.md` in this repo. **Broken.**
- `spawned_by: ux-review` — same as above. **Broken.**
- No `references/*.md` exist to be checked for dead-link breakage (the directory itself is absent).
- In-body cross-references to `ux-review`, `ui-ux-pro-max`, `qe-agent`, `contract-auditor`, `performance-agent`, `orchestrator`, `feature-dev` (lines 22, 195–199, 205–209) — `qe-agent`, `contract-auditor`, `performance-agent`, `orchestrator` all resolve. `ux-review`, `ui-ux-pro-max`, `feature-dev` are plugin/external. The body context makes the external dependency clear, so this isn't as severe as the frontmatter breakage, but the inconsistency should be reconciled.
