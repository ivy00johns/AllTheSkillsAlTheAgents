# 08 — Open Questions

## Why this document exists

A stack this large does not fail because there are no ideas.
It fails when key decisions remain implicit for too long.

These are the questions to force into the open early.

## Product questions

### 1. Who is the first-class operator?

Options:

- solo power user
- small engineering team
- platform team serving many teams

Why it matters:

- changes every UX, auth, and hosting decision

### 2. Is the first product local-first or service-hosted?

Why it matters:

- determines how much of `gastown` can stay intact
- determines whether evidence and analytics must be remote from day one

### 3. Is the goal "better software factory for one person" or "platform for many operators"?

Why it matters:

- the first is a power tool
- the second needs RBAC, auditability, quotas, and policy administration

## Architecture questions

### 4. Is `beads` the source of truth for all durable state, or only work state?

Why it matters:

- storing everything in beads may overfit the graph
- splitting state too early creates fragmentation

### 5. Should quality services run inline with execution or asynchronously?

Why it matters:

- inline gives tighter loops
- async gives better throughput and isolation

### 6. How strict should ownership be?

Options:

- strict file ownership
- soft ownership with merge-time conflict mediation
- mixed mode by project type

Why it matters:

- changes throughput versus coordination cost

### 7. What is the canonical contract format?

Candidates:

- generated markdown plus machine-readable schemas
- OpenAPI and AsyncAPI plus custom ownership schema
- one custom bundle format with generated projections

Why it matters:

- every runtime and tool will depend on this

## Operational questions

### 8. What is the minimum evidence set required before a task can be called done?

Possible minimums:

- code diff
- tests
- review summary
- screenshot if UI touched
- trace or logs if runtime behavior changed

### 9. How should the router optimize?

Candidates:

- speed
- cost
- quality
- confidence-adjusted blended score

### 10. What should trigger human approval?

Examples:

- contract changes
- production-impacting migrations
- design regressions above threshold
- cost spikes
- failed recovery loops

## Security questions

### 11. What is the trust boundary for agents?

Why it matters:

- determines credential scoping
- determines whether workers can access prod-like systems

### 12. How are secrets injected, rotated, and audited?

Why it matters:

- local-first assumptions break quickly in team settings

## Upstream strategy questions

### 13. Which repos are dependencies, and which are reference implementations?

Provisional answer:

- `beads`: dependency
- `gastown`: dependency plus reference
- `gstack`: reference plus extracted services

### 14. What is the upgrade cadence?

Why it matters:

- without a cadence, adapters silently rot

## Questions to answer with prototypes, not debate

1. Can browse be turned into a runtime-neutral service cleanly?
2. Can review findings be normalized into a durable bead schema without losing nuance?
3. Can routing quality be improved measurably with scorecards?
4. Can contract bundles stay small enough for workers without losing precision?
5. Can the operator understand the system from one timeline view?

## Final reminder

Whenever a design argument gets abstract, reduce it to this:

`Which question does this decision answer, and what prototype will prove it?`
