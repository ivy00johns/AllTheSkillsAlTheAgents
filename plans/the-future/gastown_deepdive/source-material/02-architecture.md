# 02 — Architecture

## The Three Planes

Gas Town has three architectural layers:

```
┌─────────────────────────────────────────────┐
│  Control Plane: gt CLI + daemon             │
│  (Cobra commands, tmux management, patrol   │
│   loops, session lifecycle)                 │
├─────────────────────────────────────────────┤
│  Data Plane: Beads (bd CLI) + Dolt          │
│  (Issues, molecules, hooks, mail, agents,   │
│   identity — all in Git-backed SQL)         │
├─────────────────────────────────────────────┤
│  Execution Plane: Claude Code sessions      │
│  (tmux panes, prompted roles, GUPP-driven)  │
└─────────────────────────────────────────────┘
```

## Directory Structure

```
~/gt/                           Town root (HQ)
├── .beads/                     Town-level beads (hq-* prefix)
│   ├── metadata.json           Beads config (dolt_mode, dolt_database)
│   └── routes.jsonl            Prefix → rig routing table
├── .dolt-data/                 Centralized Dolt data directory
│   ├── hq/                     Town beads database
│   ├── gastown/                Gastown rig database (gt-*)
│   ├── beads/                  Beads rig database (bd-*)
│   └── <other-rigs>/           Per-rig databases
├── daemon/                     Daemon runtime state
│   ├── dolt-state.json         Dolt server state (pid, port, databases)
│   ├── dolt-server.log         Server log
│   └── dolt.pid                Server PID file
├── deacon/                     Deacon workspace
│   └── dogs/<name>/            Dog worker directories
├── mayor/                      Mayor agent home
│   ├── town.json               Town configuration
│   ├── rigs.json               Rig registry
│   ├── daemon.json             Daemon patrol config
│   ├── accounts.json           Claude Code account management
│   └── wasteland.json          Wasteland federation config
├── settings/                   Town-level settings
│   ├── config.json             Agent presets, themes
│   └── escalation.json         Escalation routes
├── config/
│   └── messaging.json          Mail lists, queues, channels
└── <rig>/                      Project container (NOT a git clone)
    ├── config.json             Rig identity and beads prefix
    ├── mayor/rig/              Canonical clone (beads live here)
    │   └── .beads/             Rig-level beads (redirected to Dolt)
    ├── refinery/               Refinery agent home
    │   └── rig/                Worktree from mayor/rig
    ├── witness/                Witness agent home (no clone)
    ├── crew/                   Crew parent
    │   └── <name>/             Human workspaces (full clones)
    └── polecats/               Polecats parent
        └── <name>/<rigname>/   Worker worktrees from mayor/rig
```

## Two-Tier Beads Architecture

| Level | Location | Prefix | Purpose |
|-------|----------|--------|---------|
| **Town** | `~/gt/.beads/` | `hq-*` | Cross-rig coordination, Mayor mail, agent identity |
| **Rig** | `<rig>/mayor/rig/.beads/` | project prefix | Implementation work, MRs, project issues |

All beads data is stored in a single **Dolt SQL Server** per town (port 3307).
There is no embedded Dolt fallback. The daemon monitors and auto-restarts the
server on crash.

### Cross-Rig Routing

`routes.jsonl` maps bead ID prefixes to rig locations:

```jsonl
{"prefix":"hq-","path":"."}
{"prefix":"gt-","path":"gastown/mayor/rig"}
{"prefix":"bd-","path":"beads/mayor/rig"}
```

This enables transparent cross-rig operations: `bd show gt-xyz` automatically
routes to the gastown rig's beads database.

### Beads Redirects

Worktrees (polecats, refinery, crew) don't have their own beads databases.
They use `.beads/redirect` files pointing to the canonical location:

```
polecats/alpha/.beads/redirect → ../../mayor/rig/.beads
```

## Storage: Dolt SQL Server

All beads data lives in a single Dolt SQL Server process per town:

```
┌─────────────────────────────────┐
│  Dolt SQL Server (per town)     │
│  Port 3307, managed by daemon   │
│  Data: ~/gt/.dolt-data/         │
└──────────┬──────────────────────┘
           │ MySQL protocol
    ┌──────┼──────┬──────────┐
    │      │      │          │
  USE hq  USE gastown  USE beads  ...
```

Write concurrency: agents write directly to `main` using transaction discipline
(`BEGIN` / `DOLT_COMMIT` / `COMMIT` atomically).

### Data Lifecycle

```
CREATE → LIVE → CLOSE → DECAY → COMPACT → FLATTEN
  │        │       │        │        │          │
  Dolt   active   done   DELETE   REBASE     SQUASH
  commit  work    bead    rows    commits    all history
                         >7-30d  together   to 1 commit
```

## The `gt` CLI

103 non-test command files under `internal/cmd/`. Built on Cobra. Key commands:

### Workspace Management
- `gt install` — Initialize workspace
- `gt rig add/list/remove` — Manage project rigs
- `gt crew add` — Create crew workspace
- `gt up/down` — Start/stop the town

### Agent Operations
- `gt agents` — List active agents
- `gt sling` — Assign work to an agent (the fundamental primitive)
- `gt nudge` — Send real-time tmux message to an agent
- `gt mail` — Persistent mail system (inbox, send, read)
- `gt prime` — Context recovery after compaction/restart
- `gt handoff` — Graceful session restart with work transfer
- `gt seance` — Talk to previous sessions via `/resume`
- `gt hook` — Check what's on an agent's hook
- `gt done` — Complete polecat work (push, submit MR, nuke sandbox)

### Convoy Operations
- `gt convoy create/list/show/add` — Work tracking units
- `gt convoy launch` — Start a convoy with automatic polecat spawning

### Patrol Operations
- `gt patrol new/report` — Create and complete patrol cycles
- `gt daemon` — Start the daemon that pings the Deacon

### Molecules
- `gt mol attach/detach` — Pin/unpin molecules to beads
- `gt formula` — Formula management

### Infrastructure
- `gt dashboard` — Web dashboard (htmx-based)
- `gt feed` — TUI activity dashboard (Charmbracelet)
- `gt doctor` — Health diagnostics
- `gt dolt` — Dolt server management
- `gt config` — Agent presets and settings
- `gt worktree` — Cross-rig worktree management

### The Wasteland
- `gt wl join/browse/claim/done/post/sync` — Federation commands

## Internal Package Map

65 packages under `internal/`:

| Package | Purpose |
|---------|---------|
| `cmd/` | All CLI command implementations (365 files) |
| `agent/` | Agent identity and lifecycle |
| `beads/` | Beads integration layer |
| `convoy/` | Convoy tracking and management |
| `crew/` | Crew member management |
| `daemon/` | Daemon process, heartbeats |
| `deacon/` | Deacon patrol logic |
| `dog/` | Dog worker management |
| `formula/` | Formula parsing, cooking, protomolecules |
| `feed/` | TUI activity feed (Charmbracelet) |
| `hooks/` | Hook management (GUPP) |
| `mail/` | Mail system |
| `mayor/` | Mayor agent logic |
| `mq/` | Merge queue (batch-then-bisect) |
| `nudge/` | Nudge messaging system |
| `polecat/` | Polecat lifecycle and management |
| `refinery/` | Refinery patrol and merge processing |
| `rig/` | Rig management |
| `runtime/` | Agent runtime abstraction (Claude, Codex, Gemini, etc.) |
| `session/` | Session management |
| `tmux/` | tmux integration |
| `wasteland/` | Wasteland federation |
| `web/` | Web dashboard |
| `wisp/` | Ephemeral beads |
| `witness/` | Witness patrol logic |
| `workspace/` | Workspace detection and management |

Plus: `activity/`, `boot/`, `channelevents/`, `checkpoint/`, `cli/`,
`config/`, `connection/`, `constants/`, `doltserver/`, `events/`, `git/`,
`health/`, `hookutil/`, `keepalive/`, `krc/`, `lock/`, `plugin/`,
`protocol/`, `proxy/`, `quota/`, `reaper/`, `scheduler/`, `shell/`,
`state/`, `style/`, `suggest/`, `telemetry/`, `templates/`, `testutil/`,
`townlog/`, `tui/`, `ui/`, `util/`, `version/`, `wrappers/`.
