# 07 -- Real-Time Systems

The complete real-time architecture of Mission Control: WebSocket gateway communication, Server-Sent Events for browser push, the server-side event bus, smart polling with visibility awareness, and Ed25519 device identity for cryptographic handshakes.

---

## Dual-Protocol Architecture

Mission Control uses two distinct real-time protocols, each serving a different communication path:

| Protocol | Direction | Purpose | Port |
|----------|-----------|---------|------|
| **WebSocket** | MC UI <-> OpenClaw Gateway | Bidirectional comms with the agent orchestration gateway (sessions, logs, spawning, cron) | 18789 (default) |
| **SSE** | MC Backend -> Browser | Unidirectional push of local database mutations (tasks, agents, chat, activities, notifications) | Same as Next.js (3007) |

This separation exists because the gateway is a separate process (OpenClaw) running on a different port, while SSE handles the MC backend's own data layer. The browser receives real-time updates from both channels simultaneously, merging them into a single Zustand store.

```
                          OpenClaw Gateway (port 18789)
                                 |
                            WebSocket
                                 |
    Browser <-- SSE (/api/events) -- MC Backend (Next.js)
         \                              |
          \                          SQLite
           \                            |
            +--- Zustand Store <--------+
```

### Complete Data Flow Diagrams

**Agent via Gateway path:**
```
Agent Process
  -> Framework Adapter (Claude Code / Codex / custom)
    -> OpenClaw Gateway (WS:18789)
      -> MC Backend receives WS events
        -> SQLite (persist)
          -> eventBus.broadcast()
            -> SSE stream (/api/events)
              -> Browser EventSource
                -> useServerEvents dispatch
                  -> Zustand store
                    -> React panels re-render
```

**Direct CLI path (no gateway):**
```
Agent CLI Tool
  -> POST /api/connect (register)
  -> POST /api/agents/[id]/heartbeat (periodic)
  -> POST /api/tokens (report usage)
  -> MC Backend
    -> SQLite (persist)
      -> eventBus.broadcast()
        -> SSE stream (/api/events)
          -> Browser EventSource
            -> Zustand store
```

---

## WebSocket Client (`useWebSocket` hook)

**Source:** `src/lib/websocket.ts`

The `useWebSocket` hook is a React hook that manages the full lifecycle of a WebSocket connection to the OpenClaw gateway. It is a client-side module (`'use client'`).

### Protocol Version

```typescript
const PROTOCOL_VERSION = 3  // v3 required by OpenClaw 2026.x
const DEFAULT_GATEWAY_CLIENT_ID = process.env.NEXT_PUBLIC_GATEWAY_CLIENT_ID || 'openclaw-control-ui'
```

The client negotiates protocol v3 exclusively -- it sends `minProtocol: 3, maxProtocol: 3` in the connect handshake.

### Connection Flow

1. **`connect(url, token?)`** is called with a gateway URL and optional auth token
2. URL is normalized via `buildGatewayWebSocketUrl()` (handles `ws://`, `wss://`, bare hostnames, port inference)
3. A native `WebSocket` is opened to the normalized URL
4. On `ws.onopen`, the client logs connection but does NOT set `isConnected: true` yet -- it waits for the handshake
5. The gateway sends a `connect.challenge` event frame containing a `nonce`
6. The client calls `sendConnectHandshake(ws, nonce)` which performs Ed25519 signing and sends the `connect` request
7. On successful `res` frame with `ok: true`, the handshake is complete:
   - `isConnected` is set to `true`
   - Device token is cached if returned by gateway
   - Heartbeat ping interval starts
   - Reconnect attempts counter resets to 0

### Gateway Frame Protocol

The gateway uses a JSON-based frame protocol with three frame types:

```typescript
interface GatewayFrame {
  type: 'event' | 'req' | 'res'
  event?: string      // For type='event': event name
  method?: string     // For type='req': RPC method name
  id?: string         // Request/response correlation ID
  payload?: any       // Event data
  ok?: boolean        // Response success flag
  result?: any        // Successful response data
  error?: any         // Error response data
  params?: any        // Request parameters
}
```

### Connect Handshake Request

```typescript
const connectRequest = {
  type: 'req',
  method: 'connect',
  id: 'mc-1',          // Auto-incrementing: mc-{counter}
  params: {
    minProtocol: 3,
    maxProtocol: 3,
    client: {
      id: 'openclaw-control-ui',
      displayName: 'Mission Control',
      version: APP_VERSION,        // From package.json
      platform: 'web',
      mode: 'ui',
      instanceId: `mc-${Date.now()}`
    },
    role: 'operator',
    scopes: ['operator.admin'],
    auth: { token: '...' },         // If auth token provided
    device: {                        // If nonce received & Ed25519 available
      id: '<sha256(publicKey)>',
      publicKey: '<base64url>',
      signature: '<base64url>',
      signedAt: 1710000000000,
      nonce: '<server-nonce>'
    },
    deviceToken: '<cached-token>',   // If previously cached
  }
}
```

### Ed25519 Device Identity

**Source:** `src/lib/device-identity.ts`

The device identity system provides cryptographic proof that the connecting browser is the same physical device across reconnects. This is the OpenClaw gateway's device authentication mechanism.

#### Key Generation

```typescript
// Uses Web Crypto API (Ed25519)
const keyPair = await crypto.subtle.generateKey('Ed25519', true, ['sign', 'verify'])

// Device ID = SHA-256 hash of raw public key, lowercase hex
const pubRaw = await crypto.subtle.exportKey('raw', keyPair.publicKey)
const deviceId = sha256Hex(pubRaw)  // e.g., "a1b2c3d4e5..."

// Keys stored as base64url in localStorage
const publicKeyBase64 = toBase64Url(pubRaw)
const privateKeyBase64 = toBase64Url(privPkcs8)
```

#### localStorage Persistence

| Key | Value |
|-----|-------|
| `mc-device-id` | SHA-256 hex of raw public key |
| `mc-device-pubkey` | Base64url-encoded raw public key |
| `mc-device-privkey` | Base64url-encoded PKCS#8 private key |
| `mc-device-token` | Gateway-issued device token (cached after successful handshake) |

On subsequent connections, the stored key pair is loaded and re-imported. If key import fails (corruption), a new identity is generated automatically.

#### Nonce Signing Format (v2)

The signature payload is a pipe-delimited string:

```
v2|{deviceId}|{clientId}|{clientMode}|{role}|{scopes}|{signedAt}|{tokenForSignature}|{nonce}
```

Concrete example:
```
v2|a1b2c3d4e5...|openclaw-control-ui|ui|operator|operator.admin|1710000000000||<server-nonce>
```

The `tokenForSignature` is the auth token if available, or the cached device token, or empty string.

```typescript
const { signature } = await signPayload(identity.privateKey, payload, signedAt)
// signature = base64url(Ed25519.sign(privateKey, utf8Encode(payload)))
```

#### Graceful Degradation

If Ed25519 is unavailable (older browsers without WebCrypto Ed25519 support), the handshake proceeds without device identity -- auth-token-only mode.

#### Device Token Caching

After a successful handshake, the gateway may return a `deviceToken` in the response. This token is cached in localStorage (`mc-device-token`) and sent in subsequent connect requests, allowing the gateway to recognize the device without re-verifying the full signature.

### Request ID Format

All outgoing requests use the format `mc-{counter}` where counter is an auto-incrementing integer starting at 0 per hook instance:

```typescript
const nextRequestId = () => {
  requestIdRef.current += 1
  return `mc-${requestIdRef.current}`
}
```

### Heartbeat: Ping/Pong

**Configuration:**
```typescript
const PING_INTERVAL_MS = 30_000     // Ping every 30 seconds
const MAX_MISSED_PONGS = 3          // Force reconnect after 3 missed pongs
```

**Ping frame:**
```json
{
  "type": "req",
  "method": "ping",
  "id": "ping-1"
}
```

**Pong handling:**
- Any response frame whose `id` starts with `ping-` counts as a pong (even error responses prove the connection is alive)
- RTT (round-trip time) is calculated and stored as `connection.latency` in the Zustand store
- `missedPongsRef` resets to 0 on any pong
- If the gateway returns an error with "unknown method: ping", the client switches to **passive heartbeat mode** -- pings stop but the connection stays alive

**Heartbeat timeout:**
When `missedPongsRef >= MAX_MISSED_PONGS` (3), the WebSocket is force-closed with code `4000` ("Heartbeat timeout"), triggering the reconnect flow.

### Automatic Reconnect with Jittered Exponential Backoff

**Configuration:**
```typescript
const maxReconnectAttempts = 10
```

**Backoff formula:**
```typescript
const base = Math.min(Math.pow(2, attempts) * 1000, 30000)  // 1s, 2s, 4s, 8s, 16s, 30s, 30s...
const timeout = Math.round(base + Math.random() * base * 0.5)  // +0-50% jitter
```

| Attempt | Base (ms) | With Jitter (range) |
|---------|-----------|---------------------|
| 0 | 1,000 | 1,000 - 1,500 |
| 1 | 2,000 | 2,000 - 3,000 |
| 2 | 4,000 | 4,000 - 6,000 |
| 3 | 8,000 | 8,000 - 12,000 |
| 4 | 16,000 | 16,000 - 24,000 |
| 5-9 | 30,000 | 30,000 - 45,000 |

After 10 failed attempts, reconnection stops and a log entry instructs the user to reconnect manually.

**Reconnect bypass conditions:**
- Manual disconnect (`manualDisconnectRef`) -- user clicked disconnect
- Non-retryable error -- handshake failure that cannot be recovered without config changes

### Non-Retryable Error Detection

Certain gateway errors indicate configuration or auth problems that will never succeed on retry:

```typescript
const isNonRetryableGatewayError = (message: string): boolean => {
  const normalized = message.toLowerCase()
  return (
    normalized.includes('origin not allowed') ||
    normalized.includes('device identity required') ||
    normalized.includes('device_auth_signature_invalid') ||
    normalized.includes('invalid connect params') ||
    normalized.includes('/client/id') ||
    normalized.includes('auth rate limit') ||
    normalized.includes('rate limited')
  )
}
```

When a non-retryable error is detected:
1. A persistent notification is shown with human-readable help text
2. The heartbeat is stopped
3. The WebSocket is closed with code `4001`
4. Auto-reconnect is permanently disabled for this connection attempt

**Error-specific help messages:**

| Error Pattern | Help Message |
|---------------|-------------|
| `origin not allowed` | "Gateway rejected browser origin. Add {origin} to gateway.controlUi.allowedOrigins..." |
| `device identity required` | "Open Mission Control via HTTPS (or localhost), then reconnect so WebCrypto signing can run." |
| `device_auth_signature_invalid` | "Clear local device identity in the browser and reconnect." |
| `invalid connect params` / `/client/id` | "Ensure NEXT_PUBLIC_GATEWAY_CLIENT_ID is set to openclaw-control-ui..." |
| `auth rate limit` / `rate limited` | "Gateway authentication is rate limited. Wait briefly, then reconnect." |

### Error Log Deduplication

To prevent flooding the log panel with repeated WebSocket errors during reconnect loops:

```typescript
const ERROR_LOG_DEDUPE_MS = 5_000  // Suppress identical errors within 5 seconds
```

### Message Handlers

The `handleGatewayFrame` function processes incoming frames and dispatches to the Zustand store:

| Frame Event | Store Action | Description |
|------------|--------------|-------------|
| `connect.challenge` | n/a | Triggers handshake with nonce |
| `res` (ok, first) | `setConnection({ isConnected: true })` | Handshake complete |
| `res` (ping-*) | `setConnection({ latency: rtt })` | Pong with RTT |
| `tick` | `setSessions(...)` | Periodic session snapshot from gateway |
| `log` | `addLog(...)` | Gateway log entry |
| `chat.message` | `addChatMessage(...)` | Real-time chat from gateway |
| `notification` | `addNotification(...)` | Real-time notification |
| `agent.status` | `updateAgent(id, { status, ... })` | Agent status change |

The `handleGatewayMessage` function handles the older message format:

| Message Type | Store Action | Description |
|-------------|--------------|-------------|
| `session_update` | `setSessions(...)` | Gateway session list |
| `log` | `addLog(...)` | Log entry |
| `spawn_result` | `updateSpawnRequest(...)` | Spawn completion status |
| `cron_status` | `setCronJobs(...)` | Cron job status |
| `event` (token_usage) | `addTokenUsage(...)` | Token consumption event |

### URL Normalization

**Source:** `src/lib/gateway-url.ts`

The `buildGatewayWebSocketUrl` function handles diverse input formats:

```typescript
buildGatewayWebSocketUrl({
  host: 'my-gateway.example.com',
  port: 18789,
  browserProtocol: 'https:'
})
// => 'wss://my-gateway.example.com' (port omitted for non-local HTTPS with default port)

buildGatewayWebSocketUrl({
  host: 'localhost',
  port: 18789,
  browserProtocol: 'http:'
})
// => 'ws://localhost:18789'

buildGatewayWebSocketUrl({
  host: 'ws://192.168.1.50:9000/dashboard?session=abc',
  port: 18789,
  browserProtocol: 'http:'
})
// => 'ws://192.168.1.50:9000' (path/search/hash stripped, protocol normalized)
```

Rules:
- Protocol is derived from browser protocol (`https:` -> `wss:`, `http:` -> `ws:`)
- If the input already has a protocol prefix (`ws://`, `wss://`, `http://`, `https://`), it is parsed and normalized
- Path, search, and hash are always stripped (gateway root only)
- Port 18789 is omitted for non-localhost `wss:` connections (assumes reverse proxy)
- Localhost detection covers: `localhost`, `127.0.0.1`, `::1`, `*.local`

### Hook Return Value

```typescript
return {
  isConnected: connection.isConnected,    // boolean
  connectionState: connection,             // Full connection object from store
  connect,                                 // (url: string, token?: string) => void
  disconnect,                              // () => void
  reconnect,                               // () => void (disconnect + reconnect after 1s)
  sendMessage                              // (message: any) => boolean
}
```

---

## Server-Sent Events (SSE)

### SSE Endpoint

**Source:** `src/app/api/events/route.ts`

```
GET /api/events
```

- **Runtime:** `nodejs` (Next.js App Router with `force-dynamic`)
- **Auth:** Requires `viewer` role minimum
- **Response:** `text/event-stream` with `no-cache, no-transform` and `X-Accel-Buffering: no` (nginx proxy support)

#### Implementation

The endpoint creates a `ReadableStream` that:

1. Sends an initial `connected` event on stream start
2. Subscribes to the `eventBus` singleton's `server-event` channel
3. Forwards every `ServerEvent` as a JSON-encoded SSE data frame
4. Sends a `:heartbeat` comment every 30 seconds to keep the connection alive through proxies
5. Cleans up the event listener and heartbeat interval when the client disconnects

```typescript
// Initial connection event
controller.enqueue(
  encoder.encode(`data: ${JSON.stringify({ type: 'connected', data: null, timestamp: Date.now() })}\n\n`)
)

// Heartbeat (every 30s)
controller.enqueue(encoder.encode(': heartbeat\n\n'))

// Data event
controller.enqueue(
  encoder.encode(`data: ${JSON.stringify(event)}\n\n`)
)
```

### SSE Client Hook

**Source:** `src/lib/use-server-events.ts`

The `useServerEvents` hook connects to `/api/events` using the browser's native `EventSource` API.

**Reconnect behavior:**
- Max 20 reconnect attempts (`SSE_MAX_RECONNECT_ATTEMPTS`)
- Exponential backoff: base delay 1s, max 30s, with 0-50% jitter
- Same formula as WebSocket: `Math.min(2^attempts * 1000, 30000) + random(0, base * 0.5)`

**Event dispatch:**

| SSE Event Type | Store Action |
|----------------|-------------|
| `connected` | No-op (initial ack) |
| `task.created` | `addTask(data)` |
| `task.updated` | `updateTask(id, data)` |
| `task.status_changed` | `updateTask(id, { status, updated_at })` |
| `task.deleted` | `deleteTask(id)` |
| `agent.created` | `addAgent(data)` |
| `agent.updated` | `updateAgent(id, data)` |
| `agent.status_changed` | `updateAgent(id, data)` |
| `chat.message` | `addChatMessage(...)` |
| `notification.created` | `addNotification(...)` |
| `activity.created` | `addActivity(...)` |

**Connection state:** The hook sets `connection.sseConnected` in the store on open/close, which the `useSmartPoll` hook uses to decide whether polling is needed.

---

## Event Bus

**Source:** `src/lib/event-bus.ts`

The event bus is the server-side backbone that connects database mutations to both SSE clients and webhook delivery.

### Singleton Pattern

```typescript
class ServerEventBus extends EventEmitter {
  private static instance: ServerEventBus | null = null

  private constructor() {
    super()
    this.setMaxListeners(50)  // Support up to 50 concurrent SSE clients
  }

  static getInstance(): ServerEventBus {
    if (!ServerEventBus.instance) {
      ServerEventBus.instance = new ServerEventBus()
    }
    return ServerEventBus.instance
  }
}

// Survives HMR in development via globalThis
const globalBus = globalThis as typeof globalThis & { __eventBus?: ServerEventBus }
export const eventBus = globalBus.__eventBus ?? ServerEventBus.getInstance()
globalBus.__eventBus = eventBus as ServerEventBus
```

The `globalThis` trick is critical for development: Next.js hot module replacement would otherwise create a new `EventEmitter` on each file change, breaking all existing SSE subscriptions. By stashing the instance on `globalThis`, the bus survives HMR.

### Event Types

```typescript
export type EventType =
  | 'task.created'
  | 'task.updated'
  | 'task.deleted'
  | 'task.status_changed'
  | 'chat.message'
  | 'chat.message.deleted'
  | 'notification.created'
  | 'notification.read'
  | 'activity.created'
  | 'agent.updated'
  | 'agent.created'
  | 'agent.deleted'
  | 'agent.synced'
  | 'agent.status_changed'
  | 'audit.security'
  | 'connection.created'
  | 'connection.disconnected'
  | 'github.synced'
```

### The `broadcast()` Method

```typescript
broadcast(type: EventType, data: any): ServerEvent {
  const event: ServerEvent = { type, data, timestamp: Date.now() }
  this.emit('server-event', event)
  return event
}
```

All events are emitted under a single channel name (`server-event`). This simplifies the listener model -- SSE clients and webhook handlers each register one listener.

### Listeners

**1. SSE forwarding** -- The `/api/events` route handler subscribes to `server-event` and forwards every event to its `ReadableStream`:

```typescript
eventBus.on('server-event', handler)
// handler encodes event as SSE data frame and enqueues it
```

**2. Webhook dispatch** -- `src/lib/webhooks.ts` subscribes once during server initialization:

```typescript
// Called by initWebhookListener() at startup
eventBus.on('server-event', (event: ServerEvent) => {
  const mapping = EVENT_MAP[event.type]
  if (!mapping) return
  // Maps bus event types to webhook event types, then fires matching webhooks
  fireWebhooksAsync(webhookEventType, event.data, workspaceId)
})
```

The webhook event map translates bus events to webhook-specific event names:

| Bus Event | Webhook Event |
|-----------|---------------|
| `activity.created` | `activity.{type}` (dynamic) |
| `notification.created` | `notification.{type}` (dynamic) |
| `agent.status_changed` | `agent.status_change` |
| `agent.status_changed` (status=error) | `agent.error` (additional) |
| `audit.security` | `security.{action}` (dynamic) |
| `task.created` | `activity.task_created` |
| `task.updated` | `activity.task_updated` |
| `task.deleted` | `activity.task_deleted` |
| `task.status_changed` | `activity.task_status_changed` |

### Where Events Are Emitted

Events are broadcast from API route handlers throughout the codebase. Examples:

```typescript
// POST /api/agents -- agent creation
eventBus.broadcast('agent.created', parsedAgent)

// PUT /api/agents -- agent update
eventBus.broadcast('agent.updated', { id, name, status, updated_at })

// POST /api/connect -- direct CLI connection
eventBus.broadcast('connection.created', { connection_id, agent_id, agent_name, tool_name })

// POST /api/chat/messages -- chat message
eventBus.broadcast('chat.message', parsedMessage)

// POST /api/agents/sync -- agent config sync
eventBus.broadcast('agent.created', { type: 'sync', synced, created, updated })
```

---

## Smart Polling (`useSmartPoll`)

**Source:** `src/lib/use-smart-poll.ts`

Smart polling is a visibility-aware polling hook that intelligently pauses and resumes based on tab visibility and real-time connection state.

### API

```typescript
function useSmartPoll(
  callback: () => void | Promise<void>,
  intervalMs: number,
  options: SmartPollOptions = {}
): () => void  // Returns manual trigger function
```

### Options

```typescript
interface SmartPollOptions {
  pauseWhenConnected?: boolean       // Pause when WebSocket is connected
  pauseWhenDisconnected?: boolean    // Pause when WebSocket is disconnected
  pauseWhenSseConnected?: boolean    // Pause when SSE is connected (real-time replaces polling)
  backoff?: boolean                  // Enable interval backoff on errors
  maxBackoffMultiplier?: number      // Max backoff (default: 3x)
  enabled?: boolean                  // Master switch (default: true)
}
```

### Page Visibility API Integration

The hook uses `document.visibilitychange` to detect when the browser tab is hidden or shown:

```typescript
const handleVisibilityChange = () => {
  isVisibleRef.current = document.visibilityState === 'visible'

  if (isVisibleRef.current) {
    // Tab became visible: fire immediately, reset backoff, restart interval
    backoffMultiplierRef.current = 1
    fire()
    startInterval()
  } else {
    // Tab hidden: stop polling completely
    clearInterval(intervalRef.current)
  }
}

document.addEventListener('visibilitychange', handleVisibilityChange)
```

**Behavior when tab is hidden:** All polling stops immediately. No wasted HTTP requests.

**Behavior when tab becomes visible:** An immediate poll fires, backoff resets to 1x, and regular interval polling resumes.

### `pauseWhenConnected` / `pauseWhenSseConnected`

The `shouldPoll()` function checks multiple conditions:

```typescript
const shouldPoll = () => {
  if (!enabled) return false
  if (!isVisibleRef.current) return false
  if (pauseWhenConnected && connection.isConnected) return false
  if (pauseWhenDisconnected && !connection.isConnected) return false
  if (pauseWhenSseConnected && connection.sseConnected) return false
  return true
}
```

This allows components to configure polling as a fallback that automatically pauses when real-time channels are active:

```typescript
// Example: Poll tasks every 30s, but stop when SSE is delivering real-time updates
useSmartPoll(fetchTasks, 30_000, { pauseWhenSseConnected: true })

// Example: Poll gateway status every 10s, but only when WebSocket is connected
useSmartPoll(fetchGatewayStatus, 10_000, { pauseWhenDisconnected: true })
```

### Initial Fetch

The hook always fires an initial fetch on mount regardless of SSE/WS state:

```typescript
if (!initialFiredRef.current && enabled) {
  initialFiredRef.current = true
  callbackRef.current()
}
```

This bootstraps component data -- SSE delivers events (deltas) but not the full initial state.

### Backoff on Errors

When `backoff: true` is set and the callback returns a rejected promise:

```typescript
backoffMultiplierRef.current = Math.min(
  backoffMultiplierRef.current + 0.5,
  maxBackoffMultiplier  // Default: 3x
)
```

The effective interval becomes `intervalMs * backoffMultiplier`. Backoff resets to 1x when the tab becomes visible.

### Connection State Reactivity

The hook restarts its interval whenever `connection.isConnected` or `connection.sseConnected` changes:

```typescript
useEffect(() => {
  startInterval()
}, [connection.isConnected, connection.sseConnected, startInterval])
```

This ensures that when SSE drops, polling automatically kicks in, and when SSE reconnects, polling pauses again.

---

## Real-Time Protocol Interaction Matrix

How all four real-time mechanisms interact across different scenarios:

| Scenario | WebSocket | SSE | Smart Poll | Notes |
|----------|-----------|-----|------------|-------|
| **Normal operation (gateway connected)** | Connected, receiving tick/log/chat | Connected, receiving DB mutations | Paused (SSE active) | All data flows through WS + SSE |
| **Gateway offline, MC running** | Disconnected, reconnecting | Connected | Active (WS down, SSE up) | Polling fills gaps for gateway data |
| **Tab hidden** | Stays connected (browser keeps WS alive) | Stays connected (EventSource stays open) | Paused | No wasted poll requests |
| **Tab becomes visible** | No change | No change | Immediate fire + resume | Catches up on any missed poll data |
| **SSE disconnects** | No change | Reconnecting (exp backoff) | Resumes | Polling provides resilience |
| **Both WS + SSE down** | Reconnecting | Reconnecting | Active | Polling is the last resort |
| **Non-retryable WS error** | Stopped, manual reconnect needed | No change | Active | Config error prevents WS recovery |

---

## Webhook Integration

**Source:** `src/lib/webhooks.ts`

Webhooks are the external notification leg of the real-time system. They subscribe to the same event bus and deliver HTTP POST requests to configured endpoints.

### Event Bus Subscription

```typescript
export function initWebhookListener() {
  eventBus.on('server-event', (event: ServerEvent) => {
    const mapping = EVENT_MAP[event.type]
    if (!mapping) return
    fireWebhooksAsync(webhookEventType, event.data, workspaceId)
  })
}
```

### Delivery

- **Timeout:** 10 seconds per delivery attempt
- **Signature:** HMAC-SHA256 if webhook has a secret configured (`X-MC-Signature: sha256={hex}`)
- **Headers:** `Content-Type: application/json`, `User-Agent: MissionControl-Webhook/1.0`, `X-MC-Event: {eventType}`
- **Retry:** Up to 5 attempts with backoff: 30s, 5m, 30m, 2h, 8h (plus +/-20% jitter)
- **Circuit breaker:** After exhausting all retries with consecutive failures >= 5, the webhook is automatically disabled

### Retry Processing

The scheduler runs `processWebhookRetries()` every 60 seconds, picking up deliveries where `next_retry_at` has passed.

---

## Architecture Decisions for The Hive

### Key design patterns to replicate:

1. **Dual-protocol separation** -- WebSocket for the orchestration layer, SSE for the data layer. Do not try to multiplex both over a single WebSocket; the separation provides independent failure domains.

2. **Event bus as the spine** -- All mutations go through a single `broadcast()` call. SSE, webhooks, and any future consumers (e.g., desktop notifications) subscribe to the same channel.

3. **globalThis singleton** -- Essential for development. Without it, HMR breaks all real-time connections.

4. **Device identity as localStorage** -- Ed25519 key pairs persisted in the browser provide device-level identity without server-side device registration. The gateway issues short-lived device tokens after initial verification.

5. **Passive heartbeat fallback** -- When the gateway doesn't support the `ping` RPC method, the client silently switches to passive mode rather than breaking. Forward compatibility.

6. **Smart polling as last resort** -- Polling is not the enemy; it is the resilience layer. The visibility API ensures zero waste when the tab is hidden, and `pauseWhenSseConnected` ensures zero waste when real-time channels are active.

7. **Non-retryable error classification** -- Prevents infinite reconnect loops for configuration errors. The user gets a clear, actionable error message instead of watching the connection counter spin up.
