# Frontend Agent Validation Checklist

Run ALL before reporting done. Fix failures. Adapt commands for your package manager (npm/pnpm/yarn).

> **The single most important gate is below: actually run the typecheck and any tests the package defines.** Grep-based validation (e.g., "all 9 routes are wired" by counting matches) cannot catch missing dependency declarations, broken type narrowing, or runtime errors. If `tsc --noEmit` reports errors, you are not done.

## Build Verification

```bash
# Run the package's own scripts via the workspace package manager so workspace-deps resolve correctly.
pnpm --filter <your-package> run typecheck   # zero type errors (TS projects)
pnpm --filter <your-package> run build       # zero build errors
pnpm --filter <your-package> run lint        # zero lint errors (warnings OK)
pnpm --filter <your-package> run test        # if a test script exists
```

Common failure: `Cannot find module '@<workspace-scope>/<sibling>'`. This means the sibling package is referenced in your code (an `import` statement) but NOT declared in your `package.json` `dependencies`. Add it as `"@<workspace-scope>/<sibling>": "workspace:*"`. The dep declaration is what tells the package manager to symlink the sibling into your `node_modules`.

## Imports must resolve to declared deps

```bash
# List every import path used in src/, then verify each is in package.json (deps + devDeps + peerDeps).
# If any import is unresolvable, the typecheck above will already flag it — but be aware of the failure mode.
grep -rhE '^import .* from "([^.][^"]+)"' src/ \
  | sed -E 's/.*from "([^"]+)".*/\1/' \
  | grep -v '^\.' \
  | sort -u
```

For each entry, confirm it appears as a key under `dependencies`, `devDependencies`, or `peerDependencies` in your `package.json`. **Workspace siblings (e.g., `@bazaar/contracts`) MUST be declared explicitly** — pnpm/npm will not symlink them into `node_modules` otherwise, and you'll get `TS2307: Cannot find module` errors that look mysterious until you check the manifest.

## Build Verification (continued)

## Dev Server

```bash
npm run dev             # Starts without errors, no console errors in browser
```

## API Contract Compliance

```bash
# Find all API calls — verify each matches the contract
grep -rn "fetch\|axios\|\.get\|\.post\|\.put\|\.delete" src/ \
  --include="*.ts" --include="*.tsx" --include="*.jsx" \
  --include="*.vue" --include="*.svelte"
```

For each call found: URL matches contract exactly, HTTP method matches, request body shape matches, response destructuring matches contracted shape, errors handled per error envelope.

## Environment Variable Audit

```bash
# Zero hardcoded API URLs in source
grep -rn "localhost\|127\.0\.0\.1" src/ \
  --include="*.ts" --include="*.tsx" --include="*.jsx" \
  --include="*.vue" --include="*.svelte" \
  | grep -v "node_modules" | grep -v ".env"
# Each match should reference an env variable, not a literal URL
```

## CORS Verification

If the backend is running: open dev tools, Network tab, trigger an API call, verify zero CORS errors.

If the backend is not yet available: flag CORS verification as **BLOCKED** in your completion report. Do NOT skip it silently.

## Route Verification

- Every defined route renders without errors
- 404/not-found route displays for undefined paths
- Protected routes redirect unauthenticated users (if auth is in contract)
- Browser back/forward navigation works correctly

## Visual Verification

- Primary user flow works end-to-end
- Empty states display correctly
- Loading states appear during API calls
- Error states appear when backend is down
- Responsive at 375px width (mobile) and 1440px (desktop)
- Zero console errors or warnings during primary user flow

## Accessibility Verification

- Tab through every interactive element — focus indicator visible on each
- Every `<input>` has an associated `<label>` or `aria-label`
- Every `<button>` has descriptive text (not just an icon)
- Every `<img>` has meaningful `alt` text
- Loading and error states use `aria-live="polite"` or `role="status"`
- No keyboard traps — Tab/Shift+Tab can reach and leave every control
