# Claude Design Prompt — Structural Skeleton

This is the shape of the paste-ready prompt the skill produces. **It is not a fill-in-the-blank template.** Every section needs project-specific opinion density. Generic outputs trigger Claude Design's clarifying-question loop — the whole point of this skill is to skip that loop.

The output goes into a single Markdown file (default: `<repo-root>/CLAUDE-DESIGN-PROMPT.md`) that the user pastes into a fresh Claude Design conversation at claude.ai. Claude Design then opens its design canvas and starts producing artboards.

Length target: **60–150 lines.** Hard ceiling: 250 lines. If you're past 200 lines you are probably duplicating `ui-brief` work — switch to with-brief mode and reference the brief instead.

The skill body's **Two Modes**, **Canvas Constraints**, **Variation Rubric**, and **Risk Decomposition** sections are what fill the template with real opinion. Read them before composing the prompt.

---

## Section 1 — Opening Frame

```markdown
# [PROJECT NAME] — Design Canvas Brief

You are designing **[N] direction(s) × [M] page(s) = [N×M] artboards (+ 1 title card = X+1 frames total)** as hi-fi mockups on a Claude Design canvas. Build the canvas immediately — do not ask clarifying questions. Every decision below is committed.

**The product:** [one paragraph describing what it is and who it's for, anchored to the moat].

**The thesis:** [one sentence on what the design must make obvious in the first 2 seconds].
```

Length: 4–7 lines. The opening sentence ("Build the canvas immediately — do not ask clarifying questions") is load-bearing — it tells Claude Design to skip its question loop. The artboard math is also load-bearing — it tells the canvas how to lay itself out.

---

## Section 2 — The Design Commitment

This section carries the load. Write it to fit the project — there is no required structure, no required order, no required labels. The goal is a block of prose and per-direction specs dense enough that Claude Design has nothing left to ask.

**What needs to land somewhere in this section** (not necessarily in this order, not necessarily with these labels):

- Scope: which pages, what's explicitly out of scope
- Directions: how many, what each leans into — must vary on layout × register × treatment × color (see Variation Rubric in SKILL.md), not just color
- Tone and register — named with reference apps, not adjectives
- Palette per direction — hex values: bg, type, accent, CTA, alert
- Typography per direction — display + body + mono, with **Google Fonts fallbacks** for any licensed family
- Hero treatment per direction — image-led / type-led / split
- Live elements — explicit yes/no on tickers/counters, with reason
- Photos — real, placeholder frames, or AI; no external image URLs (canvas can't fetch them)
- CTAs — donation/payment pattern or explicit absence; newsletter pattern or explicit absence
- Interactivity — nav scoping rule: Direction A's nav routes only within Direction A's artboards
- Risks — decomposed by sub-risk (see SKILL.md Risk Decomposition), not generic
- Device — primary viewport, secondary viewport policy

**How to structure it** depends on the project. Some projects want per-direction blocks grouping palette + typography + hero for each direction. Others work better with tone and register in the opening paragraph, a palette table, then per-page specs. A minimal two-direction product brief might fold all of this into one tight section. A complex advocacy site with sensitive identity questions might need risk framing up front. Read the project first.

**The one fixed rule:** concrete values only. `Söhne (fallback: Inter)` — not "a clean grotesque." `bg #1a1a1a, type #f5f0e8, accent #e63946` — not "dark with a warm accent." Named patterns (`ACU sticky donate model`, `Kyiv Independent newsletter band`) — not "a prominent CTA." Vague language is what triggers the question loop this brief is meant to prevent.

Length: 30–60 lines. Every line should be a committed decision, not a placeholder.

---

## Section 3 — Reference Language (Positive + Negative)

```markdown
## Reference Language

**Take from:**
- **[App / brand 1]** — [the specific aspect — typography, density, hero pattern, color discipline].
- **[App / brand 2]** — [a *different* aspect].
- **[App / brand 3]** — [a third aspect].

**Actively avoid:**
- **[Failure mode 1]** — [why specifically this is wrong for this product].
- **[Failure mode 2]** — [why].
- **[Failure mode 3]** — [why].
- **Day counters, live tickers, animated combat clocks, deployment timers** (or whatever the user explicitly rejected — list rejections by name so they can't drift back as different gimmicks).
```

Length: ~12 lines. Negative references are at least as load-bearing as positive ones. Surface user rejections explicitly.

---

## Section 4 — Page-by-Page Frame Spec

For each page in the scope, a tight 30–60 word brief:

```markdown
## Page Frames (apply to all directions)

### `/[route]` — [purpose]
**Above the fold:** [what's there — header strip, hero treatment, primary CTAs].
**Below the fold:** [secondary content — feed, grid, embed].
**Excludes:** [explicit list of what does NOT belong on this page].

[Repeat for each page in scope.]
```

Length: 30–60 words per page × N pages. For a 4-page scope this section is ~120–240 words.

---

## Section 5 — Canvas Output Spec

The instruction Claude Design needs to ship the right artifact. **All four sub-rules below are defaults — include every one of them in the prompt.**

```markdown
## What To Ship

Build a single HTML artifact on a design canvas containing **[N] directions × [M] pages = [N×M] artboards plus 1 title card = [N×M+1] frames total.** Layout the canvas as:

- A **title card** on the left with the project name, the [N] direction names, and a one-sentence "what each direction leans into" for each. The title card is the only place cross-direction navigation belongs.
- Direction A's [M] artboards in a row (route 1 → route 2 → route 3 → route 4), then Direction B's row, then Direction C's row. Each artboard labeled with its direction name and route in the corner.
- Inside each direction, the nav links between the [M] artboards are **clickable**. **Direction A's nav stays within Direction A's artboards** — never routes to Direction B or C from inside an artboard.
- Realistic hover states on every header nav link, every CTA, every card or row.
- Caption frames for every photo slot in monospace, describing what should land there. No external image URLs (the canvas runtime cannot fetch them).
- Sticky CTAs (Donate, Take Action, etc.) rendered on every artboard at the correct top-right position.

After building, output a brief in the chat (not on the canvas) summarizing:
- What you leaned into for each of the [N] directions and why.
- Open questions for the user before the next pass.
- What was scoped out and deferred (other pages, other viewports, real photography pass).
```

Length: ~14–20 lines. The chat-vs-canvas summary instruction is non-negotiable — without it the recap either gets buried on the canvas or skipped entirely.

---

## Section 6 — Source Material Pointer

**With-brief mode** (a `UI-CHALLENGE.md` exists): summarize the 5–8 most load-bearing rules. Do NOT inline the whole brief — Claude Design has a context limit and the user is pasting this prompt manually.

```markdown
## Source Material

Full design opinion lives in `UI-CHALLENGE.md` (in this repo) and the underlying research at `docs/initial-research/[file].md`. The 5 most load-bearing rules:

1. [Rule 1 — the moat sentence as a rule, not a narrative.]
2. [Rule 2 — the diagnosis or vision as a rule.]
3. [Rule 3 — the hero rule.]
4. [Rule 4 — the failure-mode rule.]
5. [Rule 5 — the most opinionated hard rule from §5 of the brief.]
```

**Standalone mode** (no `UI-CHALLENGE.md`): either omit Section 6 entirely, or summarize underlying research in 5–8 lines:

```markdown
## Source Material

Source research: [file path or URL]. Key facts:
- [load-bearing fact 1]
- [load-bearing fact 2]
- [load-bearing fact 3]
- [load-bearing fact 4]
- [load-bearing fact 5]
```

Length: ~10–12 lines if present. Skip the section entirely in standalone mode if the prompt's earlier sections already carry the research forward.

---

## Final Sanity Check Before Returning

Walk through:

1. Does the brief cover all decision areas from the SKILL.md coverage guide? Not necessarily labeled — just present and committed somewhere in the prompt.
2. Are palette hex values and font family names concrete? Each licensed font paired with a Google Fonts fallback?
3. Do positive AND negative reference apps both appear?
4. Did the user's named patterns (ACU sticky donate, Kyiv Independent newsletter, etc.) survive verbatim?
5. Did explicit user rejections (no day counter, no AI photos, no jingoism) appear in the negative-reference section?
6. Do the directions vary on at least three orthogonal axes (layout × register × treatment × color), not just color?
7. Is the artboard math enumerated literally in "What To Ship"? (`N × M = X artboards + 1 title card`)
8. Is the chat-vs-canvas summary instruction present?
9. Is nav scoping explicit (Direction A stays within A)?
10. Is the prompt under 250 lines? Under 150 is better.

If any answer is no, fix it before returning.
