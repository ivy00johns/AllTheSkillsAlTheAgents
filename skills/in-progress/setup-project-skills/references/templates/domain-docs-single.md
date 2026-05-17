# Domain docs — single-context layout

This repository uses a **single-context** domain doc layout. There is one product, one bounded context, and all domain knowledge lives at the repo root.

## File locations

- **`CONTEXT.md`** — at the repo root. The project's domain glossary. Each entry is a term, its meaning in this codebase, and an `_Avoid_:` list of forbidden synonyms. Owned by `maintain-context`.
- **`docs/adr/`** — at the repo root. Architecture Decision Records, numbered sequentially (`0001-title.md`, `0002-title.md`, ...). Owned by `maintain-context`.
- **`docs/agents/`** — at the repo root. Per-repo configuration consumed by Skill-Madness skills (this file lives here). Owned by `setup-project-skills`.

## What lives where

| Concern | File |
|---------|------|
| "What do we call this thing in this project?" | `CONTEXT.md` |
| "Why did we pick X over Y?" (hard-to-reverse) | `docs/adr/NNNN-title.md` |
| "What contract format does this repo use?" | `docs/agents/contract-format.md` |
| "Where do work items go?" | `docs/agents/work-item-tracker.md` |
| "How do I run / build / test?" | `README.md` or `CLAUDE.md` |

## How agents should read this

Any skill that needs to look up domain vocabulary or past decisions:

1. Read `CONTEXT.md` at the repo root for glossary entries.
2. Read `docs/adr/` for prior decisions when context is missing.

If `CONTEXT.md` or `docs/adr/` do not exist, do not create them eagerly. `maintain-context` creates them lazily, only when there is a real entry to capture.

## How to switch layouts

If this repo becomes a multi-context monorepo (e.g., `apps/` directory with multiple sibling projects), re-run `/setup-project-skills` and pick the multi-context option. This will rewrite `docs/agents/domain-docs.md` and you will need to migrate existing `CONTEXT.md` / `docs/adr/` content into the per-app locations manually.
