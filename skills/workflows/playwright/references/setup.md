# Playwright Setup & Configuration

## Installation Check

Run these checks in order. Stop at the first success.

### 1. Check if @playwright/test is installed

```bash
npx playwright --version 2>/dev/null
```

If this returns a version (e.g., `1.52.0`), Playwright is installed. Skip to browser check.

### 2. Check if Chromium browser is available

```bash
npx playwright install --dry-run 2>&1 | grep -i chromium
```

Or simply try launching:

```bash
node -e "
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: false });
  console.log('Chromium OK:', browser.version());
  await browser.close();
})().catch(e => { console.error('FAIL:', e.message); process.exit(1); });
"
```

### 3. Full Installation

If Playwright isn't installed at all:

```bash
# Ensure package.json exists
npm init -y 2>/dev/null

# Install Playwright test framework
npm install -D @playwright/test

# Install Chromium browser binary
npx playwright install chromium

# On Linux, also install system dependencies
npx playwright install-deps chromium
```

### 4. TypeScript Support

If the project uses TypeScript (check for `tsconfig.json`), Playwright's test runner handles `.ts` files natively. For standalone scripts, ensure `tsx` is available:

```bash
npx tsx --version 2>/dev/null || npm install -D tsx
```

## Playwright Configuration

If the project doesn't have a `playwright.config.ts`, you don't necessarily need one — tests can be run with CLI flags. But if the project has one, respect its settings and only override what's needed for screenshots.

### Minimal Config for Screenshot Runs

When you need a config (e.g., for custom viewports or multiple projects):

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './playwright-results',
  timeout: 30_000,
  expect: { timeout: 5_000 },
  fullyParallel: false, // sequential for predictable screenshots
  use: {
    headless: false,
    screenshot: 'on',
    trace: 'on-first-retry',
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
  },
  projects: [
    {
      name: 'desktop',
      use: { ...devices['Desktop Chrome'], headless: false },
    },
    {
      name: 'tablet',
      use: { ...devices['iPad Pro 11'], headless: false },
    },
    {
      name: 'mobile',
      use: { ...devices['iPhone 14'], headless: false },
    },
  ],
});
```

## Responsive Testing Viewports

Standard viewport set for responsive checks:

| Name | Width | Height | Device Scale |
|------|-------|--------|-------------|
| Desktop | 1920 | 1080 | 1 |
| Laptop | 1366 | 768 | 1 |
| Tablet | 1024 | 768 | 2 |
| Mobile | 375 | 667 | 3 |

Use `page.setViewportSize()` to switch between them during a single test, or configure separate Playwright projects for each.

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `BASE_URL` | Target application URL | `http://localhost:3000` |
| `SPOT_CHECK` | Enable slow-motion for interactive review | unset |
| `PW_TIMEOUT` | Global test timeout (ms) | `30000` |

## Troubleshooting

### Browser won't launch

**Symptom:** "Browser closed unexpectedly" or "Failed to launch chromium"

**Fix:** Install system-level dependencies:
```bash
npx playwright install-deps chromium
```

On macOS, this is rarely needed since Playwright bundles its own Chromium. On Linux (especially Docker/CI), it's almost always required.

### Sandbox errors on Linux

**Symptom:** "No usable sandbox" or "Operation not permitted"

**Fix:** Disable sandbox (development/testing only — never in production):
```typescript
const browser = await chromium.launch({
  headless: false,
  args: ['--no-sandbox', '--disable-setuid-sandbox'],
});
```

### Page loads but screenshots are blank

**Symptom:** Screenshots are all white or show partial content

**Fix:** Wait for the page to fully render:
```typescript
await page.goto(url);
await page.waitForLoadState('networkidle');
// For SPAs, also wait for a known element:
await page.waitForSelector('[data-testid="main-content"]');
await page.screenshot({ path: screenshotPath });
```

### Timeout waiting for selector

**Symptom:** Tests time out looking for elements that should exist

**Common causes:**
1. Element is inside an iframe — use `page.frameLocator()`
2. Element is lazy-loaded — increase timeout or wait for a network event
3. Selector is wrong — use Playwright Inspector to verify: `npx playwright codegen <url>`
4. SPA routing hasn't completed — wait for `page.waitForURL()`

### Port conflicts

**Symptom:** "Address already in use" when starting the test server

**Fix:** Check what's on the port before starting:
```bash
lsof -i :3000 | grep LISTEN
```

Kill if needed, or configure a different port via `BASE_URL`.

## Generating Tests with Codegen

Playwright's codegen is useful for quickly scaffolding test scripts:

```bash
npx playwright codegen http://localhost:3000
```

This opens a browser and records your interactions as Playwright test code. Useful for creating initial test scripts that you then refine.
