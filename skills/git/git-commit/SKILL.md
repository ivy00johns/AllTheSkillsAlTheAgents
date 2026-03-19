---
name: git-commit
version: 1.1.0
description: >
  Guide for creating git commits in this repository: conventional commit format,
  allowed types, and branch naming conventions.
  Use when staging changes and writing a commit message, creating a branch,
  or naming a branch. Trigger on: "commit", "create a commit", "git commit",
  "stage changes", "write a commit message", "make a commit", "branch name",
  "new branch", "create branch". Also use proactively whenever you are about
  to run `git commit` — even if the user did not explicitly mention this skill.
composes_with: ["git-pr", "git-branch-cleanup"]
---

# Git Commit Conventions

## Commit Message Format

```text
type: short description in imperative mood

Optional body paragraph.
```

- **No scope** — use `feat: add X`, not `feat(module): add X`.
- **Lowercase** type and description.
- **Imperative mood**: "add X", "fix Y", "remove Z" — not "added", "adding", "fixes".
- **No period** at the end.
- **Max ~72 characters** on the subject line.
- Optional body (blank line after subject): use for context, not mechanics.

### Allowed Types

| Type | When to use |
|---|---|
| `feat` | New feature or behaviour |
| `fix` | Bug fix |
| `test` | Adding or fixing tests only |
| `docs` | Documentation only |
| `refactor` | Code change with no feature/fix |
| `chore` | Build, tooling, config, deps |
| `build` | Build system changes |
| `perf` | Performance improvement |
| `style` | Formatting, whitespace — no logic change |
| `revert` | Reverts a previous commit |

### Examples

A complete commit with body:

```text
feat: add retry policy to HTTP client

Wrap outbound calls in a retry with exponential backoff so
transient failures from downstream services don't fail the request.
```

A minimal commit:

```text
fix: handle null input in prompt builder
```

Subject-only quick reference:

```text
test: add unit tests for retry backoff logic
chore: update dependencies
docs: document skill frontmatter spec
refactor: extract connection string builder to helper
```

---

## Branch Naming

```text
{type}/{short-description}
```

- Use the commit type directly (`feat`, `fix`, `chore`, etc.) — not expanded forms.
- Description uses hyphens to separate words, kept to 3–5 meaningful words.

### Branch Name Examples

```text
feat/add-query-meter-api
fix/api-client-retry-policy
chore/update-skill-frontmatter
docs/add-orchestrator-guide
```

---

## Merge Strategy

PRs merge with a **squash merge** by default unless the branch has a meaningful commit history worth preserving.

---

## Quick Checklist

- [ ] Subject line: `type: description` (lowercase, imperative, no scope, no period)
- [ ] Type is one of the allowed types above
- [ ] Optional body explains the *why*, not the *what*
- [ ] Branch: `type/short-description`
