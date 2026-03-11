# Frontend Agent Validation Checklist

## Build Verification
```bash
npx tsc --noEmit        # Zero type errors
npm run build           # Zero build errors
npm run lint            # Zero lint errors (warnings OK)
```

## Dev Server
```bash
npm run dev             # Starts without errors, no console errors
```

## API Contract Compliance
```bash
grep -rn "fetch\|axios\|\.get\|\.post\|\.put\|\.delete" src/ \
  --include="*.ts" --include="*.tsx"
```
For each call: URL matches contract, method matches, request body matches, response destructuring matches, errors handled.

## CORS Verification
With backend running: open dev tools → Network tab → trigger API call → zero CORS errors.

## Visual Verification
- Primary user flow works end-to-end
- Empty states display correctly
- Loading states appear during API calls
- Error states appear when backend is down
- Responsive at ≤375px width
