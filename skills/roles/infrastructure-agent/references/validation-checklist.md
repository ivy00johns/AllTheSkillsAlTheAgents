# Infrastructure Agent Validation Checklist

Adapt all commands to the project's actual service names, ports, and endpoints. The examples below use placeholder variables — replace them with values from the service map and contracts.

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
