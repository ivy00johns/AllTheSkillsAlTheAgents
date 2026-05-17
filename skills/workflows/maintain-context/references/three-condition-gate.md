# The three-condition gate

An ADR is worth writing only when *all three* conditions hold:

1. **Hard to reverse.** Rolling back costs real time, money, or coordination.
2. **Surprising without context.** A new contributor would reach for the obvious answer and be wrong.
3. **Real trade-off involved.** There were viable alternatives, and picking this one closed doors.

If any condition is missing, skip the ADR. The folder's value depends on rarity — every routine entry dilutes the rest.

## Scenarios

### Scenario 1: Switching the primary database from MongoDB to Postgres

- **Hard to reverse?** Yes. Migrating data, rewriting query layers, retraining the team — months of work.
- **Surprising without context?** Yes. A contributor seeing Postgres might assume it was the default from day one and not realize there was a deliberate migration with constraints around aggregate queries and consistency.
- **Real trade-off?** Yes. MongoDB's flexible schema was working; Postgres trades that for ACID guarantees and richer query semantics.

**Call: write the ADR.** All three conditions hit. Capture why MongoDB stopped working, what the migration cost, and what we gave up to gain ACID.

### Scenario 2: Adopting event-sourcing for the billing subsystem

- **Hard to reverse?** Yes. Event-sourced systems are not casually un-event-sourced; downstream consumers depend on the event stream.
- **Surprising without context?** Yes. A new dev seeing event rows in the database might assume it's an audit log rather than the source of truth and write code that mutates derived state directly.
- **Real trade-off?** Yes. Event-sourcing trades query simplicity for auditability and time-travel.

**Call: write the ADR.** See the worked example in `adr-format.md` — this is exactly that case.

### Scenario 3: Choosing camelCase over snake_case for TypeScript variable names

- **Hard to reverse?** No. A codemod plus a lint rule reverses this in a day. Maybe an afternoon.
- **Surprising without context?** No. It's the TypeScript community default; new contributors won't be surprised.
- **Real trade-off?** Barely — snake_case is viable but unusual in TS.

**Call: skip the ADR.** Fails "hard to reverse" and arguably "surprising." Put the rule in the linter config — that's the right home for low-stakes consistency choices. If anyone asks why, the linter rule and the convention itself are sufficient explanation.

### Scenario 4: Using JWT for API authentication

- **Hard to reverse?** Yes — clients, refresh logic, token rotation are all entangled.
- **Surprising without context?** No. JWT is the default expectation for stateless API auth in this kind of system; nobody walks in expecting session cookies.
- **Real trade-off?** Yes — sessions vs JWTs is a genuine debate.

**Call: skip the ADR.** Fails "surprising without context." Even though it's hard to reverse and there was a real trade-off, a new contributor will see JWT middleware and immediately understand what's happening. The ADR would describe a normal choice, and the folder loses signal when it documents normal choices. If JWT had been picked over an internal SSO system that everyone expected, the answer flips — surprising-ness depends on the surrounding context.

### Scenario 5: Picking AWS over GCP for the production hosting environment

- **Hard to reverse?** Yes — IAM, networking, managed services, billing contracts.
- **Surprising without context?** Maybe — depends on the team's background.
- **Real trade-off?** Not really, if the decision was "the founding team already had AWS expertise and credits." There were no rejected alternatives — GCP was never seriously compared.

**Call: skip the ADR.** Fails "real trade-off." This is a historical fact, not a decision. Put it in `CONTEXT.md` or the deployment README ("We run on AWS — `us-east-1` for prod, `us-west-2` for staging"). An ADR is for capturing *why we chose A over B*; if there was no B, there's no decision to record. If two years later someone proposes migrating to GCP and the team chooses to stay on AWS, *that* is the ADR — the moment a real trade-off appears.

## How to use the gate in conversation

When a decision surfaces:

1. Name each condition out loud. "Hard to reverse: yes/no because <reason>. Surprising: yes/no because <reason>. Real trade-off: yes/no because <reason>."
2. If any is "no," say so and skip. Suggest the right home instead — linter config, README, CONTEXT.md, runbook.
3. If all three are "yes," ask the user: "Want me to draft this as ADR NNNN?" Then write it inline, not at end-of-session.

The gate is a filter, not a ceremony. Apply it fast and move on.
