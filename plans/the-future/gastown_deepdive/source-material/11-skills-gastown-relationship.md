# 11 — Skills Ecosystem ↔ Gas Town Relationship

AllTheSkillsAllTheAgents and Gas Town are **parallel approaches** to the same
problem — multi-agent orchestration — but they operate at different layers
and make fundamentally different trade-offs.

## The Shared Problem

Both systems address: "How do you coordinate multiple AI coding agents
working in parallel on the same codebase?"

Both solve:
- File ownership conflicts
- Work decomposition and tracking
- Quality gating
- Context management across sessions
- Agent coordination and communication

## How They Differ

| Dimension | Skills Ecosystem | Gas Town |
|-----------|-----------------|----------|
| **Layer** | Claude Code skill files (prompts) | External Go binary + tmux + Dolt |
| **Persistence** | Within-session (context window) | Git-backed Beads database |
| **Agent model** | Subagents spawned within session | Independent Claude Code sessions |
| **Scope** | Single build session | Ongoing, multi-day, multi-project |
| **Scale** | 2-5 parallel agents per build | 20-30+ concurrent agents |
| **State** | Contracts as files, reports as JSON | Beads, molecules, hooks, wisps |
| **UI** | Claude Code terminal | tmux + TUI + web dashboard |
| **Work tracking** | Task list within session | Beads issue tracker |
| **Merge strategy** | File ownership prevents conflicts | Refinery + Merge Queue |
| **Recovery** | Handoff protocol with context files | GUPP + hook + molecule durability |
| **Runtime** | Claude Code (with Agent Teams) | Claude, Codex, Gemini, Cursor, etc. |
| **Cost model** | Single session's token usage | Multiple concurrent sessions |

## Complementary, Not Competing

These systems can work together:

### Skills as Gas Town Workers

Gas Town workers (polecats, crew) are prompted Claude Code sessions. They
*could* use skills from AllTheSkillsAllTheAgents internally. For example:

- A polecat running a `shiny` formula could use the `code-reviewer` skill
  during its self-review step
- A crew member doing design work could use the `frontend-agent` skill
- The Mayor could use the `orchestrator` skill for complex planning

### Gas Town as Skills Runtime

The skills ecosystem's orchestrator skill can detect and use Gas Town's
infrastructure when available. The runtime detection logic:

```
Is CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS set?
  YES → Native Agent Teams
  NO → Is bash available?
    YES → Subagents via Agent tool
    NO → Sequential mode
```

Gas Town adds a fourth option: full tmux-based agent management with
persistent state.

## Conceptual Parallels

| Skills Concept | Gas Town Equivalent |
|----------------|-------------------|
| Orchestrator skill | Mayor + Witness |
| Contract-author | Beads issue descriptions + acceptance criteria |
| QE agent | Refinery gates + polecat self-review |
| File ownership map | Polecat worktree isolation + Refinery merge |
| Context handoff protocol | `gt handoff` + GUPP |
| Agent spawn | `gt sling` |
| qa-report.json | Convoy landing status |
| Circuit breaker | Escalation system + max retry limits |

## Key Divergences

### 1. Philosophy

**Skills:** Contract-first. Define every interface before code is written.
Prevent integration failures through specification.

**Gas Town:** Throughput-first. "Work becomes fluid... Fish fall out of the
barrel. Some escape back to sea, or get stepped on. More fish will come."
Fix things after they break.

### 2. Quality Model

**Skills:** QE agent gates the build. Structured JSON report with scores.
Build literally blocks on failures. "You do NOT override the QE gate."

**Gas Town:** Refinery runs gates (build, test, lint, typecheck) but the
primary quality signal is "does it merge clean?" The system tolerates bugs
being fixed 2-3 times and picking the winner.

### 3. Agent Identity

**Skills:** Agents are ephemeral — spawned for a build, gone when done.
No persistent identity, no work history, no CV chain.

**Gas Town:** Agents are persistent identities (Beads in Git). Polecat
"alpha" has a CV chain of every assignment it has completed. Sessions are
ephemeral; agents are not.

### 4. Workflow Model

**Skills:** Linear build phases. Phase guide is a checklist. Agents work
and report done.

**Gas Town:** MEOW stack. Formulas → protomolecules → molecules → wisps.
Turing-complete workflows with loops, gates, and composition. NDI ensures
eventual completion.

### 5. Human Role

**Skills:** Human triggers build, reviews output, approves merge.
"Orchestrator never implements code."

**Gas Town:** Human is the Overseer — a named role with an inbox. Shapes
work by talking to the Mayor. "You are a Product Manager, and Gas Town is
an Idea Compiler."

## Evolution Path

The skills ecosystem represents a **standardized, portable** approach:
drop markdown files into `~/.claude/skills/` and any Claude Code gains
multi-agent capability. It's accessible to anyone at Stage 5+.

Gas Town represents the **frontier**: a full operating system for agent
orchestration that requires Stage 7+ expertise and significant investment
in tooling. It's where the skills ecosystem's concepts are pushed to their
logical extreme — persistent agents, durable workflows, federation.

A plausible evolution:
1. Users start with the skills ecosystem (Stage 5-6)
2. Hit scaling limits at 5+ agents
3. Graduate to Gas Town (Stage 7-8)
4. Gas Town concepts eventually fold back into more accessible tools

Both systems are Steve Yegge's work. The skills ecosystem is "what should
be built into the tools." Gas Town is "what I built because nobody else
would."

## The Superpowers Connection

The user's Claude Code installation has `superpowers:*` skills loaded,
which are the *user's own* orchestration skills that complement both
systems:

- `superpowers:brainstorming` — creative exploration before implementation
- `superpowers:writing-plans` — spec → step-by-step plan
- `superpowers:executing-plans` — plan execution with review checkpoints
- `superpowers:test-driven-development` — TDD before implementation
- `superpowers:systematic-debugging` — bug investigation protocol
- `superpowers:dispatching-parallel-agents` — parallel agent coordination
- `superpowers:verification-before-completion` — evidence before assertions

These superpowers represent a third layer: **personal workflow discipline**
that wraps around either the skills ecosystem or Gas Town.
