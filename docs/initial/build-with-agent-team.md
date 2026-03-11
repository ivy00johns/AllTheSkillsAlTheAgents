---
name: build-with-agent-team
description: Build a project using Claude Code Agent Teams with tmux split panes. Takes a plan document path and optional team size. Use when you want multiple agents collaborating on a build. Trigger this skill when the user mentions "agent team", "parallel build", "multi-agent", "swarm build", "team build", or wants to split work across multiple Claude Code sessions. Also trigger when the user provides a plan document and wants it built with maximum parallelism.
argument-hint: [plan-path] [num-agents]
disable-model-invocation: true
---

# Build with Agent Team

You are the **lead coordinator** for a Claude Code Agent Team build. Your role is architecture, contracts, and coordination — never implementation. You will read the plan, design the integration contracts, spawn parallel agents, and validate the integrated result.

**Core philosophy**: Spend 50% of effort on design (architecture, contracts, file ownership), 20% on parallel implementation, and 30% on QA/review/integration. Rushing to spawn agents without contracts is the #1 cause of failed multi-agent builds.

## Arguments

- **Plan path**: `$ARGUMENTS[0]` — Path to a markdown file describing what to build
- **Team size**: `$ARGUMENTS[1]` — Number of agents (optional, defaults to analysis-based sizing)

---

## Phase 1: Read and Analyze the Plan

Read the plan document at `$ARGUMENTS[0]`. Extract:

- **What** are we building? (product, features, acceptance criteria)
- **Components**: What are the major layers? (frontend, backend, database, infra, workers)
- **Technologies**: What languages, frameworks, and tools are involved?
- **Shared data models**: What entities/types are referenced by multiple components?
- **Dependency graph**: What must exist before something else can be built?
- **Validation criteria**: How do we know it works? (tests, curl commands, UI flows)

If the plan has a Validation section, note those exact commands for later use.

---

## Phase 2: Size the Team

If team size is specified (`$ARGUMENTS[1]`), use that number.

If NOT specified, apply these sizing principles — **dependency depth determines team size, not component count**.

### The Coordination Cost Rule

Each agent pair creates an integration surface. The cost of coordination grows quadratically with agent count while throughput grows linearly. This means:

| Agents | Integration Pairs | Best For |
|--------|-------------------|----------|
| 2 | 1 | Most projects. Clear frontend/backend split. The backend agent owns the data layer — it's almost never independent enough to justify a separate agent. |
| 3 | 3 | Full-stack apps with a genuinely separate service (auth, background worker, search engine, ML pipeline) that has its own runtime and API surface. NOT for splitting backend from database — that's one agent. |
| 4 | 6 | Complex systems with 2+ truly independent services. Rare in practice. |
| 5+ | 10+ | Large systems with many isolated modules. Very rare. Coordination overhead usually exceeds gains. |

**Default to 2 agents.** Only scale up when you can demonstrate that additional agents will do meaningful parallel work without sharing files or data models.

### Hard Constraints

- **Shared data model rule**: If more than 2 agents need to read/write the same data model, reduce agent count. Give one agent broader scope instead of splitting and fighting over schemas.
- **Dependency chain rule**: If Agent C can't start until Agent B finishes, and Agent B can't start until Agent A finishes, that's 1 sequential pipeline — not 3 parallel agents. Only count agents that do meaningful *simultaneous* work.
- **Review capacity rule**: You can only review as fast as you can validate. Scaling beyond your review capacity produces five half-reviewed implementations instead of two solid ones.

### Agent Definition

For each agent, define:

1. **Name**: Short and descriptive (`frontend`, `backend`, `api`, `data-layer`)
2. **Ownership**: Exact files and directories they own exclusively
3. **Off-limits**: Files they must NOT touch (other agents' territories)
4. **Responsibilities**: What they build, in concrete terms
5. **Validation checklist**: Specific commands they must pass before reporting done

### Shared Infrastructure Files

Some files live at the project root and don't naturally belong to any single agent's territory — but they still need exactly one owner. Common examples:

- `package.json` / `pyproject.toml` (dependency manifest)
- `.env` / `.env.example` (environment config)
- `docker-compose.yml` (service orchestration)
- `tsconfig.json` / `vite.config.ts` (build config)
- `README.md`
- `.gitignore`
- `Makefile` / `justfile` (project-level scripts)

**Rule: Every file in the repo has exactly one owner. No exceptions.**

When defining agents, explicitly assign each shared file to the agent whose domain it most affects:

| File | Usually Owned By | Rationale |
|------|-----------------|-----------|
| Root `package.json` | Frontend (if monorepo root is JS) or Backend | Whoever runs `npm install` more often |
| `.env` / `.env.example` | Backend | Backend typically defines ports, DB URLs, API keys |
| `docker-compose.yml` | Backend | Backend defines service topology |
| `tsconfig.json` (root) | Frontend | Frontend build tooling is more sensitive to TS config |
| `.gitignore` | Lead (pre-created) | Create this yourself before spawning agents — it rarely changes |
| `README.md` | Lead (post-build) | Write this yourself after integration — agents lack full-system context |

If an agent needs a change to a file they don't own (e.g., frontend needs a new env var in `.env`), they message the lead, and the lead either makes the change directly or relays the request to the owning agent.

**In the agent definition, list shared file assignments explicitly:**

```
Agent: backend
  Owns: backend/, .env, .env.example, docker-compose.yml
  Off-limits: frontend/, contracts/ (read-only)

Agent: frontend
  Owns: frontend/, tsconfig.json, root package.json (if applicable)
  Off-limits: backend/, contracts/ (read-only)

Lead pre-creates: .gitignore, contracts/
Lead post-creates: README.md
```

---

## Phase 3: Set Up tmux

Enable tmux split panes so each agent is visible:

```
teammateMode: "tmux"
```

---

## Phase 4: Author Integration Contracts

This is the most critical phase. **Machine-readable contracts between agents are non-negotiable for reliable parallel work.** Agents that build in parallel will diverge on endpoint URLs, response shapes, type definitions, and storage semantics unless they start with agreed-upon contracts. Specification problems cause ~42% of multi-agent failures.

### 4a. Map the Contract Chain

Identify which layers must agree on interfaces. Typical chains:

```
Database → function signatures, data shapes, storage semantics → Backend
Backend → API contract (URLs, methods, request/response shapes, status codes, SSE) → Frontend
Shared → type definitions, enums, constants → All agents
```

### 4b. Create the Shared Types File

Before writing any other contract, define shared data models in a single source of truth. This prevents the most common failure mode: two agents assuming different shapes for the same entity.

Create a `contracts/` directory (or `types/`, `shared/`) with machine-readable type definitions:

```typescript
// contracts/types.ts — SINGLE SOURCE OF TRUTH for all agents

export interface User {
  id: string;           // UUID v4
  email: string;
  displayName: string;
  createdAt: string;    // ISO 8601
}

export interface Session {
  id: string;           // UUID v4
  userId: string;
  title: string;
  createdAt: string;    // ISO 8601
  updatedAt: string;    // ISO 8601
}

export interface Message {
  id: string;
  sessionId: string;
  role: "user" | "assistant";
  content: string;
  createdAt: string;
}

// Enums and constants
export const API_BASE = "/api/v1";
export const DEFAULT_PAGE_SIZE = 20;
```

**Why TypeScript interfaces**: Machine-parseable, agents can validate against them, and they serve as documentation. If the project uses Python, use Pydantic models. If multi-language, use JSON Schema.

### 4c. Author API Contracts

Define each integration contract with enough specificity that agents can build to it independently. Every contract gets a version number starting at `v1`.

**Backend → Frontend Contract (v1)**

```
## API Contract (v1)

### Conventions
- Base URL: /api/v1
- Trailing slashes: NO trailing slashes on any endpoint
- Content-Type: application/json for all requests and responses
- Dates: ISO 8601 strings everywhere

### Endpoints

POST /api/v1/sessions
  Request:  { "title": "string" }
  Response 201: { "id": "uuid", "title": "string", "createdAt": "iso8601" }
  Response 422: { "error": "string", "details": [...] }

GET /api/v1/sessions/{sessionId}/messages
  Response 200: { "messages": [{ "id": "uuid", "role": "user"|"assistant", "content": "string", "createdAt": "iso8601" }] }
  Response 404: { "error": "Session not found" }

POST /api/v1/sessions/{sessionId}/messages
  Request:  { "role": "user", "content": "string" }
  Response 201: { "id": "uuid", "role": "user", "content": "string", "createdAt": "iso8601" }

### SSE Streaming (if applicable)
POST /api/v1/sessions/{sessionId}/stream
  Event types:
    event: chunk    data: { "content": "string" }
    event: done     data: { "messageId": "uuid" }
    event: error    data: { "error": "string" }

### Error Envelope (all errors)
{ "error": "human-readable message", "code": "MACHINE_CODE", "details": [...] }
```

**Database → Backend Contract (v1)**

```
## Data Layer Contract (v1)

### Function Signatures
createSession(title: string, userId: string): Promise<Session>
getSession(sessionId: string): Promise<Session | null>
getSessionMessages(sessionId: string): Promise<Message[]>
createMessage(sessionId: string, role: string, content: string): Promise<Message>

### Storage Semantics
- Streaming chunks: Accumulated into a SINGLE message row (not per-chunk rows)
- Cascade deletes: Deleting a session deletes all its messages
- Timestamps: Set by the data layer, not the caller

### Indexes
- sessions: (userId, updatedAt DESC)
- messages: (sessionId, createdAt ASC)
```

### 4d. Assign Cross-Cutting Concerns

These behaviors span multiple agents and WILL fall through the cracks unless explicitly assigned to ONE agent:

| Concern | Assign To | Why It Matters |
|---------|-----------|----------------|
| URL conventions (trailing slashes, params) | Backend | Frontend must match exactly |
| Response envelope shape | Backend | Frontend parses this |
| Error format and status codes | Backend | Frontend error handling depends on this |
| Streaming storage semantics | Backend/Data | Accumulated vs per-chunk determines how frontend renders on reload |
| Environment config (ports, base URLs, env vars) | Backend | Frontend needs to know where to connect |
| CORS configuration | Backend | **#1 "works in dev, breaks in integration" issue.** Backend must set `Access-Control-Allow-Origin` for the frontend's origin. Frontend agent must verify zero CORS errors in browser console as part of validation. |
| Accessibility (aria-labels on interactive elements) | Frontend | Required for automated testing |

### 4e. Contract Quality Checklist

Before proceeding, verify every contract passes:

- [ ] URLs are exact, including method and path (no ambiguous "the sessions endpoint")
- [ ] Response shapes are explicit JSON, not prose ("returns session with messages" ← BAD)
- [ ] All status codes are specified for success AND error cases
- [ ] SSE event types have exact JSON shapes (if applicable)
- [ ] Storage semantics are explicit (accumulated vs per-event, cascade behavior)
- [ ] Shared types are defined once in `contracts/` and referenced by all consumers
- [ ] Trailing slash convention is stated and consistent
- [ ] Error envelope format is defined
- [ ] Each cross-cutting concern is assigned to exactly one agent
- [ ] CORS origin is specified in the backend contract
- [ ] Every shared infrastructure file (.env, docker-compose.yml, root configs) is assigned to exactly one agent

---

## Phase 5: Distill Agent Prompts

**Do NOT paste the entire plan into every agent's prompt.** Each agent receives only what they need. This keeps context focused and avoids wasting tokens on irrelevant sections.

Each agent prompt contains:

1. Their ownership scope and boundaries (including shared infrastructure files they own)
2. The shared types file (or path to it)
3. The contract(s) they produce (build to match exactly)
4. The contract(s) they consume (build against exactly)
5. The cross-cutting concerns they own
6. The relevant excerpt from the plan — NOT the full plan
7. Their validation checklist
8. Coordination rules

### Agent Prompt Template

```
You are the [ROLE] agent for this build.

## Your Ownership
- You own: [exact directories/files]
- You also own these shared files: [e.g., .env, docker-compose.yml]
- Do NOT touch: [other agents' territories]
- Read-only: contracts/ (reference these but never modify without lead approval)

If you need a change to a file you don't own (e.g., a new dependency in another
agent's package.json, a new env var in .env), message the lead with the exact
change needed. Do not make the change yourself.

## What You're Building
[Relevant excerpt from plan — only the sections this agent needs]

## Contracts

### Shared Types (v1)
[Paste or reference the shared types file]

### Contract You Produce (v1)
[The contract this agent is responsible for implementing]
Build to match this exactly. If you need to deviate:
1. STOP work on the affected interface
2. Message the lead with the proposed change and why
3. Wait for approval before continuing

### Contract You Consume (v1)
[The contract this agent depends on]
Build against this interface exactly. Do not guess or assume.
If this contract doesn't cover a case you need, message the lead.

### Cross-Cutting Concerns You Own
[List with specific instructions for each]

## Strict File Ownership
You must NEVER create, edit, or delete files outside your ownership scope.
If you believe a file outside your scope needs changes, message the lead.
Do not "helpfully" create files in another agent's territory — this causes
silent conflicts and data loss. After each meaningful commit: git status

## Coordination Rules
- Message the lead if you discover something that affects a contract
- STOP work on affected interfaces when requesting a contract change
- Do not build against your own assumptions — ask the lead
- Flag cross-cutting concerns that weren't anticipated

## Before Reporting Done
Run ALL validations and fix any failures before reporting done:
1. [specific command, e.g., "npm run build" or "python -m pytest tests/"]
2. [specific command, e.g., "tsc --noEmit" or "curl -s http://localhost:8000/api/v1/health"]
3. [specific manual check if needed]
4. Verify your code uses the EXACT URLs/shapes from the contract — compare manually

Do NOT report done until every validation passes.
```

---

## Phase 6: Spawn All Agents in Parallel

Enter **Delegate Mode** (Shift+Tab) before spawning. You must NOT implement code yourself — your entire role is coordination, validation, and contract management.

Spawn all agents simultaneously with their distilled prompts. This is the payoff for the contract work: all agents build in parallel to agreed-upon interfaces from the very first line of code.

---

## Phase 7: Active Coordination

All agents are now working in parallel. Your job is to keep them aligned and unblocked. You are the bottleneck — respond to agent messages quickly.

### Contract Change Protocol

When an agent requests a contract deviation:

1. **Pause**: Tell the requesting agent to STOP work on the affected interface immediately
2. **Evaluate**: Determine if the change is necessary. What other agents does it affect?
3. **Update**: Write the updated contract with an incremented version (v1 → v2). Write the full updated contract, not just the diff
4. **Notify**: Send the updated contract to ALL affected agents with explicit instructions:
   ```
   CONTRACT UPDATE: Backend → Frontend contract is now v2.
   CHANGE: GET /api/v1/sessions/{id} now returns
     {"session": {...}, "messages": [...]}
   instead of just {"messages": [...]}.
   ACTION REQUIRED: Update your fetch calls to destructure
   from the new response envelope.
   ```
5. **Confirm**: Wait for each affected agent to acknowledge the update before they resume
6. **Log**: Keep a running changelog so you can trace integration issues:
   ```
   Contract Changelog:
   - v1 (initial): [description]
   - v2 (agent-B request): Added session envelope to GET /sessions/{id} response
   ```

**Never approve a change verbally and assume agents will figure out the details.** Always write the full updated contract and get explicit acknowledgment.

### Shared File Change Requests

When an agent needs a change to a shared file they don't own:

1. Agent messages you with the exact change needed (e.g., "I need `DATABASE_URL` added to `.env`")
2. You evaluate: does this affect other agents?
3. If no: relay the request to the owning agent, or make the change yourself
4. If yes: treat it like a contract change — pause, update, notify all affected agents

Common triggers: frontend needs a new env var, backend needs a dependency added to a shared `package.json`, an agent needs a new service in `docker-compose.yml`.

### Message Relay

Agents cannot talk to each other directly. You relay all inter-agent communication:

- Agent A flags an issue → You evaluate → You notify Agent B with specific instructions
- Agent B needs something from Agent A → You determine if it's a contract change or a simple info request → You relay appropriately

### Progress Tracking

Maintain a shared task list:

```
[ ] Agent A: Build UI components (frontend/)
[ ] Agent B: Implement API endpoints (backend/)
[ ] Lead: Pre-completion contract verification (blocked by A, B)
[ ] All: Integration fixes (blocked by contract verification)
[ ] Lead: End-to-end validation (blocked by integration fixes)
```

### Circuit Breaker

If an agent fails validation 3 times on the same issue:

1. Stop that agent
2. Read their code yourself to diagnose the root cause
3. Determine if it's a contract bug (affects multiple agents) or an implementation bug (single agent)
4. For contract bugs: follow the Contract Change Protocol
5. For implementation bugs: re-spawn the agent with the specific error, root cause analysis, and a concrete fix direction
6. If the same agent fails 5+ times: consider whether the task decomposition is wrong and the agent's scope needs to change

---

## Phase 8: Validation

Validation has three stages: **contract diff** (do the interfaces match?), **agent validation** (does each domain work in isolation?), and **end-to-end testing** (does the integrated system work?).

### Stage 1: Contract Diff

Before any agent reports "done", verify that the implemented interfaces actually match across agents. This catches the integration mismatches that cause most post-build failures.

1. Ask the backend agent: **"List every endpoint you implemented with exact curl commands that test each one."**
2. Ask the frontend agent: **"List every API call you make with exact URLs, methods, headers, and request bodies."**
3. Compare line by line:
   - Do the URLs match exactly (including trailing slashes)?
   - Do the request bodies match?
   - Do the expected response shapes match?
   - Are error cases handled on both sides?
4. If the data layer is a separate agent, also verify: **"List every function signature you export with parameter types and return types."** Compare against what the backend agent is calling.
5. Flag and resolve ALL mismatches before proceeding. Each mismatch gets sent back to the responsible agent with the specific fix required.

### Stage 2: Agent Validation

Each agent runs their domain-specific validation checklist. Tailor these to the plan with specific commands, not vague instructions.

**Data layer validates:**
- Schema creates without errors (`python -m database.init` or equivalent)
- All CRUD functions work (create, read, update, delete — test each one)
- Foreign keys and cascade deletes behave correctly
- Indexes exist for contracted query patterns

**Backend agent validates:**
- Server starts without errors on the contracted port
- Every contracted endpoint responds correctly (test with curl, show the commands)
- Request/response formats match the contract EXACTLY (compare JSON shapes)
- Error cases return the contracted status codes and error envelope
- SSE streaming works end-to-end (if applicable)
- CORS headers are present for the frontend's origin (`Access-Control-Allow-Origin`)

**Frontend agent validates:**
- TypeScript compiles cleanly (`tsc --noEmit`)
- Build succeeds (`npm run build` with zero errors)
- Dev server starts and loads without console errors
- Components render correctly for the primary user flow
- API calls use the EXACT contracted URLs and methods
- **Zero CORS errors in the browser console** when calling backend endpoints

### Stage 3: End-to-End Testing

After all agents pass their validation and the contract diff is clean, you run end-to-end testing yourself. This catches integration issues that no single agent can see.

**Startup test:**
1. Start all services (database, backend, frontend) in order
2. Verify zero startup errors
3. Verify backend can connect to database
4. Verify frontend can reach backend (no CORS errors, no connection refused)

**Happy path test:**
1. Walk through the primary user flow end-to-end
2. Each step produces the expected result
3. Data flows correctly: frontend → backend → database → backend → frontend
4. Verify data persists (reload the page — does it still show?)

**Edge case tests:**
1. Empty states render correctly (no data yet)
2. Error states show user-friendly messages (kill the backend — does frontend handle it?)
3. Loading states appear during async operations
4. Invalid input is rejected gracefully

### When Validation Fails

**Single-agent bug** (contract is correct, implementation is wrong):
- Identify which agent's domain contains the bug
- Re-spawn that agent with: the specific error message, the expected behavior, and the file(s) involved
- Re-run the failed validation after fix

**Contract bug** (the contract itself was wrong or incomplete):
- Follow the full Contract Change Protocol (Phase 7)
- Increment the version number
- Re-spawn ALL affected agents with the updated contract
- Re-run full end-to-end validation

**Cascading failure** (contract change ripples across multiple agents):
1. Stop all agents
2. Assess the full scope of the change
3. Rewrite all affected contracts with new version numbers
4. If the cascade is large, consider rebuilding affected layers sequentially (data → backend → frontend) rather than parallel re-spawns — dependency order matters for cascading fixes
5. Re-run full end-to-end validation

---

## Anti-Patterns to Prevent

| Anti-Pattern | Why It Fails | Prevention |
|---|---|---|
| **Spawning without contracts** | Agents diverge on URLs, shapes, types. Integration fails. | Never spawn until all contracts pass the quality checklist. |
| **Fully sequential spawning** | One agent at a time defeats the purpose of agent teams. | Contracts enable parallel spawning — that's the whole point. |
| **"Tell agents to coordinate"** | They won't reliably. One agent sends info, the other already built half the app. | All coordination goes through you (the lead). |
| **Verbal contract changes** | You say "sure, change it" — other agents never hear. | Always write the full updated contract, version it, and get acknowledgments. |
| **Pasting full plan to all agents** | Wastes context, confuses agents with irrelevant info. | Distill: each agent gets only their relevant sections + contracts. |
| **Lead starts coding** | You lose coordination awareness. Agents get stuck waiting. | Stay in Delegate Mode. Your job is orchestration. |
| **Too many agents** | Coordination cost scales quadratically. 5 agents = 10 integration surfaces. | Default to 2. Only add agents for genuinely independent parallel work. |
| **Shared file editing** | Last write wins. Silent data loss. Agent A creates a file, Agent B deletes it. | Strict file ownership. No exceptions without lead approval. |
| **Agent scope creep** | Agent "helpfully" creates files outside their ownership to move faster. Causes silent conflicts when another agent creates the same file or the lead doesn't know it exists. | Prompt template explicitly forbids out-of-scope file creation. Treat any violation as a bug. |
| **Unowned shared files** | Nobody owns `.env` or `docker-compose.yml`. Both agents edit it. Last write wins silently. | Assign every shared infrastructure file to exactly one agent during Phase 2. |
| **Skipping contract diff** | Backend uses `/api/sessions/` (trailing slash), frontend calls `/api/sessions` (no slash). | Always run the curl-vs-fetch comparison before integration testing. |
| **Per-chunk storage** | Backend stores each SSE chunk as a separate DB row. Frontend renders N bubbles on reload. | Specify accumulation strategy in the data layer contract. |
| **Hidden UI elements** | CSS `opacity-0` on interactive elements — invisible to automation/testing. | Require aria-labels and visible focus states in frontend contract. |
| **Optimistic peer review** | Expecting agents to meaningfully review each other's code. They lack cross-domain context. | Use concrete integration assertions and contract diffs instead. |

---

## Definition of Done

The build is complete when ALL of the following are true:

1. ✅ Every agent has passed their validation checklist
2. ✅ Lead has run the contract diff (curl vs fetch comparison) — zero mismatches
3. ✅ Lead has run end-to-end validation (startup, happy path, edge cases)
4. ✅ All integration issues found have been fixed and re-validated
5. ✅ The plan's acceptance criteria are met
6. ✅ Contract changelog is clean (no pending/unapproved changes)

---

## Execute

Now read the plan at `$ARGUMENTS[0]` and begin. Follow this sequence exactly:

1. **Read** the plan — extract components, technologies, dependencies, shared data models, validation criteria
2. **Size the team** — use `$ARGUMENTS[1]` if provided; otherwise default to 2, justify if using more
3. **Define agents** — names, exact file ownership (including shared infrastructure files), off-limits boundaries, validation commands
4. **Pre-create lead-owned files** — `.gitignore`, `contracts/` directory, shared types file
5. **Author contracts** — start with shared types file, then layer-to-layer contracts with exact URLs, JSON shapes, function signatures, status codes. Version everything as v1. Run the quality checklist.
6. **Assign cross-cutting concerns** — every concern gets exactly one owner
7. **Distill prompts** — extract only relevant plan sections per agent; include contracts, types, shared file ownership, and validation checklists
8. **Enter Delegate Mode** (Shift+Tab) — you do not write code from this point forward
9. **Spawn all agents in parallel** with their distilled prompts
10. **Coordinate** — relay messages, manage contract changes (pause → update → version → notify → confirm), handle shared file change requests, unblock agents, track progress
11. **Validate** — contract diff first, then agent-level validation, then end-to-end testing
12. **Fix failures** — re-spawn agents for implementation bugs; follow cascading failure protocol for contract bugs
13. **Post-build** — write README.md, clean up any loose ends
14. **Confirm** the build meets the plan's acceptance criteria
