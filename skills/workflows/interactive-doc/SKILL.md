---
name: interactive-doc
version: 1.0.1
description: |
  Use this skill whenever the user wants rich documentation as a paired Obsidian-friendly markdown source plus an HTML companion built from it — the "unreasonable effectiveness of HTML" pattern with the .md as canonical source of truth. Two workflows: (A) render an existing research markdown file into an HTML companion (the .md stays read-only by default), or (B) create both files for a new doc, with the .md written first as the substantive source and the HTML derived from it. Trigger this for architecture deep-dives, module maps, concept explainers (interactive demos), side-by-side comparisons of repos or approaches, feature walkthroughs, and any time the user mentions "interactive doc", "wiki page", "Obsidian doc", "explainer", "render this research", "architecture diagram", "compare these repos", or wants documentation that goes beyond a markdown wall of text. Especially trigger when the user has done deep research in markdown and wants an HTML companion humans will actually read, or when they want a new doc that lives in their Obsidian vault but also has a beautiful rendered version. Output is always a pair: a fully-substantive `.md` (Obsidian-native: YAML frontmatter, wiki links, callouts, Mermaid diagrams) and a self-contained `.html` companion (inline SVG, collapsibles, tabs, on-page nav, optional interactive demos). One self-contained HTML file per doc, no build step, opens in a browser.
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash"]
metadata:
  category: workflows
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
composes_with: ["llm-wiki", "wiki-research", "docs-agent"]
spawned_by: []
---

# Interactive Doc

Pair an Obsidian-friendly markdown source with a self-contained HTML companion. The .md is the canonical source of truth — token-efficient, wiki-linkable, what other agents and tools consume. The HTML is the experience for humans who want to *read* it instead of *grep* it. Same content, two surfaces.

## The two workflows

This skill handles two distinct jobs. Identify which one applies before doing anything else.

### Workflow A — Render existing research

The user has an existing markdown file (often deep-research notes, an Obsidian vault page, or a long analysis) and wants an HTML companion. The .md is **canonical and read-only by default** — your job is to read it carefully and produce HTML that respects what's there. You may, however, **offer** to suggest edits to the .md if rendering reveals genuine gaps or contradictions; only make those edits if the user says yes.

Steps:
1. Read the source .md in full — frontmatter, body, links, embedded diagrams, the lot. Don't skim.
2. Identify the doc type (architecture map, concept explainer, comparison, or other) from the content. If unclear, ask.
3. Read `references/house-style.md` and the relevant doc-type reference.
4. Build the HTML as a faithful rendering: every section, callout, file ref, and link in the .md has a place in the HTML. Don't invent content the .md doesn't support.
5. If you noticed gaps while rendering (a diagram referenced but not shown, a section that ends mid-thought, a wiki-link to a note that doesn't exist), surface those at the end as "things I noticed" — don't silently fix them.
6. Save the HTML next to the source .md with the same slug.

### Workflow B — Create both, greenfield

The user wants a new doc. No source exists yet. Write the **.md first** as the substantive document, then derive the HTML from it.

Steps:
1. Establish what's being documented — concrete component names, file paths, real data. Generic examples produce generic docs; ask for specifics if they're missing.
2. Pick the doc type and read the relevant references plus `references/house-style.md` and `references/markdown-document.md`.
3. Write the .md as a real Obsidian-native document — YAML frontmatter, callout blocks, wiki links, Mermaid diagrams, file-referenced code blocks. Full prose. The .md should stand on its own.
4. Write the HTML from the .md. Every section in the HTML traces to a section in the .md. The HTML adds *experience* (interactivity, hand-SVG diagrams, color, layout) but never *content*.
5. Save both files with the same slug.

## The cardinal rule

> The .md is the source of truth. The HTML never adds content the .md doesn't have.

This isn't aesthetic — it's load-bearing. If the HTML ever drifts ahead of the .md, the .md stops being canonical and the system collapses into "two files that both half-document the same thing." When you find yourself wanting to add something to the HTML that isn't in the .md, the answer is to add it to the .md first and then render it.

The reverse asymmetry is allowed and expected: the .md can have content that the HTML *renders differently* (e.g. a Mermaid block becomes a hand-SVG; a list of `[[wiki-links]]` becomes a sidebar of cards; a fenced code block with a file path becomes a collapsible with a file:line badge). Same content, different rendering.

## Doc types supported

Three are first-class in v1. A fourth is supported but uses an existing pattern.

- **Architecture / module map** — boxes-and-arrows of how components talk, with hot paths highlighted and entry points listed. Reference: `references/architecture-map.md`.
- **Concept explainer** — a thing taught with a live interactive piece (a ring you can add nodes to, a state machine you can step through), plus comparison tables and a glossary. Reference: `references/concept-explainer.md`.
- **Side-by-side comparison** — two or three approaches/repos rendered next to each other, with a "what we borrowed from each" synthesis section. Reference: `references/comparison.md`.
- **Feature explainer** (TL;DR + collapsible step-through + tabbed code + FAQ) — supported but not first-class. Use the concept-explainer reference and drop the live demo.

If the user's request doesn't fit any of these, you can adapt the house style to other formats (a slide deck, a status report, a post-mortem) but flag the mismatch and confirm.

## File naming and location

Always paired, same slug:

```
docs/<topic-slug>.md
docs/<topic-slug>.html
```

In an Obsidian vault, the .md goes in the appropriate vault folder; the .html goes alongside it (Obsidian ignores it, vault tools tolerate it). For a project repo without a vault, default to a `docs/` folder.

## The Obsidian-native .md format

Detailed in `references/markdown-document.md`. Quick summary:

**YAML frontmatter** — at minimum `title`, `tags`, `type`, and `html` (path to companion):

```yaml
---
title: How the Hive orchestrator dispatches to agents
tags: [hive, architecture, orchestrator]
type: architecture-map
html: ./orchestrator-dispatch.html
date: 2026-05-09
---
```

**Wiki links** — `[[double-bracket]]` form throughout the .md. Obsidian resolves them; at HTML render time, you translate to plain `<a href>` anchors. A link `[[skill-md-explainer]]` becomes `<a href="./skill-md-explainer.html">SKILL.md explainer</a>` in the HTML.

**Obsidian callouts** — for TL;DRs, gotchas, asides:

```markdown
> [!tldr]
> The orchestrator builds a task envelope, picks an agent based on
> capability tags, and hands off via a SKILL.md contract.

> [!warning] Gotcha
> `burst` is bucket capacity, not rate.
```

These render natively in Obsidian and translate to the HTML's `.tldr` / `.callout` components.

**File-referenced code blocks** — fence with both language and path:

````markdown
```ts orchestrator/dispatch.ts:21
function dispatch(envelope: Envelope) { ... }
```
````

In the HTML, the path becomes a small badge under the code block.

**Mermaid for diagrams** — `mermaid` fenced blocks for diagrams in the .md. These render in Obsidian. The HTML uses **independent hand-SVG** drawn from the same concept — *not* auto-converted from the Mermaid, since the two serve different needs (Mermaid is for grep and quick render; hand-SVG is for the polished read).

## Diagram parity

This is the one place where "single source of truth" gets a careful exception. The .md has Mermaid; the HTML has hand-SVG. They depict the *same conceptual diagram* but are written independently.

Why both:
- Mermaid in the .md is essential for Obsidian rendering, grep-ability, and tools that ingest your vault.
- Hand-SVG in the HTML is what makes the rendered version feel handmade and not Mermaid-stamped.

The rule that keeps them honest: **same boxes, same connections, same labels, same colors**. If you change one, change the other in the same edit. The Mermaid is the contract; the hand-SVG is the artwork. They must agree on what they depict.

For Workflow A specifically: if the source .md has Mermaid diagrams, draw the hand-SVG to match exactly — same nodes, same edges. If the source .md has no diagrams but the architecture clearly needs one, surface that as a "noticed" gap and *ask* before adding. (The .md is read-only by default.)

## Workflow choreography in practice

### Workflow A walk-through

User: "Render this research doc as an interactive HTML." [attaches `hive-orchestrator-research.md`]

You:
1. Read the .md in full.
2. Note: it's an architecture deep-dive on the Hive orchestrator. Type → architecture-map.
3. Read `references/architecture-map.md` and `references/house-style.md`.
4. Build `hive-orchestrator-research.html` — every section in the .md becomes a section in the HTML, the Mermaid diagram becomes a hand-SVG of the same shape, file:line refs become badges, callouts become styled boxes, wiki links become anchors to sibling HTML files.
5. Surface any gaps: "I noticed the .md references a 'capability matcher' component but never defines it — want me to flag that as a follow-up, or leave the HTML as-is?"
6. Save next to the source.

### Workflow B walk-through

User: "Create a doc explaining how SKILL.md works as an operational contract."

You:
1. Confirm the substance — what does the user know about this? Where does it live in the code? What sources can you draw from? (Check past chats with `conversation_search` if it'd help.)
2. Pick type → concept explainer (it's pedagogical, wants a live demo).
3. Read references for concept-explainer, house-style, markdown-document.
4. Write `skill-md-as-contract.md` first — full prose, frontmatter, callouts, wiki links to `[[hive-orchestrator]]` and `[[agent-anatomy]]`, a Mermaid diagram of the dispatch flow, file-referenced code samples.
5. Write `skill-md-as-contract.html` — every section from the .md, the live SKILL.md editor demo (the experience the .md *describes* with a callout but can't *be*), hand-SVG of the same dispatch flow, comparison table, hover-glossary.
6. Save both.

## House style essentials (always apply)

Full reference in `references/house-style.md`. The non-negotiables:

- **Self-contained HTML.** One file. CSS in `<style>`, JS in `<script>`. CDN imports tolerable for charting libraries but prefer hand-written SVG. Works offline after first load.
- **CSS variables for theming.** Every color and font goes through a variable in `:root`. This is what holds the "loose house style" together.
- **Typography: serif body, sans UI, mono code.** System stacks. ~70ch measure for body.
- **Inline SVG over images.** The agent has a real pen — use it.
- **On-page nav at the top** for any doc longer than two screens.
- **The "Files read" / "Sources" header** above the H1, listing actual files this doc draws from. Credibility move.
- **Color-code by layer or status, not decoration.**

## Optional: index page

Once the user has 3+ docs, offer to generate `index.html` — a landing page linking all docs, grouped by type, with the same house style. Great for an Obsidian vault folder you want to share externally.

## Anti-patterns

- **HTML adding content the .md doesn't have.** Cardinal rule violation. Stop, add to .md first, then render.
- **Editing the source .md in Workflow A without permission.** Read-only by default. Surface gaps; don't silently patch them.
- **Mermaid and hand-SVG depicting different things.** Same boxes, same connections, same labels. Always.
- **Generic stock examples.** "Imagine a service that handles user authentication..." No. Use the user's actual repo, file paths, component names. Ask for specifics if missing.
- **Bootstrap / Tailwind / framework CSS.** These docs feel handmade and live forever in a repo. A 200-line `<style>` block beats 100KB of framework.
- **Diagrams as screenshots.** Always inline SVG.
- **Decoration over information.** Gradients, glassmorphism, animations that don't teach. Restrained on purpose.
- **Walls of text inside the HTML.** If a section has 3+ paragraphs in a row with no visual break, add a collapsible, tab, side-by-side, diagram, or callout.
- **Wiki links left as `[[double-brackets]]` in the HTML.** Translate at render time to `<a href="./<slug>.html">`. Falling back to the slug as link text is fine if there's no friendlier label.

## Reference files

Read these as needed — don't read all upfront:

- `references/house-style.md` — CSS tokens, components, typography, .md → HTML mapping (read every time)
- `references/markdown-document.md` — Obsidian-native .md conventions (read every time you write a .md)
- `references/architecture-map.md` — boxes-and-arrows pattern with SVG techniques (load when type = architecture-map)
- `references/concept-explainer.md` — interactive demo pattern with vanilla JS (load when type = concept-explainer)
- `references/comparison.md` — side-by-side pattern for repos/approaches (load when type = comparison)
