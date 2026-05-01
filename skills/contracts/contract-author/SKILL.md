---
name: contract-author
version: 1.2.0
description: |
  Generate machine-readable integration contracts (API, data layer, shared types, events) before any implementation begins in multi-agent builds. This is orchestrator Phase 4 — contracts are written here before any implementation agent is spawned. Use this skill when authoring API contracts, OpenAPI specs, AsyncAPI specs, Pydantic models, TypeScript interfaces, JSON Schema definitions, data layer interfaces, shared type schemas, integration boundaries between agents, or domain business rules for multi-agent coordination. Trigger for any contract creation task, especially before spawning implementation agents. Also trigger when the user says "write the API contract", "define the shared types", "spec out the endpoints", "create the OpenAPI", "author the contract", or when the orchestrator needs contracts authored for a plan document. Bundles 6 templates: OpenAPI, AsyncAPI, Pydantic, TypeScript, JSON Schema, and a data-layer YAML — pick the one matching the project's stack.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: ["contracts/", "schemas/"]
  patterns: ["openapi.yaml", "asyncapi.yaml"]
  shared_read: ["*"]
allowed_tools: ["Read", "Write", "Edit", "Glob", "Grep"]
composes_with: ["backend-agent", "frontend-agent", "contract-auditor", "qe-agent"]
spawned_by: ["orchestrator"]
---

# Contract Author

Generate machine-readable integration contracts before any implementation begins. Contracts are the foundation of reliable multi-agent builds — specification problems cause ~42% of multi-agent failures.

## Role

You are the **contract author**. You create the shared types, API contracts, and data layer contracts that implementation agents build against. You work during the orchestrator's Phase 4, before any implementation agent is spawned.

## Why Contracts Matter

Without contracts, agents independently invent their own endpoint URLs, response shapes, type definitions, and storage semantics. The result: two implementations that technically work in isolation but fail at integration. Contracts eliminate this by defining the interfaces upfront.

## Process

### 0. Extract Entities from the Plan

Before writing any contract, read the plan and extract:

- **Domain entities** — nouns that represent stored data (User, Product, Order, etc.)
- **Relationships** — which entities reference which (Order has many OrderItems, each referencing a Product)
- **Actions** — verbs that become endpoints (create, search, checkout, upload)
- **Domain rules** — business logic that crosses agent boundaries (e.g., "sellers can't buy their own listings", "stock decrements atomically at checkout")
- **Integration points** — external services (Stripe, S3, Redis) that need contract coverage

This extraction step prevents missing entities that only become apparent during implementation.

### 1. Start with Shared Types

Always create the shared types file first — everything else references it.

Pick the format that matches the project's primary language:

- TypeScript → `references/typescript-template.ts`
- Python → `references/pydantic-template.py`
- Multi-language → `references/json-schema-template.json`

Define every entity, enum, request shape, response shape, and the error envelope. Use the strongest type annotations available — `EmailStr` for emails, `HttpUrl` for URLs, `Decimal` for money (or integer cents with clear documentation). The richer the types, the fewer integration bugs.

### 2. Author API Contract

Use `references/openapi-template.yaml` as the starting point. For every endpoint, specify:

- **Method + Path** (exact, including trailing slash convention)
- **Request body** (exact JSON shape with types)
- **Success response** (status code + exact JSON shape)
- **Error responses** (every possible error status + shape)
- **SSE/Streaming events** (if applicable, with exact event shapes)

Required sections (non-negotiable):

- Conventions (base URL, trailing slashes, Content-Type, date format, ID format)
- Error envelope (standard shape for all errors)
- CORS (allowed origin for browser consumers)

### 3. Author Data Layer Contract

Use `references/data-layer-template.yaml` as the starting point. Define function signatures, return types, storage semantics:

- Streaming/chunked data handling (accumulated vs per-chunk)
- Cascade delete behavior
- Timestamp ownership (caller vs data layer vs DB)
- ID generation strategy
- Required indexes

### 4. Author Event Contract (if applicable)

For event-driven systems, use `references/asyncapi-template.yaml`:

- Channel/topic names
- Message schemas
- Delivery guarantees
- Error handling

### 5. Assign Cross-Cutting Concerns

Explicitly assign each concern to exactly one agent:

- URL conventions → backend
- Response envelope → backend
- Error format → backend
- CORS configuration → backend
- Streaming storage → backend/data layer
- Accessibility → frontend

Add project-specific concerns as they arise (e.g., Stripe webhook validation → backend, image upload storage → backend, client-side validation → frontend).

### 6. Document Domain Business Rules

Capture cross-cutting business logic that agents need to enforce consistently. These are rules that don't belong in a single contract file but affect multiple agents:

- Invariants (e.g., "sellers cannot buy their own listings")
- Transaction semantics (e.g., "checkout must atomically decrement stock and create order")
- Idempotency requirements (e.g., "webhook handler must tolerate duplicate delivery")
- State machine transitions (e.g., "order status can only go pending → paid → shipped → delivered")

Document these in `contracts/README.md` under a "Domain Rules" section.

### 7. Define File Ownership Boundaries

In `contracts/README.md`, include a table mapping which agent owns which files/directories. This prevents conflicts during parallel implementation:

```
| Agent    | Owns                              |
|----------|-----------------------------------|
| Backend  | src/api/, src/services/, src/models/ |
| Frontend | src/components/, static/, templates/ |
| Neither  | contracts/ (read-only)             |
```

### 8. Add Per-Agent Implementation Notes

For each agent that will consume the contracts, include brief implementation guidance in the README:

- Which libraries/frameworks to use for contract compliance
- How to import or generate types from the shared types file
- Any agent-specific patterns (e.g., "frontend should generate TypeScript types from openapi.yaml using openapi-typescript")

These notes save agents from independently rediscovering the same decisions.

### 9. Quality Checklist

Before handing contracts to the orchestrator:

- [ ] URLs are exact (method + path, no ambiguity)
- [ ] Response shapes are explicit JSON, not prose
- [ ] All status codes specified (success AND error)
- [ ] SSE event types have exact JSON shapes
- [ ] Storage semantics explicit
- [ ] Shared types defined once and referenced everywhere
- [ ] Trailing slash convention stated
- [ ] Error envelope defined
- [ ] Cross-cutting concerns each assigned to one agent
- [ ] CORS origin specified
- [ ] Every contract versioned (start at v1)
- [ ] Domain business rules documented
- [ ] File ownership boundaries defined for each agent
- [ ] Per-agent implementation notes included
- [ ] Field names consistent across ALL contract files (types, OpenAPI, data layer)
- [ ] Complexity matches project scope (simple projects don't need JWT, AsyncAPI, etc.)

## Contract Versioning

All contracts start at v1. When changes are needed during the build:

1. Increment version (v1 → v2)
2. Write the full updated contract (not just a diff)
3. Notify all affected agents with explicit change description
4. Get acknowledgment from each affected agent

## Right-Sizing

Match contract complexity to the project. A personal habit tracker with SQLite doesn't need JWT auth schemas, AsyncAPI specs, or elaborate security middleware contracts. Ask:

- Does this project need auth? If not, omit security schemes entirely.
- Is there a real-time component? If not, skip AsyncAPI.
- How many entities? A 2-entity project needs a simpler data layer than a 10-entity one.
- What DB? SQLite projects use auto-increment IDs, not UUIDs. PostgreSQL projects can use UUID v4.

Over-engineered contracts waste agent time implementing unnecessary complexity.

## Output

Your deliverables (machine-readable formats — not markdown narratives):

- `contracts/types.[ts|py|json]` — shared type definitions
- `contracts/openapi.yaml` — API contract (OpenAPI 3.1 spec)
- `contracts/data-layer.yaml` — data layer interface (use `references/data-layer-template.yaml`)
- `contracts/asyncapi.yaml` — event-driven interface (if applicable)
- `contracts/README.md` — human-readable summary including:
  - Conventions (base URL, trailing slashes, date format, ID format, CORS)
  - Naming transform table (snake_case ↔ camelCase field mappings)
  - Cross-cutting concern assignments
  - Domain business rules
  - File ownership boundaries
  - Per-agent implementation notes
  - Endpoint quick reference

The `schemas/` directory is for standalone JSON Schema files when the project uses schema-based validation outside the API context (e.g., config file validation, message queue payloads).

## Naming Convention Rule

When the API uses camelCase (OpenAPI/TypeScript) but the backend uses snake_case (Python), document the transform explicitly in `contracts/README.md`. The Pydantic template includes `alias_generator=to_camel` for this — both sides must agree on the wire format.
