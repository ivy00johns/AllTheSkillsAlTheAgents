# Audit: zoom-out

**Path:** skills/workflows/zoom-out/SKILL.md
**Version:** 1.0.0
**Category:** workflows
**Verdict:** NEEDS WORK

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields present; semver 1.0.0; no `<`/`>` in field values. Description 412 chars (well under 1024). `allowed-tools` hyphenated. `composes_with: ["maintain-context"]` — exists. **However, `disable-model-invocation: true` (line 5) is the same out-of-spec field as in setup-project-skills — not documented in the frontmatter spec.** Same ecosystem-level issue: either standardize the field or move under `metadata:`. Score: 4 (not 5) for the unspecced field. |
| Description quality | 5 | 412 chars — concise and well within ceiling. Starts with action verb "Step back". Three explicit trigger contexts ("feeling stuck in detail", "change feels bigger than expected", "before making a structural decision"). States exclusion ("Explicit invocation only — does not auto-fire") — useful pushy/anti-pushy disambiguation. |
| Progressive disclosure | 5 | Body 24 lines / ~50 words. Tiny by design — the skill is a single orientation prompt that doesn't need references. Appropriate level of disclosure for the scope. |
| Instruction clarity | 4 | Three short imperative lines. Clear output format (numbered list with arrows). Explicit non-goal ("Do not propose changes"). Could explain WHY the output uses arrows (presumably to make connections visible), but the format is conventional enough. The instructions are crisp and complete for the skill's scope. |
| Coordination | 5 | `composes_with: ["maintain-context"]` accurate — maintain-context provides the `CONTEXT.md` this skill reads. Non-agent so no ownership conflicts. `shared_read: ["*"]` reasonable for a read-only orientation tool. |
| Completeness | 4 | The skill references `CONTEXT.md` (body line 20) which is a convention from the maintain-context skill — fine assumption. No worked example of the output format — a 3-5 line example would help (e.g., "1. AuthService — handles JWT validation → 2. UserRepo — persists users"). The skill is intentionally minimal but a single example would prevent ambiguity. |
| Anti-patterns | 5 | No MUST/NEVER abuse. No hardcoded project paths. No body content that should move to references (the body IS the skill). "Do not propose changes" is the right shape of non-goal. |

**Average:** 4.57

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- `disable-model-invocation: true` on `skills/workflows/zoom-out/SKILL.md:5` is not in the frontmatter spec — same issue as `skills/workflows/setup-project-skills/SKILL.md:6`. Both skills use this field for the same semantic ("explicit invocation only, do not auto-fire from description matching"). Resolve at the spec level: add to the spec OR migrate both to `metadata.invocation: explicit-only`. This is an ecosystem-level fix, not skill-local.

### Nits (won't block ship)
- Add a 3-5 line output example. — `skills/workflows/zoom-out/SKILL.md:22` — after "with arrows (`→`) showing the connections between them" add a code fence:
  ```
  Example:
  1. AuthService — validates JWTs → 2. UserRepo
  2. UserRepo — persists/loads users → 3. SessionStore
  3. SessionStore — refresh-token cache → AuthService
  ```
  Removes any ambiguity about format.
- "Use the domain glossary (`CONTEXT.md`) if one exists" — body line 20 — could add "(see `setup-project-skills` for where CONTEXT.md is configured)" to anchor the convention. Minor.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Resolve the ecosystem-level `disable-model-invocation: true` out-of-spec field. — `skills/workflows/zoom-out/SKILL.md:5` AND `skills/workflows/setup-project-skills/SKILL.md:6` AND `skills/meta/skill-writer/references/frontmatter-spec.md` — either document the field in the spec as an optional top-level boolean OR migrate both skills to `metadata.invocation: explicit-only`. effort: small (touches the spec + 2 SKILL.md files).
2. Add a worked output example to remove format ambiguity. — `skills/workflows/zoom-out/SKILL.md:22` — append a 3-5 line example showing the numbered-list-with-arrows format. effort: small.
3. Anchor the `CONTEXT.md` reference to setup-project-skills. — `skills/workflows/zoom-out/SKILL.md:20` — add "(configured via `setup-project-skills`)" or similar. effort: small.

## Dead links / broken references
- None. `composes_with: ["maintain-context"]` resolves; `CONTEXT.md` is a convention not a hardcoded file path.
