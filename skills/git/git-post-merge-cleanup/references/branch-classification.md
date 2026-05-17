# Branch Classification

How to bucket every local and remote branch into one of four classes. The
classification IS the safety net — get it right and the deletion is trivial.

## The four classes

| Class | Meaning | Action |
|---|---|---|
| **fully-merged-local** | Local branch whose commits are reachable from `$DEFAULT` | `git branch -d` |
| **fully-merged-remote** | `origin/<x>` whose commits are reachable from `origin/$DEFAULT` | `git push origin --delete` |
| **orphan-tracking** | Local branch whose upstream is `gone` AND not in `--merged` | Flag for user — has unmerged work |
| **in-flight** | Everything else — active branches, unmerged work | Leave alone |

## Detection commands

### Refresh first

```bash
git fetch origin --prune
```

Without `--prune`, stale `origin/*` refs make orphan-tracking look like
in-flight.

### Resolve the default branch

```bash
git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@'
```

If empty, fall back to `main`, then `master`.

### Fully-merged local branches

```bash
git branch --merged origin/$DEFAULT
```

Every line in this list (excluding `$DEFAULT` itself and any line starting
with `*` — the current branch) is **fully-merged-local**.

### Fully-merged remote branches

```bash
git branch -r --merged origin/$DEFAULT
```

Every line (excluding `origin/HEAD` and `origin/$DEFAULT`) is
**fully-merged-remote**. Strip the `origin/` prefix when calling `git push
origin --delete`.

### Orphan-tracking branches

```bash
git branch -vv
```

Look for lines containing `: gone]` — the upstream remote is deleted. Of
those, if a branch is NOT in `git branch --merged origin/$DEFAULT`, it is
**orphan-tracking**: the remote disappeared but the local branch still has
commits that never landed on the default branch. Do not delete; flag.

If a branch with `: gone]` IS in `--merged`, classify it as
**fully-merged-local** — the remote just got cleaned up after merge.

### In-flight

Anything not matched above. Has unmerged work, has an active remote, may
be the current branch.

## Edge cases

### Squash-merge — branch looks unmerged but content is on main

GitHub squash-merges produce a different commit hash, so the original
branch never appears in `--merged`. Detect by comparing trees:

```bash
git diff $DEFAULT...<branch-name> --stat
```

Empty output means the branch's content is already on `$DEFAULT`. Reclassify
as **fully-merged-local** (or fully-merged-remote, on the remote side).
This is the only justification for using `git branch -D` instead of `-d`.

### Detached HEAD

`git branch -vv` won't list a real branch name. Skip — there's nothing to
delete. The user should check out a real branch.

### Current branch in --merged

The current branch can appear in `git branch --merged origin/$DEFAULT` (it
is, after all, an ancestor of itself if you're on `$DEFAULT`). Lines
starting with `*` are the current branch — exclude them from the deletion
list. `git branch -d` refuses to delete the current branch anyway.

### Protected branches

Never delete, even if `--merged` says they're safe:

- `$DEFAULT` (`main` / `master`)
- `develop`, `staging`, `production`
- Anything the user explicitly named "keep"

### Local branch with no remote ever set

`git branch -vv` shows no tracking info. If it's in `--merged`, it's
**fully-merged-local** (safe). If not, it's **in-flight** (local-only WIP).
Either way, treat the same as branches that did have a remote.

## What "safe to delete" actually means

A local branch is safe to delete iff every commit on it is reachable from
`$DEFAULT` (either via direct merge or via squash-merge with empty diff).
Lowercase `git branch -d` enforces the direct-merge case; the squash-merge
case requires the empty-diff check before escalating to `-D`.

A remote branch is safe to delete iff every commit on `origin/<x>` is
reachable from `origin/$DEFAULT`. `git branch -r --merged` answers exactly
this.
