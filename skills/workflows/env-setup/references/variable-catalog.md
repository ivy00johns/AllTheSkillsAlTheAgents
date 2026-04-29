# Variable Catalog

Common environment variables, their platform source, and sensible defaults.
Use this when prompting the user for a missing value — show them where to get it.

---

## AI / LLM Providers

| Variable | Platform | Where to get it |
|----------|----------|-----------------|
| `OPENAI_API_KEY` | OpenAI | platform.openai.com → API keys |
| `ANTHROPIC_API_KEY` | Anthropic | console.anthropic.com → API keys |
| `GROQ_API_KEY` | Groq | console.groq.com → API keys |
| `OPENROUTER_API_KEY` / `OPEN_ROUTER_API_KEY` | OpenRouter | openrouter.ai → keys |
| `DEEPSEEK_API_KEY` | DeepSeek | platform.deepseek.com |
| `XAI_API_KEY` | xAI (Grok) | console.x.ai |
| `MISTRAL_API_KEY` | Mistral | console.mistral.ai |
| `COHERE_API_KEY` | Cohere | dashboard.cohere.com |
| `TOGETHER_API_KEY` | Together AI | api.together.xyz |
| `PERPLEXITY_API_KEY` | Perplexity | perplexity.ai/settings/api |
| `HUGGINGFACEHUB_API_TOKEN` / `HuggingFace_API_KEY` | HuggingFace | huggingface.co/settings/tokens |
| `GOOGLE_GENERATIVE_AI_API_KEY` | Google | aistudio.google.com |

**Common config (use these defaults):**
- `LLM_PROVIDER` → `openai`
- `LLM_MODEL` / `OPENAI_MODEL` → `gpt-4o`
- `EMBEDDING_MODEL` → `text-embedding-3-small`
- `EMBEDDING_DIMENSIONS` → `1536`
- `OLLAMA_API_BASE` / `OLLAMA_API_BASE_URL` → `http://localhost:11434`

---

## Search & Web APIs

| Variable | Platform | Where to get it |
|----------|----------|-----------------|
| `SERPER_API_KEY` | Serper | serper.dev → API key |
| `TAVILY_API_KEY` | Tavily | tavily.com/dashboard |
| `BRAVE_API_KEY` | Brave Search | api.search.brave.com |
| `EXA_API_KEY` | Exa.ai | exa.ai/api |
| `FIRECRAWL_API_KEY` | Firecrawl | firecrawl.dev/app |
| `BROWSERLESS_API_KEY` | Browserless | browserless.io/dashboard |
| `JINA_API_KEY` | Jina AI | jina.ai |
| `GOOGLE_API_KEY` | Google | console.cloud.google.com |
| `GOOGLE_SEARCH_ENGINE_ID` | Google CSE | programmablesearchengine.google.com |

---

## Backend / Database

| Variable | Notes | Default / Pattern |
|----------|-------|-------------------|
| `DATABASE_URL` | Full connection string | `postgresql://user:pass@localhost:5432/dbname` |
| `POSTGRES_HOST` | | `localhost` |
| `POSTGRES_PORT` | | `5432` |
| `POSTGRES_USER` | | `postgres` |
| `POSTGRES_PASSWORD` | | *(must be set)* |
| `POSTGRES_DB` | | *(project name)* |
| `MONGODB_URI` | | `mongodb://localhost:27017/dbname` |
| `REDIS_HOST` | | `localhost` |
| `REDIS_PORT` | | `6379` |
| `REDIS_URL` | | `redis://localhost:6379` |

---

## Auth / Security

| Variable | Notes |
|----------|-------|
| `JWT_SECRET` | Random 32+ char string — generate with `openssl rand -hex 32` |
| `SESSION_SECRET` | Random string — same approach |
| `AUTH_SECRET` | Same |
| `BEARER_TOKEN` / `API_BEARER_TOKEN` | App-level bearer token — can be self-generated |

---

## Supabase

| Variable | Where |
|----------|-------|
| `SUPABASE_URL` | supabase.com → project → Settings → API → Project URL |
| `SUPABASE_SERVICE_KEY` | Settings → API → service_role key (secret) |
| `SUPABASE_ANON_KEY` / `SUPABASE_KEY` | Settings → API → anon/public key |

---

## Project Management

| Variable | Platform | Notes |
|----------|----------|-------|
| `ASANA_ACCESS_TOKEN` | Asana | app.asana.com/0/my-apps → Personal Access Token |
| `ASANA_PROJECT_ID` | Asana | From project URL: app.asana.com/0/**PROJECT_ID** |
| `ASANA_WORKPLACE_ID` | Asana | From API or URL |
| `GITHUB_TOKEN` | GitHub | github.com/settings/tokens |

---

## Social / Messaging

| Variable | Platform |
|----------|----------|
| `TELEGRAM_BOT_TOKEN` | BotFather on Telegram |
| `TELEGRAM_CHAT_ID` | Use @userinfobot |
| `SLACK_BOT_TOKEN` | api.slack.com → App → OAuth tokens |
| `TWITTER_API_KEY` / `TWITTER_API_SECRET` | developer.twitter.com |

---

## Infrastructure Defaults

These are almost always safe to use from the template default:

| Variable | Default |
|----------|---------|
| `PORT` | `3000` (Node) / `8000` (Python) |
| `HOST` | `0.0.0.0` |
| `NODE_ENV` | `development` |
| `LOG_LEVEL` | `info` |
| `DEBUG` | `false` |
| `DO_NOT_TRACK` | `1` |
| `ANONYMIZED_TELEMETRY` | `false` |

---

## Intelligence / Data APIs (project-specific repos)

| Variable | Platform |
|----------|----------|
| `FRED_API_KEY` | fred.stlouisfed.org/docs/api |
| `FINNHUB_API_KEY` | finnhub.io/dashboard |
| `AISSTREAM_API_KEY` | aisstream.io |
| `NASA_FIRMS_API_KEY` | firms.modaps.eosdis.nasa.gov |
| `ACLED_ACCESS_TOKEN` | acleddata.com/acleddatanew/wp-content/uploads/dlm_uploads |
| `EIA_API_KEY` | eia.gov/opendata |
