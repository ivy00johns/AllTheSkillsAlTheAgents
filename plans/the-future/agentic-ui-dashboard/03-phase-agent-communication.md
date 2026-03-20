# Phase 3 — Agent Communication Layer

**Version:** 0.1.0-draft
**Date:** 2026-03-20
**Status:** Design
**Depends on:** Phase 1 (Foundation Shell)
**Enables:** Phase 4 (Approval + Quality Gates), Phase 6 (Observability + Coordination)
**Duration:** 2-3 weeks

---

## 1. Objective

Build the communication backbone that connects the Rust backend process manager to the React frontend via three transport channels: SSE for unidirectional event streaming, WebSocket for bidirectional terminal I/O, and REST for stateless control commands. All agent events are normalized to the AG-UI protocol's 17 event types before reaching the frontend.

This phase delivers the core infrastructure that every subsequent phase depends on: the ability to spawn agent subprocesses, capture their output in real-time, stream events to the dashboard, and accept control commands from the user.

---

## 2. Scope

### 2.1 AG-UI Protocol Adapter

The adapter layer sits between the Rust event bus and the SSE endpoint, converting internal `ProcessEvent` values into AG-UI's standardized event types. This is the single point of protocol translation -- all downstream consumers (frontend, persistence, observability) receive AG-UI-formatted events.

**Event type mapping:**

| Internal Event | AG-UI Event Type | When |
|---------------|-----------------|------|
| Agent spawned | `RUN_STARTED` | Process manager successfully spawns subprocess |
| Agent stdout chunk | `TEXT_MESSAGE_CONTENT` | Each line of stdout output |
| Agent stderr chunk | `TEXT_MESSAGE_CONTENT` | Each line of stderr (tagged with `stream: "stderr"`) |
| Tool call detected | `TOOL_CALL_START` | Agent invokes a tool (parsed from output) |
| Tool arguments | `TOOL_CALL_ARGS` | Tool invocation parameters |
| Tool result | `TOOL_CALL_RESULT` | Tool execution output |
| Tool complete | `TOOL_CALL_END` | Tool invocation finished |
| State change | `STATE_DELTA` | Agent status transitions (queued -> running -> completed) |
| Full state sync | `STATE_SNAPSHOT` | 5-second periodic refresh or reconnection recovery |
| Agent completed | `RUN_FINISHED` | Agent exits with code 0 |
| QA gate block | `RUN_FINISHED` | Agent pauses for quality gate (outcome: "interrupt") |
| Agent error | `RUN_FINISHED` | Agent exits with non-zero code (outcome: "error") |
| Agent reasoning | `REASONING_MESSAGE_CONTENT` | Extended thinking output (if parseable) |
| QA report output | `RAW` | Raw qa-report.json payload |

**Multi-agent multiplexing:** Every AG-UI event is extended with `agentId` and `agentRole` fields to support routing over a single SSE stream. The frontend's event processor routes events to the correct block's Jotai atoms based on these fields.

**Event sequencing:** Each event carries a monotonically increasing `sequenceId` (u64, assigned by the Rust event bus). The frontend uses this to detect gaps and request state snapshots when events are missed.

**State machine validation:** The adapter enforces the AG-UI lifecycle state machine per agent:

```
IDLE -> RUN_STARTED -> (TEXT_MESSAGE_CONTENT | TOOL_CALL_* | STATE_DELTA | REASONING_MESSAGE_CONTENT)* -> RUN_FINISHED
```

Events that violate this ordering (for example, `TEXT_MESSAGE_CONTENT` before `RUN_STARTED`) are logged as warnings and dropped.

### 2.2 Rust Process Manager

The process manager is the core Rust component responsible for spawning, monitoring, and terminating agent subprocesses. It operates within the Tokio async runtime and communicates with the rest of the backend via a broadcast channel.

**Two spawn modes:**

1. **Pipe mode** (`child_process.spawn()` with `stdio: 'pipe'`): For non-interactive agents that read a prompt from stdin and write output to stdout/stderr. This is the default for Claude Code agents running with `--print` or headless flags.

2. **PTY mode** (`node-pty` / `portable-pty` integration): For agents that need full terminal emulation (ANSI escape sequences, cursor movement, screen clearing). Required when an agent needs to interact with tools that expect a real terminal (git interactive rebase, vim, etc.).

**Core data structures:**

```rust
use std::collections::HashMap;
use tokio::sync::broadcast;
use chrono::{DateTime, Utc};

/// Manages all agent subprocesses for a build session.
pub struct ProcessManager {
    processes: HashMap<String, ManagedProcess>,
    event_tx: broadcast::Sender<ProcessEvent>,
    max_processes: usize,
    worktree_root: PathBuf,
}

/// A single managed agent subprocess.
pub struct ManagedProcess {
    pub id: String,
    pub role: AgentRole,
    pub child: Option<tokio::process::Child>,
    pub status: ProcessStatus,
    pub started_at: DateTime<Utc>,
    pub stdout_buffer: RingBuffer<OutputLine>,  // Last 10,000 lines
    pub stderr_buffer: RingBuffer<OutputLine>,  // Last 5,000 lines
    pub worktree_path: PathBuf,
    pub branch_name: String,
    pub pid: Option<u32>,
    pub stdin_tx: Option<tokio::sync::mpsc::Sender<Vec<u8>>>,
}

/// Ring buffer for bounded output retention.
pub struct RingBuffer<T> {
    buffer: Vec<T>,
    capacity: usize,
    head: usize,
    len: usize,
}

/// A single line of captured output.
pub struct OutputLine {
    pub content: String,
    pub timestamp: DateTime<Utc>,
    pub line_number: u64,
}

#[derive(Clone, Debug)]
pub enum ProcessStatus {
    Spawning,
    Running,
    WaitingForApproval { gate_id: String },
    Paused,
    Completed { exit_code: i32 },
    Failed { exit_code: i32, error: String },
    Killed,
}

#[derive(Clone, Debug, serde::Serialize)]
pub enum AgentRole {
    Backend,
    Frontend,
    Infrastructure,
    QE,
    Security,
    Docs,
    Observability,
    DbMigration,
    Performance,
}

#[derive(Clone, Debug)]
pub enum ProcessEvent {
    Spawned {
        id: String,
        role: AgentRole,
        pid: u32,
        worktree: String,
    },
    Output {
        id: String,
        stream: StdStream,
        data: String,
        timestamp: DateTime<Utc>,
        line_number: u64,
    },
    StatusChanged {
        id: String,
        from: ProcessStatus,
        to: ProcessStatus,
    },
    Exited {
        id: String,
        code: i32,
        duration_ms: u64,
    },
    Error {
        id: String,
        error: String,
    },
}

#[derive(Clone, Debug)]
pub enum StdStream {
    Stdout,
    Stderr,
}
```

**Spawn implementation:**

```rust
impl ProcessManager {
    /// Spawn a new agent subprocess with its own git worktree.
    pub async fn spawn_agent(
        &mut self,
        role: AgentRole,
        config: &AgentConfig,
    ) -> Result<String, ProcessError> {
        let id = format!("{}-{}", role.as_str(), Uuid::new_v4().to_string()[..8].to_string());

        // Create git worktree for isolation
        let branch_name = format!("agent/{}/{}", role.as_str(), &id);
        let worktree_path = self.worktree_root.join(&id);
        self.create_worktree(&worktree_path, &branch_name).await?;

        // Build the command
        let mut cmd = tokio::process::Command::new(&config.binary);
        cmd.args(&config.args)
            .current_dir(&worktree_path)
            .stdin(std::process::Stdio::piped())
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .env("AGENT_ID", &id)
            .env("AGENT_ROLE", role.as_str())
            .env("BUILD_SESSION_ID", &config.build_id);

        // Inject skill-specific environment
        for (key, value) in &config.env {
            cmd.env(key, value);
        }

        let mut child = cmd.spawn().map_err(|e| ProcessError::SpawnFailed {
            role: role.clone(),
            error: e.to_string(),
        })?;

        let pid = child.id().unwrap_or(0);

        // Set up stdin channel
        let stdin = child.stdin.take().expect("stdin was piped");
        let (stdin_tx, mut stdin_rx) = tokio::sync::mpsc::channel::<Vec<u8>>(256);

        // Forward stdin channel to process
        tokio::spawn(async move {
            let mut stdin = stdin;
            while let Some(data) = stdin_rx.recv().await {
                if tokio::io::AsyncWriteExt::write_all(&mut stdin, &data).await.is_err() {
                    break;
                }
            }
        });

        // Capture stdout in background task
        let stdout = child.stdout.take().expect("stdout was piped");
        self.spawn_output_reader(id.clone(), StdStream::Stdout, stdout);

        // Capture stderr in background task
        let stderr = child.stderr.take().expect("stderr was piped");
        self.spawn_output_reader(id.clone(), StdStream::Stderr, stderr);

        // Monitor process exit in background
        self.spawn_exit_monitor(id.clone(), child);

        let process = ManagedProcess {
            id: id.clone(),
            role: role.clone(),
            child: None, // Ownership moved to exit monitor
            status: ProcessStatus::Running,
            started_at: Utc::now(),
            stdout_buffer: RingBuffer::new(10_000),
            stderr_buffer: RingBuffer::new(5_000),
            worktree_path,
            branch_name,
            pid: Some(pid),
            stdin_tx: Some(stdin_tx),
        };

        self.processes.insert(id.clone(), process);

        let _ = self.event_tx.send(ProcessEvent::Spawned {
            id: id.clone(),
            role,
            pid,
            worktree: worktree_path.to_string_lossy().to_string(),
        });

        Ok(id)
    }

    /// Capture output line-by-line and emit events.
    fn spawn_output_reader(
        &self,
        id: String,
        stream: StdStream,
        reader: impl tokio::io::AsyncRead + Unpin + Send + 'static,
    ) {
        let tx = self.event_tx.clone();
        let mut line_counter: u64 = 0;

        tokio::spawn(async move {
            let mut lines = tokio::io::BufReader::new(reader).lines();

            while let Ok(Some(line)) = lines.next_line().await {
                line_counter += 1;
                let _ = tx.send(ProcessEvent::Output {
                    id: id.clone(),
                    stream: stream.clone(),
                    data: line,
                    timestamp: Utc::now(),
                    line_number: line_counter,
                });
            }
        });
    }

    /// Monitor process exit and emit status change.
    fn spawn_exit_monitor(&self, id: String, mut child: tokio::process::Child) {
        let tx = self.event_tx.clone();
        let started = Utc::now();

        tokio::spawn(async move {
            match child.wait().await {
                Ok(status) => {
                    let code = status.code().unwrap_or(-1);
                    let duration_ms = (Utc::now() - started).num_milliseconds() as u64;

                    let _ = tx.send(ProcessEvent::Exited {
                        id: id.clone(),
                        code,
                        duration_ms,
                    });

                    let _ = tx.send(ProcessEvent::StatusChanged {
                        id: id.clone(),
                        from: ProcessStatus::Running,
                        to: if code == 0 {
                            ProcessStatus::Completed { exit_code: code }
                        } else {
                            ProcessStatus::Failed {
                                exit_code: code,
                                error: format!("Process exited with code {}", code),
                            }
                        },
                    });
                }
                Err(e) => {
                    let _ = tx.send(ProcessEvent::Error {
                        id: id.clone(),
                        error: e.to_string(),
                    });
                }
            }
        });
    }

    /// Send SIGTERM, wait 5 seconds, then SIGKILL if still alive.
    pub async fn kill_agent(&mut self, id: &str) -> Result<(), ProcessError> {
        let process = self.processes.get_mut(id)
            .ok_or(ProcessError::NotFound(id.to_string()))?;

        if let Some(pid) = process.pid {
            // Send SIGTERM
            unsafe {
                libc::kill(pid as i32, libc::SIGTERM);
            }

            // Wait up to 5 seconds for graceful shutdown
            let deadline = tokio::time::Instant::now() + tokio::time::Duration::from_secs(5);
            loop {
                if tokio::time::Instant::now() >= deadline {
                    // Force kill
                    unsafe {
                        libc::kill(pid as i32, libc::SIGKILL);
                    }
                    break;
                }

                // Check if process has exited
                // In practice, the exit monitor task handles this
                tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
            }

            process.status = ProcessStatus::Killed;

            let _ = self.event_tx.send(ProcessEvent::StatusChanged {
                id: id.to_string(),
                from: ProcessStatus::Running,
                to: ProcessStatus::Killed,
            });
        }

        // Clean up git worktree
        self.remove_worktree(&process.worktree_path).await?;

        Ok(())
    }

    /// Retrieve the output buffer for an agent (for REST /logs endpoint).
    pub fn get_output_buffer(&self, id: &str) -> Result<Vec<OutputLine>, ProcessError> {
        let process = self.processes.get(id)
            .ok_or(ProcessError::NotFound(id.to_string()))?;
        Ok(process.stdout_buffer.to_vec())
    }

    /// Send data to an agent's stdin.
    pub async fn send_to_stdin(&self, id: &str, data: Vec<u8>) -> Result<(), ProcessError> {
        let process = self.processes.get(id)
            .ok_or(ProcessError::NotFound(id.to_string()))?;

        if let Some(tx) = &process.stdin_tx {
            tx.send(data).await.map_err(|_| ProcessError::StdinClosed(id.to_string()))?;
        }

        Ok(())
    }
}
```

**Git worktree management:**

```rust
impl ProcessManager {
    /// Create a git worktree for agent isolation.
    /// One agent = one worktree = one branch = one PR.
    async fn create_worktree(
        &self,
        path: &Path,
        branch: &str,
    ) -> Result<(), ProcessError> {
        // Create branch from current HEAD
        let output = tokio::process::Command::new("git")
            .args(["worktree", "add", "-b", branch, path.to_str().unwrap()])
            .current_dir(&self.worktree_root)
            .output()
            .await
            .map_err(|e| ProcessError::WorktreeCreation(e.to_string()))?;

        if !output.status.success() {
            return Err(ProcessError::WorktreeCreation(
                String::from_utf8_lossy(&output.stderr).to_string()
            ));
        }

        Ok(())
    }

    /// Remove a git worktree after agent completion.
    async fn remove_worktree(&self, path: &Path) -> Result<(), ProcessError> {
        let _ = tokio::process::Command::new("git")
            .args(["worktree", "remove", "--force", path.to_str().unwrap()])
            .current_dir(&self.worktree_root)
            .output()
            .await;
        Ok(())
    }
}
```

### 2.3 AG-UI Event Adapter (Rust)

The adapter converts internal `ProcessEvent` values to AG-UI-formatted JSON before they reach the SSE endpoint.

```rust
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// AG-UI event types as defined by the protocol specification.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum AgUiEvent {
    #[serde(rename = "RUN_STARTED")]
    RunStarted {
        #[serde(rename = "runId")]
        run_id: String,
        #[serde(rename = "agentId")]
        agent_id: String,
        #[serde(rename = "agentRole")]
        agent_role: String,
        #[serde(rename = "threadId")]
        thread_id: String,
    },

    #[serde(rename = "TEXT_MESSAGE_START")]
    TextMessageStart {
        #[serde(rename = "messageId")]
        message_id: String,
        #[serde(rename = "agentId")]
        agent_id: String,
        role: String,
    },

    #[serde(rename = "TEXT_MESSAGE_CONTENT")]
    TextMessageContent {
        #[serde(rename = "messageId")]
        message_id: String,
        #[serde(rename = "agentId")]
        agent_id: String,
        delta: String,
    },

    #[serde(rename = "TEXT_MESSAGE_END")]
    TextMessageEnd {
        #[serde(rename = "messageId")]
        message_id: String,
        #[serde(rename = "agentId")]
        agent_id: String,
    },

    #[serde(rename = "TOOL_CALL_START")]
    ToolCallStart {
        #[serde(rename = "toolCallId")]
        tool_call_id: String,
        #[serde(rename = "agentId")]
        agent_id: String,
        #[serde(rename = "toolName")]
        tool_name: String,
    },

    #[serde(rename = "TOOL_CALL_ARGS")]
    ToolCallArgs {
        #[serde(rename = "toolCallId")]
        tool_call_id: String,
        #[serde(rename = "agentId")]
        agent_id: String,
        delta: String,
    },

    #[serde(rename = "TOOL_CALL_END")]
    ToolCallEnd {
        #[serde(rename = "toolCallId")]
        tool_call_id: String,
        #[serde(rename = "agentId")]
        agent_id: String,
    },

    #[serde(rename = "STATE_SNAPSHOT")]
    StateSnapshot {
        snapshot: serde_json::Value,
    },

    #[serde(rename = "STATE_DELTA")]
    StateDelta {
        #[serde(rename = "agentId")]
        agent_id: String,
        delta: Vec<JsonPatch>,
    },

    #[serde(rename = "RUN_FINISHED")]
    RunFinished {
        #[serde(rename = "runId")]
        run_id: String,
        #[serde(rename = "agentId")]
        agent_id: String,
        outcome: RunOutcome,
    },

    #[serde(rename = "RAW")]
    Raw {
        #[serde(rename = "agentId")]
        agent_id: String,
        #[serde(rename = "rawType")]
        raw_type: String,
        payload: serde_json::Value,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum RunOutcome {
    #[serde(rename = "success")]
    Success,
    #[serde(rename = "error")]
    Error { message: String, code: Option<i32> },
    #[serde(rename = "interrupt")]
    Interrupt {
        id: String,
        reason: String,
        payload: serde_json::Value,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct JsonPatch {
    pub op: String,       // "replace", "add", "remove"
    pub path: String,     // JSON Pointer path
    pub value: Option<serde_json::Value>,
}

/// Envelope wrapping every event with metadata for multiplexing.
#[derive(Clone, Debug, Serialize)]
pub struct EventEnvelope {
    #[serde(rename = "sequenceId")]
    pub sequence_id: u64,
    pub timestamp: String,
    pub event: AgUiEvent,
}

/// Convert internal ProcessEvent to AG-UI event(s).
/// Some internal events map to multiple AG-UI events.
pub fn convert_process_event(
    event: &ProcessEvent,
    sequence_counter: &mut u64,
) -> Vec<EventEnvelope> {
    let mut results = Vec::new();

    match event {
        ProcessEvent::Spawned { id, role, pid, worktree } => {
            *sequence_counter += 1;
            results.push(EventEnvelope {
                sequence_id: *sequence_counter,
                timestamp: Utc::now().to_rfc3339(),
                event: AgUiEvent::RunStarted {
                    run_id: id.clone(),
                    agent_id: id.clone(),
                    agent_role: role.as_str().to_string(),
                    thread_id: format!("thread-{}", id),
                },
            });
        }

        ProcessEvent::Output { id, stream, data, timestamp, line_number } => {
            // Each output line becomes a TEXT_MESSAGE_CONTENT event.
            // We generate message IDs based on agent ID + line number
            // for deterministic deduplication.
            let message_id = format!("{}-msg-{}", id, line_number);

            *sequence_counter += 1;
            results.push(EventEnvelope {
                sequence_id: *sequence_counter,
                timestamp: timestamp.to_rfc3339(),
                event: AgUiEvent::TextMessageContent {
                    message_id,
                    agent_id: id.clone(),
                    delta: data.clone(),
                },
            });
        }

        ProcessEvent::StatusChanged { id, from, to } => {
            *sequence_counter += 1;
            results.push(EventEnvelope {
                sequence_id: *sequence_counter,
                timestamp: Utc::now().to_rfc3339(),
                event: AgUiEvent::StateDelta {
                    agent_id: id.clone(),
                    delta: vec![JsonPatch {
                        op: "replace".to_string(),
                        path: format!("/agents/{}/status", id),
                        value: Some(serde_json::to_value(to).unwrap()),
                    }],
                },
            });
        }

        ProcessEvent::Exited { id, code, duration_ms } => {
            *sequence_counter += 1;
            let outcome = if *code == 0 {
                RunOutcome::Success
            } else {
                RunOutcome::Error {
                    message: format!("Agent exited with code {}", code),
                    code: Some(*code),
                }
            };

            results.push(EventEnvelope {
                sequence_id: *sequence_counter,
                timestamp: Utc::now().to_rfc3339(),
                event: AgUiEvent::RunFinished {
                    run_id: id.clone(),
                    agent_id: id.clone(),
                    outcome,
                },
            });
        }

        ProcessEvent::Error { id, error } => {
            *sequence_counter += 1;
            results.push(EventEnvelope {
                sequence_id: *sequence_counter,
                timestamp: Utc::now().to_rfc3339(),
                event: AgUiEvent::RunFinished {
                    run_id: id.clone(),
                    agent_id: id.clone(),
                    outcome: RunOutcome::Error {
                        message: error.clone(),
                        code: None,
                    },
                },
            });
        }
    }

    results
}
```

### 2.4 SSE Production Endpoint

The SSE endpoint is built with Axum and handles initial state snapshots, real-time event streaming, backpressure via lag detection, and keep-alive pings.

```rust
use axum::{
    extract::{Query, State},
    response::sse::{Event, KeepAlive, Sse},
};
use futures::stream::Stream;
use std::convert::Infallible;
use std::time::Duration;
use tokio::sync::broadcast;

#[derive(Debug, Deserialize)]
pub struct SSEParams {
    /// Optional: resume from a specific sequence ID.
    #[serde(rename = "lastEventId")]
    last_event_id: Option<u64>,

    /// Optional: filter events to a specific agent.
    #[serde(rename = "agentId")]
    agent_id: Option<String>,
}

/// SSE endpoint: GET /api/events
pub async fn sse_events(
    State(app): State<AppState>,
    Query(params): Query<SSEParams>,
) -> Sse<impl Stream<Item = Result<Event, Infallible>>> {
    let mut rx = app.event_bus.subscribe();

    let stream = async_stream::stream! {
        // 1. Send initial STATE_SNAPSHOT on connect.
        //    This gives the client the full current state regardless
        //    of when they connected.
        let full_state = app.orchestrator.get_full_state().await;
        let snapshot = EventEnvelope {
            sequence_id: app.sequence_counter.load(Ordering::SeqCst),
            timestamp: Utc::now().to_rfc3339(),
            event: AgUiEvent::StateSnapshot {
                snapshot: serde_json::to_value(&full_state).unwrap(),
            },
        };

        yield Ok(Event::default()
            .event("STATE_SNAPSHOT")
            .data(serde_json::to_string(&snapshot).unwrap())
            .id(snapshot.sequence_id.to_string()));

        // 2. Stream events from broadcast channel.
        loop {
            match rx.recv().await {
                Ok(envelope) => {
                    // Apply agent filter if specified
                    if let Some(ref filter_id) = params.agent_id {
                        if !envelope_matches_agent(&envelope, filter_id) {
                            continue;
                        }
                    }

                    // Skip events the client already has (reconnection)
                    if let Some(last_id) = params.last_event_id {
                        if envelope.sequence_id <= last_id {
                            continue;
                        }
                    }

                    let event_type = event_type_name(&envelope.event);
                    yield Ok(Event::default()
                        .event(&event_type)
                        .data(serde_json::to_string(&envelope).unwrap())
                        .id(envelope.sequence_id.to_string()));
                }

                Err(broadcast::error::RecvError::Lagged(n)) => {
                    // Client fell behind the broadcast buffer.
                    // Instead of trying to replay N missed events,
                    // send a full state snapshot to resynchronize.
                    log::warn!("SSE client lagged by {} events, sending state snapshot", n);

                    let full_state = app.orchestrator.get_full_state().await;
                    let snapshot = EventEnvelope {
                        sequence_id: app.sequence_counter.load(Ordering::SeqCst),
                        timestamp: Utc::now().to_rfc3339(),
                        event: AgUiEvent::StateSnapshot {
                            snapshot: serde_json::to_value(&full_state).unwrap(),
                        },
                    };

                    yield Ok(Event::default()
                        .event("STATE_SNAPSHOT")
                        .data(serde_json::to_string(&snapshot).unwrap())
                        .id(snapshot.sequence_id.to_string()));
                }

                Err(broadcast::error::RecvError::Closed) => {
                    // Channel closed, terminate stream
                    break;
                }
            }
        }
    };

    Sse::new(stream).keep_alive(
        KeepAlive::new()
            .interval(Duration::from_secs(15))
            .text("ping")
    )
}

/// Extract the AG-UI event type name for the SSE event field.
fn event_type_name(event: &AgUiEvent) -> String {
    match event {
        AgUiEvent::RunStarted { .. } => "RUN_STARTED".to_string(),
        AgUiEvent::TextMessageStart { .. } => "TEXT_MESSAGE_START".to_string(),
        AgUiEvent::TextMessageContent { .. } => "TEXT_MESSAGE_CONTENT".to_string(),
        AgUiEvent::TextMessageEnd { .. } => "TEXT_MESSAGE_END".to_string(),
        AgUiEvent::ToolCallStart { .. } => "TOOL_CALL_START".to_string(),
        AgUiEvent::ToolCallArgs { .. } => "TOOL_CALL_ARGS".to_string(),
        AgUiEvent::ToolCallEnd { .. } => "TOOL_CALL_END".to_string(),
        AgUiEvent::StateSnapshot { .. } => "STATE_SNAPSHOT".to_string(),
        AgUiEvent::StateDelta { .. } => "STATE_DELTA".to_string(),
        AgUiEvent::RunFinished { .. } => "RUN_FINISHED".to_string(),
        AgUiEvent::Raw { .. } => "RAW".to_string(),
    }
}
```

**Broadcast channel setup:**

```rust
/// Application state shared across all Axum handlers.
pub struct AppState {
    pub event_bus: broadcast::Sender<EventEnvelope>,
    pub orchestrator: Arc<Orchestrator>,
    pub process_manager: Arc<tokio::sync::RwLock<ProcessManager>>,
    pub sequence_counter: Arc<AtomicU64>,
    pub db: Arc<rusqlite::Connection>,
}

impl AppState {
    pub fn new(db: rusqlite::Connection, worktree_root: PathBuf) -> Self {
        // 4096-event buffer. When a subscriber falls behind by this many
        // events, they receive RecvError::Lagged and we send a snapshot.
        let (event_tx, _) = broadcast::channel::<EventEnvelope>(4096);

        let process_manager = ProcessManager {
            processes: HashMap::new(),
            event_tx: event_tx.clone(),
            max_processes: 20,
            worktree_root,
        };

        Self {
            event_bus: event_tx,
            orchestrator: Arc::new(Orchestrator::new()),
            process_manager: Arc::new(tokio::sync::RwLock::new(process_manager)),
            sequence_counter: Arc::new(AtomicU64::new(0)),
            db: Arc::new(db),
        }
    }
}
```

**5-second periodic state snapshot:**

```rust
/// Spawns a background task that emits STATE_SNAPSHOT every 5 seconds.
/// This provides self-healing: any missed SSE patches are recovered
/// within 5 seconds.
pub fn spawn_periodic_snapshot(app: AppState) {
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_secs(5));

        loop {
            interval.tick().await;

            let full_state = app.orchestrator.get_full_state().await;
            let seq = app.sequence_counter.fetch_add(1, Ordering::SeqCst);

            let envelope = EventEnvelope {
                sequence_id: seq,
                timestamp: Utc::now().to_rfc3339(),
                event: AgUiEvent::StateSnapshot {
                    snapshot: serde_json::to_value(&full_state).unwrap(),
                },
            };

            // Ignore send errors (no subscribers)
            let _ = app.event_bus.send(envelope);
        }
    });
}
```

### 2.5 WebSocket Terminal Endpoint

The WebSocket endpoint provides bidirectional communication for interactive terminal sessions. It is only used when an agent needs PTY-mode interaction (for example, manual debugging, or agents that use interactive tools).

```rust
use axum::{
    extract::{ws::{Message, WebSocket, WebSocketUpgrade}, Path, State},
    response::IntoResponse,
};
use futures::{SinkExt, StreamExt};

/// WebSocket endpoint: GET /api/terminal/:agent_id
pub async fn ws_terminal(
    ws: WebSocketUpgrade,
    Path(agent_id): Path<String>,
    State(app): State<AppState>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_terminal_ws(socket, agent_id, app))
}

async fn handle_terminal_ws(socket: WebSocket, agent_id: String, app: AppState) {
    let (mut ws_sender, mut ws_receiver) = socket.split();

    let pm = app.process_manager.read().await;
    let process = match pm.processes.get(&agent_id) {
        Some(p) => p,
        None => {
            let _ = ws_sender
                .send(Message::Close(Some(axum::extract::ws::CloseFrame {
                    code: 4004,
                    reason: "Agent not found".into(),
                })))
                .await;
            return;
        }
    };

    // Subscribe to agent output for sending to the client
    let mut output_rx = app.event_bus.subscribe();
    let target_agent_id = agent_id.clone();

    // Task 1: Forward agent output -> WebSocket client
    let send_task = tokio::spawn(async move {
        loop {
            match output_rx.recv().await {
                Ok(envelope) => {
                    // Only forward output events for this agent
                    if let AgUiEvent::TextMessageContent {
                        ref agent_id, ref delta, ..
                    } = envelope.event {
                        if agent_id == &target_agent_id {
                            if ws_sender
                                .send(Message::Binary(delta.as_bytes().to_vec()))
                                .await
                                .is_err()
                            {
                                break;
                            }
                        }
                    }
                }
                Err(broadcast::error::RecvError::Lagged(_)) => {
                    // Skip lagged events for terminal -- real-time only
                    continue;
                }
                Err(_) => break,
            }
        }
    });

    // Task 2: Forward WebSocket client input -> agent stdin
    let stdin_agent_id = agent_id.clone();
    let pm_clone = app.process_manager.clone();
    let recv_task = tokio::spawn(async move {
        while let Some(Ok(msg)) = ws_receiver.next().await {
            match msg {
                Message::Binary(data) => {
                    let pm = pm_clone.read().await;
                    if let Err(e) = pm.send_to_stdin(&stdin_agent_id, data).await {
                        log::error!("Failed to send to stdin: {}", e);
                        break;
                    }
                }
                Message::Text(text) => {
                    let pm = pm_clone.read().await;
                    if let Err(e) = pm.send_to_stdin(&stdin_agent_id, text.into_bytes()).await {
                        log::error!("Failed to send to stdin: {}", e);
                        break;
                    }
                }
                Message::Close(_) => break,
                _ => {}
            }
        }
    });

    // Wait for either task to complete, then cancel the other.
    tokio::select! {
        _ = send_task => {}
        _ = recv_task => {}
    }

    log::info!("Terminal WebSocket closed for agent {}", agent_id);
}
```

### 2.6 REST Control API

The REST API provides stateless control commands. All endpoints require authentication (covered in Phase 8 RBAC; for now, no auth middleware is applied).

```rust
use axum::{
    extract::{Json, Path, State},
    http::StatusCode,
    routing::{get, post},
    Router,
};

/// Build the full Axum router.
pub fn build_router(app: AppState) -> Router {
    Router::new()
        // SSE stream
        .route("/api/events", get(sse_events))

        // WebSocket terminal
        .route("/api/terminal/:agent_id", get(ws_terminal))

        // Build lifecycle
        .route("/api/build/start", post(start_build))
        .route("/api/build/pause", post(pause_build))
        .route("/api/build/resume", post(resume_build))

        // Agent control
        .route("/api/agent/:id/command", post(send_agent_command))
        .route("/api/agent/:id/logs", get(get_agent_logs))

        // Approval gates
        .route("/api/approval/:id/decide", post(decide_approval))

        // State polling fallback
        .route("/api/state", get(get_full_state))

        // Health
        .route("/health", get(health_check))

        .with_state(app)
}

// --- Request/Response types ---

#[derive(Deserialize)]
pub struct StartBuildRequest {
    pub plan_id: String,
    pub config: Option<BuildConfig>,
}

#[derive(Deserialize)]
pub struct BuildConfig {
    pub max_agents: Option<usize>,
    pub auto_approve_threshold: Option<u8>,
    pub worktree_root: Option<String>,
}

#[derive(Serialize)]
pub struct StartBuildResponse {
    pub build_id: String,
    pub agents: Vec<AgentSummary>,
    pub status: String,
}

#[derive(Serialize)]
pub struct AgentSummary {
    pub id: String,
    pub role: String,
    pub status: String,
    pub worktree: String,
}

#[derive(Deserialize)]
pub struct AgentCommandRequest {
    pub command: String,
}

#[derive(Deserialize)]
pub struct ApprovalDecisionRequest {
    pub decision: String,     // "approved" | "rejected" | "request_changes"
    pub notes: Option<String>,
}

#[derive(Serialize)]
pub struct ApiResponse<T: Serialize> {
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<String>,
}

// --- Handler implementations ---

/// POST /api/build/start
/// Starts a new build from a plan. Spawns agent subprocesses.
async fn start_build(
    State(app): State<AppState>,
    Json(req): Json<StartBuildRequest>,
) -> Result<Json<ApiResponse<StartBuildResponse>>, StatusCode> {
    let mut pm = app.process_manager.write().await;

    // Load plan and determine which agents to spawn
    let plan = app.orchestrator.load_plan(&req.plan_id).await
        .map_err(|_| StatusCode::NOT_FOUND)?;

    let build_id = Uuid::new_v4().to_string();
    let mut agents = Vec::new();

    for agent_config in &plan.agents {
        match pm.spawn_agent(agent_config.role.clone(), agent_config).await {
            Ok(id) => {
                agents.push(AgentSummary {
                    id: id.clone(),
                    role: agent_config.role.as_str().to_string(),
                    status: "running".to_string(),
                    worktree: pm.processes.get(&id)
                        .map(|p| p.worktree_path.to_string_lossy().to_string())
                        .unwrap_or_default(),
                });
            }
            Err(e) => {
                log::error!("Failed to spawn agent {:?}: {}", agent_config.role, e);
            }
        }
    }

    Ok(Json(ApiResponse {
        success: true,
        data: Some(StartBuildResponse {
            build_id,
            agents,
            status: "running".to_string(),
        }),
        error: None,
    }))
}

/// POST /api/build/pause
/// Sends SIGSTOP to all running agent processes.
async fn pause_build(
    State(app): State<AppState>,
) -> Result<Json<ApiResponse<()>>, StatusCode> {
    let pm = app.process_manager.read().await;

    for process in pm.processes.values() {
        if let (ProcessStatus::Running, Some(pid)) = (&process.status, process.pid) {
            unsafe {
                libc::kill(pid as i32, libc::SIGSTOP);
            }
        }
    }

    Ok(Json(ApiResponse {
        success: true,
        data: Some(()),
        error: None,
    }))
}

/// POST /api/build/resume
/// Sends SIGCONT to all paused agent processes.
async fn resume_build(
    State(app): State<AppState>,
) -> Result<Json<ApiResponse<()>>, StatusCode> {
    let pm = app.process_manager.read().await;

    for process in pm.processes.values() {
        if let (ProcessStatus::Paused, Some(pid)) = (&process.status, process.pid) {
            unsafe {
                libc::kill(pid as i32, libc::SIGCONT);
            }
        }
    }

    Ok(Json(ApiResponse {
        success: true,
        data: Some(()),
        error: None,
    }))
}

/// POST /api/agent/:id/command
/// Send a command string to the agent's stdin.
async fn send_agent_command(
    State(app): State<AppState>,
    Path(agent_id): Path<String>,
    Json(req): Json<AgentCommandRequest>,
) -> Result<Json<ApiResponse<()>>, StatusCode> {
    let pm = app.process_manager.read().await;

    pm.send_to_stdin(&agent_id, format!("{}\n", req.command).into_bytes())
        .await
        .map_err(|_| StatusCode::NOT_FOUND)?;

    Ok(Json(ApiResponse {
        success: true,
        data: Some(()),
        error: None,
    }))
}

/// GET /api/agent/:id/logs
/// Retrieve agent output history from the ring buffer.
async fn get_agent_logs(
    State(app): State<AppState>,
    Path(agent_id): Path<String>,
) -> Result<Json<ApiResponse<Vec<OutputLine>>>, StatusCode> {
    let pm = app.process_manager.read().await;

    let logs = pm.get_output_buffer(&agent_id)
        .map_err(|_| StatusCode::NOT_FOUND)?;

    Ok(Json(ApiResponse {
        success: true,
        data: Some(logs),
        error: None,
    }))
}

/// POST /api/approval/:id/decide
/// Approve or reject a QA gate. Resumes the blocked agent.
async fn decide_approval(
    State(app): State<AppState>,
    Path(approval_id): Path<String>,
    Json(req): Json<ApprovalDecisionRequest>,
) -> Result<Json<ApiResponse<()>>, StatusCode> {
    // Record decision in SQLite
    app.orchestrator
        .record_approval_decision(&approval_id, &req.decision, req.notes.as_deref())
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // If approved, resume the blocked agent
    if req.decision == "approved" {
        app.orchestrator
            .resume_agent_from_gate(&approval_id)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    }

    Ok(Json(ApiResponse {
        success: true,
        data: Some(()),
        error: None,
    }))
}

/// GET /api/state
/// Polling fallback: returns the full orchestrator state.
async fn get_full_state(
    State(app): State<AppState>,
) -> Result<Json<ApiResponse<serde_json::Value>>, StatusCode> {
    let state = app.orchestrator.get_full_state().await;

    Ok(Json(ApiResponse {
        success: true,
        data: Some(serde_json::to_value(&state).unwrap()),
        error: None,
    }))
}

/// GET /health
async fn health_check() -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "status": "healthy",
        "timestamp": Utc::now().to_rfc3339(),
    }))
}
```

### 2.7 Frontend SSE Client

The TypeScript client that connects to the SSE endpoint, processes events through the 50ms batch window, and routes them to the appropriate Zustand/Jotai stores.

```typescript
// src/services/sse-client.ts

import { useOrchestratorStore } from '../stores/orchestrator';
import { routeEventToBlockAtom } from '../stores/block-router';
import type { EventEnvelope, AgUiEvent } from '../types/ag-ui';

export class SSEClient {
  private eventSource: EventSource | null = null;
  private pendingEvents: EventEnvelope[] = [];
  private flushTimer: ReturnType<typeof setTimeout> | null = null;
  private batchWindowMs = 50;
  private lastEventId: string | null = null;
  private reconnectAttempts = 0;
  private maxReconnectDelay = 30_000; // 30 seconds

  constructor(private baseUrl: string) {}

  connect(agentIdFilter?: string): void {
    const params = new URLSearchParams();
    if (this.lastEventId) {
      params.set('lastEventId', this.lastEventId);
    }
    if (agentIdFilter) {
      params.set('agentId', agentIdFilter);
    }

    const url = `${this.baseUrl}/api/events?${params.toString()}`;
    this.eventSource = new EventSource(url);

    this.eventSource.onopen = () => {
      this.reconnectAttempts = 0;
      useOrchestratorStore.getState().setConnectionStatus('connected');
    };

    // Listen for all AG-UI event types
    const eventTypes = [
      'RUN_STARTED', 'RUN_FINISHED',
      'TEXT_MESSAGE_START', 'TEXT_MESSAGE_CONTENT', 'TEXT_MESSAGE_END',
      'TOOL_CALL_START', 'TOOL_CALL_ARGS', 'TOOL_CALL_END',
      'STATE_SNAPSHOT', 'STATE_DELTA',
      'REASONING_MESSAGE_CONTENT',
      'RAW',
    ];

    for (const eventType of eventTypes) {
      this.eventSource.addEventListener(eventType, (event: MessageEvent) => {
        const envelope: EventEnvelope = JSON.parse(event.data);
        this.lastEventId = event.lastEventId;
        this.enqueueEvent(envelope);
      });
    }

    this.eventSource.onerror = () => {
      useOrchestratorStore.getState().setConnectionStatus('reconnecting');

      // EventSource auto-reconnects, but we track attempts
      // for exponential backoff logging
      this.reconnectAttempts++;
      if (this.reconnectAttempts > 10) {
        console.error('SSE reconnection failing repeatedly');
        useOrchestratorStore.getState().setConnectionStatus('disconnected');
      }
    };
  }

  disconnect(): void {
    if (this.eventSource) {
      this.eventSource.close();
      this.eventSource = null;
    }
    if (this.flushTimer) {
      clearTimeout(this.flushTimer);
      this.flushTimer = null;
    }
    useOrchestratorStore.getState().setConnectionStatus('disconnected');
  }

  /** Adjust batch window based on activity level. */
  setBatchWindow(ms: number): void {
    this.batchWindowMs = ms;
  }

  private enqueueEvent(envelope: EventEnvelope): void {
    this.pendingEvents.push(envelope);

    if (!this.flushTimer) {
      this.flushTimer = setTimeout(() => {
        this.flushEvents();
      }, this.batchWindowMs);
    }
  }

  private flushEvents(): void {
    const events = [...this.pendingEvents];
    this.pendingEvents.length = 0;
    this.flushTimer = null;

    if (events.length === 0) return;

    // Check for STATE_SNAPSHOT -- if present, use the latest one
    // and discard earlier events (snapshot is the full truth)
    const lastSnapshot = events
      .filter(e => e.event.type === 'STATE_SNAPSHOT')
      .pop();

    if (lastSnapshot) {
      // Apply full state replacement
      useOrchestratorStore.getState().applyStateSnapshot(
        (lastSnapshot.event as any).snapshot
      );
    }

    // Apply non-snapshot events (only those after the last snapshot)
    const snapshotIndex = lastSnapshot
      ? events.lastIndexOf(lastSnapshot)
      : -1;

    const deltaEvents = events.slice(snapshotIndex + 1);

    // Batch-update Zustand store
    useOrchestratorStore.setState((prev) => {
      return applyEventBatch(prev, deltaEvents);
    });

    // Route to block-specific Jotai atoms
    for (const envelope of deltaEvents) {
      routeEventToBlockAtom(envelope);
    }
  }
}

/** Apply a batch of AG-UI events to the Zustand store. */
function applyEventBatch(
  state: OrchestratorState,
  events: EventEnvelope[]
): Partial<OrchestratorState> {
  let agents = [...state.agents];
  let pendingApprovals = [...state.pendingApprovals];

  for (const envelope of events) {
    const event = envelope.event;

    switch (event.type) {
      case 'RUN_STARTED': {
        agents.push({
          id: event.agentId,
          role: event.agentRole as AgentRole,
          status: 'running',
          currentStep: 'initializing',
          progress: 0,
          tokenUsage: 0,
          cost: 0,
          startedAt: new Date(envelope.timestamp),
          completedAt: null,
          error: null,
        });
        break;
      }

      case 'STATE_DELTA': {
        // Apply JSON Patch operations
        for (const patch of event.delta) {
          agents = applyJsonPatch(agents, patch);
        }
        break;
      }

      case 'RUN_FINISHED': {
        const agentIndex = agents.findIndex(a => a.id === event.agentId);
        if (agentIndex !== -1) {
          if (event.outcome.type === 'success') {
            agents[agentIndex] = {
              ...agents[agentIndex],
              status: 'completed',
              completedAt: new Date(envelope.timestamp),
            };
          } else if (event.outcome.type === 'error') {
            agents[agentIndex] = {
              ...agents[agentIndex],
              status: 'failed',
              error: event.outcome.message,
              completedAt: new Date(envelope.timestamp),
            };
          } else if (event.outcome.type === 'interrupt') {
            agents[agentIndex] = {
              ...agents[agentIndex],
              status: 'waiting',
            };

            // Add to pending approvals
            pendingApprovals.push({
              id: event.outcome.id,
              agentId: event.agentId,
              reason: event.outcome.reason,
              payload: event.outcome.payload,
              createdAt: new Date(envelope.timestamp),
              status: 'pending',
            });
          }
        }
        break;
      }
    }
  }

  return { agents, pendingApprovals };
}
```

**Event routing to block atoms:**

```typescript
// src/stores/block-router.ts

import { getDefaultStore } from 'jotai';
import type { EventEnvelope } from '../types/ag-ui';
import { blockAtomRegistry } from './block-atoms';

const jotaiStore = getDefaultStore();

/**
 * Route an AG-UI event to the appropriate block's Jotai atoms.
 * Each block type handles events differently:
 * - agent-output: appends TEXT_MESSAGE_CONTENT to log lines
 * - dag-visualization: updates node status on STATE_DELTA
 * - approval-queue: adds pending approval on RUN_FINISHED(interrupt)
 */
export function routeEventToBlockAtom(envelope: EventEnvelope): void {
  const event = envelope.event;
  const agentId = extractAgentId(event);

  if (!agentId) return;

  // Find all blocks tracking this agent
  const blocks = blockAtomRegistry.getBlocksForAgent(agentId);

  for (const block of blocks) {
    switch (block.type) {
      case 'agent-output': {
        if (event.type === 'TEXT_MESSAGE_CONTENT') {
          const currentLogs = jotaiStore.get(block.atoms.logsAtom);
          jotaiStore.set(block.atoms.logsAtom, [
            ...currentLogs,
            event.delta,
          ]);
        }
        break;
      }

      case 'dag-visualization': {
        if (event.type === 'STATE_DELTA' || event.type === 'RUN_STARTED' || event.type === 'RUN_FINISHED') {
          // The DAG block reads from Zustand, not Jotai,
          // so it picks up changes automatically via selectors.
          // We only need to trigger animation state here.
          if (event.type === 'RUN_STARTED' || event.type === 'RUN_FINISHED') {
            const animating = jotaiStore.get(block.atoms.animatingNodesAtom);
            const newSet = new Set(animating);
            newSet.add(agentId);
            jotaiStore.set(block.atoms.animatingNodesAtom, newSet);

            // Clear animation after 600ms
            setTimeout(() => {
              const current = jotaiStore.get(block.atoms.animatingNodesAtom);
              const cleared = new Set(current);
              cleared.delete(agentId);
              jotaiStore.set(block.atoms.animatingNodesAtom, cleared);
            }, 600);
          }
        }
        break;
      }

      case 'log-viewer': {
        if (event.type === 'TEXT_MESSAGE_CONTENT') {
          const currentLines = jotaiStore.get(block.atoms.logLinesAtom);
          jotaiStore.set(block.atoms.logLinesAtom, [
            ...currentLines,
            {
              content: event.delta,
              timestamp: envelope.timestamp,
              level: detectLogLevel(event.delta),
            },
          ]);
        }
        break;
      }
    }
  }
}

function extractAgentId(event: AgUiEvent): string | null {
  if ('agentId' in event) return event.agentId;
  return null;
}

function detectLogLevel(line: string): 'info' | 'warn' | 'error' | 'debug' {
  if (line.includes('ERROR') || line.includes('error:')) return 'error';
  if (line.includes('WARN') || line.includes('warning:')) return 'warn';
  if (line.includes('DEBUG')) return 'debug';
  return 'info';
}
```

---

## 3. Error Handling Strategy

### 3.1 Process Crashes

When an agent subprocess crashes (non-zero exit code), the process manager:

1. Captures the last 100 lines of stderr into the `ProcessEvent::Error` payload.
2. Emits `RUN_FINISHED` with `outcome: "error"` including the exit code and stderr excerpt.
3. Preserves the git worktree (does not clean up) so the crash can be investigated.
4. Updates the agent's SQLite row with `exit_code` and `error` fields.
5. Notifies the orchestrator, which can trigger a reaction (retry, escalate) if configured.

```rust
/// On process crash, capture and emit detailed error context.
async fn handle_process_crash(
    pm: &ProcessManager,
    agent_id: &str,
    exit_code: i32,
) {
    let process = pm.processes.get(agent_id).unwrap();

    // Collect last 100 stderr lines for error context
    let stderr_tail: Vec<String> = process.stderr_buffer
        .tail(100)
        .iter()
        .map(|line| line.content.clone())
        .collect();

    let _ = pm.event_tx.send(ProcessEvent::Error {
        id: agent_id.to_string(),
        error: format!(
            "Agent {} crashed with exit code {}.\nLast stderr:\n{}",
            agent_id,
            exit_code,
            stderr_tail.join("\n")
        ),
    });
}
```

### 3.2 Connection Drops

| Scenario | Detection | Recovery |
|----------|-----------|----------|
| SSE connection lost | `EventSource.onerror` fires | Browser auto-reconnects; `Last-Event-ID` header sends last received sequence ID; server skips already-delivered events |
| SSE events missed (lag) | `RecvError::Lagged(n)` on broadcast channel | Server sends full `STATE_SNAPSHOT` to resynchronize |
| WebSocket disconnected | `onclose` event | Frontend shows "Terminal disconnected" overlay with "Reconnect" button; output continues buffering server-side |
| Server restart | All connections drop | SSE auto-reconnects; state snapshot on reconnect restores full state; in-progress builds persist in SQLite |

### 3.3 Timeout Handling

- **Agent spawn timeout:** If a process does not emit its first stdout line within 30 seconds, emit a warning event but do not kill the process (Claude Code can take time to initialize).
- **Agent execution timeout:** Configurable per-agent (default: 10 minutes). After timeout, send SIGTERM with the standard 5-second grace period.
- **SSE client timeout:** Keep-alive pings every 15 seconds prevent intermediate proxies from closing idle connections.
- **WebSocket idle timeout:** Close connections with no activity for 5 minutes.

---

## 4. Git Worktree Lifecycle

Each agent operates in its own git worktree, providing complete filesystem isolation. This means agents cannot accidentally modify each other's files, and each agent's changes can be reviewed and merged independently.

**Lifecycle:**

```
Build starts
    |
    v
For each agent in plan:
    1. git worktree add -b agent/<role>/<id> .worktrees/<id>
    2. Spawn agent subprocess in that worktree
    3. Agent reads/writes files in its worktree only
    |
    v
Agent completes successfully:
    1. git add + commit in worktree (agent does this as part of its workflow)
    2. Dashboard shows diff for review (Phase 5)
    3. After approval: git merge agent/<role>/<id> into target branch
    4. git worktree remove --force .worktrees/<id>
    5. git branch -d agent/<role>/<id>
    |
Agent fails:
    1. Worktree preserved for debugging
    2. Manual cleanup: git worktree remove --force .worktrees/<id>
```

**Cleanup on build completion:**

```rust
impl ProcessManager {
    /// Clean up all worktrees for a completed build.
    pub async fn cleanup_build(&mut self) -> Result<(), ProcessError> {
        let agent_ids: Vec<String> = self.processes.keys().cloned().collect();

        for id in agent_ids {
            if let Some(process) = self.processes.get(&id) {
                match &process.status {
                    ProcessStatus::Completed { .. } => {
                        self.remove_worktree(&process.worktree_path).await?;
                    }
                    ProcessStatus::Failed { .. } | ProcessStatus::Killed => {
                        // Preserve failed worktrees for investigation.
                        // Log the path so the user can inspect.
                        log::info!(
                            "Preserving worktree for failed agent {}: {}",
                            id,
                            process.worktree_path.display()
                        );
                    }
                    _ => {
                        // Agent still running -- should not happen at build cleanup
                        log::warn!("Agent {} still running during cleanup", id);
                    }
                }
            }
        }

        Ok(())
    }
}
```

---

## 5. Tauri IPC Integration

The Rust backend serves the SSE/REST/WebSocket endpoints via an embedded Axum HTTP server. The React frontend communicates via standard HTTP to `localhost:<port>`. This preserves the fallback to pure web deployment (no Tauri-specific IPC dependency for data flow).

Tauri IPC is used only for native desktop operations:

```rust
#[tauri::command]
async fn get_server_port(state: tauri::State<'_, AppState>) -> Result<u16, String> {
    Ok(state.server_port)
}

#[tauri::command]
async fn show_notification(
    app: tauri::AppHandle,
    title: String,
    body: String,
) -> Result<(), String> {
    app.notification()
        .builder()
        .title(&title)
        .body(&body)
        .show()
        .map_err(|e| e.to_string())?;
    Ok(())
}

#[tauri::command]
async fn open_worktree_in_editor(
    path: String,
) -> Result<(), String> {
    tokio::process::Command::new("code")
        .arg(&path)
        .spawn()
        .map_err(|e| e.to_string())?;
    Ok(())
}
```

**Server startup in Tauri main:**

```rust
fn main() {
    tauri::Builder::default()
        .setup(|app| {
            let db = rusqlite::Connection::open("dashboard.db")?;
            initialize_schema(&db)?;

            let app_state = AppState::new(db, PathBuf::from("."));

            // Start Axum HTTP server on a random available port
            let server_port = find_available_port();
            let router = build_router(app_state.clone());

            tokio::spawn(async move {
                let listener = tokio::net::TcpListener::bind(
                    format!("127.0.0.1:{}", server_port)
                ).await.unwrap();

                axum::serve(listener, router).await.unwrap();
            });

            // Start periodic state snapshot
            spawn_periodic_snapshot(app_state.clone());

            // Store state for Tauri commands
            app.manage(app_state);

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_server_port,
            show_notification,
            open_worktree_in_editor,
        ])
        .run(tauri::generate_context!())
        .expect("error running tauri application");
}
```

---

## 6. TypeScript Type Definitions

Complete type definitions shared between the SSE client and Zustand/Jotai stores:

```typescript
// src/types/ag-ui.ts

/** AG-UI event types as emitted by the Rust backend. */
export type AgUiEventType =
  | 'RUN_STARTED'
  | 'RUN_FINISHED'
  | 'TEXT_MESSAGE_START'
  | 'TEXT_MESSAGE_CONTENT'
  | 'TEXT_MESSAGE_END'
  | 'TOOL_CALL_START'
  | 'TOOL_CALL_ARGS'
  | 'TOOL_CALL_END'
  | 'STATE_SNAPSHOT'
  | 'STATE_DELTA'
  | 'REASONING_MESSAGE_CONTENT'
  | 'RAW';

/** Every AG-UI event is wrapped in an envelope with sequencing metadata. */
export interface EventEnvelope {
  sequenceId: number;
  timestamp: string;
  event: AgUiEvent;
}

/** Union of all AG-UI event shapes. */
export type AgUiEvent =
  | RunStartedEvent
  | RunFinishedEvent
  | TextMessageStartEvent
  | TextMessageContentEvent
  | TextMessageEndEvent
  | ToolCallStartEvent
  | ToolCallArgsEvent
  | ToolCallEndEvent
  | StateSnapshotEvent
  | StateDeltaEvent
  | ReasoningMessageContentEvent
  | RawEvent;

export interface RunStartedEvent {
  type: 'RUN_STARTED';
  runId: string;
  agentId: string;
  agentRole: string;
  threadId: string;
}

export interface RunFinishedEvent {
  type: 'RUN_FINISHED';
  runId: string;
  agentId: string;
  outcome: RunOutcome;
}

export type RunOutcome =
  | { type: 'success' }
  | { type: 'error'; message: string; code?: number }
  | { type: 'interrupt'; id: string; reason: string; payload: unknown };

export interface TextMessageStartEvent {
  type: 'TEXT_MESSAGE_START';
  messageId: string;
  agentId: string;
  role: string;
}

export interface TextMessageContentEvent {
  type: 'TEXT_MESSAGE_CONTENT';
  messageId: string;
  agentId: string;
  delta: string;
}

export interface TextMessageEndEvent {
  type: 'TEXT_MESSAGE_END';
  messageId: string;
  agentId: string;
}

export interface ToolCallStartEvent {
  type: 'TOOL_CALL_START';
  toolCallId: string;
  agentId: string;
  toolName: string;
}

export interface ToolCallArgsEvent {
  type: 'TOOL_CALL_ARGS';
  toolCallId: string;
  agentId: string;
  delta: string;
}

export interface ToolCallEndEvent {
  type: 'TOOL_CALL_END';
  toolCallId: string;
  agentId: string;
}

export interface StateSnapshotEvent {
  type: 'STATE_SNAPSHOT';
  snapshot: OrchestratorSnapshot;
}

export interface StateDeltaEvent {
  type: 'STATE_DELTA';
  agentId: string;
  delta: JsonPatch[];
}

export interface ReasoningMessageContentEvent {
  type: 'REASONING_MESSAGE_CONTENT';
  messageId: string;
  agentId: string;
  delta: string;
}

export interface RawEvent {
  type: 'RAW';
  agentId: string;
  rawType: string;
  payload: unknown;
}

export interface JsonPatch {
  op: 'replace' | 'add' | 'remove';
  path: string;
  value?: unknown;
}

/** Full orchestrator state, sent on connect and every 5 seconds. */
export interface OrchestratorSnapshot {
  buildId: string | null;
  buildPhase: number;
  buildStatus: 'idle' | 'running' | 'paused' | 'completed' | 'failed';
  agents: AgentSnapshot[];
  pendingApprovals: ApprovalSnapshot[];
  timestamp: string;
}

export interface AgentSnapshot {
  id: string;
  role: string;
  status: string;
  currentStep: string;
  progress: number;
  tokenUsage: number;
  cost: number;
  startedAt: string | null;
  completedAt: string | null;
  error: string | null;
  worktree: string;
}

export interface ApprovalSnapshot {
  id: string;
  agentId: string;
  reason: string;
  payload: unknown;
  createdAt: string;
  status: 'pending' | 'approved' | 'rejected';
}
```

---

## 7. Acceptance Criteria

| ID | Criterion | Verification |
|----|-----------|-------------|
| AC-3.1 | Rust process manager spawns a real Claude Code agent subprocess and captures its stdout/stderr | Integration test: spawn `echo "hello"` subprocess, verify output arrives in ring buffer |
| AC-3.2 | Agent stdout/stderr streams to SSE endpoint in real-time with AG-UI event format | E2E test: connect EventSource, spawn agent, verify TEXT_MESSAGE_CONTENT events arrive within 200ms |
| AC-3.3 | SSE reconnection recovers missed events via state snapshot | Test: disconnect SSE client, spawn agent, reconnect with Last-Event-ID, verify STATE_SNAPSHOT contains agent |
| AC-3.4 | SSE backpressure sends state snapshot when client lags behind broadcast buffer | Test: slow consumer that processes events at 1/10th rate, verify STATE_SNAPSHOT is sent instead of individual events |
| AC-3.5 | WebSocket terminal enables bidirectional agent communication | Test: connect WebSocket, send command via WebSocket, verify command reaches agent stdin, verify agent output returns via WebSocket |
| AC-3.6 | REST API starts a build and spawns agent subprocesses | Test: POST /api/build/start, verify response contains agent IDs and "running" status |
| AC-3.7 | REST API pauses and resumes builds | Test: start build, pause, verify SIGSTOP sent, resume, verify SIGCONT sent, verify agent continues output |
| AC-3.8 | Process manager handles agent crash gracefully | Test: spawn agent that exits with code 1, verify RUN_FINISHED(error) event emitted, verify error details in SQLite |
| AC-3.9 | Git worktree created per agent and cleaned up on completion | Test: start build, verify worktree directories exist, complete build, verify worktrees removed (except failed agents) |
| AC-3.10 | Keep-alive pings sent every 15 seconds | Test: connect SSE, wait 20 seconds with no events, verify ping comment received |
| AC-3.11 | Multi-agent events are correctly multiplexed over single SSE stream | Test: spawn 3 agents, connect single SSE client, verify events from all 3 agents arrive with correct agentId |
| AC-3.12 | Frontend 50ms batch window groups rapid events into single store update | Performance test: emit 100 events in 10ms, verify only 1-2 Zustand setState calls |

---

## 8. Testing Strategy

### Unit Tests (Rust)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ring_buffer_overwrites_oldest() {
        let mut buf: RingBuffer<String> = RingBuffer::new(3);
        buf.push("a".to_string());
        buf.push("b".to_string());
        buf.push("c".to_string());
        buf.push("d".to_string()); // overwrites "a"

        let items = buf.to_vec();
        assert_eq!(items.len(), 3);
        assert_eq!(items[0].content, "b");
        assert_eq!(items[2].content, "d");
    }

    #[test]
    fn ag_ui_event_serialization() {
        let event = AgUiEvent::RunStarted {
            run_id: "run-1".to_string(),
            agent_id: "backend-abc123".to_string(),
            agent_role: "backend".to_string(),
            thread_id: "thread-backend-abc123".to_string(),
        };

        let json = serde_json::to_string(&event).unwrap();
        assert!(json.contains("\"type\":\"RUN_STARTED\""));
        assert!(json.contains("\"agentId\":\"backend-abc123\""));
    }

    #[tokio::test]
    async fn process_event_conversion_spawned() {
        let event = ProcessEvent::Spawned {
            id: "backend-abc".to_string(),
            role: AgentRole::Backend,
            pid: 12345,
            worktree: "/tmp/worktrees/backend-abc".to_string(),
        };

        let mut seq = 0;
        let envelopes = convert_process_event(&event, &mut seq);

        assert_eq!(envelopes.len(), 1);
        assert_eq!(seq, 1);
        match &envelopes[0].event {
            AgUiEvent::RunStarted { agent_id, agent_role, .. } => {
                assert_eq!(agent_id, "backend-abc");
                assert_eq!(agent_role, "backend");
            }
            _ => panic!("Expected RunStarted event"),
        }
    }

    #[tokio::test]
    async fn process_event_conversion_exit_success() {
        let event = ProcessEvent::Exited {
            id: "frontend-xyz".to_string(),
            code: 0,
            duration_ms: 45000,
        };

        let mut seq = 10;
        let envelopes = convert_process_event(&event, &mut seq);

        assert_eq!(envelopes.len(), 1);
        match &envelopes[0].event {
            AgUiEvent::RunFinished { outcome, .. } => {
                assert!(matches!(outcome, RunOutcome::Success));
            }
            _ => panic!("Expected RunFinished event"),
        }
    }

    #[tokio::test]
    async fn process_event_conversion_exit_failure() {
        let event = ProcessEvent::Exited {
            id: "qe-abc".to_string(),
            code: 1,
            duration_ms: 5000,
        };

        let mut seq = 0;
        let envelopes = convert_process_event(&event, &mut seq);

        match &envelopes[0].event {
            AgUiEvent::RunFinished { outcome, .. } => {
                match outcome {
                    RunOutcome::Error { code, .. } => assert_eq!(*code, Some(1)),
                    _ => panic!("Expected Error outcome"),
                }
            }
            _ => panic!("Expected RunFinished event"),
        }
    }
}
```

### Integration Tests

```rust
#[tokio::test]
async fn test_spawn_and_capture_output() {
    let (tx, mut rx) = broadcast::channel(256);
    let mut pm = ProcessManager {
        processes: HashMap::new(),
        event_tx: tx,
        max_processes: 5,
        worktree_root: PathBuf::from("/tmp/test-worktrees"),
    };

    let config = AgentConfig {
        binary: "echo".to_string(),
        args: vec!["Hello from agent".to_string()],
        build_id: "test-build".to_string(),
        env: HashMap::new(),
        // ... other fields
    };

    let agent_id = pm.spawn_agent(AgentRole::Backend, &config).await.unwrap();

    // Collect events for 1 second
    let mut events = Vec::new();
    let deadline = tokio::time::Instant::now() + Duration::from_secs(1);
    while tokio::time::Instant::now() < deadline {
        if let Ok(event) = tokio::time::timeout(
            Duration::from_millis(100),
            rx.recv(),
        ).await {
            if let Ok(e) = event {
                events.push(e);
            }
        }
    }

    // Should have: Spawned, Output("Hello from agent"), Exited(0), StatusChanged
    assert!(events.iter().any(|e| matches!(e, ProcessEvent::Spawned { .. })));
    assert!(events.iter().any(|e| matches!(e, ProcessEvent::Output { data, .. } if data.contains("Hello"))));
    assert!(events.iter().any(|e| matches!(e, ProcessEvent::Exited { code: 0, .. })));
}
```

### Frontend Tests

```typescript
// src/services/__tests__/sse-client.test.ts
import { SSEClient } from '../sse-client';

describe('SSEClient', () => {
  it('batches events within 50ms window', async () => {
    const client = new SSEClient('http://localhost:3000');
    const stateUpdates: number[] = [];

    // Mock Zustand setState to count calls
    const originalSetState = useOrchestratorStore.setState;
    useOrchestratorStore.setState = (...args) => {
      stateUpdates.push(Date.now());
      return originalSetState(...args);
    };

    // Simulate 10 rapid events
    for (let i = 0; i < 10; i++) {
      client['enqueueEvent']({
        sequenceId: i,
        timestamp: new Date().toISOString(),
        event: {
          type: 'TEXT_MESSAGE_CONTENT',
          messageId: `msg-${i}`,
          agentId: 'test-agent',
          delta: `line ${i}`,
        },
      });
    }

    // Wait for batch flush
    await new Promise(resolve => setTimeout(resolve, 100));

    // Should have been batched into 1 setState call
    expect(stateUpdates.length).toBe(1);

    useOrchestratorStore.setState = originalSetState;
  });

  it('replaces state on STATE_SNAPSHOT', async () => {
    const client = new SSEClient('http://localhost:3000');

    client['enqueueEvent']({
      sequenceId: 1,
      timestamp: new Date().toISOString(),
      event: {
        type: 'STATE_SNAPSHOT',
        snapshot: {
          buildId: 'build-123',
          buildPhase: 3,
          buildStatus: 'running',
          agents: [],
          pendingApprovals: [],
          timestamp: new Date().toISOString(),
        },
      },
    });

    await new Promise(resolve => setTimeout(resolve, 100));

    const state = useOrchestratorStore.getState();
    expect(state.buildId).toBe('build-123');
    expect(state.buildPhase).toBe(3);
  });
});
```

---

## 9. Risk Considerations

| Risk | Severity | Probability | Mitigation |
|------|----------|------------|------------|
| Claude Code agents may not produce parseable stdout for AG-UI mapping | High | Medium | Start with raw TEXT_MESSAGE_CONTENT for all output. Add structured parsing (tool calls, reasoning) incrementally. Unparseable output is still visible as raw text. |
| tokio broadcast channel memory pressure with 20 agents producing rapid output | Medium | Medium | Buffer size of 4096 events. Lagged clients get state snapshot instead of replay. Monitor channel capacity in metrics. |
| Git worktree creation is slow on large repos | Medium | Low | Worktrees share the object store -- creation is O(tree size), not O(repo history). Pre-create worktrees for known agent roles during plan loading. |
| SIGSTOP/SIGCONT for pause/resume may not work with all agent implementations | Medium | Medium | Document that pause/resume is best-effort. Some agents may not handle SIGSTOP gracefully. Fallback: stdin-based pause command. |
| SSE connection limits under HTTP/1.1 (6 per domain) | Medium | Low | The architecture uses a single multiplexed SSE stream, not per-agent streams. This fits within even HTTP/1.1 limits. |
| WebSocket connections for interactive terminals compete for browser resources | Low | Low | Interactive terminal use is the exception, not the rule. Most agents run in pipe mode. Limit concurrent WebSocket terminals to 4. |

---

## 10. Dependencies on Other Phases

| Phase | What This Phase Needs | What This Phase Provides |
|-------|----------------------|-------------------------|
| Phase 1 (Foundation) | Block registry, Zustand store, Jotai atom infrastructure, Tauri shell | -- |
| Phase 2 (Visualization) | -- | SSE event stream that feeds agent-output, DAG, and log-viewer blocks |
| Phase 4 (Approval Gates) | -- | REST `/api/approval/:id/decide` endpoint, `RUN_FINISHED(interrupt)` event emission |
| Phase 6 (Observability) | -- | ProcessEvent stream that Langfuse and hcom can subscribe to |
| Phase 7 (Extensibility) | -- | Plugin interface for `AgentPlugin` and `RuntimePlugin` to swap process management |

---

## 11. File Inventory

Files created or modified in this phase:

```
src-tauri/
  src/
    process_manager.rs       # ManagedProcess, ProcessManager, spawn/kill/monitor
    ag_ui_adapter.rs         # AG-UI event types, conversion functions
    sse_endpoint.rs          # Axum SSE handler with backpressure
    ws_terminal.rs           # WebSocket terminal handler
    rest_api.rs              # REST route handlers and request/response types
    event_bus.rs             # Broadcast channel setup, periodic snapshot
    worktree.rs              # Git worktree create/remove/cleanup
    main.rs                  # (modified) Wire up Axum server in Tauri setup

src/
  services/
    sse-client.ts            # SSE connection, batch processing, reconnection
  stores/
    block-router.ts          # Event routing to block-specific Jotai atoms
    orchestrator.ts          # (modified) Add setConnectionStatus, applyStateSnapshot
  types/
    ag-ui.ts                 # Full AG-UI TypeScript type definitions
  hooks/
    use-sse.ts               # React hook wrapping SSEClient lifecycle
    use-terminal-ws.ts       # React hook for WebSocket terminal connections
```
