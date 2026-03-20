# 02 — Architecture

## The SPA Shell

Mission Control uses Next.js 16 App Router in a non-standard way: it is a **single-page application** that renders all 26+ panels through a single catch-all route, switching views by updating Zustand state rather than navigating to different URLs.

```
┌─────────────────────────────────────────────────────────────┐
│  src/app/layout.tsx         (Server Component)              │
│  ├── ThemeProvider (next-themes, dark default)              │
│  └── <div className="h-screen overflow-hidden">             │
│       └── children                                          │
│                                                             │
│  src/app/[[...panel]]/page.tsx   (Client Component)         │
│  ├── NavRail          (left sidebar)                        │
│  ├── HeaderBar         (top bar)                            │
│  ├── LocalModeBanner   (shown when no gateway)              │
│  ├── UpdateBanner      (shown when new release available)   │
│  ├── PromoBanner       (Pro tier CTA)                       │
│  ├── ContentRouter     (switch on activeTab)                │
│  ├── LiveFeed          (right sidebar, toggleable)          │
│  └── ChatPanel         (floating overlay)                   │
└─────────────────────────────────────────────────────────────┘
```

### Why SPA, Not File-Based Routing?

The entire dashboard lives at `src/app/[[...panel]]/page.tsx` — a Next.js optional catch-all route. This means `/`, `/tasks`, `/agents`, `/tokens`, and every other panel URL all render the same React component. The URL is synced to state but does not trigger a page navigation:

```typescript
// src/app/[[...panel]]/page.tsx
const pathname = usePathname()
const panelFromUrl = pathname === '/' ? 'overview' : pathname.slice(1)

useEffect(() => {
  setActiveTab(panelFromUrl)
}, [panelFromUrl, setActiveTab])
```

NavRail dispatches panel changes via `useNavigateToPanel()` which calls `router.push()`, but the catch-all route means Next.js never unmounts the page component. The `ContentRouter` switch statement selects which panel to render:

```typescript
function ContentRouter({ tab }: { tab: string }) {
  switch (tab) {
    case 'overview':    return <Dashboard />
    case 'tasks':       return <TaskBoardPanel />
    case 'agents':      return <><OrchestrationBar /><AgentSquadPanelPhase3 /></>
    case 'tokens':      return <TokenDashboardPanel />
    // ... 22 more cases
    default:            return <Dashboard />
  }
}
```

This is deliberate, not accidental. The approach preserves:

1. **Persistent WebSocket connections** — the gateway WS connection lives in `useWebSocket()` at the page level and never disconnects on panel switch
2. **Persistent SSE stream** — `useServerEvents()` stays alive across all panel views
3. **Continuous Zustand state** — agents, tasks, activities, chat messages all remain in memory
4. **No remount cost** — switching from Tokens to Tasks is a state update, not a route navigation with data fetching

The tradeoff is that the initial page load is heavier (all panel code ships in one bundle) and SEO is irrelevant (it's a dashboard, not a content site).

### The Three Routes

Only three actual page routes exist in the entire application:

| Route | File | Purpose |
|-------|------|---------|
| `[[...panel]]` | `src/app/[[...panel]]/page.tsx` | Main SPA shell (all panels) |
| `/login` | `src/app/login/page.tsx` | Authentication page |
| `/docs` | `src/app/docs/page.tsx` | OpenAPI documentation (Scalar UI) |

Everything else is an API route (83 route files under `src/app/api/`).

## Next.js Configuration

From `next.config.js`:

```javascript
const nextConfig = {
  output: 'standalone',
  turbopack: {},
  transpilePackages: ['react-markdown', 'remark-gfm'],
  async headers() { /* security headers */ }
}
```

### Key Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `output` | `'standalone'` | Produces a self-contained deployment directory at `.next/standalone/` with `server.js` entry point. No need for `node_modules` in production. |
| `turbopack` | `{}` | Enables Turbopack for dev server (faster HMR). Empty config = defaults. |
| `transpilePackages` | `['react-markdown', 'remark-gfm']` | ESM-only packages that need transpilation for server-side rendering compatibility. |

### Security Headers

Applied to all routes (`/:path*`):

| Header | Value | Notes |
|--------|-------|-------|
| `X-Frame-Options` | `DENY` | Prevents clickjacking |
| `X-Content-Type-Options` | `nosniff` | Prevents MIME-type sniffing |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Standard referrer policy |
| `Content-Security-Policy` | Dynamic (see below) | Restricts resource loading |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | Disables device APIs |
| `Strict-Transport-Security` | Conditional on `MC_ENABLE_HSTS=1` | `max-age=63072000; includeSubDomains; preload` |

The CSP is constructed dynamically based on whether Google OAuth is enabled:

```
default-src 'self';
script-src 'self' 'unsafe-inline' [+ accounts.google.com if Google enabled];
style-src 'self' 'unsafe-inline';
connect-src 'self' ws: wss: http://127.0.0.1:* http://localhost:*;
img-src 'self' data: blob: [+ googleusercontent.com if Google enabled];
font-src 'self' data:;
frame-src 'self' [+ accounts.google.com if Google enabled];
```

Notable: `unsafe-inline` remains in both `script-src` and `style-src`. The README acknowledges this as a known limitation — `unsafe-eval` was removed but inline styles remain for framework compatibility.

## TypeScript Configuration

From `tsconfig.json`:

| Option | Value | Notes |
|--------|-------|-------|
| `target` | `es2017` | Async/await native, no polyfills |
| `module` | `esnext` | ESM module system |
| `moduleResolution` | `bundler` | Next.js bundler-compatible resolution |
| `strict` | `true` | All strict checks enabled |
| `jsx` | `react-jsx` | React 19 JSX transform |
| `incremental` | `true` | Faster rebuilds |
| `noEmit` | `true` | Type-checking only, Next.js handles emit |
| `paths.@/*` | `./src/*` | Clean imports: `@/lib/db`, `@/store`, etc. |
| `plugins` | `[{ "name": "next" }]` | Next.js TypeScript plugin for route type safety |

Includes: `next-env.d.ts`, all `.ts/.tsx` files, `.next/types/**/*.ts`.
Excludes: `node_modules` only.

## Directory Structure

```
mission-control/
├── .data/                          # Runtime data directory
│   ├── mission-control.db          #   SQLite database (WAL mode)
│   ├── mission-control-tokens.json #   Token usage log
│   └── backups/                    #   Scheduled DB backups
│
├── .env.example                    # Environment variable template
├── .github/workflows/              # CI: quality-gate.yml
├── next.config.js                  # Standalone output, Turbopack, security headers
├── tailwind.config.js              # Semantic design tokens, dark mode
├── tsconfig.json                   # Strict mode, @/* alias
├── package.json                    # pnpm, 31 dependencies
│
├── src/
│   ├── proxy.ts                    # Auth gate, CSRF validation, host allowlist
│   │
│   ├── app/
│   │   ├── layout.tsx              # Root layout: ThemeProvider, viewport meta
│   │   ├── globals.css             # CSS variables (HSL design tokens), dark mode
│   │   ├── [[...panel]]/
│   │   │   └── page.tsx            # SPA shell: NavRail + ContentRouter + LiveFeed
│   │   ├── login/
│   │   │   └── page.tsx            # Login page
│   │   ├── docs/
│   │   │   └── page.tsx            # OpenAPI docs (Scalar)
│   │   └── api/                    # 83 API route files
│   │       ├── auth/               #   login, logout, me, google, access-requests, users
│   │       ├── agents/             #   CRUD, heartbeat, wake, soul, comms, message, sync, keys
│   │       │   └── [id]/           #   attribution, diagnostics, memory
│   │       ├── tasks/              #   CRUD, queue, comments, broadcast, outcomes, regression
│   │       │   └── [id]/
│   │       ├── chat/               #   conversations, messages
│   │       ├── claude/sessions/    #   Claude Code session discovery
│   │       ├── connect/            #   Direct CLI connections
│   │       ├── events/             #   SSE stream endpoint
│   │       ├── gateways/           #   Multi-gateway CRUD, connect, health
│   │       ├── github/             #   GitHub Issues sync
│   │       ├── pipelines/          #   Pipeline runs
│   │       ├── projects/           #   Project management
│   │       ├── super/              #   Tenant management, provisioning jobs
│   │       ├── webhooks/           #   CRUD, test, retry, deliveries, verify-docs
│   │       ├── workflows/          #   Workflow templates
│   │       ├── activities/         #   Activity feed
│   │       ├── alerts/             #   Alert rules
│   │       ├── audit/              #   Audit log
│   │       ├── backup/             #   Database backup trigger
│   │       ├── cleanup/            #   Stale data cleanup
│   │       ├── cron/               #   Cron job management
│   │       ├── docs/               #   Knowledge base: tree, content, search
│   │       ├── export/             #   CSV/JSON export
│   │       ├── gateway-config/     #   OpenClaw config editor
│   │       ├── integrations/       #   Integration management
│   │       ├── local/              #   Flight Deck, terminal
│   │       ├── logs/               #   Agent log browser
│   │       ├── memory/             #   Memory file browser
│   │       ├── mentions/           #   @mention resolution
│   │       ├── notifications/      #   Notification CRUD, delivery
│   │       ├── releases/check/     #   GitHub release version check
│   │       ├── scheduler/          #   Background scheduler control
│   │       ├── search/             #   Global search
│   │       ├── sessions/           #   Gateway session management
│   │       ├── settings/           #   App settings
│   │       ├── spawn/              #   Agent session spawning
│   │       ├── standup/            #   Standup report generation
│   │       ├── status/             #   System status + capabilities
│   │       ├── tokens/             #   Token usage data
│   │       └── workload/           #   Workload signals
│   │
│   ├── components/
│   │   ├── ErrorBoundary.tsx       # React error boundary wrapper
│   │   ├── layout/
│   │   │   ├── nav-rail.tsx        # Left sidebar navigation (4 groups, 28 items)
│   │   │   ├── header-bar.tsx      # Top bar (search, notifications, user menu)
│   │   │   ├── live-feed.tsx       # Right sidebar (real-time activity stream)
│   │   │   ├── local-mode-banner.tsx   # "No gateway" warning banner
│   │   │   ├── update-banner.tsx   # "New version available" banner
│   │   │   └── promo-banner.tsx    # Pro tier promotion banner
│   │   ├── dashboard/
│   │   │   └── dashboard.tsx       # Overview dashboard with stat cards
│   │   ├── panels/                 # 30 panel component files
│   │   │   ├── task-board-panel.tsx
│   │   │   ├── agent-squad-panel-phase3.tsx
│   │   │   ├── token-dashboard-panel.tsx
│   │   │   ├── agent-cost-panel.tsx
│   │   │   ├── session-details-panel.tsx
│   │   │   ├── activity-feed-panel.tsx
│   │   │   ├── log-viewer-panel.tsx
│   │   │   ├── memory-browser-panel.tsx
│   │   │   ├── cron-management-panel.tsx
│   │   │   ├── agent-spawn-panel.tsx
│   │   │   ├── webhook-panel.tsx
│   │   │   ├── alert-rules-panel.tsx
│   │   │   ├── notifications-panel.tsx
│   │   │   ├── user-management-panel.tsx
│   │   │   ├── audit-trail-panel.tsx
│   │   │   ├── agent-history-panel.tsx
│   │   │   ├── settings-panel.tsx
│   │   │   ├── gateway-config-panel.tsx
│   │   │   ├── integrations-panel.tsx
│   │   │   ├── multi-gateway-panel.tsx
│   │   │   ├── super-admin-panel.tsx
│   │   │   ├── office-panel.tsx
│   │   │   ├── github-sync-panel.tsx
│   │   │   ├── documents-panel.tsx
│   │   │   ├── standup-panel.tsx
│   │   │   ├── orchestration-bar.tsx
│   │   │   ├── agent-comms-panel.tsx
│   │   │   ├── agent-detail-tabs.tsx
│   │   │   ├── agent-squad-panel.tsx  (legacy, replaced by phase3)
│   │   │   └── pipeline-tab.tsx
│   │   ├── chat/
│   │   │   └── chat-panel.tsx      # Floating agent chat overlay
│   │   ├── hud/                    # HUD-style UI components
│   │   └── ui/                     # Shared UI primitives
│   │
│   ├── lib/                        # Core server + client libraries
│   │   ├── config.ts               # Centralized config from env vars
│   │   ├── db.ts                   # SQLite connection, schema init, seed
│   │   ├── migrations.ts           # 27 schema migrations
│   │   ├── schema.sql              # Base schema (migration 001)
│   │   ├── auth.ts                 # Session management, RBAC, API key auth
│   │   ├── password.ts             # scrypt password hashing
│   │   ├── session-cookie.ts       # Cookie management
│   │   ├── google-auth.ts          # Google OAuth integration
│   │   ├── validation.ts           # Zod schemas for API input
│   │   ├── rate-limit.ts           # In-memory rate limiter
│   │   ├── proxy.ts                # Host allowlist, CSRF, network control
│   │   ├── event-bus.ts            # Server-side EventEmitter singleton
│   │   ├── websocket.ts            # Client-side WebSocket hook (gateway)
│   │   ├── use-server-events.ts    # Client-side SSE hook (local DB events)
│   │   ├── use-smart-poll.ts       # Visibility-aware polling hook
│   │   ├── use-focus-trap.ts       # Accessibility focus trap
│   │   ├── navigation.ts           # useNavigateToPanel hook
│   │   ├── scheduler.ts            # Background task scheduler
│   │   ├── webhooks.ts             # Outbound webhook delivery + retry
│   │   ├── agent-sync.ts           # OpenClaw config to DB sync
│   │   ├── agent-templates.ts      # Agent template management
│   │   ├── claude-sessions.ts      # Claude Code session scanner
│   │   ├── codex-sessions.ts       # Codex session tracking
│   │   ├── device-identity.ts      # Ed25519 identity for gateway auth
│   │   ├── gateway-url.ts          # Gateway WebSocket URL builder
│   │   ├── sessions.ts             # Gateway session management
│   │   ├── github.ts               # GitHub API integration
│   │   ├── mentions.ts             # @mention parsing
│   │   ├── models.ts               # Model catalog (pricing, names)
│   │   ├── token-pricing.ts        # Token cost calculation
│   │   ├── task-costs.ts           # Task-level cost attribution
│   │   ├── task-status.ts          # Task status transitions
│   │   ├── office-layout.ts        # Office panel layout logic
│   │   ├── docs-knowledge.ts       # Knowledge base file system reader
│   │   ├── logger.ts               # Pino logger factory
│   │   ├── client-logger.ts        # Browser-side structured logger
│   │   ├── version.ts              # App version constant
│   │   ├── command.ts              # CLI command execution
│   │   ├── cron-occurrences.ts     # Cron schedule calculation
│   │   ├── json-relaxed.ts         # Relaxed JSON parser
│   │   ├── paths.ts                # Path utilities
│   │   ├── provider-subscriptions.ts # Provider subscription management
│   │   ├── provisioner-client.ts   # Provisioning job client
│   │   ├── super-admin.ts          # Super admin business logic
│   │   ├── utils.ts                # General utilities
│   │   └── __tests__/              # 12 unit test files
│   │
│   ├── store/
│   │   └── index.ts                # Zustand store (795 lines)
│   │
│   ├── test/                       # Test utilities and fixtures
│   └── types/                      # Shared TypeScript type definitions
│
├── tests/                          # 35 Playwright E2E test files
└── docs/                           # Documentation assets
```

## The Zustand Store

The entire client-side state lives in a single Zustand store at `src/store/index.ts` (795 lines). It uses the `subscribeWithSelector` middleware for fine-grained subscriptions.

### State Domains

| Domain | State Fields | Actions |
|--------|-------------|---------|
| **Dashboard Mode** | `dashboardMode` ('full' / 'local'), `gatewayAvailable`, `bannerDismissed`, `subscription` | `setDashboardMode`, `setGatewayAvailable`, `dismissBanner`, `setSubscription` |
| **Update Checker** | `updateAvailable`, `updateDismissedVersion` | `setUpdateAvailable`, `dismissUpdate` |
| **Connection** | `connection` (isConnected, url, reconnectAttempts, latency, sseConnected), `lastMessage` | `setConnection`, `setLastMessage` |
| **Tasks** | `tasks[]`, `selectedTask` | `setTasks`, `setSelectedTask`, `addTask`, `updateTask`, `deleteTask` |
| **Agents** | `agents[]`, `selectedAgent` | `setAgents`, `setSelectedAgent`, `addAgent`, `updateAgent`, `deleteAgent` |
| **Activities** | `activities[]` (capped at 1000) | `setActivities`, `addActivity` |
| **Notifications** | `notifications[]`, `unreadNotificationCount` | `setNotifications`, `addNotification`, `markNotificationRead`, `markAllNotificationsRead` |
| **Comments** | `taskComments` (Record<taskId, Comment[]>) | `setTaskComments`, `addTaskComment` |
| **Standup** | `standupReports[]`, `currentStandupReport` | `setStandupReports`, `setCurrentStandupReport` |
| **Sessions** | `sessions[]`, `selectedSession` | `setSessions`, `setSelectedSession`, `updateSession` |
| **Logs** | `logs[]` (capped at 1000), `logFilters` | `addLog`, `setLogFilters`, `clearLogs` |
| **Spawn** | `spawnRequests[]` | `addSpawnRequest`, `updateSpawnRequest` |
| **Cron** | `cronJobs[]` | `setCronJobs`, `updateCronJob` |
| **Memory** | `memoryFiles[]`, `selectedMemoryFile`, `memoryContent` | `setMemoryFiles`, `setSelectedMemoryFile`, `setMemoryContent` |
| **Tokens** | `tokenUsage[]`, `availableModels[]` | `addTokenUsage`, `getUsageByModel`, `getTotalCost`, `setAvailableModels` |
| **Chat** | `chatMessages[]` (capped at 500), `conversations[]`, `activeConversation`, `chatInput`, `isSendingMessage`, `chatPanelOpen` | `setChatMessages`, `addChatMessage`, `replacePendingMessage`, `updatePendingMessage`, `removePendingMessage`, `setConversations`, `setActiveConversation`, `setChatInput`, `setIsSendingMessage`, `setChatPanelOpen`, `markConversationRead` |
| **Auth** | `currentUser` | `setCurrentUser` |
| **UI** | `activeTab`, `sidebarExpanded`, `collapsedGroups[]`, `liveFeedOpen` | `setActiveTab`, `toggleSidebar`, `setSidebarExpanded`, `toggleGroup`, `toggleLiveFeed` |

### Notable Design Patterns

**localStorage persistence for UI state.** Sidebar expansion, collapsed nav groups, and live feed visibility are persisted to `localStorage` and restored on mount:

```typescript
sidebarExpanded: (() => {
  if (typeof window === 'undefined') return false
  try { return localStorage.getItem('mc-sidebar-expanded') === 'true' } catch { return false }
})(),
```

**Collection caps.** Logs are capped at 1000, chat messages at 500, and activities at 1000 to prevent memory growth in long-running sessions.

**Deduplication.** Both `addLog` and `addChatMessage` check for existing IDs before inserting to handle duplicate events from SSE/WebSocket.

**Computed getters.** `getUsageByModel(timeframe)` and `getTotalCost(timeframe)` compute derived state on demand rather than storing aggregates.

**No middleware stack.** Unlike Redux patterns, there is no action logging, no persistence middleware, no devtools integration. The store is pure state + setters.

## Tailwind Configuration

### Design Token System

The Tailwind config at `tailwind.config.js` defines a semantic color system built on CSS custom properties with HSL values:

```
┌─────────────────────────────────────────────┐
│  CSS Variables (globals.css)                │
│  --background: 240 10% 3.9%    (dark)       │
│  --primary: 210 100% 52%       (dark)       │
│  --card: 240 10% 5.5%          (dark)       │
│  --border: 240 4% 16%          (dark)       │
│  ...                                        │
├─────────────────────────────────────────────┤
│  Tailwind Config (tailwind.config.js)       │
│  background: hsl(var(--background))         │
│  primary.DEFAULT: hsl(var(--primary))       │
│  card.DEFAULT: hsl(var(--card))             │
│  border: hsl(var(--border))                 │
│  ...                                        │
├─────────────────────────────────────────────┤
│  Component Usage                            │
│  className="bg-background text-foreground"  │
│  className="bg-card border-border"          │
│  className="text-primary"                   │
└─────────────────────────────────────────────┘
```

### Color Palette

| Token | Purpose | Light HSL | Dark HSL |
|-------|---------|-----------|----------|
| `background` | Page background | `0 0% 100%` | `240 10% 3.9%` |
| `foreground` | Default text | `240 10% 3.9%` | `0 0% 95%` |
| `card` | Card surfaces | `0 0% 100%` | `240 10% 5.5%` |
| `primary` | Accent actions | `240 5.9% 10%` | `210 100% 52%` |
| `secondary` | Secondary surfaces | `240 4.8% 95.9%` | `240 5% 12%` |
| `muted` | Subdued elements | `240 4.8% 95.9%` | `240 5% 15%` |
| `destructive` | Danger/delete | `0 84.2% 60.2%` | `0 63% 31%` |
| `success` | Success states | `142 71% 45%` | `142 71% 45%` |
| `warning` | Warning states | `38 92% 50%` | `38 92% 50%` |
| `info` | Info states | `217 91% 60%` | `217 91% 60%` |

Dark mode uses `darkMode: 'class'` — toggled by next-themes adding/removing the `dark` class on `<html>`. Default theme is dark.

### Surface Hierarchy

Four surface levels are defined for depth layering:

```
surface-0  →  Base background (darkest in dark mode)
surface-1  →  Elevated cards
surface-2  →  Popovers, dropdowns
surface-3  →  Tooltips, highest elevation
```

### Custom Animations

| Name | Duration | Use |
|------|----------|-----|
| `fade-in` | 0.15s ease-out | Panel transitions |
| `slide-in-right` | 0.2s ease-out | Side panel reveal |
| `slide-in-left` | 0.2s ease-out | Navigation transitions |
| `pulse-dot` | 2s infinite | Status indicator dots |

### Custom Spacing and Typography

- Font size `2xs`: `0.625rem` (10px) — used for compact status indicators
- Spacing `18`: `4.5rem`, `88`: `22rem`, `112`: `28rem`, `128`: `32rem` — used for fixed-width sidebars and panel widths

## The .data/ Directory

All runtime state lives in a single directory, defaulting to `.data/` in the project root:

```
.data/
├── mission-control.db              # SQLite database (WAL mode)
├── mission-control.db-wal          # WAL journal (auto-managed)
├── mission-control.db-shm         # Shared memory (auto-managed)
├── mission-control-tokens.json     # Token usage log (JSON)
└── backups/                        # Scheduled database backups
    ├── mc-backup-2026-03-01_12-00-00.db
    └── mc-backup-2026-03-02_12-00-00.db
```

Configuration from `src/lib/config.ts`:

```typescript
export const config = {
  dataDir:    process.env.MISSION_CONTROL_DATA_DIR || '.data',
  dbPath:     process.env.MISSION_CONTROL_DB_PATH  || '.data/mission-control.db',
  tokensPath: process.env.MISSION_CONTROL_TOKENS_PATH || '.data/mission-control-tokens.json',
  // ...
}
```

The config module handles standalone mode path resolution — when running from `.next/standalone/`, it normalizes `process.cwd()` back to the project root:

```typescript
const runtimeCwd = process.cwd()
const normalizedCwd = runtimeCwd.endsWith(path.join('.next', 'standalone'))
  ? path.resolve(runtimeCwd, '..', '..')
  : runtimeCwd
```

### Data Retention

Configurable via environment variables with sensible defaults:

| Data Type | Default Retention | Env Var |
|-----------|------------------|---------|
| Activities | 90 days | `MC_RETAIN_ACTIVITIES_DAYS` |
| Audit log | 365 days | `MC_RETAIN_AUDIT_DAYS` |
| Logs | 30 days | `MC_RETAIN_LOGS_DAYS` |
| Notifications | 60 days | `MC_RETAIN_NOTIFICATIONS_DAYS` |
| Pipeline runs | 90 days | `MC_RETAIN_PIPELINE_RUNS_DAYS` |
| Token usage | 90 days | `MC_RETAIN_TOKEN_USAGE_DAYS` |
| Gateway sessions | 90 days | `MC_RETAIN_GATEWAY_SESSIONS_DAYS` |

## Client-Side Hooks

### Real-Time Communication

Mission Control uses a **dual-channel** real-time architecture:

```
┌─────────────┐         ┌──────────────────────┐
│  Browser    │◄──SSE───│  Next.js Server      │
│             │         │  /api/events          │
│             │         │  (local DB mutations) │
│             │         └──────────────────────┘
│             │
│             │         ┌──────────────────────┐
│             │◄──WS────│  OpenClaw Gateway    │
│             │         │  (agent events,      │
│             │         │   session updates,   │
│             │         │   logs, spawns)       │
└─────────────┘         └──────────────────────┘
```

**`useServerEvents()`** — connects to `/api/events` via `EventSource`. Dispatches local DB mutation events (task CRUD, agent updates, chat messages, notifications, activities) directly to the Zustand store. Reconnects with exponential backoff (base 1s, max 30s, up to 20 attempts).

**`useWebSocket()`** — connects to the OpenClaw gateway via WebSocket. Handles session updates, logs, spawn results, cron status, and gateway events. Implements protocol version 3 with Ed25519 device identity challenge-response. Ping/pong heartbeat every 30 seconds, 3 missed pongs triggers reconnect.

**`useSmartPoll(callback, intervalMs, options)`** — visibility-aware polling that pauses when the browser tab is hidden and optionally pauses when SSE or WebSocket connections are active. Always fires an initial fetch on mount. Supports interval backoff when no new data is returned:

```typescript
interface SmartPollOptions {
  pauseWhenConnected?: boolean      // Pause when WS is connected
  pauseWhenDisconnected?: boolean   // Pause when WS is disconnected
  pauseWhenSseConnected?: boolean   // Pause when SSE is active
  backoff?: boolean                 // Enable interval backoff
  maxBackoffMultiplier?: number     // Default: 3x
  enabled?: boolean                 // Gate polling on condition
}
```

### Navigation

**`useNavigateToPanel()`** — wraps Next.js `router.push()` for panel navigation. Returns a callback that accepts a panel ID and pushes the URL. The catch-all route means this never triggers a full page navigation:

```typescript
export function useNavigateToPanel() {
  const router = useRouter()
  return useCallback((panel: string) => {
    router.push(panel === 'overview' ? '/' : `/${panel}`)
  }, [router])
}
```

## Layout Components

### NavRail (`src/components/layout/nav-rail.tsx`)

The left sidebar organizes 28 navigation items into 4 groups:

| Group | ID | Items |
|-------|----|-------|
| **Core** | `core` | Overview, Agents*, Tasks, Sessions, Office, Documents |
| **Observe** | `observe` | Activity, Logs, Tokens, Agent Costs, Memory |
| **Automate** | `automate` | Cron, Spawn*, Webhooks, Alerts, GitHub |
| **Admin** | `admin` | Users, Audit, History, Gateways, Config*, Integrations, Workspaces, Super Admin, Settings |

Items marked with `*` have `requiresGateway: true` and are hidden in local-only mode.

Features:
- Collapsible groups with localStorage persistence
- Expandable sidebar (icon-only vs icon+label) toggled with `[` keyboard shortcut
- Mobile: renders as a bottom bar with priority items only
- Desktop: vertical rail on the left side
- Active tab highlighted with primary color
- Connection status indicator (WS connected/disconnected)

### HeaderBar (`src/components/layout/header-bar.tsx`)

Top bar containing:
- Panel title (derived from `activeTab`)
- Global search trigger
- Notification bell with unread count
- User menu (profile, theme toggle, logout)

### LiveFeed (`src/components/layout/live-feed.tsx`)

Right sidebar showing real-time activity stream. Toggleable — state persisted to localStorage via `liveFeedOpen` in Zustand. Hidden on mobile. When closed, a floating chevron button appears at the right edge to reopen.

### Banners

Three conditional banners stack below the HeaderBar:

1. **LocalModeBanner** — shown when `dashboardMode === 'local'` (no gateway connection). Informational, not dismissible.
2. **UpdateBanner** — shown when `updateAvailable` is set and the version hasn't been dismissed. Checks GitHub releases via `/api/releases/check`.
3. **PromoBanner** — Pro tier CTA. Dismissible.

## The Event Bus

The server-side event bus (`src/lib/event-bus.ts`) is a singleton `EventEmitter` that bridges database mutations to SSE clients:

```
API Route (e.g., POST /api/tasks)
  │
  ▼
eventBus.emit('task.created', { id, title, ... })
  │
  ▼
GET /api/events (SSE endpoint)
  │  Listens on eventBus, pushes to EventSource
  ▼
Browser: useServerEvents() → Zustand store update
```

Supported event types:

| Event | Trigger |
|-------|---------|
| `task.created` / `task.updated` / `task.deleted` / `task.status_changed` | Task CRUD operations |
| `agent.created` / `agent.updated` / `agent.deleted` / `agent.synced` / `agent.status_changed` | Agent lifecycle |
| `chat.message` / `chat.message.deleted` | Chat operations |
| `notification.created` / `notification.read` | Notification system |
| `activity.created` | Activity logging |
| `audit.security` | Security events |
| `connection.created` / `connection.disconnected` | Direct CLI connections |
| `github.synced` | GitHub Issues sync |

Max listeners set to 50 (handles up to 50 concurrent SSE clients).

## The Startup Flow

When Mission Control starts (either `pnpm dev` or `pnpm start`), the initialization sequence is:

```
1. Next.js server starts
       │
       ▼
2. First API request triggers getDatabase()
       │
       ▼
3. SQLite connection opened
   ├── WAL mode enabled
   ├── synchronous = NORMAL
   ├── cache_size = 1000
   └── foreign_keys = ON
       │
       ▼
4. runMigrations(db)
   └── 27 migrations applied (001_init through 027_agent_api_keys)
       │
       ▼
5. seedAdminUserFromEnv(db)
   └── Creates admin user from AUTH_USER/AUTH_PASS if no users exist
       │
       ▼
6. initWebhookListener()
   └── Subscribes event bus → processes outbound webhooks
       │
       ▼
7. initScheduler()  (skipped during `next build`)
   ├── Registers background tasks:
   │   ├── Database backup (configurable interval)
   │   ├── Stale data cleanup
   │   ├── Agent heartbeat monitoring
   │   ├── Webhook retry processing
   │   ├── Claude Code session scanning (every 60s)
   │   └── Gateway session pruning
   └── Starts tick interval
       │
       ▼
8. Browser loads [[...panel]]/page.tsx
   ├── Fetches /api/auth/me (redirect to /login if 401)
   ├── Fetches /api/releases/check (update banner)
   ├── Fetches /api/status?action=capabilities
   │   ├── If gateway=false → local mode
   │   └── If gateway=true → connect WebSocket
   ├── Connects SSE (useServerEvents)
   └── Renders NavRail + ContentRouter + LiveFeed
```

Steps 3-7 are lazy — they happen on the first database access, not on server start. This means the Next.js server starts fast and initializes the database subsystem on first request. The guard `process.env.NEXT_PHASE !== 'phase-production-build'` prevents the scheduler from running during `next build` static generation.

## Standalone Deployment Model

The `output: 'standalone'` setting in `next.config.js` produces a self-contained deployment at `.next/standalone/`:

```
.next/standalone/
├── server.js                    # Entry point: node server.js
├── node_modules/                # Only production dependencies (pruned)
├── .next/
│   └── ... (compiled assets)
└── public/                      # Static files (if any)
```

This means:
- **No `pnpm install` in production** — all needed `node_modules` are bundled
- **Single deployable artifact** — copy the standalone directory and run `node server.js`
- **Works with Docker** — `COPY .next/standalone ./` in Dockerfile
- **E2E tests run against this** — Playwright hits `node .next/standalone/server.js` on port 3005

The standalone binary binds to `0.0.0.0:${PORT:-3000}` in production (all interfaces) vs `127.0.0.1:${PORT:-3000}` in dev (localhost only).
