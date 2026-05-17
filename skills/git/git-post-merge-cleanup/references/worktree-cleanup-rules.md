# Worktree Cleanup Rules

When a worktree is actually safe to remove — and the exact commands to
prove it. The classification is the safety net; do not eyeball.

## Why worktrees go stale

Worktrees are created for isolation during feature work. When the branch
gets merged (regular merge, squash merge, or cherry-pick), the worktree
does NOT disappear. It still has the branch checked out, and `git status`
inside it shows modifications relative to the worktree's HEAD — but those
changes are already on `$DEFAULT`. The worktree is stale but looks active.
This is the confusion the user wants resolved.

## List worktrees

```bash
git worktree list
```

The first entry is the **main worktree** (the repo root) — never a
candidate, never remove. Every other entry is a candidate.

If only the main worktree appears: report "No secondary worktrees" and
stop the worktree pass.

## The "safe to remove" definition

A secondary worktree is **safe-worktree** iff it satisfies ALL of:

1. The worktree's branch is reachable from `$DEFAULT` — directly merged,
   squash-merged with empty diff, or cherry-picked with empty diff.
2. The worktree has no uncommitted changes that differ from `$DEFAULT`.
3. The worktree has no stashed work.
4. The worktree has no unpushed commits that aren't on `$DEFAULT`.

If any condition fails, classify as **unsafe-worktree** and flag for the
user. Do not remove.

## Detection commands

Run each in order until one resolves the worktree's class.

### A. Branch fully merged

```bash
git branch --merged $DEFAULT | grep -q "^[ *]*<branch-name>$"
```

If grep finds it, the branch's commits are reachable from `$DEFAULT`.
Continue to checks B/C/D for the worktree's working tree and stash.

### B. Squash-merged — branch not in --merged, but diff is empty

Squash merges produce a new commit hash, so the original branch never
appears in `--merged`. Compare trees:

```bash
git diff $DEFAULT...<branch-name> --stat
```

Empty output ⇒ the branch's content is identical to `$DEFAULT`. Treated
the same as fully merged. Continue to C/D.

If non-empty: there's real divergence. Classify **unsafe-worktree**.

### C. Working tree changes match $DEFAULT

The worktree may show "modified" files but those changes might already
be on `$DEFAULT`:

```bash
git -C <worktree-path> status --porcelain
```

For each modified file:

```bash
git -C <worktree-path> diff $DEFAULT -- <file-path>
```

Empty output for every modified file ⇒ working tree matches `$DEFAULT`.
Any file with a non-empty diff ⇒ **unsafe-worktree**; the worktree has
real uncommitted divergence.

### D. No stash, no unpushed work

```bash
git -C <worktree-path> stash list
```

Non-empty ⇒ **unsafe-worktree**. The user has stashed work in this
worktree that would be silently lost on remove.

```bash
git -C <worktree-path> log $DEFAULT..HEAD --oneline
```

Non-empty AND check A/B failed ⇒ **unsafe-worktree**. There are commits
on the worktree's branch that are not on `$DEFAULT` and were not absorbed
via squash-merge.

## Removal

For each **safe-worktree**:

```bash
git worktree remove --force <worktree-path>
```

`--force` is necessary because git sees local modifications relative to
the worktree's HEAD even though those changes are on `$DEFAULT`. That is
the whole point of this skill — we have already proved the work is safe.

After removing, the branch behind the worktree may still exist locally.
Branch cleanup handles that — `git branch -d <branch>` if `--merged`
classified it, or `git branch -D <branch>` only if check B confirmed
empty diff. Order matters: remove worktrees first, then delete branches,
otherwise `branch -d` refuses because the branch is checked out elsewhere.

Then:

```bash
git worktree prune
```

Cleans up admin files for worktrees no longer on disk (left behind by
manual `rm -rf` of a worktree directory in the past).

## Common locations

Worktrees accumulate in several places. Always trust `git worktree list`,
not directory guesses, but for context:

| Creator | Typical Location |
|---|---|
| Claude Code built-in worktrees | `.claude/worktrees/<name>` |
| superpowers `using-git-worktrees` | `.worktrees/<name>` or `worktrees/<name>` |
| Manual / other tools | Anywhere |

## Hard rules

- Never remove the main worktree (the repo root). Ever.
- Never remove a worktree with a non-empty stash without explicit user
  confirmation — that work is invisible to `git diff` and `git status`.
- Never escalate to `--force` based on intuition. The four checks above
  ARE the justification for `--force`.
- If checks A and B both fail, stop — the branch has real unmerged work.
- If in doubt, show the diff and ask.
