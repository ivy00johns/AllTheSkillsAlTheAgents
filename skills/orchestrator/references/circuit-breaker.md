# Circuit Breaker — Failure Detection & Recovery

## When to Trigger

The circuit breaker activates when:
- An agent fails validation **3 times** on the same issue
- An agent is stuck in a loop (making changes that don't fix the problem)
- An agent reports it can't proceed without information from another agent
- A contract change cascades across 3+ agents

## Escalation Ladder

### Level 1: Retry (1-2 failures)

Normal build flow. Agent has failed validation on an issue. Actions:
1. Send the agent the specific error message
2. Include the expected behavior (from the contract)
3. Include the file(s) likely involved
4. Let the agent attempt a fix

### Level 2: Diagnose (3 failures)

The agent can't fix the issue on its own. Actions:
1. **Stop** the failing agent
2. **Read** their code yourself to diagnose the root cause
3. Determine: is this a **contract bug** or an **implementation bug**?
4. For **implementation bugs**: Re-spawn the agent with:
   - The specific error
   - Your root cause analysis
   - A concrete fix direction (not just "fix the error")
5. For **contract bugs**: Follow the Contract Change Protocol

### Level 3: Reassign (5+ failures)

The task decomposition may be wrong. Actions:
1. **Stop** the failing agent
2. **Evaluate**: Is the agent's scope too broad? Too narrow?
3. Consider:
   - Splitting the task into smaller pieces
   - Merging the agent's scope with another agent
   - Reassigning specific files to a different agent
4. **Re-spawn** with adjusted scope and explicit guidance

### Level 4: Cascade Recovery

A contract change affects multiple agents. Actions:
1. **Stop all affected agents** immediately
2. Assess the full scope of the change
3. Rewrite all affected contracts with new version numbers
4. Consider rebuilding in dependency order:
   - Data layer → Backend → Frontend (sequential, not parallel)
5. Re-run full end-to-end validation after all agents complete

## Common Failure Patterns

### Pattern: URL Mismatch
**Symptom**: Integration test fails with 404
**Root Cause**: Backend uses `/api/sessions/` (trailing slash), frontend calls `/api/sessions`
**Fix**: Check contract for trailing slash convention. Update the non-conforming side.

### Pattern: Response Shape Disagreement
**Symptom**: Frontend crashes parsing response
**Root Cause**: Backend returns `{session: {...}}`, frontend expects `{...}` (no wrapper)
**Fix**: Check contract. Update the non-conforming side.

### Pattern: CORS Failure
**Symptom**: Frontend shows CORS error in browser console
**Root Cause**: Backend doesn't set `Access-Control-Allow-Origin` for frontend origin
**Fix**: Backend adds CORS middleware with the correct frontend origin.

### Pattern: Type Mismatch
**Symptom**: Date/time parsing fails, IDs don't match
**Root Cause**: Backend sends snake_case (`created_at`), frontend expects camelCase (`createdAt`)
**Fix**: Check shared types contract. Add serialization transform or align naming.

### Pattern: In-Memory Storage
**Symptom**: Data disappears on restart
**Root Cause**: Agent used a variable/array instead of the database
**Fix**: Re-spawn with explicit instruction to use the contracted data layer.

### Pattern: SSE Chunk Storage
**Symptom**: Chat history shows N separate bubbles instead of one message
**Root Cause**: Backend stored each SSE chunk as a separate DB row
**Fix**: Check data layer contract for accumulation strategy. Backend should accumulate chunks.

## Recovery Checklist

After any circuit breaker action:
- [ ] Root cause identified and documented
- [ ] Affected contracts updated (if contract bug)
- [ ] All affected agents notified of changes
- [ ] Failed agent re-spawned with specific guidance
- [ ] Validation re-run and passing
- [ ] Contract changelog updated
