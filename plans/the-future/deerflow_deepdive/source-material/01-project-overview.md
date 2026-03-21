# 01 — DeerFlow: Project Overview

## What DeerFlow Is

DeerFlow (Deep Exploration and Efficient Research Flow) is a Python/TypeScript multi-agent orchestration harness built on LangGraph and LangChain. Originally a deep research framework, ByteDance rebuilt it from scratch as v2 — a general-purpose "SuperAgent harness" — after the community pushed v1 far beyond its original research-only scope into data pipelines, slide decks, and full applications. The core insight is that a well-instrumented agent runtime with sandboxed execution, persistent memory, and a middleware-based processing pipeline can serve as the foundation for arbitrary AI-powered workflows, not just research.

DeerFlow sits under the official `bytedance/` GitHub organization with a dedicated website at deerflow.tech, professional branding, and promotion from ByteDance Open Source's official accounts. It is MIT-licensed with no known enterprise/commercial tier, though it integrates with BytePlus InfoQuest (ByteDance's commercial search product) and deploys one-click via Volcengine (ByteDance's cloud).

## By the Numbers

| Metric | Value |
|--------|-------|
| Python source files | 190 |
| TypeScript source files | 219 |
| JavaScript source files | 12 |
| Python lines of code | ~34,000 |
| TypeScript lines of code | ~22,000 |
| Total lines of code | ~58,500 |
| Git commits | 1,634 |
| First commit | 2025-04-07 |
| Latest commit (analyzed) | 2026-03-21 |
| GitHub stars | ~30,500 |
| Forks | ~3,700 |
| Contributors | 224 |
| Middleware stages | 13 (ordered pipeline) |
| IM channels | 3 (Feishu, Slack, Telegram) |
| Supported languages (i18n) | 2 (English, Chinese) |
| Backend runtime | Python 3.12+ (FastAPI, LangGraph, uvicorn) |
| Frontend runtime | Next.js 16 / React 19 / TypeScript 5.8 |
| License | MIT |

## Key Dependencies

| Dependency | Purpose | Layer |
|-----------|---------|-------|
| LangGraph | Agent workflow orchestration, state graph | Backend core |
| LangChain | Model abstraction, tool framework, middleware base | Backend core |
| FastAPI | Gateway API server | Backend gateway |
| uvicorn | ASGI server | Backend gateway |
| Pydantic | Configuration validation, data models | Backend |
| Nginx | Reverse proxy, SSE streaming, CORS | Infrastructure |
| Next.js 16 | App Router, SSR, frontend framework | Frontend |
| React 19 | UI rendering | Frontend |
| @langchain/langgraph-sdk | LangGraph client, SSE streaming | Frontend |
| @tanstack/react-query | Server state management | Frontend |
| Radix UI | Headless component primitives | Frontend |
| Tailwind CSS 4 | Styling | Frontend |
| CodeMirror 6 | Code editing in artifact viewer | Frontend |
| Shiki | Syntax highlighting | Frontend |
| better-auth | Authentication | Frontend |

## How DeerFlow Differs from AllTheSkillsAllTheAgents

| Dimension | DeerFlow | AllTheSkillsAllTheAgents |
|-----------|----------|--------------------------|
| Primary purpose | Agent runtime + harness | Skill/orchestration toolkit for Claude Code |
| Language | Python backend + TypeScript frontend | Markdown skills + TypeScript conventions |
| Scale | ~58k LoC across 421 files | ~48 skill files, ~5k lines of skill definitions |
| Agent runtime | Built-in LangGraph supervisor | Delegates to Claude Code's native runtime |
| Model support | Any OpenAI-compatible + Anthropic + Google + local | Claude models via Claude Code |
| Middleware | 13-stage ordered pipeline with typed hooks | No middleware — skills are declarative |
| Sandbox execution | Docker/K8s isolated containers | Claude Code's built-in Bash tool |
| Memory | Persistent cross-session with confidence-scored facts | File-based auto-memory in ~/.claude/ |
| Cost management | None — no LiteLLM, no budget controls | No built-in (planned via The Hive) |
| Autoscaling | None — single-instance deployment | N/A (runs in Claude Code session) |
| Observability | External only (LangSmith, Langfuse) | None built-in |
| IM integration | Feishu, Slack, Telegram channels | None |
| Frontend | Full Next.js web UI with streaming | Claude Code CLI |
| File ownership | No concept | Exclusive file ownership per agent role |
| Contract-first | No | Yes — contracts authored before implementation |

## Origin and Trajectory

DeerFlow v1 shipped in 2025 as a focused deep research framework with a 9-node LangGraph StateGraph pipeline (Coordinator → Planner → Research Team → Reporter). Developers began using its Docker-based execution to build automated data pipelines, dashboards, and content workflows. That community signal prompted a ground-up rewrite sharing zero code with v1.

DeerFlow 2.0 launched February 28, 2026, hit #1 on GitHub Trending the same day, and sustained rapid growth to ~30,500 stars. The v2 architecture is fundamentally different: a single supervisor agent (`make_lead_agent()`) with a 13-stage middleware pipeline replaces v1's explicit multi-node graph. The v1 research pipeline is maintained on the 1.x branch; in v2, research is handled through the skills system.

The project is actively refactoring (PR #1131, March 2026) to separate the publishable harness (`deerflow.*` packages) from the deployment-specific app layer (`app.*`), with the goal of publishing a standalone `deerflow-harness` pip package. This separation is enforced by automated tests — the harness never imports from app.

**Top contributors by commit count:**

| Contributor | Commits |
|-------------|---------|
| Henry Li | 605 |
| Li Xin | 203 |
| Willem Jiang | 159 |
| hetaoBackend | 83 |
| DanielWalnut | 63 |
| LofiSu | 63 |
| hetao | 63 |
| ruitanglin | 56 |
| JeffJiang | 37 |
| He Tao | 30 |

## Benchmark Performance

The LiveResearchBench paper (arXiv:2510.14240) benchmarked Deerflow+ (enhanced with GPT-5 backbone) at **72.9 overall** — 3rd globally among 17 systems. Its standout metric is **citation association at 81.4** (#1 among multi-agent systems). Coverage (61.6) is its weakest dimension, attributed to context window bottlenecks when retrieval scales to thousands of pages. The benchmark validates DeerFlow as a genuine research tool, not just a search aggregator.
