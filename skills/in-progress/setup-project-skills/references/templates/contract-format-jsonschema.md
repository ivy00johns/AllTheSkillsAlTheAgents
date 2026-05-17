# Contract format — JSON Schema

This repository uses **JSON Schema** as the source of truth for integration contracts. Cross-language boundaries, event payloads, and config validation all use JSON Schema definitions.

## File locations

- **Schemas live in:** `contracts/schemas/` (one `.json` file per domain object or event)
- **Filename convention:** `<name>.schema.json` — e.g., `contracts/schemas/billing-event.schema.json`
- **JSON Schema draft:** Draft 2020-12 unless otherwise noted.

## How `contract-author` should generate

When the orchestrator invokes `contract-author` in this repo, it should:

1. Use the JSON Schema template at `skills/contracts/contract-author/references/templates/jsonschema-template.json`.
2. Write to `contracts/schemas/<name>.schema.json`.
3. Include `$id`, `$schema`, `title`, `description`, `type`, `properties`, `required`, and `additionalProperties: false` at every object level.

## How `contract-auditor` should verify

`contract-auditor` reads the `.schema.json` files and checks:

1. Every producer of a payload validates it against the schema before emitting.
2. Every consumer validates incoming payloads against the schema before processing.
3. Code-generated types (TS, Python, Go) derived from the schema match the canonical schema definitions.

## How role agents should consume

- **backend-agent** — validates request/response payloads against schemas using `ajv` (Node), `jsonschema` (Python), or the platform equivalent. Generated types are imported from the schema.
- **frontend-agent** — generates TS types from schemas (e.g., via `json-schema-to-typescript`) and validates server responses with `ajv` when the schema allows it.
- **qe-agent** — uses schemas for property-based fuzz testing of producer/consumer pairs.

## Forbidden patterns

- Do not hand-write parallel type definitions in TS or Python that duplicate a schema. Generate them.
- Do not use `additionalProperties: true` at contract boundaries — extra fields mask drift.
- Do not use `anyOf` / `oneOf` without `discriminator` keys; consumers cannot distinguish ambiguous unions safely.
