# ADR format

Architecture Decision Records live in `docs/adr/`, numbered sequentially: `0001-title-kebab.md`, `0002-...`. Once accepted, an ADR is append-only — if the decision changes later, write a new ADR that supersedes it and update the old one's `Status` to `Superseded by NNNN`.

## Template

```markdown
# ADR NNNN: <Short imperative title>

- **Status:** Proposed | Accepted | Superseded by NNNN | Deprecated
- **Date:** YYYY-MM-DD
- **Deciders:** <names or roles, optional>

## Context

What is the situation forcing a decision? What constraints apply? What did we learn that made this question worth resolving now rather than later? Two to five sentences. Do not re-explain the codebase — link to it.

## Decision

The decision, stated as a single declarative sentence in present tense. "We use X for Y." Then a short paragraph on the mechanism — enough that a new contributor reading this can recognize the choice in the code.

## Consequences

What changes because of this decision? Both directions:

- **Positive:** what we gain, why we picked this option.
- **Negative:** what we lose, what becomes harder, what we're now locked into.
- **Neutral:** observable changes that aren't clearly wins or losses (e.g. new tooling, new vocabulary, migration burden).

## Alternatives considered

Each alternative gets one paragraph: what it was, why it was viable, why we didn't pick it. If there were no viable alternatives, the decision didn't need an ADR — re-check the three-condition gate.
```

## Fully-fleshed-out example

```markdown
# ADR 0007: Store financial events as an append-only ledger

- **Status:** Accepted
- **Date:** 2026-02-14
- **Deciders:** backend team, finance ops

## Context

Subscriber billing history needs to support both customer-facing invoices and finance reconciliation reports. Customer support also occasionally needs to issue retroactive credits. The existing `payments` table is updated in place on refunds, which means historical state is destroyed and reconciliation requires reading Stripe's API as the source of truth. Finance ops have flagged this twice in 2025 as a recurring source of mismatched numbers.

## Decision

We store all billing events in an append-only `billing_events` table, with each row representing a charge, refund, credit, or adjustment. Current subscriber balance is a derived view (`current_balance`) computed by summing events. The existing `payments` table is retained read-only for backfill, but no new code writes to it.

## Consequences

- **Positive:** History is preserved exactly. Finance reconciliation runs against our database instead of Stripe. Retroactive credits become normal inserts rather than special-case mutations.
- **Negative:** Every read of "current balance" hits the view, which is `O(n)` in events per subscriber. We accept this for now and will add a snapshot table if the slowest subscriber exceeds 50ms. We also lose the ability to ad-hoc `UPDATE` a payment row to fix a typo — corrections become compensating events, which is more ceremony.
- **Neutral:** Introduces the vocabulary "event" and "balance" — both added to CONTEXT.md. Migration of historical `payments` rows into `billing_events` is a one-time backfill, scripted in `scripts/backfill-billing-events.py`.

## Alternatives considered

**Keep the existing `payments` table and add an audit log via triggers.** Viable — Postgres triggers can capture row history into a shadow table. Rejected because the audit log would be a parallel source of truth that drifts from the live table, and finance ops would still need to reason about both. The ledger model collapses live state and history into one source.

**Use Stripe as the system of record and stop storing payments locally at all.** Viable for a smaller product. Rejected because reconciliation reports already need cross-references to internal subscriber state, support tooling needs sub-second balance lookups, and Stripe API rate limits would bottleneck the customer dashboard.
```

## Style rules

- Title is imperative and specific. "Use Postgres" is bad. "Store financial events as an append-only ledger" is good.
- Context explains the forcing function, not the universe. Two to five sentences.
- Decision is one sentence followed by a short paragraph. No bullet lists for the decision itself.
- Alternatives section is mandatory and must contain real alternatives. If you can't write two paragraphs about options you considered, the decision wasn't a real trade-off and shouldn't be an ADR.
