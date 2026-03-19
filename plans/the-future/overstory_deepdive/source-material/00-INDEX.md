# Overstory Deep Dive — Index

A comprehensive technical breakdown of the Overstory project, its relationship
to the AllTheSkillsAllTheAgents skill ecosystem, and the convergence opportunity
between them.

## Documents

| # | File | Topic |
|---|------|-------|
| 01 | [project-overview.md](01-project-overview.md) | What Overstory is, by the numbers, and where it sits in the landscape |
| 02 | [architecture.md](02-architecture.md) | Two-layer agent system, worktree isolation, SQLite backbone, the `ov` CLI |
| 03 | [agent-system.md](03-agent-system.md) | All 10 agent roles, identity/lifecycle, capability hierarchy, the overlay system |
| 04 | [messaging-and-coordination.md](04-messaging-and-coordination.md) | SQLite mail, protocol types, broadcast groups, nudge system |
| 05 | [merge-system.md](05-merge-system.md) | FIFO merge queue, 4-tier conflict resolution, mulch-informed learning |
| 06 | [runtime-adapters.md](06-runtime-adapters.md) | 9 runtime adapters (Claude, Pi, Copilot, Codex, Gemini, Sapling, OpenCode, Cursor), the AgentRuntime interface |
| 07 | [observability-stack.md](07-observability-stack.md) | Events, metrics, costs, dashboard, inspector, trace, replay, feed, watchdog |
| 08 | [ecosystem-integration.md](08-ecosystem-integration.md) | Seeds, Mulch, Canopy — the os-eco tool family |
| 09 | [hooks-and-config.md](09-hooks-and-config.md) | Hook-driven orchestrator loop, config system, guard rules, templates |
| 10 | [skills-comparison.md](10-skills-comparison.md) | How Overstory and AllTheSkillsAllTheAgents compare — shared DNA, divergent paths |
| 11 | [convergence-analysis.md](11-convergence-analysis.md) | What each project has that the other lacks, and what we steal |
| 12 | [frontier-assessment.md](12-frontier-assessment.md) | What is genuinely novel, what is table stakes, and what the combined system could become |

## Generated

2026-03-18 — from codebase analysis of overstory (96k LoC TypeScript, 1,237 commits,
209 source files, 10 agent roles, 9 runtime adapters, 36+ CLI commands)
and AllTheSkillsAllTheAgents (17 skills, 44 files, platform scaffold).
