# 01 — Project Overview

## What Gas Town Is

Gas Town is a multi-agent orchestration system for coding agents (primarily
Claude Code). It coordinates 20-30+ concurrent AI coding sessions working on
one or more projects, with persistent work tracking, automated merging, and
hierarchical supervision — all backed by Git.

Steve Yegge describes it as "Kubernetes for agents" — but where k8s asks
"Is it running?", Gas Town asks "Is it done?" It optimizes for *completion*
of work, not uptime.

## By The Numbers (as of 2026-03-17)

| Metric | Value |
|--------|-------|
| Go source files | 1,006 |
| Lines of Go code | 377,251 |
| Git commits | 6,457 |
| CLI commands (`internal/cmd/*.go`) | 365 files (103 non-test commands) |
| Built-in formulas | 42 TOML workflow templates |
| Internal packages | 65 packages under `internal/` |
| Dependencies | 135 lines in go.mod |
| 100% vibe coded | Yes. Steve has never read the code. |

## Key Dependencies

| Dependency | Purpose |
|------------|---------|
| `github.com/steveyegge/beads` (v0.59.0) | Git-backed issue tracking, the data plane |
| `github.com/spf13/cobra` | CLI framework for `gt` |
| `github.com/charmbracelet/*` | TUI framework (bubbles, bubbletea, lipgloss, glamour) |
| `github.com/BurntSushi/toml` | Formula parsing |
| `github.com/go-sql-driver/mysql` | Dolt SQL Server communication |
| `github.com/go-rod/rod` | Browser automation (dashboard) |
| OpenTelemetry stack | Observability, metrics, logging |

## Distribution

Gas Town distributes through four channels:

- **GitHub Releases** — platform binaries via GoReleaser
- **Homebrew** — `brew install steveyegge/gastown/gt`
- **npm** — `npx @gastown/gt` (wrapper that downloads the correct binary)
- **Docker** — `docker compose up -d` with included Dockerfile

## Origin Story

Gas Town is Steve Yegge's *fourth* orchestrator of 2025:

1. **Orchestrator v1** (Aug 2025) — failed
2. **Orchestrator v2** — failed, but produced Beads as a byproduct
3. **Python Gas Town** (v3) — lasted 6-8 weeks
4. **Go Gas Town** (v4, current) — started Dec 14, 2025. First "flying" Dec 29, 2025.

Beads came first (October 2025, 225k LoC), as a lightweight git-backed issue
tracker. Gas Town is the orchestration layer built on top of Beads.

## The Evolution Scale

Steve defines 8 stages of AI-assisted coding:

| Stage | Description |
|-------|-------------|
| 1 | Zero or near-zero AI |
| 2 | Coding agent in IDE, permissions on |
| 3 | Agent in IDE, YOLO mode |
| 4 | Wide agent in IDE, code just for diffs |
| 5 | CLI, single agent, YOLO |
| 6 | CLI, multi-agent (3-5 instances) |
| 7 | 10+ agents, hand-managed |
| 8 | Building your own orchestrator |

Gas Town targets Stage 7-8 users. "If you're not at least Stage 7, or maybe
Stage 6 and very brave, then you will not be able to use Gas Town."
