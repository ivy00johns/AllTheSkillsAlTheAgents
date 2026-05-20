# Audit: dependency-coordinator

**Path:** skills/workflows/dependency-coordinator/SKILL.md
**Version:** 1.0.0
**Category:** workflows
**Verdict:** NEEDS WORK

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 3 | Required fields present (`name`, `version`, `description`). Description 238 chars — close to 200 target. No `<`/`>`. **However:** uses two non-standard fields not in the frontmatter spec: `disable-model-invocation: true` (line 4) and `type: contract` (line 6). Neither appears in `skills/meta/skill-writer/references/frontmatter-spec.md`. Missing `composes_with`/`spawned_by` even though composition with `contract-author`, `infrastructure-agent`, `contract-auditor`, `orchestrator` is described in body (lines 105-110). Missing `allowed-tools`. Missing `requires_claude_code`. |
| Description quality | 3 | Action verb "Authors"; 238 chars. **States "Not user-invocable"** and "Orchestrator-dispatched only" — this is unusual; intentionally narrow trigger surface. No keyword-variant triggers. Defensible for a contract skill that only runs via orchestrator, but won't trigger on user phrases. |
| Progressive disclosure | 5 | Body 110 lines / under 2000 words; three reference files all linked from body with explicit "when to read" guidance (lines 48, 50, 54, 101-103); no duplicate content; references are well-scoped. |
| Instruction clarity | 5 | Imperative voice; clear Inputs / Process / Right-sizing / Coordination / Output / Quality checklist / Anti-patterns sections; numbered process steps; explicit dry-install verification (line 57). |
| Coordination | 3 | Composition described in body (lines 105-110) but **NOT declared in frontmatter** as `composes_with`. Lines 70-72 explicitly state run order vs contract-author and infrastructure-agent — good. But since the frontmatter doesn't expose this, ecosystem-level checks (reciprocal composes_with verification) can't validate it. No `owns` block — workflow skill so technically OK, but `DEPENDENCIES.md` ownership at workspace root could be declared. |
| Completeness | 4 | All three reference files exist and are linked. Templates thorough (pnpm/npm/yarn/Poetry/uv/Cargo all covered). Known-conflict table comprehensive. **One issue:** `references/dependencies-md-template.md:47` references `docs/qa/skill-ecosystem-audit-2026-04-30.md` and `references/known-conflict-deps.md:75` references the same file — that doc lives outside the skill repo as a project artifact (Bazaar build). Won't resolve for other users. |
| Anti-patterns | 4 | One real anti-pattern: hardcoded project history embedded in references ("the Bazaar gauntlet, 2026-04-30", "5 parallel agents wrote independent package.json files"). It's narratively useful but is one-project bias. Otherwise the skill explicitly avoids common anti-patterns (empty overrides block, strict-pinning everything, authoring per-package package.json directly). |

**Average:** 3.9

## Findings

### Critical (must fix to ship)
- None hard-blocking, but the non-standard frontmatter fields are concerning.

### Important (should fix)
- **Non-standard frontmatter fields** `disable-model-invocation: true` and `type: contract` — SKILL.md:4, :6 — neither is defined in `skills/meta/skill-writer/references/frontmatter-spec.md`. Either add them to the spec (with a documented purpose) or move the intent into the description ("Not user-invocable; dispatched only by orchestrator") and remove the fields.
- **`composes_with` missing from frontmatter** — SKILL.md:7 — body lines 105-110 list 4 composition targets (`contract-author`, `infrastructure-agent`, `contract-auditor`, `orchestrator`). These should be declared in frontmatter so ecosystem-level checks pass.
- **`spawned_by: [orchestrator]` missing** — SKILL.md:7 — body line 110 says "runs this skill in Phase 4" and description says "Orchestrator-dispatched only" — declare reciprocally.
- **Hardcoded project narrative** in references — references/known-conflict-deps.md:75, references/dependencies-md-template.md:47 — both cite "the Bazaar gauntlet, 2026-04-30" and a path `docs/qa/skill-ecosystem-audit-2026-04-30.md` outside this repo. Generalize the lesson or move the citation to a private notes file.
- **Missing `allowed-tools`** — SKILL.md:7 — skill writes templates, reads profile.yaml, runs dry installs; should declare `["Read", "Write", "Edit", "Bash", "Glob"]`.

### Nits (won't block ship)
- "Pipeline position" blockquote at line 11 duplicates body-level coordination info at lines 68-72; minor.
- Quality checklist (lines 83-90) could move to a `references/checklist.md` if checklist grows.
- Reference to "orchestrator's Phase 4" appears 3x; could be normalized.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Add `composes_with`, `spawned_by`, `allowed-tools`, and remove non-standard `disable-model-invocation`/`type` fields** — SKILL.md:4-7 — replace with standard frontmatter: `composes_with: ["contract-author", "infrastructure-agent", "contract-auditor", "orchestrator"]`, `spawned_by: ["orchestrator"]`, `allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob"]`, `requires_claude_code: true`. Move the "Not user-invocable" semantic to the description body.
2. **Generalize "Bazaar gauntlet" hardcoded citations** — references/known-conflict-deps.md:75, references/dependencies-md-template.md:47 — replace project-specific incident name with generic "real-world build with N parallel agents and esbuild postinstall conflict"; remove the `docs/qa/...` path that lives outside this repo.
3. **Tighten description with action triggers** — SKILL.md:5 — current 238 chars is fine but the "Not user-invocable" framing precludes any user-said triggers. If kept, document the intentional narrow surface; if loosened, add 3-4 trigger phrases ("pin dependencies", "monorepo dep drift", "package version conflict").

## Dead links / broken references
- `docs/qa/skill-ecosystem-audit-2026-04-30.md` cited at references/known-conflict-deps.md:75 and references/dependencies-md-template.md:47 — lives outside the skill repo; won't resolve.
- All three references/*.md files exist and are linked from SKILL.md.
- `composes_with` targets from body (contract-author, infrastructure-agent, contract-auditor, orchestrator) all exist in the ecosystem.
