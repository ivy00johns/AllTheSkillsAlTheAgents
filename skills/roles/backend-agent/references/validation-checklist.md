# Backend Agent Validation Checklist

Run ALL before reporting done. Fix failures. Substitute actual endpoints from the API contract.

## Server Starts

```bash
# FastAPI: uvicorn main:app --port ${PORT}
# Express: node server.js or npm run dev
# Django: python manage.py runserver ${PORT}
# Go: go run main.go
# Expected: starts without errors, listening on configured port
```

## Database Initializes

```bash
# SQLAlchemy: python -c "from db import engine; from models import Base; Base.metadata.create_all(engine)"
# Prisma: npx prisma db push
# Django: python manage.py migrate
# EF Core: dotnet ef database update
# Expected: no errors, tables created
```

## Every Contracted Endpoint Works

For each endpoint in the API contract, verify with curl. Substitute your actual URLs and payloads:

```bash
# Create (POST)
curl -s -X POST http://localhost:${PORT}/${contracted-path} \
  -H "Content-Type: application/json" \
  -d '{"field": "value"}' | python3 -m json.tool
# Verify: status matches contract (e.g. 201), response shape matches contract

# Read (GET)
curl -s http://localhost:${PORT}/${contracted-path}/{id} | python3 -m json.tool
# Verify: status 200, response shape matches contract

# Update (PUT/PATCH)
curl -s -X PATCH http://localhost:${PORT}/${contracted-path}/{id} \
  -H "Content-Type: application/json" \
  -d '{"field": "updated"}' | python3 -m json.tool
# Verify: status matches contract, updated fields reflected

# Delete (DELETE)
curl -s -o /dev/null -w "%{http_code}" -X DELETE http://localhost:${PORT}/${contracted-path}/{id}
# Verify: status matches contract (e.g. 204), subsequent GET returns 404

# Error case
curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT}/${contracted-path}/nonexistent
# Verify: status 404, error envelope matches contract
```

## Error Handling

```bash
# Empty body → 422 with error envelope (not 500)
curl -s -X POST http://localhost:${PORT}/${contracted-path} \
  -H "Content-Type: application/json" -d '{}'

# Malformed JSON → 400 or 422 (not 500)
curl -s -X POST http://localhost:${PORT}/${contracted-path} \
  -H "Content-Type: application/json" -d 'not json'

# Not found → 404 with error envelope
curl -s http://localhost:${PORT}/${contracted-path}/does-not-exist
```

## CORS Headers

```bash
# Substitute the actual frontend origin from the contract or project profile
curl -s -I -X OPTIONS http://localhost:${PORT}/${contracted-path} \
  -H "Origin: ${FRONTEND_ORIGIN}" \
  -H "Access-Control-Request-Method: POST" \
  | grep -i "access-control"
# Expected: Access-Control-Allow-Origin includes frontend origin
```

## Data Persistence

```bash
# 1. Create a resource
RESOURCE_ID=$(curl -s -X POST http://localhost:${PORT}/${contracted-path} \
  -H "Content-Type: application/json" \
  -d '{"field": "persistence-test"}' | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

# 2. Stop the server (Ctrl+C or kill the process)
# 3. Restart the server

# 4. Retrieve — data must still exist
curl -s http://localhost:${PORT}/${contracted-path}/${RESOURCE_ID} | python3 -m json.tool
# Verify: resource exists and matches what was created
```

## SSE/Streaming (if applicable)

```bash
# Verify streaming endpoint returns event-stream content type
curl -s -N -X POST http://localhost:${PORT}/${stream-path} \
  -H "Content-Type: application/json" \
  -d '{"field": "value"}' &
CURL_PID=$!
sleep 3
kill $CURL_PID 2>/dev/null
# Verify: received chunk events, done event, correct event shapes per contract

# Verify accumulated data is stored
curl -s http://localhost:${PORT}/${resource-path}/{id} | python3 -m json.tool
# Verify: accumulated content matches streamed chunks
```

## Environment Configuration

```bash
# .env.example exists with placeholder values
test -f .env.example && echo "PASS" || echo "FAIL: .env.example missing"

# .env is gitignored
grep -q ".env" .gitignore && echo "PASS" || echo "FAIL: .env not in .gitignore"

# No hardcoded connection strings or secrets in source
grep -rn "postgresql://\|mysql://\|mongodb://\|sk-\|password=" src/ \
  --include="*.py" --include="*.ts" --include="*.js" --include="*.go" \
  | grep -v ".env" | grep -v "node_modules"
# Expected: zero matches
```
