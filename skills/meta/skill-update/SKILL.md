---
name: skill-update
version: 1.1.0
description: |
  Plan and apply changes to an existing skill in one workflow. Reads a skill-deep-review or skill-audit report (or inline findings), drafts an edit list with the agent's recommended answer attached to each item, walks the user through the changes one at a time, applies them, and re-runs lint and frontmatter checks. Use after running skill-review or skill-audit and you are ready to ship changes. Trigger on: "apply the review", "update this skill", "fix the skill", "ship the recommendations", "edit this skill", "let's improve it", "apply the plan", "implement the changes", "make those edits".
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: ["skills/"]
  patterns: []
  shared_read: []
allowed_tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
composes_with: ["skill-review", "skill-writer", "sync-skills"]
spawned_by: []
---

# Skill Update

Plan and apply changes to an existing skill in a single walk-through. Consumes a review report (or inline findings), drafts one edit per bullet with the agent's recommended answer attached, walks the edits one at a time, applies them, and re-validates the skill.

## When to Use

- A `skill-deep-review` or `skill-audit` report exists and the user wants next steps
- The user said something like "apply the review", "ship the recommendations", "fix this skill"
- A short list of fixes is in the chat and the user wants them applied with confirmation
- Simple direct edits where planning and applying is one motion, not two

If there is no review yet, run `skill-review` (deep) or `skill-audit` (broad) first and come back.

## Inputs

- **Review source** — a `skill-deep-review` report, a `skill-audit` report, or inline findings from chat
- **Target skill(s)** — SKILL.md path(s) to edit
- **Scope (optional)** — priority levels to walk ("just P0", "P0 and P1", "all")

## Process

### Step 1: Parse the Feedback

Read every report and note provided. Extract:

- Each issue with its severity, affected skill, file, and dimension
- Each recommendation
- Trigger-testing results (from `skill-deep-review`) and coverage gaps (from `skill-audit`)

Deduplicate — if audit and deep-review flag the same issue, merge them. Group by category:

| Category | Examples |
|----------|----------|
| Frontmatter fixes | Missing fields, wrong types, bad version |
| Description rewrites | Vague triggers, missing keywords, too long/short |
| Content restructuring | Body too long, needs reference extraction, missing sections |
| Instruction improvements | Ambiguous steps, missing rationale, wrong voice |
| Ownership fixes | Overlaps, stale `composes_with`, missing declarations |
| New content | Missing reference files, examples, checklists |
| Deletions | Duplicate content, orphan files, dead links |

### Step 2: Draft the Edit Plan

Produce a one-bullet-per-edit list. Each bullet carries an explicit **recommended answer** so the user can accept by nodding.

Score each change:

- **Impact** (1–3): 3 = skill misfires without this, 2 = quality suffers, 1 = polish
- **Effort** (1–3): 1 = quick field edit, 2 = rewrite a section, 3 = major rework

Sort by Impact DESC, then Effort ASC. P0 first, P1 next, P2/P3 later.

For each bullet, draft the actual edit text — not "improve the description" but `Rewrite description to: "<new text>"`. For description rewrites, draft the new description in the plan so it can be applied verbatim.

See `references/plan-format.md` for the full bullet schema.

### Step 3: Walk the User Through Edits

Present the plan, then walk one edit at a time. For each:

1. State the change — file, what, why, recommended answer
2. Ask: "Apply this edit?" Default is yes
3. On confirm, apply with `Edit` (one logical change per call — never batch unrelated edits)
4. On skip, note why and move on
5. On modify, take the user's revision and apply that
6. Briefly confirm: `Updated <skill-name>: <what changed>`

Rules while applying:

- **Read before editing, always** — never edit a file you have not read this session
- For new reference files, create the file first, then edit the parent SKILL.md to link it
- For deletions, update any links that pointed to the removed content
- Preserve YAML formatting and field order in frontmatter edits
- If a planned edit no longer makes sense (file already fixed, context changed), skip it and say why

For batches of 10+ independent edits across different skills, parallel-dispatch with subagents.

### Step 4: Post-Edit Validation

After all edits in this pass:

- Re-read every modified SKILL.md and validate frontmatter against `skills/meta/skill-writer/references/frontmatter-spec.md`
- Confirm body length is within spec guidance — ≤5,000 words and ≤500 lines (soft warnings); warn over ~100 lines when content could move to references
- Resolve all reference links in modified files
- If `owns` fields changed, re-check there are no overlaps with other agent roles
- Run markdownlint if available — `.markdownlint.json` is at repo root

See `references/validation-checklist.md` for the full check list and report format.

### Step 5: Re-Run Review and Sync (optional)

Offer:

> "Re-run `skill-review` to confirm the issues are gone? I can diff before/after."

Then offer sync:

> "All changes applied and validated. Sync to your global skill locations now?"

If yes, invoke `sync-skills`:

```bash
skills/workflows/sync-skills/scripts/sync-skills.sh --to-all
```

If declined, remind: "Repo versions are updated but your global locations still have the old versions — sync when you are ready."

## Error Handling

- **Edit fails:** report what failed, skip to the next edit, collect failures, present them at the end with retry/manual-fix/skip options
- **Validation fails:** name the specific failures, suggest fixes, ask whether to fix now or leave for later — do not auto-fix without confirmation

## Guidelines

- Be specific in every bullet — vague "improve the description" is not actionable
- Attach the recommended answer to every bullet so the user can accept fast
- One logical change per `Edit` call
- Skip pure style preferences — focus on functional improvements
- Note ordering dependencies between changes (e.g. ownership fix in skill A must land before skill B's update)
- Never reformat an entire file as a side-effect of a targeted edit

## References

- `references/plan-format.md` — schema for the one-bullet-per-edit plan
- `references/validation-checklist.md` — post-edit checks (markdownlint, frontmatter spec, line count, broken xrefs)
