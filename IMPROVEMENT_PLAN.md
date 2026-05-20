# Skill Ecosystem Improvement Plan

**Date:** 2026-05-19
**Status:** Draft — under review
**Owner:** @ivy00johns

## Sources

1. **`claude_notes.txt`** — Twitter post by @sairahul1, "20 Claude Skills Most Builders Don't Know Exist." Five categories: Content & Writing, Research & Analysis, Business & Ops, Coding & Dev, Strategy & Thinking. Each "skill" is a single-prompt template with frontmatter — no references, no scripts, no validation. Useful as a *pattern catalog*, not as importable skills.
2. **Anthropic, "The Complete Guide to Building Skills for Claude"** — 32-page PDF, published with Agent Skills as an open standard. Six chapters: Introduction, Fundamentals, Planning & Design, Testing & Iteration, Distribution & Sharing, Patterns & Troubleshooting, Resources. This is the **canonical Anthropic spec** — the repo's `frontmatter-spec.md` should align with it where the divergence isn't deliberate.

---

## Part 1: Adopt 3 thinking-moves from `claude_notes.txt`

### Rationale

Most of the 20 skills in the Twitter post are either out of scope (content/writing, business ops) or under-engineered versions of skills we already have (PR Reviewer, Debug Partner, Code Explainer — we cover these 5-10x better with `code-review`, `superpowers:systematic-debugging`, `diagnose-loop`, `git-pr-feedback`, etc.).

Three of their analysis skills name a *thinking discipline* this repo doesn't currently treat as a first-class move:

| Their skill | Thinking move | Why we don't have it |
|---|---|---|
| **Contradiction Finder (07)** | "Where do my sources disagree?" | `wiki-research` and `repo-deep-dive` gather but don't reconcile conflicts. |
| **Assumption Auditor (09)** | "Surface the invisible assumptions before launch." | `deployment-checklist` checks artifacts, not assumptions. `orchestrator` Phase 3 plans but doesn't audit. |
| **Second-Order Thinker (19)** | "Map the consequences of the consequences." | `superpowers:brainstorming` explores intent; `plan-builder` sequences work. Neither forces second/third-order analysis. |

These are not worth adding as standalone skills. They are worth adding as **named reference sections** inside existing skills so they can be invoked by name during the right phase.

### Changes

1. **`skills/workflows/wiki-research/references/`** — add `contradiction-finding.md`. Heuristics for surfacing disagreement across sources (surface consensus → 3 specific contradictions → weakest claim → real debate → confidence verdict). Reference it from the wiki-research SKILL.md body as a checklist step when synthesizing 3+ sources.

2. **`skills/workflows/deployment-checklist/references/`** — add `assumption-audit.md`. Pre-launch check that surfaces explicit + implicit assumptions + the single most-dangerous-if-wrong assumption + how to test each. Wire it into the deployment-checklist body as a required step before sign-off. Also reference it from `skills/orchestrator/references/phase-guide.md` at Phase 3 (design).

3. **`skills/workflows/plan-builder/references/`** — add `second-order-effects.md`. Maps 1st/2nd/3rd-order consequences + the unintended consequence + the feedback loop. Reference it from plan-builder's SKILL.md when the plan affects systems beyond 30 days. Also link from `superpowers:brainstorming` as an optional deepening move when the user is stuck on first-order framing.

### Out of scope

- **Content & writing (skills 01-05)** — Hook Forge, Voice Locker, Thread Architect, Repurpose Engine, Headline Lab. Wrong repo. This is a multi-agent dev toolkit, not a content-marketing toolkit. If wanted, they belong in a separate personal skill set.
- **Business & ops (skills 11-15)** — SOP Writer, Decision Framer, Meeting Extractor, Pricing Stress Tester, Offer Sharpener. Wrong repo.
- **Coding (skills 16-18)** — Code Explainer, PR Reviewer, Debug Partner. We have `code-review`, `review`, `git-pr-feedback`, `security-review`, `superpowers:systematic-debugging`, `diagnose-loop`, `simplify` and an entire `roles/code-review` agent. Our versions are richer.
- **Strategy (skill 20)** — Mental Model Applier. Too generic; "apply three mental models" without naming which is just a vibe, not a discipline.

---

## Part 2: Adopt patterns from Anthropic's official guide

The repo's `skills/meta/skill-writer/references/frontmatter-spec.md` is its own spec — opinionated and richer than Anthropic's in some places (ownership, runtime detection, plan-tier gating) but **divergent on field names and structure** in ways that may break cross-platform loading. `CLAUDE.md` explicitly states "skills should be platform-agnostic" — so divergence is a real cost, not a hypothetical one.

### A. Compliance gaps (must-fix if we want cross-platform loading)

These are places where Anthropic's spec differs and the divergence likely breaks Claude.ai / Agent SDK consumption of our skills.

| # | Issue | Anthropic | This repo | Recommendation |
|---|---|---|---|---|
| A1 | **`allowed-tools` field name** | hyphen: `allowed-tools` (PDF p.31) | underscore: `allowed_tools` | Add `allowed-tools` as the canonical form; keep `allowed_tools` as a deprecated alias for one release cycle. |
| A2 | **`metadata` nesting** | nested object with `author`, `version`, `mcp-server`, `category`, `tags` (p.11, p.31) | flat: `version` at top level, no `metadata` object | Move `version` (and any future author/category fields) under `metadata`. Top-level `version` stays valid for back-compat. |
| A3 | **`compatibility` field** | 1-500 chars; declares environment/platform requirements (p.11, p.19) | not in spec | Add it. Use it to capture `requires_claude_code` + `requires_agent_teams` + `min_plan` in a human-readable string. Keep boolean flags for programmatic checks. |
| A4 | **Forbidden frontmatter chars** | XML angle brackets `< >` forbidden; "claude" / "anthropic" name prefixes reserved (p.11, p.31) | not enforced | Add validation to `skill-review`: fail any skill with `<` or `>` in frontmatter, or `claude-*` / `anthropic-*` name. |
| A5 | **Description max length** | 1024 chars (p.10) | target ≤200 chars | Keep 200 as our *target* (forces tight triggers), but document 1024 as the hard ceiling. Some pushy descriptions in this repo already exceed 200; that's fine if they trigger reliably. |
| A6 | **SKILL.md body length** | "under 5,000 words" (p.27) | "<500 lines" in CLAUDE.md | Switch the rule to **5,000 words OR 500 lines, whichever comes first**. Word count is what actually drives context cost. |

### B. Worth-adopting additions

Net-new patterns from the Anthropic guide that would strengthen the repo without conflicting with existing structure.

| # | Pattern | Source | Action |
|---|---|---|---|
| B1 | **Recommended SKILL.md body structure** — `## Instructions` → `### Step N` → `## Examples` → `## Troubleshooting (Error / Cause / Solution)` (p.12) | Anthropic | Add as the default template in `skill-writer`. Many existing skills already follow this loosely; make it explicit. |
| B2 | **"Iterate on a single task before expanding"** (p.15) | Anthropic | Add to `skill-writer` and `skill-update` guidance: prototype against one real task, get it working, then extract to a skill. Prevents speculative skills. |
| B3 | **Triggering test format** — explicit "Should trigger" + "Should NOT trigger" lists (p.15) | Anthropic | Add to `skill-review` as a required output: every skill review must produce a triggering test list with at least 3 positives and 2 negatives. |
| B4 | **Performance comparison metric** — "with skill vs without skill" (token count, back-and-forth count, failed-call count) (p.16) | Anthropic | Add to `skill-review`'s deep-dive mode as an optional measurement. Hard to automate but valuable for high-traffic skills. |
| B5 | **The 5 emergent patterns** (Ch.5, p.21-24) — Sequential workflow, Multi-MCP coordination, Iterative refinement, Context-aware tool selection, Domain-specific intelligence | Anthropic | Add `skills/meta/skill-writer/references/patterns.md` cataloging all 5 with one-line "use when" + a pointer to an in-repo example. |
| B6 | **Quick Checklist (Reference A, p.30)** — before-start / during-development / before-upload / after-upload | Anthropic | Add as `skills/meta/skill-writer/references/quick-checklist.md`. Referenced from `skill-writer` body as the final step before declaring a skill done. |
| B7 | **Troubleshooting taxonomy** — Skill won't upload / doesn't trigger / triggers too often / instructions not followed / large context (p.25-27) | Anthropic | Add as `skills/meta/skill-explorer/references/troubleshooting.md`. Lets `skill-explorer` answer "why isn't my skill firing?" with named symptoms. |
| B8 | **"Add explicit encouragement" for model laziness** (p.26) — `## Performance Notes` block | Anthropic | Document as an optional pattern; add to `skill-writer` reference. Some of our long-running role agents could benefit. |
| B9 | **Programmatic validation script pattern** (p.26 "Advanced technique") — bundle a deterministic check script instead of relying on prose validation | Anthropic | Already partially done (contract-auditor). Document as a first-class pattern: `scripts/validate.{sh,py}` is the right home for invariants you can compute. |
| B10 | **Description anatomy: `[What] + [When] + [Key capabilities]`** (p.11) | Anthropic | Adopt explicitly in `frontmatter-spec.md`. The repo's current "pushy enumeration" advice doesn't name the three slots. |

### C. Strengths the repo has that Anthropic doesn't cover — no action

Context for the next reviewer: these are deliberate extensions, not omissions in the Anthropic guide we missed.

- **File ownership (`owns.directories`, `owns.patterns`, `owns.shared_read`)** — core to zero-conflict parallel multi-agent builds. Anthropic's guide assumes single-skill execution.
- **Two-runtime degradation** — Agent Teams → subagents → sequential. Orchestrator-specific.
- **QE-gated builds** with `qa-report.json` schema and blocker thresholds.
- **Symlink-based syncing** (`sync-skills`) — keeps repo and `~/.claude/skills/` in lockstep.
- **Plugin namespacing** (e.g., `superpowers:writing-plans`) — handles cross-plugin collisions.
- **Cross-platform tool mapping** (`references/copilot-tools.md`, `references/codex-tools.md`) — lets the same SKILL.md body work across hosts.
- **`spawned_by` / `composes_with`** — explicit composition graph.
- **`requires_agent_teams` / `requires_claude_code` / `min_plan`** booleans — programmatic gating Anthropic's `compatibility` string can't do.

### D. Explicit non-adoptions — divergence on purpose

- **No `version` field in `metadata` (we keep it top-level required)** — semver is too important to bury under `metadata`. We adopt B-A2 partially: `metadata.version` becomes valid, but top-level `version` stays the canonical form for this repo.
- **No `license` field per-skill** — repo-level LICENSE applies. Per-skill license is noise for an OSS bundle that ships as one unit.
- **Anthropic's "Single-prompt skill" pattern** — many of their examples are essentially fancy prompts (cf. claude_notes.txt). We deliberately set a higher bar: a skill earns its keep with references, scripts, or composition logic. Single-prompt skills should be slash commands or in-context prompts, not skills.

---

## Execution order

Phased so that compliance work lands before additive work, and so each phase can be a clean PR.

### Phase 1 — Spec alignment (1 PR)
- A1: add `allowed-tools` alias
- A2: nested `metadata` block accepted, top-level `version` retained
- A3: add `compatibility` field
- A4: add validation rules to `skill-review`
- A5–A6: update `frontmatter-spec.md` length rules
- B10: rewrite description guidance with the 3-slot anatomy

**Deliverable:** updated `skills/meta/skill-writer/references/frontmatter-spec.md` + `skill-review` validation rules.

### Phase 2 — Templates and references (1 PR)
- B1: default body template in `skill-writer`
- B5: `patterns.md` reference (5 patterns)
- B6: `quick-checklist.md` reference
- B7: `troubleshooting.md` reference in `skill-explorer`
- B8: `## Performance Notes` pattern doc
- B9: validation-script pattern doc

**Deliverable:** new reference files under `skills/meta/skill-writer/references/` and `skills/meta/skill-explorer/references/`.

### Phase 3 — Thinking moves (1 PR)
- Part 1: add `contradiction-finding.md` to `wiki-research`, `assumption-audit.md` to `deployment-checklist`, `second-order-effects.md` to `plan-builder`. Wire references from each parent SKILL.md.

**Deliverable:** 3 new reference files + 3 SKILL.md body edits.

### Phase 4 — Process changes (1 PR or just memory)
- B2: "iterate on one task first" — add to `skill-writer` body
- B3: triggering test format — add to `skill-review` required output
- B4: performance comparison — optional deep-dive output in `skill-review`

**Deliverable:** updated `skill-writer` and `skill-review` SKILL.md bodies.

### Phase 5 — Sweep (defer until phases 1-2 land)
- Audit existing 46 skills for compliance with new spec
- Fix any with `<` / `>` in frontmatter (A4)
- Move any out-of-template body sections to match B1
- Add missing Troubleshooting sections where applicable

**Deliverable:** sweep PR with per-skill diffs.

---

## Decisions (resolved 2026-05-19)

1. **`version` stays top-level, required.** Anthropic's nested `metadata.version` form is *accepted* as a valid alias by the spec, but our canonical form is top-level. Semver is too important to bury.
2. **Publish/share is the target.** Repo is already public. Skills must load correctly on Claude.ai web app, Claude Desktop, and Agent SDK — not just Claude Code. **Phase 1 (spec alignment) is mandatory and ships first.**
3. **Adopt both `compatibility` string AND `requires_*` booleans.** String for cross-platform spec parsers; booleans for the orchestrator's runtime checks.
4. **Accept the 5,000-word divergence for heavy skills.** Skills like `orchestrator`, `ui-ux-pro-max`, `repo-deep-dive` earn the length. Rule becomes guidance, not gate: "aim for under 5,000 words; references for the rest." No forced splits.

---

## Not adopted from `claude_notes.txt`

For the record, so future-us doesn't relitigate:

- **All 5 content/writing skills** — out of repo scope.
- **All 5 business/ops skills** — out of repo scope.
- **3 coding skills** (Code Explainer, PR Reviewer, Debug Partner) — already covered more deeply.
- **Source Ranker (10)** — `wiki-research` covers source quality; not worth a separate move.
- **Signal Scanner (08)** — too domain-specific (industry-news triage).
- **Brief Builder (06)** — overlaps with `plan-builder` and `superpowers:writing-plans`.
- **Mental Model Applier (20)** — too generic to encode.
