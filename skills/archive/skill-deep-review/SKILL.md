---
name: skill-deep-review
version: 1.1.0
description: |
  Perform a thorough, single-skill deep dive reviewing structure, description quality, instruction clarity, progressive disclosure, anti-patterns, and frontmatter compliance — then run test prompts via /skill-creator to validate triggering and output quality. Use this skill when deeply reviewing one skill, auditing a specific skill's quality, checking if a skill triggers correctly, doing a "deep dive" on a skill, or when someone says "review this skill", "is this skill good", "check skill quality", or "deep review". Not for broad multi-skill scans — use skill-audit for that.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["skills/"]
allowed_tools: ["Read", "Grep", "Glob", "Bash", "Agent", "Skill"]
composes_with: ["skill-writer", "skill-audit", "skill-improvement-plan"]
spawned_by: []
---

# Skill Deep Review

Perform a comprehensive quality review of a single skill, combining static analysis with live trigger testing via `/skill-creator`.

## When to Use

- Reviewing a single skill in depth before publishing
- Investigating why a skill isn't triggering or producing poor results
- Validating a skill after major edits
- Quality-gating a skill before it enters the ecosystem

## Inputs

- **Skill path** — path to the skill directory (must contain `SKILL.md`)
- **Context (optional)** — what prompted the review (e.g., "it never triggers", "outputs are wrong")

## Process

### Phase 1: Structural Analysis

Read the skill's `SKILL.md` and all files in its directory tree. Evaluate against the rubric in `references/deep-review-rubric.md`. Score each dimension 1–5 and note specific issues.

**Dimensions:**

1. **Frontmatter compliance** — required fields present, types correct, version valid semver, description follows patterns
2. **Description quality** — action verb, trigger contexts, keyword variants, appropriate length, "pushiness"
3. **Progressive disclosure** — body under 500 lines, references used appropriately, clear pointers to reference files
4. **Instruction clarity** — imperative voice, logical flow, no ambiguity, explains "why" not just "what"
5. **Coordination** — ownership declarations, composes_with accuracy, no overlaps with existing skills
6. **Completeness** — all referenced files exist, no dead links, validation checklists present where needed
7. **Anti-patterns** — no hardcoded project details, no excessive MUSTs/NEVERs without rationale, no duplicate content between body and references

### Phase 2: Live Trigger Testing

Use `/skill-creator`'s eval infrastructure to test whether the skill actually works:

1. Generate 3–5 realistic test prompts that should trigger this skill
2. Generate 2–3 near-miss prompts that should NOT trigger it
3. Run trigger evaluation using skill-creator's description optimization tooling
4. Report trigger accuracy (hit rate on should-trigger, false-positive rate on should-not)

### Phase 3: Output Quality Sampling

If the skill produces structured output (reports, files, configs):

1. Pick 2 representative test prompts
2. Run them through `/skill-creator`'s test infrastructure
3. Evaluate output against the skill's own stated format/expectations
4. Note any gaps between promised and actual output

### Phase 4: Generate Review Report

Produce a structured markdown report:

```markdown
# Deep Review: [skill-name]
Reviewed: [timestamp]
Skill path: [path]

## Summary
| Dimension | Score (1-5) | Issues |
|-----------|-------------|--------|
| Frontmatter compliance | X | Y |
| Description quality | X | Y |
| Progressive disclosure | X | Y |
| Instruction clarity | X | Y |
| Coordination | X | Y |
| Completeness | X | Y |
| Anti-patterns | X | Y |

**Overall score:** X.X / 5.0
**Verdict:** SHIP | NEEDS WORK | MAJOR REWORK

## Trigger Testing
- Should-trigger hit rate: X/Y (Z%)
- False-positive rate: X/Y (Z%)
- Problem triggers: [list any that failed]

## Issues

### [SEVERITY]-[N]: [Title]
- **Dimension:** [which]
- **Location:** [file:line or frontmatter field]
- **Description:** [what's wrong]
- **Suggestion:** [how to fix]

## Strengths
[What the skill does well — specific examples]

## Recommendations
[Prioritized list of improvements, ordered by impact]
```

Save the report to `{skill-path}/deep-review-report.md` (or a location the user specifies).

## Output

The review report is designed to feed directly into **skill-improvement-plan**, which can consume it and produce an actionable edit plan. Tell the user:

> "Review complete. To act on these findings, you can feed this report into `/skill-improvement-plan` to generate a prioritized edit plan."

## Guidelines

- Be constructive — every issue should have a concrete suggestion
- Score honestly but explain your reasoning, especially for low scores
- Don't nitpick style if the skill is functionally sound
- Weight trigger testing heavily — a skill that doesn't trigger is useless regardless of how well-written it is
- If the skill has known context (user said "it never triggers"), prioritize investigating that specific complaint

## Reference Files

- `references/deep-review-rubric.md` — Detailed scoring criteria for each dimension
