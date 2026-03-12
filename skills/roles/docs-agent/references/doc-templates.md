# Documentation Templates

## README.md Template

````markdown
# [Project Name]

[1-2 sentence description of what this project does]

## Tech Stack

- **Frontend:** [framework + language]
- **Backend:** [framework + language]
- **Database:** [database]
- **Infrastructure:** [Docker, etc.]

## Prerequisites

- [Runtime] v[version]+
- [Package manager]
- [Database] (or Docker)

## Quick Start

```bash
# Clone
git clone [url]
cd [project]

# Install dependencies
[install command]

# Set up environment
cp .env.example .env

# Start development
[start command]
```

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `PORT` | Backend server port | `8000` | No |
| `DATABASE_URL` | Database connection string | `sqlite:///app.db` | Yes |
| `FRONTEND_ORIGIN` | CORS allowed origin | `http://localhost:5173` | No |

## API Overview

Base URL: `http://localhost:8000/api/v1`

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/sessions` | Create a new session |
| `GET` | `/sessions` | List all sessions |
| `GET` | `/sessions/:id` | Get session by ID |

See [API Documentation](docs/api.md) for full details.

## Project Structure

```
├── backend/          # API server
├── frontend/         # Web UI
├── contracts/        # Shared type definitions
├── tests/            # Integration tests
└── docker-compose.yml
```

## Development

```bash
# Run tests
[test command]

# Lint
[lint command]

# Build for production
[build command]
```

## License

[License type]

````

## API Endpoint Documentation Template

````markdown
### [METHOD] [path]

[One-line description]

**Request:**
```bash
curl -X [METHOD] http://localhost:8000[path] \
  -H "Content-Type: application/json" \
  -d '{"field": "value"}'
```

**Response (success):**

```json
{
  "id": "uuid",
  "field": "value",
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Response (error):**

```json
{
  "error": "Description",
  "code": "ERROR_CODE",
  "details": []
}
```

| Status | Meaning |
|--------|---------|
| 201 | Created successfully |
| 422 | Validation error |
| 404 | Not found |

````

## Documentation Quality Checklist

- [ ] README has working Quick Start instructions
- [ ] All environment variables documented with defaults
- [ ] Every API endpoint has a curl example
- [ ] Project structure overview is accurate
- [ ] No broken internal links
- [ ] No stale/outdated information
- [ ] CHANGELOG follows Keep a Changelog format
