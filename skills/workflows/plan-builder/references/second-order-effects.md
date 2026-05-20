# Second-Order Effects

A discipline for mapping consequences beyond the obvious first move when planning. Most planning stops at first-order effects ("we ship X, X happens") and misses the dynamics that actually determine whether the plan works in month two.

## When to Use

Invoke in `plan-builder` for any plan affecting systems beyond roughly 30 days — product launches, pricing changes, architectural migrations, team restructures, anything that has time to ripple. Also useful in brainstorming when stuck on first-order framing ("we'll just ship it and see").

Skip for plans where the change is fully reversible within a sprint and the blast radius is one team.

## The 5-Step Process

Work through these in order. Steps 2 and 3 are where the leverage lives — most teams over-invest in step 1 and never reach step 5.

### 1. First-order effects (3 bullets)

The immediate, obvious consequences. **What everyone sees coming.** The reason someone is proposing the plan in the first place.

### 2. Second-order effects (3 bullets)

The consequences of the first-order effects. **What happens after what happens.** Spend more time here than on first-order. Useful prompt: "Given the first-order effect lands as expected, how do users, competitors, employees, and adjacent systems then *respond*?"

### 3. Third-order effects (2 bullets)

The consequences of the second-order effects. **Where things get unpredictable** — but where the surprises that kill the plan tend to live. You can't enumerate everything, so name the two effects that feel most consequential, not most likely.

### 4. The unintended consequence (1 sentence)

The one outcome **nobody is planning for** that is most likely to emerge from this. Must be specific. "There could be unforeseen effects" doesn't count — name the specific thing.

### 5. The feedback loop (1 sentence)

The dynamic where an effect circles back and **amplifies or undermines the original decision**. This is the most strategically important output of the discipline — feedback loops are why plans that look good on a whiteboard go sideways in production.

## Worked Example

Plan: "Add a 1,000-message-per-month cap to the free tier of our chat product."

1. **First-order effects:**
   - Revenue protection — heavy free users now hit a wall.
   - Reduced infra cost on free-tier abuse.
   - Cleaner conversion funnel from free → paid.
2. **Second-order effects:**
   - Heavy users split into two streams: a minority upgrades; the majority churns to free competitors.
   - Power users — the loudest voice in the community — feel "punished for using the product."
   - Support load shifts from infra complaints to billing complaints.
3. **Third-order effects:**
   - Community sentiment turns: the product gets labeled "the one that nickels-and-dimes you," which raises CAC for paid acquisition.
   - The newly-paid cohort starts demanding premium features ("I'm paying now, where's the value") that didn't exist in the roadmap.
4. **Unintended consequence:** A small group of churned power users builds an open-source competitor specifically positioned against the cap, and it gains traction precisely because the cap created a narrative anchor.
5. **Feedback loop:** Upgraded users demand features to justify their new spend → roadmap shifts toward paid-tier feature work → free tier stagnates → free → paid conversion drops because the free tier is no longer compelling → revenue pressure increases → the team is tempted to *tighten* the cap further, deepening the loop.

## Anti-Patterns

| Anti-Pattern | Why It Fails |
|---|---|
| Stopping at first-order | The bias the discipline is explicitly designed to break; if your output is just "ship it, revenue goes up" you skipped steps 2–5 |
| Listing risks instead of consequences | A risk is "this might not work"; a consequence is "if this works, here is what then happens." Risks belong in a risk register, not here |
| Generic feedback loops not specific to this decision | "Users might react negatively" applies to every plan ever written. Name the actual loop in this product, with this user base, this quarter |
| Treating the unintended consequence as a disclaimer | "There may be unforeseen impacts" is the absence of the discipline, not the application of it. Name a specific outcome |
| Over-claiming certainty on third-order | These are deliberately speculative — the value is in naming candidates worth watching, not predicting the future |
