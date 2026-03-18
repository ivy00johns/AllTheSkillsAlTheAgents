# 05 — GUPP and Nondeterministic Idempotence

## GUPP: Gas Town Universal Propulsion Principle

> **"If there is work on your hook, YOU MUST RUN IT."**

GUPP is Gas Town's solution to the fundamental problem with coding agents:
they stop. Context windows fill up, sessions crash, models get polite and
wait for input. GUPP creates a self-perpetuating cycle of work execution.

### How GUPP Works

```
Agent starts session
    │
    ├── Check hook (gt hook)
    │   ├── Work found → Execute immediately (physics over politeness)
    │   └── No work → Check mail, report in
    │
    ├── Work through molecule steps
    │   └── If session fills → gt handoff → new session starts
    │                              └── New session checks hook → continues work
    │
    └── Complete work → gt done → go idle or die
```

Every agent has a **hook** — a special pinned bead. Work gets "slung" to the
hook via `gt sling`. When the agent starts (or restarts), it must check its
hook and begin working immediately.

### The GUPP Nudge Problem

In practice, Claude Code is "so miserably polite" that GUPP doesn't always
work. The agent starts up and waits for user input instead of checking its
hook.

**Solution:** The GUPP Nudge.

```
Agent starts → (30-60 seconds) → gt nudge sends tmux notification
                                      │
                                      └── Agent reads hook and mail
                                          → begins working
```

Systems that deliver nudges:
- **Boot the Dog** — checks the Deacon every 5 minutes
- **The Deacon** — propagates DYFJ downward to Witnesses
- **The Witness** — nudges stuck polecats
- **The daemon** — pings the Deacon on a timer

### The Nudge Content Doesn't Matter

Because agents are prompted so strictly about GUPP, they ignore the nudge
content and just check their hook. You can say "hi", "Elon Musk says the
moon is made of green cheese", or "do your job" — the agent will run the
hook regardless.

This led to `gt seance`: since the nudge content is ignored, Steve started
including the Claude Code session_id in the nudge. This makes `/resume`
sessions discoverable, enabling agents to talk to their predecessors.

### The Handoff Cycle

The core inner loop of Gas Town:

```
Session starts → gt prime (load context) → check hook → work
    → context fills → "let's hand off" → gt handoff
        → saves work state → restarts session in tmux
            → new session → gt prime → check hook → continues work
```

`gt handoff` is the fundamental workflow command. Say "let's hand off" to
any worker and it will gracefully clean up and restart.

## NDI: Nondeterministic Idempotence

NDI is Gas Town's alternative to Temporal's deterministic durable replay.
Both guarantee workflow completion, but through completely different machinery.

### Temporal vs Gas Town

| Aspect | Temporal | Gas Town |
|--------|----------|----------|
| Path | Deterministic replay | Nondeterministic AI execution |
| Storage | Event sourcing + replay log | Beads in Git-backed Dolt |
| Workers | Stateless functions | Superintelligent AI agents |
| Recovery | Replay exact same steps | AI figures out the right fix |
| Guarantees | Exactly-once semantics | Eventual completion ("guaranteed") |

### How NDI Works

Given a molecule on an agent's hook:

1. **Agent is persistent** — a Bead backed by Git. Sessions come and go.
2. **Hook is persistent** — also a Bead backed by Git.
3. **Molecule is persistent** — a chain of Beads, also in Git.

If Claude Code crashes mid-step:

```
Agent crashes at step 5 of 10
    │
    └── New session starts for this role
        └── Checks hook → finds molecule
            └── Scans molecule → step 5 partially done
                └── AI evaluates the state
                    └── Figures out the fix → completes step 5
                        └── Continues to step 6...10
```

The path is fully nondeterministic (the AI might take a different approach
on retry), but the outcome — the workflow completing — is deterministic
because:

- Molecules have **acceptance criteria** per step
- AI is smart enough to detect and recover from partial completions
- The bureaucracy of checking off issues keeps the agent on track
- Git backs everything, so nothing is lost

### NDI Caveats

Steve acknowledges this is oversimplifying:

> "There are tons of edge cases. Gas Town is not a replacement for Temporal.
> Ask your doctor if Gas Town is right for you."

NDI provides workflow guarantees "plenty good enough for a developer tool."
The key insight is that **AI can handle the nondeterminism** because it
can reason about partial states and self-correct. Traditional workflow
engines need determinism because their workers are dumb functions.

## The Heartbeat Cascade

The supervision hierarchy creates a cascade of nudges:

```
daemon (timer)
    └── pings Deacon (DYFJ)
        └── Deacon propagates to Witnesses
            └── Witnesses check Polecats
                └── Nudge stuck polecats
```

Plus the separate Boot → Deacon check every 5 minutes.

This ensures that even if individual agents get stuck, the system
self-heals within minutes. As long as the daemon is running and there's
work in the system, agents will eventually pick it up and complete it.

## Exponential Backoff

Patrol agents (Deacon, Witness, Refinery) use exponential backoff:

```
Patrol finds work → process it → next patrol immediately
Patrol finds no work → wait 30s → patrol
Still no work → wait 60s → patrol
Still no work → wait 2m → patrol
...up to max backoff
```

Any mutating `gt` or `bd` command wakes the town, resetting backoff.
