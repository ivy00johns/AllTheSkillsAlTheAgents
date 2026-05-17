# Screenshot Organization and Report Output

How runs are laid out on disk, and the exact format of the structured + human-readable reports.

## Output Directories

All outputs go into gitignored directories at the project root:

- **`playwright-screenshots/<run-id>/`** — PNG screenshots captured during the run
- **`playwright-results/<run-id>/`** — test reports, traces, and the structured JSON summary

The `<run-id>` is a timestamp: `YYYY-MM-DD_HH-MM-SS` (e.g., `2026-04-08_14-32-07`).

These directories are gitignored — they exist for local review only, never committed.

## Screenshot Naming Convention

Within a run directory, screenshots follow this layout:

```text
playwright-screenshots/<run-id>/
  <flow-name>/
    01-<step-description>.png
    02-<step-description>.png
    ...
```

Example:

```text
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

After a run completes, produce two files in the results directory.

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

## Spot-Check Mode Notes

Screenshots still go into the timestamped directory even in spot-check mode — they're useful for later reference. Workflow:

1. Launch the browser visibly — the user is watching
2. Before each action, tell the user what you're about to do: "Navigating to /login, looking for the login form"
3. After each action, describe what happened and capture a screenshot
4. Ask: "Looks good? Should I continue to the next step?"
5. If the user flags an issue, capture it and note it in your findings
6. At the end, ask if they want a full report or just a notes file with their observations

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

Common issues — see also `references/setup.md` for full troubleshooting.

- **"Browser closed unexpectedly"** — missing system dependencies; run `npx playwright install-deps chromium`
- **"Navigation timeout"** — service isn't running; verify the URL is reachable first
- **"No usable sandbox"** — on Linux without proper sandbox; use `chromiumSandbox: false` in config (not for production)
- **Screenshots are blank** — page hasn't finished rendering; add `waitForLoadState('networkidle')` before capture
