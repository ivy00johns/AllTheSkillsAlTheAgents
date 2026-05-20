---
name: playwright
version: 1.2.0
description: |
  Run browser-based E2E tests, capture screenshots, and validate user flows using Playwright with visible Chrome. Use this skill when testing a web UI end-to-end, capturing screenshots for visual review, running user journey validation, checking responsive layouts, verifying frontend behavior in a real browser, or performing accessibility audits. Trigger on: "browser test", "screenshot", "e2e test", "visual regression", "test in chrome", "playwright", "click through the UI", "verify the user flow", "responsive layout check", "accessibility audit". Also use when qe-agent needs browser-level integration testing.
requires_agent_teams: false
requires_claude_code: true
min_plan: starter
owns:
  directories: []
  patterns: []
  shared_read: ["*"]
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"]
composes_with: ["qe-agent", "frontend-agent", "deployment-checklist"]
spawned_by: ["orchestrator", "qe-agent"]
---

# Playwright

Run browser-based E2E tests with visible Chrome, capture screenshots at each interaction point, and produce structured reports or interactive spot-check sessions.

## Two Modes

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

## Workflow

1. **Determine what to test.** Translate inputs (plan excerpt, acceptance criteria, user request) into a list of user flows. See `references/selectors-guide.md` for how to structure each flow as navigate → interact → assert → screenshot.

2. **Write the test script** in non-headless Chromium so screenshots show the real rendered UI. See `references/selectors-guide.md` for the standard `test.use({ headless: false })` block, key patterns (`waitForLoadState('networkidle')`, descriptive screenshot names, multi-viewport runs), and the accessibility quick-check snippet.

3. **Execute the run.** The standard `RUN_ID=$(date +%Y-%m-%d_%H-%M-%S)` command for both `@playwright/test` runner and standalone `npx tsx` execution is in `references/selectors-guide.md`.

4. **Lay out the outputs.** All runs go under `playwright-screenshots/<run-id>/` (PNG screenshots) and `playwright-results/<run-id>/` (reports, traces, JSON). Both directories are gitignored. See `references/screenshot-workflow.md` for the exact directory layout and naming convention.

5. **Produce the report.** Report mode emits two files in the results directory: `playwright-report.json` (structured) and `playwright-report.md` (human-readable). See `references/screenshot-workflow.md` for the exact JSON schema and markdown template.

## Spot-Check Mode

In spot-check mode, the browser is visible, you narrate each step, the user approves before you continue, and screenshots still land in the timestamped directory. Full workflow is in `references/screenshot-workflow.md`.

## Coordination with QE Agent

When spawned by qe-agent during Phase 2 (Integration Verification): qe-agent provides base URL + flows + acceptance criteria; you return `playwright-report.json` + the screenshot directory path; qe-agent incorporates the findings into the overall QA report. Full handoff details — and standalone invocation — are in `references/screenshot-workflow.md`.

## Troubleshooting

Common issues and fixes are in `references/screenshot-workflow.md`; the full troubleshooting guide is in `references/setup.md`. Quick checklist:

- "Browser closed unexpectedly" → missing system deps; `npx playwright install-deps chromium`
- "Navigation timeout" → service isn't running; verify the URL first
- "No usable sandbox" (Linux) → `chromiumSandbox: false` (non-production only)
- Blank screenshots → add `waitForLoadState('networkidle')` before capture

## Reference Files

- `references/setup.md` — installation and configuration
- `references/selectors-guide.md` — test-script patterns, key Playwright idioms, accessibility quick-check, run commands
- `references/screenshot-workflow.md` — directory layout, JSON + Markdown report formats, spot-check workflow, QE handoff, troubleshooting
