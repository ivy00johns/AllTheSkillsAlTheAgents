# Why archived

**Replaced by:** [git-post-merge-cleanup](../../git/git-post-merge-cleanup/) — merged branch + worktree cleanup into one pass
**Date archived:** 2026-05-15
**Reason:** Both skills clean up debris left by merges. Splitting them forced two invocations for one user intent ("clean up after merges"). The merged skill scans, presents one plan, and executes both classes of cleanup with `--dry-run`/`--yes` flags.
