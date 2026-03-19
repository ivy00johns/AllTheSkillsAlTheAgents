# 06 — Runtime Adapters

## The Runtime Abstraction

Overstory's most forward-looking feature: it doesn't assume Claude Code.
The `AgentRuntime` interface (`src/runtimes/types.ts`) defines a contract
that any coding agent can implement. Nine adapters exist today.

This means the same orchestration infrastructure — worktrees, mail, merge
queue, watchdog — works regardless of which AI is doing the coding.

## The AgentRuntime Interface

Every runtime adapter must implement:

```typescript
interface AgentRuntime {
  id: string;                          // "claude", "pi", "codex", etc.
  stability: "stable" | "beta" | "experimental";
  instructionPath: string;             // ".claude/CLAUDE.md", "AGENTS.md", etc.

  buildSpawnCommand(opts: SpawnOpts): string;
  buildPrintCommand(prompt: string, model?: string): string[];
  deployConfig(worktreePath, overlay, hooks): Promise<void>;
  detectReady(paneContent: string): ReadyState;
  parseTranscript(path: string): Promise<TranscriptSummary | null>;
  getTranscriptDir(projectRoot: string): string | null;
  buildEnv(model: ResolvedModel): Record<string, string>;

  // Optional
  requiresBeaconVerification?(): boolean;
  connect?(process: RpcProcessHandle): RuntimeConnection;
  headless?: boolean;
  buildDirectSpawn?(opts: DirectSpawnOpts): string[];
  parseEvents?(stream: ReadableStream): AsyncIterable<AgentEvent>;
}
```

### Key Methods Explained

**`buildSpawnCommand()`** — Produces the shell command string for tmux to run.
Claude Code: `claude --model sonnet --dangerously-skip-permissions`
Pi: `pi --mode chat --model anthropic/claude-sonnet-4-6`
Codex: headless, no tmux command needed

**`deployConfig()`** — Writes runtime-specific instruction and guard files:
- Claude Code → `.claude/CLAUDE.md` + `settings.local.json` with hooks
- Pi → `.claude/CLAUDE.md` + `.pi/extensions/overstory-guard.json`
- Codex → `AGENTS.md` (Codex's instruction file)
- Gemini → `GEMINI.md` (Gemini's instruction file)

**`detectReady()`** — Parses tmux pane content to determine if the agent
is ready for input. Returns one of:
- `{ phase: "loading" }` — still initializing
- `{ phase: "dialog", action: "approve" }` — stuck on a permission dialog
- `{ phase: "ready" }` — ready to receive the initial prompt

**`parseTranscript()`** — Reads the runtime's session transcript and extracts
normalized token usage for cost tracking.

## The 9 Runtime Adapters

### Claude Code (`src/runtimes/claude.ts`) — STABLE
- **Stability:** stable
- **Instruction path:** `.claude/CLAUDE.md`
- **Spawn:** `claude --model <model> --dangerously-skip-permissions`
- **Print:** `claude --print --model <model>`
- **Config deployment:** `.claude/CLAUDE.md` + `settings.local.json` hooks
- **Readiness:** Detects ">" prompt, permission dialogs, loading states
- **Transcripts:** Parses Claude Code JSONL transcripts in `~/.claude/projects/`
- **Beacon verification:** YES — Claude's TUI sometimes swallows Enter during
  late initialization, so ov resends the beacon if needed

### Pi (`src/runtimes/pi.ts`) — BETA
- **Stability:** beta
- **Instruction path:** `.claude/CLAUDE.md` (Pi reads Claude's config)
- **Spawn:** `pi --mode chat --model <provider/model>`
- **Print:** `pi --mode print --model <model>`
- **Config deployment:** `.claude/CLAUDE.md` + `.pi/extensions/` guard files
- **RPC support:** YES — `connect()` returns a `RuntimeConnection` for
  direct stdin/stdout JSON-RPC communication
- **Beacon verification:** NO — Pi's idle/processing states are
  indistinguishable via `detectReady`, so resending would spam duplicates
- **Guard extensions:** Pi uses `.pi/extensions/` for tool restrictions
  instead of settings.json hooks

### GitHub Copilot (`src/runtimes/copilot.ts`) — EXPERIMENTAL
- **Instruction path:** `.github/copilot-instructions.md`
- **Spawn:** `github-copilot-cli --model <model>`
- **Config deployment:** Writes to `.github/copilot-instructions.md`

### OpenAI Codex (`src/runtimes/codex.ts`) — EXPERIMENTAL
- **Instruction path:** `AGENTS.md`
- **Spawn:** Headless via `codex exec`
- **Headless:** YES — no tmux, uses `Bun.spawn` directly
- **Config deployment:** Writes `AGENTS.md` (no hooks needed, Codex has
  OS-level sandbox)
- **Event parsing:** Reads NDJSON from stdout

### Google Gemini CLI (`src/runtimes/gemini.ts`) — EXPERIMENTAL
- **Instruction path:** `GEMINI.md`
- **Spawn:** `gemini --model <model>`
- **Config deployment:** Writes `GEMINI.md`
- **Readiness:** Detects Gemini's `>` prompt

### Sapling (`src/runtimes/sapling.ts`) — EXPERIMENTAL
- **Headless:** YES — direct subprocess
- **Instruction path:** `AGENTS.md`
- **Config deployment:** Writes `AGENTS.md`

### OpenCode (`src/runtimes/opencode.ts`) — EXPERIMENTAL
- **Instruction path:** `.opencode/instructions.md`
- **Spawn:** `opencode --model <model>`
- **Config deployment:** Writes `.opencode/instructions.md`

### Cursor (`src/runtimes/cursor.ts`) — EXPERIMENTAL
- **Instruction path:** `.cursor/rules/overstory.mdc`
- **Spawn:** `cursor-agent --model <model>`
- **Config deployment:** Writes `.cursor/rules/overstory.mdc`

## Runtime Selection

The runtime is selected through a chain:

1. **Explicit `--runtime` flag** on `ov sling` — highest priority
2. **Per-capability config** — `runtime.capabilities.builder = "pi"`
3. **Default config** — `runtime.default = "claude"`
4. **Fallback** — "claude"

This allows mixed fleets: leads on Claude (for interactive coordination),
builders on Pi (for fast coding), scouts on Codex (for headless exploration).

## Model Routing

Overstory supports multiple model providers:

```yaml
# config.yaml
providers:
  openrouter:
    type: gateway
    baseUrl: "https://openrouter.ai/api/v1"
    authTokenEnv: "OPENROUTER_API_KEY"

models:
  builder: "openrouter/anthropic/claude-sonnet-4-6"
  scout: "haiku"
  coordinator: "opus"
```

The `ResolvedModel` type carries the model ID plus any environment variables
needed for the provider:

```typescript
interface ResolvedModel {
  model: string;
  env?: Record<string, string>;
  isExplicitOverride?: boolean;
}
```

## RPC Connection (Pi Runtime)

Pi supports direct RPC via stdin/stdout JSON-RPC 2.0:

```typescript
interface RuntimeConnection {
  sendPrompt(text: string): Promise<void>;   // Initial prompt
  followUp(text: string): Promise<void>;     // Replaces tmux send-keys
  abort(): Promise<void>;                     // Clean shutdown
  getState(): Promise<ConnectionState>;       // Replaces tmux capture-pane
  close(): void;                              // Release resources
}
```

When `runtime.connect` exists, the orchestrator bypasses tmux entirely for
mail delivery, nudges, shutdown, and health checks. This is the future —
tmux is a compatibility layer, RPC is the clean interface.

The connection registry (`src/runtimes/connections.ts`) tracks active
connections at the module level.

## Headless Runtimes

Codex and Sapling run headless — no tmux session, no interactive TUI:

```typescript
buildDirectSpawn(opts: DirectSpawnOpts): string[];
parseEvents(stream: ReadableStream): AsyncIterable<AgentEvent>;
```

The process manager (`src/worktree/process.ts`) handles direct subprocess
lifecycle. Events flow through NDJSON stdout and are parsed by the tailer
(`src/events/tailer.ts`).

## Design Implications

### Runtime-Neutral Is Real

Overstory's runtime abstraction is not theoretical — it has 9 working
adapters. This means:

- Agent behavior is defined in markdown, not in Claude-specific APIs
- Guard rules translate to each runtime's native mechanism
- Cost tracking normalizes across runtimes
- The merge system, mail system, and watchdog are completely runtime-agnostic

### The Adapter Tax

Each adapter is ~200-400 lines. The interface is tight enough that adding
a new runtime is mechanical — implement the 8 required methods, add it to
the registry. The hardest part is readiness detection (each TUI is different).

### Mixed Fleets Are Possible

Nothing prevents running Claude builders alongside Pi scouts alongside
Codex reviewers. The orchestrator doesn't care which runtime is behind
each agent — it communicates through mail and observes through the event
store.
