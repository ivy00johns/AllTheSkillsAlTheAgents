---
name: skill-updater
version: 1.0.0
description: |
  Execute skill improvement plans by making edits to SKILL.md files and references, validating changes, and optionally syncing to global skill locations. Use this skill when implementing planned skill changes, applying fixes from a review, executing an improvement plan, batch-editing skills, or when someone says "apply the plan", "fix the skills", "implement the changes", "update the skills", "execute the improvement plan", or "make those edits". Also trigger after skill-improvement-plan produces output and the user wants to proceed.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["skills/"]
allowed_tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Agent"]
composes_with: ["skill-improvement-plan", "skill-deep-review", "skill-audit", "sync-skills"]
spawned_by: []
---

# Skill Updater

Execute skill improvement plans by making specific edits to skill files, validating the changes, and prompting the user to sync.

## When to Use

- After skill-improvement-plan generates a plan and the user says "go"
- When you have a clear list of edits to make across skills
- When applying fixes from a review report directly (skipping the planning step for simple fixes)

## Inputs

- **Improvement plan** — a structured plan from skill-improvement-plan, OR a list of specific changes to make
- **Scope (optional)** — which priority levels to execute (e.g., "just P0", "P0 and P1", "all")

## Process

### Step 1: Parse the Plan

Read the improvement plan. Extract the ordered list of changes with:
- Target skill and file path
- What to change
- The specific edit (old text → new text, new content, file to create/delete)

If the user provided ad-hoc changes instead of a formal plan, organize them into the same structure.

### Step 2: Validate Before Editing

For each change, before applying:

1. **Read the target file** — confirm it exists and the content matches expectations
2. **Check for conflicts** — if multiple changes target the same file, plan the edit order to avoid conflicts
3. **Verify ownership** — if changing `owns` fields, check against other skills for overlaps

If anything doesn't match expectations (file content changed since the review, file doesn't exist), flag it and ask the user before proceeding.

### Step 3: Apply Changes

Execute changes in priority order (P0 first, then P1, etc.):

**For frontmatter edits:**
- Use Edit tool to modify specific frontmatter fields
- Preserve YAML formatting and field order

**For description rewrites:**
- Replace the entire description field with the new text from the plan
- Verify the new description follows the patterns (action verb, trigger contexts)

**For content restructuring:**
- If moving content to a new reference file: create the reference file first, then edit the body to add the pointer and remove the moved content
- If merging sections: read both sources, combine, write the merged version

**For new files:**
- Create reference files, checklists, or templates as specified
- Ensure they're linked from the parent SKILL.md

**For deletions:**
- Remove orphan files or duplicate content
- Update any links that pointed to removed content

After each change, briefly confirm what was done:
> "Updated [skill-name]: [what changed]"

### Step 4: Post-Edit Validation

After all changes are applied:

1. **Frontmatter check** — Re-read every modified SKILL.md and validate frontmatter fields are still valid
2. **Link check** — Verify all reference links in modified files still resolve
3. **Line count check** — Confirm no SKILL.md body now exceeds 500 lines
4. **Ownership check** — If any `owns` fields changed, re-validate no overlaps exist

Report validation results:

```markdown
## Validation Results
- Files modified: X
- Frontmatter valid: X/X
- Links resolved: X/X
- Body line limits: X/X
- Ownership clean: yes/no

### Issues Found
[Any post-edit validation failures]
```

### Step 5: Prompt to Sync

After successful validation, prompt the user:

> "All [X] changes applied and validated. Would you like to sync these skills to your global locations? I can use the sync-skills workflow to push to Cursor and/or Claude Code."

If the user says yes, invoke the sync-skills workflow (or run the sync script directly if available):

```bash
# Sync to both Cursor and Claude Code
skills/workflows/sync-skills/scripts/sync-skills.sh --to-all
```

If they decline, remind them:

> "No problem. Remember to sync when you're ready — the repo versions are updated but your global skill locations still have the old versions."

## Guidelines

- Make one logical change at a time — don't batch unrelated edits into a single Edit call
- Read before editing, always — never edit a file you haven't read in this session
- Preserve existing formatting when making targeted edits (don't reformat entire files)
- If a planned change no longer makes sense (context changed, file was already fixed), skip it and note why
- For large batches (10+ changes), use subagents to parallelize independent edits across different skills
- Always validate after editing — catching a broken link now is better than discovering it in the next audit

## Error Handling

If an edit fails:
1. Report what failed and why
2. Skip to the next change (don't block the whole batch)
3. Collect all failures and present them at the end
4. Suggest whether to retry, manually fix, or skip

If validation fails after edits:
1. Report the specific validation failures
2. Suggest fixes
3. Ask the user whether to fix now or leave for later
