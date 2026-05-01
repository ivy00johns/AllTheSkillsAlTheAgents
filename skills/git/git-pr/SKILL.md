---
name: git-pr
version: 1.2.0
description: >
  Guide for creating and updating GitHub pull requests in this repository:
  PR title format, body structure, clean descriptions, and the gh CLI workflow.
  Use when creating a pull request, writing a PR description, updating a PR,
  or preparing changes for review. Trigger on: "create a PR", "open a PR",
  "pull request", "PR description", "PR body", "ready for review",
  "gh pr create", "open pull request", "submit PR", "PR template".
  Also use proactively whenever you are about to run `gh pr create` —
  even if the user did not explicitly mention this skill.
requires_agent_teams: false
requires_claude_code: false
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed_tools: ["Read", "Bash"]
composes_with: ["git-commit", "git-pr-feedback"]
spawned_by: []
---

# GitHub Pull Request Conventions

## PR Title Format

```text
type: Short description of the change
```

- Use the same type conventions as git-commit (`feat`, `fix`, `docs`, etc.).
- Sentence case for the description (capital first letter, no trailing period).
- Keep it concise (under 70 characters is ideal).
- The description should summarize the *intent* of the whole PR, not list individual commits.

### Title examples

```text
feat: Add retry policy to HTTP client
fix: Handle null input in prompt builder
docs: Add platform comparison document
chore: Update skill frontmatter spec
```

---

## PR Body Structure

Use this template when writing the PR description. Adjust sections as needed
for the size and complexity of the change — small fixes may only need the summary.

```markdown
## Summary

<1–3 bullet points explaining what changed and why>

## Changes

<Grouped list of notable changes.>

## Test plan

<How was this tested? What should reviewers verify?>
```

### Body guidelines

- **Lead with the why.** Reviewers already have the diff — tell them what problem this solves.
- **Keep it scannable.** Bullet points and short paragraphs. No walls of text.
- **Mention risks.** If the change has migration steps or deployment ordering constraints, call them out.

---

## Workflow

### Creating a new PR

1. **Ensure the branch is pushed** with tracking set:

   ```bash
   git push -u origin HEAD
   ```

2. **Create the PR** using `gh pr create`. Pass the body via a HEREDOC to
   preserve formatting. Keep HEREDOC content flush-left so GitHub renders
   the markdown correctly:

   ```bash
   gh pr create --title "type: Description here" --body "$(cat <<'EOF'
   ## Summary

   - <what changed and why>

   ## Changes

   - <notable change 1>
   - <notable change 2>

   ## Test plan

   - [ ] <verification step>
   EOF
   )"
   ```

   Use `--base <branch>` if targeting a branch other than the repository default.

3. **Return the PR URL** to the user so they can review it.

### Updating an existing PR

```bash
gh pr edit {number} --title "type: Updated description"
gh pr edit {number} --body "$(cat <<'EOF'
…updated body…
EOF
)"
```

### Checking PR status

```bash
gh pr status          # overview of your PRs
gh pr view {number}   # details of a specific PR
gh pr checks {number} # CI check status
```

---

## Pre-Push Checklist

- [ ] PR title: `type: Description` (sentence case, under 70 chars)
- [ ] PR body has a Summary section explaining the why
- [ ] Test plan describes how to verify the change
- [ ] CI checks pass (or failures are understood and noted)
