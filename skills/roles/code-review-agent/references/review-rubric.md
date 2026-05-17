# Code Review Rubric

## Scoring Guide

Each dimension is scored 1-5:

- **5**: Excellent — exemplary, no issues
- **4**: Good — minor issues only, production-ready
- **3**: Acceptable — some issues but functional
- **2**: Needs Work — significant issues that should be fixed
- **1**: Critical — fundamental problems, not ready for use

## Correctness

| Score | Criteria |
|-------|----------|
| 5 | All contracted behavior implemented correctly. Edge cases handled. Return types accurate. |
| 4 | Core behavior correct. 1-2 minor edge cases unhandled. |
| 3 | Happy path works but some contracted behavior missing or wrong. |
| 2 | Multiple logic errors. Some endpoints return wrong data. |
| 1 | Core functionality broken or unimplemented. |

## Security

| Score | Criteria |
|-------|----------|
| 5 | All input validated. No injection vectors. Auth/authz correct. CORS configured. No secrets in code. |
| 4 | Main security concerns addressed. Minor gaps in non-critical paths. |
| 3 | Basic input validation present but incomplete. |
| 2 | Multiple security gaps. Injection possible. Auth bypassable. |
| 1 | No input validation. Hardcoded secrets. Critical vulnerabilities. |

## Code Quality

| Score | Criteria |
|-------|----------|
| 5 | Consistent naming. Clean separation. DRY. Appropriate abstractions. Clear intent. |
| 4 | Good structure. Minor inconsistencies. Readable. |
| 3 | Functional but some anti-patterns. Mixed styles. Some duplication. |
| 2 | Poor structure. Significant duplication. Unclear naming. |
| 1 | Spaghetti code. No organization. Copy-paste everywhere. |

## Performance

| Score | Criteria |
|-------|----------|
| 5 | Efficient queries. Appropriate data structures. No unnecessary work. |
| 4 | Good performance. No N+1 queries. Minor optimization opportunities. |
| 3 | Acceptable but some unnecessary work (e.g., loading full objects when only IDs needed). |
| 2 | N+1 queries present. Unnecessary allocations. Missing pagination. |
| 1 | Obvious performance issues that will cause problems at any scale. |

## Maintainability

| Score | Criteria |
|-------|----------|
| 5 | Self-documenting. Logical file structure. Easy to extend. Minimal dependencies. |
| 4 | Clear structure. Most code self-explanatory. Comments where needed. |
| 3 | Understandable with effort. Some unclear sections. |
| 2 | Hard to follow. Tight coupling. Unclear responsibilities. |
| 1 | Impossible to understand without author. Circular dependencies. |

## Issue Severity Definitions

| Severity | Definition | Action |
|----------|-----------|--------|
| CRITICAL | Will cause data loss, security breach, or crash in production | Must fix before any deployment |
| HIGH | Incorrect behavior or significant security gap | Must fix before integration testing |
| MEDIUM | Works but fragile, inefficient, or doesn't follow conventions | Should fix before final review |
| LOW | Style issues, minor improvements, missing comments | Fix if time permits |
| SUGGESTION | Optional improvements or alternative approaches | Consider for future iteration |
