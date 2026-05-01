---
name: playwright
version: 1.1.0
description: |
  Run browser-based E2E tests, capture screenshots, and validate user flows using Playwright with visible Chrome. Use this skill when testing a web UI end-to-end, capturing screenshots for visual review, running user journey validation, checking responsive layouts, verifying frontend behavior in a real browser, or performing accessibility audits. Trigger for any Playwright, browser testing, E2E testing, screenshot capture, visual regression, or UI verification task. Also use when qe-agent needs browser-level integration testing.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed_tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
composes_with: ["qe-agent", "frontend-agent", "deployment-checklist"]
spawned_by: ["orchestrator", "qe-agent"]
---

# Playwright

Run browser-based E2E tests with visible Chrome, capture screenshots at each interaction point, and produce structured reports or interactive spot-check sessions.

## Two Modes

This skill operates in two modes depending on the situation:

### Report Mode (default)

Automated test execution that produces a timestamped run directory with screenshots, a structured JSON report, and a human-readable summary. Use this when running as part of qe-agent's integration phase, CI-adjacent verification, or any time you need a documented record of test results.

### Spot-Check Mode

Interactive session where the user watches the browser and approves each step. Use this when the user says "let me watch", "spot check", "walk me through", or otherwise indicates they want to observe and approve in real time. In this mode, pause after each navigation or interaction, describe what's on screen, and wait for the user's go-ahead before continuing.

## Setup

Before running any tests, verify Playwright is available. Read `references/setup.md` for the full installation and configuration flow.

Quick check:

```bash
# Check if Playwright is installed
npx playwright --version 2>/dev/null || echo "NOT_INSTALLED"
```

If not installed, install it along with the Chromium browser:

```bash
npm init -y 2>/dev/null  # ensure package.json exists
npm install -D @playwright/test
npx playwright install chromium
```

## Output Directories

All outputs go into gitignored directories at the project root:

- **`playwright-screenshots/<run-id>/`** — PNG screenshots captured during the run
- **`playwright-results/<run-id>/`** — test reports, traces, and the structured JSON summary

The `<run-id>` is a timestamp: `YYYY-MM-DD_HH-MM-SS` (e.g., `2026-04-08_14-32-07`).

These directories are gitignored — they exist for local review only, never committed.

## Running Tests

### 1. Determine What to Test

From the inputs you receive (plan excerpt, acceptance criteria, user request), build a list of user flows to verify. Each flow is a sequence of:
- Navigate to URL
- Interact (click, type, select)
- Assert (element visible, text matches, network response correct)
- Screenshot (capture the state for review)

### 2. Write the Test Script

Create a Playwright test file in your run's results directory. The test launches **non-headless Chromium** so screenshots show the actual rendered UI:

```typescript
import { test, expect } from '@playwright/test';

test.use({
  // Non-headless so we get real Chrome rendering for screenshots
  headless: false,
  // Slow down for spot-check mode visibility
  launchOptions: {
    slowMo: process.env.SPOT_CHECK ? 500 : 0,
  },
});
```

Key Playwright patterns:
- **Always wait for network idle** before screenshots: `await page.waitForLoadState('networkidle');`
- **Name screenshots descriptively**: `01-homepage-loaded.png`, `02-login-form-filled.png`, `03-dashboard-after-login.png`
- **Capture full page** when checking layout: `await page.screenshot({ path, fullPage: true });`
- **Capture element** when checking a specific component: `await locator.screenshot({ path });`
- **Multiple viewports** when checking responsive design: test at 1920x1080, 1024x768, and 375x667

### 3. Execute

```bash
RUN_ID=$(date +%Y-%m-%d_%H-%M-%S)
mkdir -p playwright-screenshots/$RUN_ID playwright-results/$RUN_ID

npx playwright test playwright-results/$RUN_ID/test.spec.ts \
  --project=chromium \
  --reporter=json \
  --output=playwright-results/$RUN_ID \
  2>&1 | tee playwright-results/$RUN_ID/output.log
```

If tests are written as standalone scripts (not using `@playwright/test` runner), execute directly:

```bash
npx tsx playwright-results/$RUN_ID/test-script.ts
```

### 4. Screenshot Organization

Within a run directory, screenshots follow this naming convention:

```
playwright-screenshots/<run-id>/
  <flow-name>/
    01-<step-description>.png
    02-<step-description>.png
    ...
```

For example:
```
playwright-screenshots/2026-04-08_14-32-07/
  login-flow/
    01-login-page-loaded.png
    02-credentials-entered.png
    03-dashboard-visible.png
  settings-flow/
    01-settings-page.png
    02-profile-updated.png
```

## Report Mode Output

After a run completes, produce two files in the results directory:

### playwright-report.json

```json
{
  "run_id": "2026-04-08_14-32-07",
  "mode": "report",
  "timestamp": "2026-04-08T14:32:07Z",
  "base_url": "http://localhost:3000",
  "browser": "chromium",
  "headless": false,
  "flows_tested": [
    {
      "name": "login-flow",
      "steps": [
        {
          "description": "Navigate to login page",
          "action": "goto",
          "target": "/login",
          "screenshot": "login-flow/01-login-page-loaded.png",
          "assertions": [
            {"check": "title contains 'Login'", "passed": true}
          ],
          "passed": true
        }
      ],
      "passed": true,
      "duration_ms": 2340
    }
  ],
  "summary": {
    "total_flows": 3,
    "passed": 2,
    "failed": 1,
    "total_screenshots": 12,
    "total_duration_ms": 8500
  }
}
```

### playwright-report.md

Human-readable summary with inline screenshot references. Use this format:

```markdown
# Playwright Test Report
**Run:** 2026-04-08_14-32-07
**URL:** http://localhost:3000
**Browser:** Chromium (non-headless)

## Results: 2/3 flows passed

### login-flow - PASS (2.3s)
1. Navigate to /login - PASS [screenshot: login-flow/01-login-page-loaded.png]
2. Enter credentials - PASS [screenshot: login-flow/02-credentials-entered.png]
3. Verify dashboard - PASS [screenshot: login-flow/03-dashboard-visible.png]

### settings-flow - FAIL (1.8s)
1. Open settings - PASS [screenshot: settings-flow/01-settings-page.png]
2. Update profile - FAIL: Expected "Saved" toast, got timeout
   [screenshot: settings-flow/02-profile-updated.png]

## Failed Assertions
| Flow | Step | Expected | Actual |
|------|------|----------|--------|
| settings-flow | Update profile | "Saved" toast visible | Timeout after 5s |
```

## Spot-Check Mode

When operating interactively:

1. Launch the browser visibly — the user is watching
2. Before each action, tell the user what you're about to do: "Navigating to /login, looking for the login form"
3. After each action, describe what happened and capture a screenshot
4. Ask: "Looks good? Should I continue to the next step?"
5. If the user flags an issue, capture it and note it in your findings
6. At the end, ask if they want a full report or just a notes file with their observations

Screenshots still go into the timestamped directory even in spot-check mode — they're useful for later reference.

## Accessibility Quick-Check

When testing any page, include a basic accessibility scan using Playwright's built-in accessibility tree:

```typescript
const snapshot = await page.accessibility.snapshot();
// Check for missing labels, empty buttons, missing alt text
```

Report accessibility findings in a separate section of the report, noting:
- Interactive elements without accessible names
- Images without alt text
- Contrast issues (if detectable via computed styles)
- Missing ARIA landmarks

This is a quick check, not a full WCAG audit — flag obvious issues, don't claim compliance.

## Coordination with QE Agent

When spawned by qe-agent during Phase 2 (Integration Verification):

- qe-agent provides: base URL, user flows to test, acceptance criteria
- You return: `playwright-report.json` and the screenshot directory path
- qe-agent incorporates your findings into their overall QA report
- Your screenshots serve as evidence for pass/fail assertions in the QA report

When spawned standalone (user invokes directly):
- Ask the user for the URL and what they want to test
- Default to spot-check mode unless they ask for a full report

## Troubleshooting

Common issues and their fixes — read `references/setup.md` for the full troubleshooting guide.

- **"Browser closed unexpectedly"** — missing system dependencies; run `npx playwright install-deps chromium`
- **"Navigation timeout"** — service isn't running; verify the URL is reachable first
- **"No usable sandbox"** — on Linux without proper sandbox; use `chromiumSandbox: false` in config (not for production)
- **Screenshots are blank** — page hasn't finished rendering; add `waitForLoadState('networkidle')` before capture
