# Work-item tracker — GitLab Issues

This repository uses **GitLab Issues** as the work-item tracker. Items are created, queried, and updated via the `glab` CLI.

## How agents create work items

```bash
glab issue create \
  --title "<short declarative title>" \
  --description "<intent + acceptance criteria>" \
  --label "<priority/type labels>"
```

The CLI returns an issue IID (e.g., `#318`). Use that IID when referring to the item from other artifacts.

## How agents query work items

```bash
glab issue list --state opened
glab issue view <iid>
glab issue list --label "ready" --state opened
```

## How agents update status

GitLab also uses labels rather than a built-in workflow state:

- `status::ready` — unblocked, available for an agent
- `status::in-progress` — agent has picked it up
- `status::blocked` — depends on another issue or external answer
- `status::done` — implementation complete, awaiting verification

```bash
glab issue update <iid> --label "status::in-progress" --unlabel "status::ready"
glab issue close <iid>
```

(GitLab scoped labels using `::` give mutually exclusive states. Prefer them over flat labels when the project already uses them.)

## Brief workflow

When the `work-item-brief` skill produces a brief at `briefs/<slug>.md`, attach it to a GitLab issue:

```bash
glab issue create --title "..." --description "$(cat briefs/<slug>.md)" --label "status::ready"
```

The brief is the durable artifact; the GitLab issue is the trackable contract.

## How orchestrator should consume

When the orchestrator dispatches a multi-agent build, it should:

1. Query `glab issue list --label status::ready --state opened`.
2. Pull the brief referenced by each ready issue (linked in the description) from `briefs/`.
3. Spawn role agents with the brief as context.
4. On agent completion, transition labels and/or close the issue via `glab issue update` / `glab issue close`.

If `glab` is not authenticated locally, fail loud: "glab CLI not authenticated. Run `glab auth login` or re-run `/setup-project-skills` and pick a different tracker."
