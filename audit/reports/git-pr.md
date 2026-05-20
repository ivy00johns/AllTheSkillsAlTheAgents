# Audit: git-pr

**Path:** skills/git/git-pr/SKILL.md
**Version:** 1.2.0
**Category:** git
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields present; valid semver (1.2.0); description 552 chars folded (well under 1024 ceiling); `>` at L4 is YAML scalar style marker not content (permitted); allowed-tools hyphenated; owns block correctly empty for a guide skill; composes_with lists real local skills (git-commit, git-pr-feedback). spawned_by empty (correct). |
| Description quality | 5 | Action verb ("Guide for creating and updating"), 10 trigger keyword variants ("create a PR", "open a PR", "pull request", "PR description", "PR body", "ready for review", "gh pr create", "open pull request", "submit PR", "PR template"), proactive trigger statement ("Also use proactively whenever you are about to run `gh pr create`"). |
| Progressive disclosure | 5 | Body 137 lines / ~550 words — well within all guidelines. No references/ directory (correct — tight reference card pattern). All workflow content is self-contained. |
| Instruction clarity | 5 | Numbered Workflow steps (1-3) with imperative voice. Body Structure section provides exact template. Body guidelines call out lead-with-why principle. HEREDOC pattern shown with explicit "flush-left for GitHub markdown rendering" rationale. Pre-Push Checklist at L132-137 captures key gates. |
| Coordination | 5 | composes_with: git-commit, git-pr-feedback — both exist locally and are accurate pairings (commits feed PRs; PRs lead to feedback handling). spawned_by empty (correct, user-invoked). owns correctly empty. |
| Completeness | 5 | All content self-contained. Title examples concrete. Body template provided inline. Workflow commands shown with exact gh CLI syntax. Update and status sections cover full PR lifecycle. No reference files needed for this scope. |
| Anti-patterns | 4 | Imperative voice throughout. No emojis. Templates marked as adjustable ("Adjust sections as needed for the size and complexity of the change — small fixes may only need the summary") — guards against over-rigid template application. No explicit anti-pattern callout (unlike sibling git-commit which has one) — adding one (e.g., "Forbidden: pushing to main without a PR" or "Forbidden: rewriting the diff after marking ready for review") would parallel sibling structure. |

**Average:** 4.86

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- None.

### Nits (won't block ship)
- `owns.shared_read: ["*"]` is a wildcard — SKILL.md:19 — same nit as git-commit; the skill operates via `gh` CLI commands not file reads; consider `[]` or removing.
- Description uses `>` folded scalar with line breaks that have no semantic meaning — SKILL.md:4-12 — stylistic; single paragraph or `|` block scalar would render identically and be more uniform with other skills.
- No explicit Anti-Pattern callout — SKILL.md (end of file) — git-commit has one (forbid amending without permission); for parity, consider adding e.g. "Forbidden: pushing to main without a PR" or "Forbidden: marking ready for review while CI is red".
- L33 cross-references git-commit ("Use the same type conventions as git-commit") without a path — consider `[git-commit](../git-commit/SKILL.md)` for clarity in renderers.
- HEREDOC command body at L91-105 hard-codes the type prefix and a generic test plan checkbox — fine as a template; could note that the actual PR should bring real Summary/Changes/Test plan content rather than placeholder bullets.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Tighten owns.shared_read** — SKILL.md:19 — change to `[]` (skill operates via `gh` CLI, not file reads) or `["./"]`. Effort: trivial.
2. **Add an Anti-Pattern callout for sibling parity** — SKILL.md (end of file) — append a section: `## Anti-Pattern\n\n> **Forbidden:** Pushing directly to main without a PR. Even one-line fixes go through review when the repo's CONTRIBUTING.md requires it.` Effort: small.
3. **Add explicit path to git-commit cross-reference** — SKILL.md:33 — change `git-commit` to `[git-commit](../git-commit/SKILL.md)`. Effort: trivial.

## Dead links / broken references
- None. composes_with targets (git-commit, git-pr-feedback) both exist locally.
