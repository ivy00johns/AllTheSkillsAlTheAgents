# Contract Templates

Reusable templates for integration contracts. The lead copies the relevant template, fills in the project-specific details, and hands it to agents.

These are starting points, not rigid formats. Adapt to the project's needs — but always include the marked **[REQUIRED]** sections. Optional sections can be removed if they don't apply.

---

## API Contract Template

Use for defining the interface between a backend (or any HTTP service) and its consumers.

```markdown
## [Service Name] → [Consumer Name] API Contract (v1)

### Conventions [REQUIRED]
- Base URL: [e.g., /api/v1]
- Trailing slashes: [YES | NO] on endpoints
- Content-Type: application/json (all requests and responses)
- Date format: [ISO 8601 | Unix timestamp | other]
- ID format: [UUID v4 | auto-increment integer | CUID | ULID]

### Authentication [if applicable]
- Method: [Bearer token | API key | Session cookie | None]
- Header: [e.g., Authorization: Bearer <token>]
- Unauthenticated response: [status code + body]

### Endpoints [REQUIRED]

[Repeat this block for each endpoint]

[METHOD] [path]
  Description: [what this endpoint does]
  Request body: [exact JSON shape, or "none"]
  Request params: [path params, query params, or "none"]
  Response [success status]: [exact JSON shape]
  Response [error status]:   [exact JSON shape]
  Response [another error]:  [exact JSON shape if different]
  Notes: [rate limits, pagination, side effects, etc.]

#### Example:

POST /api/v1/sessions
  Description: Create a new session
  Request body:  { "title": "string (required, 1-200 chars)" }
  Response 201:  { "id": "uuid", "title": "string", "createdAt": "iso8601" }
  Response 422:  { "error": "string", "code": "VALIDATION_ERROR", "details": [{"field": "title", "message": "string"}] }

GET /api/v1/sessions/{sessionId}/messages
  Description: List messages in a session
  Request params: sessionId (path, UUID)
  Query params: limit (optional, int, default 50), offset (optional, int, default 0)
  Response 200:  { "messages": [{ "id": "uuid", "role": "user"|"assistant", "content": "string", "createdAt": "iso8601" }], "total": "int" }
  Response 404:  { "error": "Session not found", "code": "NOT_FOUND", "details": [] }

### SSE/Streaming Endpoints [if applicable]

[METHOD] [path]
  Description: [what this stream does]
  Request body: [if any]
  Event types:
    event: [name]    data: [exact JSON shape]
    event: [name]    data: [exact JSON shape]
    event: [name]    data: [exact JSON shape]
  Connection close: [when/how the stream ends]
  Error during stream: [exact event format]

#### Example:

POST /api/v1/sessions/{sessionId}/stream
  Description: Stream an assistant response
  Request body:  { "message": "string" }
  Event types:
    event: chunk    data: { "content": "string" }
    event: done     data: { "messageId": "uuid", "fullContent": "string" }
    event: error    data: { "error": "string", "code": "string" }
  Connection close: Server sends "done" or "error" event, then closes
  Error during stream: Send error event, then close connection

### Error Envelope [REQUIRED]
All error responses use this shape:
{ "error": "human-readable message", "code": "MACHINE_READABLE_CODE", "details": [...] }

Common codes:
- VALIDATION_ERROR (422) — invalid input
- NOT_FOUND (404) — resource doesn't exist
- UNAUTHORIZED (401) — missing or invalid auth
- FORBIDDEN (403) — valid auth but insufficient permissions
- INTERNAL_ERROR (500) — unexpected server error
- RATE_LIMITED (429) — too many requests

### Pagination [if applicable]
- Method: [offset-based | cursor-based]
- Default page size: [N]
- Max page size: [N]
- Response shape: { "items": [...], "total": N, "offset": N, "limit": N }
  OR: { "items": [...], "nextCursor": "string | null" }

### CORS [REQUIRED for browser consumers]
- Allowed origin: [e.g., http://localhost:5173]
- Allowed methods: [e.g., GET, POST, PUT, DELETE, OPTIONS]
- Allowed headers: [e.g., Content-Type, Authorization]
```

---

## Data Layer Contract Template

Use for defining the interface between the data layer and its consumer (typically the backend business logic).

```markdown
## Data Layer Contract (v1)

### Models [REQUIRED]
[Reference the shared types file]
See: contracts/types.[ts|py|json]

### Function Signatures [REQUIRED]

[Repeat for each function]

[functionName]([params with types]): [return type]
  Description: [what it does]
  Throws/Raises: [error conditions]
  Side effects: [if any]

#### Example:

createSession(title: string, userId: string): Promise<Session>
  Description: Create a new session record
  Throws: ValidationError if title is empty
  Side effects: Sets createdAt and updatedAt to current time

getSession(sessionId: string): Promise<Session | null>
  Description: Retrieve a session by ID
  Returns: Session object or null if not found

deleteSession(sessionId: string): Promise<void>
  Description: Delete a session and all associated data
  Side effects: Cascade deletes all messages belonging to this session

### Storage Semantics [REQUIRED]

- Streaming/chunked data: [Accumulated into single row | Stored per-chunk | Not applicable]
- Cascade deletes: [List parent→child relationships and cascade behavior]
- Soft deletes: [Yes (mark deleted, retain data) | No (hard delete)]
- Timestamps: [Set by data layer | Set by caller | Set by database trigger]
- ID generation: [UUID v4 by data layer | Auto-increment by database | Provided by caller]

### Indexes [REQUIRED if database is used]

- [table]: ([column1], [column2] [ASC|DESC]) — [purpose]
- [table]: ([column]) UNIQUE — [purpose]

#### Example:

- sessions: (userId, updatedAt DESC) — list user's sessions sorted by recent
- sessions: (id) PRIMARY KEY
- messages: (sessionId, createdAt ASC) — list session messages in order
- messages: (id) PRIMARY KEY

### Migrations [if applicable]

- Migration tool: [Alembic | Prisma | Django migrations | Knex | raw SQL]
- Migration directory: [e.g., backend/migrations/]
- Run command: [e.g., alembic upgrade head]

### Connection Configuration

- Connection string env var: [e.g., DATABASE_URL]
- Connection pool size: [e.g., 5-20 depending on load]
- Timeout: [e.g., 30 seconds]
```

---

## Shared Types Templates

### TypeScript

```typescript
// contracts/types.ts — SINGLE SOURCE OF TRUTH

// ============================================================
// Core entities — both frontend and backend reference these
// ============================================================

export interface [EntityName] {
  id: string;                    // [ID format: UUID v4 | CUID | etc.]
  [field]: [type];               // [description]
  [field]: [type];               // [description]
  createdAt: string;             // ISO 8601
  updatedAt: string;             // ISO 8601
}

// ============================================================
// Enums and constants
// ============================================================

export type [EnumName] = "[value1]" | "[value2]" | "[value3]";

export const API_BASE = "[/api/v1]";
export const DEFAULT_PAGE_SIZE = [20];

// ============================================================
// Request/Response shapes (if different from entities)
// ============================================================

export interface Create[Entity]Request {
  [field]: [type];               // [required/optional]
}

export interface [Entity]ListResponse {
  items: [Entity][];
  total: number;
}

// ============================================================
// Error envelope
// ============================================================

export interface ApiError {
  error: string;
  code: string;
  details: Array<{ field?: string; message: string }>;
}
```

### Python (Pydantic)

```python
# contracts/types.py — SINGLE SOURCE OF TRUTH

from datetime import datetime
from enum import Enum
from pydantic import BaseModel, Field
from uuid import UUID

# ============================================================
# Core entities
# ============================================================

class EntityName(BaseModel):
    id: UUID
    field_name: str              # description
    field_name: int              # description
    created_at: datetime
    updated_at: datetime

# ============================================================
# Enums
# ============================================================

class EnumName(str, Enum):
    VALUE1 = "value1"
    VALUE2 = "value2"

# ============================================================
# Request/Response shapes
# ============================================================

class CreateEntityRequest(BaseModel):
    field_name: str = Field(..., min_length=1, max_length=200)

class EntityListResponse(BaseModel):
    items: list[EntityName]
    total: int

# ============================================================
# Error envelope
# ============================================================

class ErrorDetail(BaseModel):
    field: str | None = None
    message: str

class ApiError(BaseModel):
    error: str
    code: str
    details: list[ErrorDetail] = []
```

### JSON Schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "contracts/types.json",
  "description": "Shared type definitions — SINGLE SOURCE OF TRUTH",

  "$defs": {
    "EntityName": {
      "type": "object",
      "properties": {
        "id": { "type": "string", "format": "uuid" },
        "fieldName": { "type": "string" },
        "createdAt": { "type": "string", "format": "date-time" },
        "updatedAt": { "type": "string", "format": "date-time" }
      },
      "required": ["id", "fieldName", "createdAt", "updatedAt"]
    },

    "ApiError": {
      "type": "object",
      "properties": {
        "error": { "type": "string" },
        "code": { "type": "string" },
        "details": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "field": { "type": "string" },
              "message": { "type": "string" }
            },
            "required": ["message"]
          }
        }
      },
      "required": ["error", "code", "details"]
    }
  }
}
```

---

## How to Use These Templates

1. **Copy** the relevant template(s) into your project's `contracts/` directory
2. **Fill in** the project-specific details (entity names, fields, endpoints, etc.)
3. **Remove** optional sections that don't apply
4. **Version** as v1
5. **Include** in agent prompts during Phase 5 (Distill Agent Prompts)

The lead authors contracts during Phase 4. Agents receive them as part of their spawn prompt and build to match them exactly.

**The shared types file is always created first** — API and data layer contracts reference it. If you find yourself defining types inline in a contract, pull them into the shared types file instead.
