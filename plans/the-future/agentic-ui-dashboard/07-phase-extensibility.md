# Phase 7 — Extensibility

**Version:** 0.1.0-draft
**Date:** 2026-03-20
**Status:** Design
**Duration:** 2 weeks
**Dependencies:** Phase 4 (Approval + Quality Gates)
**Deliverables:** 8 plugin slots with defaults, reactions engine, framework adapters

---

## 1. Scope Overview

Phase 7 transforms the dashboard from a monolithic application into an extensible platform. Three subsystems are built:

1. **Plugin Architecture** — 8 swappable interface slots (Runtime, Agent, Workspace, Tracker, SCM, Notifier, Dashboard, Observability) with registry resolution, lifecycle management, and YAML-driven configuration.
2. **Reactions System** — YAML-declarative event automation that watches for CI failures, QA gate rejections, contract mismatches, and other build events, then dispatches corrective actions with retry tracking and human escalation.
3. **Framework Adapters** — Normalized interface layer that lets the dashboard control agents exposed as CLI processes, REST APIs, or native Claude Code instances through a single unified contract.

All three subsystems are designed around Composio AO's proven patterns (84.6% CI self-correction rate, 8-slot plugin architecture validated in production).

---

## 2. Plugin Architecture

### 2.1 Plugin Slot Summary

| Slot | Interface | Default | Alternatives | Purpose |
|------|-----------|---------|-------------|---------|
| Runtime | `RuntimePlugin` | tmux | docker, k8s, process, worktree | Process isolation strategy |
| Agent | `AgentPlugin` | claude-code | codex, aider, gemini-cli, opencode | Agent binary and protocol |
| Workspace | `WorkspacePlugin` | git-worktree | clone, container | File isolation strategy |
| Tracker | `TrackerPlugin` | github-issues | linear, jira | Task tracking integration |
| SCM | `SCMPlugin` | github | gitlab, bitbucket | Source control integration |
| Notifier | `NotifierPlugin` | desktop | slack, discord, webhook | Alert delivery channel |
| Dashboard | `DashboardPlugin` | tauri-web | web-only, terminal-only | UI deployment target |
| Observability | `ObservabilityPlugin` | langfuse | jaeger, datadog, console | Trace collection backend |

### 2.2 Plugin Lifecycle

Every plugin goes through a 5-stage lifecycle:

```
  INITIALIZE ──> VALIDATE ──> ACTIVATE ──> DEACTIVATE ──> DISPOSE
  Load class     Schema chk    Start svc    Pause svc      Cleanup
  Parse cfg      Dep check     Open conn    Flush buffer   Close conn
  Create inst    Health chk    Register     Unregister     Free mem
       |              |                          |
       | PluginError  | ValidationError          |
       v              v                          v
  [Fall to default]  [Fall to default]     [ACTIVATE next]
```

- **Initialize:** Constructor called with parsed config. Plugin sets up internal state but does not open connections or start services.
- **Validate:** Schema validation on config, dependency resolution (e.g., SCM plugin checks that `git` is available), and a health check probe (e.g., can we reach the GitHub API?).
- **Activate:** Plugin starts its service -- opens connections, registers event listeners, marks itself ready. The plugin registry flips its state to `active`.
- **Deactivate:** Plugin pauses its service -- flushes buffers, unregisters listeners, but retains state for potential reactivation. Used during hot-reload.
- **Dispose:** Full teardown -- closes connections, frees memory, removes all references. Used during shutdown or plugin removal.

### 2.3 Core Plugin Interface

All 8 plugin slots extend a shared base interface:

```typescript
// src/plugins/types.ts

/** Base interface every plugin must implement */
interface Plugin {
  /** Unique identifier for this plugin implementation */
  readonly id: string;

  /** Human-readable name for UI display */
  readonly displayName: string;

  /** Semantic version of this plugin */
  readonly version: string;

  /** Which slot this plugin fills */
  readonly slot: PluginSlot;

  /** Current lifecycle state */
  state: PluginState;

  /** Initialize with parsed configuration */
  initialize(config: PluginConfig): Promise<void>;

  /** Validate configuration and dependencies */
  validate(): Promise<ValidationResult>;

  /** Activate the plugin (start services, open connections) */
  activate(): Promise<void>;

  /** Deactivate without full teardown (for hot-reload) */
  deactivate(): Promise<void>;

  /** Full teardown and cleanup */
  dispose(): Promise<void>;

  /** Health check -- called periodically after activation */
  healthCheck(): Promise<HealthStatus>;
}

type PluginSlot =
  | 'runtime'
  | 'agent'
  | 'workspace'
  | 'tracker'
  | 'scm'
  | 'notifier'
  | 'dashboard'
  | 'observability';

type PluginState =
  | 'uninitialized'
  | 'initialized'
  | 'validated'
  | 'active'
  | 'deactivated'
  | 'disposed'
  | 'error';

interface PluginConfig {
  [key: string]: unknown;
}

interface ValidationResult {
  valid: boolean;
  errors: ValidationError[];
  warnings: ValidationWarning[];
}

interface ValidationError {
  field: string;
  message: string;
  code: string;
}

interface ValidationWarning {
  field: string;
  message: string;
}

interface HealthStatus {
  healthy: boolean;
  latencyMs: number;
  details?: Record<string, unknown>;
}
```

### 2.4 Slot-Specific Interfaces

#### RuntimePlugin

Controls how agent processes are isolated and managed.

```typescript
interface RuntimePlugin extends Plugin {
  readonly slot: 'runtime';

  /** Create an isolated environment for an agent */
  createEnvironment(agentId: string, config: EnvironmentConfig): Promise<Environment>;

  /** Destroy an environment and all its processes */
  destroyEnvironment(envId: string): Promise<void>;

  /** Run a command inside an environment (safe: uses execFile, not shell) */
  execInEnvironment(envId: string, command: string, args: string[]): Promise<ExecResult>;

  /** Attach to the stdout/stderr stream of a running process */
  attach(envId: string, processId: string): AsyncIterable<ProcessOutput>;

  /** List all active environments */
  listEnvironments(): Promise<Environment[]>;

  /** Get resource usage for an environment */
  getResourceUsage(envId: string): Promise<ResourceUsage>;
}

interface Environment {
  id: string;
  agentId: string;
  status: 'creating' | 'running' | 'stopped' | 'error';
  createdAt: Date;
  metadata: Record<string, unknown>;
}

interface EnvironmentConfig {
  workingDir: string;
  env: Record<string, string>;
  resourceLimits?: {
    memoryMB?: number;
    cpuPercent?: number;
    timeoutMs?: number;
  };
}

interface ExecResult {
  exitCode: number;
  stdout: string;
  stderr: string;
  durationMs: number;
}

interface ProcessOutput {
  stream: 'stdout' | 'stderr';
  data: string;
  timestamp: number;
}

interface ResourceUsage {
  memoryMB: number;
  cpuPercent: number;
  diskMB: number;
  processCount: number;
}
```

#### AgentPlugin

Controls how agent binaries are invoked and how their output is interpreted.

```typescript
interface AgentPlugin extends Plugin {
  readonly slot: 'agent';

  /** Spawn an agent process with a task prompt */
  spawn(config: AgentSpawnConfig): Promise<AgentHandle>;

  /** Send a message or instruction to a running agent */
  sendMessage(agentId: string, message: string): Promise<void>;

  /** Inject context into a running agent (for reactions) */
  injectContext(agentId: string, context: AgentContext): Promise<void>;

  /** Request the agent to stop gracefully */
  stop(agentId: string): Promise<void>;

  /** Force-kill the agent process */
  kill(agentId: string): Promise<void>;

  /** Subscribe to structured events from the agent */
  subscribe(agentId: string): AsyncIterable<AgentEvent>;

  /** Parse raw agent output into structured events */
  parseOutput(raw: string): AgentEvent | null;

  /** Get supported capabilities of this agent type */
  getCapabilities(): AgentCapabilities;
}

interface AgentSpawnConfig {
  agentId: string;
  role: string;
  taskPrompt: string;
  workingDir: string;
  env: Record<string, string>;
  /** Additional CLI flags for the agent binary */
  flags?: string[];
  /** Maximum execution time before timeout reaction fires */
  timeoutMs?: number;
}

interface AgentHandle {
  agentId: string;
  pid: number;
  status: 'spawning' | 'running' | 'completed' | 'failed';
  startedAt: Date;
}

interface AgentContext {
  /** Context type determines how it is injected */
  type: 'ci-logs' | 'review-comments' | 'qa-report' | 'error-trace' | 'custom';
  content: string;
  metadata?: Record<string, unknown>;
}

interface AgentEvent {
  type: 'output' | 'tool-call' | 'tool-result' | 'status-change' | 'error' | 'completed';
  agentId: string;
  timestamp: number;
  payload: unknown;
}

interface AgentCapabilities {
  supportsStreaming: boolean;
  supportsInterrupts: boolean;
  supportsContextInjection: boolean;
  supportsToolCalls: boolean;
  maxConcurrentTasks: number;
}
```

#### WorkspacePlugin

Controls how file systems are isolated per agent.

```typescript
interface WorkspacePlugin extends Plugin {
  readonly slot: 'workspace';

  /** Create an isolated workspace for an agent */
  create(config: WorkspaceConfig): Promise<Workspace>;

  /** Destroy a workspace and clean up files */
  destroy(workspaceId: string): Promise<void>;

  /** Get the absolute path to the workspace root */
  getPath(workspaceId: string): string;

  /** List files modified in this workspace (relative to base) */
  getModifiedFiles(workspaceId: string): Promise<FileChange[]>;

  /** Get a diff between workspace and base */
  getDiff(workspaceId: string): Promise<string>;

  /** Merge workspace changes back to the base branch */
  merge(workspaceId: string, strategy: MergeStrategy): Promise<MergeResult>;

  /** List all active workspaces */
  listWorkspaces(): Promise<Workspace[]>;
}

interface WorkspaceConfig {
  agentId: string;
  baseBranch: string;
  branchName: string;
  repoPath: string;
}

interface Workspace {
  id: string;
  agentId: string;
  path: string;
  branchName: string;
  status: 'creating' | 'ready' | 'merging' | 'merged' | 'error';
  createdAt: Date;
}

interface FileChange {
  path: string;
  status: 'added' | 'modified' | 'deleted' | 'renamed';
  additions: number;
  deletions: number;
}

type MergeStrategy = 'merge' | 'squash' | 'rebase';

interface MergeResult {
  success: boolean;
  commitSha?: string;
  conflicts?: string[];
}
```

#### TrackerPlugin

Integrates with external task/issue tracking systems.

```typescript
interface TrackerPlugin extends Plugin {
  readonly slot: 'tracker';

  /** Create a task/issue for an agent assignment */
  createTask(task: CreateTaskRequest): Promise<TrackerTask>;

  /** Update task status */
  updateTask(taskId: string, update: TaskUpdate): Promise<TrackerTask>;

  /** Get task details */
  getTask(taskId: string): Promise<TrackerTask>;

  /** List tasks for a build */
  listTasks(buildId: string): Promise<TrackerTask[]>;

  /** Add a comment to a task */
  addComment(taskId: string, comment: string): Promise<void>;

  /** Link a PR to a task */
  linkPR(taskId: string, prUrl: string): Promise<void>;
}

interface CreateTaskRequest {
  title: string;
  description: string;
  buildId: string;
  agentRole: string;
  labels?: string[];
  assignee?: string;
}

interface TrackerTask {
  id: string;
  externalId: string;        // GitHub issue number, Linear ID, etc.
  externalUrl: string;
  title: string;
  status: 'open' | 'in-progress' | 'review' | 'done' | 'closed';
  buildId: string;
  agentRole: string;
}

interface TaskUpdate {
  status?: string;
  title?: string;
  labels?: string[];
  assignee?: string;
}
```

#### SCMPlugin

Integrates with source control management platforms.

```typescript
interface SCMPlugin extends Plugin {
  readonly slot: 'scm';

  /** Create a pull request */
  createPR(config: CreatePRRequest): Promise<PullRequest>;

  /** Update a pull request */
  updatePR(prId: string, update: PRUpdate): Promise<PullRequest>;

  /** Get PR status (reviews, checks, mergeable) */
  getPRStatus(prId: string): Promise<PRStatus>;

  /** Merge a pull request */
  mergePR(prId: string, strategy: MergeStrategy): Promise<MergeResult>;

  /** Get CI check status for a commit/PR */
  getCheckStatus(ref: string): Promise<CheckStatus>;

  /** Subscribe to PR events (review, check, comment) */
  subscribeToPR(prId: string): AsyncIterable<PREvent>;

  /** Post a review comment on a PR */
  postReviewComment(prId: string, comment: ReviewComment): Promise<void>;
}

interface CreatePRRequest {
  title: string;
  body: string;
  head: string;          // Source branch
  base: string;          // Target branch
  labels?: string[];
  reviewers?: string[];
  draft?: boolean;
}

interface PullRequest {
  id: string;
  number: number;
  url: string;
  title: string;
  status: 'open' | 'closed' | 'merged';
  head: string;
  base: string;
  checksStatus: 'pending' | 'passing' | 'failing' | 'unknown';
  reviewStatus: 'pending' | 'approved' | 'changes-requested';
}

interface PRStatus {
  mergeable: boolean;
  checks: CheckRun[];
  reviews: Review[];
  conflicts: boolean;
}

interface CheckRun {
  name: string;
  status: 'queued' | 'in_progress' | 'completed';
  conclusion?: 'success' | 'failure' | 'neutral' | 'cancelled' | 'timed_out';
}

interface Review {
  author: string;
  state: 'approved' | 'changes_requested' | 'commented' | 'pending';
  submittedAt: Date;
}

interface PREvent {
  type: 'review-submitted' | 'check-completed' | 'comment-added' | 'merged' | 'closed';
  timestamp: Date;
  payload: unknown;
}

interface ReviewComment {
  body: string;
  path?: string;
  line?: number;
  side?: 'LEFT' | 'RIGHT';
}

interface CheckStatus {
  overall: 'pending' | 'passing' | 'failing';
  checks: CheckRun[];
}
```

#### NotifierPlugin

Delivers alerts and notifications through various channels.

```typescript
interface NotifierPlugin extends Plugin {
  readonly slot: 'notifier';

  /** Send a notification */
  send(notification: Notification): Promise<NotificationResult>;

  /** Send a batch of notifications */
  sendBatch(notifications: Notification[]): Promise<NotificationResult[]>;

  /** Test the notification channel (used during validation) */
  testConnection(): Promise<boolean>;

  /** Get delivery status for a sent notification */
  getDeliveryStatus(notificationId: string): Promise<DeliveryStatus>;
}

interface Notification {
  id?: string;
  severity: 'info' | 'warning' | 'error' | 'critical';
  title: string;
  body: string;
  /** Structured data for rich notifications (Slack blocks, etc.) */
  richContent?: Record<string, unknown>;
  /** URL to link back to the dashboard */
  actionUrl?: string;
  /** Tags for filtering/routing */
  tags?: string[];
}

interface NotificationResult {
  id: string;
  delivered: boolean;
  channel: string;
  error?: string;
}

type DeliveryStatus = 'pending' | 'delivered' | 'failed' | 'unknown';
```

#### DashboardPlugin

Controls how the UI is deployed and served.

```typescript
interface DashboardPlugin extends Plugin {
  readonly slot: 'dashboard';

  /** Start the dashboard server/application */
  start(config: DashboardConfig): Promise<void>;

  /** Stop the dashboard */
  stop(): Promise<void>;

  /** Get the URL where the dashboard is accessible */
  getUrl(): string;

  /** Check if the dashboard is running */
  isRunning(): boolean;

  /** Open the dashboard in the user's environment */
  open(): Promise<void>;
}

interface DashboardConfig {
  port: number;
  host: string;
  /** Enable HTTPS with auto-generated certs */
  https?: boolean;
  /** Path to static assets */
  staticDir?: string;
}
```

#### ObservabilityPlugin

Controls where traces and metrics are exported.

```typescript
interface ObservabilityPlugin extends Plugin {
  readonly slot: 'observability';

  /** Start a trace for a build */
  startTrace(config: TraceConfig): Promise<TraceHandle>;

  /** Create a span within a trace */
  startSpan(traceId: string, config: SpanConfig): Promise<SpanHandle>;

  /** End a span */
  endSpan(spanId: string, result?: SpanResult): Promise<void>;

  /** End a trace */
  endTrace(traceId: string, result?: TraceResult): Promise<void>;

  /** Record a metric data point */
  recordMetric(metric: MetricPoint): Promise<void>;

  /** Flush all buffered data */
  flush(): Promise<void>;

  /** Get a URL to view a trace in the observability UI */
  getTraceUrl(traceId: string): string | null;
}

interface TraceConfig {
  traceId: string;
  name: string;
  buildId: string;
  metadata?: Record<string, unknown>;
}

interface TraceHandle {
  traceId: string;
  startedAt: Date;
}

interface SpanConfig {
  spanId?: string;
  name: string;
  parentSpanId?: string;
  agentId?: string;
  agentRole?: string;
  attributes?: Record<string, unknown>;
}

interface SpanHandle {
  spanId: string;
  traceId: string;
  startedAt: Date;
}

interface SpanResult {
  status: 'ok' | 'error';
  attributes?: Record<string, unknown>;
  error?: string;
}

interface TraceResult {
  status: 'success' | 'failure' | 'cancelled';
  durationMs: number;
  metadata?: Record<string, unknown>;
}

interface MetricPoint {
  name: string;
  value: number;
  unit: string;
  tags: Record<string, string>;
  timestamp?: number;
}
```

### 2.5 Plugin Registry Implementation

The registry is the central lookup table that maps slot names to active plugin instances. It handles resolution order, fallback logic, and lifecycle orchestration.

```typescript
// src/plugins/registry.ts

interface PluginEntry {
  plugin: Plugin;
  config: Record<string, unknown>;
  loadedFrom: 'yaml' | 'env' | 'auto-detect' | 'default';
}

class PluginRegistry {
  private plugins: Map<PluginSlot, PluginEntry> = new Map();
  private defaults: Map<PluginSlot, () => Plugin> = new Map();
  private eventListeners: Map<string, Set<(...args: any[]) => void>> = new Map();

  constructor() {
    // Register default plugin factories
    this.defaults.set('runtime', () => new TmuxRuntimePlugin());
    this.defaults.set('agent', () => new ClaudeCodeAgentPlugin());
    this.defaults.set('workspace', () => new GitWorktreeWorkspacePlugin());
    this.defaults.set('tracker', () => new GithubIssuesTrackerPlugin());
    this.defaults.set('scm', () => new GithubSCMPlugin());
    this.defaults.set('notifier', () => new DesktopNotifierPlugin());
    this.defaults.set('dashboard', () => new TauriWebDashboardPlugin());
    this.defaults.set('observability', () => new LangfuseObservabilityPlugin());
  }

  /**
   * Resolve a plugin for a slot using the 4-step resolution order:
   * 1. Config YAML (explicit user choice)
   * 2. Environment variables (PLUGIN_RUNTIME=docker, etc.)
   * 3. Auto-detection (detect available tools on PATH)
   * 4. Default (hardcoded fallback)
   */
  async resolve(
    slot: PluginSlot,
    yamlConfig?: PluginYAMLConfig,
    env?: Record<string, string>
  ): Promise<Plugin> {
    // Step 1: YAML config
    if (yamlConfig?.plugins?.[slot]) {
      const pluginName = yamlConfig.plugins[slot].name;
      const pluginConfig = yamlConfig.plugins[slot].config ?? {};
      const plugin = this.loadPluginByName(slot, pluginName);
      await this.initializeAndValidate(slot, plugin, pluginConfig, 'yaml');
      return plugin;
    }

    // Step 2: Environment variable
    const envKey = `PLUGIN_${slot.toUpperCase()}`;
    const envValue = env?.[envKey] ?? process.env[envKey];
    if (envValue) {
      const plugin = this.loadPluginByName(slot, envValue);
      await this.initializeAndValidate(slot, plugin, {}, 'env');
      return plugin;
    }

    // Step 3: Auto-detection
    const detected = await this.autoDetect(slot);
    if (detected) {
      await this.initializeAndValidate(slot, detected, {}, 'auto-detect');
      return detected;
    }

    // Step 4: Default
    const factory = this.defaults.get(slot);
    if (!factory) {
      throw new PluginResolutionError(
        slot,
        'No default plugin registered for this slot'
      );
    }
    const defaultPlugin = factory();
    await this.initializeAndValidate(slot, defaultPlugin, {}, 'default');
    return defaultPlugin;
  }

  private async initializeAndValidate(
    slot: PluginSlot,
    plugin: Plugin,
    config: Record<string, unknown>,
    source: PluginEntry['loadedFrom']
  ): Promise<void> {
    // Initialize
    try {
      await plugin.initialize(config);
    } catch (error) {
      this.emit('plugin:init-failed', { slot, plugin: plugin.id, error });
      throw new PluginInitError(slot, plugin.id, error);
    }

    // Validate
    const validation = await plugin.validate();
    if (!validation.valid) {
      this.emit('plugin:validation-failed', {
        slot,
        plugin: plugin.id,
        errors: validation.errors,
      });
      throw new PluginValidationError(slot, plugin.id, validation.errors);
    }

    if (validation.warnings.length > 0) {
      this.emit('plugin:validation-warnings', {
        slot,
        plugin: plugin.id,
        warnings: validation.warnings,
      });
    }

    // Register
    this.plugins.set(slot, { plugin, config, loadedFrom: source });
    this.emit('plugin:registered', { slot, plugin: plugin.id, source });
  }

  /** Activate all registered plugins in dependency order */
  async activateAll(): Promise<void> {
    const activationOrder: PluginSlot[] = [
      'runtime',        // Must be first -- other plugins may need environments
      'workspace',      // Depends on runtime
      'scm',            // Independent
      'tracker',        // Independent
      'observability',  // Should be early to capture traces
      'agent',          // Depends on runtime + workspace
      'notifier',       // Independent
      'dashboard',      // Last -- presents all other plugins
    ];

    for (const slot of activationOrder) {
      const entry = this.plugins.get(slot);
      if (!entry) continue;

      try {
        await entry.plugin.activate();
        entry.plugin.state = 'active';
        this.emit('plugin:activated', { slot, plugin: entry.plugin.id });
      } catch (error) {
        this.emit('plugin:activation-failed', {
          slot,
          plugin: entry.plugin.id,
          error,
        });

        // Fall back to default if non-default plugin fails to activate
        if (entry.loadedFrom !== 'default') {
          console.warn(
            `Plugin ${entry.plugin.id} failed to activate for slot ${slot}. ` +
            `Falling back to default.`
          );
          const factory = this.defaults.get(slot);
          if (factory) {
            const fallback = factory();
            await this.initializeAndValidate(slot, fallback, {}, 'default');
            await fallback.activate();
            fallback.state = 'active';
          }
        } else {
          throw new PluginActivationError(slot, entry.plugin.id, error);
        }
      }
    }
  }

  /** Get the active plugin for a slot */
  get<T extends Plugin>(slot: PluginSlot): T {
    const entry = this.plugins.get(slot);
    if (!entry || entry.plugin.state !== 'active') {
      throw new PluginNotActiveError(slot);
    }
    return entry.plugin as T;
  }

  /** Hot-reload: swap a plugin without full restart */
  async hotSwap(
    slot: PluginSlot,
    newPlugin: Plugin,
    config: Record<string, unknown>
  ): Promise<void> {
    const current = this.plugins.get(slot);

    // Deactivate current plugin
    if (current && current.plugin.state === 'active') {
      await current.plugin.deactivate();
      this.emit('plugin:deactivated', { slot, plugin: current.plugin.id });
    }

    // Initialize, validate, and activate new plugin
    await this.initializeAndValidate(slot, newPlugin, config, 'yaml');
    await newPlugin.activate();
    newPlugin.state = 'active';

    // Dispose old plugin
    if (current) {
      await current.plugin.dispose();
      this.emit('plugin:disposed', { slot, plugin: current.plugin.id });
    }

    this.emit('plugin:hot-swapped', {
      slot,
      from: current?.plugin.id,
      to: newPlugin.id,
    });
  }

  /** Dispose all plugins (shutdown) */
  async disposeAll(): Promise<void> {
    // Dispose in reverse activation order
    const slots: PluginSlot[] = [
      'dashboard', 'notifier', 'agent', 'observability',
      'tracker', 'scm', 'workspace', 'runtime',
    ];

    for (const slot of slots) {
      const entry = this.plugins.get(slot);
      if (entry) {
        try {
          if (entry.plugin.state === 'active') {
            await entry.plugin.deactivate();
          }
          await entry.plugin.dispose();
        } catch (error) {
          console.error(
            `Error disposing plugin ${entry.plugin.id} for slot ${slot}:`,
            error
          );
        }
      }
    }

    this.plugins.clear();
  }

  /** Get status of all plugin slots */
  getStatus(): PluginRegistryStatus {
    const slots: Record<string, PluginSlotStatus> = {};
    for (const slot of this.plugins.keys()) {
      const entry = this.plugins.get(slot)!;
      slots[slot] = {
        pluginId: entry.plugin.id,
        displayName: entry.plugin.displayName,
        version: entry.plugin.version,
        state: entry.plugin.state,
        loadedFrom: entry.loadedFrom,
      };
    }
    return { slots, activeCount: this.plugins.size };
  }

  private loadPluginByName(slot: PluginSlot, name: string): Plugin {
    const knownPlugins: Record<string, Record<string, () => Plugin>> = {
      runtime: {
        tmux: () => new TmuxRuntimePlugin(),
        docker: () => new DockerRuntimePlugin(),
        k8s: () => new K8sRuntimePlugin(),
        process: () => new ProcessRuntimePlugin(),
        worktree: () => new WorktreeRuntimePlugin(),
      },
      agent: {
        'claude-code': () => new ClaudeCodeAgentPlugin(),
        codex: () => new CodexAgentPlugin(),
        aider: () => new AiderAgentPlugin(),
        'gemini-cli': () => new GeminiCLIAgentPlugin(),
        opencode: () => new OpencodeAgentPlugin(),
      },
      workspace: {
        'git-worktree': () => new GitWorktreeWorkspacePlugin(),
        clone: () => new CloneWorkspacePlugin(),
        container: () => new ContainerWorkspacePlugin(),
      },
      tracker: {
        'github-issues': () => new GithubIssuesTrackerPlugin(),
        linear: () => new LinearTrackerPlugin(),
        jira: () => new JiraTrackerPlugin(),
      },
      scm: {
        github: () => new GithubSCMPlugin(),
        gitlab: () => new GitlabSCMPlugin(),
        bitbucket: () => new BitbucketSCMPlugin(),
      },
      notifier: {
        desktop: () => new DesktopNotifierPlugin(),
        slack: () => new SlackNotifierPlugin(),
        discord: () => new DiscordNotifierPlugin(),
        webhook: () => new WebhookNotifierPlugin(),
      },
      dashboard: {
        'tauri-web': () => new TauriWebDashboardPlugin(),
        'web-only': () => new WebOnlyDashboardPlugin(),
        'terminal-only': () => new TerminalOnlyDashboardPlugin(),
      },
      observability: {
        langfuse: () => new LangfuseObservabilityPlugin(),
        jaeger: () => new JaegerObservabilityPlugin(),
        datadog: () => new DatadogObservabilityPlugin(),
        console: () => new ConsoleObservabilityPlugin(),
      },
    };

    const factory = knownPlugins[slot]?.[name];
    if (!factory) {
      throw new PluginResolutionError(
        slot,
        `Unknown plugin "${name}" for slot "${slot}". ` +
        `Known plugins: ${Object.keys(knownPlugins[slot] ?? {}).join(', ')}`
      );
    }
    return factory();
  }

  private async autoDetect(slot: PluginSlot): Promise<Plugin | null> {
    const detectors: Record<PluginSlot, () => Promise<Plugin | null>> = {
      runtime: async () => {
        if (await commandExists('tmux')) return new TmuxRuntimePlugin();
        if (await commandExists('docker')) return new DockerRuntimePlugin();
        return new ProcessRuntimePlugin();
      },
      agent: async () => {
        if (await commandExists('claude')) return new ClaudeCodeAgentPlugin();
        if (await commandExists('codex')) return new CodexAgentPlugin();
        if (await commandExists('aider')) return new AiderAgentPlugin();
        return null;
      },
      workspace: async () => {
        if (await commandExists('git')) return new GitWorktreeWorkspacePlugin();
        return null;
      },
      scm: async () => {
        if (await commandExists('gh')) return new GithubSCMPlugin();
        if (await commandExists('glab')) return new GitlabSCMPlugin();
        return null;
      },
      tracker: async () => {
        if (await commandExists('gh')) return new GithubIssuesTrackerPlugin();
        return null;
      },
      notifier: async () => {
        return new DesktopNotifierPlugin();
      },
      dashboard: async () => {
        return new TauriWebDashboardPlugin();
      },
      observability: async () => {
        if (process.env.LANGFUSE_PUBLIC_KEY) {
          return new LangfuseObservabilityPlugin();
        }
        return new ConsoleObservabilityPlugin();
      },
    };

    const detector = detectors[slot];
    return detector ? detector() : null;
  }

  private emit(event: string, data: unknown): void {
    this.eventListeners.get(event)?.forEach((listener) => listener(data));
  }

  on(event: string, listener: (...args: any[]) => void): void {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, new Set());
    }
    this.eventListeners.get(event)!.add(listener);
  }
}

interface PluginRegistryStatus {
  slots: Record<string, PluginSlotStatus>;
  activeCount: number;
}

interface PluginSlotStatus {
  pluginId: string;
  displayName: string;
  version: string;
  state: PluginState;
  loadedFrom: 'yaml' | 'env' | 'auto-detect' | 'default';
}
```

### 2.6 Custom Error Types

```typescript
// src/plugins/errors.ts

class PluginResolutionError extends Error {
  constructor(public slot: PluginSlot, message: string) {
    super(`Plugin resolution failed for slot "${slot}": ${message}`);
  }
}

class PluginInitError extends Error {
  constructor(
    public slot: PluginSlot,
    public pluginId: string,
    public cause: unknown
  ) {
    super(`Plugin "${pluginId}" failed to initialize for slot "${slot}"`);
  }
}

class PluginValidationError extends Error {
  constructor(
    public slot: PluginSlot,
    public pluginId: string,
    public errors: ValidationError[]
  ) {
    super(
      `Plugin "${pluginId}" failed validation for slot "${slot}": ` +
      errors.map((e) => `${e.field}: ${e.message}`).join('; ')
    );
  }
}

class PluginActivationError extends Error {
  constructor(
    public slot: PluginSlot,
    public pluginId: string,
    public cause: unknown
  ) {
    super(`Plugin "${pluginId}" failed to activate for slot "${slot}"`);
  }
}

class PluginNotActiveError extends Error {
  constructor(public slot: PluginSlot) {
    super(`No active plugin for slot "${slot}"`);
  }
}
```

### 2.7 YAML Configuration Schema

Plugins and their configuration are specified in the project's `orchestrator.yaml`:

```yaml
# orchestrator.yaml -- plugin configuration section

plugins:
  runtime:
    name: tmux
    config:
      sessionPrefix: "agent-"
      defaultShell: /bin/zsh

  agent:
    name: claude-code
    config:
      binary: claude
      model: opus
      maxTokens: 200000
      flags:
        - "--dangerously-skip-permissions"

  workspace:
    name: git-worktree
    config:
      baseDir: .worktrees
      cleanupOnComplete: true

  tracker:
    name: github-issues
    config:
      repo: owner/repo
      labelPrefix: "agent:"

  scm:
    name: github
    config:
      repo: owner/repo
      defaultBase: main
      autoLabel: true

  notifier:
    name: desktop
    config:
      sound: true
      criticalOnly: false

  dashboard:
    name: tauri-web
    config:
      port: 3100
      host: localhost

  observability:
    name: langfuse
    config:
      publicKey: ${LANGFUSE_PUBLIC_KEY}
      secretKey: ${LANGFUSE_SECRET_KEY}
      baseUrl: https://cloud.langfuse.com
      flushIntervalMs: 2000
```

**YAML validation schema (JSON Schema format) for CI/startup validation:**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "plugins": {
      "type": "object",
      "properties": {
        "runtime": { "$ref": "#/definitions/pluginEntry" },
        "agent": { "$ref": "#/definitions/pluginEntry" },
        "workspace": { "$ref": "#/definitions/pluginEntry" },
        "tracker": { "$ref": "#/definitions/pluginEntry" },
        "scm": { "$ref": "#/definitions/pluginEntry" },
        "notifier": { "$ref": "#/definitions/pluginEntry" },
        "dashboard": { "$ref": "#/definitions/pluginEntry" },
        "observability": { "$ref": "#/definitions/pluginEntry" }
      },
      "additionalProperties": false
    }
  },
  "definitions": {
    "pluginEntry": {
      "type": "object",
      "required": ["name"],
      "properties": {
        "name": { "type": "string" },
        "config": { "type": "object" }
      }
    }
  }
}
```

### 2.8 Error Handling and Fallback Strategy

When a plugin fails at any lifecycle stage, the system follows a deterministic fallback path:

| Failure Point | Behavior | User-Visible Effect |
|---------------|----------|-------------------|
| **Initialize** | Log error, attempt default plugin for same slot | Warning toast: "Plugin X failed to load, using default" |
| **Validate** | Log validation errors, attempt default | Warning toast with specific validation failures |
| **Activate** | Log error, attempt default | Warning toast, dashboard continues with reduced capability |
| **Health check** (periodic) | Mark plugin as degraded, emit event | Yellow indicator on plugin status panel |
| **Health check** (3 consecutive failures) | Deactivate, attempt default | Orange toast: "Plugin X degraded, switching to default" |
| **Runtime method call** | Catch error, retry once, then escalate | Error toast with retry option |
| **Default plugin fails** | Fatal -- dashboard enters degraded mode | Red banner: "Critical plugin failure for slot X" |

If the default plugin itself fails to activate, the slot enters a `degraded` state where all method calls return safe fallback values (empty arrays, no-op promises). This prevents cascading failures from taking down the entire dashboard.

### 2.9 Hot-Reload Behavior

Plugins can be swapped at runtime without a full restart:

1. User changes `orchestrator.yaml` (or uses the plugin configuration UI).
2. File watcher detects the change and re-parses the affected slot configuration.
3. Registry calls `hotSwap(slot, newPlugin, newConfig)`.
4. Current plugin is deactivated (flushes buffers, pauses services).
5. New plugin is initialized, validated, and activated.
6. Old plugin is disposed.
7. All block components that consume the swapped slot receive updated references through Jotai atoms.

**Limitations:** Hot-reload works for stateless or soft-stateful plugins (notifier, tracker, observability). For stateful plugins (runtime, workspace), hot-reload may lose in-flight agent state. The UI displays a confirmation dialog: "Swapping the runtime plugin will terminate all running agents. Continue?"

---

## 3. Reactions System

### 3.1 Event Types

The reactions engine listens for these events emitted by the orchestrator:

| Event | Source | Payload | Default Action |
|-------|--------|---------|---------------|
| `ci-failed` | SCM plugin (check status) | CI logs, failing checks, commit SHA | `send-to-agent` |
| `qa-gate-failed` | QA gate evaluator | QA report with scores, failing criteria | `fix-and-revalidate` |
| `contract-mismatch` | Contract auditor | Diff of expected vs actual endpoints | `notify-orchestrator` |
| `changes-requested` | SCM plugin (PR review) | Review comments, reviewer name | `send-to-agent` |
| `approved-and-green` | SCM plugin (PR status) | PR URL, approver, all checks passing | `auto-merge` |
| `agent-crashed` | Process manager | Exit code, last 100 lines of output, stack trace | `retry` |
| `timeout` | Process manager | Agent ID, elapsed time, timeout threshold | `notify-orchestrator` |

### 3.2 Reaction Actions

| Action | Description | Implementation |
|--------|-------------|---------------|
| `send-to-agent` | Inject event context into the agent's running prompt via `AgentPlugin.injectContext()` | Formats CI logs/review comments as context, sends to agent |
| `fix-and-revalidate` | Agent fixes the issue, then QE agent re-runs validation | Chains: `send-to-agent` -> wait for agent completion -> trigger QE re-run |
| `notify-orchestrator` | Alert human via the active `NotifierPlugin` | Desktop/Slack/Discord notification with deep link to dashboard |
| `auto-merge` | Merge the PR automatically via `SCMPlugin.mergePR()` | Checks: all reviews approved + all checks passing + no conflicts |
| `retry` | Restart agent from last checkpoint or clean state | Kills crashed process, re-spawns with same config + error context |
| `escalate` | Move to human review queue (approval-queue block) | Creates an approval entry with the event context and all retry history |

### 3.3 YAML Configuration

```yaml
# orchestrator.yaml -- reactions configuration section

reactions:
  ci-failed:
    auto: true
    action: send-to-agent
    retries: 2
    escalateAfter: 2         # Escalate after 2 failed retries
    cooldown: 30s             # Min 30 seconds between triggers for same agent
    condition: null           # No additional condition

  qa-gate-failed:
    auto: true
    action: fix-and-revalidate
    retries: 3
    escalateAfter: 3
    cooldown: 60s
    condition: "scores.contract_conformance >= 1"  # Only auto-fix if not catastrophic

  contract-mismatch:
    auto: false               # Always human decision
    action: notify-orchestrator
    retries: 0
    escalateAfter: 0          # Immediate escalation
    cooldown: 0s

  changes-requested:
    auto: true
    action: send-to-agent
    retries: 2
    escalateAfter: 30m        # Time-based escalation (30 minutes)
    cooldown: 60s

  approved-and-green:
    auto: true
    action: auto-merge
    retries: 1                # Retry once if merge fails (rebase conflict)
    escalateAfter: 1
    cooldown: 0s

  agent-crashed:
    auto: true
    action: retry
    retries: 2
    escalateAfter: 2
    cooldown: 10s             # Quick retry for crashes
    condition: "exitCode != 137"  # Don't retry OOM kills (SIGKILL)

  timeout:
    auto: false
    action: notify-orchestrator
    retries: 0
    escalateAfter: 0
    cooldown: 0s
```

**YAML validation schema for reactions:**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "reactions": {
      "type": "object",
      "patternProperties": {
        "^[a-z][a-z0-9-]*$": {
          "type": "object",
          "required": ["auto", "action"],
          "properties": {
            "auto": { "type": "boolean" },
            "action": {
              "type": "string",
              "enum": [
                "send-to-agent",
                "fix-and-revalidate",
                "notify-orchestrator",
                "auto-merge",
                "retry",
                "escalate"
              ]
            },
            "retries": { "type": "integer", "minimum": 0, "default": 0 },
            "escalateAfter": {
              "oneOf": [
                { "type": "integer", "minimum": 0 },
                { "type": "string", "pattern": "^\\d+[smh]$" }
              ]
            },
            "cooldown": {
              "type": "string",
              "pattern": "^\\d+[smh]?$",
              "default": "0s"
            },
            "condition": { "type": ["string", "null"], "default": null }
          }
        }
      }
    }
  }
}
```

### 3.4 Reaction Engine Implementation

```typescript
// src/reactions/engine.ts

interface ReactionConfig {
  auto: boolean;
  action: ReactionAction;
  retries: number;
  escalateAfter: number | string;   // Count or duration string
  cooldown: string;                  // Duration string: "30s", "5m", "1h"
  condition: string | null;
}

type ReactionAction =
  | 'send-to-agent'
  | 'fix-and-revalidate'
  | 'notify-orchestrator'
  | 'auto-merge'
  | 'retry'
  | 'escalate';

interface ReactionEvent {
  type: string;
  agentId: string;
  buildId: string;
  timestamp: Date;
  payload: Record<string, unknown>;
}

interface RetryTracker {
  eventType: string;
  agentId: string;
  retryCount: number;
  firstTriggeredAt: Date;
  lastTriggeredAt: Date;
  history: ReactionAttempt[];
}

interface ReactionAttempt {
  attemptNumber: number;
  action: ReactionAction;
  triggeredAt: Date;
  completedAt: Date | null;
  result: 'success' | 'failure' | 'pending';
  error?: string;
}

class ReactionEngine {
  private configs: Map<string, ReactionConfig> = new Map();
  private retryTrackers: Map<string, RetryTracker> = new Map();
  private cooldowns: Map<string, Date> = new Map();
  private pluginRegistry: PluginRegistry;
  private db: Database;

  constructor(pluginRegistry: PluginRegistry, db: Database) {
    this.pluginRegistry = pluginRegistry;
    this.db = db;
  }

  /** Load reaction configurations from YAML */
  loadConfig(reactionsYaml: Record<string, ReactionConfig>): void {
    this.configs.clear();
    for (const [eventType, config] of Object.entries(reactionsYaml)) {
      this.configs.set(eventType, config);
    }
  }

  /** Process an incoming event through the reaction pipeline */
  async handleEvent(event: ReactionEvent): Promise<void> {
    const config = this.configs.get(event.type);
    if (!config) return; // No reaction configured -- ignore

    // Gate 1: Is auto-handling enabled?
    if (!config.auto) {
      await this.escalate(event, config, 'Manual reaction -- auto disabled');
      return;
    }

    // Gate 2: Is cooldown active?
    const cooldownKey = `${event.type}:${event.agentId}`;
    const cooldownUntil = this.cooldowns.get(cooldownKey);
    if (cooldownUntil && new Date() < cooldownUntil) {
      return; // Silently skip -- cooldown active
    }

    // Gate 3: Does the condition pass?
    if (config.condition) {
      const conditionMet = ConditionEvaluator.evaluate(
        config.condition, event.payload
      );
      if (!conditionMet) {
        await this.escalate(
          event, config, `Condition not met: ${config.condition}`
        );
        return;
      }
    }

    // Get or create retry tracker
    const trackerKey = `${event.type}:${event.agentId}:${event.buildId}`;
    let tracker = this.retryTrackers.get(trackerKey);
    if (!tracker) {
      tracker = {
        eventType: event.type,
        agentId: event.agentId,
        retryCount: 0,
        firstTriggeredAt: new Date(),
        lastTriggeredAt: new Date(),
        history: [],
      };
      this.retryTrackers.set(trackerKey, tracker);
    }

    // Gate 4: Have we exceeded the retry/time limit?
    const escalateThreshold = this.parseEscalateAfter(config.escalateAfter);
    if (typeof escalateThreshold === 'number') {
      if (tracker.retryCount >= escalateThreshold) {
        await this.escalate(
          event, config, `Exceeded ${escalateThreshold} retries`
        );
        return;
      }
    } else {
      const elapsed = Date.now() - tracker.firstTriggeredAt.getTime();
      if (elapsed > escalateThreshold.ms) {
        await this.escalate(
          event, config, `Exceeded time limit: ${config.escalateAfter}`
        );
        return;
      }
    }

    // Execute the reaction action
    const attempt: ReactionAttempt = {
      attemptNumber: tracker.retryCount + 1,
      action: config.action,
      triggeredAt: new Date(),
      completedAt: null,
      result: 'pending',
    };
    tracker.history.push(attempt);
    tracker.retryCount++;
    tracker.lastTriggeredAt = new Date();

    try {
      await this.dispatchAction(config.action, event, tracker);
      attempt.result = 'success';
      attempt.completedAt = new Date();
    } catch (error) {
      attempt.result = 'failure';
      attempt.completedAt = new Date();
      attempt.error = error instanceof Error ? error.message : String(error);

      if (typeof escalateThreshold === 'number'
          && tracker.retryCount >= escalateThreshold) {
        await this.escalate(
          event, config,
          `Action failed after ${tracker.retryCount} attempts`
        );
      }
    }

    // Set cooldown
    const cooldownMs = this.parseDuration(config.cooldown);
    if (cooldownMs > 0) {
      this.cooldowns.set(cooldownKey, new Date(Date.now() + cooldownMs));
    }

    // Persist reaction attempt to SQLite for audit trail
    await this.persistAttempt(event, attempt, tracker);
  }

  /** Dispatch a reaction action to the appropriate plugin */
  private async dispatchAction(
    action: ReactionAction,
    event: ReactionEvent,
    tracker: RetryTracker
  ): Promise<void> {
    switch (action) {
      case 'send-to-agent': {
        const agentPlugin = this.pluginRegistry.get<AgentPlugin>('agent');
        const context: AgentContext = {
          type: this.mapEventToContextType(event.type),
          content: this.formatContextForAgent(event),
          metadata: {
            retryCount: tracker.retryCount,
            eventType: event.type,
            buildId: event.buildId,
          },
        };
        await agentPlugin.injectContext(event.agentId, context);
        break;
      }

      case 'fix-and-revalidate': {
        // Step 1: Send context to agent
        await this.dispatchAction('send-to-agent', event, tracker);

        // Step 2: Wait for agent to complete the fix (poll with timeout)
        await this.waitForAgentCompletion(event.agentId, 300_000); // 5m

        // Step 3: Trigger QE re-validation via internal event
        this.emit('reaction:revalidate-requested', {
          agentId: event.agentId,
          buildId: event.buildId,
          triggeredBy: `reaction:${event.type}`,
        });
        break;
      }

      case 'notify-orchestrator': {
        const notifier = this.pluginRegistry.get<NotifierPlugin>('notifier');
        await notifier.send({
          severity: event.type === 'agent-crashed' ? 'critical' : 'warning',
          title: `Reaction: ${event.type}`,
          body: this.formatNotificationBody(event, tracker),
          actionUrl: `/dashboard/agent/${event.agentId}`,
          tags: [event.type, event.agentId],
        });
        break;
      }

      case 'auto-merge': {
        const scm = this.pluginRegistry.get<SCMPlugin>('scm');
        const prId = event.payload.prId as string;
        if (!prId) throw new Error('auto-merge requires prId in event payload');

        const status = await scm.getPRStatus(prId);
        if (!status.mergeable) {
          throw new Error(
            `PR ${prId} is not mergeable: conflicts=${status.conflicts}`
          );
        }

        await scm.mergePR(prId, 'squash');
        break;
      }

      case 'retry': {
        const agentPlugin = this.pluginRegistry.get<AgentPlugin>('agent');

        // Kill the crashed process (may already be dead)
        try { await agentPlugin.kill(event.agentId); } catch { /* noop */ }

        // Re-spawn with same config + error context
        const originalConfig = event.payload.spawnConfig as AgentSpawnConfig;
        if (!originalConfig) {
          throw new Error('retry requires spawnConfig in event payload');
        }

        const handle = await agentPlugin.spawn(originalConfig);
        await agentPlugin.injectContext(handle.agentId, {
          type: 'error-trace',
          content: this.formatErrorContext(event),
          metadata: { retryCount: tracker.retryCount },
        });
        break;
      }

      case 'escalate': {
        await this.escalate(
          event, this.configs.get(event.type)!, 'Explicit escalation action'
        );
        break;
      }
    }
  }

  /** Escalate an event to the human review queue */
  private async escalate(
    event: ReactionEvent,
    config: ReactionConfig,
    reason: string
  ): Promise<void> {
    const tracker = this.retryTrackers.get(
      `${event.type}:${event.agentId}:${event.buildId}`
    );

    await this.db.run(
      `INSERT INTO approvals
         (id, build_id, agent_id, gate_type, status, payload, created_at)
       VALUES (?, ?, ?, ?, 'pending', ?, datetime('now'))`,
      [
        generateId(),
        event.buildId,
        event.agentId,
        `reaction:${event.type}`,
        JSON.stringify({
          event,
          reason,
          retryHistory: tracker?.history ?? [],
          config,
        }),
      ]
    );

    const notifier = this.pluginRegistry.get<NotifierPlugin>('notifier');
    await notifier.send({
      severity: 'critical',
      title: `Escalation: ${event.type} for ${event.agentId}`,
      body: `${reason}. Retry history: ${tracker?.retryCount ?? 0} attempts. `
          + `Requires human decision.`,
      actionUrl: `/dashboard/approvals`,
      tags: ['escalation', event.type, event.agentId],
    });

    this.emit('reaction:escalated', { event, reason, tracker });
  }

  private parseEscalateAfter(
    value: number | string
  ): number | { ms: number } {
    if (typeof value === 'number') return value;
    return { ms: this.parseDuration(value) };
  }

  private parseDuration(duration: string): number {
    const match = duration.match(/^(\d+)(s|m|h)?$/);
    if (!match) return 0;
    const num = parseInt(match[1], 10);
    const unit = match[2] ?? 's';
    switch (unit) {
      case 's': return num * 1000;
      case 'm': return num * 60_000;
      case 'h': return num * 3_600_000;
      default:  return num * 1000;
    }
  }

  private mapEventToContextType(
    eventType: string
  ): AgentContext['type'] {
    const mapping: Record<string, AgentContext['type']> = {
      'ci-failed': 'ci-logs',
      'qa-gate-failed': 'qa-report',
      'changes-requested': 'review-comments',
      'agent-crashed': 'error-trace',
    };
    return mapping[eventType] ?? 'custom';
  }

  private formatContextForAgent(event: ReactionEvent): string {
    return [
      `--- AUTOMATED REACTION: ${event.type} ---`,
      `Agent: ${event.agentId}`,
      `Build: ${event.buildId}`,
      `Time: ${event.timestamp.toISOString()}`,
      ``,
      `Details:`,
      JSON.stringify(event.payload, null, 2),
      ``,
      `Please fix the issue described above and verify your changes.`,
      `--- END REACTION CONTEXT ---`,
    ].join('\n');
  }

  private formatNotificationBody(
    event: ReactionEvent,
    tracker: RetryTracker
  ): string {
    return [
      `Event: ${event.type}`,
      `Agent: ${event.agentId}`,
      `Build: ${event.buildId}`,
      `Retry count: ${tracker.retryCount}`,
      `First triggered: ${tracker.firstTriggeredAt.toISOString()}`,
    ].join('\n');
  }

  private formatErrorContext(event: ReactionEvent): string {
    const lastOutput = (event.payload.lastOutput as string[]) ?? [];
    return [
      `The previous execution failed with exit code ${event.payload.exitCode}.`,
      ``,
      `Last 100 lines of output:`,
      ...lastOutput.slice(-100),
      ``,
      `Please investigate and fix the root cause.`,
    ].join('\n');
  }

  private async waitForAgentCompletion(
    agentId: string,
    timeoutMs: number
  ): Promise<void> {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
      const row = await this.db.get(
        'SELECT status FROM agents WHERE id = ?',
        [agentId]
      );
      const status = row?.status ?? 'unknown';
      if (status === 'completed' || status === 'failed') return;
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }
    throw new Error(
      `Agent ${agentId} did not complete within ${timeoutMs}ms`
    );
  }

  private async persistAttempt(
    event: ReactionEvent,
    attempt: ReactionAttempt,
    tracker: RetryTracker
  ): Promise<void> {
    await this.db.run(
      `INSERT INTO event_log
         (build_id, agent_id, event_type, payload, timestamp)
       VALUES (?, ?, ?, ?, datetime('now'))`,
      [
        event.buildId,
        event.agentId,
        `reaction:${event.type}:attempt`,
        JSON.stringify({
          attempt,
          totalRetries: tracker.retryCount,
          eventPayload: event.payload,
        }),
      ]
    );
  }

  // Internal event emitter
  private listeners: Map<string, Set<(...args: any[]) => void>> = new Map();

  private emit(event: string, data: unknown): void {
    this.listeners.get(event)?.forEach((fn) => fn(data));
  }

  on(event: string, fn: (...args: any[]) => void): void {
    if (!this.listeners.has(event)) this.listeners.set(event, new Set());
    this.listeners.get(event)!.add(fn);
  }
}
```

### 3.5 Condition Evaluator

The condition evaluator provides a safe, restricted expression language for reaction conditions. It does NOT use arbitrary code evaluation. Instead, it parses a limited grammar of comparison expressions.

```typescript
// src/reactions/condition-evaluator.ts

/**
 * Safe condition evaluator. Supports:
 *   - Property access: "field" or "nested.field"
 *   - Comparisons: ==, !=, >, <, >=, <=
 *   - Literals: numbers, strings (quoted), booleans, null
 *   - Logical: &&, ||
 *
 * Does NOT support: function calls, assignment, imports, prototype
 * access, array indexing, or any other arbitrary code execution.
 */
class ConditionEvaluator {
  static evaluate(
    condition: string,
    payload: Record<string, unknown>
  ): boolean {
    // Split on logical operators, evaluate each sub-expression
    if (condition.includes('&&')) {
      return condition.split('&&')
        .map(c => c.trim())
        .every(c => ConditionEvaluator.evaluate(c, payload));
    }
    if (condition.includes('||')) {
      return condition.split('||')
        .map(c => c.trim())
        .some(c => ConditionEvaluator.evaluate(c, payload));
    }

    // Parse single comparison: "field operator value"
    const match = condition.match(
      /^([\w.]+)\s*(==|!=|>=|<=|>|<)\s*(.+)$/
    );
    if (!match) {
      console.warn(`Cannot parse condition: ${condition}`);
      return false;
    }

    const [, fieldPath, operator, rawValue] = match;
    const actualValue = ConditionEvaluator.resolveField(
      fieldPath, payload
    );
    const expectedValue = ConditionEvaluator.parseLiteral(rawValue.trim());

    switch (operator) {
      case '==': return actualValue === expectedValue;
      case '!=': return actualValue !== expectedValue;
      case '>':  return (actualValue as number) > (expectedValue as number);
      case '<':  return (actualValue as number) < (expectedValue as number);
      case '>=': return (actualValue as number) >= (expectedValue as number);
      case '<=': return (actualValue as number) <= (expectedValue as number);
      default:   return false;
    }
  }

  private static resolveField(
    path: string,
    obj: Record<string, unknown>
  ): unknown {
    return path.split('.').reduce<unknown>(
      (current, key) => {
        if (current && typeof current === 'object') {
          return (current as Record<string, unknown>)[key];
        }
        return undefined;
      },
      obj
    );
  }

  private static parseLiteral(value: string): unknown {
    if (value === 'true') return true;
    if (value === 'false') return false;
    if (value === 'null') return null;
    if (/^".*"$/.test(value) || /^'.*'$/.test(value)) {
      return value.slice(1, -1);
    }
    const num = Number(value);
    if (!isNaN(num)) return num;
    return value;
  }
}
```

### 3.6 Reaction Tracking Database

Reactions produce audit-trail entries in the existing `event_log` table (see master spec section 13). Additionally, a dedicated table tracks retry state across restarts:

```sql
-- Migration: 007_reaction_trackers.sql

CREATE TABLE reaction_trackers (
    id TEXT PRIMARY KEY,               -- "{eventType}:{agentId}:{buildId}"
    event_type TEXT NOT NULL,
    agent_id TEXT NOT NULL,
    build_id TEXT NOT NULL,
    retry_count INTEGER DEFAULT 0,
    first_triggered_at DATETIME NOT NULL,
    last_triggered_at DATETIME NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',  -- 'active', 'resolved', 'escalated'
    history TEXT NOT NULL DEFAULT '[]',     -- JSON array of ReactionAttempt
    resolved_at DATETIME,
    resolved_by TEXT                        -- 'auto' or user_id
);

CREATE INDEX idx_reaction_tracker_build ON reaction_trackers(build_id);
CREATE INDEX idx_reaction_tracker_status ON reaction_trackers(status);
CREATE INDEX idx_reaction_tracker_agent ON reaction_trackers(agent_id);
```

---

## 4. Framework Adapters

### 4.1 Overview

Framework adapters provide a normalized interface for discovering, registering, and controlling agents regardless of their underlying implementation. This follows Mission Control's pattern of abstracting away framework-specific details.

Three adapters are implemented in Phase 7:
1. **Claude Code Adapter** (default) -- manages Claude Code CLI processes
2. **Generic CLI Adapter** -- wraps any command-line agent (codex, aider, opencode)
3. **REST API Adapter** -- connects to agents exposed via HTTP endpoints

### 4.2 Framework Adapter Interface

```typescript
// src/adapters/framework-adapter.ts

interface AgentDefinition {
  id: string;
  name: string;
  framework: string;           // "claude-code", "generic-cli", "rest-api"
  capabilities: AgentCapabilities;
  metadata: Record<string, unknown>;
}

interface TaskAssignment {
  taskId: string;
  agentId: string;
  prompt: string;
  workingDir: string;
  env?: Record<string, string>;
  timeout?: number;
  metadata?: Record<string, unknown>;
}

type TaskStatus =
  | { state: 'queued' }
  | { state: 'running'; progress: number; currentStep: string }
  | { state: 'completed'; result: TaskResult }
  | { state: 'failed'; error: string; exitCode?: number }
  | { state: 'cancelled'; reason: string };

interface TaskResult {
  output: string;
  filesModified: string[];
  tokensUsed: number;
  durationMs: number;
  metadata?: Record<string, unknown>;
}

interface TaskEvent {
  type: 'output' | 'tool-call' | 'tool-result' | 'status' | 'error' | 'metric';
  taskId: string;
  agentId: string;
  timestamp: number;
  payload: unknown;
}

/** Base class for all framework adapters */
abstract class FrameworkAdapter {
  abstract readonly framework: string;

  /** Discover available agents for this framework */
  abstract discoverAgents(): Promise<AgentDefinition[]>;

  /** Register a new agent definition */
  abstract registerAgent(def: AgentDefinition): Promise<string>;

  /** Assign a task to an agent */
  abstract assignTask(
    agentId: string,
    task: TaskAssignment
  ): Promise<{ taskId: string }>;

  /** Get current task status */
  abstract getTaskStatus(taskId: string): Promise<TaskStatus>;

  /** Cancel a running task */
  abstract cancelTask(taskId: string): Promise<void>;

  /** Subscribe to real-time task events */
  abstract subscribeToTaskEvents(taskId: string): AsyncIterable<TaskEvent>;

  /** Normalize raw adapter events to AG-UI events */
  toAGUIEvent(event: TaskEvent): OrchestratorEvent {
    switch (event.type) {
      case 'output':
        return {
          type: 'TEXT_MESSAGE_CONTENT',
          agentId: event.agentId,
          agentRole: this.getAgentRole(event.agentId),
          phaseId: this.getCurrentPhase(),
          messageId: generateId(),
          content: event.payload as string,
        };
      case 'tool-call':
        return {
          type: 'TOOL_CALL_START',
          agentId: event.agentId,
          agentRole: this.getAgentRole(event.agentId),
          phaseId: this.getCurrentPhase(),
          toolCallId: (event.payload as any).toolCallId,
          toolCallName: (event.payload as any).name,
        };
      case 'status':
        return {
          type: 'STATE_DELTA',
          agentId: event.agentId,
          agentRole: this.getAgentRole(event.agentId),
          phaseId: this.getCurrentPhase(),
          delta: event.payload,
        };
      case 'error':
        return {
          type: 'RUN_FINISHED',
          agentId: event.agentId,
          agentRole: this.getAgentRole(event.agentId),
          phaseId: this.getCurrentPhase(),
          runId: event.taskId,
          outcome: 'error',
          error: { message: event.payload as string },
        };
      default:
        return {
          type: 'RAW',
          agentId: event.agentId,
          agentRole: this.getAgentRole(event.agentId),
          phaseId: this.getCurrentPhase(),
          payload: event.payload,
        };
    }
  }

  protected abstract getAgentRole(agentId: string): string;
  protected abstract getCurrentPhase(): number;
}
```

### 4.3 Claude Code Adapter

```typescript
// src/adapters/claude-code-adapter.ts

class ClaudeCodeAdapter extends FrameworkAdapter {
  readonly framework = 'claude-code';
  private processes: Map<string, ManagedClaudeProcess> = new Map();
  private agentRoles: Map<string, string> = new Map();
  private currentPhase: number = 0;

  async discoverAgents(): Promise<AgentDefinition[]> {
    const exists = await commandExists('claude');
    if (!exists) return [];

    return [{
      id: 'claude-code-default',
      name: 'Claude Code',
      framework: 'claude-code',
      capabilities: {
        supportsStreaming: true,
        supportsInterrupts: true,
        supportsContextInjection: true,
        supportsToolCalls: true,
        maxConcurrentTasks: 10,
      },
      metadata: {
        binary: 'claude',
        version: await this.getVersion(),
      },
    }];
  }

  async registerAgent(def: AgentDefinition): Promise<string> {
    const binary = (def.metadata?.binary as string) ?? 'claude';
    const exists = await commandExists(binary);
    if (!exists) throw new Error(`Claude Code CLI not found: ${binary}`);
    return def.id;
  }

  async assignTask(
    agentId: string,
    task: TaskAssignment
  ): Promise<{ taskId: string }> {
    const taskId = task.taskId ?? generateId();

    const args: string[] = [
      '--print',
      '--output-format', 'stream-json',
    ];

    // Use spawn (not shell) to avoid command injection
    const child = spawn('claude', [...args, task.prompt], {
      cwd: task.workingDir,
      env: { ...process.env, ...task.env },
    });

    const managed: ManagedClaudeProcess = {
      taskId,
      agentId,
      child,
      status: 'running',
      startedAt: new Date(),
      output: [],
      toolCalls: [],
    };

    this.processes.set(taskId, managed);
    this.agentRoles.set(
      agentId, (task.metadata?.role as string) ?? 'unknown'
    );

    if (task.timeout) {
      managed.timeoutHandle = setTimeout(() => {
        this.cancelTask(taskId);
      }, task.timeout);
    }

    return { taskId };
  }

  async getTaskStatus(taskId: string): Promise<TaskStatus> {
    const managed = this.processes.get(taskId);
    if (!managed) return { state: 'failed', error: 'Task not found' };

    if (managed.status === 'running') {
      return {
        state: 'running',
        progress: managed.progress ?? 0,
        currentStep: managed.currentStep ?? 'executing',
      };
    }

    if (managed.status === 'completed') {
      return {
        state: 'completed',
        result: {
          output: managed.output.join('\n'),
          filesModified: managed.filesModified ?? [],
          tokensUsed: managed.tokensUsed ?? 0,
          durationMs: Date.now() - managed.startedAt.getTime(),
        },
      };
    }

    return {
      state: 'failed',
      error: managed.error ?? 'Unknown error',
      exitCode: managed.exitCode,
    };
  }

  async cancelTask(taskId: string): Promise<void> {
    const managed = this.processes.get(taskId);
    if (!managed || managed.status !== 'running') return;

    managed.child.kill('SIGTERM');
    // Grace period then force kill
    setTimeout(() => {
      if (managed.status === 'running') {
        managed.child.kill('SIGKILL');
      }
    }, 5000);
  }

  async *subscribeToTaskEvents(taskId: string): AsyncIterable<TaskEvent> {
    const managed = this.processes.get(taskId);
    if (!managed) return;

    const { child, agentId } = managed;
    const rl = createInterface({ input: child.stdout! });

    for await (const line of rl) {
      try {
        const parsed = JSON.parse(line);

        if (parsed.type === 'assistant') {
          yield {
            type: 'output',
            taskId,
            agentId,
            timestamp: Date.now(),
            payload: parsed.content,
          };
        } else if (parsed.type === 'tool_use') {
          yield {
            type: 'tool-call',
            taskId,
            agentId,
            timestamp: Date.now(),
            payload: {
              toolCallId: parsed.id,
              name: parsed.name,
              args: parsed.input,
            },
          };
        } else if (parsed.type === 'tool_result') {
          yield {
            type: 'tool-result',
            taskId,
            agentId,
            timestamp: Date.now(),
            payload: {
              toolCallId: parsed.tool_use_id,
              result: parsed.content,
            },
          };
        }
      } catch {
        // Non-JSON line -- emit as raw output
        yield {
          type: 'output',
          taskId,
          agentId,
          timestamp: Date.now(),
          payload: line,
        };
      }
    }

    // Process exited
    const exitCode = await new Promise<number>((resolve) => {
      child.on('exit', (code) => resolve(code ?? 1));
    });

    managed.exitCode = exitCode;
    managed.status = exitCode === 0 ? 'completed' : 'failed';
    if (managed.timeoutHandle) clearTimeout(managed.timeoutHandle);

    yield {
      type: exitCode === 0 ? 'status' : 'error',
      taskId,
      agentId,
      timestamp: Date.now(),
      payload: exitCode === 0
        ? { state: 'completed' }
        : `Process exited with code ${exitCode}`,
    };
  }

  private async getVersion(): Promise<string> {
    try {
      const result = await execFileAsync('claude', ['--version']);
      return result.stdout.trim();
    } catch {
      return 'unknown';
    }
  }

  setCurrentPhase(phase: number): void { this.currentPhase = phase; }
  protected getAgentRole(agentId: string): string {
    return this.agentRoles.get(agentId) ?? 'unknown';
  }
  protected getCurrentPhase(): number { return this.currentPhase; }
}

interface ManagedClaudeProcess {
  taskId: string;
  agentId: string;
  child: ChildProcess;
  status: 'running' | 'completed' | 'failed';
  startedAt: Date;
  output: string[];
  toolCalls: unknown[];
  filesModified?: string[];
  tokensUsed?: number;
  progress?: number;
  currentStep?: string;
  exitCode?: number;
  error?: string;
  timeoutHandle?: ReturnType<typeof setTimeout>;
}
```

### 4.4 Generic CLI Adapter

```typescript
// src/adapters/generic-cli-adapter.ts

class GenericCLIAdapter extends FrameworkAdapter {
  readonly framework = 'generic-cli';

  constructor(private binaryConfig: CLIBinaryConfig) {
    super();
  }

  async discoverAgents(): Promise<AgentDefinition[]> {
    const exists = await commandExists(this.binaryConfig.binary);
    if (!exists) return [];

    return [{
      id: `cli-${this.binaryConfig.name}`,
      name: this.binaryConfig.name,
      framework: 'generic-cli',
      capabilities: {
        supportsStreaming: true,
        supportsInterrupts: false,
        supportsContextInjection:
          this.binaryConfig.supportsStdinInjection ?? false,
        supportsToolCalls: false,
        maxConcurrentTasks: this.binaryConfig.maxConcurrent ?? 5,
      },
      metadata: { binary: this.binaryConfig.binary },
    }];
  }

  async registerAgent(def: AgentDefinition): Promise<string> {
    return def.id;
  }

  async assignTask(
    agentId: string,
    task: TaskAssignment
  ): Promise<{ taskId: string }> {
    const taskId = task.taskId ?? generateId();
    const args = this.binaryConfig.buildArgs(task.prompt, task.workingDir);
    // Use spawn (not shell) with explicit binary + args
    spawn(this.binaryConfig.binary, args, {
      cwd: task.workingDir,
      env: { ...process.env, ...task.env },
    });
    return { taskId };
  }

  // Remaining methods follow same pattern as ClaudeCodeAdapter
  // but without structured JSON parsing -- all output is raw text

  async getTaskStatus(taskId: string): Promise<TaskStatus> {
    return { state: 'queued' }; // Stub -- implement with process tracking
  }

  async cancelTask(taskId: string): Promise<void> { /* kill process */ }

  async *subscribeToTaskEvents(taskId: string): AsyncIterable<TaskEvent> {
    // Yield raw stdout/stderr lines as output events
  }

  protected getAgentRole(agentId: string): string { return 'unknown'; }
  protected getCurrentPhase(): number { return 0; }
}

interface CLIBinaryConfig {
  name: string;
  binary: string;
  buildArgs: (prompt: string, cwd: string) => string[];
  supportsStdinInjection?: boolean;
  maxConcurrent?: number;
}
```

### 4.5 REST API Adapter

```typescript
// src/adapters/rest-api-adapter.ts

class RESTAPIAdapter extends FrameworkAdapter {
  readonly framework = 'rest-api';

  constructor(private baseUrl: string, private apiKey?: string) {
    super();
  }

  async discoverAgents(): Promise<AgentDefinition[]> {
    const response = await fetch(`${this.baseUrl}/agents`, {
      headers: this.getHeaders(),
    });
    if (!response.ok) return [];
    return response.json();
  }

  async registerAgent(def: AgentDefinition): Promise<string> {
    const response = await fetch(`${this.baseUrl}/agents`, {
      method: 'POST',
      headers: this.getHeaders(),
      body: JSON.stringify(def),
    });
    const result = await response.json();
    return result.id;
  }

  async assignTask(
    agentId: string,
    task: TaskAssignment
  ): Promise<{ taskId: string }> {
    const response = await fetch(
      `${this.baseUrl}/agents/${agentId}/tasks`,
      {
        method: 'POST',
        headers: this.getHeaders(),
        body: JSON.stringify(task),
      }
    );
    return response.json();
  }

  async getTaskStatus(taskId: string): Promise<TaskStatus> {
    const response = await fetch(`${this.baseUrl}/tasks/${taskId}`, {
      headers: this.getHeaders(),
    });
    return response.json();
  }

  async cancelTask(taskId: string): Promise<void> {
    await fetch(`${this.baseUrl}/tasks/${taskId}/cancel`, {
      method: 'POST',
      headers: this.getHeaders(),
    });
  }

  async *subscribeToTaskEvents(taskId: string): AsyncIterable<TaskEvent> {
    const url = `${this.baseUrl}/tasks/${taskId}/events`;
    const eventSource = new EventSource(url);
    const queue: TaskEvent[] = [];
    let resolve: (() => void) | null = null;
    let closed = false;

    eventSource.onmessage = (event) => {
      queue.push(JSON.parse(event.data));
      if (resolve) { resolve(); resolve = null; }
    };

    eventSource.onerror = () => {
      closed = true;
      eventSource.close();
      if (resolve) { resolve(); resolve = null; }
    };

    try {
      while (!closed || queue.length > 0) {
        if (queue.length > 0) {
          yield queue.shift()!;
        } else if (!closed) {
          await new Promise<void>((r) => { resolve = r; });
        }
      }
    } finally {
      eventSource.close();
    }
  }

  private getHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    if (this.apiKey) {
      headers['Authorization'] = `Bearer ${this.apiKey}`;
    }
    return headers;
  }

  protected getAgentRole(agentId: string): string { return 'unknown'; }
  protected getCurrentPhase(): number { return 0; }
}
```

---

## 5. Plugin Configuration UI

A new block type `plugin-config` is added to the block registry for Phase 7. This is accessible only to Admin-role users (RBAC check).

### 5.1 Plugin Status Panel

Displays the current state of all 8 plugin slots:

```
+-----------+--------------+---------+----------+---------+
| Slot      | Plugin       | Version | Status   | Source  |
+-----------+--------------+---------+----------+---------+
| Runtime   | tmux         | 1.0.0   | Active   | default |
| Agent     | claude-code  | 1.2.0   | Active   | yaml    |
| Workspace | git-worktree | 1.0.0   | Active   | auto    |
| Tracker   | github-issues| 1.1.0   | Active   | yaml    |
| SCM       | github       | 1.0.0   | Active   | env     |
| Notifier  | desktop      | 1.0.0   | Active   | default |
| Dashboard | tauri-web    | 1.0.0   | Active   | default |
| Observ.   | langfuse     | 1.0.0   | Degraded | yaml    |
+-----------+--------------+---------+----------+---------+
```

Each row is clickable and expands to show:
- Plugin health check result (latency, details)
- Configuration values (redacted secrets)
- "Swap Plugin" button (triggers hot-reload flow with confirmation)
- "Health Check" button (manual probe)

### 5.2 Reactions Status Panel

Displays active reaction trackers with retry counts and history:

```
+-------------+-------------+-------+----------+------------+
| Event       | Agent       | Tries | Status   | Action     |
+-------------+-------------+-------+----------+------------+
| ci-failed   | backend-01  | 1/2   | Retrying | send-agent |
| qa-gate     | frontend-01 | 3/3   | Escalated| fix+reval  |
| changes-req | security-01 | 1/2   | Waiting  | send-agent |
+-------------+-------------+-------+----------+------------+
```

---

## 6. Testing Strategy

### 6.1 Unit Tests

| Test Area | Count | Framework |
|-----------|-------|-----------|
| Plugin interface compliance (per slot) | 8x3 = 24 | Vitest |
| Plugin registry resolution (4 steps) | 12 | Vitest |
| Plugin lifecycle (5 stages per slot) | 40 | Vitest |
| Reaction engine (7 event types x 6 actions) | 42 | Vitest |
| Retry tracking and escalation | 15 | Vitest |
| Condition evaluation | 10 | Vitest |
| Framework adapter (3 adapters x 6 methods) | 18 | Vitest |
| YAML config parsing and validation | 10 | Vitest |
| **Total** | **~170** | |

### 6.2 Integration Tests

- **Plugin hot-swap:** Swap notifier from desktop to webhook while a build is running. Verify new notifications go to webhook.
- **Reaction chain:** Trigger `ci-failed` -> verify agent receives context -> agent "fixes" (mock) -> verify retry tracker updates -> exhaust retries -> verify escalation fires.
- **Framework adapter end-to-end:** Spawn a mock Claude Code process via adapter, stream events, verify AG-UI event conversion.
- **Plugin fallback:** Configure a non-existent plugin, verify system falls back to default with warning.

### 6.3 Mock Plugin for Testing

```typescript
// src/plugins/__tests__/mock-plugin.ts

class MockPlugin implements Plugin {
  readonly id = 'mock';
  readonly displayName = 'Mock Plugin';
  readonly version = '0.0.1';
  readonly slot: PluginSlot;
  state: PluginState = 'uninitialized';

  callLog: { method: string; args: unknown[] }[] = [];
  shouldFailOn: Set<string> = new Set();

  constructor(slot: PluginSlot) {
    this.slot = slot;
  }

  async initialize(config: PluginConfig): Promise<void> {
    this.log('initialize', config);
    if (this.shouldFailOn.has('initialize'))
      throw new Error('Mock init failure');
    this.state = 'initialized';
  }

  async validate(): Promise<ValidationResult> {
    this.log('validate');
    if (this.shouldFailOn.has('validate')) {
      return {
        valid: false,
        errors: [{
          field: 'mock',
          message: 'Mock validation failure',
          code: 'MOCK',
        }],
        warnings: [],
      };
    }
    this.state = 'validated';
    return { valid: true, errors: [], warnings: [] };
  }

  async activate(): Promise<void> {
    this.log('activate');
    if (this.shouldFailOn.has('activate'))
      throw new Error('Mock activation failure');
    this.state = 'active';
  }

  async deactivate(): Promise<void> {
    this.log('deactivate');
    this.state = 'deactivated';
  }

  async dispose(): Promise<void> {
    this.log('dispose');
    this.state = 'disposed';
  }

  async healthCheck(): Promise<HealthStatus> {
    this.log('healthCheck');
    return {
      healthy: !this.shouldFailOn.has('healthCheck'),
      latencyMs: 1,
    };
  }

  private log(method: string, ...args: unknown[]): void {
    this.callLog.push({ method, args });
  }
}
```

---

## 7. Acceptance Criteria

| # | Criterion | Verification Method |
|---|-----------|-------------------|
| AC-1 | All 8 plugin slots have working default implementations | Unit tests pass for all defaults |
| AC-2 | Plugins can be swapped via YAML config without code changes | Change YAML, restart, verify new plugin active |
| AC-3 | Plugin resolution follows 4-step order: YAML -> env -> auto-detect -> default | Unit test with mocked sources |
| AC-4 | Plugin validation catches misconfigured plugins at startup | Test with invalid config, verify error + fallback |
| AC-5 | Reactions engine triggers `send-to-agent` on `ci-failed` event | Integration test with mock CI failure |
| AC-6 | Agent receives CI logs via context injection and self-corrects | Integration test with mock agent |
| AC-7 | Retry tracker increments count and respects `retries` limit | Unit test: trigger event N+1 times, verify escalation |
| AC-8 | Escalation creates approval entry and sends notification | Integration test: exhaust retries, check approvals table + notification |
| AC-9 | Cooldown prevents duplicate reactions within configured window | Unit test: rapid-fire same event, verify single reaction |
| AC-10 | Condition evaluation gates reactions on payload values | Unit test: `exitCode != 137` blocks OOM retries |
| AC-11 | Claude Code framework adapter normalizes output to AG-UI events | Integration test with mock Claude output stream |
| AC-12 | Plugin hot-swap completes without dashboard restart | Integration test: swap notifier plugin, verify new plugin active |
| AC-13 | Plugin status panel shows all slots with correct state | E2E test: render plugin-config block, verify 8 rows |
| AC-14 | Reaction status panel shows active trackers with retry counts | E2E test: trigger reaction, verify panel updates |

---

## 8. Risk Register

| Risk | Severity | Probability | Mitigation |
|------|----------|------------|------------|
| Plugin hot-swap loses in-flight agent state | High | Medium | Confirmation dialog for stateful plugins (runtime, workspace). Deactivate flushes buffers before swap. |
| Condition evaluation allows code injection | High | Low | Sandboxed evaluator uses regex parsing, not eval/Function. Rejects any input containing parens, brackets, semicolons, or keyword patterns. |
| Reaction infinite loop (fix triggers new failure) | High | Medium | Cooldown timer + hard retry limit + circuit breaker: stop all reactions for an agent after 5 total failures in one build. |
| Plugin auto-detection picks wrong tool | Medium | Medium | Auto-detected plugins log a notice. Config YAML always overrides. |
| Generic CLI adapter cannot parse structured output | Medium | High | Fall back to raw text events. Agent capabilities flag `supportsToolCalls: false`. Dashboard degrades gracefully. |
| REST API adapter network failures | Medium | Medium | Exponential backoff on connection failures. Health check probes every 30s. Timeout at 10s per request. |
| YAML config drift between instances | Low | Low | Config hash stored in SQLite. Warn on mismatch at startup. |

---

## 9. Open Questions (Phase 7)

| # | Question | Impact | Decision Owner |
|---|----------|--------|---------------|
| Q3 (from master) | Should reactions engine live in Rust backend or TypeScript frontend? | Code organization, latency | Architect |
| Q7.1 | Should plugins be npm packages or built-in modules? | Distribution, updates | Architect |
| Q7.2 | Should the condition evaluator support a richer expression language (e.g., JSONPath, CEL)? | Flexibility vs. complexity | Architect |
| Q7.3 | Should reactions support chained actions (e.g., `send-to-agent` then `notify-orchestrator`)? | Configuration complexity | Product |
| Q7.4 | Should third-party plugins be supported (npm install, dynamic import)? | Security, ecosystem | Architect |

---

## 10. File Manifest

Files created or modified in Phase 7:

```
src/
  plugins/
    types.ts                          # Base Plugin interface, PluginSlot, PluginState
    registry.ts                       # PluginRegistry class
    errors.ts                         # Custom error types
    slots/
      runtime/
        runtime-plugin.ts             # RuntimePlugin interface
        tmux-runtime.ts               # Default: TmuxRuntimePlugin
        docker-runtime.ts             # DockerRuntimePlugin
        process-runtime.ts            # ProcessRuntimePlugin
      agent/
        agent-plugin.ts               # AgentPlugin interface
        claude-code-agent.ts          # Default: ClaudeCodeAgentPlugin
        generic-cli-agent.ts          # GenericCLIAgentPlugin
      workspace/
        workspace-plugin.ts           # WorkspacePlugin interface
        git-worktree-workspace.ts     # Default: GitWorktreeWorkspacePlugin
      tracker/
        tracker-plugin.ts             # TrackerPlugin interface
        github-issues-tracker.ts      # Default: GithubIssuesTrackerPlugin
      scm/
        scm-plugin.ts                 # SCMPlugin interface
        github-scm.ts                 # Default: GithubSCMPlugin
      notifier/
        notifier-plugin.ts            # NotifierPlugin interface
        desktop-notifier.ts           # Default: DesktopNotifierPlugin
        webhook-notifier.ts           # WebhookNotifierPlugin
      dashboard/
        dashboard-plugin.ts           # DashboardPlugin interface
        tauri-web-dashboard.ts        # Default: TauriWebDashboardPlugin
      observability/
        observability-plugin.ts       # ObservabilityPlugin interface
        langfuse-observability.ts     # Default: LangfuseObservabilityPlugin
        console-observability.ts      # ConsoleObservabilityPlugin
  reactions/
    engine.ts                         # ReactionEngine class
    types.ts                          # ReactionConfig, ReactionEvent, RetryTracker
    condition-evaluator.ts            # Sandboxed condition evaluation
  adapters/
    framework-adapter.ts              # Base FrameworkAdapter abstract class
    claude-code-adapter.ts            # ClaudeCodeAdapter
    generic-cli-adapter.ts            # GenericCLIAdapter
    rest-api-adapter.ts               # RESTAPIAdapter
  blocks/
    plugin-config/
      PluginConfigBlock.tsx           # Plugin status panel component
      ReactionStatusPanel.tsx         # Reaction tracker panel component
      atoms.ts                        # Jotai atoms for plugin config block

src-tauri/
  src/
    plugins/
      mod.rs                          # Rust plugin registry (mirrors TS for commands)
      yaml_loader.rs                  # YAML config parser

migrations/
  007_reaction_trackers.sql           # reaction_trackers table

tests/
  plugins/
    registry.test.ts                  # Plugin registry unit tests
    mock-plugin.ts                    # MockPlugin for testing
    resolution.test.ts                # 4-step resolution tests
    lifecycle.test.ts                 # 5-stage lifecycle tests
    hot-swap.test.ts                  # Hot-reload integration tests
  reactions/
    engine.test.ts                    # Reaction engine unit tests
    retry-tracking.test.ts            # Retry and escalation tests
    condition.test.ts                 # Condition evaluator tests
  adapters/
    claude-code-adapter.test.ts       # Claude Code adapter tests
    generic-cli-adapter.test.ts       # Generic CLI adapter tests
    rest-api-adapter.test.ts          # REST API adapter tests
```
