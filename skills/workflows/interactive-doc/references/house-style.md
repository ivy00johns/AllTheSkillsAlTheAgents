# House Style

Loose but coherent. Same tokens and components everywhere; layout is per-doc.

## Contents

- [.md → HTML translation rules](#md--html-translation-rules)
- [CSS variables (paste into every doc's `:root`)](#css-variables-paste-into-every-docs-root)
- [Typography](#typography)
- [Standard components](#standard-components)
  - [`.files` — the credibility header](#files--the-credibility-header)
  - [`.tldr` — the standing summary](#tldr--the-standing-summary)
  - [`.nav` — on-page nav strip](#nav--on-page-nav-strip)
  - [`<details>` — collapsibles for step-throughs](#details--collapsibles-for-step-throughs)
  - [`.tabs` — tabbed code examples](#tabs--tabbed-code-examples)
  - [`.badge` — layer / status pills](#badge--layer--status-pills)
  - [`.callout` — sidebar / aside](#callout--sidebar--aside)
- [Body skeleton](#body-skeleton)
- [What "loose" means](#what-loose-means)

## .md → HTML translation rules

The .md is the source. The HTML renders it. These are the translation rules — apply them mechanically when going from canonical markdown to the HTML companion:

| Source (.md) | Rendered (HTML) |
|---|---|
| Frontmatter `title` | `.kicker` (doc type) above the H1 + the H1 itself |
| Frontmatter `sources:` array | `.files` line above the H1 (file paths in `<code>`) |
| Frontmatter `status:` | A `.badge.status-X` near the H1 |
| Frontmatter `tags:` | (Not rendered — Obsidian-only metadata) |
| `> [!tldr]` | `.tldr` styled box |
| `> [!info]` / `> [!note]` | `.callout` (default) |
| `> [!warning]` | `.callout.warning` with accent ring |
| `> [!tip]` | `.callout.tip` |
| `> [!example]` | `.callout.example` — and if it describes a demo, the actual interactive demo lives here in the HTML |
| `> [!todo]` | `.callout.todo` (visually de-emphasized) |
| `[[slug]]` | `<a href="./slug.html">slug</a>` (or `class="dangling"` if target doesn't exist) |
| `[[slug\|label]]` | `<a href="./slug.html">label</a>` |
| `[[slug#heading]]` | `<a href="./slug.html#heading-anchor">slug › heading</a>` |
| ` ```ts path/file.ts:21 ` | `<pre><code>` with a small file-path badge above |
| ` ```mermaid ` | Hand-drawn SVG of the *same diagram*, written independently — same nodes, same edges, same colors |
| H2 sections | Anchor IDs + on-page `.nav` strip entries |
| Standard tables | `.compare` styled tables |
| Plain prose | Plain prose |

The HTML may **add** structural rendering choices the .md doesn't dictate (a 3-column `.sxs` grid for comparisons, a `.borrowed-item` card for `> [!example]` blocks in comparison docs, hover-glossary `<dfn>` for terms used multiple times, click-to-detail anchors on diagram nodes). These are *renderings*, not new content.

The HTML must **never** add content the .md lacks. If the rendering reveals a gap, surface it; don't silently fill it.

## CSS variables (paste into every doc's `:root`)

```css
:root {
  /* surfaces */
  --bg: #fafaf7;          /* page background — warm off-white */
  --surface: #ffffff;     /* cards, demo boxes */
  --rule: #e5e5e0;        /* borders, dividers */

  /* text */
  --fg: #1a1a1a;
  --muted: #666666;
  --faint: #999999;

  /* accents — semantic, not decorative */
  --accent: #c2410c;      /* primary highlight (warm orange) */
  --accent-soft: #fef3ec; /* accent backgrounds */
  --link: #0c4ec2;        /* links — only when they need to look like links */

  /* layer / status colors — assign per-doc, here are defaults */
  --layer-1: #c2410c;     /* orchestrator / primary layer */
  --layer-2: #0c8aa8;     /* agents / second layer */
  --layer-3: #6b6f1d;     /* skills / third layer */
  --layer-4: #8a3a99;     /* infra / fourth layer */

  --status-stable: #1d6f40;
  --status-experimental: #c08a1d;
  --status-deprecated: #8a8a8a;

  /* typography */
  --serif: ui-serif, Georgia, "Iowan Old Style", serif;
  --sans: ui-sans-serif, system-ui, -apple-system, sans-serif;
  --mono: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg: #16161a;
    --surface: #1f1f24;
    --rule: #2e2e34;
    --fg: #e8e8e2;
    --muted: #9a9a92;
    --faint: #6a6a62;
    --accent: #ff7a47;
    --accent-soft: #2a1d14;
    --link: #6ea8ff;
  }
}
```

Dark mode is opt-in per doc — don't include the `@media` block if the doc is intentionally light-only (e.g. a printed-feeling reference). For most project docs, default to including it.

## Typography

- Body: `var(--serif)`, `line-height: 1.6`, `max-width: 70ch`. Long-form reading.
- UI chrome (nav, buttons, file refs, captions, badges): `var(--sans)`, smaller (`0.85–0.9rem`), often `var(--muted)`.
- Code: `var(--mono)`, slight background tint (`#efece4` light, `#2a2a30` dark), 1–2px padding for inline.
- Headings: serif, `font-weight: 500` (not bold). The pattern is restrained — bold serif headings look heavy and dated.

## Standard components

These are the Lego pieces every doc draws from. Copy and adapt; the class names are conventional so docs feel related.

### `.files` — the credibility header

Always at the top, above the H1. Lists the actual files this doc draws from.

```html
<p class="files">Files read · <code>orchestrator/dispatch.ts</code> · <code>agents/qe-agent/SKILL.md</code></p>
```

```css
.files {
  font-family: var(--sans);
  font-size: 0.85rem;
  color: var(--muted);
  border-bottom: 1px solid var(--rule);
  padding-bottom: 0.5rem;
  margin-bottom: 1rem;
}
.files code {
  font-family: var(--mono);
  background: var(--accent-soft);
  padding: 1px 6px;
  border-radius: 3px;
  color: var(--fg);
}
```

For comparison docs, swap "Files read" for "Repos compared". For concept explainers, "Sources" with links.

### `.tldr` — the standing summary

Right after the H1. One paragraph. The reader should be able to stop here and have the gist.

```html
<div class="tldr">
  <strong>TL;DR</strong> — One sentence stating the thing. One more sentence
  giving the load-bearing detail. Stop.
</div>
```

```css
.tldr {
  background: var(--surface);
  border-left: 3px solid var(--accent);
  padding: 1rem 1.25rem;
  margin: 1.5rem 0;
  font-size: 1.05rem;
}
.tldr strong { color: var(--accent); }
```

### `.nav` — on-page nav strip

For docs longer than two screens. Horizontal row of small links to anchors, optionally with item counts (thariq's pattern).

```html
<nav class="nav">
  <a href="#overview">Overview</a>
  <a href="#dispatch">Dispatch <span>4</span></a>
  <a href="#contract">Handoff contract</a>
  <a href="#failures">Failure modes <span>3</span></a>
</nav>
```

```css
.nav {
  font-family: var(--sans);
  font-size: 0.9rem;
  display: flex;
  flex-wrap: wrap;
  gap: 1.25rem;
  margin: 1.5rem 0 2.5rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid var(--rule);
}
.nav a { color: var(--muted); text-decoration: none; }
.nav a:hover { color: var(--fg); }
.nav a span {
  font-size: 0.75rem;
  background: var(--accent-soft);
  color: var(--accent);
  padding: 1px 6px;
  border-radius: 8px;
  margin-left: 4px;
}
```

### `<details>` — collapsibles for step-throughs

Use the native element. Don't reinvent it with JS.

```html
<details open>
  <summary><strong>1 · Identify the caller</strong> <code>orchestrator/dispatch.ts:21</code></summary>
  <p>Body text explaining this step.</p>
</details>
```

```css
details {
  border: 1px solid var(--rule);
  border-radius: 4px;
  padding: 0.75rem 1rem;
  margin: 0.75rem 0;
  background: var(--surface);
}
details summary {
  cursor: pointer;
  font-family: var(--sans);
  list-style: none;
}
details summary::-webkit-details-marker { display: none; }
details summary::before {
  content: "▸ ";
  color: var(--accent);
  display: inline-block;
  transition: transform 0.15s;
}
details[open] summary::before { content: "▾ "; }
details summary code {
  font-size: 0.85rem;
  color: var(--muted);
  margin-left: 0.5rem;
}
```

Open the first one by default so the reader sees the structure.

### `.tabs` — tabbed code examples

For "the same thing in three forms" (e.g. config, code, response). Pure CSS using radio inputs — no JS.

```html
<div class="tabs">
  <input type="radio" name="t1" id="t1a" checked><label for="t1a">limits.yaml</label>
  <input type="radio" name="t1" id="t1b"><label for="t1b">route.ts</label>
  <input type="radio" name="t1" id="t1c"><label for="t1c">response</label>
  <div class="panel" data-for="t1a"><pre><code># yaml here</code></pre></div>
  <div class="panel" data-for="t1b"><pre><code>// ts here</code></pre></div>
  <div class="panel" data-for="t1c"><pre><code>HTTP/1.1 429</code></pre></div>
</div>
```

```css
.tabs { display: grid; grid-template-columns: auto 1fr; margin: 1rem 0; }
.tabs input { display: none; }
.tabs label {
  font-family: var(--sans);
  font-size: 0.85rem;
  padding: 0.4rem 0.9rem;
  border: 1px solid var(--rule);
  border-bottom: none;
  background: var(--bg);
  cursor: pointer;
  margin-right: -1px;
  grid-row: 1;
}
.tabs input:checked + label { background: var(--surface); font-weight: 500; }
.tabs .panel { display: none; grid-row: 2; grid-column: 1 / -1;
               border: 1px solid var(--rule); padding: 1rem; background: var(--surface); }
.tabs input:nth-of-type(1):checked ~ .panel[data-for$="a"],
.tabs input:nth-of-type(2):checked ~ .panel[data-for$="b"],
.tabs input:nth-of-type(3):checked ~ .panel[data-for$="c"] { display: block; }
```

(For more than 3 tabs, use a tiny JS handler; the CSS-only version gets ugly past 3.)

### `.badge` — layer / status pills

Small, sans, lowercase. Always paired with a CSS variable so swapping the palette restains everything.

```html
<span class="badge layer-1">orchestrator</span>
<span class="badge status-experimental">experimental</span>
```

```css
.badge {
  font-family: var(--sans);
  font-size: 0.7rem;
  padding: 1px 7px;
  border-radius: 8px;
  text-transform: lowercase;
  letter-spacing: 0.02em;
  vertical-align: middle;
  border: 1px solid currentColor;
}
.badge.layer-1 { color: var(--layer-1); }
.badge.layer-2 { color: var(--layer-2); }
.badge.layer-3 { color: var(--layer-3); }
.badge.layer-4 { color: var(--layer-4); }
.badge.status-stable { color: var(--status-stable); }
.badge.status-experimental { color: var(--status-experimental); }
.badge.status-deprecated { color: var(--status-deprecated); }
```

### `.callout` — sidebar / aside

For gotchas, tips, warnings. Subdued — the reader should notice it but not be stopped by it. Variants map directly to Obsidian callout types.

```html
<aside class="callout">
  <strong>Note</strong> — generic info or aside.
</aside>

<aside class="callout warning">
  <strong>Gotcha</strong> — <code>burst</code> is bucket capacity, not rate.
</aside>

<aside class="callout tip">
  <strong>Tip</strong> — define route handlers next to their config.
</aside>

<aside class="callout example">
  <strong>Live demo</strong> — the actual interactive demo embeds here.
</aside>

<aside class="callout todo">
  <strong>TODO</strong> — capability matcher needs its own deep-dive.
</aside>
```

```css
.callout {
  background: var(--accent-soft);
  border-radius: 4px;
  padding: 0.75rem 1rem;
  margin: 1rem 0;
  font-size: 0.95rem;
  border-left: 3px solid var(--accent);
}
.callout.warning {
  background: #fef3ec;
  border-left-color: var(--status-experimental);
}
.callout.tip {
  background: #ecf5ee;
  border-left-color: var(--status-stable);
}
.callout.example {
  background: var(--surface);
  border: 1px solid var(--rule);
  border-left: 3px solid var(--accent);
}
.callout.todo {
  background: transparent;
  border: 1px dashed var(--rule);
  border-left: 3px dashed var(--muted);
  color: var(--muted);
}

@media (prefers-color-scheme: dark) {
  .callout.warning { background: #2a1d14; }
  .callout.tip { background: #142a1d; }
}
```

The `.example` callout is special: in the rendered HTML, if its content describes an interactive demo, the actual demo replaces the callout text. The .md says "live demo: edit a SKILL.md, see how Claude routes to it"; the HTML at that position is the working editor.

## Body skeleton

Every doc body starts roughly like this:

```html
<body>
  <p class="files">Files read · <code>...</code></p>
  <p class="kicker">Architecture · {project-name}</p>   <!-- doc-type kicker, optional -->
  <h1>The actual title</h1>
  <div class="tldr">...</div>
  <nav class="nav">...</nav>
  <!-- sections with anchor IDs matching the nav -->
</body>
```

```css
body {
  font-family: var(--serif);
  background: var(--bg);
  color: var(--fg);
  max-width: 70ch;
  margin: 3rem auto;
  padding: 0 1.5rem;
  line-height: 1.6;
}
.kicker {
  font-family: var(--sans);
  font-size: 0.8rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--muted);
  margin: 0.5rem 0 0;
}
h1 { font-weight: 500; font-size: 2rem; margin: 0.5rem 0 1rem; }
h2 { font-weight: 500; margin-top: 2.5rem; padding-top: 0.5rem;
     border-top: 1px solid var(--rule); }
h3 { font-weight: 500; font-size: 1.1rem; margin-top: 1.5rem; }
a { color: var(--link); text-decoration: underline; text-underline-offset: 2px; }
```

For docs heavy on diagrams (architecture maps especially), bump `max-width` to `90ch` or even drop it for full-width sections — the SVG needs room to breathe.

## What "loose" means

- ✅ Use the variables. Use `--accent` for the primary highlight in every doc.
- ✅ Use the components when they fit. `<details>` for step-throughs, `.tabs` for parallel views, `.badge` for categorization.
- ✅ Override variables for a specific doc's needs (e.g. a comparison doc might want three accent colors instead of one).
- ❌ Don't switch font stacks per doc. Serif body, sans UI, mono code. Stable.
- ❌ Don't reach for a CSS framework. The whole point is the handmade feel.
- ❌ Don't add gradients or glassmorphism unless they're communicating something (e.g. depth in a layered architecture diagram). Decoration is the enemy.
