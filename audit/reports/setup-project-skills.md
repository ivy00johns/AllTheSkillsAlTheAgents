# Audit: setup-project-skills

**Path:** skills/workflows/setup-project-skills/SKILL.md
**Version:** 1.0.0
**Category:** workflows
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields present; semver 1.0.0; no `<`/`>` in field values; `allowed-tools` hyphenated. `composes_with: ["project-profiler", "sync-skills"]` — both exist. `disable-model-invocation: true` (line 6) is non-standard — not documented in the frontmatter spec at `skills/meta/skill-writer/references/frontmatter-spec.md`. The intent (explicit-invocation only) is clearly stated in body line 21, but the field needs to be either added to the spec or moved into `metadata:` as a nested key. |
| Description quality | 5 | 819 chars (under 1024 ceiling). Starts with action verb "Bootstrap". 5 explicit trigger phrases. Clearly states what it writes, what it doesn't overwrite, and that it runs once. Pushy where it needs to be. |
| Progressive disclosure | 5 | Body 125 lines / ~1000 words — within guidelines. 10 template files under `references/templates/`, each 32-59 lines, referenced from body lines 66-68 with explicit substitution syntax. No reference >300 lines so no TOC needed. |
| Instruction clarity | 5 | Strong imperative voice. Three-question flow is numbered. Each Q includes a recommendation heuristic (e.g., "Recommend `single-context` unless you see..."). Output section maps Q→template→output explicitly. Idempotence section spells out the success condition. |
| Coordination | 5 | `owns.directories: ["docs/agents/"]` — exclusive and meaningful. `composes_with: ["project-profiler", "sync-skills"]` both exist. Body §"Compose with" (line 122-125) accurately describes the integration points. Defines a "failure-loud contract" downstream skills MUST follow — clear handoff protocol. |
| Completeness | 5 | All 10 template files exist (3 domain-docs would be too many; spec is 2 domain × 4 contract × 4 tracker = 10 templates which matches). The "Agent skills" block to append is given verbatim. Idempotence rules cover repeat invocations. Downstream consumer pattern explicitly documented. |
| Anti-patterns | 4 | Body uses MUST in §"Failure-loud contract" (line 98) — justified by the explicit need for downstream skills to surface missing config. The `disable-model-invocation: true` field is an out-of-spec extension that should be standardized. Otherwise no hardcoded paths beyond the documented `docs/agents/` convention, no duplication. |

**Average:** 4.71

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- `disable-model-invocation: true` on `skills/workflows/setup-project-skills/SKILL.md:6` is not in the frontmatter spec at `skills/meta/skill-writer/references/frontmatter-spec.md`. Either (a) add it to the spec as a documented optional field with a clear semantic ("skill is invoke-only via slash command, not via description-triggered auto-invocation"), or (b) move it under `metadata:` as `metadata.invocation: explicit-only`. The body already states "Explicit-invocation only" so the semantic is unambiguous — it just needs spec alignment.

### Nits (won't block ship)
- Body refers to "Skill-Madness toolkit" by name in lines 25, 87 — this is the project name (per CLAUDE.md the repo was renamed to Skill Madness). Acceptable since the project is the deployment target, but worth noting hardcoded project name.
- Output mapping on line 66-68 uses the shorthand `{single|multi}` and `{openapi|pydantic|ts|jsonschema}` — clearer if rendered as an explicit table mapping answer → template path.
- "Failure-loud contract for downstream skills" section uses MUST (line 98) but the pattern (line 100-102) doesn't tell downstream skill authors HOW to detect missing config. A one-line code snippet like `if not Path('docs/agents/contract-format.md').exists():` would help.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Resolve the out-of-spec `disable-model-invocation: true` frontmatter field. — `skills/workflows/setup-project-skills/SKILL.md:6` AND `skills/meta/skill-writer/references/frontmatter-spec.md` — either document the field in the spec as an optional top-level boolean (clear semantic: skip auto-invocation gating) or move it to `metadata.invocation: explicit-only` and update body line 21 to reference the metadata field. effort: small.
2. Convert the answer→template mapping on lines 66-68 into an explicit table. — `skills/workflows/setup-project-skills/SKILL.md:64-68` — replace the bullet shorthand with a 3-column table (Question / Answer / Template). effort: small.
3. Add a concrete code snippet for the downstream-skill detection pattern. — `skills/workflows/setup-project-skills/SKILL.md:98-110` — show a one-line `Read('docs/agents/contract-format.md')` check + error message template downstream skill authors can paste. effort: small.

## Dead links / broken references
- None. All 10 template files exist. `composes_with` targets `project-profiler` and `sync-skills` both exist in repo.
