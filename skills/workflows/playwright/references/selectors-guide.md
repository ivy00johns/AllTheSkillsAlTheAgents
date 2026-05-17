# Selectors and Test-Writing Patterns

Patterns for writing Playwright test scripts that capture useful screenshots and produce reliable assertions.

## Determining What to Test

From the inputs you receive (plan excerpt, acceptance criteria, user request), build a list of user flows to verify. Each flow is a sequence of:

- Navigate to URL
- Interact (click, type, select)
- Assert (element visible, text matches, network response correct)
- Screenshot (capture the state for review)

## Writing the Test Script

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

## Key Playwright Patterns

- **Always wait for network idle** before screenshots: `await page.waitForLoadState('networkidle');`
- **Name screenshots descriptively**: `01-homepage-loaded.png`, `02-login-form-filled.png`, `03-dashboard-after-login.png`
- **Capture full page** when checking layout: `await page.screenshot({ path, fullPage: true });`
- **Capture element** when checking a specific component: `await locator.screenshot({ path });`
- **Multiple viewports** when checking responsive design: test at 1920x1080, 1024x768, and 375x667

## Running the Suite

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
