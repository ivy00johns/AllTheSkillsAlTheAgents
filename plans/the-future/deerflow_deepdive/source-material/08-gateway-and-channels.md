# 08 -- Gateway API and IM Channels

## What It Does

DeerFlow has two external-facing backend services that live in the app layer (`backend/app/`), separate from the LangGraph harness:

1. **FastAPI Gateway** (port 8001) -- a management API for models, MCP configuration, memory, skills, artifacts, uploads, agents, follow-up suggestions, and channel status.
2. **IM Channels** (Feishu, Slack, Telegram) -- messaging platform integrations that let users interact with DeerFlow agents from chat apps instead of the web UI.

The gateway never calls LangGraph directly. All agent execution requests flow through Nginx, which reverse-proxies `/api/langgraph/*` to the LangGraph Server on port 2024. The gateway handles everything else under `/api/`.

## How It Works

### Gateway API

**Entry point:** `backend/app/gateway/app.py`

`create_app()` builds a FastAPI application titled "DeerFlow API Gateway" with an async `lifespan` handler that:

1. Loads `AppConfig` and `GatewayConfig` at startup.
2. Calls `start_channel_service()` to launch any configured IM channels.
3. On shutdown, calls `stop_channel_service()`.

Port defaults to `8001` (configurable via `GATEWAY_PORT` env var). The app registers 9 route modules plus a `/health` endpoint. CORS is explicitly not handled by FastAPI -- the comment on line 149 of `app.py` reads "CORS is handled by nginx."

### Gateway Routes

| Route prefix | Router file | Purpose |
|---|---|---|
| `/api/models` | `routers/models.py` | List available AI models, get model details by name. Reads from `AppConfig.models`. |
| `/api/mcp/config` | `routers/mcp.py` | GET/PUT MCP server configurations. Persists to `extensions_config.json`. |
| `/api/memory` | `routers/memory.py` | GET global memory data (facts, user context, history). POST `/memory/reload` to refresh from disk. GET `/memory/config` and `/memory/status`. |
| `/api/skills` | `routers/skills.py` | List skills, get/update enabled status, install `.skill` archives (ZIP). Safe extraction with symlink rejection and zip-bomb defense. |
| `/api/threads/{id}/artifacts` | `routers/artifacts.py` | Serve generated files. Resolves virtual paths (`mnt/user-data/outputs/...`) to host filesystem. Supports `.skill` archive introspection, HTML rendering, text detection, and `?download=true`. |
| `/api/threads/{id}/uploads` | `routers/uploads.py` | File upload (POST), list, delete. Convertible file types (PDF, PPT, Excel, Word) are auto-converted to markdown via `markitdown`. Max body size 100MB enforced by Nginx. |
| `/api/agents` | `routers/agents.py` | Full CRUD for custom agents. Each agent has a `config.yaml` and `SOUL.md` on disk. Also manages the global `USER.md` profile via `/api/user-profile`. |
| `/api/threads/{id}/suggestions` | `routers/suggestions.py` | POST with recent messages to generate follow-up questions. Uses a lightweight LLM call that returns a JSON array of suggested questions. |
| `/api/channels` | `routers/channels.py` | GET channel status, POST `/{name}/restart` to restart a specific channel. |

### Channel Base

**File:** `backend/app/channels/base.py`

Abstract `Channel` class with three lifecycle methods every implementation must provide:

- `start()` -- begin listening for messages from the external platform.
- `stop()` -- graceful shutdown.
- `send(msg: OutboundMessage)` -- deliver a response back to the platform.

Optional `send_file(msg, attachment)` returns `True` on success (default: `False`). The base class wires up `_on_outbound` as a bus callback that routes outbound messages to the correct channel by checking `msg.channel_name == self.name`, then sends text first and uploads file attachments afterward. If the text send fails, file uploads are skipped entirely to prevent partial deliveries.

### Message Bus

**File:** `backend/app/channels/message_bus.py`

The `MessageBus` is an async pub/sub hub with two halves:

- **Inbound:** `asyncio.Queue[InboundMessage]`. Channels call `publish_inbound()` to enqueue; the ChannelManager calls `get_inbound()` to consume.
- **Outbound:** A list of `OutboundCallback` coroutines. The ChannelManager calls `publish_outbound()`, which fans out to all registered listeners.

Key data types:

| Type | Direction | Fields |
|---|---|---|
| `InboundMessage` | channel -> dispatcher | `channel_name`, `chat_id`, `user_id`, `text`, `msg_type` (CHAT or COMMAND), `thread_ts`, `topic_id`, `files`, `metadata` |
| `OutboundMessage` | dispatcher -> channel | `channel_name`, `chat_id`, `thread_id`, `text`, `artifacts`, `attachments`, `is_final`, `thread_ts` |
| `ResolvedAttachment` | used in outbound | `virtual_path`, `actual_path`, `filename`, `mime_type`, `size`, `is_image` |

`InboundMessageType` is a `StrEnum` with two values: `CHAT` and `COMMAND`.

### ChannelManager (the Agent Dispatcher)

**File:** `backend/app/channels/manager.py`

`ChannelManager` is the core bridge between IM channels and the DeerFlow agent. It runs a `_dispatch_loop` that reads from the bus inbound queue with a 1-second timeout poll. Each message is dispatched as a fire-and-forget `asyncio.Task`, bounded by a semaphore (`max_concurrency=5`).

The LangGraph SDK client (`langgraph_sdk.get_client`) connects to `http://localhost:2024`. For each chat message, the manager:

1. Looks up an existing thread via `ChannelStore.get_thread_id(channel, chat_id, topic_id)`.
2. If none exists, creates a new thread via `client.threads.create()` and stores the mapping.
3. Resolves run parameters (assistant_id, config, context) from a layered session config: defaults -> channel-level -> user-level overrides.
4. Dispatches to either streaming or non-streaming path based on `CHANNEL_CAPABILITIES`.

**Non-streaming path** (Slack, Telegram): calls `client.runs.wait()`, extracts response text from the final state's messages list, extracts artifact paths from `present_files` tool calls, resolves attachments, and publishes a single `OutboundMessage`.

**Streaming path** (Feishu only): calls `client.runs.stream()` with `stream_mode=["messages-tuple", "values"]`. Accumulates AI text into per-message-id buffers. Publishes intermediate `OutboundMessage(is_final=False)` updates throttled to one every 0.35 seconds. Sends a final `is_final=True` message with resolved artifacts.

**Commands:** The manager handles `/bootstrap`, `/new`, `/status`, `/models`, `/memory`, and `/help`. The `/models` and `/memory` commands fetch data from the gateway API at `http://localhost:8001` via `httpx`.

**Artifact delivery:** `_resolve_attachments()` only accepts virtual paths under `/mnt/user-data/outputs/` -- any other path is rejected to prevent exfiltration. Each resolved path is verified to actually reside within the thread's outputs directory (double-checks against path traversal even after prefix validation).

### Channel Store

**File:** `backend/app/channels/store.py`

`ChannelStore` is a JSON-file-backed persistence layer mapping IM conversations to DeerFlow thread IDs. The key format is `channel_name:chat_id` or `channel_name:chat_id:topic_id` when a topic is present. Data is stored at `{base_dir}/channels/store.json` and atomically rewritten on every mutation using a temp-file-and-rename pattern. Thread-safe via `threading.Lock`.

### Channel Service

**File:** `backend/app/channels/service.py`

`ChannelService` orchestrates the full lifecycle. It reads the `channels` key from `config.yaml`, instantiates enabled channels via a lazy-loading registry, starts the `ChannelManager`, and provides `restart_channel()` for hot-reloading individual channels. Exposed as a process-global singleton via `start_channel_service()` / `stop_channel_service()`.

The channel registry maps names to import paths:

```python
_CHANNEL_REGISTRY = {
    "feishu": "app.channels.feishu:FeishuChannel",
    "slack": "app.channels.slack:SlackChannel",
    "telegram": "app.channels.telegram:TelegramChannel",
}
```

### Channel Implementations

**Feishu** (`channels/feishu.py`): Uses `lark-oapi` WebSocket long-connection mode (no public IP needed). Runs the WS client in a dedicated `threading.Thread` with its own asyncio event loop to avoid conflicting with uvicorn's uvloop. Patches the SDK's module-level `loop` reference. Message flow: user sends message -> bot adds "OK" emoji reaction -> bot replies in-thread with a "Working on it..." interactive card -> agent processes -> bot updates the card in-place with results -> bot adds "DONE" emoji reaction. Streaming updates patch the same card via `_update_card()`. Supports file uploads: images via `im.v1.image.create` (10MB limit), files via `im.v1.file.create` (30MB limit). Uses Feishu's interactive card format (JSON with markdown elements) for all replies. Topic mapping uses `root_id` for threaded replies, `msg_id` for new conversations.

**Slack** (`channels/slack.py`): Uses `slack-sdk` Socket Mode (WebSocket, no public IP). The `SocketModeClient` runs in a background thread via `run_in_executor`. Converts standard markdown to Slack's `mrkdwn` format using `markdown_to_mrkdwn.SlackMarkdownConverter`. Handles `message` and `app_mention` events. Adds "eyes" emoji on receipt, sends "Working on it..." reply, then delivers the final response. Adds `white_check_mark` reaction on success, `x` on failure. Supports optional `allowed_users` whitelist. Topic mapping uses `thread_ts`.

**Telegram** (`channels/telegram.py`): Uses `python-telegram-bot` with long-polling (no webhooks). Runs polling in a dedicated thread with a fresh event loop, manually calling `initialize()`, `start()`, and `start_polling()` to avoid `add_signal_handler` issues in non-main threads. Registers command handlers (`/start`, `/new`, `/status`, `/models`, `/memory`, `/help`) and a general text handler. In private chats, `topic_id` is `None` so all messages share one thread. In group chats, uses `reply_to_message.message_id` or current `message_id` for topic isolation. Supports file uploads: photos up to 10MB, documents up to 50MB.

All three channels implement retry logic with exponential backoff (1s, 2s) for send failures, up to 3 attempts.

## Key Files

| File | Purpose |
|---|---|
| `backend/app/gateway/app.py` | FastAPI app factory, lifespan handler, router registration |
| `backend/app/gateway/config.py` | `GatewayConfig` Pydantic model (host, port, CORS origins) |
| `backend/app/gateway/path_utils.py` | `resolve_thread_virtual_path()` shared by artifacts and uploads |
| `backend/app/gateway/routers/models.py` | `/api/models` -- list/get AI models |
| `backend/app/gateway/routers/mcp.py` | `/api/mcp/config` -- MCP server CRUD |
| `backend/app/gateway/routers/memory.py` | `/api/memory` -- global memory read/reload |
| `backend/app/gateway/routers/skills.py` | `/api/skills` -- skill listing, enable/disable, install |
| `backend/app/gateway/routers/artifacts.py` | `/api/threads/{id}/artifacts` -- serve generated files |
| `backend/app/gateway/routers/uploads.py` | `/api/threads/{id}/uploads` -- file upload/list/delete |
| `backend/app/gateway/routers/agents.py` | `/api/agents` -- custom agent CRUD + user profile |
| `backend/app/gateway/routers/suggestions.py` | `/api/threads/{id}/suggestions` -- follow-up question generation |
| `backend/app/gateway/routers/channels.py` | `/api/channels` -- IM channel status/restart |
| `backend/app/channels/base.py` | Abstract `Channel` class with start/stop/send lifecycle |
| `backend/app/channels/message_bus.py` | `MessageBus`, `InboundMessage`, `OutboundMessage`, `ResolvedAttachment` |
| `backend/app/channels/manager.py` | `ChannelManager` -- agent dispatcher, streaming, commands, artifact delivery |
| `backend/app/channels/store.py` | `ChannelStore` -- JSON-backed chat-to-thread mapping |
| `backend/app/channels/service.py` | `ChannelService` -- lifecycle orchestrator, channel registry singleton |
| `backend/app/channels/feishu.py` | Feishu/Lark: WebSocket, interactive cards, emoji reactions, streaming |
| `backend/app/channels/slack.py` | Slack: Socket Mode, mrkdwn conversion, threaded replies |
| `backend/app/channels/telegram.py` | Telegram: long-polling, command handlers, private/group topic isolation |
| `docker/nginx/nginx.local.conf` | Nginx reverse proxy: CORS, route splitting, 100MB upload limit |

## Design Decisions

**Why message bus decoupling instead of direct channel-to-agent calls.** The `MessageBus` creates a clean separation between platform-specific message handling and agent dispatch logic. Channels only know how to receive and send platform messages; the `ChannelManager` only knows how to talk to LangGraph. This means adding a new channel (e.g., Discord, WeChat) requires zero changes to the dispatcher. It also enables concurrency control in one place (the semaphore in `ChannelManager`) rather than per-channel.

**Why only Feishu gets streaming.** The `CHANNEL_CAPABILITIES` dict in `manager.py` explicitly sets `supports_streaming: True` only for Feishu. This is because Feishu's interactive card API supports in-place message updates (`_update_card` via `PatchMessageRequest`), making live-updating responses natural. Slack and Telegram lack efficient message-patching APIs that work well for streaming -- Slack's `chat.update` has rate limits and Telegram's `editMessageText` is unreliable for rapid updates. Both fall back to `runs.wait()` for a single complete response.

**Why topic_id-based thread reuse.** Each platform has a different concept of "conversation context." Feishu uses `root_id` (thread root), Slack uses `thread_ts`, Telegram uses reply chains in groups and a flat conversation in private chats. The `topic_id` abstraction normalizes these into a single key that the `ChannelStore` uses to map back to a persistent DeerFlow thread. This lets multi-turn conversations maintain state across messages without the user doing anything special.

**Why the gateway is separate from the LangGraph server.** The gateway handles management operations (config CRUD, file serving, skill installation) that have nothing to do with agent execution. Keeping them separate means the LangGraph server can focus purely on graph execution with its own process model, while the gateway can be a lightweight FastAPI process. Nginx sits in front of both on port 2026, routing `/api/langgraph/*` to LangGraph and everything else to the gateway.

## Gotchas

- **Channel registry uses lazy loading.** Channel classes are only imported when the `ChannelService` actually starts a channel. The `_CHANNEL_REGISTRY` maps names to dotted import paths (`"app.channels.feishu:FeishuChannel"`), and `resolve_class()` handles the dynamic import. This avoids hard dependencies on `lark-oapi`, `slack-sdk`, or `python-telegram-bot` unless a channel is actually enabled.

- **ChannelManager uses the LangGraph SDK (not direct HTTP) for all agent interactions.** The client at `http://localhost:2024` is created lazily via `langgraph_sdk.get_client()`. This is the same SDK used by LangGraph Studio and ensures wire-compatible serialization of threads, runs, and streaming events.

- **Feishu uses emoji reactions for progress feedback.** On message receipt, the bot adds an "OK" reaction immediately, then adds "DONE" when the response is delivered. Slack uses "eyes" on receipt and "white_check_mark" on completion. Telegram has no equivalent reaction API.

- **Central CORS in Nginx.** The FastAPI gateway explicitly does not set up CORS middleware (line 149 of `app.py`). All CORS headers (`Access-Control-Allow-Origin: *`) are added by Nginx in `nginx.local.conf` to prevent duplicate headers. This means the gateway cannot be accessed directly from a browser on a different origin without Nginx in front.

- **Feishu WebSocket runs in a separate thread with a patched event loop.** The `lark-oapi` SDK captures a module-level event loop at import time. When uvicorn uses uvloop, the captured loop is the main thread's running loop, causing `RuntimeError` on `run_until_complete()`. The workaround in `_run_ws()` creates a new `asyncio.new_event_loop()` and patches `lark_oapi.ws.client.loop` before starting the WS client.

- **Artifact security is enforced at two levels.** First, `_resolve_attachments()` rejects any virtual path that does not start with `/mnt/user-data/outputs/`. Second, the resolved host path is checked against the thread's outputs directory via `actual.resolve().relative_to(outputs_dir)` to catch traversal that sneaks past the prefix check.

- **The store is a single JSON file with atomic writes.** `ChannelStore._save()` writes to a temp file in the same directory then calls `Path.replace()` for atomicity. This works fine for low-concurrency IM usage but would need a database backend for production-scale deployments.
