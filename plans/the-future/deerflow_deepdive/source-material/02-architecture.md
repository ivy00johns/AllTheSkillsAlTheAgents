# 02 — DeerFlow: Architecture

## High-Level Architecture

```
                              Port 2026
                         ┌──────────────────┐
                         │      Nginx       │
                         │  Reverse Proxy   │
                         └────────┬─────────┘
                    ┌─────────────┼──────────────┐
                    │             │               │
              /api/langgraph/*   /api/*           /*
                    │             │               │
           ┌───────▼──────┐ ┌───▼──────┐  ┌─────▼──────┐
           │  LangGraph   │ │ FastAPI  │  │  Next.js   │
           │   Server     │ │ Gateway  │  │  Frontend  │
           │  Port 2024   │ │ Port 8001│  │  Port 3000 │
           └───────┬──────┘ └───┬──────┘  └────────────┘
                   │            │
           ┌───────▼──────┐    │
           │  Lead Agent  │    │
           │  (LangGraph  │    │
           │   Workflow)  │    │
           └───────┬──────┘    │
                   │           │
    ┌──────────────┼───────────┼──────────────┐
    │              │           │              │
┌───▼───┐  ┌──────▼──────┐ ┌──▼──────┐ ┌────▼──────┐
│Sandbox│  │  Sub-agents │ │Channels │ │  Memory   │
│Docker/│  │  (Thread    │ │Feishu/  │ │  Store    │
│  K8s  │  │   Pools)    │ │Slack/   │ │ (.json)   │
└───────┘  └─────────────┘ │Telegram │ └───────────┘
                           └─────────┘

           ┌─────────────────────────┐
           │   K8s Provisioner       │
           │   Port 8002 (optional)  │
           └─────────────────────────┘
```

## Directory Layout

```
deer-flow/
├── backend/
│   ├── app/                          # Deployment-specific code (app layer)
│   │   ├── channels/                 # IM channel integrations
│   │   │   ├── base.py              #   Abstract Channel class
│   │   │   ├── feishu.py            #   Feishu (WebSocket)
│   │   │   ├── slack.py             #   Slack (Socket Mode)
│   │   │   ├── telegram.py          #   Telegram (polling)
│   │   │   ├── manager.py           #   ChannelManager — agent dispatcher
│   │   │   ├── message_bus.py       #   Async message routing
│   │   │   ├── store.py             #   Thread mapping persistence
│   │   │   └── service.py           #   Channel registry + lifecycle
│   │   └── gateway/                  # FastAPI API Gateway
│   │       ├── app.py               #   Application factory + lifespan
│   │       ├── routers/             #   9 route modules
│   │       ├── config.py            #   Gateway-specific config
│   │       └── path_utils.py        #   Virtual ↔ actual path mapping
│   ├── packages/
│   │   └── harness/
│   │       └── deerflow/            # Publishable harness (deerflow.* packages)
│   │           ├── agents/
│   │           │   ├── lead_agent/  #   make_lead_agent() + prompt template
│   │           │   ├── middlewares/ #   13 middleware implementations
│   │           │   ├── memory/      #   Long-term memory system
│   │           │   ├── checkpointer/#   State persistence (Postgres/SQLite/memory)
│   │           │   └── thread_state.py
│   │           ├── config/          #   12 config modules (YAML → Pydantic)
│   │           ├── tools/           #   Tool assembly + built-in tools
│   │           ├── subagents/       #   SubagentExecutor + registry
│   │           ├── models/          #   Model factory + provider patches
│   │           ├── mcp/             #   MCP client, tools, cache, OAuth
│   │           ├── sandbox/         #   Sandbox providers (local, Docker, K8s)
│   │           ├── skills/          #   Skill loader, parser, validation
│   │           ├── reflection/      #   Runtime class/variable resolution
│   │           ├── community/       #   Community integrations (Tavily, Jina, etc.)
│   │           └── client.py        #   DeerFlowClient (embedded Python client)
│   ├── tests/                       # Backend test suite
│   ├── langgraph.json               # LangGraph server configuration
│   ├── pyproject.toml               # Python project + dependencies
│   └── Dockerfile
├── frontend/
│   ├── src/
│   │   ├── app/                     # Next.js App Router pages
│   │   │   ├── workspace/           #   Chat + agent pages
│   │   │   └── page.tsx             #   Landing page
│   │   ├── components/
│   │   │   ├── ai-elements/         #   Reusable AI interaction components
│   │   │   ├── workspace/           #   Workspace-specific components
│   │   │   ├── landing/             #   Landing page sections
│   │   │   └── ui/                  #   Radix-based component library
│   │   ├── core/                    #   State, API, hooks, utilities
│   │   │   ├── api/                 #   LangGraph SDK client wrapper
│   │   │   ├── threads/             #   Thread streaming hooks
│   │   │   ├── artifacts/           #   Artifact loading + display
│   │   │   ├── i18n/                #   Internationalization (en-US, zh-CN)
│   │   │   ├── mcp/                 #   MCP server configuration
│   │   │   ├── memory/              #   Memory read-only display
│   │   │   ├── skills/              #   Skill enable/disable
│   │   │   ├── settings/            #   Local settings (localStorage)
│   │   │   └── tasks/               #   Subtask context for streaming
│   │   └── server/                  #   Server-side auth (better-auth)
│   └── package.json
├── docker/
│   ├── nginx/nginx.conf             # Reverse proxy configuration
│   └── provisioner/app.py           # K8s sandbox pod provisioner
├── scripts/                         # serve.sh, config generation, etc.
├── skills/                          # Markdown skill definitions
├── config.example.yaml              # Full configuration reference
├── Makefile                         # Dev/build/deploy commands
└── README.md
```

## Key Design Decisions

**1. Supervisor Pattern Over Explicit Graph**

v1 used a 9-node explicit StateGraph (Coordinator → Planner → Research Team → Reporter). v2 replaces this with a single supervisor agent (`make_lead_agent()`) that delegates via the `task` tool. The supervisor pattern is more flexible — it handles arbitrary workflows without predefined node topology — but less predictable than v1's explicit pipeline. The tradeoff is intentional: v2 optimizes for generality over research-specific structure.

**2. Harness/App Layer Separation**

The backend is being refactored into two layers: a publishable **harness** (`deerflow.*` packages containing core agent infrastructure) and an **app** layer (`app.*` containing deployment-specific code). The harness never imports from app — enforced by automated tests. This enables eventual publication as a standalone `deerflow-harness` pip package. Channels, the gateway, and deployment config live in app; the agent runtime, middleware, tools, and memory live in the harness.

**3. Ordered Middleware Pipeline**

The heart of v2 is a 13-stage ordered middleware pipeline with typed hooks (`before_agent`, `before_model`, `after_model`, `wrap_model_call`, `wrap_tool_call`). Order matters: ThreadDataMiddleware must run first (creates directories), ClarificationMiddleware must run last (intercepts after all processing). This is an interceptor pattern borrowed from web frameworks, applied to agent execution — each middleware can observe or modify the agent's behavior without coupling to other middleware.

**4. Reflection-Based Configuration**

Models and tools are configured as string class paths in YAML (e.g., `"langchain_openai:ChatOpenAI"`) and resolved at runtime via `resolve_class()` / `resolve_variable()`. This enables dynamic pluggability — any LangChain-compatible model or tool can be used without code changes, just config edits. The tradeoff is that configuration errors surface at runtime rather than import time.

**5. Thread Pool Sub-Agent Execution**

Sub-agents run in dedicated thread pools (3 scheduler workers + 3 execution workers). Each sub-agent spawns its own asyncio event loop via `asyncio.run()` in a thread, enabling async MCP tools in an otherwise synchronous polling context. The lead agent polls sub-agent results every 5 seconds with a 15-minute default timeout. This is simpler than a message-passing architecture but limits concurrency to 3 simultaneous sub-agents (clamped to [2, 4]).

**6. Nginx as Unified Entry Point**

A single Nginx instance on port 2026 routes all traffic: `/api/langgraph/*` to the LangGraph server, `/api/*` to the FastAPI gateway, `/*` to the Next.js frontend. SSE streaming is handled with `proxy_buffering off` and 600-second timeouts. CORS is centralized in Nginx rather than in application code. This simplifies deployment (one port) but adds an infrastructure dependency.

**7. Channel-Agnostic Message Bus**

IM channels (Feishu, Slack, Telegram) communicate through an async `MessageBus` with `InboundMessage`/`OutboundMessage` types. The `ChannelManager` consumes inbound messages, creates/reuses LangGraph threads, and publishes responses back. This decouples channels from agent logic — adding a new channel requires only implementing the `Channel` abstract class, not modifying the agent runtime.

**8. React Context Over State Libraries**

The Deep Research document claims "Zustand state management" but the actual codebase uses React Context API + hooks exclusively. There is no Zustand, Redux, or other state management library. All state lives in React hooks (`useState`, `useReducer`) and context providers (`SubtasksProvider`, `ArtifactsProvider`, `PromptInputProvider`). Server state is managed via React Query (`@tanstack/react-query`). Settings persist to `localStorage`.

**9. Progressive Skill Loading**

Skills are Markdown files with YAML frontmatter. Only frontmatter (~100 tokens) is loaded by default; the full skill body is loaded on trigger. This keeps the system prompt lean while enabling rich skill definitions. Skills can be enabled/disabled via the frontend settings UI.

**10. Virtual Path Mapping for Sandboxes**

The agent sees virtual paths (`/mnt/user-data/workspace/`, `/mnt/user-data/uploads/`, `/mnt/user-data/outputs/`) that map to different actual filesystem paths depending on sandbox mode (local, Docker, K8s). The gateway's `path_utils.py` handles bidirectional mapping. This abstraction lets the same agent code work across all sandbox modes without path awareness.

## Execution Model

### Startup Sequence

```
make dev (or make start)
  └─ scripts/serve.sh
       ├─ 1. LangGraph Server (port 2024, 60s timeout)
       │    └─ uv run langgraph dev --no-browser --allow-blocking
       ├─ 2. FastAPI Gateway (port 8001, 30s timeout)
       │    └─ uv run uvicorn app.gateway.app:app --port 8001
       ├─ 3. Next.js Frontend (port 3000, 120s timeout)
       │    └─ pnpm run dev
       └─ 4. Nginx (port 2026, 10s timeout)
            └─ nginx -g 'daemon off;' -c nginx.local.conf
```

### Request Flow (Web UI)

```
1. User types message in InputBox
2. Files uploaded via POST /api/threads/{id}/uploads → Gateway
3. Frontend calls thread.submit() → LangGraph SDK
4. Request: POST /api/langgraph/threads/{id}/runs/stream
5. Nginx rewrites → LangGraph Server (port 2024)
6. LangGraph invokes make_lead_agent()
7. Middleware pipeline executes (13 stages)
8. Lead agent processes, optionally spawns sub-agents via task tool
9. SSE events stream back through Nginx to frontend
10. Frontend renders messages, artifacts, subtask cards in real-time
```

### Request Flow (IM Channel)

```
1. Message arrives via platform (WebSocket/polling)
2. Channel creates InboundMessage → MessageBus.publish_inbound()
3. ChannelManager.get_inbound() consumes from queue
4. Looks up/creates thread on LangGraph Server via SDK
5. Streaming channels: client.runs.stream() with 0.35s publish interval
6. Non-streaming channels: client.runs.wait() (blocks until completion)
7. ChannelManager creates OutboundMessage with artifacts
8. MessageBus.publish_outbound() → channel callbacks
9. Channel sends reply to platform (with file uploads if needed)
```

### Shutdown

All services are managed as background processes by `serve.sh`. `make stop` sends SIGTERM to the process group. Nginx and LangGraph handle graceful shutdown; the gateway's lifespan handler stops channels on exit.
