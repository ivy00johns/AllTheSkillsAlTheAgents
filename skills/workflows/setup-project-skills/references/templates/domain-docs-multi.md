# Domain docs — multi-context monorepo layout

This repository is a **multi-context monorepo**. Each app under `apps/` (or `packages/`, or `services/`) has its own bounded context, its own vocabulary, and its own decision history.

## File locations

- **`apps/<app>/CONTEXT.md`** — per-app domain glossary. Each app maintains its own.
- **`apps/<app>/docs/adr/`** — per-app Architecture Decision Records. Numbered locally within each app.
- **`docs/agents/`** — at the repo root. Per-repo configuration consumed by Skill-Madness skills (this file lives here). Shared across all apps.
- **`CONTEXT.md`** (root, optional) — only for terms that are shared across **every** app in the monorepo. Keep it short. If a term only applies to one app, it does not belong here.

## What lives where

| Concern | File |
|---------|------|
| App-specific vocabulary | `apps/<app>/CONTEXT.md` |
| App-specific decisions | `apps/<app>/docs/adr/NNNN-title.md` |
| Monorepo-wide vocabulary (rare) | `CONTEXT.md` at repo root |
| Contract format, tracker, agent config | `docs/agents/` at repo root |

## How agents should read this

When a skill operates on a specific app:

1. Read `apps/<app>/CONTEXT.md` first.
2. Fall back to root `CONTEXT.md` if the term is not found at the app level.
3. Read `apps/<app>/docs/adr/` for prior decisions scoped to that app.

When a skill operates across the monorepo, it reads only the root `CONTEXT.md` and may consult per-app `CONTEXT.md` files as needed.

## App naming convention

Replace `<app>` with the app directory name as it appears under `apps/`. Examples: `apps/web/CONTEXT.md`, `apps/api/CONTEXT.md`, `apps/worker/docs/adr/0001-event-sourcing.md`.

If the monorepo uses `packages/` or `services/` instead of `apps/`, substitute that prefix throughout. The pattern is the same — per-context glossary and ADR directory live next to the code they describe.
