# Contract format — Pydantic

This repository uses **Pydantic models** as the source of truth for integration contracts. Domain types, request/response shapes, and event schemas are defined as Pydantic v2 `BaseModel` classes.

## File locations

- **Contract models live in:** `contracts/models/` (one `.py` file per domain boundary)
- **Filename convention:** `<domain>_contracts.py` — e.g., `contracts/models/billing_contracts.py`
- **Python version:** Pydantic v2 (`from pydantic import BaseModel`). Do not mix with v1 unless explicitly noted.

## How `contract-author` should generate

When the orchestrator invokes `contract-author` in this repo, it should:

1. Use the Pydantic template at `skills/contracts/contract-author/references/templates/pydantic-template.py`.
2. Write to `contracts/models/<domain>_contracts.py`.
3. Include request, response, error, and event models with full type annotations and field-level docstrings.

## How `contract-auditor` should verify

`contract-auditor` imports the Pydantic models and checks:

1. Every API handler signature uses the declared request/response models.
2. Field types match between handler input and the contract model.
3. No handler returns a shape not described by a contract model.

## How role agents should consume

- **backend-agent** — imports models from `contracts/models/` and uses them directly in route signatures and service interfaces. Does not redefine the same shape locally.
- **frontend-agent** — derives TypeScript types from the Pydantic models (e.g., via `datamodel-code-generator --output-model-type typescript`) or via a `/openapi.json` endpoint that the framework auto-generates.
- **qe-agent** — uses the models for schema-based property tests and for asserting handler I/O conformance.

## Forbidden patterns

- Do not define `dataclasses.dataclass` or `TypedDict` versions of the same contract — Pydantic models are canonical.
- Do not loosen field types with `Any` or `Dict[str, Any]` at the contract boundary; that defeats the purpose.
