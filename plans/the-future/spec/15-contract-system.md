# 15 — Contract System Specification

**Document type:** System specification
**Status:** DRAFT
**Date:** 2026-03-18
**Scope:** Contract-first architecture, authoring, auditing, ownership enforcement, and quality integration
**Depends on:** `04-role-taxonomy.md` (agent roles), `07-merge-system.md` (pre-merge conformance), `08-skill-system.md` (skill ownership), `10-quality-intelligence.md` (QA gates)
**Source platforms:** ATSA (contract-author/auditor skills, file ownership, QA gate scoring), Gas Town (TOML formula acceptance criteria), Overstory (guard rules, path boundaries, exit triggers)

---

## 1. Why Contract-First Architecture

### The Multi-Agent Coordination Problem

When N agents build N components of the same system in parallel, every pair of components that interact creates an integration surface. Without explicit agreement on those surfaces, each agent invents its own version: different endpoint paths, different field names, different response shapes, different error envelopes. The components work individually but fail together.

This is not a hypothetical risk. Research on multi-agent software builds shows that specification problems -- mismatched interfaces, ambiguous requirements, undocumented assumptions -- cause approximately 42% of integration failures. Contract-first architecture eliminates this class of failure by defining every integration surface before any agent writes implementation code.

### Three Purposes of Contracts

Contracts serve the platform at three levels:

**1. Specification.** A contract defines what to build before building it. An OpenAPI spec declares that `POST /auth/login` accepts `{email, password}` and returns `{token, expiresAt}`. The backend builder implements that endpoint. The frontend builder calls that endpoint. Neither guesses. Both reference the same machine-readable document.

**2. Verification.** A contract enables automated checking. After implementation, the contract auditor reads the implementation code and the contract side by side. Does the handler at `POST /auth/login` actually parse an `email` field? Does the response include `expiresAt`? Automated checks catch drift before integration testing begins.

**3. Communication.** Contracts are machine-readable interface definitions that agents can parse without human interpretation. A TypeScript interface is unambiguous. A JSON Schema is unambiguous. Natural language requirements are not. When an agent loads a contract, it knows exactly what types to use, what fields to include, and what status codes to return.

### Why Before Implementation, Not After

The alternative -- writing contracts after implementation to document what was built -- provides documentation but not coordination. By the time you document what agent A built, agent B has already built something incompatible. The contract must exist before either agent starts. This is the contract-first constraint: no implementation agent is spawned until the contract-author has produced the interface specifications and the coordinator has distributed them.

---

## 2. Contract Types

The platform supports five contract formats. Each serves a different integration surface. Projects use whichever subset matches their architecture -- a simple REST API needs OpenAPI and TypeScript interfaces; an event-driven system adds AsyncAPI; a Python project substitutes Pydantic for TypeScript.

### OpenAPI (REST APIs)

The primary contract format for HTTP endpoints. Declares paths, methods, request bodies, response shapes, error envelopes, and authentication schemes.

```yaml
openapi: 3.1.0
info:
  title: User Authentication API
  version: 1.0.0
paths:
  /auth/login:
    post:
      summary: Authenticate user
      operationId: loginUser
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/LoginRequest'
      responses:
        '200':
          description: Authentication successful
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AuthToken'
        '401':
          description: Invalid credentials
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiError'
        '422':
          description: Validation error
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ApiError'
components:
  schemas:
    LoginRequest:
      type: object
      required: [email, password]
      properties:
        email: { type: string, format: email }
        password: { type: string, minLength: 8 }
    AuthToken:
      type: object
      required: [token, expiresAt]
      properties:
        token: { type: string }
        expiresAt: { type: string, format: date-time }
    ApiError:
      type: object
      required: [error, code, details]
      properties:
        error: { type: string }
        code:
          type: string
          enum: [VALIDATION_ERROR, NOT_FOUND, UNAUTHORIZED,
                 FORBIDDEN, INTERNAL_ERROR, RATE_LIMITED]
        details:
          type: array
          items:
            type: object
            required: [message]
            properties:
              field: { type: string }
              message: { type: string }
```

Every endpoint declares exact paths, exact request shapes, exact response shapes, and every possible error status code. The error envelope is standardized across the entire API -- agents do not invent their own error formats.

### AsyncAPI (Event-Driven APIs)

For systems that communicate through message channels, event buses, or streaming protocols. Declares channels, message schemas, delivery guarantees, and operation semantics.

```yaml
asyncapi: 3.0.0
info:
  title: Agent Coordination Events
  version: 1.0.0
channels:
  agentStatus:
    address: events.agent.status
    messages:
      agentStatusMessage:
        $ref: '#/components/messages/AgentStatusUpdate'
  taskCompleted:
    address: events.task.completed
    messages:
      taskCompletedMessage:
        $ref: '#/components/messages/TaskCompleted'
operations:
  publishAgentStatus:
    action: send
    channel:
      $ref: '#/channels/agentStatus'
  consumeTaskCompleted:
    action: receive
    channel:
      $ref: '#/channels/taskCompleted'
components:
  messages:
    AgentStatusUpdate:
      headers:
        type: object
        properties:
          correlationId: { type: string, format: uuid }
          timestamp: { type: string, format: date-time }
          source: { type: string }
      payload:
        type: object
        required: [agentId, status, taskId]
        properties:
          agentId: { type: string }
          status:
            type: string
            enum: [active, idle, stalled, zombie]
          taskId: { type: string }
    TaskCompleted:
      headers:
        type: object
        properties:
          correlationId: { type: string, format: uuid }
          timestamp: { type: string, format: date-time }
      payload:
        type: object
        required: [taskId, agentId, result]
        properties:
          taskId: { type: string }
          agentId: { type: string }
          result:
            type: string
            enum: [success, partial, failed]
          artifacts: { type: array, items: { type: string } }
```

### TypeScript Interfaces

Shared type definitions that serve as the single source of truth across frontend and backend when both use TypeScript. Defines entities, enums, request/response shapes, and domain constants.

```typescript
export interface WorkItem {
  id: string;
  title: string;
  status: 'open' | 'active' | 'blocked' | 'resolved' | 'closed';
  priority: 0 | 1 | 2 | 3 | 4;
  type: 'bug' | 'feature' | 'task' | 'chore' | 'spike';
  assignee?: string;
  labels: string[];
  dependencies: Dependency[];
  createdAt: string;   // ISO 8601
  updatedAt: string;   // ISO 8601
}

export interface Dependency {
  sourceId: string;
  targetId: string;
  type: DependencyType;
}

export type DependencyType =
  | 'blocks' | 'blocked-by'
  | 'needs-design' | 'design-needed-by'
  | 'requires-migration' | 'migration-required-by'
  | 'needs-api' | 'api-needed-by'
  | 'needs-test' | 'test-needed-by'
  | 'needs-review' | 'review-needed-by'
  | 'needs-contract' | 'contract-needed-by'
  | 'needs-security' | 'security-needed-by'
  | 'needs-docs' | 'docs-needed-by'
  | 'needs-deploy' | 'deploy-needed-by'
  | 'needs-config' | 'config-needed-by';

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  offset: number;
  limit: number;
}

export interface ErrorDetail {
  field?: string;
  message: string;
}

export interface ApiError {
  error: string;
  code: ErrorCode;
  details: ErrorDetail[];
}

export type ErrorCode =
  | 'VALIDATION_ERROR' | 'NOT_FOUND' | 'UNAUTHORIZED'
  | 'FORBIDDEN' | 'INTERNAL_ERROR' | 'RATE_LIMITED';
```

### Pydantic Models (Python)

The Python equivalent of TypeScript interfaces. Uses Pydantic's validation engine to enforce types at runtime. Includes the `alias_generator` pattern for snake_case-to-camelCase translation on the wire.

```python
from datetime import datetime
from enum import Enum
from typing import Literal, Optional, List
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


def to_camel(string: str) -> str:
    components = string.split("_")
    return components[0] + "".join(x.title() for x in components[1:])


class ContractModel(BaseModel):
    """Base for all contract models. Serializes to camelCase."""
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
    )


class Priority(int, Enum):
    CRITICAL = 0
    HIGH = 1
    MEDIUM = 2
    LOW = 3
    BACKLOG = 4


class WorkItem(ContractModel):
    id: str = Field(pattern=r'^wi-[a-f0-9]{4,8}$')
    title: str = Field(min_length=1, max_length=200)
    status: Literal['open', 'active', 'blocked', 'resolved', 'closed']
    priority: Priority
    type: Literal['bug', 'feature', 'task', 'chore', 'spike']
    assignee: Optional[str] = None
    labels: List[str] = []
    created_at: datetime
    updated_at: datetime
```

The `ContractModel` base class is critical. Without it, Python uses snake_case internally but the API wire format uses camelCase, and the two sides disagree on field names. The alias generator resolves this: `created_at` in Python becomes `createdAt` on the wire.

### JSON Schema

Language-agnostic contract format for data validation. Used for config file schemas, message queue payloads, and inter-service contracts where neither side is TypeScript or Python.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "QA Report",
  "type": "object",
  "required": ["work_item_id", "scores", "verdict"],
  "properties": {
    "work_item_id": {
      "type": "string",
      "pattern": "^wi-[a-f0-9]{4,8}$"
    },
    "scores": {
      "type": "object",
      "required": ["contract_conformance", "security"],
      "properties": {
        "contract_conformance": {
          "type": "integer", "minimum": 1, "maximum": 5
        },
        "security": {
          "type": "integer", "minimum": 1, "maximum": 5
        },
        "correctness": {
          "type": "integer", "minimum": 1, "maximum": 5
        },
        "completeness": {
          "type": "integer", "minimum": 1, "maximum": 5
        },
        "code_quality": {
          "type": "integer", "minimum": 1, "maximum": 5
        }
      }
    },
    "verdict": {
      "type": "string",
      "enum": ["PASS", "FAIL", "PARTIAL", "BLOCKED"]
    },
    "findings": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["severity", "description"],
        "properties": {
          "severity": {
            "type": "string",
            "enum": ["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"]
          },
          "contract_clause": { "type": "string" },
          "description": { "type": "string" },
          "file": { "type": "string" },
          "line": { "type": "integer" }
        }
      }
    }
  }
}
```

### Data Layer Contracts

A custom YAML format for the interface between API handlers and the persistence layer. Declares function signatures, return types, storage semantics, cascade behavior, and transaction boundaries.

```yaml
version: "1.0.0"

storage:
  engine: "postgres"
  id_strategy: "uuid-v4"
  timestamp_owner: "data-layer"
  connection_env_var: "DATABASE_URL"

functions:
  - name: createUser
    description: "Create a new user"
    params:
      - name: email
        type: string
        constraints: "format=email, unique"
      - name: passwordHash
        type: string
    returns: User
    side_effects:
      - "inserts users row"
      - "sets created_at and updated_at to now()"
    errors:
      - condition: "email already exists"
        raises: "ConflictError"

  - name: getUserByEmail
    description: "Retrieve a user by email address"
    params:
      - name: email
        type: string
    returns: "User | null"
    side_effects: []
    errors: []

transactions:
  - name: "deleteUser cascade"
    operations: ["delete sessions by user_id", "delete user"]
    isolation: "read-committed"

indexes:
  - table: users
    columns: [email]
    type: btree
    unique: true
    purpose: "Unique lookup by email"
```

The data layer contract prevents a common class of integration failure: the API handler assumes `getUserByEmail` returns a promise, but the implementation returns a synchronous result. Or the handler assumes deletion cascades to sessions, but the implementation does not. The contract makes these semantics explicit.

---

## 3. Contract Lifecycle

Contracts move through six stages. Each stage has a defined input, output, responsible agent, and timing within the build lifecycle.

```
Phase 1: AUTHOR ──> Phase 2: REVIEW ──> Phase 3: DISTRIBUTE
    │                   │                    │
    │                   │                    │
    v                   v                    v
Generate contracts   Validate for        Share with
from requirements    completeness        implementing agents
                     and consistency

Phase 4: IMPLEMENT ──> Phase 5: AUDIT ──> Phase 6: ENFORCE
    │                      │                   │
    │                      │                   │
    v                      v                   v
Agents build to         Verify code         Block non-conforming
contract spec           matches contracts    merges via QA gate
```

### Phase 1: Author

**Input:** Requirements document, existing codebase context, project profile.
**Output:** Contract files in `contracts/` directory.
**Agent:** contract-author.
**Timing:** Before any implementation agent is spawned.

The contract-author analyzes requirements and generates:

1. Shared types file (`contracts/types.[ts|py|json]`)
2. API contract (`contracts/openapi.yaml`)
3. Data layer contract (`contracts/data-layer.yaml`)
4. Event contract (`contracts/asyncapi.yaml`) -- if applicable
5. Contract README (`contracts/README.md`) -- conventions, ownership map, domain rules

The contract-author extracts entities, relationships, actions, and domain rules from the requirements. It generates types first -- everything else references them. It assigns cross-cutting concerns to exactly one agent. It right-sizes complexity to the project scope.

### Phase 2: Review

**Input:** Contract files from Phase 1.
**Output:** Validated contract set or revision requests.
**Agent:** Coordinator (with contract-auditor assistance).
**Timing:** Before distribution.

Validation checks:

- All endpoints have complete request/response schemas (no prose descriptions)
- All error cases are covered with the standard error envelope
- Shared types are referenced, not duplicated
- File ownership declarations do not overlap across agents
- Contracts are internally consistent (OpenAPI schemas match TypeScript interfaces match Pydantic models)
- Complexity matches project scope (no JWT auth for a SQLite personal tool)

### Phase 3: Distribute

**Input:** Validated contract set.
**Output:** Contracts loaded into implementing agents' context.
**Agent:** Coordinator and leads.
**Timing:** At agent spawn time (Layer 3 dynamic overlay).

Each implementing agent receives the relevant subset of contracts:

- Backend builder receives: OpenAPI spec, data layer contract, shared types
- Frontend builder receives: OpenAPI spec, shared types
- DB migration builder receives: data layer contract, shared types
- Infrastructure builder receives: AsyncAPI spec (if applicable)

Contracts are loaded as part of the dynamic overlay (`prime` command). The agent sees: "These are the interfaces you must implement."

### Phase 4: Implement

**Input:** Contracts + work item assignment.
**Output:** Implementation code conforming to contracts.
**Agent:** Domain builders (backend, frontend, db-migration, etc.).
**Timing:** Main build phase.

Builders reference contracts as their acceptance criteria. The backend builder does not invent endpoint paths -- it reads them from `openapi.yaml`. The frontend builder does not guess response shapes -- it reads them from the shared types file. Both sides build to the same specification.

### Phase 5: Audit

**Input:** Implementation code + original contracts.
**Output:** Audit report with pass/fail per contract clause.
**Agent:** contract-auditor.
**Timing:** After implementation agents report done, before QE integration testing.

The contract-auditor performs static analysis -- it reads code and contracts without running the application. Automated checks include:

- Schema validation: do implemented types match contract types?
- Endpoint coverage: does every contracted endpoint have a handler?
- Response format: do API responses match contracted schemas?
- Type compatibility: are function signatures consistent with interfaces?
- Cross-agent consistency: does frontend call the same URLs the backend exposes?
- Domain rule enforcement: are business invariants checked in code?
- Contract internal consistency: do the contracts themselves agree with each other?

### Phase 6: Enforce

**Input:** Audit report + QA report.
**Output:** Merge allowed or blocked.
**Agent:** QA gate (automated) + coordinator (override authority).
**Timing:** Pre-merge pipeline.

Enforcement rules:

- `contract_conformance` score < 3 --> merge blocked
- Any CRITICAL contract violation --> immediate block
- `security` score < 3 --> merge blocked
- All blockers with category `contract_violation` must be resolved

The merge system's pre-merge pipeline (documented in `07-merge-system.md`) runs the contract conformance check before any merge attempt. Non-conforming branches cannot land on canonical.

---

## 4. File Ownership System

File ownership is the companion to contracts. Contracts define what interfaces look like. Ownership defines who is responsible for implementing them. Together, they ensure that integration surfaces are specified and that each side of the surface has exactly one responsible builder.

### Declaration

Ownership is declared in skill frontmatter:

```yaml
# In backend-builder SKILL.md
owns:
  directories:
    - src/api/auth/
    - src/services/auth/
    - src/models/
  files:
    - src/routes/auth.ts
  patterns:
    - "src/**/*.controller.ts"
    - "src/**/*.service.ts"
    - "tests/api/**/*"
  shared_read:
    - contracts/
    - shared/
    - src/types/
```

### Ownership Scope Types

| Scope | Meaning | Example |
|-------|---------|---------|
| `directories` | Exclusive write access to all files in the directory tree | `src/api/auth/` -- agent owns everything under this path |
| `files` | Exclusive write access to specific files | `src/routes/auth.ts` -- only this file |
| `patterns` | Exclusive write access to files matching glob patterns | `src/**/*.controller.ts` -- all controller files |
| `shared_read` | Read-only access to directories owned by other agents or no agent | `contracts/` -- can read but not modify |

### Enforcement Points

Ownership is enforced at four points in the build lifecycle:

**At spawn time:** The coordinator validates that the new agent's ownership claims do not overlap with any currently active agent. If two skills claim the same directory, the spawn is rejected with a specific conflict report. The coordinator resolves the conflict -- by splitting the directory, assigning priority, or sequencing the agents -- before retrying the spawn.

**At edit time:** Guard rules prevent writing outside owned scope. A backend builder's Write and Edit tools are constrained to paths matching its `owns.directories`, `owns.files`, and `owns.patterns`. Attempts to write outside scope are rejected by the platform runtime, not by prompt instructions.

**At audit time:** The contract-auditor verifies that all changes in an agent's branch are within that agent's declared scope. Files modified outside scope are flagged as ownership violations.

**At merge time:** The merge system's pre-merge pipeline includes an ownership check. Changes to files not owned by the submitting agent are rejected. This is the final enforcement gate.

### Ownership Resolution Rules

When ownership is ambiguous, the platform resolves using these rules in priority order:

**Rule 1: Directory ownership takes precedence over pattern ownership.** If a file matches agent A's glob pattern but lives inside agent B's owned directory, agent B owns it. Example: `src/api/routes.test.ts` matches the QA agent's `*.test.*` pattern but lives in the backend builder's `src/api/` directory. The backend builder owns it.

**Rule 2: More specific paths override less specific paths.** A subdirectory carve-out overrides the parent. Example: the db-migration builder owns `src/models/migrations/` even though the backend builder owns `src/models/`. The migration directory is carved out explicitly.

**Rule 3: Shared files are assigned to the coordinator or lead.** Files that multiple agents need to modify -- `package.json`, `tsconfig.json`, `platform.config.yaml` -- are not owned by any builder. They are owned by the coordinator or lead, who can delegate specific modifications through the work item system.

**Rule 4: Unresolvable conflicts escalate to the operator.** If rules 1-3 cannot resolve an ownership conflict, the coordinator escalates to the human operator. This is rare -- it indicates a structural problem in the project layout that should be fixed, not worked around.

### Ownership Map

The platform maintains a global ownership map -- a lookup from file path to owning skill. This map is computed at startup from all registered skill frontmatters and updated when agents are spawned or retired.

```typescript
interface OwnershipMap {
  byDirectory: Map<string, string>;    // directory path -> skill name
  byFile: Map<string, string>;         // file path -> skill name
  byPattern: Map<string, string>;      // glob pattern -> skill name
  sharedRead: Map<string, string[]>;   // directory -> skills with read access

  resolve(filePath: string): string | null;  // returns owning skill or null
  checkOverlap(claim: OwnershipClaim): OverlapResult[];
}
```

The `resolve()` method applies the precedence rules to determine the owner of any given file path. The `checkOverlap()` method validates a new ownership claim against all existing claims before a spawn is approved.

---

## 5. Contract Authoring Process

### Input Requirements

The contract-author accepts requirements in multiple forms:

- Natural language requirements document
- Structured plan from the orchestrator
- Existing codebase (for extracting implicit contracts from running code)
- Domain model diagrams

### Entity Extraction

Before writing any contract, the contract-author extracts:

- **Domain entities** -- nouns representing stored data (User, Product, Order)
- **Relationships** -- which entities reference which (Order contains OrderItems, each referencing a Product)
- **Actions** -- verbs becoming endpoints (create, search, checkout, upload)
- **Domain rules** -- business logic crossing agent boundaries ("sellers cannot buy their own listings", "stock decrements atomically at checkout")
- **Integration points** -- external services needing contract coverage (Stripe, S3, Redis)

This extraction step prevents missing entities that surface only during implementation.

### Authoring Sequence

```
Step 1: Shared types (always first -- everything references them)
        → Pick format: TypeScript | Pydantic | JSON Schema
        → Define every entity, enum, request shape, response shape
        → Define error envelope
        → Use strongest available type annotations

Step 2: API contract (OpenAPI 3.1)
        → Method + path for every endpoint (exact, including trailing slash)
        → Request body with exact JSON shape
        → Success response with status code and shape
        → Error responses with every possible status code
        → SSE/streaming event shapes (if applicable)
        → Standard sections: conventions, error envelope, CORS

Step 3: Data layer contract
        → Function signatures with param types
        → Return types
        → Storage semantics (accumulated vs per-chunk)
        → Cascade delete behavior
        → Timestamp ownership (caller vs data layer vs DB)
        → ID generation strategy
        → Required indexes and transaction boundaries

Step 4: Event contract (if applicable)
        → Channel/topic names
        → Message schemas with headers and payload
        → Delivery guarantees
        → Error handling semantics

Step 5: Cross-cutting concern assignment
        → URL conventions → backend
        → Response envelope → backend
        → Error format → backend
        → CORS configuration → backend
        → Accessibility → frontend
        → Project-specific concerns assigned to one agent each

Step 6: Domain business rules documentation
        → Invariants
        → Transaction semantics
        → Idempotency requirements
        → State machine transitions

Step 7: File ownership boundaries
        → Per-agent directory/file/pattern ownership
        → Shared-read declarations
        → Table format in contracts/README.md

Step 8: Per-agent implementation notes
        → Libraries and frameworks for contract compliance
        → How to import shared types
        → Agent-specific patterns
```

### Quality Checklist

Every contract set must pass before distribution:

- URLs are exact (method + path, no ambiguity)
- Response shapes are explicit JSON, not prose descriptions
- All status codes specified (success AND every error case)
- SSE event types have exact JSON shapes
- Storage semantics are explicit (accumulated vs per-chunk, cascade behavior)
- Shared types defined once and referenced everywhere (no duplication)
- Trailing slash convention stated
- Error envelope defined and used by all error responses
- Cross-cutting concerns each assigned to exactly one agent
- CORS origin specified
- Every contract file versioned (start at v1)
- Domain business rules documented
- File ownership boundaries defined for each agent
- Per-agent implementation notes included
- Field names consistent across ALL contract files (types, OpenAPI, data layer)
- Complexity matches project scope

### Right-Sizing

The contract-author matches complexity to the project. Questions to ask:

| Question | If No | Contract Impact |
|----------|-------|----------------|
| Does this project need auth? | Omit security schemes entirely | No JWT, no bearer tokens |
| Is there a real-time component? | Skip AsyncAPI | No event contracts |
| How many entities? | 2-entity projects get simpler data layer | Fewer functions, simpler indexes |
| What DB? | SQLite uses auto-increment IDs | No UUIDs, simpler storage semantics |
| Multiple consumers? | No Pact testing needed | Static auditing suffices |

Over-engineered contracts waste agent time implementing unnecessary complexity.

---

## 6. Contract Auditing Process

### Audit Scope

The contract-auditor performs static analysis -- reading code and contracts without running the application. It operates after implementation agents report done but before the QE agent begins integration testing.

### Audit Checks

**Backend vs API Contract:**

For each endpoint in `openapi.yaml`:
- Route path matches contract exactly (including trailing slash convention)
- HTTP method matches
- Request body parsing matches contracted shape (field names, types, required fields)
- Response shape matches (field names, types, nesting)
- Status codes match for success and all error cases
- Error responses use the contracted error envelope

**Frontend vs API Contract:**

For each API call in the frontend:
- URL matches contracted endpoint exactly
- HTTP method matches
- Request body shape matches
- Response destructuring matches contracted shape
- Error handling covers contracted error cases

**Backend vs Frontend Cross-Check:**

The most critical audit -- verifying the two sides agree:
- Backend route path vs frontend fetch URL
- Backend response shape vs frontend parsing logic
- Backend error codes vs frontend error handling
- Backend Content-Type vs frontend headers

**Data Layer Conformance:**

- Exported function names match contract
- Parameter types match
- Return types match
- Storage semantics match (accumulated vs per-chunk, cascade behavior)

**Shared Types Conformance:**

- Backend models match `contracts/types`
- Frontend types match `contracts/types`
- No camelCase vs snake_case mismatches (unless a documented transform exists)
- Enum values identical on both sides
- Shared types are actually imported and used (not manually reconstructed)

**Domain Rules Conformance:**

- Invariants are enforced in code (e.g., "sellers cannot buy their own listings" -- is the check present?)
- Null handling is correct (nullable fields can be set to null via PATCH, absent keys are not conflated with explicit null)
- Transaction semantics are implemented (atomic operations wrapped in transactions)
- Idempotency requirements are met

**Contract Internal Consistency:**

- README does not contradict the shared types file
- OpenAPI response shapes match shared type definitions
- Every OpenAPI endpoint is covered by the data layer contract
- No error codes in implementation are undefined in the contract

### Scoring Rubric

| Score | Meaning | Criteria |
|-------|---------|---------|
| 5 | Full conformance | Every contract clause implemented correctly. All endpoints match. All types align. All error cases handled. No deviations. |
| 4 | Minor deviations | Small differences that do not affect integration. Example: an optional field is present but unused, or response includes extra informational fields not in the contract. |
| 3 | Partial conformance | Some interfaces differ, but core functionality matches. Integration will work for the happy path but may fail on edge cases. Example: error responses use the right envelope but are missing some contracted error codes. |
| 2 | Significant deviation | Major interface mismatches. Integration will fail for common cases. Example: field names differ between frontend and backend, or request body shape does not match. |
| 1 | Non-conformant | Implementation ignores contracts. Endpoints have different paths, response shapes are unrelated to contracted schemas, or shared types are not used at all. |

### Severity Classification

| Severity | Definition | Example |
|----------|-----------|---------|
| CRITICAL | Will cause runtime integration failure | Wrong field name on the wire, missing endpoint, broken error envelope |
| HIGH | Will cause edge-case failures | Null handling bug, missing error status code, validation gap |
| MEDIUM | Contract drift risk | Shared types not imported (manual dict construction), undocumented behavior |
| LOW | Style or naming inconsistency with no functional impact | Extra whitespace in response, non-standard date format that still parses |

### Audit Report Format

```markdown
# Contract Audit Report
Generated: 2026-03-18T14:30:00Z
Contract Set: auth-api-v1.0.0

## Summary
| Area              | Matches | Mismatches | Not Checked |
|-------------------|---------|------------|-------------|
| API endpoints     | 7       | 1          | 0           |
| Frontend calls    | 6       | 1          | 1           |
| Data layer        | 5       | 0          | 0           |
| Shared types      | 12      | 0          | 0           |
| Domain rules      | 3       | 0          | 1           |
| Cross-agent       | 6       | 1          | 0           |

## Conformance Score: 4/5
## Verdict: PASS (with warnings)

## Mismatches
### MISMATCH-1: POST /auth/login error response
- **Contract says:** 401 response includes `code` field in error envelope
- **Implementation does:** Returns `{error: "Invalid credentials"}` without `code`
- **Agent responsible:** backend-builder
- **File:** src/api/auth/login.ts:45
- **Severity:** HIGH

### MISMATCH-2: Frontend error handling for /auth/login
- **Contract says:** Handle 401 and 422 errors distinctly
- **Implementation does:** Catches all errors with generic handler
- **Agent responsible:** frontend-builder
- **File:** src/components/LoginForm.tsx:82
- **Severity:** MEDIUM

### MISMATCH-3: Token expiry format
- **Contract says:** `expiresAt` is ISO 8601 datetime
- **Implementation does:** Returns Unix timestamp (integer)
- **Agent responsible:** backend-builder
- **File:** src/services/auth/token.ts:23
- **Severity:** CRITICAL
- **Note:** Frontend parses as string, will fail at runtime

## Verified Matches
[List of all 39 verified contract clauses that match]
```

---

## 7. Contract Versioning

### Version Scheme

Contracts use semantic versioning (MAJOR.MINOR.PATCH):

| Component | Meaning | Example |
|-----------|---------|---------|
| MAJOR | Breaking interface change -- field removed, type changed, endpoint path altered | 1.0.0 to 2.0.0 |
| MINOR | Additive change -- new endpoint, new optional field, new enum value | 1.0.0 to 1.1.0 |
| PATCH | Documentation or constraint fix -- corrected description, tightened validation, fixed example | 1.0.0 to 1.0.1 |

### Version Lifecycle

```
v1.0.0   Initial contract authored before implementation
v1.0.1   Fixed typo in error code enum
v1.1.0   Added GET /auth/me endpoint (additive)
v1.1.1   Clarified CORS policy in README
v2.0.0   Changed token format from JWT to opaque token (breaking)
```

### Breaking Change Protocol

Breaking changes (MAJOR version bumps) require:

1. **Changelog entry** -- what changed and why
2. **Migration guide** -- how implementing agents must update their code
3. **Notification** -- all implementing agents receive a mail message with the specific change description
4. **Acknowledgment** -- each affected agent confirms receipt before continuing
5. **Re-audit** -- the contract-auditor re-runs against all affected implementations after they update

### Contract Diff

The platform provides tooling to compare contract versions:

```bash
platform contract diff auth-api v1.1.0 v2.0.0
```

Output highlights:
- Added endpoints (green)
- Removed endpoints (red)
- Modified schemas (yellow with field-level diff)
- Changed constraints (blue)

### Storage

Contracts live in the `contracts/` directory of the project repository. They are version-controlled in git alongside the code they specify. The contract-author is the only agent with write access to `contracts/`; all other agents have shared-read access. This prevents implementation agents from unilaterally modifying their own contracts -- contract changes flow through the contract-author and require coordinator approval.

---

## 8. Contract-Quality Integration

### How Contracts Feed the QA Gate

The QA report schema includes a `contract_conformance` score (1-5) as one of five required dimensions. The gate decision logic blocks the build when `contract_conformance.score < 3` or when any blocker has category `contract_violation`.

```json
{
  "contract_audit": {
    "contract_id": "auth-api-v1.0.0",
    "coverage": {
      "endpoints_covered": 8,
      "endpoints_total": 8,
      "schemas_valid": 12,
      "schemas_total": 12,
      "types_compatible": 15,
      "types_total": 16
    },
    "findings": [
      {
        "severity": "CRITICAL",
        "contract_clause": "paths./auth/login.post.responses.200",
        "description": "Token expiresAt returns Unix timestamp instead of ISO 8601 datetime",
        "file": "src/services/auth/token.ts",
        "line": 23
      },
      {
        "severity": "WARNING",
        "contract_clause": "paths./auth/login.post.responses.401",
        "description": "Error response missing 'code' field in envelope",
        "file": "src/api/auth/login.ts",
        "line": 45
      }
    ],
    "score": 3,
    "verdict": "PASS"
  }
}
```

### Gate Decision Matrix

| Condition | Gate Decision | Rationale |
|-----------|--------------|-----------|
| Score 5, no findings | PASS | Full conformance |
| Score 4, warnings only | PASS | Minor deviations, integration will work |
| Score 3, no CRITICAL findings | PASS (with warnings) | Partial conformance, core integration works |
| Score 3, has CRITICAL findings | FAIL | Critical findings override the score |
| Score 2 or lower | FAIL | Integration will break |
| Any blocker with category `contract_violation` | FAIL | Explicit contract violation cannot be merged |

### Audit-QE Handoff

The contract-auditor and QE agent have complementary roles:

- **Contract-auditor**: static verification (reads code against contracts, does not run the application)
- **QE agent**: runtime verification (executes requests, compares actual responses to expected)

The contract-auditor runs first. Its audit report feeds into the QE agent's Phase 1. If the auditor finds CRITICAL mismatches, it reports them immediately -- the QE agent should not waste time integration-testing broken interfaces.

---

## 9. Cross-Agent Contract Coordination

### The Shared Reference Pattern

When multiple agents implement complementary sides of the same interface, all reference the same contract. The contract is the single source of truth that both sides agree on.

```
Example: User Authentication Feature

  Contract: contracts/openapi.yaml (auth endpoints)
            contracts/types.ts (shared types)
            contracts/data-layer.yaml (persistence interface)

  Backend builder:
    - Reads openapi.yaml → implements POST /auth/login handler
    - Reads data-layer.yaml → implements createUser(), getUserByEmail()
    - Reads types.ts → imports LoginRequest, AuthToken types

  Frontend builder:
    - Reads openapi.yaml → implements login form that calls POST /auth/login
    - Reads types.ts → imports LoginRequest, AuthToken for type safety
    - Reads error envelope → implements error handling for 401, 422

  DB migration builder:
    - Reads data-layer.yaml → creates users table with correct columns
    - Reads types.ts → ensures column types match entity definitions
    - Reads indexes section → creates required indexes

  Contract auditor:
    - Verifies backend handler matches openapi.yaml
    - Verifies frontend calls match openapi.yaml
    - Verifies backend and frontend agree with each other
    - Verifies data layer implementation matches data-layer.yaml

  Integration test:
    - Frontend calls backend → response matches contracted shape
    - Backend queries data layer → results match contracted types
    - All three layers work together because all three built to spec
```

### Naming Convention Coordination

When the API uses camelCase (TypeScript/JSON) but the backend uses snake_case (Python), the naming transform must be documented and enforced:

```markdown
## Naming Convention (from contracts/README.md)

| Python Field     | Wire (JSON) Field | Used By          |
|------------------|--------------------|------------------|
| created_at       | createdAt          | Backend, Frontend |
| session_id       | sessionId          | Backend, Frontend |
| message_id       | messageId          | Backend, Frontend |
| full_content     | fullContent        | Backend, Frontend |

Transform: Pydantic alias_generator=to_camel (automatic)
Frontend: receives camelCase natively (no transform needed)
```

Both sides must agree on the wire format. The Pydantic `ContractModel` base class handles the transform automatically. The frontend receives camelCase and uses it directly.

---

## 10. CLI Commands

### Authoring

```bash
# Generate contracts from a requirements document
platform contract author requirements.md

# Generate contracts with a specific primary type
platform contract author requirements.md \
  --type openapi \
  --type typescript \
  --type data-layer

# Generate a blank contract template
platform contract template openapi       # OpenAPI 3.1 starter
platform contract template asyncapi      # AsyncAPI 3.0 starter
platform contract template typescript    # TypeScript interfaces starter
platform contract template pydantic      # Pydantic models starter
platform contract template json-schema   # JSON Schema starter
platform contract template data-layer    # Data layer interface starter
```

### Inspection

```bash
# List all contracts in the project
platform contract list
# Output:
# ID                TYPE        VERSION   FILES
# auth-api          openapi     1.0.0     contracts/openapi.yaml
# auth-types        typescript  1.0.0     contracts/types.ts
# auth-data         data-layer  1.0.0     contracts/data-layer.yaml
# agent-events      asyncapi    1.0.0     contracts/asyncapi.yaml

# Show details of a specific contract
platform contract show auth-api
# Output: renders the OpenAPI spec with endpoint summary

# Diff two versions of a contract
platform contract diff auth-api v1.0.0 v2.0.0
# Output: field-level diff with added/removed/modified highlighting
```

### Auditing

```bash
# Audit a specific contract against its implementation
platform contract audit auth-api --implementation src/api/auth/

# Audit all contracts in the project
platform contract audit --all

# Audit with verbose output (show verified matches too)
platform contract audit --all --verbose

# Audit and output machine-readable report
platform contract audit --all --format json > audit-report.json
```

### Ownership

```bash
# Show the global file ownership map
platform contract ownership map
# Output:
# PATH                        OWNER              TYPE
# src/api/auth/               backend-builder    directory
# src/api/auth/login.ts       backend-builder    directory (inherited)
# src/components/LoginForm.tsx frontend-builder   directory
# contracts/                  contract-author    directory
# package.json                coordinator        shared

# Check for ownership overlaps
platform contract ownership check
# Output:
# OK: No ownership overlaps detected
# -- or --
# CONFLICT: src/api/types.ts claimed by both backend-builder (pattern)
#           and frontend-builder (pattern). Resolve before spawning.

# Show ownership for a specific file
platform contract ownership resolve src/api/auth/login.test.ts
# Output:
# Owner: backend-builder (via directory: src/api/auth/)
# Note: Also matches qe-agent pattern *.test.ts, but directory
#       ownership takes precedence (Rule 1)
```

### Validation

```bash
# Validate contract set for internal consistency
platform contract validate
# Output:
# Checking OpenAPI schemas against TypeScript types... OK
# Checking data layer functions against OpenAPI endpoints... OK
# Checking field naming consistency... WARNING: 'userId' in types.ts
#   vs 'user_id' in data-layer.yaml (transform documented: OK)
# Checking ownership boundaries... OK
# Result: VALID (1 warning)
```

---

## 11. Design Decisions and Rationale

### Why Five Contract Types, Not One

**Decision:** Support OpenAPI, AsyncAPI, TypeScript, Pydantic, and JSON Schema rather than a single universal format.

**Rationale:** Each format has a natural ecosystem. OpenAPI integrates with Swagger UI, code generators, and API gateways. TypeScript interfaces integrate with the TypeScript compiler's type checking. Pydantic models integrate with FastAPI's automatic validation. JSON Schema integrates with validators in every language. A single universal format would require translation layers that add complexity without adding value. Projects use the subset that matches their stack.

### Why Static Auditing Before Runtime Testing

**Decision:** The contract-auditor performs static analysis (reading code) before the QE agent performs runtime testing (executing requests).

**Rationale:** Static auditing is fast (seconds), cheap (no infrastructure), and catches obvious mismatches -- wrong field names, missing endpoints, type mismatches. Runtime testing is slow (minutes), expensive (requires running services), and catches behavioral issues -- incorrect logic, race conditions, edge cases. Running static auditing first prevents the QE agent from wasting time integration-testing interfaces that are structurally broken.

### Why Exclusive Contract Ownership

**Decision:** Only the contract-author can write to `contracts/`. All other agents have read-only access.

**Rationale:** If implementing agents could modify their own contracts, they would. An agent that finds its implementation does not match the contract has two options: fix the implementation or fix the contract. The second option is easier but defeats the purpose of contracts. By making contracts read-only to builders, the platform ensures that contract deviations are caught, not silently papered over. Contract changes require explicit action through the contract-author and coordinator approval.

### Why Contract Conformance Score, Not Pass/Fail

**Decision:** A 1-5 score with configurable threshold, not a binary pass/fail.

**Rationale:** Real implementations exist on a spectrum. A score of 4 (minor deviations) is acceptable for merging -- the interface works, integration will succeed, and minor cleanup can happen later. A binary pass/fail would block merges for trivial deviations (an extra optional field in a response, a slightly different error message) that have no integration impact. The threshold (default: 3) lets projects configure their tolerance.

### Why Right-Sizing Is Explicit

**Decision:** The contract-author is instructed to ask scope questions and omit unnecessary complexity.

**Rationale:** Over-engineered contracts are as harmful as absent contracts. A personal habit tracker with SQLite does not need JWT auth schemas, AsyncAPI specs, or elaborate CORS contracts. When an agent receives a contract for JWT auth, it implements JWT auth -- even if the project only needs a cookie. Right-sizing is an explicit step in the authoring process to prevent complexity inflation.

---

## 12. Relationship to Other Subsystems

| Subsystem | Contract System Interaction |
|-----------|-----------------------------|
| **Skill System** (`08-skill-system.md`) | Skills declare `owns.directories` and `shared_read` in frontmatter. The contract system uses these declarations to build the ownership map and enforce file boundaries. Contracts are loaded as part of Layer 3 (dynamic overlay) at agent spawn time. |
| **Merge System** (`07-merge-system.md`) | The pre-merge pipeline runs contract conformance checks before any merge attempt. Non-conforming branches are rejected. Contract files themselves use `merge=theirs` in `.gitattributes` -- agents cannot merge contract changes through builder branches. |
| **Quality Intelligence** (`10-quality-intelligence.md`) | The QA report includes `contract_conformance` as a required score dimension. The gate blocks builds when the score falls below 3 or when CRITICAL contract violations exist. The contract-auditor's report feeds directly into the QE agent's testing plan. |
| **Orchestration Engine** (`09-orchestration-engine.md`) | The coordinator spawns the contract-author in Phase 4 (before implementation). It distributes contracts to builders via the `prime` command. It enforces the contract-first constraint: no builder is spawned until contracts are validated. |
| **Communication Model** (`06-communication-model.md`) | Contract version changes trigger mail notifications to all affected agents. Breaking changes require acknowledgment before agents continue. The contract-auditor sends audit reports via the mail protocol. |
| **Role Taxonomy** (`04-role-taxonomy.md`) | The contract-author role is a specialized builder. The contract-auditor role is a specialized reviewer. Both follow the role hierarchy: spawned by coordinator or lead, composed with domain builders and QE agents. |

---

## Source Material

| Source | Location | Relevance |
|--------|----------|-----------|
| ATSA contract-author skill | `skills/contracts/contract-author/SKILL.md` | Authoring process, quality checklist, right-sizing, entity extraction, cross-cutting concerns, naming conventions |
| ATSA contract-auditor skill | `skills/contracts/contract-auditor/SKILL.md` | Audit process, severity guidelines, backend/frontend cross-check, domain rules conformance, coordination rules |
| ATSA contract templates | `skills/contracts/contract-author/references/` | OpenAPI, AsyncAPI, TypeScript, Pydantic, JSON Schema, and data layer templates |
| ATSA QA report schema | `skills/roles/qe-agent/references/qa-report-schema.json` | Score dimensions, gate rules, blocker categories |
| ATSA Pact testing guide | `skills/contracts/contract-auditor/references/pact-setup.md` | Consumer-driven contract testing patterns |
| Gas Town formulas | `gastown_deepdive/` | TOML formula acceptance criteria as implicit contracts |
| Overstory guard rules | `overstory_deepdive/` | Tool restrictions and path boundaries as behavioral contracts |
| Merge system spec | `07-merge-system.md` | Pre-merge contract conformance check, `.gitattributes` contract protection |
| Skill system spec | `08-skill-system.md` | File ownership declaration, composition validation, guard rule enforcement |

---

*This document specifies the contract-first architecture, authoring and auditing processes, file ownership enforcement, and quality integration. The merge system that enforces contracts at merge time is specified in `07-merge-system.md`. The quality gate that uses contract conformance scores is specified in `10-quality-intelligence.md`. The orchestration engine that coordinates contract timing within the build lifecycle is specified in `09-orchestration-engine.md`.*
