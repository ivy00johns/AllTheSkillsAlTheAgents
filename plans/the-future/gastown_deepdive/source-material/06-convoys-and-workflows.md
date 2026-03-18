# 06 — Convoys and Workflows

## Convoys

A **Convoy** is Gas Town's work-order system. It wraps related beads into
a trackable unit of delivery.

### Why Convoys Exist

Without convoys, completion notifications are confusing:

> "Issue wy-a7je4 just finished" — what was that part of?

Convoys provide:
- Single view of "what's in flight"
- Cross-rig tracking (convoy in `hq-*`, issues in `gt-*`, `bd-*`)
- Auto-notification when work lands
- Historical record of completed work

### Convoy Lifecycle

```
Create → Active → (partial completions) → Landed
  │         │                                │
  └─ gt convoy create       └─ gt convoy list
       "Feature X"              gt convoy show
       gt-abc gt-def
```

A convoy can have **multiple swarms** attack it before it finishes. Swarms
are ephemeral agent sessions taking on persistent work. The managing agent
(e.g., Witness) keeps recycling polecats and pushing them on issues until
the convoy lands.

### Convoy Commands

```bash
gt convoy create "Feature X" gt-abc gt-def --notify --human
gt convoy list                    # All active convoys
gt convoy show [id]               # Details + issue tree
gt convoy add <convoy-id> <ids>   # Add issues to convoy
gt convoy launch <convoy-id>      # Auto-spawn polecats for all issues
```

### Convoy + Sling Flow

The fundamental pattern:

```
You: "Our tmux sessions show the wrong rig count — file it and sling it"
    │
Mayor:
    ├── bd create --title "Fix rig count in tmux status bar"
    ├── gt convoy create "Tmux rig fix" gt-xyz --notify --human
    └── gt sling gt-xyz gastown
         │
         └── Polecat spawns → works → submits MR → Refinery merges
             │
             └── Convoy lands → You get notified
```

## Slinging

`gt sling` is the fundamental primitive for assigning work:

```bash
gt sling <bead-id> <rig>                    # Sling to any available polecat
gt sling <bead-id> <rig>/<agent>            # Sling to specific agent
gt sling <bead-id> <rig> --agent codex      # Override runtime
```

What `gt sling` does:
1. Hangs the bead on the target agent's hook
2. Creates/updates a convoy to track it
3. Spawns a polecat session if needed
4. The polecat picks up work via GUPP

## The Merge Queue

The Refinery processes Merge Requests through a **batch-then-bisect** strategy
(Bors-style):

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
              B passes → C or D broke it → bisect [C,D]
              B fails  → A or B broke it → bisect [A,B]
```

### MQ Implementation Phases

| Phase | Description | Status |
|-------|-------------|--------|
| 1: GatesParallel | Run test + lint concurrently per MR | In progress |
| 2: Batch-then-bisect | Bors-style batching with binary bisect | Blocked by Phase 1 |
| 3: Pre-verification | Polecats run tests before MR submission | Blocked by Phase 2 |

### Pre-Verification Fast Path

The `mol-polecat-work` formula includes a "pre-verify" step where polecats
rebase onto main and run the full gate suite *before* submitting their MR.
If pre-verification passes, the Refinery can fast-path merge in ~5 seconds
instead of re-running all gates.

### MR Verdict Loop

```
Polecat submits MR
    │
    └── Refinery processes
        ├── MERGED → gt done (polecat self-cleans)
        └── FIX_NEEDED → polecat reads failure, fixes, resubmits
                              └── max 3 attempts → escalate to Witness
```

## Patrols

Patrols are **ephemeral (wisp) workflows** that patrol agents run in a loop.
Three agents have patrols:

### Deacon Patrol (`mol-deacon-patrol`)
- Run town-level plugins
- Propagate DYFJ signal downward
- Manage session recycling
- Check worker cleanup
- Delegate complex work to Dogs

### Witness Patrol (`mol-witness-patrol`)
- Check polecat health (stuck, zombie, GUPP violations)
- Nudge unresponsive polecats
- Check refinery is processing MQ
- Peek at Deacon health
- Run rig-level plugins

### Refinery Patrol (`mol-refinery-patrol`)
- Preflight: clean workspace
- Process Merge Queue until empty
- Post-flight: prepare for handoff

### Patrol Lifecycle

```
gt patrol new          # Create root-only patrol wisp
    │
gt prime               # Shows patrol checklist inline
    │
Work through each step
    │
gt patrol report --summary "..."   # Close + start next cycle
    │
(exponential backoff if no work found)
```

## Work Generation

Gas Town both produces and consumes work. The hardest problem is keeping
the engine fed. Approaches:

1. **Direct filing** — Tell the Mayor what to build, it creates beads
2. **Epics** — File hierarchical plans as epic trees
3. **Formulas** — Use TOML templates for repeatable workflows
4. **Plan conversion** — Use external tools (Spec Kit, BMAD), then convert to beads
5. **Swarming** — Convoy large plans and swarm polecats at them
6. **Composition** — Wrap workflows with `rule-of-five` or other meta-formulas

## Activity Feed

`gt feed` is the real-time monitoring dashboard:

```bash
gt feed                 # TUI dashboard
gt feed --problems      # Stuck agent detection
gt feed --plain         # Plain text output
gt feed --window        # Open in dedicated tmux window
gt feed --since 1h      # Events from last hour
```

### Three Panels
- **Agent Tree** — hierarchical view by rig and role
- **Convoy Panel** — in-progress and recently-landed
- **Event Stream** — chronological (creates, completions, slings, nudges)

### Problems View

At scale (20-50+ agents), surfaces agents needing intervention:

| State | Condition |
|-------|-----------|
| GUPP Violation | Hooked work, no progress |
| Stalled | Hooked work, reduced progress |
| Zombie | Dead tmux session |
| Working | Active, progressing |
| Idle | No hooked work |

Keys: `n` to nudge, `h` to handoff.

## Web Dashboard

```bash
gt dashboard            # Start on port 8080
gt dashboard --port 3000
gt dashboard --open     # Auto-open in browser
```

htmx-based single-page overview: agents, convoys, hooks, queues, issues,
escalations. Auto-refreshes. Includes a command palette for running `gt`
commands from the browser.
