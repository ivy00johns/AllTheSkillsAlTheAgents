# 06 — Frontend Architecture: Panels, Components & Client State

This document covers every panel in Mission Control's SPA shell, the Zustand store, client hooks, layout components, styling patterns, and reusable UI primitives. All file paths are relative to `~/AI/mission-control/`.

---

## 1. SPA Shell Architecture

Mission Control is a Next.js App Router application that functions as a single-page app. The entire UI is rendered by one catch-all route.

### The Entry Point: `src/app/[[...panel]]/page.tsx`

This catch-all route renders every panel. It:

1. **Syncs URL to state**: Extracts panel name from pathname, sets `activeTab` in Zustand
2. **Bootstraps auth**: Fetches `GET /api/auth/me` on mount, redirects to `/login` on 401
3. **Detects capabilities**: Fetches `GET /api/status?action=capabilities` to determine gateway availability
4. **Connects to gateway**: Establishes WebSocket connection if gateway is available
5. **Connects to SSE**: Calls `useServerEvents()` for real-time DB mutation events
6. **Renders the shell**: NavRail + HeaderBar + ContentRouter + LiveFeed + ChatPanel

### Layout Structure

```
┌─────────────────────────────────────────────────────────────┐
│                        HeaderBar (h-12)                      │
├──────┬──────────────────────────────────────┬────────────────┤
│      │                                      │                │
│  Nav │        Main Content Area             │   LiveFeed     │
│  Rail│        (ContentRouter)               │   (w-72)       │
│(w-14 │                                      │                │
│ or   │                                      │                │
│w-220)│                                      │                │
│      │                                      │                │
├──────┴──────────────────────────────────────┴────────────────┤
│                  Mobile Bottom Bar (md:hidden)               │
└─────────────────────────────────────────────────────────────┘
                    ChatPanel (overlay, right side)
```

### ContentRouter

A `switch` statement mapping `activeTab` strings to panel components:

```typescript
function ContentRouter({ tab }: { tab: string }) {
  const { dashboardMode } = useMissionControl()
  const isLocal = dashboardMode === 'local'

  switch (tab) {
    case 'overview':    return <><Dashboard />{!isLocal && <AgentCommsPanel />}</>
    case 'tasks':       return <TaskBoardPanel />
    case 'agents':      return <><OrchestrationBar /><AgentSquadPanelPhase3 />{!isLocal && <AgentCommsPanel />}</>
    case 'activity':    return <ActivityFeedPanel />
    // ... 20+ more cases
    default:            return <Dashboard />
  }
}
```

Notable: The `overview` and `agents` tabs compose multiple panels together. The `AgentCommsPanel` is conditionally shown only when a gateway is connected (`!isLocal`).

---

## 2. NavRail — Navigation Component

**File**: `src/components/layout/nav-rail.tsx`

### Desktop: Collapsible Sidebar

- Default width: `w-14` (icon-only) / `w-[220px]` (expanded with labels)
- Toggle via button or keyboard shortcut `[`
- Sidebar state persisted to `localStorage` (`mc-sidebar-expanded`)
- Active item indicated by left blue bar (`w-0.5 h-5 bg-primary rounded-r`)

### Navigation Groups

| Group ID | Label | Items |
|----------|-------|-------|
| `core` | (none) | Overview, Agents*, Tasks, Sessions, Office, Documents |
| `observe` | OBSERVE | Activity, Logs, Tokens, Agent Costs, Memory |
| `automate` | AUTOMATE | Cron, Spawn*, Webhooks, Alerts, GitHub |
| `admin` | ADMIN | Users, Audit, History, Gateways, Config*, Integrations, Workspaces, Super Admin, Settings |

\* = `requiresGateway: true` — disabled in local mode

### Group Collapsing

Groups with labels can be collapsed. Collapsed state is persisted to `localStorage` (`mc-sidebar-groups`).

### Mobile: Bottom Tab Bar

Priority items (Overview, Agents, Tasks, Activity) shown as fixed bottom tabs. A "More" button opens a bottom sheet with all items in a 2-column grid, organized by group.

### Connection Indicator

Bottom of the sidebar shows a colored dot:
- Green pulsing: Gateway connected
- Red: Gateway disconnected
- Blue: Local mode

---

## 3. HeaderBar

**File**: `src/components/layout/header-bar.tsx`

### Left Section
- Current panel title (from `tabLabels` map)
- App version (`v{APP_VERSION}`)

### Center Section (Desktop)
- **Search bar**: `Cmd+K` / `Ctrl+K` shortcut, searches via `GET /api/search?q=...&limit=12`
  - Results typed by entity: task (T), agent (A), activity (E), audit (S), message (M), notification (N), webhook (W), pipeline (P)
  - Each type has a color-coded icon badge
- **Session count**: `{active}/{total}` format
- **Connection badge**: Gateway status with latency display
- **SSE badge**: Shows "Live" or "Off" with blue/gray dot

### Right Section
- `DigitalClock` component
- Chat toggle button
- Notification bell with unread badge (`9+` for > 9)
- `ThemeToggle` (dark/light)
- User avatar menu (initials, role display, password change dialog, sign out)

### Search Implementation
- Debounced (250ms) text input
- Results rendered in a floating overlay
- Click navigates to the relevant panel
- Escape or outside click closes

---

## 4. LiveFeed

**File**: `src/components/layout/live-feed.tsx`

Right-side panel (hidden on mobile, `hidden lg:flex`) showing a unified real-time feed.

### Data Sources
- **Logs**: Gateway WebSocket events (last 30)
- **Activities**: DB activities from SSE (last 20)
- **Sessions** (local mode only): Session status events (last 10)

All items are merged, sorted by timestamp (newest first), and truncated to 40 items.

### Collapsible States
- **Expanded** (`w-72`): Full feed with message text, source, and relative timestamps
- **Collapsed** (`w-10`): Mini dots showing error/warn/info colors
- **Closed**: Hidden entirely, replaced by a floating `<` button on the right edge

LiveFeed open state persisted to `localStorage` (`mc-livefeed-open`).

### Bottom Section
Shows "Active Sessions" mini-list: up to 4 active sessions with green dots, session keys, and model names.

---

## 5. Complete Panel Inventory

### 5.1 Core Operations

#### Overview / Dashboard
**File**: `src/components/dashboard/dashboard.tsx`
**Route**: `/` or `/overview`
**Data**: `GET /api/status?action=dashboard`, `GET /api/sessions`, `GET /api/claude/sessions` (local mode), `GET /api/github?action=stats` (local mode)

The main dashboard with stat cards showing: active sessions, online agents, running tasks, error count, DB size, audit events. Uses `useSmartPoll` with 60s interval, pauses when WebSocket is connected. Shows system stats, database stats, Claude session stats (local mode), and GitHub stats (local mode). Also embeds `AgentCommsPanel` below in gateway mode.

#### Task Board
**File**: `src/components/panels/task-board-panel.tsx`
**Route**: `/tasks`
**Data**: `GET /api/tasks`

Kanban-style task board with columns: Inbox, Assigned, In Progress, Review, Quality Review, Done. Features:
- Drag-and-drop between columns (status updates)
- Task detail modal with `useFocusTrap` for accessibility
- Priority color coding (critical=red, high=orange, medium=blue, low=gray)
- Agent assignment via dropdown
- Markdown descriptions via `MarkdownRenderer`
- Project/ticket reference display
- URL deep-linking via search params
- `AgentAvatar` for assigned agents

#### Agent Squad (Phase 3)
**File**: `src/components/panels/agent-squad-panel-phase3.tsx`
**Route**: `/agents`
**Data**: `GET /api/agents`

Agent management with tabbed detail view per agent:
- **Overview tab**: Status, role, last activity, task stats
- **Soul tab**: SOUL.md content viewer/editor
- **Memory tab**: Working memory browser
- **Tasks tab**: Agent's assigned/in-progress tasks
- **Activity tab**: Agent-specific activity feed
- **Config tab**: Agent configuration JSON editor

Additional features:
- Heartbeat polling to check agent responsiveness
- Template-based agent creation modal
- `AgentAvatar` with deterministic color hashing
- Soul template selection on creation

Wrapped by `OrchestrationBar` which shows workflow templates and pipeline execution.

#### Sessions
**File**: `src/components/panels/session-details-panel.tsx`
**Route**: `/sessions`
**Data**: `GET /api/sessions`

Gateway session listing with: session key, model, token counts (input/output/context), active/idle status, age. Uses `useSmartPoll` at 60s with `pauseWhenConnected`.

#### Office
**File**: `src/components/panels/office-panel.tsx`
**Route**: `/office`
**Data**: `GET /api/agents`, session data

Visual agent workspace with two view modes:
- **Office view**: Pixel-art floor plan with agent "seats" positioned via `buildOfficeLayout()`
- **Org chart**: Hierarchical view segmentable by category, role, or status

Animated agent movement between seats, zoomable canvas.

#### Documents
**File**: `src/components/panels/documents-panel.tsx`
**Route**: `/documents`
**Data**: `GET /api/docs/tree`, `GET /api/docs/content?path=...`, `GET /api/docs/search?q=...`

File tree browser for project documentation:
- Tree navigation with expand/collapse
- Markdown content rendering via `MarkdownRenderer`
- Full-text search across documents
- File path display and modification timestamps

### 5.2 Observation & Monitoring

#### Activity Feed
**File**: `src/components/panels/activity-feed-panel.tsx`
**Route**: `/activity`
**Data**: `GET /api/activities`

Chronological stream of all system activities (task created, agent status change, comment added, etc.) with:
- Type-specific icons and color coding
- Entity context cards showing related task/agent details
- Infinite scroll or pagination
- Uses `useSmartPoll`

#### Log Viewer
**File**: `src/components/panels/log-viewer-panel.tsx`
**Route**: `/logs`
**Data**: Gateway WebSocket events, `GET /api/logs`

Real-time log stream with:
- Level filtering (info/warn/error/debug)
- Source filtering (available sources auto-detected)
- Text search
- Auto-scroll toggle
- Log entry count (capped at 1000 in Zustand store)
- Uses `useSmartPoll`

#### Token Dashboard
**File**: `src/components/panels/token-dashboard-panel.tsx`
**Route**: `/tokens`
**Data**: `GET /api/tokens?action=stats&timeframe=...`, `GET /api/tokens?action=trends&timeframe=...`

Token usage analytics with Recharts visualizations:
- Line chart: Token usage trends over time
- Bar chart: Usage by model
- Pie chart: Cost distribution
- Summary stats: total tokens, total cost, request count, averages
- Timeframe selector: hour/day/week/month
- CSV export functionality

#### Agent Costs
**File**: `src/components/panels/agent-cost-panel.tsx`
**Route**: `/agent-costs`
**Data**: `GET /api/tokens?action=agent-costs&timeframe=...`

Per-agent cost breakdown with Recharts:
- Pie chart of cost distribution across agents
- Per-agent expandable detail with model breakdown
- Timeline chart of agent spending
- Timeframe selector: hour/day/week/month

#### Memory Browser
**File**: `src/components/panels/memory-browser-panel.tsx`
**Route**: `/memory`
**Data**: `GET /api/memory`

File tree explorer for agent memory/state files:
- Hierarchical directory browser
- File content viewer
- File size and modification timestamps
- Different behavior in local vs gateway mode

### 5.3 Automation & Scheduling

#### Cron Management
**File**: `src/components/panels/cron-management-panel.tsx`
**Route**: `/cron`
**Data**: `GET /api/cron`

Cron job management with calendar views:
- Create/edit/delete cron jobs
- Schedule syntax: standard cron expressions
- Calendar views: agenda, day, week, month (via `getCronOccurrences()`)
- Model selection for LLM-powered cron tasks
- Enable/disable toggle
- Last run status and error display

#### Agent Spawn
**File**: `src/components/panels/agent-spawn-panel.tsx`
**Route**: `/spawn`
**Requires**: Gateway

On-demand agent spawning:
- Task description input
- Model selector (from `availableModels`)
- Label and timeout configuration
- Spawn request history with status tracking (pending/running/completed/failed)

#### Webhook Management
**File**: `src/components/panels/webhook-panel.tsx`
**Route**: `/webhooks`
**Data**: `GET /api/webhooks`

Outbound webhook configuration:
- Create/edit/delete webhooks
- URL, event filter, and secret management
- Delivery history with status codes
- Success/failure counts
- Enable/disable toggle
- Test delivery trigger
- Uses `useSmartPoll`

#### Alert Rules
**File**: `src/components/panels/alert-rules-panel.tsx`
**Route**: `/alerts`
**Data**: `GET /api/alerts`

Configurable alert rules:
- Entity type targeting: agent, task, session, activity
- Condition operators: equals, not_equals, greater_than, less_than, contains, count_above, count_below, age_minutes_above
- Cooldown configuration (minutes)
- Trigger count and last triggered timestamp
- Rule evaluation results display
- Enable/disable toggle

#### GitHub Sync
**File**: `src/components/panels/github-sync-panel.tsx`
**Route**: `/github`
**Data**: `GET /api/github`

GitHub issue synchronization:
- Repository configuration (owner/repo format)
- Issue listing with labels, assignees, state
- Sync operations: pull issues, push comments, close issues
- Sync history and error tracking
- Agent assignment from GitHub issues

### 5.4 Communication

#### Agent Comms
**File**: `src/components/panels/agent-comms-panel.tsx`
**Route**: Embedded in Overview and Agents pages
**Data**: `GET /api/messages`

Inter-agent communication visualization:
- Message graph showing agent-to-agent communication edges
- Per-agent sent/received stats
- Coordinator agent highlighting
- Recent message timeline
- Uses `useSmartPoll`

#### Standup
**File**: `src/components/panels/standup-panel.tsx`
**Route**: `/standup`
**Data**: `GET /api/standup`

Daily standup report generation:
- Per-agent report: completed today, in progress, assigned, blocked
- Team accomplishments and blockers summary
- Overdue task highlighting
- Historical report browsing by date

#### Notifications
**File**: `src/components/panels/notifications-panel.tsx`
**Route**: `/notifications`
**Data**: `GET /api/notifications?recipient=...`

Agent-targeted notification inbox:
- Recipient selector (persisted to localStorage)
- Notification types: mention, assignment, status_change, due_date
- Read/unread status
- Source entity linking
- Mark as delivered action
- Uses `useSmartPoll`

#### Chat Panel
**File**: `src/components/chat/chat-panel.tsx`
**Route**: Overlay (toggle via header)

Slide-over chat panel with sub-components:
- `ConversationList` (`src/components/chat/conversation-list.tsx`) — Thread listing with unread counts
- `MessageList` (`src/components/chat/message-list.tsx`) — Chronological message display
- `MessageBubble` (`src/components/chat/message-bubble.tsx`) — Individual message rendering
- `ChatInput` (`src/components/chat/chat-input.tsx`) — Message composition

Features:
- Conversation-based threading
- Pending message states (sending/sent/failed)
- Optimistic updates with rollback
- Mobile-responsive (full width on small screens)
- Real-time via SSE and WebSocket
- Message deduplication (server ID check)
- Capped at 500 messages per conversation in store

### 5.5 Administration

#### User Management
**File**: `src/components/panels/user-management-panel.tsx`
**Route**: `/users`
**Data**: `GET /api/auth/users`, `GET /api/auth/access-requests`

Admin-only user administration:
- User listing with role, provider, approval status
- Create local users with password policy
- Edit roles (admin/operator/viewer)
- Delete users (with self-delete protection)
- Google OAuth access request review (approve/reject with role assignment)

#### Audit Trail
**File**: `src/components/panels/audit-trail-panel.tsx`
**Route**: `/audit`
**Data**: `GET /api/audit`

Admin-only security event browser:
- Action-specific labels and color coding (login=green, failures=red, password changes=amber)
- Filter by action type and actor
- IP address and user agent display
- Detail JSON expansion
- Pagination with offset/limit
- Uses `useSmartPoll`

#### Agent History
**File**: `src/components/panels/agent-history-panel.tsx`
**Route**: `/history`
**Data**: `GET /api/activities?actor=...`, session data

Agent-specific historical activity:
- Per-agent activity timeline
- Session history
- Type-colored activity entries
- Uses `useSmartPoll`

#### Gateway Config
**File**: `src/components/panels/gateway-config-panel.tsx`
**Route**: `/gateway-config`
**Requires**: Gateway

Gateway `openclaw.json` configuration editor:
- Tree view of config sections
- Inline value editing
- Section expand/collapse
- Feedback on save (success/error)

#### Multi-Gateway Manager
**File**: `src/components/panels/multi-gateway-panel.tsx`
**Route**: `/gateways`
**Data**: `GET /api/gateways`

Multi-gateway topology management:
- Gateway listing with status, latency, session/agent counts
- Primary gateway designation
- Direct connection tracking per agent
- WebSocket URL builder via `buildGatewayWebSocketUrl()`

#### Integrations
**File**: `src/components/panels/integrations-panel.tsx`
**Route**: `/integrations`
**Data**: `GET /api/integrations`

Environment variable and service integration status:
- Categorized integration listing
- Per-integration env var status (set/not set, redacted values)
- 1Password vault item references
- Integration test execution
- Bulk pull from vault

#### Super Admin / Workspaces
**File**: `src/components/panels/super-admin-panel.tsx`
**Route**: `/super-admin` or `/workspaces`
**Data**: `GET /api/super/tenants`, `GET /api/super/jobs`

Multi-tenant provisioning panel with three tabs:
- **Tenants**: List, create (bootstrap), decommission
- **Jobs**: Provision job queue with approve/reject/execute workflow
- **Events**: Provision event log with step-level detail

Two-person rule enforcement on live jobs.

#### Settings
**File**: `src/components/panels/settings-panel.tsx`
**Route**: `/settings`
**Data**: `GET /api/settings`

Categorized settings editor:
- Categories: General, Data Retention, Gateway, Custom
- Key-value editing with descriptions
- Default value indicators
- Last updated by/at tracking
- Admin-only access

#### Orchestration Bar
**File**: `src/components/panels/orchestration-bar.tsx`
**Route**: Rendered above Agent Squad

Workflow template and pipeline management:
- Workflow template CRUD (name, prompt, model, timeout, tags)
- Pipeline builder (multi-step template chains)
- Pipeline execution against agents
- Template use count tracking
- Includes `PipelineTab` sub-component (`src/components/panels/pipeline-tab.tsx`)

---

## 6. Zustand Store

**File**: `src/store/index.ts`

Single store created with `subscribeWithSelector` middleware:

```typescript
export const useMissionControl = create<MissionControlStore>()(
  subscribeWithSelector((set, get) => ({ ... }))
)
```

### State Domains

| Domain | State Keys | Actions |
|--------|-----------|---------|
| Dashboard Mode | `dashboardMode`, `gatewayAvailable`, `bannerDismissed`, `subscription` | `setDashboardMode`, `setGatewayAvailable`, `dismissBanner`, `setSubscription` |
| Updates | `updateAvailable`, `updateDismissedVersion` | `setUpdateAvailable`, `dismissUpdate` |
| WebSocket | `connection`, `lastMessage` | `setConnection`, `setLastMessage` |
| Tasks | `tasks`, `selectedTask` | `setTasks`, `setSelectedTask`, `addTask`, `updateTask`, `deleteTask` |
| Agents | `agents`, `selectedAgent` | `setAgents`, `setSelectedAgent`, `addAgent`, `updateAgent`, `deleteAgent` |
| Activities | `activities` | `setActivities`, `addActivity` (capped at 1000) |
| Notifications | `notifications`, `unreadNotificationCount` | `setNotifications`, `addNotification`, `markNotificationRead`, `markAllNotificationsRead` |
| Comments | `taskComments` (Record<number, Comment[]>) | `setTaskComments`, `addTaskComment` |
| Standup | `standupReports`, `currentStandupReport` | `setStandupReports`, `setCurrentStandupReport` |
| Sessions | `sessions`, `selectedSession` | `setSessions`, `setSelectedSession`, `updateSession` |
| Logs | `logs`, `logFilters` | `addLog` (capped at 1000, dedup by ID), `setLogFilters`, `clearLogs` |
| Spawn | `spawnRequests` | `addSpawnRequest`, `updateSpawnRequest` |
| Cron | `cronJobs` | `setCronJobs`, `updateCronJob` |
| Memory | `memoryFiles`, `selectedMemoryFile`, `memoryContent` | `setMemoryFiles`, `setSelectedMemoryFile`, `setMemoryContent` |
| Tokens | `tokenUsage` | `addTokenUsage`, `getUsageByModel(timeframe)`, `getTotalCost(timeframe)` |
| Models | `availableModels` | `setAvailableModels` (initialized from `MODEL_CATALOG`) |
| Chat | `chatMessages`, `conversations`, `activeConversation`, `chatInput`, `isSendingMessage`, `chatPanelOpen` | `setChatMessages`, `addChatMessage`, `replacePendingMessage`, `updatePendingMessage`, `removePendingMessage`, `setConversations`, `setActiveConversation`, `setChatInput`, `setIsSendingMessage`, `setChatPanelOpen`, `markConversationRead` |
| Auth | `currentUser` | `setCurrentUser` |
| UI | `activeTab`, `sidebarExpanded`, `collapsedGroups`, `liveFeedOpen` | `setActiveTab`, `toggleSidebar`, `setSidebarExpanded`, `toggleGroup`, `toggleLiveFeed` |

### Key Implementation Details

**Deduplication**: `addLog` checks for existing log by ID before inserting. `addChatMessage` skips if a message with the same server ID already exists.

**Capping**: Logs capped at 1000 entries, chat messages at 500 per conversation, activities at 1000.

**Computed values**: `getUsageByModel(timeframe)` and `getTotalCost(timeframe)` use `get()` to compute from raw `tokenUsage` array with date filtering.

**localStorage persistence**: `sidebarExpanded`, `collapsedGroups`, `liveFeedOpen`, `updateDismissedVersion` all read from localStorage on store creation and persist on change.

**`subscribeWithSelector` middleware**: Enables fine-grained subscriptions to specific store slices, so components only re-render when their slice changes.

---

## 7. Client Hooks

### 7.1 `useWebSocket` — Gateway Connection

**File**: `src/lib/websocket.ts`

Manages the WebSocket connection to the OpenClaw gateway.

```typescript
export function useWebSocket() {
  // Returns: { connect, disconnect, send, isConnected, reconnect }
}
```

Key features:
- **Protocol v3**: Gateway frame format with `type: 'event' | 'req' | 'res'`
- **Device identity**: Uses Ed25519 keys for challenge-response auth during connect
- **Heartbeat**: Ping every 30s, max 3 missed pongs before disconnect
- **Reconnection**: Exponential backoff, max 10 attempts
- **Non-retryable errors**: Certain gateway errors stop reconnection
- **Message routing**: Dispatches `session_update`, `log`, `event`, `spawn_result`, `cron_status`, `pong` to Zustand store

### 7.2 `useServerEvents` — SSE Connection

**File**: `src/lib/use-server-events.ts`

Connects to `GET /api/events` (Server-Sent Events) for real-time DB mutation events.

```typescript
export function useServerEvents() {
  // Connects on mount, reconnects on error (max 20 attempts, exponential backoff)
  // Dispatches events to Zustand: addTask, updateTask, deleteTask, addAgent, updateAgent,
  //   addChatMessage, addNotification, addActivity
}
```

SSE is the primary real-time channel for local DB changes (tasks, agents, chat). The WebSocket handles gateway-specific events (sessions, logs, spawn results). Both can run simultaneously.

### 7.3 `useSmartPoll` — Visibility-Aware Polling

**File**: `src/lib/use-smart-poll.ts`

```typescript
export function useSmartPoll(
  callback: () => void | Promise<void>,
  intervalMs: number,
  options?: {
    pauseWhenConnected?: boolean      // Pause when WS connected
    pauseWhenDisconnected?: boolean   // Pause when WS disconnected
    pauseWhenSseConnected?: boolean   // Pause when SSE connected
    backoff?: boolean                 // Enable interval backoff on errors
    maxBackoffMultiplier?: number     // Default: 3x
    enabled?: boolean                 // Conditional enable
  }
) → manualTrigger: () => void
```

Features:
- **Visibility-aware**: Pauses when tab is hidden, fires immediately when tab becomes visible
- **Always bootstraps**: Initial fetch fires on mount regardless of SSE/WS state
- **Connection-aware pausing**: Can pause based on WebSocket or SSE connection state
- **Error backoff**: Optionally increases interval by 0.5x on errors (up to `maxBackoffMultiplier`)
- **Returns manual trigger**: Callers can force an immediate poll

Used by: Dashboard (60s, `pauseWhenConnected`), SessionDetails (60s, `pauseWhenConnected`), ActivityFeed, LogViewer, AuditTrail, WebhookPanel, AgentHistory, and more.

### 7.4 `useMissionControl` — Zustand Store Hook

**File**: `src/store/index.ts`

The primary store hook. Every panel imports this. The `subscribeWithSelector` middleware allows selective subscriptions:

```typescript
const { activeTab, connection } = useMissionControl()
```

### 7.5 `useNavigateToPanel` — URL-Synced Navigation

**File**: `src/lib/navigation.ts`

```typescript
export function useNavigateToPanel() {
  const router = useRouter()
  return useCallback((panel: string) => {
    router.push(panel === 'overview' ? '/' : `/${panel}`)
  }, [router])
}
```

Used by NavRail, HeaderBar (search results, notifications), and various panels for cross-panel navigation.

### 7.6 `useFocusTrap` — Accessible Modal Focus

**File**: `src/lib/use-focus-trap.ts`

```typescript
export function useFocusTrap(onClose?: () => void) → containerRef
```

Traps keyboard focus within a container element:
- Tab/Shift+Tab cycles through focusable elements
- Escape calls `onClose`
- Saves and restores previous focus on unmount
- Queries all focusable elements: `a[href]`, `button:not([disabled])`, `input`, `select`, `textarea`, `[tabindex]`

Used by: TaskBoardPanel's task detail modal, various dialog overlays.

---

## 8. Reusable UI Components

### 8.1 `AgentAvatar`

**File**: `src/components/ui/agent-avatar.tsx`

Generates colored circular avatars from agent names:

```typescript
export function AgentAvatar({ name, size = 'sm', className = '' })
```

- Sizes: `xs` (20px), `sm` (24px), `md` (32px)
- Color: Deterministic HSL from name hash (`hue = hash % 360`, saturation 70%, lightness 38%)
- Text: First two initials (handles single-word and multi-word names)

### 8.2 `OnlineStatus`

**File**: `src/components/ui/online-status.tsx`

Simple online/offline indicator with colored dot and text.

### 8.3 `DigitalClock`

**File**: `src/components/ui/digital-clock.tsx`

24-hour format clock (`HH:MM`), updates every 10 seconds. Renders as `text-xs text-muted-foreground digital-clock`.

### 8.4 `ThemeToggle`

**File**: `src/components/ui/theme-toggle.tsx`

Dark/light mode toggle using `next-themes`:

```typescript
const { theme, setTheme } = useTheme()
// Renders sun icon (in dark mode) or moon icon (in light mode)
```

Handles hydration mismatch with mounted state check (renders placeholder skeleton until mounted).

### 8.5 `ErrorBoundary`

**File**: `src/components/ErrorBoundary.tsx`

React class component error boundary:
- Catches render errors in child component tree
- Shows error message with "Try again" button
- Logs errors via `createClientLogger('ErrorBoundary')`
- Accepts optional `fallback` prop for custom error UI
- Used as `<ErrorBoundary key={activeTab}>` in ContentRouter — `key` change resets boundary on tab switch

### 8.6 `MarkdownRenderer`

**File**: `src/components/markdown-renderer.tsx`

Markdown rendering with `react-markdown` and `remark-gfm`:

```typescript
export function MarkdownRenderer({ content, preview = false })
```

Features:
- GFM support (tables, strikethrough, task lists)
- Preview mode: first paragraph, max 240 chars
- Custom component overrides for all elements (headings, paragraphs, lists, code, blockquotes, links)
- Inline code: `bg-surface-2 text-primary` styling
- Block code: `bg-surface-2 border border-border` with overflow scroll
- Links: `target="_blank" rel="noopener noreferrer"`

---

## 9. Styling Patterns

### 9.1 Tailwind Semantic Tokens

Mission Control uses CSS custom properties mapped to Tailwind classes for theme-aware styling:

| Token | Usage |
|-------|-------|
| `text-foreground` | Primary text |
| `text-muted-foreground` | Secondary/dim text |
| `bg-background` | Page background |
| `bg-card` | Card/panel backgrounds |
| `bg-secondary` | Hover states, secondary surfaces |
| `bg-primary` | Accent/brand color |
| `text-primary` | Accent text, active items |
| `text-primary-foreground` | Text on primary backgrounds |
| `border-border` | All borders |
| `bg-destructive` | Error states |
| `bg-muted` | Disabled/muted backgrounds |
| `bg-popover` / `text-popover-foreground` | Tooltip/dropdown |
| `bg-surface-2` | Code blocks, deeper surfaces |

### 9.2 Dark Mode

Managed by `next-themes`:
- Theme preference stored automatically
- `ThemeToggle` component switches between `dark` and `light`
- All colors use CSS variables that change with theme class

### 9.3 Common CSS Classes

| Pattern | Meaning |
|---------|---------|
| `transition-smooth` | Custom transition timing |
| `font-mono-tight` | Monospace font with tighter tracking |
| `text-2xs` | Extra-small text (custom size) |
| `pulse-dot` | Green pulsing animation for status dots |
| `slide-in-right` | LiveFeed re-entry animation |
| `digital-clock` | Clock-specific monospace styling |
| `safe-area-bottom` | Mobile safe area inset padding |
| `status-online` | Online status animation |

### 9.4 Responsive Breakpoints

| Breakpoint | Usage |
|------------|-------|
| `md:hidden` / `hidden md:flex` | Mobile bottom bar vs desktop sidebar |
| `lg:flex` / `hidden lg:flex` | LiveFeed visibility |
| `min-w-[48px] min-h-[48px]` | Touch target sizing on mobile |

### 9.5 Component Patterns

**Card pattern**: `rounded-xl border border-border bg-card overflow-hidden`

**Button pattern**: `h-8 px-2.5 rounded-md text-xs font-medium transition-smooth`

**Active nav item**: `bg-primary/15 text-primary` with absolute-positioned left bar

**Hover pattern**: `text-muted-foreground hover:text-foreground hover:bg-secondary`

**Badge pattern**: `text-2xs font-medium px-1 py-0.5 rounded bg-{color}-500/20 text-{color}-400`

**Backdrop pattern**: `fixed inset-0 bg-black/40 backdrop-blur-sm` (for modals)

### 9.6 Accessibility

- Skip-to-content link: `<a href="#main-content" className="sr-only focus:not-sr-only ...">Skip to main content</a>`
- `role="navigation"`, `role="banner"`, `role="main"` on layout elements
- `aria-current="page"` on active nav items
- `aria-disabled` on gateway-requiring items in local mode
- `aria-live="polite"` on content area for screen reader announcements
- `useFocusTrap` for modal dialogs
- Keyboard shortcuts: `[` for sidebar toggle, `Cmd/Ctrl+K` for search, `Escape` for close

---

## 10. Data Flow Architecture

### Real-Time Data Channels

```
┌─────────────┐     WebSocket      ┌──────────────┐
│   OpenClaw   │ ←───────────────→  │  Browser UI  │
│   Gateway    │   sessions, logs,  │              │
│              │   spawn, cron      │  Zustand     │
└─────────────┘                     │  Store       │
                                    │              │
┌─────────────┐     SSE (/api/     │              │
│  Next.js     │ ───events)──────→  │              │
│  Server      │   tasks, agents,   │              │
│  (SQLite)    │   chat, notifs     └──────────────┘
└─────────────┘         ↑
       ↑                │
       │           REST polling
       │         (useSmartPoll)
       └────── /api/* endpoints
```

### Polling Hierarchy

1. **SSE** delivers instant DB mutations (preferred)
2. **WebSocket** delivers gateway events (sessions, logs)
3. **REST polling** is the fallback (visibility-aware, pauses when SSE/WS connected)
4. **Initial fetch** always fires on mount (bootstraps component data)

### State Propagation

```
API/SSE/WS Event → Zustand Action → Component Re-render (via selector)
```

The `subscribeWithSelector` middleware ensures only affected components re-render when specific state slices change.

---

## 11. Summary: Frontend Architecture for The Hive

### What to Replicate

1. **SPA catch-all route** — Single `[[...panel]]/page.tsx` simplifies routing
2. **Zustand with subscribeWithSelector** — Fine-grained reactivity without Redux boilerplate
3. **Three-channel real-time** — SSE for DB events, WebSocket for gateway, polling as fallback
4. **useSmartPoll** — Visibility-aware, connection-aware polling with backoff
5. **NavRail with groups** — Collapsible, persisted sidebar state, mobile bottom sheet
6. **ErrorBoundary per panel** — Key-based reset on tab change isolates failures
7. **Semantic Tailwind tokens** — Theme-aware styling without hardcoded colors
8. **useFocusTrap** — Proper modal accessibility
9. **Panel composition** — Some routes compose multiple panels (overview = dashboard + comms)

### What to Improve

1. **Code splitting** — All panels are imported eagerly in page.tsx; use `React.lazy()` + `Suspense`
2. **Server components** — Currently `'use client'` everywhere; leverage server components for initial data
3. **State persistence** — Only UI preferences persist; consider persisting critical data for offline support
4. **Virtual lists** — Activity feeds and log viewers could benefit from virtualization for large datasets
5. **Component library** — Many patterns are repeated inline; extract to a shared component library
6. **Type safety** — Several panels redefine the same interfaces locally instead of importing from store
