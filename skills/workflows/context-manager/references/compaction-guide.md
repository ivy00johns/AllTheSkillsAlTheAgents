# Context Compaction Guide

## Context Budget Management

### Monitoring Usage

Context usage is approximate. Watch for these signals:
- Responses becoming shorter or less detailed
- Agent starting to "forget" earlier instructions
- System messages about context limits
- Conversation has exceeded ~100 tool calls

### Compaction Strategies

**Strategy 1: Summarize and Discard**
When you've read many files, summarize what you learned and note which files contain what. Don't re-read files unless you need specific line-level details.

**Strategy 2: Task Chunking**
Break large tasks into subtasks. Complete each subtask fully (including validation) before moving to the next. This way, completed subtasks can be safely forgotten.

**Strategy 3: External State**
Write important decisions and state to files rather than keeping them only in context:
- Write a `STATUS.md` tracking what's done and what's next
- Write decision logs to `.claude/handoffs/`
- Write partial results to files as you go

**Strategy 4: Handoff at 80%**
Don't push to 100%. At ~80% usage, write a handoff file and let the orchestrator spawn a continuation agent. A fresh agent with a good handoff is more effective than a context-starved agent.

## Handoff File Best Practices

### What to Include

1. **Task state** — be honest about completion percentage
2. **Decisions made** — especially non-obvious ones (why did you choose X over Y?)
3. **Files touched** — so the continuation agent knows what to check
4. **Blockers** — anything preventing progress
5. **Suggested first action** — the single most important next step

### What NOT to Include

- Full file contents (the continuation agent can read them)
- Complete conversation history
- Verbose error logs (summarize the key error)
- Duplicate information already in contracts or the plan

### continuation_context Tips

This free-text field is the most important part of the handoff. Write it as if briefing a colleague:

**Good:**
```
Backend API is 90% done. All CRUD endpoints for sessions work.
The streaming endpoint (POST /api/v1/sessions/{id}/stream) is
partially implemented — the SSE connection establishes and sends
chunks, but the "done" event doesn't include fullContent yet.
The bug is in backend/src/routes/stream.py line 47 — the
accumulated content variable resets on each chunk instead of
appending. Fix that, then run the validation checklist.
```

**Bad:**
```
I was working on the backend and made good progress on most
things. There might be a bug in the streaming code. The frontend
agent might need to check their side too.
```

## Recovery from Failed Handoff

If a continuation agent can't make sense of the handoff:
1. Read all files in `files_modified` and `files_created`
2. Read the relevant contracts
3. Run the validation checklist to understand current state
4. Report to the orchestrator what's unclear
5. The orchestrator may need to provide additional context

## Context-Efficient Patterns

### Do
- Read files once, note key information
- Write incremental results to disk
- Use grep/glob instead of reading entire directories
- Focus on the current subtask

### Don't
- Re-read the same file multiple times
- Keep large file contents in conversational context
- Ask for the full plan when you only need one section
- Accumulate tool output without summarizing
