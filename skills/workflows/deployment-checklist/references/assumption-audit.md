# Assumption Audit

A pre-sign-off discipline that surfaces every assumption baked into a deploy plan — including the invisible ones nobody thought to question. Most outages live in the assumptions nobody wrote down.

## When to Use

Invoke before sign-off in `deployment-checklist` — after the per-section checks pass, before the final `READY / NOT READY` verdict. Also suitable for architecture review during design phases (e.g., before contract authoring in an orchestrated build).

Skip only for hotfixes where the change set is a single line and the failure mode is already understood.

## The 4-Step Process

Walk through these in order. Steps 2 and 3 are where the value lives — spend most of the time there.

### 1. Explicit assumptions (3 bullets)

List the things the plan **openly states as true**. These are stated but not necessarily proven — surface them so they can be re-examined under deploy conditions. Things like declared dependency versions, advertised SLAs, claimed migration ordering.

### 2. Implicit assumptions (3 bullets)

List the things the plan assumes are true **without saying so**. These are the beliefs so obvious to the author they were never written down — and so are also invisible to reviewers. Spend more time here than on explicit. Useful prompts:

- What is true today that, if it changed silently, would break this plan?
- What does the plan assume about upstream services, traffic shape, data volume, identity, or trust boundaries?
- What does the plan assume about the *human* side — who is on call, what they know, how fast they can respond?

### 3. The most-dangerous assumption (1 sentence)

Name the single assumption that, **if wrong, causes the entire plan to fail.** Not the most likely to be wrong — the **most catastrophic if wrong**. These are different questions and the discipline is to answer the second one.

### 4. How to test each (3 bullets)

For each implicit assumption from step 2, write **one concrete way to verify it before commit**. Must be executable: a named source to query, a specific experiment to run, a specific person to ask. "Do more research" or "review the design" does not count.

## Worked Example

Deploy plan: "Roll out the new search service to 100% of traffic on Friday."

1. **Explicit assumptions:**
   - The search service passes all integration tests in staging.
   - The new index is backwards-compatible with the v1 query shape.
   - Rollback is one Helm command.
2. **Implicit assumptions:**
   - The upstream auth service can handle 10x its current QPS, because each search now triggers a per-request token check.
   - Friday traffic patterns match Wednesday's load test (no weekly batch jobs hit search).
   - The on-call rotation knows what a degraded-but-up search response looks like and will not page out at 3am.
3. **Most-dangerous assumption:** That the upstream auth service can absorb the new per-request load — if wrong, every search degrades, every login degrades, the blast radius is the whole product.
4. **How to test each:**
   - Auth capacity: pull the auth service's current p99 utilization from Grafana dashboard `auth-prod-load`; if above 60%, run a shadow-traffic test before rollout.
   - Friday traffic shape: ask the data team's on-call (Slack #data-oncall) for the Friday vs Wednesday QPS delta over the last 4 weeks.
   - On-call readiness: walk the current primary through the new degraded-response runbook in a 15-min sync before Friday.

## Anti-Patterns

| Anti-Pattern | Why It Fails |
|---|---|
| Listing assumptions that are obviously safe | Pure filler — "we assume the network exists" wastes the slot a real assumption could fill |
| Confusing "most likely to fail" with "most catastrophic if fails" | These are different questions; the discipline is specifically about blast radius, not probability |
| Tests that aren't actually executable | "Verify with the team" is not a test; name the person, the dashboard, or the experiment |
| Only listing technical assumptions | Human and process assumptions (who's on call, who can approve a rollback) cause as many incidents as code does |
| Treating the audit as paperwork | If you finish without changing anything in the plan, you almost certainly skipped step 2 |
