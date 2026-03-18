# Beads Deep Dive -- Complete Technical Reference

Generated 2026-03-17 from codebase analysis of steveyegge/beads (v0.61.0, 225k+ LoC)
and 9-agent parallel research covering storage, formulas, CLI, agents, MCP, Dolt internals.

## Documents

| # | File | Topic |
|---|------|-------|
| 00 | 00-INDEX.md | This index |
| 01 | 01-architecture-overview.md | Three-layer architecture, execution modes, design decisions |
| 02 | 02-data-model.md | Complete SQL schema, Issue struct, all 50+ columns, views |
| 03 | 03-storage-engine.md | DoltStore, transactions, auto-start, retry, circuit breaker |
| 04 | 04-dependency-graph.md | 22 dependency types, ready_issues view, cycle detection, claims |
| 05 | 05-formula-engine.md | Chemistry metaphor, formula DSL, transformation pipeline, compaction |
| 06 | 06-agent-coordination.md | Agent beads, witness system, gates, swarms, HOP |
| 07 | 07-cli-reference.md | 120+ commands, lifecycle hooks, routing, config system |
| 08 | 08-integration-layer.md | MCP server, Claude plugin, recipes, community tools |
| 09 | 09-dolt-database.md | Dolt internals, concurrency model, performance, limitations |
| 10 | 10-federation.md | Peer-to-peer sync, sovereignty tiers, remotes, conflict resolution |
| 11 | 11-production-gaps.md | Gap analysis with severity ratings and remediation paths |
| 12 | 12-build-plan.md | What to build for Gas Town: priorities, architecture, cleaner version |

## Context

Beads (bd) is the data plane for Gas Town -- Steve Yegge's multi-agent orchestration system.
Gas Town runs 20-30 concurrent Claude Code agents against a shared Dolt SQL database,
coordinating via atomic claims, dependency graphs, and a chemistry-inspired workflow engine.

This reference was generated from a 9-agent parallel deep dive covering:
- Web research on Gas Town articles and community discussion
- Exhaustive code tracing of storage, formulas, CLI, agents, MCP, and integrations
- Dolt database internals and concurrency model research

See also: ../source-material/ for Gas Town (gt) orchestrator documentation.

## How to Read This Series

Start with **01-architecture-overview.md** for the big picture: the three-layer
architecture, three execution modes, and the ten key design decisions that explain
why the codebase is shaped the way it is.

Continue to **02-data-model.md** for the complete SQL schema. This is the most
reference-heavy document -- every column, every table, every view, every constant.
Keep it open as a companion while reading the rest.

Documents 03-06 cover the four major subsystems in depth: the storage engine (03),
the dependency graph (04), the formula/molecule engine (05), and agent coordination (06).

Documents 07-08 cover the external surface area: CLI commands (07) and integrations
with MCP, Claude Code, and external tools (08).

Documents 09-10 go deep on Dolt: its internals and concurrency model (09) and the
federation protocol for multi-town synchronization (10).

Documents 11-12 are forward-looking: gap analysis (11) and the build plan for what
Gas Town should build on top of beads (12).

## Source Repository

- Repository: https://github.com/steveyegge/beads
- Version analyzed: v0.61.0
- Primary language: Go (Cobra CLI, Dolt storage)
- Integration languages: Python (MCP server), TypeScript (Claude Code plugin)
- Database: Dolt (MySQL-compatible, version-controlled SQL)
- License: Apache 2.0
