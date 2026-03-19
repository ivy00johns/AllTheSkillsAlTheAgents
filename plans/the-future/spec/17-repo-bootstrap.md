# 17 — Repo Bootstrap Specification

**Document type:** Implementation blueprint
**Status:** DRAFT
**Date:** 2026-03-18
**Scope:** First commit scaffold, tooling, and dev workflow for the AI agent orchestration platform
**Depends on:** `03-system-architecture.md` (5-layer model, tech stack), `05-data-model.md` (entities), `08-skill-system.md` (skill anatomy)

---

## 1. Repository Structure

This is the complete file tree for the first commit. Every directory and file listed here
must exist. Files marked with `(stub)` contain only the module signature and a TODO comment;
they are implemented in later phases. Files with full contents are specified in subsequent
sections of this document.

```
platform/
├── README.md
├── package.json
├── tsconfig.json
├── bunfig.toml
├── biome.json
├── .gitignore
├── .gitattributes
├── .env.example
│
├── CLAUDE.md
├── AGENTS.md
├── GEMINI.md
│
├── src/
│   ├── index.ts                  # CLI entry point
│   ├── cli/
│   │   ├── index.ts              # Commander.js setup
│   │   ├── commands/
│   │   │   ├── tracker.ts        # Work tracker commands
│   │   │   ├── fleet.ts          # Agent fleet commands
│   │   │   ├── mail.ts           # Communication commands
│   │   │   ├── merge.ts          # Merge queue commands
│   │   │   ├── sling.ts          # Work dispatch commands
│   │   │   ├── skill.ts          # Skill management commands
│   │   │   ├── contract.ts       # Contract commands
│   │   │   ├── quality.ts        # Quality/eval commands
│   │   │   ├── federation.ts     # Federation commands
│   │   │   ├── config.ts         # Configuration commands
│   │   │   └── doctor.ts         # Health check commands
│   │   └── output.ts             # Shared output formatting
│   │
│   ├── core/
│   │   ├── types.ts              # Shared type definitions (ALL interfaces)
│   │   ├── config.ts             # Configuration loader
│   │   ├── id.ts                 # Hash-based ID generation
│   │   ├── errors.ts             # Error types and handling
│   │   └── logger.ts             # Structured logging
│   │
│   ├── data/
│   │   ├── dolt/
│   │   │   ├── connection.ts     # Dolt SQL Server connection
│   │   │   ├── migrations/
│   │   │   │   ├── 001-work-items.sql
│   │   │   │   ├── 002-dependencies.sql
│   │   │   │   ├── 003-agents.sql
│   │   │   │   ├── 004-convoys.sql
│   │   │   │   └── 005-evidence.sql
│   │   │   └── queries/
│   │   │       ├── ready-queue.sql
│   │   │       ├── blocked-items.sql
│   │   │       └── claim-item.sql
│   │   │
│   │   └── sqlite/
│   │       ├── connection.ts     # SQLite connection (WAL mode)
│   │       ├── mail.ts           # mail.db schema and queries
│   │       ├── sessions.ts       # sessions.db schema and queries
│   │       ├── events.ts         # events.db schema and queries
│   │       └── metrics.ts        # metrics.db schema and queries
│   │
│   ├── tracker/                  # Work tracker module (stub)
│   │   ├── work-item.ts
│   │   ├── dependency.ts
│   │   ├── ready-queue.ts
│   │   ├── formula.ts
│   │   ├── gate.ts
│   │   ├── compaction.ts
│   │   └── hop.ts
│   │
│   ├── orchestration/            # Orchestration engine (stub)
│   │   ├── coordinator.ts
│   │   ├── sling.ts
│   │   ├── lifecycle.ts
│   │   ├── worktree.ts
│   │   ├── tmux.ts
│   │   ├── context.ts
│   │   ├── circuit-breaker.ts
│   │   └── convoy.ts
│   │
│   ├── communication/            # Inter-agent messaging (stub)
│   │   ├── mail.ts
│   │   ├── protocol.ts
│   │   ├── broadcast.ts
│   │   ├── nudge.ts
│   │   └── hooks.ts
│   │
│   ├── quality/                  # Quality intelligence (stub)
│   │   ├── cognitive.ts
│   │   ├── qa-gate.ts
│   │   ├── design-audit.ts
│   │   ├── slop-detection.ts
│   │   ├── evals.ts
│   │   └── browse.ts
│   │
│   ├── merge/                    # Merge system (stub)
│   │   ├── queue.ts
│   │   ├── resolution.ts
│   │   ├── pre-merge.ts
│   │   ├── post-merge.ts
│   │   └── expertise.ts
│   │
│   ├── runtime/                  # Runtime adapters (stub)
│   │   ├── adapter.ts
│   │   ├── detect.ts
│   │   ├── adapters/
│   │   │   ├── claude-code.ts
│   │   │   ├── pi-cli.ts
│   │   │   ├── codex-cli.ts
│   │   │   ├── gemini-cli.ts
│   │   │   └── aider.ts
│   │   ├── instruction-gen.ts
│   │   └── fallback.ts
│   │
│   ├── contracts/                # Contract system (stub)
│   │   ├── author.ts
│   │   ├── auditor.ts
│   │   ├── ownership.ts
│   │   └── templates/
│   │       └── .gitkeep
│   │
│   ├── federation/               # Federation module (stub)
│   │   ├── sync.ts
│   │   ├── sovereignty.ts
│   │   ├── routing.ts
│   │   └── portability.ts
│   │
│   └── observability/            # Observability subsystem (stub)
│       ├── events.ts
│       ├── watchdog.ts
│       ├── dashboard.ts
│       ├── alerts.ts
│       ├── doctor.ts
│       └── audit.ts
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
├── contracts/
│   └── .gitkeep
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
│   │   ├── core/
│   │   │   ├── id.test.ts
│   │   │   ├── config.test.ts
│   │   │   └── errors.test.ts
│   │   ├── tracker/
│   │   │   └── .gitkeep
│   │   ├── communication/
│   │   │   └── .gitkeep
│   │   └── merge/
│   │       └── .gitkeep
│   ├── integration/
│   │   ├── dolt.test.ts
│   │   ├── sqlite.test.ts
│   │   └── .gitkeep
│   └── e2e/
│       └── .gitkeep
│
├── .github/
│   └── workflows/
│       └── ci.yml
│
└── docs/
    └── .gitkeep
```

---

## 2. Package Configuration

### package.json

```json
{
  "name": "platform",
  "version": "0.1.0",
  "description": "AI agent orchestration platform — work tracking, fleet management, merge queue, quality gates",
  "type": "module",
  "main": "dist/index.js",
  "bin": {
    "platform": "dist/index.js"
  },
  "scripts": {
    "build": "bun build src/index.ts --outdir dist --target bun",
    "dev": "bun --watch src/index.ts",
    "test": "bun test",
    "test:unit": "bun test tests/unit",
    "test:integration": "bun test tests/integration",
    "test:e2e": "bun test tests/e2e",
    "lint": "biome check .",
    "lint:fix": "biome check --write .",
    "format": "biome format --write .",
    "typecheck": "tsc --noEmit",
    "clean": "rm -rf dist .platform/db",
    "doctor": "bun run src/index.ts doctor",
    "precommit": "bun run typecheck && bun run lint && bun run test:unit"
  },
  "dependencies": {
    "commander": "^13.1.0",
    "better-sqlite3": "^11.8.0",
    "mysql2": "^3.12.0",
    "yaml": "^2.7.0",
    "handlebars": "^4.7.8",
    "chalk": "^5.4.1",
    "dotenv": "^16.5.0"
  },
  "devDependencies": {
    "@types/better-sqlite3": "^7.6.13",
    "@types/bun": "^1.2.0",
    "@biomejs/biome": "^1.9.0",
    "typescript": "^5.7.0"
  },
  "engines": {
    "bun": ">=1.1.0"
  }
}
```

### tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "outDir": "dist",
    "rootDir": "src",
    "baseUrl": ".",
    "paths": {
      "@core/*": ["src/core/*"],
      "@data/*": ["src/data/*"],
      "@cli/*": ["src/cli/*"],
      "@tracker/*": ["src/tracker/*"],
      "@orchestration/*": ["src/orchestration/*"],
      "@communication/*": ["src/communication/*"],
      "@quality/*": ["src/quality/*"],
      "@merge/*": ["src/merge/*"],
      "@runtime/*": ["src/runtime/*"],
      "@contracts/*": ["src/contracts/*"],
      "@federation/*": ["src/federation/*"],
      "@observability/*": ["src/observability/*"]
    },
    "types": ["bun-types"]
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

### bunfig.toml

```toml
[install]
peer = false

[test]
preload = ["./tests/setup.ts"]
timeout = 30000
bail = 1

[run]
smol = true
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

Complete contents of `src/core/types.ts`. Every shared interface referenced across the
platform's five layers is defined here. This is the single source of truth; all modules
import from `@core/types`.

```typescript
// src/core/types.ts
// ─────────────────────────────────────────────────────────
// Shared type definitions for the AI agent orchestration platform.
// Single source of truth. All modules import from here.
// ─────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════
// WORK ITEMS (Layer 4: Work)
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
  body: string;
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
// AGENTS (Layer 2: Orchestration + Layer 5: Runtime)
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
// COMMUNICATION (Layer 2: Orchestration)
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
// CONVOYS (Layer 2: Orchestration)
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
// QUALITY (Layer 3: Quality)
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
// RUNTIME (Layer 5: Runtime)
// ═══════════════════════════════════════════════════════════

export interface RuntimeCapabilities {
  interactive: boolean; // tmux-based TUI
  headless: boolean; // Bun.spawn with NDJSON
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
// SESSIONS (Layer 5: Runtime)
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
// EVENTS (Layer 5: Observability)
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
// EVIDENCE (Layer 3: Quality)
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

export interface Evidence {
  id: string;
  type: EvidenceType;
  workItemId: string;
  agentId: string;
  path: string; // filesystem path to evidence file
  contentHash: string;
  description: string;
  createdAt: string;
  metadata: Record<string, unknown>;
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
  dolt: DoltConfig;
  sqlite: SqliteConfig;
  fleet: FleetConfig;
  merge: MergeConfig;
  quality: QualityConfig;
  observability: ObservabilityConfig;
}

export interface DoltConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
  autoStart: boolean;
}

export interface SqliteConfig {
  dir: string;
  walMode: boolean;
  busyTimeoutMs: number;
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

// ═══════════════════════════════════════════════════════════
// SKILLS (Layer 1: Skill / Prompt)
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

### config.yaml (committed defaults)

```yaml
platform:
  name: "my-platform"
  version: "0.1.0"

dolt:
  host: "127.0.0.1"
  port: 3307
  database: "platform"
  user: "root"
  password: ""
  auto_start: true

sqlite:
  dir: ".platform/db"
  wal_mode: true
  busy_timeout_ms: 5000

fleet:
  max_agents: 15
  max_depth: 3
  default_runtime: "claude-code"

merge:
  strategy: "batch-then-bisect"
  max_batch_size: 5
  max_retries: 3

quality:
  min_contract_conformance: 3
  min_security: 3
  block_on_critical: true

observability:
  heartbeat_interval_s: 60
  stale_threshold_s: 300
  watchdog_tiers:
    - mechanical
    - ai_triage
    - monitor
```

### config.local.yaml (gitignored, machine-specific overrides)

```yaml
# Machine-specific overrides. This file is in .gitignore.
# Copy from config.yaml and change what you need.
dolt:
  port: 3307
  password: ""

fleet:
  max_agents: 5
  default_runtime: "claude-code"
```

### .env.example

```bash
# Dolt SQL Server
PLATFORM_DOLT_HOST=127.0.0.1
PLATFORM_DOLT_PORT=3307
PLATFORM_DOLT_USER=root
PLATFORM_DOLT_PASSWORD=

# Runtime API keys (never commit real values)
ANTHROPIC_API_KEY=
OPENAI_API_KEY=
GOOGLE_API_KEY=

# Observability
PLATFORM_LOG_LEVEL=info
PLATFORM_LOG_FORMAT=text  # text | json
```

### Configuration Loader (src/core/config.ts)

Resolution priority: defaults < config.yaml < config.local.yaml < env vars < CLI flags.

```typescript
// src/core/config.ts
import { readFileSync, existsSync } from "node:fs";
import { parse as parseYaml } from "yaml";
import type { PlatformConfig } from "./types.js";

const DEFAULT_CONFIG: PlatformConfig = {
  platform: { name: "my-platform", version: "0.1.0" },
  dolt: {
    host: "127.0.0.1",
    port: 3307,
    database: "platform",
    user: "root",
    password: "",
    autoStart: true,
  },
  sqlite: { dir: ".platform/db", walMode: true, busyTimeoutMs: 5000 },
  fleet: { maxAgents: 15, maxDepth: 3, defaultRuntime: "claude-code" },
  merge: { strategy: "batch-then-bisect", maxBatchSize: 5, maxRetries: 3 },
  quality: { minContractConformance: 3, minSecurity: 3, blockOnCritical: true },
  observability: {
    heartbeatIntervalS: 60,
    staleThresholdS: 300,
    watchdogTiers: ["mechanical", "ai_triage", "monitor"],
  },
};

function snakeToCamel(obj: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj)) {
    const camelKey = key.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase());
    result[camelKey] =
      value && typeof value === "object" && !Array.isArray(value)
        ? snakeToCamel(value as Record<string, unknown>)
        : value;
  }
  return result;
}

function deepMerge(
  target: Record<string, unknown>,
  source: Record<string, unknown>,
): Record<string, unknown> {
  const result = { ...target };
  for (const [key, value] of Object.entries(source)) {
    if (
      value && typeof value === "object" && !Array.isArray(value) &&
      target[key] && typeof target[key] === "object"
    ) {
      result[key] = deepMerge(
        target[key] as Record<string, unknown>,
        value as Record<string, unknown>,
      );
    } else {
      result[key] = value;
    }
  }
  return result;
}

export function loadConfig(projectRoot: string = process.cwd()): PlatformConfig {
  let config = structuredClone(DEFAULT_CONFIG) as unknown as Record<string, unknown>;

  // Layer 1: config.yaml (project defaults)
  const projectPath = `${projectRoot}/config.yaml`;
  if (existsSync(projectPath)) {
    const raw = parseYaml(readFileSync(projectPath, "utf-8")) as Record<string, unknown>;
    config = deepMerge(config, snakeToCamel(raw));
  }

  // Layer 2: config.local.yaml (machine overrides, gitignored)
  const localPath = `${projectRoot}/config.local.yaml`;
  if (existsSync(localPath)) {
    const raw = parseYaml(readFileSync(localPath, "utf-8")) as Record<string, unknown>;
    config = deepMerge(config, snakeToCamel(raw));
  }

  // Layer 3: environment variables
  const dolt = config.dolt as Record<string, unknown>;
  if (process.env.PLATFORM_DOLT_HOST) dolt.host = process.env.PLATFORM_DOLT_HOST;
  if (process.env.PLATFORM_DOLT_PORT) dolt.port = Number(process.env.PLATFORM_DOLT_PORT);
  if (process.env.PLATFORM_DOLT_USER) dolt.user = process.env.PLATFORM_DOLT_USER;
  if (process.env.PLATFORM_DOLT_PASSWORD) dolt.password = process.env.PLATFORM_DOLT_PASSWORD;

  return config as unknown as PlatformConfig;
}
```

---

## 5. CLI Framework Setup

### Entry Point (src/index.ts)

```typescript
#!/usr/bin/env bun
// src/index.ts
import { createCLI } from "./cli/index.js";

const program = createCLI();
program.parse(process.argv);
```

### Commander.js Setup (src/cli/index.ts)

```typescript
// src/cli/index.ts
import { Command } from "commander";
import { registerTrackerCommands } from "./commands/tracker.js";
import { registerFleetCommands } from "./commands/fleet.js";
import { registerMailCommands } from "./commands/mail.js";
import { registerMergeCommands } from "./commands/merge.js";
import { registerSlingCommands } from "./commands/sling.js";
import { registerSkillCommands } from "./commands/skill.js";
import { registerContractCommands } from "./commands/contract.js";
import { registerQualityCommands } from "./commands/quality.js";
import { registerFederationCommands } from "./commands/federation.js";
import { registerConfigCommands } from "./commands/config.js";
import { registerDoctorCommands } from "./commands/doctor.js";

export function createCLI(): Command {
  const program = new Command();

  program
    .name("platform")
    .description("AI agent orchestration platform")
    .version("0.1.0")
    .option("--json", "Output as JSON")
    .option("--verbose", "Verbose output")
    .option("--config <path>", "Path to config.yaml");

  // Work tracking
  const tracker = program
    .command("tracker")
    .description("Work item tracking and dependency management");
  registerTrackerCommands(tracker);

  // Agent fleet
  const fleet = program
    .command("fleet")
    .description("Agent fleet lifecycle management");
  registerFleetCommands(fleet);

  // Communication
  const mail = program
    .command("mail")
    .description("Inter-agent messaging");
  registerMailCommands(mail);

  // Merge queue
  const merge = program
    .command("merge")
    .description("Merge queue and conflict resolution");
  registerMergeCommands(merge);

  // Work dispatch
  const sling = program
    .command("sling")
    .description("Dispatch work to agents");
  registerSlingCommands(sling);

  // Skill management
  const skill = program
    .command("skill")
    .description("Skill registry and management");
  registerSkillCommands(skill);

  // Contracts
  const contract = program
    .command("contract")
    .description("Contract authoring and auditing");
  registerContractCommands(contract);

  // Quality
  const quality = program
    .command("quality")
    .description("Quality gates, evals, and audits");
  registerQualityCommands(quality);

  // Federation
  const federation = program
    .command("federation")
    .description("Cross-instance federation");
  registerFederationCommands(federation);

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

### Example Command Registration (src/cli/commands/tracker.ts)

```typescript
// src/cli/commands/tracker.ts
import type { Command } from "commander";
import { formatOutput } from "../output.js";

export function registerTrackerCommands(parent: Command): void {
  parent
    .command("create")
    .description("Create a new work item")
    .requiredOption("-t, --title <title>", "Work item title")
    .option("-T, --type <type>", "Work item type", "task")
    .option("-p, --priority <priority>", "Priority (0-4)", "2")
    .option("-a, --assignee <assignee>", "Assignee")
    .option("--parent <parentId>", "Parent work item ID")
    .option("--body <body>", "Description body")
    .action(async (opts) => {
      // TODO: implement via tracker module
      formatOutput({ status: "created", id: "wi-TODO", ...opts }, parent.parent);
    });

  parent
    .command("list")
    .description("List work items")
    .option("-s, --status <status>", "Filter by status")
    .option("-T, --type <type>", "Filter by type")
    .option("-a, --assignee <assignee>", "Filter by assignee")
    .option("--ready", "Show only ready (unblocked) items")
    .option("-n, --limit <n>", "Max results", "20")
    .action(async (opts) => {
      // TODO: implement via tracker module
      formatOutput({ items: [] }, parent.parent);
    });

  parent
    .command("show <id>")
    .description("Show work item details")
    .action(async (id) => {
      // TODO: implement via tracker module
      formatOutput({ id, status: "TODO" }, parent.parent);
    });

  parent
    .command("update <id>")
    .description("Update a work item")
    .option("-s, --status <status>", "New status")
    .option("-p, --priority <priority>", "New priority")
    .option("-a, --assignee <assignee>", "New assignee")
    .option("--body <body>", "Updated description")
    .action(async (id, opts) => {
      // TODO: implement via tracker module
      formatOutput({ id, updated: true, ...opts }, parent.parent);
    });

  parent
    .command("close <id>")
    .description("Close a work item")
    .option("-r, --reason <reason>", "Close reason")
    .action(async (id, opts) => {
      // TODO: implement via tracker module
      formatOutput({ id, closed: true, ...opts }, parent.parent);
    });

  parent
    .command("deps <id>")
    .description("Show dependencies for a work item")
    .option("--tree", "Show as dependency tree")
    .action(async (id, opts) => {
      // TODO: implement via tracker module
      formatOutput({ id, dependencies: [] }, parent.parent);
    });

  parent
    .command("ready")
    .description("Show work items ready for assignment")
    .option("-n, --limit <n>", "Max results", "10")
    .action(async (opts) => {
      // TODO: implement via tracker module
      formatOutput({ items: [] }, parent.parent);
    });
}
```

### Output Formatting (src/cli/output.ts)

```typescript
// src/cli/output.ts
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

### Dolt Connection (src/data/dolt/connection.ts)

```typescript
// src/data/dolt/connection.ts
import mysql from "mysql2/promise";
import { loadConfig } from "@core/config.js";
import type { DoltConfig } from "@core/types.js";

let pool: mysql.Pool | null = null;

export async function getDoltConnection(): Promise<mysql.Pool> {
  if (pool) return pool;

  const config = loadConfig();
  const doltConfig = config.dolt;

  // Auto-start Dolt server if configured
  if (doltConfig.autoStart) {
    await ensureDoltRunning(doltConfig);
  }

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

async function ensureDoltRunning(config: DoltConfig): Promise<void> {
  try {
    const testConn = await mysql.createConnection({
      host: config.host,
      port: config.port,
      user: config.user,
      password: config.password,
      connectTimeout: 2000,
    });
    await testConn.end();
  } catch {
    // Server not running — attempt auto-start
    Bun.spawn(
      ["dolt", "sql-server", "--port", String(config.port), "--host", config.host],
      { stdout: "ignore", stderr: "ignore" },
    );

    // Wait for server readiness (up to 10s)
    for (let i = 0; i < 20; i++) {
      await new Promise((r) => setTimeout(r, 500));
      try {
        const testConn = await mysql.createConnection({
          host: config.host,
          port: config.port,
          user: config.user,
          password: config.password,
          connectTimeout: 1000,
        });
        await testConn.end();
        return;
      } catch {
        // Not ready yet
      }
    }
    throw new Error(
      `Dolt server failed to start on ${config.host}:${config.port}`,
    );
  }
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

### SQLite Connection (src/data/sqlite/connection.ts)

```typescript
// src/data/sqlite/connection.ts
import Database from "better-sqlite3";
import { mkdirSync, existsSync } from "node:fs";
import { loadConfig } from "@core/config.js";

const databases = new Map<string, Database.Database>();

export type SqliteDbName = "mail" | "sessions" | "events" | "metrics";

export function getSqliteDb(name: SqliteDbName): Database.Database {
  if (databases.has(name)) return databases.get(name)!;

  const config = loadConfig();
  const dir = config.sqlite.dir;

  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }

  const dbPath = `${dir}/${name}.db`;
  const db = new Database(dbPath);

  // WAL mode for concurrent access from multiple agent processes
  if (config.sqlite.walMode) {
    db.pragma("journal_mode = WAL");
  }
  db.pragma(`busy_timeout = ${config.sqlite.busyTimeoutMs}`);
  db.pragma("foreign_keys = ON");

  databases.set(name, db);
  return db;
}

export function closeSqliteDb(name: SqliteDbName): void {
  const db = databases.get(name);
  if (db) {
    db.close();
    databases.delete(name);
  }
}

export function closeAllSqliteDbs(): void {
  for (const [, db] of databases) {
    db.close();
  }
  databases.clear();
}
```

### SQLite Mail Schema (src/data/sqlite/mail.ts)

```typescript
// src/data/sqlite/mail.ts
import { getSqliteDb } from "./connection.js";

export function initMailDb(): void {
  const db = getSqliteDb("mail");

  db.exec(`
    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      from_agent TEXT NOT NULL,
      to_agent TEXT NOT NULL,
      subject TEXT NOT NULL,
      body TEXT NOT NULL DEFAULT '',
      priority TEXT NOT NULL DEFAULT 'normal'
        CHECK (priority IN ('critical', 'high', 'normal', 'low')),
      protocol TEXT,
      thread_id TEXT,
      reply_to TEXT,
      sent_at TEXT NOT NULL DEFAULT (datetime('now')),
      read_at TEXT,
      expires_at TEXT,
      metadata TEXT NOT NULL DEFAULT '{}'
    );

    CREATE INDEX IF NOT EXISTS idx_mail_to ON messages (to_agent, read_at);
    CREATE INDEX IF NOT EXISTS idx_mail_thread ON messages (thread_id);
    CREATE INDEX IF NOT EXISTS idx_mail_sent ON messages (sent_at);
  `);
}
```

### SQLite Sessions Schema (src/data/sqlite/sessions.ts)

```typescript
// src/data/sqlite/sessions.ts
import { getSqliteDb } from "./connection.js";

export function initSessionsDb(): void {
  const db = getSqliteDb("sessions");

  db.exec(`
    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      agent_id TEXT NOT NULL,
      runtime_id TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'completed', 'crashed', 'handoff')),
      started_at TEXT NOT NULL DEFAULT (datetime('now')),
      ended_at TEXT,
      tokens_used INTEGER NOT NULL DEFAULT 0,
      cost REAL NOT NULL DEFAULT 0.0,
      handoff_checkpoint TEXT
    );

    CREATE INDEX IF NOT EXISTS idx_sessions_agent ON sessions (agent_id);
    CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions (status);
  `);
}
```

### SQLite Events Schema (src/data/sqlite/events.ts)

```typescript
// src/data/sqlite/events.ts
import { getSqliteDb } from "./connection.js";

export function initEventsDb(): void {
  const db = getSqliteDb("events");

  db.exec(`
    CREATE TABLE IF NOT EXISTS events (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      agent_id TEXT,
      session_id TEXT,
      work_item_id TEXT,
      timestamp TEXT NOT NULL DEFAULT (datetime('now')),
      data TEXT NOT NULL DEFAULT '{}'
    );

    CREATE INDEX IF NOT EXISTS idx_events_type ON events (type);
    CREATE INDEX IF NOT EXISTS idx_events_agent ON events (agent_id);
    CREATE INDEX IF NOT EXISTS idx_events_session ON events (session_id);
    CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events (timestamp);
  `);
}
```

### SQLite Metrics Schema (src/data/sqlite/metrics.ts)

```typescript
// src/data/sqlite/metrics.ts
import { getSqliteDb } from "./connection.js";

export function initMetricsDb(): void {
  const db = getSqliteDb("metrics");

  db.exec(`
    CREATE TABLE IF NOT EXISTS token_usage (
      id TEXT PRIMARY KEY,
      agent_id TEXT NOT NULL,
      session_id TEXT NOT NULL,
      runtime_id TEXT NOT NULL,
      model TEXT NOT NULL,
      input_tokens INTEGER NOT NULL DEFAULT 0,
      output_tokens INTEGER NOT NULL DEFAULT 0,
      cost REAL NOT NULL DEFAULT 0.0,
      recorded_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE INDEX IF NOT EXISTS idx_tokens_agent ON token_usage (agent_id);
    CREATE INDEX IF NOT EXISTS idx_tokens_session ON token_usage (session_id);
    CREATE INDEX IF NOT EXISTS idx_tokens_recorded ON token_usage (recorded_at);
  `);
}
```

---

## 7. CLAUDE.md for Self-Building

This is the platform's own CLAUDE.md, written so the agent team can build the
platform itself. It lives at the repo root.

```markdown
# CLAUDE.md

## What This Is

AI agent orchestration platform. TypeScript + Bun. Dolt SQL for work state,
SQLite for operational data. Commander.js CLI.

## Commands

    bun install          # Install dependencies
    bun run build        # Build to dist/
    bun run dev          # Watch mode
    bun test             # All tests
    bun run test:unit    # Unit tests only
    bun run typecheck    # TypeScript strict check
    bun run lint         # Biome check
    bun run lint:fix     # Biome auto-fix
    bun run format       # Biome format

## Architecture

Five layers. Each layer has a src/ directory and exposes interfaces consumed
by adjacent layers. The orchestration layer (L2) is the hub.

| Layer | Directory | Responsibility |
|-------|-----------|---------------|
| Skill / Prompt | `skills/`, `templates/` | What agents know |
| Orchestration | `src/orchestration/`, `src/communication/` | Who does what |
| Quality | `src/quality/`, `src/contracts/` | Whether work is good |
| Work | `src/tracker/`, `src/merge/` | What needs doing |
| Runtime | `src/runtime/` | Where agents execute |

## File Ownership Map

    src/core/           — shared (all agents read, coordinator writes)
    src/cli/            — CLI agent
    src/data/dolt/      — data agent
    src/data/sqlite/    — data agent
    src/tracker/        — tracker agent
    src/orchestration/  — orchestration agent
    src/communication/  — communication agent
    src/quality/        — quality agent
    src/merge/          — merge agent
    src/runtime/        — runtime agent
    src/contracts/      — contracts agent
    src/federation/     — federation agent
    src/observability/  — observability agent
    skills/             — skill-writer agent
    templates/          — orchestration agent
    formulas/           — tracker agent
    tests/unit/         — mirrors src/ ownership
    tests/integration/  — quality agent
    tests/e2e/          — quality agent

## Coding Standards

- TypeScript strict mode. No `any` without a comment explaining why.
- All public functions have JSDoc comments.
- Imports use path aliases (@core/types, @data/dolt/connection).
- Every CLI command supports --json for machine-readable output.
- Errors use typed error classes from src/core/errors.ts.
- Tests use bun test (Jest-compatible API).
- Prefer const over let. Never use var.
- Functions over classes unless state management requires it.

## How To Add a New CLI Command

1. Create src/cli/commands/{name}.ts
2. Export registerXCommands(parent: Command): void
3. Import and register in src/cli/index.ts
4. Add tests in tests/unit/cli/{name}.test.ts
5. Every command must handle --json via formatOutput()

## How To Add a Runtime Adapter

1. Create src/runtime/adapters/{name}.ts
2. Implement RuntimeAdapter interface from @core/types
3. Register in src/runtime/detect.ts adapter map
4. Add tests in tests/unit/runtime/{name}.test.ts

## How To Add a Skill

1. Create skills/{name}/SKILL.md with YAML frontmatter
2. Follow the frontmatter spec (name, version, description, role, owns)
3. Add references/ directory if the skill needs detailed material
4. Keep body under 500 lines

## How To Modify the Data Model

1. Create new migration: src/data/dolt/migrations/NNN-description.sql
2. Number sequentially (e.g., 006-new-table.sql)
3. Update src/core/types.ts with corresponding TypeScript types
4. Run: bun run src/index.ts doctor --fix
```

---

## 8. Dev Environment Setup

### Prerequisites

```bash
# Bun (>= 1.1)
curl -fsSL https://bun.sh/install | bash
bun --version

# Dolt (>= 1.0)
# macOS:
brew install dolt
# Linux:
sudo bash -c 'curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash'
dolt version

# Verify both
bun --version  # expect >= 1.1.0
dolt version   # expect >= 1.0.0
```

### First Run

```bash
# Clone and install
git clone <repo-url> platform
cd platform
bun install

# Initialize Dolt database
mkdir -p .platform/dolt-data
cd .platform/dolt-data
dolt init
dolt sql-server --port 3307 &
cd ../..

# Run migrations
bun run src/index.ts doctor --fix

# Verify
bun run typecheck
bun run lint
bun test

# Start development
bun run dev    # watch mode
# or
bun run src/index.ts --help
```

### .gitignore

```gitignore
# Dependencies
node_modules/

# Build output
dist/

# Platform runtime data
.platform/
config.local.yaml

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
```

### .gitattributes

```gitattributes
# Merge strategies for state files
config.yaml merge=union
formulas/*.toml merge=union

# Binary files
*.png binary
*.jpg binary
*.ico binary

# Lock files
bun.lockb binary
```

---

## 9. CI/CD Setup

### .github/workflows/ci.yml

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest
      - run: bun install
      - run: bun run typecheck

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest
      - run: bun install
      - run: bun run lint

  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest
      - run: bun install
      - run: bun run test:unit

  integration-tests:
    runs-on: ubuntu-latest
    needs: [typecheck, lint, unit-tests]
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest

      # Install Dolt
      - name: Install Dolt
        run: |
          sudo bash -c 'curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash'
          dolt version

      - run: bun install

      # Initialize and start Dolt
      - name: Start Dolt Server
        run: |
          mkdir -p .platform/dolt-data
          cd .platform/dolt-data
          dolt init
          dolt sql-server --port 3307 &
          cd ../..
          sleep 3

      - run: bun run test:integration

  e2e-tests:
    runs-on: ubuntu-latest
    needs: [integration-tests]
    steps:
      - uses: actions/checkout@v4
      - uses: oven-sh/setup-bun@v2
        with:
          bun-version: latest

      - name: Install Dolt
        run: |
          sudo bash -c 'curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash'

      - run: bun install

      - name: Start Dolt Server
        run: |
          mkdir -p .platform/dolt-data
          cd .platform/dolt-data
          dolt init
          dolt sql-server --port 3307 &
          cd ../..
          sleep 3

      - run: bun run test:e2e
```

---

## 10. Contributing Guidelines

### Adding a New CLI Command

1. Create `src/cli/commands/{name}.ts`.
2. Export a `register{Name}Commands(parent: Command): void` function.
3. Import and register the function in `src/cli/index.ts` under the appropriate
   command group.
4. Every action handler must call `formatOutput(data, parent.parent)` to respect
   the `--json` flag.
5. Add unit tests in `tests/unit/cli/{name}.test.ts`.
6. Update the `platform {group} --help` output if the command group is new.

### Adding a New Runtime Adapter

1. Create `src/runtime/adapters/{name}.ts`.
2. Implement the `RuntimeAdapter` interface from `src/core/types.ts`. Required
   methods: `buildSpawnCommand`, `deployConfig`, `detectReady`,
   `parseTranscript`, `buildEnv`.
3. Add the adapter to the registry map in `src/runtime/detect.ts`.
4. Document runtime-specific environment variables in `.env.example`.
5. Add unit tests in `tests/unit/runtime/{name}.test.ts`. Test at minimum:
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

1. Create `src/data/dolt/migrations/{NNN}-{description}.sql`, numbered
   sequentially.
2. Write both the `CREATE/ALTER` statements and any required `CREATE INDEX`.
3. Update `src/core/types.ts` with corresponding TypeScript interfaces.
4. Run `bun run src/index.ts doctor --fix` to apply migrations.
5. Write a unit test that verifies the migration applies cleanly.
6. For SQLite schema changes, update the corresponding init function in
   `src/data/sqlite/{db}.ts`.

### Code Review Standards

- **Type safety:** No untyped `any` without a justifying comment.
- **Error handling:** All async operations must have error handling. Use typed
  error classes from `src/core/errors.ts`.
- **Testing:** Every new function needs at least one unit test. Integration
  tests required for database operations.
- **CLI consistency:** All commands support `--json`. Output formats are
  consistent across command groups.
- **Documentation:** Public functions have JSDoc. Non-obvious logic has inline
  comments explaining *why*, not *what*.

---

## 11. How ATSA Skills Integrate

### ATSA as the Skill/Prompt Layer

The existing AllTheSkillsAllTheAgents (ATSA) repository contains 17 skills
across 44 files. These skills serve as the initial Skill/Prompt Layer (Layer 1)
for the platform. The relationship is structural, not incidental:

**ATSA skills are the prompt templates that define agent behavior.** The
platform's orchestration, work, quality, and runtime layers execute agents; ATSA
skills define what those agents know and how they think. The platform loads ATSA
skills via the skill system module and injects them into agent sessions at spawn
time.

### Integration Mechanism

```
Platform boots
  --> Skill registry scans skills/**/SKILL.md
    --> Parses YAML frontmatter (Stage 1: metadata, ~100 tokens each)
    --> Builds indexes: by name, by role, by domain, ownership map
  --> Orchestrator requests agent spawn
    --> Dispatcher resolves skill for agent role + domain
    --> Loads full SKILL.md body (Stage 2: ~500 lines)
    --> Overlay generator injects project state (Stage 3: dynamic)
    --> Combined prompt deployed to agent worktree
  --> Agent reads references on demand (Stage 3: unlimited)
```

### Dogfooding: Building the Platform with Its Own Skills

The platform uses its own skills to build itself. This is the ultimate
validation of the skill system. The following mapping shows how platform skills
correspond to implementation work:

| Skill | Builds | Owns |
|-------|--------|------|
| `coordinator` | Project orchestration | config.yaml, formulas/ |
| `lead` | Team decomposition | N/A (coordination only) |
| `builder` (backend domain) | src/tracker/, src/data/, src/merge/ | Backend implementation |
| `builder` (infra domain) | src/runtime/, src/orchestration/ | Infrastructure implementation |
| `builder` (comms domain) | src/communication/ | Communication module |
| `reviewer` | Code review | Read-only |
| `scout` | Codebase exploration | Read-only |
| `merger` | Conflict resolution | Merge scope only |

### Progressive Disclosure in Practice

The token budget for skill loading during a platform build session:

```
Metadata for 6 skills x ~100 tokens     =    ~600 tokens
Active skill body (1 builder)            =  ~2,000 tokens
2 reference files loaded on demand       =  ~1,000 tokens
Dynamic overlay (project state)          =    ~500 tokens
                                           ────────────
Total skill overhead per agent            ~4,100 tokens  (< 2% of 200k)
```

This leaves over 98% of the context window for actual work -- code, errors,
git output, test results. The platform's skill loading adds negligible overhead.

### Skill-to-Platform Mapping

ATSA skills from the source repository map to platform concepts:

| ATSA Skill | Platform Equivalent | Notes |
|------------|-------------------|-------|
| orchestrator | Coordinator loop | ATSA's 14-phase playbook becomes the coordinator skill |
| backend-agent | Builder (backend domain) | File scope + cognitive patterns define the specialization |
| frontend-agent | Builder (frontend domain) | Same role, different domain config |
| qe-agent | Quality Auditor | QA report schema and gate logic carry over directly |
| contract-author | Contract system | Template-driven contract generation |
| contract-auditor | Contract auditor | Conformance checking against implementations |
| skill-writer | Meta skill | Generates new skills following the frontmatter spec |
| project-profiler | Profile system | Codebase analysis for project-specific adaptation |
| context-manager | Handoff protocol | Checkpoint-based context handoff at ~80% usage |

ATSA's existing skills are not discarded -- they are the starting point for the
platform's skill library. As the platform matures, skills evolve via the
template generation system (see `08-skill-system.md` section 5), but the core
anatomy -- YAML frontmatter, markdown body, reference directory -- remains
identical.
