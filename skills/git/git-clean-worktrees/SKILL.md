---
name: git-clean-worktrees
version: 1.1.0
description: >
  Clean up stale git worktrees whose work is already on the main branch.
  Worktrees accumulate after branches are merged — they sit around with
  "modified" files that look like uncommitted work but are actually already
  on main. This causes confusion ("did I forget to merge this?") and
  clutters git status. Use this skill whenever the user mentions stale
  worktrees, worktree cleanup, leftover worktrees, "clean up workspaces",
  or when you notice orphaned worktrees during other git operations.
  Also trigger on: "worktrees keep getting left behind", "is this merged",
  "clean up worktrees", "remove old worktrees", "worktree confusion",
  or any mention of phantom modified files in worktree directories.
  Trigger proactively when `git worktree list` shows entries beyond the
  main worktree, especially before or after branch cleanup operations.
requires_agent_teams: false
requires_claude_code: false
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed_tools: ["Read", "Bash"]
composes_with: ["git-branch-cleanup"]
spawned_by: []
---

# Clean Worktrees

Systematically find and remove git worktrees whose work is already on the
main branch. The core problem this solves: worktrees created during feature
work persist after the branch is merged, showing "modified" files that are
actually already committed — creating confusion about what's merged and
what isn't.

## Why This Happens

Worktrees are created for isolation during feature work. When the branch
gets merged (squash-merge, regular merge, or cherry-pick), the worktree
doesn't disappear. It still has the branch checked out, and `git status`
inside it shows modifications relative to the worktree's HEAD — but those
changes are already on main. The worktree is stale but looks active.

## Workflow

### Step 1: List all worktrees

```bash
git worktree list
```

Identify the **main worktree** (the repo root) — it must never be removed.
Everything else is a candidate for cleanup.

If there's only the main worktree, report "No secondary worktrees found"
and stop.

### Step 2: For each secondary worktree, determine if it's stale

Run these checks in order. A worktree is **safe to remove** if ANY of
these conditions is true:

#### Check A: Branch is merged into main

```bash
git branch --merged main | grep -q <branch-name>
```

If the branch appears in `--merged`, all its commits are reachable from
main. Safe to remove.

#### Check B: Squash-merged (branch not technically merged, but diff is empty)

Squash merges don't show up in `--merged` because git sees different
commit hashes. Check if the branch's changes are already on main by
comparing the trees:

```bash
git diff main...<branch-name> --stat
```

If this produces no output (empty diff), the branch's content is identical
to main. Safe to remove.

#### Check C: Worktree has uncommitted changes that match main

If the worktree has uncommitted modifications, check whether those changes
already exist on main:

```bash
# List uncommitted changes in the worktree
git -C <worktree-path> status --porcelain

# For each modified file, check if main already has those changes
git diff main -- <file-path>
```

If every modified file in the worktree matches what's on main, the
worktree is stale. Safe to remove.

#### Result: Not safe

If none of the checks pass, the worktree has genuinely unmerged work.
Flag it for the user's attention — don't remove it.

### Step 3: Present findings before acting

Show a clear summary:

```
Worktree cleanup scan complete.

Safe to remove (work already on main):
  .claude/worktrees/heuristic-northcutt [claude/heuristic-northcutt] — branch merged
  .worktrees/auth-feature [feat/auth] — squash-merged (empty diff vs main)

Needs attention (unmerged work):
  .worktrees/experimental [feat/experiment] — 3 files differ from main

No secondary worktrees. (if applicable)
```

For each safe-to-remove entry, include the reason (branch merged, empty
diff, or changes match main) so the user understands why it's safe.

### Step 4: Remove stale worktrees

For each worktree confirmed safe:

```bash
git worktree remove --force <worktree-path>
```

`--force` is necessary because git sees the worktree's branch as having
local modifications (even though those changes are on main). This is
the whole point of this skill — we've already verified the work is safe.

### Step 5: Clean up associated branches

After removing worktrees, delete the local branches if they're merged:

```bash
git branch -d <branch-name>
```

Use lowercase `-d` (safe delete — refuses if not merged). If `-d` fails
because git doesn't recognize a squash-merge as "merged", and Step 2
Check B confirmed the diff is empty, use `-D`:

```bash
git branch -D <branch-name>
```

### Step 6: Prune worktree metadata

```bash
git worktree prune
```

This cleans up any stale worktree administrative files that reference
worktrees that no longer exist on disk.

### Step 7: Verify clean state

```bash
git worktree list
```

Report what was removed and what remains.

## Safety Rules

- **NEVER** remove the main worktree (the repo root)
- **NEVER** remove a worktree with genuinely unmerged work without explicit user confirmation
- Always verify against main before force-removing — the verification IS the safety net
- Use `git branch -d` first (safe), only escalate to `-D` when diff-against-main confirmed empty
- If in doubt, show the diff and ask

## Common Locations

Worktrees accumulate in several places depending on what created them:

| Creator | Typical Location |
|---------|-----------------|
| Claude Code (built-in) | `.claude/worktrees/<name>` |
| superpowers skill | `.worktrees/<name>` or `worktrees/<name>` |
| Manual / other tools | Anywhere (check `git worktree list`) |

Always use `git worktree list` as the source of truth — don't assume
locations.

## Integration

**Pairs with:**
- **git-branch-cleanup** — run after this skill to clean remaining branches
- **using-git-worktrees** — creates the worktrees this skill cleans up
- **finishing-a-development-branch** — handles cleanup during active work; this skill handles the "forgot to clean up" case
