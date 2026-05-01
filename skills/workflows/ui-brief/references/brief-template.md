# UI Brief — Structural Skeleton

This is a checklist of sections, **not** a fill-in-the-blank template. Each section needs project-specific opinion density. If you copy headers and add bullet points without prose, the resulting brief will produce a generic UI. The whole point of this skill is to prevent that.

Lengths below are guidance, not limits.

---

## Section 1 — Title + Brief For Whoever Builds

```markdown
# UI CHALLENGE — [Project Name] [Console / Dashboard / Studio / etc.]

## Brief for whoever [builds | rebuilds] the [thing] next

> Paste this entire file into a fresh Claude Code session at the repo root.
> Auto mode on. [One sentence on the vision (greenfield) OR why the current UI is wrong (rebuild)].
> This brief is opinionated on purpose. Don't soften it back into [the failure mode].
```

**Length:** ~5 lines. The blockquote is the operator's instruction. Make it concrete.

---

## Section 2 — The Problem (rebuild) OR The Vision (greenfield)

### Rebuild variant

Name what is wrong with the current UI. Reference the screenshot file if one exists in the repo.

> "Look at `<screenshot-filename>.png` in the repo root. That's the current state. It is competent, accessible, responsive — and completely generic. You could re-skin it as [unrelated domain] without changing a pixel of the layout. The product's moat is invisible."

**Length:** 1–3 paragraphs. Be specific about *why* it is wrong. Vague diagnosis = vague rebuild.

### Greenfield variant

State the vision and the target reference language up front. No diagnosis — there is nothing to diagnose. Instead, name the design vocabulary the brief will use and the failure mode it is engineered to *avoid*.

> "Build the [thing] for [users]. Target language: [reference 1] × [reference 2] × [named style]. The risk we are designing against is converging on [the generic version of this product type]. Everything below is engineered to prevent that drift."

**Length:** 1–3 paragraphs. Lead with the target style references — they will anchor every section that follows.

---

## Section 3 — The Thesis

Extract the product's actual moat in one paragraph. Then state how the design must serve it.

Include a numbered "optimize for" list:

```markdown
1. **[Glanceability / density / focus / etc.]** — the user should know in 0.5s: [what].
2. **[Reasoning visibility / data fidelity / direct manipulation]** — [how the moat shows through].
3. **[Information density / breathing room]** — every pixel earns its keep / nothing crowds the work.
4. **[Real-time pulse / static calm]** — [what the temporal feel should be].

If a design choice trades any of those for "looks cleaner in a screenshot," reject the choice.
```

**Length:** ~150–200 words. The closing line ("If a design choice trades…") is load-bearing — keep it or replace it with a similarly sharp filter.

---

## Section 4 — Design Language

The most important section. Three subsections:

### Reference Points (in order of weight)

```markdown
- **[Reference app 1]** — [what to take from it: a specific aspect — density, typography, color discipline, a particular interaction pattern].
- **[Reference app 2]** — [a *different* aspect — the feeling of speed, the chart system, the navigation model, the empty-state voice].
- **[Reference app 3]** — [a third aspect, ideally non-overlapping with the first two].
```

### Reference Points To Actively Avoid

```markdown
- Generic shadcn dashboard templates ([what we have now / the failure mode]).
- [Vercel/Stripe marketing-style cards] with thick padding and hero numbers.
- Bento-grid playfulness. This isn't a portfolio site.
- Glassmorphism. [Reason specific to this product.]
```

### Concrete Rules

A bulleted list of design-system rules: dark/light mode, accent color discipline (1–2 max), typography stack (one sans + one mono usually), spacing scale, iconography source, animation budget. Use specific values.

**Length:** ~300–500 words across the three subsections. This is the section that does the most work to prevent drift.

---

## Section 5 — Hard Rules — do these, do not deviate

A numbered list of 8–12 opinionated rules. Each rule:
- Is one sentence (with a follow-up sentence of rationale if needed).
- Contains a concrete anchor (number, behavior, position).
- Is defensible — you can explain *why* this number, this behavior.

Examples of the *shape* (do not copy verbatim):

```markdown
1. **The hero of the dashboard is [the moat-revealing element]**, not [the obvious metric].
2. **Every [primary entity] links to [the underlying reasoning / source]** in one click.
3. **The [recurring loop] is visualized as a real countdown** — not just text.
4. **Tables are dense.** Row height [32px] max. Sticky headers. Sortable columns.
5. **Keyboard shortcuts are first-class.** Cheat sheet on `?`.
6. **No empty states with cute illustrations.** Empty = a single line of muted text.
7. **Color does not carry information alone.** Every red/green has an icon or sign character.
```

**Length:** 8–12 rules, ~150 words total.

---

## Section 6 — Page-by-Page Brief (priority order)

For each primary route, write a short brief:

```markdown
### N. `/route` — [Page Purpose]

**[One-sentence positioning of the page in the product.]**

**Layout** ([baseline viewport]):

- **[Strip / region 1]**: [what goes here, with specific elements].
- **[Hero / left N%, ~Mpx tall]**: [what goes here — be specific, this is where the moat lives].
- **[Right region]**: [what goes here].
- **[Lower region]**: [what goes here].

**What does NOT belong on [this page]**: [explicit exclusions to prevent kitchen-sinking].
```

Rank pages by importance. The first page (usually the dashboard / index route) gets the most detail; tertiary pages can be 3–5 lines each.

**Length:** 30–80 words per primary page, 10–30 words per tertiary page.

---

## Section 7 — Component Primitives — build these once, reuse everywhere

A bulleted list of 8–12 reusable components with implied APIs:

```markdown
- `<MetricNumber>` — tabular, animates the digit shift on update, optional sign prefix, optional unit suffix, color from semantic prop (`positive`/`negative`/`neutral`).
- `<DirectionBadge>` — [BUY/SELL/etc.], consistent shape and color, sized for table cells.
- `<DomainChart>` — wrapper around the project's primary chart library with the theme baked in (whatever fits the domain — `lightweight-charts` for finance, `recharts` / `visx` / `nivo` for general dashboards, `d3` for bespoke).
- `<DenseTable>` — 32px rows, sticky header, sortable, virtualized for >200 rows.
- `<KeyboardHint>` — renders chord with proper styling.
- `<PulseDot>` — the LIVE indicator. 2s breathe, color-prop.
```

These should map to actual reuse opportunities you spotted during discovery.

**Length:** 8–12 entries, one line each.

---

## Section 8 — Motion, Sound, Notifications

Often missing from briefs. Include it explicitly:

```markdown
- **Motion**: [state changes animate, background never; total motion budget].
- **Sound**: [optional, off by default; how many tones, when they fire].
- **Toasts** ([library]): [what they're reserved for — usually only user-initiated actions].
- **Browser notifications**: [opt-in, what fires them].
```

**Length:** ~60–100 words.

---

## Section 9 — Accessibility & Responsive

```markdown
- **Pass axe AA on every route.** Wire it into the [test framework] suite, fail CI on violations.
- **Keyboard navigable everywhere.** Tab order matches visual order. Focus rings visible.
- **Responsive baseline**: [primary viewport] primary, must remain usable at [secondary], must show "this UI is built for [desktop/mobile]" at < [tertiary].
- **Color contrast 4.5:1 minimum.** Use a checker.
- **`prefers-reduced-motion` respected** — disables [the animations from Section 8].
```

**Length:** ~80 words.

---

## Section 10 — Implementation Discipline

Which skills compose during the build, in order:

```markdown
- **Brainstorm first.** Don't open a file until the design is sketched.
- **Spawn an orchestrator** with a frontend-agent that runs at `ui-ux-pro-max` quality.
- **Write a real plan** before coding.
- **TDD the primitives.** [Specific list].
- **Playwright E2E** every page on landing + an axe pass.
- **UX review in a real browser** at [viewports] once the build compiles. Capture screenshots. Compare side-by-side with `<old-screenshot>.png`.
- **Verify before claiming done.** [Specific commands.] Load every route, confirm zero console errors before reporting back.
```

**Length:** ~120 words.

---

## Section 11 — Definition of Done

A checklist of verifiable items. **Must include:**

- [ ] [The dev command] boots cleanly with prefixed output.
- [ ] Every route in §"Page-by-Page" loads with **zero console errors** against a live backend.
- [ ] [Hero / moat-revealing element] is visible in the first viewport at [primary viewport size] without scrolling.
- [ ] [Library that should be used] is used everywhere it should be (with grep command to verify).
- [ ] Tables use the new `<DenseTable>` primitive.
- [ ] Keyboard shortcuts work; `?` shows the cheat sheet.
- [ ] axe-core passes on every route.
- [ ] **Screenshot comparison item** — *Rebuild*: side-by-side old vs new shows visibly different product, not a recolor. *Greenfield*: side-by-side vs the target reference apps named in §"Design Language" shows the new UI captures the target language, not a generic shadcn fallback.
- [ ] [Project-specific verifiable item.]
- [ ] Unit + E2E tests pass.

The **screenshot comparison item is non-negotiable.** Without it, "tests pass" becomes the bar and the build quietly reverts to defaults.

---

## Section 12 — Skill Coverage Expected

A bullet list of skills that should naturally trigger during the build, with one-line "why":

```markdown
- `superpowers:brainstorming` (before any creative work — non-negotiable)
- `superpowers:writing-plans` (the page-priority + component-dependency plan)
- `ui-ux-pro-max` (design intelligence, palette, typography)
- `frontend-design:frontend-design` (the distinctive non-generic feel)
- `frontend-agent` (the implementation work)
- `orchestrator` (if multi-agent — frontend + qe + docs is reasonable)
- `playwright` (E2E + axe runs)
- `ux-review` (the in-browser review with screenshots — catches "tests pass but UI looks wrong")
- `superpowers:test-driven-development` (the primitives)
- `superpowers:verification-before-completion` (load every route, no console errors)
- `code-reviewer` (the review pass)
- `git-commit` + `git-pr` (the integration commit + PR)
- `simplify` (after the build, review the diff for reuse and bloat)
```

**Length:** 10–15 entries.

---

## Section 13 — Notes for the Operator

Guardrails to prevent drift back to generic defaults during the build. Include:

- What in the existing codebase is right and should be preserved (don't rewrite the data layer if it's good).
- What should *not* change (route structure, existing primitives that work).
- Which installed libraries to use vs avoid (and why).
- Reminder that the anchor numbers in the brief are starting points, not laws.
- "If the build feels like it's drifting back into [the failure mode], stop, re-read [the relevant section], and course-correct."

**Length:** ~100–200 words.

---

## Final Sanity Check Before Returning

Before handing the brief back to the user, walk through:

1. Does the brief mention 2+ libraries already in `package.json`?
2. Are there both positive and negative reference points?
3. Does the DoD include "loads in browser, zero console errors" + screenshot-diff?
4. Is every numbered hard rule defensible (could you explain *why* this number)?
5. Is the prose dense enough that an implementing agent cannot skim it into defaults?

If any answer is no, fix it before returning.
