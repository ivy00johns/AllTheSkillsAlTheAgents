# Master Audit Plan — Skill Ecosystem (47 skills)

**Audit date:** 2026-05-20
**Skills audited:** 47 (skipped 6 archived: skills/archive/)
**Method:** skill-review rubric (deep-review-rubric.md, 7 dimensions × 1-5 scoring) + ecosystem-wide cross-cutting bulk audit (broken refs, frontmatter drift, dead refs, trigger overlap, coverage gaps, doc drift).
**Inputs:** `audit/reports/00-bulk-audit.{md,json}` + `audit/reports/{skill}.{md,json}` × 47.

---

## Executive Summary

- **SHIP:** 35 skills (74%)
- **NEEDS WORK:** 12 skills (26%)
- **MAJOR REWORK:** 0 skills (0%)
- **Average score:** 4.49 / 5.0
- **Critical findings:** 15 (per-skill) + ecosystem deltas (broken refs ×5 real + ×24 plugin-only, coverage gaps, doc drift) — ≈ **18 unique critical action items** after dedupe
- **Important findings:** 77 (per-skill) + ecosystem normalization items (frontmatter drift, non-spec fields ×16, missing `requires_*` ×2, dead reference links ×4, role-agent template bleed ×7, description >200 chars on long tail) — ≈ **90 unique important action items**
- **Nits:** 160 (deferred unless trivially batched with related fix)

**Headline:** the ecosystem is healthy. No skill scored below 3.0. The pain points cluster on **5 oversized descriptions (>1024 char hard fail)**, **5 cross-refs to archived/non-existent skills**, **2 skills missing required frontmatter** (`dependency-coordinator`, `interactive-doc`), **stale archive references** in 4 skills, and **CLAUDE.md doc drift** (24 skills not listed, render-sanity missing from workflows count). Everything else is tightening for polish.

---

## Verdict Distribution

| Category | SHIP | NEEDS WORK | MAJOR REWORK | Total |
|---|---|---|---|---|
| orchestrator | 0 | 1 | 0 | 1 |
| contracts | 2 | 0 | 0 | 2 |
| meta | 2 | 2 | 0 | 4 |
| git | 3 | 1 | 0 | 4 |
| roles | 10 | 0 | 0 | 10 |
| workflows | 18 | 8 | 0 | 26 |
| **Total** | **35** | **12** | **0** | **47** |

---

## Critical Findings (must fix to ship)

Grouped by **fix category** so disjoint-file fix waves can run in parallel.

### C1. Hard-fail descriptions (>1024-char Anthropic ceiling)

Five skills exceed the documented hard ceiling; one sits right at it.

| Skill | Chars | File:Line | Proposed fix | Effort |
|---|---|---|---|---|
| orchestrator | 1445 | `skills/orchestrator/SKILL.md:5` | Compress to ≤200-char trigger paragraph; move INVOKES/DISPATCHES enumeration + "does NOT preempt" list into a new `## Composition` body section | S |
| ui-brief | 1443 | `skills/workflows/ui-brief/SKILL.md:5` | Trim to ≤800 chars; collapse named-style enumeration + reference-app enumeration; drop "Also trigger before invoking..." sentence | S |
| interactive-doc | 1416 | `skills/workflows/interactive-doc/SKILL.md:4-5` | Delete final "Output is always a pair..." sentence and "Especially trigger when..." repetition | S |
| render-sanity | 1388 | `skills/workflows/render-sanity/SKILL.md:5` | Collapse inline failure-mode enumeration into one summary clause; keep trigger phrases + "BEFORE build declared done" framing; target ~600 chars | S |
| claude-design-brief | 1191 | `skills/workflows/claude-design-brief/SKILL.md:4-5` | Delete "Distinguish from ui-brief" sentence (~280 chars); trim trigger list from 11 to ~6 | S |
| skill-explorer | 1024 (at ceiling) | `skills/meta/skill-explorer/SKILL.md:5-15` | 1 char under ceiling — tighten multi-clause sentence at L11-15 to drop ~200 chars | S |
| settings-consolidator | 1011 (near ceiling) | `skills/workflows/settings-consolidator/SKILL.md:4-16` | 13 chars under ceiling; collapse two trigger sentences + dedupe keywords to ≤800 chars | S |

### C2. Broken in-repo cross-references (composes_with / spawned_by → skills that do not exist)

These reference archived or never-existed skill names. Five **real bugs**:

| Skill | Field | Ref | Proposed fix | Effort |
|---|---|---|---|---|
| git-commit | composes_with | `git-branch-cleanup` (archived) | Replace with `git-post-merge-cleanup` (active replacement); array becomes `['git-pr', 'git-post-merge-cleanup', 'git-pr-feedback']` | S |
| skill-explorer | composes_with | `skill-audit` (archived) | Replace with `skill-review` | S |
| skill-explorer | composes_with | `skill-deep-review` (archived) | Replace with `skill-review` (consolidated `--scope=all` / `--scope=<name>`) | S |
| sync-skills | composes_with | `skill-updater` | Correct name: `skill-update` | S |
| sync-skills | composes_with | `skill-audit` | Replace with `skill-review` | S |

### C3. Stale archive references in body text (not just frontmatter)

Body content still routes users to archived skills.

| Skill | Location | Stale ref | Fix | Effort |
|---|---|---|---|---|
| skill-explorer | `SKILL.md:131` routing rule | `skill-audit` | Change to `skill-review (--scope=all` / `--scope=<name>`) | S |
| skill-explorer | `SKILL.md:144` "When NOT to invoke" | `skill-audit` | Change to `skill-review` | S |
| skill-update | `SKILL.md:5,24,29,33,45` (5 instances) | `skill-deep-review`, `skill-audit` | Replace all with `skill-review` | M |
| skill-update | `references/plan-format.md` | `skill-audit` | Replace with `skill-review` | S |

### C4. Missing required frontmatter fields (`requires_*` / `allowed-tools`)

Two skills lack the required-fields block per house spec.

| Skill | Missing fields | Fix | Effort |
|---|---|---|---|
| dependency-coordinator | `composes_with`, `spawned_by`, `allowed-tools`, `requires_claude_code` (plus non-spec `disable-model-invocation`, `type:contract` to remove) | Add full required block: `composes_with: [contract-author, infrastructure-agent, contract-auditor, orchestrator]`, `spawned_by: [orchestrator]`, `allowed-tools: [Read, Write, Edit, Bash, Glob]`; remove `disable-model-invocation` + `type` | S |
| interactive-doc | `composes_with`, `allowed-tools`, `requires_claude_code`, `metadata.category` | Add the four standard fields | S |

### C5. Cross-project portability — hardcoded "Skill Madness root .env"

Breaks the toolkit when installed in any other project. Affects two skills.

| Skill | Location | Fix | Effort |
|---|---|---|---|
| nano-banana | `SKILL.md:47` | Rephrase to "current project repo-root .env" or document lookup chain | S |
| railway-deploy | `SKILL.md:33` | Same; rephrase to "current project repo-root .env" | S |

### C6. Hardcoded path to author-only machine

| Skill | Location | Fix | Effort |
|---|---|---|---|
| claude-design-brief | `SKILL.md:120` references `SovereignSampson/CLAUDE-DESIGN-PROMPT.md` | Drop the line or replace with generic pointer to `references/direction-examples/` | S |

### C7. render-sanity composes_with/spawned_by reference plugin-only skills as if in-repo

| Skill | Location | Fix | Effort |
|---|---|---|---|
| render-sanity | `SKILL.md:14-15` | Either remove `ux-review` + `feature-dev` from arrays, **or** qualify with plugin namespace (`superpowers:feature-dev`) | S |

### C8. ui-brief composes_with lists 4 plugin-only skills without namespace

| Skill | Location | Fix | Effort |
|---|---|---|---|
| ui-brief | `SKILL.md:14` | Drop `ui-ux-pro-max`, `frontend-design`, `brainstorming`, `ux-review` (leaving `frontend-agent`, `orchestrator`, `playwright`) **or** extend frontmatter spec to support a `composes_with_external:` plugin-namespaced field | S |

---

## Important Findings (should fix this pass)

### I1. Plugin-only `composes_with` / `spawned_by` (annotate or namespace)

Bulk audit found **24 plugin-only references** across orchestrator (12), claude-design-brief (3), render-sanity (3), ui-brief (4), frontend-agent (2). These are not broken — they reference skills that exist in plugin packs (`superpowers`, `claude-mem`, etc.) and the user is running them. But they violate the strict cross-ref check.

**Recommended fix:** add a `plugin_external` convention to `references/frontmatter-spec.md` and namespace these (e.g., `superpowers:brainstorming`, `claude-mem:mem-search`). orchestrator already uses `claude-mem:*` correctly — extend the pattern everywhere.

Affected skills + counts:

| Skill | Plugin-only refs |
|---|---|
| orchestrator | brainstorming, writing-plans, frontend-design, ui-ux-pro-max, ux-review, claude-api, feature-dev, claude-mem:mem-search, claude-mem:timeline-report, claude-mem:knowledge-agent, loop, schedule |
| frontend-agent | frontend-design, ui-ux-pro-max |
| claude-design-brief | ui-ux-pro-max, frontend-design, brainstorming |
| render-sanity | ux-review (composes_with + spawned_by), feature-dev |
| ui-brief | ui-ux-pro-max, frontend-design, ux-review, brainstorming |

### I2. CLAUDE.md doc drift

- **Workflow count is wrong**: CLAUDE.md says `workflows/` has **25** skills; actual count is **26**. Missing from CLAUDE.md workflows list: **`render-sanity`**.
- **24 skills are not referenced anywhere in CLAUDE.md** (only category counts mention them): backend-agent, caveman, code-review-agent, contract-auditor, contract-author, db-migration-agent, docs-agent, frontend-agent, git-commit, git-post-merge-cleanup, git-pr, git-pr-feedback, infrastructure-agent, observability-agent, orchestrator, performance-agent, playwright, qe-agent, render-sanity, security-agent, skill-explorer, skill-review, skill-update, skill-writer.
- `allowed-tools` mentioned in CLAUDE.md but not found in repo grep target (false-positive — appears in nearly every SKILL.md).
- `multi-agent` in file-ownership not found in repo (legacy reference; check file-ownership.md).

**Fix:** update CLAUDE.md workflow count `25` → `26`, add `render-sanity` to the workflows list, verify count once more. Optionally regenerate the skill catalog inline from a `ls skills/*/*/` script.

### I3. Description over 200-char target (long tail)

After fixing the 5 hard-fail oversize descriptions (C1), **22 more skills** are over the 200-char house target. Acceptable individually (well under 1024 ceiling) but the long tail signals pushy-description debt. Top offenders:

| Skill | Chars | Suggested fix |
|---|---|---|
| contract-author | 984 | Drop trailing "Bundles 6 templates..." sentence |
| mermaid-charts | 954 | Drop "even if the user doesn't say mermaid" paragraph; target ~400 chars |
| settings-consolidator | 928 | (covered in C1 borderline) |
| wiki-research | 902 | Collapse "Trigger on:" list to 3-4 phrases |
| llm-wiki | 846 | Trim preamble + in-wiki trigger restatement |
| architecture-rescue | 747 | Trim methodology preamble |
| maintain-context | 717 | Drop inline three-condition recital |
| setup-project-skills | 685 | Tighten |
| plan-builder | 673 | Drop trigger enumeration |
| grill-me | 656 | Trim methodology preamble |
| caveman | 629 | Trim auto-deactivation enumeration |
| work-item-brief | 631 | Tighten |
| nano-banana | 615 | Remove redundant trigger phrases |
| playwright | 616 | Consolidate 10 triggers to 4-5 |
| diagnose-loop | 603 | Trim methodology preamble |
| skill-update | 596 | After C3 fix, trim to 5 strongest variants |
| skill-review | 586 | Update "100-line rule" → "500-line/5000-word"; trim list |
| railway-deploy | 586 | Collapse to 3 distinctive triggers |
| git-pr-feedback | 554 | Stylistic (acceptable) |
| sync-skills | 544 | (covered in C2 — fix during ref fix) |
| git-pr | 553 | Stylistic |
| git-commit | 502 | Stylistic |
| context-manager | 481 | Drop middle "managing context limits..." repetition |
| project-profiler | 483 | Acceptable |
| deployment-checklist | 416 | Drop "Use this skill when preparing..." middle clause |

### I4. Role-agent template bleed ("Reports to qe-agent via qa-report.json" appears in non-qe agents)

Self-referential pipeline blockquote bleed from a template now used wholesale across role agents. Cosmetic but confusing.

| Skill | Location | Fix |
|---|---|---|
| code-review-agent | `SKILL.md:20` | "Review report feeds into qe-agent correctness/code_quality/contract_conformance scores" |
| db-migration-agent | `SKILL.md:20` | "Schema feeds qe-agent contract_conformance" |
| docs-agent | `SKILL.md:20` | "feeds into qe-agent completeness score" |
| observability-agent | `SKILL.md:20` | "Provides instrumentation that qe-agent validates" |
| performance-agent | `SKILL.md:20` | "Feeds into qe-agent performance score" |
| qe-agent | `SKILL.md:22` | "Writes qa-report.json for the orchestrator" |
| security-agent | `SKILL.md:20` | "Findings feed into qe-agent security score" |

### I5. Non-spec frontmatter fields

Bulk audit found:

- `disable-model-invocation` on **14 skills** (all role agents + dependency-coordinator + setup-project-skills + zoom-out). This is a real Claude Code intent ("not user-invocable") but is **not in the `frontmatter-spec.md`**. Two options:
  1. **Document it** as a house extension in `skills/meta/skill-writer/references/frontmatter-spec.md`.
  2. **Migrate** to `metadata.invocation: explicit-only` or `metadata.invocation: orchestrator-only`.
  Decision: option 1 is lower-risk and matches actual practice — add a "Disable Model Invocation" section to the spec.
- `argument-hint` on **skill-review** — also a real Claude Code field (slash command UX); document in spec.
- `type: contract` on **dependency-coordinator** — not a known field; remove (covered in C4).

### I6. Dead reference links (referenced in SKILL.md body but no matching file in `references/`)

| Skill | Unlinked ref | Fix |
|---|---|---|
| db-migration-agent | `validation-checklist.md` (exists but body doesn't link it at L116-124) | Replace inline list with "Run `references/validation-checklist.md` before reporting done" |
| claude-design-brief | `direction-examples` (referenced as dir) | Verify body link target spelling vs `references/direction-examples/` |
| mermaid-charts | `chart-types` (referenced) | Verify body link target |
| setup-project-skills | `templates` (referenced) | Verify body link target |

### I7. Trigger overlap disambiguation (already partially disambiguated; tighten)

These pairs share keywords — confusion risk is low but worth one-line clarifications.

| Pair | Shared keyword | Status |
|---|---|---|
| claude-design-brief vs ui-brief | "design brief / redesign" | Already disambiguated; keep sibling-distinction sentence (NOTE: C1 fix above suggests removing it from claude-design-brief — replace with a body §When to use which paragraph instead) |
| skill-writer vs skill-update | "create / improve skill" | Already disambiguated |
| skill-writer vs skill-review | "skill quality" | Low risk |
| skill-review vs skill-update | "audit / improve" | Already coupled (review → update) |
| interactive-doc vs llm-wiki | "wiki / knowledge base" | Disambiguated |
| interactive-doc vs wiki-research | "wiki / research artifact" | Sequential — keep |
| llm-wiki vs wiki-research | "wiki / second brain" | Disambiguated |
| playwright vs render-sanity | "browser / frontend check" | **Tighten**: change render-sanity to say "lightweight visual sanity" explicitly |

### I8. Hardcoded project-specific endpoints in role-agent reference files

Multiple role agents have hardcoded `/api/v1/sessions` (a leftover from a worked example).

| Skill | Location | Fix |
|---|---|---|
| qe-agent | `references/validation-checklist.md:17,40,52,56,59,64` | Replace with `${RESOURCE_PATH}` |
| performance-agent | `references/k6-patterns.md:35,48,135` | Replace with `${RESOURCE_PATH}` |
| docs-agent | `references/doc-templates.md:50,54-56` | Use `/<resource>` placeholders |

### I9. Hardcoded old project name "AllTheSkills"

| Skill | Location | Fix |
|---|---|---|
| ui-brief | `SKILL.md:183` | Replace "AllTheSkills repo root" with "Skill Madness" |
| repo-deep-dive | `references/document-template.md:167,170` | Replace "AllTheSkills" with `{reference-project}` placeholder |

### I10. Missing `compatibility:` string (house-spec optional but role-agent pattern)

Seven role agents lack the `compatibility:` field that documents required external tools:

| Skill | Suggested value |
|---|---|
| backend-agent | `Claude Code; requires Bash for curl/test commands` |
| code-review-agent | `Claude Code` |
| db-migration-agent | `Claude Code; requires Bash + DB CLI` |
| docs-agent | `Claude Code` |
| frontend-agent | `Claude Code; requires Bash + Node toolchain` |
| infrastructure-agent | `Claude Code; requires Bash + docker CLI + lsof` |
| observability-agent | `Claude Code; requires Bash for instrumentation tooling` |
| performance-agent | `Claude Code; requires Bash + k6` |
| qe-agent | `Claude Code; requires Bash + curl + python3` |
| security-agent | `Claude Code; requires Bash + npm/pip/govulncheck` |

Plus workflow skills with external tool deps:

| Skill | Suggested value |
|---|---|
| mermaid-charts | `Claude Code; mmdc optional for rendering` |
| nano-banana | `Claude Code; requires Bash + Python 3 + GEMINI_API_KEY` |
| playwright | `Claude Code; requires Bash + Node/npm + Chromium + Linux install-deps` |
| plan-builder | `Claude Code; Write access for docs/plans/` |
| project-profiler | `Claude Code; Bash + Read + Write for repo-root and .claude/` |
| railway-deploy | `Claude Code; requires railway CLI + Docker` |
| render-sanity | `Claude Code; requires Playwright MCP tools` |

### I11. Missing Step 0: Read Contracts on role agents

| Skill | Location | Fix |
|---|---|---|
| code-review-agent | `SKILL.md:46-60` | Promote Step 2's contract-reading bullet to Step 0 matching other role agents |
| docs-agent | `SKILL.md:55` | Add `### 0. Read Contracts and Source` step before step 1 |

### I12. `owns.shared_read: ['*']` wildcard cleanup

Bulk audit + per-skill findings flag the `'*'` wildcard as overly broad in 7+ skills: `contract-auditor:12`, `contract-author:12`, `context-manager:12`, `git-commit:18`, `git-pr:19`, `git-pr-feedback:19`, `infrastructure-agent:12`, `mermaid-charts:22`, `qe-agent:12`. Replace with explicit directory lists OR keep as `['*']` only where genuinely needed (`git-pr-feedback` may legitimately read any file).

### I13. Empty `owns` block on workflow skills (noise)

Workflow skills carry agent-role `owns` block even when empty. Affected: `architecture-rescue:8-11`, `caveman:9-12`, `claude-design-brief:9-12`, `deployment-checklist:9-12`, `diagnose-loop:9-12`, `grill-me:8-11`. Either remove the block entirely OR keep for sibling consistency.

### I14. Other location-specific important findings (per-skill)

- **orchestrator** `SKILL.md:209-215` — Definition of Done numbering bug (9 + 9a then 10). Renumber.
- **orchestrator** `SKILL.md:194-196` — Orphan duplicate "Anti-Pattern" header below main table. Merge as a new row.
- **interactive-doc** `references/house-style.md` — 404 lines, no TOC. Add H2 TOC.
- **llm-wiki** `references/operations.md` — 253 lines, no TOC. Add H2 TOC.
- **llm-wiki** `SKILL.md:20` — `owns.patterns` are common filenames potentially conflicting with other projects. Tighten to `wiki/`-prefixed paths.
- **diagnose-loop** `SKILL.md:14` — `composes_with` missing `architecture-rescue` (referenced in body line 73).
- **frontend-agent** `references/validation-checklist.md:7,70` — duplicate `## Build Verification` heading.
- **infrastructure-agent** `SKILL.md:66-88` — process steps too terse; add 2-3 concrete sub-bullets per step 1-6.
- **deployment-checklist** `references/pre-deploy.md` — bash commands assume Python/npm split. Add stack-conditional sections.
- **dependency-coordinator** `references/known-conflict-deps.md:75, references/dependencies-md-template.md:47` — hardcoded "Bazaar gauntlet" project citations. Generalize.
- **dependency-coordinator** — broken external doc link `docs/qa/skill-ecosystem-audit-2026-04-30.md` (cited in 2 reference files).
- **claude-design-brief** `references/direction-examples/{safe,bold,experimental}.md:17-32` + `references/variation-and-risks.md:33` — "Sovereign Sampson" project naming + politically-scoped audience example. Anonymize.
- **interactive-doc** `references/architecture-map.md, references/concept-explainer.md` — hardcoded "Hive" worked examples. Add disclaimer or anonymize.
- **interactive-doc** `SKILL.md:164` — "thariq's site" reference without URL/context.
- **skill-explorer** `SKILL.md:30` — hardcoded "38 repo skills" is stale (now 47). Update to "47" or omit.
- **skill-review** `SKILL.md:6` — description references stale "100-line rule" (house style is 500 lines).
- **skill-update** `SKILL.md:100` — line-count guidance "~100 lines" stale (house style is 200/500).
- **skill-writer** `SKILL.md:14` — `composes_with` missing `skill-review` and `skill-update`.
- **skill-writer** `SKILL.md:31-37` — Skill Directory Structure shows `templates/` subdirectory not used by any skill.
- **maintain-context** `SKILL.md:13` — missing `setup-project-skills` from `composes_with` despite hard precondition.
- **railway-deploy** `SKILL.md:82` — "Optional: Procfile fallback" listed as a numbered step. Move out or mark optional aside.
- **plan-builder** `SKILL.md:32,108,110,121` — uses non-standard `<what-to-do>` / `<supporting-info>` XML-style section markers. Replace with H2 headings.
- **playwright** `SKILL.md:28-30,63-65` — Spot-Check Mode described twice. Merge.
- **setup-project-skills** `SKILL.md:6` — `disable-model-invocation: true` out-of-spec (covered in I5).
- **zoom-out** `SKILL.md:5` — same out-of-spec issue (covered in I5).
- **db-migration-agent** `SKILL.md:10 vs body:50` — `owns` missing `knex/migrations/` mentioned in body. Reconcile.
- **backend-agent / frontend-agent / many roles** — frontmatter field-order drift (`allowed-tools` after `owns` rather than before). Normalize.

---

## Nits (won't block; defer unless a fix wave is already touching the file)

160 nits captured in `audit/reports/*.json`. Categories:

- Metadata blocks missing (`metadata.author/category/tags`) on all 10 role agents — purely catalog discovery, defer.
- `mattpocock` attribution lacks URL in caveman, architecture-rescue, diagnose-loop — add URL.
- `>` folded vs `|` block YAML scalar style on git/ skills — stylistic, defer.
- Right-sizing tradeoff blockquote missing on observability-agent, security-agent, code-review-agent, db-migration-agent, performance-agent, docs-agent — add when touching file.
- `[brackets]` vs `${PLACEHOLDER}` template convention mismatch in code-review-agent + security-agent reports.
- Various TOC additions on long references (operations.md, feedback-loop-recipes.md, house-style.md).
- `nano-banana` `references/imagen-4-prompting.md` naming confusion (Imagen vs Nano Banana).
- `work-item-brief` AFK/HITL expansion on first use.

Full nit list in `/tmp/all_nits.txt` and per-skill JSON files.

---

## Fix Waves (for Phase D parallel execution)

Each wave touches **disjoint file sets** so agents can run in parallel without merge conflicts. Aim 30-60 minutes per wave.

### Wave 1 — Critical: oversize descriptions (HARD-FAIL fixes)

**Purpose:** unblock spec compliance. All seven skills cited in C1 + the two near-ceiling cases.

**Files touched (frontmatter description field only):**
- `skills/orchestrator/SKILL.md` (also add new `## Composition` body section)
- `skills/workflows/ui-brief/SKILL.md`
- `skills/workflows/interactive-doc/SKILL.md`
- `skills/workflows/render-sanity/SKILL.md`
- `skills/workflows/claude-design-brief/SKILL.md`
- `skills/meta/skill-explorer/SKILL.md` (near-ceiling tightening)
- `skills/workflows/settings-consolidator/SKILL.md` (near-ceiling tightening)

**Agent prompt template:**
> Read `audit/MASTER_AUDIT_PLAN.md` §C1. For each listed skill, open its SKILL.md, compress the YAML `description:` field to ≤1024 chars (target ≤800 for new ceiling-headroom). Move any enumeration that doesn't belong in the trigger field to a new body section (`## Composition` for orchestrator, `## When to use which` for claude-design-brief). Verify with `awk` that the new char count is under 1024. Bump patch version. Do not change body content other than the noted additions.

### Wave 2 — Critical: cross-reference cleanup (broken refs + stale archive refs)

**Purpose:** fix the 5 broken composes_with entries (C2) + the 4 skills with body-level archive-skill routing (C3) + the C6/C7/C8 plugin-namespace decisions.

**Files touched:**
- `skills/git/git-commit/SKILL.md` (composes_with)
- `skills/meta/skill-explorer/SKILL.md` (composes_with + body L131, L144)
- `skills/meta/skill-update/SKILL.md` (5 instances at L5,24,29,33,45) + `references/plan-format.md`
- `skills/workflows/sync-skills/SKILL.md` (composes_with L14)
- `skills/workflows/claude-design-brief/SKILL.md:120` (drop SovereignSampson path)
- `skills/workflows/render-sanity/SKILL.md:14-15` (decide: remove or namespace plugin refs)
- `skills/workflows/ui-brief/SKILL.md:14` (decide: remove or namespace plugin refs)

**Agent prompt template:**
> Read `audit/MASTER_AUDIT_PLAN.md` §C2, §C3, §C6, §C7, §C8. Replace each archived-skill reference per the table. For plugin-only refs in render-sanity and ui-brief, decide based on policy: either drop or qualify with plugin namespace (recommendation: keep them in `composes_with` with `superpowers:` prefix for consistency with orchestrator's `claude-mem:*` pattern; if going this route, also do Wave 6's spec update first).

### Wave 3 — Critical: frontmatter normalization (missing required fields + portability)

**Purpose:** make dependency-coordinator and interactive-doc spec-compliant (C4); fix the two hardcoded `.env` portability bugs (C5).

**Files touched:**
- `skills/workflows/dependency-coordinator/SKILL.md` (full frontmatter rebuild)
- `skills/workflows/interactive-doc/SKILL.md` (add 4 missing standard fields)
- `skills/workflows/nano-banana/SKILL.md:47`
- `skills/workflows/railway-deploy/SKILL.md:33`

**Agent prompt template:**
> Read `audit/MASTER_AUDIT_PLAN.md` §C4 and §C5. For dependency-coordinator: add `composes_with: [contract-author, infrastructure-agent, contract-auditor, orchestrator]`, `spawned_by: [orchestrator]`, `allowed-tools: [Read, Write, Edit, Bash, Glob]`, `requires_claude_code: true`; remove non-spec `disable-model-invocation` and `type: contract` (or move intent to description body). For interactive-doc: add `allowed-tools`, `requires_claude_code`, `composes_with`, `metadata.category: workflows`. For nano-banana + railway-deploy: rephrase hardcoded `Skill Madness root .env` to `current project repo-root .env` + document the lookup chain. Bump patch versions.

### Wave 4 — Important: role-agent template bleed + Step 0 + compatibility fields

**Purpose:** clean up self-referential pipeline blockquote (I4), add missing `Step 0: Read Contracts` (I11), add `compatibility:` strings (I10) — all role agents at once.

**Files touched (one per role agent; fully disjoint):**
- `skills/roles/backend-agent/SKILL.md`
- `skills/roles/code-review-agent/SKILL.md` (+ L141 underscore-to-hyphen `allowed_tools` fix)
- `skills/roles/db-migration-agent/SKILL.md` (+ link `validation-checklist.md` from body L116)
- `skills/roles/docs-agent/SKILL.md` (+ add Step 0)
- `skills/roles/frontend-agent/SKILL.md`
- `skills/roles/infrastructure-agent/SKILL.md`
- `skills/roles/observability-agent/SKILL.md`
- `skills/roles/performance-agent/SKILL.md`
- `skills/roles/qe-agent/SKILL.md`
- `skills/roles/security-agent/SKILL.md`

**Agent prompt template:**
> Read `audit/MASTER_AUDIT_PLAN.md` §I4, §I10, §I11. For each role agent: (1) reword the self-referential pipeline blockquote at the cited line per the per-agent table; (2) add `compatibility:` field per the suggested value; (3) for code-review-agent and docs-agent only: add `Step 0: Read Contracts and Source` and fix the `allowed_tools` underscore. Each agent edits ONE file — fully parallel-safe.

### Wave 5 — Important: description tightening + project-portability cleanups

**Purpose:** trim long descriptions on healthy skills (I3 long tail) and fix hardcoded "AllTheSkills" + hardcoded endpoints (I8, I9).

**Files touched:**
- 20+ SKILL.md description fields (all in I3 table)
- `skills/roles/qe-agent/references/validation-checklist.md`
- `skills/roles/performance-agent/references/k6-patterns.md`
- `skills/roles/docs-agent/references/doc-templates.md`
- `skills/workflows/ui-brief/SKILL.md:183`
- `skills/workflows/repo-deep-dive/references/document-template.md:167,170`
- `skills/workflows/dependency-coordinator/references/known-conflict-deps.md:75`
- `skills/workflows/dependency-coordinator/references/dependencies-md-template.md:47`
- `skills/workflows/claude-design-brief/references/direction-examples/*.md`
- `skills/workflows/claude-design-brief/references/variation-and-risks.md:33`
- `skills/workflows/interactive-doc/references/architecture-map.md`
- `skills/workflows/interactive-doc/references/concept-explainer.md`

**Agent prompt template:**
> Read §I3, §I8, §I9. For each skill in §I3 table, trim YAML `description:` per the listed suggestion (target 200-400 chars; keep the strongest trigger phrases). For §I8: replace project-specific endpoints with `${RESOURCE_PATH}` placeholders. For §I9: replace "AllTheSkills" with "Skill Madness" or `{reference-project}` placeholder. Anonymize the political/project-named examples per §I14 (Sovereign Sampson, Hive, thariq).

### Wave 6 — Important: ecosystem spec + docs sync

**Purpose:** update `frontmatter-spec.md` to legitimize `disable-model-invocation` + `argument-hint` + `plugin_external` (or `composes_with_external`) conventions (I1, I5); sync CLAUDE.md (I2).

**Files touched:**
- `skills/meta/skill-writer/references/frontmatter-spec.md`
- `CLAUDE.md` (workflow count `25 → 26`, add render-sanity, optionally regenerate catalog)
- `README.md` (verify skill counts match)

**Agent prompt template:**
> Read §I1, §I2, §I5. Update `references/frontmatter-spec.md` to add three sections: (1) `disable-model-invocation` field semantics + when to use; (2) `argument-hint` field semantics; (3) plugin-external reference convention (recommended: keep refs in `composes_with` but use `plugin-name:skill-name` namespace, matching the existing `claude-mem:*` pattern in orchestrator). Update CLAUDE.md: change workflows count to 26 and add `render-sanity` to the workflows enumeration line. Verify with `ls skills/workflows | wc -l` matches the new count.

### Wave 7 (optional polish) — Nit batches

Group nits by file proximity to fix opportunistically. Recommended: skip unless time permits. Worthwhile picks:
- Add metadata blocks to all 10 role agents (catalog discovery).
- Add right-sizing tradeoff blockquote to 6 role agents.
- Standardize `[brackets]` → `${PLACEHOLDER}` in code-review-agent + security-agent templates.
- Add URLs to mattpocock attributions.

---

## Out of Scope (deferred to a future cycle)

- Major content rewrites — no skill scored below 3.0; no skill needs MAJOR REWORK.
- Reorganizing skill categories — current `orchestrator / contracts / meta / git / roles / workflows` is working.
- Splitting overweight skills — largest body is 219 lines (`contract-author`); none over the 500-line soft warning.
- Promoting nits to important — defer 160 nits unless a wave already touches the file.
- Adding `evals/evals.json` (interactive-doc has a great example) as a house-style convention across skills — this is its own initiative.
- Verifying every `spawned_by` reciprocity (e.g., wiki-research lists 8 spawners; check each actually mentions wiki-research) — defer to a dedicated bidirectional-link audit.
- `disable-model-invocation` → `metadata.invocation` migration (option 2 in §I5) — defer; option 1 (document in spec) is lower-risk this pass.

---

## Top 20 Skills Ranked by Audit Score (worst-to-best, for prioritization)

| Rank | Skill | Avg | Verdict | Worst dimension(s) |
|---|---|---|---|---|
| 1 | render-sanity | 3.00 | NEEDS WORK | frontmatter (2), description (2), progressive_disclosure (2), coordination (2) |
| 2 | ui-brief | 3.29 | NEEDS WORK | description (1), coordination (2), frontmatter (3) |
| 3 | interactive-doc | 3.40 | NEEDS WORK | frontmatter (2), coordination (2), progressive_disclosure (3) |
| 4 | claude-design-brief | 3.60 | NEEDS WORK | frontmatter (2), completeness (3), anti_patterns (3) |
| 5 | skill-explorer | 3.71 | NEEDS WORK | coordination (2 — archived refs), frontmatter (3), description (3) |
| 6 | skill-update | 3.86 | NEEDS WORK | description (2 — stale skill names), frontmatter (3) |
| 6 | orchestrator | 3.86 | NEEDS WORK | frontmatter (2 — desc over ceiling), description (3) |
| 8 | dependency-coordinator | 3.90 | NEEDS WORK | frontmatter (3), description (3), coordination (3) |
| 9 | railway-deploy | 4.14 | NEEDS WORK | anti_patterns (2 — hardcoded .env), description (4), instruction (4), progressive (4) |
| 9 | sync-skills | 4.14 | NEEDS WORK | coordination (2 — broken refs), frontmatter (3), progressive (4) |
| 11 | db-migration-agent | 4.30 | SHIP | description (3), completeness (4), anti_patterns (4) |
| 12 | backend-agent | 4.40 | SHIP | description (3), anti_patterns (4) |
| 12 | code-review-agent | 4.40 | SHIP | description (3), anti_patterns (4) |
| 12 | docs-agent | 4.40 | SHIP | description (3), instruction (4) |
| 12 | frontend-agent | 4.40 | SHIP | description (3), anti_patterns (4) |
| 12 | infrastructure-agent | 4.40 | SHIP | description (3), instruction (4) |
| 12 | performance-agent | 4.40 | SHIP | description (3), anti_patterns (4) |
| 18 | git-commit | 4.43 | NEEDS WORK | coordination (2 — archived ref), anti_patterns (5) |
| 19 | zoom-out | 4.57 | NEEDS WORK | frontmatter (4), instruction (4), completeness (4) |
| 20 | observability-agent | 4.60 | SHIP | description (3) |
| 20 | security-agent | 4.60 | SHIP | description (3) |
| 20 | architecture-rescue | 4.60 | SHIP | description (4), coordination (4) |
| 20 | deployment-checklist | 4.60 | SHIP | completeness (4), anti_patterns (4) |

**Perfect-score skills (5.00):** git-post-merge-cleanup, git-pr-feedback, project-profiler, repo-deep-dive, work-item-brief.

---

## Source artifacts

- Bulk audit: `audit/reports/00-bulk-audit.{md,json}`
- Per-skill audits: `audit/reports/{skill}.{md,json}` × 47
- Extracted findings (for diffing): `/tmp/all_critical.txt`, `/tmp/all_important.txt`, `/tmp/all_nits.txt`, `/tmp/all_top_fixes.txt`, `/tmp/all_broken_refs.txt`

**Next phase:** Phase D — dispatch Wave 1-6 in parallel against disjoint file sets, gated on each wave passing `lint --frontmatter` + manual diff review.
