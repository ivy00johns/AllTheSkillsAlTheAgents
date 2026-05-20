---
name: git-post-merge-cleanup
version: 1.0.0
description: >
  Clean up everything stale after merges in one pass: local branches fully
  merged into the default branch, remote-tracking refs whose remote is gone,
  and worktrees that look "modified" but are already on main. Scans, classifies,
  presents a clear plan, and only acts on confirmation. Supports `--dry-run`
  and `--yes`. Use whenever the user mentions cleaning up branches OR worktrees,
  tidying git state after a batch of PRs landed, or noticing stale debris.
  Trigger on: "clean up branches", "delete merged branches", "prune branches",
  "stale branches", "branch cleanup", "tidy branches", "remove old branches",
  "clean up worktrees", "remove old worktrees", "worktree confusion", "phantom
  modified files", "tidy git state", "lots of things merged", "post-merge
  cleanup", "I have too many branches", "clean up my git".
  Also trigger proactively when `git worktree list` shows entries beyond the
  main worktree, or after a run of `git-pr` merges several PRs in a row.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: []
allowed-tools: ["Bash", "Read", "Write"]
composes_with: ["git-commit", "git-pr"]
spawned_by: []
---

# Git Post-Merge Cleanup

After a batch of PRs land, the local repo accumulates debris: fully merged
branches, tracking refs whose remote was deleted by GitHub, and worktrees
that still show "modified" files even though those changes are already on
main. This skill cleans all of it in one pass — scan, classify, present a
plan, confirm, execute. The scan is cheap; always do both classes.

## Flags

- `--dry-run` — scan and present the plan, but do not delete anything.
- `--yes` — skip the confirmation prompt. Still presents the plan first.

Default (no flags): scan, present plan, wait for confirmation.

## Step 1 — Refresh remote state

```bash
git fetch origin --prune
```

Without `--prune`, stale `origin/*` refs linger for branches GitHub already
deleted on merge.

## Step 2 — Detect the default branch

Do not assume `main`:

```bash
git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@'
```

If that fails, fall back to checking whether `main` or `master` exists
locally. Use the result as `$DEFAULT`.

## Step 3 — Scan and classify

Run both classifiers. Results feed the single plan in Step 4.

### Branches

Cross-reference: `git branch -vv` (tracking status), `git branch --merged
origin/$DEFAULT` (local merged), `git branch -r --merged origin/$DEFAULT`
(remote merged), `git branch -r --no-merged origin/$DEFAULT` (context).

Bucket every branch into one of:

- **fully-merged-local** — in `--merged`, not the default branch. Safe to `git branch -d`.
- **fully-merged-remote** — in `-r --merged`, not `origin/HEAD` and not `origin/$DEFAULT`. Safe to `git push origin --delete`.
- **orphan-tracking** — `git branch -vv` shows tracking remote as `gone` AND branch is not in `--merged`. Unmerged work; flag for user attention, do not delete.
- **in-flight** — everything else. Leave alone.

See `references/branch-classification.md` for edge cases (squash-merged
branches that don't appear in `--merged`, detached HEAD, etc).

### Worktrees

```bash
git worktree list
```

The first entry is the **main worktree** (the repo root) — never a candidate.
For each secondary worktree, classify as either:

- **safe-worktree** — branch is fully merged into `$DEFAULT` OR squash-merged with empty diff vs `$DEFAULT` OR uncommitted changes all match `$DEFAULT`. Safe to `git worktree remove --force`.
- **unsafe-worktree** — genuinely unmerged work. Flag for user attention, do not remove.

The detection commands and the exact "safe" definition live in
`references/worktree-cleanup-rules.md`. Use them — do not eyeball.

## Step 4 — Present the plan

Show one combined plan, grouped by category, with counts and reasons:

```text
Post-merge cleanup plan ($DEFAULT = main)

Local branches to delete (fully merged) — N:
  - feat/add-retry
  - chore/bump-deps

Remote branches to delete (fully merged) — M:
  - origin/feat/add-retry  (or: already pruned by GitHub)

Worktrees to remove (safe) — P:
  - .claude/worktrees/heuristic-northcutt  [claude/heuristic-northcutt] — branch merged
  - .worktrees/auth-feature                [feat/auth]                 — squash-merged (empty diff)

Needs attention (will NOT touch) — K:
  - branch: experimental             — remote gone, unmerged work
  - worktree: .worktrees/spike-foo   — 3 files differ from main

Keeping — J active branches, 1 main worktree.
```

If a category is empty, say so explicitly ("No orphaned branches.") rather
than omitting it — the user should see every category was checked.

## Step 5 — Confirm

- Default: wait for the user to confirm before any destructive command runs.
- `--dry-run`: print the plan and stop.
- `--yes`: proceed without confirmation. Still print the plan first.

## Step 6 — Execute

Order matters: remove worktrees before deleting their branches, otherwise
`git branch -d` refuses because the branch is checked out elsewhere.

Remove safe worktrees first:

```bash
git worktree remove --force <worktree-path>
```

`--force` is needed because the worktree shows local modifications relative
to its HEAD — those changes are already on `$DEFAULT`, which is why we
classified it safe. The classification IS the safety net.

Delete local merged branches:

```bash
git branch -d branch1 branch2 branch3
```

Lowercase `-d` refuses to delete unmerged branches as a backstop. Never use
`-D` unless a squash-merge was confirmed (empty diff vs `$DEFAULT`) or the
user explicitly asked to force-delete.

Delete remote merged branches:

```bash
git push origin --delete branch1 branch2 branch3
```

Use bare names — strip `origin/`. "remote ref does not exist" is expected
when GitHub already deleted on PR merge; note and move on.

Prune worktree metadata and tracking refs:

```bash
git worktree prune
git fetch origin --prune
```

## Step 7 — Summary

Show the final state with `git branch -vv` and `git worktree list`. Report:
local branches deleted, remote branches deleted, worktrees removed, items
flagged for attention, and what remains.

## Safety rules

- Never remove the main worktree (the repo root). Ever.
- Never delete `$DEFAULT`, `develop`, `staging`, or `production`.
- Never delete a branch or remove a worktree with unmerged work without
  explicit user confirmation. The "needs attention" bucket is the signal.
- Lowercase `-d` before uppercase `-D`. Always.
- The classification is the safety net — do not eyeball.

## Edge cases

- **Nothing to clean up** — report "Already tidy" and stop.
- **Permission errors on remote delete** — report cleanly; suggest the
  GitHub UI or a permissions check.
- **Squash-merge not detected by `--merged`** — covered by the empty-diff
  check in `references/worktree-cleanup-rules.md`; same check applies to
  branches without worktrees.
- **Large counts (>20 in a category)** — list all but group by prefix
  (e.g., "12 feat/*, 5 chore/*") so the plan stays readable.
