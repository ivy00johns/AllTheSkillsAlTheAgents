---
name: git-branch-cleanup
version: 1.1.0
description: >
  Clean up stale and merged git branches — both local and remote. Prunes
  tracking refs, identifies merged branches safe to delete, flags orphaned
  branches whose remote is gone, and presents a clear summary before acting.
  Use this skill whenever the user mentions cleaning up branches, pruning
  stale branches, deleting old branches, or tidying their git state.
  Trigger on: "clean up branches", "delete merged branches", "prune branches",
  "stale branches", "branch cleanup", "tidy branches", "remove old branches",
  "git branch cleanup", "branches to delete", "what branches can I delete",
  or any request about removing branches that have already been merged.
  Also trigger when the user says things like "I have too many branches",
  "clean up my git", or "lots of things merged".
composes_with: ["git-commit", "git-pr"]
---

# Git Branch Cleanup

Systematically identify and remove branches that are no longer needed.
Stale branches accumulate fast — especially when PRs auto-delete the remote
branch on merge but the local tracking ref and local branch stick around.
This skill walks through the cleanup safely so nothing important gets lost.

## Workflow

### Step 1: Refresh remote state

Start by fetching and pruning so the local view of remote branches is
accurate. Without this, you'd see stale `origin/*` refs for branches
GitHub already deleted on merge.

```bash
git fetch origin --prune
```

### Step 2: Detect the default branch

Don't assume `main` — check:

```bash
git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@'
```

The `-q` flag suppresses the fatal error when `origin/HEAD` isn't set, and
`--short` strips the `refs/remotes/` prefix. If that fails, fall back to
checking whether `main` or `master` exists locally. Use the result as
`$DEFAULT` for the rest of the workflow.

### Step 3: Categorize every branch

Run these four commands and cross-reference the results:

| Command | Purpose |
|---|---|
| `git branch -vv` | Local branches with tracking status and ahead/behind |
| `git branch --merged origin/$DEFAULT` | Local branches fully merged into the default branch |
| `git branch -r --merged origin/$DEFAULT` | Remote branches fully merged |
| `git branch -r --no-merged origin/$DEFAULT` | Remote branches with unmerged work (context only) |

From these results, build four categories:

1. **Merged local branches** — appear in `--merged` output, excluding the
   default branch itself. These are safe to delete.
2. **Stale remote branches** — appear in `-r --merged` output, excluding
   `origin/HEAD` and `origin/$DEFAULT`. These are safe to delete from the
   remote.
3. **Orphaned local branches** — `git branch -vv` shows their tracking
   remote as `gone` but they are NOT in the `--merged` list. These contain
   unmerged work and need the user's attention.
4. **Active unmerged branches** — everything else. Leave these alone.

### Step 4: Present the summary

Show the user a clear, categorized summary before doing anything destructive:

```text
**Safe to delete — N local branches merged into $DEFAULT:**
- branch-name-1
- branch-name-2

**Safe to delete — M remote branches merged into $DEFAULT:**
- origin/branch-name-1 → delete as `branch-name-1`
- origin/branch-name-2 → delete as `branch-name-2`
(or: "All merged remote branches were already pruned by GitHub.")

**Needs attention — K orphaned branches (remote gone, not merged):**
- branch-name (last commit: <short msg>)

**Keeping — J active unmerged branches:**
- branch-name → origin/branch-name
```

If any category is empty, say so briefly (e.g., "No orphaned branches.")
rather than omitting the section — the user should see that every category
was checked.

Wait for the user to confirm before proceeding to deletion.

### Step 5: Delete confirmed branches

Once the user confirms:

**Local merged branches:**

```bash
git branch -d branch1 branch2 branch3
```

Use `-d` (lowercase) which refuses to delete unmerged branches as a safety
net. Never use `-D` unless the user explicitly asks to force-delete an
unmerged branch.

**Remote merged branches:**

```bash
git push origin --delete branch1 branch2 branch3
```

Use bare branch names — strip the `origin/` prefix. These may fail with
"remote ref does not exist" if GitHub already deleted them on PR merge.
That's expected — just note it and move on.

**Final prune** to clean up any remaining stale tracking refs:

```bash
git fetch origin --prune
```

### Step 6: Verify and report

Show the final branch state:

```bash
git branch -vv
```

Summarize what was done: how many local branches deleted, how many remote
branches deleted, how many pruned, and what remains.

## Protected Branches

Never delete these, even if they appear in a merged list:

- The default branch (`main`, `master`, or whatever `$DEFAULT` resolved to)
- `develop`, `staging`, `production` (if they exist)
- Any branch the user explicitly asks to keep

## Edge Cases

- **No branches to clean up** — if everything is already tidy, say so.
- **Permission errors on remote delete** — report the error clearly and
  suggest the user delete the branch via the GitHub UI or check permissions.
- **Large number of branches** — if there are more than ~20 branches in
  any category, list them all but consider grouping by prefix
  (e.g., "12 feature/* branches, 5 chore/* branches").
