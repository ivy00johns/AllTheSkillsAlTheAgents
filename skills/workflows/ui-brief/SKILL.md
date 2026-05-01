---
name: ui-brief
version: 1.0.0
description: |
  Generate opinionated, design-led briefs for building or rebuilding UIs that lead with the product's actual moat instead of converging on generic SaaS dashboard patterns. Use this skill whenever the user wants a detailed UI prompt or spec to hand off — for a fresh greenfield build OR a rebuild of an existing UI. Trigger on phrases like "write me a UI brief", "the current UI sucks, redesign it", "make this not look like every shadcn admin", "I need a prompt for the frontend", "design brief for X", "the design feels generic", "build a UI for [project] but make it look like [reference]", or when the user wants a paste-into-fresh-session brief to hand to a frontend agent or orchestrator. Works across every domain — operator consoles, dashboards, marketing sites, e-commerce, social, creative tools, mobile apps. Also trigger before invoking ui-ux-pro-max / frontend-design / frontend-agent on any non-trivial UI work, when the user names a target reference app (Linear, Notion, Figma, Arc, Stripe, Vercel, Datadog, Bloomberg, Posthog, etc.) or a named style (bento-grid, glassmorphism, claymorphism, brutalism, neumorphism, minimalism, skeuomorphism), or when prior chat history shows the user just wrote one of these briefs and wants to capture the pattern. Produces a standalone Markdown file with positioning, design-language rules, page-by-page treatment, component primitives, motion discipline, and a verifiable Definition of Done.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed_tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash"]
composes_with: ["ui-ux-pro-max", "frontend-design", "frontend-agent", "orchestrator", "ux-review", "playwright", "brainstorming"]
spawned_by: []
---

# UI Brief

Produce opinionated, design-leading UI briefs that survive contact with implementation.

The default failure mode for LLM-driven UI work is converging on the same shadcn-default-card-grid for every product. This skill exists to write a brief so opinion-dense and reference-specific that the implementing agent cannot drift back into that default. The output is a standalone Markdown file the user (or an orchestrator + frontend-agent) can paste into a fresh Claude Code session and execute against.

**Announce at start:** "Using ui-brief to write an opinionated design brief for [project]."

## Two Modes — Greenfield vs Rebuild

The skill produces both flavors. Pick the right entry path:

### Greenfield (no UI exists yet)

The user is building from scratch. Examples: a new product, a fresh app, a feature with no prior UI surface. The brief sets **target style references** and primitives upfront — there is nothing to diagnose, only failure modes to anticipate.

Hallmark phrases: "build me a UI for X", "I want to build [thing] and want it to look like [reference]", "design a dashboard for [new product]", "make a frontend for [API/backend that exists]".

### Rebuild (UI exists, needs replacement)

The user has a working UI that buries the product's value or feels generic. The brief leads with a **diagnosis** of the current state, then prescribes the replacement.

Hallmark phrases: "the current UI sucks", "redesign this dashboard", "make this not look like every shadcn admin", "the design feels generic", "rebuild the frontend".

Both modes share most of the brief's structure. The differences:

| | Greenfield | Rebuild |
|---|---|---|
| Section 2 — Opening | "The Vision" — what this UI is for, the target reference language | "The Problem" — what is wrong with the current UI, with screenshot reference |
| Discovery focus | Stack + adjacent products + target style references | Stack + current screenshot + current routes + libraries underused |
| DoD screenshot diff | "Side-by-side vs target reference (or design mockup)" | "Side-by-side vs old screenshot — visibly different product, not a recolor" |

The opinion density and structure are otherwise identical.

## When To Use This vs Other Skills

- **`ui-brief`** *(this)* — produces a brief / spec / prompt. Output is a Markdown file. No code is written.
- **`ui-ux-pro-max`** — design intelligence (palettes, fonts, component patterns) consumed *during* implementation.
- **`frontend-design`** — the implementation skill that builds distinctive frontends.
- **`frontend-agent`** — the role agent that does the actual building.
- **`ux-review`** — reviews a *built* UI in a real browser. Use after the build/rebuild ships.
- **`orchestrator`** — consumes this brief if the build is large enough to need a multi-agent team.

```
ui-brief (write the spec)
        ↓
orchestrator + frontend-agent (build it)
        ↓
ux-review + playwright (verify it)
```

If the user has only a vague idea ("I want a better dashboard but I do not know what for"), invoke `brainstorming` first, then come back here with the spec it produces.

## What Makes A Good Brief

The briefs that work follow a specific shape. Each section earns its presence:

1. **The Opening** — *Greenfield*: state the vision and the target reference language up front. *Rebuild*: name what is wrong with the current UI vividly, referencing the screenshot file.
2. **The Thesis** — extract the product's actual moat in one paragraph. Every design decision will be evaluated against it.
3. **Design Language** — concrete reference points appropriate to the domain. Examples of the *shape*: `Linear × Notion × Arc` for a productivity tool; `Stripe × Vercel × Posthog` for a developer marketing site; `bento-grid × glassmorphism × claymorphism` for a playful consumer product; `Datadog × Grafana × Linear` for ops tooling. Pick what fits — never copy-paste these. State both **positive** references AND **negative** references — what to actively avoid is at least as load-bearing as what to emulate. Greenfield briefs lean into target styles; rebuild briefs often lean against the failure mode.
4. **Hard Rules** — 8–12 numbered, opinionated rules. Anchor numbers (32px row height, 2s pulse, 60/40 split). Frame them as judgment-cementing starting points, not laws.
5. **Page-by-Page Brief** — every primary route gets a layout treatment with what belongs and what does not.
6. **Component Primitives** — name 8–12 reusable pieces with implied APIs (e.g. `<MetricNumber>`, `<DenseTable>`).
7. **Motion / Sound / Notifications** — usually missing from briefs; including this section prevents drift toward over-animation or zero animation.
8. **Accessibility & Responsive Baseline** — explicit, not aspirational. axe AA, specific viewports.
9. **Implementation Discipline** — which skills compose during the build (brainstorming → orchestrator → frontend-agent → playwright → ux-review).
10. **Definition of Done** — verifiable items. Must include "loads in a browser with zero console errors" and a screenshot-diff item (vs old screenshot for rebuilds, vs target reference for greenfield).
11. **Notes for the Operator** — guardrails to prevent drift back to generic defaults during the build.

The voice matters. Brief bullet points and bare specifications produce bland UIs. Opinion-dense paragraphs with rationale produce good ones. **Explain the why** for every non-obvious decision.

## How To Run

### Step 1 — Discovery (2–5 minutes of reading)

Before writing a single line of the brief, ground the work in the actual project. Generic briefs come from skipping this step.

- **Read the README, CLAUDE.md, and package.json.** What is the stack? What libraries are already installed? Which ones are barely used? Libraries-already-installed-but-underused is gold — recommending them costs the project nothing and proves you read the file.
- **List the routes / pages** if any exist yet. `find <frontend>/src/app -type d -maxdepth 3` (Next.js) or equivalent for the framework in play.
- **List the existing components and hooks.** Which primitives already exist that the brief should reuse vs replace?
- **Look for screenshots in the repo root or `docs/`.** Use the Read tool on PNG/JPG files — Claude Code can see them. For rebuilds the current UI is the most important artifact you have. For greenfield, look for design mockups, Figma exports, mood-board files.
- **For greenfield with no project yet**, the user must provide either target reference apps or a written vision. If neither is present, ask one targeted question.

### Step 2 — Diagnose or Vision

**Rebuild mode** — answer two questions in writing (your own scratch, before the brief):

1. **What is wrong with the current UI?** Be specific. "Generic" is not a diagnosis — *why* is it generic? Same visual weight on every section? Hero card hides the product? No information density? Wrong chart library for the domain? Cards on a navy background that looks like every B2B SaaS panel from 2023?
2. **What is the product's actual moat?** Read the README's "core thesis" / "what is this" section, the marketing copy, the CLAUDE.md. Reduce to one sentence. The brief's hero element will be whatever makes this moat visible.

**Greenfield mode** — answer two different questions:

1. **What is the product's actual moat or differentiator?** Same question, different source — read the plan, the brainstorm, the user's vision. The hero element will surface this.
2. **What is the target style language?** From the user's stated references, the product's gravity (playful vs serious vs operational), and the space (consumer vs prosumer vs operator). State it in 2–3 reference apps + 1–2 named styles drawn from the design intelligence vocabulary (`ui-ux-pro-max` recognizes 67 styles — pick from there: bento-grid, glassmorphism, claymorphism, neumorphism, brutalism, minimalism, skeuomorphism, etc.).

If you cannot answer the moat question from the project's own files, ask the user one targeted question — do not guess. The whole brief hangs on this answer.

### Step 3 — Pick References

Choose 2–3 positive references and 2–3 negative references. Concrete apps/products and named styles, not adjectives.

| Project type | Positive references that often fit | Negative references to call out |
|---|---|---|
| Trading / finance / data ops | Bloomberg Terminal, Linear, TradingView, Datadog | Vercel/Stripe SaaS, generic admin templates, bento grids |
| Developer tools | Linear, Vercel dashboard, Sentry, Raycast | Bento-grid portfolio sites, glassmorphism, hero-card SaaS |
| Creative / playful consumer | Arc Browser, Figma, Notion, Pitch | Buttoned-up enterprise palettes, dense data-grid feel |
| Operations / monitoring | Datadog, Grafana, Linear | Generic shadcn dashboards, marketing-style hero cards |
| Marketing / content sites | Stripe, Vercel, Notion, Posthog blog | Bento-grid playfulness if the product is serious |
| Marketplace / social / commerce | Stripe checkout, modern Etsy, modern eBay | Web 2.0 density, gradient-heavy retail aesthetics |

For greenfield with target styles already stated by the user (e.g. "I want bento-grid item cards, glassmorphism trust badges, dark mode default"), **lean into them** — they are the brief's design vocabulary, not the failure mode. Negative references in greenfield mode usually call out the *adjacent* failure modes (the generic version of what they are asking for).

These tables are starting points, not laws. Pick what fits the product's gravity. **Always include negatives** — naming what to avoid is half the brief's job.

### Step 4 — Write The Brief

Use `references/brief-template.md` as the structural skeleton. **Do not fill it in mechanically** — the template is a checklist of sections, not a template for the prose. Each section needs project-specific opinion density.

**File location:** by default, write to `<repo-root>/UI-CHALLENGE.md`. If `UI-CHALLENGE.md` already exists, name the next one `UI-CHALLENGE-v2.md`. The user can rename. For greenfield builds embedded inside a larger build challenge, the UI brief may be a section of a larger document (like THE-GAUNTLET.md) rather than a standalone file — ask the user if unclear.

**Length:** typically 200–350 lines of Markdown. Short enough to paste into a fresh session, long enough to be opinion-dense. Ruthlessly cut sections that do not earn their keep — but do not cut for length alone.

### Step 5 — Verify Before Returning

Before reporting done, check:

- [ ] The brief mentions 2+ libraries already installed in the project (proves discovery happened, where applicable).
- [ ] The brief has both positive AND negative reference points (proves opinion).
- [ ] The DoD includes "loads in a browser with zero console errors" and a screenshot-diff item — vs old screenshot for rebuilds, vs target reference / mockup for greenfield.
- [ ] The brief lists which skills should compose during the build.
- [ ] The brief is under 400 lines (or you have a defensible reason for going longer).

Then summarize for the user in 3–5 sentences: the diagnosis-or-vision, the chosen references, where the brief lives. Show, do not narrate.

## Anti-Patterns

| Anti-Pattern | Prevention |
|---|---|
| "Generic" as the diagnosis | Name the specific failure mode — same visual weight, buried hero, missing density, wrong chart library. |
| Adjective-only design language ("clean", "modern", "polished") | Replace with 2–3 concrete reference apps appropriate to the domain plus 1–2 named styles from the design vocabulary (bento-grid, glassmorphism, claymorphism, brutalism, etc.). |
| Spec without opinion | Every numbered hard rule should be defensible. If you cannot explain *why* 32px, change it or drop it. |
| Long bullet lists with no prose | The implementing agent will skim and pattern-match to defaults. Use prose for design-language sections. |
| Skipping the diagnosis section in rebuild mode | Without naming what is broken, the new brief is just preferences. The diagnosis is what makes the rebuild land. |
| Skipping target references in greenfield mode | Without concrete style references, greenfield briefs converge on the same shadcn default. |
| Treating the brief as a contract | It is a *brief*. The implementing agent should bring judgment. Anchor numbers are starting points — say so. |
| Library-blind | If you do not read package.json, you will recommend installing things that are already there. The user will lose trust. |
| Forgetting the screenshot-diff DoD | "Tests pass" is not the bar for UI work. Side-by-side comparison vs current (or vs target) is the only proof the brief produced what was asked for. |
| One-size-fits-all reference points | A reference app that fits one product fits another badly — Bloomberg suits a trading dashboard but not a kids' drawing app; Arc suits a consumer browser but not an enterprise admin. Pick references that match the product's gravity. |
| Writing in passive voice | Briefs that work read like an opinionated colleague telling you what to build. Active voice. First-person plural ("we", "the user") sparingly. |

## Output File Convention

The brief is a standalone Markdown file. It must be paste-ready into a fresh Claude Code session. That means:

- **Self-contained** — no "see [other doc] for X." If a referenced doc is critical, inline its key points.
- **Project-specific** — references the actual stack, the actual routes (or the planned ones), the actual screenshots or target references.
- **Operator-aware** — includes a "Notes for the Operator" section for guardrails during build.
- **Skill-coverage list at the end** — which skills should fire during the build (so the operator can audit coverage after).

## Examples Of Briefs That Worked

Two reference briefs are linked from this skill's parent repo (when running inside the AllTheSkillsAllTheAgents context):

- **Greenfield** — `THE-GAUNTLET.md` at the AllTheSkills repo root. Single-prompt greenfield stress test for "Bazaar" (eBay × PayPal × Twitter). Called for bento-grid item cards, glassmorphism trust badges, dark-mode default, full responsive. The UI section is one phase of a larger build brief — the design language was opinion-dense even without an existing UI to diagnose.
- **Rebuild** — `UI-CHALLENGE.md` at the MarketsBeRigged repo root. Diagnoses the existing trading dashboard's "generic shadcn admin grid" failure mode and prescribes a Bloomberg × Linear × TradingView replacement that leads with the LLM-reasoning moat.

Both followed the structure above. Read them when in doubt about voice. The greenfield one shows how to lean into target styles; the rebuild one shows how to diagnose and replace.
