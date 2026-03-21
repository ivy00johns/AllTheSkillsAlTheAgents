# 17 — Repo Bootstrap Specification

**Document type:** Implementation blueprint
**Status:** DRAFT (revised for service-hosted architecture)
**Date:** 2026-03-20
**Scope:** First commit scaffold, tooling, and dev workflow for The Hive — a service-hosted AI agent orchestration platform
**Depends on:** `03-system-architecture.md` (5-layer model, tech stack), `05-data-model.md` (entities), `08-skill-system.md` (skill anatomy), `18-api-layer.md` (API surface)

---

## 1. Repository Structure

This is the complete file tree for the first commit. The Hive is a Turborepo/pnpm
workspace monorepo. Apps are deployable processes, services are domain microservices,
and packages are shared libraries consumed by both.

Files marked with `(stub)` contain only the module signature and a TODO comment;
they are implemented in later phases. Files with full contents are specified in
subsequent sections of this document.

```
the-hive/
├── README.md
├── package.json                    # Workspace root (pnpm + Turborepo)
├── pnpm-workspace.yaml
├── turbo.json
├── tsconfig.base.json              # Shared compiler options
├── biome.json
├── .gitignore
├── .gitattributes
├── .env.example
│
├── CLAUDE.md
├── AGENTS.md
├── GEMINI.md
│
├── apps/
│   ├── control-plane/              # The Queen — orchestration API
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── src/
│   │       ├── index.ts            # Fastify server entry point
│   │       ├── server.ts           # Server factory (createApp)
│   │       ├── routes/
│   │       │   ├── auth.ts         # Authentication routes
│   │       │   ├── builds.ts       # Build lifecycle routes
│   │       │   ├── agents.ts       # Worker fleet routes
│   │       │   ├── work-items.ts   # Work tracker routes
│   │       │   ├── mail.ts         # Communication routes
│   │       │   ├── merge.ts        # Merge queue routes
│   │       │   ├── approvals.ts    # Keeper approval routes
│   │       │   ├── events.ts       # SSE event streaming
│   │       │   ├── terminal.ts     # WebSocket terminal I/O
│   │       │   └── health.ts       # Health check routes
│   │       ├── plugins/
│   │       │   ├── auth.ts         # @fastify/jwt + session plugin
│   │       │   ├── rate-limit.ts   # @fastify/rate-limit (Valkey-backed)
│   │       │   └── cors.ts         # @fastify/cors configuration
│   │       └── cli/
│   │           ├── index.ts        # Commander.js setup (The Smoker)
│   │           ├── commands/
│   │           │   ├── serve.ts    # platform serve (start Fastify)
│   │           │   ├── tracker.ts  # Work tracker commands
│   │           │   ├── fleet.ts    # Agent fleet commands
│   │           │   ├── mail.ts     # Communication commands
│   │           │   ├── merge.ts    # Merge queue commands
│   │           │   ├── sling.ts    # Work dispatch commands
│   │           │   ├── skill.ts    # Skill management commands
│   │           │   ├── contract.ts # Contract commands
│   │           │   ├── quality.ts  # Quality/eval commands
│   │           │   ├── config.ts   # Configuration commands
│   │           │   └── doctor.ts   # Health check commands
│   │           └── output.ts       # Shared output formatting
│   │
│   └── operator-console/           # The Glass — React SPA (stub)
│       ├── package.json
│       ├── tsconfig.json
│       ├── vite.config.ts
│       └── src/
│           ├── main.tsx
│           └── App.tsx
│
├── services/
│   ├── runtime-orchestrator/       # Agent spawning, lifecycle, worktrees
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── src/
│   │       ├── index.ts            # Service entry point
│   │       ├── coordinator.ts      # Coordinator loop (stub)
│   │       ├── sling.ts            # Work dispatch (stub)
│   │       ├── lifecycle.ts        # Agent lifecycle (stub)
│   │       ├── worktree.ts         # Git worktree management (stub)
│   │       ├── context.ts          # Context tracking (stub)
│   │       ├── circuit-breaker.ts  # Circuit breaker (stub)
│   │       ├── convoy.ts           # Convoy coordination (stub)
│   │       └── adapters/
│   │           ├── adapter.ts      # RuntimeAdapter interface
│   │           ├── detect.ts       # Auto-detection
│   │           ├── claude-code.ts  # Claude Code adapter (stub)
│   │           ├── pi-cli.ts       # Pi CLI adapter (stub)
│   │           ├── codex-cli.ts    # Codex CLI adapter (stub)
│   │           ├── gemini-cli.ts   # Gemini CLI adapter (stub)
│   │           └── aider.ts        # Aider adapter (stub)
│   │
│   ├── browser-automation/         # Browse CLI (Playwright)
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── src/
│   │       ├── index.ts            # Service entry point
│   │       ├── browse.ts           # Browser session management (stub)
│   │       └── design-audit.ts     # Design audit automation (stub)
│   │
│   ├── review-engine/              # Quality intelligence
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── src/
│   │       ├── index.ts            # Service entry point
│   │       ├── cognitive.ts        # Cognitive pattern review (stub)
│   │       ├── qa-gate.ts          # QA gate evaluation (stub)
│   │       ├── slop-detection.ts   # AI slop detection (stub)
│   │       ├── evals.ts            # Eval system (stub)
│   │       ├── contracts/
│   │       │   ├── author.ts       # Contract generation (stub)
│   │       │   ├── auditor.ts      # Contract auditing (stub)
│   │       │   └── ownership.ts    # File ownership enforcement (stub)
│   │       └── templates/
│   │           └── .gitkeep
│   │
│   └── router/                     # Capability-based agent routing
│       ├── package.json
│       ├── tsconfig.json
│       └── src/
│           ├── index.ts            # Service entry point
│           ├── routing.ts          # Quality-aware routing (stub)
│           └── scoring.ts          # Worker scorecard aggregation (stub)
│
├── packages/
│   ├── contracts/                  # Shared JSON schemas + TypeScript types
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   ├── src/
│   │   │   ├── index.ts            # Barrel export
│   │   │   └── types.ts            # ALL shared type definitions
│   │   └── schemas/
│   │       ├── work-item.json      # JSON Schema for work items
│   │       ├── agent.json          # JSON Schema for agents
│   │       ├── run-ledger.json     # JSON Schema for run ledger entries
│   │       ├── scorecard.json      # JSON Schema for worker scorecards
│   │       └── evidence.json       # JSON Schema for evidence records
│   │
│   ├── sdk/                        # Client SDK for inter-service calls
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── src/
│   │       ├── index.ts
│   │       ├── client.ts           # HTTP client factory
│   │       └── airway.ts           # Valkey Streams client (The Airway)
│   │
│   └── shared/                     # Common utilities
│       ├── package.json
│       ├── tsconfig.json
│       └── src/
│           ├── index.ts
│           ├── id.ts               # Hash-based ID generation
│           ├── errors.ts           # Error types and handling
│           ├── logger.ts           # Structured logging (pino)
│           ├── config.ts           # Environment-based config loader
│           └── db/
│               ├── postgres.ts     # PostgreSQL connection (pg + Drizzle)
│               ├── dolt.ts         # Dolt connection (mysql2 — The Frame)
│               ├── valkey.ts       # Valkey connection (ioredis — The Airway)
│               └── clickhouse.ts   # ClickHouse connection (@clickhouse/client)
│
├── infra/
│   ├── compose.local.yml           # Docker Compose for local dev
│   ├── k8s/                        # Kubernetes manifests (Phase 5+)
│   │   └── .gitkeep
│   └── scripts/
│       ├── check-prereqs.sh        # Verify node, docker, pnpm
│       ├── dev-up.sh               # Start local infrastructure
│       └── dev-down.sh             # Stop local infrastructure
│
├── docs/
│   └── adr/
│       └── 0001-core-principles.md # Architecture Decision Record
│
├── skills/
│   ├── coordinator/
│   │   └── SKILL.md
│   ├── lead/
│   │   └── SKILL.md
│   ├── builder/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── .gitkeep
│   ├── reviewer/
│   │   └── SKILL.md
│   ├── scout/
│   │   └── SKILL.md
│   └── merger/
│       └── SKILL.md
│
├── formulas/
│   ├── standard-build.toml
│   ├── review-cycle.toml
│   └── patrol.toml
│
├── templates/
│   ├── claude.md.hbs
│   ├── gemini.md.hbs
│   └── agents.md.hbs
│
├── tests/
│   ├── setup.ts
│   ├── unit/
│   │   ├── shared/
│   │   │   ├── id.test.ts
│   │   │   ├── config.test.ts
│   │   │   └── errors.test.ts
│   │   ├── control-plane/
│   │   │   └── .gitkeep
│   │   ├── runtime-orchestrator/
│   │   │   └── .gitkeep
│   │   ├── review-engine/
│   │   │   └── .gitkeep
│   │   └── router/
│   │       └── .gitkeep
│   ├── integration/
│   │   ├── postgres.test.ts
│   │   ├── dolt.test.ts
│   │   ├── valkey.test.ts
│   │   └── .gitkeep
│   └── e2e/
│       └── .gitkeep
│
├── .github/
│   └── workflows/
│       └── ci.yml
│
└── contracts/
    └── .gitkeep
```

---

## 2. Package Configuration

### Root package.json

```json
{
  "name": "the-hive",
  "version": "0.1.0",
  "private": true,
  "description": "The Hive — AI agent orchestration platform. Work tracking, fleet management, merge queue, quality gates.",
  "packageManager": "pnpm@9.15.0",
  "scripts": {
    "build": "turbo build",
    "dev": "turbo dev",
    "test": "turbo test",
    "test:unit": "turbo test:unit",
    "test:integration": "turbo test:integration",
    "test:e2e": "turbo test:e2e",
    "lint": "biome check .",
    "lint:fix": "biome check --write .",
    "format": "biome format --write .",
    "typecheck": "turbo typecheck",
    "clean": "turbo clean",
    "doctor": "pnpm --filter @the-hive/control-plane exec -- node dist/index.js doctor",
    "serve": "pnpm --filter @the-hive/control-plane exec -- node dist/index.js serve",
    "infra:up": "docker compose -f infra/compose.local.yml up -d",
    "infra:down": "docker compose -f infra/compose.local.yml down",
    "infra:check": "bash infra/scripts/check-prereqs.sh",
    "precommit": "pnpm typecheck && pnpm lint && pnpm test:unit"
  },
  "devDependencies": {
    "@biomejs/biome": "^1.9.0",
    "turbo": "^2.4.0",
    "typescript": "^5.7.0"
  },
  "engines": {
    "node": ">=22.0.0",
    "pnpm": ">=9.0.0"
  }
}
```

### pnpm-workspace.yaml

```yaml
packages:
  - "apps/*"
  - "services/*"
  - "packages/*"
```

### turbo.json

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "test": {
      "dependsOn": ["build"]
    },
    "test:unit": {
      "dependsOn": ["build"]
    },
    "test:integration": {
      "dependsOn": ["build"]
    },
    "test:e2e": {
      "dependsOn": ["build"]
    },
    "typecheck": {
      "dependsOn": ["^build"]
    },
    "clean": {
      "cache": false
    }
  }
}
```

### tsconfig.base.json

Shared compiler options inherited by all workspace packages.

```json
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "NodeNext",
    "moduleResolution": "nodenext",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "composite": true,
    "incremental": true
  },
  "exclude": ["node_modules", "dist"]
}
```

### Example workspace tsconfig.json (apps/control-plane)

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src/**/*.ts"],
  "references": [
    { "path": "../../packages/contracts" },
    { "path": "../../packages/shared" },
    { "path": "../../packages/sdk" }
  ]
}
```

### biome.json

```json
{
  "$schema": "https://biomejs.dev/schemas/1.9.0/schema.json",
  "organizeImports": {
    "enabled": true
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "complexity": {
        "noExcessiveCognitiveComplexity": {
          "level": "warn",
          "options": { "maxAllowedComplexity": 25 }
        }
      },
      "suspicious": {
        "noExplicitAny": "warn"
      },
      "style": {
        "useConst": "error",
        "noNonNullAssertion": "warn"
      }
    }
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100
  },
  "javascript": {
    "formatter": {
      "quoteStyle": "double",
      "semicolons": "always",
      "trailingCommas": "all"
    }
  },
  "files": {
    "ignore": ["dist/", "node_modules/", ".platform/", "*.sql"]
  }
}
```

---

## 3. Core Type Definitions

Complete contents of `packages/contracts/src/types.ts`. Every shared interface
referenced across The Hive's five layers is defined here. This is the single source
of truth; all apps, services, and packages import from `@the-hive/contracts`.

```typescript
// packages/contracts/src/types.ts
// ─────────────────────────────────────────────────────────
// Shared type definitions for The Hive.
// Single source of truth. All modules import from here.
// ─────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════
// WORK ITEMS — Cells in The Comb (Layer 4: Work)
// ═══════════════════════════════════════════════════════════

export type WorkItemStatus =
  | "open"
  | "active"
  | "blocked"
  | "deferred"
  | "resolved"
  | "closed"
  | "pinned"
  | "hooked";

export type WorkItemType =
  | "task"
  | "bug"
  | "feature"
  | "chore"
  | "epic"
  | "decision"
  | "message"
  | "molecule"
  | "event"
  | "gate"
  | "convoy"
  | "agent"
  | "role"
  | "rig"
  | "slot";

export type Priority = 0 | 1 | 2 | 3 | 4;
// 0 = P0/critical, 1 = urgent, 2 = normal, 3 = low, 4 = backlog

export interface WorkItem {
  // Identity
  id: string;
  contentHash: string | null;
  title: string;
  description: string; // renamed from body — matches Drizzle schema
  type: WorkItemType;
  specId: string | null;

  // Status & Priority
  status: WorkItemStatus;
  priority: Priority;
  assignee: string | null;
  owner: string;

  // Hierarchy
  parentId: string | null;
  epicId: string | null;
  moleculeId: string | null;

  // Workflow / Formula
  formulaId: string | null;
  sourceFormula: string | null;
  sourceLocation: string | null;
  stepIndex: number | null;
  acceptanceCriteria: string;
  isTemplate: boolean;

  // Design
  designNotes: string;
  designStatus: "draft" | "reviewed" | "approved" | "rejected" | "";
  designReviewer: string | null;

  // Evidence
  evidenceIds: string[];
  contractId: string | null;

  // Timestamps
  createdAt: string;
  createdBy: string;
  updatedAt: string;
  startedAt: string | null;
  resolvedAt: string | null;
  closedAt: string | null;
  closedBy: string;
  closeReason: string;
  dueAt: string | null;
  deferUntil: string | null;

  // Metrics / Effort
  estimatedEffort: number | null;
  actualEffort: number | null;
  retryCount: number;
  qualityScore: number | null;
  crystallizes: boolean;

  // Agent
  assignedAgent: string | null;
  assignedRuntime: string | null;
  agentScorecardId: string | null;
  hookBead: string;
  roleBead: string;
  agentState: AgentStatus | "";
  roleType: string;
  rig: string;
  lastActivity: string | null;

  // Gate
  awaitType: "gh:run" | "gh:pr" | "timer" | "human" | "mail" | "contract" | "";
  awaitId: string;
  awaitTimeout: number;
  waiters: string;

  // Wisp
  isEphemeral: boolean;
  noHistory: boolean;
  wispType: string;
  wispParent: string | null;

  // Molecule
  molType: "swarm" | "patrol" | "work" | "";
  workType: "mutex" | "open_competition";

  // Event
  eventKind: string;
  actor: string;
  target: string;
  payload: string;

  // Messaging
  sender: string;

  // External
  externalRef: string | null;
  sourceSystem: string;
  sourceRepo: string;
  metadata: Record<string, unknown>;
}

// ═══════════════════════════════════════════════════════════
// DEPENDENCIES (Layer 4: Work)
// ═══════════════════════════════════════════════════════════

export type DependencyType =
  // Workflow (affect scheduling)
  | "blocks"
  | "parent-child"
  | "conditional-blocks"
  | "waits-for"
  // Association
  | "related"
  | "discovered-from"
  // Graph links
  | "replies-to"
  | "relates-to"
  | "duplicates"
  | "supersedes"
  // Entity
  | "authored-by"
  | "assigned-to"
  | "approved-by"
  | "attests"
  // Convoy
  | "tracks"
  // Reference
  | "until"
  | "caused-by"
  | "validates"
  // Delegation
  | "delegated-from"
  // Custom (string fallback)
  | (string & {});

export interface Dependency {
  sourceId: string;
  targetId: string;
  type: DependencyType;
  createdAt: string;
  createdBy: string;
  metadata: Record<string, unknown>;
  threadId: string;
}

// ═══════════════════════════════════════════════════════════
// WORKERS — Agents in The Hive (Layer 2: Orchestration + Layer 5: Runtime)
// ═══════════════════════════════════════════════════════════

export type AgentRole =
  | "coordinator"
  | "lead"
  | "builder"
  | "reviewer"
  | "scout"
  | "merger"
  | "watchdog"
  | "fleet-coordinator"
  | "infrastructure-helper"
  | "queue-processor"
  | "browse-agent"
  | "quality-auditor"
  | "crew";

export type AgentStatus =
  | "idle"
  | "spawning"
  | "running"
  | "working"
  | "stuck"
  | "done"
  | "stopped"
  | "dead";

export interface Agent {
  id: string;
  name: string;
  role: AgentRole;
  status: AgentStatus;
  depth: number; // 0 = coordinator, 1 = lead, 2 = leaf
  parentId: string | null;
  skillName: string;
  runtimeId: string;
  worktreePath: string | null;
  tmuxSession: string | null;
  hookBead: string | null;
  currentWorkItemId: string | null;
  spawnedAt: string;
  lastHeartbeat: string | null;
  contextUsage: number; // 0.0 - 1.0
  scorecard: AgentScorecard;
}

export interface AgentScorecard {
  tasksCompleted: number;
  tasksFailed: number;
  mergeSuccessRate: number;
  averageQualityScore: number;
  totalTokensUsed: number;
  totalCost: number;
}

// ═══════════════════════════════════════════════════════════
// COMMUNICATION — The Airway (Layer 2: Orchestration)
// ═══════════════════════════════════════════════════════════

export type MessagePriority = "critical" | "high" | "normal" | "low";

export type ProtocolType =
  | "task:assigned"
  | "task:completed"
  | "task:failed"
  | "task:blocked"
  | "review:requested"
  | "review:completed"
  | "merge:requested"
  | "merge:completed"
  | "merge:conflict"
  | "contract:updated"
  | "contract:violation"
  | "gate:passed"
  | "gate:failed"
  | "heartbeat"
  | "nudge"
  | "handoff:checkpoint"
  | "escalation"
  | "broadcast";

export interface Message {
  id: string;
  from: string;
  to: string; // agent name or broadcast group (@all, @builders, @leads)
  subject: string;
  body: string;
  priority: MessagePriority;
  protocol: ProtocolType | null;
  threadId: string | null;
  replyTo: string | null;
  sentAt: string;
  readAt: string | null;
  expiresAt: string | null;
  metadata: Record<string, unknown>;
}

// ═══════════════════════════════════════════════════════════
// MERGE SYSTEM (Layer 4: Work)
// ═══════════════════════════════════════════════════════════

export type MergeRequestStatus =
  | "pending"
  | "validating"
  | "merging"
  | "merged"
  | "conflict"
  | "failed"
  | "rejected";

export type ConflictTier = 1 | 2 | 3 | 4;
// 1 = clean merge, 2 = auto-resolve, 3 = AI-assisted, 4 = reimagine

export interface MergeRequest {
  id: string;
  branch: string;
  agentId: string;
  workItemId: string | null;
  status: MergeRequestStatus;
  submittedAt: string;
  validatedAt: string | null;
  processedAt: string | null;
  completedAt: string | null;
  tierUsed: ConflictTier | null;
  conflictFiles: string[];
  resolutionLog: ResolutionEntry[];
  errorMessage: string | null;
  warnings: string[];
  retryCount: number;
  maxRetries: number;
  preVerified: boolean;
  batchId: string | null;
}

export interface ResolutionEntry {
  file: string;
  tierAttempted: ConflictTier;
  tierResolved: ConflictTier | null;
  strategy: string;
}

export interface MergeResult {
  requestId: string;
  status: "merged" | "conflict" | "failed";
  mergeCommit: string | null;
  conflictFiles: string[];
  resolutionLog: ResolutionEntry[];
}

// ═══════════════════════════════════════════════════════════
// FORMULAS (Layer 4: Work)
// ═══════════════════════════════════════════════════════════

export interface Formula {
  id: string;
  name: string;
  description: string;
  steps: FormulaStep[];
  variables: Record<string, string>;
  advice: FormulaAdvice[];
}

export interface FormulaStep {
  id: string;
  title: string;
  type: WorkItemType;
  assignRole: AgentRole | null;
  acceptanceCriteria: string;
  dependsOn: string[]; // step IDs
  parallel: boolean;
}

export interface FormulaAdvice {
  after: string; // step ID
  condition: "success" | "failure" | "always";
  action: string;
}

export interface Protomolecule {
  id: string;
  formulaId: string;
  frozenAt: string;
  variables: Record<string, string>;
}

export interface Molecule {
  id: string;
  protoId: string;
  status: "active" | "completed" | "failed" | "cancelled";
  createdAt: string;
  completedAt: string | null;
  workItemIds: string[];
}

export interface Wisp {
  id: string;
  parentId: string | null;
  type: string;
  payload: Record<string, unknown>;
  createdAt: string;
  expiresAt: string | null;
}

// ═══════════════════════════════════════════════════════════
// CONVOYS — Flights (Layer 2: Orchestration)
// ═══════════════════════════════════════════════════════════

export type ConvoyStatus = "forming" | "active" | "completing" | "completed" | "failed";

export interface Convoy {
  id: string;
  name: string;
  description: string;
  status: ConvoyStatus;
  agentIds: string[];
  workItemIds: string[];
  createdAt: string;
  completedAt: string | null;
  progress: number; // 0.0 - 1.0
}

// ═══════════════════════════════════════════════════════════
// QUALITY — Inspection (Layer 3: Quality)
// ═══════════════════════════════════════════════════════════

export interface QAReport {
  id: string;
  workItemId: string;
  agentId: string;
  gateDecision: GateDecision;
  contractConformance: QAScore;
  security: QAScore;
  testResults: TestResult[];
  findings: QAFinding[];
  evidence: string[]; // evidence IDs
  createdAt: string;
}

export interface GateDecision {
  proceed: boolean;
  blockers: string[];
  warnings: string[];
}

export interface QAScore {
  score: number; // 1-5
  rationale: string;
  details: string[];
}

export interface TestResult {
  name: string;
  status: "passed" | "failed" | "skipped";
  duration: number;
  error: string | null;
}

export interface QAFinding {
  severity: "critical" | "high" | "medium" | "low" | "informational";
  category: string;
  message: string;
  file: string | null;
  line: number | null;
  suggestion: string | null;
}

// ═══════════════════════════════════════════════════════════
// RUN LEDGER — The Trail (Act → Remember)
// ═══════════════════════════════════════════════════════════

export interface RunLedgerEntry {
  id: string;
  agentId: string;
  sessionId: string;
  workItemId: string;
  runtimeId: string;
  model: string;
  startedAt: string;
  endedAt: string | null;
  status: "running" | "completed" | "failed" | "aborted";
  inputTokens: number;
  outputTokens: number;
  cost: number;
  toolCalls: number;
  filesModified: string[];
  testsRun: number;
  testsPassed: number;
  qualityScore: number | null;
  errorCategory: string | null;
  metadata: Record<string, unknown>;
}

// ═══════════════════════════════════════════════════════════
// WORKER SCORECARDS (Remember → better Decide)
// ═══════════════════════════════════════════════════════════

export interface WorkerScorecard {
  agentId: string;
  runtimeId: string;
  model: string;
  period: string; // ISO date range
  runsCompleted: number;
  runsFailed: number;
  totalTokens: number;
  totalCost: number;
  averageQualityScore: number;
  mergeSuccessRate: number;
  averageRunDurationMs: number;
  domainScores: Record<string, number>; // domain -> quality score
  lastUpdated: string;
}

// ═══════════════════════════════════════════════════════════
// EVIDENCE RECORDS (Layer 3: Quality)
// ═══════════════════════════════════════════════════════════

export type EvidenceType =
  | "screenshot"
  | "log_capture"
  | "test_result"
  | "diff"
  | "qa_report"
  | "design_audit"
  | "contract_audit"
  | "css_computed"
  | "performance_trace";

export interface EvidenceRecord {
  id: string;
  type: EvidenceType;
  workItemId: string;
  agentId: string;
  runId: string; // links to RunLedgerEntry
  storagePath: string; // filesystem or object store path
  contentHash: string;
  mimeType: string;
  sizeBytes: number;
  description: string;
  createdAt: string;
  metadata: Record<string, unknown>;
}

// ═══════════════════════════════════════════════════════════
// PENDING APPROVALS — The Keeper (from API layer)
// ═══════════════════════════════════════════════════════════

export type ApprovalKind =
  | "gate"         // QA gate hold
  | "merge"        // Merge approval
  | "deploy"       // Deployment approval
  | "cost_ceiling" // Budget exceeded
  | "escalation";  // Agent escalation

export type ApprovalStatus = "pending" | "approved" | "rejected" | "expired";

export interface PendingApproval {
  id: string;
  kind: ApprovalKind;
  status: ApprovalStatus;
  title: string;
  description: string;
  requestedBy: string; // agent ID or system
  requestedAt: string;
  decidedBy: string | null; // keeper ID
  decidedAt: string | null;
  expiresAt: string | null;
  context: Record<string, unknown>; // approval-specific payload
  workItemId: string | null;
  buildId: string | null;
}

// ═══════════════════════════════════════════════════════════
// AG-UI EVENT ENVELOPE (Dashboard boundary adapter)
// ═══════════════════════════════════════════════════════════

export type AgUiEventType =
  | "lifecycle"       // Agent spawned, state changed, died
  | "text_message"    // Agent text output (streaming)
  | "tool_call"       // Agent invoked a tool
  | "tool_result"     // Tool returned a result
  | "state_snapshot"  // Full agent state update
  | "state_delta"     // Incremental agent state update
  | "run_started"     // New run ledger entry
  | "run_finished"    // Run completed or failed
  | "approval_needed" // Keeper attention required
  | "custom";         // Extension point

export interface AgUiEvent {
  id: string;
  type: AgUiEventType;
  agentId: string | null;
  sessionId: string | null;
  buildId: string | null;
  timestamp: string;
  data: Record<string, unknown>;
  // SSE delivery metadata
  sequence: number;
  retryMs: number;
}

// ═══════════════════════════════════════════════════════════
// RUNTIME — Where Workers Execute (Layer 5: Runtime)
// ═══════════════════════════════════════════════════════════

export interface RuntimeCapabilities {
  interactive: boolean; // tmux-based TUI
  headless: boolean; // Node.js child_process with NDJSON
  rpc: boolean; // programmatic API (e.g., Pi CLI)
  subagents: boolean; // can spawn child agents
  maxContextTokens: number;
  supportedModels: string[];
}

export interface RuntimeAdapter {
  id: string;
  name: string;
  capabilities: RuntimeCapabilities;

  buildSpawnCommand(config: SpawnConfig): string[];
  deployConfig(agentDir: string, overlay: string): void;
  detectReady(handle: AgentHandle): Promise<boolean>;
  parseTranscript(raw: string): TranscriptEntry[];
  buildEnv(config: SpawnConfig): Record<string, string>;

  // Optional
  connect?(handle: AgentHandle): Promise<RpcConnection>;
}

export interface SpawnConfig {
  agentName: string;
  role: AgentRole;
  skillName: string;
  worktreePath: string;
  overlay: string;
  model: string | null;
  env: Record<string, string>;
}

export interface AgentHandle {
  agentId: string;
  runtimeId: string;
  pid: number | null;
  tmuxSession: string | null;
  worktreePath: string;
  startedAt: string;
}

export interface TranscriptEntry {
  timestamp: string;
  type: "tool_call" | "tool_result" | "text" | "error";
  content: string;
}

export interface RpcConnection {
  send(method: string, params: unknown): Promise<unknown>;
  close(): void;
}

// ═══════════════════════════════════════════════════════════
// SESSIONS — Chambers (Layer 5: Runtime)
// ═══════════════════════════════════════════════════════════

export type SessionStatus = "active" | "completed" | "crashed" | "handoff";

export interface Session {
  id: string;
  agentId: string;
  runtimeId: string;
  status: SessionStatus;
  startedAt: string;
  endedAt: string | null;
  tokensUsed: number;
  cost: number;
  handoffCheckpoint: Checkpoint | null;
}

export interface Checkpoint {
  agentName: string;
  taskId: string;
  completedSteps: string[];
  remainingSteps: string[];
  currentState: Record<string, unknown>;
  filesModified: string[];
  openQuestions: string[];
  timestamp: string;
}

// ═══════════════════════════════════════════════════════════
// EVENTS — The Airway (Layer 5: Observability)
// ═══════════════════════════════════════════════════════════

export type EventType =
  | "tool_start"
  | "tool_end"
  | "session_start"
  | "session_end"
  | "mail_sent"
  | "mail_received"
  | "spawn"
  | "error"
  | "progress"
  | "result"
  | "heartbeat"
  | "gate_check"
  | "merge_attempt"
  | "conflict_resolution";

export interface PlatformEvent {
  id: string;
  type: EventType;
  agentId: string | null;
  sessionId: string | null;
  workItemId: string | null;
  timestamp: string;
  data: Record<string, unknown>;
}

// ═══════════════════════════════════════════════════════════
// CONTRACTS (Layer 3: Quality)
// ═══════════════════════════════════════════════════════════

export type ContractType =
  | "openapi"
  | "asyncapi"
  | "pydantic"
  | "typescript"
  | "json-schema";

export interface Contract {
  id: string;
  name: string;
  type: ContractType;
  version: string;
  path: string; // filesystem path to contract file
  ownerSkill: string;
  dependents: string[]; // skill names that depend on this contract
  createdAt: string;
  updatedAt: string;
}

export interface AuditResult {
  contractId: string;
  passed: boolean;
  conformanceScore: number; // 1-5
  violations: ContractViolation[];
  warnings: string[];
  auditedAt: string;
}

export interface ContractViolation {
  severity: "critical" | "high" | "medium" | "low";
  field: string;
  expected: string;
  actual: string;
  file: string;
  line: number | null;
}

// ═══════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════

export interface PlatformConfig {
  platform: {
    name: string;
    version: string;
  };
  postgres: PostgresConfig;
  dolt: DoltConfig;
  valkey: ValkeyConfig;
  clickhouse: ClickHouseConfig;
  fleet: FleetConfig;
  merge: MergeConfig;
  quality: QualityConfig;
  observability: ObservabilityConfig;
  server: ServerConfig;
}

export interface PostgresConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
}

export interface DoltConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
}

export interface ValkeyConfig {
  host: string;
  port: number;
  password: string;
}

export interface ClickHouseConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
}

export interface FleetConfig {
  maxAgents: number;
  maxDepth: number;
  defaultRuntime: string;
}

export interface MergeConfig {
  strategy: "batch-then-bisect" | "sequential";
  maxBatchSize: number;
  maxRetries: number;
}

export interface QualityConfig {
  minContractConformance: number;
  minSecurity: number;
  blockOnCritical: boolean;
}

export interface ObservabilityConfig {
  heartbeatIntervalS: number;
  staleThresholdS: number;
  watchdogTiers: string[];
}

export interface ServerConfig {
  host: string;
  port: number;
}

// ═══════════════════════════════════════════════════════════
// SKILLS — Blueprints in The Waggle (Layer 1: Skill / Prompt)
// ═══════════════════════════════════════════════════════════

export interface SkillMetadata {
  name: string;
  version: string;
  description: string;
  role: AgentRole;
  domain: string | null;
  path: string;
  owns: OwnershipClaim;
  allowedTools: string[];
  bashGuards: BashGuards;
  composesWith: string[];
  spawnedBy: string | null;
  cognitivePatterns: string[];
  bodyLoaded: boolean;
}

export interface OwnershipClaim {
  directories: string[];
  files: string[];
  patterns: string[];
  sharedRead: string[];
}

export interface BashGuards {
  allow: string[];
  deny: string[];
}

export interface SkillDefinition extends SkillMetadata {
  body: string; // full SKILL.md markdown body
  references: string[]; // available reference file paths
}

export interface CognitivePattern {
  name: string;
  author: string;
  domain: string;
  applicableRoles: AgentRole[];
  summary: string;
  principles: string[];
  injectionFormat: string;
}
```

---

## 4. Configuration System

### Environment-based Configuration

The Hive uses environment variables as the primary configuration mechanism, loaded
from `.env` files for local development and injected by Docker Compose / Kubernetes
in deployed environments. No `config.yaml` file — environment variables are the
single source of runtime configuration.

### .env.example

```bash
# ──────────────────────────────────────
# The Hive — Environment Configuration
# Copy to .env and fill in values.
# ──────────────────────────────────────

# Platform
HIVE_NAME=my-colony
HIVE_VERSION=0.1.0

# Server (platform serve)
HIVE_HOST=127.0.0.1
HIVE_PORT=3000

# PostgreSQL — The Comb (operational state)
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
POSTGRES_DB=the_hive
POSTGRES_USER=hive
POSTGRES_PASSWORD=hive_dev

# Dolt — The Frame (work graph, version-controlled)
DOLT_HOST=127.0.0.1
DOLT_PORT=3307
DOLT_DB=the_frame
DOLT_USER=root
DOLT_PASSWORD=

# Valkey — The Airway (event bus + ephemeral state)
VALKEY_HOST=127.0.0.1
VALKEY_PORT=6379
VALKEY_PASSWORD=

# ClickHouse — The Yield (analytics at scale)
CLICKHOUSE_HOST=127.0.0.1
CLICKHOUSE_PORT=8123
CLICKHOUSE_DB=hive_analytics
CLICKHOUSE_USER=default
CLICKHOUSE_PASSWORD=

# Fleet
HIVE_MAX_AGENTS=15
HIVE_MAX_DEPTH=3
HIVE_DEFAULT_RUNTIME=claude-code

# Merge
HIVE_MERGE_STRATEGY=batch-then-bisect
HIVE_MERGE_MAX_BATCH=5
HIVE_MERGE_MAX_RETRIES=3

# Quality
HIVE_MIN_CONTRACT_CONFORMANCE=3
HIVE_MIN_SECURITY=3
HIVE_BLOCK_ON_CRITICAL=true

# Observability
HIVE_HEARTBEAT_INTERVAL_S=60
HIVE_STALE_THRESHOLD_S=300
HIVE_LOG_LEVEL=info
HIVE_LOG_FORMAT=text

# Runtime API keys (never commit real values)
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
GOOGLE_API_KEY=
```

### Configuration Loader (packages/shared/src/config.ts)

Resolution priority: defaults < `.env` < environment variables < CLI flags.

```typescript
// packages/shared/src/config.ts
import type { PlatformConfig } from "@the-hive/contracts";

function env(key: string, fallback: string): string {
  return process.env[key] ?? fallback;
}

function envInt(key: string, fallback: number): number {
  const val = process.env[key];
  return val ? Number.parseInt(val, 10) : fallback;
}

function envBool(key: string, fallback: boolean): boolean {
  const val = process.env[key];
  if (!val) return fallback;
  return val === "true" || val === "1";
}

export function loadConfig(): PlatformConfig {
  return {
    platform: {
      name: env("HIVE_NAME", "my-colony"),
      version: env("HIVE_VERSION", "0.1.0"),
    },
    postgres: {
      host: env("POSTGRES_HOST", "127.0.0.1"),
      port: envInt("POSTGRES_PORT", 5432),
      database: env("POSTGRES_DB", "the_hive"),
      user: env("POSTGRES_USER", "hive"),
      password: env("POSTGRES_PASSWORD", "hive_dev"),
    },
    dolt: {
      host: env("DOLT_HOST", "127.0.0.1"),
      port: envInt("DOLT_PORT", 3307),
      database: env("DOLT_DB", "the_frame"),
      user: env("DOLT_USER", "root"),
      password: env("DOLT_PASSWORD", ""),
    },
    valkey: {
      host: env("VALKEY_HOST", "127.0.0.1"),
      port: envInt("VALKEY_PORT", 6379),
      password: env("VALKEY_PASSWORD", ""),
    },
    clickhouse: {
      host: env("CLICKHOUSE_HOST", "127.0.0.1"),
      port: envInt("CLICKHOUSE_PORT", 8123),
      database: env("CLICKHOUSE_DB", "hive_analytics"),
      user: env("CLICKHOUSE_USER", "default"),
      password: env("CLICKHOUSE_PASSWORD", ""),
    },
    fleet: {
      maxAgents: envInt("HIVE_MAX_AGENTS", 15),
      maxDepth: envInt("HIVE_MAX_DEPTH", 3),
      defaultRuntime: env("HIVE_DEFAULT_RUNTIME", "claude-code"),
    },
    merge: {
      strategy: env("HIVE_MERGE_STRATEGY", "batch-then-bisect") as
        "batch-then-bisect" | "sequential",
      maxBatchSize: envInt("HIVE_MERGE_MAX_BATCH", 5),
      maxRetries: envInt("HIVE_MERGE_MAX_RETRIES", 3),
    },
    quality: {
      minContractConformance: envInt("HIVE_MIN_CONTRACT_CONFORMANCE", 3),
      minSecurity: envInt("HIVE_MIN_SECURITY", 3),
      blockOnCritical: envBool("HIVE_BLOCK_ON_CRITICAL", true),
    },
    observability: {
      heartbeatIntervalS: envInt("HIVE_HEARTBEAT_INTERVAL_S", 60),
      staleThresholdS: envInt("HIVE_STALE_THRESHOLD_S", 300),
      watchdogTiers: ["mechanical", "ai_triage", "monitor"],
    },
    server: {
      host: env("HIVE_HOST", "127.0.0.1"),
      port: envInt("HIVE_PORT", 3000),
    },
  };
}
```

---

## 5. CLI Framework Setup

### Entry Point (apps/control-plane/src/index.ts)

```typescript
#!/usr/bin/env node
// apps/control-plane/src/index.ts
import { createCLI } from "./cli/index.js";

const program = createCLI();
program.parse(process.argv);
```

### Commander.js Setup (apps/control-plane/src/cli/index.ts)

```typescript
// apps/control-plane/src/cli/index.ts
import { Command } from "commander";
import { registerServeCommand } from "./commands/serve.js";
import { registerTrackerCommands } from "./commands/tracker.js";
import { registerFleetCommands } from "./commands/fleet.js";
import { registerMailCommands } from "./commands/mail.js";
import { registerMergeCommands } from "./commands/merge.js";
import { registerSlingCommands } from "./commands/sling.js";
import { registerSkillCommands } from "./commands/skill.js";
import { registerContractCommands } from "./commands/contract.js";
import { registerQualityCommands } from "./commands/quality.js";
import { registerConfigCommands } from "./commands/config.js";
import { registerDoctorCommands } from "./commands/doctor.js";

export function createCLI(): Command {
  const program = new Command();

  program
    .name("platform")
    .description("The Hive — AI agent orchestration platform (The Smoker)")
    .version("0.1.0")
    .option("--json", "Output as JSON")
    .option("--verbose", "Verbose output");

  // HTTP server
  registerServeCommand(program);

  // Work tracking
  const tracker = program
    .command("tracker")
    .description("Work item tracking and dependency management (The Comb)");
  registerTrackerCommands(tracker);

  // Agent fleet
  const fleet = program
    .command("fleet")
    .description("Worker fleet lifecycle management");
  registerFleetCommands(fleet);

  // Communication
  const mail = program
    .command("mail")
    .description("Inter-agent messaging (The Airway)");
  registerMailCommands(mail);

  // Merge queue
  const merge = program
    .command("merge")
    .description("Merge queue and conflict resolution");
  registerMergeCommands(merge);

  // Work dispatch
  const sling = program
    .command("sling")
    .description("Dispatch work to Workers (Swarming)");
  registerSlingCommands(sling);

  // Skill management
  const skill = program
    .command("skill")
    .description("Skill registry and management (The Waggle)");
  registerSkillCommands(skill);

  // Contracts
  const contract = program
    .command("contract")
    .description("Contract authoring and auditing");
  registerContractCommands(contract);

  // Quality
  const quality = program
    .command("quality")
    .description("Quality gates, evals, and audits (Inspection)");
  registerQualityCommands(quality);

  // Configuration
  const config = program
    .command("config")
    .description("Configuration management");
  registerConfigCommands(config);

  // Health checks
  const doctor = program
    .command("doctor")
    .description("Health checks and diagnostics");
  registerDoctorCommands(doctor);

  return program;
}
```

### Serve Command (apps/control-plane/src/cli/commands/serve.ts)

```typescript
// apps/control-plane/src/cli/commands/serve.ts
import type { Command } from "commander";

export function registerServeCommand(program: Command): void {
  program
    .command("serve")
    .description("Start The Hive HTTP server (Fastify)")
    .option("-p, --port <port>", "Port number", "3000")
    .option("-h, --host <host>", "Host address", "127.0.0.1")
    .option("--tls", "Enable TLS")
    .option("--cert <path>", "TLS certificate path")
    .option("--key <path>", "TLS key path")
    .action(async (opts) => {
      const { createApp } = await import("../../server.js");
      const app = await createApp();
      await app.listen({ port: Number(opts.port), host: opts.host });
      console.log(`The Hive listening on http://${opts.host}:${opts.port}`);
    });
}
```

### Fastify Server Factory (apps/control-plane/src/server.ts)

```typescript
// apps/control-plane/src/server.ts
import Fastify from "fastify";
import type { FastifyInstance } from "fastify";

export async function createApp(): Promise<FastifyInstance> {
  const app = Fastify({
    logger: {
      level: process.env.HIVE_LOG_LEVEL ?? "info",
    },
  });

  // Plugins
  await app.register(import("@fastify/cors"), {
    origin: process.env.HIVE_CORS_ORIGIN ?? "http://localhost:5173",
  });
  await app.register(import("@fastify/jwt"), {
    secret: process.env.HIVE_JWT_SECRET ?? "dev-secret-change-me",
  });
  await app.register(import("@fastify/rate-limit"), {
    max: 120,
    timeWindow: "1 minute",
  });

  // Health check (always available, no auth)
  app.get("/health", async () => ({ status: "ok", service: "control-plane" }));

  // API routes registered under /api/v1/
  // TODO: register route modules from ./routes/

  return app;
}
```

### Example Command Registration (apps/control-plane/src/cli/commands/tracker.ts)

```typescript
// apps/control-plane/src/cli/commands/tracker.ts
import type { Command } from "commander";
import { formatOutput } from "../output.js";

export function registerTrackerCommands(parent: Command): void {
  parent
    .command("create")
    .description("Create a new Cell in The Comb")
    .requiredOption("-t, --title <title>", "Work item title")
    .option("-T, --type <type>", "Work item type", "task")
    .option("-p, --priority <priority>", "Priority (0-4)", "2")
    .option("-a, --assignee <assignee>", "Assignee")
    .option("--parent <parentId>", "Parent work item ID")
    .option("--description <description>", "Description")
    .action(async (opts) => {
      // TODO: implement via tracker service
      formatOutput({ status: "created", id: "wi-TODO", ...opts }, parent.parent);
    });

  parent
    .command("list")
    .description("List Cells")
    .option("-s, --status <status>", "Filter by status")
    .option("-T, --type <type>", "Filter by type")
    .option("-a, --assignee <assignee>", "Filter by assignee")
    .option("--ready", "Show only ready (unblocked) items")
    .option("-n, --limit <n>", "Max results", "20")
    .action(async (opts) => {
      // TODO: implement via tracker service
      formatOutput({ items: [] }, parent.parent);
    });

  parent
    .command("show <id>")
    .description("Show Cell details")
    .action(async (id) => {
      // TODO: implement via tracker service
      formatOutput({ id, status: "TODO" }, parent.parent);
    });

  parent
    .command("update <id>")
    .description("Update a Cell")
    .option("-s, --status <status>", "New status")
    .option("-p, --priority <priority>", "New priority")
    .option("-a, --assignee <assignee>", "New assignee")
    .option("--description <description>", "Updated description")
    .action(async (id, opts) => {
      // TODO: implement via tracker service
      formatOutput({ id, updated: true, ...opts }, parent.parent);
    });

  parent
    .command("close <id>")
    .description("Close a Cell")
    .option("-r, --reason <reason>", "Close reason")
    .action(async (id, opts) => {
      // TODO: implement via tracker service
      formatOutput({ id, closed: true, ...opts }, parent.parent);
    });

  parent
    .command("deps <id>")
    .description("Show dependencies for a Cell")
    .option("--tree", "Show as dependency tree")
    .action(async (id, opts) => {
      // TODO: implement via tracker service
      formatOutput({ id, dependencies: [] }, parent.parent);
    });

  parent
    .command("ready")
    .description("Show Cells ready for assignment")
    .option("-n, --limit <n>", "Max results", "10")
    .action(async (opts) => {
      // TODO: implement via tracker service
      formatOutput({ items: [] }, parent.parent);
    });
}
```

### Output Formatting (apps/control-plane/src/cli/output.ts)

```typescript
// apps/control-plane/src/cli/output.ts
import type { Command } from "commander";
import chalk from "chalk";

export function formatOutput(data: unknown, program: Command | null): void {
  const isJson = program?.opts?.()?.json;
  if (isJson) {
    console.log(JSON.stringify(data, null, 2));
  } else {
    console.log(data);
  }
}

export function success(message: string): void {
  console.log(chalk.green("[ok]"), message);
}

export function warn(message: string): void {
  console.log(chalk.yellow("[warn]"), message);
}

export function error(message: string): void {
  console.error(chalk.red("[err]"), message);
}

export function info(message: string): void {
  console.log(chalk.blue("[info]"), message);
}
```

---

## 6. Database Module Setup

### PostgreSQL Connection (packages/shared/src/db/postgres.ts)

PostgreSQL is The Comb's operational store — agents, sessions, messages, events, and
all mutable platform state that does not require version control.

```typescript
// packages/shared/src/db/postgres.ts
import { drizzle } from "drizzle-orm/node-postgres";
import pg from "pg";
import { loadConfig } from "../config.js";

let pool: pg.Pool | null = null;

export function getPostgresPool(): pg.Pool {
  if (pool) return pool;

  const config = loadConfig();
  pool = new pg.Pool({
    host: config.postgres.host,
    port: config.postgres.port,
    database: config.postgres.database,
    user: config.postgres.user,
    password: config.postgres.password,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
  });

  return pool;
}

export function getDb() {
  return drizzle(getPostgresPool());
}

export async function closePostgres(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}
```

### Dolt Connection (packages/shared/src/db/dolt.ts)

Dolt is The Frame — the version-controlled work graph. Every work item mutation is a
Dolt commit, enabling `dolt diff`, `dolt log`, and branch-based task isolation.

```typescript
// packages/shared/src/db/dolt.ts
import mysql from "mysql2/promise";
import { loadConfig } from "../config.js";
import type { DoltConfig } from "@the-hive/contracts";

let pool: mysql.Pool | null = null;

export async function getDoltConnection(): Promise<mysql.Pool> {
  if (pool) return pool;

  const config = loadConfig();
  const doltConfig = config.dolt;

  pool = mysql.createPool({
    host: doltConfig.host,
    port: doltConfig.port,
    user: doltConfig.user,
    password: doltConfig.password,
    database: doltConfig.database,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    connectTimeout: 10000,
  });

  return pool;
}

export async function runMigrations(
  dbPool: mysql.Pool,
  migrationsDir: string,
): Promise<void> {
  const { readdirSync, readFileSync } = await import("node:fs");
  const files = readdirSync(migrationsDir)
    .filter((f) => f.endsWith(".sql"))
    .sort();

  // Create migrations tracking table
  await dbPool.execute(`
    CREATE TABLE IF NOT EXISTS _migrations (
      name VARCHAR(255) PRIMARY KEY,
      applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  `);

  for (const file of files) {
    const [rows] = await dbPool.execute(
      "SELECT name FROM _migrations WHERE name = ?",
      [file],
    );
    if ((rows as unknown[]).length > 0) continue;

    const sql = readFileSync(`${migrationsDir}/${file}`, "utf-8");
    const statements = sql.split(";").filter((s) => s.trim());
    for (const stmt of statements) {
      await dbPool.execute(stmt);
    }

    await dbPool.execute("INSERT INTO _migrations (name) VALUES (?)", [file]);
    await dbPool.execute("CALL DOLT_ADD('.')");
    await dbPool.execute("CALL DOLT_COMMIT('-m', ?)", [`migration: ${file}`]);
  }
}

export async function closeDoltConnection(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}
```

### Valkey Connection (packages/shared/src/db/valkey.ts)

Valkey is The Airway — the event bus for inter-agent communication, real-time state
propagation, and rate limiting. Uses Valkey Streams for durable, ordered event
delivery.

```typescript
// packages/shared/src/db/valkey.ts
import Redis from "ioredis";
import { loadConfig } from "../config.js";

let client: Redis | null = null;
let subscriber: Redis | null = null;

export function getValkeyClient(): Redis {
  if (client) return client;

  const config = loadConfig();
  client = new Redis({
    host: config.valkey.host,
    port: config.valkey.port,
    password: config.valkey.password || undefined,
    maxRetriesPerRequest: 3,
    retryStrategy(times: number) {
      return Math.min(times * 50, 2000);
    },
  });

  return client;
}

export function getValkeySubscriber(): Redis {
  if (subscriber) return subscriber;

  const config = loadConfig();
  subscriber = new Redis({
    host: config.valkey.host,
    port: config.valkey.port,
    password: config.valkey.password || undefined,
  });

  return subscriber;
}

// Airway stream helpers
export async function publishToAirway(
  stream: string,
  data: Record<string, string>,
): Promise<string> {
  const valkey = getValkeyClient();
  return valkey.xadd(stream, "*", ...Object.entries(data).flat());
}

export async function readFromAirway(
  stream: string,
  lastId: string = "0",
  count: number = 10,
): Promise<unknown[]> {
  const valkey = getValkeyClient();
  const result = await valkey.xread("COUNT", count, "BLOCK", 1000, "STREAMS", stream, lastId);
  return result ?? [];
}

export async function closeValkey(): Promise<void> {
  if (client) {
    client.disconnect();
    client = null;
  }
  if (subscriber) {
    subscriber.disconnect();
    subscriber = null;
  }
}
```

### ClickHouse Connection (packages/shared/src/db/clickhouse.ts)

ClickHouse stores The Yield — analytics at scale. Token usage, cost tracking, run
durations, and aggregated Worker scorecards.

```typescript
// packages/shared/src/db/clickhouse.ts
import { createClient, type ClickHouseClient } from "@clickhouse/client";
import { loadConfig } from "../config.js";

let client: ClickHouseClient | null = null;

export function getClickHouseClient(): ClickHouseClient {
  if (client) return client;

  const config = loadConfig();
  client = createClient({
    url: `http://${config.clickhouse.host}:${config.clickhouse.port}`,
    username: config.clickhouse.user,
    password: config.clickhouse.password,
    database: config.clickhouse.database,
  });

  return client;
}

export async function closeClickHouse(): Promise<void> {
  if (client) {
    await client.close();
    client = null;
  }
}
```

---

## 7. Docker Compose (Local Development)

### infra/compose.local.yml

```yaml
# The Hive — Local Development Infrastructure
# Start: docker compose -f infra/compose.local.yml up -d
# Stop:  docker compose -f infra/compose.local.yml down

name: the-hive

services:
  # ──────────────────────────────────────
  # PostgreSQL — The Comb (operational state)
  # ──────────────────────────────────────
  postgres:
    image: postgres:16-alpine
    container_name: hive-postgres
    environment:
      POSTGRES_DB: the_hive
      POSTGRES_USER: hive
      POSTGRES_PASSWORD: hive_dev
    ports:
      - "5432:5432"
    volumes:
      - hive-pg-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U hive -d the_hive"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - hive-net

  # ──────────────────────────────────────
  # Valkey 8 — The Airway (event bus)
  # ──────────────────────────────────────
  valkey:
    image: valkey/valkey:8-alpine
    container_name: hive-valkey
    ports:
      - "6379:6379"
    volumes:
      - hive-valkey-data:/data
    healthcheck:
      test: ["CMD", "valkey-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - hive-net

  # ──────────────────────────────────────
  # ClickHouse — The Yield (analytics)
  # ──────────────────────────────────────
  clickhouse:
    image: clickhouse/clickhouse-server:latest
    container_name: hive-clickhouse
    environment:
      CLICKHOUSE_DB: hive_analytics
      CLICKHOUSE_USER: default
      CLICKHOUSE_PASSWORD: ""
    ports:
      - "8123:8123"   # HTTP interface
      - "9000:9000"   # Native protocol
    volumes:
      - hive-ch-data:/var/lib/clickhouse
    healthcheck:
      test: ["CMD", "clickhouse-client", "--query", "SELECT 1"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - hive-net

  # ──────────────────────────────────────
  # Dolt — The Frame (version-controlled work graph)
  # ──────────────────────────────────────
  dolt:
    image: dolthub/dolt-sql-server:latest
    container_name: hive-dolt
    command: >
      -l debug
      --host 0.0.0.0
      --port 3307
    ports:
      - "3307:3307"
    volumes:
      - hive-dolt-data:/var/lib/dolt
    healthcheck:
      test: ["CMD-SHELL", "dolt sql -q 'SELECT 1' 2>/dev/null || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 10
    networks:
      - hive-net

volumes:
  hive-pg-data:
  hive-valkey-data:
  hive-ch-data:
  hive-dolt-data:

networks:
  hive-net:
    driver: bridge
```

---

## 8. Infrastructure Scripts

### infra/scripts/check-prereqs.sh

```bash
#!/usr/bin/env bash
# Check prerequisites for The Hive local development.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

errors=0

check() {
  local cmd="$1"
  local min_version="$2"
  local install_hint="$3"

  if command -v "$cmd" &>/dev/null; then
    local version
    version=$("$cmd" --version 2>&1 | head -1)
    echo -e "${GREEN}[ok]${NC} $cmd found: $version"
  else
    echo -e "${RED}[missing]${NC} $cmd not found. Install: $install_hint"
    errors=$((errors + 1))
  fi
}

echo "Checking The Hive prerequisites..."
echo ""

check "node" "22.0.0" "https://nodejs.org/ (v22+)"
check "pnpm" "9.0.0" "npm install -g pnpm"
check "docker" "24.0.0" "https://docs.docker.com/get-docker/"
check "docker" "compose" "Included with Docker Desktop"

echo ""
if [ "$errors" -gt 0 ]; then
  echo -e "${RED}$errors prerequisite(s) missing.${NC}"
  exit 1
else
  echo -e "${GREEN}All prerequisites met.${NC}"
fi
```

### infra/scripts/dev-up.sh

```bash
#!/usr/bin/env bash
# Start The Hive local development infrastructure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

echo "Starting The Hive infrastructure..."
docker compose -f "$INFRA_DIR/compose.local.yml" up -d

echo "Waiting for services to be healthy..."
docker compose -f "$INFRA_DIR/compose.local.yml" ps

echo ""
echo "Infrastructure ready. Services:"
echo "  PostgreSQL (The Comb):   localhost:5432"
echo "  Valkey (The Airway):     localhost:6379"
echo "  ClickHouse (The Yield):  localhost:8123"
echo "  Dolt (The Frame):        localhost:3307"
```

### infra/scripts/dev-down.sh

```bash
#!/usr/bin/env bash
# Stop The Hive local development infrastructure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

echo "Stopping The Hive infrastructure..."
docker compose -f "$INFRA_DIR/compose.local.yml" down

echo "Infrastructure stopped."
```

---

## 9. CLAUDE.md for Self-Building

This is The Hive's own CLAUDE.md, written so the Worker team can build the
platform itself. It lives at the repo root.

```markdown
# CLAUDE.md

## What This Is

The Hive — AI agent orchestration platform. TypeScript / Node.js / Fastify.
PostgreSQL for operational state (The Comb), Dolt for version-controlled work
graph (The Frame), Valkey Streams for event bus (The Airway), ClickHouse for
analytics (The Yield). Turborepo/pnpm monorepo.

## Commands

    pnpm install          # Install all workspace dependencies
    pnpm build            # Build all packages (Turborepo)
    pnpm dev              # Watch mode across all packages
    pnpm test             # All tests (vitest)
    pnpm test:unit        # Unit tests only
    pnpm typecheck        # TypeScript strict check
    pnpm lint             # Biome check
    pnpm lint:fix         # Biome auto-fix
    pnpm format           # Biome format
    pnpm infra:up         # Start Docker Compose (Postgres, Valkey, ClickHouse, Dolt)
    pnpm infra:down       # Stop Docker Compose
    pnpm serve            # Start Fastify server (platform serve)

## Architecture

Service-hosted monorepo. Five layers, each mapped to workspace packages.

| Layer | Packages | Responsibility |
|-------|----------|---------------|
| Skill / Prompt | `skills/`, `templates/` | What Workers know (Blueprints in The Waggle) |
| Orchestration | `apps/control-plane`, `services/runtime-orchestrator` | Who does what (The Queen) |
| Quality | `services/review-engine`, `services/browser-automation` | Whether work is good (Inspection) |
| Work | `apps/control-plane` (tracker routes) | What needs doing (The Comb) |
| Runtime | `services/runtime-orchestrator/adapters/`, `services/router` | Where Workers execute |

### Data Stores

| Store | Hive Name | Purpose | Connection |
|-------|-----------|---------|------------|
| PostgreSQL | The Comb | Operational state — agents, sessions, messages, events | `packages/shared/src/db/postgres.ts` |
| Dolt | The Frame | Version-controlled work graph — work items, dependencies | `packages/shared/src/db/dolt.ts` |
| Valkey | The Airway | Event bus, ephemeral state, rate limiting | `packages/shared/src/db/valkey.ts` |
| ClickHouse | The Yield | Analytics — token usage, cost, run durations | `packages/shared/src/db/clickhouse.ts` |

## Workspace Structure

    apps/control-plane/       — The Queen: Fastify API + CLI (The Smoker)
    apps/operator-console/    — The Glass: React SPA dashboard
    services/runtime-orchestrator/ — Worker spawning, lifecycle, worktrees
    services/browser-automation/   — Browse CLI (Playwright)
    services/review-engine/        — Quality intelligence, contracts
    services/router/               — Capability-based Worker routing
    packages/contracts/       — Shared types + JSON schemas (single source of truth)
    packages/sdk/             — Client SDK for inter-service calls
    packages/shared/          — Common utilities, DB connections, config, logging

## File Ownership Map

    packages/contracts/       — shared (all Workers read, coordinator writes)
    packages/shared/          — shared utilities (infrastructure Worker)
    packages/sdk/             — SDK Worker
    apps/control-plane/       — control-plane Worker
    apps/operator-console/    — frontend Worker
    services/runtime-orchestrator/ — orchestration Worker
    services/browser-automation/   — browse Worker
    services/review-engine/        — quality Worker
    services/router/               — routing Worker
    skills/                   — skill-writer Worker
    templates/                — orchestration Worker
    formulas/                 — tracker Worker
    infra/                    — infrastructure Worker
    tests/unit/               — mirrors package ownership
    tests/integration/        — quality Worker
    tests/e2e/                — quality Worker

## Coding Standards

- TypeScript strict mode. No `any` without a comment explaining why.
- All public functions have JSDoc comments.
- Imports use workspace package names (@the-hive/contracts, @the-hive/shared).
- Every CLI command supports --json for machine-readable output.
- Errors use typed error classes from @the-hive/shared.
- Tests use vitest (Jest-compatible API).
- Prefer const over let. Never use var.
- Functions over classes unless state management requires it.

## How To Add a New CLI Command

1. Create apps/control-plane/src/cli/commands/{name}.ts
2. Export registerXCommands(parent: Command): void
3. Import and register in apps/control-plane/src/cli/index.ts
4. Add tests in tests/unit/control-plane/{name}.test.ts
5. Every command must handle --json via formatOutput()

## How To Add a Runtime Adapter

1. Create services/runtime-orchestrator/src/adapters/{name}.ts
2. Implement RuntimeAdapter interface from @the-hive/contracts
3. Register in services/runtime-orchestrator/src/adapters/detect.ts
4. Add tests in tests/unit/runtime-orchestrator/{name}.test.ts

## How To Add a Skill

1. Create skills/{name}/SKILL.md with YAML frontmatter
2. Follow the frontmatter spec (name, version, description, role, owns)
3. Add references/ directory if the skill needs detailed material
4. Keep body under 500 lines

## How To Modify the Data Model

1. For Dolt (The Frame): create new migration in a migrations/ directory
2. For PostgreSQL (The Comb): create a Drizzle schema migration
3. Update packages/contracts/src/types.ts with corresponding TypeScript types
4. Run: pnpm serve -- doctor --fix
```

---

## 10. Dev Environment Setup

### Prerequisites

```bash
# Node.js (>= 22)
# macOS:
brew install node
# Or use a version manager:
fnm install 22
fnm use 22

# pnpm (>= 9)
npm install -g pnpm

# Docker (>= 24, with Compose v2)
# macOS: Docker Desktop
# Linux: https://docs.docker.com/engine/install/

# Dolt (>= 1.0) — for direct CLI access to The Frame
# macOS:
brew install dolt
# Linux:
sudo bash -c 'curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash'

# Verify prerequisites
bash infra/scripts/check-prereqs.sh
```

### First Run

```bash
# Clone and install
git clone <repo-url> the-hive
cd the-hive
pnpm install

# Start infrastructure (PostgreSQL, Valkey, ClickHouse, Dolt)
pnpm infra:up

# Build all packages
pnpm build

# Verify
pnpm typecheck
pnpm lint
pnpm test

# Start development
pnpm dev              # watch mode across all packages
# or
pnpm serve            # start Fastify server
# or
node apps/control-plane/dist/index.js --help
```

### .gitignore

```gitignore
# Dependencies
node_modules/

# Build output
dist/
.turbo/

# Platform runtime data
.platform/

# Environment
.env
.env.local
.env.*.local

# OS
.DS_Store
Thumbs.db

# Editor
.vscode/settings.json
.idea/

# Dolt
.dolt/

# Test artifacts
coverage/

# Docker volumes (local only)
.docker-data/
```

### .gitattributes

```gitattributes
# Merge strategies for state files
formulas/*.toml merge=union

# Binary files
*.png binary
*.jpg binary
*.ico binary

# Lock files
pnpm-lock.yaml -diff
```

---

## 11. CI/CD Setup

### .github/workflows/ci.yml

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm typecheck

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm lint

  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm test:unit

  integration-tests:
    runs-on: ubuntu-latest
    needs: [typecheck, lint, unit-tests]
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: the_hive
          POSTGRES_USER: hive
          POSTGRES_PASSWORD: hive_dev
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U hive -d the_hive"
          --health-interval 5s
          --health-timeout 3s
          --health-retries 5

      valkey:
        image: valkey/valkey:8-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "valkey-cli ping"
          --health-interval 5s
          --health-timeout 3s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm

      # Install Dolt for The Frame tests
      - name: Install Dolt
        run: |
          sudo bash -c 'curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash'
          dolt version

      - name: Start Dolt Server
        run: |
          mkdir -p /tmp/dolt-data && cd /tmp/dolt-data
          dolt init
          dolt sql-server --port 3307 --host 0.0.0.0 &
          sleep 3

      - run: pnpm install --frozen-lockfile
      - run: pnpm build

      - name: Run integration tests
        env:
          POSTGRES_HOST: 127.0.0.1
          POSTGRES_PORT: 5432
          POSTGRES_DB: the_hive
          POSTGRES_USER: hive
          POSTGRES_PASSWORD: hive_dev
          VALKEY_HOST: 127.0.0.1
          VALKEY_PORT: 6379
          DOLT_HOST: 127.0.0.1
          DOLT_PORT: 3307
          DOLT_USER: root
        run: pnpm test:integration

  e2e-tests:
    runs-on: ubuntu-latest
    needs: [integration-tests]
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: the_hive
          POSTGRES_USER: hive
          POSTGRES_PASSWORD: hive_dev
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U hive -d the_hive"
          --health-interval 5s
          --health-timeout 3s
          --health-retries 5

      valkey:
        image: valkey/valkey:8-alpine
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: pnpm

      - name: Install Dolt
        run: |
          sudo bash -c 'curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash'

      - name: Start Dolt Server
        run: |
          mkdir -p /tmp/dolt-data && cd /tmp/dolt-data
          dolt init
          dolt sql-server --port 3307 --host 0.0.0.0 &
          sleep 3

      - run: pnpm install --frozen-lockfile
      - run: pnpm build

      - name: Run E2E tests
        env:
          POSTGRES_HOST: 127.0.0.1
          POSTGRES_PORT: 5432
          POSTGRES_DB: the_hive
          POSTGRES_USER: hive
          POSTGRES_PASSWORD: hive_dev
          VALKEY_HOST: 127.0.0.1
          VALKEY_PORT: 6379
          DOLT_HOST: 127.0.0.1
          DOLT_PORT: 3307
          DOLT_USER: root
        run: pnpm test:e2e

  docker-build:
    runs-on: ubuntu-latest
    needs: [integration-tests]
    strategy:
      matrix:
        service: [control-plane, runtime-orchestrator, review-engine, router, browser-automation]
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: |
          if [ -f "apps/${{ matrix.service }}/Dockerfile" ]; then
            docker build -f apps/${{ matrix.service }}/Dockerfile -t the-hive/${{ matrix.service }}:ci .
          elif [ -f "services/${{ matrix.service }}/Dockerfile" ]; then
            docker build -f services/${{ matrix.service }}/Dockerfile -t the-hive/${{ matrix.service }}:ci .
          else
            echo "No Dockerfile for ${{ matrix.service }} — skipping (Phase 5+)"
          fi
```

---

## 12. Contributing Guidelines

### Adding a New CLI Command

1. Create `apps/control-plane/src/cli/commands/{name}.ts`.
2. Export a `register{Name}Commands(parent: Command): void` function.
3. Import and register the function in `apps/control-plane/src/cli/index.ts`
   under the appropriate command group.
4. Every action handler must call `formatOutput(data, parent.parent)` to respect
   the `--json` flag.
5. Add unit tests in `tests/unit/control-plane/{name}.test.ts`.
6. Update the `platform {group} --help` output if the command group is new.

### Adding a New Service

1. Create `services/{name}/` with `package.json`, `tsconfig.json`, and `src/index.ts`.
2. The `package.json` name must follow `@the-hive/{name}` convention.
3. Add `@the-hive/contracts` and `@the-hive/shared` as workspace dependencies.
4. Register the service in `pnpm-workspace.yaml` (already covered by `services/*`).
5. Add a health check endpoint at `GET /health`.
6. Add unit tests in `tests/unit/{name}/`.
7. Add a Dockerfile when the service is ready for containerized deployment (Phase 5+).

### Adding a New Runtime Adapter

1. Create `services/runtime-orchestrator/src/adapters/{name}.ts`.
2. Implement the `RuntimeAdapter` interface from `@the-hive/contracts`. Required
   methods: `buildSpawnCommand`, `deployConfig`, `detectReady`,
   `parseTranscript`, `buildEnv`.
3. Add the adapter to the registry map in `services/runtime-orchestrator/src/adapters/detect.ts`.
4. Document runtime-specific environment variables in `.env.example`.
5. Add unit tests in `tests/unit/runtime-orchestrator/{name}.test.ts`. Test at minimum:
   spawn command generation, config deployment, env building.
6. Add an integration test that verifies readiness detection if the runtime is
   available in CI.

### Adding a New Formula

1. Create `formulas/{name}.toml`.
2. Define steps with `id`, `title`, `type`, `depends_on`, and
   `acceptance_criteria`.
3. Test by running `platform tracker cook {name}` and verifying the work item
   hierarchy.
4. Document the formula's purpose and expected workflow in a comment header.

### Adding a New Skill

1. Create `skills/{name}/SKILL.md` with YAML frontmatter.
2. Required fields: `name` (kebab-case, unique), `version` (semver),
   `description` (trigger text with action verbs), `role` (from taxonomy).
3. Optional ownership: `owns.directories`, `owns.files`, `owns.patterns`.
4. Body must be under 500 lines. Move detail to `skills/{name}/references/`.
5. Run `platform skill validate {name}` to check frontmatter.
6. Verify no ownership overlap with `platform skill check-ownership`.

### Modifying the Data Model

1. For Dolt (The Frame): create `migrations/{NNN}-{description}.sql`, numbered
   sequentially. Write both the `CREATE/ALTER` statements and required indexes.
2. For PostgreSQL (The Comb): update or create a Drizzle schema file in the
   relevant service, then run `pnpm drizzle-kit generate` to produce a migration.
3. Update `packages/contracts/src/types.ts` with corresponding TypeScript interfaces.
4. Run `platform doctor --fix` to apply pending migrations.
5. Write a unit test that verifies the migration applies cleanly.

### Code Review Standards

- **Type safety:** No untyped `any` without a justifying comment.
- **Error handling:** All async operations must have error handling. Use typed
  error classes from `@the-hive/shared`.
- **Testing:** Every new function needs at least one unit test (vitest).
  Integration tests required for database operations.
- **CLI consistency:** All commands support `--json`. Output formats are
  consistent across command groups.
- **Documentation:** Public functions have JSDoc. Non-obvious logic has inline
  comments explaining *why*, not *what*.

---

## 13. How ATSA Skills Integrate

### ATSA as the Skill/Prompt Layer

The existing AllTheSkillsAllTheAgents (ATSA) repository contains 21 skills
across 48+ files. These skills serve as the initial Skill/Prompt Layer (Layer 1)
for The Hive. The relationship is structural, not incidental:

**ATSA skills are the Blueprints that define Worker behavior.** The Hive's
orchestration, work, quality, and runtime layers execute Workers; ATSA skills
define what those Workers know and how they think. The Hive loads ATSA skills
via The Waggle (skill registry) and injects them into Worker sessions at spawn
time.

### Integration Mechanism

```
The Hive boots
  --> The Waggle scans skills/**/SKILL.md
    --> Parses YAML frontmatter (Stage 1: metadata, ~100 tokens each)
    --> Builds indexes: by name, by role, by domain, ownership map
  --> The Queen requests Worker spawn
    --> Dispatcher resolves Blueprint for Worker role + domain
    --> Loads full SKILL.md body (Stage 2: ~500 lines)
    --> Overlay generator injects project state (Stage 3: dynamic)
    --> Combined prompt deployed to Worker worktree
  --> Worker reads references on demand (Stage 3: unlimited)
```

### Dogfooding: Building The Hive with Its Own Skills

The Hive uses its own skills to build itself. This is the ultimate
validation of The Waggle. The following mapping shows how Blueprints
correspond to implementation work:

| Blueprint | Builds | Owns |
|-----------|--------|------|
| `coordinator` | The Queen orchestration | formulas/ |
| `lead` | Team decomposition | N/A (coordination only) |
| `builder` (backend domain) | apps/control-plane, packages/* | Backend implementation |
| `builder` (infra domain) | services/runtime-orchestrator, infra/ | Infrastructure implementation |
| `builder` (quality domain) | services/review-engine, services/browser-automation | Quality services |
| `builder` (frontend domain) | apps/operator-console | The Glass |
| `reviewer` | Code review | Read-only |
| `scout` | Codebase exploration | Read-only |
| `merger` | Conflict resolution | Merge scope only |

### Progressive Disclosure in Practice

The token budget for skill loading during a Hive build session:

```
Metadata for 6 Blueprints x ~100 tokens     =    ~600 tokens
Active Blueprint body (1 builder)            =  ~2,000 tokens
2 reference files loaded on demand           =  ~1,000 tokens
Dynamic overlay (project state)              =    ~500 tokens
                                               ────────────
Total skill overhead per Worker               ~4,100 tokens  (< 2% of 200k)
```

This leaves over 98% of the context window for actual work — code, errors,
git output, test results. The Hive's skill loading adds negligible overhead.

### Skill-to-Platform Mapping

ATSA skills from the source repository map to Hive concepts:

| ATSA Skill | Hive Equivalent | Notes |
|------------|----------------|-------|
| orchestrator | The Queen (Coordinator loop) | ATSA's 14-phase playbook becomes the coordinator Blueprint |
| backend-agent | Builder (backend Caste) | File scope + cognitive patterns define the specialization |
| frontend-agent | Builder (frontend Caste) | Same role, different domain config |
| qe-agent | Quality Auditor | QA report schema and Inspection logic carry over directly |
| contract-author | Contract system | Template-driven contract generation |
| contract-auditor | Contract auditor | Conformance checking against implementations |
| skill-writer | Meta skill | Generates new Blueprints following the frontmatter spec |
| project-profiler | Profile system | Codebase analysis for project-specific adaptation |
| context-manager | Handoff protocol | Checkpoint-based context handoff at ~80% usage |

ATSA's existing skills are not discarded — they are the starting point for The
Hive's Blueprint library. As The Hive matures, Blueprints evolve via the
template generation system (see `08-skill-system.md` section 5), but the core
anatomy — YAML frontmatter, markdown body, reference directory — remains
identical.
