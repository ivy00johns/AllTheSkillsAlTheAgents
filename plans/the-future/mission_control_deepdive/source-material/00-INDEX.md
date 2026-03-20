# Mission Control Deep Dive — Index

A comprehensive technical breakdown of the Mission Control project (builderz-labs),
its architecture and implementation patterns, and the strategic mapping to The Hive's
component architecture.

## Documents

| # | File | Topic |
|---|------|-------|
| 01 | [project-overview.md](01-project-overview.md) | What Mission Control is, by the numbers, and where it sits in the landscape |
| 02 | [architecture.md](02-architecture.md) | Next.js 16 SPA shell, Zustand state, directory layout, standalone deployment |
| 03 | [database-schema.md](03-database-schema.md) | SQLite WAL, 27 migrations, all tables, relationships, seed logic, helpers |
| 04 | [api-surface.md](04-api-surface.md) | All 83+ REST endpoints — signatures, auth, validation, rate limiting |
| 05 | [authentication-security.md](05-authentication-security.md) | Auth flow, RBAC, rate limiting, CSRF, security headers, audit trail |
| 06 | [frontend-panels.md](06-frontend-panels.md) | All 28+ panels, component architecture, Zustand store, hooks, styling |
| 07 | [realtime-systems.md](07-realtime-systems.md) | WebSocket, SSE, event bus, smart polling, Ed25519 device identity |
| 08 | [agent-lifecycle.md](08-agent-lifecycle.md) | Registration, heartbeat, sync, SOUL, working memory, optimization, comms |
| 09 | [task-orchestration.md](09-task-orchestration.md) | Kanban, Aegis quality gates, recurring tasks, pipelines, dispatch, workload signals |
| 10 | [integrations-ecosystem.md](10-integrations-ecosystem.md) | Webhooks, gateways, GitHub sync, Claude Code sessions, skills hub, multi-tenant |
| 11 | [testing-infrastructure.md](11-testing-infrastructure.md) | Vitest unit tests, Playwright E2E, CI pipeline, coverage gaps |
| 12 | [patterns-to-steal.md](12-patterns-to-steal.md) | 12 code patterns directly adoptable for The Hive build |
| 13 | [hive-component-mapping.md](13-hive-component-mapping.md) | MC panels → Hive components — what to adopt, what to surpass |

## Generated

2026-03-20 — from codebase analysis of mission-control (v1.3.0, Next.js 16,
83+ API routes, 27 migrations, 28+ panels, 460+ tests, MIT license)
and strategic mapping to The Hive's 11-component architecture.
