# Work-item tracker — GitHub Issues

This repository uses **GitHub Issues** as the work-item tracker. Items are created, queried, and updated via the `gh` CLI.

## How agents create work items

```bash
gh issue create \
  --title "<short declarative title>" \
  --body "<intent + acceptance criteria>" \
  --label "<priority/type labels>"
```

The CLI returns an issue number (e.g., `#318`). Use that number when referring to the item from other artifacts.

## How agents query work items

```bash
gh issue list --state open
gh issue view <number>
gh issue list --label "ready" --state open    # filter for ready work
```

## How agents update status

GitHub does not have a built-in `in_progress` status. Use labels:

- `status:ready` — unblocked, available for an agent
- `status:in-progress` — agent has picked it up
- `status:blocked` — depends on another issue or external answer
- `status:done` — implementation complete, awaiting verification

```bash
gh issue edit <number> --add-label "status:in-progress" --remove-label "status:ready"
gh issue close <number>
```

## Brief workflow

When the `work-item-brief` skill produces a brief at `briefs/<slug>.md`, attach it to a GitHub issue:

```bash
gh issue create --title "..." --body "$(cat briefs/<slug>.md)" --label "status:ready"
```

The brief is the durable artifact; the GitHub issue is the trackable contract.

## How orchestrator should consume

When the orchestrator dispatches a multi-agent build, it should:

1. Query `gh issue list --label status:ready --state open`.
2. Pull the brief referenced by each ready issue (linked in the body) from `briefs/`.
3. Spawn role agents with the brief as context.
4. On agent completion, transition labels and/or close the issue via `gh issue edit` / `gh issue close`.

If `gh` is not authenticated locally, fail loud: "gh CLI not authenticated. Run `gh auth login` or re-run `/setup-project-skills` and pick a different tracker."
