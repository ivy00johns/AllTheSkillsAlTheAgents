# Handoff Protocol

When an agent approaches context limits (~80% usage), it writes a structured handoff file and signals the orchestrator.

## Roles

- **Agent** — detects context usage approaching ~80%, drafts the handoff file content
- **Context-manager** — owns `.claude/handoffs/`, validates handoff quality, assists with compaction strategy
- **Orchestrator** — reads completed handoff files, spawns continuation agents with the handoff as context

Signaling varies by runtime: in Agent Teams, signal via inbox/TeammateTool. In subagent mode, the agent exits and the orchestrator reads the handoff file from `.claude/handoffs/`. In sequential mode, the user relays.

## Handoff File Format

Location: `.claude/handoffs/{agent-role}-{timestamp}.yaml`

```yaml
handoff_version: "1.0.0"
agent_role: string                  # e.g., "backend", "frontend", "qe"
timestamp: ISO8601                  # When the handoff was written
session_id: string                  # Current session identifier
context_usage_pct: number           # Approximate percentage (e.g., 82)

task_state:
  assigned_task: string             # Original task description
  completion_pct: number            # Honest estimate (0-100)
  completed_subtasks:
    - string                        # Each completed subtask
  remaining_subtasks:
    - string                        # Each remaining subtask
  blockers:
    - string                        # Anything preventing progress

decisions_made:
  - decision: string                # What was decided
    rationale: string               # Why this choice
    affects_files:
      - string                      # Which files are affected

files_modified:
  - string                          # Relative paths of files modified
files_created:
  - string                          # Relative paths of files created
contracts_consumed:
  - string                          # Which contract files were read

continuation_context: |
  Free-text: what the continuation agent needs to know immediately.
  Key variable names, error states, partial work, next action.
  Maximum 500 words. Be specific and actionable.

suggested_first_action: string      # Exact next step for continuation agent
```

## Orchestrator Behavior on Handoff

1. **Read** the handoff file immediately
2. **Validate** the handoff is well-formed:
   - `completion_pct` is realistic given `completed_subtasks`
   - `remaining_subtasks` is non-empty (otherwise, why hand off?)
   - `suggested_first_action` is specific and actionable
3. **Spawn** continuation agent with:
   - The handoff file as first message context
   - The original agent role skill
   - The relevant contracts
   - Access to all files listed in `files_modified` and `files_created`
4. **Tag** the task as `in_progress_handoff` in the shared task list
5. **Monitor** the continuation agent's first few actions to ensure it picks up correctly

## Continuation Agent Startup Sequence

The continuation agent should:

1. Read the handoff file
2. Read the agent's role skill (provided in spawn context by the orchestrator)
3. Read all files in `files_modified` and `files_created`
4. Read the relevant contracts in `contracts_consumed`
5. Execute `suggested_first_action`
6. Continue with `remaining_subtasks`

## Handoff Quality Checklist

A good handoff includes:

- [ ] Honest completion percentage (not inflated)
- [ ] All modified files listed (so continuation agent knows current state)
- [ ] Key decisions documented with rationale
- [ ] Specific next step (not "continue working on the backend")
- [ ] Blockers listed (if any)
- [ ] continuation_context is ≤500 words and actionable

## Anti-Patterns

| Anti-Pattern | Why It Fails | Better Approach |
|-------------|-------------|-----------------|
| Vague continuation_context | Continuation agent wastes context re-discovering state | Be specific: file paths, line numbers, error messages |
| Inflated completion_pct | Continuation agent skips necessary work | Be honest — 60% done is fine |
| Missing files_modified | Continuation agent doesn't know what changed | Always list every file you touched |
| "Continue from where I left off" as suggested_first_action | Too vague to act on | "Fix the streaming endpoint in backend/src/routes/stream.py — the accumulated variable resets on each chunk" |
| Writing handoff at 95% context | Handoff quality degrades under pressure | Target 80% — leave headroom |

## Multiple Handoffs

For long-running tasks, an agent may need multiple handoffs (Agent A → Agent B → Agent C). Each handoff file is independent and self-contained. The continuation agent should:

1. Read the **latest** handoff file
2. Check for **previous** handoff files to understand the full history
3. Not assume the previous agent's context is available
