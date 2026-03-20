# Deployment architecture and DevOps for The Hive

**The Hive's deployment architecture solves a problem most AI agent frameworks never address: growing from a laptop to production Kubernetes without rewriting infrastructure.** This report provides the complete, battle-tested blueprint for deploying 20–30 parallel AI worker agents across three deployment tiers, with concrete YAML for every component and production-proven patterns drawn from KEDA's CNCF graduation ecosystem, ArgoCD v3.3, and the real-world experience of companies like Microsoft, Google Cloud, and Red Hat running LLM workloads at scale. The critical insight underpinning the entire architecture is that **LLM agent workloads are fundamentally I/O-bound** — workers spend 30–120 seconds waiting on API responses while CPU sits at 1–6% — which breaks every assumption traditional Kubernetes autoscaling makes.

---

## 1. The three-tier deployment model and when to migrate

The Hive follows a progressive deployment model where the Docker Compose service definitions remain the canonical source of truth across all three tiers. What changes between tiers is orchestration, persistence guarantees, and scaling capability — not application architecture.

**Tier 1: Local development** runs the full stack on Docker Compose with `docker compose watch` for hot-reload, ephemeral volumes, and all services on a single machine. This tier optimizes for iteration speed. Developers can spin up the entire Hive — Queen orchestrator, worker agents, PostgreSQL with pgvector, Valkey, ClickHouse, LiteLLM proxy, and the Next.js UI — in under 60 seconds.

**Tier 2: Single-node VPS production** uses the same Docker Compose definitions but adds persistent named volumes, file-based secrets via the `_FILE` convention, proper health checks with `depends_on: condition: service_healthy`, and backup automation. A single VPS with 8–16 vCPUs and 32–64 GB RAM handles 20–30 concurrent agents comfortably because the workload is I/O-bound. Most open-source agent management tools — including frameworks like Mission Control — never escape Tier 2 because they lack the architectural separation between orchestration and execution that enables horizontal scaling.

**Tier 3: Distributed Kubernetes** deploys The Hive across namespaced pods with KEDA event-driven autoscaling, ArgoCD GitOps, and proper secrets management. The Queen service, microservices, and worker agents run as independently scalable deployments. This tier becomes necessary when task queue depth consistently exceeds single-node capacity, when you need zero-downtime deployments during active agent runs, or when cost optimization requires scaling workers to zero during idle periods.

The migration signals are concrete: **move from Tier 1 to Tier 2** when you need persistent data between restarts, real API keys, and always-on availability. **Move from Tier 2 to Tier 3** when queue depth regularly exceeds what 20–30 workers on a single node can drain within your latency SLA, when you need automatic scaling during traffic spikes, or when VPS memory pressure causes OOMKilled workers. The Hive's design — stateless workers pulling from a Valkey task queue, all state in PostgreSQL and ClickHouse — means the Tier 2→3 migration requires zero application code changes. Only infrastructure manifests change.

What stays the same across all three tiers: the Fastify microservice interfaces, the Valkey event bus protocol, the PostgreSQL schema, the LiteLLM proxy configuration, and the health check endpoints. What changes: orchestration (Compose → Kubernetes), secrets (files → Sealed Secrets/ESO), scaling (manual → KEDA), and networking (Docker networks → Kubernetes NetworkPolicies).

---

## 2. The complete Docker Compose architecture

The production-quality `compose.yaml` for The Hive organizes 12+ services across five isolated networks with health-checked dependencies, file-based secrets, and profiles for selective startup.

### Service definitions and network segmentation

Docker Compose networks enforce the principle of least privilege at the network layer. Services only join networks they need, and the `internal: true` flag blocks internet access for data-tier services.

```yaml
networks:
  frontend:
    driver: bridge
  orchestration:
    driver: bridge
  data:
    driver: bridge
    internal: true
  llm:
    driver: bridge
  monitoring:
    driver: bridge
    internal: true

secrets:
  postgres_password:
    file: ./secrets/postgres_password.txt
  anthropic_key:
    file: ./secrets/anthropic_key.txt
  openai_key:
    file: ./secrets/openai_key.txt
  litellm_master_key:
    file: ./secrets/litellm_master_key.txt
  clickhouse_password:
    file: ./secrets/clickhouse_password.txt

volumes:
  pgdata:
  valkeydata:
  clickhouse_data:
  grafana_data:
  prometheus_data:

services:
  # === DATA TIER ===
  postgres:
    image: pgvector/pgvector:pg17
    environment:
      POSTGRES_USER: hive
      POSTGRES_DB: hive
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
    secrets:
      - postgres_password
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks: [data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      retries: 5
      start_period: 30s
      timeout: 10s

  valkey:
    image: valkey/valkey:8-alpine
    volumes:
      - valkeydata:/data
    networks: [data, orchestration]
    healthcheck:
      test: ["CMD", "valkey-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3

  clickhouse:
    image: clickhouse/clickhouse-server:25.3
    environment:
      CLICKHOUSE_USER: hive
      CLICKHOUSE_PASSWORD_FILE: /run/secrets/clickhouse_password
    secrets:
      - clickhouse_password
    volumes:
      - clickhouse_data:/var/lib/clickhouse
    networks: [data, monitoring]
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://0.0.0.0:8123/ping"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  # === LLM TIER ===
  litellm:
    image: ghcr.io/berriai/litellm:main-stable
    volumes:
      - ./litellm-config.yaml:/app/config.yaml:ro
    environment:
      ANTHROPIC_API_KEY_FILE: /run/secrets/anthropic_key
      OPENAI_API_KEY_FILE: /run/secrets/openai_key
      LITELLM_MASTER_KEY_FILE: /run/secrets/litellm_master_key
    secrets:
      - anthropic_key
      - openai_key
      - litellm_master_key
    command: ["--config=/app/config.yaml", "--port", "4000"]
    networks: [llm, monitoring]
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:4000/health/liveliness || exit 1"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 10s

  # === ORCHESTRATION TIER ===
  queen:
    build:
      context: ./services/queen
      target: production
    depends_on:
      postgres:
        condition: service_healthy
      valkey:
        condition: service_healthy
      litellm:
        condition: service_healthy
    environment:
      DATABASE_URL_FILE: /run/secrets/postgres_password
      VALKEY_URL: redis://valkey:6379
      LITELLM_BASE_URL: http://litellm:4000/v1
      NODE_ENV: production
    secrets:
      - postgres_password
      - litellm_master_key
    networks: [frontend, orchestration, data, llm]
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3001/health"]
      interval: 15s
      timeout: 5s
      retries: 3

  worker:
    build:
      context: ./services/worker
      target: production
    depends_on:
      queen:
        condition: service_healthy
      valkey:
        condition: service_healthy
    deploy:
      replicas: 4
    environment:
      VALKEY_URL: redis://valkey:6379
      QUEEN_API_URL: http://queen:3001
      LITELLM_BASE_URL: http://litellm:4000/v1
    secrets:
      - litellm_master_key
    networks: [orchestration, llm]
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3002/health"]
      interval: 15s
      timeout: 5s
      retries: 3

  # === FRONTEND TIER ===
  ui:
    build:
      context: ./services/ui
      target: production
    depends_on:
      queen:
        condition: service_healthy
    ports:
      - "3000:3000"
    networks: [frontend]
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 5s
      retries: 3

  # === OBSERVABILITY (profile-gated) ===
  prometheus:
    image: prom/prometheus:v3.3.0
    profiles: [monitoring, full]
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    networks: [monitoring, orchestration, llm]

  grafana:
    image: grafana/grafana:11.6.0
    profiles: [monitoring, full]
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3030:3000"
    networks: [monitoring]

  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.147.0
    profiles: [monitoring, full]
    volumes:
      - ./otel-config.yaml:/etc/otelcol-contrib/config.yaml:ro
    networks: [monitoring, orchestration, llm]

  langfuse:
    image: langfuse/langfuse:latest
    profiles: [monitoring, full]
    depends_on:
      postgres:
        condition: service_healthy
      clickhouse:
        condition: service_healthy
    environment:
      DATABASE_URL: postgresql://hive:password@postgres:5432/langfuse
      CLICKHOUSE_URL: http://clickhouse:8123
    networks: [monitoring, data]
```

### Why `_FILE` secrets prevent exposure that plain env vars cannot

Environment variables set in `compose.yaml` are visible in four dangerous places: `docker inspect` output shows every env var in plaintext, the Linux `/proc/[pid]/environ` file exposes them to any process with read access, application error handlers and stack traces routinely dump the environment, and CI/CD pipeline logs can capture them. Docker's official documentation states explicitly: *"Environment variables are often available to all processes, and it can be difficult to track access."*

The `_FILE` convention solves this by mounting secrets as files in a tmpfs filesystem at `/run/secrets/`. The secret value never enters the environment variable namespace. Official Docker images for PostgreSQL, MySQL, and MariaDB support this natively — when the entrypoint sees `POSTGRES_PASSWORD_FILE`, it reads the file contents at startup and uses the value internally without ever exposing it as an environment variable. For custom services like The Hive's Fastify microservices, reading from `/run/secrets/` requires a small utility function:

```typescript
import { readFileSync } from 'fs';

function resolveSecret(envVar: string): string {
  const fileVar = process.env[`${envVar}_FILE`];
  if (fileVar) return readFileSync(fileVar, 'utf-8').trim();
  return process.env[envVar] ?? '';
}

const apiKey = resolveSecret('ANTHROPIC_API_KEY');
```

### Multi-stage Dockerfile for TypeScript microservices

The three-stage build pattern separates dependency installation, TypeScript compilation, and production runtime into isolated layers:

```dockerfile
# Stage 1: Production dependencies only
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Stage 2: Build TypeScript
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# Stage 3: Production image
FROM node:22-alpine AS production
ENV NODE_ENV=production
WORKDIR /app
RUN addgroup -g 1001 -S hive && adduser -S hive -u 1001 -G hive
COPY --from=deps --chown=hive:hive /app/node_modules ./node_modules
COPY --from=build --chown=hive:hive /app/dist ./dist
COPY --chown=hive:hive package.json ./
USER hive
EXPOSE 3000
CMD ["node", "dist/index.js"]
```

**Critical details**: use `npm ci` (not `npm install`) for deterministic builds. The `--omit=dev` flag (replacing deprecated `--only=production`) excludes devDependencies from the production image. Run as a non-root user. Use `CMD ["node", ...]` directly — never wrap with npm or nodemon in production, as this breaks SIGTERM signal handling required for graceful shutdown in Kubernetes.

### Docker Compose profiles and watch for development

Profiles gate optional services behind activation flags. Core services (postgres, valkey, queen, worker, ui) have no `profiles` attribute and always start. Monitoring services declare `profiles: [monitoring, full]` and only start when explicitly activated:

```bash
# Core services only
docker compose up

# Core + monitoring
docker compose --profile monitoring up

# Everything
docker compose --profile full up

# Via environment
COMPOSE_PROFILES=monitoring,debug docker compose up
```

The `docker compose watch` feature (GA since Compose v2.22.0) replaces fragile bind-mount-based hot-reload with a purpose-built file synchronization system. Three actions control behavior: `sync` copies changed files into the running container, `rebuild` triggers a full image rebuild, and `sync+restart` syncs then restarts the container process.

```yaml
services:
  queen:
    build:
      context: ./services/queen
      target: development
    develop:
      watch:
        - action: sync
          path: ./services/queen/src
          target: /app/src
          ignore:
            - "**/*.test.ts"
            - node_modules/
        - action: rebuild
          path: ./services/queen/package.json
        - action: sync+restart
          path: ./services/queen/config
          target: /app/config
```

---

## 3. Why CPU autoscaling is blind to LLM agent load and how KEDA fixes it

The fundamental mismatch between Kubernetes HPA and LLM agent workloads is well-documented across every major cloud provider. **An LLM agent worker spends 95%+ of its time blocked on network I/O** — waiting for Claude, GPT-4, or other providers to return completions that take 30–120 seconds per call. During this wait, CPU utilization sits at **1–6%** even when the task queue contains 200 pending items. The HPA, which scales on CPU utilization by default, sees an idle cluster and refuses to add capacity.

Red Hat's developer documentation states directly: *"The unpredictable nature of AI workloads, where traffic can spike dramatically, often means that traditional autoscaling methods fall short. Relying solely on CPU or memory usage can lead to either overprovisioning and wasted resources, or underprovisioning and poor user experience."* The CNCF's KServe v0.15 announcement in June 2025 echoed this: *"Traditional Horizontal Pod Autoscaler metrics fall short when dealing with the variable nature of generative workloads."* Google Cloud publishes dedicated tutorials for using KEDA with LLM workloads on GKE, explicitly recommending scale-to-zero with KEDA for GPU-intensive AI workloads to manage costs. Microsoft built a purpose-built `keda-kaito-scaler` for vLLM inference autoscaling on AKS, defaulting to `vllm:num_requests_waiting` as the scaling metric — queue depth, not CPU.

### KEDA: event-driven scaling that understands queue depth

KEDA (Kubernetes Event-Driven Autoscaling) is a **CNCF Graduated project** — the same maturity level as Kubernetes itself — with 45+ production end-users including Alibaba Cloud, Microsoft, Red Hat, Cisco, FedEx, Reddit, and Zapier. The current stable release is **v2.19** (January 2026). KEDA extends the standard HPA with 60+ event source scalers that can trigger scaling from Redis queue depth, Prometheus metrics, Kafka consumer lag, AWS SQS, and dozens of other sources.

The critical capability for The Hive: KEDA can **scale to zero replicas**, unlike standard HPA which requires a minimum of 1. When `minReplicaCount: 0`, KEDA monitors triggers independently and scales from 0→1 when the first task arrives. For production Hive deployments, setting `minReplicaCount: 2` avoids cold-start latency while keeping costs manageable.

### Complete KEDA ScaledObject for Hive workers

```yaml
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: valkey-auth
  namespace: hive-workers
spec:
  secretTargetRef:
    - parameter: password
      name: hive-valkey-secret
      key: password
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: hive-worker-scaler
  namespace: hive-workers
spec:
  scaleTargetRef:
    name: hive-worker
    kind: Deployment
    apiVersion: apps/v1
  pollingInterval: 15
  cooldownPeriod: 300
  minReplicaCount: 2
  maxReplicaCount: 20
  fallback:
    failureThreshold: 3
    replicas: 4
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          stabilizationWindowSeconds: 120
          policies:
            - type: Percent
              value: 25
              periodSeconds: 60
        scaleUp:
          stabilizationWindowSeconds: 0
          policies:
            - type: Percent
              value: 100
              periodSeconds: 15
  triggers:
    # Primary: scale on Valkey task queue depth
    - type: redis
      metadata:
        address: valkey.hive-data.svc.cluster.local:6379
        listName: hive:task_queue
        listLength: "5"
        activationListLength: "1"
        databaseIndex: "0"
      authenticationRef:
        name: valkey-auth
    # Secondary: scale on p95 task duration exceeding 60s
    - type: prometheus
      metadata:
        serverAddress: http://prometheus.hive-observability.svc:9090
        metricName: hive_task_duration_p95
        threshold: "60"
        query: |
          histogram_quantile(0.95,
            sum(rate(hive_task_duration_seconds_bucket{service="worker"}[5m]))
            by (le))
```

KEDA's multi-trigger system uses **OR logic**: scaling activates when *any* trigger meets its threshold. The primary Redis trigger scales proactively as work queues — one additional replica per 5 pending tasks. The secondary Prometheus trigger catches situations where queue depth is low but individual tasks are running slowly (indicating a degraded LLM provider), triggering scale-up even at moderate queue depths. The `activationListLength: "1"` ensures scaling from `minReplicaCount` activates as soon as a single task enters the queue. The `fallback` block ensures that if KEDA loses contact with Valkey, it falls back to 4 replicas rather than scaling to zero.

### terminationGracePeriodSeconds and resource sizing

The default Kubernetes termination grace period is **30 seconds**. An LLM API call routinely takes 30–120 seconds. Without extending the grace period, Kubernetes sends SIGKILL to pods mid-API-call during scale-down events, cluster upgrades, or rolling deployments — wasting the tokens already consumed and requiring full task retry.

For LLM agent workers, **`terminationGracePeriodSeconds: 120`** is the minimum safe value. The worker's SIGTERM handler should immediately stop pulling new tasks from the queue and allow the current API call to complete before exiting.

Resource requests for I/O-bound agent pods should be **low CPU, moderate-to-high memory**:

```yaml
resources:
  requests:
    cpu: "250m"      # I/O-bound: CPU mostly idle during API waits
    memory: "512Mi"  # Context assembly, JSON parsing, response buffering
  limits:
    cpu: "500m"      # Allow burst for token counting, context window assembly
    memory: "2Gi"    # Large context windows can consume significant memory
```

Setting CPU requests too high wastes cluster resources because the CPU is unused during API waits. Setting memory limits too low risks OOMKilled when agents process large context windows or multiple concurrent tool-use chains.

### Karpenter provisions the right node at the right time

For Tier 3 deployments on AWS, **Karpenter** provisions nodes in approximately 55 seconds by calling EC2 APIs directly, compared to 3–4 minutes for Cluster Autoscaler which works through Auto Scaling Groups. Karpenter evaluates pending pod requirements and dynamically selects the optimal instance type — no predefined node groups required. For The Hive's heterogeneous workload (lightweight API pods alongside memory-hungry worker pods), Karpenter's bin-packing algorithm consolidates workloads efficiently, with teams reporting **20–30% cluster cost reductions**. On GKE, Autopilot provides equivalent just-in-time provisioning natively.

---

## 4. Secrets management from Docker Compose to production Kubernetes

The progression from development to production secrets follows a clear decision tree: Docker Compose `_FILE` secrets → Sealed Secrets for early Kubernetes adoption → External Secrets Operator for multi-environment management.

### Docker Compose: the _FILE convention

At Tier 1 and Tier 2, secrets are stored as individual files in a `./secrets/` directory (gitignored) and mounted into containers via the Compose `secrets` top-level element. Services access them at `/run/secrets/<name>` — a tmpfs mount that never touches disk. The complete pattern is shown in the Compose architecture above.

**Hard rule**: never put LLM API keys as plaintext environment variables in any manifest, Compose file, or Kubernetes YAML. A single `docker inspect` command exposes every env var. The `/proc/[pid]/environ` file on the host exposes them to any process with read access. Application crash handlers, debug middleware, and error tracking services routinely dump environment variables into logs.

### Sealed Secrets: encrypted GitOps for small teams

Bitnami's Sealed Secrets (v0.36.0, ~9k GitHub stars, Apache 2.0 license) uses asymmetric encryption so that only the cluster's controller can decrypt secrets. The `kubeseal` CLI encrypts a standard Kubernetes Secret into a `SealedSecret` CRD that is **safe to commit to Git**, even public repositories:

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: hive-api-keys
  namespace: hive-services
spec:
  encryptedData:
    anthropic-api-key: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEq.....
    openai-api-key: AgCF8nK2PLWJ+RjUYZAB7sP54dGFDr.....
```

The controller decrypts this into a native Kubernetes Secret at runtime. **Limitations**: no dynamic secret generation, manual rotation of actual secret values (sealing keys rotate automatically), and secrets are tied to a specific cluster's key pair.

### External Secrets Operator: multi-backend synchronization

The External Secrets Operator (ESO, Helm chart v2.1.0, CNCF project) synchronizes secrets from external providers into native Kubernetes Secrets via CRDs. It supports **20+ backends** including AWS Secrets Manager, GCP Secret Manager, Azure Key Vault, HashiCorp Vault, 1Password, and Doppler:

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secrets
  namespace: hive-services
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: hive-eso-sa
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: hive-llm-keys
  namespace: hive-services
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: hive-api-keys
    creationPolicy: Owner
  data:
    - secretKey: anthropic-api-key
      remoteRef:
        key: hive/production/anthropic
    - secretKey: openai-api-key
      remoteRef:
        key: hive/production/openai
```

The `refreshInterval: 1h` field means ESO re-fetches secrets hourly, automatically picking up rotations made in the upstream provider.

### Vault and the BSL license consideration

HashiCorp changed Vault's license from MPL 2.0 to BSL 1.1 on **August 10, 2023**, restricting competitive commercial use. **OpenBao** (v2.5.1, ~5.6k GitHub stars, MPL 2.0 license, Linux Foundation governance) is the community fork from Vault's last open-source commit. For enterprise teams needing dynamic credential generation, PKI, and comprehensive audit logging, Vault (or OpenBao) remains the most capable option.

The **Vault Secrets Operator (VSO)** is the preferred Kubernetes integration over the older Agent Injector and CSI Provider. VSO operates at the cluster level with CRD-based connections — not per-pod sidecars — resulting in the **lowest Vault load and resource consumption**. Uniquely, VSO triggers **automatic deployment rollouts when secrets change** and exposes **Prometheus metrics** for observability. The Agent Injector creates a sidecar container in every pod, multiplying Vault connections linearly with pod count. The CSI Provider runs as a DaemonSet, which is better than per-pod but still creates per-node connections.

### The recommended progression for The Hive

Start with Docker Compose `_FILE` secrets at Tier 1–2. When migrating to Kubernetes, adopt **Sealed Secrets** for simplicity — they require zero external dependencies and fit naturally into GitOps workflows. When managing secrets across multiple environments (dev, staging, production) or when secrets live in a cloud provider's secrets manager, adopt **ESO**. Add Vault/OpenBao only when you need dynamic database credentials, automated PKI certificate issuance, or compliance audit trails.

In all Kubernetes environments, reference secrets using `secretKeyRef`, never hardcoded values:

```yaml
env:
  - name: ANTHROPIC_API_KEY
    valueFrom:
      secretKeyRef:
        name: hive-api-keys
        key: anthropic-api-key
```

---

## 5. Kubernetes architecture for Tier 3 production

### Namespace strategy and isolation boundaries

The Hive's Kubernetes deployment uses four namespaces that enforce security boundaries, independent scaling, and resource governance:

- **`hive-system`**: Queen orchestrator, HiveMind service, core infrastructure
- **`hive-services`**: Trail (logging), Yield (output), API gateway — stateless microservices
- **`hive-workers`**: KEDA-scaled worker pods — the only namespace that auto-scales
- **`hive-observability`**: Prometheus, Grafana, Langfuse, OTel Collector

Namespace isolation matters because RBAC permissions are namespace-scoped. Workers in `hive-workers` should have ServiceAccounts with minimal permissions — they cannot access PostgreSQL directly and communicate exclusively through the Queen's API. KEDA scales only the `hive-workers` namespace, preventing autoscaling events from affecting system services. ResourceQuotas per namespace prevent runaway workers from starving the Queen.

**Critical caveat**: namespaces do not provide network isolation by default. Without NetworkPolicies, pods in `hive-workers` can freely reach pods in `hive-system`. A CNI that supports NetworkPolicies (Calico or Cilium — not Flannel) is required.

### Choosing a Kubernetes distribution

**K3s** (current LTS: v1.32.13+k3s1) is the right choice for self-hosted Tier 3 deployments. It runs all control plane components in a single process, requiring **less than 512 MB RAM** — dramatically lighter than full K8s. It bundles Traefik as the default ingress controller, Flannel for CNI (swap to Calico for NetworkPolicy support with `--flannel-backend=none`), CoreDNS, and a local storage provisioner. K3s is CNCF-certified and fully Kubernetes API-compatible. Installation is a single command: `curl -sfL https://get.k3s.io | sh -`.

**GKE Autopilot** is the best managed option for Google Cloud-first teams. Google manages all nodes, billing is pod-based (you pay for what pods request), and it integrates natively with Google Secret Manager via the Secrets Store CSI Driver. **EKS** on AWS offers managed node groups, IAM Roles for Service Accounts (IRSA), and native KEDA support via the SQS scaler. Both managed options eliminate node management overhead at the cost of reduced control.

### Complete worker Deployment with three-probe health checking

The three-probe pattern separates concerns: the **startup probe** gives slow-starting workers time to initialize (up to 300 seconds), the **liveness probe** detects deadlocked processes and triggers restarts, and the **readiness probe** controls traffic routing by verifying external dependencies.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hive-worker
  namespace: hive-workers
spec:
  selector:
    matchLabels:
      app: hive-worker
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: hive-worker
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "3002"
        prometheus.io/path: "/metrics"
    spec:
      terminationGracePeriodSeconds: 120
      containers:
        - name: worker
          image: ghcr.io/the-hive/worker:v1.0.0
          ports:
            - containerPort: 3002
              name: http
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "500m"
              memory: "2Gi"
          env:
            - name: ANTHROPIC_API_KEY
              valueFrom:
                secretKeyRef:
                  name: hive-api-keys
                  key: anthropic-api-key
            - name: VALKEY_URL
              value: "redis://valkey.hive-data.svc.cluster.local:6379"
            - name: QUEEN_API_URL
              value: "http://queen.hive-system.svc.cluster.local:3001"
            - name: LITELLM_BASE_URL
              value: "http://litellm.hive-system.svc.cluster.local:4000/v1"
            - name: NODE_ENV
              value: "production"
          startupProbe:
            httpGet:
              path: /health
              port: 3002
            periodSeconds: 10
            failureThreshold: 30
          livenessProbe:
            httpGet:
              path: /health
              port: 3002
            periodSeconds: 15
            timeoutSeconds: 3
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /ready
              port: 3002
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
```

The `/health` endpoint returns 200 if the process is alive. The `/ready` endpoint performs deeper checks: is the Valkey connection live, is the LLM provider reachable (a lightweight HEAD request to the LiteLLM proxy), and does the agent's context window budget have remaining capacity. When `/ready` fails, Kubernetes removes the pod from the Service's endpoints — it stops receiving new tasks but is not restarted.

The `maxSurge: 1, maxUnavailable: 0` rolling update strategy ensures a new worker pod is fully Ready before any existing pod is terminated. Combined with `terminationGracePeriodSeconds: 120`, this guarantees zero task loss during deployments.

### PodDisruptionBudgets and NetworkPolicies

PDBs prevent cluster maintenance from disrupting too many workers simultaneously:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: hive-worker-pdb
  namespace: hive-workers
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: hive-worker
```

NetworkPolicies implement deny-all-then-allow. After applying a default deny, **always add a DNS allow policy** — without it, pods cannot resolve service names:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: hive-workers
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: hive-workers
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-worker-egress
  namespace: hive-workers
spec:
  podSelector:
    matchLabels:
      app: hive-worker
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: hive-system
      ports:
        - protocol: TCP
          port: 3001
        - protocol: TCP
          port: 4000
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: hive-data
      ports:
        - protocol: TCP
          port: 6379
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except: [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16]
      ports:
        - protocol: TCP
          port: 443
```

This policy allows workers to reach the Queen API (port 3001), LiteLLM proxy (port 4000), Valkey (port 6379), and external HTTPS endpoints (LLM provider APIs) — nothing else. Workers cannot reach PostgreSQL directly.

### Resource quotas as cost guardrails

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: hive-workers-quota
  namespace: hive-workers
spec:
  hard:
    requests.cpu: "8"
    requests.memory: "32Gi"
    limits.cpu: "16"
    limits.memory: "64Gi"
    pods: "30"
```

Combined with KEDA's `maxReplicaCount: 20` and LiteLLM's budget caps, this creates a three-layer cost ceiling: KEDA caps the pod count, ResourceQuota caps total resource consumption, and LiteLLM caps LLM API spend.

---

## 6. CI/CD pipeline from push to production

The Hive's deployment pipeline follows a GitOps model: application code and infrastructure manifests live in separate repositories. GitHub Actions builds and pushes images, then updates Kustomize overlays in the manifests repo. ArgoCD (v3.3.3, released March 2026) detects the Git change and syncs to the cluster.

### GitHub Actions: parallel multi-service builds

```yaml
name: Build and Deploy
on:
  push:
    branches: [main]

env:
  REGISTRY: ghcr.io

permissions:
  contents: read
  packages: write
  id-token: write

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: npm ci
      - run: npm test

  build:
    needs: test
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        service: [queen, worker, hivemind, trail, yield, ui]
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v7
        with:
          context: ./services/${{ matrix.service }}
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/${{ matrix.service }}:${{ github.sha }}
            ghcr.io/${{ github.repository_owner }}/${{ matrix.service }}:latest
          cache-from: type=gha,scope=${{ matrix.service }}
          cache-to: type=gha,scope=${{ matrix.service }},mode=max

  update-manifests:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: the-hive/k8s-manifests
          token: ${{ secrets.DEPLOY_TOKEN }}
      - name: Update image tags via Kustomize
        run: |
          TAG=${{ github.sha }}
          cd overlays/production
          for svc in queen worker hivemind trail yield ui; do
            kustomize edit set image \
              ghcr.io/the-hive/${svc}=ghcr.io/the-hive/${svc}:${TAG}
          done
      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .
          git commit -m "deploy: ${GITHUB_SHA::7}"
          git push

  smoke-test:
    needs: update-manifests
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Wait for ArgoCD sync and verify
        run: |
          argocd login ${{ secrets.ARGOCD_SERVER }} \
            --auth-token ${{ secrets.ARGOCD_TOKEN }} --grpc-web
          argocd app sync hive-production --grpc-web
          argocd app wait hive-production --timeout 300 --grpc-web
      - name: Smoke test
        run: |
          kubectl rollout status deployment/hive-worker \
            -n hive-workers --timeout=180s
          kubectl run smoke-test --rm -i --restart=Never \
            --image=curlimages/curl -- \
            curl -sf --retry 5 --retry-delay 10 \
            http://queen.hive-system.svc:3001/health
```

The `cache-from: type=gha,scope=${{ matrix.service }}` and `cache-to: type=gha,mode=max` configuration uses GitHub Actions' built-in cache (10 GB per repo with LRU eviction). The `scope` parameter prevents cache collisions between services. The `mode=max` setting caches all intermediate layers, not just the final image layers — critical for multi-stage TypeScript builds where the `npm ci` layer rarely changes.

### Kustomize overlays for environment management

```
k8s-manifests/
├── base/
│   ├── kustomization.yaml
│   ├── queen-deployment.yaml
│   ├── worker-deployment.yaml
│   ├── services.yaml
│   └── configmap.yaml
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml
    │   └── resource-patch.yaml
    ├── staging/
    │   └── kustomization.yaml
    └── production/
        ├── kustomization.yaml
        ├── keda-scaledobject.yaml
        └── network-policies.yaml
```

```yaml
# overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
  - keda-scaledobject.yaml
  - network-policies.yaml
namespace: hive-system
images:
  - name: ghcr.io/the-hive/queen
    newTag: latest
  - name: ghcr.io/the-hive/worker
    newTag: latest
patches:
  - path: resource-patch.yaml
```

### ArgoCD and the KEDA replica count conflict

When KEDA scales workers from 2 to 12, ArgoCD sees the live cluster diverging from the Git manifests and marks the application as "OutOfSync." With `selfHeal: true`, ArgoCD would force replicas back to the Git-specified value, creating an infinite scaling war.

**The correct solution**: use `ignoreDifferences` with `RespectIgnoreDifferences=true` in the ArgoCD Application spec:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hive-production
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/the-hive/k8s-manifests.git
    targetRevision: main
    path: overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: hive-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - RespectIgnoreDifferences=true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```

The `RespectIgnoreDifferences=true` sync option is **essential**. Without it, ArgoCD ignores the difference for display purposes but still overwrites replicas during sync. With it enabled, ArgoCD strips `/spec/replicas` from the manifest before applying, preserving KEDA's scaling decisions. An even cleaner approach: omit `spec.replicas` from the Deployment manifest entirely, letting KEDA own the replica count from initial deployment.

For Kubernetes imagePullSecrets to access ghcr.io from the cluster:

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<github-user> \
  --docker-password=<PAT-with-read:packages> \
  -n hive-workers
```

---

## 7. Observability stack from traces to LLM cost dashboards

### OpenTelemetry Collector as the telemetry hub

The OTel Collector (v0.147.0-contrib) receives traces and metrics from all Hive services via OTLP, processes them, and routes to appropriate backends:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    send_batch_size: 8192
    timeout: 10s
  memory_limiter:
    check_interval: 1s
    limit_mib: 1500
    spike_limit_mib: 300

exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"
    namespace: "hive"
    send_timestamps: true
    metric_expiration: 5m
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true
  otlp/langfuse:
    endpoint: langfuse:4318
    tls:
      insecure: true

extensions:
  health_check:
    endpoint: 0.0.0.0:13133

service:
  extensions: [health_check]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/tempo, otlp/langfuse]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheus]
```

### Langfuse: now ClickHouse-native after the January 2026 acquisition

**ClickHouse acquired Langfuse on January 16, 2026**, announced alongside ClickHouse's $400M Series D at a $15B valuation. Langfuse remains 100% open-source under the MIT license. The acquisition is significant for The Hive because Langfuse v3 already uses ClickHouse as its core analytical data store — meaning a self-hosted Hive deployment can share the same ClickHouse instance for both application analytics and LLM observability. PostgreSQL is still used by Langfuse for transactional data. With over **20k GitHub stars** and **26M+ SDK installs per month**, Langfuse is the dominant open-source LLM observability platform.

### LiteLLM Prometheus metrics for cost control

LiteLLM exposes metrics at `http://litellm:4000/metrics` when configured with `callbacks: [prometheus]`. The key metrics for Hive monitoring:

- **`litellm_proxy_total_requests_metric`**: Total requests with labels for model, team, status code, and route
- **`litellm_spend_metric`**: Cumulative USD spend per model, team, and user
- **`litellm_remaining_team_budget_metric`**: Remaining budget per team — critical for alerting before hard cutoffs
- **`litellm_total_tokens_metric`** / **`litellm_input_tokens_metric`** / **`litellm_output_tokens_metric`**: Token consumption
- **`litellm_deployment_state`**: Health indicator (0=healthy, 1=partial outage, 2=complete outage)

Prometheus scrapes these using Kubernetes pod annotations:

```yaml
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
```

Grafana dashboards should include four panels: LLM cost over time (from `litellm_spend_metric`), task throughput per worker caste (from custom Hive metrics), Valkey queue depth over time (from the KEDA Redis scaler metrics or direct Valkey `LLEN` polling), and p95 latency per worker type. LiteLLM maintains official Grafana dashboard templates referenced in their Prometheus documentation.

### Structured JSON logging from Fastify

Fastify uses Pino as its built-in logger, outputting structured JSON by default in production:

```typescript
const fastify = Fastify({
  logger: {
    level: process.env.LOG_LEVEL || 'info',
    redact: ['req.headers.authorization', 'req.headers.cookie'],
  },
});
```

Every log line includes a `reqId` for request correlation. In Kubernetes, these JSON logs go to stdout and are collected by the node-level log agent (Promtail, Fluent Bit, or Vector) for forwarding to Loki or a central log store. The `redact` option prevents sensitive headers from appearing in logs — essential when authorization headers contain API keys.

---

## 8. Production operations patterns that prevent 3 AM incidents

### Database migrations without race conditions

When multiple pods start simultaneously in Kubernetes, all init containers attempt to run migrations concurrently — causing conflicts, duplicate schema changes, or database locks. The recommended pattern uses a dedicated Kubernetes Job for migrations, with application pods waiting for completion:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hive-db-migrate
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: ghcr.io/the-hive/queen:latest
          command: ["npx", "drizzle-kit", "migrate"]
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: hive-db-secret
                  key: url
      restartPolicy: Never
  backoffLimit: 3
```

Application Deployments use an init container that waits for the Job to complete before starting. Alternatively, use PostgreSQL advisory locks (`SELECT pg_advisory_lock(12345)`) in the migration script itself to serialize concurrent migration attempts.

### Graceful shutdown for Fastify and Node.js workers

Kubernetes sends SIGTERM on pod termination. The worker must stop accepting new tasks and complete in-flight API calls:

```typescript
let isShuttingDown = false;

const shutdown = async (signal: string) => {
  if (isShuttingDown) return;
  isShuttingDown = true;
  fastify.log.info(`${signal} received, starting graceful shutdown`);
  
  // Stop pulling new tasks from Valkey queue
  await taskConsumer.stop();
  
  // Close Fastify (drains in-flight HTTP requests)
  await fastify.close();
  
  // Close database connections
  await db.end();
  
  process.exit(0);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Safety net: force exit after grace period minus buffer
setTimeout(() => {
  console.error('Forced shutdown after timeout');
  process.exit(1);
}, 110_000); // 110s, under the 120s terminationGracePeriodSeconds
```

The 110-second safety timeout is set 10 seconds below `terminationGracePeriodSeconds: 120` to allow clean exit before SIGKILL. Use `CMD ["node", "dist/index.js"]` in the Dockerfile — never npm — because npm swallows SIGTERM and the Node.js process never receives the shutdown signal.

### Backup strategies for PostgreSQL and ClickHouse

**PostgreSQL**: pgBackRest is the enterprise-grade solution, supporting incremental backups, PITR, parallel backup/restore, ZSTD compression, and direct S3 upload. For simpler setups, WAL-G provides cloud-native WAL archiving to S3 — the closest PostgreSQL equivalent to Litestream's continuous replication model.

**Important clarification**: Litestream is a streaming replication tool for **SQLite only**, not PostgreSQL. For PostgreSQL continuous WAL replication to S3 on Tier 2 VPS deployments, use WAL-G with `archive_mode = on`:

```bash
# WAL-G continuous archiving
export WALG_S3_PREFIX=s3://hive-backups/postgres
wal-g backup-push /var/lib/postgresql/17/main
```

**ClickHouse**: The `clickhouse-backup` tool from Altinity handles full and incremental backups to S3:

```yaml
# /etc/clickhouse-backup/config.yml
general:
  remote_storage: s3
  backups_to_keep_local: 3
  backups_to_keep_remote: 10
s3:
  bucket: "hive-clickhouse-backups"
  endpoint: "https://s3.amazonaws.com"
  region: us-east-1
  path: "backup/hive"
  compression_format: zstd
```

ClickHouse 25.x also supports native `BACKUP` SQL commands for direct S3 backup without external tools.

### Cost guardrails: KEDA + LiteLLM budget caps

The three-layer cost control system prevents runaway agent spending:

1. **KEDA `maxReplicaCount: 20`** caps the number of concurrent worker pods
2. **ResourceQuota `pods: 30`** in the `hive-workers` namespace provides a hard ceiling
3. **LiteLLM budget caps** limit actual LLM API spend:

```yaml
# litellm-config.yaml
litellm_settings:
  max_budget: 500          # $500 USD total
  budget_duration: 30d     # Reset monthly
  callbacks: [prometheus]

router_settings:
  provider_budget_config:
    anthropic:
      budget_limit: 300
      time_period: 1d
    openai:
      budget_limit: 200
      time_period: 1d
```

When `litellm_remaining_team_budget_metric` drops below a threshold, Grafana alerts fire before the hard cutoff. The `/ready` endpoint on workers should check remaining budget — when LiteLLM returns budget-exceeded errors, the readiness probe fails, and Kubernetes stops routing tasks to that worker, creating a graceful degradation rather than hard failures.

---

## Conclusion

The Hive's deployment architecture succeeds where most agent frameworks fail because it separates the scaling unit (stateless workers) from the coordination unit (the Queen) and the state layer (PostgreSQL, Valkey, ClickHouse). This separation means the identical application code runs across all three tiers — only the infrastructure layer changes.

Three insights emerge from this analysis that challenge common assumptions. First, **KEDA is not optional for LLM agent workloads** — it is required. Every major cloud provider now recommends event-driven scaling for AI workloads, and the CNCF's graduation of KEDA in August 2023 reflects production validation across 45+ organizations. CPU-based HPA will never trigger for I/O-bound agents. Second, **the ArgoCD replica count conflict with KEDA** is a solved problem but an underdocumented one — the `RespectIgnoreDifferences=true` sync option (not just `ignoreDifferences`) is the critical piece that prevents scaling wars. Third, the `_FILE` secrets convention is not a Docker best practice nicety — it is a security boundary. Environment variables are visible in at least four attack surfaces that file-based secrets eliminate entirely.

The progression from `docker compose up` to a KEDA-scaled Kubernetes cluster is not a rewrite. It is a series of additive changes: add persistent volumes, add health checks, add secrets management, add autoscaling, add GitOps. Each step builds on the previous one, and every Docker Compose service definition maps directly to a Kubernetes Deployment. The Hive's architecture ensures this mapping remains clean across all three tiers.