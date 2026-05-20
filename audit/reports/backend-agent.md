# Audit: backend-agent

**Path:** skills/roles/backend-agent/SKILL.md
**Version:** 1.1.0
**Category:** roles
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields present, version semver, owns block populated correctly. Uses `disable-model-invocation: true` (Anthropic-spec field; not in house spec but valid). Field order drifts: `disable-model-invocation` and `description` come before `requires_*` block which is fine, but `allowed-tools` comes AFTER `min_plan` — house order is `compatibility, license, allowed-tools, metadata, requires_*, min_plan, owns`. No `compatibility` string, no `metadata` block. |
| Description quality | 3 | 207 chars — within ceiling but over 200-char target. Has action verbs ("Builds", "Composed"). Trigger contexts limited to "orchestrator-dispatched only" — intentional gating since this is a spawned-only role. Lacks keyword variants because the design intent is non-user-invocable. Adequate for its purpose but would score low on a generic rubric. |
| Progressive disclosure | 5 | Body 164 lines, well under 500-line guideline. References folder has validation-checklist.md (187 lines, focused). Body links to it at line 161 with clear "when to read" guidance ("Before reporting done"). |
| Instruction clarity | 5 | Imperative voice throughout ("Read the file", "Scaffold based on tech stack"). Numbered steps 1–8 in clear order. Explains WHY (e.g., CORS is "#1 'works in dev, breaks in integration' issue"). Pitfalls table maps cause → prevention. |
| Coordination | 5 | Owns section matches orchestrator's file-ownership.md exactly. Off-limits explicitly enumerated at line 57. `composes_with` lists 6 collaborators that all exist. Database boundary with db-migration-agent clearly explained at line 142. Observability hooks coordination at line 143. |
| Completeness | 5 | validation-checklist.md exists and is linked. Pitfalls table provides examples. Step 0 (Read Contracts) IS present at section "1. Read Contracts and Domain Rules". Right-sizing called out in step 3. Off-limits section explicit. |
| Anti-patterns | 4 | One mild kitchen-sink risk: validation-checklist.md includes a Fastify-specific section (lines 41–61) inside a generic backend checklist — fine as a known-trap callout but it is project-style guidance leaking into a generic role checklist. Otherwise no hardcoded paths, no excessive MUST/NEVER without rationale. |

**Average:** 4.4

## Findings

### Critical (must fix to ship)

None.

### Important (should fix)

- Frontmatter field order drift — SKILL.md:7–15 — move `allowed-tools` above `requires_agent_teams` to match house order (`compatibility, license, allowed-tools, metadata, requires_*, min_plan, owns`).
- Description at 207 chars exceeds 200-char target — SKILL.md:5 — tighten to ≤200 chars (drop the redundant "Composed by orchestrator during multi-agent builds" since "Orchestrator-dispatched only" already says this).
- Missing `compatibility` string — SKILL.md:1–16 — add e.g. `compatibility: "Claude Code; requires Bash for curl/test commands"` to declare host requirements per spec.

### Nits (won't block ship)

- No `metadata` block (author/category/tags) — would aid catalog discovery.
- validation-checklist.md Fastify section (refs:41–61) is stack-specific inside a generic checklist; consider moving to `references/fastify-traps.md` linked conditionally.
- SKILL.md:80 has minor whitespace inconsistency in the ASCII directory layout (extra space before `src/middleware/`).
- "Off-limits" listed inline in the "Your Ownership" section rather than a dedicated heading — house convention varies but a `## Off-Limits` heading would aid scannability.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Reorder frontmatter to house style — SKILL.md:7–15 — move `allowed-tools` to come after `min_plan`-block reorder so order is `name, version, disable-model-invocation, description, allowed-tools, requires_agent_teams, requires_claude_code, min_plan, owns, composes_with, spawned_by`. Effort: small.
2. Tighten description to ≤200 chars — SKILL.md:5 — replace with `"Orchestrator-dispatched only. Builds API servers, business logic, and data layers for multi-agent contract-first builds. Not user-invocable."` (~155 chars). Effort: small.
3. Add `compatibility` field — SKILL.md:6 — insert `compatibility: "Claude Code; requires Bash for curl/test commands"`. Effort: small.

## Dead links / broken references

None. `references/validation-checklist.md` exists and resolves. All `composes_with` targets (frontend-agent, qe-agent, infrastructure-agent, contract-author, db-migration-agent, observability-agent) exist under `skills/roles/` and `skills/contracts/`.
