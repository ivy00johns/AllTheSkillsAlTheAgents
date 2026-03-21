---
name: hive-cli
version: 0.2.0
description: >
  Use The Hive's running platform to manage work instead of just editing code.
  Trigger this skill when working in ~/AI/The-Hive and the user mentions work items,
  build status, agent health, fleet, tracker, doctor, merge queue, infrastructure
  checks, "check on the build", "create a work item", "what's the fleet doing",
  "is infra up", "run doctor", or any operational task that the platform CLI or
  REST API can handle. Also trigger when the user says "dogfood" or wants to use
  The Hive to manage its own development. This skill bridges the gap between
  "I have a running platform" and "use it" — Claude should reach for the CLI
  or REST API, not grep the codebase or create a todo.
---

# Working with The Hive Platform

You are working on a live, running instance of The Hive. The platform has a CLI
(`platform`) and a REST API (Fastify on port 4000) that you should use for
operational tasks instead of manually editing databases or grepping code.

## Prerequisites

The Fastify server must be running. The user typically starts it in a separate
terminal with `pnpm serve` (or `pnpm dev` for watch mode). If a CLI command
fails with a connection error, remind the user to start the server.

Infrastructure (Postgres, Dolt, Valkey, ClickHouse) must be up. Always run
doctor first if you haven't verified infra this session.

## Invocation

All CLI commands run from the repo root (`~/AI/The-Hive`):

```bash
pnpm exec platform <command> [subcommand] [options]
```

Global options available on every command:
- `--json` — machine-readable JSON output (prefer this when parsing results)
- `--verbose` — debug logging

## Core Workflow

When the user wants to do operational work, follow this sequence:

### 1. Verify infrastructure

```bash
pnpm exec platform doctor
```

Checks Postgres, Dolt, Valkey, and ClickHouse connectivity. If anything fails,
suggest `pnpm infra:up` to start Docker containers.

### 2. Manage work items (The Frame)

Work items are called **Cells**. The work graph lives in Dolt.

```bash
# Create a work item
pnpm exec platform tracker create \
  --title "Implement X" \
  --type task \
  --priority 3 \
  --description "Details here"

# List work items (with optional filters)
pnpm exec platform tracker list --status open
pnpm exec platform tracker list --type task --json

# Show a specific item
pnpm exec platform tracker show <id>

# Update fields
pnpm exec platform tracker update <id> --status in_progress
pnpm exec platform tracker update <id> --assignee "agent-name"

# Close a completed item
pnpm exec platform tracker close <id>

# Search by keyword
pnpm exec platform tracker search "federation"

# See what's ready to work on (no blocked dependencies)
pnpm exec platform tracker ready

# Claim/release items for an agent
pnpm exec platform tracker claim <id> --agent "agent-name"
pnpm exec platform tracker release <id>
```

**Dependencies:**
```bash
pnpm exec platform tracker dep add <from> <to> --type blocks
pnpm exec platform tracker dep remove <from> <to>
pnpm exec platform tracker dep tree <id>
```

**Quality gates:**
```bash
pnpm exec platform tracker gate list <id>
pnpm exec platform tracker gate check <id>
pnpm exec platform tracker gate resolve <id> --gate <gate-type> --pass
```

### 3. Check the fleet (Workers)

```bash
# Overview of all agents
pnpm exec platform fleet status
pnpm exec platform fleet status --json

# Spawn a new agent session
pnpm exec platform fleet spawn --role <role> --work-item <id>

# Kill a session
pnpm exec platform fleet kill <sessionId>
```

### 4. Monitor health (Watchdog — Phase 6)

```bash
# Scan all agents for health
pnpm exec platform watchdog scan
pnpm exec platform watchdog scan --json

# List stale/stuck agents
pnpm exec platform watchdog stale

# Force-cleanup a stuck session (kills tmux + removes worktree)
pnpm exec platform watchdog cleanup <sessionId>
```

### 5. Merge queue

```bash
pnpm exec platform merge queue          # See pending merges
pnpm exec platform merge submit <id>    # Submit work item for merge
pnpm exec platform merge process        # Process next in queue
pnpm exec platform merge stats          # Queue statistics
```

### 6. Federation (Phase 6)

```bash
pnpm exec platform federation list                    # List peers
pnpm exec platform federation add <name> --remote <url> --tier t2
pnpm exec platform federation remove <id>
pnpm exec platform federation sync --peer <id>
pnpm exec platform federation history
```

### 7. Alerting (Phase 6)

```bash
pnpm exec platform alerting rules                     # List alert rules
pnpm exec platform alerting add-rule <name> --condition ... --severity warning
pnpm exec platform alerting list                      # List fired alerts
pnpm exec platform alerting active                    # Currently active
pnpm exec platform alerting ack <id>                  # Acknowledge
```

## REST API Alternative

When the CLI is inconvenient or you need structured responses, hit the REST API
directly. The server runs on `http://localhost:4000` by default (override with
`HIVE_PORT`). All routes are under the `/api/v1` prefix.

**Key endpoints** (all prefixed with `/api/v1` except health):

| Resource | GET | POST | Other |
|----------|-----|------|-------|
| Health | `/health` (root, no prefix) | | |
| Work items | `/work`, `/work/ready`, `/work/blocked`, `/work/:id`, `/work/:id/deps` | `/work` (create), `/work/deps`, `/work/import` | POST `/work/:id/close`, `/work/:id/claim`, `/work/:id/release` |
| Builds | `/builds/:id` | `/builds` (create), `/builds/start` | POST `/builds/:id/pause`, `/builds/:id/resume`, `/builds/:id/cancel` |
| Agents | `/agents`, `/agents/:id`, `/fleet/status` | | POST `/agents/:id/kill` |
| Metrics | `/metrics`, `/metrics/cost` | | |
| Mail | `/mail`, `/mail/:id` | `/mail` (send) | POST `/mail/:id/read` |
| Merge | `/merge/queue`, `/merge/:id` | `/merge/submit`, `/merge/process` | |
| Convoys | `/convoys`, `/convoys/:id` | `/convoys` | PATCH `/convoys/:id` |
| Watchdog | `/watchdog/scan`, `/watchdog/stale` | POST `/watchdog/cleanup/:sessionId`, `/watchdog/zombie/:sessionId` | |
| Federation | `/federation/peers`, `/federation/history` | `/federation/peers`, `/federation/sync` | DELETE `/federation/peers/:id` |
| Alerts | `/alerts`, `/alerts/rules`, `/alerts/active` | `/alerts/rules` | PUT `/alerts/:id/acknowledge` |
| Audit | `/audit`, `/audit/entity/:type/:id`, `/audit/actor/:actor`, `/audit/trace/:id` | | |
| Approvals | `/approvals`, `/approvals/pending`, `/approvals/:id` | `/approvals`, POST `/approvals/:id/decide` | |
| Contracts | `/contracts`, `/contracts/:id/compliance` | | |
| Events | `/events`, `/events/stream` (SSE) | | |
| State | `/state/events` (SSE), `/state/metrics/costs`, `/state/metrics/agent/:name` | | |
| Formulas | `/formulas` | POST `/formulas/:name/cook`, `/formulas/:protoId/pour` | |
| Gates | `/gates` | POST `/gates/check`, `/gates/:id/resolve` | |
| Layouts | `/layouts` | `/layouts` | PUT `/layouts/:id`, DELETE `/layouts/:id` |
| Files | `/files/:agentId`, `/files/:agentId/:path` | | |
| Workload | `/workload` | | |
| AG-UI | `/ag-ui/events` (SSE) | | |

Example using curl:
```bash
curl -s http://localhost:4000/health | jq .
curl -s http://localhost:4000/api/v1/work?status=open | jq .
curl -s -X POST http://localhost:4000/api/v1/work \
  -H "Content-Type: application/json" \
  -d '{"title":"Fix X","type":"task","priority":3}'
```

## When to Use CLI vs. REST vs. Code

| Situation | Use |
|-----------|-----|
| User says "check infra" / "run doctor" | CLI: `platform doctor` |
| User says "create a work item for X" | CLI: `platform tracker create ...` |
| User says "what's the fleet doing" | CLI: `platform fleet status --json` |
| User says "is anything stuck" | CLI: `platform watchdog stale` |
| You need to parse structured data | REST API with `curl ... | jq` |
| User asks about code implementation | Read the source code (not this skill) |
| User wants to add a feature to the CLI | Edit source code (not this skill) |

The key insight: if the user is asking about the *state* of the system (work items,
agents, health, queue), reach for the CLI or API. If they're asking about the *code*
(how something is implemented, adding a feature), read the source.

## Hive Vocabulary

Use these names when talking about platform concepts:

| Concept | Hive Name |
|---------|-----------|
| Platform | The Hive |
| CLI | The Smoker |
| Work item | Cell |
| Task graph | The Frame |
| Agent | Worker |
| Agent type | Caste |
| Event bus | The Airway |
| Dashboard | The Glass |
| Quality gates | Inspection |

## What's Implemented (as of Phase 6)

All 18 CLI command groups are functional: tracker, fleet, merge, convoy, sling,
skill, contract, quality, prime, checkpoint, deploy, mail, config, doctor,
migrate, serve, federation, watchdog, alerting, audit.

The platform builds itself from Phase 3 onward — it's dogfood all the way down.
