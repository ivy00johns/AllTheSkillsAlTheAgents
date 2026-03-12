# LLM-as-Judge Scoring Rubrics

Rubrics for the five dimensions in the QA report's `scores` section. Each dimension is scored 1–5. The QE agent uses these to self-score; the orchestrator uses them to validate.

## Correctness (Does it work?)

| Score | Criteria |
|-------|----------|
| 5 | All contracted endpoints return correct responses. All happy paths work. All error cases return proper envelopes. |
| 4 | All critical paths work. 1-2 minor edge cases return unexpected results but don't break functionality. |
| 3 | Happy path works but some contracted endpoints have wrong response shapes or missing fields. |
| 2 | Happy path partially works. Multiple endpoints fail or return wrong data. |
| 1 | Core functionality is broken. Services crash or can't connect. |

## Completeness (Is everything there?)

| Score | Criteria |
|-------|----------|
| 5 | Every contracted endpoint implemented. All CRUD operations work. All specified features present. |
| 4 | 90%+ of contracted endpoints implemented. Missing features are non-critical. |
| 3 | Core endpoints present but some contracted features missing. |
| 2 | Significant gaps — multiple contracted endpoints unimplemented. |
| 1 | Skeleton only — most contracted functionality missing. |

## Code Quality (Is it well-built?)

| Score | Criteria |
|-------|----------|
| 5 | Clean separation of concerns. Consistent patterns. Error handling everywhere. No code smells. |
| 4 | Good structure. Minor inconsistencies. Error handling covers main paths. |
| 3 | Functional but some anti-patterns. Mixed error handling. Some duplication. |
| 2 | Poor structure. Many anti-patterns. Missing error handling in critical paths. |
| 1 | Spaghetti code. No error handling. Copy-paste duplication. |

## Security (Is it safe?)

| Score | Criteria |
|-------|----------|
| 5 | Input validated. No injection vulnerabilities. Auth/authz correct. CORS properly configured. No secrets in code. |
| 4 | Main security concerns addressed. Minor issues in non-critical paths. |
| 3 | Basic input validation present but gaps exist. CORS may be overly permissive. |
| 2 | Multiple security gaps. SQL/XSS injection possible. Auth easily bypassed. |
| 1 | No input validation. Secrets hardcoded. Critical vulnerabilities present. |

## Contract Conformance (Does it match the spec?)

| Score | Criteria |
|-------|----------|
| 5 | Every endpoint URL, method, request/response shape, status code, and error envelope exactly matches the contract. |
| 4 | All endpoints match. 1-2 minor field naming differences or extra fields (backward-compatible). |
| 3 | Most endpoints match. Some response shapes differ from contract or status codes are wrong. |
| 2 | Multiple contract violations. Frontend and backend disagree on shapes. |
| 1 | Widespread contract violations. Implementations built against assumptions, not the contract. |

## Gate Rules

The orchestrator blocks the build (`gate_decision.proceed = false`) when:

- Overall `status` is `FAIL` or `BLOCKED`
- Any blocker has `severity: CRITICAL`
- `scores.contract_conformance < 3`
- `scores.security < 3`

A score of 3 is the minimum acceptable threshold — it means "functional but needs improvement." Scores of 4-5 indicate production-ready quality.
