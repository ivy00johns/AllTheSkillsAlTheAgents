# 11 - Runtime Adapters: Multi-LLM Execution Specification

Clean-sheet specification for the runtime adapter system that enables any LLM coding
agent to participate in orchestrated builds. Synthesizes Overstory's 9-adapter
implementation, Gas Town's tmux session management, and ATSA's runtime degradation
model. This is the deep specification of Layer 5 (Runtime) from `03-system-architecture.md`.

---

## 1. Why Runtime Neutrality

### No Single LLM Is Best at Everything

The AI landscape is fragmenting, not consolidating. Each provider optimizes for
different strengths:

- **Claude** excels at complex reasoning, multi-step planning, and nuanced judgment.
  It is the strongest coordinator but also the most expensive.
- **Gemini** offers the largest context windows (1M+ tokens) and strong multi-modal
  understanding. It is ideal for codebase-wide analysis and document comprehension.
- **Pi** (Inflection) prioritizes speed and iteration velocity. It handles routine
  implementation faster and cheaper than frontier models.
- **Codex** (OpenAI) runs in a strict OS-level sandbox with deterministic tooling.
  It is the safest option for untrusted exploration and read-only tasks.
- **Open-source models** via OpenRouter provide cost flexibility and emerging
  capabilities at a fraction of frontier pricing.

A platform locked to one provider inherits that provider's weaknesses as hard
constraints. Runtime neutrality converts provider weaknesses into routing decisions.

### Cost Optimization Through Model Routing

The cost difference between models is 10-100x:

| Task | Optimal Model | Cost/MTok | Why |
|------|--------------|-----------|-----|
| Architectural decomposition | Claude Opus | $$$$ | Requires deep reasoning across entire codebase |
| Code review | Claude Sonnet | $$ | Good judgment at moderate cost |
| Routine implementation | Pi / Sonnet | $ - $$ | Speed matters more than depth |
| Read-only exploration | Haiku / Codex | $ | Cheap, sandboxed, disposable |
| Large context analysis | Gemini Pro | $$ | 1M+ context makes this feasible |
| Batch formatting | Haiku | $ | Mechanical tasks need cheap tokens |

Running every task on Opus wastes 90% of the budget. Running every task on Haiku
produces 90% failures. The right model for the right task is not optimization --
it is a structural requirement for viable multi-agent economics.

### Vendor Independence

Provider outages happen. Pricing changes happen. Capability regressions happen.
API deprecations happen. A platform that depends on a single vendor's API is
operationally fragile and strategically captive.

Runtime adapters provide:

- **Failover** -- when Claude API is down, builders can switch to Gemini or Pi
  without changing orchestration logic
- **Migration** -- when a new model outperforms the incumbent, swap the adapter
  without rewriting the platform
- **Negotiation** -- when costs increase, credibly threaten to shift workload
  to alternatives
- **Competition** -- route identical tasks to different runtimes and compare
  quality, speed, and cost empirically

### Future-Proofing

New LLM coding agents ship every quarter. The adapter interface means adding
support for a new runtime is 200-400 lines of mechanical implementation, not an
architectural change. The orchestration, quality, and work layers never know which
runtime is executing an agent -- they communicate through mail and observe through
the event store.

---

## 2. Adapter Interface

The contract every runtime adapter must implement. This interface is the boundary
between Layer 2 (Orchestration) and Layer 5 (Runtime). The orchestration layer
calls these methods; the adapter translates them into runtime-specific operations.

### Core Interface

```typescript
interface RuntimeAdapter {
  // ── Identity ──────────────────────────────────────────────────────
  readonly id: string;                    // "claude-code", "pi-cli", "codex-cli"
  readonly displayName: string;           // "Claude Code", "Pi CLI", "Codex CLI"
  readonly stability: "stable" | "beta" | "experimental";

  // ── Capabilities ──────────────────────────────────────────────────
  readonly capabilities: RuntimeCapabilities;

  // ── Spawning ──────────────────────────────────────────────────────
  buildSpawnCommand(opts: SpawnOpts): string;
  buildPrintCommand(prompt: string, model?: string): string[];
  buildDirectSpawn?(opts: DirectSpawnOpts): string[];  // headless only

  // ── Configuration Deployment ──────────────────────────────────────
  deployConfig(
    worktreePath: string,
    overlay: string,
    hooks: HookConfig
  ): Promise<void>;

  // ── Readiness Detection ───────────────────────────────────────────
  detectReady(paneContent: string): ReadyState;
  requiresBeaconVerification?(): boolean;

  // ── Transcript Parsing ────────────────────────────────────────────
  parseTranscript(path: string): Promise<TranscriptSummary | null>;
  getTranscriptDir(projectRoot: string): string | null;

  // ── Environment ───────────────────────────────────────────────────
  buildEnv(model: ResolvedModel): Record<string, string>;

  // ── RPC (optional, for direct-communication runtimes) ─────────────
  connect?(process: RpcProcessHandle): RuntimeConnection;

  // ── Event Streaming (optional, for headless runtimes) ─────────────
  headless?: boolean;
  parseEvents?(stream: ReadableStream): AsyncIterable<AgentEvent>;
}
```

### Capabilities Declaration

Every adapter declares its capabilities upfront. The orchestrator uses this
to validate role-runtime compatibility before spawning.

```typescript
interface RuntimeCapabilities {
  // ── Session Model ─────────────────────────────────────────────────
  supportsTmux: boolean;            // can run in tmux session
  supportsInteractive: boolean;     // requires terminal interaction
  supportsHeadless: boolean;        // can run without terminal

  // ── Communication ─────────────────────────────────────────────────
  supportsFollowUp: boolean;        // can receive messages mid-session
  supportsHooks: boolean;           // SessionStart/UserPromptSubmit hooks
  supportsRPC: boolean;             // JSON-RPC stdin/stdout protocol

  // ── Agent Features ────────────────────────────────────────────────
  supportsAgentTool: boolean;       // can spawn sub-agents natively
  supportsBrowser: boolean;         // has browser automation built in

  // ── Model Characteristics ─────────────────────────────────────────
  maxContextTokens: number;         // context window size
  costTier: "budget" | "standard" | "premium" | "frontier";

  // ── Syntax ────────────────────────────────────────────────────────
  quoteStyle: "single" | "double" | "heredoc";
  commentPrefix: string;            // '#' for bash-based, '//' for others
}
```

### Readiness Detection

Each runtime's TUI behaves differently during startup. The adapter must parse
raw tmux pane content and classify the current state:

```typescript
type ReadyState =
  | { phase: "loading" }                              // still initializing
  | { phase: "dialog"; action: "approve" | "dismiss" } // stuck on permission dialog
  | { phase: "ready" };                                // ready for initial prompt

interface SpawnOpts {
  model: ResolvedModel;
  agentName: string;
  flags?: string[];       // runtime-specific flags
}

interface DirectSpawnOpts extends SpawnOpts {
  prompt: string;         // initial prompt for headless execution
  timeout?: number;       // max execution time in ms
}
```

### RPC Connection (Direct Communication)

For runtimes that support RPC (currently Pi), the adapter provides a direct
communication channel that bypasses tmux entirely:

```typescript
interface RuntimeConnection {
  sendPrompt(text: string): Promise<void>;     // initial prompt delivery
  followUp(text: string): Promise<void>;       // mid-session message injection
  abort(): Promise<void>;                       // clean shutdown
  getState(): Promise<ConnectionState>;         // replaces tmux capture-pane
  close(): void;                                // release resources
}

type ConnectionState =
  | { status: "idle" }
  | { status: "processing"; elapsed: number }
  | { status: "completed"; result: string }
  | { status: "error"; message: string };
```

The connection registry tracks active RPC connections at the module level. When
`runtime.connect` exists, the orchestrator bypasses tmux for mail delivery,
nudges, shutdown, and health checks. RPC is the clean interface; tmux is the
compatibility layer.

### Model Resolution

The model router maps abstract capability names to concrete model identifiers
and provider credentials:

```typescript
interface ResolvedModel {
  model: string;                      // "opus", "sonnet", "openrouter/anthropic/claude-sonnet-4-6"
  env?: Record<string, string>;       // provider-specific env vars (API keys, base URLs)
  isExplicitOverride?: boolean;       // true if user specified --model flag
}
```

### Transcript Summary

Normalized cost tracking across runtimes:

```typescript
interface TranscriptSummary {
  sessionId: string;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  totalCostUsd: number;
  toolCalls: number;
  durationMs: number;
}
```

---

## 3. Supported Runtimes

### 3.1 Claude Code -- Primary / Coordinator-Class

**Stability:** Stable

The reference runtime. Claude Code is the most capable coding agent available,
with the deepest reasoning, the richest tool ecosystem, and the most mature
session management. It is the default for coordination roles and complex
implementation tasks.

| Property | Value |
|----------|-------|
| **Detection** | `which claude` or `claude --version` |
| **Session model** | tmux pane, interactive TUI |
| **Instruction file** | `.claude/CLAUDE.md` |
| **Guard mechanism** | `.claude/settings.local.json` with hooks and permissions |
| **Spawn command** | `claude --model <model> --dangerously-skip-permissions` |
| **Print command** | `claude --print --model <model>` |
| **Transcript location** | `~/.claude/projects/<path>/` (JSONL) |
| **Readiness signal** | Detects `>` prompt, permission dialogs, loading states |
| **Beacon verification** | YES -- Claude's TUI sometimes swallows Enter during late init |

**Capabilities:**

| Capability | Status |
|------------|--------|
| tmux | YES |
| followUp | YES (via tmux send-keys + UserPromptSubmit hook) |
| agentTool | YES (with worktree isolation modes) |
| interactive | YES |
| headless | NO |
| hooks | YES (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse) |
| browser | NO (via Browse CLI binary, not native) |
| RPC | NO |
| Context | 200k (Sonnet), 1M (Opus) |
| Cost tier | premium (Sonnet), frontier (Opus) |

**Config deployment:**

The adapter writes two files to the agent's worktree:

1. `.claude/CLAUDE.md` -- merged overlay with agent identity, task spec, file scope,
   quality gates, communication instructions, and pre-loaded expertise
2. `.claude/settings.local.json` -- hooks configuration:

```json
{
  "hooks": {
    "SessionStart": [{
      "command": "platform prime --agent builder-1"
    }],
    "UserPromptSubmit": [{
      "command": "platform mail check --agent builder-1 --inject"
    }]
  },
  "permissions": {
    "allow": ["Read", "Write", "Edit", "Glob", "Grep", "Bash(...)"]
  }
}
```

**Best roles:** Coordinator, Lead, Reviewer, Builder (complex tasks)

**Quirks:**
- Agent tool has isolation modes: `worktree` (full git worktree) vs `default`
  (shared directory). The platform always uses worktree isolation.
- Beacon verification is required because Claude's TUI sometimes fails to
  register the initial prompt if Enter is sent during late initialization. The
  adapter sends a known beacon string and verifies it appears in the output
  before sending the real prompt.
- The `--dangerously-skip-permissions` flag disables the interactive permission
  dialog. Without it, agents stall on every tool call awaiting approval.

---

### 3.2 Pi CLI -- Builder-Class, Fast Iteration

**Stability:** Beta

Pi is Inflection AI's coding CLI. Its standout feature is JSON-RPC 2.0
communication via stdin/stdout, which provides a clean programmatic interface
without tmux intermediation. This makes it the most orchestration-friendly
runtime after Claude Code.

| Property | Value |
|----------|-------|
| **Detection** | `which pi` or `pi --version` |
| **Session model** | Spawned process with JSON-RPC 2.0 stdin/stdout |
| **Instruction file** | `.claude/CLAUDE.md` (Pi reads Claude's config) |
| **Guard mechanism** | `.pi/extensions/overstory-guard.json` |
| **Spawn command** | `pi --mode chat --model <provider/model>` |
| **Print command** | `pi --mode print --model <model>` |
| **Readiness signal** | Indistinguishable idle/processing states via pane capture |
| **Beacon verification** | NO -- resending would spam duplicates |

**Capabilities:**

| Capability | Status |
|------------|--------|
| tmux | NO (uses RPC instead) |
| followUp | YES (via RPC `followUp()` method) |
| agentTool | NO |
| interactive | NO |
| headless | YES |
| hooks | NO (instructions embedded in CLAUDE.md) |
| browser | NO |
| RPC | YES (JSON-RPC 2.0) |
| Context | Varies by underlying model |
| Cost tier | budget to standard |

**RPC protocol:**

Pi's RPC connection provides the cleanest integration path. The `connect()`
method returns a `RuntimeConnection` that supports:

```typescript
const conn = adapter.connect(process);
await conn.sendPrompt("Implement the user service...");
// ... later, inject a message mid-session:
await conn.followUp("Builder-2 has merged shared types. Rebase and continue.");
const state = await conn.getState(); // { status: "processing", elapsed: 45000 }
await conn.abort(); // clean shutdown
conn.close();
```

This replaces tmux send-keys for prompt delivery, tmux capture-pane for state
checking, and process signals for shutdown. The orchestrator detects `connect`
on the adapter and uses RPC for all communication.

**Config deployment:**

1. `.claude/CLAUDE.md` -- same overlay format as Claude Code (Pi reads this)
2. `.pi/extensions/overstory-guard.json` -- tool restrictions via Pi's extension
   system, replacing Claude's `settings.local.json` hooks

**Best roles:** Builder (routine implementation), Scout (fast exploration)

**Quirks:**
- Pi reads `.claude/CLAUDE.md` by convention, making it config-compatible with
  Claude Code deployments.
- RPC state monitoring cannot distinguish idle from processing, so the adapter
  cannot use beacon verification. The orchestrator relies on timeout-based
  health checking instead.
- Model specification uses provider-prefixed format: `anthropic/claude-sonnet-4-6`,
  `openai/gpt-4o`, etc.

---

### 3.3 OpenAI Codex CLI -- Scout-Class, Sandboxed

**Stability:** Experimental

Codex runs in a strict OS-level sandbox with no network access, no filesystem
escape, and deterministic tool execution. This makes it ideal for untrusted
exploration where the risk of unintended side effects must be zero.

| Property | Value |
|----------|-------|
| **Detection** | `which codex` |
| **Session model** | Headless background process via `Bun.spawn` |
| **Instruction file** | `AGENTS.md` (OpenAI convention) |
| **Guard mechanism** | OS-level sandbox (no additional guards needed) |
| **Spawn command** | `codex exec` (headless, no tmux) |
| **Event stream** | NDJSON on stdout |
| **Readiness signal** | N/A (headless -- events indicate readiness) |

**Capabilities:**

| Capability | Status |
|------------|--------|
| tmux | NO |
| followUp | NO |
| agentTool | NO |
| interactive | NO |
| headless | YES |
| hooks | NO |
| browser | NO |
| RPC | NO |
| Context | 200k tokens |
| Cost tier | standard |

**Headless execution model:**

Codex does not use tmux. The adapter spawns it as a direct subprocess and reads
structured events from stdout:

```typescript
const args = adapter.buildDirectSpawn({
  model: resolvedModel,
  agentName: "scout-1",
  prompt: "Analyze the authentication module and report findings.",
  timeout: 300_000
});
const proc = Bun.spawn(args, { stdout: "pipe" });
for await (const event of adapter.parseEvents(proc.stdout)) {
  // AgentEvent: tool_call, progress, result, error
  eventStore.record(event);
}
```

**Config deployment:**

Writes `AGENTS.md` at the project root. Codex has no hook system -- all
instructions and constraints are embedded in the instruction file.

**Best roles:** Scout (read-only exploration), simple Builder tasks

**Quirks:**
- Very sandboxed. Limited tool access compared to other runtimes.
- No mid-session communication. The agent receives a prompt, executes, and
  terminates. No iterative conversation.
- File writes may be restricted by the OS sandbox depending on Codex
  configuration.

---

### 3.4 Google Gemini CLI -- Builder-Class, Large Context

**Stability:** Experimental

Gemini's advantage is its 1M+ token context window and strong multi-modal
capabilities. Tasks that require understanding an entire codebase at once --
large-scale refactoring, cross-module dependency analysis, documentation of
complex systems -- benefit from Gemini's context capacity.

| Property | Value |
|----------|-------|
| **Detection** | `which gemini` |
| **Session model** | tmux pane, interactive |
| **Instruction file** | `GEMINI.md` |
| **Guard mechanism** | Instructions embedded in GEMINI.md |
| **Spawn command** | `gemini --model <model>` |
| **Readiness signal** | Detects Gemini's `>` prompt |

**Capabilities:**

| Capability | Status |
|------------|--------|
| tmux | YES |
| followUp | NO (tmux send-keys only, no structured injection) |
| agentTool | NO |
| interactive | YES |
| headless | NO |
| hooks | NO |
| browser | NO |
| RPC | NO |
| Context | 1M+ tokens |
| Cost tier | standard |

**Config deployment:**

Writes `GEMINI.md` at the project root. Gemini does not support hooks, so
all instructions including mail check commands and quality gate definitions
are embedded directly in the instruction file.

**Best roles:** Builder (large-context tasks), Scout (codebase-wide analysis)

**Quirks:**
- Different tool naming conventions from Claude. The overlay generator must
  translate tool references in instructions.
- No hook system means the agent cannot automatically check mail on each
  prompt. Instructions must explicitly tell the agent to run mail check
  commands periodically.
- Context window advantage is significant for tasks touching 50+ files.

---

### 3.5 Cursor -- Builder-Class, IDE-Integrated

**Stability:** Experimental

Cursor is an IDE-embedded agent. Its tight VS Code integration provides
advantages for interactive development but makes external orchestration
difficult. Best used for human-supervised work rather than fleet participation.

| Property | Value |
|----------|-------|
| **Detection** | Process check for `cursor` |
| **Session model** | IDE-embedded |
| **Instruction file** | `.cursor/rules/platform.mdc` |
| **Guard mechanism** | Instructions in rule file |
| **Spawn command** | `cursor-agent --model <model>` |

**Capabilities:**

| Capability | Status |
|------------|--------|
| tmux | NO |
| followUp | NO |
| agentTool | NO |
| interactive | YES |
| headless | NO |
| hooks | NO |
| browser | NO |
| RPC | NO |
| Context | Varies |
| Cost tier | standard |

**Best roles:** Crew (user-directed work), Builder (IDE-assisted tasks)

**Quirks:**
- Tight IDE coupling makes fleet orchestration impractical. The adapter
  exists primarily for hybrid workflows where a human uses Cursor alongside
  an orchestrated fleet.
- `.cursor/rules/` uses `.mdc` format (Cursor's rule format), not markdown.
- Process detection is less reliable than binary detection -- Cursor may be
  running but not in agent mode.

---

### 3.6 GitHub Copilot -- Assistant-Class

**Stability:** Experimental

GitHub Copilot's coding agent mode provides IDE-integrated assistance with
strong GitHub ecosystem integration. Like Cursor, it is better suited for
human-supervised work than autonomous fleet participation.

| Property | Value |
|----------|-------|
| **Detection** | `which github-copilot-cli` or process check |
| **Session model** | IDE-embedded or CLI |
| **Instruction file** | `.github/copilot-instructions.md` |
| **Guard mechanism** | Instructions in instruction file |
| **Spawn command** | `github-copilot-cli --model <model>` |

**Capabilities:**

| Capability | Status |
|------------|--------|
| tmux | NO |
| followUp | NO |
| agentTool | NO |
| interactive | YES |
| headless | NO |
| hooks | NO |
| browser | NO |
| RPC | NO |
| Context | Varies |
| Cost tier | standard |

**Best roles:** Crew (human-directed), simple Builder tasks

**Quirks:**
- GitHub-native instruction file location (`.github/copilot-instructions.md`)
  integrates well with GitHub-hosted projects.
- Limited orchestration surface. Primarily useful in hybrid human+fleet workflows.

---

### 3.7 Windsurf -- Builder-Class, IDE-Integrated

**Stability:** Experimental

Windsurf (Codeium) provides IDE-embedded agent capabilities with its own
agentic features. Similar orchestration constraints to Cursor and Copilot.

| Property | Value |
|----------|-------|
| **Detection** | Process check for `windsurf` |
| **Session model** | IDE-embedded |
| **Instruction file** | `.windsurf/instructions.md` |
| **Guard mechanism** | Instructions in instruction file |

**Capabilities:**

| Capability | Status |
|------------|--------|
| tmux | NO |
| followUp | NO |
| agentTool | NO |
| interactive | YES |
| headless | NO |
| hooks | NO |
| browser | NO |
| RPC | NO |
| Context | Varies |
| Cost tier | standard |

**Best roles:** Crew (human-directed), simple Builder tasks

---

### 3.8 Sapling -- Builder-Class, Headless

**Stability:** Experimental

Sapling runs headless as a direct subprocess, similar to Codex but with
different tooling constraints. Good for batch tasks where interactive
sessions are unnecessary overhead.

| Property | Value |
|----------|-------|
| **Detection** | `which sapling` |
| **Session model** | Headless direct subprocess |
| **Instruction file** | `AGENTS.md` |
| **Guard mechanism** | OS-level or instruction-embedded |
| **Spawn command** | Headless via `Bun.spawn` |
| **Event stream** | NDJSON on stdout |

**Capabilities:**

| Capability | Status |
|------------|--------|
| tmux | NO |
| followUp | NO |
| agentTool | NO |
| interactive | NO |
| headless | YES |
| hooks | NO |
| browser | NO |
| RPC | NO |
| Context | Varies |
| Cost tier | budget |

**Best roles:** Builder (batch tasks), Scout (background exploration)

---

### 3.9 OpenCode -- Builder-Class, Open Source

**Stability:** Experimental

OpenCode is an open-source CLI agent with multi-provider support via
OpenRouter. Its tmux compatibility makes it more orchestration-friendly
than IDE-embedded alternatives.

| Property | Value |
|----------|-------|
| **Detection** | `which opencode` |
| **Session model** | tmux pane, interactive |
| **Instruction file** | `.opencode/instructions.md` |
| **Guard mechanism** | Instructions in instruction file |
| **Spawn command** | `opencode --model <model>` |

**Capabilities:**

| Capability | Status |
|------------|--------|
| tmux | YES |
| followUp | NO (tmux send-keys only) |
| agentTool | NO |
| interactive | YES |
| headless | NO |
| hooks | NO |
| browser | NO |
| RPC | NO |
| Context | Varies by underlying model |
| Cost tier | varies |

**Best roles:** Builder (general implementation)

**Quirks:**
- OpenRouter support means any model available on OpenRouter can be used
  through this adapter.
- Instruction file location (`.opencode/instructions.md`) is unique to
  OpenCode.
- tmux compatibility makes it a reasonable fallback when Claude Code is
  unavailable.

---

## 4. Auto-Detection Algorithm

Runtime selection follows a priority chain with multiple override points.

### Selection Priority

```
1. Explicit --runtime flag on sling command     (highest priority)
2. Per-capability config in config.yaml
3. Default runtime in config.yaml
4. Auto-detection via filesystem probing         (lowest priority)
```

### Auto-Detection Implementation

```typescript
interface RuntimeDetector {
  name: string;
  check: () => Promise<boolean>;
  priority: number;     // lower = checked first
}

const DETECTORS: RuntimeDetector[] = [
  {
    name: "claude-code",
    check: () => commandExists("claude"),
    priority: 1
  },
  {
    name: "pi-cli",
    check: () => commandExists("pi"),
    priority: 2
  },
  {
    name: "codex-cli",
    check: () => commandExists("codex"),
    priority: 3
  },
  {
    name: "gemini-cli",
    check: () => commandExists("gemini"),
    priority: 4
  },
  {
    name: "opencode",
    check: () => commandExists("opencode"),
    priority: 5
  },
  {
    name: "sapling",
    check: () => commandExists("sapling"),
    priority: 6
  },
  {
    name: "cursor",
    check: () => processRunning("cursor"),
    priority: 7
  },
  {
    name: "copilot",
    check: () => commandExists("github-copilot-cli"),
    priority: 8
  },
  {
    name: "windsurf",
    check: () => processRunning("windsurf"),
    priority: 9
  }
];

async function detectRuntime(): Promise<RuntimeAdapter> {
  // Sort by priority and check in order
  const sorted = DETECTORS.sort((a, b) => a.priority - b.priority);

  for (const detector of sorted) {
    if (await detector.check()) {
      return createAdapter(detector.name);
    }
  }

  throw new Error(
    "No supported runtime detected. Install one of: claude, pi, codex, gemini, opencode"
  );
}

async function commandExists(cmd: string): Promise<boolean> {
  try {
    const proc = Bun.spawn(["which", cmd], { stdout: "pipe" });
    await proc.exited;
    return proc.exitCode === 0;
  } catch {
    return false;
  }
}

async function processRunning(name: string): Promise<boolean> {
  try {
    const proc = Bun.spawn(["pgrep", "-x", name], { stdout: "pipe" });
    await proc.exited;
    return proc.exitCode === 0;
  } catch {
    return false;
  }
}
```

### Adapter Registry

```typescript
const ADAPTER_REGISTRY: Record<string, () => RuntimeAdapter> = {
  "claude-code":  () => new ClaudeCodeAdapter(),
  "pi-cli":       () => new PiCliAdapter(),
  "codex-cli":    () => new CodexCliAdapter(),
  "gemini-cli":   () => new GeminiCliAdapter(),
  "cursor":       () => new CursorAdapter(),
  "copilot":      () => new CopilotAdapter(),
  "windsurf":     () => new WindsurfAdapter(),
  "sapling":      () => new SaplingAdapter(),
  "opencode":     () => new OpenCodeAdapter(),
};

function createAdapter(name: string): RuntimeAdapter {
  const factory = ADAPTER_REGISTRY[name];
  if (!factory) {
    throw new Error(`Unknown runtime: ${name}. Available: ${Object.keys(ADAPTER_REGISTRY).join(", ")}`);
  }
  return factory();
}
```

---

## 5. Instruction File Generation

Each runtime expects its instructions in a different file, at a different path,
in a potentially different format. The overlay generator produces runtime-neutral
content; the adapter translates it into the runtime's native format.

### Instruction File Map

| Runtime | File Path | Format |
|---------|-----------|--------|
| Claude Code | `.claude/CLAUDE.md` | Markdown with YAML frontmatter |
| Pi CLI | `.claude/CLAUDE.md` | Same as Claude (Pi reads Claude config) |
| Codex CLI | `AGENTS.md` | Markdown (OpenAI convention) |
| Gemini CLI | `GEMINI.md` | Markdown |
| Cursor | `.cursor/rules/platform.mdc` | Cursor rule format |
| Copilot | `.github/copilot-instructions.md` | Markdown |
| Windsurf | `.windsurf/instructions.md` | Markdown |
| Sapling | `AGENTS.md` | Markdown |
| OpenCode | `.opencode/instructions.md` | Markdown |

### Generation Pipeline

```typescript
function deployInstructions(
  runtime: RuntimeAdapter,
  worktreePath: string,
  config: OverlayConfig
): void {
  // Step 1: Generate runtime-neutral overlay content
  const overlay = generateOverlay(config);

  // Step 2: Adapt content to runtime-specific format
  const adapted = adaptForRuntime(runtime.id, overlay);

  // Step 3: Write to runtime-specific path
  const instructionPath = path.join(worktreePath, runtime.instructionPath);
  ensureDir(path.dirname(instructionPath));
  writeFile(instructionPath, adapted);

  // Step 4: Deploy runtime-specific guard configuration
  runtime.deployConfig(worktreePath, overlay, config.hooks);
}
```

### Template Variables

Every instruction file, regardless of runtime, receives these variables:

| Variable | Source | Example |
|----------|--------|---------|
| `{{AGENT_NAME}}` | Sling config | `builder-alpha` |
| `{{AGENT_ROLE}}` | Sling config | `builder` |
| `{{TASK_ID}}` | Work item | `task-a1b2c3` |
| `{{BRANCH_NAME}}` | Worktree | `agent/builder-alpha/task-a1b2c3` |
| `{{FILE_SCOPE}}` | Ownership map | `services/auth/, packages/shared/types.ts` |
| `{{PARENT_AGENT}}` | Hierarchy | `lead-frontend` |
| `{{DEPTH}}` | Hierarchy | `2` |
| `{{QUALITY_GATES}}` | Project config | `bun test, biome check ., tsc --noEmit` |
| `{{INSTRUCTION_PATH}}` | Runtime adapter | `.claude/CLAUDE.md` |
| `{{EXPERTISE}}` | Mulch/knowledge base | Pre-loaded domain expertise |
| `{{COGNITIVE_PATTERNS}}` | Role + specialization | `Beck Make Change Easy, Kernighan Debugging` |
| `{{MAIL_CHECK_CMD}}` | Platform CLI | `platform mail check --agent builder-alpha --inject` |
| `{{MAIL_SEND_CMD}}` | Platform CLI | `platform mail send --from builder-alpha --to lead-frontend` |

### Runtime-Specific Adaptations

**Claude Code:** Full hook support. Mail check runs automatically via
`UserPromptSubmit` hook. Guard rules enforced via `settings.local.json`
permissions. No need to embed mail check reminders in instructions.

**Pi CLI:** No hooks. Instructions must include explicit reminders to check
mail periodically. Guard rules deployed as `.pi/extensions/` JSON files
instead of settings hooks.

**Codex CLI / Sapling:** No hooks, no mid-session communication. All context
must be in the initial prompt. Instructions include the complete task
specification, not just a reference to check mail.

**Gemini CLI:** No hooks. Instructions embed periodic mail check reminders.
Tool names may differ from Claude -- the adapter translates references
(e.g., "use the Edit tool" becomes runtime-appropriate language).

**IDE runtimes (Cursor, Copilot, Windsurf):** Instructions are minimal --
these runtimes are primarily for human-supervised work. Guard rules are
advisory, not enforced.

---

## 6. Mixed Fleet Configuration

Mixed fleets assign different runtimes to different roles based on capability
requirements and cost constraints.

### Fleet Configuration Schema

```yaml
# config.yaml — runtime section

runtime:
  default: "claude-code"          # fallback for any role not explicitly configured

  # Per-capability runtime assignment
  capabilities:
    coordinator: "claude-code"     # must support hooks or followUp
    lead: "claude-code"            # must support tmux or followUp
    builder: "pi-cli"              # fast iteration, cost-effective
    reviewer: "claude-code"        # needs good reasoning for review quality
    scout: "codex-cli"             # sandboxed, cheap, read-only
    merger: "claude-code"          # needs reasoning for conflict resolution
    watchdog: "claude-code"        # needs hooks for patrol loop
    browse-agent: "claude-code"    # needs browser tool support
    quality-auditor: "claude-code" # needs reasoning for audit quality

  # Model selection per role
  models:
    coordinator: "opus"
    lead: "sonnet"
    builder: "sonnet"
    reviewer: "sonnet"
    scout: "haiku"
    merger: "sonnet"
    watchdog: "haiku"

  # Provider configuration
  providers:
    openrouter:
      type: "gateway"
      baseUrl: "https://openrouter.ai/api/v1"
      authTokenEnv: "OPENROUTER_API_KEY"

  # Pi-specific configuration
  pi:
    provider: "anthropic"
    modelMap:
      opus: "anthropic/claude-opus-4-6"
      sonnet: "anthropic/claude-sonnet-4-6"
      haiku: "anthropic/claude-3-5-haiku"

  # Print command for non-interactive LLM calls (overlays, summaries)
  printCommand: "claude"
```

### Example Fleet Compositions

**Cost-Optimized Fleet (Solo Developer)**

```yaml
fleet:
  coordinator:
    runtime: claude-code
    model: sonnet        # Opus is expensive; Sonnet coordinates well enough
    count: 1
  builders:
    runtime: pi-cli      # cheapest runtime for implementation
    model: sonnet
    count: 3
  scouts:
    runtime: codex-cli   # sandboxed, cheap read-only exploration
    count: 2
  reviewers:
    runtime: claude-code
    model: sonnet        # review quality matters
    count: 1
```

**Quality-Optimized Fleet (Critical Project)**

```yaml
fleet:
  coordinator:
    runtime: claude-code
    model: opus           # best reasoning for orchestration
    count: 1
  leads:
    runtime: claude-code
    model: sonnet
    count: 2
  builders:
    runtime: claude-code  # Claude for complex tasks
    model: sonnet
    count: 5
  scouts:
    runtime: gemini-cli   # large context for codebase analysis
    count: 2
  reviewers:
    runtime: claude-code
    model: sonnet
    count: 2
  quality-auditors:
    runtime: claude-code
    model: sonnet
    count: 1
```

**Maximum Throughput Fleet**

```yaml
fleet:
  coordinator:
    runtime: claude-code
    model: opus
    count: 1
  leads:
    runtime: claude-code
    model: sonnet
    count: 3
  builders:
    runtime: pi-cli       # fast iteration for routine tasks
    count: 8
  scouts:
    runtime: codex-cli    # cheap background exploration
    count: 3
  reviewers:
    runtime: claude-code
    model: sonnet
    count: 2
```

### Role-Runtime Compatibility Matrix

Not every runtime can fulfill every role. The orchestrator validates
compatibility before spawning:

| Role | Required Capabilities | Compatible Runtimes |
|------|----------------------|---------------------|
| Coordinator | hooks OR followUp, tmux OR RPC | Claude Code |
| Lead | tmux OR RPC, sling access | Claude Code, Pi CLI |
| Builder | read + write + edit + bash | Claude Code, Pi CLI, Gemini CLI, OpenCode, Codex*, Sapling* |
| Reviewer | read + bash (read-only) | All runtimes |
| Scout | read + bash (read-only) | All runtimes |
| Merger | read + write + edit + bash | Claude Code, Pi CLI, Gemini CLI |
| Watchdog | hooks OR periodic polling, tmux inspection | Claude Code |
| Browse Agent | browser tool support | Claude Code (via Browse CLI) |
| Quality Auditor | read + bash (read-only) | All runtimes |

*Codex and Sapling can serve as Builders only for simple, self-contained tasks
that do not require mid-session communication.

---

## 7. Fallback Chains

When the preferred runtime for a role is unavailable, the system falls back
through a defined chain. Fallback is per-role, not global.

### Default Fallback Chains

```
Coordinator:     claude-code → ERROR (no substitute for coordinator capabilities)
Lead:            claude-code → pi-cli → ERROR
Builder:         pi-cli → claude-code → gemini-cli → opencode → codex-cli → sapling → ERROR
Reviewer:        claude-code → gemini-cli → pi-cli → codex-cli → opencode → ERROR
Scout:           codex-cli → claude-code → gemini-cli → pi-cli → opencode → sapling → ERROR
Merger:          claude-code → gemini-cli → pi-cli → ERROR
Watchdog:        claude-code → ERROR (requires hooks)
Browse Agent:    claude-code → ERROR (requires browser support)
Quality Auditor: claude-code → gemini-cli → pi-cli → codex-cli → ERROR
```

### Fallback Rules

The fallback engine validates each candidate against role requirements:

```typescript
interface FallbackRule {
  role: string;
  chain: string[];                    // ordered runtime preferences
  requiredCapabilities: string[];     // capabilities that cannot be degraded
  degradableCapabilities: string[];   // capabilities that can be lost in fallback
}

const FALLBACK_RULES: FallbackRule[] = [
  {
    role: "coordinator",
    chain: ["claude-code"],
    requiredCapabilities: ["supportsHooks", "supportsTmux"],
    degradableCapabilities: []
  },
  {
    role: "builder",
    chain: ["pi-cli", "claude-code", "gemini-cli", "opencode", "codex-cli", "sapling"],
    requiredCapabilities: [],   // minimum: can execute code
    degradableCapabilities: ["supportsFollowUp", "supportsTmux", "supportsHooks"]
  },
  {
    role: "scout",
    chain: ["codex-cli", "claude-code", "gemini-cli", "pi-cli", "opencode", "sapling"],
    requiredCapabilities: [],   // read-only, any runtime works
    degradableCapabilities: ["supportsFollowUp", "supportsTmux", "supportsHooks"]
  }
];

async function resolveRuntime(role: string, preferred?: string): Promise<RuntimeAdapter> {
  // Try explicit preference first
  if (preferred) {
    const adapter = createAdapter(preferred);
    if (validateCompatibility(role, adapter)) {
      return adapter;
    }
    console.warn(`Runtime ${preferred} incompatible with role ${role}, falling back`);
  }

  // Walk the fallback chain
  const rule = FALLBACK_RULES.find(r => r.role === role);
  if (!rule) throw new Error(`No fallback rule for role: ${role}`);

  for (const runtimeName of rule.chain) {
    try {
      const adapter = createAdapter(runtimeName);
      if (await runtimeAvailable(runtimeName) && validateCompatibility(role, adapter)) {
        if (runtimeName !== rule.chain[0]) {
          console.warn(`Using fallback runtime ${runtimeName} for ${role} (preferred: ${rule.chain[0]})`);
        }
        return adapter;
      }
    } catch {
      continue;
    }
  }

  throw new Error(
    `No compatible runtime available for role ${role}. Checked: ${rule.chain.join(", ")}`
  );
}

function validateCompatibility(role: string, adapter: RuntimeAdapter): boolean {
  const rule = FALLBACK_RULES.find(r => r.role === role);
  if (!rule) return false;

  for (const cap of rule.requiredCapabilities) {
    if (!adapter.capabilities[cap]) return false;
  }
  return true;
}
```

### Degradation Logging

When a fallback occurs, the system logs what capabilities were lost:

```
[WARN] Runtime fallback for builder-3: pi-cli unavailable, using claude-code
       Lost capabilities: none (upgrade)
       Gained capabilities: hooks, agentTool
       Cost impact: +$0.02/MTok estimated

[WARN] Runtime fallback for scout-1: codex-cli unavailable, using gemini-cli
       Lost capabilities: headless, sandbox
       Gained capabilities: tmux, large context
       Cost impact: +$0.01/MTok estimated
```

---

## 8. Cost and Capability Matrix

### Comparative Overview

| Runtime | Context | Cost Tier | Reasoning | Speed | Orchestration | Best Role |
|---------|---------|-----------|-----------|-------|---------------|-----------|
| Claude Code (Opus) | 1M | Frontier | Exceptional | Moderate | Full | Coordinator |
| Claude Code (Sonnet) | 200k | Premium | Strong | Fast | Full | Lead, Reviewer |
| Claude Code (Haiku) | 200k | Standard | Good | Very Fast | Full | Scout, Watchdog |
| Pi CLI | Varies | Budget | Good | Very Fast | RPC only | Builder |
| Codex CLI | 200k | Standard | Good | Moderate | Minimal | Scout |
| Gemini CLI (Pro) | 1M+ | Standard | Strong | Moderate | Partial | Builder (large context) |
| OpenCode | Varies | Varies | Varies | Varies | Partial | Builder |
| Sapling | Varies | Budget | Moderate | Fast | Minimal | Builder (batch) |
| Cursor | Varies | Standard | Good | Fast | None | Crew |
| Copilot | Varies | Standard | Good | Fast | None | Crew |
| Windsurf | Varies | Standard | Good | Fast | None | Crew |

### Cost Estimation Model

```typescript
interface CostEstimate {
  runtime: string;
  model: string;
  inputCostPerMTok: number;
  outputCostPerMTok: number;
  cacheReadDiscount: number;      // multiplier (e.g., 0.1 = 90% discount)
  estimatedTokensPerTask: {
    scout: number;
    builder: number;
    reviewer: number;
    coordinator: number;
  };
}

// Example: estimate build cost for a 10-agent fleet
function estimateBuildCost(fleet: FleetConfig): CostBreakdown {
  let total = 0;
  const breakdown: Record<string, number> = {};

  for (const [role, config] of Object.entries(fleet)) {
    const cost = COST_ESTIMATES[config.runtime];
    const tokensPerTask = cost.estimatedTokensPerTask[role] || 500_000;
    const taskCost = (tokensPerTask / 1_000_000) *
      (cost.inputCostPerMTok * 0.7 + cost.outputCostPerMTok * 0.3);
    const roleCost = taskCost * config.count;
    breakdown[role] = roleCost;
    total += roleCost;
  }

  return { total, breakdown };
}
```

### Orchestration Capability Tiers

| Tier | Capabilities | Runtimes | Use Case |
|------|-------------|----------|----------|
| **Full orchestration** | hooks + tmux + followUp + agentTool | Claude Code | Coordinator, Lead, Watchdog |
| **RPC orchestration** | RPC + followUp (no tmux, no hooks) | Pi CLI | Builder with mid-session comms |
| **Partial orchestration** | tmux only (no hooks, no followUp) | Gemini CLI, OpenCode | Builder, Reviewer |
| **Minimal orchestration** | headless only (no tmux, no hooks, no followUp) | Codex CLI, Sapling | Scout, simple Builder |
| **No orchestration** | IDE-embedded, human-supervised | Cursor, Copilot, Windsurf | Crew only |

---

## 9. Adding a New Runtime

The adapter interface is designed for mechanical extension. Adding a new
runtime follows a repeatable 8-step process.

### Step 1: Create the Adapter Class

```typescript
// src/runtimes/newruntime.ts

import type { RuntimeAdapter, RuntimeCapabilities, SpawnOpts, ReadyState } from "./types";

export class NewRuntimeAdapter implements RuntimeAdapter {
  readonly id = "new-runtime";
  readonly displayName = "New Runtime";
  readonly stability = "experimental" as const;

  readonly capabilities: RuntimeCapabilities = {
    supportsTmux: true,           // can it run in tmux?
    supportsInteractive: true,    // does it need a terminal?
    supportsHeadless: false,      // can it run without a terminal?
    supportsFollowUp: false,      // can you send messages mid-session?
    supportsHooks: false,         // does it support lifecycle hooks?
    supportsRPC: false,           // does it support JSON-RPC?
    supportsAgentTool: false,     // can it spawn sub-agents?
    supportsBrowser: false,       // does it have browser tools?
    maxContextTokens: 200_000,    // context window size
    costTier: "standard",
    quoteStyle: "double",
    commentPrefix: "#",
  };

  // ... implement all required methods
}
```

### Step 2: Implement Required Methods

Each method has a clear responsibility:

| Method | Responsibility | Typical Lines |
|--------|---------------|---------------|
| `buildSpawnCommand()` | Construct the shell command for tmux | 10-20 |
| `buildPrintCommand()` | Construct a one-shot print command | 5-10 |
| `deployConfig()` | Write instruction file + guard config to worktree | 30-60 |
| `detectReady()` | Parse tmux pane content and classify state | 20-40 |
| `parseTranscript()` | Read session transcript and extract token usage | 40-80 |
| `getTranscriptDir()` | Return path to transcript storage | 5 |
| `buildEnv()` | Set up environment variables for the runtime | 10-20 |

**Total: 120-235 lines for a basic adapter.**

### Step 3: Define the Instruction File Path

```typescript
// What file does this runtime read for instructions?
readonly instructionPath = ".newruntime/instructions.md";
```

### Step 4: Add Detection Logic

Add an entry to the `DETECTORS` array in the auto-detection module:

```typescript
{
  name: "new-runtime",
  check: () => commandExists("newruntime"),
  priority: 10    // lower priority than established runtimes
}
```

### Step 5: Register the Adapter

Add to `ADAPTER_REGISTRY`:

```typescript
"new-runtime": () => new NewRuntimeAdapter(),
```

### Step 6: Create Instruction File Template

Create a template that adapts the standard overlay format to the runtime's
conventions:

```typescript
// templates/NEWRUNTIME.md.tmpl
function generateNewRuntimeInstructions(config: OverlayConfig): string {
  // Start with the standard overlay content
  let content = generateOverlay(config);

  // Adapt for runtime-specific conventions
  // - Rename tool references if needed
  // - Add runtime-specific sections
  // - Embed mail check reminders if no hooks

  return content;
}
```

### Step 7: Add to Fallback Chains

Determine which roles the new runtime can fulfill and add it to the
appropriate fallback chains in `FALLBACK_RULES`.

### Step 8: Test with Sling Dispatch

```bash
# Test spawning an agent with the new runtime
platform sling \
  --capability builder \
  --name test-builder \
  --runtime new-runtime \
  --spec tasks/test-task.md \
  --files "src/test/"

# Verify:
# 1. Worktree created
# 2. Instruction file written to correct path
# 3. Guard config deployed (if applicable)
# 4. Session started (tmux or headless)
# 5. Readiness detected
# 6. Initial prompt delivered
# 7. Agent begins working
# 8. Transcript parsed on completion
```

### Documentation Checklist for New Adapters

When adding a new runtime, document:

- [ ] Detection method (binary check, process check, env var)
- [ ] Session model (tmux, headless, IDE-embedded)
- [ ] Instruction file path and format
- [ ] Guard mechanism (hooks, extensions, embedded, none)
- [ ] Spawn command with all required flags
- [ ] Readiness detection heuristics (what does the TUI look like when ready?)
- [ ] Transcript location and format
- [ ] Known quirks and limitations
- [ ] Capability declaration with rationale for each boolean
- [ ] Compatible roles
- [ ] Cost tier and context window size

---

## 10. Session Manager

The session manager handles the lifecycle of agent execution environments,
bridging the gap between the orchestrator's abstract `spawn` call and the
concrete reality of tmux sessions, headless processes, and RPC connections.

### Interactive Session Lifecycle (tmux)

```
sling called
  → create git worktree on feature branch
  → deploy instruction file via adapter.deployConfig()
  → create tmux session: tmux new-session -d -s {agent-name}
  → send spawn command: tmux send-keys "{adapter.buildSpawnCommand()}" Enter
  → poll for readiness: adapter.detectReady(capturePane())
    → if "loading": wait 1s, retry
    → if "dialog": handle permission dialog (approve/dismiss)
    → if "ready": proceed
  → deliver initial prompt
    → if adapter.requiresBeaconVerification(): send beacon first, verify, then send real prompt
    → else: send prompt directly via tmux send-keys
  → register session in sessions.db
  → record spawn event in events.db
```

### Headless Session Lifecycle

```
sling called
  → create git worktree on feature branch
  → deploy instruction file via adapter.deployConfig()
  → spawn process: Bun.spawn(adapter.buildDirectSpawn(opts))
  → stream events: adapter.parseEvents(proc.stdout)
  → register session in sessions.db
  → record spawn event in events.db
  → await process exit
  → parse transcript: adapter.parseTranscript()
  → record completion in sessions.db
```

### RPC Session Lifecycle (Pi)

```
sling called
  → create git worktree on feature branch
  → deploy instruction file via adapter.deployConfig()
  → spawn process: Bun.spawn(adapter.buildSpawnCommand())
  → establish RPC connection: adapter.connect(process)
  → deliver initial prompt: connection.sendPrompt(prompt)
  → register session and connection in sessions.db
  → record spawn event in events.db
  → orchestrator uses connection.followUp() for subsequent messages
  → on completion: connection.abort(), connection.close()
```

### Communication Dispatch

The session manager selects the communication mechanism based on the adapter's
capabilities:

```typescript
async function deliverMessage(agentHandle: AgentHandle, message: string): Promise<void> {
  const adapter = agentHandle.adapter;

  // Prefer RPC (cleanest, most reliable)
  if (adapter.capabilities.supportsRPC && agentHandle.connection) {
    await agentHandle.connection.followUp(message);
    return;
  }

  // Fall back to tmux send-keys
  if (adapter.capabilities.supportsTmux && agentHandle.tmuxSession) {
    await tmuxSendKeys(agentHandle.tmuxSession, message);
    return;
  }

  // Headless runtimes cannot receive mid-session messages
  throw new Error(
    `Runtime ${adapter.id} does not support mid-session communication. ` +
    `Message for ${agentHandle.agentName} cannot be delivered.`
  );
}
```

---

## 11. Guard Rule Translation

Guard rules (tool restrictions, bash patterns, path boundaries) must be
translated from the platform's abstract format into each runtime's native
enforcement mechanism.

### Platform Guard Format (Abstract)

```typescript
interface GuardRules {
  allowedTools: string[];              // ["Read", "Write", "Edit", "Glob", "Grep", "Bash"]
  bashPatterns: {
    allow: string[];                   // ["git status", "git diff", "git log", "bun test"]
    deny: string[];                    // ["git push", "platform sling"]
  };
  pathBoundary: string;                // "/path/to/worktree"
  fileScope: string[];                 // ["services/auth/", "packages/shared/types.ts"]
}
```

### Translation by Runtime

**Claude Code** -- Native enforcement via `settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write(services/auth/**)",
      "Edit(services/auth/**)",
      "Glob",
      "Grep",
      "Bash(git status:git diff:git log:bun test:git add:git commit)"
    ]
  }
}
```

**Pi CLI** -- Extension-based enforcement:

```json
// .pi/extensions/platform-guard.json
{
  "toolRestrictions": {
    "allowed": ["Read", "Write", "Edit", "Glob", "Grep", "Bash"],
    "pathRestrictions": ["services/auth/", "packages/shared/types.ts"],
    "bashAllowlist": ["git status", "git diff", "git log", "bun test"]
  }
}
```

**Codex CLI** -- OS-level sandbox (no additional guards needed). Codex's
sandbox restricts filesystem access and network access at the OS level.
The instruction file includes advisory constraints but enforcement is
structural.

**Gemini CLI / OpenCode / Others** -- Instruction-embedded guards. The
instruction file includes explicit statements about what the agent is
and is not allowed to do. Enforcement is advisory (LLM compliance), not
structural.

```markdown
## Restrictions

You MUST only modify files within these directories:
- services/auth/
- packages/shared/types.ts

You MUST NOT run these commands:
- git push
- platform sling

You MUST run these commands before reporting completion:
- bun test
- biome check .
```

### Guard Enforcement Tiers

| Tier | Mechanism | Strength | Runtimes |
|------|-----------|----------|----------|
| **Structural** | Runtime prevents the action at the tool level | Impossible to violate | Claude Code (permissions), Codex (OS sandbox) |
| **Extension** | Runtime plugin intercepts and blocks | Very hard to violate | Pi (extensions) |
| **Instructional** | LLM follows instructions in the prompt | Probabilistic compliance | Gemini, OpenCode, Cursor, Copilot, Windsurf, Sapling |

The platform prefers structural enforcement when available. For runtimes with
only instructional enforcement, the merge queue serves as a second gate:
work that violates file scope or modifies disallowed files is rejected during
merge review regardless of runtime enforcement tier.

---

## 12. Design Implications

### The Adapter Tax

Each adapter is 200-400 lines. Nine adapters represent ~2,000-3,600 lines of
code. This is the adapter tax -- the ongoing cost of maintaining runtime
neutrality.

The tax is justified because:

1. **Adding a new runtime is mechanical.** Implement the 8 required methods,
   add to the registry. No architectural changes required.
2. **The interface is stable.** Changes to one adapter do not affect others.
   Runtime-specific bugs are isolated.
3. **The hardest part is readiness detection.** Each TUI displays different
   loading states, different prompt characters, different permission dialogs.
   This is the bulk of adapter complexity.

### Runtime-Neutral Is Not Runtime-Identical

The platform is neutral (any runtime can participate) but not identical (each
runtime has different capabilities). The orchestrator must reason about
capability differences:

- A builder on Pi cannot receive mid-session mail injections via hooks.
  The orchestrator must deliver all context in the initial prompt.
- A scout on Codex cannot be nudged if it stalls. The orchestrator must
  set timeouts and restart rather than attempt recovery.
- A coordinator on anything other than Claude Code loses hook-driven
  orchestration. This is a hard constraint, not a degradation.

### RPC Is the Future, tmux Is the Present

Pi's JSON-RPC protocol is cleaner than tmux send-keys in every dimension:
reliable message delivery, structured state queries, clean shutdown, no
character escaping issues. As more runtimes adopt RPC-style communication,
the tmux layer becomes a compatibility shim for legacy runtimes.

The adapter interface supports both models. The orchestrator prefers RPC
when available and falls back to tmux. New adapters should implement
`connect()` if the runtime supports any form of programmatic communication.

### Mixed Fleets Are the Default, Not the Exception

The cost matrix makes mixed fleets economically rational for any build with
more than 3 agents. Running 10 builders on Opus when Pi handles routine
implementation at 10x lower cost is waste. Running scouts on Claude when
Codex provides a free sandbox is waste.

The fleet configuration system treats mixed runtimes as the default. A
homogeneous fleet (all Claude Code) is a special case, not the expected
configuration.

---

## Appendix A: Runtime Quick Reference

| Runtime | Detection | Instruction File | Session | Guard | Stability |
|---------|-----------|-----------------|---------|-------|-----------|
| Claude Code | `which claude` | `.claude/CLAUDE.md` | tmux | settings.json | stable |
| Pi CLI | `which pi` | `.claude/CLAUDE.md` | RPC | extensions | beta |
| Codex CLI | `which codex` | `AGENTS.md` | headless | OS sandbox | experimental |
| Gemini CLI | `which gemini` | `GEMINI.md` | tmux | instructions | experimental |
| Cursor | `pgrep cursor` | `.cursor/rules/platform.mdc` | IDE | instructions | experimental |
| Copilot | `which github-copilot-cli` | `.github/copilot-instructions.md` | IDE | instructions | experimental |
| Windsurf | `pgrep windsurf` | `.windsurf/instructions.md` | IDE | instructions | experimental |
| Sapling | `which sapling` | `AGENTS.md` | headless | instructions | experimental |
| OpenCode | `which opencode` | `.opencode/instructions.md` | tmux | instructions | experimental |

## Appendix B: Capability Matrix

| Capability | Claude | Pi | Codex | Gemini | Cursor | Copilot | Windsurf | Sapling | OpenCode |
|------------|--------|-----|-------|--------|--------|---------|----------|---------|----------|
| tmux | Y | N | N | Y | N | N | N | N | Y |
| followUp | Y | Y | N | N | N | N | N | N | N |
| agentTool | Y | N | N | N | N | N | N | N | N |
| interactive | Y | N | N | Y | Y | Y | Y | N | Y |
| headless | N | Y | Y | N | N | N | N | Y | N |
| hooks | Y | N | N | N | N | N | N | N | N |
| browser | N | N | N | N | N | N | N | N | N |
| RPC | N | Y | N | N | N | N | N | N | N |

## Appendix C: Source Provenance

| Section | Primary Source | Secondary Source |
|---------|---------------|-----------------|
| Adapter interface | Overstory `src/runtimes/types.ts` | Platform `03-system-architecture.md` Layer 5 |
| Per-runtime specs | Overstory `src/runtimes/*.ts` (9 adapters) | Gas Town session management |
| Auto-detection | Overstory runtime selection chain | -- |
| Instruction file generation | Overstory `deployConfig()` + template system | ATSA overlay generator concept |
| Mixed fleet config | Overstory `config.yaml` runtime section | Platform `04-role-taxonomy.md` role specs |
| Fallback chains | ATSA runtime degradation (3 modes) | Overstory default runtime chain |
| Guard rule translation | Overstory `guard-rules.ts` | ATSA `allowed_tools` frontmatter |
| RPC connection | Overstory `src/runtimes/connections.ts` | Pi CLI JSON-RPC protocol |
| Headless execution | Overstory `src/worktree/process.ts` | Codex/Sapling subprocess model |
| Session manager | Gas Town tmux + sling dispatch | Overstory sling mechanism |
