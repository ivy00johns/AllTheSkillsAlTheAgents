# Architecture / Module Map

The doc you write when someone asks "how does this system fit together?" The reader should be able to point at a box and say "that's the orchestrator" within 5 seconds, then drill in for the details.

## When this is the right pattern

- "How does The Hive work?"
- "Show me how the orchestrator hands off to qe-agent"
- "Map out the AI-Hub microservices and how they talk"
- "How does this unfamiliar repo fit together?" (onboarding)

If the user wants to *teach* a concept (with a live demo), use the concept-explainer pattern instead. If they want to *compare* approaches, use the comparison pattern. Architecture maps are about spatial structure, not pedagogy.

## Structure

A typical architecture doc has these sections, in this order:

1. **Files read** header — the credibility move
2. **TL;DR** — what the system does in one paragraph
3. **The map** — the headline diagram, full-width, the thing the reader scrolls back to
4. **Components** — one section per box, in order of importance (entry points first)
5. **Data flow / hot path** — a request traced end-to-end through the boxes
6. **Failure modes** — what happens when each component fails
7. **Where things live** — a table mapping component → file path

The "components" sections are the bulk of the doc. Each one has: a one-line summary, what it owns, what it talks to, and (often) a smaller diagram zooming in.

## SVG techniques for the map (HTML side)

Hand-write the SVG for the HTML companion. The .md uses Mermaid for the same diagram (see `markdown-document.md`); the HTML uses bespoke SVG so the rendered version doesn't look Mermaid-stamped. Same boxes, same connections, same labels, same colors — independent depictions of the same conceptual diagram.

### Boxes and arrows — the basic vocabulary

```html
<svg viewBox="0 0 800 400" class="map" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5"
            markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="var(--muted)"/>
    </marker>
  </defs>

  <!-- a box -->
  <g class="node layer-1" transform="translate(50, 50)">
    <rect width="160" height="60" rx="4" fill="var(--surface)"
          stroke="currentColor" stroke-width="1.5"/>
    <text x="80" y="28" text-anchor="middle" font-family="var(--sans)"
          font-size="14" font-weight="500" fill="var(--fg)">Orchestrator</text>
    <text x="80" y="46" text-anchor="middle" font-family="var(--sans)"
          font-size="11" fill="var(--muted)">routes &amp; dispatches</text>
  </g>

  <!-- another box -->
  <g class="node layer-2" transform="translate(330, 50)">
    <rect width="160" height="60" rx="4" fill="var(--surface)"
          stroke="currentColor" stroke-width="1.5"/>
    <text x="80" y="35" text-anchor="middle" font-family="var(--sans)"
          font-size="14" font-weight="500" fill="var(--fg)">qe-agent</text>
  </g>

  <!-- arrow between them -->
  <line x1="210" y1="80" x2="330" y2="80"
        stroke="var(--muted)" stroke-width="1.5" marker-end="url(#arrow)"/>
  <text x="270" y="72" text-anchor="middle" font-family="var(--sans)"
        font-size="11" fill="var(--muted)">SKILL.md handoff</text>
</svg>
```

```css
.map { width: 100%; height: auto; margin: 1.5rem 0; }
.map .node { cursor: default; }
.map .node.layer-1 { color: var(--layer-1); }
.map .node.layer-2 { color: var(--layer-2); }
.map .node.layer-3 { color: var(--layer-3); }
.map .node.layer-4 { color: var(--layer-4); }
.map .node:hover rect { fill: var(--accent-soft); }
```

The `currentColor` trick lets the box stroke take on the layer color via the parent `<g>`'s `color` (set by the `.layer-N` class). This is what makes the loose house style cohere — every diagram across every doc uses the same layer palette.

### Hot path highlighting

For data-flow diagrams, draw the path the request takes in `--accent`, and de-emphasize everything else.

```html
<line x1="..." y1="..." x2="..." y2="..." class="hot-path"
      marker-end="url(#arrow-hot)"/>
<line x1="..." y1="..." x2="..." y2="..." class="cold-path"/>
```

```css
.hot-path { stroke: var(--accent); stroke-width: 2; }
.cold-path { stroke: var(--rule); stroke-width: 1; stroke-dasharray: 3 3; }
```

Define a second arrowhead marker (`arrow-hot`) using `--accent` so the heads match.

### Click-to-detail interaction

Optional but lovely. Wrap each box in `<a href="#component-name">` (just the inline anchor) so clicking the diagram jumps to that component's section. No JS needed.

```html
<a href="#qe-agent" xlink:href="#qe-agent">
  <g class="node layer-2" transform="translate(330, 50)">
    ...
  </g>
</a>
```

For richer interactions (highlighting connected boxes on hover, filtering by layer), a tiny script:

```html
<script>
  document.querySelectorAll('.map .node').forEach(node => {
    node.addEventListener('mouseenter', () => {
      const layer = [...node.classList].find(c => c.startsWith('layer-'));
      document.querySelectorAll('.map .node').forEach(n => {
        n.style.opacity = n.classList.contains(layer) ? '1' : '0.3';
      });
    });
    node.addEventListener('mouseleave', () => {
      document.querySelectorAll('.map .node').forEach(n => n.style.opacity = '1');
    });
  });
</script>
```

## Common gotchas in architecture docs

- **Too many boxes.** If your top-level map has more than 8–10 boxes, it's a system map, not an architecture map. Group sub-components into a parent box and detail them in a zoomed sub-diagram below.
- **Direction matters.** Arrows should match data flow, not call direction. If a service *publishes* events that another service *consumes*, the arrow points to the consumer. If it's a synchronous call/response, draw two arrows or a double-headed one.
- **Layout meaning.** Vertical = layers (orchestrator on top, infra at the bottom). Horizontal = peers / time. Mixing these confuses readers.
- **Over-labeling.** Every box doesn't need a description sub-line. Use them for the boxes whose names are ambiguous; let the rest speak for themselves.
- **Forgetting the legend.** If you use layer colors, include a tiny legend at the top of the map.

## What the .md looks like

The canonical .md for an architecture map is a real document — full prose, Mermaid for the headline diagram, callouts for gotchas, file-referenced code blocks, wiki links to related docs. The HTML renders this; it doesn't replace it.

```markdown
---
title: How the Hive orchestrator dispatches to agents
tags: [hive, architecture, orchestrator]
type: architecture-map
html: ./orchestrator-dispatch.html
date: 2026-05-09
sources: ["orchestrator/dispatch.ts", "agents/manifest.json", "agents/qe-agent/SKILL.md"]
status: stable
related: ["[[skill-md-explainer]]", "[[capability-matcher]]"]
---

# How the Hive orchestrator dispatches to agents

> [!tldr]
> The orchestrator builds a task envelope, resolves it to an agent via
> the capability matcher reading the agent manifest, and hands off
> through the agent's SKILL.md contract.

## The map

```mermaid
flowchart LR
  prompt[User Prompt] --> orch[Orchestrator]
  orch --> matcher[Capability Matcher]
  matcher --> registry[Agent Registry]
  registry --> agent[Selected Agent]
  classDef layer1 stroke:#c2410c
  classDef layer2 stroke:#0c8aa8
  class orch,matcher layer1
  class registry,agent layer2
```

The orchestrator and matcher are dispatch-layer; the registry and agents
are catalog-layer.

## Components

### Orchestrator

The orchestrator's job is small: turn a prompt into an envelope, ask the
matcher for an agent, invoke it. It owns no domain logic.

```ts orchestrator/dispatch.ts:21
function dispatch(envelope: Envelope) {
  const agent = matcher.find(envelope.capability);
  if (!agent) throw new NoMatchError(envelope);
  return agent.invoke(envelope);
}
```

### Capability matcher

[prose, code refs]

### Agent registry

[prose, code refs]

> [!warning] Gotcha
> Agents registered after the orchestrator boots aren't visible until
> the next manifest reload. This bit us during the [[hive-hot-reload]] work.

## A request, end to end

[Mermaid sequenceDiagram or another flowchart]

[Numbered prose steps with `code/path:line` references inline]

## Failure modes

[Table: failure mode / what happens / how to recover]

## Where things live

[Table: component / file path / owner]
```

The HTML rendering of this:
- Frontmatter title → kicker + H1
- TL;DR callout → `.tldr` styled box
- Mermaid map → hand-SVG with `.layer-1` / `.layer-2` colored boxes, click-to-detail
- `> [!warning]` → `.callout.warning`
- File-referenced code blocks → `<pre>` with file-path badge
- Wiki links → `<a href="./<slug>.html">` (or `class="dangling"` if the target doesn't exist yet)
- Component sections → on-page nav entries; the H2 anchors match the nav links
- Failure modes table → 3-column CSS grid
- File-path table → standard table with `.compare` styling

The .md is ~250-400 lines for a real architecture map. The HTML is roughly the same scale.
