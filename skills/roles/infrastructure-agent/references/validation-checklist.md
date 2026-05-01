# Infrastructure Agent Validation Checklist

Adapt all commands to the project's actual service names, ports, and endpoints. The examples below use placeholder variables — replace them with values from the service map and contracts.

## Host-port collision preflight (before authoring docker-compose.yml)

The standard ports for common dev services (5432 Postgres, 6379 Redis, 5672 RabbitMQ, 27017 Mongo, 9200 Elasticsearch, 11211 memcached, 9000 MinIO) are routinely held by other local stacks — Homebrew services, another project's docker-compose, a globally-installed daemon. If you publish those ports unconditionally, the human's first `docker compose up -d` will fail with `Bind for 127.0.0.1:6379 failed: port is already allocated` and the build will look broken on day one.

Probe before you publish:

```bash
# For each port you intend to publish on the host:
for p in 5432 6379 5672; do
  if lsof -nP -iTCP:$p -sTCP:LISTEN 2>/dev/null | grep -q LISTEN; then
    echo "PORT $p IS HELD — pick a non-default host port (e.g., $((p+1)):$p)"
  fi
done
```

If a port is held, remap on the **host side only** in `docker-compose.yml`:

```yaml
# ✅ Right — container-side stays standard, host-side moves out of the way
redis:
  ports: ["6380:6379"]   # host 6380 → container 6379
```

Update `.env.example` to match (`REDIS_URL=redis://localhost:6380`) and add a one-line comment in the compose file explaining why the non-default host port. **Do not silently take a port the user is already using.**

## Docker Build

```bash
docker compose build     # All images build successfully
docker images | grep -E "${SERVICE_NAMES}"  # Recent timestamps
```

## Service Startup

```bash
docker compose up -d
docker compose ps        # All "running" or "healthy"
docker compose logs --tail=20  # No errors in any service
```

## Connectivity

```bash
# Verify each service's health endpoint (ports and paths from service map)
curl -s -o /dev/null -w "%{http_code}" http://localhost:${BACKEND_PORT}/${HEALTH_PATH}  # 200
curl -s -o /dev/null -w "%{http_code}" http://localhost:${FRONTEND_PORT}  # 200
```

## Persistence

```bash
# Use a write endpoint from the contract to create data, then restart and verify
curl -s -X POST http://localhost:${BACKEND_PORT}/${API_PREFIX}/${RESOURCE} \
  -H "Content-Type: application/json" -d '${SAMPLE_BODY}'
docker compose restart
curl -s http://localhost:${BACKEND_PORT}/${API_PREFIX}/${RESOURCE}  # Data still present
```

## Clean Startup

```bash
docker compose down -v && docker compose up -d
sleep 10 && docker compose ps  # All healthy, fresh state
```

## Observability Wiring (if observability-agent is active)

```bash
# Verify metrics endpoint is reachable
curl -s -o /dev/null -w "%{http_code}" http://localhost:${METRICS_PORT}/metrics  # 200 or valid response
# Verify log driver is configured (check docker-compose.yml logging section)
docker compose config | grep -A 3 "logging"
```
