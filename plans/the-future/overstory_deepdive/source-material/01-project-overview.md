# 01 — Project Overview

## What Overstory Is

Overstory is a multi-agent orchestration CLI for AI coding agents. It turns a
single Claude Code session into a coordinated swarm of parallel agents — each
working in isolated git worktrees, communicating through a custom SQLite mail
system, and merging their work back through tiered conflict resolution.

The key insight: **your Claude Code session IS the orchestrator.** There is no
separate daemon, server, or control plane. The CLAUDE.md file, shell hooks, and
the `ov` CLI provide everything needed to coordinate 20+ concurrent agents from
within a single interactive session.

Built by Jaymin West as part of the **os-eco** (open-source ecosystem) tool
family alongside Seeds (issue tracking), Mulch (expertise management), and
Canopy (prompt management).

## By The Numbers (as of 2026-03-18)

| Metric | Value |
|--------|-------|
| TypeScript source files | 209 |
| Lines of TypeScript | 96,069 |
| Git commits | 1,237 |
| CLI commands | 36+ subcommands |
| Agent roles defined | 10 (scout, builder, reviewer, lead, merger, coordinator, orchestrator, monitor, supervisor [deprecated], ov-co-creation) |
| Runtime adapters | 9 (Claude, Pi, Copilot, Codex, Gemini, Sapling, OpenCode, Cursor) |
| SQLite databases | 4 (mail.db, sessions.db, events.db, metrics.db) |
| Test files | Co-located with source (`*.test.ts`) |
| npm package | `@os-eco/overstory-cli` v0.9.1 |
| Runtime | Bun (TypeScript direct, no build step) |
| License | MIT |
| CLI framework | Commander.js |

## Key Dependencies

| Dependency | Purpose |
|------------|---------|
| `bun:sqlite` | All 4 SQLite databases (WAL mode, synchronous API) |
| `Bun.spawn` | All subprocess execution (git, tmux, CLI tools) |
| `chalk` v5 | ESM-only terminal color output |
| `commander` | CLI framework with typed options and subcommands |
| `@os-eco/mulch-cli` | Programmatic expertise API |
| `tmux` (external) | Agent session hosting and isolation |
| `git` (external) | Worktree management and branch isolation |
| `bd` / `sd` (external) | Issue tracking (beads/seeds backends) |
| `cn` (external) | Prompt management (canopy) |
| `ml` (external) | Expertise management (mulch) |

## How Overstory Differs from Gas Town

Both are "Kubernetes for agents" — but they diverge significantly:

| Dimension | Overstory | Gas Town |
|-----------|-----------|----------|
| **Language** | TypeScript (Bun) | Go |
| **Scale** | 96k LoC, 1,237 commits | 377k LoC, 6,457 commits |
| **Data plane** | Seeds (git-native, lightweight) | Beads (Dolt-backed, heavyweight) |
| **Storage** | 4 SQLite databases (WAL mode) | Dolt SQL Server + Beads git store |
| **Messaging** | SQLite mail (~1-5ms per query) | Beads-based (slower) |
| **Runtimes** | 9 adapters (Claude, Pi, Codex, Gemini, etc.) | Primarily Claude Code |
| **Merge** | 4-tier resolution (clean → auto → AI → reimagine) | Formula-based merge workflows |
| **Distribution** | npm package | Homebrew + npm + Docker |
| **Philosophy** | Ecosystem of composable tools | Monolithic orchestrator |
| **Expertise** | Mulch (structured knowledge base) | Internal formulas |
| **Prompts** | Canopy (versioned prompt management) | Inline formula templates |
| **Complexity** | Tool per concern (ov, sd, ml, cn) | One tool (gt) does everything |

## The os-eco Philosophy

Overstory is one of four tools that compose into an ecosystem:

```
overstory (ov)  — orchestration: spawn, coordinate, merge, observe
seeds (sd)      — issue tracking: git-native, dependency-aware
mulch (ml)      — expertise: structured knowledge, patterns, decisions
canopy (cn)     — prompts: versioned, inheritable, profile-aware
```

Each tool is an independent npm package with its own CLI, data store, and
release cycle. They integrate through file conventions and subprocess calls —
never through shared npm imports. This means:

- Any tool can be used standalone
- Any tool can be replaced without affecting the others
- Version upgrades are independent
- Agents can use only the tools they need

## Origin and Trajectory

Overstory started as a way to make Claude Code's Agent tool useful for
coordinating real work across isolated worktrees. The first version was a
handful of scripts. It evolved through several key inflection points:

1. **SQLite mail** — replaced file-based messaging with a proper database
2. **Runtime adapters** — broke free from Claude Code-only via pluggable runtimes
3. **Mulch integration** — agents could learn and share knowledge across sessions
4. **Canopy integration** — prompts became versioned and profile-aware
5. **Seeds integration** — issue tracking became lightweight and git-native
6. **Tiered merge** — AI-assisted conflict resolution replaced manual merging
7. **Watchdog system** — three-tier monitoring replaced ad-hoc health checks
8. **Event store** — observability became first-class with SQLite-backed events

The project is at v0.9.1 — pre-1.0, actively evolving, with the core
architecture stable but many refinements still landing.
