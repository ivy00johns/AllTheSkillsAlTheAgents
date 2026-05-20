---
name: claude-design-brief
version: 1.3.1
description: |
  Generate paste-ready prompts for Claude Design (the artifact / design-canvas tool at claude.ai, distinct from Claude Code) that are so specific and committed that Claude Design skips its Q&A loop and goes straight to building. Use this skill whenever the user wants to produce hi-fi design mockups, an interactive prototype, an artifact-based mockup canvas, multiple design directions on a canvas, or compare safe / bold / experimental directions inside Claude. Trigger on phrases like "build mockups in Claude Design", "design canvas prompt", "hi-fi design mockup", "interactive prototype in claude", "claude design prompt", "make me a mockup prompt", "I want directions A/B/C in claude", "stop letting claude design ask me 15 questions", "claude design keeps asking", "compare safe / bold / experimental", or "build me variations on a design canvas". Distinguish from `ui-brief`: ui-brief produces a long Markdown spec for Claude Code / a frontend agent to BUILD the production site; this skill produces a short paste-ready prompt for Claude Design's canvas to MOCK UP variations. Works for any product type — personal brand sites, advocacy sites, dashboards, marketing sites, portfolios.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash"]
composes_with: ["ui-brief", "superpowers:ui-ux-pro-max", "superpowers:frontend-design", "superpowers:brainstorming"]
spawned_by: []
---

# Claude Design Brief

> **Naming exception:** This skill's name starts with `claude-` — a prefix Anthropic reserves for first-party skills. Kept deliberately: the skill targets **Claude Design** specifically, and a name that doesn't say "claude" would be less discoverable. Per `skills/meta/skill-writer/references/frontmatter-spec.md`, `skill-review` WARNs but does not FAIL on this pattern when the skill genuinely targets the corresponding Anthropic product.

Produce paste-ready prompts for **Claude Design** (the artifact/design-canvas tool at claude.ai) that are vivid and project-specific enough that Claude Design has nothing left to ask — it opens its canvas and starts drawing on the first message.

The failure mode the skill exists to prevent: a prompt so vague that Claude Design interrogates scope, tone, palette, typography, hero, device, and a dozen other decisions one at a time. The fix is not to answer those questions in a labeled numbered list — it's to write a design brief dense enough with committed, specific opinion that the questions never arise. How you structure that brief should fit the project, not a template.

**Announce at start:** "Using claude-design-brief to write a paste-ready Claude Design prompt for [project]."

## Sibling vs Mode Selection

This skill is the sibling of `ui-brief` (which targets Claude Code / production builds, not the Claude Design canvas). It runs in either **with-brief mode** (a `UI-CHALLENGE.md` already exists — translate it) or **standalone mode** (research → Claude Design directly). See `references/usage-modes.md` for the full comparison table, hallmarks of each mode, what they share, and how the greenfield/rebuild axis layers on top.

## Coverage Guide — What Needs To Be In The Brief

These are the decisions Claude Design is likely to lack if you don't address them. Cover each one in whatever form fits the project — as prose, per-direction blocks, embedded in the opening framing, or wherever it lands most naturally. They do not need to be labeled or in any fixed order. The test is not "did I address all 13 categories by name" — it is "does this brief leave Claude Design nothing to ask."

| Decision area | What to commit |
|---|---|
| **Scope** | Which pages, what's explicitly out of scope |
| **Variations** | How many directions, what each leans into — must be orthogonally distinct |
| **Tone** | Register, voice, emotional weight — named with reference apps, not adjectives |
| **Palette** | Hex values per direction |
| **Typography** | Display + body + mono per direction, with **Google Fonts fallbacks** for any licensed family |
| **Hero** | Image-led / type-led / split — different per direction is good |
| **Live elements** | Explicit yes/no on tickers, counters, animated stats |
| **Photos** | Real, placeholder frames, or AI — commit and state the reason |
| **CTAs** | Donation / payment pattern, or explicit absence; newsletter pattern, or explicit absence |
| **Interactivity** | Nav scoping rule: Direction A routes only within Direction A's artboards |
| **Risks** | Decomposed by sub-risk (see `references/variation-and-risks.md`) — not a generic statement |
| **Device** | Primary viewport, secondary viewport policy |

Add anything project-specific that would otherwise become a question.

## Canvas Constraints, Variation Rubric, Risk Decomposition

Three load-bearing reference files. Read them before writing the prompt:

- `references/canvas-constraints.md` — the 7 non-obvious canvas runtime limits (licensed fonts, image URLs, animation, backends, nav scoping, artboard math, chat-vs-canvas split). Encode all 7 as defaults in every prompt.
- `references/variation-and-risks.md` — orthogonal-axes rubric for keeping directions distinct, plus the sub-risk decomposition table for the risk section.
- `references/direction-examples/` — worked examples of safe (`safe.md`), bold (`bold.md`), and experimental (`experimental.md`) directions.

## How To Run

### Step 1 — Discovery (2–4 minutes)

- **Read the source material.** Research doc, brand brief, prior site URL, brainstorm transcript.
- **Check for `UI-CHALLENGE.md`.** If it exists, you are in with-brief mode. If not, standalone.
- **Identify the moat** in one sentence.
- **Confirm scope and variations.** The two questions you cannot guess. If the user has not specified "4 pages, 3 directions" (or whatever), ask once. Everything else has reasonable defaults.
- **Identify named patterns the user has called out** (e.g., "ACU sticky donate", "Kyiv Independent newsletter band"). Quote them verbatim.
- **Note explicit user rejections.** Capture in the negative-references section.

### Step 2 — Decide The Defaults

When the user says "decide for me", **decide**. State the decision, explain the why in one clause. The canvas executes on commitments, not questions.

If you need help picking concrete palette/font values, **invoke `ui-ux-pro-max`** as a sub-step. Run before committing the per-direction palette and typography blocks.

### Step 3 — Apply The Variation Rubric

Sketch the directions on the orthogonal-axes table in `references/variation-and-risks.md`. If two directions land in the same cell on the same axis, change one.

### Step 4 — Write The Prompt

`references/prompt-template.md` shows one way to organize the sections — treat it as a reference for what sections tend to exist, not a form to fill in. The opening frame and canvas output spec have fixed load-bearing sentences (the "build immediately" directive and the artboard math) — everything in between should be shaped by what this project needs most.

**File location:** by default, write to `<repo-root>/CLAUDE-DESIGN-PROMPT.md`. If it already exists, name the next one `CLAUDE-DESIGN-PROMPT-v2.md`.

**Length:** 60–150 lines target. Hard ceiling 250. If past 200, you are probably duplicating `ui-brief` work — switch to with-brief mode and reference the brief.

### Step 5 — Verify Before Returning

- [ ] All coverage-guide decision areas addressed somewhere — not necessarily labeled, but present and committed.
- [ ] Per-direction palette and typography specified with concrete hex values and named font families with Google Fonts fallbacks.
- [ ] Directions vary on at least three orthogonal axes (per `references/variation-and-risks.md`), not just color.
- [ ] All 7 canvas constraints encoded (per `references/canvas-constraints.md`).
- [ ] Named patterns the user called out appear verbatim.
- [ ] Explicit user rejections appear in the negative-reference section.
- [ ] Risk section decomposed into 2–4 sub-risks (per `references/variation-and-risks.md`).
- [ ] "What to ship" section enumerates the artboard math and the chat-vs-canvas summary instruction.
- [ ] Source Material section: with-brief mode quotes 5–8 rules from `UI-CHALLENGE.md`; standalone mode summarizes or omits.
- [ ] Prompt is under 250 lines (60–150 ideal).

Then summarize for the user in 3–5 sentences: which answers were committed, where the prompt lives, what was deferred.

## Anti-Patterns and Composition

See `references/anti-patterns.md` for the 12 anti-patterns (decide-for-me echoed back, adjective-only tone, 13-slot form structure, three palettes of the same layout, missing font fallbacks, missing chat-vs-canvas instruction, cross-direction nav, generic risk framing, rebuilding `ui-brief` inline, omitting artboard math), how each is prevented, and how this skill composes with `ui-brief`, `brainstorming`, `ui-ux-pro-max`, and `frontend-design`. The output-file convention (self-contained, project-specific, decision-dense, paste-target friendly, canvas-aware) lives there too.

## Reference Files

- `references/usage-modes.md` — `ui-brief` vs this skill comparison; with-brief vs standalone mode; greenfield/rebuild axis
- `references/canvas-constraints.md` — 7 non-obvious canvas runtime limits to encode as defaults
- `references/variation-and-risks.md` — orthogonal-axes rubric and risk sub-risk decomposition
- `references/direction-examples/safe.md` — credible-default direction with worked "Navy Field" sample
- `references/direction-examples/bold.md` — leaned-in direction with worked "Blackout Dossier" sample
- `references/direction-examples/experimental.md` — swing-for-fence direction with worked "Bone & Olive" sample
- `references/anti-patterns.md` — the 12 anti-patterns and prevention rules, composition notes, output-file convention
- `references/prompt-template.md` — sample prompt structure (reference, not a form)

Worked examples live in `references/direction-examples/` — read the safe / bold / experimental files for the variation rubric in action, the four-axis distinct-direction discipline, and the per-direction font-fallback pattern.
