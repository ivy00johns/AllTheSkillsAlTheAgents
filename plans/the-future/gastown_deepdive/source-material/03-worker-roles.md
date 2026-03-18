# 03 — Worker Roles

Gas Town has 7 agent roles plus the human Overseer. Each role is defined by a
**Role Bead** (global template stored with `hq-` prefix) and instantiated as
**Agent Beads** (per-worker identity).

## Role Taxonomy

### Town-Level Roles (Cross-Rig)

| Role | Count | Lifecycle | Identity |
|------|-------|-----------|----------|
| Mayor | 1 per town | Persistent | `hq-mayor` |
| Deacon | 1 per town | Persistent | `hq-deacon` |
| Dogs | N per town | Ephemeral tasks | `hq-dog-<name>` |
| Boot | 1 special Dog | Ephemeral (5m ticks) | `hq-boot` |

### Rig-Level Roles (Per-Project)

| Role | Count | Lifecycle | Identity |
|------|-------|-----------|----------|
| Witness | 1 per rig | Persistent | `<prefix>-<rig>-witness` |
| Refinery | 1 per rig | Persistent | `<prefix>-<rig>-refinery` |
| Polecats | N per rig | Persistent identity, ephemeral sessions | `<prefix>-<rig>-polecat-<name>` |
| Crew | N per rig | Persistent, user-managed | `<prefix>-<rig>-crew-<name>` |

### The Overseer (Role 8)

That's you. You have an identity in the system, your own inbox, and can send
and receive town mail. You're the boss.

---

## The Mayor

**Purpose:** Chief-of-staff. Primary human-facing agent. Coordinates work
distribution, kicks off convoys, receives completion notifications.

**Key behaviors:**
- Initiates convoys from user requests
- Slings work to polecats
- Monitors convoy progress
- Handles cross-rig coordination
- Operates from `~/gt/mayor/`

**Interface:** `gt mayor attach` / `gt mayor start`

**Prompt context:** Injected by `gt prime` at session start via Claude Code
SessionStart hook. Role templates are embedded in the `gt` binary
(see `internal/templates/`).

---

## Polecats

**Purpose:** Ephemeral worker agents. The workhorses of Gas Town. They
receive work, do it, submit a Merge Request, and die.

**Key distinction:** Persistent *identity*, ephemeral *sessions*. A polecat
named "alpha" accumulates a CV chain across assignments. But each assignment
is a fresh Claude Code session in a fresh git worktree.

**Lifecycle:**

```
spawning → working → mr_submitted → awaiting_verdict
                                          │
                          ┌───────────────┴───────────────┐
                          ▼                               ▼
                    FIX_NEEDED                          MERGED
                          │                               │
                    (fix & resubmit)                  (gt done → gone)
                          │
                    awaiting_verdict (loop)
```

**Work assignment:** Via `gt sling <bead-id> <rig>`. Work goes on their hook.
They follow the `mol-polecat-work` formula (10 steps from load-context through
self-clean).

**Workflow options:**
- `mol-polecat-work` — Base workflow (load, branch, implement, review, test, submit)
- `shiny` — "Engineer in a Box" (design → implement → review → test → submit)
- `shiny-secure` — Adds security audit step
- `shiny-enterprise` — Maximum ceremony workflow

**Git:** Work in isolated worktrees from `mayor/rig`. Push to feature branches.
Never push to main — the Refinery handles merging.

**Cleanup:** `gt done` nukes the worktree and exits the session.

---

## The Refinery

**Purpose:** Manages the Merge Queue (MQ) for each rig. Intelligently merges
polecat work to main, one at a time, handling conflicts.

**Merge strategy:** Batch-then-bisect (Bors-style):

```
MRs waiting:  [A, B, C, D]
                    ↓
Batch:        Rebase A..D as a stack on main
                    ↓
Test tip:     Run tests on D (tip of stack)
                    ↓
If PASS:      Fast-forward merge all 4 → done
If FAIL:      Binary bisect → test B (midpoint)
                    ↓
              If B passes: C or D broke it → bisect [C,D]
              If B fails:  A or B broke it → bisect [A,B]
```

**Patrol formula:** `mol-refinery-patrol` — preflight cleanup, process MQ,
post-flight handoff.

**Key commands:** `gt mq submit`, `gt mq list`, `gt mq process`

**Escalation:** If a polecat's MR fails 3 times, the Refinery sends a
FIX_NEEDED message. If that exceeds the retry limit, it escalates to the
Witness.

---

## The Witness

**Purpose:** Per-rig supervisor that monitors polecats and the refinery.
Detects stuck agents and triggers recovery.

**Responsibilities:**
- Monitor polecat health (detect stuck, zombie, GUPP violations)
- Nudge unresponsive polecats
- Check refinery is processing the MQ
- Peek at the Deacon's health
- Run rig-level plugins

**Patrol formula:** `mol-witness-patrol`

**Key distinction:** The Witness observes but does NOT gate polecat completion.
Polecats self-manage their lifecycle. This prevents the Witness from becoming
a bottleneck.

---

## The Deacon

**Purpose:** The daemon beacon. Town-level watchdog that ensures everything
stays running. Runs continuous patrol cycles triggered by the daemon.

**Named after:** Dennis Hopper's character from Waterworld (which was inspired
by Lord Humungus from Mad Max — making it a crossover).

**Responsibilities:**
- Receive heartbeats from the daemon
- Propagate "Do Your Fucking Job" (DYFJ) signal downward
- Run town-level plugins
- Manage session recycling and handoff protocol
- Coordinate worker cleanup

**Patrol formula:** `mol-deacon-patrol`

**Delegation:** Complex work gets delegated to Dogs to keep the Deacon
focused on its patrol loop.

---

## Dogs

**Purpose:** The Deacon's personal crew. Handle maintenance, cleanup,
health checks, and infrastructure tasks.

**Named after:** Mick Herron's MI5 "Dogs" from the Slow Horses universe.

**Key Dogs:**
- **Boot** — Special dog awakened every 5 minutes by the daemon to check on
  the Deacon. Decides if the Deacon needs a heartbeat, nudge, restart, or
  to be left alone.

**Not workers:** Dogs are NOT project workers. They do infrastructure tasks
for the Deacon. For project work, use Crew or Polecats.

**Dog formulas:**
- `mol-dog-backup` — Dolt database backup
- `mol-dog-compactor` — Data compaction
- `mol-dog-doctor` — Health diagnostics
- `mol-dog-jsonl` — JSONL maintenance
- `mol-dog-phantom-db` — Phantom database cleanup
- `mol-dog-reaper` — Stale data reaping
- `mol-dog-stale-db` — Stale database cleanup

---

## The Crew

**Purpose:** Long-lived, named agents for persistent collaboration. Your
direct replacements for raw Claude Code sessions.

**Key differences from Polecats:**

| Aspect | Crew | Polecat |
|--------|------|---------|
| Lifecycle | Persistent (user controls) | Transient (Witness controls) |
| Monitoring | None | Witness watches |
| Work assignment | Human-directed | Slung via `gt sling` |
| Git state | Full clones, push to main directly | Worktrees, branch → Refinery merges |
| Cleanup | Manual | Automatic on completion |
| Best for | Design work, exploration, long-running | Discrete, well-defined tasks |

**tmux navigation:** `C-b n/p` cycles through crew members in a rig.

**Cross-rig work:** Crew can work cross-rig via `gt worktree <rig>`, which
creates a worktree in the target rig while preserving identity attribution.

---

## Supervision Hierarchy

```
Overseer (You)
    │
    ├── Mayor ──────────────── Convoys, coordination
    │
    ├── Deacon ─────────────── Town-level watchdog
    │   ├── Boot ────────────── Checks on Deacon
    │   └── Dogs ────────────── Infrastructure tasks
    │
    └── Per-Rig:
        ├── Witness ─────────── Polecat supervisor
        │   └── Polecats ────── Ephemeral workers
        ├── Refinery ────────── Merge queue
        └── Crew ────────────── Your personal agents
```

## Agent Identity and Attribution

All work is attributed:

```
Git commits:      Author: gastown/crew/joe <owner@example.com>
Beads issues:     created_by: gastown/crew/joe
Events:           actor: gastown/crew/joe
```

Identity is preserved cross-rig. `gastown/crew/joe` working in
`~/gt/beads/crew/gastown-joe/` still has commits attributed to
`gastown/crew/joe`.

## Runtime Abstraction

Gas Town supports multiple AI runtimes:

**Built-in presets:** `claude`, `gemini`, `codex`, `cursor`, `auggie`,
`amp`, `opencode`, `copilot`, `pi`, `omp`

**Custom agents:** `gt config agent set <name> "<command>"` —
e.g., `gt config agent set claude-glm "claude-glm --model glm-4"`

Per-rig runtime is configured in `settings/config.json`. You can override
per-sling with `gt sling <bead> <rig> --agent cursor`.
