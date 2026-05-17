---
name: render-sanity
version: 1.0.0
description: |
  Catch the failure modes that pass a "tests green + dev server boots + 0 console errors" gate but visibly break the app when a human clicks around — stale mock IDs leaking into "live" pages, lone `?` / `—` / `undefined` / `Loading…` text where real data should be, repeated generic-fallback labels (the default string a component renders when its data prop is missing) appearing across rows that should show distinct content, "Couldn't load X" / "Unauthorized" / "Failed to fetch" dead-end shells on auth-gated routes, and lists that render plausibly but link to dead targets. Use this skill whenever a build is wrapping up and someone is about to claim "the UI works" without having clicked through it as a real user; whenever ux-review or qe-agent finishes its screenshot/contract pass; whenever the user says "is it actually working", "did anyone click around", "fix the app", "broken pages", "dead links", or after they paste a screenshot showing visible garbage like `?`, `—`, `undefined`, `null`, or a "Not found" detail page. Triggers BEFORE the build is declared done, not after the user finds the bug themselves. Also invoke proactively when a frontend agent has just rewired data sources from mocks → real backend, when auth was added to previously-public routes, when seed data was regenerated, or when a previously-broken page was "fixed" without a click-through verification.
requires_claude_code: true
allowed_tools: ["Read", "Bash", "Glob", "Grep",
  "mcp__plugin_playwright_playwright__browser_navigate",
  "mcp__plugin_playwright_playwright__browser_snapshot",
  "mcp__plugin_playwright_playwright__browser_click",
  "mcp__plugin_playwright_playwright__browser_evaluate",
  "mcp__plugin_playwright_playwright__browser_console_messages",
  "mcp__plugin_playwright_playwright__browser_network_requests"]
composes_with: ["ux-review", "qe-agent", "orchestrator", "frontend-agent", "feature-dev", "playwright"]
spawned_by: ["orchestrator", "ux-review", "qe-agent"]
---

# Render Sanity

> **Why this exists:** "Tests pass, dev server boots, console is clean" is a process bar. It's not the same as "the app works." This skill is the missing semantic check between those two. It catches the failure modes that render plausibly but are quietly broken — the ones that make a user say "did anyone actually click around in this?"

This skill is **not** subjective. It does not evaluate visual hierarchy, typography, or polish — leave those to `ux-review` / `ui-ux-pro-max`. It hunts for four specific, objectively-verifiable failure modes that ship past every other gate.

**Announce at start:** "Using render-sanity to click through [N routes] and check for stale data, placeholder text, dead links, and auth dead-ends."

## The Four Checks

These run in order. Each produces concrete file/route/text evidence — not "feels off."

### Check 1 — Visible-text smell scan

The app may render. The text it renders may be garbage. For every page in the sitemap, grab `document.body.innerText` and look for two classes of pattern:

**A. Universal smells (apply to any project, any stack):**

| Pattern | What it usually means |
|---|---|
| Lone `?` where a name/value should be | A `find()` / `get()` / lookup against a collection that didn't match — usually mock data vs real backend IDs |
| Lone `—`, `--`, or persistent `Loading…` that doesn't resolve after a few seconds | Async fetch never resolved, threw silently, or the loading state is the steady state |
| `undefined`, `null`, `NaN`, `[object Object]`, `Symbol(...)` in user-facing text | Field unwrapping went wrong; a typed contract is being violated |
| `Couldn't load`, `Unauthorized`, `Failed to fetch`, `Not found`, `Forbidden`, `500`, `Internal server error`, `Network error` | Backend rejected the call, the UI is rendering its error state AS the page content. (May be correct on a deep route. Almost never correct on a landing page or top-nav target.) |
| Hardcoded `Lorem ipsum`, `Placeholder`, `TODO`, `FIXME`, `Coming soon` shipped to a "live" page | Stub content that never got replaced |
| Repeated identical fallback strings (e.g. the same generic noun + `@same-handle` across rows where data should differ) | A lookup returning the same default on every miss — almost always a stale mock or wrong ID space |

**B. Project-specific smells (you derive these in Step 1 by reading the project):**

Before scanning, look at the project's mocks / fixtures / seed files (e.g. `mocks.ts`, `__fixtures__/`, `seed.sql`, `factories/`, `dev/seed.json`, anywhere with hardcoded "demo data"). Capture two things:

1. **The mock-ID format.** Mock data typically uses a recognizable, non-cryptographic pattern — sequential UUIDs (`00000000-0000-...`), prefixed slugs (`mock_*`, `demo_*`, `fixture_*`), or pseudo-IDs with a project-specific shape. Any ID matching this pattern appearing on a page that's supposed to come from the real backend is a Critical: the page is wired to mock data instead of the live source.
2. **The placeholder-label vocabulary.** Mock data often uses generic role nouns as default labels (e.g. the generic name of the entity the mock represents — "User", "Item", "Account", "Seller", "Buyer", etc.) plus a corresponding lowercased `@handle`. When a real page renders multiple of these in a context that should show distinct real data, the lookup is missing the real records — that's a Critical too.

Record both findings in Step 1's notes so Step 3's scan knows what to grep for. Do not hardcode patterns from one project into this skill — they vary per project.

When the scan flags something, capture: the route, the matched string, and the surrounding 30 chars. That tuple goes in the Critical Issues section of the report.

**This is not a "warning."** A user-facing `?` or `Couldn't load` is a critical issue, not a polish item.

### Check 2 — Click-through every list

Pages that render a list of links — feed, catalog, search results, dashboard rows, recent items, leaderboards, threads, files, anything iterating a collection into `<a>` tags — are the most common silent-failure surface. The list renders fine; the items link to dead targets.

For every page that renders a list:

1. Take the page's accessibility snapshot.
2. Identify the first list-item link (`<a>` inside the card / row / item container).
3. Read its `href`.
4. Navigate to that href.
5. Confirm the destination page renders real content — not a generic 404, not a domain-specific "X not found" page (whatever the project's missing-resource state is), not an empty shell.

If a list contains many items, you don't need to click all of them — clicking the first is sufficient to catch the systemic "all our list IDs are stale mocks" bug. If the first works and you have time, sample one from the middle and one from the end. The bug pattern this catches is "every link in the list is dead because the data source is wrong," not "this one particular item happens to be missing."

### Check 3 — Signed-out matrix

For every route, navigate to it with no session and record the outcome:

| Outcome | Verdict |
|---|---|
| Public page renders real content | Pass |
| Redirect to `/login` (or equivalent) | Pass |
| Empty shell with persistent "Couldn't load X · Unauthorized" / "Failed to fetch" / blank ledger / `—` everywhere | **Critical** — pick one: gate it with a real auth wall (redirect) OR fall back to a public read-only view. A dead-end-but-still-rendered page is the worst of both. |
| Console errors but no visible error state | Critical — the fetch is throwing, the page is silently broken |
| 500 / unhandled exception in network log | Critical — server bug, not UX |

Record the verdict per route. The matrix lives in the report so the build owner can see which routes need auth wiring vs which need fallback content.

### Check 4 — Signed-in matrix

If the project has any way to log in — seed credentials, a demo button, an OAuth flow with a test account, a magic-link in dev — sign in **once** with a known seeded user and re-walk every auth-gated route. The bar, in the abstract:

- **User-scoped data views** (anything that should reflect WHO is signed in — profile, account, balance, inbox, dashboard, "your X" pages) must show data that actually corresponds to the signed-in user. If the seed gives this user known activity, the page must reflect it. A "logged in but the page is empty / zeroed / generic" outcome where the seed says otherwise is a Critical.
- **User-scoped lists** (your items, your followers, your conversations, your orders, etc.) must show entries that belong to this user. Lists showing the wrong user's data, or showing "0 items" when the seed says this user has items, are Criticals.
- **Counterparty / participant labels** (the other side of any two-party relationship the page is rendering — the other end of a thread, the assignee of a task, the author of a post, the owner of a resource the viewer is inspecting) must resolve to real names/handles — not the generic-fallback label from the placeholder vocabulary you captured in Check 1.
- **Empty states** are FINE when the seed legitimately has no data for this user. The bar is coherence: "Follow some people to see activity here" is good; a 401-shaped error on an authed page is bad.

**Finding seed credentials.** Read the project's seed / fixtures / dev-data files (`db/seed.*`, `fixtures/`, `scripts/seed.*`, `prisma/seed.*`, `factories/`, `.env.example`, `README` "Demo accounts" sections) for the project's seeded user list and their passwords. If the project ships a LoginPage with hardcoded demo defaults or a "demo" button, use those — but verify they actually work against the running auth endpoint first (a quick curl POST is cheaper than discovering at the click that the defaults were never updated when the schema changed).

**If there is no way to sign in** (no seed creds, no working OAuth in dev, broken signup flow) — that itself is a Critical. File it as "Cannot enter the app as any user — sign-in path is broken or undocumented." A logged-in surface that can't be reached is functionally equivalent to no logged-in surface, and Check 4 cannot be performed without one.

**If the project has roles** (admin, owner, member, viewer; buyer/seller; teacher/student; etc.), sign in as at least one user per role that has distinct UI affordances. The "admin sees nothing where a regular user sees a dashboard" case is real and worth checking once, especially if the seed creates users in multiple roles.

## Workflow

### Step 1 — Build the route inventory

Read the router file (`App.tsx`, `app/`, `pages/`, `src/routes/`, etc.) and write down every route. Mark each as **public**, **auth-gated**, or **role-gated** based on visible `<RequireAuth>` / `requireAuth` / middleware patterns. Do this from code, not by clicking — a route that exists in the router but isn't linked from any nav still counts.

If the inventory is large (>20 routes), prioritize by:
1. Routes linked from the navbar (highest signal — a real user lands here)
2. Routes that render lists or accept `:id` params (highest bug density)
3. Auth-gated routes (highest "looks fine but is silently broken" risk)

### Step 2 — Confirm the dev stack is actually up

```bash
# Try the common ports
for p in 3000 3001 4000 4321 5173 8000 8080; do
  if lsof -i :$p -t > /dev/null 2>&1; then
    echo "Port $p is listening"
  fi
done
# Hit the URL and confirm 200
curl -fsS http://localhost:<port>/ > /dev/null && echo "Frontend responsive"
```

If nothing is listening, **stop**. Don't run render-sanity against a dead port and call it a pass. Either bring up the stack (typically `pnpm dev` / `npm run dev` from the project root) or report "Cannot run — dev server not responding."

### Step 3 — Run the four checks

For each route in the inventory:
1. Navigate (Playwright)
2. Snapshot + console + network
3. Run Check 1 (smell scan) on the snapshot's visible text
4. If the page renders a list, run Check 2 (click first item, verify destination)
5. Record outcome in the signed-out matrix (Check 3)

Then sign in as a seed user (or hit the demo button) and re-walk the auth-gated routes for Check 4.

### Step 4 — Write the report

Save to `docs/render-sanity-YYYY-MM-DD.md`. The structure is fixed — every report has the same shape so a reviewer can scan it. The placeholders in angle brackets below are illustrative; each row is a real (route, evidence, verdict) tuple from the run:

```markdown
# Render Sanity — <project> — YYYY-MM-DD

## Stack state
- Dev server: <url> reachable / not reachable (with evidence)
- Sign-in available: yes (mechanism: seed creds / demo button / OAuth / magic-link) / no — REASON
- Project mock-ID pattern (from Step 1): <pattern> (e.g. `mock_*`, prefixed UUIDs, sequential ints)
- Project placeholder vocabulary (from Step 1): <generic-noun + @handle pairs>

## Route inventory
N total — M public, K auth-gated, J role-gated. (Listed below in walk order.)

## Check 1 — Visible-text smells
| Route | Pattern | Matched text | Verdict |
|---|---|---|---|
| <route> | <which pattern from the table> | "<the matched substring>" | CRITICAL / Pass |

## Check 2 — Click-through
| Source list page | First item href | Destination outcome | Verdict |
|---|---|---|---|
| <route> | <href> | <renders real content / "not found" / etc.> | CRITICAL / Pass |

## Check 3 — Signed-out matrix
| Route | Outcome | Verdict |
|---|---|---|
| <auth-gated route> | <redirect / dead-end shell / 500> | CRITICAL / Pass |
| <public route> | <real content renders> | Pass |

## Check 4 — Signed-in matrix
Signed in as: <user / role>
| Route | Outcome | Verdict |
|---|---|---|
| <user-scoped route> | <reflects seeded user data / generic empty / wrong user's data> | CRITICAL / Pass |

## Summary
- Critical: <count>
- Pass: <count>
- Total routes walked: <count> of <inventory size>

[The next agent / orchestrator must fix every Critical before declaring the build done. Polish items belong to ux-review, not here.]
```

### Step 5 — Decide pass/fail

The skill returns a single boolean to whoever invoked it:

- **PASS**: zero critical findings across all four checks.
- **FAIL**: one or more critical findings. The report names them; the build cannot be declared done until they're fixed and render-sanity is re-run.

A FAIL is not a recommendation. It's a gate. The orchestrator's Definition of Done depends on this skill returning PASS on a UI build.

## What this skill is NOT

- **Not visual review.** "The spacing feels off" / "the gradient is harsh" / "this should be 16px" — those are `ux-review`'s problem. This skill does not have an opinion about aesthetics.
- **Not accessibility audit.** Heading hierarchy, ARIA labels, keyboard nav — those are `ux-review` / a11y tooling.
- **Not performance.** Bundle size, LCP, hydration — those are `performance-agent`.
- **Not contract conformance.** Whether the API matches the OpenAPI spec — that's `qe-agent` / `contract-auditor`.
- **Not test coverage.** Whether the unit tests cover this code — that's `qe-agent`.

This skill catches a specific failure mode: **the app renders, but renders broken content that humans can see and machines couldn't tell from the test suite alone.** That's it. Keep it focused.

## When invoked by other skills

- **`orchestrator`** is the primary invoker. It calls render-sanity at Phase 12 (post-build verification) BEFORE `ux-review` — render-sanity catches the broken-content failures; ux-review then assesses polish on a known-good shell. A render-sanity FAIL blocks the build's Definition of Done; ux-review does not run until criticals are fixed and render-sanity re-runs clean.
- **`ux-review`** MAY invoke render-sanity as a precondition to its Phase 2 (Experience). When it does, the render-sanity report becomes the "Critical Issues" section of the ux-review report. If ux-review does not invoke render-sanity directly, the orchestrator's Phase 12 ordering guarantees render-sanity runs first anyway.
- **`qe-agent`** SHOULD invoke render-sanity when its plan includes E2E or "UI reflects backend state after mutations" acceptance criteria. The signed-out/signed-in matrices in particular are inside qe-agent's remit and catch bugs that contract conformance cannot.
- **`feature-dev`** SHOULD invoke render-sanity after a feature is wired end-to-end, before declaring "the feature works." The four checks are the cheapest way to catch "I rewired the data source and forgot something."
- **The user** can invoke this skill directly any time they want a fast, objective answer to "is the UI actually working" — typically after a build claims done, after a refactor, after auth was added, or after seeing a screenshot with `?` / `Couldn't load` / dead links.

## Key principles

- **Concrete evidence beats subjective judgment.** Every finding is a tuple of (route, pattern, matched text) or (source list, first link, destination, outcome). No "feels broken."
- **Click, don't just look.** Lists that render but link to nowhere are this skill's primary catch. Snapshots and screenshots don't catch them. Clicking does.
- **Both auth states.** "It works when I'm logged in" is half a test. "It works when I'm signed out" is the other half. A skill that only walks one state misses the half its build session happened to be in.
- **Treat mock-ID leakage as a P0.** The "frontend imports mocks.ts directly into a 'live' page" bug class is silent, common, and embarrassing. If render-sanity catches a mock ID on a live page, that's not a polish item — that's a "the page is wired to fake data" critical.
- **Refuse to pass a dead stack.** If the dev server isn't listening, this skill must not say "passed." Either bring it up or report that you couldn't run.
