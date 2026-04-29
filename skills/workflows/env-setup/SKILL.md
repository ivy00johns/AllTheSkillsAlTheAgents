---
name: env-setup
version: 2.1.0
description: >
  Wire up a project's .env file using 1Password vault references (op://) so secrets never
  live in the file itself. Use when cloning a new repo, setting up a project for the first
  time, populating a .env from .env.example, or when the user says "set up my env", "wire
  up the env file", "I need my .env configured", "get my keys set up", "bootstrap this
  project's environment", "set up credentials", or "add new env vars". Also use when a
  project fails because of missing env vars, or when the user wants to add a custom/project-
  specific override for a shared key. Reads .env.example (or .env.sample / .env.template),
  fetches or creates items in the 1Password Key Madness vault, and writes op:// secret
  references — so the .env file is safe to inspect without exposing credentials.
  IMPORTANT: Requires OP_SERVICE_ACCOUNT_TOKEN to be set when running via Claude Code iOS
  or any remote control session — OS-level auth prompts cannot be approved remotely.
---

# env-setup

Populate a project's `.env` file with **1Password secret references** (`op://`), not actual
values. Secrets stay in the vault; the `.env` file contains only pointers.

## Prerequisites

The `op` (1Password CLI) must be installed and authenticated.

### Remote control / iOS warning

**If this session is running via Claude Code iOS or any remote control context**, OS-level authentication prompts cannot be approved — the session will hang silently. Before attempting any `op` commands, check for a Service Account token:

```bash
echo "${OP_SERVICE_ACCOUNT_TOKEN:0:8}"
```

- If this prints `ops_` → you're good. `op` will use the token automatically with no OS prompts. Proceed to the auth check below.
- If this prints nothing → **stop here** and tell the user:

  > "1Password requires OS-level authentication (biometric or password prompt) which can't be approved in a remote/iOS session. To use this skill remotely, set up a Service Account token first:
  >
  > On your Mac (in a local terminal or Claude Code desktop):
  > ```bash
  > op service-account create "Claude Code Remote" --vault "Key Madness:read_items,write_items" --expires-in 365d
  > ```
  > Copy the token (starts with `ops_`) and add it to your shell profile:
  > ```bash
  > echo 'export OP_SERVICE_ACCOUNT_TOKEN=ops_YOUR_TOKEN_HERE' >> ~/.zshrc
  > ```
  > Then start a new remote session."

**Do not attempt `op vault list` or any other `op` command without a service account token in a remote/iOS context** — it will trigger an OS prompt that hangs the session.

---

### Auth check (local / desktop sessions)

**Do not use `op whoami` as your auth check.** When 1Password uses desktop app / biometric integration, `op whoami` fails in Claude Code subprocesses even when the app is fully unlocked — it requires keychain IPC that subprocesses can't reach. Use a data operation instead:

```bash
# Check 1: plain op — use vault list WITHOUT --vault filter (filtered form can return
# empty even when auth works, due to different code path)
op vault list 2>/dev/null | head -1

# Check 2: desktop app bypass (required in Claude Code with biometric auth)
OP_CONNECT_TOKEN="" op vault list 2>/dev/null | head -1
```

- If Check 1 returns output → use plain `op` for all commands.
- If Check 2 returns output → prefix **every** `op` command with `OP_CONNECT_TOKEN=""`.
- If both return nothing → tell the user to run `! op signin` in the prompt, wait for confirmation, then retry Check 2.
- If still nothing → stop and tell the user: their 1Password setup requires a terminal session where biometric auth is active. The long-term fix is creating a Service Account token for the Key Madness vault (see the remote control section above).

---

## Workflow

### Step 1: Find the template

Look for `.env.example`, `.env.sample`, or `.env.template` in the current directory. Check
one level of subdirectories if none found at root. If still none, tell the user and stop.

**Derive the project name** from the working directory basename. Uppercase every character
and remove all non-alphanumeric characters (e.g., `MarketsBeRigged` → `MARKETSBERIGGED`,
`my-app` → `MYAPP`). You'll use this as a prefix for project-specific vault item names.

**Check if `.env` already exists.** If it does, read it fully before doing anything else:
- Collect every variable name and its current value — you'll use these instead of asking
- Distinguish `op://` references (already migrated) from plaintext values (need migration)
- If it has plaintext secrets, you have what you need to vault them — do not ask the user
  to re-enter values that are already in the file
- If the user declines migration, proceed to add only the new/missing variables

### Step 2: Parse and classify variables

Read the template file. For each non-blank, non-comment line, extract:
- Variable name
- Value from template (if any — often empty or a placeholder)
- Inline comment (the human-readable description after `#`)

**Classify each variable:**

| Class | Description | Action |
|-------|-------------|--------|
| **secret** | API key, token, or credential | Always use vault reference |
| **config** | Infrastructure setting with a sensible default | Write value directly |
| **project-specific** | URL or ID unique to this deployment | Use vault reference |

**Classify as `secret` if the name matches any pattern:**
`*_API_KEY`, `*_SECRET*`, `*_TOKEN*`, `*_PASSWORD`, `*_PRIVATE_KEY`, `*_ACCESS_KEY`,
`*_AUTH*`, `JWT_*`, `BEARER_*`, `*_CREDENTIAL*`, `*_HASH`, `PRIVATE_KEY`

**Classify as `config` (write value directly, skip vault) if:**
- Template already has a concrete non-placeholder value (`PORT=3000`, `NODE_ENV=development`)
- Name is: `PORT`, `HOST`, `NODE_ENV`, `ENVIRONMENT`, `LOG_LEVEL`, `DEBUG`,
  `PYTHON_VERSION`, `DEPLOYMENT_TARGET`, `TRADING_MODE`, `*_ENABLED`, `*_DISABLED`,
  `DO_NOT_TRACK`, `ANONYMIZED_TELEMETRY`

**Classify as `project-specific` if:**
- `*_URL` (when template value is empty or a placeholder)
- `*_PROJECT_ID`, `*_WORKSPACE_ID`, `*_ORG_ID`, `*_APP_ID`
- `DATABASE_URL`, `MONGODB_URI`, `REDIS_URL`

Everything else: treat as `secret`.

### Step 3: Bulk check 1Password vault

For all `secret` and `project-specific` variables, check the **Key Madness** vault. For
each variable, check two vault item names:

1. **Shared name** — `VAR_NAME` (e.g., `ANTHROPIC_API_KEY`)
2. **Project-specific name** — `PROJECTNAME_VAR_NAME` (e.g., `MARKETSBERIG GED_ANTHROPIC_API_KEY`)

Check the project-specific name first; if found, use that. Otherwise use the shared name.

```bash
# Check project-specific first
OP_CONNECT_TOKEN="" op read "op://Key Madness/PROJECTNAME_VAR_NAME/password" 2>/dev/null
# If empty, check shared
OP_CONNECT_TOKEN="" op read "op://Key Madness/VAR_NAME/password" 2>/dev/null
```

(Omit the `OP_CONNECT_TOKEN=""` prefix if Check 1 succeeded in Prerequisites.)

Collect:
- **found (project-specific)** — project-namespaced item exists in vault
- **found (shared)** — shared item exists; will be used unless user wants an override
- **missing** — not in vault under either name

### Step 4: Print status and gather missing values

Print a clear summary. **Never show actual secret values** — not in the status output, not
anywhere in the conversation. Show variable names and vault item names only.

```
Env setup for: ./MarketsBeRigged

✓ Found in vault — project-specific (1):
  MARKETSBERIGGED_ANTHROPIC_API_KEY  →  ANTHROPIC_API_KEY

✓ Found in vault — shared (2):
  ALPACA_API_KEY, ALPACA_SECRET_KEY

✓ From existing .env — will vault as shared (2):
  ALPACA_API_KEY, ALPACA_SECRET_KEY

→ Using template defaults (1):
  TRADING_MODE=paper

✗ Need values — not in .env or vault (1):
  NEWS_API_KEY          — News API key for headlines

Any shared key can be overridden with a project-specific value — just say which ones.
```

Then ask for missing values. For each missing variable, show the name and its template
comment as context. Load `references/variable-catalog.md` if you need to tell the user
where to get the value.

**Since `.env` will use `op://` references, every secret must be saved to the vault.**
There is no "skip vault" option for secrets — the reference won't work without an item.

**Use existing `.env` values whenever possible.** If the current `.env` already has a
plaintext value for a variable, use that value to create the vault item — never ask the
user to re-type something you can read from the file. Only prompt when you genuinely don't
have the value (variable exists in the template but not in `.env` and not in the vault).

**Project-specific override flow:** If a variable has a plaintext value in the current
`.env` that differs from the shared vault item, or the user explicitly requests a separate
key for this project, create a project-namespaced vault item: `PROJECTNAME_VAR_NAME`. Read
the value from the existing `.env` — do not ask for it. Ask only: "Should this be
project-specific (just this project) or replace the shared key?"

Save new/override values to vault:

```bash
# Create or update vault item (use OP_CONNECT_TOKEN="" prefix if needed per Prerequisites)
OP_CONNECT_TOKEN="" op item create \
  --category "Password" \
  --title "ITEM_NAME" \
  --vault "Key Madness" \
  "password=THE_VALUE" 2>/dev/null \
|| OP_CONNECT_TOKEN="" op item edit "ITEM_NAME" \
  --vault "Key Madness" \
  "password=THE_VALUE" 2>/dev/null
```

### Step 5: Write the .env file

Write `.env` preserving original comment lines, section headers, variable ordering, and
blank lines from the template.

**For `secret` and `project-specific` variables:**
Write an `op://` reference, not the actual value:
```
ANTHROPIC_API_KEY=op://Key Madness/ANTHROPIC_API_KEY/password
ALPACA_API_KEY=op://Key Madness/ALPACA_API_KEY/password
```

For project-specific overrides, reference the namespaced item:
```
ANTHROPIC_API_KEY=op://Key Madness/MARKETSBERIG GED_ANTHROPIC_API_KEY/password
```

**For `config` variables:**
Write the actual value directly:
```
TRADING_MODE=paper
PORT=8000
```

Never write placeholder text from the template (`your_key_here`, `<YOUR_KEY>`, `xxxx`,
`changeme`) — if a value is still unresolved, write `VAR_NAME=` (empty).

For `VITE_*` and `NEXT_PUBLIC_*` prefixed variables, look up the un-prefixed name first
(e.g., `VITE_OPENAI_API_KEY` → check `OPENAI_API_KEY`, then `VITE_OPENAI_API_KEY`).

### Step 6: Update .env.example for new variables

If any variables were added that aren't in `.env.example`, append them to `.env.example`
with empty/placeholder values and any inline comment the user provided:

```
NEW_VAR_NAME=           # Description of what this is for
```

This keeps the template in sync so the next developer knows the variable exists.

### Step 7: Final summary

```
✓ .env written (6 variables)
  • 3 op:// vault references (shared)
  • 1 op:// vault reference (project-specific override)
  • 1 config value written directly
  • 1 new vault item created: NEWS_API_KEY

✓ .env.example updated with 1 new variable

New items saved to Key Madness: NEWS_API_KEY

Runtime usage:
  op run -- python main.py          # inject secrets for a single command
  op run -- docker-compose up       # inject into Docker
  eval $(op run --env-file .env)    # export into current shell
```

Check that `.env` is in `.gitignore`. If not, mention it but don't add it automatically.
Note: `.env` with `op://` references is still sensitive (reveals which secrets the project
uses), so it should stay out of version control.

---

## Reference files

- `references/variable-catalog.md` — Common variable names, platform source, and where to
  get them. Load when you need to tell the user where to find a missing key.
- `references/op-commands.md` — 1Password CLI command reference. Load when troubleshooting
  `op` authentication or item creation errors.
