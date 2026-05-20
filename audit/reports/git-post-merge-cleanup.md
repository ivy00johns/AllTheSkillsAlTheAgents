# Audit: git-post-merge-cleanup

**Path:** skills/git/git-post-merge-cleanup/SKILL.md
**Version:** 1.0.0
**Category:** git
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields present; valid semver (1.0.0); description 958 chars folded (under 1024 ceiling); `>` at L4 is YAML scalar style marker (permitted); allowed-tools hyphenated; owns block correctly empty (this skill operates on git refs, not project files); composes_with lists real local skills (git-commit, git-pr). spawned_by empty (correct, user-invoked). requires_claude_code: true (correct — needs Bash for git/gh CLI). |
| Description quality | 5 | Action verb ("Clean up everything stale"), enumerates capabilities (branches, refs, worktrees), 16+ trigger keyword variants ("clean up branches", "delete merged branches", "prune branches", "tidy branches", "worktree confusion", "phantom modified files", "I have too many branches", "clean up my git"), proactive trigger when `git worktree list` shows extras, mentions flag support (`--dry-run`, `--yes`). 958 chars at the upper end but within ceiling. |
| Progressive disclosure | 5 | Body 199 lines / ~1400 words — within all guidelines. Two references linked from body with explicit "when to read" guidance (L82 "See `references/branch-classification.md` for edge cases" and L97-98 "live in `references/worktree-cleanup-rules.md`. Use them — do not eyeball"). Both refs under 300-line TOC threshold (122 and 149 lines). |
| Instruction clarity | 5 | Numbered Steps 1-7 with imperative voice. Each step explains WHY (e.g., "Without --prune, stale origin/* refs linger", "Order matters: remove worktrees before deleting their branches, otherwise git branch -d refuses"). The "classification IS the safety net" framing at L147 is excellent design rationale. Empty-category rule at L125 ("the user should see every category was checked") is thoughtful UX. |
| Coordination | 5 | composes_with: git-commit, git-pr — both exist locally and are accurate (cleanup happens after PRs merge, often after a series of commits). spawned_by empty (correct, user-invoked). owns correctly empty. |
| Completeness | 5 | All workflow content self-contained with concrete git commands. Edge Cases section at L190-199 covers nothing-to-clean, permission errors, squash-merge detection gap, large-count formatting. Safety rules section at L181-188 is explicit. Both reference files exist and address the gaps the body promises. |
| Anti-patterns | 5 | Safety rules section explicitly enumerates 5 destructive-action constraints with rationale ("Lowercase -d before uppercase -D. Always."). Default behavior is "scan, present plan, wait for confirmation" — guards against accidental destructive runs. "--force" use is explained: "those changes are already on $DEFAULT, which is why we classified it safe. The classification IS the safety net." Never assumes `main` — detects default branch dynamically. No emojis. No hardcoded project paths. |

**Average:** 5.00

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- None.

### Nits (won't block ship)
- Description at 958 chars uses 16+ trigger phrase variants — comprehensive but could trim to ~700 chars without losing trigger coverage. SKILL.md:4-17 — drop "tidy git state", "lots of things merged", "I have too many branches", "clean up my git" (already covered by the stronger variants). Stylistic.
- Description uses `>` folded scalar with line breaks that have no semantic meaning — SKILL.md:4-17 — consistency nit with other git/ skills; same pattern across all four.
- L17 references `git-pr` as the trigger source ("after a run of `git-pr` merges several PRs in a row") — git-pr is a guide for creating/updating PRs, not a merge tool. Slight misframing — the merges happen via `gh pr merge` or GitHub UI, not via `git-pr`. Could clarify "after a batch of PRs land".
- Edge cases at L190-199 mention "Squash-merge not detected by `--merged`" — references worktree-cleanup-rules.md but the description implies the check also covers branches. Could be clearer that the empty-diff classifier is shared.
- L153-154 `git branch -d branch1 branch2 branch3` example uses positional names — could note that for large batches this is more readable as `xargs git branch -d` or a for-loop with explicit logging.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Trim description from 958 → ~700 chars** — SKILL.md:4-17 — drop redundant trigger variants ("tidy git state", "lots of things merged", "I have too many branches", "clean up my git" — already covered by stronger explicit variants). Effort: small.
2. **Clarify the "git-pr merges" framing at L17** — SKILL.md:17 — git-pr creates/updates PRs but doesn't merge. Change "after a run of `git-pr` merges several PRs in a row" to "after a batch of PRs land". Effort: trivial.
3. **Clarify squash-merge empty-diff classifier applies to branches too** — SKILL.md:195-197 — extend the edge-case note to make it explicit that the check covers both branches without worktrees and worktrees themselves. Effort: small.

## Dead links / broken references
- None. Both reference files (`branch-classification.md`, `worktree-cleanup-rules.md`) exist. composes_with targets (git-commit, git-pr) both exist locally.
