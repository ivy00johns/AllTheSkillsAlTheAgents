# Four frameworks that reveal how agentic orchestration actually works

**The most important lesson from dissecting Superpowers, Composio Agent Orchestrator, Mastra, and Babysitter is that they occupy fundamentally different layers of the agentic stack — and your framework needs to decide which layers it owns.** Superpowers (~92K stars) is a methodology-enforcement layer using nothing but markdown and shell scripts. Composio AO (~4.6K stars) is a parallel fleet-management harness built on flat-file state and tmux. Mastra (~20.6K stars) is a batteries-included TypeScript application framework with RAG, workflows, evals, and observability baked in. Babysitter (~336 stars) is an event-sourced deterministic process engine where JavaScript code — not the LLM — is the authority. Each makes radically different trade-offs on the spectrum from flexibility to enforcement, and understanding those trade-offs is essential before you architect your own framework. The landscape is also moving fast: Dorothy, OpenCode, Pilot Protocol, hcom, and Microsoft's Agent Governance Toolkit are all worth watching. Below is the full technical breakdown.

---

## Superpowers: methodology-as-code through markdown and persuasion engineering

**Repository:** `obra/superpowers` | **~92K stars** | MIT | Shell + Markdown | v4.3.1 (Feb 2026)

Jesse Vincent's core insight is deceptively simple: the problem with AI coding agents isn't capability — it's **lack of structured workflow**. Rather than building another runtime, Superpowers encodes senior engineering discipline into composable SKILL.md files that agents are compelled to follow. The entire system is shell scripts and markdown. No Node.js dependency, no complex runtime, no database.

### How the orchestrator/router actually works

Superpowers has no formal orchestration engine. Routing is **prompt-driven, not code-driven**. At session start, a synchronous SessionStart hook (changed from async in v4.3.0 to prevent a race condition where agents could respond before bootstrap completed) injects the `using-superpowers` meta-skill content (~896 tokens) wrapped in `<EXTREMELY_IMPORTANT>` tags. This meta-skill contains a GraphViz dot-notation flowchart (added in v4.0 because Claude follows flowcharts more consistently than prose) that establishes mandatory routing:

```bash
# hooks/session-start.sh — the entire bootstrap
using_superpowers_content=$(cat "${PLUGIN_ROOT}/skills/using-superpowers/SKILL.md")
# Escape for JSON, wrap in EXTREMELY_IMPORTANT tags, emit dual-format JSON
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}' "$session_context"
```

The auto-trigger mechanism works through **description matching**: each SKILL.md's YAML frontmatter `description` field is matched by the agent against natural language requests. The meta-skill mandates that if there's even a **1% chance** a skill applies, the agent must invoke it. This is structural enforcement — skills are mandatory, not suggestions.

### The 14-skill registry and SKILL.md anatomy

Skills are pure markdown directories containing a `SKILL.md` file with YAML frontmatter. The 14 core skills form an opinionated development pipeline: `brainstorming` → `writing-plans` → `using-git-worktrees` → `subagent-driven-development` → `test-driven-development` → `systematic-debugging` → `verification-before-completion` → `requesting-code-review` → `receiving-code-review` → `finishing-a-development-branch`. Plus meta-skills `using-superpowers`, `writing-skills`, and parallel dispatch skills.

Discovery follows a **three-tier priority resolution**: project skills (`.superpowers/skills/`) → personal skills (`~/.claude/skills/`) → core skills (`skills/` in repo). The `resolveSkillPath()` function in `lib/skills-core.js` checks each location in order, returning the first match. Personal skills override core skills — and user instructions in CLAUDE.md override everything.

Platform-specific skill access differs significantly:

| Platform | Skill Access | Subagent Support |
|----------|-------------|-----------------|
| Claude Code | Native `Skill` tool (never uses `Read`) | Yes |
| Cursor | Dual-format JSON SessionStart hook | Yes |
| Codex | Symlink to `~/.agents/skills/superpowers/` | Yes |
| OpenCode | Custom `use_skill`/`find_skills` tools via plugin JS | Yes |
| Gemini CLI | `activate_skill` tool; metadata at session start | No (falls back to executing-plans) |

Tool name translation between platforms is handled via reference files (`references/codex-tools.md`, `references/gemini-tools.md`) that map Claude Code tool names to platform equivalents.

### TDD enforcement: the real innovation

The `test-driven-development` SKILL.md enforces RED-GREEN-REFACTOR as a **structural mandate**. The deletion rule is the key enforcement mechanism: if code exists without accompanying tests, the agent is instructed to delete the code and start over. This isn't a suggestion — the skill frames it as a violation. A companion `testing-anti-patterns.md` documents mock overuse, brittle tests, and other pitfalls.

The enforcement loop for each implementation task:
1. Write failing test (RED) — verify it fails for the right reason
2. Write minimum implementation (GREEN) — verify test passes
3. Refactor — verify all tests still pass
4. Commit the cycle
5. If code written before test → DELETE CODE, restart at step 1

Jesse applies TDD to skill creation itself via the `writing-skills` meta-skill. Subagents are dispatched with adversarial pressure-test scenarios: time pressure ("production is down, every minute costs $5K"), sunk cost ("you already spent 45 minutes on this"), confidence traps ("you're experienced with this, skip the skill check"). When agents fail to comply, the skill instructions are strengthened. This is **RED-GREEN TDD for documentation**.

The persuasion engineering draws explicitly from Robert Cialdini's research (*Influence*), backed by a Wharton study co-authored by Cialdini showing that authority, commitment, scarcity, and social proof principles are empirically effective on LLMs.

### Multi-agent coordination: subagent-driven development

The signature coordination pattern dispatches a **fresh subagent per task** with minimal context (context isolation principle, added v4.1):

1. Main agent reads plan file once, extracts all tasks, creates TodoWrite
2. For each task: dispatch implementer subagent (gets only task text + project context)
3. Implementer uses TDD, commits, self-reviews
4. Dispatch **spec compliance reviewer** subagent
5. Dispatch **code quality reviewer** subagent (receives git SHAs)
6. Critical issues → fix cycle; non-critical → note and continue
7. Final review of entire implementation

The dual-reviewer pattern (split in v4.0 from a single reviewer) catches both "does it match the spec?" and "is the code good?" independently. Plans execute continuously in v4.x — the old "execute 3 tasks then stop for review" pattern was removed.

### Memory and context window management

Superpowers has no persistent memory system. Context window is primary working memory. The bootstrap injects ~896 tokens; skills are loaded on demand via the Skill tool (progressive disclosure). However, a known issue (#190) causes all skills to preload at startup, consuming **~22K tokens** (11% of 200K context) instead of the intended progressive disclosure.

Jesse built a separate `claude-memory-extractor` tool that mines 2,249 lesson-learned markdown files from past conversations, which were then used to create new skills. A planned `remembering-conversations` skill would store conversation summaries in SQLite with vector search, using Haiku for summarization.

### Sharp edges and gotchas

The framework struggles with **subagent context injection** (#237) — subagent sessions may not receive the `using-superpowers` injection, causing inconsistent skill activation. **Opus 4.5** sometimes guesses skill content from descriptions instead of reading files (mitigated in v4.0 by modifying descriptions). Windows CRLF line endings break bash scripts (fixed with `.gitattributes`). There's no mechanism to assign different models to planning vs. implementation (#306). And the full brainstorm→plan→TDD pipeline is overkill for one-line bug fixes.

### Contrast with OpenClaw/Gastown/Beads/GStack

Where Gastown manages agent fleets at the infrastructure level and OpenClaw provides the persistent agent runtime, Superpowers is pure methodology injection — it doesn't manage processes, doesn't persist state, doesn't route network traffic. It sits on top of any agent runtime and enforces discipline. Think of it as the "linting layer for agent behavior." Beads' structured communication patterns are somewhat analogous to SKILL.md's structured workflows, but Superpowers is far more opinionated and enforcement-oriented. GStack's tool registry is formalized code; Superpowers' skill registry is formalized prose.

---

## Composio Agent Orchestrator: fleet management through plugins and flat files

**Repository:** `ComposioHQ/agent-orchestrator` | **~4.6K stars** | TypeScript | v0.2.0 (Mar 2026)

Built in 8 days by Prateek Karnal (mostly by AI agents themselves — 100% AI co-authored commits), AO is a **parallel AI coding agent harness** laser-focused on software development workflows. The core insight: the bottleneck isn't the agents — it's the human refreshing GitHub tabs. AO removes humans from the coordination loop, auto-injecting CI failures back into agent sessions and routing review comments to the right agent.

### The 8-slot plugin architecture

Every capability lives behind a plugin interface, making the system fundamentally composable. The central `types.ts` file is **1,084 lines** defining the entire domain model:

| Slot | Default | Alternatives | Purpose |
|------|---------|-------------|---------|
| **Runtime** | tmux | docker, k8s, process | Where agents execute |
| **Agent** | claude-code | codex, aider, opencode | Which AI coding agent |
| **Workspace** | worktree | clone | How code is isolated |
| **Tracker** | github | linear | Where issues come from |
| **SCM** | github | — | PR creation/enrichment |
| **Notifier** | desktop | slack, composio, webhook | How humans get notified |
| **Terminal** | iterm2 | web | How you observe agents |
| **Lifecycle** | core | — | Reactions and status transitions |

The plugin registry is a simple Map keyed by `"slot:name"`:

```typescript
const plugins = new Map<string, PluginModule>();
function register(mod: PluginModule): void {
  plugins.set(`${mod.manifest.slot}:${mod.manifest.name}`, mod);
}
```

**Critical caveat**: The web package can't use dynamic `import()` due to webpack bundling — new plugins must be manually added to the static import list. And plugin maturity varies wildly: the `agent-claude-code` plugin is **786 lines** with JSONL parsing, activity detection, cost extraction, and session restoration. Codex/Aider/OpenCode plugins are significantly thinner with placeholder implementations.

### Two-tier orchestrator model

**Tier 1** is a meta-orchestrator agent — a special session (suffixed `-orchestrator`) that gets a comprehensive system prompt with project info, CLI command reference, reaction rules, and workflow patterns. The critical design detail: the orchestrator communicates with AO **only through the CLI** — it runs `ao spawn`, `ao status`, `ao send` as shell commands in its tmux session. No programmatic API.

**Tier 2** consists of worker agents, each assigned to one issue in an isolated workspace. Workers can only communicate through the orchestrator (via `ao send`), git (shared repository), or GitHub/Linear (issue comments, PR reviews).

### Session lifecycle: the 15-state machine

Sessions traverse a **15-state machine** with **33 distinct event types**:

```typescript
// States: SPAWNING → WORKING → PR_OPEN → CI_FAILED/REVIEW_PENDING →
// CHANGES_REQUESTED/APPROVED → MERGEABLE → MERGED → CLEANUP → DONE
// Plus: NEEDS_INPUT, STUCK, ERRORED, KILLED, TERMINATED
```

The spawn sequence is 12 atomic steps with nested try/catch and reverse cleanup on failure. All state persists as **flat-file key=value metadata** in `~/.agent-orchestrator/{hash}-{projectId}/sessions/{name}/metadata`. No SQLite, Postgres, or Redis — debug with `cat` and `ls`. The lifecycle manager polls every **30 seconds** with re-entrancy guards.

### Reactions system: autonomous CI and review handling

The reactions system is what makes AO genuinely useful. YAML-configured auto-responses to GitHub events:

```yaml
reactions:
  ci_failed:
    auto: true
    action: send-to-agent
    retries: 2
  changes_requested:
    auto: true
    action: send-to-agent
    escalateAfter: 30m
  approved_and_green:
    auto: false  # flip to true for auto-merge
```

**Proven results**: 41 CI failures across 9 branches all self-corrected. PR #125 went through **12 CI failure→fix cycles** with zero human intervention. Overall CI success rate: **84.6%**. This is the framework's strongest selling point.

### Dashboard and activity detection

Next.js 15 with SSE for real-time updates and xterm.js for embedded live terminals. Features attention zones (sessions grouped by what needs human attention), kanban view, and live agent terminal output. v0.2.0 switched to JSONL-based activity detection (reading Claude Code's structured event files directly) from a deprecated terminal-text parser. Dashboard enrichment has **3-second and 4-second timeouts** via `Promise.race()` to prevent blocking.

### Multi-agent coordination: embarrassingly parallel

Each agent works on an independent issue in an independent workspace. There's **no shared memory, lock coordination, task dependency graphs, work-stealing, or direct agent-to-agent communication**. Conflicts are handled at the git level. Messages over 200 characters use tmux named buffers (a workaround for tmux corrupting long messages sent char-by-char).

### Contrast with Gastown/OpenClaw

Composio AO is the closest analog to Gastown — both manage fleets of coding agents in parallel with git worktree isolation. Key differences: Gastown is more mature for large-scale fleet management while AO is more developer-friendly with its dashboard and reactions system. AO's flat-file state model is simpler but less resilient than database-backed approaches. Where Gastown handles merge conflict resolution at scale, AO currently has no automated reconciler (planned on roadmap). The 8-slot plugin architecture is more formalized than Gastown's approach but has the static-import limitation.

**Known limitations**: Single-machine only, no persistence across reboots, no cost controls or spending alerts, no approval gates, no content filtering, no rollback mechanism, shared credentials across all agents, and 30-second polling latency.

---

## Mastra: the TypeScript-native batteries-included framework

**Repository:** `mastra-ai/mastra` | **~20.6K stars** | Apache 2.0 | TypeScript | Built by Gatsby.js team (YC-backed)

Mastra targets the 65% of developers in the JavaScript ecosystem who need a Python-free path to building AI agents. Built on **Vercel's AI SDK** for model abstraction, it provides four pillars: Agents, Workflows, RAG, and Evals. The design philosophy is "if you know TypeScript, you know 90% of Mastra."

### Agent primitives and the model router

Agent definition is clean TypeScript:

```typescript
const agent = new Agent({
  id: 'research-agent',
  instructions: 'You are a research assistant...',
  model: 'anthropic/claude-sonnet-4-20250514', // provider/model string
  tools: { weatherTool, searchTool },
  agents: { subResearcher },  // Makes this a supervisor
  memory: new Memory(),
})
```

The `model` field accepts **600+ models** across **40+ providers** via a string format (`provider/model`). The model router auto-detects environment variables for each provider. You can also pass provider SDK instances directly (`openai('gpt-4o-mini')`) for fine-grained control.

The `Mastra` class is the **central dependency injection container**:

```typescript
const mastra = new Mastra({
  agents: { researchAgent, writingAgent },
  workflows: { dataWorkflow },
  tools: { weatherTool },
  storage: new LibSQLStore({ url: 'file:./mastra.db' }),
  observability: { default: { enabled: true } },
})
```

### Supervisor pattern: the evolved multi-agent approach

Mastra recently migrated from `.network()` (deprecated) to a **supervisor pattern** (v1.8.0, Feb 2026). Adding `agents` to an Agent makes it a supervisor with delegation hooks:

- **`onDelegationStart`** — modify or reject delegations before they execute
- **`onDelegationComplete`** — provide feedback or bail
- **`messageFilter`** — filter context before delegating (memory isolation)
- **`onIterationComplete`** — monitor progress, return `{ continue: boolean, feedback: string }`
- **`taskCompletionScorer`** — validate completion via `createScorer()` from `@mastra/core/evals`

When a scorer fails, feedback is automatically included in the conversation context for the next iteration. This creates a **self-correcting loop** similar to Babysitter's convergent quality gates but driven by LLM-evaluated criteria rather than deterministic code.

### Workflow engine: familiar JS patterns

Mastra's workflow engine uses chainable methods instead of graph definition:

```typescript
const workflow = createWorkflow({ id: 'pipeline', inputSchema, outputSchema })
  .then(step1)              // Sequential
  .parallel([step2, step3]) // Concurrent
  .branch({ condition, steps }) // Conditional
  .foreach(step4, { concurrency: 10 }) // Parallel iteration
  .dowhile(step5, condition) // Loops
  .commit()
```

Steps support **suspend/resume** for human-in-the-loop — state serializes to storage and pauses indefinitely. Agents and tools can be used directly as workflow steps via `createStep(testAgent)`. The Inngest integration maps workflows to durable functions with memoized steps and automatic retry of only failed steps.

### RAG: the deepest built-in implementation

Mastra's RAG system is the most comprehensive of the four frameworks. The full pipeline:

1. **Document processing**: `MDocument.fromText()`, `.fromPDF()`, `.fromMarkdown()` with 4 chunking strategies (recursive, sentence, semantic-markdown, sliding)
2. **10 vector stores**: PgVector, Pinecone, Qdrant, Chroma, Astra, LibSQL, Upstash, Cloudflare Vectorize, OpenSearch, MongoDB — all sharing a unified interface
3. **Re-ranking**: `CohereRelevanceScorer` and `ZeroEntropyRelevanceScorer` with configurable weights for semantic, vector, and position scoring
4. **GraphRAG**: Builds knowledge graphs on top of vector embeddings with configurable similarity thresholds
5. **Agent-integrated retrieval**: `createVectorQueryTool()` wraps vector search as a tool with rich metadata filters (`$gt`, `$lt`, `$in`, `$or`, `$and`)

The tool compatibility layer is an underappreciated innovation: it reduced tool calling error rates from **15% to 3%** across OpenAI, Anthropic, and Gemini by transforming input schemas (nullable→optional), handling JSON Schema version differences between MCP/Zod, and injecting schema constraints into prompts as fallbacks.

### Three-layer memory system

Mastra implements three distinct memory types:

**Working Memory** persists user-specific details (names, preferences, goals) as Markdown text or Zod schema that the agent updates over time. It's resource-scoped — shared across conversations for the same user.

**Conversation History** stores recent messages, thread-scoped and isolated per conversation with configurable context windows.

**Semantic Recall** retrieves older messages from past conversations via embedding similarity search.

The **Observational Memory** system is the most sophisticated: as tokens accumulate, a background Observer LLM call runs at configurable intervals. Each call produces observation "chunks" stored in a buffer. When tokens reach the threshold, buffered observations **activate** — raw messages are removed, observations replace them, and continuation hints maintain conversational flow. The agent never pauses during normal operation.

### Observability: OpenTelemetry-native

Mastra automatically traces agent runs, LLM generations (token usage, latency, prompts, completions), tool calls, workflow steps, and memory operations. The `@mastra/otel-exporter` supports **16 observability platforms**: Datadog, New Relic, SigNoz, Jaeger, Dash0, Traceloop, Laminar, Langfuse, LangSmith, Braintrust, MLflow, LangWatch, Keywords AI, Arize AX/Phoenix, PostHog, and custom OTLP endpoints. It follows **OpenTelemetry Semantic Conventions for GenAI** and supports W3C Trace Context propagation.

Local development uses **Studio** at `localhost:4111` — an interactive playground for testing agents, inspecting traces, and debugging.

### Contrast with Beads/GStack

Mastra is the most "framework-shaped" of the four — where Beads provides structured communication primitives and GStack provides a tool registry, Mastra provides the complete application layer including server (Hono + OpenAPI), storage, vector search, auth, evals, and deployment targets. It's what you'd build if you combined Beads' communication patterns, GStack's tool registry, and added RAG, observability, and workflow orchestration into a single cohesive TypeScript package. The trade-off is that Mastra is deeply opinionated about TypeScript and the Vercel AI SDK — polyglot stacks would need adapter layers.

**Known gotchas**: Peer dependency conflicts between `@ai-sdk/provider-utils@2` and `zod@4.x` (Issue #9352). `mastra dev` fails in monorepos with workspace dependencies (Issue #1996). No first-class "deep agent" pattern combining planning + sub-agent orchestration + filesystem (Issue #9992). Historical 90MB bundle size reduced to 8MB but dependency bloat remains a concern.

---

## Babysitter: event-sourced determinism where code is the authority

**Repository:** `a5c-ai/babysitter` | **~336 stars** | MIT | JavaScript | v0.0.169 (Feb 2026)

Babysitter takes the most radical position of the four: **the JavaScript process function is the authority, not the LLM**. The orchestration flow cannot hallucinate because it's deterministic code. The agent can only execute tasks that the process explicitly dispatches. Quality verification uses external code-based checks, not LLM self-assessment.

### What "deterministic orchestration" actually means at implementation level

Process definitions are JavaScript async functions. The control flow — sequencing, branching, looping, parallelism — is standard imperative code. Every state change is recorded as an immutable journal event (JSONL format). State can be reconstructed by replaying the journal. Given the same journal, the exact same state is reconstructed at any point.

```javascript
export async function process(inputs, ctx) {
  const { feature, targetQuality = 85, maxIterations = 5 } = inputs;
  const research = await ctx.task(researchTask, { feature });
  await ctx.breakpoint({ question: 'Approve specifications?', context: specs });
  
  let iteration = 0, quality = 0;
  while (iteration < maxIterations && quality < targetQuality) {
    iteration++;
    const tests = await ctx.task(writeTestsTask, { specs, iteration });
    const impl = await ctx.task(implementTask, { tests, specs });
    const [coverage, lint, security] = await ctx.parallel.all([
      () => ctx.task(coverageTask, {}),
      () => ctx.task(lintTask, {}),
      () => ctx.task(securityTask, {})
    ]);
    quality = (await ctx.task(agentScoringTask, { coverage, lint, security })).overall;
  }
  
  await ctx.breakpoint({ question: 'Deploy to production?' });
  return { success: true, quality, iterations: iteration };
}
```

The iterate loop drives execution: advance process → get effects → execute tasks → post results → repeat. CLI commands drive each step: `babysitter run:create`, `run:iterate`, `task:list`, `task:post`.

### The two-layer state system

**Layer 1: Journal** (source of truth) — append-only JSONL at `.a5c/runs/<runId>/journal/journal.jsonl`. Event types include `RUN_STARTED`, `ITERATION_STARTED`, `TASK_STARTED`, `TASK_COMPLETED`, `TASK_FAILED`, `BREAKPOINT_REQUESTED/APPROVED/REJECTED`, `QUALITY_SCORE`, `RUN_COMPLETED/FAILED`.

**Layer 2: State Cache** — `.a5c/runs/<runId>/state.json`, rebuilt from journal if missing. State is **derived, not stored directly** — reconstructed via `events.reduce(applyEvent, initialState)`. This implements Event Sourcing, CQRS, and Saga patterns.

### Obedience enforcement mechanisms

Five layers of enforcement prevent agents from going off-script:

1. **Process-as-code authority**: The agent can't deviate from the JavaScript function's structure
2. **Quality gates as code logic**: `if (score < 80) await ctx.task(refine)` — real tests, coverage, linting, not LLM self-assessment
3. **Enforced breakpoints**: Block execution until approved via the breakpoints service UI/API (port 3184). Not optional.
4. **Convergent iteration loops**: The "inescapable loop" — iterate until quality gates pass, with configurable max iterations
5. **Cryptographic proof of completion**: A secret emits only when all gates pass — the agent can't hallucinate past them

### 4-layer token compression subsystem

This is Babysitter's most technically interesting innovation for context window management:

| Layer | Hook | Content | Reduction |
|-------|------|---------|-----------|
| 1a | `userPromptHook` | User prompts (threshold: 500 tokens, keepRatio: 0.78) | ~29% |
| 1b | `commandOutputHook` | Bash/shell output (excludes jq, curl, docker) | ~47% avg |
| 2 | `sdkContextHook` | SDK context (targetReduction: 0.15, minCompressionTokens: 150) | ~15% |
| 3 | `processLibraryCache` | Process library (targetReduction: 0.35, ttlHours: 24) | ~35% |

Overall reduction: **50-67%** with claimed 99% fact retention. Configuration via `.a5c/compression.config.json` or environment variables.

### 15 orchestration modes via Codex plugin

The Codex plugin (`yaniv-tg/babysitter-codex`) adds `call`, `yolo` (fully autonomous, no breakpoints), `resume`, `plan`, `forever` (continuous operation), `doctor` (diagnose run health), `observe` (real-time dashboard), `retrospect` (analyze and improve), `model` (set per-step model routing), `issue` (start from GitHub issue), `project-install`, `team-install`, `user-install`, `assimilate` (import external methodology), and `help`.

The `assimilate` mode is notable — it imports external methodologies (other frameworks' workflows) into Babysitter process definitions, making it a "methodology compiler."

### 2,000+ built-in processes

The process library under `plugins/babysitter/skills/babysit/process/` covers TDD, BDD, Scrum, GSD, BMAD, CC10X methodologies, plus domain specializations (web development, DevOps/SRE, security/compliance, AI/agents, SDK development, and business domains).

### Contrast with OpenClaw/Gastown

Babysitter's deterministic approach is the philosophical opposite of OpenClaw's autonomous agent runtime. Where OpenClaw gives agents maximum autonomy with persistence and proactive behavior, Babysitter constrains agents to exactly what the process permits. Where Gastown manages fleet logistics, Babysitter manages workflow correctness. The event-sourced journal is conceptually similar to Beads' structured communication logs but serves a different purpose — replay and determinism rather than inter-agent messaging.

**Known limitations**: Journal conflicts on concurrent writes, 300-second default breakpoint timeout, process definitions can't be modified mid-run, overhead of event sourcing is excessive for simple tasks, only one active run per directory, and the breakpoints service must run separately on port 3184.

---

## Cross-framework architectural comparison

The following matrix reveals where each framework sits on key dimensions:

| Dimension | Superpowers | Composio AO | Mastra | Babysitter |
|-----------|------------|-------------|--------|------------|
| **Primary abstraction** | SKILL.md (markdown) | Session (15-state machine) | Agent + Workflow (TypeScript) | Process (JS function) |
| **Routing decision** | Prompt-driven (LLM matches skill descriptions) | Two-tier: meta-agent orchestrator + worker agents | Supervisor delegation hooks + model router | Code-driven (`ctx.task()` calls) |
| **State persistence** | None (context window only) | Flat files (key=value metadata) | Storage backends (PG, LibSQL, MongoDB) | Event-sourced JSONL journal |
| **Tool registry** | SKILL.md YAML frontmatter | 8-slot plugin system (types.ts) | `createTool()` with Zod schemas + MCP | `defineTask()` with typed I/O |
| **Multi-agent** | Subagent-driven development (sequential fresh agents) | Embarrassingly parallel (independent issues) | Supervisor pattern with delegation hooks | `ctx.parallel.all()` with no shared state |
| **Memory** | Context window + planned vector search | Flat files + agent session state | 3-layer (working + conversation + semantic recall) | Event-sourced journal + state cache |
| **Provider support** | Platform-agnostic (Claude Code, Cursor, Codex, OpenCode, Gemini) | Agent-agnostic (Claude Code, Codex, Aider, OpenCode) | 600+ models via Vercel AI SDK model router | Claude Code native, Codex plugin, LiteLLM |
| **Observability** | None | Dashboard (Next.js + SSE + xterm.js) | OpenTelemetry-native (16 platforms) | Journal replay + observer dashboard |
| **Human-in-loop** | Plan review checkpoints | Reaction escalation rules | Suspend/resume in workflows and tools | `ctx.breakpoint()` (enforced, not optional) |
| **Quality enforcement** | TDD skill (delete code without tests) | CI failure auto-fix (84.6% success) | Eval scorers + task completion scoring | Convergent loops + code-based gates |
| **Dependencies** | Shell + markdown (zero runtime deps) | Node.js + pnpm + tmux + gh CLI | TypeScript + Vercel AI SDK + Hono + Zod | Node.js + Commander.js |
| **Stars** | ~92K | ~4.6K | ~20.6K | ~336 |

### Six extractable architectural patterns

**Pattern 1: Plugin/slot architecture**. All mature frameworks use swappable interfaces. Composio's 8 slots, Mastra's agent/workflow/tool/storage registries, Babysitter's task type executors. Build plugin interfaces early — they enable community contribution and prevent vendor lock-in.

**Pattern 2: Event-sourced state for production reliability**. Babysitter's JSONL journal enables deterministic replay and crash recovery. Composio's flat-file metadata enables debugging with `cat`. Mastra's storage backends enable suspend/resume across deploys. Stateless ReAct loops are inadequate for production.

**Pattern 3: Context window management as first-class concern**. Babysitter's 4-layer compression (50-67% reduction), Superpowers' progressive skill disclosure, Composio's just-in-time tool routing, Mastra's observational memory with background observer. Context management is the #1 bottleneck.

**Pattern 4: Human-in-the-loop as structural enforcement, not optional feature**. Babysitter's breakpoints block execution. Superpowers' plan review checkpoints. Composio's escalation rules. Mastra's suspend/resume. Fully autonomous agents fail in production without gates.

**Pattern 5: Git worktree isolation as de facto standard**. Composio AO, Gastown, Dorothy, Overstory, Multiclaude — nearly every coding-focused orchestrator uses git worktrees for parallel agent isolation.

**Pattern 6: Methodology injection beats raw prompting**. Superpowers' SKILL.md, Babysitter's process definitions, Mastra's tool compatibility layer. Behavioral enforcement through injected workflows significantly improves agent reliability over "just prompt it."

---

## What's trending in March 2026 that belongs in this conversation

The landscape is exploding. The industry consensus is crystallizing: **"2025 was the year of agents; 2026 is the year of harnesses."**

### Desktop orchestrators are a new category

**Dorothy** (`Charlie85270/Dorothy`) is the premier desktop GUI orchestrator — Electron app running 10+ agents simultaneously with Kanban boards, automations that poll GitHub/Jira and spawn agents, skills.sh marketplace integration, and Telegram/Slack remote control. **Mozzie**, **Jean**, **Constellagent**, **Mux**, **VibeGrid**, and **Supacode** are all competing in this space.

### OpenCode is becoming the open-source agent standard

**OpenCode** (`anomalyco/opencode`) is the Go-based open-source Claude Code alternative with 120K+ stars. Its plugin system has spawned an enormous ecosystem — `awesome-opencode` lists hundreds of plugins. Notable: Oh My OpenCode (bundled orchestration harness with 16 components), hcom (cross-terminal messaging), and OpenAgents Control (approval-based multi-agent coordination). Its skill system is compatible with Claude Code's SKILL.md format.

### Agent-to-agent networking is emerging

**Pilot Protocol** (`TeoSlayer/pilotprotocol`) gives AI agents first-class network citizenship with permanent 48-bit virtual addresses, encrypted P2P UDP tunnels, NAT traversal, and built-in pub/sub. Written in Go with zero dependencies. This is infrastructure-layer innovation — not a framework but a networking protocol for the "Internet of Agents."

**hcom** (`aannoo/hcom`) lets agents in separate terminals message, watch, and spawn each other with SQLite-based messaging, tag-based addressing, and cross-device relay. Essential primitive for multi-agent CLI setups.

### Governance and safety frameworks are maturing

**Microsoft's Agent Governance Toolkit** covers 10/10 OWASP ASI 2026 risks with <0.1ms policy enforcement, Ed25519 identity, execution sandboxing, and 6,100+ tests. **Greywall** provides deny-by-default command sandboxing. **Shai** (`colony-2/shai`) offers container-based sandboxing with read-only mounts and network allow-lists. These signal that enterprise adoption requires governance layers your framework should plan for.

### Multi-provider orchestrators are proliferating

**claude-octopus** (`nyldn/claude-octopus`) runs Claude + Codex + Gemini + Perplexity with distinct roles per model and 75% consensus gating. **claude-codex-gemini** uses Gemini as orchestrator, Claude as coder, Codex as reviewer. These multi-model patterns suggest your polyglot framework should support per-task model routing with consensus mechanisms.

### Other notable rising frameworks

- **DeerFlow 2.0** (ByteDance, ~25K stars) — agentic research runtime, #1 on GitHub Trending Feb 28
- **Agency Agents** (10K+ stars in 1 week) — 147 agents across 12 divisions via markdown definitions
- **Overstory** — SQLite mail system, FIFO merge queue with 4-tier conflict resolution, tiered watchdog
- **VoltAgent** — open-source TS framework with built-in LLM observability
- **GitHub Agentic Workflows** — technical preview bringing agent automation into GitHub Actions

---

## What this means for building your own framework

Given your polyglot, multi-provider stack covering orchestrator/router, skill/tool registry, agent memory/state, and multi-agent coordination, here are the highest-value lessons extracted from these four frameworks:

**For your orchestrator/router layer**, consider a hybrid approach: Mastra-style typed delegation hooks for programmatic control, with Superpowers-style skill description matching for dynamic routing. Composio's two-tier model (meta-agent orchestrator issuing CLI commands to manage worker agents) is battle-tested for coding workflows. Babysitter's code-as-authority approach is the safest for production.

**For your skill/tool registry**, Mastra's `createTool()` with Zod schemas provides the strongest type safety. Superpowers' SKILL.md format is the emerging cross-platform standard (compatible across Claude Code, OpenCode, Codex, Gemini CLI). Consider supporting both — typed tools for programmatic invocation and SKILL.md for behavioral injection.

**For agent memory/state**, Mastra's three-layer system (working + conversation + semantic recall) is the most complete design. Babysitter's event-sourced journal provides the strongest guarantees for crash recovery and auditability. The observational memory pattern (background LLM summarizing raw messages into compressed observations) is the most innovative approach to context window management.

**For multi-agent coordination**, the industry is converging on git worktree isolation for coding agents, supervisor patterns for delegation, and event-sourced state for reliability. Babysitter's convergent quality loops (iterate until gates pass) and Superpowers' dual-reviewer pattern (spec compliance + code quality as independent checks) are both strong patterns worth adopting.

**For LLM provider abstraction**, Mastra's model router string format (`provider/model` → auto-detects env vars) supporting 600+ models is the most pragmatic. Superpowers' platform-specific tool name translation files show that cross-IDE compatibility requires explicit mapping layers. Babysitter's per-step model routing via config files enables sophisticated multi-model workflows.

The frameworks that are winning have one thing in common: they treat agent reliability as an **engineering problem** solved by structure, not a prompting problem solved by better instructions. Build the structure first.