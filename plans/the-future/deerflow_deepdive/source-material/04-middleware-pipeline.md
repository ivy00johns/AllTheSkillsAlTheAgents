# 04 — Middleware Pipeline

## What It Does

The middleware pipeline is a 14-stage ordered interceptor chain that wraps every aspect of agent execution. Each middleware extends LangChain's `AgentMiddleware` base class and implements one or more hooks: `before_agent`, `after_agent`, `before_model`/`abefore_model`, `after_model`/`aafter_model`, `wrap_model_call`/`awrap_model_call`, `wrap_tool_call`/`awrap_tool_call`. The pipeline runs in registration order for before/wrap hooks and reverse order for after hooks, giving the first-registered middleware the outermost position in the call stack.

Five middleware stages are always active. Nine more are conditionally included based on runtime configuration (model capabilities, feature flags, plan mode). At maximum capacity all 14 run.

## How It Works

### Stage-by-Stage Reference

| # | Middleware | Hook(s) | Condition | Purpose |
|---|-----------|---------|-----------|---------|
| 1 | ThreadDataMiddleware | before_agent | always | Per-thread filesystem dirs |
| 2 | UploadsMiddleware | before_agent | lead agent only | Inject `<uploaded_files>` context |
| 3 | SandboxMiddleware | before_agent, after_agent | always | Acquire/release sandbox |
| 4 | DanglingToolCallMiddleware | wrap_model_call | lead agent only | Patch orphaned tool calls |
| 5 | ToolErrorHandlingMiddleware | wrap_tool_call | always | Catch tool exceptions |
| 6 | SummarizationMiddleware | wrap_model_call | if enabled in config | Compress long histories |
| 7 | TodoMiddleware | before_model | if plan_mode | Re-inject truncated todo list |
| 8 | TitleMiddleware | after_model | always | Auto-generate thread title |
| 9 | MemoryMiddleware | after_agent | always | Queue async memory extraction |
| 10 | ViewImageMiddleware | before_model | if model supports vision | Inject base64 images |
| 11 | DeferredToolFilterMiddleware | wrap_model_call | if tool_search enabled | Hide deferred tool schemas |
| 12 | SubagentLimitMiddleware | after_model | if subagent_enabled | Truncate excess task calls |
| 13 | LoopDetectionMiddleware | after_model | always | Detect repetitive tool loops |
| 14 | ClarificationMiddleware | wrap_tool_call | always (must be last) | Intercept clarification requests |

### 1. ThreadDataMiddleware

**File:** `backend/packages/harness/deerflow/agents/middlewares/thread_data_middleware.py`
**Hook:** `before_agent`

Creates per-thread filesystem paths for workspace, uploads, and outputs directories under `{base_dir}/threads/{thread_id}/user-data/`. With `lazy_init=True` (default) it only computes paths; with `lazy_init=False` it eagerly creates directories via `Paths.ensure_thread_dirs()`. Writes a `thread_data` dict into state containing `workspace_path`, `uploads_path`, and `outputs_path`. Raises `ValueError` if `thread_id` is missing from runtime context.

### 2. UploadsMiddleware

**File:** `backend/packages/harness/deerflow/agents/middlewares/uploads_middleware.py`
**Hook:** `before_agent`

Reads file metadata from the last `HumanMessage`'s `additional_kwargs.files` (populated by the frontend after upload). Scans the thread's physical uploads directory for historical files not in the current message. If any files exist, prepends an `<uploaded_files>` XML block to the last human message content listing filenames, sizes, and virtual paths (`/mnt/user-data/uploads/{filename}`). Validates filenames (rejects path traversal), checks physical file existence, and preserves `additional_kwargs` on the updated message so the frontend can read structured metadata from the stream. Only included for lead agents (not subagents).

### 3. SandboxMiddleware

**File:** `backend/packages/harness/deerflow/sandbox/middleware.py`
**Hooks:** `before_agent`, `after_agent`

Manages sandbox lifecycle per thread. With `lazy_init=True` (default) sandbox acquisition is deferred until the first tool call. With `lazy_init=False` it acquires eagerly in `before_agent` by calling `SandboxProvider.acquire(thread_id)`. The `after_agent` hook releases the sandbox via `SandboxProvider.release(sandbox_id)`, checking both state and runtime context for the sandbox ID. Sandboxes are reused across turns within the same thread; final cleanup happens at application shutdown.

### 4. DanglingToolCallMiddleware

**File:** `backend/packages/harness/deerflow/agents/middlewares/dangling_tool_call_middleware.py`
**Hook:** `wrap_model_call` / `awrap_model_call`

Fixes message history corruption caused by interrupted tool calls (user cancellation, timeouts). Scans for `AIMessage`s whose `tool_calls` have no corresponding `ToolMessage` in the history. Inserts synthetic `ToolMessage(status="error", content="[Tool call was interrupted and did not return a result.]")` immediately after the offending `AIMessage`. Uses `wrap_model_call` (not `before_model`) so patches are positionally correct -- `before_model`'s `add_messages` reducer would append patches to the end instead of interleaving them. Only included for lead agents.

### 5. ToolErrorHandlingMiddleware

**File:** `backend/packages/harness/deerflow/agents/middlewares/tool_error_handling_middleware.py`
**Hook:** `wrap_tool_call` / `awrap_tool_call`

Catches exceptions during tool execution and converts them to `ToolMessage(status="error")` so the run can continue. Error detail is truncated to 500 characters. The error message includes the tool name, exception class, and detail, plus a prompt to continue with available context or choose an alternative tool. Critically, `GraphBubbleUp` exceptions are re-raised rather than caught -- these are LangGraph control-flow signals (interrupt, pause, resume) that must propagate. This file also exports `build_lead_runtime_middlewares()` and `build_subagent_runtime_middlewares()`, the shared base builders.

### 6. SummarizationMiddleware

**Import:** `from langchain.agents.middleware import SummarizationMiddleware` (LangChain built-in)
**Hook:** `wrap_model_call`

Compresses message history when a configured threshold is exceeded. Triggers are configurable as `fraction` (e.g., 0.8 = 80% of model's max input tokens), `tokens` (absolute count), or `messages` (message count) -- multiple triggers can be combined (any-of). After triggering, it summarizes older messages and retains only the `keep` amount (default: 20 messages). Uses a lightweight model for summarization (configurable via `model_name`). Trimming before summarization is capped at `trim_tokens_to_summarize` (default 4000). Disabled by default (`enabled: false`); configured via `SummarizationConfig`.

### 7. TodoMiddleware

**File:** `backend/packages/harness/deerflow/agents/middlewares/todo_middleware.py`
**Hook:** `before_model` / `abefore_model`

Extends LangChain's `TodoListMiddleware` with context-loss detection. When `SummarizationMiddleware` truncates the message history, the original `write_todos` tool call and its `ToolMessage` can scroll out of the active context window, causing the model to lose awareness of the todo list. This middleware checks three conditions in `before_model`: (1) todos exist in state, (2) no `write_todos` tool call is visible in messages, (3) no reminder has already been injected. If all three hold, it injects a `HumanMessage(name="todo_reminder")` wrapped in `<system_reminder>` tags listing all todo items with their statuses. Only active when `is_plan_mode=True` in the runtime config. The system prompt and tool description are customized with detailed usage guidance.

### 8. TitleMiddleware

**File:** `backend/packages/harness/deerflow/agents/middlewares/title_middleware.py`
**Hook:** `after_model` / `aafter_model`

Auto-generates a thread title after the first complete user-assistant exchange. Checks: (1) title generation is enabled in config, (2) no title exists in state yet, (3) exactly one user message and at least one assistant message. Builds a prompt from the first 500 chars of each, calls a lightweight model (configured via `TitleConfig.model_name`) with `thinking_enabled=False`, strips quotes, and truncates to `max_chars`. Falls back to truncated user message or "New Conversation" on failure. Always included.

### 9. MemoryMiddleware

**File:** `backend/packages/harness/deerflow/agents/middlewares/memory_middleware.py`
**Hook:** `after_agent`

Queues the conversation for async memory extraction after agent execution. Filters messages to keep only human messages and final AI messages (no tool messages, no AI messages with `tool_calls`). Strips `<uploaded_files>` blocks from human messages since file paths are session-scoped and must not persist in long-term memory. If a human message is entirely upload bookkeeping (nothing remains after stripping), that turn and its paired assistant response are both dropped. The filtered conversation is added to a `MemoryQueue` which uses a 30-second debounce (configurable, range 1-300s) to batch multiple updates. Supports per-agent memory storage via `agent_name` parameter. Always included.

### 10. ViewImageMiddleware

**File:** `backend/packages/harness/deerflow/agents/middlewares/view_image_middleware.py`
**Hook:** `before_model` / `abefore_model`

Injects base64 image data as a multi-content `HumanMessage` before LLM calls when `view_image` tool calls have completed. Checks: (1) the last `AIMessage` contains `view_image` tool calls, (2) all tool calls in that message have corresponding `ToolMessage`s, (3) no image-details message has already been injected after that `AIMessage`. Reads from `viewed_images` state (keyed by path, containing `mime_type` and `base64`), constructs mixed-content blocks with `image_url` entries using data URIs. Only included when the resolved model's config has `supports_vision=True`.

### 11. DeferredToolFilterMiddleware

**File:** `backend/packages/harness/deerflow/agents/middlewares/deferred_tool_filter_middleware.py`
**Hook:** `wrap_model_call` / `awrap_model_call`

Hides deferred tool schemas from model binding to save context tokens. When `tool_search` is enabled, MCP tools are registered in the `DeferredToolRegistry` and available to `ToolNode` for execution, but their schemas should not be sent to the LLM via `bind_tools`. This middleware filters `request.tools` to remove any tool whose name appears in the deferred registry's entries. The model discovers deferred tools at runtime via the `tool_search` tool. Only included when `app_config.tool_search.enabled` is true.

### 12. SubagentLimitMiddleware

**File:** `backend/packages/harness/deerflow/agents/middlewares/subagent_limit_middleware.py`
**Hook:** `after_model` / `aafter_model`

Truncates excess `task` tool calls from a single model response. When the LLM generates more parallel `task` tool calls than `max_concurrent`, only the first N are kept and the rest are dropped. The limit is clamped to `[2, 4]` (constants `MIN_SUBAGENT_LIMIT` / `MAX_SUBAGENT_LIMIT`), with a default of `MAX_CONCURRENT_SUBAGENTS` (3, imported from `deerflow.subagents.executor`). Modifies the last `AIMessage` in-place via `model_copy(update={"tool_calls": truncated})`. Only included when `subagent_enabled=True` in runtime config.

### 13. LoopDetectionMiddleware

**File:** `backend/packages/harness/deerflow/agents/middlewares/loop_detection_middleware.py`
**Hook:** `after_model` / `aafter_model`

Detects and breaks repetitive tool call loops as a P0 safety mechanism. After each model response, hashes the tool calls (name + args, order-independent via sorted normalization, MD5 truncated to 12 hex chars). Tracks hashes in a per-thread sliding window (default size 20). At `warn_threshold` (default 3) identical occurrences: injects a `SystemMessage` warning the model to stop repeating and produce a final answer (once per unique hash). At `hard_limit` (default 5): strips all `tool_calls` from the `AIMessage` and appends a forced-stop notice to the content. Per-thread tracking uses `OrderedDict` for LRU eviction at `max_tracked_threads` (default 100). Thread-safe via `threading.Lock`. Includes a `reset()` method for clearing per-thread or global tracking state. Always included.

### 14. ClarificationMiddleware

**File:** `backend/packages/harness/deerflow/agents/middlewares/clarification_middleware.py`
**Hook:** `wrap_tool_call` / `awrap_tool_call`

Intercepts `ask_clarification` tool calls and interrupts execution to present questions to the user. When the model calls `ask_clarification`, the middleware extracts the question, clarification type, context, and options from the tool call args. Formats a user-friendly message with type-specific icons. Returns a `Command(update={"messages": [tool_message]}, goto=END)` that adds the formatted `ToolMessage` to history and routes to `__end__`, interrupting the agent loop. Non-clarification tool calls pass through to the original handler. Always included and must be last in the chain.

## Pipeline Assembly

The pipeline is assembled in `_build_middlewares()` at `backend/packages/harness/deerflow/agents/lead_agent/agent.py` (lines 207-259).

**Step 1 -- Base runtime middlewares** via `build_lead_runtime_middlewares(lazy_init=True)`:
Returns `[ThreadDataMiddleware, UploadsMiddleware, SandboxMiddleware, DanglingToolCallMiddleware, ToolErrorHandlingMiddleware]`. `UploadsMiddleware` is inserted at index 1 (between ThreadData and Sandbox). Subagents use `build_subagent_runtime_middlewares()` which excludes `UploadsMiddleware` and `DanglingToolCallMiddleware`.

**Step 2 -- Conditional middleware** appended in fixed order:
- `SummarizationMiddleware` -- if `summarization_config.enabled` is true
- `TodoMiddleware` -- if `config.configurable.is_plan_mode` is true
- `TitleMiddleware` -- always
- `MemoryMiddleware` -- always (receives `agent_name` for per-agent storage)
- `ViewImageMiddleware` -- if `model_config.supports_vision` is true
- `DeferredToolFilterMiddleware` -- if `app_config.tool_search.enabled` is true
- `SubagentLimitMiddleware` -- if `config.configurable.subagent_enabled` is true (reads `max_concurrent_subagents`, default 3)

**Step 3 -- Safety and control flow** (always last):
- `LoopDetectionMiddleware` -- always
- `ClarificationMiddleware` -- always, explicitly documented as "should always be last"

The assembled list is passed to `create_agent(middleware=...)`.

### Lead Agent vs Subagent Pipelines

The two builder functions produce different middleware stacks:

| Middleware | Lead Agent | Subagent |
|-----------|-----------|----------|
| ThreadDataMiddleware | yes | yes |
| UploadsMiddleware | yes | no |
| SandboxMiddleware | yes | yes |
| DanglingToolCallMiddleware | yes | no |
| ToolErrorHandlingMiddleware | yes | yes |

Subagents get the minimal `build_subagent_runtime_middlewares()` stack (3 middleware) plus whatever their own agent builder appends. The rationale: subagents do not receive uploads (they access files through the shared sandbox), and their shorter execution lifespans make dangling tool call repair unnecessary.

## Hook Execution Flow

A single agent turn traverses hooks in this lifecycle:

```
before_agent (stages 1-3)
  |
  +-- [agent loop begins]
  |     |
  |     +-> before_model (stages 7, 10)
  |     |     |
  |     |     +-> wrap_model_call (stages 4, 6, 11)
  |     |           |
  |     |           +-> [LLM INVOCATION]
  |     |           |
  |     |         <-+ wrap_model_call returns
  |     |
  |     +<- after_model (stages 8, 12, 13)
  |     |
  |     +-> wrap_tool_call (stages 5, 14)
  |     |     |
  |     |     +-> [TOOL EXECUTION]
  |     |     |
  |     |   <-+ wrap_tool_call returns
  |     |
  |     +-- [loop back to before_model if tool calls present]
  |
  +-- [agent loop ends]
  |
after_agent (stages 3, 9)
```

`before_*` and `wrap_*` hooks run in registration order (stage 1 first). `after_*` hooks run in reverse registration order (last registered first). This means `ClarificationMiddleware` (stage 14) sees tool calls before `ToolErrorHandlingMiddleware` (stage 5) in the `wrap_tool_call` chain, allowing it to intercept `ask_clarification` before error handling could catch any exception.

Each hook type serves a distinct purpose in this flow:
- **`before_agent`** -- one-time setup (directories, sandbox, file injection). Runs once per `invoke()` call.
- **`before_model`** -- per-LLM-call preparation (todo reminders, image injection). Runs every iteration of the agent loop.
- **`wrap_model_call`** -- request/response interception around the LLM (message patching, tool filtering, summarization). Can modify both the request going in and the response coming out.
- **`after_model`** -- post-LLM processing (title generation, subagent limiting, loop detection). Sees the model's output before tools execute.
- **`wrap_tool_call`** -- per-tool interception (error handling, clarification routing). Runs once per tool call in the response.
- **`after_agent`** -- cleanup and async work (sandbox release, memory queuing). Runs once after the agent loop terminates.

## Design Decisions

**Ordered pipeline over event-based dispatch.** The registration-order contract means middlewares can reason about what has already run. ThreadDataMiddleware must populate `thread_data` in state before SandboxMiddleware reads it. UploadsMiddleware needs `thread_id` from the runtime context set up by ThreadDataMiddleware. An event bus would require explicit dependency declarations for the same guarantees, adding complexity without benefit.

**ClarificationMiddleware must be last.** It intercepts `ask_clarification` tool calls and returns a `Command(goto=END)` that terminates the agent loop. If any `wrap_tool_call` middleware ran after it, that middleware would never see the command -- the agent would already be routing to `__end__`. Placing it last ensures every other tool-wrapping middleware (particularly `ToolErrorHandlingMiddleware`) has already had its chance to process other tool calls normally.

**LoopDetectionMiddleware uses sliding window hash comparison.** Rather than tracking full message history (unbounded memory), it maintains a fixed-size window (default 20) of MD5 hashes. The hash is order-independent (tool calls are sorted by name + serialized args before hashing) so parallel tool calls in different orders still match. The two-tier response (warn at 3, force-stop at 5) gives the model a chance to self-correct before hard termination. Per-thread tracking with LRU eviction (max 100 threads) prevents memory leaks in long-running server processes.

**Lazy initialization as default.** Both `ThreadDataMiddleware` and `SandboxMiddleware` default to `lazy_init=True`, deferring directory creation and sandbox acquisition until actually needed. This avoids allocating resources for turns that may not require filesystem or sandbox access (e.g., pure conversational responses).

## Gotchas

**SummarizationMiddleware can truncate TodoMiddleware's `write_todos` calls.** When summarization compresses history, the original `write_todos` tool call and its `ToolMessage` may be removed from the active context. The model then loses awareness of the todo list entirely. This is why `TodoMiddleware` exists as a separate stage that runs in `before_model` -- it detects the absence of `write_todos` in the message list and re-injects a `<system_reminder>` with the current todo state from the persistent `todos` key in graph state.

**ToolErrorHandlingMiddleware preserves GraphBubbleUp signals.** `GraphBubbleUp` is LangGraph's control-flow exception for interrupt, pause, and resume operations. The error handler explicitly re-raises it before the generic `except Exception` catch. If it were caught and converted to an error `ToolMessage`, LangGraph's interrupt mechanism would silently break, and the agent would continue executing when it should have paused.

**LoopDetectionMiddleware per-thread tracking with LRU eviction.** Tracking state is stored in an `OrderedDict` with `max_tracked_threads=100`. When a new thread exceeds this limit, the least recently used thread's history is evicted. This prevents unbounded memory growth but means very old threads lose their loop detection state if the server handles more than 100 concurrent threads. The `_warned` set (tracking which hashes have already triggered warnings) is evicted alongside the history. All tracking is protected by `threading.Lock` for thread safety.

**UploadsMiddleware only runs for lead agents.** `build_lead_runtime_middlewares` includes it; `build_subagent_runtime_middlewares` does not. Subagents do not receive file uploads directly -- they inherit file access through the shared sandbox filesystem. Similarly, `DanglingToolCallMiddleware` is excluded from subagents since their shorter lifespans make orphaned tool calls unlikely.

**SandboxMiddleware after_agent releases but does not destroy.** The `release()` call returns the sandbox to the pool for reuse within the same thread. Actual destruction happens at application shutdown via `SandboxProvider.shutdown()`. This avoids wasteful sandbox recreation on every agent turn within a conversation.
