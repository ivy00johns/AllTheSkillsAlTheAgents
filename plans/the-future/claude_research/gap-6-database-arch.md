# The Hive's database architecture should use three databases, not one

**PostgreSQL + Redis/Valkey + ClickHouse is the production-proven trident** that both Langfuse and LangSmith independently converged on for LLM observability — and it maps almost perfectly onto The Hive's nine components. The polyglot persistence question has a clear answer: not one database, not nine databases, but exactly three plus an optional fourth (Dolt) if you want Beads-style version-controlled task graphs. At 20–30 concurrent agents emitting a combined **~3,000 events/hour**, this workload is trivially handled by commodity hardware. The architectural decisions that matter here aren't about raw throughput — they're about choosing the right data model for each concern and building a storage adapter layer that lets you evolve without rewrites.

Mission Control's SQLite single-writer ceiling and Babysitter's flat JSONL files represent two ends of a simplicity spectrum that both break at horizontal scale. The Hive needs to thread the needle: operationally simple enough for a small team to run, architecturally sound enough to grow to hundreds of agents. The research points to a clear path.

---

## The three-database pattern that keeps winning

Langfuse started as a single Postgres container in March 2023. By summer 2023, ingestion latency hit **50 seconds**. They added Redis queues, then migrated traces to ClickHouse. By March 2025, over **1,000 self-hosted deployments** ran this three-database architecture in production. LangSmith (LangChain's observability platform) independently arrived at the identical stack: **ClickHouse for traces, PostgreSQL for operational data, Redis for hot-path state**. This isn't coincidence — it's convergence on the right tool boundaries.

The pattern maps onto The Hive's concerns cleanly:

| Database | Role in The Hive | Handles |
|---|---|---|
| **PostgreSQL** | Durable source of truth | Agent registry (Yard), task graph (Comb), skill registry (Waggle), approvals (Keeper), routing state (Queen), cost records (Yield) |
| **Valkey/Redis** | Hot-path coordination layer | Agent output streaming (Glass), CLI dispatch (Smoker), rate limiting, pub/sub, ephemeral state, session cache |
| **ClickHouse** | Analytical engine | Distributed traces (Trail), historical metrics (Yield aggregations), audit trail queries |

This gives you **ACID transactions** where you need them (task state, approvals, billing), **sub-millisecond pub/sub** where you need it (agent output streaming, real-time coordination), and **columnar analytics** where you need it (trace queries across millions of spans). Critically, each database handles the access pattern it was designed for — no awkward workarounds.

---

## Why "just use Postgres" works for 80% of The Hive but fatally breaks for the other 20%

The "just use Postgres" movement has strong momentum in 2025–2026: modern hardware means most workloads fit on a single box, and extensions like pgvector, TimescaleDB, and pg_cron cover an expanding surface area. For The Hive, Postgres handles the majority of components well. But two critical findings kill the Postgres-only dream:

**PostgreSQL LISTEN/NOTIFY acquires a global exclusive lock** on the entire instance during COMMIT when a transaction has issued a NOTIFY. Recall.ai discovered this in production — under multi-writer scenarios, CPU and I/O **plummet** because all commits serialize on a global mutex. The payload limit is 8KB, messages are ephemeral (lost if no listener), it doesn't work with connection poolers, and it fails with Neon's scale-to-zero. For The Glass (real-time agent output streaming to 20–30 terminals), this is a dealbreaker. You need Redis Streams.

**Postgres is not an analytics engine.** Langfuse proved this: dashboard queries over trace data were timing out, and IOPS costs on RDS exploded. ClickHouse handles the same queries in milliseconds on a single node. For The Trail (distributed traces) and The Yield (historical metrics), columnar storage isn't optional — it's the difference between sub-second dashboards and 30-second page loads.

Where Postgres genuinely excels for The Hive: **JSONB** for flexible task/agent metadata, **recursive CTEs** for DAG traversal (sub-second on thousands of tasks), **row-level security** for multi-tenant isolation, **pgvector** for agent semantic memory (easily handles <10M vectors with HNSW), and **`SELECT ... FOR UPDATE SKIP LOCKED`** for durable work queues (the pattern Armin Ronacher's "Absurd" workflow engine uses). The "just use Postgres" approach covers six of nine Hive components. The remaining three need purpose-built tools.

---

## Component-by-component database architecture

### The Yard and The Queen share PostgreSQL as their backbone

The Yard (agent registry, heartbeats, fleet status) and The Queen (orchestrator control plane, routing decisions, model selection, budget tracking) are classic OLTP workloads — structured data, frequent reads, moderate writes, relational integrity matters. PostgreSQL handles this trivially.

Agent heartbeats use a `last_seen_at` timestamp column updated via upsert. Fleet status is a simple query over recent heartbeats. The Queen's routing decisions read agent capabilities and budget state in single queries. **Connection pooling via PgBouncer** is essential — it handles **10,000+ client connections** with sub-100μs overhead per query and uses only **2–5 MB RAM** regardless of connection count. For 20–30 agents plus API servers, PgBouncer in transaction mode is the right choice (benchmarked at **6,626 TPS**, a 17× improvement over direct connections).

Multi-tenant workspace isolation uses **shared schema with row-level security**. AWS and Nile both recommend this pattern for SaaS applications: `SET app.current_tenant = $1` at session start, RLS policies filter automatically. One migration path for all tenants, simplified connection pooling, and database-level enforcement that can't be bypassed by a missing WHERE clause.

### The Comb needs PostgreSQL adjacency lists — and optionally Dolt for versioning

The task graph is The Hive's most architecturally interesting persistence challenge. The research reveals a critical insight: **none of the major orchestration systems (Temporal, Airflow, Prefect, Dagster) store DAG edges in a database**. They all define graphs in code and persist only execution state. But The Hive's task graphs are dynamic — created by agents at runtime — so you *do* need to persist the graph structure.

PostgreSQL with an **adjacency list pattern** (tasks table + task_edges table) handles this elegantly. The most critical query for agents — "find all ready tasks" — is a simple anti-join that runs in **sub-millisecond time** on thousands of tasks:

```sql
SELECT t.* FROM tasks t
WHERE t.status = 'open'
AND NOT EXISTS (
    SELECT 1 FROM task_edges e
    JOIN tasks blocker ON e.from_task_id = blocker.id
    WHERE e.to_task_id = t.id AND blocker.status NOT IN ('closed', 'done')
);
```

**Topological sort belongs in application code, not SQL.** A Fusionbox analysis found SQL-based topological sort can be exponential for generic DAGs due to CTE limitations. Kahn's algorithm in TypeScript/Python is O(V+E) and takes microseconds for agent-scale graphs. Recursive CTEs are fine for dependency chain queries (one benchmark showed **<0.1 seconds on 200K rows**), but use them for traversal, not sorting.

**LTREE is wrong for task graphs.** Despite impressive benchmarks (sub-millisecond on 12 million rows), LTREE only supports trees — single-parent hierarchies. Task graphs are DAGs with multiple dependencies per task.

**Graph databases are overkill.** Neo4j's GDS library handles 50K dependencies in 51ms, but the JVM overhead, Enterprise licensing costs, and operational complexity far exceed what's needed for agent-scale task graphs. FalkorDB is interesting (10× faster than Neo4j, 7× less memory), but adding a Redis module for task tracking when PostgreSQL handles the same queries in sub-millisecond time adds unnecessary infrastructure.

**The Dolt option is compelling if you want Beads-style semantics.** Steve Yegge's Beads system proves Dolt works for agent task tracking — reportedly supporting **~160 concurrent agents** on a single host. Dolt's cell-level merge is uniquely valuable: two agents updating different fields of the same task merge cleanly without conflicts. As of December 2025, Dolt has reached **MySQL parity on sysbench** (read/write mean multiplier: 0.99). TPC-C throughput is 40% of MySQL, which is fine for task tracking. The hash-based ID system (4–6 char prefix of SHA-256) prevents merge collisions in multi-branch workflows. However, Dolt is single-node only with a ~100GB dataset limit, doesn't speak Postgres, and has a smaller ecosystem. Use it if you specifically need git-like branching, time-travel queries, and the Beads workflow. Otherwise, PostgreSQL is simpler and more capable.

### The Glass demands Redis Streams + SSE, not database polling

Streaming 20–30 simultaneous agent terminal outputs to a web UI is a real-time pub/sub problem, not a database problem. Redis Streams with the `MAXLEN` trim pattern implements the exact "tail -f with history" semantics The Glass needs:

The pattern works in two steps. First, new subscribers call `XREVRANGE` to get the last N lines instantly. Then they switch to `XREAD BLOCK` for real-time tailing. At **1,000 lines × 200 bytes × 30 agents = ~6MB**, the memory footprint is negligible. Redis handles this without breaking a sweat.

**Server-Sent Events (SSE) beats WebSocket** for agent output streaming. Agent output is unidirectional (server→client), SSE runs over standard HTTP (works through CDNs and corporate firewalls), and it has built-in auto-reconnection with `Last-Event-ID`. OpenAI, Anthropic, and most LLM APIs use SSE for streaming. Use WebSocket only if agents need bidirectional interaction during streaming (cancel, approve, steer).

Replit's Shell2 architecture is the gold standard here: they achieved **200× faster** terminal output by eliminating string-byte conversions, avoiding stdio pipes, and using raw byte passthrough. The key lesson for The Hive: keep the streaming hot path as thin as possible — agent → Redis Stream → SSE endpoint → browser, with zero serialization/deserialization in between.

### The Trail and The Yield converge on ClickHouse for analytics

SigNoz (open-source OTel backend) stores **all telemetry** — traces, metrics, and logs — in ClickHouse, handling **10TB+/day ingestion** at scale. For The Hive, a single ClickHouse node handles the trace and metrics volume of hundreds of agents easily. Langfuse's self-hosted deployments start with a single ClickHouse instance and scale up.

**For The Trail (traces):** Use OpenTelemetry SDK to instrument agents, export to ClickHouse via the OTel collector. Store traces, observations (LLM calls, tool calls), and scores in ClickHouse's `ReplacingMergeTree` engine. This gives you span-level latency, token usage, and cost attribution with columnar query performance.

**For The Yield (metrics/cost):** Two-tier approach. Real-time cost tracking goes through PostgreSQL (ACID matters for billing) with **TimescaleDB** extension for time-series queries. Historical analytics and aggregations go to ClickHouse. The hot-path cost attribution (per-task, per-agent, per-model) stays in Postgres where it can JOIN with agent configs and project data. Dashboards querying "show me cost trends over the last 90 days" hit ClickHouse.

LiteLLM's pattern is instructive here: they use a **Redis buffer** for spend increments to prevent database contention, then a single instance acquires a lock and flushes to PostgreSQL periodically. For The Hive, agent cost events flow through Redis → batch insert to Postgres → periodic ETL to ClickHouse for analytics.

---

## Event sourcing is the right pattern but not at the Kafka scale

The academic case for event sourcing in agent systems is strong. An arxiv paper (ESAA, 2602.23193) validated the pattern with 4 concurrent LLM agents producing 86 events across 8 phases. Temporal is essentially event sourcing per workflow — append-only event histories with state reconstructed by replay. The Akka team argues that agent systems are "fundamentally event-driven" with natural read/write separation (perception/RAG path vs. action/tool-use path).

**For 20–30 agents at 100+ events/hour, the total throughput is ~0.83 events/second.** This is laughably low for any streaming system. Even at 10× burst, it's 8 events/second. The technology choice matters for operational simplicity, not throughput.

**NATS JetStream is the right event backbone** for The Hive if you want a dedicated streaming layer. Single binary (~20MB), sub-millisecond latency, built-in persistence and replay, durable consumer groups. Kafka is massive overkill at this scale ("renting a cargo ship to cross a river" — it needs 3+ brokers minimum, 8+ vCPU per broker). Redis Streams is viable if Redis is already in the stack but lacks JetStream's purpose-built streaming features.

**The pragmatic path: PostgreSQL events table.** At <10 events/second, an append-only `events` table in PostgreSQL with a NOTIFY trigger works fine for event sourcing. Application-side polling (not LISTEN/NOTIFY for the reasons above) or NATS for event distribution. Babysitter's JSONL approach works too at this scale but lacks indexing, concurrent reader optimization, and replication. JSONL append-only can handle **~80,000–100,000 writes/sec on SSD** without fsync, so throughput isn't the issue — it's queryability and operational tooling.

**Temporal's 50K event limit** per workflow execution is the key design constraint to learn from. Long-running agents must use a Continue-As-New pattern: checkpoint state, close the current execution, start fresh with carried-forward state. For The Hive, this means designing agent task executions as bounded units that write their results to the task graph (The Comb) rather than accumulating unbounded event histories.

---

## Agent semantic memory: pgvector wins at this scale, hands down

The vector database comparison reveals that at The Hive's scale (20–30 agents, each with thousands to tens of thousands of memories), **pgvector is the clear winner**. The bottleneck isn't raw vector search speed — it's operational simplicity and integration with relational data.

Benchmarks at 50M vectors show pgvectorscale achieving **471 QPS at 99% recall** — 11.4× better than Qdrant's 41 QPS at the same recall level. Under 10M vectors, pgvector matches or beats every dedicated vector database. At <100K vectors per agent (the realistic ceiling for agent memory), query latency is **<10ms**. You get unified ACID transactions across vectors, conversation history, and agent state in one database.

**sqlite-vec (used by OpenClaw) caps at ~100K vectors** before performance degrades unacceptably. At 1M vectors with 3072 dimensions, queries take **8.52 seconds**. It uses brute-force search only (no HNSW or IVF indexes yet). Fine for per-agent local scratch files during development; not suitable for production.

**The right embedding model is `text-embedding-3-small` at 512–768 dimensions** (via Matryoshka truncation). At **$0.02 per million tokens**, it's the consensus sweet spot. Shopify found 512 dimensions performed identically to 1536 for product search, saving 67% storage and 40% latency. Agent memories are short text — preferences, facts, conversation snippets — and don't need high-dimensional embeddings.

**Hybrid search (BM25 + vector) delivers 15–30% better recall.** One team went from 62% to 84% retrieval precision by adding full-text search plus Reciprocal Rank Fusion to pgvector, with zero additional infrastructure. PostgreSQL's native `tsvector/tsquery` combined with pgvector similarity in a single SQL query gives you hybrid search without Elasticsearch.

**Mastra's memory architecture is the blueprint to copy.** Their four-tier system — message history (raw conversations), working memory (persistent scratchpad), semantic recall (RAG over past messages), and observational memory (LLM-compressed summaries) — solves the unbounded growth problem. The observational memory tier uses a background LLM to compress old messages into dense observations, then discards the raw messages. This is the right compaction pattern for The Hive: periodic consolidation with importance-weighted TTL eviction and a hard per-agent vector budget (e.g., 10K vectors).

---

## Valkey over Redis, Drizzle for migrations, and the storage adapter pattern

**Valkey is the default for new projects in 2026.** After Redis's license change to RSALv2/SSPLv1 (March 2024), Valkey forked under the Linux Foundation with backing from AWS, Google, Oracle, and Snap. Performance benchmarks show Valkey 8.1.1 achieving **37% higher SET throughput and 60% faster p99 GET latency** versus Redis 8.0. AWS ElastiCache automatically migrated to Valkey. The only caveat: Valkey's RedisSearch/RedisJSON equivalents are still maturing. For The Hive's use cases (streams, pub/sub, caching, rate limiting), Valkey is fully compatible with existing Redis clients.

**Drizzle ORM is the right migration tool** for a TypeScript-primary stack. It supports PostgreSQL, SQLite, LibSQL, and Turso natively with a ~7.4KB bundle (versus Prisma's much larger footprint), generates raw SQL migration files, and has **up to 14× lower latency** on complex joins. For serverless/edge deployments, the zero cold-start overhead is critical. Drizzle's convergence with Prisma's patterns (relational API v2) means you get similar DX with better performance.

**The storage adapter pattern (from Mastra) is non-negotiable.** Define a storage interface with five domains: messages, threads, agents/resources, workflows, and traces. Implement per-backend adapters (LibSQLStore, PostgresStore). Mastra's `MastraCompositeStore` enables per-domain routing — memory to LibSQL for development, workflows to PostgreSQL for production, observability to ClickHouse. This is how The Hive should be built: **abstract storage behind interfaces from day one**, swap backends without rewriting business logic.

The migration path is: start with LibSQL/SQLite for development (zero-config), PostgreSQL for early production, then add Valkey and ClickHouse when streaming and analytics demands justify the operational overhead. Drizzle supports both SQLite and Postgres with identical schema definitions, making the switch a connection string change plus `drizzle-kit push`.

---

## The final architecture map

Here is the concrete recommendation for each Hive component, with rationale:

| Component | Database | Why |
|---|---|---|
| **The Yard** (agent registry) | PostgreSQL | Structured data, heartbeat upserts, fleet queries. RLS for multi-tenant. |
| **The Glass** (streaming output) | Valkey Streams + SSE | Real-time unidirectional streaming. `XADD MAXLEN ~1000` for ring buffer. History via `XREVRANGE`. |
| **The Comb** (task graph) | PostgreSQL adjacency list (or Dolt) | Tasks + task_edges tables, recursive CTEs for traversal, topological sort in app code. Dolt if you need git-style versioning. |
| **The Waggle** (skill registry) | PostgreSQL + JSONB | Skill metadata in JSONB, SHA-256 hash column for change detection, security scan results as structured data. |
| **The Keeper** (approvals) | PostgreSQL | Approval queues via `SELECT ... FOR UPDATE SKIP LOCKED`, audit log as append-only table, blocking gates as row-level state. |
| **The Smoker** (CLI bridge) | Valkey pub/sub | Command dispatch and output routing. Ephemeral by nature — no persistence needed. |
| **The Trail** (traces) | ClickHouse | `ReplacingMergeTree` for traces/spans. OTel collector → ClickHouse. SigNoz pattern. |
| **The Yield** (metrics) | PostgreSQL + TimescaleDB (real-time) / ClickHouse (historical) | ACID for billing, TimescaleDB for time-series queries, ClickHouse for 90-day trend dashboards. |
| **The Queen** (orchestrator) | PostgreSQL + Valkey cache | Routing decisions read from Postgres, hot-path budget state cached in Valkey with write-behind to Postgres. |

This architecture uses **three databases** (PostgreSQL, Valkey, ClickHouse), optionally four with Dolt, covering all nine components. Total infrastructure: one Postgres instance with pgvector + TimescaleDB extensions, one Valkey instance, one ClickHouse node. On a single mid-range server (8 vCPU, 32GB RAM), this handles 200+ concurrent agents before you need to think about horizontal scaling — well beyond the 20–30 agent near-term target and the hundreds-of-agents long-term goal.

---

## Conclusion: what the research actually decided

The research eliminated several attractive-sounding options. Graph databases are overkill for agent task graphs (PostgreSQL anti-joins are sub-millisecond). Kafka is overkill for event sourcing at <10 events/second. PostgreSQL LISTEN/NOTIFY is broken for real-time streaming (global lock). sqlite-vec is limited to ~100K vectors. SQLite's single-writer ceiling is a hard blocker for 20–30 concurrent agents.

What survived scrutiny: **PostgreSQL as the gravity well** that pulls in six of nine components, **Valkey as the real-time coordination layer** handling streaming and ephemeral state, and **ClickHouse as the analytical engine** for traces and historical metrics. This is not "it depends" — it's a concrete, production-validated architecture that Langfuse, LangSmith, SigNoz, and LiteLLM have all converged on independently. The Hive should build on what the industry has already proven works, with Mastra's storage adapter pattern ensuring the flexibility to swap any component as requirements evolve.

The one genuinely novel architectural choice in this stack is **Dolt for The Comb**. Beads proves it works at 160+ concurrent agents with cell-level merge eliminating conflicts when agents update different fields of the same task. No other database offers git-style branching, time-travel queries, and content-addressed storage in a MySQL-compatible package. If The Hive's task graph needs version control semantics (branch-per-agent-experiment, diff between graph states, push/pull to remotes), Dolt is the only real option. If it just needs a fast, reliable DAG store, PostgreSQL is simpler and more capable for everything else.

Build the storage adapter layer first. Start with PostgreSQL + Valkey. Add ClickHouse when you have enough trace data to justify it. Add Dolt when you need Beads-style semantics. The architecture grows with the system — and every addition has a clear, defensible trigger.