# 10 - Quality Intelligence: The System's Design-Aware Self-Validation Layer

A comprehensive specification of the quality intelligence system for a clean-sheet AI
agent orchestration platform, synthesizing cognitive patterns and design audit from gstack,
contract-first QA gating from ATSA, and expertise-store learning from Overstory.

---

## 1. Quality Intelligence Philosophy

### Quality Is Structural, Not a Phase

Quality is not a phase that happens after implementation. It is _structural_ -- woven
into every layer: contracts prevent misalignment before work starts, cognitive patterns
shape how agents think while they work, evals validate output after work completes, and
an expertise store feeds lessons back into future work. There is no "QA phase" because
quality is enforced at every phase.

### Cognitive Patterns Activate Latent Knowledge

LLMs already have deep knowledge of how great leaders, engineers, and designers think.
The instruction "think like Dieter Rams" activates a coherent worldview the model
already understands -- not teaching, but unlocking. A 2-line prompt reference activates
pages of latent understanding that no checklist could replicate. Checklists enumerate;
patterns reason.

### "Boil the Lake": Thoroughness Is Cheap Now

AI compression changes the calculus on completeness. Before AI, 100% test coverage
might cost 3 weeks -- shortcuts were rational. After AI, 100% coverage costs 30 minutes.
The principle: don't sample -- run ALL the tests, check ALL the files, verify ALL the
contracts. The cost of thoroughness has collapsed; the cost of missing something has not.

### Three Pillars

**Prevention** -- Contracts define expected behavior before implementation begins. File
ownership prevents conflicts. Cognitive patterns shape thinking before code is written.
Quality problems that never occur cost nothing to fix.

**Detection** -- 3-tier evals catch problems that slip through prevention. The 80-item
design audit catches visual and interaction regressions. AI slop detection catches
the specific patterns of AI-generated mediocrity. The QA gate blocks substandard work
from merging.

**Learning** -- The expertise store records successful patterns, failed approaches,
conflict resolutions, and quality findings. This knowledge feeds back into prevention
and detection, creating a virtuous cycle where the system gets better at quality over
time.

### Veto Power

The quality layer has veto power over the build. It can block merges, reject work items,
and escalate findings to the coordinator. A CRITICAL finding always blocks. A security
score below 3 always blocks. This is not advisory -- it is structural enforcement. No
agent, regardless of role or urgency, can override the quality gate without human
approval.

---

## 2. Cognitive Patterns Library

### The Core Insight

Invoking "think like Andy Grove" activates a coherent worldview the LLM already
understands deeply. This is categorically more powerful than a checklist because:

1. **Coherent worldviews** -- activates entire philosophies, not isolated checks
2. **Context-sensitive** -- patterns adapt to the specific situation
3. **Composable** -- Bezos Doors + Altman Leverage = "reversible high-leverage bet? Ship fast."
4. **Memorable** -- engineers remember "Chesterton's Fence" forever; nobody remembers checklist item 47
5. **Upgradable** -- adding a pattern enriches all future reviews

### CEO Mode -- 14 Patterns

For strategic thinking, product decisions, prioritization, and scope management.

| # | Pattern | Thinker | Core Insight | Activation Context |
|---|---------|---------|-------------|-------------------|
| 1 | Bezos Doors | Jeff Bezos | One-way doors (irreversible) need caution; two-way doors (reversible) need speed | Architecture decisions, API design, data model changes |
| 2 | Day 1 Proxy | Jeff Bezos | Skepticism toward process-as-proxy -- process should serve customers, not itself | Workflow reviews, ceremony evaluation |
| 3 | Regret Minimization | Jeff Bezos | Will you regret NOT doing this in 10 years? | Feature prioritization, strategic bets |
| 4 | Grove Paranoid Scanning | Andy Grove | "Only the paranoid survive" -- what threat are you not seeing? | Risk assessment, dependency review |
| 5 | Munger Inversion | Charlie Munger | Invert the problem -- what would guarantee failure? Avoid that. | Planning reviews, failure mode analysis |
| 6 | Munger Latticework | Charlie Munger | Apply mental models from multiple disciplines | Cross-cutting decisions, complex tradeoffs |
| 7 | Horowitz Wartime/Peacetime | Ben Horowitz | Peacetime: expand, explore. Wartime: focus, cut, survive. | Sprint planning, crisis response |
| 8 | Chesky Founder Mode | Brian Chesky | Stay close to product details, don't delegate blindly | Quality reviews, UX decisions |
| 9 | Altman Leverage | Sam Altman | What's the highest-leverage thing you could do right now? | Task prioritization, resource allocation |
| 10 | Collison Stripe Think | Patrick Collison | Think clearly about hard problems, don't pattern-match | Novel architecture, unfamiliar domains |
| 11 | Lutke Shopify Scale | Tobi Lutke | Build for the next 10x scale, not the current one | Infrastructure decisions, data model design |
| 12 | Graham Schlep Blindness | Paul Graham | The most valuable work is often the work nobody wants to do | Backlog prioritization, tech debt decisions |
| 13 | Thiel Zero to One | Peter Thiel | Are you creating something new or copying what exists? | Feature design, competitive positioning |
| 14 | Tan Founder Density | Garry Tan | High-density teams (small, elite) outperform large teams | Team sizing, agent spawning decisions |

**Operating modes** for CEO-mode reviews:
1. **SCOPE EXPANSION** -- Dream big, surface all opportunities enthusiastically
2. **SELECTIVE EXPANSION** -- Hold current scope, cherry-pick expansion opportunities
3. **HOLD SCOPE** -- Maximum rigor on existing plan
4. **SCOPE REDUCTION** -- Minimal viable version

### Engineering Mode -- 15 Patterns

For technical decisions, architecture, implementation quality, and operational excellence.

| # | Pattern | Thinker/Source | Core Insight | Activation Context |
|---|---------|---------------|-------------|-------------------|
| 1 | Larson Team State | Will Larson | Diagnose team state: falling behind, treading water, repaying debt, or innovating | Sprint retrospectives, velocity analysis |
| 2 | McKinley Boring Default | Dan McKinley | Choose boring technology -- new tech has hidden costs | Technology selection, dependency decisions |
| 3 | Brooks Essential/Accidental | Fred Brooks | Distinguish essential complexity (inherent) from accidental (self-inflicted) | Architecture review, complexity analysis |
| 4 | Beck Make Change Easy | Kent Beck | "Make the change easy, then make the easy change" | Refactoring decisions, API evolution |
| 5 | Majors Own Your Code | Charity Majors | You should run what you build, in production, yourself | Observability, deployment ownership |
| 6 | Google SRE Error Budgets | Google | Error budgets balance reliability and velocity -- spend them wisely | Release decisions, reliability tradeoffs |
| 7 | Fowler Refactoring | Martin Fowler | Continuous small refactors prevent big rewrites | Code review, tech debt management |
| 8 | Hyrum's Law | Hyrum Wright | Any observable behavior will be depended upon by someone | API changes, backwards compatibility |
| 9 | Conway's Law | Melvin Conway | System architecture mirrors communication structure | Team organization, service boundaries |
| 10 | Kernighan Debugging | Brian Kernighan | "If you write code as cleverly as possible, you are by definition not smart enough to debug it" | Code review, complexity flags |
| 11 | Unix Philosophy | Doug McIlroy | Do one thing well. Compose via pipes. Text as universal interface. | Interface design, service decomposition |
| 12 | Knuth Premature Optimization | Donald Knuth | "Premature optimization is the root of all evil" | Performance decisions, abstraction timing |
| 13 | Postel's Law | Jon Postel | "Be liberal in what you accept, conservative in what you send" | API design, input validation |
| 14 | Chesterton's Fence | G.K. Chesterton | Before removing something, understand why it was put there | Refactoring, legacy code changes |
| 15 | Dijkstra Simplicity | Edsger Dijkstra | "Simplicity is prerequisite for reliability" | Architecture review, complexity reduction |

### Design Mode -- 12 Patterns

For UX, product design, information architecture, and visual quality.

| # | Pattern | Thinker | Core Insight | Activation Context |
|---|---------|---------|-------------|-------------------|
| 1 | Rams Subtraction | Dieter Rams | "Less, but better." Start by removing. | UI review, feature scope |
| 2 | Norman 3 Levels | Don Norman | Visceral (5s), Behavioral (5min), Reflective (5yr) | UX assessment, emotional design |
| 3 | Zhuo Principled Taste | Julie Zhuo | Good design isn't subjective -- it's principled judgment | Design critique, quality standards |
| 4 | Gebbia Trust Design | Joe Gebbia | Design for trust first, features second | Onboarding flows, payment UX |
| 5 | Ive Care Is Visible | Jony Ive | Users can feel when designers cared about details | Polish review, detail audit |
| 6 | Tufte Data-Ink | Edward Tufte | Maximize the data-ink ratio -- every pixel should mean something | Dashboard design, data visualization |
| 7 | Krug Don't Make Me Think | Steve Krug | If users have to think, the design is wrong | Navigation review, form design |
| 8 | Victor Immediate Feedback | Bret Victor | The gap between action and result should be zero | Interaction design, loading states |
| 9 | Chimero Shape of Design | Frank Chimero | Design is about relationships between elements, not individual elements | Layout review, composition |
| 10 | Eames Constraints | Charles Eames | "Design depends largely on constraints" | Creative briefs, constraint-driven design |
| 11 | Muller-Brockmann Grid | Josef Muller-Brockmann | Grid systems bring order, proportion, and rhythm | Layout systems, responsive design |
| 12 | Munari Simplicity | Bruno Munari | "Complicating is easy, simplifying is hard" | Complexity review, simplification passes |

---

## 3. Role-Specific Pattern Assignment

Cognitive patterns load into agent context based on operational role. Primary patterns
are always loaded; secondary patterns load on demand when the agent's work touches
relevant domains.

| Role | Primary Patterns | Secondary Patterns | Rationale |
|------|-----------------|-------------------|-----------|
| Coordinator | CEO mode (all 14) | Brooks, Fowler | Strategic decisions, scope management, team orchestration |
| Lead | Grove, Horowitz, Collison, Altman | Beck, Majors, Larson | Tactical leadership, work decomposition, team state diagnosis |
| Builder | Beck, Martin (via Kernighan), Knuth, Fowler, Dijkstra | Brooks, Majors, Postel | Implementation quality, clean code, appropriate optimization |
| Reviewer | Munger (Inversion + Latticework), Fowler, Chesterton's Fence | Rams, Norman, Kernighan | Critical analysis, multi-model reasoning, understanding before changing |
| Quality Auditor | All Design mode (12) | Munger, Majors | Full design audit capability, observability, mental model diversity |
| Scout | Bezos (Working Backwards, Regret Minimization) | Norman, Krug | Customer-centric analysis, usability assessment |
| Browse Agent | Norman, Tufte, Krug, Victor | Rams, Muller-Brockmann | Interaction quality, data visualization, immediate feedback |

**Pattern composition examples:**
- Builder + Beck + Dijkstra = "Make the change easy (refactor first), keep it simple (no clever tricks), then make the easy change"
- Reviewer + Munger Inversion + Chesterton's Fence = "What would make this fail? And before removing that guard clause, why was it added?"
- Coordinator + Bezos Doors + Tan Founder Density = "Is this architecture decision reversible? Keep the team small and elite regardless."

---

## 4. 80-Item Design Audit

The design audit is a structured rubric applied by the Quality Auditor role (or any
agent with Design mode patterns loaded). It covers 10 categories with 8 items each,
producing a per-category grade and an overall design quality score.

### Category 1: Visual Hierarchy and Layout (8 items)

1. Clear focal point on every page/view
2. F-pattern or Z-pattern scanning support for content pages
3. Whitespace used for grouping, not just filling
4. Above-the-fold content hierarchy is intentional
5. Card/section visual weight is balanced
6. Consistent alignment grid across pages
7. Visual hierarchy matches information hierarchy
8. No competing focal points within the same view

### Category 2: Typography (8 items)

1. Maximum 2-3 font families in use
2. Readable body text (16px+ on desktop, 14px+ on mobile)
3. Proper line-height (1.4-1.6 for body text)
4. Heading hierarchy is visually distinct (h1 through h6)
5. No orphaned lines or widows in content blocks
6. Consistent text alignment per section type
7. Adequate letter-spacing for headings and all-caps text
8. Code blocks use monospace with proper sizing

### Category 3: Color System (8 items)

1. Consistent primary/secondary/accent color usage
2. Sufficient contrast ratios (WCAG AA minimum: 4.5:1 normal, 3:1 large)
3. Color used for meaning, not just decoration
4. Dark/light mode consistency (if applicable)
5. No more than 5 non-neutral colors in the palette
6. Hover/focus/active states use consistent color shifts
7. Error/success/warning colors follow standard conventions
8. Background colors do not compete with foreground content

### Category 4: Spacing and Rhythm (8 items)

1. Consistent spacing scale (4px or 8px base unit)
2. Vertical rhythm maintained across sections
3. Component internal spacing is consistent within type
4. Section spacing creates clear visual breaks
5. No cramped elements (minimum touch targets on mobile)
6. Padding consistent within each component type
7. Gap consistency in flex/grid layouts
8. Margin collapse handled properly (no double-spacing bugs)

### Category 5: Interactive Elements (8 items)

1. All interactive elements have visible hover states
2. Focus indicators present and visible (no `outline: none` without replacement)
3. Active/pressed states provide feedback
4. Disabled states are visually distinct and non-interactive
5. Cursor changes appropriately (pointer, text, grab, not-allowed)
6. Touch targets meet minimum size (44x44px)
7. Interactive element affordances are clear (buttons look clickable)
8. Form validation feedback is immediate and positioned near the input

### Category 6: Responsive Design (8 items)

1. Content readable at all standard breakpoints (320px, 768px, 1024px, 1440px)
2. No horizontal scrolling on mobile
3. Navigation adapts appropriately (hamburger, tab bar, etc.)
4. Images scale properly (no overflow, no distortion)
5. Typography scales appropriately across breakpoints
6. Touch-friendly spacing on mobile (larger gaps, bigger targets)
7. Tables handled for small screens (horizontal scroll, stack, or collapse)
8. Modals and overlays usable on mobile

### Category 7: Motion and Animation (8 items)

1. Transitions are consistent in duration (150-300ms for micro, 300-500ms for macro)
2. Easing functions are consistent (not mixing linear, ease, ease-in-out randomly)
3. Loading indicators present during async operations
4. Page transitions are smooth (no flash of unstyled content)
5. Animations serve a purpose (guiding attention, indicating state change)
6. No gratuitous animations that slow down interaction
7. Respects `prefers-reduced-motion` media query
8. Skeleton screens or shimmer effects for content loading

### Category 8: Content Quality (8 items)

1. Microcopy is clear and action-oriented (button labels, tooltips)
2. Error messages are helpful and suggest next steps
3. Label text is consistent (sentence case vs. title case applied uniformly)
4. No placeholder text surviving to production (no Lorem ipsum)
5. Empty states have helpful messaging and actions
6. Confirmation dialogs explain consequences clearly
7. Success messages confirm what happened and what to do next
8. Help text is concise and positioned near the relevant element

### Category 9: AI Slop Detection (8 items)

1. No generic hero sections ("Welcome to [Product]!", "Transform your workflow")
2. No placeholder text or Lorem ipsum in production
3. No stock photo placeholder aesthetics in illustrations
4. Design tokens are consistent (not mixing arbitrary values)
5. Component structure varies appropriately (not cookie-cutter throughout)
6. All states handled (empty, loading, error -- not just the happy path)
7. No "AI assistant" copy patterns ("Let me help you with that", "I'd be happy to")
8. No gratuitous gradients, glassmorphism, or trend-chasing animations

### Category 10: Performance Perception (8 items)

1. Above-the-fold content renders within 1 second
2. Interactive elements respond within 100ms
3. No layout shift after initial render (CLS < 0.1)
4. Images are optimized (WebP/AVIF, lazy loaded below fold)
5. Fonts load without visible flash (FOIT/FOUT handled)
6. Scroll performance is smooth (60fps)
7. Large lists use virtualization
8. Progressive loading for heavy content (images, maps, charts)

### Scoring

Each item is scored: PASS (1), PARTIAL (0.5), FAIL (0). Category score = sum / 8.
Overall design score = average of 10 category scores, expressed as a letter grade:

- A (90-100%): Production-ready, polished
- B (75-89%): Good with minor issues
- C (60-74%): Functional but needs polish
- D (40-59%): Significant issues, needs redesign pass
- F (<40%): Fundamental problems, block merge

---

## 5. AI Slop Detection

Ten codified anti-patterns that indicate AI-generated mediocrity. These are
distilled from Category 9 of the design audit but expanded with detection
heuristics and remediation guidance for use as standalone checks.

### 1. Generic Hero Sections
- **Signature:** "Welcome to [Product]!", "Transform your workflow", "Unlock the power of"
- **Detection:** Regex match against known generic phrases; LLM judge scores copy specificity
- **Severity:** WARNING (does not block, but strongly flagged)
- **Remediation:** Replace with product-specific value proposition. Reference actual user outcomes, not abstract benefits.

### 2. Placeholder Text Surviving to Production
- **Signature:** Lorem ipsum, "TODO", "placeholder", "example.com" in non-example contexts
- **Detection:** Static text search for known placeholder strings
- **Severity:** BLOCKING (always blocks merge)
- **Remediation:** Replace with real content or remove the section entirely.

### 3. Stock Photo Placeholder Aesthetics
- **Signature:** `via.placeholder.com`, unsplash URLs in production, generic illustration style
- **Detection:** URL pattern matching; LLM review of image context and relevance
- **Severity:** WARNING
- **Remediation:** Use product-specific imagery, custom illustrations, or remove decorative images.

### 4. Inconsistent Design Tokens
- **Signature:** Mixing `#3B82F6` and `#2563EB` for the same semantic purpose; arbitrary spacing values
- **Detection:** Extract computed styles and cluster by semantic purpose; flag outliers
- **Severity:** WARNING
- **Remediation:** Define and enforce a design token system. Map all values to named tokens.

### 5. Cookie-Cutter Component Structure
- **Signature:** Every section is a 3-column grid with icon + heading + paragraph
- **Detection:** AST analysis of component structure; LLM review for layout diversity
- **Severity:** WARNING
- **Remediation:** Vary layout patterns. Use different structures for different content types.

### 6. Missing Empty, Error, and Loading States
- **Signature:** Components that only render the happy path; no skeleton screens, no error boundaries
- **Detection:** Static analysis for state handling patterns; E2E tests that trigger edge states
- **Severity:** WARNING (upgrades to BLOCKING if more than 3 components are missing all three)
- **Remediation:** Add empty state messaging, error boundaries with retry, and loading skeletons.

### 7. AI Assistant Copy Patterns
- **Signature:** "Let me help you with that", "I'd be happy to assist", "Here's what I found"
- **Detection:** Regex match against conversational AI phrases in UI copy
- **Severity:** WARNING
- **Remediation:** Write UI copy in the product's voice. Buttons should be verbs. Labels should be nouns.

### 8. Gratuitous Gradients and Animations
- **Signature:** Purple-to-blue gradients on everything; gradient text on headings; floating decorative elements
- **Detection:** CSS analysis for gradient frequency; LLM review for decorative purpose
- **Severity:** WARNING
- **Remediation:** Use gradients sparingly and intentionally. Prefer solid colors for most UI surfaces.

### 9. Missing Responsive Breakpoints
- **Signature:** Desktop layout breaks on mobile; no media queries; fixed-width containers
- **Detection:** Playwright screenshots at 320px, 768px, 1024px, 1440px; visual comparison
- **Severity:** BLOCKING (modern apps must be responsive)
- **Remediation:** Implement mobile-first responsive design with appropriate breakpoints.

### 10. Over-Abstracted Component Hierarchy
- **Signature:** `<PageWrapper><ContentContainer><SectionWrapper><CardGrid><CardWrapper>` for simple content
- **Detection:** AST analysis of component nesting depth; flag >5 wrapper layers
- **Severity:** WARNING
- **Remediation:** Flatten component hierarchy. Each abstraction layer should add clear value.

### Threshold Logic

Finding 1-2 patterns in a codebase is normal -- not every instance is a problem.
Finding 5 or more is a strong signal of AI-generated code that was not reviewed by a
human designer. The quality auditor escalates at 5+ with the recommendation: "This
output shows signs of AI-generated design. Consider a focused design pass to add
specificity and intentionality."

---

## 6. 3-Tier Eval System

### Tier 1: Static Validation

**Cost:** Free. **Speed:** Under 1 second. **Run:** Every build, every commit, every merge request.

| Check | What It Validates | Failure Mode |
|-------|-------------------|-------------|
| File existence | Do expected outputs exist? | Missing deliverable |
| Linting (ESLint, Prettier) | Code style and formatting | Style violations |
| Type checking (TypeScript strict) | Type safety | Type errors |
| Contract conformance | Schema validation against declared contracts | Implementation drift |
| Dependency check | No circular imports, no missing dependencies | Build failures |
| Command registry | All referenced commands exist and are valid | Broken integrations |
| Touchfile completeness | Every E2E test has declared file dependencies | Untested changes |

### Tier 2: E2E Testing (Browser-Driven)

**Cost:** ~$3-4 per full run. **Speed:** Minutes. **Run:** On merge request, on integration.

| Check | What It Validates | Tool |
|-------|-------------------|------|
| Browser tests | Full user flows work end-to-end | Playwright |
| Visual regression | Screenshots match baseline | Playwright screenshot comparison |
| Interaction testing | Click, type, navigate all work | Playwright actions |
| Accessibility audit | WCAG compliance | axe-core |
| Performance budget | Lighthouse scores meet thresholds | Lighthouse |
| Multi-page flows | Complex user journeys complete | Playwright scenarios |

**Session runner architecture:**
- Spawns headless Chromium via the Browse CLI
- Per-workspace isolation prevents test interference
- Heartbeat logging tracks progress during long runs
- Machine-readable diagnostics: `exit_reason`, `timeout_at_turn`, `last_tool_call`
- Non-fatal I/O: observability writes never cause tests to fail

### Tier 3: LLM-as-Judge

**Cost:** ~$0.15 per run. **Speed:** 10-30 seconds. **Run:** On merge request, on quality audit request.

| Check | What It Validates | Method |
|-------|-------------------|--------|
| Output quality | Does the output meet the rubric? | AI evaluates against structured rubric |
| Domain rubrics | API quality, UI quality, docs quality | Per-domain rubric definitions |
| Planted-bug detection | Can the judge find known issues? | Known bugs injected into fixtures |
| Cross-validation | Do multiple judges agree? | Multi-model consensus |

**Rubric structure:**
```
Domain: API
Criteria:
  - Endpoint naming follows REST conventions (1-5)
  - Error responses include actionable messages (1-5)
  - Request validation rejects invalid input gracefully (1-5)
  - Response schemas match declared contracts (1-5)
  - Authentication/authorization properly enforced (1-5)
Pass threshold: average >= 3.5, no individual score < 2
```

**Multi-model consensus:** When judges diverge by more than 1 point on any criterion,
the finding is flagged for human review.

### Diff-Based Test Selection

**Mechanism:**
1. `git diff <base>...HEAD --name-only` produces the list of changed files
2. Each test declares its file dependencies (touchfiles)
3. Only tests whose dependencies were modified are selected
4. Global touchfiles (eval infrastructure, persistence, judge logic) trigger all tests

**Cost optimization:** A change to a single module runs 1 test (~$0.30) instead of the
full suite (~$4.00). Infrastructure changes still trigger the full suite. Preview before
spending with `eval:select --json`.

**Override:** `EVALS_ALL=1` forces all tests regardless of diff. Use when you suspect
a change has cross-cutting effects that touchfiles don't capture.

---

## 7. Browse CLI (Browser Automation)

### Architecture

- **Persistent daemon:** Compiled to binary, runs as a long-lived process per workspace
- **Cold start:** 3-5 seconds for initial launch
- **Subsequent commands:** 100-200ms response time
- **Per-workspace isolation:** Each workspace gets its own browser context
- **Cookie import:** Can import cookies from Chrome, Arc, Brave, Edge for authenticated testing

### Command Surface (50+ commands)

**Navigation:** navigate, navigate_back, reload, wait_for
**Inspection:** snapshot (DOM), screenshot, console_messages, network_requests
**Interaction:** click, fill, type, select_option, press_key, hover, drag
**Forms:** fill_form (multi-field), file_upload
**Evaluation:** evaluate (arbitrary JS), run_code (multi-statement)
**Management:** tabs, resize, close, handle_dialog

### Quality-Specific Capabilities

**Visual regression testing:**
- Screenshot at multiple breakpoints (320px, 768px, 1024px, 1440px)
- Pixel-level comparison against baseline screenshots
- Diff highlighting shows exactly what changed
- Threshold-based pass/fail (configurable sensitivity)

**Accessibility audit:**
- DOM snapshot analysis for semantic HTML
- ARIA label completeness checking
- Focus order verification via tab-through testing
- Color contrast extraction from computed styles

**Performance metrics collection:**
- First Contentful Paint (FCP)
- Largest Contentful Paint (LCP)
- Cumulative Layout Shift (CLS)
- Time to Interactive (TTI)
- Total Blocking Time (TBT)

**Design system inference:**
- Extract computed styles from key elements
- Identify font families, sizes, colors, spacing, border-radius, shadows
- Cluster values to detect the design system in use
- Export as DESIGN.md for future review calibration

**Form testing:**
- Fill multiple fields with test data
- Submit and verify response
- Test validation messages for invalid input
- Test multi-step form flows

---

## 8. QA Gate (Quality Report)

### Schema

```json
{
  "work_item_id": "wi-a1b2c3",
  "agent_id": "builder-alpha",
  "timestamp": "2026-03-18T20:00:00Z",
  "scores": {
    "contract_conformance": 4,
    "security": 5,
    "test_coverage": 3,
    "code_quality": 4,
    "documentation": 3
  },
  "overall": 3.8,
  "verdict": "PASS",
  "blockers": [],
  "warnings": ["test_coverage below 4 -- add edge case tests"],
  "findings": [
    {
      "severity": "WARNING",
      "category": "test_coverage",
      "description": "Missing tests for error handling in auth middleware",
      "file": "src/auth.ts",
      "line": 42,
      "suggestion": "Add test for expired token scenario"
    }
  ],
  "eval_results": {
    "tier1": { "passed": 12, "failed": 0, "skipped": 2 },
    "tier2": { "passed": 5, "failed": 0, "skipped": 0 },
    "tier3": { "score": 4.2, "judge_model": "claude-sonnet-4-6" }
  }
}
```

### Five Scoring Dimensions

- **Contract conformance (1-5):** Implementation matches declared contract -- schema validation, endpoint coverage, type alignment
- **Security (1-5):** Auth enforced, input validated, secrets managed, no injection vectors
- **Test coverage (1-5):** Unit + integration tests, edge cases, error paths -- quality, not just quantity
- **Code quality (1-5):** Clean code, appropriate abstraction, no dead code, consistent patterns
- **Documentation (1-5):** API documented, complex logic explained, changelog updated

### Verdict Logic

| Verdict | Meaning | When |
|---------|---------|------|
| PASS | Work can merge | No blockers, no dimension below threshold |
| FAIL | Work is blocked | Any blocking condition met |
| CONDITIONAL | Work can merge with caveats | Warnings present but no blockers |

### Blocking Rules

These rules are non-negotiable. No agent can override them without human approval.

- **CRITICAL finding** --> FAIL (always blocks, regardless of scores)
- **contract_conformance < 3** --> FAIL (implementation doesn't match spec)
- **security < 3** --> FAIL (unacceptable security posture)
- **Any two dimensions < 2** --> FAIL (broad quality failure)
- **Overall < 2.5** --> FAIL (aggregate quality too low)

### Failure Blame Protocol

When a quality check fails, attribution matters. The protocol:

1. Run the same eval on the base branch and show it fails there too
2. If it passes on the base but fails on the current branch -- the change caused it
3. If you cannot run on the base branch, state "unverified -- may or may not be related"

Claiming "pre-existing" without proof is prohibited. Prove it or investigate.

---

## 9. "Boil the Lake" Completeness Principle

### The Philosophical Foundation

AI compression makes shortcuts irrational for bounded tasks. The math:

```
Before AI:
  Complete implementation: 3 weeks
  Shortcut: 3 days
  Savings: 2.5 weeks
  Decision: Take the shortcut. Rational.

After AI:
  Complete implementation: 30 minutes
  Shortcut: 15 minutes
  Savings: 15 minutes
  Decision: Do the complete version. Also rational.
```

The delta between 80 lines and 150 lines is meaningless with AI coding assistance.
The delta between 80% coverage and 100% coverage is a production incident.

### Applied Thoroughness

- **In evals:** Run all three tiers. Tier 3 costs $0.15 -- skipping it to save 30 seconds is irrational.
- **In review:** Check all files in the changeset. The file you skip has the subtle regression.
- **In audit:** Run all 80 design audit items. Inconsistency is worse than absence.
- **In testing:** Test empty states, error states, edge cases, boundary conditions. AI makes these free.
- **In documentation:** Generate comprehensive docs. 10 minutes of AI time vs. compounding onboarding cost.

### Lake vs. Ocean

Not everything should be boiled. The distinction:

**Lakes (boil these):**
- 100% test coverage for a module
- Full feature implementation with all edge cases
- Complete error handling for every code path
- All enum variants handled in switch statements
- Every validation rule enforced
- Comprehensive docs for a new API

**Oceans (don't attempt as a lake):**
- Rewriting an entire codebase in a new language
- Multi-quarter migration projects
- Redesigning a distributed system from scratch
- Replacing a fundamental dependency across all consumers

The test: can AI compression reduce this to under an hour? If yes, it's a lake. If no,
it's an ocean that requires planning, phasing, and incremental execution.

### The Caveat

Completeness without quality = more bugs, faster. The completeness principle only works
when coupled with the full quality intelligence layer. Completeness with quality =
production-grade code, fast.

---

## 10. Expertise Store (Learning System)

### What Gets Recorded

| Entry Type | Content | Example |
|-----------|---------|---------|
| Successful pattern | Implementation approach that passed QA with high scores | "Middleware chain pattern for auth reduced security findings by 80%" |
| Failed approach | Implementation that was rejected or required significant rework | "Monolithic error handler -- split into domain-specific handlers after review" |
| Conflict resolution | How a file ownership or merge conflict was resolved | "Both agents modified shared types -- resolved by extracting to shared contract" |
| Quality finding | Recurring issue found during review or audit | "Missing error boundary in React components -- found in 3 consecutive reviews" |
| Design regression | Design quality that degraded between reviews | "Typography grade dropped from A- to B after new component library integration" |

### Query Interface

The expertise store is queryable along multiple dimensions:

- **By file path:** "What quality issues have occurred in `src/auth/`?"
- **By domain:** "What patterns work well for database migration?"
- **By pattern type:** "Show all conflict resolutions from the last month"
- **By agent:** "What are builder-alpha's common quality findings?"
- **By severity:** "Show all CRITICAL findings across all projects"

### Integration Points

- **Prompt enrichment:** Builder agents receive historical context for files with recurring findings
- **Routing decisions:** Coordinator routes work based on agent quality history per domain
- **Review calibration:** Reviewers get extra scrutiny signals for known problem areas
- **Design regression tracking:** Quality auditor compares current scores against stored baselines

### Storage and Lifecycle

**Storage:** Dolt table (versioned, queryable SQL database that survives federation
across distributed deployments).

**Compaction:** Old entries are periodically summarized. A 6-month-old finding becomes:
"Auth middleware: 3 security findings (input validation) resolved by adding zod schemas."
Full history remains accessible in version control but does not bloat active queries.

**Retention:** Successful patterns retained indefinitely (institutional knowledge).
Failed approaches retained 12 months (prevent repeating mistakes). Quality findings
retained until verified as resolved, then summarized.

### Feedback Loop

The expertise store closes the quality loop:

```
Prevention (contracts, patterns) --> Implementation (builders)
        ^                                     |
        |                                     v
    Learning (expertise store) <-- Detection (evals, audit, QA gate)
```

Every quality finding detected becomes a prevention input for future work. Every
successful pattern becomes a template for future builders. Every conflict resolution
becomes a routing signal for future coordination. The system does not just enforce
quality -- it learns what quality means for this specific codebase, team, and domain.
