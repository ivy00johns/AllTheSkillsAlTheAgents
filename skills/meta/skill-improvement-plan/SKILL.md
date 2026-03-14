---
name: skill-improvement-plan
version: 1.1.0
description: |
  Consume review reports from skill-deep-review or skill-audit and produce a prioritized, actionable improvement plan with specific edits per skill. Use this skill when you have review feedback to act on, need to plan skill improvements, want to turn audit results into a fix plan, or when someone says "plan the fixes", "what should we improve", "make a plan from this review", "improvement plan", or "prioritize the changes". Also trigger when a deep-review or audit report exists and the user wants next steps.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["skills/"]
allowed_tools: ["Read", "Grep", "Glob", "Write"]
composes_with: ["skill-deep-review", "skill-audit", "skill-updater"]
spawned_by: []
---

# Skill Improvement Plan

Take feedback from skill-deep-review, skill-audit, or manual observations and produce a structured, prioritized plan of specific changes to make.

## When to Use

- After a deep review report identifies issues in a skill
- After an audit report surfaces ecosystem-wide problems
- When you have scattered feedback notes and need to organize them into an actionable plan
- When deciding what order to fix things in

## Inputs

- **Review source** — one or more of:
  - A deep-review report (markdown from skill-deep-review)
  - An audit report (markdown from skill-audit)
  - Manual feedback (user-provided notes, conversation context)
- **Constraints (optional)** — time budget, which skills are off-limits, what to prioritize

## Process

### Step 1: Parse the Feedback

Read all review/audit reports provided. Extract:

- Every issue with its severity, affected skill, and dimension
- Every recommendation
- Trigger testing results (if from deep-review)
- Coverage gaps (if from audit)

### Step 2: Deduplicate and Categorize

Group issues by type:

| Category | Examples |
|----------|----------|
| **Frontmatter fixes** | Missing fields, wrong types, bad version |
| **Description rewrites** | Vague triggers, missing keywords, too long/short |
| **Content restructuring** | Body too long, needs reference extraction, missing sections |
| **Instruction improvements** | Ambiguous steps, missing rationale, wrong voice |
| **Ownership fixes** | Overlaps, missing declarations, stale composes_with |
| **New content** | Missing reference files, missing examples, missing checklists |
| **Deletions** | Duplicate content, orphan files, dead links |

Merge duplicates — if the audit and a deep review both flag the same issue, combine them.

### Step 3: Prioritize

Score each change on two axes:

- **Impact** (1–3): How much does fixing this improve the skill ecosystem?
  - 3 = Skill doesn't trigger or produces wrong output without this fix
  - 2 = Skill works but quality or consistency suffers
  - 1 = Polish, nice-to-have
- **Effort** (1–3): How hard is the change?
  - 1 = Quick edit (fix a field, add a line)
  - 2 = Moderate rewrite (restructure a section, write a new reference file)
  - 3 = Major rework (rewrite a skill from scratch, resolve complex ownership conflicts)

Sort by: Impact DESC, then Effort ASC (high-impact easy wins first).

### Step 4: Generate the Plan

Produce a structured markdown plan:

```markdown
# Skill Improvement Plan
Generated: [timestamp]
Source: [which reports/feedback were consumed]
Total changes: [count]

## Priority Matrix

| Priority | Impact | Effort | Changes |
|----------|--------|--------|---------|
| P0 (do first) | 3 | 1 | X |
| P1 (do next) | 3 | 2–3, or 2 | 1 | X |
| P2 (do later) | 2 | 2–3, or 1 | 1 | X |
| P3 (backlog) | 1 | any | X |

## Changes

### P0: [Title]
- **Skill:** [name]
- **File:** [path]
- **Category:** [from step 2]
- **What:** [specific change to make]
- **Why:** [from the review — what issue this fixes]
- **How:** [brief description of the edit — enough for skill-updater to execute]

### P0: [Title]
...

### P1: [Title]
...

## Execution Notes
- [Any ordering dependencies between changes]
- [Skills that should be reviewed again after changes]
- [Changes that might affect other skills]

## Post-Implementation
- [ ] Run skill-audit on affected skills to verify fixes
- [ ] Run skill-deep-review on any skill with P0 changes
- [ ] Sync repo → global locations
```

### Step 5: Present and Confirm

Show the plan to the user. Ask:

> "Here's the improvement plan with [X] changes across [Y] skills. The P0 items are [brief summary]. Want me to proceed with skill-updater to implement these, or would you like to adjust priorities first?"

## Guidelines

- Be specific in the "How" field — vague instructions like "improve the description" aren't helpful. Say exactly what to change: "Rewrite description to: '[new description text]'"
- For description rewrites, draft the new description text in the plan so the updater can apply it directly
- Don't generate a plan for issues that are actually just style preferences — focus on functional improvements
- If a change would affect multiple skills (e.g., fixing an ownership overlap), note the dependency explicitly
- Keep the plan actionable — every item should be something skill-updater can execute without further research

## Output

The plan is designed to feed directly into **skill-updater**, which reads the plan and executes the changes. The user can also use it as a manual TODO list.
