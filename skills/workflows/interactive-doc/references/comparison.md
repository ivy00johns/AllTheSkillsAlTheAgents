# Side-by-Side Comparison

The doc you write when the user is choosing between approaches, or when they've borrowed ideas from multiple repos and want to see how they relate. The reader should be able to point at a column and say "that one, because of *this*" — instead of holding three sequential walls of text in their head.

## When this is the right pattern

- "Compare The Hive's orchestrator to MemPalace's memory architecture and FutureShow's prediction layer"
- "Should we build this on Temporal, Dask, or Ray?"
- "How does our agent dispatch differ from CrewAI's?"
- "What did we borrow from each of these repos and how does it fit together?"

If the user wants to *understand* a single approach, use concept-explainer. If they want to *map* their existing system, use architecture-map. Comparisons are about choosing or synthesizing, not learning or mapping.

## Structure

1. **Repos compared** header — the actual repo URLs / commit hashes if relevant
2. **TL;DR** — the bottom-line answer (which to pick, or what we took from each)
3. **The comparison table** — the headline, dense, immediately scannable
4. **Side-by-side detail** — typically a 2- or 3-column layout walking through key dimensions, one per row
5. **Where they overlap, where they diverge** — narrative section that the table can't capture
6. **What we borrowed (if applicable)** — the synthesis: which ideas came from where in the user's own work
7. **Tradeoffs honestly stated** — every option's failure mode

The comparison table near the top is load-bearing. If a reader closes the doc after just that, they should already have the answer. The rest is for people who need to defend the answer in a meeting.

## The headline comparison table

Same `.compare` styling as in concept-explainer. For repo comparisons, the dimensions usually include:

| Dimension | Why it matters |
|---|---|
| **Primary abstraction** | What's the unit of work? Tasks? Workflows? Actors? |
| **Coupling model** | How tightly coupled are the pieces? Function calls? Message passing? Contracts? |
| **State location** | Where does state live? In-memory? Persistent store? Distributed? |
| **Failure model** | What happens when a step fails? Retry? Compensate? Crash? |
| **Observability** | How do you see what's happening? Logs? UI? Traces? |
| **Where it shines** | The use case it's clearly best at |
| **Where it struggles** | The use case it's clearly worst at |

Pick the 5–7 dimensions that matter for *this* comparison. Don't pad — every row should be load-bearing.

## Side-by-side layout

CSS Grid is the right tool. Two or three equal columns, each repo gets one.

```html
<section class="sxs">
  <div class="sxs-row">
    <h3 class="sxs-row-title">Primary abstraction</h3>
    <div class="sxs-col">
      <h4>The Hive</h4>
      <p>SKILL.md contracts — agents are markdown files with frontmatter
      that the orchestrator reads at dispatch time.</p>
    </div>
    <div class="sxs-col">
      <h4>MemPalace</h4>
      <p>Memory shards — durable, addressable knowledge units that
      composers retrieve and assemble into context.</p>
    </div>
    <div class="sxs-col">
      <h4>FutureShow</h4>
      <p>Forecasting agents — specialized prediction modules with
      a shared signal bus.</p>
    </div>
  </div>
  <!-- more rows -->
</section>
```

```css
.sxs { margin: 2rem 0; }
.sxs-row {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr;  /* or 1fr 1fr for 2-up */
  gap: 1.5rem;
  padding: 1.5rem 0;
  border-top: 1px solid var(--rule);
}
.sxs-row-title {
  grid-column: 1 / -1;
  font-family: var(--sans);
  font-size: 0.85rem;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--muted);
  margin: 0 0 0.5rem;
  font-weight: 500;
}
.sxs-col h4 {
  font-family: var(--sans);
  font-size: 0.95rem;
  margin: 0 0 0.5rem;
  color: var(--accent);
}
.sxs-col p { margin: 0; font-size: 0.95rem; }

@media (max-width: 700px) {
  .sxs-row { grid-template-columns: 1fr; }
}
```

Color-code the columns. Each repo gets a layer color (`--layer-1`, `--layer-2`, `--layer-3`) and that color is used for its `<h4>` headers, any badges, and any architectural diagrams that include it. Consistent across the whole doc — the reader develops a muscle for "orange = Hive, blue = MemPalace."

## When to draw a unifying diagram

If the comparison is about systems that *could* coexist (or already do, in the user's work), draw a single diagram showing all three with their respective colors, with shared interfaces highlighted. This is the synthesis move — it makes "what we borrowed from each" visually obvious.

For purely choosing-between comparisons (Temporal vs Dask vs Ray for the same job), skip the unifying diagram and instead draw three small parallel diagrams showing how the same workflow looks in each. Same SVG style, same dimensions, just three repetitions. Visual rhyme makes the differences pop.

## "What we borrowed" section

When the user has synthesized ideas from multiple repos into their own work — which is exactly your Hive situation — this section is the most valuable in the doc. It's where the comparison stops being academic and becomes "here's what we built on top of these influences."

Pattern:

```html
<section id="borrowed">
  <h2>What we took from each</h2>

  <div class="borrowed-item">
    <span class="badge layer-1">from MemPalace</span>
    <h3>The "memory shard" abstraction</h3>
    <p>We adapted MemPalace's shard model for the Hive's context-assembly
    layer, but where MemPalace shards are durable knowledge, ours are
    ephemeral conversation summaries that age out.</p>
    <p class="files">In our code · <code>orchestrator/memory/shard.ts</code></p>
  </div>

  <div class="borrowed-item">
    <span class="badge layer-2">from FutureShow</span>
    <h3>The signal bus pattern for cross-agent comms</h3>
    <p>...</p>
  </div>
</section>
```

```css
.borrowed-item {
  border-left: 3px solid var(--accent);
  padding: 0.5rem 0 0.5rem 1rem;
  margin: 1.5rem 0;
}
.borrowed-item h3 { margin: 0.5rem 0 0.25rem; font-size: 1.1rem; }
.borrowed-item .files { margin-top: 0.5rem; border: none; padding: 0; }
```

Use the badge color of the source repo. This visually links the "what we took" item to its column in the side-by-side above.

## Tradeoffs section

Every option has a failure mode. Naming them honestly is what makes the doc trustworthy. Three short paragraphs (one per option) is usually enough — each one states the *worst case* for that option.

Don't hedge. "X struggles with Y" is more useful than "X may have some challenges in certain Y scenarios."

## Common gotchas

- **The comparison is loaded.** If you're recommending one option, say so up front — don't pretend to be neutral while the table secretly favors your pick. Honest framing: "We're comparing these because we're choosing between them. We picked The Hive's approach. Here's why, and here's where it costs us."
- **Apples to oranges dimensions.** "X has 30k stars, Y has 5k" is not a useful row. Stick to dimensions that actually affect how the system works in the user's context.
- **Too many options.** Three is the comfortable max for a side-by-side. Four works at a stretch. Five and the columns become unreadable on a laptop.
- **The diagrams don't visually rhyme.** If you're drawing the same workflow in three systems, lock the SVG dimensions, the box sizes, and the layout. Only the labels and connections should change.
- **No "borrowed from" section when there should be.** If the user is comparing repos they've drawn from, the synthesis is the point. Don't end at the comparison.

## What the .md looks like

For comparisons, markdown tables and callouts carry most of the substance — they translate cleanly. The HTML adds the side-by-side grid layout, the unifying diagram, and the color-coded "what we borrowed" cards.

```markdown
---
title: Hive vs MemPalace vs FutureShow — what we took and why
tags: [hive, comparison, mempalace, futureshow, agent-orchestration]
type: comparison
html: ./hive-vs-mempalace-vs-futureshow.html
date: 2026-05-09
sources: ["github.com/<user>/hive", "HKUDS/MemPalace", "HKUDS/FutureShow"]
related: ["[[hive-orchestrator]]", "[[mempalace-shard-model]]", "[[futureshow-signal-bus]]"]
---

# Hive vs MemPalace vs FutureShow — what we took and why

> [!tldr]
> All three are agent-orchestration systems but they optimize for
> different primary problems. We took MemPalace's shard model and
> FutureShow's signal bus, layered on top of SKILL.md contracts as
> our coordination primitive. The result: cheaper than MemPalace at
> runtime, more flexible than FutureShow's fixed agent roster.

## Headline comparison

| | The Hive | MemPalace | FutureShow |
|---|---|---|---|
| Primary abstraction | SKILL.md contracts | Memory shards | Forecasting agents |
| Coupling | Contract-based dispatch | Composer + shard retrieval | Shared signal bus |
| State location | Ephemeral + skill registry | Durable shard store | In-memory bus |
| Failure model | Skip agent, fall through | Shard recompute | Agent restart |
| Observability | Per-skill traces | Shard access logs | Bus replay |
| Where it shines | Heterogeneous agent roster | Long-context recall | Real-time forecasting |
| Where it struggles | Cold-start latency | Storage cost | Fixed agent roster |

## Side by side, dimension by dimension

### Primary abstraction

**The Hive** uses SKILL.md contracts — agents are markdown files with
frontmatter that the orchestrator reads at dispatch time...

**MemPalace** uses memory shards — durable, addressable knowledge units
that composers retrieve and assemble into context...

**FutureShow** uses forecasting agents — specialized prediction modules
with a shared signal bus...

### Coupling model

[same three-paragraph pattern]

### State location

[etc.]

## Where they overlap, where they diverge

[3 narrative paragraphs that the table can't capture — tone, philosophy,
where the projects' authors had different goals]

## What we borrowed from each

> [!example] From MemPalace — the memory shard abstraction
> We adapted MemPalace's shard model for the Hive's context-assembly
> layer. Where MemPalace shards are durable knowledge, ours are
> ephemeral conversation summaries that age out. Lives in
> `orchestrator/memory/shard.ts`.

> [!example] From FutureShow — the signal bus pattern
> [...]

## Tradeoffs we accept

The Hive's cold-start latency is real. When a SKILL.md hasn't been
parsed recently, the matcher does an extra read...

[honest paragraph per option]

## Where to read more

- [[hive-orchestrator]] — our system in detail
- [[skill-md-explainer]] — the contract primitive
- HKUDS/MemPalace paper — `arxiv.org/...`
- HKUDS/FutureShow — `github.com/HKUDS/FutureShow`
```

The HTML rendering of this:
- Headline table → `.compare` styled with bold "winner" cells where appropriate
- Side-by-side dimension sections → `.sxs-row` 3-column grid (one column per option, prose moves into the grid)
- Each option keeps a consistent `--layer-N` color throughout the doc — Hive orange, MemPalace blue, FutureShow purple. Headers, badges, and any unifying diagram all use these colors.
- `> [!example] From X — the Y pattern` → `.borrowed-item` card with the `.badge` colored by source repo
- Optional: a unifying diagram showing all three systems with shared interfaces highlighted
- Wiki links → resolved to sibling HTML files

The .md is typically 350-600 lines for a real comparison. The headline table is the dense entry point; the per-dimension sections carry the explanation.
