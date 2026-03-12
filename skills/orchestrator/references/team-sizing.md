# Team Sizing Guide

## The Coordination Cost Rule

Each agent pair creates an integration surface. Coordination cost grows quadratically with agent count while throughput grows linearly.

| Agents | Integration Pairs | Best For |
|--------|-------------------|----------|
| 2 | 1 | Most projects. Clear frontend/backend split. Backend owns data layer — rarely justifies a separate agent. |
| 3 | 3 | Full-stack apps with a genuinely separate service (auth, background worker, search, ML pipeline) that has its own runtime and API surface. NOT for splitting backend from database. |
| 4 | 6 | Complex systems with 2+ truly independent services. Rare. |
| 5+ | 10+ | Large systems with many isolated modules. Very rare. Coordination overhead usually exceeds gains. |

**Default to 2 agents. Only scale up when additional agents do meaningful parallel work without sharing files or data models.**

## Hard Constraints

### Shared Data Model Rule

If more than 2 agents need to read/write the same data model, reduce agent count. Give one agent broader scope instead of splitting and fighting over schemas.

### Dependency Chain Rule

If Agent C can't start until Agent B finishes, and Agent B can't start until Agent A finishes, that's 1 sequential pipeline — not 3 parallel agents. Only count agents that do meaningful *simultaneous* work.

### Review Capacity Rule

You can only review as fast as you can validate. Scaling beyond your review capacity produces five half-reviewed implementations instead of two solid ones.

## Agent Definition Template

For each agent, define:

1. **Name**: Short and descriptive (`frontend`, `backend`, `api`, `data-layer`)
2. **Ownership**: Exact files and directories they own exclusively
3. **Off-limits**: Files they must NOT touch
4. **Responsibilities**: What they build, in concrete terms
5. **Validation checklist**: Specific commands they must pass before reporting done

## Shared Infrastructure File Assignment

Every file in the repo has exactly one owner. No exceptions.

| File | Usually Owned By | Rationale |
|------|-----------------|-----------|
| Root `package.json` | Frontend (if JS monorepo root) or Backend | Whoever runs `npm install` more often |
| `.env` / `.env.example` | Backend | Backend defines ports, DB URLs, API keys |
| `docker-compose.yml` | Backend or Infrastructure | Defines service topology |
| `tsconfig.json` (root) | Frontend | Frontend build tooling more sensitive to TS config |
| `.gitignore` | Lead (pre-created) | Rarely changes |
| `README.md` | Docs-agent (post-build) | Orchestrator provides full-system context; docs-agent writes it |

## Built-In Specialist Agents

The ecosystem includes 5 specialist role skills. These are not "extra agents" — they're first-class members of the toolkit. Spawn them based on project needs:

| Specialist | When to Include | When to Skip |
|-----------|-----------------|--------------|
| security-agent | Any project with user auth, external APIs, or sensitive data | Internal tools, prototypes |
| docs-agent | Any project shipping to users or teams | Personal projects, throwaway proofs of concept |
| observability-agent | Production services needing monitoring | Prototypes, single-use scripts |
| db-migration-agent | Projects with existing databases or evolving schemas | Greenfield with simple schema, SQLite prototypes |
| performance-agent | APIs with latency SLAs or high traffic expectations | Internal tools, low-traffic services |

These specialists add coordination cost (more integration pairs), so include them judiciously. A 2-agent core (backend + frontend) with 1 specialist is common; 4+ specialists simultaneously is rare.

## When to Add Custom Specialist Agents

Add a custom specialist agent only when the service:

- Has its **own runtime** (separate process)
- Has its **own data store** or external dependencies
- Has its **own API surface**
- Can do **meaningful parallel work** during the build

If the answer to any of these is "no," it should be a module within an existing agent's scope, not a separate agent.

### Common Specialist Roles

| Role | Justification | Integration Pattern |
|------|---------------|-------------------|
| Auth service | Separate token management, rate limiting | HTTP API |
| Background worker | Job queue with different runtime needs | Message queue |
| Search service | Separate index, query engine | HTTP API |
| ML/AI pipeline | Model loading, inference, different runtime | HTTP API or queue |
| Notification service | WebSocket connections, push notifications | HTTP API + WebSocket |
