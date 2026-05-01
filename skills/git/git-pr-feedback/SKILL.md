---
name: git-pr-feedback
version: 1.2.0
description: >
  Fetch, triage, and address PR review comments from GitHub Copilot and human
  reviewers. Use when the user asks to check PR feedback, review comments,
  address reviewer suggestions, or fix PR issues. Trigger on: "check PR
  comments", "what did copilot say", "address PR feedback", "fix review
  comments", "handle PR suggestions", "review feedback", "PR comments",
  "copilot review", "reviewer feedback", or any mention of responding to pull
  request comments. Also trigger when the user returns to a PR after some time
  and wants to handle accumulated feedback.
requires_agent_teams: false
requires_claude_code: false
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed_tools: ["Read", "Write", "Edit", "Bash", "Grep"]
composes_with: ["git-pr", "git-commit"]
spawned_by: []
---

# PR Feedback Handler

Fetch review comments on a GitHub PR, triage them, fix what's clear, ask about
what's ambiguous, and reply to each comment on GitHub with what was done.

## Workflow

### 1. Identify the PR

Determine the PR number from context:

```bash
# Current branch's PR
gh pr view --json number -q .number

# Or from a URL the user provided
# Or from a specific PR number they mentioned
```

### 2. Fetch All Comments

Pull both review comments (inline on code) and issue-level comments:

```bash
# Inline review comments (from Copilot and reviewers)
gh api --paginate repos/{owner}/{repo}/pulls/{pr}/comments

# General PR comments (not on specific lines)
gh api --paginate repos/{owner}/{repo}/issues/{pr}/comments

# Review summaries
gh api --paginate repos/{owner}/{repo}/pulls/{pr}/reviews
```

Use `--paginate` to ensure all comments are returned — the default page size
is 30, which can silently miss comments on large PRs.

Parse each comment to extract:

- **who**: `user.login` — distinguish `Copilot`, `copilot-pull-request-reviewer[bot]`, and human reviewers
- **where**: `path` and `line` — the file and line the comment targets
- **what**: `body` — the feedback text
- **id**: `id` — needed for replying
- **replied**: to detect already-handled comments, scan all comments for
  replies where `in_reply_to_id == <top_level_id>` and the reply author is
  the PR author.

### 3. Triage Each Comment

Classify every comment into one of these categories:

| Category | Action | Example |
|----------|--------|---------|
| **Bug** | Fix immediately | "This glob won't match broken symlinks" |
| **Improvement** | Fix if straightforward, ask if complex | "Exit code should be non-zero for errors" |
| **Doc issue** | Fix immediately | "The doc says X but the code does Y" |
| **Style/nit** | Fix if trivial, skip if subjective | "Consider renaming this variable" |
| **Noise/false positive** | Dismiss with explanation | "This is intentional because..." |
| **Ambiguous/tricky** | Present to user with options | "This could be fixed multiple ways..." |

**Triage guidelines:**

- Read the actual code the comment references before deciding. The diff context
  in the comment may be stale after pushes.
- Copilot comments are usually technically accurate but sometimes miss context.
  Verify before acting.
- Human reviewer comments carry more weight. Treat these as higher priority.
- If a comment suggests a significant design decision, always escalate to the user.

### 4. Present the Triage

Before making changes, show the user a summary:

```text
PR #34 — 3 review comments:

1. [BUG] Copilot on sync-skills.sh:426
   Broken symlink glob — --clean uses */ which skips broken symlinks
   → Will fix: change glob to /*

2. [IMPROVEMENT] Copilot on sync-skills.sh:101
   usage exits 0 on invalid options
   → Will fix: exit 1 for unknown options

3. [DOC] Copilot on SKILL.md:78
   Doc claims non-repo skills untouched but name collisions get replaced
   → Will fix: clarify the wording

Ready to fix all 3? Or want to discuss any of them?
```

For items classified as **ambiguous/tricky**, present the options and wait for
the user's decision before proceeding.

### 5. Implement Fixes

For each actionable comment:

1. Read the file at the referenced path and line
2. Make the fix
3. Stage the changed files by name (not `git add -p` — interactive staging
   doesn't work in automated environments)

After all fixes are applied, commit following git-commit conventions:

```bash
git add path/to/fixed-file1 path/to/fixed-file2
git commit -m "$(cat <<'EOF'
fix: address review feedback on {context}

{brief description of changes}
EOF
)"

git push
```

### 6. Reply to Comments on GitHub

For each comment, post a reply using the GitHub API:

```bash
# Reply to an inline review comment (threaded)
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies \
  -f body="Fixed in {sha} — {brief description of what changed}."

# Reply to a general PR comment (post a new issue comment)
gh api repos/{owner}/{repo}/issues/{pr}/comments \
  -f body="Re: {summary of original comment} — Fixed in {sha}."
```

Reply content by category:

- **Bug/Improvement/Doc**: "Fixed in {short sha} — {what changed}."
- **Noise/false positive**: "This is intentional — {reason}."
- **Style adopted**: "Good catch, fixed in {sha}."
- **Style declined**: "Keeping as-is — {reason}."

### 7. Check for New Comments

After pushing fixes, Copilot may generate new comments on the updated code.
Don't block waiting for them — let the user know they can ask to check again
later.

## Handling Specific Reviewer Types

### GitHub Copilot

- Copilot review is *requested* immediately when a PR is created or updated,
  but comments can take 30 seconds to several minutes to appear.
- Usually catches real issues: bugs, edge cases, doc inconsistencies.
- Sometimes suggests changes that miss project-specific context — verify first.
- May not comment at all on markdown-only or trivial PRs.

### Human Reviewers

- May not appear immediately — check back when the user asks.
- Comments may be conversational rather than prescriptive.
- Look for approval/changes-requested status in the reviews endpoint.
- If a reviewer requested changes, prioritize their comments.

## Edge Cases

- **Already-replied comments**: Skip any top-level comment that has a reply
  from the PR author (`in_reply_to_id` points back to the parent).
- **Outdated comments**: After pushing fixes, read the file fresh — don't
  trust the diff context in the comment.
- **Multiple commits**: Batch fixes into one commit unless the fixes are
  logically independent enough to warrant separate commits.
- **No comments yet**: If fetching after PR creation and getting zero comments,
  that's normal — let the user know and offer to check again later.
