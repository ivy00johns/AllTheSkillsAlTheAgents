# 02 — The Browse CLI

## Architecture: Persistent Daemon Model

```
Claude Code → browse CLI (compiled binary)
            → HTTP POST to localhost:<random-port>
            → Bun HTTP server
            → Playwright
            → Headless Chromium (persistent, auto-starts, auto-dies after 30min idle)
```

**Why a daemon?**
- First call: ~3 seconds (Chromium startup)
- Subsequent calls: ~100–200ms (just HTTP + Playwright command)
- Persistent state: cookies, login sessions, open tabs all survive between commands
- Sub-second latency makes agent interaction feel natural

## The Ref System (Key Innovation)

Instead of CSS selectors, agents use `@e1`, `@e2` refs:

1. `snapshot` reads Playwright's accessibility tree (`page.ariaSnapshot()`)
2. Parser assigns sequential `@e` refs to each element
3. For each ref, builds a `Locator` (Playwright's abstraction, no DOM mutation)
4. Later commands: `click @e3` → lookup Locator → `locator.click()`

**Why Locators, not DOM injection?**
- CSP blocks DOM mutation on production sites
- React/Vue hydration strips injected attributes
- Shadow DOM is unreachable from outside
- Locators are external to DOM — always work

**Ref Staleness Detection:**
- SPAs mutate DOM without navigation (tab switches, modals, infinite scroll)
- Before using any ref, `resolveRef()` does async `count()` check
- If count=0, throws immediately: "Ref @e3 is stale — run 'snapshot'"
- Fails fast (~5ms) instead of waiting for 30-second Playwright timeout

## Command Catalog (50+)

### Navigation
`goto`, `back`, `forward`, `reload`, `url`

### Reading (Non-Mutating)
`text`, `html`, `links`, `forms`, `accessibility`, `js`, `eval`, `css`, `attrs`

### Interaction (Mutating)
`click`, `fill`, `select`, `hover`, `type`, `press`, `scroll`, `wait`,
`viewport`, `upload`, `dialog-accept`

### Inspection
`console`, `network`, `dialog`, `cookies`, `storage`, `perf`,
`is` (element state check — visible? enabled? checked?)

### Visual
`screenshot` (full-page, viewport-only, element-crop, region-clip),
`pdf`, `responsive` (multi-viewport comparison), `diff` (visual diff)

### Snapshot Flags
`-i` (interactive only), `-c` (compact), `-d N` (depth limit),
`-D` (diff vs previous), `-a` (annotate with ref labels),
`-C` (cursor-interactive non-ARIA elements)

### Tabs
`tabs`, `tab <id>`, `newtab`, `closetab`

### Utilities
`chain` (batch commands as JSON array),
`cookie-import` (from file),
`cookie-import-browser` (decrypt from Chrome/Arc/Brave/Edge via macOS Keychain)

## Security Model

- **Localhost-only** HTTP binding (never exposed externally)
- **Random port** selection (10000–60000) — supports 10+ parallel workspaces
- **Bearer token** auth (UUID, stored in `.gstack/browse.json` with chmod 600)
- **Cookie security:** Read-only DB access, in-memory decryption only, values never logged
- **Shell injection prevention:** Hardcoded command registry, no string interpolation

## Infrastructure Details

- **State file:** `.gstack/browse.json` (atomic write: tmp + rename)
- **Logging:** 3 circular buffers (50K entries each) → `.gstack/browse-{console,network,dialog}.log`
- **Crash recovery:** Browser crash → server exits → CLI detects dead server → auto-restarts
- **Version tracking:** `browse/dist/.version` contains git SHA; CLI auto-restarts server if binary changed
- **Commands registry:** `browse/src/commands.ts` — single source of truth, imported by gen-skill-docs

## Why This Matters

No other AI agent framework has a browser with:
1. Sub-second command latency (daemon model)
2. AI-native element addressing (ref system, not CSS selectors)
3. Staleness detection that prevents phantom clicks
4. Cookie decryption for authenticated QA
5. Persistent sessions that survive across tool calls

This is what enables gstack's QA skills to actually *use* the app like a human would,
at machine speed, with evidence (screenshots, console logs, network traces).
