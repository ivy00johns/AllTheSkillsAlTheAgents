# Hypothesis Format

Phase 3 produces a *ranked list of falsifiable hypotheses*, not a "let me try a few things and see." A hypothesis is falsifiable if running the Phase 1 loop after a specific change either confirms it or rules it out. Show the list to the user before testing — they often have context that re-ranks the list.

## Template

> If `<X>` is the cause, then `<changing Y>` will make the bug disappear.

The structure forces three commitments at once:

1. **`<X>` is concrete.** Not "something with the cache" — "the user-permissions cache returning stale data after a role change."
2. **`<changing Y>` is a single experiment.** Not "rewrite the cache layer" — "disable the cache for this endpoint and rerun the loop."
3. **The link between the two is testable.** If `Y` changes nothing, the hypothesis is wrong, even if the bug seems related.

Hypotheses that don't fit this shape are usually too vague to test ("maybe it's a race condition" — a race in *what*, fixed by *what*?). Reshape them until they fit, or drop them.

## Ranking

Order the list by **likelihood × cost-to-test**, cheapest-likely-cause first. A hypothesis you can falsify in 30 seconds always goes before a hypothesis that requires a fresh database snapshot, even if the slow one feels more likely.

```
1. (high likelihood, 30s to test)  ← start here
2. (high likelihood, 5min to test)
3. (medium likelihood, 30s to test)
4. (medium likelihood, 1hr to test)
5. (low likelihood, 30s to test)   ← still worth running because cheap
```

## Three example hypotheses

These come from a real bug pattern: an HTTP endpoint that returns the wrong total price for ~1% of requests under load.

### Hypothesis 1 — float rounding in tax calculation

> If float-rounding in `applyTax()` is the cause, then changing the call to use the `Decimal` library (already imported elsewhere in the codebase) will make the bug disappear.

**Cost to test:** 5 minutes — swap one call site, rerun the loop.
**Why it's first:** Cheap to falsify and the loop already shows the wrong total is always off by a fraction of a cent, which matches a float rounding signature.

### Hypothesis 2 — cache returning stale price after a SKU price update

> If the price cache returning stale data after a SKU update is the cause, then disabling the price cache (force-fetch from the database every request) will make the bug disappear under the same load test.

**Cost to test:** 10 minutes — flip the feature flag, rerun the load-test loop for 200 requests.
**Why it's second:** Plausible because the failures cluster in time, which matches a cache invalidation window. Slightly more expensive to test than #1.

### Hypothesis 3 — concurrent write race on the `discounts` table

> If a race condition on concurrent writes to the `discounts` table is the cause, then serializing access (wrapping the read+write in a transaction with `SELECT ... FOR UPDATE`) will make the bug disappear when the loop runs in parallel mode.

**Cost to test:** 30 minutes — add the lock, rerun the parallel loop variant, then back out the change if it doesn't fix it.
**Why it's third:** Matches the "only under load" signature, but more expensive than #1 and #2 to test, so try the cheaper ones first.

## Common shape mistakes

- **Not falsifiable:** "Maybe it's a memory leak somewhere." → Fix: "If the OrderService leaks Order objects per request, then forcing a GC after each request will keep RSS flat across 1000 iterations of the loop."
- **Two hypotheses smushed together:** "It's probably the cache *and* the rounding." → Fix: split into two hypotheses, test independently. Bug fixes that change two things at once teach you nothing.
- **Hypothesis with no experiment:** "It's a race condition." → Fix: name the resource being raced on and the change that would serialize it. If you can't, you don't have a hypothesis yet.

## After testing each one

Record the result against the hypothesis in your notes:

```
1. Float rounding — TESTED, ruled out. Decimal swap didn't change the bug.
2. Stale cache — TESTED, CONFIRMED. Disabling cache makes the bug disappear.
   Real root cause: cache TTL > price-update propagation delay.
3. Discount race — UNTESTED. Not needed; #2 explained the symptom.
```

The confirmed hypothesis goes into the PR message — that's the "post-mortem in the commit" from Phase 6.
