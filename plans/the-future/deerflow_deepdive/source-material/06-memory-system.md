# DeerFlow Memory System Deep Dive

## What It Does

DeerFlow has a persistent cross-session memory system that builds a profile of the user over time. Memory is stored as a JSON file at `{base_dir}/memory.json` (default `~/.deer-flow/memory.json`), with optional per-agent scoping to `{base_dir}/agents/{agent_name}/memory.json`.

The memory schema (version 1.0) has three top-level sections:

- **User Context** -- Three subsections (`workContext`, `personalContext`, `topOfMind`), each containing a 1-5 sentence summary and an `updatedAt` timestamp. `topOfMind` is the most frequently updated and captures 3-5 concurrent focus themes.
- **History** -- Three temporal tiers (`recentMonths`, `earlierContext`, `longTermBackground`), each a paragraph-length summary with timestamp. These cascade from recent (1-3 months) to foundational/permanent context.
- **Facts** -- An array of discrete facts, each with `id`, `content`, `category` (preference/knowledge/context/behavior/goal), `confidence` (0.0-1.0), `createdAt`, and `source` (thread ID). Maximum 100 facts by default; when exceeded, lowest-confidence facts are evicted.

Memory is extracted asynchronously after each conversation turn and injected into the system prompt on subsequent conversations, wrapped in `<memory>` XML tags.

## How It Works

### MemoryMiddleware

**File:** `backend/packages/harness/deerflow/agents/middlewares/memory_middleware.py`

Hooks into `after_agent()` on the lead agent's middleware chain. It:

1. Checks `config.enabled` -- exits early if memory is off.
2. Extracts `thread_id` from the runtime context.
3. Filters the full message list via `_filter_messages_for_memory()` to keep only human messages and final AI responses (no tool calls, no AI messages with `tool_calls` set).
4. Strips ephemeral `<uploaded_files>` blocks from human messages. If a human message is entirely an upload block (nothing left after stripping), both that message and its paired AI response are dropped.
5. Requires at least one user message and one assistant message to proceed.
6. Queues a `ConversationContext` on the global `MemoryUpdateQueue`.

MemoryMiddleware is registered **after** TitleMiddleware in the middleware chain to prevent title generation from polluting memory extraction. The ordering comment in `lead_agent/agent.py` (line 203) is explicit about this.

### Memory Queue

**File:** `backend/packages/harness/deerflow/agents/memory/queue.py`

`MemoryUpdateQueue` is a global singleton with a debounce mechanism:

- **Debounce window:** 30 seconds by default (configurable 1-300s via `debounce_seconds`).
- When `.add()` is called, the conversation is appended (or replaces an existing entry for the same `thread_id`) and a `threading.Timer` is reset.
- Multiple updates within the debounce window are batched. The timer fires `_process_queue()` after the debounce elapses.
- The timer thread is daemonic (`self._timer.daemon = True`), so it does not block process shutdown.
- A `_processing` lock prevents concurrent processing; if already processing when the timer fires, it reschedules.
- Between processing multiple queued contexts, a 0.5s sleep prevents rate limiting on the LLM API.
- `flush()` forces immediate processing (used in tests/shutdown). `clear()` discards without processing.

### MemoryUpdater

**File:** `backend/packages/harness/deerflow/agents/memory/updater.py`

`MemoryUpdater.update_memory()` is the core update path:

1. Loads current memory from file (with an in-memory cache keyed by `agent_name`, invalidated on file `mtime` change).
2. Formats the filtered conversation via `format_conversation_for_update()` (truncates individual messages to 1000 chars).
3. Sends the current memory state + conversation to an LLM via `MEMORY_UPDATE_PROMPT` -- a detailed prompt that instructs the model to output JSON with `shouldUpdate` flags per section, `newFacts`, and `factsToRemove`.
4. Parses the JSON response, applies updates via `_apply_updates()`:
   - Overwrites user/history sections where `shouldUpdate` is true.
   - Removes facts by ID from `factsToRemove`.
   - Adds new facts that meet the confidence threshold (default 0.7), deduplicating by normalized content string.
   - Evicts lowest-confidence facts when the count exceeds `max_facts`.
5. Runs `_strip_upload_mentions_from_memory()` to scrub any sentences about file uploads that the LLM may have included despite prompt instructions.
6. Writes atomically: writes to a `.tmp` file, then renames (atomic on most systems).

### Memory Config

**File:** `backend/packages/harness/deerflow/config/memory_config.py`

Pydantic model with these fields:

| Field | Type | Default | Constraints |
|-------|------|---------|-------------|
| `enabled` | `bool` | `True` | -- |
| `storage_path` | `str` | `""` (uses `{base_dir}/memory.json`) | Absolute or relative to base_dir |
| `debounce_seconds` | `int` | `30` | 1-300 |
| `model_name` | `str \| None` | `None` (uses default model) | -- |
| `max_facts` | `int` | `100` | 10-500 |
| `fact_confidence_threshold` | `float` | `0.7` | 0.0-1.0 |
| `injection_enabled` | `bool` | `True` | -- |
| `max_injection_tokens` | `int` | `2000` | 100-8000 |

### Memory Injection

**File:** `backend/packages/harness/deerflow/agents/lead_agent/prompt.py` (function `_get_memory_context`)

When both `config.enabled` and `config.injection_enabled` are true, the function loads memory data, formats it via `format_memory_for_injection()`, and wraps it in `<memory>` tags. This is interpolated into `SYSTEM_PROMPT_TEMPLATE` at the `{memory_context}` placeholder, appearing right after the `<role>` and `{soul}` blocks.

`format_memory_for_injection()` builds a text representation with sections "User Context", "History", and "Facts". Facts are sorted by confidence (descending) and included incrementally until the token budget is exhausted. Token counting uses `tiktoken` (cl100k_base encoding) with a character-based fallback (`len // 4`) if tiktoken is unavailable.

### Gateway Memory API

**File:** `backend/app/gateway/routers/memory.py`

Three endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/memory` | GET | Returns full memory data (user, history, facts) |
| `/api/memory/reload` | POST | Force-reloads from file, refreshing cache |
| `/api/memory/config` | GET | Returns current memory config |
| `/api/memory/status` | GET | Returns both config and data in one call |

The frontend fetches via `GET /api/memory` and displays in a read-only settings panel (`memory-settings-page.tsx`) using `useMemory()` hook backed by React Query.

## Key Files

| File | Role |
|------|------|
| `backend/packages/harness/deerflow/agents/middlewares/memory_middleware.py` | Post-agent hook; filters messages, queues for async update |
| `backend/packages/harness/deerflow/agents/memory/queue.py` | Debounced queue with `threading.Timer`; global singleton |
| `backend/packages/harness/deerflow/agents/memory/updater.py` | LLM-based extraction; reads/writes `memory.json`; fact dedup and eviction |
| `backend/packages/harness/deerflow/agents/memory/prompt.py` | `MEMORY_UPDATE_PROMPT`, `format_memory_for_injection()`, token counting |
| `backend/packages/harness/deerflow/config/memory_config.py` | Pydantic config model with all tuning knobs |
| `backend/packages/harness/deerflow/config/paths.py` | Resolves `memory_file` and `agent_memory_file` paths |
| `backend/packages/harness/deerflow/agents/lead_agent/prompt.py` | `_get_memory_context()` injects memory into system prompt |
| `backend/app/gateway/routers/memory.py` | FastAPI endpoints for frontend access |
| `frontend/src/core/memory/types.ts` | TypeScript `UserMemory` interface |
| `frontend/src/core/memory/api.ts` | `loadMemory()` fetch wrapper |
| `frontend/src/core/memory/hooks.ts` | `useMemory()` React Query hook |
| `frontend/src/components/workspace/settings/memory-settings-page.tsx` | Read-only settings panel rendering memory as markdown |

## Design Decisions

**Why async with debounce instead of synchronous.** Memory extraction requires an LLM call (potentially seconds). Running it synchronously would add latency to every agent response. The 30-second debounce further batches rapid-fire exchanges into a single update, reducing LLM calls during active conversation.

**Why confidence scores on facts.** Not all extracted information is equally reliable. Explicitly stated facts ("I work at Acme") get 0.9-1.0; inferred patterns get 0.5-0.6. The confidence threshold (default 0.7) gates what gets stored, and when max_facts is exceeded, lowest-confidence facts are evicted first. This creates a natural quality filter without manual curation.

**Why JSON file storage instead of a database.** Memory is per-user, low-volume (one file, updated at most every 30 seconds), and needs to work in local-first deployments with zero infrastructure. A JSON file is human-readable, trivially portable, and requires no database dependency. Atomic writes via temp-file-then-rename prevent corruption.

**Why memory injected into system prompt rather than separate context.** System prompt injection ensures every model call sees the memory context with maximum attention weight. Separate context windows or retrieval-augmented approaches would add architectural complexity for a payload that fits within 2000 tokens. The `<memory>` XML tags make it cleanly separable from other prompt sections.

## Gotchas

- Memory never blocks conversation flow. All extraction is async via the debounced queue. If the LLM call fails, it is caught and logged; the user never sees an error.
- MemoryMiddleware runs **after** TitleMiddleware in the middleware chain. This prevents the title-generation exchange from being captured as memory content.
- Memory is per-agent (optional `agent_name` scope) but shares one physical base directory. Global memory lives at `{base_dir}/memory.json`; per-agent memory at `{base_dir}/agents/{name}/memory.json`. The cache is keyed by `agent_name` (with `None` for global).
- No memory deletion API from the frontend. The gateway exposes read-only endpoints. Memory management (deletion, editing) must be done by modifying the JSON file directly on the backend.
- Upload file paths are aggressively scrubbed. Both the middleware (strips `<uploaded_files>` blocks before queuing) and the updater (regex-scrubs upload sentences after LLM extraction) work to prevent session-scoped file paths from leaking into long-term memory.
- The in-memory cache checks file `mtime` on every read, so external edits to `memory.json` are picked up automatically without requiring a restart or explicit reload.
- Facts are deduplicated by exact normalized content string. Two facts with identical text but different metadata will not both be stored.
- When `max_facts` is exceeded, eviction sorts by confidence and keeps the top N. There is no time-based decay -- old high-confidence facts persist indefinitely.
