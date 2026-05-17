# QA Report Schema Reference

The `qa-report.json` is the orchestrator's build gate. The orchestrator parses it programmatically and blocks the build on CRITICAL blockers or `contract_conformance` / `security` scores below 3. A non-conformant report is as bad as no report.

The canonical machine-readable schema lives at `qa-report-schema.json` in this directory. This document explains the structure, the score model, and how to produce a conformant report.

## File pair

The QE agent writes both files at the end of Phase 4:

- `qa-report.md` — human-readable narrative with findings table and summary
- `qa-report.json` — machine-readable per `qa-report-schema.json` (the gate)

Both files share the same findings; the JSON exists so the orchestrator can parse without LLM calls.

## Schema shape (summary)

The `qa-report.json` MUST include the following top-level dimensions. Each is an object with `score` (1–5 integer) and `notes` (string explaining the score). Bare integers are non-conformant.

```json
{
  "correctness":          { "score": 4, "notes": "..." },
  "completeness":         { "score": 4, "notes": "..." },
  "code_quality":         { "score": 4, "notes": "..." },
  "security":             { "score": 4, "notes": "..." },
  "contract_conformance": { "score": 5, "notes": "..." },
  "findings": [ ... ],
  "passed":   [ ... ]
}
```

Refer to `qa-report-schema.json` for the full field list, required vs optional, and finding object shape.

## Dimension definitions

Score each 1–5 per `references/llm-judge-rubrics.md`. Use these definitions when assigning scores so the orchestrator's interpretation matches yours:

- **correctness** — does it work? Do endpoints return correct responses for the happy path and contracted edge cases?
- **completeness** — is everything there? Are all contracted endpoints implemented? Is the data model complete?
- **code_quality** — is it well-built? Clean separation, consistent patterns, error handling, no dead code?
- **security** — is it safe? Input validated, no injection, CORS correct, no secrets leaked? Coordinate with security-agent if present — avoid duplicating their deeper audit.
- **contract_conformance** — does the implementation match the spec? URLs, methods, request/response shapes, status codes, error envelope, field names.

## Finding object

Each finding in the `findings` array must include:

- `id` — stable identifier (e.g., `CR-001`)
- `severity` — `CRITICAL` | `HIGH` | `MEDIUM` | `LOW`
- `dimension` — which scored dimension it pulls down
- `agent` — which agent owns the fix (from the orchestrator's ownership map)
- `summary` — one-line description
- `evidence` — exact reproduction command or file:line reference
- `expected` — what the contract or test required
- `actual` — what the implementation produced

## Passed list

The `passed` array is not optional. Credit what works — list contract-conformance checks that succeeded, happy-path flows that ran clean, adversarial probes that did not break the system. The orchestrator uses this to calibrate the score notes.

## Examples

See the canonical schema file and an example report under the orchestrator's reference materials. Field names must match the schema exactly — the orchestrator parses by name, not position.
