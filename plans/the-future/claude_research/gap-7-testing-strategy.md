# Testing strategy for agentic systems: a complete guide for The Hive

**The single hardest problem in shipping AI agents to production is not building them — it is knowing whether they work.** A full **32% of teams** cite quality as their primary blocker to deploying agents, according to LangChain's 2025 State of AI Agents report, and Gartner predicts over 40% of agentic AI projects will be canceled by 2027. Yet while 89% of organizations have observability for their agents, only 52% run offline evaluations and just 37% evaluate live production traffic — a gap that turns every deployment into a gamble. The Hive, with its Queen orchestrator dispatching 20–30 parallel workers across Coder, Researcher, Reviewer, and Planner castes connected by a Valkey event bus, represents exactly the class of system where traditional testing collapses and purpose-built evaluation infrastructure becomes existential.

This report provides the complete testing strategy for The Hive: from deterministic unit tests through trajectory evaluation to production monitoring, with concrete TypeScript code, tool recommendations, and an implementation plan sequenced by priority.

---

## 1. Why testing agentic systems breaks classical assumptions

Traditional software testing rests on a deterministic contract: given input X, expect output Y. LLMs violate this contract at every level. Even at temperature zero, OpenAI has documented that floating-point non-determinism in batched computation means API responses are not bitwise identical across calls. An agent asked "What is the capital of France?" can validly produce "Paris," "The capital of France is Paris," or "Paris is the capital city of France" — a string equality assertion accepts at most one.

The problem compounds catastrophically in multi-step agent workflows. **A model with 99% per-step accuracy has only a 0.004% probability of completing a 1,000-step task without error** (0.99^1000 ≈ 0.00004). The Hive's architecture makes this worse: a Planner decomposes a task into subtasks, a Coder generates code for each, a Reviewer evaluates it, and the Queen orchestrates retries and handoffs. An error in the Planner's decomposition cascades through every downstream caste. As Anthropic's engineering team notes, "The autonomous nature of agents means higher costs, and the potential for compounding errors."

When something goes wrong in a 200-step trace, you are not finding a single line of code that failed. You are asking: why did the Queen dispatch to a Coder instead of a Researcher at step 23? Why did the Reviewer approve code with a subtle type error at step 47? LangChain's engineering blog frames it well: traditional traces do not capture the reasoning context behind each decision.

**The industry data paints a stark picture.** LangChain's 2025 report (1,340 respondents, surveyed November–December 2025) found that 57.3% of respondents have agents in production, but evaluation adoption severely lags observability. Human review remains the most common evaluation method at **59.8%**, followed by LLM-as-judge at **53.3%**, while traditional ML metrics like ROUGE and BLEU see limited adoption — they are "less suitable for open-ended agent interactions where multiple valid responses exist." Among teams not yet in production, 29.5% are not evaluating at all.

Gartner's June 2025 prediction that over 40% of agentic AI projects will be canceled by end of 2027 cites "escalating costs, unclear business value or inadequate risk controls." Their analyst Anushree Verma warned that "most agentic AI projects right now are early stage experiments or proof of concepts that are mostly driven by hype." They estimate only **~130 of thousands** of "agentic AI" vendors offer genuine agentic capabilities; the rest are rebranded chatbots and RPA. For The Hive, the message is clear: without rigorous testing and evaluation infrastructure, the system will not survive contact with production.

A 2025 academic paper ("Rethinking Testing for LLM Applications," arXiv:2508.20737) identifies four systemic mismatches between traditional testing and LLM-based systems: mismatch in test unit abstraction (single inputs vs. composite prompt chains and multi-agent coordination), assertion-based testing fundamentally breaking with natural language outputs, traditional coverage metrics having limited validity given the black-box nature of LLMs, and regression testing via output-equivalence being unreliable. Jest, Vitest, and Playwright remain essential for testing The Hive's deterministic TypeScript code — routing logic, schema validation, event bus handling — but they cannot test whether a Researcher agent correctly synthesized three web sources into an accurate summary.

---

## 2. The testing pyramid reimagined for agent architectures

The traditional testing pyramid inverts elegantly for agentic systems when organized by **uncertainty tolerance** rather than test type. Block's engineering team published the most detailed agent testing pyramid in January 2026 (authored by Angie Jones), and this framework maps directly onto The Hive's architecture across five distinct layers.

**Layer 1: Deterministic unit tests** form the pyramid's base. These test The Hive's TypeScript code with zero LLM involvement: does the Queen's router select the correct caste for a given task classification? Does the Valkey event bus correctly serialize and deserialize Cell lifecycle events? Are tool call schemas validated before dispatch? Does budget enforcement reject a task that would exceed an agent's token limit? These tests run in milliseconds, cost nothing, and belong in every commit. For The Hive, this layer covers Queen routing logic, Hivemind event serialization, Keeper approval gate conditions, and Worker tool schema validation.

**Layer 2: Component tests** isolate individual castes with mocked LLM responses. Record a real interaction between a Coder agent and Claude, commit the response fixture, and replay it deterministically. Block calls this "reproducible reality" — asserting tool call sequences and interaction flow, not exact outputs. The Hive should maintain recorded sessions for each caste: Coder generating a function, Researcher synthesizing search results, Reviewer identifying a bug, Planner decomposing a multi-step task.

**Layer 3: Integration tests** validate the full Cell lifecycle. A Cell in The Hive represents a complete task execution unit: Queen receives a request, classifies it, spawns a Worker of the correct caste, the Worker executes using tools, results flow back through the Hivemind bus, the Queen validates and returns. Integration tests verify this end-to-end flow with stubbed LLM providers, ensuring the message contracts between services are honored.

**Layer 4: Trajectory evaluation** tests the sequence of actions an agent takes, not just its final output. This is where agentic testing diverges most sharply from traditional approaches. As Databricks notes, "Strictly comparing the final answer to ground truth does not reveal whether the agent acted efficiently or used tools appropriately." A Coder might produce correct code through an inefficient trajectory — reading 15 files when 3 would suffice, or retrying a failed approach 8 times before succeeding by luck. Trajectory evaluation catches these hidden quality issues.

**Layer 5: End-to-end scenario tests** run full Hive operations against real or stubbed LLMs with LLM-as-judge scoring. Block's pyramid uses a majority vote: each evaluation runs 3 times, with a 4th tiebreaker if all three disagree. These tests are expensive, slow, and non-deterministic — they never run in CI but execute on-demand or nightly.

The "soft failure" concept is essential across all layers: **regression does not mean "the output changed" — it means "success rates dropped."** The Hive must track pass rates over rolling windows, not individual assertion failures. A Coder agent that succeeds on 92% of golden dataset entries is healthy; one that drops from 92% to 78% after a prompt change has regressed, even if every individual test case might still occasionally pass.

---

## 3. Golden datasets: the foundation of evaluation quality

A golden dataset is a curated, versioned collection of inputs, expected outputs, metadata, and evaluation criteria that serves as the source of truth for measuring quality. For The Hive, golden datasets are the equivalent of a comprehensive test suite — except they measure reasoning quality rather than code correctness.

**Start with 20–50 examples per caste and grow from production failures.** Multiple practitioner sources converge on this range: Klu.ai recommends 10–20 for initial iteration, Musubi Labs suggests 30–50 per policy area, and production-ready systems typically need 200–500 examples. The key insight is that coverage matters more than raw count — every production failure should become a golden dataset entry. Maxim AI calculates that achieving statistical rigor (80% pass rate, 5% margin of error, 95% confidence) requires approximately 246 samples per scenario, but this is a maturity target, not a starting requirement.

### Building golden datasets from scratch

The most effective pipeline begins with production logs. When The Hive processes real tasks, the Trail service (backed by ClickHouse) captures complete execution traces. From these traces, extract representative examples: tasks the system handled well, tasks it failed on, and edge cases that exposed unexpected behavior. Each entry should include the input task, the expected output, the rationale for why the expected output is correct, alternative outputs that would be acceptable, and metadata (caste, task type, difficulty level, edge case flags).

**The silver-to-gold promotion pipeline** accelerates dataset construction. Microsoft's Data Science team popularized this approach: use a frontier LLM to generate candidate question-answer pairs (the "silver" dataset), then have human domain experts review and verify them, promoting validated entries to "gold" status. For The Hive, this means using Claude or GPT-4 to generate diverse task inputs for each caste, then running them through the system, and having engineers verify both the inputs and the expected outputs.

### Preventing dataset contamination

Golden datasets must not overlap with any training data. Five decontamination techniques apply: exact and substring matching against known training corpora, continuation tests that probe whether models can reproduce long passages (indicating memorization), embedding similarity clustering to prune near-duplicates, cross-referencing against known training data when available, and regular audits as models update.

### Structuring golden datasets for The Hive

The Hive should organize datasets in its monorepo alongside the code they test:

```
packages/evals/
  golden/
    coder/
      function-generation.jsonl    # 30+ examples
      bug-fixes.jsonl              # 25+ examples
      refactoring.jsonl            # 20+ examples
    researcher/
      web-search-synthesis.jsonl   # 25+ examples
      document-analysis.jsonl      # 20+ examples
    reviewer/
      code-review-accuracy.jsonl   # 30+ examples
      false-positive-tests.jsonl   # 15+ examples
    planner/
      task-decomposition.jsonl     # 25+ examples
      dependency-ordering.jsonl    # 20+ examples
    adversarial/
      prompt-injection.jsonl       # 15+ examples
      budget-exhaustion.jsonl      # 10+ examples
    queen/
      routing-decisions.jsonl      # 40+ examples
      fallback-scenarios.jsonl     # 15+ examples
```

Each JSONL entry follows a consistent schema:

```jsonc
{
  "id": "coder-fn-gen-001",
  "version": "1.2.0",
  "input": {
    "task": "Write a TypeScript function that debounces async functions with proper return type inference",
    "context": { "language": "typescript", "framework": "none" }
  },
  "expected": {
    "output": "// reference implementation...",
    "criteria": ["handles async return types", "preserves generic types", "includes cancellation"],
    "acceptable_alternatives": ["using Promise wrapper", "using AbortController"]
  },
  "metadata": {
    "caste": "coder",
    "difficulty": "medium",
    "source": "production-failure-2026-02-15",
    "added_by": "engineer@tricentis.com",
    "tags": ["generics", "async", "utility-function"]
  }
}
```

Version golden datasets with Git for small datasets (under 1,000 entries) and DVC for larger datasets. DVC stores large files in cloud storage while keeping lightweight `.dvc` pointer files in Git, enabling `dvc checkout` to switch between dataset versions. Pin dataset versions to prompt versions and agent workflow configurations: when a system prompt changes, the golden dataset version should increment alongside it.

---

## 4. LLM-as-judge: scaling evaluation beyond human review

LLM-as-judge uses a capable model (typically GPT-4o, Claude Sonnet, or Gemini Pro) to evaluate another model's output against defined criteria. The process takes an original query, the agent's response, a scoring rubric, and optionally a reference answer, then produces a structured score with chain-of-thought reasoning. This approach scales evaluation by orders of magnitude compared to human review while achieving **>80% agreement with human preferences** — matching the inter-human agreement rate, as established by Zheng et al. at NeurIPS 2023.

### Cost and latency benchmarks

The Agent-as-a-Judge paper (Zhuge et al., ICML 2025) provides the clearest production cost data: evaluating the DevAI benchmark (55 tasks across 3 frameworks) cost **$1,297 and 86 hours** with human evaluators versus **~$31 and ~2 hours** with Agent-as-a-Judge — a 97% reduction in both cost and time. Agent-as-a-Judge achieved approximately **90% agreement** with human experts compared to ~70% for simpler LLM-as-Judge approaches. Langfuse reports typical per-evaluation costs of **$0.01–$0.10** for LLM-as-Judge, with costs scaling based on context length and judge model selection. Monte Carlo found that one enterprise's evaluation costs reached 10× the baseline agent workload, and recommends maintaining roughly a 1:1 workload-to-evaluation cost ratio by sampling strategically.

### Judge bias is real and measurable

Three primary biases identified by Zheng et al. and confirmed across subsequent research demand mitigation strategies in The Hive's evaluation pipeline.

**Position bias** causes LLMs to favor responses appearing in certain positions during pairwise comparison. Mitigation: randomize output positions and average results across swapped orderings. **Verbosity bias** leads judges to assign higher scores to longer responses regardless of quality — creating a perverse incentive for agents to pad output. Mitigation: use narrow scales (binary pass/fail or 1–5), provide calibration examples, and explicitly instruct judges to penalize unnecessary verbosity. **Self-enhancement bias** causes LLMs to systematically prefer their own outputs. An ICLR 2025 paper demonstrated that GPT-4 exhibits significant self-preference rooted in perplexity — models favor outputs with lower perplexity (outputs more "familiar" to them). Mitigation: use a different model family as judge than the one being evaluated.

Additional biases documented in the "Justice or Prejudice" paper include authority bias (influenced by fake citations), bandwagon-effect bias (influenced by stated popularity), and score clustering (tendency to assign middle-range scores on wide scales).

### Multi-judge panels reduce variance

Using multiple LLM judges as an ensemble produces more reliable scores. The DEBATE framework (2024) uses Scorer, Critic ("devil's advocate"), and Commander agents, outperforming single-agent evaluators on standard benchmarks. CourtEval (2025) uses a multi-agent court-style evaluation achieving state-of-the-art correlation with human judgments. The practical tradeoff is **2–3× cost** per evaluation. For The Hive, a pragmatic approach: use single judges during development iteration, multi-judge panels for deployment gates.

### Evaluation rubrics for each Hive caste

**Coder caste rubric** (binary + scored dimensions):

- Correctness: Does the code compile and pass test cases? (binary, deterministic)
- Style compliance: Does it follow project conventions? (1–5, LLM judge)
- Test coverage: Are edge cases handled? (binary, deterministic via coverage tool)
- Efficiency: Is the approach reasonable for the problem size? (1–5, LLM judge)
- Security: Any injection vectors, unsafe operations? (binary, static analysis + LLM)

**Researcher caste rubric:**

- Source quality: Are sources authoritative and current? (1–5, LLM judge)
- Synthesis accuracy: Are claims supported by cited sources? (binary, groundedness check)
- Hallucination rate: Any fabricated facts or sources? (binary, verification against sources)
- Coverage: Are key aspects of the topic addressed? (1–5 against reference checklist)

**Reviewer caste rubric:**

- Issue detection rate: What percentage of known issues were found? (numeric, deterministic)
- False positive rate: What percentage of flagged issues are non-issues? (numeric, deterministic)
- Severity accuracy: Are issues classified at correct severity? (categorical match)
- Actionability: Are suggestions specific and implementable? (1–5, LLM judge)

**Planner caste rubric:**

- Decomposition completeness: Are all necessary subtasks identified? (checklist match)
- Dependency accuracy: Are task dependencies correctly ordered? (DAG validation, deterministic)
- Granularity: Are subtasks appropriately sized — neither too broad nor too atomic? (1–5, LLM judge)
- Parallelism identification: Are independent subtasks correctly marked as parallelizable? (binary, deterministic)

---

## 5. Trajectory evaluation: testing how agents work, not just what they produce

Final-output evaluation is blind to process quality. A Coder agent might produce correct code through a chaotic trajectory — reading 20 files, calling the wrong tool 5 times, exhausting retries, and succeeding on the last attempt by luck. The output passes; the process is catastrophically fragile. Trajectory evaluation closes this gap by examining the **complete sequence of states, actions, observations, and reasoning** that an agent traverses.

### What trajectories capture

An agent trajectory is a step-by-step record comprising state (current context), action (tool call, search, response), observation (feedback after action), reasoning (internal logic), and reward (performance signal). Google Vertex AI defines six trajectory metrics: exact match, in-order match, any-order match, precision, recall, and single tool use verification. For The Hive, trajectory evaluation should measure:

- **Tool selection accuracy**: Did the Queen dispatch to the correct caste? Did the Coder use `write_file` rather than `read_file` at the right moment?
- **Parameter quality**: Were search queries well-formed? Were file paths correct?
- **Step count efficiency**: Did the agent complete the task in a reasonable number of steps?
- **Error recovery**: When a tool call failed, did the agent adapt appropriately?
- **Policy adherence**: Did the agent respect budget limits, avoid forbidden operations, and trigger human review when required?

### Multiple valid trajectories are the norm

The same task can legitimately be solved via different tool sequences. A Researcher tasked with synthesizing information about a topic might search three sources sequentially or two in parallel; both trajectories are valid. LangChain's AgentEvals framework addresses this with multiple matching modes:

```typescript
import { createTrajectoryMatchEvaluator } from "agentevals";

// Strict: identical messages in same order
const strictEval = createTrajectoryMatchEvaluator({
  trajectoryMatchMode: "strict",
});

// Superset: output trajectory is a superset of reference
// (allows additional useful steps beyond the minimum)
const supersetEval = createTrajectoryMatchEvaluator({
  trajectoryMatchMode: "superset",
});

// Unordered: same tool calls in any order
const unorderedEval = createTrajectoryMatchEvaluator({
  trajectoryMatchMode: "unordered",
});
```

For nuanced evaluation, the LLM-as-judge trajectory evaluator assesses efficiency and appropriateness without requiring exact matches:

```typescript
import { createTrajectoryLLMAsJudge } from "agentevals";

const trajectoryJudge = createTrajectoryLLMAsJudge({
  model: "openai:gpt-4o",
  criteria: `Evaluate whether the agent's trajectory was efficient and correct.
    Penalize: unnecessary tool calls, wrong tool selection, excessive retries.
    Reward: direct path to solution, appropriate error recovery, policy compliance.`,
});
```

### The pass@k and pass^k metrics measure different things

**pass@k** measures the probability that at least one of k independent runs succeeds — it answers "can the agent solve this at all?" The unbiased estimator is `pass@k = 1 - C(n-c, k) / C(n, k)`. **pass^k** from Sierra Research's τ-bench measures the probability of succeeding on *all* k trials — it answers "is the agent reliable?" pass^k decays exponentially: **a model with 90% pass@1 drops to just 57% consistency at pass^8**. τ-bench found GPT-4o achieves ~61% pass@1 on retail tasks but only ~25% pass^8. For The Hive's production deployment, pass^k is the metric that matters — customers need consistent reliability, not occasional success.

### Detecting trajectory anti-patterns

The Hive's Trail service should flag these automatically:

- **Retry spirals**: More than 3 consecutive failures on the same tool call pattern
- **Infinite loops**: Same state-action pair recurring more than twice (detectable via hash comparison)
- **Context window bloat**: Token count exceeding 70% of the model's context window mid-task
- **Tool call spirals**: Monotonically increasing tool call count without progress toward the goal
- **Budget exhaustion**: Approaching the Cell's token or cost budget without proportional task completion

The open-source `agent-chaos` library provides assertions like `MaxTotalLLMCalls` and `TokenBurstDetection` to catch these patterns in testing.

---

## 6. Testing the Queen's routing and orchestration logic

The Queen is The Hive's single point of coordination failure. If it misroutes a task, dispatches to a crashed Worker, or fails to enforce budget limits, every downstream operation suffers. Fortunately, the Queen's core logic is largely deterministic and testable with standard tools.

### Deterministic routing tests in Vitest

The Queen's task classification and caste routing should be tested exhaustively with conventional assertions. These tests mock the LLM response (or test the classification logic directly if rule-based) and verify routing correctness:

```typescript
// queen-routing.test.ts
import { describe, test, expect } from "vitest";
import { classifyTask, routeToCaste } from "@hive/queen/router";

describe("Queen routing decisions", () => {
  test.each([
    {
      input: "Write a debounce function in TypeScript",
      expectedCaste: "coder",
      expectedPriority: "normal",
    },
    {
      input: "Research the latest Node.js security advisories",
      expectedCaste: "researcher",
      expectedPriority: "normal",
    },
    {
      input: "Review this pull request for potential memory leaks",
      expectedCaste: "reviewer",
      expectedPriority: "high",
    },
    {
      input: "Break down the migration from Express to Fastify into subtasks",
      expectedCaste: "planner",
      expectedPriority: "normal",
    },
  ])(
    'routes "$input" to $expectedCaste caste',
    async ({ input, expectedCaste, expectedPriority }) => {
      const classification = await classifyTask(input);
      expect(classification.caste).toBe(expectedCaste);
      expect(classification.priority).toBe(expectedPriority);
    }
  );

  test("ambiguous tasks route to planner for decomposition", async () => {
    const result = await classifyTask(
      "Build a complete authentication system with OAuth, JWT, and role-based access"
    );
    expect(result.caste).toBe("planner");
    expect(result.requiresDecomposition).toBe(true);
  });

  test("rejects tasks exceeding budget cap", async () => {
    const result = await routeToCaste({
      task: "Analyze entire codebase",
      estimatedTokens: 5_000_000,
      budgetCap: 1_000_000,
    });
    expect(result.status).toBe("rejected");
    expect(result.reason).toContain("budget");
  });
});
```

### Testing the Keeper approval gate

The Keeper gate determines which actions require human review before execution. This is a critical safety boundary:

```typescript
// keeper-gate.test.ts
import { describe, test, expect } from "vitest";
import { requiresApproval } from "@hive/keeper/gate";

describe("Keeper approval gate", () => {
  test("file deletion requires approval", () => {
    expect(requiresApproval({ action: "delete_file", path: "/src/main.ts" }))
      .toBe(true);
  });

  test("file read does not require approval", () => {
    expect(requiresApproval({ action: "read_file", path: "/src/main.ts" }))
      .toBe(false);
  });

  test("external API calls with write scope require approval", () => {
    expect(requiresApproval({
      action: "api_call",
      method: "POST",
      url: "https://api.github.com/repos/owner/repo/issues",
    })).toBe(true);
  });

  test("budget exceeding 80% triggers approval", () => {
    expect(requiresApproval({
      action: "llm_call",
      currentSpend: 8500,
      budgetLimit: 10000,
    })).toBe(true);
  });
});
```

### Testing the Hivemind event bus

The Valkey/Redis event bus must guarantee message delivery, proper ordering, and dead letter handling. These are infrastructure tests that should run against a real Valkey instance in CI (via Docker):

```typescript
// hivemind-bus.test.ts
import { describe, test, expect, beforeAll, afterAll } from "vitest";
import { HivemindBus } from "@hive/hivemind/bus";
import { createClient } from "valkey";

describe("Hivemind event bus", () => {
  let bus: HivemindBus;
  let valkey: ReturnType<typeof createClient>;

  beforeAll(async () => {
    valkey = createClient({ url: "valkey://localhost:6379" });
    await valkey.connect();
    bus = new HivemindBus(valkey);
  });

  test("Cell lifecycle events arrive in order", async () => {
    const events: string[] = [];
    bus.subscribe("cell:test-001", (event) => events.push(event.type));

    await bus.emit("cell:test-001", { type: "spawned" });
    await bus.emit("cell:test-001", { type: "running" });
    await bus.emit("cell:test-001", { type: "completed" });

    // Allow propagation
    await new Promise((r) => setTimeout(r, 100));
    expect(events).toEqual(["spawned", "running", "completed"]);
  });

  test("unacknowledged messages move to dead letter after max retries", async () => {
    const failingHandler = async () => { throw new Error("processing failed"); };
    bus.subscribe("cell:dlq-test", failingHandler, { maxRetries: 3 });

    await bus.emit("cell:dlq-test", { type: "task", payload: "test" });
    await new Promise((r) => setTimeout(r, 5000));

    const dlqMessages = await bus.getDeadLetterMessages("cell:dlq-test");
    expect(dlqMessages).toHaveLength(1);
    expect(dlqMessages[0].retryCount).toBe(3);
  });

  afterAll(async () => {
    await valkey.quit();
  });
});
```

### Chaos engineering for The Hive

Traditional chaos engineering tools like Chaos Monkey target infrastructure. AI agents need chaos at the LLM and tool layer. The `agent-chaos` library provides LLM-specific fault injection: `llm_rate_limit`, `llm_server_error`, `llm_timeout`, `tool_error`, `tool_timeout`, and `tool_mutate` (data corruption). A 2025 arXiv paper (Owotogbe, arXiv:2505.03096) directly addresses chaos engineering for LLM-based multi-agent systems, finding that systems are "vulnerable to emergent errors or disruptions, such as hallucinations, agent failures, and agent communication failures."

For The Hive, chaos tests should verify: when 30% of Workers crash mid-task, does the Queen detect the failures via heartbeat timeout, reclaim the tasks from the Valkey reliable queue, and redispatch to healthy Workers? When the LLM provider returns a rate limit error, does the Worker retry with exponential backoff and eventually succeed or escalate gracefully? When a tool returns corrupted data, does the Reviewer caste catch the inconsistency?

---

## 7. The evaluation tooling ecosystem in 2026

The agentic evaluation tooling landscape consolidated significantly in early 2026 with two major acquisitions. Understanding the current state of each tool is critical for making infrastructure decisions that will serve The Hive for years.

**Langfuse** was acquired by ClickHouse on **January 16, 2026**, as part of ClickHouse's $400M Series D round valuing the company at $15 billion. Langfuse remains open-source (MIT license) and self-hostable. With **20,000+ GitHub stars** and **26M+ SDK installs per month**, it is the dominant open-source LLM observability platform. Langfuse v3 migrated its core data layer from Postgres to ClickHouse for high-throughput trace ingestion — which creates a natural infrastructure synergy with The Hive's Trail service, which already uses ClickHouse. Self-hosted Langfuse requires ClickHouse (OLAP traces), PostgreSQL (transactional data), Redis/Valkey (queuing/caching), and S3/blob storage (large payloads) — all components The Hive already runs. The TypeScript SDK v4 is built on OpenTelemetry:

```typescript
// hive-instrumentation.ts
import { NodeSDK } from "@opentelemetry/sdk-node";
import { LangfuseSpanProcessor } from "@langfuse/otel";

const langfuseProcessor = new LangfuseSpanProcessor({
  publicKey: process.env.LANGFUSE_PUBLIC_KEY!,
  secretKey: process.env.LANGFUSE_SECRET_KEY!,
  baseUrl: "http://langfuse.internal:3000", // self-hosted
  environment: process.env.NODE_ENV ?? "development",
});

const sdk = new NodeSDK({ spanProcessors: [langfuseProcessor] });
sdk.start();
```

**PromptFoo** was acquired by OpenAI on **March 9, 2026**, with its technology integrating into OpenAI Frontier. It remains open-source under MIT license. PromptFoo excels at declarative prompt testing (YAML-based configuration), red-teaming (50+ vulnerability types including OWASP LLM Top 10 and NIST AI RMF presets), and CI/CD integration via a dedicated GitHub Action. For The Hive, it is the best tool for automated regression testing and security scanning of agent prompts.

**Braintrust** provides the tightest production-to-eval feedback loop. Its `Eval()` TypeScript function, `autoevals` library (open-source scorers including Factuality, Levenshtein, and custom LLM-as-judge), and one-click trace-to-dataset conversion make it the strongest option for teams that want managed evaluation infrastructure. Braintrust's custom analytics engine, Brainstore, claims 80× faster queries than traditional data warehouses for AI traces.

**LangSmith** is LangChain's commercial platform offering tracing, evaluation, and the AgentEvals framework. Its Vitest integration for trajectory evaluation is directly usable in TypeScript:

```typescript
import * as ls from "langsmith/vitest";
import { createTrajectoryLLMAsJudge } from "agentevals";

const judge = createTrajectoryLLMAsJudge({ model: "openai:o3-mini" });

ls.describe("Coder trajectory evaluation", () => {
  ls.test("efficient file generation", {
    inputs: { task: "Create a debounce utility" },
    referenceOutputs: { trajectory: expectedToolCalls },
  }, async ({ inputs, referenceOutputs, outputs }) => {
    const result = await judge({ outputs, referenceOutputs });
    ls.logFeedback({ key: "trajectory_quality", score: result.score });
  });
});
```

**Arize Phoenix** is the safest long-term open-source bet — fully MIT licensed, OpenTelemetry-native, no acquisitions, no feature gates between self-hosted and cloud, and framework-agnostic. It provides pre-built evaluation templates for RAG relevance, hallucination detection, toxicity, and code generation quality.

**RAGAS** specializes in retrieval evaluation with metrics like Faithfulness, Answer Relevancy, Context Precision, and Context Recall. For The Hive's Researcher caste, RAGAS patterns directly apply to evaluating source quality and synthesis accuracy.

### The recommended stack for The Hive

Given The Hive's existing infrastructure (TypeScript/Node.js, ClickHouse, PostgreSQL, Valkey), the optimal evaluation stack shares maximum infrastructure:

- **Vitest** for deterministic tests (Layer 1–3): routing, schemas, event bus, lifecycle
- **Langfuse** (self-hosted, sharing The Hive's ClickHouse instance): trace ingestion, dataset management, prompt versioning, scoring API
- **PromptFoo** for CI/CD regression testing and red-teaming
- **Braintrust autoevals** (open-source library) or custom LLM-as-judge for quality scoring
- **AgentEvals** (`agentevals` npm package) for trajectory evaluation

---

## 8. CI/CD integration: making evals a deployment gate

The fundamental tension in CI/CD for agent systems is that the most valuable evaluations (LLM-as-judge, trajectory evaluation) are expensive, slow, and non-deterministic — exactly the properties that make tests unsuitable for blocking every commit. The solution is a tiered evaluation budget.

### The tiered eval strategy

| Trigger | Test type | Cost | Duration | The Hive specifics |
|---|---|---|---|---|
| Every commit | Deterministic unit tests | Free | < 30s | Queen routing, schema validation, Keeper gates |
| PR (path-filtered) | Component tests + small golden set | ~$0.50–$2.00 | 2–5 min | 10–20 golden examples per affected caste, mocked LLMs |
| Merge to main | Full eval suite with LLM-as-judge | ~$10–$50 | 10–30 min | Full golden dataset, multi-caste trajectory evaluation |
| Nightly/scheduled | Comprehensive benchmarks + red teaming | ~$50–$200 | 30–60 min | A/B prompt comparisons, security scanning, pass^k reliability |

Path filtering ensures expensive evals only run when relevant files change:

```yaml
# .github/workflows/eval-pipeline.yml
name: Hive Eval Pipeline
on:
  pull_request:
    paths: ["packages/queen/**", "packages/workers/**", "packages/evals/**"]
  push:
    branches: [main]
  schedule:
    - cron: "0 3 * * *" # Nightly at 3 AM

jobs:
  deterministic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "22" }
      - run: npm ci
      - run: npx vitest run --config vitest.config.ts
        # Tests Queen routing, schemas, Keeper gates, bus serialization

  llm-evals:
    if: github.event_name == 'push' || github.event_name == 'schedule'
    needs: deterministic
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: "22" }
      - run: npm ci
      - name: Run golden dataset evals
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
          LANGFUSE_SECRET_KEY: ${{ secrets.LANGFUSE_SECRET_KEY }}
        run: npx vitest run --config vitest.eval.config.ts
      - name: Quality gate
        run: |
          PASS_RATE=$(jq '.results.passRate' eval-results.json)
          if (( $(echo "$PASS_RATE < 0.90" | bc -l) )); then
            echo "❌ Quality gate failed: ${PASS_RATE}"
            exit 1
          fi

  red-team:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: promptfoo/promptfoo-action@v1
        with:
          type: "redteam"
          config: "promptfooconfig.yaml"
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Regression detection through baselines

Anthropic's evaluation guide distinguishes two eval categories: **capability evals** start at low pass rates and represent goals the agent is working toward, while **regression evals** should maintain ~100% pass rates and any decline signals breakage. When capability evals achieve consistently high pass rates, they "graduate" to the regression suite. The Hive should maintain a fixed baseline: a snapshot of eval results from a known-good deployment. Every subsequent evaluation compares against this baseline, not just the previous version. This prevents gradual quality erosion where each deployment is "slightly worse" than the last but never triggers an absolute threshold.

### Handling non-deterministic flakiness

Run each eval task multiple times (3–5 trials) and aggregate. A task that passes 4/5 times is flaky and warrants investigation; one that fails 5/5 times is a genuine regression. Use **95% confidence intervals** (CI = x̄ ± 1.96 × SE, where SE = σ/√n) rather than point estimates for pass rates. If the confidence intervals of two prompt versions do not overlap, the difference is statistically significant. Anthropic's research team emphasizes that "fundamentally, evaluations are experiments" and recommends paired-difference analysis when comparing models, since frontier models perform similarly on shared questions and paired tests are more powerful than independent two-sample tests.

---

## 9. Online evaluation: monitoring agents in production

Offline evals against golden datasets catch regressions before deployment, but production traffic is always more diverse, adversarial, and unpredictable than any curated test set. Online evaluation bridges this gap by scoring real-world agent performance continuously.

### Sampling strategies for production traces

The Hive's Trail service already captures traces in ClickHouse. Langfuse's OpenTelemetry sampler controls what percentage of traces are ingested:

```typescript
import { TraceIdRatioBasedSampler } from "@opentelemetry/sdk-trace-base";
import { NodeSDK } from "@opentelemetry/sdk-node";
import { LangfuseSpanProcessor } from "@langfuse/otel";

const sdk = new NodeSDK({
  sampler: new TraceIdRatioBasedSampler(0.1), // Sample 10% of traces
  spanProcessors: [new LangfuseSpanProcessor()],
});
```

Four sampling strategies should operate in parallel: **random sampling** (5–10% of all traffic) provides an unbiased quality baseline; **stratified sampling** ensures coverage across castes, task types, and customer segments; **anomaly-triggered sampling** captures 100% of traces where confidence scores drop below a threshold or latency spikes; and **error-triggered sampling** always captures traces that result in failures.

### User feedback closes the loop

The Hive's Yield service (the user-facing dashboard) should collect feedback at multiple granularities: binary thumbs up/down on task results, edit distance between the agent's output and the user's final accepted version (a powerful implicit quality signal), and explicit ratings on individual Worker outputs. Langfuse's web SDK supports client-side score collection:

```typescript
import { LangfuseWeb } from "langfuse";

const langfuseWeb = new LangfuseWeb({ publicKey: "pk-lf-..." });

// When user clicks thumbs up/down
await langfuseWeb.score({
  traceId: currentCell.traceId,
  name: "user-feedback",
  value: 1, // or 0
  comment: "Code worked correctly on first try",
});
```

### Drift detection across four dimensions

Agent performance can degrade without any code or prompt changes — model provider updates, shifting user behavior, and evolving data all contribute. The Hive should monitor four drift types, following the framework from recent agent drift research:

- **Goal drift**: Changes in the distribution of task types arriving at the Queen. Detect via chi-squared test on task classification distributions (p-value < 0.05 threshold). If suddenly 40% of tasks are code review when historically it was 15%, the golden dataset may no longer be representative.
- **Context drift**: Changes in the data and knowledge agents access. Monitor embedding similarity between retrieved documents over time.
- **Reasoning drift**: Changes in model behavior from provider-side updates. Track pass^k reliability scores on a fixed probe set weekly.
- **Collaboration drift**: Degradation in tool and integration reliability. Monitor tool success rates per tool per caste.

Set alerts when the **Population Stability Index exceeds 0.1** (indicating significant distribution shift) or when rolling 7-day pass rates drop more than 5 percentage points below baseline.

### Closing the feedback loop

The most valuable outcome of production monitoring is **growing the golden dataset**. When a production trace reveals a failure mode not covered by existing golden data, it should enter the silver-to-gold pipeline: the trace is flagged, an engineer reviews and annotates the expected behavior, and the entry is promoted to the golden dataset. Braintrust enables this with one-click trace-to-dataset conversion. For The Hive, the Trail service should surface candidate traces via a ClickHouse query:

```sql
SELECT trace_id, cell_id, caste, task_input, task_output, 
       user_feedback_score, llm_judge_score
FROM hive_traces
WHERE user_feedback_score = 0  -- negative feedback
   OR llm_judge_score < 0.5   -- low quality score
   OR error_count > 3         -- excessive errors
ORDER BY created_at DESC
LIMIT 50;
```

---

## 10. The Hive implementation plan: what to build and when

This plan sequences testing infrastructure in strict priority order, ensuring each phase delivers measurable quality improvement before the next begins.

### Phase 0: Foundation (before writing agent code)

Set up the test harness, golden dataset skeleton, and eval pipeline scaffolding. Create the monorepo structure under `packages/evals/` with empty golden dataset files for each caste. Configure Vitest with two config files: `vitest.config.ts` for deterministic tests (runs on every commit) and `vitest.eval.config.ts` for LLM-backed evals (runs on merge to main). Deploy self-hosted Langfuse sharing The Hive's existing ClickHouse and Valkey instances — the only additional infrastructure needed is the Langfuse Web container and Langfuse Worker container.

### Phase 1: Wire phase testing (Queen dispatch → Worker spawn → Result return)

This is the minimum viable test suite for The Hive's first working end-to-end flow:

```typescript
// cell-lifecycle.test.ts
import { describe, test, expect, beforeAll } from "vitest";
import { Queen } from "@hive/queen";
import { MockLLMProvider } from "@hive/testing/mocks";

describe("Cell lifecycle - Wire phase", () => {
  let queen: Queen;
  let mockLLM: MockLLMProvider;

  beforeAll(() => {
    mockLLM = new MockLLMProvider({
      "coder": { response: 'function debounce(fn, ms) { /* ... */ }' },
      "classifier": { response: '{"caste": "coder", "priority": "normal"}' },
    });
    queen = new Queen({ llmProvider: mockLLM, bus: testBus });
  });

  test("Queen dispatches coding task to Coder worker", async () => {
    const cell = await queen.createCell({
      task: "Write a debounce function",
      requester: "user-001",
    });

    expect(cell.status).toBe("spawned");
    expect(cell.assignedCaste).toBe("coder");

    const result = await cell.waitForCompletion({ timeout: 30_000 });
    expect(result.status).toBe("completed");
    expect(result.output).toBeDefined();
  });

  test("Queen rejects task when all Workers are busy", async () => {
    // Saturate worker pool
    const tasks = Array.from({ length: 30 }, (_, i) =>
      queen.createCell({ task: `Task ${i}`, requester: "load-test" })
    );
    await Promise.all(tasks);

    // 31st task should queue or reject
    const overflow = await queen.createCell({
      task: "One more task",
      requester: "load-test",
    });
    expect(["queued", "rejected"]).toContain(overflow.status);
  });

  test("Failed Worker triggers retry with exponential backoff", async () => {
    mockLLM.setFailureMode("coder", { failCount: 2, thenSucceed: true });

    const cell = await queen.createCell({
      task: "Write a function",
      requester: "retry-test",
    });
    const result = await cell.waitForCompletion({ timeout: 60_000 });

    expect(result.status).toBe("completed");
    expect(result.retryCount).toBe(2);
  });
});
```

### Sample golden dataset entries for the Coder caste

```jsonc
// packages/evals/golden/coder/function-generation.jsonl
{"id":"coder-001","input":{"task":"Write a TypeScript function that deeply merges two objects, handling arrays by concatenation","context":{"language":"typescript","targetNode":">=18"}},"expected":{"mustInclude":["generic type parameter","recursive call","Array.isArray check","return type matches input types"],"mustNotInclude":["any type","as unknown"],"testCases":["deepMerge({a:1},{b:2}) => {a:1,b:2}","deepMerge({a:[1]},{a:[2]}) => {a:[1,2]}","deepMerge({a:{b:1}},{a:{c:2}}) => {a:{b:1,c:2}}"]},"metadata":{"difficulty":"medium","tags":["generics","recursion","utility"]}}
{"id":"coder-002","input":{"task":"Fix this bug: the function returns undefined for empty arrays","context":{"code":"function first<T>(arr: T[]): T { return arr[0]; }","language":"typescript"}},"expected":{"mustInclude":["T | undefined","optional return type OR explicit undefined handling"],"criteria":"The fix must make the return type reflect the possibility of undefined without using non-null assertion"},"metadata":{"difficulty":"easy","tags":["bug-fix","types"],"source":"production-2026-02-20"}}
{"id":"coder-003","input":{"task":"Refactor this Express middleware to work with Fastify","context":{"code":"app.use((req, res, next) => { req.startTime = Date.now(); next(); res.on('finish', () => console.log(Date.now() - req.startTime)); });","language":"typescript"}},"expected":{"mustInclude":["onRequest OR preHandler hook","onResponse hook","fastify.decorateRequest"],"mustNotInclude":["app.use","next()"]},"metadata":{"difficulty":"medium","tags":["refactoring","fastify","migration"]}}
```

### The eval metrics dashboard in The Yield service

The Yield service should display a quality dashboard querying ClickHouse for eval data. Key panels and their queries:

```sql
-- Pass rate by caste (rolling 7 days)
SELECT caste, 
  countIf(llm_judge_score >= 0.7) / count(*) AS pass_rate,
  avg(llm_judge_score) AS avg_score,
  count(*) AS total_evals
FROM hive_eval_results
WHERE created_at >= now() - INTERVAL 7 DAY
GROUP BY caste;

-- Trajectory efficiency trends
SELECT toDate(created_at) AS day, caste,
  avg(step_count) AS avg_steps,
  avg(total_tokens) AS avg_tokens,
  avg(retry_count) AS avg_retries
FROM hive_traces
WHERE created_at >= now() - INTERVAL 30 DAY
GROUP BY day, caste
ORDER BY day;

-- Quality regression detection (compare to baseline)
SELECT caste,
  baseline.pass_rate AS baseline_rate,
  current.pass_rate AS current_rate,
  current.pass_rate - baseline.pass_rate AS delta
FROM (
  SELECT caste, countIf(score >= 0.7) / count(*) AS pass_rate
  FROM hive_eval_results WHERE eval_run = 'baseline-v1'
  GROUP BY caste
) baseline
JOIN (
  SELECT caste, countIf(score >= 0.7) / count(*) AS pass_rate
  FROM hive_eval_results WHERE created_at >= now() - INTERVAL 1 DAY
  GROUP BY caste
) current ON baseline.caste = current.caste;
```

The dashboard should display: per-caste pass rates with trend sparklines, trajectory efficiency (average steps, tokens, retries), cost per task by caste, user feedback correlation (LLM judge score vs. user thumbs up/down), and a drift indicator showing whether production task distributions match the golden dataset distribution.

### LLM-as-judge integration for The Hive

A reusable judge function for scoring Worker outputs across all castes:

```typescript
// packages/evals/lib/judge.ts
import { generateObject } from "ai";
import { openai } from "@ai-sdk/openai";
import { z } from "zod";
import { Langfuse } from "langfuse";

const langfuse = new Langfuse({
  secretKey: process.env.LANGFUSE_SECRET_KEY!,
  publicKey: process.env.LANGFUSE_PUBLIC_KEY!,
});

const JudgeResult = z.object({
  score: z.number().min(0).max(1),
  passed: z.boolean(),
  reasoning: z.string(),
  dimensions: z.record(z.number().min(0).max(1)),
});

export async function judgeWorkerOutput(params: {
  caste: string;
  taskInput: string;
  workerOutput: string;
  expectedOutput?: string;
  rubric: string;
  traceId: string;
}) {
  const { object } = await generateObject({
    model: openai("gpt-4o"),
    schema: JudgeResult,
    prompt: `You are an expert evaluator for a ${params.caste} AI agent.

TASK INPUT: ${params.taskInput}
AGENT OUTPUT: ${params.workerOutput}
${params.expectedOutput ? `REFERENCE OUTPUT: ${params.expectedOutput}` : ""}

EVALUATION RUBRIC:
${params.rubric}

Score from 0.0 to 1.0. Set passed=true if score >= 0.7.
Provide per-dimension scores in the dimensions object.
Explain your reasoning.`,
  });

  // Record score in Langfuse
  await langfuse.score({
    traceId: params.traceId,
    name: `${params.caste}-quality`,
    value: object.score,
    comment: object.reasoning,
  });

  return object;
}

// Caste-specific rubrics
export const CODER_RUBRIC = `
Evaluate on these dimensions (score each 0-1):
- correctness: Does the code compile and produce correct results?
- type_safety: Are TypeScript types properly used without 'any' or unsafe casts?
- style: Does it follow modern TypeScript conventions?
- completeness: Are edge cases handled?
- efficiency: Is the approach reasonable for the problem?`;

export const RESEARCHER_RUBRIC = `
Evaluate on these dimensions (score each 0-1):
- source_quality: Are sources authoritative and current?
- accuracy: Are all claims factually correct and supported?
- synthesis: Is information from multiple sources coherently combined?
- coverage: Are key aspects of the topic addressed?
- hallucination_free: Are there any fabricated facts or sources?`;
```

### Implementation priority sequence

1. **Week 1–2**: Vitest deterministic tests for Queen routing, Keeper gates, Hivemind bus serialization, Cell lifecycle state machine. These tests block every PR.
2. **Week 2–3**: Self-hosted Langfuse deployment sharing The Hive's ClickHouse instance. Instrument all Worker agents with the Langfuse TypeScript SDK v4 for trace capture.
3. **Week 3–4**: Golden dataset skeleton with 20+ entries per caste. LLM-as-judge scoring function with caste-specific rubrics. First `vitest.eval.config.ts` running on merge to main.
4. **Week 4–6**: Trajectory evaluation using AgentEvals for multi-step task flows. Anti-pattern detection in the Trail service (retry spirals, budget exhaustion, context bloat).
5. **Week 6–8**: Production sampling at 10% with online LLM-as-judge scoring. User feedback collection in the Yield service. Drift detection alerts.
6. **Week 8+**: PromptFoo red-teaming in nightly CI runs. Silver-to-gold pipeline from production failures. Eval metrics dashboard in The Yield service querying ClickHouse.

---

## Conclusion

Testing agentic systems demands a fundamentally different mindset from traditional software testing. The Hive cannot rely on deterministic assertions for outputs generated by stochastic models operating across multi-step workflows where errors compound exponentially. The five-layer testing pyramid — from deterministic unit tests through trajectory evaluation — provides the structure, while tools like Langfuse (now sharing infrastructure with ClickHouse), AgentEvals for trajectory matching, and LLM-as-judge scoring provide the mechanisms.

Three insights should guide The Hive's testing strategy above all else. First, **test the skeleton, not the model**: the vast majority of bugs in agent systems come from routing logic, tool selection, parameter construction, and state management — all deterministic and cheaply testable. Second, **regression means pass rates dropped, not outputs changed**: non-determinism is inherent and acceptable; declining success rates across golden datasets are not. Third, **production failures are the most valuable test data**: every negative user feedback, every flagged trace, every budget-exceeding Cell should flow back into the golden dataset through the silver-to-gold pipeline, creating a testing infrastructure that gets stronger with every failure it encounters.

The minimum viable investment is surprisingly small: Vitest for deterministic tests, self-hosted Langfuse for traces (sharing existing infrastructure), and a 20-entry golden dataset per caste with LLM-as-judge scoring. This foundation, built before the first agent ships, is the difference between the 57% of teams that successfully deploy agents to production and the 40% that Gartner predicts will abandon the effort entirely.