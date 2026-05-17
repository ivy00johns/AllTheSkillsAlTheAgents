# Agent Spawning

The template, the permissions, and a worked example for spawning an implementation agent.

## Agent Prompt Template

Each agent receives ONLY what they need:

```text
You are the [ROLE] agent for this build.

## Your Ownership
- You own: [exact directories/files]
- Do NOT touch: [other agents' territories]
- Read-only: contracts/

## What You're Building
[Relevant plan excerpt — NOT the full plan]

## Contracts
### Shared Types (v1)
[Paste or reference]
### Contract You Produce (v1)
[The contract this agent implements]
### Contract You Consume (v1)
[The contract this agent depends on]

## Domain Rules
[Relevant business rules from contracts/README.md that this agent must enforce]

## Implementation Notes
[Per-agent guidance from contracts/README.md — libraries, patterns, framework specifics]

## Before Reporting Done
[Specific validation commands]
```

**Agent spawn permissions:** Spawn agents in a permission mode that allows file writes without per-tool prompts (in Claude Code, this is `mode: "auto"` on the Agent tool). Agents that cannot write files burn their entire context asking for permission instead of building.

## AFK / HITL Classification (required)

Every agent dispatch MUST declare whether it can finish unattended:

- **AFK (away-from-keyboard)** — the agent has everything it needs to complete its work without further input. No mid-flight clarifying questions, no permission stalls, no external secrets it can't read.
- **HITL (human-in-the-loop)** — the agent will pause at known checkpoints for a human. Document the checkpoints up front so the user knows when to expect a return.

Spawning without an explicit classification is forbidden (see Anti-Patterns in the main skill).

## Example: a filled-in backend-agent prompt

Here's what the template looks like in practice for a habit-tracker build. Notice how short the plan excerpt is — only the API/data sections, not the marketing copy or design system:

```text
You are the backend agent for the habit-tracker build.

## Your Ownership
- You own: src/api/, src/services/, src/models/, src/middleware/, .env.example
- Do NOT touch: src/components/, src/pages/, tests/ (qe agent owns)
- Read-only: contracts/

## What You're Building
Habit CRUD + JWT auth + streak calculation. Plan §3.2 (Habits API) and §3.4 (Auth).
Soft-delete only. Streaks reset at 04:00 in the user's timezone.

## Contracts
### Shared Types (v1)
See contracts/types.ts — Habit, User, AuthToken, ErrorEnvelope.
### Contract You Produce (v1)
contracts/api.openapi.yaml — implement exactly. URLs include trailing slashes.
### Contract You Consume (v1)
contracts/data-layer.yaml — Postgres via the Drizzle client in src/db/.

## Domain Rules
- Streak = consecutive days with ≥1 completion, computed in user TZ, reset at 04:00 local
- Soft-delete sets `deleted_at`; queries filter it out by default
- All timestamps stored UTC, returned ISO8601

## Implementation Notes
Express + Zod for validation. JWT in Authorization header. CORS origin from
ALLOWED_ORIGIN env var (verified against the Cloud Run config in Phase 0).

## Before Reporting Done
- `pnpm typecheck && pnpm test` clean
- `curl -i localhost:3000/api/habits/` returns 401 without auth, 200 with
- CORS preflight returns ALLOWED_ORIGIN, not `*`
```

The prompt is ~40 lines. The full plan was 12 pages. That ratio is the point — every line not relevant to the backend agent is noise that crowds out the work.
