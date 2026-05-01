# 14-Phase Build Playbook

## Phase 0: External Services Audit (MANDATORY when integrating with existing services)

**Before reading the plan**, if the build integrates with any existing external service (auth server, API gateway, OAuth provider, payment processor, third-party backend), do this first:

1. **Read the Terraform / deployment config** for that service — not just the code, the *infrastructure*. Look for:
   - Allowed origins / redirect URIs / CORS whitelists
   - Environment variables set on the running service (Cloud Run, ECS, Heroku, etc.)
   - Firewall rules, VPC config, IAM permissions
   - Any hardcoded values that differ from `.env.example` or docs
2. **Identify every constraint the running service imposes** on consumers — ports, domains, scopes, rate limits
3. **Record these as hard constraints in the contracts** before any agent is spawned. These are non-negotiable facts about the real world, not design decisions.
4. **If a constraint blocks the plan** (e.g., the auth server doesn't allow localhost callbacks), flag it to the user BEFORE writing contracts and BEFORE spawning any agents. Do not proceed around it silently.

> **Why this phase exists**: The most common integration failure is building against documentation or code while the actual *running* service has different configuration. A Terraform file telling you `ALLOWED_REDIRECT_ORIGINS=https://*.example.com` with no localhost entries will break every local dev OAuth flow — and no amount of correct application code will fix it. Read the infra first.

## Phase 1: Read and Analyze the Plan

Read the plan document. Extract:

- **What** are we building? (product, features, acceptance criteria)
- **Components**: Major layers (frontend, backend, database, infra, workers)
- **Technologies**: Languages, frameworks, tools
- **Shared data models**: Entities referenced by multiple components
- **Dependency graph**: What must exist before something else can be built
- **Validation criteria**: How we know it works (tests, curl commands, UI flows)
- **Architecture visualization** — use the mermaid-charts skill to generate an architecture overview diagram showing major components, their layers, and dependency flow. This visual anchor guides the rest of the build and is included in final documentation.

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

For monorepos where ≥2 implementation agents will each write a package manifest (`package.json`, `pyproject.toml`, `Cargo.toml`), also invoke the `dependency-coordinator` skill in this same phase. It authors the cross-package dependency contract so parallel agents don't produce transitive version drift that breaks `install` after the wave completes.

Quality checklist (all must pass):

- URLs are exact (method + path)
- Response shapes are explicit JSON
- All status codes specified (success AND error)
- Trailing slash convention stated
- Error envelope defined
- CORS origin specified — and verified against the **actual running Terraform/deployment config**, not just docs
- For OAuth/auth integrations: allowed redirect origins verified in the **running** service config (not just `.env.example`)
- Every external service constraint from Phase 0 is explicitly reflected in the contract
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
- Follow git-commit conventions for branch naming and commit messages throughout the build
- Create `.gitignore` (orchestrator-owned)
- Invoke `contract-author` skill to create `contracts/` with shared types and integration contracts — contract-author owns this directory
- Create any skeleton files needed for agent orientation (assign ownership per the canonical table in `skills/orchestrator/SKILL.md` § File Ownership Map)

## Phase 7: Detect Runtime and Spawn

Use the runtime detection tree in `skills/orchestrator/SKILL.md` § Runtime Detection (the canonical version — kept there because it's always loaded). Once the runtime is chosen, spawn all implementation agents simultaneously with their distilled prompts.

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
- **External service integration**: For every external service integrated, verify the running service config actually accepts requests from the app (test the actual OAuth redirect, API call, webhook, etc.) — do not assume it works because the code is correct

## Phase 11: Smoke Testing (Orchestrator)

You (the orchestrator) run quick smoke tests to verify integration before spawning QE. This is a fast sanity check, NOT a thorough test suite:

1. **Startup**: All services start, connect, no errors
2. **Happy path**: One primary flow works end-to-end
3. **Data flow**: Verify one write is visible via read (Frontend → Backend → Database → Backend → Frontend)

For browser-based flows (auth, form submit, navigation), invoke the `playwright` skill to drive a real browser through the happy path — this catches CORS, redirect, and rendering issues that curl-only smoke tests miss. The QE agent will rerun and extend these in Phase 13.

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
2. Generate final architecture diagram(s) using mermaid-charts — system overview, data flow, and deployment topology as appropriate. Include in README or `docs/`.
3. Clean up any temporary files
4. Verify the plan's acceptance criteria are met
5. If the build will go through PR review, hand off to the `git-pr` and `git-pr-feedback` skills for the review cycle — they own commit/PR conventions and the response-to-review loop.
6. Produce final status report

## Definition of Done

The canonical DoD lives in `skills/orchestrator/SKILL.md` § Definition of Done. Use that — it's the always-loaded version and includes the UI-renders gate and one-command-dev requirement that this file would otherwise drift on.
