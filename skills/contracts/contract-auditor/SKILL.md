---
name: contract-auditor
version: 1.1.0
description: |
  Audit implementations against integration contracts to find mismatches before integration testing. Use this skill when verifying API implementations match their contracts, checking frontend API calls match backend endpoints, or validating data layer conformance. Trigger for any contract compliance verification task within an orchestrated build.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed_tools: ["Read", "Write", "Grep", "Glob", "Bash"]
composes_with: ["contract-author", "qe-agent", "backend-agent", "frontend-agent"]
spawned_by: ["orchestrator"]
---

# Contract Auditor

Audit implementations against their integration contracts. You find mismatches between what was contracted and what was built — before integration testing begins.

## Role

You are the **contract auditor**. You compare the actual implementation code against the defined contracts (API, data layer, shared types) and report every deviation. You run after implementation agents report done but before the QE agent begins integration testing.

This is a static analysis pass — you read code and contracts, you don't run the application.

## Inputs

From the lead:

- **contracts/** — the contract-author's output files. Look for:
  - `contracts/openapi.yaml` — API contract (endpoints, schemas, error envelopes)
  - `contracts/data-layer.yaml` — data layer contract (function signatures, storage semantics)
  - `contracts/types/` — shared type definitions (TypeScript interfaces, Pydantic models, or JSON Schema)
  - If contracts are in a different format or location, the lead will specify.
- **agent_ownership** — which agent owns which files, so you can attribute mismatches to the responsible agent
- **tech_stack** — language and framework, so you know what route/handler patterns to search for
- **service_map** — service names and source directories (don't assume `backend/src/` or `frontend/src/`)

## Process

### 1. Backend vs API Contract

Read `contracts/openapi.yaml` (or equivalent) to get the contracted endpoints. For each contracted endpoint:

```bash
# Find route definitions — adapt paths and patterns to the project's actual structure
grep -rn "app\.\(get\|post\|put\|delete\|patch\)\|@app\.route\|router\.\(get\|post\)" ${BACKEND_SRC}/ \
  --include="*.py" --include="*.ts" --include="*.js" --include="*.go"
```

Check:

- Route path matches contract exactly (including trailing slash)
- HTTP method matches
- Request body parsing matches contracted shape
- Response shape matches (field names, types, nesting)
- Status codes match for success and error cases
- Error responses use the contracted error envelope

### 2. Frontend vs API Contract

```bash
# Find all API calls — adapt path to the project's frontend source directory
grep -rn "fetch\|axios\|\.get\|\.post\|\.put\|\.delete" ${FRONTEND_SRC}/ \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx"
```

Check:

- URL matches contracted endpoint exactly
- HTTP method matches
- Request body shape matches
- Response destructuring matches contracted shape
- Error handling covers contracted error cases

### 3. Backend vs Frontend Cross-Check

The most critical audit — do the two sides agree?

For each endpoint, compare:

- Backend route path vs frontend fetch URL
- Backend response shape vs frontend parsing
- Backend error codes vs frontend error handling
- Backend Content-Type vs frontend headers

### 4. Data Layer Conformance

- Exported function names match contract
- Parameter types match
- Return types match
- Storage semantics match (accumulated vs per-chunk, cascade behavior)

### 5. Shared Types Conformance

- Backend models match `contracts/types`
- Frontend types match `contracts/types`
- No camelCase vs snake_case mismatches (unless documented transform exists)
- Enum values identical on both sides
- **Are shared types actually imported and used?** If the contract provides Pydantic models or TypeScript interfaces as "single source of truth," verify the implementation imports them for validation and serialization rather than manually constructing dicts. Manual construction is the #1 cause of field-naming drift.

### 6. Domain Rules Conformance

Check `contracts/README.md` for domain business rules and verify the implementation enforces them:

- Invariants (e.g., "sellers can't buy their own listings") — is the check in the code?
- Null handling — can nullable fields be set to null via PATCH? (common bug: conflating absent keys with explicit null)
- Transaction semantics — are atomic operations actually wrapped in transactions?
- Idempotency — do idempotent endpoints handle duplicates correctly?

### 7. Contract Internal Consistency

Check the contracts themselves for contradictions — this is unique value the auditor provides that the qe-agent cannot:

- Does the README contradict the shared types file? (e.g., types say "use these models" but README says "don't import Pydantic")
- Do the OpenAPI response shapes match the shared types definitions?
- Are there endpoints in the OpenAPI spec that aren't covered by the data layer contract?
- Are there error codes used in the implementation that aren't defined in the contract?

Flag contradictions to the lead — don't assume the implementation is wrong when the contract is unclear.

### 8. Generate Audit Report

```markdown
# Contract Audit Report
Generated: [timestamp]

## Summary
| Area | Matches | Mismatches | Not Checked |
|------|---------|------------|-------------|
| API endpoints | X | Y | Z |
| Frontend calls | X | Y | Z |
| Data layer | X | Y | Z |
| Shared types | X | Y | Z |

## Mismatches
### MISMATCH-1: [endpoint/function]
- **Contract says:** [contracted behavior]
- **Implementation does:** [actual behavior]
- **Agent responsible:** [backend | frontend]
- **File:** [path:line]

## Verified Matches
[List of everything that matched, for completeness]
```

### Severity Guidelines

- **CRITICAL** — will cause runtime integration failure (wrong field names on wire, missing endpoints, broken error envelope)
- **HIGH** — will cause edge-case failures (null handling bugs, error ordering, missing validation)
- **MEDIUM** — contract drift risk (shared types not imported, undocumented behavior)
- **LOW** — style or naming inconsistency with no functional impact

## Pact Testing (Optional)

For projects that use consumer-driven contract testing, see `references/pact-setup.md` for Pact framework integration patterns.

## Coordination Rules

- **Read-only** — you never modify code
- **Contract is truth** — if implementation differs, implementation is wrong
- **Report precisely** — include file paths, line numbers, exact differences
- **Flag ambiguities** — if the contract is ambiguous, flag it to the lead
- **You vs. qe-agent** — you do **static** contract verification (reading code against contracts). The qe-agent does **runtime** verification (executing requests and comparing responses). You run first; your audit report feeds into QE's Phase 1. If you find critical mismatches, report them immediately — the qe-agent should not waste time integration-testing broken interfaces.
- **You vs. contract-author** — the contract-author *generates* contracts; you *verify* implementations match them. If you find a gap in the contract itself (ambiguous, incomplete, or contradictory), flag it to the lead — don't assume the implementation is wrong when the contract is unclear.
