# Four frameworks, one architect's field guide

**OpenClaw, Gastown, Beads, and GStack represent four fundamentally different layers of the agentic AI stack — not four competing orchestration frameworks.** Understanding what each one actually is (and is not) is the single most important insight for an engineer designing their own system. OpenClaw is a persistent autonomous agent daemon with a chat-native interface and 310K+ GitHub stars. Gastown is a multi-agent coding orchestrator that manages 20–30 parallel AI sessions. Beads is the git-native task memory layer that sits beneath orchestrators like Gastown. GStack is a SKILL.md-based workflow skill pack that transforms Claude Code into a role-based engineering team. Together they reveal the architecture of where agentic AI is heading in 2026 — and every design decision relevant to building your own framework.

---

## OpenClaw: the always-on agent daemon

OpenClaw (formerly Clawdbot → Moltbot → OpenClaw) is an MIT-licensed, local-first autonomous AI agent created by Peter Steinberger, with **310K+ GitHub stars** and 18,372+ commits as of March 2026 — the most-starred non-aggregator software repo on GitHub. NVIDIA announced NemoClaw at GTC. The creator joined OpenAI in February 2026 and is moving the project to an open-source foundation.

### Architecture: five subsystems in one Node.js process

OpenClaw runs as a single long-lived daemon (the "Gateway") exposing a WebSocket control plane on `:18789`. Five subsystems handle the full lifecycle:

1. **Channel Adapters** normalize inbound messages from 12+ platforms (WhatsApp via Baileys, Telegram via grammY, Discord, Slack, Signal, iMessage, IRC, Teams, Matrix, LINE) into a common format
2. **Session Manager** resolves sender identity and routes conversations — DMs collapse into a main session; groups get their own
3. **Command Queue** serializes runs per session lane, preventing tool conflicts and state corruption
4. **Agent Runtime** assembles context (AGENTS.md + SOUL.md + TOOLS.md + MEMORY.md + daily logs + conversation history), then runs a ReAct loop: call model → execute tool calls → feed results → repeat
5. **Control Plane** serves the CLI, macOS app, web UI, and mobile nodes over WebSocket

All state lives as **plain Markdown and YAML files on disk** in `~/.openclaw/`, backed by SQLite. No Redis. No Pinecone. Git-backupable, grep-able.

### Orchestrator/router layer

The Gateway routes messages based on channel/sender/group bindings configured in `openclaw.json`. Each agent gets its own workspace, memory, skills, and identity. Different agents can target different models — Opus for complex reasoning, Sonnet for routine tasks, Haiku for sub-agents. Failover uses auth profile rotation with exponential backoff across providers.

The critical design choice: **messages are serialized per session lane**. One message processes at a time per session. This prevents state corruption but limits per-session throughput. Sub-agents run in a global lane with configurable concurrency (`maxConcurrent: 8`).

### SKILL.md format and the skill ecosystem

Each skill is a directory containing a `SKILL.md` file with YAML frontmatter and natural-language instructions:

```yaml
---
name: github-pr-reviewer
description: Review GitHub pull requests and post feedback
metadata:
  openclaw:
    requires:
      bins: ["gh"]
      env: ["GITHUB_TOKEN"]
      config: ["browser.enabled"]
    primaryEnv: "GITHUB_TOKEN"
---

# GitHub PR Reviewer
When asked to review a pull request:
1. Use web_fetch to retrieve the PR diff from the GitHub URL
2. Analyze for correctness, security issues, and code style
3. Structure review as: Summary, Issues Found, Suggestions
```

Skills are **not** bulk-injected into context. A compact XML list (~24 tokens per skill) is injected; full SKILL.md content loads on-demand only when the model selects a skill. This keeps the base prompt lean regardless of installed skill count.

The ecosystem includes **5,400+ community skills** via ClawHub, but security is a serious problem. Cisco found **26% of audited skills had vulnerabilities**, and 230+ malicious skills were uploaded to ClawHub in the first week of February 2026. **CVE-2026-25253** (CVSS 8.8) enabled cross-site WebSocket hijacking with RCE on 21,000+ exposed instances.

### Three-tier memory architecture

| Tier | Storage | Lifecycle |
|------|---------|-----------|
| Session transcripts | JSONL files, append-only | Per-session, compacted when context exceeded |
| Daily logs | `memory/YYYY-MM-DD.md` | Ephemeral, agent retrieves on-demand |
| Long-term memory | `MEMORY.md` | Curated by agent over time, read at session start |

Context window management uses a compaction process that summarizes older turns when the window fills. Embedding-based search uses `sqlite-vec` for retrieval. The system needs at least **64K tokens of context** to function reliably.

### Multi-agent coordination

Three communication primitives:

- **`agentToAgent`**: Direct peer messaging between named agents with their own workspaces
- **`sessions_send`**: Fire-and-forget or synchronous messaging via addressable session keys
- **`sessions_spawn`**: Background sub-agents in isolated sessions, with results announced up the hierarchy

Sub-agent depth maxes at 2. Depth-0 (main) spawns depth-1 (orchestrators), which spawn depth-2 (leaf workers). Results flow upward through an "announce chain." For deterministic workflows, OpenClaw includes **Lobster** — a YAML-based workflow engine that handles routing while LLMs do creative work.

### LLM provider abstraction

All providers look identical from the Gateway's perspective — OpenAI-compatible endpoints. Cloud (Anthropic, OpenAI, Google) and local (Ollama, LM Studio) are interchangeable. Per-agent model configuration:

```json
{
  "agents": {
    "list": [{"id": "main", "model": "claude-sonnet-4-20250514"}],
    "defaults": {
      "subagents": {"model": "claude-haiku-3-5"}
    }
  }
}
```

Cost ranges from **$5–20/month** for light usage to thousands for unoptimized power users. Local models eliminate per-token cost but need ≥32B parameters and ≥24GB VRAM.

### Key trade-offs and gotchas

OpenClaw's **files-over-databases** philosophy scales poorly for large deployments but excels for personal/small-team use. The **single-process architecture** means no horizontal scaling and a single point of failure. Community skills without sandboxing enable rapid ecosystem growth but create a massive attack surface. The heartbeat scheduler enables proactive behavior but can drain API budgets overnight if misconfigured — one user reported $70/month in redundant calls. Memory compaction is lossy. Sub-agent session IDs are auto-generated UUIDs, not meaningful names.

Community projects include **IronClaw** (Rust reimplementation by Near AI), **NanoClaw** (Docker-containerized), **GitClaw** (runs on GitHub Actions), and **TenacitOS** (real-time dashboard).

---

## Gastown: Kubernetes for AI coding agents

Gastown (officially "Gas Town") is a multi-agent orchestration system created by Steve Yegge — 40+ years at Amazon, Google, Sourcegraph. Released January 2026, **~12.4K stars**, MIT license, written in Go (~189K lines). Tagline: **"Multi-agent orchestration system for Claude Code with persistent work tracking."** Yegge explicitly states the entire system was "100% vibecoded" — he never looked at the code.

### Architecture: two-level hierarchy

Gas Town doesn't replace your AI coding tool. It's an orchestration layer **on top of** existing agents (Claude Code, Codex, Cursor, Gemini, Augment, AMP). The architecture:

- **Town** (`~/gt/`): Headquarters housing configuration, town-level agents (Mayor, Deacon, Dogs), and cross-project orchestration
- **Rigs**: Project-specific Git repositories under Gas Town management, each with its own Polecats, Refinery, Witness, and Crew members

Every piece of state is **Git-backed**. Agent identity, work items, role instructions, hooks — all stored in Git, branching and merging with the code. This is the foundational design decision.

### The Mayor and MEOW routing

The **Mayor** is the primary interface agent — a Claude Code instance with full context about the workspace. The human ("Overseer") talks to the Mayor, who coordinates everything through **MEOW** (Mayor-Enhanced Orchestration Workflow):

1. Tell the Mayor what you want
2. Mayor analyzes and breaks work into **beads** (atomic work items)
3. Mayor creates a **convoy** (batch work tracking unit) containing the beads
4. Mayor spawns agents and distributes beads via `gt sling`
5. Progress monitored through convoy status
6. Mayor synthesizes results

Current routing uses hardcoded cost tiers (`standard`/`economy`/`budget`) mapped to agent presets. An intelligent routing enhancement (Issue #2784, March 2026) adds task-complexity-based tier selection, Witness→Router feedback for excluding failed agents, and dynamic tier selection from bead metadata. This router runs as a function call during dispatch, not as a persistent agent.

### Eight operational roles

| Role | Scope | Function |
|------|-------|----------|
| **Mayor** 🎩 | Town | Global coordinator, never writes code |
| **Deacon** | Town | Background supervisor daemon, health patrol |
| **Witness** | Per-rig | Polecat lifecycle manager, detects stuck agents |
| **Refinery** | Per-rig | Merge queue processor |
| **Polecat** | Rig | Ephemeral grunt workers in isolated git worktrees |
| **Crew** | Rig | Persistent named agents for sustained work |
| **Dog** | Town | Infrastructure maintenance helpers |
| **Overseer** | Town | The human operator |

This is fundamentally different from frameworks like CrewAI or BMAD that simulate org charts (Analyst→PM→Architect→Dev). Gas Town uses **operational coordination roles**, not SDLC personas. The Mayor doesn't pretend to be a product manager — it's a dispatch system.

### Parallel execution and merge management

Each Polecat works in its own **git worktree** — complete filesystem isolation. Multiple Polecats work in parallel without file-stomping. The system uses **tmux** for UX — multiple terminal panes showing different agents.

The **Refinery** processes the merge queue per rig, handling conflicts when late-finishing agents find main has moved. It can "creatively re-imagine" implementations when conflicts get hairy — a documented risk.

Communication uses a **mail system** (`gt mail send/inbox/read`) backed by Dolt, plus **nudges** for real-time alerts. The Witness includes a **spawn circuit breaker** (`MaxBeadRespawns`) to prevent infinite respawn loops, sending `SPAWN_BLOCKED` mail to the Mayor when triggered.

### Context window management via GUPP

**GUPP** (Gas Town Universal Propulsion Principle): "If there is work on your Hook, YOU MUST RUN IT." When a session's context window fills, the agent hands off via `gt handoff` or the automatic **PreCompact** trigger. The new session picks up by checking its hook. A "séance" protocol lets the new agent resume the previous session to ask questions about unfinished work.

### LLM provider abstraction

Gas Town abstracts runtimes as agent presets: `claude`, `gemini`, `codex`, `cursor`, `auggie`, `amp`. Custom agents register via `gt config agent set`. Per-role and per-rig overrides enable mixing providers:

```bash
gt config agent set kimi "opencode -m openrouter/moonshotai/kimi-k2.5"
gt sling gt-abc12 myproject --agent cursor
gt mayor start --agent auggie
```

Because every task has completion time, quality signals, and revision count attributed to specific agents, you get built-in **A/B testing** for model evaluation across your fleet.

### Critical gotchas

**Cost is the elephant**: running 20-30 Claude Code instances requires multiple $200/month subscriptions. Yegge runs 3+ Claude Pro Max plans. Estimated **$100/hour burn rate** during active use. The system auto-merges branches even with failing CI — the DoltHub team had to `git reset --hard` after Gas Town merged broken code. Local-only state means no multi-user or team coordination. The Beads daemon can consume 70%+ CPU. The Mad Max-themed terminology (Polecats, Convoys, Rigs, Hooks, Wisps, GUPP, MEOW) creates a steep learning curve. Yegge explicitly targets "Stage 7-8 developers only."

Community projects include **Goosetown** (Block's fork on top of Goose), **multiclaude** (Dan Lorenc's remote-first alternative), and OpenCode integration for multi-provider support via OpenRouter.

---

## Beads: git-native task memory for agents

Beads is the most misunderstood piece of this stack. **It is not an orchestration framework.** It is a **distributed, git-backed graph issue tracker designed for AI coding agents** — "a memory upgrade for your coding agent." Created by Steve Yegge, **18.1K stars**, MIT license, written in Go. Gastown uses Beads as its work-tracking backbone.

### The "50 First Dates" problem

AI coding agents wake up each session with no memory of previous work. They lose context as context windows fill, forget architectural decisions, and can't track what's done vs. what's next. Markdown-based plans (TODO.md, PLAN.md) rot fast — agents can't update them reliably, and reconstructing work graphs from scattered files wastes tokens.

Beads solves this with **hash-based work items stored in Git**:

```bash
bd create "Implement user authentication" -p 1 -t feature --json
bd create "Add password hashing" -p 1 --deps discovered-from:bd-a1b2 --json
bd ready --json     # Returns only unblocked tasks, topologically sorted
bd update bd-a1b2 --claim   # Atomic claiming
bd close bd-a1b2 --reason "Completed, all tests passing"
```

### Storage evolution

Beads has evolved through two backends:

**Legacy (pre-v0.50)**: JSONL + SQLite hybrid. Source of truth was `.beads/issues.jsonl` (Git-tracked, append-only). SQLite hydrated on startup for fast queries.

**Current (v0.50+)**: **Dolt-powered** — a version-controlled SQL database with cell-level merge and native branching. Every write auto-commits to Dolt history. Dolt push/pull for sync across machines.

Hash-based IDs (e.g., `bd-a1b2`) prevent merge conflicts across agents and branches — no coordination needed.

### Token-efficient context injection

`bd prime` generates ~80 lines (~1–2K tokens) of dynamic workflow context. Compare this to MCP schemas at ~10–50K tokens. `bd ready` performs **topological sort server-side** so agents don't burn tokens analyzing dependency graphs. The tool does the thinking for the agent.

### What Beads explicitly does not do

Beads is **passive** — it provides shared memory that multiple agents read/write but does NOT actively coordinate them. Yegge is explicit: "orchestration doesn't belong in Beads." It has no LLM provider abstraction, no agent routing, no inter-agent communication. It's the database layer beneath orchestration frameworks.

### Multi-agent coordination via complementary tools

The recommended pattern is **Beads + MCP Agent Mail** (by Jeffrey Emanuel):
- Beads = shared memory (task state, dependencies, priorities)
- MCP Agent Mail = messaging (inboxes, file reservations, coordination)
- Together: "agents quickly decide on a leader and just split things up"

Six orchestration layers have been built on top of Beads: **Gas Town** (Yegge), **The Claude Protocol** (enforcement-first, one bead = one worktree = one PR), **Metaswarm** (18 agents, 13 skills, recursive swarm-of-swarms), **JAT** ("World's First Agentic IDE"), **Overstory** (pluggable runtime adapters), and **Perles** (TUI with BQL query language).

### Gotchas at scale

Performance degrades beyond ~500 issues. JSONL files exceeding ~25K tokens break agents that read files directly. `bd edit` opens an interactive editor — hangs agent processes (must use `bd update` with flags). Agents in long sessions forget about Beads by hour two. A **Rust reimplementation** (`br`) now exists and is actively maintained alongside the Go original.

---

## GStack: role-based SKILL.md workflow layer

GStack is a Claude Code skill pack created by Garry Tan (Y Combinator CEO), released March 12–13, 2026. **12–16K stars** in the first 48 hours. MIT license. It is not a general-purpose framework — it's a set of **13 opinionated SKILL.md-defined specialist personas** plus a compiled native browser binary.

### The "one mushy mode" problem

A single AI agent provides unfocused output when asked to plan, code, review, and ship simultaneously. GStack enforces **cognitive modes** — explicit personas with distinct priorities:

| Slash Command | Role | Function |
|---------------|------|----------|
| `/plan-ceo-review` | Founder/CEO | Rethinks the problem; finds the "10-star product" |
| `/plan-eng-review` | Eng Manager | Architecture, data flow, failure modes, test matrix |
| `/plan-design-review` | Designer | 80-item design audit with letter grades |
| `/review` | Staff Engineer | Finds bugs that pass CI but blow up in production |
| `/ship` | Release Engineer | Syncs main, runs tests, pushes, opens PR |
| `/browse` | QA Engineer | Real Chromium browser, real clicks, real screenshots |
| `/qa` | QA Lead | Diff-aware testing, auto-generates regression tests |
| `/retro` | Engineering Manager | Team-aware weekly retro with per-person breakdowns |

### SKILL.md template system

Each skill is a directory with `SKILL.md` (active) and `SKILL.md.tmpl` (source template). The setup script creates **symlinks** in `.claude/skills/` pointing into the gstack directory. Changes to templates propagate immediately across all sessions.

The skill content pattern includes context gathering (read CLAUDE.md, TODOS.md, git log), step-by-step workflows with explicit STOP points and `AskUserQuestion` interactive checkpoints, dual effort estimation (human team vs. Claude+gstack), observability requirements, and eval requirements.

### The browser: GStack's key technical innovation

A persistent headless Chromium daemon communicating over localhost HTTP, built with Playwright and compiled to a native **~58MB binary via Bun**. Cold start ~3–5 seconds, subsequent calls ~100–200ms, auto-shutdown after 30 minutes idle. Each workspace gets isolated Chromium processes, cookies, tabs, and logs. Cookie import reads Chrome/Arc/Brave/Edge SQLite databases directly using Bun's native SQLite.

### What GStack explicitly chose not to do

GStack is **Claude Code-exclusive** — no multi-provider support, no model switching, no fallback. No inter-agent communication or handoff protocols. Coordination is human-mediated. No shared state between parallel sessions by design. The community project **gstack-auto** adds semi-autonomous orchestration on top.

### Critical limitation

Context window pressure from running multiple skills sequentially in one Claude Code session has no built-in mitigation. Running on Opus with cascading skill invocations can fill the context window quickly.

---

## How these four compare on key dimensions

| Dimension | OpenClaw | Gastown | Beads | GStack |
|-----------|----------|---------|-------|--------|
| **What it is** | Autonomous agent daemon | Multi-agent coding orchestrator | Git-native task memory | SKILL.md workflow layer |
| **Primary interface** | Messaging apps (WhatsApp, Telegram, etc.) | tmux terminal | CLI (`bd`) | Claude Code slash commands |
| **Language** | Node.js | Go | Go (+ Rust `br`) | Markdown + Bun/TypeScript |
| **State backend** | Markdown + SQLite on disk | Git (worktrees, JSONL) | Git (Dolt/JSONL) | JSONL files + TODOS.md |
| **Multi-provider** | Yes (any OpenAI-compatible) | Yes (agent presets) | N/A (model-agnostic) | Claude only |
| **Multi-agent** | Yes (spawn, peer, session) | Yes (20-30 parallel agents) | No (passive memory) | No (isolated sessions) |
| **SKILL.md** | Yes (YAML frontmatter + markdown) | Via Claude Code native | Via AGENTS.md convention | Yes (template-generated) |
| **Memory model** | 3-tier (session/daily/long-term) | Git-backed hooks + mail | Task graph with compaction | JSONL reviews + TODOS.md |
| **Proactive** | Yes (heartbeat scheduler) | Yes (Deacon daemon) | No | No |
| **GitHub stars** | 310K+ | ~12.4K | ~18.1K | ~16K |
| **Target user** | Power users wanting a personal AI | Stage 7-8 developers | Any developer using coding agents | Claude Code users |

The key insight: **these are layers, not competitors.** You could run GStack's SKILL.md skills inside a Claude Code session that's being orchestrated by Gastown, tracking work in Beads, while OpenClaw handles the messaging interface. In practice, Gastown already uses Beads as its memory backbone.

---

## Ecosystem context: what the established frameworks teach us

### SKILL.md is becoming a standard

Published by Anthropic at agentskills.io in December 2025, the **SKILL.md specification** is now supported across Claude Code, OpenAI Codex, VS Code Copilot, Microsoft Agent Framework, and OpenClaw. The format is simple: a directory containing a `SKILL.md` file with YAML frontmatter (`name`, `description`, `license`, `compatibility`, `metadata`) and markdown instructions, plus optional `scripts/`, `references/`, and `assets/` directories.

The **progressive disclosure model** is the critical design pattern: metadata (~100 tokens) loads at startup for all skills; full instructions (<5000 tokens recommended) load on activation; resources load only when needed. This keeps context lean at scale. Platform locations vary: `~/.claude/skills/` for Claude Code, `~/.codex/skills/` for OpenAI Codex, `.github/skills/` for VS Code Copilot.

The complementary **AGENTS.md** pattern (plain markdown at repo root with project conventions, build commands, code standards) has been adopted by Claude Code (as CLAUDE.md), Cursor, GitHub Copilot, Gemini CLI, Windsurf, Aider, Zed, Warp, and more. Best practice: keep root small, use progressive disclosure with separate files in an `agent_docs/` directory.

### Multi-provider routing: LiteLLM dominates but alternatives emerge

**LiteLLM** is the dominant open-source LLM router with a unified interface across 100+ providers via OpenAI-compatible API. Five routing strategies: `simple-shuffle` (RPM/TPM-weighted random, recommended for production), `least-busy`, `latency-based`, `usage-based`, and `cost-based`. Fallback chains with cooldowns for failed deployments, Redis for shared state across proxy instances.

**Bifrost** (by Maxim AI) offers <11µs overhead at 5K RPS — 50x faster than LiteLLM — written in Go. **Helicone** provides PeakEWMA load-balancing with 95% cost savings via caching. Anthropic now supports OpenAI SDK compatibility (`base_url="https://api.anthropic.com/v1/"`), reducing the abstraction burden.

The **Vercel AI SDK** provides the cleanest TypeScript abstraction: same `generateText()`, `streamText()`, `generateObject()` API across `@ai-sdk/openai`, `@ai-sdk/anthropic`, `@ai-sdk/google`. For your polyglot stack, the pattern to steal is: define a `LLMProvider` abstract interface with `create_message(messages, tools, **kwargs)`, implement per-provider, and handle tool-calling format translation at the provider layer.

### Memory architectures are converging on four types

The field has converged on a taxonomy from cognitive science (formalized by Princeton's CoALA framework):

- **Working memory**: current conversation context in the LLM context window — session-scoped
- **Episodic memory**: specific past experiences with temporal metadata — stored in vector DBs with timestamps
- **Semantic memory**: accumulated facts, user preferences, domain knowledge — knowledge graphs or structured DBs
- **Procedural memory**: learned behaviors and skills — system prompts, code, SKILL.md files

The production pattern emerging is **hybrid memory**: critical operations (checkpoints, session state) are managed programmatically; optional operations (what to remember/forget) are tool-based, invoked by the agent. **Redis** is becoming the unified platform for short-term + long-term + episodic memory with microsecond lookups. **PostgreSQL + pgvector** dominates enterprise deployments with row-level security and ACID transactions.

For context window management, three strategies dominate: LLM-based summarization (risk: losing details), vectorization for semantic search (approximate k-NN in milliseconds), and structured extraction of factual claims into separate storage.

### Tool registries at scale need deferred loading

**MCP** (Model Context Protocol) is the emerging standard, now hosted by the Linux Foundation. Architecture: Host (AI app) → Client (one per server) → Server (exposes tools, resources, prompts). The **MCP Registry** launched in preview September 2025 as a metaregistry referencing NPM/PyPI/Docker Hub for actual code.

For hundreds or thousands of tools, Anthropic's **Tool Search Tool** is the breakthrough pattern: mark tools with `defer_loading: true` so they're not loaded into context initially. Claude discovers tools on-demand via search, yielding **85% reduction in token usage** while accuracy improves (Opus 4: 49%→74%). The architectural lesson: never load all tool schemas upfront. Use progressive disclosure: compact metadata → description → full schema → execution.

### How established frameworks compare to the four

| Dimension | LangChain/LangGraph | CrewAI | AutoGen/MS Agent Framework | Anthropic Patterns |
|-----------|--------------------|---------|-----------------------------|-------------------|
| **Abstraction** | Graph-based workflows with state machines | Role-based agent teams | Conversational multi-agent with enterprise features | Composable patterns: chaining, routing, parallelization |
| **Routing** | Conditional edges evaluating shared state | Sequential/hierarchical/consensual processes | Typed graph-based data flow | Classify input → route to specialized handler |
| **Memory** | Reducer-driven state + LangMem SDK | Built-in short/long/entity/contextual | Session-based + Azure AI Foundry | Orchestrator holds global state, specialists hold task state |
| **Tools** | Pluggable toolkits as graph nodes + MCP | Agent-assigned tools with task overrides | `@ai_function` decorator + SKILL.md + MCP | Tool Search Tool for deferred loading |
| **Multi-agent** | Parallel execution with sync (fork/join) | Coordinator-worker + peer groups | GraphFlow + Magentic One patterns | Orchestrator-workers + evaluator-optimizer loops |

The four frameworks you asked about occupy different niches than these established players. LangChain/CrewAI/AutoGen are **SDKs for building custom agent applications**. OpenClaw is a **complete running agent system**. Gastown is an **orchestration layer for existing coding agents**. Beads is **infrastructure** beneath orchestration. GStack is a **domain-specific workflow layer** for Claude Code.

---

## Architectural lessons for building your own framework

Based on everything these frameworks teach, here are the patterns and anti-patterns most relevant to building a polyglot, multi-provider orchestration framework.

### Orchestrator/router layer

**Steal from Gastown**: separate the routing decision from the execution runtime. Gastown's agent presets (`claude`, `gemini`, `codex`, `cursor`) abstract the runtime completely — the orchestrator doesn't care which tool executes, only that the task gets done. For your system, define a `RuntimeAdapter` interface that wraps any coding agent or LLM provider.

**Steal from Anthropic**: their five composable patterns (chaining, routing, parallelization, orchestrator-workers, evaluator-optimizer) are primitives, not frameworks. Implement these as composable building blocks rather than rigid workflow types. Anthropic's research found that **80% of performance variance is explained by token usage alone** — the architecture of routing matters less than ensuring agents have enough context.

**Steal from LiteLLM**: implement provider-level routing with fallback chains, RPM/TPM-weighted distribution, and cooldowns for failed deployments. Use Redis for shared rate-limit state if running multiple proxy instances.

### Skill/tool registry

**Adopt SKILL.md** — it's becoming the standard. The progressive disclosure model (metadata → instructions → resources) is the right architecture for scale. Keep per-skill metadata under 100 tokens and full instructions under 5000 tokens.

**Steal from Anthropic's Tool Search Tool**: deferred loading with on-demand discovery is the only pattern that works at hundreds of tools. Don't load all schemas upfront. Implement semantic search over tool descriptions with a fallback to BM25/regex.

**Steal from MCP**: define tools as MCP servers with a standardized discovery protocol. This gives you ecosystem compatibility for free.

### Agent memory and state

**Steal from OpenClaw's three-tier model**: session transcripts (JSONL, append-only), daily ephemeral logs, and curated long-term memory (MEMORY.md). The append-only pattern is crash-safe and git-friendly.

**Steal from Beads' topological sort**: perform graph analysis server-side, not in the LLM's context window. `bd ready` returning only unblocked tasks is the right pattern — the tool does the computation, the agent consumes the result.

**Steal from Gastown's GUPP**: persistent hooks that survive session restarts. The handoff/séance protocol for context window recovery is elegant — when a session fills its context, the new session can resume the old one to ask questions about unfinished work.

**Choose your backend carefully**: start with SQLite + files for local development, PostgreSQL + pgvector for production. Redis for hot-path memory if latency matters. Avoid vector-only solutions — you need both structured queries and semantic search.

### Multi-agent coordination

**Steal from Gastown's git worktree isolation**: parallel agents need filesystem isolation. Git worktrees provide this with built-in merge tooling.

**Steal from OpenClaw's serialized session lanes**: prevent state corruption by serializing execution per conversation/session. Run different sessions in parallel, but never two messages in the same session simultaneously.

**Steal from Beads' hash-based IDs**: content-hashed identifiers for work items prevent merge conflicts across agents and branches without coordination.

**Implement both synchronous and fire-and-forget messaging**: OpenClaw's `sessions_send(sessionKey, message, timeoutSeconds?)` with `timeoutSeconds: 0` for async and a positive value for sync covers both patterns cleanly.

### What to explicitly avoid

- **Don't simulate org charts** (the CrewAI/BMAD trap). Use operational coordination roles like Gastown.
- **Don't use a single LLM call for routing** at the orchestrator level. Use deterministic routing where possible, LLM routing only when task classification is genuinely ambiguous.
- **Don't build a monolithic process** like OpenClaw unless you're building a personal assistant. For a team framework, distribute state and allow horizontal scaling.
- **Don't trust community skills without sandboxing**. OpenClaw's 26% vulnerability rate is a warning.
- **Don't load all tools into context**. Progressive disclosure or deferred loading is non-negotiable at scale.
- **Don't skip compaction**. Both OpenClaw and Beads implement memory decay — summarizing old content to manage growth. Budget tokens for this.

---

## Conclusion

The four frameworks reveal that **the agentic AI stack is stratifying into distinct layers**: messaging/interface (OpenClaw), multi-session orchestration (Gastown), persistent task memory (Beads), and workflow/skill definitions (GStack/SKILL.md). No single framework covers all layers well, which is precisely why building your own is defensible.

The most important architectural bets to make: adopt SKILL.md as your skill format (it's winning); use git-backed state for auditability with a proper database (Dolt or PostgreSQL) for queries; implement progressive tool disclosure from day one; separate the routing decision from the runtime adapter; and build hybrid memory (programmatic for critical ops, agent-controlled for everything else). The frameworks that are thriving — OpenClaw at 310K stars, Beads at 18K — share one trait: they're **opinionated about persistence and context management** while being **agnostic about which LLM runs underneath**. That's the design center to target.