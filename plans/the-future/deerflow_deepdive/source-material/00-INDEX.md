# DeerFlow Deep Dive — Index

This deep dive dissects ByteDance's DeerFlow v2 — a 58k LoC multi-agent orchestration harness built on LangGraph that hit 30k+ GitHub stars in three weeks. The analysis combines a Claude Deep Research document with hands-on codebase exploration to answer a strategic question: **what can AllTheSkillsAllTheAgents adopt from DeerFlow, and what does DeerFlow need that AllTheSkills already has?** The answer is that the two systems are complementary — DeerFlow for agent capabilities, AllTheSkills for coordination, The Hive for infrastructure.

## Documents

| # | File | Topic |
|---|------|-------|
| 01 | [project-overview.md](01-project-overview.md) | What DeerFlow is, by the numbers, landscape position, benchmarks |
| 02 | [architecture.md](02-architecture.md) | 4-service architecture, directory layout, 10 key design decisions |
| 03 | [harness-core.md](03-harness-core.md) | Agent runtime: make_lead_agent(), ThreadState, tool assembly, sub-agents |
| 04 | [middleware-pipeline.md](04-middleware-pipeline.md) | 14-stage ordered middleware: every stage, hooks, execution lifecycle |
| 05 | [sandbox-system.md](05-sandbox-system.md) | Code execution isolation: Local, Docker, K8s modes + provisioner |
| 06 | [memory-system.md](06-memory-system.md) | Persistent memory: confidence-scored facts, async extraction, injection |
| 07 | [tools-and-mcp.md](07-tools-and-mcp.md) | 5-source tool assembly, MCP integration, deferred loading, skills |
| 08 | [gateway-and-channels.md](08-gateway-and-channels.md) | FastAPI gateway, message bus, Feishu/Slack/Telegram channels |
| 09 | [frontend.md](09-frontend.md) | Next.js app, SSE streaming, React Context state, component library |
| 10 | [comparison.md](10-comparison.md) | DeerFlow vs. AllTheSkills: what each has that the other lacks |
| 11 | [convergence-analysis.md](11-convergence-analysis.md) | Integration opportunities, portable patterns, combined architecture |
| 12 | [frontier-assessment.md](12-frontier-assessment.md) | What's novel, what's table stakes, 5-phase build sequence |

## How to Read This Series

Start with **01-project-overview** for the big picture — what DeerFlow is, its scale, and how it compares to AllTheSkills at a glance. Then read **02-architecture** for the structural blueprint: the 4-service deployment, directory layout, and 10 key design decisions that explain why the codebase is shaped the way it is.

The subsystem documents (**03-09**) go deep on individual components. Read **03-harness-core** first — it's the agent runtime that everything else hangs off of. Then **04-middleware-pipeline** for the 14-stage interceptor chain that instruments all agent behavior. Documents 05-09 can be read in any order based on interest: sandbox isolation (05), persistent memory (06), tool system (07), gateway and IM channels (08), or the frontend (09). Keep 03 and 04 open as reference while reading the others — they define patterns the subsystem docs reference.

The strategic documents (**10-12**) are where the insight lives. **10-comparison** maps the capability gaps between the two systems. **11-convergence-analysis** identifies what to port, what to adapt, and what ideas to steal. **12-frontier-assessment** distinguishes genuine novelty from table stakes and proposes a 5-phase build sequence for the combined system. Read these last — they benefit from understanding the technical details in 03-09.

## Source Repository

- Repository: github.com/bytedance/deer-flow
- Version analyzed: commit 9dbcca5 (2026-03-21)
- Primary language: Python 3.12+ (FastAPI, LangGraph, uvicorn) + TypeScript (Next.js 16, React 19)
- License: MIT

## Generated

2026-03-21 — from codebase analysis of DeerFlow v2 (~58k LoC, 1,634 commits, 224 contributors, 30k+ stars) and AllTheSkillsAllTheAgents (21 skills, 48+ files). Deep Research source document: `plans/the-future/claude_research/deerflow-bytedance.md`.
