# Phase 4 — Approval + Quality Gates

**Version:** 0.1.0-draft
**Date:** 2026-03-20
**Status:** Design
**Depends on:** Phase 3 (Agent Communication Layer)
**Enables:** Phase 7 (Extensibility — Reactions system)
**Duration:** 2 weeks

---

## 1. Objective

Build the human-in-the-loop quality assurance system that blocks agent execution at defined checkpoints, evaluates output quality using a 4-layer scoring model, and presents approval decisions through a purpose-built dashboard block. This phase implements the critical safety boundary between autonomous agent execution and production code delivery.

The system makes three types of decisions automatically (approve if all scores >= 3, reject if any score < 2) and escalates borderline cases (scores 2-3) to human reviewers. Every decision is logged to an append-only audit trail.

---

## 2. Scope

### 2.1 AG-UI Interrupt Lifecycle

The AG-UI protocol defines an interrupt as a `RUN_FINISHED` event with `outcome: "interrupt"`. When a QA gate fires, the orchestrator pauses the agent and emits this event. The frontend receives it, renders the approval UI, captures the human decision, and sends a resume command back to the backend.

**Interrupt event structure:**

```typescript
// Emitted by the Rust backend when a QA gate fires
interface QualityGateInterrupt {
  type: 'RUN_FINISHED';
  runId: string;
  agentId: string;
  outcome: {
    type: 'interrupt';
    id: string;          // Unique interrupt ID (UUID)
    reason: 'quality_gate';
    payload: {
      qaReport: QaReport;       // Full parsed qa-report.json
      agentId: string;
      agentRole: string;
      phaseId: number;
      gateType: GateType;
      aegisScores: AegisScores; // 4-layer evaluation results
      autoDecision: AutoDecision | null; // null = needs human review
    };
  };
}

type GateType =
  | 'phase_completion'    // Agent finished a build phase
  | 'contract_validation' // Contract conformance check
  | 'security_scan'       // Security score check
  | 'pre_merge';          // Before merging agent branch

interface AutoDecision {
  decision: 'approved' | 'rejected';
  reason: string;
  scores: AegisScores;
}
```

**Resume mechanism:**

When the user (or auto-decision logic) makes a decision, the frontend sends a REST request that the backend translates into an agent resume action:

```typescript
// Frontend sends this to POST /api/approval/:id/decide
interface ApprovalDecisionRequest {
  decision: 'approved' | 'rejected' | 'request_changes';
  notes?: string;
  // For request_changes, the feedback is injected into the agent's context
  changeFeedback?: string;
}

// Backend response confirms the decision was recorded and agent resumed
interface ApprovalDecisionResponse {
  success: boolean;
  approvalId: string;
  decision: string;
  agentResumed: boolean; // true if agent was successfully unblocked
  error?: string;
}
```

**Backend interrupt handler (Rust):**

```rust
use serde::{Deserialize, Serialize};

/// Represents a pending approval gate in the system.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PendingApproval {
    pub id: String,
    pub build_id: String,
    pub agent_id: String,
    pub agent_role: String,
    pub phase_id: u32,
    pub gate_type: GateType,
    pub qa_report: serde_json::Value,
    pub aegis_scores: AegisScores,
    pub auto_decision: Option<AutoDecisionResult>,
    pub status: ApprovalStatus,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub decided_at: Option<chrono::DateTime<chrono::Utc>>,
    pub decided_by: Option<String>,
    pub decision: Option<String>,
    pub notes: Option<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum ApprovalStatus {
    Pending,
    AutoApproved,
    AutoRejected,
    HumanApproved,
    HumanRejected,
    ChangesRequested,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum GateType {
    PhaseCompletion,
    ContractValidation,
    SecurityScan,
    PreMerge,
}

/// Process a QA report and determine whether to auto-decide or escalate.
pub async fn process_qa_gate(
    orchestrator: &Orchestrator,
    agent_id: &str,
    qa_report: serde_json::Value,
    event_tx: &broadcast::Sender<EventEnvelope>,
    db: &rusqlite::Connection,
    seq: &AtomicU64,
) -> Result<(), GateError> {
    // 1. Parse the QA report
    let report: QaReport = serde_json::from_value(qa_report.clone())
        .map_err(|e| GateError::InvalidReport(e.to_string()))?;

    // 2. Run Aegis 4-layer evaluation
    let aegis_scores = evaluate_aegis_layers(&report);

    // 3. Determine auto-decision
    let auto_decision = compute_auto_decision(&aegis_scores);

    // 4. Create the pending approval record
    let approval_id = Uuid::new_v4().to_string();
    let pending = PendingApproval {
        id: approval_id.clone(),
        build_id: orchestrator.current_build_id().unwrap_or_default(),
        agent_id: agent_id.to_string(),
        agent_role: orchestrator.get_agent_role(agent_id).unwrap_or_default(),
        phase_id: orchestrator.current_phase(),
        gate_type: GateType::PhaseCompletion,
        qa_report: qa_report.clone(),
        aegis_scores: aegis_scores.clone(),
        auto_decision: auto_decision.clone(),
        status: ApprovalStatus::Pending,
        created_at: Utc::now(),
        decided_at: None,
        decided_by: None,
        decision: None,
        notes: None,
    };

    // 5. Persist to SQLite
    insert_approval(db, &pending)?;

    // 6. Handle auto-decision or emit interrupt
    match auto_decision {
        Some(AutoDecisionResult::Approve { reason }) => {
            // Auto-approve: update record and resume agent immediately
            update_approval_decision(
                db,
                &approval_id,
                "approved",
                Some("system"),
                Some(&reason),
            )?;

            // Emit approval event for audit trail
            emit_approval_event(event_tx, seq, &approval_id, agent_id, "auto_approved");

            // Resume agent
            orchestrator.resume_agent(agent_id).await?;

            log::info!(
                "Auto-approved gate for agent {} (all scores >= 3)",
                agent_id
            );
        }
        Some(AutoDecisionResult::Reject { reason }) => {
            // Auto-reject: update record, emit event, do NOT resume
            update_approval_decision(
                db,
                &approval_id,
                "rejected",
                Some("system"),
                Some(&reason),
            )?;

            emit_approval_event(event_tx, seq, &approval_id, agent_id, "auto_rejected");

            // Emit RUN_FINISHED with error outcome
            let envelope = EventEnvelope {
                sequence_id: seq.fetch_add(1, Ordering::SeqCst),
                timestamp: Utc::now().to_rfc3339(),
                event: AgUiEvent::RunFinished {
                    run_id: agent_id.to_string(),
                    agent_id: agent_id.to_string(),
                    outcome: RunOutcome::Error {
                        message: format!("QA gate auto-rejected: {}", reason),
                        code: None,
                    },
                },
            };
            let _ = event_tx.send(envelope);

            log::warn!(
                "Auto-rejected gate for agent {} (score < 2: {})",
                agent_id, reason
            );
        }
        None => {
            // Human review required: emit AG-UI interrupt
            let interrupt_payload = serde_json::json!({
                "qaReport": qa_report,
                "agentId": agent_id,
                "agentRole": orchestrator.get_agent_role(agent_id),
                "phaseId": orchestrator.current_phase(),
                "aegisScores": aegis_scores,
            });

            let envelope = EventEnvelope {
                sequence_id: seq.fetch_add(1, Ordering::SeqCst),
                timestamp: Utc::now().to_rfc3339(),
                event: AgUiEvent::RunFinished {
                    run_id: agent_id.to_string(),
                    agent_id: agent_id.to_string(),
                    outcome: RunOutcome::Interrupt {
                        id: approval_id.clone(),
                        reason: "quality_gate".to_string(),
                        payload: interrupt_payload,
                    },
                },
            };
            let _ = event_tx.send(envelope);

            // Send desktop notification
            send_gate_notification(agent_id, &aegis_scores);

            log::info!(
                "QA gate requires human review for agent {} (scores in 2-3 range)",
                agent_id
            );
        }
    }

    Ok(())
}
```

**Frontend interrupt handling:**

```typescript
// src/hooks/use-approval-interrupt.ts

import { useEffect } from 'react';
import { useOrchestratorStore } from '../stores/orchestrator';
import { useApprovalStore } from '../stores/approval';
import type { EventEnvelope, RunOutcome } from '../types/ag-ui';

/**
 * Hook that listens for AG-UI interrupt events and populates
 * the approval queue. This is used at the app level, not per-block.
 *
 * Known CopilotKit issues we work around:
 * - #1809: resume sometimes fails silently -> we verify via REST polling
 * - #2315: null-state execution after interrupt -> we guard with status checks
 * - #2939: can't resume after page reload -> we persist pending approvals in SQLite
 *   and restore them on reconnect via STATE_SNAPSHOT
 */
export function useApprovalInterrupt() {
  const addPendingApproval = useApprovalStore((s) => s.addPendingApproval);
  const updateAgentStatus = useOrchestratorStore((s) => s.updateAgentStatus);

  useEffect(() => {
    // Subscribe to the SSE client's interrupt events.
    // The SSE client already routes RUN_FINISHED events to Zustand,
    // but we need additional handling for the approval queue.
    const unsubscribe = useOrchestratorStore.subscribe(
      (state) => state.pendingApprovals,
      (approvals, previousApprovals) => {
        // Find newly added approvals
        const newApprovals = approvals.filter(
          (a) => !previousApprovals.some((p) => p.id === a.id)
        );

        for (const approval of newApprovals) {
          // Add to the approval store (Jotai-powered block state)
          addPendingApproval(approval);

          // Play notification sound
          playNotificationSound();

          // Show desktop notification via Tauri
          showDesktopNotification(approval);
        }
      }
    );

    return unsubscribe;
  }, [addPendingApproval, updateAgentStatus]);
}

async function showDesktopNotification(approval: PendingApproval) {
  if (window.__TAURI__) {
    const { invoke } = window.__TAURI__.core;
    await invoke('show_notification', {
      title: 'QA Gate: Review Required',
      body: `Agent ${approval.agentId} (${approval.reason}) needs your approval`,
    });
  }
}

function playNotificationSound() {
  const audio = new Audio('/sounds/notification.mp3');
  audio.volume = 0.3;
  audio.play().catch(() => {
    // Autoplay blocked -- ignore
  });
}
```

**Resume flow after human decision:**

```typescript
// src/services/approval-api.ts

import type { ApprovalDecisionRequest, ApprovalDecisionResponse } from '../types/approval';

const API_BASE = import.meta.env.VITE_API_BASE || 'http://localhost:3001';

export async function submitApprovalDecision(
  approvalId: string,
  request: ApprovalDecisionRequest,
): Promise<ApprovalDecisionResponse> {
  const response = await fetch(`${API_BASE}/api/approval/${approvalId}/decide`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(request),
  });

  if (!response.ok) {
    throw new Error(`Approval decision failed: ${response.statusText}`);
  }

  const result: ApprovalDecisionResponse = await response.json();

  // Workaround for CopilotKit #1809: verify the agent actually resumed
  // by polling the agent status after a short delay.
  if (result.agentResumed) {
    setTimeout(async () => {
      const stateResponse = await fetch(`${API_BASE}/api/state`);
      const state = await stateResponse.json();
      const agent = state.data.agents.find(
        (a: any) => a.id === result.approvalId
      );
      if (agent && agent.status === 'waiting') {
        console.warn('Agent did not resume after approval -- retrying');
        // Retry the resume
        await fetch(`${API_BASE}/api/approval/${approvalId}/decide`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(request),
        });
      }
    }, 2000);
  }

  return result;
}
```

### 2.2 Aegis-Style 4-Layer Quality Evaluation

The evaluation system scores agent output across four orthogonal quality dimensions, each producing a score from 1 (unacceptable) to 5 (excellent) with explanatory notes.

**Layer definitions:**

| Layer | What It Checks | Data Source | Score Criteria |
|-------|---------------|-------------|----------------|
| **Output** | Does the result exist? Valid schema? No secrets exposed? | File system check + schema validator + secret scanner | 5: all files present, valid, clean. 3: files present but minor schema issues. 1: missing output or exposed secrets. |
| **Trace** | Does it cover requirements? Logical reasoning? Appropriate tool use? | QA report `scores.completeness` + `scores.correctness` + tool call log | 5: all requirements met, clear reasoning. 3: most requirements met. 1: major gaps or illogical steps. |
| **Component** | Do function signatures match contracts? Correct parameters? No cross-contamination? | Contract auditor output + file ownership validation | 5: perfect contract match. 3: minor parameter differences. 1: signature mismatch or ownership violation. |
| **Drift** | Consistent with baseline? Expected tools? Token usage within bounds? | Previous run metrics + token usage comparison | 5: within 1.1x baseline. 3: within 1.5x baseline. 1: >2x baseline or unexpected tool use. |

**Rust implementation:**

```rust
/// Results of the 4-layer Aegis evaluation.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AegisScores {
    pub output: LayerScore,
    pub trace: LayerScore,
    pub component: LayerScore,
    pub drift: LayerScore,
    pub overall: f64,          // Weighted average
    pub auto_decidable: bool,  // Whether auto-decision rules apply
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LayerScore {
    pub score: u8,   // 1-5
    pub notes: String,
    pub checks: Vec<CheckResult>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CheckResult {
    pub name: String,
    pub passed: bool,
    pub detail: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum AutoDecisionResult {
    Approve { reason: String },
    Reject { reason: String },
}

/// Run the 4-layer quality evaluation on a QA report.
pub fn evaluate_aegis_layers(report: &QaReport) -> AegisScores {
    let output = evaluate_output_layer(report);
    let trace = evaluate_trace_layer(report);
    let component = evaluate_component_layer(report);
    let drift = evaluate_drift_layer(report);

    // Weighted average: output 25%, trace 30%, component 30%, drift 15%
    let overall = (output.score as f64 * 0.25)
        + (trace.score as f64 * 0.30)
        + (component.score as f64 * 0.30)
        + (drift.score as f64 * 0.15);

    let min_score = *[output.score, trace.score, component.score, drift.score]
        .iter()
        .min()
        .unwrap();
    let max_score = *[output.score, trace.score, component.score, drift.score]
        .iter()
        .max()
        .unwrap();

    // Auto-decidable if all scores clearly above or below thresholds
    let auto_decidable = min_score >= 3 || min_score < 2;

    AegisScores {
        output,
        trace,
        component,
        drift,
        overall,
        auto_decidable,
    }
}

/// Output Layer: result existence, schema validation, secret scanning.
fn evaluate_output_layer(report: &QaReport) -> LayerScore {
    let mut checks = Vec::new();
    let mut score: u8 = 5;

    // Check 1: Report exists and is valid (if we got here, it is)
    checks.push(CheckResult {
        name: "report_exists".to_string(),
        passed: true,
        detail: "QA report was produced and parsed successfully".to_string(),
    });

    // Check 2: Schema version matches expected
    let schema_valid = report.schema_version == "1.0.0";
    checks.push(CheckResult {
        name: "schema_valid".to_string(),
        passed: schema_valid,
        detail: format!("Schema version: {}", report.schema_version),
    });
    if !schema_valid {
        score = score.saturating_sub(2);
    }

    // Check 3: No CRITICAL blockers of type "security"
    let security_blockers: Vec<_> = report.blockers.iter()
        .filter(|b| b.category == "security" && b.severity == "CRITICAL")
        .collect();
    let no_security_blockers = security_blockers.is_empty();
    checks.push(CheckResult {
        name: "no_security_blockers".to_string(),
        passed: no_security_blockers,
        detail: if no_security_blockers {
            "No critical security blockers".to_string()
        } else {
            format!("{} critical security blocker(s) found", security_blockers.len())
        },
    });
    if !no_security_blockers {
        score = 1; // Immediate failure for security issues
    }

    // Check 4: Test results show some passing tests
    let total_pass = report.test_results.unit.pass
        + report.test_results.integration.pass
        + report.test_results.e2e.pass;
    let total_fail = report.test_results.unit.fail
        + report.test_results.integration.fail
        + report.test_results.e2e.fail;
    let tests_healthy = total_fail == 0 || (total_pass > 0 && total_fail <= total_pass / 10);
    checks.push(CheckResult {
        name: "tests_healthy".to_string(),
        passed: tests_healthy,
        detail: format!("{} pass, {} fail across all suites", total_pass, total_fail),
    });
    if !tests_healthy {
        score = score.min(2);
    }

    let notes = checks.iter()
        .filter(|c| !c.passed)
        .map(|c| format!("FAIL: {} - {}", c.name, c.detail))
        .collect::<Vec<_>>()
        .join("; ");

    LayerScore {
        score,
        notes: if notes.is_empty() { "All output checks passed".to_string() } else { notes },
        checks,
    }
}

/// Trace Layer: requirement coverage, logical reasoning, tool use.
fn evaluate_trace_layer(report: &QaReport) -> LayerScore {
    let mut checks = Vec::new();

    // Map from qa-report.json scores to trace evaluation
    let completeness = report.scores.completeness.score;
    let correctness = report.scores.correctness.score;

    checks.push(CheckResult {
        name: "completeness".to_string(),
        passed: completeness >= 3,
        detail: format!(
            "Score {}/5: {}",
            completeness, report.scores.completeness.notes
        ),
    });

    checks.push(CheckResult {
        name: "correctness".to_string(),
        passed: correctness >= 3,
        detail: format!(
            "Score {}/5: {}",
            correctness, report.scores.correctness.notes
        ),
    });

    // Average of completeness and correctness
    let score = ((completeness + correctness) as f64 / 2.0).round() as u8;

    let notes = format!(
        "Completeness: {}/5, Correctness: {}/5",
        completeness, correctness
    );

    LayerScore { score, notes, checks }
}

/// Component Layer: contract conformance, function signatures.
fn evaluate_component_layer(report: &QaReport) -> LayerScore {
    let mut checks = Vec::new();

    let conformance = report.scores.contract_conformance.score;

    checks.push(CheckResult {
        name: "contract_conformance".to_string(),
        passed: conformance >= 3,
        detail: format!(
            "Score {}/5: {}",
            conformance, report.scores.contract_conformance.notes
        ),
    });

    // Check for contract violation blockers
    let contract_violations: Vec<_> = report.blockers.iter()
        .filter(|b| b.category == "contract_violation")
        .collect();
    let no_violations = contract_violations.is_empty();
    checks.push(CheckResult {
        name: "no_contract_violations".to_string(),
        passed: no_violations,
        detail: if no_violations {
            "No contract violation blockers".to_string()
        } else {
            format!(
                "{} contract violation(s): {}",
                contract_violations.len(),
                contract_violations.iter()
                    .map(|v| v.description.as_str())
                    .collect::<Vec<_>>()
                    .join(", ")
            )
        },
    });

    let score = if !no_violations {
        conformance.min(2) // Cap at 2 if there are violations
    } else {
        conformance
    };

    LayerScore {
        score,
        notes: format!("Contract conformance: {}/5", conformance),
        checks,
    }
}

/// Drift Layer: baseline comparison, token usage, unexpected behavior.
fn evaluate_drift_layer(report: &QaReport) -> LayerScore {
    let mut checks = Vec::new();

    // Security score as a proxy for "expected behavior"
    let security = report.scores.security.score;
    let code_quality = report.scores.code_quality.score;

    checks.push(CheckResult {
        name: "security".to_string(),
        passed: security >= 3,
        detail: format!(
            "Score {}/5: {}",
            security, report.scores.security.notes
        ),
    });

    checks.push(CheckResult {
        name: "code_quality".to_string(),
        passed: code_quality >= 3,
        detail: format!(
            "Score {}/5: {}",
            code_quality, report.scores.code_quality.notes
        ),
    });

    // Token usage check would compare against baseline from previous builds.
    // For now, we check that the report status is not BLOCKED.
    let not_blocked = report.status != "BLOCKED";
    checks.push(CheckResult {
        name: "not_blocked".to_string(),
        passed: not_blocked,
        detail: format!("Report status: {}", report.status),
    });

    let score = if !not_blocked {
        1
    } else {
        ((security + code_quality) as f64 / 2.0).round() as u8
    };

    LayerScore {
        score,
        notes: format!("Security: {}/5, Code quality: {}/5", security, code_quality),
        checks,
    }
}

/// Apply auto-decision rules:
/// - All layers >= 3 -> approve
/// - Any layer < 2 -> reject
/// - Otherwise -> None (human review)
fn compute_auto_decision(scores: &AegisScores) -> Option<AutoDecisionResult> {
    let all_scores = [
        scores.output.score,
        scores.trace.score,
        scores.component.score,
        scores.drift.score,
    ];

    let min_score = *all_scores.iter().min().unwrap();
    let max_score = *all_scores.iter().max().unwrap();

    if min_score >= 3 {
        Some(AutoDecisionResult::Approve {
            reason: format!(
                "All Aegis layers scored >= 3. Min: {}, Max: {}, Overall: {:.1}",
                min_score, max_score, scores.overall
            ),
        })
    } else if min_score < 2 {
        let failing_layers: Vec<String> = vec![
            ("output", scores.output.score),
            ("trace", scores.trace.score),
            ("component", scores.component.score),
            ("drift", scores.drift.score),
        ]
        .into_iter()
        .filter(|(_, s)| *s < 2)
        .map(|(name, score)| format!("{}: {}/5", name, score))
        .collect();

        Some(AutoDecisionResult::Reject {
            reason: format!(
                "Score below threshold (<2) in: {}. Overall: {:.1}",
                failing_layers.join(", "),
                scores.overall,
            ),
        })
    } else {
        None // Human review required
    }
}
```

**QA report parsing (matching `qa-report-schema.json`):**

```rust
/// Parsed structure matching skills/roles/qe-agent/references/qa-report-schema.json
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct QaReport {
    pub schema_version: String,
    pub timestamp: String,
    pub agent_role: String,
    pub build_session_id: String,
    pub status: String,  // "PASS" | "FAIL" | "PARTIAL" | "BLOCKED"
    pub scores: QaScores,
    pub test_results: TestResults,
    pub blockers: Vec<Blocker>,
    pub issues: Vec<Issue>,
    pub recommendations: Vec<String>,
    pub gate_decision: GateDecision,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct QaScores {
    pub correctness: ScoreEntry,
    pub completeness: ScoreEntry,
    pub code_quality: ScoreEntry,
    pub security: ScoreEntry,
    pub contract_conformance: ScoreEntry,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ScoreEntry {
    pub score: u8,
    pub notes: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TestResults {
    pub unit: TestCounts,
    pub integration: TestCounts,
    pub e2e: TestCounts,
    pub contract: TestCounts,
    pub security_scan: TestCounts,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TestCounts {
    pub pass: u32,
    pub fail: u32,
    pub skip: u32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Blocker {
    pub id: String,
    pub severity: String,   // "CRITICAL" | "HIGH"
    pub category: String,   // "contract_violation" | "security" | "build_failure" | "test_failure" | "other"
    pub file: Option<String>,
    pub line: Option<u32>,
    pub description: String,
    pub suggested_fix: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Issue {
    pub id: String,
    pub severity: String,   // "MEDIUM" | "LOW" | "INFO"
    pub category: String,
    pub file: Option<String>,
    pub line: Option<u32>,
    pub description: String,
    pub suggested_fix: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct GateDecision {
    pub proceed: bool,
    pub reason: String,
}
```

### 2.3 Approval Queue Block

The approval queue is a dashboard block type (registered in the block registry from Phase 1) that displays pending, auto-decided, and historically decided approvals.

**Jotai atoms for block state:**

```typescript
// src/stores/approval.ts

import { atom } from 'jotai';
import { atomWithStorage } from 'jotai/utils';
import type { PendingApproval, ApprovalHistoryEntry, AegisScores } from '../types/approval';

// --- Core atoms ---

/** All pending approvals awaiting human decision. */
export const pendingApprovalsAtom = atom<PendingApproval[]>([]);

/** Currently selected approval for detailed view. */
export const selectedApprovalAtom = atom<string | null>(null);

/** Approval history (decided items). */
export const approvalHistoryAtom = atom<ApprovalHistoryEntry[]>([]);

/** Sort order for the approval list. */
export const approvalSortAtom = atomWithStorage<'newest' | 'oldest' | 'urgency'>(
  'approval-sort',
  'urgency'
);

/** Filter: show only specific gate types. */
export const approvalFilterAtom = atom<GateType | 'all'>('all');

/** Set of approval IDs selected for batch operations. */
export const batchSelectedAtom = atom<Set<string>>(new Set());

/** Whether batch mode is active. */
export const batchModeAtom = atom(false);

// --- Derived atoms ---

/** Pending approvals sorted by current sort order. */
export const sortedApprovalsAtom = atom((get) => {
  const approvals = get(pendingApprovalsAtom);
  const sort = get(approvalSortAtom);
  const filter = get(approvalFilterAtom);

  let filtered = filter === 'all'
    ? approvals
    : approvals.filter((a) => a.gateType === filter);

  switch (sort) {
    case 'newest':
      return [...filtered].sort(
        (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
      );
    case 'oldest':
      return [...filtered].sort(
        (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
      );
    case 'urgency':
      return [...filtered].sort((a, b) => {
        // Sort by minimum Aegis score ascending (most urgent first)
        const aMin = minAegisScore(a.aegisScores);
        const bMin = minAegisScore(b.aegisScores);
        return aMin - bMin;
      });
  }
});

/** Count of pending approvals (for badge display). */
export const pendingCountAtom = atom((get) => get(pendingApprovalsAtom).length);

/** Full detail of the currently selected approval. */
export const selectedApprovalDetailAtom = atom((get) => {
  const id = get(selectedApprovalAtom);
  if (!id) return null;

  const pending = get(pendingApprovalsAtom).find((a) => a.id === id);
  if (pending) return { ...pending, source: 'pending' as const };

  const history = get(approvalHistoryAtom).find((a) => a.id === id);
  if (history) return { ...history, source: 'history' as const };

  return null;
});

function minAegisScore(scores: AegisScores): number {
  return Math.min(
    scores.output.score,
    scores.trace.score,
    scores.component.score,
    scores.drift.score
  );
}

// --- Action creators ---

export const approvalActions = {
  addPendingApproval: (approval: PendingApproval) => {
    const store = getDefaultStore();
    const current = store.get(pendingApprovalsAtom);
    // Avoid duplicates (SSE reconnection may resend)
    if (!current.some((a) => a.id === approval.id)) {
      store.set(pendingApprovalsAtom, [...current, approval]);
    }
  },

  removePendingApproval: (id: string) => {
    const store = getDefaultStore();
    const current = store.get(pendingApprovalsAtom);
    store.set(pendingApprovalsAtom, current.filter((a) => a.id !== id));
  },

  addToHistory: (entry: ApprovalHistoryEntry) => {
    const store = getDefaultStore();
    const current = store.get(approvalHistoryAtom);
    store.set(approvalHistoryAtom, [entry, ...current]);
  },

  toggleBatchSelect: (id: string) => {
    const store = getDefaultStore();
    const current = store.get(batchSelectedAtom);
    const next = new Set(current);
    if (next.has(id)) {
      next.delete(id);
    } else {
      next.add(id);
    }
    store.set(batchSelectedAtom, next);
  },

  selectAllPending: () => {
    const store = getDefaultStore();
    const pending = store.get(pendingApprovalsAtom);
    store.set(batchSelectedAtom, new Set(pending.map((a) => a.id)));
  },

  clearBatchSelection: () => {
    const store = getDefaultStore();
    store.set(batchSelectedAtom, new Set());
  },
};
```

**Approval queue React component:**

```tsx
// src/blocks/approval-queue/ApprovalQueueBlock.tsx

import React, { useState } from 'react';
import { useAtom, useAtomValue } from 'jotai';
import { motion, AnimatePresence } from 'motion/react';
import {
  sortedApprovalsAtom,
  selectedApprovalAtom,
  approvalSortAtom,
  batchModeAtom,
  batchSelectedAtom,
  pendingCountAtom,
  approvalActions,
} from '../../stores/approval';
import { ApprovalCard } from './ApprovalCard';
import { ApprovalDetail } from './ApprovalDetail';
import { BatchActionBar } from './BatchActionBar';
import { submitApprovalDecision } from '../../services/approval-api';
import type { BlockComponentProps } from '../../types/blocks';

export const ApprovalQueueBlock: React.FC<BlockComponentProps> = React.memo(
  ({ config }) => {
    const approvals = useAtomValue(sortedApprovalsAtom);
    const [selectedId, setSelectedId] = useAtom(selectedApprovalAtom);
    const [sort, setSort] = useAtom(approvalSortAtom);
    const [batchMode, setBatchMode] = useAtom(batchModeAtom);
    const batchSelected = useAtomValue(batchSelectedAtom);
    const pendingCount = useAtomValue(pendingCountAtom);
    const [isSubmitting, setIsSubmitting] = useState(false);

    const handleDecision = async (
      approvalId: string,
      decision: 'approved' | 'rejected' | 'request_changes',
      notes?: string,
    ) => {
      setIsSubmitting(true);
      try {
        await submitApprovalDecision(approvalId, { decision, notes });
        approvalActions.removePendingApproval(approvalId);
        approvalActions.addToHistory({
          id: approvalId,
          decision,
          decidedBy: 'user',
          decidedAt: new Date().toISOString(),
          notes,
        });

        if (selectedId === approvalId) {
          setSelectedId(null);
        }
      } finally {
        setIsSubmitting(false);
      }
    };

    const handleBatchDecision = async (
      decision: 'approved' | 'rejected',
    ) => {
      setIsSubmitting(true);
      try {
        const ids = Array.from(batchSelected);
        // Submit all decisions in parallel
        await Promise.all(
          ids.map((id) =>
            submitApprovalDecision(id, { decision })
          )
        );

        // Update local state
        for (const id of ids) {
          approvalActions.removePendingApproval(id);
          approvalActions.addToHistory({
            id,
            decision,
            decidedBy: 'user (batch)',
            decidedAt: new Date().toISOString(),
          });
        }

        approvalActions.clearBatchSelection();
        setBatchMode(false);
      } finally {
        setIsSubmitting(false);
      }
    };

    return (
      <div className="flex flex-col h-full bg-white dark:bg-gray-900">
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3 border-b border-gray-200 dark:border-gray-700">
          <div className="flex items-center gap-2">
            <h2 className="text-sm font-semibold text-gray-900 dark:text-white">
              Approval Queue
            </h2>
            {pendingCount > 0 && (
              <span className="px-2 py-0.5 text-xs font-medium bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200 rounded-full">
                {pendingCount}
              </span>
            )}
          </div>

          <div className="flex items-center gap-2">
            <select
              value={sort}
              onChange={(e) => setSort(e.target.value as any)}
              className="text-xs border rounded px-2 py-1 bg-white dark:bg-gray-800 dark:border-gray-600"
            >
              <option value="urgency">Sort: Urgency</option>
              <option value="newest">Sort: Newest</option>
              <option value="oldest">Sort: Oldest</option>
            </select>

            <button
              onClick={() => setBatchMode(!batchMode)}
              className={`text-xs px-2 py-1 rounded ${
                batchMode
                  ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
                  : 'bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300'
              }`}
            >
              {batchMode ? 'Exit Batch' : 'Batch Mode'}
            </button>
          </div>
        </div>

        {/* Batch action bar (visible in batch mode with selections) */}
        {batchMode && batchSelected.size > 0 && (
          <BatchActionBar
            selectedCount={batchSelected.size}
            onApprove={() => handleBatchDecision('approved')}
            onReject={() => handleBatchDecision('rejected')}
            onSelectAll={approvalActions.selectAllPending}
            onClear={approvalActions.clearBatchSelection}
            isSubmitting={isSubmitting}
          />
        )}

        {/* Content: list + detail split */}
        <div className="flex-1 flex overflow-hidden">
          {/* Approval list */}
          <div className="w-1/2 overflow-y-auto border-r border-gray-200 dark:border-gray-700">
            <AnimatePresence>
              {approvals.length === 0 ? (
                <div className="flex items-center justify-center h-full text-gray-400 text-sm">
                  No pending approvals
                </div>
              ) : (
                approvals.map((approval) => (
                  <motion.div
                    key={approval.id}
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, x: -100 }}
                    transition={{ duration: 0.2 }}
                  >
                    <ApprovalCard
                      approval={approval}
                      isSelected={selectedId === approval.id}
                      isBatchSelected={batchSelected.has(approval.id)}
                      batchMode={batchMode}
                      onClick={() => setSelectedId(approval.id)}
                      onBatchToggle={() =>
                        approvalActions.toggleBatchSelect(approval.id)
                      }
                    />
                  </motion.div>
                ))
              )}
            </AnimatePresence>
          </div>

          {/* Detail panel */}
          <div className="w-1/2 overflow-y-auto">
            {selectedId ? (
              <ApprovalDetail
                approvalId={selectedId}
                onDecision={handleDecision}
                isSubmitting={isSubmitting}
              />
            ) : (
              <div className="flex items-center justify-center h-full text-gray-400 text-sm">
                Select an approval to review
              </div>
            )}
          </div>
        </div>
      </div>
    );
  }
);
```

**Approval card component:**

```tsx
// src/blocks/approval-queue/ApprovalCard.tsx

import React from 'react';
import type { PendingApproval } from '../../types/approval';
import { AegisScoreBadge } from './AegisScoreBadge';
import { formatRelativeTime } from '../../utils/time';

interface ApprovalCardProps {
  approval: PendingApproval;
  isSelected: boolean;
  isBatchSelected: boolean;
  batchMode: boolean;
  onClick: () => void;
  onBatchToggle: () => void;
}

export const ApprovalCard: React.FC<ApprovalCardProps> = React.memo(
  ({ approval, isSelected, isBatchSelected, batchMode, onClick, onBatchToggle }) => {
    const minScore = Math.min(
      approval.aegisScores.output.score,
      approval.aegisScores.trace.score,
      approval.aegisScores.component.score,
      approval.aegisScores.drift.score
    );

    // Visual urgency indicators
    const urgencyClass =
      minScore < 2
        ? 'border-l-4 border-l-red-500 bg-red-50 dark:bg-red-950'
        : minScore < 3
          ? 'border-l-4 border-l-amber-500 bg-amber-50 dark:bg-amber-950'
          : 'border-l-4 border-l-green-500 bg-green-50 dark:bg-green-950';

    return (
      <div
        className={`p-3 cursor-pointer transition-colors ${urgencyClass} ${
          isSelected ? 'ring-2 ring-blue-500 ring-inset' : ''
        }`}
        onClick={batchMode ? onBatchToggle : onClick}
      >
        <div className="flex items-start gap-2">
          {batchMode && (
            <input
              type="checkbox"
              checked={isBatchSelected}
              onChange={onBatchToggle}
              className="mt-1"
              onClick={(e) => e.stopPropagation()}
            />
          )}

          <div className="flex-1 min-w-0">
            {/* Header row */}
            <div className="flex items-center justify-between mb-1">
              <span className="text-sm font-medium text-gray-900 dark:text-white truncate">
                {approval.agentRole}
              </span>
              <span className="text-xs text-gray-500 dark:text-gray-400">
                {formatRelativeTime(approval.createdAt)}
              </span>
            </div>

            {/* Gate type badge */}
            <div className="flex items-center gap-1 mb-2">
              <span className="text-xs px-1.5 py-0.5 rounded bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300">
                {formatGateType(approval.gateType)}
              </span>
              <span className="text-xs text-gray-500 dark:text-gray-400">
                Phase {approval.phaseId}
              </span>
            </div>

            {/* Aegis score summary */}
            <div className="flex items-center gap-1.5">
              <AegisScoreBadge label="Out" score={approval.aegisScores.output.score} />
              <AegisScoreBadge label="Trc" score={approval.aegisScores.trace.score} />
              <AegisScoreBadge label="Cmp" score={approval.aegisScores.component.score} />
              <AegisScoreBadge label="Dft" score={approval.aegisScores.drift.score} />
              <span className="text-xs font-medium text-gray-600 dark:text-gray-400 ml-1">
                {approval.aegisScores.overall.toFixed(1)}
              </span>
            </div>
          </div>
        </div>
      </div>
    );
  }
);

function formatGateType(type: string): string {
  const map: Record<string, string> = {
    phase_completion: 'Phase Complete',
    contract_validation: 'Contract Check',
    security_scan: 'Security Scan',
    pre_merge: 'Pre-Merge',
  };
  return map[type] || type;
}
```

**Aegis score badge component:**

```tsx
// src/blocks/approval-queue/AegisScoreBadge.tsx

import React from 'react';

interface AegisScoreBadgeProps {
  label: string;
  score: number;
}

export const AegisScoreBadge: React.FC<AegisScoreBadgeProps> = ({ label, score }) => {
  const colorClass =
    score >= 4
      ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
      : score >= 3
        ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
        : score >= 2
          ? 'bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200'
          : 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200';

  return (
    <span className={`inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-xs font-medium ${colorClass}`}>
      <span className="opacity-60">{label}</span>
      <span>{score}</span>
    </span>
  );
};
```

**Approval detail panel (expanded view with full QA report):**

```tsx
// src/blocks/approval-queue/ApprovalDetail.tsx

import React, { useState } from 'react';
import { useAtomValue } from 'jotai';
import { selectedApprovalDetailAtom } from '../../stores/approval';
import { AegisLayerCard } from './AegisLayerCard';
import { BlockerList } from './BlockerList';
import { IssueList } from './IssueList';
import { TestResultsSummary } from './TestResultsSummary';
import { ConfirmationDialog } from '../../components/ConfirmationDialog';

interface ApprovalDetailProps {
  approvalId: string;
  onDecision: (
    id: string,
    decision: 'approved' | 'rejected' | 'request_changes',
    notes?: string,
  ) => Promise<void>;
  isSubmitting: boolean;
}

export const ApprovalDetail: React.FC<ApprovalDetailProps> = ({
  approvalId,
  onDecision,
  isSubmitting,
}) => {
  const detail = useAtomValue(selectedApprovalDetailAtom);
  const [showConfirm, setShowConfirm] = useState<'approved' | 'rejected' | null>(null);
  const [notes, setNotes] = useState('');

  if (!detail) return null;

  const { aegisScores, qaReport } = detail.payload as any;

  return (
    <div className="p-4 space-y-4">
      {/* Agent info header */}
      <div>
        <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
          {detail.agentRole} - Phase {detail.phaseId}
        </h3>
        <p className="text-sm text-gray-500 dark:text-gray-400">
          Agent: {detail.agentId}
        </p>
      </div>

      {/* 4-layer Aegis scores */}
      <div className="space-y-2">
        <h4 className="text-sm font-medium text-gray-700 dark:text-gray-300">
          Quality Evaluation (Aegis 4-Layer)
        </h4>
        <div className="grid grid-cols-2 gap-2">
          <AegisLayerCard
            title="Output Layer"
            description="Result existence, schema, secrets"
            score={aegisScores.output}
          />
          <AegisLayerCard
            title="Trace Layer"
            description="Requirements, reasoning, tools"
            score={aegisScores.trace}
          />
          <AegisLayerCard
            title="Component Layer"
            description="Contract conformance, signatures"
            score={aegisScores.component}
          />
          <AegisLayerCard
            title="Drift Layer"
            description="Baseline comparison, security"
            score={aegisScores.drift}
          />
        </div>
      </div>

      {/* Blockers (if any) */}
      {qaReport.blockers.length > 0 && (
        <div>
          <h4 className="text-sm font-medium text-red-700 dark:text-red-400 mb-1">
            Blockers ({qaReport.blockers.length})
          </h4>
          <BlockerList blockers={qaReport.blockers} />
        </div>
      )}

      {/* Issues (if any) */}
      {qaReport.issues.length > 0 && (
        <div>
          <h4 className="text-sm font-medium text-amber-700 dark:text-amber-400 mb-1">
            Issues ({qaReport.issues.length})
          </h4>
          <IssueList issues={qaReport.issues} />
        </div>
      )}

      {/* Test results */}
      <TestResultsSummary results={qaReport.test_results} />

      {/* QE recommendations */}
      {qaReport.recommendations.length > 0 && (
        <div>
          <h4 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            Recommendations
          </h4>
          <ul className="text-sm text-gray-600 dark:text-gray-400 space-y-1">
            {qaReport.recommendations.map((rec: string, i: number) => (
              <li key={i} className="flex gap-2">
                <span className="text-gray-400">-</span>
                <span>{rec}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Decision notes textarea */}
      <div>
        <label className="text-sm font-medium text-gray-700 dark:text-gray-300">
          Decision Notes (optional)
        </label>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="Add notes about your decision..."
          className="w-full mt-1 px-3 py-2 text-sm border rounded-md bg-white dark:bg-gray-800 dark:border-gray-600"
          rows={2}
        />
      </div>

      {/* Action buttons */}
      {detail.source === 'pending' && (
        <div className="flex items-center gap-2 pt-2 border-t border-gray-200 dark:border-gray-700">
          <button
            onClick={() => setShowConfirm('approved')}
            disabled={isSubmitting}
            className="flex-1 px-4 py-2 text-sm font-medium text-white bg-green-600 hover:bg-green-700 disabled:opacity-50 rounded-md transition-colors"
          >
            Approve
          </button>
          <button
            onClick={() => onDecision(approvalId, 'request_changes', notes || undefined)}
            disabled={isSubmitting}
            className="flex-1 px-4 py-2 text-sm font-medium text-amber-700 bg-amber-100 hover:bg-amber-200 disabled:opacity-50 rounded-md transition-colors"
          >
            Request Changes
          </button>
          <button
            onClick={() => setShowConfirm('rejected')}
            disabled={isSubmitting}
            className="flex-1 px-4 py-2 text-sm font-medium text-white bg-red-600 hover:bg-red-700 disabled:opacity-50 rounded-md transition-colors"
          >
            Reject
          </button>
        </div>
      )}

      {/* Confirmation dialog */}
      {showConfirm && (
        <ConfirmationDialog
          title={`Confirm ${showConfirm === 'approved' ? 'Approval' : 'Rejection'}`}
          message={
            showConfirm === 'approved'
              ? `Approve ${detail.agentRole} output? The agent will resume execution.`
              : `Reject ${detail.agentRole} output? The agent will be stopped.`
          }
          confirmLabel={showConfirm === 'approved' ? 'Approve' : 'Reject'}
          confirmVariant={showConfirm === 'approved' ? 'success' : 'danger'}
          onConfirm={() => {
            onDecision(approvalId, showConfirm, notes || undefined);
            setShowConfirm(null);
          }}
          onCancel={() => setShowConfirm(null)}
        />
      )}
    </div>
  );
};
```

### 2.4 Batch Approval

The batch action bar appears when batch mode is active and items are selected. It allows approving or rejecting multiple gates simultaneously.

```tsx
// src/blocks/approval-queue/BatchActionBar.tsx

import React from 'react';

interface BatchActionBarProps {
  selectedCount: number;
  onApprove: () => void;
  onReject: () => void;
  onSelectAll: () => void;
  onClear: () => void;
  isSubmitting: boolean;
}

export const BatchActionBar: React.FC<BatchActionBarProps> = ({
  selectedCount,
  onApprove,
  onReject,
  onSelectAll,
  onClear,
  isSubmitting,
}) => {
  return (
    <div className="flex items-center justify-between px-4 py-2 bg-blue-50 dark:bg-blue-950 border-b border-blue-200 dark:border-blue-800">
      <div className="flex items-center gap-3">
        <span className="text-sm font-medium text-blue-800 dark:text-blue-200">
          {selectedCount} selected
        </span>
        <button
          onClick={onSelectAll}
          className="text-xs text-blue-600 dark:text-blue-400 hover:underline"
        >
          Select all
        </button>
        <button
          onClick={onClear}
          className="text-xs text-blue-600 dark:text-blue-400 hover:underline"
        >
          Clear
        </button>
      </div>

      <div className="flex items-center gap-2">
        <button
          onClick={onApprove}
          disabled={isSubmitting}
          className="px-3 py-1 text-xs font-medium text-white bg-green-600 hover:bg-green-700 disabled:opacity-50 rounded transition-colors"
        >
          Approve All ({selectedCount})
        </button>
        <button
          onClick={onReject}
          disabled={isSubmitting}
          className="px-3 py-1 text-xs font-medium text-white bg-red-600 hover:bg-red-700 disabled:opacity-50 rounded transition-colors"
        >
          Reject All ({selectedCount})
        </button>
      </div>
    </div>
  );
};
```

### 2.5 Desktop Notifications

When a QA gate requires human review, the system sends a desktop notification via Tauri's notification API.

```rust
// src-tauri/src/notifications.rs

use tauri::Manager;

/// Send a desktop notification for a pending QA gate.
pub fn send_gate_notification(
    app_handle: &tauri::AppHandle,
    agent_id: &str,
    scores: &AegisScores,
) {
    let min_score = [
        scores.output.score,
        scores.trace.score,
        scores.component.score,
        scores.drift.score,
    ].iter().min().copied().unwrap_or(0);

    let urgency = if min_score < 2 { "URGENT" } else { "Review" };

    let title = format!("[{}] QA Gate: {}", urgency, agent_id);
    let body = format!(
        "Scores: Out={} Trc={} Cmp={} Dft={} (Overall: {:.1})",
        scores.output.score,
        scores.trace.score,
        scores.component.score,
        scores.drift.score,
        scores.overall,
    );

    if let Err(e) = app_handle
        .notification()
        .builder()
        .title(&title)
        .body(&body)
        .show()
    {
        log::error!("Failed to send notification: {}", e);
    }
}
```

### 2.6 Approval Persistence (SQLite)

All approval decisions are persisted in the `approvals` table (defined in the master spec's schema). The persistence layer provides the audit trail and enables recovery after page reload (CopilotKit #2939 workaround).

```rust
// src-tauri/src/approval_db.rs

use rusqlite::{params, Connection, Result};

/// Insert a new pending approval record.
pub fn insert_approval(db: &Connection, approval: &PendingApproval) -> Result<()> {
    db.execute(
        "INSERT INTO approvals (id, build_id, agent_id, gate_type, status, payload, created_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
        params![
            approval.id,
            approval.build_id,
            approval.agent_id,
            serde_json::to_string(&approval.gate_type).unwrap(),
            "pending",
            serde_json::to_string(&serde_json::json!({
                "qaReport": approval.qa_report,
                "aegisScores": approval.aegis_scores,
                "agentRole": approval.agent_role,
                "phaseId": approval.phase_id,
            })).unwrap(),
            approval.created_at.to_rfc3339(),
        ],
    )?;
    Ok(())
}

/// Update an approval with a decision.
pub fn update_approval_decision(
    db: &Connection,
    approval_id: &str,
    decision: &str,
    decided_by: Option<&str>,
    notes: Option<&str>,
) -> Result<()> {
    let status = match decision {
        "approved" => {
            if decided_by == Some("system") { "auto_approved" } else { "human_approved" }
        }
        "rejected" => {
            if decided_by == Some("system") { "auto_rejected" } else { "human_rejected" }
        }
        "request_changes" => "changes_requested",
        _ => decision,
    };

    db.execute(
        "UPDATE approvals SET decision = ?1, decided_by = ?2, decided_at = ?3, status = ?4, notes = ?5
         WHERE id = ?6",
        params![
            decision,
            decided_by.unwrap_or("unknown"),
            chrono::Utc::now().to_rfc3339(),
            status,
            notes,
            approval_id,
        ],
    )?;

    // Also write to audit_log for immutable record
    db.execute(
        "INSERT INTO audit_log (id, timestamp, user_id, agent_id, action, resource_type, resource_id, new_value)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
        params![
            uuid::Uuid::new_v4().to_string(),
            chrono::Utc::now().to_rfc3339(),
            decided_by.unwrap_or("system"),
            "", // agent_id from the approval
            format!("approval_{}", decision),
            "approval",
            approval_id,
            serde_json::to_string(&serde_json::json!({
                "decision": decision,
                "notes": notes,
            })).unwrap(),
        ],
    )?;

    Ok(())
}

/// Retrieve all pending approvals (for STATE_SNAPSHOT on reconnect).
pub fn get_pending_approvals(db: &Connection) -> Result<Vec<PendingApproval>> {
    let mut stmt = db.prepare(
        "SELECT id, build_id, agent_id, gate_type, status, payload, created_at
         FROM approvals WHERE status = 'pending'
         ORDER BY created_at ASC"
    )?;

    let approvals = stmt.query_map([], |row| {
        let payload_str: String = row.get(5)?;
        let payload: serde_json::Value = serde_json::from_str(&payload_str).unwrap();

        Ok(PendingApproval {
            id: row.get(0)?,
            build_id: row.get(1)?,
            agent_id: row.get(2)?,
            agent_role: payload["agentRole"].as_str().unwrap_or("").to_string(),
            phase_id: payload["phaseId"].as_u64().unwrap_or(0) as u32,
            gate_type: serde_json::from_value(
                serde_json::Value::String(row.get::<_, String>(3)?)
            ).unwrap_or(GateType::PhaseCompletion),
            qa_report: payload["qaReport"].clone(),
            aegis_scores: serde_json::from_value(payload["aegisScores"].clone()).unwrap(),
            auto_decision: None,
            status: ApprovalStatus::Pending,
            created_at: chrono::DateTime::parse_from_rfc3339(&row.get::<_, String>(6)?)
                .unwrap()
                .with_timezone(&chrono::Utc),
            decided_at: None,
            decided_by: None,
            decision: None,
            notes: None,
        })
    })?.collect::<Result<Vec<_>>>()?;

    Ok(approvals)
}

/// Retrieve approval history with pagination.
pub fn get_approval_history(
    db: &Connection,
    limit: u32,
    offset: u32,
) -> Result<Vec<PendingApproval>> {
    let mut stmt = db.prepare(
        "SELECT id, build_id, agent_id, gate_type, status, payload, created_at, decision, decided_by, decided_at, notes
         FROM approvals WHERE status != 'pending'
         ORDER BY decided_at DESC
         LIMIT ?1 OFFSET ?2"
    )?;

    let approvals = stmt.query_map(params![limit, offset], |row| {
        let payload_str: String = row.get(5)?;
        let payload: serde_json::Value = serde_json::from_str(&payload_str).unwrap();

        Ok(PendingApproval {
            id: row.get(0)?,
            build_id: row.get(1)?,
            agent_id: row.get(2)?,
            agent_role: payload["agentRole"].as_str().unwrap_or("").to_string(),
            phase_id: payload["phaseId"].as_u64().unwrap_or(0) as u32,
            gate_type: serde_json::from_value(
                serde_json::Value::String(row.get::<_, String>(3)?)
            ).unwrap_or(GateType::PhaseCompletion),
            qa_report: payload["qaReport"].clone(),
            aegis_scores: serde_json::from_value(payload["aegisScores"].clone()).unwrap(),
            auto_decision: None,
            status: match row.get::<_, String>(4)?.as_str() {
                "auto_approved" => ApprovalStatus::AutoApproved,
                "auto_rejected" => ApprovalStatus::AutoRejected,
                "human_approved" => ApprovalStatus::HumanApproved,
                "human_rejected" => ApprovalStatus::HumanRejected,
                "changes_requested" => ApprovalStatus::ChangesRequested,
                _ => ApprovalStatus::Pending,
            },
            created_at: chrono::DateTime::parse_from_rfc3339(&row.get::<_, String>(6)?)
                .unwrap()
                .with_timezone(&chrono::Utc),
            decided_at: row.get::<_, Option<String>>(9)?
                .and_then(|s| chrono::DateTime::parse_from_rfc3339(&s).ok())
                .map(|dt| dt.with_timezone(&chrono::Utc)),
            decided_by: row.get(8)?,
            decision: row.get(7)?,
            notes: row.get(10)?,
        })
    })?.collect::<Result<Vec<_>>>()?;

    Ok(approvals)
}
```

### 2.7 Reactions Integration (Stub)

Phase 7 implements the full reactions system. This phase provides the hook point where a failed QA gate can trigger an automated retry.

```rust
// src-tauri/src/reactions_stub.rs

/// Stub for the reactions system (Phase 7).
/// When a QA gate fails and a reaction is configured,
/// this triggers the fix-and-revalidate cycle.
pub struct ReactionsStub {
    retry_counts: HashMap<String, u32>,
    max_retries: u32,
}

impl ReactionsStub {
    pub fn new(max_retries: u32) -> Self {
        Self {
            retry_counts: HashMap::new(),
            max_retries,
        }
    }

    /// Called when a QA gate is auto-rejected or human-rejected.
    /// Returns true if a retry should be attempted.
    pub fn should_retry(&mut self, agent_id: &str) -> bool {
        let count = self.retry_counts.entry(agent_id.to_string()).or_insert(0);
        if *count < self.max_retries {
            *count += 1;
            log::info!(
                "Reactions: retry {}/{} for agent {}",
                count, self.max_retries, agent_id
            );
            true
        } else {
            log::info!(
                "Reactions: max retries ({}) reached for agent {}, escalating to human",
                self.max_retries, agent_id
            );
            false
        }
    }

    /// Reset retry count after a successful approval.
    pub fn reset(&mut self, agent_id: &str) {
        self.retry_counts.remove(agent_id);
    }

    /// Get current retry count for an agent.
    pub fn retry_count(&self, agent_id: &str) -> u32 {
        self.retry_counts.get(agent_id).copied().unwrap_or(0)
    }
}
```

---

## 3. Acceptance Criteria

| ID | Criterion | Verification |
|----|-----------|-------------|
| AC-4.1 | QA gate triggers AG-UI interrupt event and pauses agent execution | Integration test: feed mock qa-report.json with scores in 2-3 range, verify RUN_FINISHED(interrupt) emitted and agent status is "waiting" |
| AC-4.2 | Approval queue block displays pending approvals with full QA report | UI test: inject 3 pending approvals via SSE, verify all 3 cards render with correct scores and gate types |
| AC-4.3 | User can approve individual gates | E2E test: click approval card, click Approve, confirm dialog, verify REST POST sent, verify agent status changes to "running" |
| AC-4.4 | User can reject individual gates | E2E test: click approval card, click Reject, confirm dialog, verify agent status changes to "failed" |
| AC-4.5 | User can request changes on individual gates | E2E test: click Request Changes with notes, verify notes persisted in SQLite, verify agent receives feedback |
| AC-4.6 | Batch approve/reject works for multiple gates | E2E test: enable batch mode, select 3 approvals, click Approve All, verify all 3 removed from pending, all 3 agents resumed |
| AC-4.7 | Auto-approve fires for scores >= 3 without human intervention | Unit test: create QA report with all scores = 4, verify auto-approve decision, verify no interrupt event emitted |
| AC-4.8 | Auto-reject fires for scores < 2 with notification | Unit test: create QA report with security score = 1, verify auto-reject decision, verify RUN_FINISHED(error) emitted |
| AC-4.9 | Scores in 2-3 range trigger human review | Unit test: create QA report with mixed scores (2, 3, 4, 3), verify no auto-decision, verify interrupt event emitted |
| AC-4.10 | Agent resumes execution after approval | Integration test: pause agent at gate, approve via REST, verify agent subprocess receives SIGCONT and continues producing output |
| AC-4.11 | All decisions logged to audit trail in SQLite | Test: approve and reject gates, query audit_log table, verify entries with correct action, user, timestamp |
| AC-4.12 | Desktop notification fires for new approval requests | Manual test: trigger QA gate, verify OS notification appears with agent name and scores |
| AC-4.13 | Pending approvals survive page reload | Test: create pending approval, reload page, verify approval appears on reconnect (from STATE_SNAPSHOT which reads from SQLite) |
| AC-4.14 | Approval queue sorts by urgency (lowest score first) | UI test: inject approvals with scores 4,4,4,4 and 2,3,2,3, verify second appears first in urgency sort |

---

## 4. Testing Strategy

### Unit Tests (Rust)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    fn make_qa_report(scores: [u8; 5]) -> QaReport {
        QaReport {
            schema_version: "1.0.0".to_string(),
            timestamp: "2026-03-20T00:00:00Z".to_string(),
            agent_role: "qe".to_string(),
            build_session_id: "test-build".to_string(),
            status: "PASS".to_string(),
            scores: QaScores {
                correctness: ScoreEntry { score: scores[0], notes: "test".to_string() },
                completeness: ScoreEntry { score: scores[1], notes: "test".to_string() },
                code_quality: ScoreEntry { score: scores[2], notes: "test".to_string() },
                security: ScoreEntry { score: scores[3], notes: "test".to_string() },
                contract_conformance: ScoreEntry { score: scores[4], notes: "test".to_string() },
            },
            test_results: TestResults {
                unit: TestCounts { pass: 10, fail: 0, skip: 0 },
                integration: TestCounts { pass: 5, fail: 0, skip: 0 },
                e2e: TestCounts { pass: 3, fail: 0, skip: 0 },
                contract: TestCounts { pass: 8, fail: 0, skip: 0 },
                security_scan: TestCounts { pass: 2, fail: 0, skip: 0 },
            },
            blockers: vec![],
            issues: vec![],
            recommendations: vec![],
            gate_decision: GateDecision { proceed: true, reason: "All clear".to_string() },
        }
    }

    #[test]
    fn test_auto_approve_all_high_scores() {
        let report = make_qa_report([4, 5, 4, 4, 5]);
        let scores = evaluate_aegis_layers(&report);
        let decision = compute_auto_decision(&scores);

        assert!(matches!(decision, Some(AutoDecisionResult::Approve { .. })));
        assert!(scores.output.score >= 3);
        assert!(scores.trace.score >= 3);
        assert!(scores.component.score >= 3);
        assert!(scores.drift.score >= 3);
    }

    #[test]
    fn test_auto_reject_security_failure() {
        let report = make_qa_report([4, 4, 4, 1, 4]);
        let scores = evaluate_aegis_layers(&report);
        let decision = compute_auto_decision(&scores);

        assert!(matches!(decision, Some(AutoDecisionResult::Reject { .. })));
    }

    #[test]
    fn test_human_review_borderline_scores() {
        let report = make_qa_report([3, 2, 3, 3, 2]);
        let scores = evaluate_aegis_layers(&report);
        let decision = compute_auto_decision(&scores);

        assert!(decision.is_none()); // Human review required
    }

    #[test]
    fn test_auto_approve_threshold_exactly_3() {
        let report = make_qa_report([3, 3, 3, 3, 3]);
        let scores = evaluate_aegis_layers(&report);
        let decision = compute_auto_decision(&scores);

        assert!(matches!(decision, Some(AutoDecisionResult::Approve { .. })));
    }

    #[test]
    fn test_security_blocker_forces_output_layer_failure() {
        let mut report = make_qa_report([4, 4, 4, 4, 4]);
        report.blockers.push(Blocker {
            id: "sec-1".to_string(),
            severity: "CRITICAL".to_string(),
            category: "security".to_string(),
            file: Some("src/auth.ts".to_string()),
            line: Some(42),
            description: "Exposed API key".to_string(),
            suggested_fix: "Move to environment variable".to_string(),
        });

        let scores = evaluate_aegis_layers(&report);

        assert_eq!(scores.output.score, 1); // Forced to 1 by security blocker
        let decision = compute_auto_decision(&scores);
        assert!(matches!(decision, Some(AutoDecisionResult::Reject { .. })));
    }

    #[test]
    fn test_reactions_stub_retry_limit() {
        let mut reactions = ReactionsStub::new(3);

        assert!(reactions.should_retry("agent-1")); // retry 1/3
        assert!(reactions.should_retry("agent-1")); // retry 2/3
        assert!(reactions.should_retry("agent-1")); // retry 3/3
        assert!(!reactions.should_retry("agent-1")); // exceeded limit

        reactions.reset("agent-1");
        assert!(reactions.should_retry("agent-1")); // reset, retry 1/3 again
    }

    #[test]
    fn test_aegis_overall_weighted_average() {
        let report = make_qa_report([5, 5, 5, 5, 5]);
        let scores = evaluate_aegis_layers(&report);

        // With all 5s, overall should be 5.0
        assert!((scores.overall - 5.0).abs() < 0.01);
    }

    #[test]
    fn test_aegis_overall_mixed_scores() {
        let report = make_qa_report([4, 3, 2, 4, 3]);
        let scores = evaluate_aegis_layers(&report);

        // Weights: output 25%, trace 30%, component 30%, drift 15%
        // This test verifies the weighted average is computed correctly.
        assert!(scores.overall > 2.0 && scores.overall < 5.0);
    }
}
```

### Frontend Component Tests

```typescript
// src/blocks/approval-queue/__tests__/ApprovalCard.test.tsx
import { render, screen } from '@testing-library/react';
import { ApprovalCard } from '../ApprovalCard';

describe('ApprovalCard', () => {
  const baseApproval: PendingApproval = {
    id: 'approval-1',
    agentId: 'backend-abc',
    agentRole: 'backend',
    phaseId: 5,
    gateType: 'phase_completion',
    aegisScores: {
      output: { score: 4, notes: 'ok', checks: [] },
      trace: { score: 3, notes: 'ok', checks: [] },
      component: { score: 2, notes: 'minor issues', checks: [] },
      drift: { score: 4, notes: 'ok', checks: [] },
      overall: 3.2,
      auto_decidable: false,
    },
    createdAt: new Date().toISOString(),
    status: 'pending',
  };

  it('renders agent role and scores', () => {
    render(
      <ApprovalCard
        approval={baseApproval}
        isSelected={false}
        isBatchSelected={false}
        batchMode={false}
        onClick={() => {}}
        onBatchToggle={() => {}}
      />
    );

    expect(screen.getByText('backend')).toBeInTheDocument();
    expect(screen.getByText('4')).toBeInTheDocument(); // output score
    expect(screen.getByText('2')).toBeInTheDocument(); // component score
  });

  it('shows amber border for scores in 2-3 range', () => {
    const { container } = render(
      <ApprovalCard
        approval={baseApproval}
        isSelected={false}
        isBatchSelected={false}
        batchMode={false}
        onClick={() => {}}
        onBatchToggle={() => {}}
      />
    );

    // Min score is 2, which falls in the amber range
    expect(container.firstChild).toHaveClass('border-l-amber-500');
  });

  it('shows red border for scores below 2', () => {
    const urgentApproval = {
      ...baseApproval,
      aegisScores: {
        ...baseApproval.aegisScores,
        component: { score: 1, notes: 'critical', checks: [] },
      },
    };

    const { container } = render(
      <ApprovalCard
        approval={urgentApproval}
        isSelected={false}
        isBatchSelected={false}
        batchMode={false}
        onClick={() => {}}
        onBatchToggle={() => {}}
      />
    );

    expect(container.firstChild).toHaveClass('border-l-red-500');
  });

  it('shows checkbox in batch mode', () => {
    render(
      <ApprovalCard
        approval={baseApproval}
        isSelected={false}
        isBatchSelected={false}
        batchMode={true}
        onClick={() => {}}
        onBatchToggle={() => {}}
      />
    );

    expect(screen.getByRole('checkbox')).toBeInTheDocument();
  });
});
```

### Integration Tests

```typescript
// tests/integration/approval-flow.test.ts

describe('Approval Flow (E2E)', () => {
  it('completes full approve flow: gate -> review -> approve -> resume', async () => {
    // 1. Start a mock build
    const build = await fetch('/api/build/start', {
      method: 'POST',
      body: JSON.stringify({ plan_id: 'test-plan' }),
    }).then(r => r.json());

    const agentId = build.data.agents[0].id;

    // 2. Simulate QA gate by posting a qa-report with mixed scores
    // (In production, the QE agent does this automatically)
    await simulateQaGate(agentId, {
      scores: { correctness: 3, completeness: 2, code_quality: 3, security: 3, contract_conformance: 3 },
    });

    // 3. Verify interrupt event arrives via SSE
    const events = await collectSSEEvents(1000); // 1 second window
    const interrupt = events.find(
      e => e.event.type === 'RUN_FINISHED' && e.event.outcome?.type === 'interrupt'
    );
    expect(interrupt).toBeDefined();
    expect(interrupt.event.outcome.reason).toBe('quality_gate');

    // 4. Verify agent is in "waiting" state
    const state = await fetch('/api/state').then(r => r.json());
    const agent = state.data.agents.find(a => a.id === agentId);
    expect(agent.status).toBe('waiting');

    // 5. Approve the gate
    const approvalId = interrupt.event.outcome.id;
    const decision = await fetch(`/api/approval/${approvalId}/decide`, {
      method: 'POST',
      body: JSON.stringify({ decision: 'approved', notes: 'Looks good' }),
    }).then(r => r.json());
    expect(decision.success).toBe(true);

    // 6. Verify agent resumed
    await new Promise(r => setTimeout(r, 500));
    const updatedState = await fetch('/api/state').then(r => r.json());
    const updatedAgent = updatedState.data.agents.find(a => a.id === agentId);
    expect(updatedAgent.status).toBe('running');

    // 7. Verify audit trail
    // (Would query SQLite directly in a real test)
  });

  it('auto-approves when all scores >= 3', async () => {
    const build = await fetch('/api/build/start', {
      method: 'POST',
      body: JSON.stringify({ plan_id: 'test-plan' }),
    }).then(r => r.json());

    const agentId = build.data.agents[0].id;

    await simulateQaGate(agentId, {
      scores: { correctness: 4, completeness: 4, code_quality: 4, security: 5, contract_conformance: 4 },
    });

    // Wait for auto-decision
    await new Promise(r => setTimeout(r, 200));

    // Should NOT have an interrupt -- should auto-approve
    const state = await fetch('/api/state').then(r => r.json());
    const agent = state.data.agents.find(a => a.id === agentId);
    // Agent should still be running (auto-approved, never paused)
    expect(agent.status).toBe('running');
  });
});
```

---

## 5. Risk Considerations

| Risk | Severity | Probability | Mitigation |
|------|----------|------------|------------|
| QE agent output does not conform to qa-report-schema.json | High | Medium | Validate report against JSON Schema before Aegis evaluation. Reject with clear error if schema validation fails. Include schema version in validation. |
| Auto-approve threshold too permissive (scores >= 3 allows mediocre output) | Medium | Medium | Make thresholds configurable per gate type. Start conservative (>= 4 for security). Log all auto-decisions for retrospective analysis. |
| CopilotKit interrupt resume failure (#1809) | Medium | Medium | REST-based approval as primary flow (not dependent on CopilotKit hooks). Polling verification after resume. Manual retry button in UI. |
| Batch approval accidentally approves gates user intended to reject | Medium | Low | Confirmation dialog for all batch actions. Visual preview of all items being affected. Undo within 5-second window (soft delete). |
| Desktop notifications blocked by OS settings | Low | Medium | Fallback: sonner toast within the app. Badge count on approval-queue block tab. Sound notification as secondary signal. |
| Race condition: agent finishes while approval is pending | Low | Low | Lock agent status during approval. If agent exits while waiting, cancel the pending approval and log the event. |
| Large QA reports slow down approval card rendering | Low | Low | Truncate blocker/issue lists in the card view (show count + "expand"). Full report only in detail panel with virtualized lists. |

---

## 6. Dependencies on Other Phases

| Phase | What This Phase Needs | What This Phase Provides |
|-------|----------------------|-------------------------|
| Phase 3 (Communication) | SSE event stream, REST API endpoints, process pause/resume, AG-UI event types | -- |
| Phase 1 (Foundation) | Block registry for approval-queue block type, Jotai atom infrastructure | -- |
| Phase 2 (Visualization) | -- | Approval status reflected in DAG node badges (gate nodes show pending/approved/rejected) |
| Phase 5 (Code Review) | -- | "Request Changes" decision feeds into diff viewer for targeted review |
| Phase 7 (Extensibility) | -- | ReactionsStub hook point for automated fix-and-revalidate cycles |

---

## 7. Open Decisions Resolved

| Question from Master Spec | Decision | Rationale |
|---------------------------|----------|-----------|
| Q7: CopilotKit SDK or custom AG-UI client? | Custom AG-UI client with REST-based approval | CopilotKit interrupt hooks have known bugs (#1809, #2315, #2939). REST-based flow is simpler and more reliable. CopilotKit hooks can be added later as a convenience layer. |
| Should auto-approve thresholds be fixed or configurable? | Configurable per gate type, defaults to >= 3 | Different gate types have different risk profiles. Security scans should be stricter. Configuration stored in SQLite `reactions` table. |
| Should batch approval require confirmation? | Yes, always | Prevents accidental mass-approval. Confirmation dialog shows count and lists affected agents. |

---

## 8. File Inventory

Files created or modified in this phase:

```
src-tauri/
  src/
    quality_gate.rs         # process_qa_gate, AegisScores, evaluation functions
    aegis_evaluator.rs      # 4-layer evaluation logic
    qa_report_types.rs      # QaReport struct matching qa-report-schema.json
    approval_db.rs          # SQLite persistence for approvals
    notifications.rs        # Desktop notification via Tauri
    reactions_stub.rs       # Retry/escalate stub for Phase 7
    rest_api.rs             # (modified) Add approval decision handler

src/
  stores/
    approval.ts             # Jotai atoms for approval queue state
  services/
    approval-api.ts         # REST client for approval decisions
  hooks/
    use-approval-interrupt.ts  # Hook for processing interrupt events
  blocks/
    approval-queue/
      ApprovalQueueBlock.tsx   # Main block component (registered in block registry)
      ApprovalCard.tsx         # Individual approval card
      ApprovalDetail.tsx       # Expanded detail panel with full QA report
      AegisScoreBadge.tsx      # Score visualization badge
      AegisLayerCard.tsx       # Layer detail card with checks
      BatchActionBar.tsx       # Batch selection action bar
      BlockerList.tsx          # Blocker items list
      IssueList.tsx            # Issue items list
      TestResultsSummary.tsx   # Test results grid
  components/
    ConfirmationDialog.tsx     # Reusable confirmation modal
  types/
    approval.ts               # TypeScript types for approval system
```
