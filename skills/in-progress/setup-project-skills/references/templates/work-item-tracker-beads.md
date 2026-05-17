# Work-item tracker — Beads

This repository uses **Beads** as the work-item tracker. Work items live in the `bd` graph database and are created, queried, and updated via the `bd` CLI.

## How agents create work items

```bash
bd issue create \
  --title "<short declarative title>" \
  --description "<intent + acceptance criteria>" \
  --priority <0|1|2|3> \
  --type <bug|feature|chore|epic>
```

The CLI returns a work-item ID (e.g., `bd-318`). Use that ID when referring to the item from other artifacts.

## How agents query work items

```bash
bd issue list --status open
bd issue show <id>
bd issue ready                 # work items with all dependencies resolved
```

## How agents update status

```bash
bd issue update <id> --status in_progress
bd issue update <id> --status done
bd issue close <id>            # only when fully complete and verified
```

## Brief workflow

When the `work-item-brief` skill produces a brief at `briefs/<slug>.md`, link it to a Beads issue:

```bash
bd issue create --title "..." --description "$(cat briefs/<slug>.md)" --priority 2
```

The brief is the durable artifact; the Beads issue is the trackable contract (status, owner, deadline).

## How orchestrator should consume

When the orchestrator dispatches a multi-agent build, it should:

1. Query `bd issue ready` for unblocked work.
2. Pull the brief referenced by each ready issue from `briefs/`.
3. Spawn role agents with the brief as context.
4. On agent completion, update the issue status via `bd issue update`.

If `bd` is not installed locally, fail loud: "Beads CLI not found. Install `bd` or re-run `/setup-project-skills` and pick a different tracker."
