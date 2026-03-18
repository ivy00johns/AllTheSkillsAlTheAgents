# Gas Town Deep Dive — Index

A comprehensive technical breakdown of the Gas Town project, its relationship
to the AllTheSkillsAllTheAgents skill ecosystem, and the vision behind it.

## Documents

| # | File | Topic |
|---|------|-------|
| 01 | [project-overview.md](01-project-overview.md) | What Gas Town is, by the numbers, and where it sits in the landscape |
| 02 | [architecture.md](02-architecture.md) | Two-tier Beads, Dolt storage, directory layout, the `gt` CLI |
| 03 | [worker-roles.md](03-worker-roles.md) | All 8 roles (Mayor through Overseer), lifecycles, and interactions |
| 04 | [meow-stack.md](04-meow-stack.md) | Beads → Epics → Molecules → Protomolecules → Formulas → Wisps |
| 05 | [gupp-and-ndi.md](05-gupp-and-ndi.md) | Propulsion, nudges, nondeterministic idempotence |
| 06 | [convoys-and-workflows.md](06-convoys-and-workflows.md) | Convoys, slinging, patrols, the merge queue |
| 07 | [tmux-and-ui.md](07-tmux-and-ui.md) | tmux integration, the feed TUI, web dashboard |
| 08 | [formulas-catalog.md](08-formulas-catalog.md) | Every built-in formula and what it does |
| 09 | [wasteland-federation.md](09-wasteland-federation.md) | The Wasteland, DoltHub federation, reputation stamps |
| 10 | [skills-ecosystem.md](10-skills-ecosystem.md) | AllTheSkillsAllTheAgents — the 17-skill orchestration toolkit |
| 11 | [skills-gastown-relationship.md](11-skills-gastown-relationship.md) | How the skill ecosystem and Gas Town relate and diverge |
| 12 | [frontier-assessment.md](12-frontier-assessment.md) | "Not production" — what the article means, who Gas Town is for |

## Generated

2026-03-17 — from codebase analysis of gastown (377k LoC, 6,457 commits)
and AllTheSkillsAllTheAgents (17 skills, 44 files).
