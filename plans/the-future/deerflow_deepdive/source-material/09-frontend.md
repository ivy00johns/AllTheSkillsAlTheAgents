# 09 - Frontend Architecture

## What It Does

DeerFlow's frontend is a Next.js 16 / React 19 / TypeScript web application that provides a real-time chat workspace with SSE streaming, a resizable split-panel layout (chat + artifacts), and a Radix-based component library. The landing page at `/` is a marketing-style page with sections for case studies, skills, sandbox, and community. The workspace at `/workspace/` is the primary application surface where users interact with the LangGraph-powered agent backend.

## How It Works

### App Structure

The Next.js App Router defines two main areas:

- **Root layout** (`frontend/src/app/layout.tsx`): wraps the entire app in `ThemeProvider` (next-themes) and `I18nProvider`. Locale is detected server-side via `detectLocaleServer()`.
- **Landing page** (`frontend/src/app/page.tsx`): static marketing page with `Header`, `Hero`, `CaseStudySection`, `SkillsSection`, `SandboxSection`, `WhatsNewSection`, `CommunitySection`, `Footer`.
- **Workspace layout** (`frontend/src/app/workspace/layout.tsx`): wraps children in `QueryClientProvider` (React Query), `SidebarProvider`, and `WorkspaceSidebar`. Sidebar collapse state syncs to localStorage settings.

Chat thread layout (`frontend/src/app/workspace/chats/[thread_id]/layout.tsx`) nests three additional context providers: `SubtasksProvider`, `ArtifactsProvider`, `PromptInputProvider`.

Routes:

| Path | Purpose |
|------|---------|
| `/` | Landing page |
| `/workspace/` | Workspace root (redirects/renders default view) |
| `/workspace/chats/[thread_id]` | Chat thread view |
| `/workspace/agents/[agent_name]/chats/[thread_id]` | Agent-specific chat thread |
| `/workspace/agents/new` | Create new agent |
| `/workspace/agents` | Agent gallery |

### State Management

There is no Zustand or Redux in the codebase. All client state uses React Context + hooks:

- **SubtaskContext** (`core/tasks/context.tsx`): holds `Record<string, Subtask>` updated by `useUpdateSubtask()`. Tracks subagent task status (in_progress, completed, failed) and latest messages from `task_running` custom events.
- **ArtifactsContext** (`components/workspace/artifacts/context.tsx`): holds `artifacts: string[]`, `selectedArtifact: string | null`, `open: boolean`. Controls artifact panel visibility and selection.
- **ThreadContext** (`components/workspace/messages/context.ts`): wraps `BaseStream<AgentThreadState>` from the LangGraph SDK. Provides the live thread stream object to all child components.
- **I18nContext** (`core/i18n/context.tsx`): holds current locale, exposes `setLocale()` which writes a cookie (`locale=<value>; path=/; max-age=31536000`).
- **PromptInputProvider**: manages text input state, file attachments, and form submission coordination across the input box component tree.

Settings are persisted to localStorage under the key `deerflow.local-settings`. The `LocalSettings` type includes `notification.enabled`, `context.model_name`, `context.mode` (flash | thinking | pro | ultra), `context.reasoning_effort`, and `layout.sidebar_collapsed`.

Server state (thread list, models, skills, MCP config, artifacts) is managed via React Query (`@tanstack/react-query`). Thread search results are cached with `refetchOnWindowFocus: false`.

### Streaming

The core streaming hook is `useThreadStream()` in `core/threads/hooks.ts`. It wraps the LangGraph SDK's `useStream()` hook:

```typescript
const thread = useStream<AgentThreadState>({
  client: getAPIClient(isMock),
  assistantId: "lead_agent",
  threadId: onStreamThreadId,
  reconnectOnMount: true,
  fetchStateHistory: { limit: 1 },
  // ...callbacks
});
```

The API client (`core/api/api-client.ts`) is a `LangGraphClient` singleton pointed at `/api/langgraph` (or a configurable `NEXT_PUBLIC_LANGGRAPH_BASE_URL`). Stream modes are sanitized to the supported set (values, messages, messages-tuple, updates, events, debug, tasks, checkpoints, custom) before being sent.

Message submission flow:
1. Files are uploaded first via `POST /api/threads/{id}/uploads` if present.
2. Optimistic human message displayed immediately while waiting for server.
3. `thread.submit()` called with config: `recursion_limit: 1000`, `streamSubgraphs: true`, `streamResumable: true`.
4. Context flags derived from mode: `thinking_enabled` = mode !== "flash", `is_plan_mode` = mode is "pro" or "ultra", `subagent_enabled` = mode is "ultra".
5. Custom events with `type: "task_running"` dispatched to `SubtaskContext` for live subtask updates.
6. On finish, thread search queries invalidated to update sidebar.

### Component Architecture

**ai-elements/** -- reusable AI interaction primitives:
- `prompt-input.tsx` -- composable prompt input with attachments, tools, footer, submit
- `conversation.tsx` -- wrapper for message display area
- `code-block.tsx` -- CodeMirror-powered code rendering
- `chain-of-thought.tsx`, `reasoning.tsx` -- thinking/reasoning display
- `message.tsx` -- single message rendering
- `plan.tsx`, `task.tsx`, `checkpoint.tsx` -- plan and task step displays
- `canvas.tsx` -- XYFlow-based node canvas (uses `@xyflow/react`)
- `model-selector.tsx` -- searchable model picker (cmdk-based command palette)
- `suggestion.tsx` -- follow-up suggestion pills
- `artifact.tsx`, `sources.tsx`, `web-preview.tsx`, `image.tsx` -- content renderers

**workspace/** -- application-level containers:
- `chats/chat-box.tsx` -- resizable split panel: chat (default 100%) | artifacts (default 0%). When artifacts open, layout shifts to 60% chat / 40% artifacts. Uses `react-resizable-panels`.
- `input-box.tsx` -- full input area: mode selector (flash/thinking/pro/ultra), model picker, reasoning effort selector, file attachment button, follow-up suggestion bar, submit button.
- `messages/message-list.tsx` -- groups messages by type using `groupMessages()` and renders: `MessageListItem` (human, assistant), `MessageGroup` (assistant:processing with reasoning + tool calls), `MarkdownContent` (assistant:clarification), `ArtifactFileList` (assistant:present-files), `SubtaskCard` (assistant:subagent).
- `messages/message-group.tsx`, `message-list-item.tsx` -- individual message rendering
- `messages/subtask-card.tsx` -- renders subagent task with status and streaming output
- `artifacts/artifact-file-detail.tsx`, `artifact-file-list.tsx` -- artifact viewing
- `workspace-sidebar.tsx`, `workspace-nav-chat-list.tsx` -- sidebar with thread history
- `settings/settings-dialog.tsx` -- settings pages (appearance, notifications, tools, skills, memory, about)
- `code-editor.tsx` -- CodeMirror editor for artifact content

**landing/** -- marketing page sections:
- `header.tsx`, `hero.tsx`, `footer.tsx`
- `sections/case-study-section.tsx`, `community-section.tsx`, `sandbox-section.tsx`, `skills-section.tsx`, `whats-new-section.tsx`
- `progressive-skills-animation.tsx` -- animated skills showcase

**ui/** -- Radix-based primitives + custom effects:
- Radix wrappers: button, card, dialog, dropdown-menu, input, textarea, select, tabs, scroll-area, sidebar, tooltip, badge, avatar, collapsible, hover-card, progress, separator, switch, toggle, toggle-group, sheet
- Custom: confetti-button, flickering-grid, magic-bento, word-rotate, aurora-text, terminal, spotlight-card, shine-border, number-ticker, skeleton, empty, carousel (embla)

### Artifacts

Artifacts are file paths stored in `AgentThreadState.artifacts: string[]`. The artifact loading system (`core/artifacts/loader.ts`) has two paths:

1. **Server-fetched artifacts**: `GET /api/threads/{threadId}/artifacts{filepath}?download=true`. The URL is constructed by `urlOfArtifact()` in `core/artifacts/utils.ts`.
2. **Tool-call artifacts**: paths starting with `write-file:` are resolved from in-memory tool call results (extracted from the thread's message history by matching `message_id` and `tool_call_id`).

Special handling: `.skill` files automatically append `/SKILL.md` to the fetch path. Artifact content is cached for 5 minutes via React Query's `staleTime`.

The right panel renders either `ArtifactFileDetail` (single selected artifact with CodeMirror editor or syntax highlighting) or `ArtifactFileList` (grid of available artifacts when none is selected).

### Message Display Pipeline

`message-list.tsx` calls `groupMessages()` from `core/messages/utils.ts` which categorizes the flat message array into typed groups:

| Group Type | Trigger | Renders |
|------------|---------|---------|
| `human` | `message.type === "human"` | `MessageListItem` |
| `assistant:processing` | AI messages with tool calls, before final answer | `MessageGroup` (reasoning + tool calls) |
| `assistant` | Final AI response with content | `MessageListItem` |
| `assistant:present-files` | AI messages containing file presentation | `ArtifactFileList` + optional `MarkdownContent` |
| `assistant:clarification` | Clarification tool results | `MarkdownContent` |
| `assistant:subagent` | AI messages with `task` tool calls | `SubtaskCard` per task (tracks in_progress/completed/failed/timed out) |

### i18n

Two locales supported: `en-US` and `zh-CN` (`core/i18n/locales/`). Locale is detected server-side from a cookie and passed to `I18nProvider`. Translation objects use nested keys (e.g., `t.inputBox.flashMode`, `t.subtasks.executing(n)`). Cookie persistence: `locale=<value>; path=/; max-age=31536000` (1 year).

### Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| react | 19.0.0 | UI framework |
| next | 16.1.7 | App framework (App Router, Turbopack dev) |
| @langchain/langgraph-sdk | 1.5.3 | LangGraph client + `useStream()` hook |
| @tanstack/react-query | 5.90.17 | Server state management |
| @radix-ui/* | various | 15+ primitive UI components |
| tailwindcss | 4.0.15 | Utility-first CSS |
| @uiw/react-codemirror | 4.25.4 | Code editing/display |
| shiki | 3.15.0 | Syntax highlighting |
| better-auth | 1.3 | Authentication |
| ai | 6.0.33 | Vercel AI SDK (type imports) |
| motion | 12.26.2 | Animations (framer-motion successor) |
| @xyflow/react | 12.10.0 | Node/edge canvas |
| sonner | 2.0.7 | Toast notifications |
| streamdown | 1.4.0 | Streaming markdown rendering |
| react-resizable-panels | 4.4.1 | Split-panel layout |
| cmdk | 1.1.1 | Command palette (model selector) |
| gsap | 3.13.0 | Landing page animations |

## Key Files

| File | Purpose |
|------|---------|
| `frontend/src/app/layout.tsx` | Root layout: ThemeProvider + I18nProvider |
| `frontend/src/app/workspace/layout.tsx` | Workspace layout: QueryClientProvider + SidebarProvider |
| `frontend/src/app/workspace/chats/[thread_id]/layout.tsx` | Chat layout: SubtasksProvider + ArtifactsProvider + PromptInputProvider |
| `frontend/src/app/workspace/chats/[thread_id]/page.tsx` | Main chat page: wires up useThreadStream, MessageList, InputBox, ChatBox |
| `frontend/src/core/threads/hooks.ts` | `useThreadStream()` -- wraps LangGraph useStream(), file upload, optimistic messages |
| `frontend/src/core/threads/types.ts` | `AgentThreadState` (title, messages, artifacts, todos), `AgentThreadContext` |
| `frontend/src/core/api/api-client.ts` | Singleton LangGraphClient with stream mode sanitization |
| `frontend/src/core/settings/local.ts` | LocalSettings type + localStorage persistence (`deerflow.local-settings`) |
| `frontend/src/core/tasks/context.tsx` | SubtaskContext + SubtasksProvider for subagent task tracking |
| `frontend/src/core/artifacts/loader.ts` | Artifact fetch logic (server GET or in-memory tool-call extraction) |
| `frontend/src/core/artifacts/utils.ts` | `urlOfArtifact()` URL construction |
| `frontend/src/core/messages/utils.ts` | `groupMessages()` -- categorizes flat message array into display groups |
| `frontend/src/components/workspace/chats/chat-box.tsx` | Resizable split panel (60/40 chat/artifacts) |
| `frontend/src/components/workspace/input-box.tsx` | Input area: mode selector, model picker, reasoning effort, suggestions |
| `frontend/src/components/workspace/messages/message-list.tsx` | Message rendering pipeline |
| `frontend/src/components/workspace/messages/context.ts` | ThreadContext (BaseStream<AgentThreadState>) |
| `frontend/src/components/workspace/artifacts/context.tsx` | ArtifactsContext + ArtifactsProvider |
| `frontend/src/core/i18n/context.tsx` | I18nProvider with cookie-based locale persistence |
| `frontend/src/core/api/stream-mode.ts` | Stream mode sanitization/validation |

## Design Decisions

**React Context over Zustand/Redux.** The codebase uses zero external state management libraries. All shared state flows through React Context providers (`SubtaskContext`, `ArtifactsContext`, `ThreadContext`, `I18nContext`). Server state is handled by React Query. This eliminates an extra dependency and keeps the state model straightforward -- each context has a narrow, well-defined scope.

**Split panel for artifacts.** The chat panel and artifact panel are a resizable pair (via `react-resizable-panels`). When no artifacts are selected the chat takes 100% width. When artifacts open, it shifts to 60/40. This lets users preview generated files while continuing to chat, without navigating away from the conversation.

**LangGraph SDK directly instead of custom WebSocket.** The frontend uses `@langchain/langgraph-sdk`'s `useStream()` hook directly rather than implementing custom SSE or WebSocket handling. This provides built-in reconnection (`reconnectOnMount: true`), resumable streams (`streamResumable: true`), subgraph streaming (`streamSubgraphs: true`), and state history fetching. The API client applies a stream mode sanitization layer to drop unsupported modes gracefully.

**Mode selector (flash/thinking/pro/ultra) instead of explicit model picker.** The input box presents four cognitive modes rather than raw model names. Each mode maps to a combination of backend flags: `thinking_enabled`, `is_plan_mode`, `subagent_enabled`, and `reasoning_effort`. The actual model is selected separately via a secondary picker. This abstracts capability levels from model implementation details.

## Gotchas

- **No Zustand anywhere.** Some external documentation claims DeerFlow uses Zustand for state management. The actual codebase uses React Context + hooks exclusively. `package.json` has no Zustand dependency.
- **No built-in DAG/workflow visualization for end users.** The `canvas.tsx` component uses XYFlow but is for displaying node graphs within conversations, not for visualizing the agent's internal LangGraph workflow. LangGraph Studio is the developer tool for that.
- **SSE timeout sensitivity.** Streaming connections route through `/api/langgraph` which proxies to the LangGraph backend. Long-running tasks with `recursion_limit: 1000` and `subagent_enabled: true` (ultra mode) can produce very long streams. Upstream Nginx or reverse proxy timeouts need to accommodate this.
- **better-auth is present but optional.** The `better-auth` package is installed and has a catch-all route at `/api/auth/[...all]`, but authentication appears optional for development -- the workspace loads and functions without any auth configuration.
- **history.replaceState instead of Next.js router.** The chat page explicitly uses the native History API (`history.replaceState`) instead of `next/navigation` for URL updates after thread creation. A code comment warns that using the Next.js router would cause the thread to re-mount and lose all streaming state.
- **Optimistic messages require careful cleanup.** The `useThreadStream` hook maintains a parallel `optimisticMessages` array merged with `thread.messages` for display. These are cleared when the server message count increases, but error paths must also clear them to avoid ghost messages.
