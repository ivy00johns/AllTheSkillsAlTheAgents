# Infrastructure Agent Validation Checklist

## Docker Build
```bash
docker compose build     # All images build successfully
docker images | grep -E "frontend|backend"  # Recent timestamps
```

## Service Startup
```bash
docker compose up -d
docker compose ps        # All "running" or "healthy"
docker compose logs --tail=20  # No errors
```

## Connectivity
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/v1/health  # 200
curl -s -o /dev/null -w "%{http_code}" http://localhost:5173  # 200
```

## Persistence
```bash
curl -s -X POST http://localhost:8000/api/v1/sessions \
  -H "Content-Type: application/json" -d '{"title": "docker test"}'
docker compose restart
curl -s http://localhost:8000/api/v1/sessions  # Data still present
```

## Clean Startup
```bash
docker compose down -v && docker compose up -d
sleep 10 && docker compose ps  # All healthy, fresh DB
```
