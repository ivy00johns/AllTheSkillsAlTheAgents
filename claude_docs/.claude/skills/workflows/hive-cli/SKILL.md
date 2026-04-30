---
name: hive-cli
version: 0.3.0
description: >
  Use The Hive's running platform to manage work instead of just editing code.
  Trigger this skill when working in ~/Repos/the-hive-ecosystem/The-Hive and
  the user mentions: starting a build, work items, agent health, fleet status,
  tracker, doctor, merge queue, infrastructure checks, costs, audit trail,
  checkpointing, formulas, skill registry, quality gates, "check on the build",
  "create a work item", "what's the fleet doing", "is infra up", "run doctor",
  "dispatch work", "cook a formula", "how much has this cost", "is anything stuck",
  or any operational task that the platform CLI or REST API can handle.
  Also trigger when the user says "dogfood" or wants to use The Hive to manage
  its own development. This skill bridges the gap between "I have a running
  platform" and "use it" — reach for the CLI or REST API, not grep or todo lists.
---

# Working with The Hive Platform

You are working with a live, running instance of The Hive. The platform exposes
a CLI (`platform`) and a REST API (Fastify on port 4000). Use these for
operational tasks instead of manually editing databases or grepping the codebase.

## Prerequisites

The Fastify server must be running. Users typically start it with `pnpm serve`
(or `pnpm dev` for watch mode) in a separate terminal. If a CLI command fails
with a connection error, check whether the server is running first.

Infrastructure (Postgres, Dolt, Valkey, ClickHouse) must be up. Run `doctor`
if you haven't verified connectivity this session.

## Invocation

All CLI commands run from the repo root (`~/Repos/the-hive-ecosystem/The-Hive`):

```bash
pnpm exec platform <command> [subcommand] [options]
```

Global flags available on every command:
- `--json` — machine-readable JSON output (prefer when parsing results)
- `--verbose` — debug logging

When in doubt about a command's flags, run `pnpm exec platform <command> --help`.

---

## Common Workflows

### Verify infrastructure first

```bash
pnpm exec platform doctor
# or filter to a specific service:
pnpm exec platform doctor --category postgres   # postgres|dolt|valkey|clickhouse|all
```

If anything fails, suggest `pnpm infra:up` to start Docker containers.

---

### Start a build

The primary way to start work on The Hive:

```bash
# Create and start a build from a description
pnpm exec platform build start "Build user authentication with JWT" \
  --max-agents 5 \
  --cost-ceiling 5.00

# Follow events as the build runs
pnpm exec platform build start "Add webhook support" --follow

# Dry run to validate without executing
pnpm exec platform build start "..." --dry-run
```

Monitor and manage running builds:

```bash
pnpm exec platform build status <build-id>
pnpm exec platform build list --limit 10
pnpm exec platform build list --status running
pnpm exec platform build logs <build-id> --limit 100
pnpm exec platform build cancel <build-id>
pnpm exec platform build output <build-id>    # show output dir for completed builds
pnpm exec platform build clean --older-than 7 # clean up workspace dirs
```

---

### Manage work items (Cells / The Frame)

Work items are called **Cells**. The work graph lives in Dolt.

```bash
# Create
pnpm exec platform tracker create "Implement X" \
  --type task --priority 3 --description "Details here"

# List / filter
pnpm exec platform tracker list --status open
pnpm exec platform tracker list --type bug --assignee worker-1 --json
pnpm exec platform tracker ready --limit 10        # no blocked deps, ready to claim

# Inspect
pnpm exec platform tracker show <id>
pnpm exec platform tracker depends <id> --depth 5  # dependency tree

# Modify
pnpm exec platform tracker update <id> --status in_progress
pnpm exec platform tracker close <id> --reason "Done"

# Find and claim
pnpm exec platform tracker search "federation"
pnpm exec platform tracker claim <id> --agent worker-1
pnpm exec platform tracker release <id>

# Bulk operations
pnpm exec platform tracker export --format json --status open --output items.json
pnpm exec platform tracker import items.json
pnpm exec platform tracker compact --tier 1 --dry-run   # compact closed items
```

**Dependencies:**
```bash
pnpm exec platform tracker dep add <sourceId> <targetId> --type blocks
pnpm exec platform tracker dep remove <sourceId> <targetId>
pnpm exec platform tracker dep tree <id> --direction down
```

**Formulas** (templates that decompose into work molecules):
```bash
pnpm exec platform tracker formula list
pnpm exec platform tracker formula cook <name> --persist --var key=value
pnpm exec platform tracker formula pour <protoId> --var key=value
pnpm exec platform tracker formula wisp <protoId>   # ephemeral, no persistence
```

**Quality gates:**
```bash
pnpm exec platform tracker gate list --all
pnpm exec platform tracker gate check --dry-run
pnpm exec platform tracker gate resolve <gateId>
```

---

### Check the fleet (Workers)

```bash
pnpm exec platform fleet status --json
pnpm exec platform fleet spawn --role builder --build <id>
pnpm exec platform fleet kill <sessionId>
pnpm exec platform fleet pause <agentId>
pnpm exec platform fleet resume <agentId>
pnpm exec platform fleet metrics <agentId>    # tokens, cost, uptime
```

---

### Monitor health (Watchdog)

```bash
pnpm exec platform watchdog scan              # full 3-tier scan
pnpm exec platform watchdog stale             # list stale/stuck agents
pnpm exec platform watchdog cleanup <sessionId>  # kill tmux + remove worktree
```

---

### Dispatch work directly (Sling)

```bash
pnpm exec platform sling <work-id> --role builder --build <id>
pnpm exec platform sling <work-id> --to <agent-id>  # send to specific agent
```

---

### Track costs (The Yield)

```bash
pnpm exec platform costs --build <id> --json
pnpm exec platform costs project --days 7       # burn rate + projection
```

---

### Merge queue

```bash
pnpm exec platform merge status               # queue depth + active merge
pnpm exec platform merge list --status pending
pnpm exec platform merge show <mrId>          # full details + conflicts
pnpm exec platform merge submit <branch> --work-item <id>
pnpm exec platform merge process --all
pnpm exec platform merge stats                # conflict resolution history
```

**Convoys** (grouped merges):
```bash
pnpm exec platform convoy create "Sprint 5" --items id1,id2,id3
pnpm exec platform convoy list --status active
pnpm exec platform convoy launch <id>
pnpm exec platform convoy add <id> <item-id>
```

---

### Handoffs and checkpoints

Save agent context so work can be picked up later:

```bash
pnpm exec platform handoff save \
  --agent worker-1 --task <id> --summary "Finished auth, next: tests"
pnpm exec platform handoff list --agent worker-1
pnpm exec platform handoff load <id>          # prints continuation context
```

---

### Audit trail

```bash
pnpm exec platform audit query \
  --entity-type work_item --actor worker-1 --since 2026-04-01
pnpm exec platform audit trace <entityId>    # trace entity across all events
```

---

### Quality and inspection

```bash
pnpm exec platform quality gate <report-file>       # evaluate QA report
pnpm exec platform quality score                     # gate thresholds
pnpm exec platform quality slop <dir>                # scan for AI slop patterns
pnpm exec platform quality audit-run                 # scored design audit
pnpm exec platform quality browse <url> --a11y       # accessibility audit
pnpm exec platform quality eval <suite> --tier 2     # run eval suite
pnpm exec platform quality approval list --pending
pnpm exec platform quality approval approve <id> --notes "LGTM"
pnpm exec platform quality approval reject <id> --notes "Needs X"
```

---

### Skill registry (The Waggle)

```bash
pnpm exec platform skill list --role builder
pnpm exec platform skill register path/to/SKILL.md
pnpm exec platform skill show <name>
pnpm exec platform skill verify path/to/SKILL.md
pnpm exec platform skill scan path/to/SKILL.md
pnpm exec platform skill revoke <id>
```

---

### Federation (multi-instance sync)

```bash
pnpm exec platform federation list
pnpm exec platform federation status           # last sync time + pending counts
pnpm exec platform federation health           # per-peer health report
pnpm exec platform federation add <name> --remote <url> --sovereignty t2
pnpm exec platform federation sync --peer <id>
pnpm exec platform federation discover         # DNS SRV + static + PostgreSQL discovery
pnpm exec platform federation reputation       # agent reputation scores
pnpm exec platform federation gossip           # broadcast known peers
pnpm exec platform federation history --limit 50
```

---

### Alerting

```bash
pnpm exec platform alerting rules              # list all rules
pnpm exec platform alerting add-rule "stall-alert" \
  --type stall_timeout --threshold 300000 --severity warning --channel mail
# --type: stall_timeout | retry_exceeded | cost_exceeded | queue_depth | custom
pnpm exec platform alerting remove-rule <id>
pnpm exec platform alerting list --severity warning
pnpm exec platform alerting active             # unacknowledged only
pnpm exec platform alerting ack <id>
```

---

### Mail (inter-agent messaging)

```bash
pnpm exec platform mail send --to worker-1 --subject "Task ready" --body "See #42"
pnpm exec platform mail check --agent worker-1 --inject  # LLM-injectable format
pnpm exec platform mail list --agent worker-1 --unread
pnpm exec platform mail reply <id> --body "Acknowledged"
```

---

### Platform events and metrics

```bash
pnpm exec platform merge events --since 1h --limit 100
pnpm exec platform merge metrics --costs --build <id>
```

---

### Configuration and migration

```bash
pnpm exec platform config show
pnpm exec platform config set HIVE_PORT 4001
pnpm exec platform migrate up
pnpm exec platform migrate status
```

---

## REST API

When the CLI is inconvenient or you need structured data, hit the Fastify API
at `http://localhost:4000`. All routes use the `/api/v1` prefix except health.

```bash
curl -s http://localhost:4000/health | jq .
curl -s http://localhost:4000/api/v1/work?status=open | jq .
curl -s -X POST http://localhost:4000/api/v1/work \
  -H "Content-Type: application/json" \
  -d '{"title":"Fix X","type":"task","priority":3}'
```

**Key resource groups:**

| Resource | Notable endpoints |
|----------|-------------------|
| Health | `GET /health` |
| Work items | `GET/POST /work`, `/work/ready`, `/work/blocked`, `/work/:id`, `/work/:id/deps`; `POST /work/:id/claim`, `/work/:id/release`, `/work/:id/close` |
| Builds | `GET /builds/:id`; `POST /builds`, `/builds/start`, `/builds/:id/pause`, `/builds/:id/resume`, `/builds/:id/cancel` |
| Agents / Fleet | `GET /agents`, `/agents/:id`, `/fleet/status`; `POST /agents/:id/kill` |
| Metrics | `GET /metrics`, `/metrics/cost` |
| Mail | `GET /mail`, `/mail/:id`; `POST /mail`, `/mail/:id/read` |
| Merge | `GET /merge/queue`, `/merge/:id`; `POST /merge/submit`, `/merge/process` |
| Convoys | `GET /convoys`, `/convoys/:id`; `POST /convoys`; `PATCH /convoys/:id` |
| Watchdog | `GET /watchdog/scan`, `/watchdog/stale`; `POST /watchdog/cleanup/:id`, `/watchdog/zombie/:id` |
| Federation | `GET /federation/peers`, `/federation/history`; `POST /federation/peers`, `/federation/sync`; `DELETE /federation/peers/:id` |
| Alerts | `GET /alerts`, `/alerts/rules`, `/alerts/active`; `POST /alerts/rules`; `PUT /alerts/:id/acknowledge` |
| Audit | `GET /audit`, `/audit/entity/:type/:id`, `/audit/actor/:actor`, `/audit/trace/:id` |
| Approvals | `GET /approvals`, `/approvals/pending`, `/approvals/:id`; `POST /approvals`, `/approvals/:id/decide` |
| Contracts | `GET /contracts`, `/contracts/:id/compliance` |
| Events | `GET /events`; SSE: `/events/stream`, `/state/events`, `/ag-ui/events` |
| Formulas | `GET /formulas`; `POST /formulas/:name/cook`, `/formulas/:protoId/pour` |
| Gates | `GET /gates`; `POST /gates/check`, `/gates/:id/resolve` |
| Layouts | `GET/POST /layouts`; `PUT /layouts/:id`; `DELETE /layouts/:id` |
| Files | `GET /files/:agentId`, `/files/:agentId/:path` |

---

## When to Use What

| Situation | Use |
|-----------|-----|
| Check infra, run doctor | `platform doctor` |
| Start a build | `platform build start "..."` |
| Create / manage work items | `platform tracker ...` |
| Check fleet status | `platform fleet status --json` |
| Find stuck agents | `platform watchdog stale` |
| Track costs | `platform costs project --days 7` |
| Parse structured data | REST API with `curl ... \| jq` |
| Agent context / handoff | `platform handoff save/load` |
| Inspect audit history | `platform audit query` |
| User asks about code implementation | Read the source (not this skill) |
| User wants to add a CLI feature | Edit source code (not this skill) |

The core principle: if the user is asking about the *state* of the system (work
items, agents, health, costs, queue), reach for the CLI or API. If they're asking
about the *code* (how something works, adding a feature), read the source.

---

## Hive Vocabulary

| Concept | Hive Name |
|---------|-----------|
| Platform | The Hive |
| CLI | The Smoker |
| Dashboard | The Glass |
| Orchestrator | The Queen |
| Work item | Cell |
| Task graph | The Frame |
| Work graph store | The Comb (PostgreSQL) |
| Agent | Worker |
| Agent type | Caste |
| Event bus | The Airway (Valkey Streams) |
| Skill registry | The Waggle |
| Quality gates | Inspection |
| Cost metrics | The Yield |
| Audit traces | The Trail |
