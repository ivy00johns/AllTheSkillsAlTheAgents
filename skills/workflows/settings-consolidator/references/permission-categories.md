# Permission Categories and Syntax Reference

The categorization scheme used in the consolidation report, plus the rules for understanding the three Bash permission syntaxes.

## Permission Syntax Reference

Claude Code settings files use three Bash permission syntaxes. Understanding them is essential for correct collapsing.

**Space-wildcard:** `Bash(git *)` — matches `git` followed by a space and anything after it. This is the broadest form. It covers all subcommands and arguments.

**Colon-wildcard:** `Bash(git config:*)` — matches the exact command `git config` with any arguments. Claude Code generates this format when a user clicks "allow" on a specific command invocation.

**Literal (no wildcard):** `Bash(claude doctor)` — matches only that exact string. These are one-off approvals saved verbatim.

**Collapsing rule:** `Bash(X *)` (space-wildcard) safely subsumes `Bash(X Y*)`, `Bash(X Y:*)`, and `Bash(X:*)` (bare colon-wildcard). The space-wildcard is always strictly broader because it matches the command followed by a space and anything — which covers every possible subcommand and argument form. Do NOT collapse across unrelated base commands (`Bash(git *)` does not subsume `Bash(gh *)`).

**Non-Bash permissions** use glob patterns: `Read(**)` subsumes `Read(src/**)`.

## Categorization for Reports

Group the consolidated permissions into categories. Each category with representative examples:

| Category | Examples |
|----------|---------|
| File Ops (Claude Tools) | Read(\*\*), Edit(\*\*), MultiEdit(\*\*), Write(\*\*), Glob(\*\*) |
| File Ops (Shell) | Bash(cp \*), Bash(mkdir \*), Bash(touch \*), Bash(ln \*) |
| Git & GitHub | Bash(git \*), Bash(gh \*) |
| Package Managers | Bash(npm \*), Bash(pip \*), Bash(cargo \*), Bash(bun \*), Bash(bunx \*), Bash(deno \*), Bash(uv \*), Bash(uvx \*), Bash(nvm \*), Bash(pyenv \*), Bash(rbenv \*), Bash(rvm \*) |
| Languages & Runtimes | Bash(python3 \*), Bash(node \*), Bash(ruby \*), Bash(go \*) |
| Build & Test | Bash(make \*), Bash(jest \*), Bash(pytest \*), Bash(vite \*) |
| Linters & Formatters | Bash(prettier \*), Bash(eslint \*), Bash(ruff \*) |
| Network | Bash(curl \*), Bash(wget \*), Bash(http \*), Bash(ssh \*) |
| Containers & Cloud | Bash(docker \*), Bash(kubectl \*), Bash(aws \*), Bash(vercel \*) |
| Databases | Bash(psql \*), Bash(sqlite3 \*), Bash(redis-cli \*) |
| System Utils | Bash(chmod \*), Bash(ps \*), Bash(df \*), Bash(systemctl \*) |
| Shell & Pipes | Bash(\* \| \*), Bash(\* && \*), Bash(bash \*), Bash(source \*), Bash(xargs \*), Bash(tee \*) |
| Editors & CLI Tools | Bash(code \*), Bash(cursor \*), Bash(claude \*), Bash(jq \*) |
| Crypto & Security | Bash(openssl \*), Bash(ssh-keygen \*), Bash(gpg \*) |
| Archive & Compression | Bash(tar \*), Bash(zip \*), Bash(gzip \*) |
| Terminal Multiplexers | Bash(tmux \*), Bash(screen \*) |
| macOS-Specific | Bash(defaults \*), Bash(networksetup \*), Bash(open \*), Bash(pbcopy\*) |
| Uncategorized | Anything that doesn't fit above |
| Project-Specific (flagged) | Bash(./ep \*), WebFetch to specific domains |

Sort entries alphabetically within each category.

## Superset Collapsing Rules

Apply in order:

1. **Space-wildcard absorbs more specific space-wildcards.** If `Bash(git *)` exists, drop `Bash(git status*)`, `Bash(git log*)`, etc. This includes flag-prefixed forms: `Bash(sqlite3 *)` absorbs `Bash(sqlite3 -*)` because `sqlite3 -` is just a more specific prefix of `sqlite3 `.

2. **Space-wildcard absorbs colon-wildcards for the same command.** If `Bash(git *)` exists, drop `Bash(git config:*)`, `Bash(git check-ignore:*)`. This also applies to bare colon-wildcards with no subcommand — `Bash(sqlite3 *)` absorbs `Bash(sqlite3:*)`, and `Bash(source *)` absorbs `Bash(source:*)`. The space-wildcard is always strictly broader regardless of whether the token is a command with subcommands or a shell builtin.

3. **Non-Bash glob collapsing.** `Read(**)` absorbs `Read(src/**)`, `Edit(**)` absorbs `Edit(components/**)`, etc.

4. **Do NOT collapse colon-wildcards into each other** unless one is clearly a prefix of the other. `Bash(git config:*)` and `Bash(git status:*)` are independent.

5. **Colon-to-space upgrade.** For any `Bash(cmd:*)` entry where no `Bash(cmd *)` exists yet, recommend upgrading to the space-wildcard form. Space-wildcards are strictly broader — `Bash(git *)` covers everything `Bash(git:*)` covers plus edge cases that colon-wildcards miss. This is especially important for autonomous sessions where a single missed command variant can interrupt an overnight build.

## Detecting Literal One-Offs

Entries with no `*` wildcard suffix and no `:*` suffix are literal one-off commands. Also flag entries that start with `#` — these are bash comments that got accidentally saved as permissions.

**Heuristic for literals:** Commonly useful standalone commands like `Bash(claude doctor)` or `Bash(claude --version)` are safe to merge. Entries that look accidental or project-specific — absolute paths, comments with `#`, project directory names — should be flagged for review rather than silently merged.

## Flagging Project-Specific Permissions

Identify permissions that should NOT be merged into global settings. Apply these 7 rules:

1. **Absolute paths to specific projects.** Entries like `Bash(source /Users/you/myproject/.venv/bin/activate)` are meaningless outside that project.

2. **Named project scripts.** Relative paths referencing a specific file (e.g., `Bash(./ep help)`, `Bash(./run_tests.sh)`). Generic wildcards like `Bash(./scripts/*)` or `Bash(./bin/*)` are fine to merge because they work in any project with that directory structure.

3. **`Bash(./*)` (dot-slash star).** This matches any executable in the current directory, which is effectively arbitrary code execution. Flag it for user confirmation rather than silently merging.

4. **Literal relative paths without wildcards.** Entries like `Bash(source .venv/bin/activate)` — even though `.venv/bin/activate` is conventional, a literal entry with no wildcard only makes sense in the project where it was approved.

5. **WebFetch/WebSearch to specific domains.** These are typically project-specific API endpoints or documentation sites.

6. **Bash comments accidentally saved.** Entries starting with `#` — these aren't real permissions.

7. **Hardcoded multi-line debug commands.** Entries containing multiple commands joined by spaces without shell operators.

**Rule for relative paths:** wildcards ending in `*` are generic and safe to merge (e.g., `./scripts/*`, `./bin/*`). Specific file references are project-specific and get flagged. The exception is `Bash(./*)` — too broad, flag it.
