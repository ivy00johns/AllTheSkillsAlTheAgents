# 14-Phase Build Playbook

## Phase 1: Read and Analyze the Plan

Read the plan document. Extract:

- **What** are we building? (product, features, acceptance criteria)
- **Components**: Major layers (frontend, backend, database, infra, workers)
- **Technologies**: Languages, frameworks, tools
- **Shared data models**: Entities referenced by multiple components
- **Dependency graph**: What must exist before something else can be built
- **Validation criteria**: How we know it works (tests, curl commands, UI flows)

## Phase 2: Size the Team

See `references/team-sizing.md` for the full decision framework.

**Size the team based on the work.** Consider:

- How many components can be built in parallel?
- Do they have clear ownership boundaries (no shared files)?
- Can the orchestrator manage context for this many agents? (Use handoffs and phased spawning for larger teams)

## Phase 3: Define Agents

For each agent:

1. Name (short, descriptive)
2. Exact file/directory ownership
3. Off-limits boundaries
4. Concrete responsibilities
5. Validation commands

Assign every shared infrastructure file to exactly one agent.

## Phase 4: Author Integration Contracts

**This is the most critical phase.** Contracts prevent the ~42% of multi-agent failures caused by specification problems.

Order:

1. **Shared types first** — single source of truth for all entities
2. **API contract** — URLs, methods, request/response shapes, status codes, SSE events
3. **Data layer contract** — function signatures, storage semantics, indexes
4. **Cross-cutting concerns** — assign each to exactly one agent

Use the contract-author skill and templates in `contracts/contract-author/references/`.

Quality checklist (all must pass):

- URLs are exact (method + path)
- Response shapes are explicit JSON
- All status codes specified (success AND error)
- Trailing slash convention stated
- Error envelope defined
- CORS origin specified
- Every contract versioned as v1

## Phase 5: Distill Agent Prompts

**Do NOT paste the full plan into every agent's prompt.** Each agent receives only:

1. Their ownership scope and boundaries
2. Shared types file (or path)
3. Contracts they produce (implement exactly)
4. Contracts they consume (build against exactly)
5. Cross-cutting concerns they own
6. Relevant plan excerpt only
7. Validation checklist
8. Coordination rules

## Phase 6: Pre-Create Scaffolding

Before spawning implementation agents:

- **Create a feature branch** — `git checkout -b build/<project-name>`. All work happens here, never on main. Do not merge to main unless the user explicitly requests it.
- Create `.gitignore` (orchestrator-owned)
- Invoke `contract-author` skill to create `contracts/` with shared types and integration contracts — contract-author owns this directory
- Create any skeleton files needed for agent orientation (assign ownership per the canonical table in the design spec §6)

## Phase 7: Detect Runtime and Spawn

```text
Is CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS set?
  YES → Use native Agent Teams (tmux split panes)
  NO → Is bash tool available?
    YES → Use subagents via Task/Agent tool (parallel)
    NO → Sequential mode (work through roles one at a time)
```

Spawn all implementation agents simultaneously with their distilled prompts.

## Phase 8: Active Coordination

While agents work:

- Relay inter-agent messages (agents can't talk directly)
- Manage contract change requests (pause → update → version → notify → confirm)
- Handle shared file change requests
- Track progress
- Apply circuit breaker if needed (see `references/circuit-breaker.md`)

### Contract Change Protocol

1. Tell requesting agent to STOP work on affected interface
2. Evaluate the change and which agents it affects
3. Write updated contract with incremented version (v1 → v2)
4. Send full updated contract to ALL affected agents
5. Wait for acknowledgment from each
6. Log the change in the contract changelog

## Phase 9: Contract Diff

Before any agent reports "done":

1. Get backend's exact curl commands for each endpoint
2. Get frontend's exact API call URLs/methods/bodies
3. Compare line by line — URLs, request bodies, response shapes, error handling
4. Flag and resolve ALL mismatches

## Phase 10: Agent Validation

Each agent runs their domain-specific validation checklist:

- Backend: server starts, endpoints respond correctly, CORS headers present
- Frontend: TypeScript compiles, build succeeds, dev server loads, zero CORS errors
- Infrastructure: Docker builds, services healthy
- Data layer: schema correct, CRUD works, cascades work

## Phase 11: Smoke Testing (Orchestrator)

You (the orchestrator) run quick smoke tests to verify integration before spawning QE. This is a fast sanity check, NOT a thorough test suite:

1. **Startup**: All services start, connect, no errors
2. **Happy path**: One primary flow works end-to-end
3. **Data flow**: Verify one write is visible via read (Frontend → Backend → Database → Backend → Frontend)

If smoke tests fail, fix integration issues before wasting QE agent context on a broken build. If they pass, spawn QE for thorough verification.

## Phase 12: Fix Failures

- **Single-agent bug** (contract correct, implementation wrong): Re-spawn that agent with specific error + expected behavior
- **Contract bug** (contract itself was wrong): Follow Contract Change Protocol, increment version, re-spawn affected agents
- **Cascading failure**: Stop all agents, rewrite affected contracts, rebuild in dependency order (data → backend → frontend)

## Phase 13: QA Gate

Spawn the QE agent for thorough verification. QE handles contract conformance, integration testing, adversarial probing, and produces `qa-report.json` per the schema in `roles/qe-agent/references/qa-report-schema.json`.

Before parsing scores, validate the report conforms to the schema (scores are `{score, notes}` objects, all required fields present). Send non-conformant reports back to QE for correction.

Gate rules:

- `gate_decision.proceed = false` blocks the build
- Blocked when: any CRITICAL blocker, `contract_conformance.score < 3`, `security.score < 3`
- The orchestrator does NOT override the QE gate

## Phase 14: Post-Build

1. Spawn docs-agent to write README.md — provide full-system context (architecture summary, how to run, directory map). Docs-agent owns README.md.
2. Clean up any temporary files
3. Verify the plan's acceptance criteria are met
4. Produce final status report

## Definition of Done

ALL of the following must be true:

1. Every agent passed their validation checklist
2. Contract diff — zero mismatches
3. End-to-end validation — startup, happy path, edge cases pass
4. All integration issues fixed and re-validated
5. Plan's acceptance criteria met
6. Contract changelog clean (no pending changes)
7. QA gate passed (if QE agent was spawned)
