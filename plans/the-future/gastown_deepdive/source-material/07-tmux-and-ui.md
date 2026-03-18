# 07 — tmux and UI

## tmux as Primary UI

Gas Town uses tmux as its primary interface. Steve describes it as
"both easy to use and shockingly powerful" and "almost like a baby Emacs."

### Why tmux

- **Session persistence** — agents survive terminal disconnects
- **Remote workers** — enables cloud-hosted agents
- **Session multiplexing** — switch between 20-30 agents
- **Programmability** — Claude Code can customize views, bindings, popups
- **Groups** — related agents grouped for `C-b n/p` cycling

### Core tmux Keybindings

| Binding | Action |
|---------|--------|
| `C-b s` | List sessions, snoop them, switch to one |
| `C-b b` | Move cursor backwards |
| `C-b [` | Enter copy mode (scroll), ESC exits |
| `C-b C-z C-z` | Suspend process to shell |
| `C-b n/p` | Cycle to next/prev worker in group |
| `C-b a` | Activity feed view (custom config) |

### Session Organization

Gas Town organizes tmux sessions by role:

```
tmux list-sessions:
  mayor: 1 windows
  gastown-witness: 1 windows
  gastown-refinery: 1 windows
  gastown-crew-joe: 1 windows
  gastown-crew-luna: 1 windows
  gastown-polecat-alpha: 1 windows
  gastown-polecat-bravo: 1 windows
  deacon: 1 windows
  boot: 1 windows
```

### Status Line

The Mayor has a custom status line showing:
- Current rig count
- Active agent count
- Convoy status
- System health indicators

## The `gt nudge` Messaging System

`gt nudge` is Gas Town's core real-time messaging. It sends text directly
to another agent's active tmux session:

```bash
gt nudge mayor "Status update: PR review complete"
gt nudge gastown/crew/dom "Check your mail"
gt nudge witness "Polecat health check needed"
gt nudge refinery "Merge queue has items"
```

**How it works:**
1. Resolves target to a tmux session name
2. Works around tmux `send-keys` debounce issues
3. Delivers notification as if the user typed it
4. Agent's GUPP prompting causes it to check hook and mail

**Target formats:**
- Role shortcuts: `mayor`, `deacon`, `witness`, `refinery`
- Full path: `<rig>/crew/<name>`, `<rig>/polecats/<name>`

**Key rule:** `gt nudge` is the ONLY way to send text to another agent.
Printing text to your own terminal is invisible to other agents.

## The `gt mail` System

Persistent mail that survives session restarts:

```bash
# Reading
gt mail inbox              # List messages
gt mail read <id>          # Read specific message

# Sending
gt mail send mayor/ -s "Subject" -m "Short message"
gt mail send <rig>/crew/dom -s "PR Review" --stdin <<'BODY'
Multi-line message content here.
BODY
gt mail send --human -s "Subject" -m "Message to overseer"
```

### When to Use Nudge vs Mail

| Want to... | Command | Why |
|------------|---------|-----|
| Wake a sleeping agent | `gt nudge` | Immediate delivery |
| Send detailed task/info | `gt mail send` | Persists across restarts |
| Both: send + wake | `gt mail send` then `gt nudge` | Mail carries payload, nudge wakes |

## Activity Feed TUI (`gt feed`)

Built with Charmbracelet (bubbles, bubbletea, lipgloss). Three-panel layout:

```
┌──────────────┬───────────────────────────────────┐
│ Agent Tree   │ Convoy Panel                      │
│              │                                   │
│ gastown/     │ 🚚 Feature X (3/5 done)          │
│ ├─ witness   │   ├─ gt-abc ✅                    │
│ ├─ refinery  │   ├─ gt-def ✅                    │
│ ├─ crew/     │   ├─ gt-ghi ⏳                    │
│ │  ├─ joe    │   ├─ gt-jkl ⏳                    │
│ │  └─ luna   │   └─ gt-mno ⏳                    │
│ └─ polecats/ │                                   │
│    ├─ alpha  ├───────────────────────────────────│
│    └─ bravo  │ Event Stream                      │
│              │ 14:23 gt-abc CLOSED by alpha       │
│ beads/       │ 14:21 gt-ghi SLUNG to bravo       │
│ ├─ witness   │ 14:19 alpha MERGED gt-abc         │
│ └─ crew/     │ 14:15 mayor CREATED convoy        │
│    └─ wolf   │ 14:12 bravo NUDGED by witness     │
└──────────────┴───────────────────────────────────┘
```

**Navigation:** `j/k` scroll, `Tab` switch panels, `1/2/3` jump to panel,
`p` toggle problems view, `?` help, `q` quit.

## Web Dashboard

htmx-based single-page app served by `gt dashboard`:

- **Agent overview** — all agents grouped by rig and role, health status
- **Convoy tracker** — active and landed convoys with issue trees
- **Hook inspector** — what's on each agent's hook
- **Queue view** — merge queue status
- **Issue browser** — beads across all rigs
- **Escalation log** — unresolved escalations
- **Command palette** — run `gt` commands from the browser

```bash
gt dashboard              # Start on port 8080
gt dashboard --port 3000  # Custom port
gt dashboard --open       # Auto-open browser
```

The dashboard uses response caching to prevent `bd` process storms when
multiple tabs or auto-refreshes hit simultaneously.

## Future UIs

Steve mentions wanting:
- **Emacs UI** — his personal preference
- **Web UI** — for broader accessibility
- **Mobile** — not mentioned but implied by federation

Current tmux UI is "good enough" and "stays out of your way."
