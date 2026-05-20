# Audit: git-commit

**Path:** skills/git/git-commit/SKILL.md
**Version:** 1.2.0
**Category:** git
**Verdict:** NEEDS WORK

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields present; valid semver (1.2.0); description uses `>` folded scalar (501 chars folded, well under 1024 ceiling); no `<` or `>` inside field values (the `>` at L4 is YAML scalar style marker, not content — explicitly permitted by frontmatter-spec.md L170 "YAML scalar style markers like description: > are structural and not affected by this rule"). allowed-tools hyphenated. owns block correctly empty for a guide skill. composes_with includes archived `git-branch-cleanup` — broken cross-skill reference. |
| Description quality | 5 | Action verb ("Guide for creating"), 9 trigger keyword variants ("commit", "create a commit", "git commit", "stage changes", "write a commit message", "make a commit", "branch name", "new branch", "create branch"), proactive trigger statement ("Also use proactively whenever you are about to run `git commit`"). 501 chars (folded) is generous but well under ceiling. |
| Progressive disclosure | 5 | Body 121 lines / ~476 words — well within all guidelines. No references/ directory (correct — this is a tight reference card, no extended material needed). All content fits in the body atomically. |
| Instruction clarity | 5 | Numbered sections with imperative voice. Allowed Types table at L43-54 explicit and bounded. Examples section provides multiple worked examples. Quick Checklist at L112-115 summarizes the rules. Anti-Pattern callout at L121 explicit ("Forbidden: Amending commits unless the user explicitly asks"). |
| Coordination | 2 | composes_with at L20 lists `git-branch-cleanup` which is archived (now `git-post-merge-cleanup`). One of two composed skills is broken. composes_with should include `git-pr-feedback` since both work on the same PR workflow. spawned_by empty (correct for user-invoked). |
| Completeness | 5 | All content is self-contained. No reference files (none needed for this skill). Examples are concrete. Quick Checklist captures the rules. No dead links. |
| Anti-patterns | 5 | Explicit Anti-Pattern callout at L121 forbids amending without permission with rationale (post-hook-failure NEW commit). Imperative voice throughout. No emojis. No excessive MUST/NEVER. The branch naming convention has explicit "3-5 meaningful words" guidance preventing both extremes. |

**Average:** 4.43

## Findings

### Critical (must fix to ship)
- composes_with references archived skill `git-branch-cleanup` — SKILL.md:20 — proposed fix: `composes_with: ["git-pr", "git-post-merge-cleanup", "git-pr-feedback"]`. The replacement skill is `git-post-merge-cleanup` (visible in `skills/git/git-post-merge-cleanup/`).

### Important (should fix)
- None.

### Nits (won't block ship)
- `owns.shared_read: ["*"]` is a wildcard — SKILL.md:18 — for a git-workflow skill that mostly reads diffs/log output via Bash, this is correct but could be more specific (e.g., `["./"]` or omitted entirely since the skill operates via git commands not file reads).
- Description uses `>` folded scalar with line breaks that have no semantic meaning — SKILL.md:4-11 — folded scalars work but could use `|` block scalar with explicit paragraph form, or single-line for clarity. Stylistic.
- L29 fenced code block tagged `text` for the commit message format — works but could be tagged `markdown` or `gitcommit` for syntax-aware rendering in some viewers. Trivial.
- Merge Strategy section at L106 makes a default claim ("squash merge by default") — this is a workflow assumption that may not hold in every repo using this skill. Consider noting "default in this repo; check the repo's CONTRIBUTING.md if it disagrees."

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Replace archived `git-branch-cleanup` with `git-post-merge-cleanup` in composes_with** — SKILL.md:20 — change `composes_with: ["git-pr", "git-branch-cleanup"]` to `composes_with: ["git-pr", "git-post-merge-cleanup", "git-pr-feedback"]`. Effort: trivial.
2. **Tighten owns.shared_read or remove the wildcard** — SKILL.md:18 — change to `[]` (the skill operates via git commands, not file reads) or `["./"]`. Effort: trivial.
3. **Add a note that Merge Strategy default is repo-conventional** — SKILL.md:106 — append "; check the repo's CONTRIBUTING.md if it disagrees." Effort: trivial.

## Dead links / broken references
- `git-branch-cleanup` in composes_with (SKILL.md:20) — **broken** (archived in `skills/archive/git-branch-cleanup/`).
- `git-pr` reference resolves (exists at `skills/git/git-pr/`).
- No other cross-references or reference files to verify.
