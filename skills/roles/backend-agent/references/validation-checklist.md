# Backend Agent Validation Checklist

Run ALL before reporting done. Fix failures.

## Server Starts
```bash
# FastAPI: uvicorn main:app --port 8000
# Express: node server.js or npm run dev
# Django: python manage.py runserver 8000
# Expected: starts without errors, listening on configured port
```

## Database Initializes
```bash
# SQLAlchemy: python -c "from db import engine; from models import Base; Base.metadata.create_all(engine)"
# Prisma: npx prisma db push
# Django: python manage.py migrate
# Expected: no errors, tables created
```

## Every Contracted Endpoint Works
```bash
# Create
curl -s -X POST http://localhost:8000/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"title": "test"}' | python3 -m json.tool
# Verify: status 201, response shape matches contract

# Read
curl -s http://localhost:8000/api/v1/sessions/{id}/messages | python3 -m json.tool
# Verify: status 200, response shape matches contract

# Error case
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/api/v1/sessions/nonexistent/messages
# Verify: status 404, error envelope matches contract
```

## Error Handling
```bash
# Empty body → 422 with error envelope (not 500)
curl -s -X POST http://localhost:8000/api/v1/sessions \
  -H "Content-Type: application/json" -d '{}'

# Malformed JSON → 400 or 422 (not 500)
curl -s -X POST http://localhost:8000/api/v1/sessions \
  -H "Content-Type: application/json" -d 'not json'

# Not found → 404 with error envelope
curl -s http://localhost:8000/api/v1/sessions/does-not-exist/messages
```

## CORS Headers
```bash
curl -s -I -X OPTIONS http://localhost:8000/api/v1/sessions \
  -H "Origin: http://localhost:5173" \
  -H "Access-Control-Request-Method: POST" \
  | grep -i "access-control"
# Expected: Access-Control-Allow-Origin includes frontend origin
```

## Data Persistence
```bash
# Create → stop server → restart → retrieve → still exists
```
