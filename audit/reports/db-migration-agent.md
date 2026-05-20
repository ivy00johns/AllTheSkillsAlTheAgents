# Audit: db-migration-agent

**Path:** skills/roles/db-migration-agent/SKILL.md
**Version:** 1.1.0
**Category:** roles
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields. Semver valid. owns block has 4 directories (`migrations/`, `seeds/`, `prisma/`, `alembic/`) — non-overlapping with other roles. shared_read is `src/models/` (specific, good). Note: owns lacks `knex/migrations/` mentioned in body line 50. No compatibility/metadata. |
| Description quality | 3 | 197 chars under 200 target. Action verb "Manages". Lists capabilities. Intentionally narrow as spawned-only. |
| Progressive disclosure | 5 | Body 127 lines. Two references: migration-checklist.md 154 lines (stack patterns), validation-checklist.md 104 lines (runtime gates). Body links migration-checklist at line 75. validation-checklist.md is NOT explicitly linked from body — body's "Validation" section uses inline checklist instead. |
| Instruction clarity | 5 | Imperative voice. Numbered steps 0–4. Step 0 explicit (Read Data Layer Contract). Step 4 includes a verification snippet pattern. Migration files (step 2) lists 4 quality attributes (idempotent, reversible, ordered, atomic). |
| Coordination | 5 | Owns matches orchestrator/file-ownership.md (note: file-ownership.md doesn't list db-migration explicitly but it's implied via "migrations/" callout in backend-agent coordination). Off-limits explicit. `composes_with` lists 3 collaborators. Coordination rules at lines 112–114 with backend-agent (models handoff), infra-agent (DB engine), qe-agent (seed determinism). |
| Completeness | 4 | migration-checklist.md exists and is linked. validation-checklist.md exists but is NOT linked from body — `## Validation` section (lines 118–124) lists inline instead. Both exist, but the body should point at validation-checklist.md since it has the load-bearing runtime gates (money columns, tenant scoping, seed determinism). |
| Anti-patterns | 4 | migration-checklist.md has stack-specific Drizzle/tsx callout (refs:93–123) which is sharp guidance but mildly kitchen-sink in a generic checklist. validation-checklist.md has multi-tenant tenant_id guidance (refs:96–103) — project-specific concern leaking into a generic role doc. Otherwise clean. |

**Average:** 4.4

## Findings

### Critical (must fix to ship)

None.

### Important (should fix)

- validation-checklist.md exists but is NOT linked from SKILL.md body — SKILL.md:116–124 — body's `## Validation` section uses inline list instead of pointing at the dedicated file (which has the load-bearing runtime checks: money columns, tenant scoping, seed determinism). Add `Run references/validation-checklist.md before reporting done` as a primary callout.
- owns directories list missing `knex/migrations/` despite body line 50 mentioning Knex — SKILL.md:10 — either add `knex/migrations/` to owns.directories or remove the parenthetical mention.
- Self-referential pipeline blockquote — SKILL.md:20 — "Reports to `qe-agent` via `qa-report.json`" template-bleed.

### Nits (won't block ship)

- No `metadata` block.
- No `compatibility` string.
- Project-specific guidance in validation-checklist.md (multi-tenant tenant_id at refs:96–103) — consider moving to a separate tenant-scoping ref.
- Stack-specific Drizzle/tsx note in migration-checklist.md (refs:93–123) is sharp but adds bulk.
- "Right-sizing" not explicit — body doesn't say "skip migrations for prototype/SQLite-only builds where `CREATE TABLE IF NOT EXISTS` is sufficient" (which backend-agent SKILL.md actually mentions).

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Link references/validation-checklist.md from body — SKILL.md:116 — replace inline list with "Run `references/validation-checklist.md` before reporting done" as primary callout. Effort: small.
2. Reconcile owns.directories with body — SKILL.md:10 — add `knex/migrations/` to match body line 50, or remove the Knex parenthetical. Effort: small.
3. Fix self-referential pipeline blockquote — SKILL.md:20 — reword to "Schema feeds `qe-agent`'s `contract_conformance` score". Effort: small.

## Dead links / broken references

None. Both references exist. All `composes_with` targets (backend-agent, infrastructure-agent, qe-agent) exist.
