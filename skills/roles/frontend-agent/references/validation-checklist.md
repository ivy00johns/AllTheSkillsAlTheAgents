# Frontend Agent Validation Checklist

Run ALL before reporting done. Fix failures. Adapt commands for your package manager (npm/pnpm/yarn).

> **The single most important gate is below: actually run the typecheck and any tests the package defines.** Grep-based validation (e.g., "all 9 routes are wired" by counting matches) cannot catch missing dependency declarations, broken type narrowing, or runtime errors. If `tsc --noEmit` reports errors, you are not done.

## Build Verification

Run the project's own scripts for your package — whatever the stack provides:

| Stack | Typecheck | Build | Lint | Test |
|---|---|---|---|---|
| Node (pnpm workspace) | `pnpm --filter <pkg> run typecheck` | `pnpm --filter <pkg> run build` | `pnpm --filter <pkg> run lint` | `pnpm --filter <pkg> run test` |
| Node (npm / yarn) | `npm run typecheck` (in package dir) | `npm run build` | `npm run lint` | `npm test` |
| Elixir (Phoenix LiveView) | `mix compile --warnings-as-errors` | `mix assets.deploy` | `mix credo` | `mix test` |
| Ruby (Rails views) | — | `bundle exec rake assets:precompile` | `bundle exec rubocop` | `bundle exec rspec` |
| Python (Streamlit / Reflex / templates) | `mypy .` | `python -m build` (if applicable) | `ruff check .` | `pytest` |

Common failure (Node workspaces): `Cannot find module '@<scope>/<sibling>'`. The sibling is referenced in an `import` statement but NOT declared in your `package.json` `dependencies`. Add it as `"@<scope>/<sibling>": "workspace:*"` — that's what tells pnpm/npm/yarn to symlink the sibling into `node_modules`. Same principle in Python: `pip install -e ./packages/sibling` won't happen unless the manifest pins it.

## Imports must resolve to declared deps

This applies wherever the language has an explicit dependency manifest (Node `package.json`, Python `pyproject.toml`, Ruby `Gemfile`, Go `go.mod`, Rust `Cargo.toml`). Every non-relative import in your source must correspond to a declared dependency.

```bash
# Node example — list every non-relative import in src/.
grep -rhE '^import .* from "([^.][^"]+)"' src/ \
  | sed -E 's/.*from "([^"]+)".*/\1/' \
  | grep -v '^\.' \
  | sort -u

# Python example — every `import foo` and `from foo import …`.
grep -rhE '^(import |from )([a-zA-Z_][a-zA-Z0-9_]*)' src/ \
  | sed -E 's/^(import|from) ([a-zA-Z_][a-zA-Z0-9_]*).*/\2/' \
  | grep -v '^_' \
  | sort -u
```

For each entry, confirm it appears in the project manifest. **Workspace siblings — declare them explicitly.** Tooling will not auto-symlink a sibling unless your manifest lists it; the resulting "module not found" error looks mysterious until you remember to check.

## Cross-package CSS imports — JS-side, not `@import`

In a workspace where your frontend imports CSS from a sibling package (a design-system package, a shared tokens file, etc.), the `@import` directive inside a `.css` file does NOT reliably resolve through:

- the sibling package's `exports` map
- TypeScript path aliases (`@scope/sibling/*`)
- pnpm/npm/yarn workspace symlinks

PostCSS-import follows the package's `main` field and naively concatenates subpaths; Vite respects the exports map but its CSS plugin doesn't fall back gracefully when your `.css`-extensioned subpath isn't an explicit key. Combinations break in non-obvious ways: `@import '@scope/ui/tokens'` resolves to `<scope/ui/main>/tokens` instead of looking up the export, then errors with `ENOTDIR` or `ENOENT` against a fake path.

**The reliable pattern: import the CSS from your TypeScript/JS entry point, not from a CSS file.** Vite handles JS-side CSS imports natively and the cross-package resolution Just Works.

```ts
// ✅ apps/web/src/main.tsx — JS-side CSS import via relative workspace path
import '../../../packages/ui/src/tokens.css';
import './styles/global.css';
```

```css
/* ❌ apps/web/src/styles/global.css — don't try to @import a workspace sibling */
@import '@scope/ui/tokens';            /* breaks: postcss-import + main field */
@import '@scope/ui/src/tokens.css';    /* breaks: exports map filters by key */
@import '../../../packages/ui/src/tokens.css';  /* breaks: postcss-import cwd */
```

The relative path inside a JS import is stable because Vite resolves it against the importing file's directory. CSS imports in CSS files are not the same — they go through a different resolver with different cwd semantics.

If you genuinely need the CSS imported from another CSS file (e.g., a Tailwind layer), use Vite's plugin layer (`vite-plugin-postcss-import` with a custom resolver) — but for 95% of cases, importing from `main.tsx` is the right answer.

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
