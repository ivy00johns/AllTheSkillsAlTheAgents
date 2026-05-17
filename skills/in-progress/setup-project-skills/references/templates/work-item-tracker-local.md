# Work-item tracker — local markdown

This repository tracks work items as **local markdown files**. No external tracker. The filesystem is the database.

## File locations

- **Open work:** `tasks/open/<short-slug>.md`
- **In progress:** `tasks/in-progress/<short-slug>.md`
- **Done (archived):** `tasks/done/<YYYY-MM>/<short-slug>.md`
- **Briefs:** `briefs/<short-slug>.md` (durable artifact; see `work-item-brief`)

A task file may be a thin pointer to a brief, or it may contain the full intent + acceptance criteria inline for very small items.

## File format

Every task file has YAML frontmatter:

```markdown
---
id: <short-slug>
title: <one-line declarative title>
priority: <P0|P1|P2|P3>
status: <ready|in-progress|blocked|done>
brief: briefs/<short-slug>.md   # optional pointer
---

# <title>

<intent + acceptance criteria, or "See brief.">
```

## How agents move work through states

Status is encoded in the directory, not the frontmatter. To move a task forward, **move the file**:

```bash
mv tasks/open/<slug>.md tasks/in-progress/<slug>.md
mv tasks/in-progress/<slug>.md tasks/done/$(date +%Y-%m)/<slug>.md
```

Keep the frontmatter `status` field in sync with the directory. Two sources of truth invite drift; the directory wins on conflict.

## How orchestrator should consume

When the orchestrator dispatches a multi-agent build:

1. List `tasks/open/*.md` for ready work.
2. Read each file (and the linked brief, if any) for context.
3. Move the file to `tasks/in-progress/` before spawning the agent.
4. On agent completion, move to `tasks/done/<YYYY-MM>/`.

## Forbidden patterns

- Do not delete completed task files. Archiving to `tasks/done/` preserves the work history.
- Do not let `status:` frontmatter and the directory disagree. If you see drift, the directory location is canonical.
- Do not nest sub-tasks inside a single file beyond a checklist. If a sub-task deserves its own status, give it its own file.
