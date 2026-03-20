# Mission Control: the most complete open-source agent dashboard dissected

**Mission Control by builderz-labs is the most feature-dense open-source agent orchestration dashboard available today — 32 panels, 101 API routes, and a Zustand-driven SPA shell powered by Next.js 16, React 19, and SQLite.** It launched on February 27, 2026 and reached ~2.7k GitHub stars in under a month. For The Hive, it represents both the clearest architectural blueprint to learn from and a sharp warning about the tradeoffs of building a monolithic "single pane of glass" rather than a composable, component-based orchestration framework. This report covers every implementation detail that matters for The Hive's design.

---

## Who built it and why it exists

Mission Control was built by **Builderz Labs**, a full-stack engineering agency co-founded by **Nyk (0xNyk)** and **Kulture** in 2022. The team operates across Dubai, Vietnam, Germany, and Pakistan. They started as a Solana development shop (originally "Cynova"), shipping 32+ products including dApp scaffolds, NFT royalty tools, and a recurring crypto payments platform. Their pivot to AI agent infrastructure reflects a bet that "running AI agents at scale means juggling sessions, tasks, costs, and reliability across multiple models and channels" — a pain point their own team experienced.

The codebase was developed internally before the open-source release. All four tagged releases (v1.0.0 through v1.3.0) shipped within **three days** (February 27–March 2, 2026), each already containing substantial security hardening, Docker support, and hundreds of tests. The project is **MIT licensed, self-hosted first, with no telemetry**. A hosted Pro tier ($29/month) is planned but not yet launched.

**Key metrics as of March 2026:**

| Metric | Value |
|--------|-------|
| GitHub stars | ~2,700 |
| Forks | ~471 |
| Panels | 32 feature panels |
| API routes | 101 REST endpoints |
| Schema migrations | 39 (SQLite) |
| Unit tests | 165 (Vitest) |
| E2E tests | 295 (Playwright) |
| License | MIT |

---

## The full tech stack and architectural decisions

Mission Control is a **Next.js 16 App Router** application that functions as a single-page application despite being a Next.js project. The root `src/app/page.tsx` acts as an SPA shell, rendering one of 32 panels based on **Zustand 5 store state** — not URL routing. A vertical **NavRail** dispatches panel changes by updating the Zustand store's active panel identifier. This is an unusual but deliberate choice: it keeps the entire dashboard in a single page context, enabling persistent WebSocket connections, live feeds, and continuous state without remounts.

| Layer | Technology | Notes |
|-------|-----------|-------|
| Framework | Next.js 16 (App Router) | SPA shell, server components by default |
| UI | React 19, Tailwind CSS 3.4 | Semantic design tokens (text-foreground, bg-card) |
| Language | TypeScript 5.7 strict | No `any` unless absolutely necessary |
| Database | SQLite via better-sqlite3 | WAL mode, 39 migrations, PRAGMA foreign_keys |
| State | Zustand 5 | Single store at `src/store/index.ts` |
| Charts | Recharts 3 | Token usage, cost trends |
| Graph visualization | React Flow (@xyflow/react ^12.10.0 + reactflow ^11.11.4) | Knowledge graph, dual version indicates migration |
| Real-time | WebSocket (ws ^8.19.0) + SSE | Gateway comms + browser push |
| Validation | Zod ^4.3.6 | 12+ schemas across mutation endpoints |
| Logging | Pino ^10.3.1 | Structured, replaced all console.log |
| Testing | Vitest + Playwright | 460 total tests |
| Auth | scrypt + Ed25519 + session tokens | RBAC with three roles |

**The critical architectural decision** is zero external dependencies. No Redis, no Postgres, no Docker requirement, no message queue. SQLite in WAL mode handles everything. This makes deployment trivial (`pnpm start`) but imposes a **single-writer constraint** — only one instance can run against a given `.data/` directory. This is the most important scaling limitation for The Hive to note.

### Source tree structure

```
mission-control/
├── src/
│   ├── proxy.ts                    # Auth gate + CSRF + network access control
│   ├── app/
│   │   ├── page.tsx                # SPA shell — routes all 32 panels via Zustand
│   │   ├── login/page.tsx          # Login page
│   │   └── api/                    # 101 REST API routes
│   ├── components/
│   │   ├── layout/                 # NavRail, HeaderBar, LiveFeed
│   │   ├── dashboard/              # Overview dashboard panel
│   │   ├── panels/                 # 32 feature panels
│   │   └── chat/                   # Agent chat UI
│   ├── lib/
│   │   ├── auth.ts                 # Session + API key auth, RBAC
│   │   ├── db.ts                   # SQLite (better-sqlite3, WAL mode)
│   │   ├── claude-sessions.ts      # Local Claude Code session scanner
│   │   ├── claude-tasks.ts         # Claude Code team task/config bridge
│   │   ├── schedule-parser.ts      # Natural language → cron (zero deps)
│   │   ├── recurring-tasks.ts      # Template-clone spawner
│   │   ├── migrations.ts           # 39 schema migrations
│   │   ├── scheduler.ts            # Background task scheduler
│   │   ├── webhooks.ts             # Outbound webhook delivery + retry
│   │   ├── websocket.ts            # Gateway WebSocket client
│   │   ├── device-identity.ts      # Ed25519 device identity for gateway auth
│   │   ├── agent-sync.ts           # OpenClaw config → MC database sync
│   │   └── models.ts               # Dynamic model catalog
│   └── store/index.ts              # Zustand state management
└── .data/                          # Runtime data (SQLite DB, token logs)
```

---

## All 32 panels documented

This is the complete inventory of every panel in Mission Control, organized by functional domain. The panel count has evolved: **26 (v1.0.0) → 28 (v1.2) → 31 (marketing site) → 32 (current main)**. Each panel is a React component in `src/components/panels/`.

### Core operations (panels 1–6)

**1. Dashboard (Overview)** — High-level fleet KPIs, system health, aggregate metrics across agents, tasks, sessions, and token usage. The entry point and default view.

**2. Task Board (Kanban)** — The centerpiece. Six columns: **Inbox → Assigned → In Progress → Review → Quality Review → Done**. Features drag-and-drop, configurable priority levels, agent assignment, threaded comments with @-mention notifications, inline sub-agent spawning, and multi-project support with per-project ticket prefixes (e.g., PA-001). Tasks from GitHub sync and Claude Code teams surface here alongside agent-created tasks in collapsible sections.

**3. Agent Management** — Full lifecycle panel: register, heartbeat, wake, retire. The agent detail modal provides a compact overview, inline model selector, editable sub-agent configuration, and SOUL personality editing. Local agent discovery auto-scans `~/.agents/`, `~/.codex/agents/`, and `~/.claude/agents/` for marker files (AGENT.md, soul.md, identity.md, config.json).

**4. Session Inspector** — Real-time session monitoring with pause/terminate controls wired to the gateway CLI via `/api/sessions/[id]/control`. Shows active/completed sessions per agent.

**5. Log Viewer** — Filterable session and agent logs with real-time streaming via SSE. Supports level-based filtering.

**6. Live Feed** — Persistent real-time activity feed (in the layout, visible across all panels) combining logs and activities from WebSocket + SSE push.

### Cost and tokens (panels 7–8)

**7. Token Usage Dashboard** — Per-model breakdowns, trend charts over time, and cost analysis. Built with **Recharts 3**. Data from `token_usage` table with per-session granularity.

**8. Cost Tracking** — Per-agent cost panels with drill-down to session-level spending. Currently "derivable from per-session data"; first-class per-agent cost breakdowns are on the roadmap.

### Quality and evaluation (panels 9–10)

**9. Quality Gates (Aegis)** — The review system that blocks task completion without sign-off. Operates in manual mode (human operator approves/rejects in Quality Review column) or automated mode (scheduler polls and evaluates based on configurable criteria). Each recurring task spawn gets its own independent Aegis gate.

**10. Agent Evals** — Four-layer evaluation framework: output evals against golden datasets, trace evals for convergence scoring (>3.0 flags looping), component evals tracking tool reliability with p50/p95/p99 latency from MCP call logs, and drift detection against a 4-week rolling baseline with 10% threshold. Golden datasets are managed via API and UI.

### Scheduling and automation (panels 11–14)

**11. Cron Management** — Scheduled background tasks: DB backups, stale record cleanup, agent heartbeat monitoring, recurring task spawning, automated quality reviews. Also displays Claude Code teams overview.

**12. Recurring Tasks** — Natural language scheduling ("every morning at 9am", "every 2 hours"). The zero-dependency `schedule-parser.ts` converts expressions to cron. Uses a **template-clone pattern**: the original task becomes a template; spawns dated children (e.g., "Daily Report – Mar 07").

**13. Task Dispatch** — The scheduler polls assigned tasks and runs agents via CLI. Dispatched tasks link to agent sessions for traceability.

**14. Pipelines & Workflows** — Pipeline orchestration with workflow templates for multi-step agent workflows. Start, monitor, and manage from this panel. Implementation details on pipeline DAG structure remain sparse; this appears to be a newer feature.

### Memory and knowledge (panels 15–16)

**15. Memory Browser** — Filesystem-backed memory tree browsing under `OPENCLAW_MEMORY_DIR`. Navigates daily logs, MEMORY.md, and markdown files from `~/clawd-agents/{agent}/memory/`. Also shows per-agent working memory from the SQLite database.

**16. Memory Knowledge Graph** — Interactive node-edge visualization using **React Flow** (@xyflow/react). Renders relationships between sessions, memory chunks, and linked knowledge files. **Only works in gateway mode** (requires OpenClaw connection).

### Communication (panels 17–18)

**17. Agent Comms** — Session-threaded inter-agent communication via the comms API. Three event namespaces: `a2a:*` (agent-to-agent), `coord:*` (coordinator events), `session:*` (session-scoped). Features a coordinator inbox and runtime tool-call visibility in the comms feed.

**18. Agent Chat** — Direct chat interface for human-to-agent interaction. Separate component at `src/components/chat/`.

### Integrations (panels 19–24)

**19. Webhooks** — Outbound webhook management with HMAC-SHA256 signatures, delivery history, retry with exponential backoff and circuit breaker. Manual retry via API.

**20. Alerts** — Configurable alert rules with cooldown periods to prevent alert storms.

**21. Gateway Management (Multi-Gateway)** — Connect to multiple agent gateways simultaneously. OS-level discovery via systemd and Tailscale Serve. Auto-connect with health probes. Live dot indicators show connection state.

**22. GitHub Sync** — Inbound sync from GitHub repositories. Issues appear on the task board with label and assignee mapping. Described as "bidirectional" with "full parity sync" on the marketing site.

**23. Claude Code Sessions** — Auto-discovers local sessions from `~/.claude/projects/`, extracts token usage, model info, message counts, cost estimates, and active status from JSONL transcripts. Scans every 60 seconds.

**24. Claude Code Teams** — Read-only bridge surfacing team tasks from `~/.claude/tasks/<team>/<N>.json` and team configs from `~/.claude/teams/<name>/config.json`. Displays in Task Board (collapsible) and Cron Management (teams overview).

### Skills and security (panels 25–26)

**25. Skills Hub** — Browse, install, and manage agent skills from local directories and two external registries (**ClawdHub** and **skills.sh**). Bidirectional disk↔DB sync via SHA-256 change detection on 60-second scheduler cycles. SKILL.md is the canonical format. Includes a **built-in security scanner** checking for prompt injection, credential leaks, data exfiltration, obfuscated content, and dangerous shell commands before installation.

**26. Security Audit** — Real-time posture scoring (0–100), secret detection across agent messages, MCP tool call auditing, injection attempt tracking, and per-agent trust scores. Three hook profiles — `minimal`, `standard`, `strict` — let operators tune security enforcement per deployment.

### Administration (panels 27–32)

**27. Audit Trail** — Complete action type coverage with grouped filters. Full history for compliance and debugging.

**28. Settings** — System configuration and user management.

**29. Self-Update** — GitHub release check with banner notification. One-click admin update runs `git pull → pnpm install → pnpm build`. Dirty working trees are rejected. All updates audit-logged.

**30. Onboarding Wizard** — Guided 5-step setup: Welcome (capabilities), Credentials (password strength check), Agent Setup (gateway/Claude Code discovery), Security Scan (config audit), Get Started. Progress persisted per user.

**31. Agent Optimization** — Self-improvement recommendations endpoint for agents. Analyzes token efficiency (tokens/task vs fleet average), tool usage patterns (success/failure rates, redundant calls), and generates prioritized recommendations. Fleet benchmarks provide percentile rankings across all agents.

**32. Workspaces (Multi-Tenant)** — Manage tenant instances via `/api/super/tenants`. Bootstrap provisioning jobs for isolated environments with dedicated gateways, state directories, and project trees. Admin can create, monitor, and decommission tenants.

---

## The real-time architecture in detail

Mission Control uses a **dual-protocol** approach with a smart polling fallback. Understanding this is critical for The Hive's design of The Glass and The Trail.

**WebSocket** handles bidirectional gateway communication. The `src/lib/websocket.ts` client maintains a persistent connection to OpenClaw gateways on ports 18789/18790 using the `ws` library. Authentication uses **Ed25519 device identity** — the browser generates a keypair via WebCrypto, and the gateway validates the signed handshake. The connection delivers instant events: agent status changes, session updates, log streams, and coordinator messages. Reconnection uses **jittered exponential backoff** to prevent thundering-herd problems when gateways restart.

**SSE (Server-Sent Events)** handles server-to-browser push. The `/api/events` endpoint streams events to the browser using Next.js App Router's native `ReadableStream` support. This delivers real-time updates for task transitions, agent heartbeats, security events, and system notifications without requiring the browser to poll.

**Smart polling** acts as a fallback. The system uses the **Page Visibility API** (`document.visibilitychange`) to pause polling when the browser tab is hidden, and resumes immediately when the user returns. This reduces server load from background tabs.

The full data flow for a live agent status update:

```
Agent → Framework Adapter → Gateway (WS:18789) → MC Backend (websocket.ts) 
  → SQLite write → SSE push → Browser (Zustand store → Panel re-render)
```

For direct CLI agents (no gateway):

```
Agent → REST API (heartbeat/status) → MC Backend → SQLite → SSE → Browser
```

---

## The Aegis quality gates system

Aegis is Mission Control's answer to the question "how do you prevent agents from marking tasks done when the output is garbage?" It implements a **task-lifecycle gate** integrated directly into the Kanban workflow.

The sixth Kanban column — **Quality Review** — is the gate. Tasks cannot advance to "Done" without explicit approval. This approval comes from two sources: manual human sign-off by an operator, or automated evaluation by the background scheduler running configurable quality criteria.

**The four-layer evaluation stack** makes Aegis genuinely sophisticated:

**Output evals** score task completion against **golden datasets** — curated reference outputs managed via both API (`/api/evals/golden-datasets`) and UI. This answers: "Did the agent produce something that looks like what we expected?"

**Trace evals** compute a **convergence score** from the execution trace. A score above **3.0 flags looping** — the agent is spinning in circles rather than making progress. This catches a real failure mode where LLM agents repeatedly invoke the same tools or revisit the same reasoning patterns.

**Component evals** track **tool reliability** with **p50/p95/p99 latency percentiles** extracted from MCP (Model Context Protocol) call logs. This identifies which tools are slow or unreliable, creating a feedback loop for tool improvement.

**Drift detection** compares current agent performance against a **4-week rolling baseline** with a **10% threshold**. If an agent's behavior drifts beyond 10% from its rolling average, drift is flagged. This catches gradual degradation that point-in-time checks miss.

The **Agent Optimization** panel takes this further with a self-improvement API endpoint. Agents can call this endpoint to receive prioritized recommendations based on their token efficiency (tokens per task vs. fleet average), tool usage patterns, and fleet-wide percentile rankings. This is the closest thing to an automated agent coaching system in any open-source tool.

---

## Framework adapters: six built-in, one interface

Mission Control ships six adapters that **normalize agent registration, heartbeats, and task reporting** to a common interface:

- **OpenClaw** — Deepest integration: WebSocket gateway, Ed25519 auth, bidirectional config sync, session controls (monitor/pause/terminate wired to gateway CLI), memory browser integration, SOUL personality sync
- **CrewAI** — Multi-agent crew framework adapter
- **LangGraph** — LangChain graph-based agent adapter
- **AutoGen** — Microsoft multi-agent framework adapter
- **Claude SDK** — Direct Anthropic SDK integration
- **Generic fallback** — Universal adapter for any agent that can make HTTP calls

Each adapter implements the same normalization contract: translate framework-specific registration payloads, heartbeat formats, and task status reports into Mission Control's internal schema. The data flow includes agent metadata, status updates, session data, token usage, task progress, and heartbeat signals.

The **multi-gateway** system lets you connect to multiple gateways simultaneously. Gateway discovery works at the OS level — scanning systemd services and Tailscale Serve endpoints. Each gateway connection gets its own health probe. The roadmap explicitly targets "agent-agnostic gateway support" for frameworks beyond OpenClaw (ZeroClaw, OpenFang, NeoBot, IronClaw, etc.).

---

## Security model: the most thorough in any open-source agent UI

Mission Control's security implementation is notably complete for an alpha project. The `src/proxy.ts` auth gate intercepts every request for CSRF origin validation, host allowlisting, and rate limiting before any API route handler executes.

**RBAC with three roles:**
- **Viewer**: Read-only access to all dashboards, task boards, logs, sessions, and monitoring
- **Operator**: Full read/write — create/modify tasks, manage agents, trigger scans, operate the Kanban board, run cron jobs
- **Admin**: Everything plus user management, credential changes, system settings, security audit, self-update, webhook config, gateway management, tenant management via `/api/super/*`, and destructive operations

**Password handling** uses Node.js native **scrypt** with a 12-character minimum (Zod-enforced). Sessions are cookie-based; API access uses bearer tokens. **Google OAuth** is also supported with an admin approval workflow.

**Rate limiting** is factory-based with four tiers: login (**5/min**), mutations (**60/min**), heavy operations like search and backup (**10/min**), and reads (**120/min**). Per-agent rate limiting uses `x-agent-name` identity. The `MC_TRUSTED_PROXIES` setting ensures correct IP extraction from `X-Forwarded-For` chains using the rightmost untrusted IP.

**Security headers** include CSP with per-request nonces (no unsafe-inline/unsafe-eval in current main), X-Content-Type-Options: nosniff, X-Frame-Options: DENY, Referrer-Policy: strict-origin-when-cross-origin, and optional HSTS via env var. Docker hardened mode adds read-only filesystem, capability dropping, and network isolation.

The **audit trail** logs every action with complete coverage and grouped filters. Auth failures, rate limit hits, and injection attempts are automatically logged as security events. The Security Audit panel computes a real-time **posture score (0–100)** incorporating secret detection, MCP tool call auditing, injection attempt tracking, and per-agent trust scores.

---

## Database schema: ~30 tables across 39 migrations

The SQLite database uses WAL mode with foreign keys enabled. While migration SQL isn't directly published, table structure can be reliably reconstructed from feature documentation, API endpoints, and helper function references. Key tables:

| Table | Purpose |
|-------|---------|
| `users` | Auth, roles (viewer/operator/admin), onboarding state |
| `sessions` (auth) | Session tokens with expiry |
| `agents` | Full agent registry with status, model, config, soul_md, working_memory, heartbeat_at |
| `tasks` | Kanban tasks with 6-status enum, priority, project_id, template flag, schedule_cron, parent_task_id |
| `task_comments` | Threaded comments with @-mention parsing |
| `projects` | Multi-project with slug, ticket_prefix, ticket_counter |
| `sessions` (agent) | Agent work sessions with token counts, model, cost, gateway_id |
| `token_usage` | Per-session/agent/model token tracking with cost |
| `logs` | Session and agent log entries |
| `audit_log` | Full audit trail with action type, actor, target, IP |
| `activity_log` | Activity feed data |
| `webhooks` / `webhook_deliveries` | Webhook configs and delivery tracking with retry state |
| `alert_rules` / `alerts` | Alert definitions and fired instances |
| `cron_jobs` | Background job definitions |
| `gateways` | Multi-gateway connections with health status |
| `skills` | Skill registry with SHA-256, security scan results |
| `comms` / `messages` | Inter-agent communication with type (a2a/coord/session) |
| `working_memory` | Per-agent memory in DB |
| `pipelines` / `workflows` | Pipeline orchestration |
| `security_events` | Security event tracking |
| `github_issues` | GitHub sync state with issue-to-task mapping |
| `tenants` / `provision_jobs` | Multi-tenant workspace management |
| `evals` / `golden_datasets` | Agent evaluation results and reference data |
| `claude_sessions` | Local Claude Code session scan data |
| `settings` | Key-value system settings |
| `api_keys` | API key management |

---

## What's missing, what breaks, and where it hits walls

**SQLite is the ceiling.** WAL mode enables concurrent reads, but the single-writer constraint means Mission Control cannot horizontally scale. A busy fleet generating high write throughput (many agents heartbeating, logging, and updating tasks simultaneously) will eventually bottleneck on SQLite's serialized writes. The docs explicitly warn: "Ensure only one instance is running against the same .data/ directory."

**Flight Deck (the desktop companion) is vaporware for now.** The Tauri v2 app with PTY terminal grid, native OS notifications, and system tray HUD is in private beta with no public code. This means Mission Control has no real terminal emulation — The Glass equivalent doesn't exist yet in the open-source release.

**Pipeline orchestration is thin.** The Pipelines panel exists, but detailed documentation on DAG structure, step execution models, dependency graphs, and conditional routing is absent. This appears to be a newer feature without the same maturity as the Kanban or agent management systems.

**The knowledge graph requires gateway mode.** The React Flow visualization only works when connected to an OpenClaw gateway — it renders memory relationships from gateway-managed agent workspaces. Without a gateway, you get the flat Memory Browser but no graph visualization.

**Known bugs and community friction:**
- Issue #91: SOUL content not syncing properly between UI and workspace files
- Issue #75: Request for workspace isolation in multi-team usage
- CSP inline styles were a persistent issue (now resolved in main with per-request nonces)
- The project is labeled "Alpha Software" — schemas and APIs explicitly may change

**What it can't do that matters for The Hive:**
- No true terminal multiplexing (no PTY support in the web UI)
- No DAG-based task graph visualization (Kanban only — linear columns, not graph topology)
- No plugin architecture for extending panels (panels are hard-coded React components)
- No distributed/multi-node deployment story
- No built-in LLM routing or model fallback logic (tracks what models were used, doesn't choose them)
- No native MCP server hosting (monitors MCP calls but doesn't serve as an MCP provider)

---

## Direct mapping to The Hive's component architecture

This is the strategic analysis. For each Hive component, here's what Mission Control offers, what it does better, and what it misses.

### The Yard (fleet overview) → Dashboard + Agent Management panels

Mission Control's Dashboard and Agent Management panels together cover fleet overview comprehensively. The agent detail modal with compact overview, inline model selector, and heartbeat visualization is well-designed. **What MC does better**: The agent lifecycle model (register → heartbeat → wake → retire) is clean and well-tested. Auto-discovery from `~/.agents/`, `~/.codex/agents/`, `~/.claude/agents/` is a pattern worth adopting. **What The Yard should add**: MC's fleet view is flat — no hierarchical agent topology. The Yard should visualize agent-to-agent relationships, delegation chains, and sub-agent trees as a graph, not a list.

### The Glass (multi-terminal observation) → Session Inspector + LiveFeed

MC's Session Inspector shows session metadata and has pause/terminate controls, but **it has no terminal emulation**. The LiveFeed is a real-time activity stream, not a terminal. The planned Flight Deck (Tauri v2, private beta) would add PTY terminal grids, but it's not available. **This is The Glass's biggest competitive advantage.** If The Hive ships real PTY multiplexing in a web UI (xterm.js or similar), it fills the most obvious gap in Mission Control. MC's approach of wiring session controls to gateway CLI is the right idea — The Glass should go further and show the actual terminal output.

### The Comb (task graph/memory) → Task Board (Kanban) + Memory Knowledge Graph

The Kanban board is MC's strongest panel — six columns, drag-drop, priorities, threaded comments, multi-project prefixes, inline sub-agent spawning, and Aegis quality gates. **The template-clone pattern for recurring tasks** (original becomes template, spawns dated children) is an elegant pattern worth stealing. The Memory Knowledge Graph uses React Flow but only works in gateway mode. **What The Comb should do differently**: MC's Kanban is linear columns; The Comb's "task graph" concept implies a DAG visualization showing task dependencies and execution flow. This is architecturally superior for complex multi-agent workflows. Adopt the Kanban for simple task management but layer a proper DAG view on top.

### The Waggle (skill registry) → Skills Hub

The Skills Hub is a near-perfect analog. Bidirectional SKILL.md sync with SHA-256 change detection, dual external registry support (ClawdHub, skills.sh), and a **built-in five-point security scanner** before installation. **Directly adopt this pattern.** The scanner checking for prompt injection, credential leaks, data exfiltration, obfuscated content, and dangerous shell commands is table-stakes functionality The Waggle needs. The 60-second sync cycle is a smart default.

### The Keeper (human-in-the-loop approvals) → Quality Gates (Aegis)

Aegis is sophisticated and The Keeper should study it closely. The integration of quality gates directly into the Kanban workflow (the Quality Review column) is cleaner than bolting approvals on as a separate system. **The four-layer eval stack** (output evals, trace evals, component evals, drift detection) goes beyond simple human approval. **What The Keeper should add beyond Aegis**: MC's quality gates are task-level only. The Keeper should support approval gates at the action level (before an agent executes a dangerous tool call), not just at task completion. This is the true human-in-the-loop pattern for safety-critical operations.

### The Smoker (CLI web bridge) → CLI Integration (Direct Connect)

MC's CLI integration — register connections, send heartbeats with inline token reporting, auto-register agents — is a lightweight but effective bridge. The Claude Code session scanner (extracting data from JSONL transcripts every 60 seconds) is a clever non-invasive approach. **For The Smoker**: MC's CLI integration is one-directional (CLI → MC data reporting). The Smoker should go further with bidirectional command dispatch — not just monitoring CLI tools but sending commands to them from the web UI and streaming output back.

### The Trail (trace/observability) → Audit Trail + Security Audit + Log Viewer

MC has three separate panels for this: Audit Trail (compliance/action logging), Security Audit (posture scoring, injection detection), and Log Viewer (session/agent logs). The **real-time posture scoring (0–100)** and **per-agent trust scores** in the Security Audit panel are novel. **What The Trail should unify**: MC fragments observability across three panels. The Trail should provide a unified trace view that correlates an agent's execution steps, tool calls, memory accesses, and security events in a single timeline — closer to OpenTelemetry trace visualization than MC's separate log/audit/security panels.

### The Yield (metrics dashboard) → Token Usage + Cost Tracking + Agent Evals

MC's token dashboard with Recharts, per-model breakdowns, and trend charts is solid but not exceptional. The Agent Optimization endpoint (tokens/task vs fleet average, tool usage patterns, percentile rankings) is the standout feature. **Worth stealing**: The fleet-wide percentile benchmarking concept. An agent being told "you're in the 72nd percentile for token efficiency" is actionable. The Yield should compute similar fleet-relative metrics.

### The Queen (orchestrator control plane) → Gateway Management + Pipelines + Cron + Workspaces

MC's Gateway Management with OS-level discovery (systemd, Tailscale), multi-gateway connections, and health probes maps to The Queen's orchestrator role. The workspace/tenant system via `/api/super/*` provides multi-tenant isolation. **What MC lacks that The Queen needs**: MC is primarily a monitoring/management layer, not a true orchestrator. It doesn't make scheduling decisions about which agent handles which task (that's the human's job on the Kanban board). The Queen should implement actual orchestration logic — automated task routing, load balancing across agents, and intelligent work distribution.

---

## Code patterns worth adopting directly

**The schedule parser** (`src/lib/schedule-parser.ts`) is a zero-dependency natural language to cron converter. This is a clean utility that The Hive could use directly.

**The requireRole() pattern** in API routes is elegant — a single guard function enforcing RBAC on every endpoint. Combined with Zod validation via `validateBody()`, it creates a consistent API route template: validate auth → validate input → execute logic → return JSON.

**The bidirectional file sync pattern** (used for both SKILL.md and soul.md) with SHA-256 change detection on 60-second scheduler cycles is a robust approach to keeping filesystem state and database state in sync without file watchers.

**The webhook retry system** with exponential backoff and circuit breaker is production-grade. Rather than building this, use MC's pattern.

**The factory-based rate limiter** with four tiers (login/mutations/heavy/reads) and per-identity quotas via `x-agent-name` headers is a pattern worth replicating.

**The agent lifecycle state machine** (register → heartbeat → wake → retire) with stale record cleanup via the background scheduler is clean and covers the full agent lifecycle.

---

## Should The Hive fork, adapt, or build fresh?

**Build fresh, with heavy inspiration.** Here's why:

Mission Control is a **monolithic SPA** — 32 panels in a single Next.js app with a single SQLite database. The Hive's architecture is fundamentally different: nine named components (Yard, Glass, Comb, Waggle, Keeper, Smoker, Trail, Yield, Queen) suggest a **composable, modular system** where components can be deployed and scaled independently. Forking MC would mean inheriting its single-process, single-database architecture and then fighting to break it apart.

However, several MC patterns should be directly adopted:

- **The Kanban task state machine** (six columns + Aegis quality gate) for The Comb
- **The RBAC model** (viewer/operator/admin with requireRole()) for auth
- **The bidirectional file sync pattern** (SHA-256 + 60s scheduler) for The Waggle
- **The security scanner's five-point checklist** for skill/tool installation
- **The four-layer eval stack concept** (output, trace, component, drift) for The Keeper
- **The fleet-relative benchmarking** for The Yield
- **React Flow** for any graph visualization needs

**What The Hive does that MC doesn't even attempt**: real terminal multiplexing (Glass), DAG-based task graphs (Comb), action-level approval gates (Keeper), bidirectional CLI command dispatch (Smoker), unified trace correlation (Trail), automated agent routing (Queen), and modular component architecture. These are The Hive's architectural advantages. MC's value is proving that a comprehensive agent dashboard is viable, popular, and needed — and showing exactly which panels and patterns users actually want. Build The Hive's own foundation, but study every one of MC's 32 panels as validated feature requirements.