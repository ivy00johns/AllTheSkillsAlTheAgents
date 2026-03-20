# 01 — Project Overview

## What Mission Control Is

Mission Control is an open-source agent orchestration dashboard built by **Builderz Labs** — a distributed team spanning Dubai, Vietnam, Germany, and Pakistan, led by Nyk (GitHub: @nyk) and Kulture. It provides a single-pane-of-glass for managing AI agent fleets: spawning sessions, tracking tasks on a Kanban board, monitoring token costs, orchestrating pipelines, and connecting to agent gateways (primarily OpenClaw) over WebSocket.

The pitch is simple: one `pnpm start`, one SQLite file, zero external dependencies. No Redis. No Postgres. No Docker requirement. No message queue. It runs as a standalone Next.js binary and stores everything in `.data/mission-control.db`.

```
┌──────────────────────────────────────────────────────────────────┐
│                      Mission Control                             │
│                                                                  │
│   Browser SPA  ──WebSocket──►  OpenClaw Gateway  ──►  Agents     │
│       │                                                          │
│       │ SSE + REST                                               │
│       ▼                                                          │
│   Next.js Server (standalone binary)                             │
│       │                                                          │
│       ▼                                                          │
│   SQLite (WAL mode, better-sqlite3)                              │
│   .data/mission-control.db                                       │
└──────────────────────────────────────────────────────────────────┘
```

MIT licensed. Self-hosted first. No telemetry. A planned Pro tier at $29/month is referenced in the promo banner (`src/components/layout/promo-banner.tsx`) but not yet shipping.

## By the Numbers

| Metric | Value |
|--------|-------|
| GitHub stars | ~2,700 |
| Forks | ~471 |
| Current version | 1.3.0 |
| License | MIT |
| Feature panels | 28 (README count) / 26 unique switch cases (ContentRouter) |
| API route files | 83 |
| Schema migrations | 27 (001_init through 027_agent_api_keys) |
| Unit test files | 12 |
| E2E test files | 35 |
| Test count (CHANGELOG) | 69 unit + 165 E2E = 234 total (as of v1.3.0) |
| Production dependencies | 20 |
| Dev dependencies | 11 |
| Total dependencies | 31 |
| Node.js minimum | >=20 |
| Package manager | pnpm |

## Release History

All four releases shipped within a 15-day window — an extraordinary pace that suggests either a pre-built codebase open-sourced in stages or an AI-assisted sprint:

| Version | Date | Key Additions |
|---------|------|---------------|
| **1.0.0** | 2026-02-15 | Agent dashboard, Kanban board, SSE activity stream, spawn management, webhooks with HMAC, alert rules, token tracking, dark/light theme, Docker support |
| **1.1.0** | 2026-02-27 | Multi-user auth (sessions + Google SSO), RBAC (admin/operator/viewer), audit log, 1Password integration, workflow templates, pipeline orchestration, quality review gates, data export, global search, settings UI, notifications, agent comms, standup reports, CSRF validation, network access control |
| **1.2.0** | 2026-03-01 | Zod validation on all mutations, security headers (X-Content-Type, X-Frame-Options, Referrer-Policy), rate limiting on expensive endpoints, unit tests for auth/validation/rate-limit/db-helpers |
| **1.3.0** | 2026-03-02 | Claude Code session tracking (auto-discover from `~/.claude/projects/`), webhook retry with exponential backoff + circuit breaker, webhook signature verification, Docker HEALTHCHECK, Vitest coverage config (60% threshold), cron deduplication, timing-safe comparison bug fixes, structured pino logging across all 31 API routes, 69 unit + 165 E2E tests |

The jump from v1.0.0 to v1.1.0 (12 days) delivered more features than most projects ship in a quarter: auth, RBAC, pipelines, quality gates, search, export, standup reports, and network hardening. v1.2.0 and v1.3.0 followed the next day and the day after that — a security-and-polish double-tap.

## Tech Stack

| Layer | Technology | Version | Notes |
|-------|-----------|---------|-------|
| Framework | Next.js | 16 | App Router, Turbopack, standalone output |
| UI Library | React | 19 | Server components by default, `'use client'` only when needed |
| Language | TypeScript | 5.7 | Strict mode, ES2017 target, `@/*` path alias |
| Database | SQLite via better-sqlite3 | 12.6 | WAL mode, `synchronous=NORMAL`, `foreign_keys=ON` |
| State | Zustand | 5 | `subscribeWithSelector` middleware |
| Styling | Tailwind CSS | 3.4 | Semantic HSL design tokens, class-based dark mode |
| Charts | Recharts | 3 | Token usage dashboards, trend charts |
| Real-time | WebSocket (ws 8.19) + SSE | — | Dual-channel: WS for gateway, SSE for local DB mutations |
| Validation | Zod | 4.3 | All mutation API routes |
| Auth | scrypt + session cookies | — | Session tokens, API keys, Google OAuth |
| Logging | Pino | 10.3 | Structured JSON logging across all routes |
| Testing (unit) | Vitest | 2.1 | v8 coverage provider, 60% threshold |
| Testing (E2E) | Playwright | 1.51 | Sequential, 1 worker, standalone build on port 3005 |
| Markdown | react-markdown + remark-gfm | — | Agent SOUL rendering, docs panel |
| Flow diagrams | @xyflow/react | 12.10 | Pipeline visualization |
| Theming | next-themes | 0.4 | Class-based dark mode, default dark |

## The Zero-External-Dependency Philosophy

Mission Control makes a deliberate architectural bet: everything in one process, one database file.

**What it does NOT require:**
- Redis (no caching layer, no pub/sub bus)
- PostgreSQL or MySQL (SQLite only)
- Docker (optional, not required)
- Message queue (no RabbitMQ, no NATS)
- External session store
- CDN or object storage

**What this enables:**
- `git clone && pnpm install && pnpm start` — running in under a minute
- Single `.data/` directory to back up (SQLite DB, token logs, backups)
- No infrastructure provisioning, no connection strings, no service discovery
- Portable across any machine with Node.js >= 20

**What this constrains:**
- Single-writer SQLite — one process, one machine
- No horizontal scaling without architectural changes
- WAL mode enables concurrent reads but writes are serialized
- Background scheduler runs in-process (not a separate worker)

## Self-Hosted First

The project is explicitly designed for self-hosting behind a reverse proxy:

- **Network access control**: `MC_ALLOWED_HOSTS` whitelist, `MC_ALLOW_ANY_HOST=1` override
- **TLS delegation**: HSTS header available via `MC_ENABLE_HSTS=1`, but TLS termination is expected at the reverse proxy (Caddy, nginx)
- **No telemetry**: zero phone-home behavior
- **Seed credentials**: `AUTH_USER` / `AUTH_PASS` set on first run, no cloud account required
- **Trusted proxies**: `MC_TRUSTED_PROXIES` for correct IP extraction behind load balancers

## Where It Sits in the Landscape

Mission Control is the most feature-dense open-source agent orchestration dashboard available as of early 2026. Its closest comparisons:

| Dimension | Mission Control | Typical Alternatives |
|-----------|----------------|---------------------|
| Architecture | Monolithic SPA | Microservices, separate API + frontend |
| Database | SQLite (single file) | PostgreSQL, MongoDB |
| Deployment | `pnpm start` | Docker Compose, Kubernetes |
| Real-time | WebSocket + SSE dual-channel | WebSocket only, or polling |
| Auth | Built-in RBAC + Google SSO | External auth provider (Auth0, Clerk) |
| Agent protocol | OpenClaw gateway (WebSocket) | Custom, varies |
| Task management | Built-in Kanban | External (Jira, Linear) |
| Cost tracking | Built-in per-model | External (LangSmith, Helicone) |

**Strengths for The Hive to study:**
- The SPA-shell-with-Zustand pattern gives persistent connections and zero-remount panel switches
- 83 API routes with consistent auth/validation middleware is a mature API surface
- The dual-channel real-time system (SSE for local mutations, WebSocket for gateway events) is well-designed
- Background scheduler with database-backed settings is production-ready
- 27 migrations demonstrate a rapidly evolving but managed schema

**Constraints The Hive should solve differently:**
- Single-writer SQLite caps at one machine
- No multi-tenant isolation (workspace isolation is in-progress, migrations 021-023)
- Tight coupling to OpenClaw gateway protocol
- No offline/sync story for distributed teams
- No plugin or extension architecture

## Scripts Available

From `package.json`:

```json
{
  "dev":          "next dev --hostname 127.0.0.1 --port ${PORT:-3000}",
  "build":        "next build",
  "start":        "next start --hostname 0.0.0.0 --port ${PORT:-3000}",
  "lint":         "eslint .",
  "typecheck":    "tsc --noEmit",
  "test":         "vitest run",
  "test:watch":   "vitest",
  "test:ui":      "vitest --ui",
  "test:e2e":     "playwright test",
  "test:all":     "pnpm lint && pnpm typecheck && pnpm test && pnpm build && pnpm test:e2e",
  "quality:gate": "pnpm test:all"
}
```

The `quality:gate` script runs the full CI pipeline: lint, typecheck, unit tests, production build, then E2E tests. Both `dev` and `start` source `.env` inline. Dev binds to `127.0.0.1` (local only); production binds to `0.0.0.0` (all interfaces).

## Dependency Inventory

### Production (20 packages)

| Package | Purpose |
|---------|---------|
| `next` ^16.1.6 | Framework |
| `react` ^19.0.1 | UI library |
| `react-dom` ^19.0.1 | DOM renderer |
| `typescript` ^5.7.2 | Language |
| `zustand` ^5.0.11 | Client state |
| `better-sqlite3` ^12.6.2 | Database driver |
| `zod` ^4.3.6 | Schema validation |
| `ws` ^8.19.0 | WebSocket client |
| `pino` ^10.3.1 | Structured logging |
| `tailwindcss` ^3.4.17 | CSS framework |
| `postcss` ^8.5.2 | CSS processing |
| `autoprefixer` ^10.4.20 | CSS vendor prefixes |
| `recharts` ^3.7.0 | Charts |
| `react-markdown` ^10.1.0 | Markdown rendering |
| `remark-gfm` ^4.0.1 | GitHub-flavored markdown |
| `@xyflow/react` ^12.10.0 | Flow diagrams (pipelines) |
| `reactflow` ^11.11.4 | Legacy flow diagrams |
| `@scalar/api-reference-react` ^0.8.66 | OpenAPI docs UI |
| `next-themes` ^0.4.6 | Theme switching |
| `clsx` ^2.1.1 | Class name utility |
| `tailwind-merge` ^3.4.0 | Tailwind class merging |
| `eslint` ^9.18.0 | Linting |
| `eslint-config-next` ^16.1.6 | Next.js lint rules |

### Dev (11 packages)

| Package | Purpose |
|---------|---------|
| `@playwright/test` ^1.51.0 | E2E testing |
| `vitest` ^2.1.5 | Unit testing |
| `@vitejs/plugin-react` ^4.3.4 | React support for Vitest |
| `@testing-library/react` ^16.1.0 | React test utilities |
| `@testing-library/dom` ^10.4.0 | DOM test utilities |
| `@testing-library/jest-dom` ^6.6.3 | DOM matchers |
| `jsdom` ^26.0.0 | DOM environment for tests |
| `vite-tsconfig-paths` ^5.1.4 | Path alias resolution |
| `pino-pretty` ^13.1.3 | Pretty-print logs in dev |
| `@types/better-sqlite3` ^7.6.13 | Type definitions |
| `@types/node` ^22.10.6 | Node.js types |
| `@types/react` ^19.0.8 | React types |
| `@types/react-dom` ^19.0.3 | React DOM types |
| `@types/ws` ^8.18.1 | WebSocket types |

Total: 31 direct dependencies (20 production + 11 dev). Notably lean for a dashboard of this scope.
