# Frontend Agent Validation Checklist

Run ALL before reporting done. Fix failures. Adapt commands for your package manager (npm/pnpm/yarn).

## Build Verification

```bash
npx tsc --noEmit        # Zero type errors (TypeScript projects)
npm run build           # Zero build errors
npm run lint            # Zero lint errors (warnings OK)
```

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
