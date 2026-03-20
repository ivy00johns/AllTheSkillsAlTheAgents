# Phase 8 — Dashboard Polish

**Version:** 0.1.0-draft
**Date:** 2026-03-20
**Status:** Design
**Duration:** 2-3 weeks
**Dependencies:** All prior phases (1-7)
**Deliverables:** Kanban, metrics, timeline blocks; RBAC; audit trail; notifications; performance optimization; E2E test suite

---

## 1. Scope Overview

Phase 8 is the final build phase. It completes the dashboard with the remaining block types, locks down security with role-based access control, adds the notification system, and performs systematic performance optimization and E2E testing at scale.

Seven workstreams run in this phase:

1. **Kanban Block** — Drag-and-drop agent status board (6 columns)
2. **Metrics Block** — Real-time charts for tokens, cost, duration
3. **Timeline Block** — Execution history as Gantt-style swim lanes
4. **RBAC Implementation** — Three roles (Viewer, Operator, Admin) with session + API key auth
5. **Audit Trail Panel** — Read-only state change history with filtering and export
6. **Notification System** — In-app toasts + desktop alerts with preferences
7. **Performance Optimization + E2E Testing** — Memoization audit, SSE tuning, memory profiling, 20-agent test suite

---

## 2. Kanban Block

### 2.1 Design

The kanban block displays all agents as draggable cards organized into 6 status columns. This mirrors the Composio AO + Mission Control pattern of treating agent status as a visual workflow.

**Columns:**

| Column | Status | Color | Description |
|--------|--------|-------|-------------|
| Queued | `queued` | Gray | Agent assigned but not yet started |
| Spawning | `spawning` | Blue | Agent process being created |
| Running | `running` | Green | Agent actively executing |
| Review | `waiting` | Yellow | Agent blocked on approval gate |
| Completed | `completed` | Teal | Agent finished successfully |
| Failed | `failed` | Red | Agent exited with error |

**Card contents:**
- Agent name and role icon
- Current step description (truncated to 1 line)
- Duration timer (live for running agents)
- Token count badge
- Cost badge (e.g., "$0.12")
- Progress bar (for agents that report progress)

### 2.2 Implementation

```typescript
// src/blocks/kanban/KanbanBlock.tsx

import {
  DndContext,
  DragOverlay,
  closestCorners,
  PointerSensor,
  useSensor,
  useSensors,
} from '@dnd-kit/core';
import {
  SortableContext,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';

// CRITICAL: All card components must be React.memo to prevent
// cascading re-renders during drag operations. Without this,
// dragging one card re-renders ALL cards in ALL columns.

const AgentCard = React.memo(function AgentCard({
  agent,
}: {
  agent: AgentState;
}) {
  return (
    <div className="kanban-card">
      <div className="kanban-card-header">
        <RoleIcon role={agent.role} />
        <span className="kanban-card-name">{agent.id}</span>
        <StatusDot status={agent.status} />
      </div>
      <p className="kanban-card-step">{agent.currentStep}</p>
      <div className="kanban-card-footer">
        <DurationBadge startedAt={agent.startedAt} />
        <TokenBadge tokens={agent.tokenUsage} />
        <CostBadge cents={agent.cost} />
      </div>
      {agent.progress > 0 && (
        <ProgressBar value={agent.progress} max={100} />
      )}
    </div>
  );
});

// Column header is also memoized
const ColumnHeader = React.memo(function ColumnHeader({
  title,
  count,
  color,
}: {
  title: string;
  count: number;
  color: string;
}) {
  return (
    <div className="kanban-column-header" style={{ borderColor: color }}>
      <span>{title}</span>
      <span className="kanban-column-count">{count}</span>
    </div>
  );
});

function KanbanBlock({ atoms, config }: BlockProps<KanbanAtoms>) {
  const columns = useAtomValue(atoms.columnsAtom);
  const [activeCard, setActiveCard] = useAtom(atoms.dragStateAtom);

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: { distance: 8 },
    })
  );

  const handleDragStart = useCallback((event: DragStartEvent) => {
    setActiveCard(event.active.id as string);
  }, [setActiveCard]);

  const handleDragEnd = useCallback((event: DragEndEvent) => {
    const { active, over } = event;
    setActiveCard(null);

    if (!over) return;

    const agentId = active.id as string;
    const targetColumn = over.id as string;

    // Manual status override -- send REST command to backend
    updateAgentStatus(agentId, targetColumn);
  }, [setActiveCard]);

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCorners}
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
    >
      <div className="kanban-board">
        {COLUMN_ORDER.map((columnId) => (
          <KanbanColumn
            key={columnId}
            columnId={columnId}
            agents={columns[columnId] ?? []}
          />
        ))}
      </div>

      <DragOverlay>
        {activeCard ? (
          <AgentCard
            agent={findAgent(columns, activeCard)}
          />
        ) : null}
      </DragOverlay>
    </DndContext>
  );
}

const COLUMN_ORDER = [
  'queued', 'spawning', 'running', 'waiting', 'completed', 'failed',
] as const;
```

### 2.3 Jotai Atoms

```typescript
// src/blocks/kanban/atoms.ts

function createKanbanAtoms() {
  type ColumnMap = Record<string, AgentState[]>;

  const columnsAtom = atom<ColumnMap>({
    queued: [],
    spawning: [],
    running: [],
    waiting: [],
    completed: [],
    failed: [],
  });

  const dragStateAtom = atom<string | null>(null);
  const sortOrderAtom = atom<'name' | 'duration' | 'cost'>('name');

  // Derived atom: completion percentage
  const completionAtom = atom((get) => {
    const cols = get(columnsAtom);
    const total = Object.values(cols).flat().length;
    if (total === 0) return 0;
    const done = (cols.completed?.length ?? 0) + (cols.failed?.length ?? 0);
    return Math.round((done / total) * 100);
  });

  // Derived atom: column counts
  const columnCountsAtom = atom((get) => {
    const cols = get(columnsAtom);
    const counts: Record<string, number> = {};
    for (const [key, agents] of Object.entries(cols)) {
      counts[key] = agents.length;
    }
    return counts;
  });

  return {
    columnsAtom,
    dragStateAtom,
    sortOrderAtom,
    completionAtom,
    columnCountsAtom,
  };
}

type KanbanAtoms = ReturnType<typeof createKanbanAtoms>;
```

### 2.4 Real-Time Updates

SSE `STATE_DELTA` events with agent status changes automatically move cards between columns:

```typescript
// In the SSE event router (from Phase 3)
function routeToKanbanAtom(event: OrchestratorEvent, atoms: KanbanAtoms) {
  if (event.type !== 'STATE_DELTA') return;

  const delta = event.delta as { agentId: string; status: string };
  if (!delta.agentId || !delta.status) return;

  // Move the agent card to the new column
  store.set(atoms.columnsAtom, (prev) => {
    const next = { ...prev };
    // Remove from all columns
    for (const [col, agents] of Object.entries(next)) {
      next[col] = agents.filter((a) => a.id !== delta.agentId);
    }
    // Add to target column
    const agent = findAgentById(delta.agentId);
    if (agent && next[delta.status]) {
      next[delta.status] = [...next[delta.status], agent];
    }
    return next;
  });
}
```

---

## 3. Metrics Block

### 3.1 Design

The metrics block renders real-time charts using recharts. Four chart types are available:

| Chart | Type | X-Axis | Y-Axis | Data Source |
|-------|------|--------|--------|------------|
| Tokens/second | Line | Time | tokens/s | SSE metric events |
| Cost per agent | Bar | Agent ID | Cost ($) | Agent state snapshots |
| Phase duration | Bar | Phase # | Duration (min) | Build state |
| Total cost | Area | Time | Cumulative $ | SSE metric events |

### 3.2 Implementation

```typescript
// src/blocks/metrics/MetricsBlock.tsx

import {
  LineChart, Line, BarChart, Bar, AreaChart, Area,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts';

const MetricsBlock = React.memo(function MetricsBlock({
  atoms,
}: BlockProps<MetricsAtoms>) {
  const dataPoints = useAtomValue(atoms.dataPointsAtom);
  const timeWindow = useAtomValue(atoms.timeWindowAtom);
  const selectedChart = useAtomValue(atoms.selectedChartAtom);

  // Filter data points to the selected time window
  const filteredData = useMemo(() => {
    const cutoff = Date.now() - timeWindowToMs(timeWindow);
    return dataPoints.filter((p) => p.timestamp >= cutoff);
  }, [dataPoints, timeWindow]);

  return (
    <div className="metrics-block">
      <MetricsToolbar
        timeWindow={timeWindow}
        selectedChart={selectedChart}
        onTimeWindowChange={(tw) =>
          store.set(atoms.timeWindowAtom, tw)
        }
        onChartChange={(c) =>
          store.set(atoms.selectedChartAtom, c)
        }
      />

      <div className="metrics-chart-container">
        {selectedChart === 'tokens-per-second' && (
          <TokensPerSecondChart data={filteredData} />
        )}
        {selectedChart === 'cost-per-agent' && (
          <CostPerAgentChart data={filteredData} />
        )}
        {selectedChart === 'phase-duration' && (
          <PhaseDurationChart data={filteredData} />
        )}
        {selectedChart === 'total-cost' && (
          <TotalCostChart data={filteredData} />
        )}
      </div>
    </div>
  );
});

// Each chart component is also memoized
const TokensPerSecondChart = React.memo(function TokensPerSecondChart({
  data,
}: {
  data: MetricDataPoint[];
}) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <LineChart data={data}>
        <CartesianGrid strokeDasharray="3 3" />
        <XAxis
          dataKey="timestamp"
          tickFormatter={(ts) => formatTime(ts)}
          domain={['auto', 'auto']}
        />
        <YAxis />
        <Tooltip
          labelFormatter={(ts) => formatTimeFull(ts)}
          formatter={(value: number) => [`${value} tok/s`, 'Throughput']}
        />
        <Line
          type="monotone"
          dataKey="tokensPerSecond"
          stroke="#3b82f6"
          strokeWidth={2}
          dot={false}
          isAnimationActive={false}  // Disable animation for real-time
        />
      </LineChart>
    </ResponsiveContainer>
  );
});
```

### 3.3 Jotai Atoms

```typescript
// src/blocks/metrics/atoms.ts

interface MetricDataPoint {
  timestamp: number;
  tokensPerSecond?: number;
  costCents?: number;
  agentId?: string;
  phaseId?: number;
  phaseDurationMs?: number;
  cumulativeCostCents?: number;
}

type TimeWindow = '5m' | '15m' | '1h' | 'build';
type ChartType =
  | 'tokens-per-second'
  | 'cost-per-agent'
  | 'phase-duration'
  | 'total-cost';

function createMetricsAtoms() {
  const dataPointsAtom = atom<MetricDataPoint[]>([]);
  const timeWindowAtom = atom<TimeWindow>('15m');
  const selectedChartAtom = atom<ChartType>('tokens-per-second');

  // Derived: per-agent cost aggregation
  const costByAgentAtom = atom((get) => {
    const points = get(dataPointsAtom);
    const costs: Record<string, number> = {};
    for (const p of points) {
      if (p.agentId && p.costCents !== undefined) {
        costs[p.agentId] = (costs[p.agentId] ?? 0) + p.costCents;
      }
    }
    return Object.entries(costs).map(([id, cents]) => ({
      agentId: id,
      costCents: cents,
    }));
  });

  return {
    dataPointsAtom,
    timeWindowAtom,
    selectedChartAtom,
    costByAgentAtom,
  };
}

type MetricsAtoms = ReturnType<typeof createMetricsAtoms>;
```

### 3.4 Data Point Management

To keep memory bounded, the metrics block enforces a rolling window of no more than 10,000 data points:

```typescript
function appendMetricDataPoint(
  atoms: MetricsAtoms,
  point: MetricDataPoint
): void {
  store.set(atoms.dataPointsAtom, (prev) => {
    const next = [...prev, point];
    // Evict oldest points if over budget
    if (next.length > 10_000) {
      return next.slice(next.length - 10_000);
    }
    return next;
  });
}
```

---

## 4. Timeline Block

### 4.1 Design

The timeline block displays execution history as a Gantt-chart-style visualization using `react-calendar-timeline`. Each row represents an agent. Items represent task executions with start and end times, color-coded by status.

### 4.2 Implementation

```typescript
// src/blocks/timeline/TimelineBlock.tsx

import Timeline, {
  TimelineHeaders,
  SidebarHeader,
  DateHeader,
} from 'react-calendar-timeline';

interface TimelineGroup {
  id: string;
  title: string;
  rightTitle?: string;  // Role badge
}

interface TimelineItem {
  id: string;
  group: string;        // Agent ID
  title: string;        // Task description
  start_time: number;   // Unix ms
  end_time: number;     // Unix ms
  itemProps: {
    style: {
      background: string;   // Color by status
      borderColor: string;
    };
  };
  status: 'running' | 'completed' | 'failed' | 'waiting';
  agentId: string;
  taskId: string;
}

const TimelineBlock = React.memo(function TimelineBlock({
  atoms,
}: BlockProps<TimelineAtoms>) {
  const groups = useAtomValue(atoms.groupsAtom);
  const items = useAtomValue(atoms.itemsAtom);
  const [timeRange, setTimeRange] = useAtom(atoms.timeRangeAtom);

  const handleItemClick = useCallback((itemId: string) => {
    // Navigate to agent output at the clicked timestamp
    const item = items.find((i) => i.id === itemId);
    if (item) {
      navigateToAgentOutput(item.agentId, item.start_time);
    }
  }, [items]);

  const handleTimeChange = useCallback(
    (start: number, end: number) => {
      setTimeRange({ start, end });
    },
    [setTimeRange]
  );

  return (
    <div className="timeline-block">
      <Timeline
        groups={groups}
        items={items}
        defaultTimeStart={timeRange.start}
        defaultTimeEnd={timeRange.end}
        onTimeChange={handleTimeChange}
        onItemSelect={handleItemClick}
        canMove={false}
        canResize={false}
        lineHeight={40}
        itemHeightRatio={0.75}
        sidebarWidth={150}
      >
        <TimelineHeaders>
          <SidebarHeader>
            {({ getRootProps }) => (
              <div {...getRootProps()}>
                <span className="timeline-sidebar-title">Agent</span>
              </div>
            )}
          </SidebarHeader>
          <DateHeader unit="hour" />
          <DateHeader unit="minute" />
        </TimelineHeaders>
      </Timeline>
    </div>
  );
});

// Status-to-color mapping
const STATUS_COLORS: Record<string, string> = {
  running: '#22c55e',    // Green
  completed: '#14b8a6',  // Teal
  failed: '#ef4444',     // Red
  waiting: '#eab308',    // Yellow
};
```

### 4.3 Jotai Atoms

```typescript
// src/blocks/timeline/atoms.ts

function createTimelineAtoms() {
  const groupsAtom = atom<TimelineGroup[]>([]);
  const itemsAtom = atom<TimelineItem[]>([]);
  const timeRangeAtom = atom<{ start: number; end: number }>({
    start: Date.now() - 60 * 60 * 1000,  // 1 hour ago
    end: Date.now(),
  });
  const selectedItemAtom = atom<string | null>(null);

  return {
    groupsAtom,
    itemsAtom,
    timeRangeAtom,
    selectedItemAtom,
  };
}

type TimelineAtoms = ReturnType<typeof createTimelineAtoms>;
```

### 4.4 Building Timeline Data from Events

```typescript
// Timeline data is built from the event_log table + live SSE events

function buildTimelineFromEvents(
  agents: AgentState[],
  events: EventLogEntry[]
): { groups: TimelineGroup[]; items: TimelineItem[] } {
  const groups: TimelineGroup[] = agents.map((a) => ({
    id: a.id,
    title: a.id,
    rightTitle: a.role,
  }));

  const items: TimelineItem[] = [];

  for (const agent of agents) {
    // Each agent becomes one or more timeline items
    // (one per task/phase they worked on)
    const agentEvents = events.filter((e) => e.agent_id === agent.id);
    const spans = extractSpans(agentEvents);

    for (const span of spans) {
      items.push({
        id: `${agent.id}-${span.taskId}`,
        group: agent.id,
        title: span.description,
        start_time: span.startedAt,
        end_time: span.completedAt ?? Date.now(),
        itemProps: {
          style: {
            background: STATUS_COLORS[span.status] ?? '#6b7280',
            borderColor: STATUS_COLORS[span.status] ?? '#6b7280',
          },
        },
        status: span.status,
        agentId: agent.id,
        taskId: span.taskId,
      });
    }
  }

  return { groups, items };
}
```

---

## 5. RBAC Implementation

### 5.1 Role Definitions

Three roles, matching the master spec (section 12):

| Permission | Viewer | Operator | Admin |
|-----------|--------|----------|-------|
| View dashboard | Yes | Yes | Yes |
| View agent output | Yes | Yes | Yes |
| View metrics/costs | Yes | Yes | Yes |
| Start/pause builds | No | Yes | Yes |
| Approve QA gates | No | Yes | Yes |
| Send commands to agents | No | Yes | Yes |
| Manage agent configs | No | No | Yes |
| Manage plugins | No | No | Yes |
| View audit trail | No | No | Yes |
| Manage users/roles | No | No | Yes |

### 5.2 SQLite Schema

```sql
-- Migration: 008_rbac.sql

-- Users table
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    password_hash TEXT NOT NULL,       -- bcrypt hash
    role TEXT NOT NULL DEFAULT 'viewer',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Check constraint on role values
-- (SQLite doesn't enforce CHECK constraints by default, validate in code)

-- Sessions table (for dashboard UI auth)
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,               -- Random session ID
    user_id TEXT NOT NULL REFERENCES users(id),
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address TEXT,
    user_agent TEXT
);

CREATE INDEX idx_sessions_user ON sessions(user_id);
CREATE INDEX idx_sessions_expires ON sessions(expires_at);

-- API keys table (for CLI/programmatic access)
CREATE TABLE api_keys (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    key_hash TEXT NOT NULL,            -- SHA-256 hash of the API key
    name TEXT NOT NULL,                -- Human-readable label
    permissions TEXT NOT NULL,         -- JSON array of allowed actions
    last_used_at DATETIME,
    expires_at DATETIME,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_api_keys_user ON api_keys(user_id);
CREATE INDEX idx_api_keys_hash ON api_keys(key_hash);

-- Seed: create default admin user (password set on first launch)
-- INSERT INTO users (id, username, display_name, password_hash, role)
-- VALUES ('admin-001', 'admin', 'Administrator', '<bcrypt_hash>', 'admin');
```

### 5.3 Rust Backend Middleware

```rust
// src-tauri/src/auth/middleware.rs

use axum::{
    extract::State,
    http::{Request, StatusCode},
    middleware::Next,
    response::Response,
};

#[derive(Debug, Clone, PartialEq)]
pub enum Role {
    Viewer,
    Operator,
    Admin,
}

#[derive(Debug, Clone, PartialEq)]
pub enum Permission {
    ViewDashboard,
    ViewAgentOutput,
    ViewMetrics,
    StartBuild,
    PauseBuild,
    ApproveGate,
    SendAgentCommand,
    ManageAgentConfig,
    ManagePlugins,
    ViewAuditTrail,
    ManageUsers,
}

impl Role {
    pub fn has_permission(&self, permission: &Permission) -> bool {
        match self {
            Role::Viewer => matches!(permission,
                Permission::ViewDashboard
                | Permission::ViewAgentOutput
                | Permission::ViewMetrics
            ),
            Role::Operator => matches!(permission,
                Permission::ViewDashboard
                | Permission::ViewAgentOutput
                | Permission::ViewMetrics
                | Permission::StartBuild
                | Permission::PauseBuild
                | Permission::ApproveGate
                | Permission::SendAgentCommand
            ),
            Role::Admin => true, // Admin has all permissions
        }
    }
}

/// Middleware: extract session from httpOnly cookie or API key from header
pub async fn auth_middleware<B>(
    State(state): State<AppState>,
    mut req: Request<B>,
    next: Next<B>,
) -> Result<Response, StatusCode> {
    // Try session cookie first
    if let Some(cookie) = req.headers().get("cookie") {
        let session_id = extract_session_id(cookie);
        if let Some(sid) = session_id {
            if let Some(user) = state.db.validate_session(&sid).await {
                req.extensions_mut().insert(user);
                return Ok(next.run(req).await);
            }
        }
    }

    // Try API key header
    if let Some(auth_header) = req.headers().get("authorization") {
        if let Some(api_key) = auth_header.to_str().ok()
            .and_then(|h| h.strip_prefix("Bearer "))
        {
            if let Some(user) = state.db.validate_api_key(api_key).await {
                req.extensions_mut().insert(user);
                return Ok(next.run(req).await);
            }
        }
    }

    Err(StatusCode::UNAUTHORIZED)
}

/// Middleware: check that the authenticated user has the required permission
pub fn require_permission(permission: Permission)
    -> impl Fn(Request<axum::body::Body>) -> Result<Request<axum::body::Body>, StatusCode>
{
    move |req| {
        let user = req.extensions().get::<AuthenticatedUser>()
            .ok_or(StatusCode::UNAUTHORIZED)?;

        if !user.role.has_permission(&permission) {
            return Err(StatusCode::FORBIDDEN);
        }

        Ok(req)
    }
}

#[derive(Debug, Clone)]
pub struct AuthenticatedUser {
    pub id: String,
    pub username: String,
    pub role: Role,
}
```

### 5.4 Tauri Command Permission Guard

```rust
// src-tauri/src/auth/tauri_guard.rs

/// Macro for Tauri commands that require a specific permission
macro_rules! require_permission {
    ($state:expr, $session_id:expr, $permission:expr) => {{
        let user = $state.db.validate_session(&$session_id).await
            .ok_or_else(|| "Unauthorized".to_string())?;
        if !user.role.has_permission(&$permission) {
            return Err("Forbidden: insufficient permissions".to_string());
        }
        user
    }};
}

#[tauri::command]
async fn start_build(
    state: tauri::State<'_, AppState>,
    session_id: String,
    plan_id: String,
) -> Result<BuildId, String> {
    let _user = require_permission!(state, session_id, Permission::StartBuild);
    state.orchestrator.start_build(&plan_id).await
        .map_err(|e| e.to_string())
}

#[tauri::command]
async fn manage_users(
    state: tauri::State<'_, AppState>,
    session_id: String,
    action: UserManagementAction,
) -> Result<(), String> {
    let _user = require_permission!(state, session_id, Permission::ManageUsers);
    state.user_manager.execute(action).await
        .map_err(|e| e.to_string())
}
```

### 5.5 Frontend Permission Checking

```typescript
// src/hooks/usePermission.ts

function usePermission(permission: Permission): boolean {
  const user = useOrchestratorStore((s) => s.currentUser);
  if (!user) return false;
  return roleHasPermission(user.role, permission);
}

function roleHasPermission(role: string, permission: Permission): boolean {
  const ROLE_PERMISSIONS: Record<string, Set<Permission>> = {
    viewer: new Set([
      'view-dashboard',
      'view-agent-output',
      'view-metrics',
    ]),
    operator: new Set([
      'view-dashboard',
      'view-agent-output',
      'view-metrics',
      'start-build',
      'pause-build',
      'approve-gate',
      'send-agent-command',
    ]),
    admin: new Set([
      'view-dashboard',
      'view-agent-output',
      'view-metrics',
      'start-build',
      'pause-build',
      'approve-gate',
      'send-agent-command',
      'manage-agent-config',
      'manage-plugins',
      'view-audit-trail',
      'manage-users',
    ]),
  };

  return ROLE_PERMISSIONS[role]?.has(permission) ?? false;
}

type Permission =
  | 'view-dashboard'
  | 'view-agent-output'
  | 'view-metrics'
  | 'start-build'
  | 'pause-build'
  | 'approve-gate'
  | 'send-agent-command'
  | 'manage-agent-config'
  | 'manage-plugins'
  | 'view-audit-trail'
  | 'manage-users';

// Usage in components:
function BuildControls() {
  const canStart = usePermission('start-build');
  const canPause = usePermission('pause-build');

  return (
    <div>
      <button disabled={!canStart} onClick={startBuild}>
        Start Build
      </button>
      <button disabled={!canPause} onClick={pauseBuild}>
        Pause Build
      </button>
    </div>
  );
}
```

### 5.6 User Management Panel

Admin-only panel for managing users:

- List all users with role, status, last login
- Add new user (username, display name, role, password)
- Edit user role (Viewer/Operator/Admin)
- Deactivate user (soft delete -- `is_active = false`)
- Generate API key for a user
- Revoke API keys

---

## 6. Audit Trail Panel

### 6.1 Design

The audit trail provides a read-only chronological view of all state changes in the system. It reads from the existing `audit_log` table (master spec section 12).

### 6.2 Implementation

```typescript
// src/blocks/audit-trail/AuditTrailBlock.tsx

interface AuditEntry {
  id: string;
  timestamp: Date;
  userId: string | null;
  agentId: string | null;
  action: string;
  resourceType: string;
  resourceId: string | null;
  oldValue: unknown;
  newValue: unknown;
  metadata: Record<string, unknown>;
}

const AuditTrailBlock = React.memo(function AuditTrailBlock({
  atoms,
}: BlockProps<AuditTrailAtoms>) {
  const entries = useAtomValue(atoms.entriesAtom);
  const filters = useAtomValue(atoms.filtersAtom);

  return (
    <div className="audit-trail-block">
      <AuditTrailToolbar
        filters={filters}
        onFiltersChange={(f) => store.set(atoms.filtersAtom, f)}
        onExport={handleExport}
      />

      <div className="audit-trail-table">
        <table>
          <thead>
            <tr>
              <th>Timestamp</th>
              <th>User</th>
              <th>Action</th>
              <th>Resource</th>
              <th>Old Value</th>
              <th>New Value</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((entry) => (
              <AuditRow key={entry.id} entry={entry} />
            ))}
          </tbody>
        </table>
      </div>

      <AuditTrailPagination
        total={entries.length}
        pageSize={50}
      />
    </div>
  );
});

const AuditRow = React.memo(function AuditRow({
  entry,
}: {
  entry: AuditEntry;
}) {
  return (
    <tr>
      <td>{formatTimestamp(entry.timestamp)}</td>
      <td>{entry.userId ?? entry.agentId ?? 'system'}</td>
      <td><ActionBadge action={entry.action} /></td>
      <td>{entry.resourceType}/{entry.resourceId}</td>
      <td><JsonPreview value={entry.oldValue} /></td>
      <td><JsonPreview value={entry.newValue} /></td>
    </tr>
  );
});
```

### 6.3 Filters

| Filter | Type | Options |
|--------|------|---------|
| User | Dropdown | All users + "system" + "agent" |
| Agent | Dropdown | All agents in current build |
| Action type | Multi-select | build_started, build_paused, gate_approved, gate_rejected, agent_spawned, agent_completed, plugin_swapped, user_created, config_changed |
| Date range | Date picker | Start date, end date |
| Search | Text | Free-text search across action + resource |

### 6.4 Export

- **CSV:** One row per entry, JSON values flattened to strings
- **JSON:** Array of AuditEntry objects, preserving nested structures
- Export respects current filters (only exports visible entries)

### 6.5 Retention Policy

Events older than 90 days are archived:

```sql
-- Run daily via Rust scheduled task
INSERT INTO audit_log_archive
  SELECT * FROM audit_log
  WHERE timestamp < datetime('now', '-90 days');

DELETE FROM audit_log
  WHERE timestamp < datetime('now', '-90 days');
```

The `audit_log_archive` table has the same schema as `audit_log`. Archived entries can be queried on demand but are not loaded by default.

---

## 7. Notification System

### 7.1 In-App Notifications (sonner)

```typescript
// src/notifications/toast-manager.ts

import { toast } from 'sonner';

type NotificationType =
  | 'agent-completed'
  | 'agent-failed'
  | 'approval-needed'
  | 'build-completed'
  | 'build-failed'
  | 'escalation';

interface NotificationPreferences {
  /** Per-type enable/disable */
  enabled: Record<NotificationType, boolean>;
  /** Sound on/off */
  soundEnabled: boolean;
  /** Desktop notifications on/off */
  desktopEnabled: boolean;
}

const DEFAULT_PREFERENCES: NotificationPreferences = {
  enabled: {
    'agent-completed': true,
    'agent-failed': true,
    'approval-needed': true,
    'build-completed': true,
    'build-failed': true,
    'escalation': true,
  },
  soundEnabled: true,
  desktopEnabled: true,
};

class NotificationManager {
  private preferences: NotificationPreferences;
  private history: NotificationHistoryEntry[] = [];

  constructor() {
    this.preferences = this.loadPreferences();
  }

  show(type: NotificationType, title: string, description?: string): void {
    // Check if this type is enabled
    if (!this.preferences.enabled[type]) return;

    // Record in history
    this.history.push({
      id: generateId(),
      type,
      title,
      description,
      timestamp: new Date(),
      read: false,
    });

    // In-app toast
    const severity = this.getSeverity(type);
    switch (severity) {
      case 'success':
        toast.success(title, { description });
        break;
      case 'error':
        toast.error(title, { description });
        break;
      case 'warning':
        toast.warning(title, { description });
        break;
      default:
        toast(title, { description });
    }

    // Desktop notification (via Tauri API)
    if (this.preferences.desktopEnabled) {
      this.showDesktopNotification(title, description);
    }

    // Sound
    if (this.preferences.soundEnabled) {
      this.playSound(severity);
    }
  }

  private async showDesktopNotification(
    title: string,
    body?: string
  ): Promise<void> {
    try {
      // Tauri v2 notification API
      const { sendNotification } = await import('@tauri-apps/plugin-notification');
      sendNotification({ title, body: body ?? '' });
    } catch {
      // Fallback to Web Notification API
      if ('Notification' in window && Notification.permission === 'granted') {
        new Notification(title, { body: body ?? '' });
      }
    }
  }

  private getSeverity(
    type: NotificationType
  ): 'success' | 'error' | 'warning' | 'info' {
    switch (type) {
      case 'agent-completed':
      case 'build-completed':
        return 'success';
      case 'agent-failed':
      case 'build-failed':
        return 'error';
      case 'approval-needed':
      case 'escalation':
        return 'warning';
      default:
        return 'info';
    }
  }

  private playSound(severity: string): void {
    // Use a short audio cue based on severity
    const sounds: Record<string, string> = {
      success: '/sounds/success.mp3',
      error: '/sounds/error.mp3',
      warning: '/sounds/warning.mp3',
      info: '/sounds/info.mp3',
    };
    const audio = new Audio(sounds[severity] ?? sounds.info);
    audio.volume = 0.3;
    audio.play().catch(() => { /* autoplay may be blocked */ });
  }

  getHistory(): NotificationHistoryEntry[] {
    return [...this.history];
  }

  markAsRead(id: string): void {
    const entry = this.history.find((h) => h.id === id);
    if (entry) entry.read = true;
  }

  getUnreadCount(): number {
    return this.history.filter((h) => !h.read).length;
  }

  updatePreferences(prefs: Partial<NotificationPreferences>): void {
    this.preferences = { ...this.preferences, ...prefs };
    this.savePreferences();
  }

  private loadPreferences(): NotificationPreferences {
    try {
      const stored = localStorage.getItem('notification-preferences');
      return stored ? JSON.parse(stored) : DEFAULT_PREFERENCES;
    } catch {
      return DEFAULT_PREFERENCES;
    }
  }

  private savePreferences(): void {
    localStorage.setItem(
      'notification-preferences',
      JSON.stringify(this.preferences)
    );
  }
}

interface NotificationHistoryEntry {
  id: string;
  type: NotificationType;
  title: string;
  description?: string;
  timestamp: Date;
  read: boolean;
}
```

### 7.2 Notification History Panel

A sidebar panel (accessible from the header bell icon) showing:
- Unread count badge on the bell icon
- List of notifications with type icon, title, description, timestamp
- "Mark all read" button
- Click notification to navigate to the relevant dashboard view
- Notifications preferences link

### 7.3 Wiring to SSE Events

```typescript
// In the SSE event router
function routeToNotifications(
  event: OrchestratorEvent,
  notificationManager: NotificationManager
): void {
  switch (event.type) {
    case 'RUN_FINISHED': {
      if (event.outcome === 'success') {
        notificationManager.show(
          'agent-completed',
          `Agent ${event.agentId} completed`,
          `Role: ${event.agentRole}`
        );
      } else if (event.outcome === 'error') {
        notificationManager.show(
          'agent-failed',
          `Agent ${event.agentId} failed`,
          event.error?.message
        );
      } else if (event.outcome === 'interrupt') {
        notificationManager.show(
          'approval-needed',
          `Approval needed for ${event.agentId}`,
          event.interrupt?.reason
        );
      }
      break;
    }

    case 'RAW': {
      if ((event.payload as any)?.type === 'build-completed') {
        notificationManager.show(
          'build-completed',
          'Build completed successfully'
        );
      }
      break;
    }
  }
}
```

---

## 8. Performance Optimization

### 8.1 React.memo Audit Checklist

Every custom component that receives props from state stores or appears in lists must be wrapped in `React.memo`. The following is the comprehensive audit:

| Component | File | Memoized? | Risk if Missing |
|-----------|------|-----------|----------------|
| `AgentTaskNode` | dag-visualization | Required | All DAG nodes re-render on any state change |
| `PhaseNode` | dag-visualization | Required | Same as above |
| `GateNode` | dag-visualization | Required | Same as above |
| `AgentCard` (kanban) | kanban | Required | All cards re-render during drag |
| `ColumnHeader` (kanban) | kanban | Required | Column headers re-render on drag |
| `AuditRow` | audit-trail | Required | All rows re-render on new entry |
| `ApprovalCard` | approval-queue | Required | Cards re-render on new approval |
| `LogLine` | log-viewer | Required | All lines re-render on new line |
| `FileTreeNode` | file-tree | Required | Tree re-renders on expand/collapse |
| `TokensPerSecondChart` | metrics | Required | Chart re-renders on window resize |
| `CostPerAgentChart` | metrics | Required | Same |
| `TimelineBlock` | timeline | Required | Full re-render on new item |
| `NotificationItem` | notification-history | Required | List re-renders on new notification |

### 8.2 Zustand Selector Audit

All Zustand selectors must use `useShallow` or explicit equality functions to prevent unnecessary re-renders:

```typescript
// BAD: This re-renders on ANY store change
const agents = useOrchestratorStore((s) => s.agents);

// GOOD: Only re-renders when agents array reference changes
const agents = useOrchestratorStore(
  (s) => s.agents,
  shallow
);

// BEST: Only re-renders when the specific agent's status changes
const status = useOrchestratorStore(
  (s) => s.agents.find((a) => a.id === agentId)?.status,
  (a, b) => a === b
);
```

### 8.3 SSE Batch Window Tuning

The batch window adapts to user activity level:

| User State | Batch Window | Trigger |
|-----------|-------------|---------|
| Active (mouse/keyboard within 5s) | 16ms | `requestAnimationFrame` |
| Background (tab visible, no input for 5s) | 50ms | `setTimeout` |
| Idle (tab hidden or no input for 30s) | 200ms | `setTimeout` |

```typescript
// src/streaming/batch-tuner.ts

class BatchWindowTuner {
  private lastActivity: number = Date.now();
  private isTabVisible: boolean = true;

  constructor() {
    document.addEventListener('mousemove', this.recordActivity);
    document.addEventListener('keydown', this.recordActivity);
    document.addEventListener('visibilitychange', () => {
      this.isTabVisible = document.visibilityState === 'visible';
    });
  }

  private recordActivity = (): void => {
    this.lastActivity = Date.now();
  };

  getCurrentWindow(): number {
    if (!this.isTabVisible) return 200;

    const idleMs = Date.now() - this.lastActivity;
    if (idleMs < 5000) return 16;   // Active
    if (idleMs < 30000) return 50;  // Background
    return 200;                      // Idle
  }
}
```

### 8.4 Terminal Cleanup

Hidden terminals consume memory but provide no visual value. Aggressive cleanup:

```typescript
// Terminal management rules:
// 1. Visible terminals: full xterm.js with WebGL renderer
// 2. Recently hidden (<5 min): headless xterm.js (buffer only)
// 3. Long hidden (>5 min): dispose instance, keep last 1000 lines in memory
// 4. Max scrollback: 5000 lines per terminal (configurable)

function cleanupHiddenTerminals(
  blocks: Map<string, BlockEntry>,
  visibleBlockIds: Set<string>
): void {
  for (const [id, block] of blocks) {
    if (block.type !== 'agent-output') continue;
    if (visibleBlockIds.has(id)) continue;

    const hiddenDuration = Date.now() - (block.hiddenAt ?? Date.now());

    if (hiddenDuration > 5 * 60 * 1000) {
      // Long hidden: dispose terminal, keep buffer
      const terminal = block.atoms.terminalRef;
      if (terminal) {
        const buffer = extractBufferLines(terminal, 1000);
        terminal.dispose();
        block.atoms.terminalRef = null;
        block.atoms.savedBuffer = buffer;
      }
    }
  }
}
```

### 8.5 Memory Profiling Target

Target: less than 200MB with 20 active agents.

| Component | Budget per Agent | 20 Agents | Optimization |
|-----------|-----------------|-----------|-------------|
| DAG node | 2KB | 40KB | React.memo |
| Terminal buffer | 5MB (5K lines) | 100MB | Dispose hidden, cap scrollback |
| Log viewer | 500KB | 10MB | Virtualized (only visible lines in DOM) |
| Kanban card | 1KB | 20KB | React.memo |
| Jotai atoms | 5KB | 100KB | Fine-grained atoms |
| Zustand store | -- | 200KB | Shared, not per-agent |
| Monaco (shared) | -- | 15MB | Single instance |
| SQLite WAL | -- | 30MB | Checkpoint periodically |
| **Total** | -- | **~155MB** | Under 200MB budget |

### 8.6 FPS Profiling Target

Target: 60 FPS with 20 active DAG nodes.

Testing methodology:
1. Create a mock build with 20 agents in various statuses
2. Open DAG visualization with all 20 nodes visible
3. Trigger status transitions every 500ms
4. Record FPS using `performance.now()` in `requestAnimationFrame`
5. Assert: 95th percentile frame time < 16.7ms (60 FPS)

```typescript
// src/testing/fps-profiler.ts

class FPSProfiler {
  private frameTimes: number[] = [];
  private lastFrameTime: number = 0;
  private running: boolean = false;

  start(): void {
    this.running = true;
    this.frameTimes = [];
    this.lastFrameTime = performance.now();
    this.tick();
  }

  stop(): FPSReport {
    this.running = false;
    const sorted = [...this.frameTimes].sort((a, b) => a - b);
    return {
      frameCount: sorted.length,
      avgFps: 1000 / (sorted.reduce((a, b) => a + b, 0) / sorted.length),
      p50FrameMs: sorted[Math.floor(sorted.length * 0.5)],
      p95FrameMs: sorted[Math.floor(sorted.length * 0.95)],
      p99FrameMs: sorted[Math.floor(sorted.length * 0.99)],
      maxFrameMs: sorted[sorted.length - 1],
      droppedFrames: sorted.filter((t) => t > 16.7).length,
    };
  }

  private tick = (): void => {
    if (!this.running) return;
    const now = performance.now();
    this.frameTimes.push(now - this.lastFrameTime);
    this.lastFrameTime = now;
    requestAnimationFrame(this.tick);
  };
}

interface FPSReport {
  frameCount: number;
  avgFps: number;
  p50FrameMs: number;
  p95FrameMs: number;
  p99FrameMs: number;
  maxFrameMs: number;
  droppedFrames: number;
}
```

### 8.7 Bundle Size Optimization

| Technique | Target | Implementation |
|-----------|--------|---------------|
| Code splitting | Each block type is a separate chunk | `React.lazy()` + `Suspense` for block components |
| Tree shaking | Remove unused recharts exports | Import specific chart types, not full library |
| Lazy imports | Monaco loaded on demand | Only import when diff-viewer block is opened |
| Asset compression | Brotli for production builds | Vite plugin `vite-plugin-compression` |
| Image optimization | SVG for icons, no raster images | lucide-react for icons |

```typescript
// Block registry uses lazy loading
const blockLoaders: Record<string, () => Promise<BlockDefinition>> = {
  'agent-output': () => import('./blocks/agent-output'),
  'dag-visualization': () => import('./blocks/dag-visualization'),
  'approval-queue': () => import('./blocks/approval-queue'),
  'log-viewer': () => import('./blocks/log-viewer'),
  'diff-viewer': () => import('./blocks/diff-viewer'),     // Heavy: Monaco
  'contract-compliance': () => import('./blocks/contract-compliance'),
  'file-tree': () => import('./blocks/file-tree'),
  'metrics': () => import('./blocks/metrics'),
  'kanban': () => import('./blocks/kanban'),
  'timeline': () => import('./blocks/timeline'),
  'audit-trail': () => import('./blocks/audit-trail'),
  'plugin-config': () => import('./blocks/plugin-config'),
};
```

### 8.8 Lighthouse Audit Target

| Metric | Target | Notes |
|--------|--------|-------|
| Performance | >90 | May be lower due to WebSocket/SSE connections |
| Accessibility | >90 | All interactive elements need ARIA labels |
| Best Practices | >90 | HTTPS required for desktop notification API |
| SEO | N/A | Desktop app, not indexed |

---

## 9. E2E Testing at Scale

### 9.1 Test Framework

- **Playwright** for web E2E tests (works with Tauri's WebView via `@playwright/test`)
- **Tauri driver** for native integration tests (window management, system tray)
- **Mock agent server** providing 20 simultaneous SSE streams with realistic event patterns

### 9.2 Mock Agent Server

```typescript
// tests/e2e/mock-agent-server.ts

/**
 * Creates a mock backend that simulates 20 agents
 * going through a build lifecycle.
 */
class MockAgentServer {
  private agents: MockAgent[] = [];
  private sseClients: Set<ServerResponse> = new Set();

  constructor(agentCount: number = 20) {
    for (let i = 0; i < agentCount; i++) {
      this.agents.push(new MockAgent({
        id: `agent-${String(i + 1).padStart(2, '0')}`,
        role: ROLES[i % ROLES.length],
        delayMs: 500 + Math.random() * 2000,
      }));
    }
  }

  start(port: number): void {
    const server = createServer((req, res) => {
      if (req.url === '/api/events') {
        this.handleSSE(res);
      } else if (req.url === '/api/state') {
        this.handleFullState(res);
      } else if (req.method === 'POST') {
        this.handleCommand(req, res);
      }
    });

    server.listen(port);
  }

  private handleSSE(res: ServerResponse): void {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    });

    this.sseClients.add(res);

    // Send initial state snapshot
    this.broadcastEvent({
      type: 'STATE_SNAPSHOT',
      state: this.getFullState(),
    });

    res.on('close', () => {
      this.sseClients.delete(res);
    });
  }

  /** Run a full build simulation */
  async simulateBuild(): Promise<void> {
    // Phase 1: Queue all agents
    for (const agent of this.agents) {
      agent.setStatus('queued');
      this.broadcastAgentDelta(agent);
      await delay(100);
    }

    // Phase 2: Spawn agents in waves
    for (const agent of this.agents) {
      agent.setStatus('spawning');
      this.broadcastAgentDelta(agent);
      await delay(200);

      agent.setStatus('running');
      this.broadcastAgentDelta(agent);
    }

    // Phase 3: Simulate work (output events, tool calls)
    const promises = this.agents.map(async (agent) => {
      for (let i = 0; i < 20; i++) {
        this.broadcastEvent({
          type: 'TEXT_MESSAGE_CONTENT',
          agentId: agent.id,
          agentRole: agent.role,
          content: `[${agent.id}] Step ${i + 1}/20: Processing...`,
        });
        agent.progress = (i / 20) * 100;
        agent.tokenUsage += Math.floor(Math.random() * 500);
        this.broadcastAgentDelta(agent);
        await delay(agent.delayMs);
      }

      // 80% success, 10% failed, 10% needs approval
      const outcome = Math.random();
      if (outcome < 0.8) {
        agent.setStatus('completed');
      } else if (outcome < 0.9) {
        agent.setStatus('failed');
        agent.error = 'Simulated failure for testing';
      } else {
        agent.setStatus('waiting');
      }
      this.broadcastAgentDelta(agent);
    });

    await Promise.all(promises);
  }

  private broadcastEvent(event: unknown): void {
    const data = `data: ${JSON.stringify(event)}\n\n`;
    for (const client of this.sseClients) {
      client.write(data);
    }
  }

  private broadcastAgentDelta(agent: MockAgent): void {
    this.broadcastEvent({
      type: 'STATE_DELTA',
      agentId: agent.id,
      delta: {
        agentId: agent.id,
        status: agent.status,
        progress: agent.progress,
        tokenUsage: agent.tokenUsage,
        currentStep: agent.currentStep,
      },
    });
  }
}

const ROLES = [
  'backend', 'frontend', 'infrastructure', 'qe', 'security',
  'docs', 'observability', 'db-migration', 'performance',
];
```

### 9.3 E2E Test Suite

```typescript
// tests/e2e/dashboard.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Dashboard at scale (20 agents)', () => {
  let mockServer: MockAgentServer;

  test.beforeAll(async () => {
    mockServer = new MockAgentServer(20);
    mockServer.start(3200);
  });

  test.afterAll(async () => {
    mockServer.stop();
  });

  test('all blocks render with 20 agents', async ({ page }) => {
    await page.goto('http://localhost:3100');

    // DAG visualization shows 20 nodes
    const dagNodes = page.locator('.react-flow__node');
    await expect(dagNodes).toHaveCount(20);

    // Kanban shows all agents distributed across columns
    const kanbanCards = page.locator('.kanban-card');
    await expect(kanbanCards).toHaveCount(20);

    // Metrics block renders without errors
    const metricsBlock = page.locator('.metrics-block');
    await expect(metricsBlock).toBeVisible();
  });

  test('kanban cards move between columns on status change', async ({ page }) => {
    await page.goto('http://localhost:3100');

    // Start the build simulation
    await mockServer.simulateBuild();

    // Wait for agents to reach running state
    await page.waitForTimeout(2000);

    // Running column should have agents
    const runningCards = page.locator('.kanban-column-running .kanban-card');
    expect(await runningCards.count()).toBeGreaterThan(0);

    // Wait for build to complete
    await page.waitForTimeout(30000);

    // Completed column should have agents
    const completedCards = page.locator('.kanban-column-completed .kanban-card');
    expect(await completedCards.count()).toBeGreaterThan(0);
  });

  test('drag agent card between columns updates status', async ({ page }) => {
    await page.goto('http://localhost:3100');

    // Find a card in "running" column
    const card = page.locator('.kanban-column-running .kanban-card').first();
    const target = page.locator('.kanban-column-waiting');

    // Drag card to "waiting" column
    await card.dragTo(target);

    // Verify the card moved
    await expect(
      page.locator('.kanban-column-waiting .kanban-card')
    ).toHaveCount(1);
  });

  test('metrics charts update in real-time', async ({ page }) => {
    await page.goto('http://localhost:3100');

    // Switch to metrics view
    await page.click('[data-block-type="metrics"]');

    // Start simulation
    mockServer.simulateBuild();

    // Wait for data points to arrive
    await page.waitForTimeout(3000);

    // Chart should have data (SVG paths for line chart)
    const chartPaths = page.locator('.recharts-line-curve');
    expect(await chartPaths.count()).toBeGreaterThan(0);
  });

  test('timeline shows accurate execution history', async ({ page }) => {
    await page.goto('http://localhost:3100');

    // Complete a build first
    await mockServer.simulateBuild();
    await page.waitForTimeout(30000);

    // Switch to timeline view
    await page.click('[data-block-type="timeline"]');

    // Should have 20 timeline groups (one per agent)
    const groups = page.locator('.rct-sidebar-row');
    await expect(groups).toHaveCount(20);

    // Click a timeline item
    const item = page.locator('.rct-item').first();
    await item.click();

    // Should navigate to agent output
    await expect(page.locator('.agent-output-block')).toBeVisible();
  });

  test('RBAC: viewer cannot start builds', async ({ page }) => {
    // Log in as viewer
    await loginAs(page, 'viewer-user', 'password');
    await page.goto('http://localhost:3100');

    // Start build button should be disabled
    const startButton = page.locator('button:has-text("Start Build")');
    await expect(startButton).toBeDisabled();
  });

  test('RBAC: operator can approve gates', async ({ page }) => {
    await loginAs(page, 'operator-user', 'password');
    await page.goto('http://localhost:3100');

    // Trigger an approval event
    mockServer.triggerApproval('agent-05');
    await page.waitForTimeout(1000);

    // Approval queue should show the pending approval
    const approvalCard = page.locator('.approval-card');
    await expect(approvalCard).toHaveCount(1);

    // Approve button should be enabled
    const approveButton = page.locator('button:has-text("Approve")');
    await expect(approveButton).toBeEnabled();
    await approveButton.click();

    // Approval should be processed
    await expect(approvalCard).toHaveCount(0);
  });

  test('RBAC: viewer cannot see audit trail', async ({ page }) => {
    await loginAs(page, 'viewer-user', 'password');
    await page.goto('http://localhost:3100');

    // Audit trail block should not be available
    const auditBlock = page.locator('[data-block-type="audit-trail"]');
    await expect(auditBlock).toHaveCount(0);
  });

  test('SSE reconnection recovery', async ({ page }) => {
    await page.goto('http://localhost:3100');

    // Verify connected
    await expect(
      page.locator('[data-connection-status="connected"]')
    ).toBeVisible();

    // Kill SSE connection by stopping mock server briefly
    mockServer.stop();
    await page.waitForTimeout(2000);

    // Should show reconnecting
    await expect(
      page.locator('[data-connection-status="reconnecting"]')
    ).toBeVisible();

    // Restart server
    mockServer.start(3200);
    await page.waitForTimeout(6000); // Wait for reconnect + state snapshot

    // Should recover
    await expect(
      page.locator('[data-connection-status="connected"]')
    ).toBeVisible();

    // All 20 agents should still be displayed
    const dagNodes = page.locator('.react-flow__node');
    await expect(dagNodes).toHaveCount(20);
  });

  test('block persistence across restart', async ({ page }) => {
    await page.goto('http://localhost:3100');

    // Rearrange layout (resize a panel)
    const handle = page.locator('.resize-handle').first();
    await handle.drag({ x: 100, y: 0 });

    // Get the current layout state
    const layoutBefore = await page.evaluate(() => {
      return localStorage.getItem('dashboard-layout');
    });

    // Reload the page (simulates restart)
    await page.reload();
    await page.waitForTimeout(2000);

    // Layout should be restored
    const layoutAfter = await page.evaluate(() => {
      return localStorage.getItem('dashboard-layout');
    });

    expect(layoutAfter).toEqual(layoutBefore);
  });

  test('desktop notifications fire for critical events', async ({ page }) => {
    await page.goto('http://localhost:3100');

    // Grant notification permission
    await page.evaluate(() => {
      // Mock the Notification API
      (window as any).__notificationHistory = [];
      (window as any).Notification = class {
        constructor(title: string, options: any) {
          (window as any).__notificationHistory.push({ title, ...options });
        }
        static permission = 'granted';
      };
    });

    // Trigger agent failure
    mockServer.triggerAgentFailure('agent-01');
    await page.waitForTimeout(1000);

    // Check that a desktop notification was fired
    const notifications = await page.evaluate(() => {
      return (window as any).__notificationHistory;
    });

    expect(notifications.length).toBeGreaterThan(0);
    expect(notifications[0].title).toContain('agent-01');
  });
});

// Performance benchmark tests
test.describe('Performance benchmarks', () => {
  test('60 FPS with 20 active DAG nodes', async ({ page }) => {
    await page.goto('http://localhost:3100');

    // Start profiler
    const report = await page.evaluate(async () => {
      const profiler = new (window as any).FPSProfiler();
      profiler.start();

      // Simulate 5 seconds of activity
      await new Promise((r) => setTimeout(r, 5000));

      return profiler.stop();
    });

    expect(report.avgFps).toBeGreaterThan(55);
    expect(report.p95FrameMs).toBeLessThan(20);
    expect(report.droppedFrames).toBeLessThan(report.frameCount * 0.05);
  });

  test('memory under 200MB with 20 agents', async ({ page }) => {
    await page.goto('http://localhost:3100');

    // Run build simulation
    const mockServer = new MockAgentServer(20);
    mockServer.start(3201);

    await page.waitForTimeout(5000);

    // Check memory usage
    const metrics = await page.evaluate(() => {
      if ('memory' in performance) {
        return {
          usedJSHeapSize: (performance as any).memory.usedJSHeapSize,
          totalJSHeapSize: (performance as any).memory.totalJSHeapSize,
        };
      }
      return null;
    });

    if (metrics) {
      const usedMB = metrics.usedJSHeapSize / (1024 * 1024);
      expect(usedMB).toBeLessThan(200);
    }

    mockServer.stop();
  });
});
```

---

## 10. Acceptance Criteria

| # | Criterion | Verification Method |
|---|-----------|-------------------|
| AC-1 | Kanban board shows all agents in correct columns | E2E test: 20 agents distributed across 6 columns |
| AC-2 | Dragging agents between columns updates their status | E2E test: drag card, verify REST call + column change |
| AC-3 | Metrics charts update in real-time during builds | E2E test: start build, verify chart has data points after 3s |
| AC-4 | Timeline shows accurate execution history with zoom | E2E test: complete build, verify 20 groups with time spans |
| AC-5 | RBAC: Viewer cannot start builds or approve gates | E2E test: login as viewer, verify buttons disabled |
| AC-6 | RBAC: Operator can start builds and approve gates | E2E test: login as operator, start build, approve gate |
| AC-7 | RBAC: Admin can manage users and plugins | E2E test: login as admin, create user, change plugin |
| AC-8 | Audit trail captures all state changes | E2E test: perform actions, verify entries in audit panel |
| AC-9 | Audit trail filters work (by user, agent, action, date) | E2E test: apply filters, verify filtered results |
| AC-10 | Audit trail exports to CSV and JSON | E2E test: click export, verify downloaded file |
| AC-11 | Desktop notifications fire for agent failures | E2E test: trigger failure, verify Notification API called |
| AC-12 | Notification preferences are persisted | E2E test: toggle preference, reload, verify persisted |
| AC-13 | 60 FPS with 20 active agents | Performance benchmark: p95 frame time < 20ms |
| AC-14 | <200MB memory with 20 agents | Performance benchmark: JS heap < 200MB |
| AC-15 | SSE reconnection recovers within 6 seconds | E2E test: disconnect, reconnect, verify state restored |
| AC-16 | Block layout persists across restart | E2E test: rearrange, reload, verify layout restored |
| AC-17 | E2E test suite passes with 20 mock agents | CI pipeline: all tests green |

---

## 11. Risk Register

| Risk | Severity | Probability | Mitigation |
|------|----------|------------|------------|
| @dnd-kit cascading re-renders with 20 cards | High | Medium | React.memo on ALL card and column components. Profile with React DevTools Profiler before and after. |
| recharts performance with frequent updates | Medium | Medium | Disable animations (`isAnimationActive={false}`). Cap data points at 10K. Throttle updates to 1/second. |
| react-calendar-timeline rendering with 20 groups | Medium | Low | Virtualization is built-in. Test with 50 groups to confirm. |
| RBAC bypass via Tauri IPC | High | Low | Permission check on EVERY Tauri command. Automated test for each permission/role combination. |
| Session fixation attacks | Medium | Low | Regenerate session ID on login. HttpOnly + Secure + SameSite cookie flags. |
| Audit log grows unbounded | Medium | Medium | 90-day retention policy with automated archival. Monitor SQLite file size. |
| Notification spam during large builds | Medium | High | Cooldown per notification type (no more than 1 per agent per 30s). Batch notifications: "5 agents completed". |
| Memory leak in long-running builds | High | Medium | Dispose hidden terminals after 5 min. Cap scrollback at 5K lines. Monitor with `performance.memory` in dev. |
| Playwright tests flaky due to timing | Medium | High | Use `waitForSelector` and `expect.poll` instead of fixed timeouts. Retry flaky tests 2x in CI. |

---

## 12. Open Questions (Phase 8)

| # | Question | Impact | Decision Owner |
|---|----------|--------|---------------|
| Q8.1 | Should the first admin user be created via CLI command or a setup wizard on first launch? | UX, security | Product |
| Q8.2 | Should audit trail support full-text search or is column filtering sufficient? | Complexity, storage | Product |
| Q8.3 | Should notification batching ("5 agents completed") be automatic or configurable? | UX | Product |
| Q8.4 | Should we add a "dark mode" toggle in Phase 8 or defer to a later release? | UI polish | Product |
| Q8.5 | Should performance benchmarks run in CI on every PR or only on release branches? | CI cost | Engineering |

---

## 13. File Manifest

Files created or modified in Phase 8:

```
src/
  blocks/
    kanban/
      KanbanBlock.tsx               # DndContext + columns + drag overlay
      KanbanColumn.tsx              # Sortable column wrapper
      AgentCard.tsx                 # React.memo card component
      atoms.ts                     # Jotai atoms: columns, dragState, sortOrder
    metrics/
      MetricsBlock.tsx              # Chart container with toolbar
      TokensPerSecondChart.tsx      # Line chart (recharts)
      CostPerAgentChart.tsx         # Bar chart
      PhaseDurationChart.tsx        # Bar chart
      TotalCostChart.tsx            # Area chart
      atoms.ts                     # Jotai atoms: dataPoints, timeWindow
    timeline/
      TimelineBlock.tsx             # react-calendar-timeline wrapper
      atoms.ts                     # Jotai atoms: groups, items, timeRange
    audit-trail/
      AuditTrailBlock.tsx           # Table + filters + pagination
      AuditTrailToolbar.tsx         # Filter controls
      AuditRow.tsx                  # React.memo row component
      atoms.ts                     # Jotai atoms: entries, filters
  hooks/
    usePermission.ts                # RBAC permission hook
  notifications/
    toast-manager.ts                # sonner + desktop notification manager
    NotificationHistoryPanel.tsx    # Sidebar notification list
    NotificationPreferences.tsx     # Settings panel
  streaming/
    batch-tuner.ts                  # Adaptive SSE batch window
  auth/
    login-page.tsx                  # Login form
    session-manager.ts              # Cookie/session management
  testing/
    fps-profiler.ts                 # FPS measurement utility

src-tauri/
  src/
    auth/
      middleware.rs                 # Auth + RBAC middleware
      tauri_guard.rs                # Tauri command permission guard
      session.rs                    # Session validation + creation
      api_key.rs                    # API key validation

migrations/
  008_rbac.sql                      # users, sessions, api_keys tables

tests/
  e2e/
    mock-agent-server.ts            # 20-agent SSE mock server
    dashboard.spec.ts               # Full E2E test suite
    rbac.spec.ts                    # RBAC permission tests
    performance.spec.ts             # FPS + memory benchmarks
    reconnection.spec.ts            # SSE disconnect/reconnect tests
  unit/
    kanban/
      kanban-block.test.tsx         # Kanban rendering tests
      drag-drop.test.tsx            # DnD interaction tests
    metrics/
      metrics-block.test.tsx        # Chart rendering tests
      data-management.test.ts       # Rolling window, eviction tests
    auth/
      permission.test.ts            # Role permission matrix tests
      session.test.ts               # Session lifecycle tests
    notifications/
      toast-manager.test.ts         # Notification routing tests
```
