# 08 — Design Intelligence

## The Problem

AI-generated UIs look like AI-generated UIs. Purple gradients, 3-column feature
grids, centered everything, uniform border-radius, generic hero copy. Users can
smell it. Investors can smell it. Designers definitely smell it.

gstack doesn't just detect bad design — it detects **AI slop specifically**.

## Design System Inference

### How It Works
`/plan-design-review` doesn't just audit — it **extracts the design system**
from the running site:

1. Navigate to the site via browse CLI
2. Extract computed styles from key elements
3. Identify:
   - Font families (headings, body, mono)
   - Font sizes (heading scale: h1→h6)
   - Color palette (primary, secondary, accent, neutrals)
   - Spacing scale (margins, paddings, gaps)
   - Border radius values
   - Shadow system
   - Breakpoints

4. Offer to export as `DESIGN.md`:
```markdown
# Design System

## Typography
- Headings: Inter, 700 weight
- Body: Inter, 400 weight, 16px base
- Mono: JetBrains Mono
- Scale: 2.5rem / 2rem / 1.5rem / 1.25rem / 1rem / 0.875rem

## Colors
- Primary: #2563EB
- Secondary: #7C3AED
...
```

### Why This Matters
Later reviews (`/qa-design-review`, `/review`) read `DESIGN.md` and calibrate
against it. The design system becomes a **constraint**, not a suggestion.
Drift from the design system is flagged as a regression.

## The 80-Item Design Audit

10 categories × 8 items:

### 1. Visual Hierarchy & Layout
- Clear focal point on every page
- F-pattern or Z-pattern scanning
- Whitespace used for grouping, not filling
- Above-the-fold content hierarchy
- Card/section visual weight balance
- Consistent alignment grid
- Visual hierarchy matches information hierarchy
- No competing focal points

### 2. Typography
- Max 2–3 font families
- Readable body text (16px+ on desktop)
- Proper line-height (1.4–1.6 for body)
- Heading hierarchy visually distinct
- No orphaned lines or widows
- Consistent text alignment per section
- Adequate letter-spacing for headings
- Code blocks use monospace with proper sizing

### 3. Color System
- Consistent primary/secondary/accent usage
- Sufficient contrast (WCAG AA minimum)
- Color used for meaning, not decoration
- Dark/light mode consistency (if applicable)
- No more than 5 non-neutral colors
- Hover/focus/active states use consistent color shifts
- Error/success/warning colors are standard
- Background colors don't compete with content

### 4. Spacing & Rhythm
- Consistent spacing scale (4px/8px base)
- Vertical rhythm maintained
- Component internal spacing consistent
- Section spacing creates clear breaks
- No cramped elements
- Padding consistent within component type
- Gap consistency in flex/grid layouts
- Margin collapse handled properly

### 5–10. [Interactive, Responsive, Motion, Content, AI Slop, Performance]

## AI Slop Detection (Category 9)

The 10 most recognizable AI-generated patterns:

1. **Purple/violet gradients** as primary color (the "AI purple")
2. **3-column feature grid** with icon + heading + text
3. **Everything centered** — no left-aligned sections
4. **Uniform border-radius** (usually 8px or 12px on everything)
5. **Generic hero copy** ("Transform your workflow", "Unlock the power of")
6. **Excessive whitespace** with no content density
7. **Card-heavy layouts** where every element is a card
8. **Gradient text** on headings
9. **Floating elements** with no visual grounding
10. **Stock-photo aesthetics** in illustrations

### How Detection Works
Each pattern has a confidence threshold. Finding 1–2 patterns: probably fine.
Finding 5+: "This looks AI-generated. Consider redesigning these elements
to feel more intentional and specific to your brand."

## Design Regression Tracking

### First Run
`/plan-design-review` saves baseline grades per category:
```jsonl
{"category": "typography", "grade": "B+", "issues": 2, "timestamp": "..."}
{"category": "color", "grade": "A-", "issues": 1, "timestamp": "..."}
```

### Subsequent Runs
Auto-compares against baseline:
- "Typography: B+ → A- (improved — fixed orphaned lines)"
- "Color: A- → B (regression — new page uses non-system colors)"

### Design Debt Tracking
Issues not fixed accumulate as design debt, tracked per-branch in
`~/.gstack/projects/{slug}/{branch}-design.jsonl`.

## The 7-Item Lite Review (In `/review`)

For changed frontend files only — runs as part of code review:

1. **Blacklisted fonts** (Comic Sans, Papyrus, system-ui without fallback)
2. **`outline: none` without replacement** (accessibility violation)
3. **`!important` abuse** (>3 uses = flag)
4. **Body text < 16px** (readability)
5. **Missing hover/focus states** on interactive elements
6. **Hardcoded colors** outside the design system
7. **z-index > 100** without justification

## Why This Matters

No other AI skill system has:
1. **Design system inference** from live sites (not just code)
2. **AI slop detection** as a codified checklist
3. **Design regression tracking** across reviews
4. **Live browser inspection** for computed styles
5. **Automatic DESIGN.md export** for design system documentation
6. **Graduated audit depth** (lite in /review, full in /plan-design-review)
