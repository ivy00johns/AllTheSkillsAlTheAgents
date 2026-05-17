# Contract format — OpenAPI

This repository uses **OpenAPI** (Swagger) for integration contracts. REST endpoints, request/response shapes, and error envelopes are defined in OpenAPI specs.

## File locations

- **Specs live in:** `contracts/openapi/` (one `.yaml` file per service or domain boundary)
- **Filename convention:** `<service-or-domain>.openapi.yaml` — e.g., `contracts/openapi/billing.openapi.yaml`
- **Version:** OpenAPI 3.1 unless otherwise noted.

## How `contract-author` should generate

When the orchestrator invokes `contract-author` in this repo, it should:

1. Use the OpenAPI template at `skills/contracts/contract-author/references/templates/openapi-template.yaml`.
2. Write to `contracts/openapi/<name>.openapi.yaml`.
3. Include request/response schemas, error responses, and authentication declarations.

## How `contract-auditor` should verify

`contract-auditor` reads `contracts/openapi/*.yaml` and checks:

1. Backend route handlers match every `paths` entry by method and path.
2. Request body schemas match handler input validation.
3. Response schemas match handler output shape.
4. Frontend API client calls match `paths` entries.

## How role agents should consume

- **backend-agent** — implements every endpoint declared in the spec. Treats the spec as authoritative; if the spec is wrong, fix the spec first, then the code.
- **frontend-agent** — generates typed client code from the spec (e.g., via `openapi-typescript`) and consumes it. Does not hand-write API client types.
- **qe-agent** — uses the spec for contract conformance tests and adversarial probing of error responses.

## Forbidden patterns

- Do not write JSON Schema or TypeScript interfaces as the source of truth for HTTP boundaries. Use OpenAPI; let other formats be derived.
- Do not split one logical service across multiple OpenAPI files unless the service is genuinely two services.
