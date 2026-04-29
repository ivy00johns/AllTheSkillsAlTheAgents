# 1Password CLI Reference

Quick reference for `op` commands used in env-setup.

## Authentication

```bash
# Check if signed in
op whoami

# Fallback (useful when desktop app socket is unavailable to subprocesses)
OP_CONNECT_TOKEN="" op whoami

# Sign in and export session token into current shell
eval $(op signin)

# Sign in (user must run this interactively with ! prefix in Claude Code)
op signin

# List available accounts
op account list
```

If `op whoami` fails:
1. Tell the user to run `! op signin` in the prompt
2. After they confirm, run `eval $(op signin) && op whoami` to pick up the session
3. If that still fails, check `op account list` — account must be registered before signing in

---

## Reading Secrets

```bash
# Read a single field (returns value only, empty string if not found)
op read "op://Key Madness/VARIABLE_NAME/password" 2>/dev/null

# Get item with all fields
op item get "VARIABLE_NAME" --vault "Key Madness"

# List all items in vault
op item list --vault "Key Madness" --format json
```

The `op read` command returns the value directly (no JSON parsing needed). Exit code 0 = found, non-zero = not found.

---

## Creating / Updating Items

```bash
# Create a new Password item
op item create \
  --category "Password" \
  --title "VARIABLE_NAME" \
  --vault "Key Madness" \
  "password=THE_SECRET_VALUE"

# Update existing item's password
op item edit "VARIABLE_NAME" \
  --vault "Key Madness" \
  "password=NEW_VALUE"

# Create or update (try create, fall back to edit on conflict)
op item create \
  --category "Password" \
  --title "VARIABLE_NAME" \
  --vault "Key Madness" \
  "password=THE_VALUE" 2>/dev/null \
|| op item edit "VARIABLE_NAME" \
  --vault "Key Madness" \
  "password=THE_VALUE" 2>/dev/null
```

---

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `[ERROR] 401: Unauthorized` | Not signed in | `! op signin` |
| `[ERROR] More than one item matches` | Duplicate item names in vault | `op item list --vault "Key Madness"` to find and remove duplicates |
| `[ERROR] No such item` | Item doesn't exist | Normal — just means the key isn't in 1Password yet |
| `[ERROR] Could not find vault` | Vault name mismatch | Confirm vault name: `op vault list` |

---

## Vault Management

```bash
# List all vaults
op vault list

# Create the Key Madness vault (first-time setup)
op vault create "Key Madness"
```

If the "Key Madness" vault doesn't exist yet, offer to create it: `op vault create "Key Madness"`
