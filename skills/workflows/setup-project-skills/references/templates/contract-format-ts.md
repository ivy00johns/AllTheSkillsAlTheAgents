# Contract format — TypeScript interfaces

This repository uses **TypeScript interfaces** as the source of truth for integration contracts. Shared types live in a single package or directory and are imported by both the API layer and consumers.

## File locations

- **Contract types live in:** `contracts/types/` (one `.ts` file per domain boundary)
- **Filename convention:** `<domain>.contracts.ts` — e.g., `contracts/types/billing.contracts.ts`
- **TypeScript:** strict mode required. `noImplicitAny`, `strictNullChecks`, `exactOptionalPropertyTypes` on.

## How `contract-author` should generate

When the orchestrator invokes `contract-author` in this repo, it should:

1. Use the TypeScript template at `skills/contracts/contract-author/references/templates/typescript-template.ts`.
2. Write to `contracts/types/<domain>.contracts.ts`.
3. Export request, response, error, and event interfaces. Use discriminated unions for sum types. Include JSDoc on every exported type.

## How `contract-auditor` should verify

`contract-auditor` reads the `.contracts.ts` files and checks:

1. Backend handlers import contract types and use them in their request/response signatures.
2. Frontend API call sites import contract types for their request bodies and response handlers.
3. No layer redefines a shape that is already in `contracts/types/`.

## How role agents should consume

- **backend-agent** — imports types from `contracts/types/` for route handler I/O. Does not duplicate shapes locally.
- **frontend-agent** — imports the same types for client-side API calls. The contract is the only source of truth — no client-side type drift.
- **qe-agent** — uses the contract types to assert API response shapes in tests.

## Forbidden patterns

- Do not use `any` or `unknown` at the contract boundary. If a field is genuinely polymorphic, model it as a discriminated union.
- Do not redefine the same shape in `types/` and `models/` — pick one location and stick with it.
- Do not use Zod schemas as the *only* source of truth; either commit to Zod everywhere (and generate TS types from it) or commit to plain interfaces. Mixed-mode contracts drift.
