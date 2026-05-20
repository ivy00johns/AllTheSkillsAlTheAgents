# Ecosystem-Wide Bulk Audit (Mode A)

**Scanned:** 2026-05-20  
**Skills:** 47 active (archive excluded)  
**Method:** Cross-cutting comparison against frontmatter spec, CLAUDE.md, file-ownership.md, and per-skill deep-dive reports.

Per-skill deep-dives live in `audit/reports/{skill}.{md,json}` — this file covers issues that can only be found by comparing skills against each other.

---

## 1. Inventory (47 skills)

| Skill | Category | Version | Desc | Body lines | Refs | allowed-tools | requires_* | composes |
|---|---|---|---:|---:|---:|:-:|:-:|---:|
| `contract-auditor` | contracts | 1.1.0 | 201 | 163 | 1 | Y | Y | 4 |
| `contract-author` | contracts | 1.3.0 | 984 | 219 | 6 | Y | Y | 4 |
| `git-commit` | git | 1.2.0 | 502 | 99 | 0 | Y | Y | 2 |
| `git-post-merge-cleanup` | git | 1.0.0 | 959 | 171 | 2 | Y | Y | 2 |
| `git-pr` | git | 1.2.0 | 553 | 114 | 0 | Y | Y | 2 |
| `git-pr-feedback` | git | 1.2.0 | 554 | 172 | 0 | Y | Y | 2 |
| `skill-explorer` | meta | 1.0.0 | 1024 | 136 | 1 | Y | Y | 3 |
| `skill-review` | meta | 1.1.0 | 586 | 126 | 3 | Y | Y | 2 |
| `skill-update` | meta | 1.1.0 | 596 | 126 | 2 | Y | Y | 3 |
| `skill-writer` | meta | 1.2.0 | 377 | 115 | 2 | Y | Y | 2 |
| `orchestrator` | orchestrator | 1.8.0 | 1445 | 203 | 9 | Y | Y | 46 |
| `backend-agent` | roles | 1.1.0 | 177 | 147 | 1 | Y | Y | 6 |
| `code-review-agent` | roles | 1.2.0 | 210 | 134 | 1 | Y | Y | 5 |
| `db-migration-agent` | roles | 1.1.0 | 193 | 110 | 2 | Y | Y | 3 |
| `docs-agent` | roles | 1.1.0 | 192 | 98 | 1 | Y | Y | 5 |
| `frontend-agent` | roles | 1.2.0 | 208 | 143 | 1 | Y | Y | 8 |
| `infrastructure-agent` | roles | 1.1.0 | 201 | 86 | 1 | Y | Y | 5 |
| `observability-agent` | roles | 1.1.0 | 176 | 114 | 1 | Y | Y | 3 |
| `performance-agent` | roles | 1.2.0 | 192 | 120 | 1 | Y | Y | 3 |
| `qe-agent` | roles | 1.3.0 | 232 | 107 | 5 | Y | Y | 7 |
| `security-agent` | roles | 1.1.0 | 232 | 136 | 1 | Y | Y | 5 |
| `architecture-rescue` | workflows | 1.0.0 | 747 | 51 | 2 | Y | Y | 3 |
| `caveman` | workflows | 1.0.0 | 629 | 43 | 0 | Y | Y | 0 |
| `claude-design-brief` | workflows | 1.3.0 | 1191 | 104 | 6 | Y | Y | 4 |
| `context-manager` | workflows | 1.1.0 | 481 | 90 | 1 | Y | Y | 1 |
| `dependency-coordinator` | workflows | 1.0.0 | 238 | 103 | 3 | - | - | 0 |
| `deployment-checklist` | workflows | 1.1.0 | 416 | 60 | 1 | Y | Y | 4 |
| `diagnose-loop` | workflows | 1.0.0 | 603 | 68 | 2 | Y | Y | 2 |
| `grill-me` | workflows | 1.0.0 | 656 | 12 | 0 | Y | Y | 3 |
| `interactive-doc` | workflows | 1.0.0 | 1416 | 180 | 5 | - | - | 0 |
| `llm-wiki` | workflows | 1.1.0 | 846 | 177 | 2 | Y | Y | 4 |
| `maintain-context` | workflows | 1.1.0 | 717 | 74 | 3 | Y | Y | 2 |
| `mermaid-charts` | workflows | 2.3.0 | 954 | 71 | 4 | Y | Y | 9 |
| `nano-banana` | workflows | 1.2.0 | 615 | 114 | 2 | Y | Y | 2 |
| `plan-builder` | workflows | 1.3.0 | 673 | 105 | 2 | Y | Y | 4 |
| `playwright` | workflows | 1.2.0 | 616 | 68 | 3 | Y | Y | 3 |
| `project-profiler` | workflows | 1.1.0 | 483 | 107 | 1 | Y | Y | 3 |
| `railway-deploy` | workflows | 1.2.0 | 586 | 71 | 3 | Y | Y | 2 |
| `render-sanity` | workflows | 1.0.0 | 1388 | 201 | 0 | Y | Y | 6 |
| `repo-deep-dive` | workflows | 1.2.0 | 745 | 72 | 3 | Y | Y | 5 |
| `settings-consolidator` | workflows | 1.2.0 | 928 | 91 | 3 | Y | Y | 1 |
| `setup-project-skills` | workflows | 1.0.0 | 685 | 108 | 1 | Y | Y | 2 |
| `sync-skills` | workflows | 2.0.0 | 544 | 120 | 0 | Y | Y | 2 |
| `ui-brief` | workflows | 1.0.0 | 1443 | 170 | 1 | Y | Y | 7 |
| `wiki-research` | workflows | 2.1.0 | 902 | 146 | 0 | Y | Y | 3 |
| `work-item-brief` | workflows | 1.0.0 | 631 | 76 | 3 | Y | Y | 3 |
| `zoom-out` | workflows | 1.0.0 | 394 | 8 | 0 | Y | Y | 1 |

## 2. Ownership Conflicts

**No real ownership conflicts found.** All declared `owns.directories` and `owns.patterns` are unique across skills, and the resolved-conflicts table in `frontmatter-spec.md` covers the historical overlaps (CLAUDE.md → project-profiler, README.md → docs-agent, contracts/ → contract-author, .claude/handoffs/ → context-manager, tests/performance/ → performance-agent).

## 3. Broken Cross-Skill Refs

Refs in `composes_with` / `spawned_by` that don't resolve to a SKILL.md inside this repo.

### 3a. Refs to in-repo skills that no longer exist (REAL BUGS)

These should be fixed — they reference skill names that don't exist in `skills/` or in `skills/archive/`.

| Skill | Field | Broken ref | Probable intent |
|---|---|---|---|
| `git-commit` | composes_with | `git-branch-cleanup` | should be `git-post-merge-cleanup` |
| `skill-explorer` | composes_with | `skill-audit` | should be `skill-review` |
| `skill-explorer` | composes_with | `skill-deep-review` | should be `skill-review` |
| `sync-skills` | composes_with | `skill-updater` | should be `skill-update` |
| `sync-skills` | composes_with | `skill-audit` | should be `skill-review` |

### 3b. Refs to plugin-only skills not in this repo (informational; not bugs unless plugin is uninstalled)

Refs that resolve to skills shipped by other Claude Code plugins (e.g. `superpowers`, `frontend-design`, `claude-mem`, plugin:playwright). They load when the user has the plugin installed. `skill-review` may still flag them since they are unverifiable from this repo alone.

| Skill | Field | Plugin-only ref |
|---|---|---|
| `orchestrator` | composes_with | `brainstorming` |
| `orchestrator` | composes_with | `writing-plans` |
| `orchestrator` | composes_with | `frontend-design` |
| `orchestrator` | composes_with | `ui-ux-pro-max` |
| `orchestrator` | composes_with | `ux-review` |
| `orchestrator` | composes_with | `claude-api` |
| `orchestrator` | composes_with | `feature-dev` |
| `orchestrator` | composes_with | `claude-mem:mem-search` |
| `orchestrator` | composes_with | `claude-mem:timeline-report` |
| `orchestrator` | composes_with | `claude-mem:knowledge-agent` |
| `orchestrator` | composes_with | `loop` |
| `orchestrator` | composes_with | `schedule` |
| `frontend-agent` | composes_with | `frontend-design` |
| `frontend-agent` | composes_with | `ui-ux-pro-max` |
| `claude-design-brief` | composes_with | `ui-ux-pro-max` |
| `claude-design-brief` | composes_with | `frontend-design` |
| `claude-design-brief` | composes_with | `brainstorming` |
| `render-sanity` | composes_with | `ux-review` |
| `render-sanity` | composes_with | `feature-dev` |
| `render-sanity` | spawned_by | `ux-review` |
| `ui-brief` | composes_with | `ui-ux-pro-max` |
| `ui-brief` | composes_with | `frontend-design` |
| `ui-brief` | composes_with | `ux-review` |
| `ui-brief` | composes_with | `brainstorming` |

## 4. Coverage Gaps

### 4a. Skills present in CLAUDE.md but missing from `skills/`

None. The only match in the heuristic scan was `allowed-tools`, which is a frontmatter field name surfaced from CLAUDE.md prose — not a missing skill.

### 4b. Skills referenced by orchestrator's `file-ownership.md` but missing from `skills/`

None. `multi-agent` is a phrase from the doc text matched by the agent-name regex; not a skill.

### 4c. Skills implemented in `skills/` but missing from CLAUDE.md

CLAUDE.md enumerates the workflows category by listing names but the heuristic flagged the following as not enumerated. Confirmed by reading CLAUDE.md:

- The **roles/** category is summarised as a count + parenthetical list (`backend, frontend, infrastructure, qe, security, performance, observability, docs, db-migration, code-review`) — those are present, just not as backticked tokens. Not a real gap.
- The **meta/** category lists `skill-writer, skill-review, skill-update, skill-explorer` — present, not backticked.
- The **git/** category lists `git-commit, git-pr, git-pr-feedback, git-post-merge-cleanup` — present, not backticked.
- The **contracts/** category lists `contract-author` and `contract-auditor` — present, not backticked.
- **`render-sanity`** is NOT listed in CLAUDE.md's `skills/workflows/` enumeration. This is a real doc gap — recently promoted from in-progress and never added to the category roster.
- **`playwright`** appears in the workflows count but the comma-separated roster is missing it depending on how you read the sentence; verify it's explicitly named.
- **`orchestrator`** is documented as its own top-level section (`skills/orchestrator/`) so not missing.

**Documented count vs actual count drift:**

| Category | CLAUDE.md says | Actual |
|---|---:|---:|
| orchestrator | 1 | 1 |
| roles | 10 | 10 |
| contracts | 2 | 2 |
| meta | 4 | 4 |
| git | 4 | 4 |
| workflows | 25 | 26 |
| **Total** | **46** | **47** |

The repo has **47** active skills; CLAUDE.md sums to **46**. Off by one — most likely because `render-sanity` was added without bumping the workflows count.

## 5. Frontmatter Spec Drift

| Check | Count | Skills |
|---|---:|---|
| Uses `allowed_tools` (underscore) instead of `allowed-tools` | 0 | — |
| Missing top-level `version` | 0 | — |
| Missing ALL of `requires_agent_teams`, `requires_claude_code`, `min_plan` | 2 | dependency-coordinator, interactive-doc |
| Reserved `claude-*` / `anthropic-*` name prefix | 1 | claude-design-brief |

### Non-spec frontmatter fields in use

Fields not enumerated in `frontmatter-spec.md`. Some may be intentional (e.g. `disable-model-invocation` is an Anthropic field for skills only meant to be invoked directly), others are drift.

| Field | Skills |
|---|---|
| `disable-model-invocation` (14) | contract-auditor, backend-agent, code-review-agent, db-migration-agent, docs-agent, frontend-agent, infrastructure-agent, observability-agent, performance-agent, qe-agent, security-agent, dependency-coordinator, setup-project-skills, zoom-out |
| `argument-hint` (1) | skill-review |
| `type` (1) | dependency-coordinator |

**Notes:**
- `disable-model-invocation: true` is used by 14 role/utility skills that are intentionally not auto-invokable. This is a legitimate Anthropic spec field — `frontmatter-spec.md` should add it.
- `argument-hint` on `skill-review` is an Anthropic slash-command convention; legitimate but undocumented.
- `type` on `dependency-coordinator` is non-standard — likely drift.
- `claude-design-brief` uses the reserved prefix; documented exception per spec (targets the Claude Design canvas product).

## 6. Description Length Distribution

Anthropic ceiling: **1024 chars**. Soft target: **≤200 chars**.

### Over the 1024-char hard ceiling (HARD FAIL)

| Skill | Chars | Over by |
|---|---:|---:|
| `orchestrator` | 1445 | +421 |
| `ui-brief` | 1443 | +419 |
| `interactive-doc` | 1416 | +392 |
| `render-sanity` | 1388 | +364 |
| `claude-design-brief` | 1191 | +167 |

All 5 known fails confirmed. **No additional hard fails.** `skill-explorer` is exactly at 1024 (right at the ceiling) — flag for monitoring.

### Full distribution (sorted desc)

| Skill | Chars |
|---|---:|
| `orchestrator` | 1445 HARD FAIL |
| `ui-brief` | 1443 HARD FAIL |
| `interactive-doc` | 1416 HARD FAIL |
| `render-sanity` | 1388 HARD FAIL |
| `claude-design-brief` | 1191 HARD FAIL |
| `skill-explorer` | 1024 at ceiling |
| `contract-author` | 984 |
| `git-post-merge-cleanup` | 959 |
| `mermaid-charts` | 954 |
| `settings-consolidator` | 928 |
| `wiki-research` | 902 |
| `llm-wiki` | 846 |
| `architecture-rescue` | 747 |
| `repo-deep-dive` | 745 |
| `maintain-context` | 717 |
| `setup-project-skills` | 685 |
| `plan-builder` | 673 |
| `grill-me` | 656 |
| `work-item-brief` | 631 |
| `caveman` | 629 |
| `playwright` | 616 |
| `nano-banana` | 615 |
| `diagnose-loop` | 603 |
| `skill-update` | 596 |
| `skill-review` | 586 |
| `railway-deploy` | 586 |
| `git-pr-feedback` | 554 |
| `git-pr` | 553 |
| `sync-skills` | 544 |
| `git-commit` | 502 |
| `project-profiler` | 483 |
| `context-manager` | 481 |
| `deployment-checklist` | 416 |
| `zoom-out` | 394 |
| `skill-writer` | 377 |
| `dependency-coordinator` | 238 |
| `qe-agent` | 232 |
| `security-agent` | 232 |
| `code-review-agent` | 210 |
| `frontend-agent` | 208 |
| `contract-auditor` | 201 |
| `infrastructure-agent` | 201 |
| `db-migration-agent` | 193 |
| `docs-agent` | 192 |
| `performance-agent` | 192 |
| `backend-agent` | 177 |
| `observability-agent` | 176 |

## 7. Body-Length Outliers

Anthropic guideline: **≤5,000 words**. This repo's soft warning: **≥500 lines OR ≥5,000 words**.

**No skills exceed the 500-line or 5000-word thresholds.** Heaviest body is `contract-author` at 219 lines / 1,509 words.

### Top 10 by line count

| Skill | Lines | Words |
|---|---:|---:|
| `contract-author` | 219 | 1509 |
| `orchestrator` | 203 | 3057 |
| `render-sanity` | 201 | 2625 |
| `interactive-doc` | 180 | 1828 |
| `llm-wiki` | 177 | 1088 |
| `git-pr-feedback` | 172 | 904 |
| `git-post-merge-cleanup` | 171 | 881 |
| `ui-brief` | 170 | 2329 |
| `contract-auditor` | 163 | 1055 |
| `backend-agent` | 147 | 1072 |

## 8. Overlapping Trigger Contexts

Pairs of skills whose descriptions reference the same trigger keyword. Some are real overlap (users may pick the wrong skill); others are intentional cross-coordination signals (orchestrator naturally overlaps with everything it spawns).

### Real overlap (review for disambiguation)

| Skill A | Skill B | Shared concept | Disambiguation needed? |
|---|---|---|---|
| `claude-design-brief` | `ui-brief` | design brief / redesign | YES — both produce briefs. claude-design-brief = short prompt for Claude Design canvas; ui-brief = long Markdown spec for Claude Code build. Disambiguation already exists in both descriptions but easy to confuse. |
| `skill-writer` | `skill-update` | create / improve skill | YES — skill-writer creates new, skill-update modifies existing. Already disambiguated in descriptions but adjacent. |
| `skill-writer` | `skill-review` | skill quality | PARTIAL — review audits, writer creates. Low confusion risk. |
| `skill-review` | `skill-update` | audit / improve | YES — review reports, update fixes. Already coupled (review outputs feed update). |
| `interactive-doc` | `llm-wiki` | wiki / knowledge base | YES — interactive-doc produces single HTML+MD pair; llm-wiki produces persistent multi-doc vault. Different scopes. |
| `interactive-doc` | `wiki-research` | wiki / research artifact | PARTIAL — interactive-doc renders existing research, wiki-research conducts deep research. Sequential, not competing. |
| `llm-wiki` | `wiki-research` | wiki / second brain | PARTIAL — llm-wiki maintains, wiki-research generates one-shot research. Disambiguation in descriptions. |
| `playwright` | `render-sanity` | browser / frontend check | YES — playwright = general browser automation/testing; render-sanity = quick visual sanity check post-build. Worth tightening render-sanity to say 'lightweight visual sanity' explicitly. |

### Coordination overlap (intentional)

The `orchestrator` description naturally overlaps with `frontend-agent`, `playwright`, `ui-brief`, `render-sanity`, `wiki-research`, `llm-wiki`, `interactive-doc`, `mermaid-charts` etc — because it explicitly enumerates which skills it composes with. This is by design, not drift.

Total keyword-pair overlaps detected: **38**. Most are orchestrator-with-spawned-skill or frontend-cluster (frontend-agent + playwright + render-sanity + ui-brief + claude-design-brief). The 8 in the table above are the ones worth disambiguating.

## 9. Dead References

Files in a skill's `references/` directory that are not linked from its SKILL.md body.

| Skill | Unlinked references |
|---|---|
| `db-migration-agent` | `validation-checklist.md` |
| `claude-design-brief` | `direction-examples` |
| `mermaid-charts` | `chart-types` |
| `setup-project-skills` | `templates` |

**Notes:**
- `db-migration-agent/references/validation-checklist.md` — file exists but never linked from SKILL.md body. Likely orphan after a refactor.
- `claude-design-brief/references/direction-examples` — appears to be a subdirectory, not a file. Verify whether SKILL.md links into it.
- `mermaid-charts/references/chart-types` — subdirectory of per-chart-type reference files. Verify SKILL.md references the directory or individual files.
- `setup-project-skills/references/templates` — subdirectory of templates. Verify linkage.

## 10. Stale Archive Cross-Refs

References to skills that have been moved to `skills/archive/` or never existed under the cited name.

| Skill | Stale ref | Where | Correct target |
|---|---|---|---|
| `git-commit` | `git-branch-cleanup` | skills/.../git-commit/SKILL.md | should be `git-post-merge-cleanup` |
| `skill-update` | `skill-audit` | skills/.../skill-update/SKILL.md | should be `skill-review` |
| `skill-update` | `skill-deep-review` | skills/.../skill-update/SKILL.md | should be `skill-review` |
| `skill-explorer` | `skill-audit` | skills/.../skill-explorer/SKILL.md | should be `skill-review` |
| `skill-explorer` | `skill-deep-review` | skills/.../skill-explorer/SKILL.md | should be `skill-review` |
| `sync-skills` | `skill-audit` | skills/.../sync-skills/SKILL.md | should be `skill-review` |
| `sync-skills` | `skill-updater` | skills/.../sync-skills/SKILL.md | should be `skill-update` |
| `skill-update` | `skill-audit` | skills/meta/skill-update/references/plan-format.md | should be `skill-review` |

**Confirmed all 3 known stale-ref skills (`skill-update`, `skill-explorer`, `git-commit`) PLUS additional finding:**

- **`sync-skills`** references both `skill-updater` and `skill-audit` (already known in task description but worth re-flagging).
- **`skill-update/references/plan-format.md`** also contains a `skill-audit` reference — fix in the reference file, not just the SKILL.md body.
- `skill-deep-review` is referenced by both `skill-update` and `skill-explorer` (and likely should be `skill-review` in both).

---

## Summary

**Critical issues (block readers, point at nonexistent skills, fail spec):** 17
- 5 broken in-repo cross-refs (point at nonexistent skill names)
- 5 descriptions over the 1024-char hard ceiling
- 7 stale archive references in SKILL.md bodies / refs

**Important issues (drift, gaps, polish):** 42
- 24 unverifiable plugin-only refs in composes_with
- 2 skills missing all `requires_*` / `min_plan` runtime gating fields
- 3 non-spec frontmatter field types in use (mostly `disable-model-invocation` which spec should adopt)
- 4 unlinked `references/` files (potential orphans)
- 1 CLAUDE.md count drift (workflows says 25, actual 26 — `render-sanity` not enumerated)
- 8 description-trigger overlaps worth disambiguating
