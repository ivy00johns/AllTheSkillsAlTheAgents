---
name: skill-review
version: 1.2.0
argument-hint: skill-name or 'all'
description: |
  Review skills for quality, consistency, triggering accuracy, and adherence to the 100-line rule. Two modes: 'all' (bulk ecosystem-wide scan for ownership conflicts, gaps, length outliers, weak triggers) or a single skill name (deep dive on description quality, body structure, anti-pattern naming, cross-references). Outputs a structured report consumable by skill-update. Trigger on: 'audit skills', 'review this skill', 'health check skills', 'skill ecosystem health', 'is this skill any good', 'scan all skills', 'check my skills', 'deep review', 'bulk review', 'what needs fixing'.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["skills/"]
allowed_tools: ["Read", "Glob", "Grep", "Bash", "Write"]
composes_with: ["skill-update", "skill-writer"]
spawned_by: []
---

# Skill Review

One skill, two modes. Use `--scope=all` for an ecosystem-wide bulk scan; use `--scope=<skill-name>` for a thorough single-skill deep dive. Both modes produce a structured markdown report plus a JSON sidecar that `skill-update` can consume to generate fix plans.

## When to Use

- Periodic health check across the skill ecosystem (`--scope=all`)
- After bulk edits or a new batch of skills lands (`--scope=all`)
- Reviewing a single skill before publishing (`--scope=<name>`)
- Investigating why one skill won't trigger or produces poor output (`--scope=<name>`)
- Quality-gating a skill before it enters the ecosystem (`--scope=<name>`)

## Inputs

The skill takes a single positional argument:

- `all` — bulk scan across `skills/**/SKILL.md`
- `<skill-name>` — deep dive on `skills/**/<skill-name>/SKILL.md`

Optional follow-on context:

- **Focus** — narrow the run to specific checks ("just ownership", "just descriptions")
- **Why-now** — what prompted the review (e.g., "it never triggers", "outputs are wrong")

## Process

### Phase 0: Parse the Argument

1. Read the argument. If it equals `all` (case-insensitive), enter Mode A.
2. Otherwise treat the argument as a skill name. Glob for `skills/**/<arg>/SKILL.md`. If exactly one match, enter Mode B. If zero matches, return a list of fuzzy candidates and stop. If multiple matches, ask the user to disambiguate.

### Mode A — Bulk Scan (`--scope=all`)

Optimize for speed. Score quickly, flag issues, move on. Use subagents to parallelize check categories where available.

#### A1. Discovery

1. Glob `skills/**/SKILL.md`
2. Parse frontmatter from each
3. Build a skill inventory table with columns: Skill, Category, Version, Description Length, Body Lines, Refs Count

#### A2. Bulk Checks

Run these check categories. Full checklist lives in `references/audit-checklist.md`.

- **Frontmatter consistency** — required fields present, name matches directory and does NOT start with `claude-` or `anthropic-`, version is valid semver, description starts with action verb and is ≤200 chars
- **Spec compliance (FAIL)** — no `<` or `>` anywhere in frontmatter (security rule); no reserved-prefix name (`claude-*` / `anthropic-*`); description ≤1024 chars (hard ceiling)
- **Tool field naming** — `allowed-tools` (hyphen) is canonical; `allowed_tools` (underscore) accepted as deprecated alias (warn but don't fail)
- **Ownership conflict detection** — collect every `owns.directories` and `owns.patterns` across agent roles. Flag overlaps. Validate against the v1.1 resolved conflicts table in `frontmatter-spec.md`
- **Description quality scoring** — has action verb, ≥3 trigger contexts, keyword variants, states exclusions if ambiguous, estimated "pushiness" (low/medium/high)
- **Progressive disclosure** — SKILL.md body line + word count, references linked from body, body >5,000 words OR >500 lines flagged (soft warning), references >300 lines without TOC flagged
- **Cross-skill consistency** — `composes_with` and `spawned_by` point to real skills, no circular `composes_with` chains, no orphan reference files
- **Coverage gaps** — compare inventory against `docs/architecture.md`, `CLAUDE.md`, and the orchestrator's File Ownership Map; flag roles or workflows referenced but not implemented

#### A3. Triage

Highlight the top 3–5 most impactful issues. Suggest which skills warrant a single-skill follow-up (re-run with `--scope=<name>`). Note which issues `skill-update` can address directly.

### Mode B — Deep Dive (`--scope=<skill-name>`)

Take time. Read every file in the skill's directory tree. Score each rubric dimension 1–5 with specific evidence.

#### B1. Structural Analysis

Read `SKILL.md` and every file in `references/`. Score these dimensions against `references/deep-review-rubric.md`:

1. **Frontmatter compliance** — required fields, types, semver, optional fields used appropriately
2. **Description quality** — action verb, trigger contexts, keyword variants, length, "pushiness"
3. **Progressive disclosure** — body ≤5,000 words (soft warning past 500 lines), references used appropriately, clear pointers
4. **Instruction clarity** — imperative voice, logical flow, no ambiguity, explains "why" not just "what"
5. **Coordination** — ownership declarations, `composes_with` accuracy, no overlaps
6. **Completeness** — referenced files exist, no dead links, validation checklists where needed
7. **Anti-patterns** — see the anti-pattern checklist in `references/audit-checklist.md`

#### B2. Live Trigger Testing

Every deep-review report **must** include an explicit triggering test block in this exact format (matches Anthropic's recommended format for skill triggering tests):

```text
Should trigger:
- "<paraphrase 1 — realistic phrasing a user would actually say>"
- "<paraphrase 2 — different angle / different keyword cluster>"
- "<paraphrase 3 — edge phrasing that should still match>"

Should NOT trigger:
- "<near-miss 1 — adjacent task that belongs to a different skill>"
- "<near-miss 2 — vague prompt that should NOT pull this skill in>"
```

Minimum 3 positives and 2 negatives. Generate from the skill's stated purpose, not from optimistic intent. If you can't write a plausible negative, the skill's scope is too broad — flag that.

If `/skill-creator` or its eval infrastructure is available, run the block as an actual trigger evaluation:

1. Feed the should-trigger prompts; record hit rate
2. Feed the should-NOT-trigger prompts; record false-positive rate
3. Report both rates with examples of any problem triggers

If `/skill-creator` is unavailable, the triggering test block is still required — just unrun. Note "evaluation not executed" in the report.

#### B3. Performance Comparison (optional)

For high-traffic skills where it's worth proving the skill improves over no-skill baseline, run a small A/B:

1. Pick 2 representative task prompts
2. **Without skill enabled:** record total messages, tool calls, failed calls, total tokens
3. **With skill enabled:** record the same metrics
4. Report the deltas — fewer back-and-forths, fewer failed calls, and lower total tokens are the wins. A skill that doesn't move any of these is not earning its load cost.

Skip this for niche or first-version skills where the comparison would be noise. Note "performance comparison skipped — low-traffic skill" in the report.

#### B3. Output Quality Sampling

For skills that produce structured output (reports, files, configs):

1. Pick 2 representative test prompts
2. Run them through the skill (or skill-creator's test harness)
3. Compare actual output against the skill's stated format
4. Note gaps between promised and actual output

### Phase 4: Report

Both modes write the report following `references/report-format.md`. Output two artifacts:

- `skill-review-report.md` — structured markdown for humans
- `skill-review-report.json` — sidecar consumable by `skill-update`

In Mode A, save to the repo root or a user-specified path. In Mode B, save to `{skill-path}/skill-review-report.{md,json}`.

## Output Handoff

The report is designed to feed directly into **skill-update**, which consumes the JSON sidecar and produces a prioritized edit plan. After writing the report, tell the user:

> "Review complete. [X] issues found. Feed the JSON sidecar into `/skill-update` to generate a fix plan, or re-run me with `--scope=<skill-name>` for a deeper look at [specific skills]."

## Guidelines

- Be constructive — every issue gets a concrete suggestion
- Score honestly but explain reasoning, especially for low scores. Don't nitpick style if the skill is functionally sound
- Weight trigger testing heavily — a skill that doesn't trigger is useless regardless of how well-written it is
- In Mode A, don't read reference file contents unless checking for orphans or broken links. Frontmatter + body line count is enough for most checks
- In Mode B, if the user supplied context (e.g., "it never triggers"), lead with that complaint
- If scope is filtered in Mode A, still validate cross-skill references against the full inventory
- Use subagents to parallelize independent check categories when available

## Reference Files

- `references/audit-checklist.md` — checklist of every per-skill and ecosystem-level check, plus the anti-pattern list
- `references/deep-review-rubric.md` — 1–5 scoring criteria for each of the seven deep-review dimensions, with verdict thresholds (SHIP / NEEDS WORK / MAJOR REWORK)
- `references/report-format.md` — exact shape of the markdown report and JSON sidecar
