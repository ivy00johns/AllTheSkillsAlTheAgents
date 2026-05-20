# Audit: git-pr-feedback

**Path:** skills/git/git-pr-feedback/SKILL.md
**Version:** 1.2.0
**Category:** git
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 5 | All required fields present; valid semver (1.2.0); description 553 chars folded (well under 1024 ceiling); `>` at L4 is YAML scalar style marker (permitted); allowed-tools hyphenated; owns block correctly empty; composes_with lists real local skills (git-pr, git-commit). spawned_by empty (correct). |
| Description quality | 5 | Action verb ("Fetch, triage, and address"), 9+ trigger keyword variants ("check PR comments", "what did copilot say", "address PR feedback", "fix review comments", "handle PR suggestions", "review feedback", "PR comments", "copilot review", "reviewer feedback"), proactive trigger ("Also trigger when the user returns to a PR after some time"). |
| Progressive disclosure | 5 | Body 195 lines / ~1020 words — within all guidelines. No references/ directory (correct — the skill is a complete operational runbook, not a deep technical spec). All gh CLI commands inline. |
| Instruction clarity | 5 | Numbered Workflow steps 1-7 with imperative voice ("Identify the PR", "Fetch All Comments", "Triage Each Comment"). Triage table at L76-83 maps category → action with examples. Each step has rationale (e.g., "Use --paginate to ensure all comments are returned — the default page size is 30, which can silently miss comments"). Specific reviewer-type handling (Copilot vs Human) explicit. |
| Coordination | 5 | composes_with: git-pr, git-commit — both exist locally and are accurate (PR feedback workflow chains: gh pr → review comments → commit fix). spawned_by empty (correct). owns correctly empty for a workflow that operates on remote API + local files. |
| Completeness | 5 | All workflow content self-contained. gh CLI commands include `--paginate` flag with WHY. Edge Cases section explicit (already-replied, outdated comments, multiple commits, no comments yet). Triage table comprehensive. Reply templates by category at L156-161 give concrete copy. |
| Anti-patterns | 5 | Triage guidelines at L85-92 explicitly say "Read the actual code the comment references before deciding. The diff context in the comment may be stale" — guards against acting on stale info. "Verify before acting" for Copilot. "Stage the changed files by name (not git add -p — interactive staging doesn't work in automated environments)" with WHY. No emojis. No excessive MUST/NEVER. |

**Average:** 5.00

## Findings

### Critical (must fix to ship)
- None.

### Important (should fix)
- None.

### Nits (won't block ship)
- `owns.shared_read: ["*"]` is a wildcard — SKILL.md:19 — consistent with sibling git skills; correct for a workflow that may need to read any file the reviewer commented on, so this nit is weakest here. Could narrow to repo-local explicit paths but not necessary.
- Description uses `>` folded scalar with line breaks that have no semantic meaning — SKILL.md:4-12 — stylistic consistency nit (same as other git/ skills).
- Step 6 reply commands at L147-153 use `{owner}/{repo}/{pr}` placeholders that aren't shell variables — could confuse users who paste-and-run. Consider noting "replace {owner}/{repo}/{pr} with actual values from `gh pr view --json`" or use shell variable substitution.
- L128 references "git-commit conventions" without a path — could be `[git-commit conventions](../git-commit/SKILL.md)` for clarity.
- Edge case "Already-replied comments" at L188 says "Skip any top-level comment that has a reply from the PR author" — slightly contradicts L68-70 in step 2 which uses `in_reply_to_id == <top_level_id>`. Same concept but inconsistent phrasing.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. **Add explicit cross-link to git-commit at L128** — SKILL.md:128 — change "commit following git-commit conventions" to "commit following [git-commit](../git-commit/SKILL.md) conventions". Effort: trivial.
2. **Clarify {owner}/{repo}/{pr} placeholder usage at L147-153** — SKILL.md:147-153 — add a note above the code block: "Substitute `{owner}/{repo}/{pr}` from `gh pr view --json url,number`; these are not shell variables." Effort: small.
3. **Normalize "already-replied comment" detection wording** — SKILL.md:68-70 and SKILL.md:188-189 — pick one phrasing and use both places. Effort: trivial.

## Dead links / broken references
- None. composes_with targets (git-pr, git-commit) both exist locally. No broken cross-references.
