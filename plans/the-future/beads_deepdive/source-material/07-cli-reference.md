# 07 -- CLI Reference

Complete reference for the `bd` command-line interface. Covers the root command,
global flags, command lifecycle, all command groups, key command details, and
the auto-commit/auto-push/config subsystems.

Source: `cmd/bd/` (329 files), `internal/config/`, `internal/configfile/`,
`internal/recipes/`.

---

## 1. Root Command

```
Use:   bd
Short: bd - Dependency-aware issue tracker
Long:  Issues chained together like beads. A lightweight issue tracker
       with first-class dependency support.
```

The binary name is overridable via the `BD_NAME` environment variable. Setting
`BD_NAME=ops` causes help text to display `ops` instead of `bd`. This supports
multi-instance setups where wrapper scripts set `BEADS_DIR` for routing.

The root command with no subcommand displays help. The `--version` / `-V` flag
on the root command prints version and build info.

---

## 2. Global Flags

These flags are registered as `PersistentFlags` on the root command and apply
to every subcommand.

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--db` | string | `""` | Database path. When empty, auto-discovers `.beads/*.db` by walking up from CWD. |
| `--actor` | string | `""` | Actor name for audit trail. Falls back through: `$BD_ACTOR` > `$BEADS_ACTOR` > `git config user.name` > `$USER` > `"unknown"`. |
| `--json` | bool | `false` | Output in JSON format. Also settable via `--format json` (hidden alias). |
| `--sandbox` | bool | `false` | Sandbox mode: disables auto-sync. Auto-detected in sandboxed environments. |
| `--readonly` | bool | `false` | Read-only mode: blocks write operations. Intended for worker sandboxes. |
| `--dolt-auto-commit` | string | `""` | Dolt auto-commit policy: `off` (default), `on` (commit after each write), `batch` (defer to explicit `bd dolt commit`). Override via config key `dolt.auto-commit`. |
| `--profile` | bool | `false` | Generate CPU profile and execution trace for performance analysis. Creates `bd-profile-<cmd>-<ts>.prof` and `bd-trace-<cmd>-<ts>.out`. |
| `--verbose` / `-v` | bool | `false` | Enable verbose/debug output. Shows config override notifications and internal diagnostic info. |
| `--quiet` / `-q` | bool | `false` | Suppress non-essential output (errors only). |

All flags respect a layered override: explicit CLI flag > viper config (config.yaml + env vars) > hardcoded default.

---

## 3. PersistentPreRun Lifecycle

Every command execution goes through this lifecycle before the command's own
`Run` function. This is the most important sequence in the CLI -- it initializes
the database, resolves the actor, and sets up the runtime environment.

### Step-by-step sequence:

1. **Init CommandContext** -- Creates the `CommandContext` struct that holds
   runtime state, replacing scattered globals.

2. **Reset write tracking** -- Clears `commandDidWrite` (atomic bool),
   `commandDidExplicitDoltCommit`, `commandDidWriteTipMetadata`, and
   `commandTipIDsShown` map.

3. **Setup graceful shutdown** -- Creates a cancellable context with signal
   handlers for `SIGINT`, `SIGTERM`, and `SIGHUP`. On first signal, flushes
   pending batch commits before cancellation. On second signal, forces `os.Exit(1)`.

4. **Init OpenTelemetry** -- Calls `telemetry.Init()`. No-op unless
   `BD_OTEL_METRICS_URL` or `BD_OTEL_STDOUT=true` is set. Must run before any
   DB access so SQL spans nest correctly.

5. **Start root span** -- Creates the OTel span `bd.command.<name>` with
   attributes for command name, version, and raw args. All downstream storage
   and AI calls become child spans.

6. **Apply verbosity** -- Sets `debug.SetVerbose()` and `debug.SetQuiet()`.

7. **Block dangerous env vars** -- Checks for `BD_BACKEND` and
   `BD_DATABASE_BACKEND`. If set, exits with error to prevent data fragmentation
   via viper's `AutomaticEnv`.

8. **Apply viper config overrides** -- For each global flag not explicitly set on
   the command line, loads the value from viper (config.yaml + env vars). Handles
   the `--format json` hidden alias.

9. **Validate auto-commit mode** -- Calls `getDoltAutoCommitMode()` early to
   fail fast on invalid config.

10. **Check noDbCommands** -- Compares the command name against a hardcoded list
    of commands that do not need database access:
    - `bootstrap`, `completion`, `doctor`, `dolt` (bare), `help`, `hook`, `hooks`,
      `human`, `init`, `merge`, `migrate`, `onboard`, `prime`, `quickstart`,
      `setup`, `version`
    - Plus Cobra internal completion commands: `__complete`, `__completeNoDesc`,
      shell names (`bash`, `fish`, `zsh`, `powershell`)
    - Exception: `dolt push`, `dolt pull`, `dolt commit` and `dolt remote` subcommands
      DO need the store and fall through.
    - If the command is in this list, PreRun returns early (no DB init).

11. **Skip for root/version** -- If showing help or `--version`, return early.

12. **CPU/trace profiling** -- If `--profile` is set, creates profile and trace
    output files and starts `pprof.StartCPUProfile()` / `trace.Start()`.

13. **Auto-detect sandbox** -- If `--sandbox` was not explicitly set, checks
    `isSandboxed()` (environment detection) and enables sandbox mode if detected.

14. **Capture redirect info** -- Before `FindDatabasePath()` follows any
    `.beads/redirect` file, captures the redirect info and sets
    `BEADS_DOLT_SERVER_DATABASE` env var so all store opens use the correct
    database in shared-server scenarios.

15. **Find database path** -- If `--db` is empty, calls `beads.FindDatabasePath()`
    to walk up the directory tree looking for `.beads/*.db`. Follows redirect
    files, resolves symlinks. If no DB is found, some commands (`import`, `setup`,
    YAML-only config ops) get a default path; all others exit with error.

16. **Resolve actor** -- Calls `getActorWithGit()` which implements the priority
    chain: `--actor` flag > `$BD_ACTOR` > `$BEADS_ACTOR` > `git config user.name`
    > `$USER` > `"unknown"`. Attaches the actor to the OTel command span.

17. **Track version changes** -- Best-effort call to `trackBdVersion()` for
    upgrade notification.

18. **Determine read-only mode** -- Checks if the command is in the
    `readOnlyCommands` map (see section 4). Read-only commands open the store
    without file modifications to avoid triggering file watchers.

19. **Auto-migrate on version bump** -- Calls `autoMigrateOnVersionBump()` which
    opens its own store connection, writes version metadata, commits, and closes
    BEFORE the main store is opened. Runs for ALL commands including read-only.

20. **Open store** -- Builds a `dolt.Config` with resolved paths (BeadsDir,
    DoltDataDir, server connection settings from `metadata.json`), cleans stale
    noms LOCK files, then calls `newDoltStore()` to open the Dolt storage.

21. **Validate workspace identity** -- For write commands only, compares the
    `project_id` from `metadata.json` against the database's `_project_id`
    metadata. Mismatch indicates configuration drift (wrong DB). Skippable via
    `BEADS_SKIP_IDENTITY_CHECK=1`.

22. **Init hook runner** -- Creates `hooks.NewRunner()` pointing at
    `.beads/hooks/` directory.

23. **Warn multiple databases** -- Detects if multiple `.beads` directories
    exist in the parent hierarchy.

24. **Load molecule templates** -- Scans hierarchical catalog locations for
    molecule template files and loads them into the store.

25. **Sync CommandContext** -- Copies all resolved state into the unified
    `CommandContext` struct.

---

## 4. Read-Only Commands

These commands open the store in read-only mode, preventing database file
modifications that would trigger file watchers (GH#804). No lock files are
created.

```
list, ready, show, stats, blocked, count, search, graph,
duplicates, comments, current, backup, export
```

All other commands open the store in read-write mode.

---

## 5. PersistentPostRun Lifecycle

Runs after every command's `Run` function completes successfully.

1. **Dolt auto-commit** -- If `commandDidWrite` is true and no explicit Dolt
   commit was already made, calls `maybeAutoCommit()`. Only fires when
   `dolt-auto-commit` is `"on"`. In `"batch"` mode, changes stay in the working
   set.

2. **Tip metadata auto-commit** -- If a tip was shown during the command,
   creates a separate Dolt commit for `tip_*_last_shown` metadata updates.

3. **Auto-backup** -- Calls `maybeAutoBackup()` to export JSONL to
   `.beads/backup/` if configured and due.

4. **Auto-push** -- Calls `maybeAutoPush()` to push to Dolt remote if enabled
   and due. Skipped for read-only commands (GH#2191).

5. **Close store** -- Marks store as inactive (prevents background flush from
   accessing closed store), then calls `store.Close()`.

6. **Flush OTel** -- Ends the command span, shuts down the telemetry provider
   with a 5-second timeout.

7. **Stop profiling** -- If profiling was enabled, stops CPU profile and
   execution trace, closes output files.

8. **Cancel context** -- Cancels the signal-aware root context to clean up
   resources.

---

## 6. Command Groups

The help output organizes commands into seven groups using Cobra's group system.

### 6.1 Working With Issues

| Command | Aliases | Description |
|---------|---------|-------------|
| `create` | `new` | Create a new issue (or batch from markdown file) |
| `list` | -- | List issues with 50+ filter flags |
| `show` | -- | Show detailed issue information |
| `update` | -- | Update issue fields |
| `close` | `done` | Close one or more issues |
| `reopen` | -- | Reopen closed issues |
| `delete` | -- | Delete issues |
| `edit` | -- | Edit issue in `$EDITOR` |
| `search` | -- | Full-text search across issues |
| `query` | -- | AST-based query language |
| `count` | -- | Count issues matching filters |

### 6.2 Views and Reports

| Command | Description |
|---------|-------------|
| `ready` | Show ready work (open, no active blockers) |
| `blocked` | Show blocked issues with blocker details |
| `stale` | Show stale issues (no recent activity) |
| `duplicates` | Detect potential duplicate issues |
| `status` | Status summary dashboard |
| `current` | Show current/in-progress issues |
| `graph` | Dependency graph visualization (text, DOT, digraph) |

### 6.3 Dependencies and Structure

| Command | Description |
|---------|-------------|
| `dep` | Manage dependencies (`add`, `remove`, `tree`) |
| `relate` | Add related-type dependency (convenience) |
| `children` | List child issues of a parent |
| `epic` | Epic management (`status`, `close-eligible`) |

### 6.4 Sync and Data

| Command | Description |
|---------|-------------|
| `dolt` | Dolt operations (`push`, `pull`, `commit`, `remote`, `log`, `diff`) |
| `vc` | Version control shorthand |
| `backup` | Backup operations (`export`, `restore`, `git`, `dolt`) |
| `flatten` | Squash all Dolt history to single commit |
| `import` | Import issues from JSONL/markdown |
| `export` | Export issues to JSONL/stdout |

### 6.5 Setup and Configuration

| Command | Description |
|---------|-------------|
| `init` | Initialize beads database (embedded, contributor, agent, team modes) |
| `bootstrap` | Quick-start initialization |
| `config` | Config management (`set`, `get`, `list`, `unset`, `validate`) |
| `setup` | Install AI tool recipes |
| `prime` | Inject workflow context for AI sessions |
| `onboard` | Interactive onboarding walkthrough |

### 6.6 Maintenance

| Command | Description |
|---------|-------------|
| `doctor` | 20+ health checks with `--fix` auto-repair. Categories: database, schema, migrations, git hooks, pollution, performance, server mode. Flags: `--fix`, `--yes`, `--interactive`, `--dry-run`, `--deep`, `--server`, `--agent`, `--check <name>`, `--clean`, `--gastown`. |
| `gc` | Three-phase garbage collection (decay, compact, dolt gc) |
| `compact` | Squash old Dolt commits |
| `migrate` | Database schema migrations |
| `cleanup` | Remove orphaned data |
| `purge` | Hard-delete purged issues |
| `worktree` | Manage git worktrees for parallel agent work |
| `sql` | Execute raw SQL against the database |
| `flatten` | Nuclear option: squash all history to one commit |

### 6.7 Integrations and Advanced

| Command | Description |
|---------|-------------|
| `query` | AST-based query language (also in Issues group) |
| `audit` | Audit trail operations (`record`, `label`) |
| `template` | Manage issue templates |
| `rename` | Rename an issue ID |
| `rename-prefix` | Rename all issues with a prefix |
| `federation` | Peer-to-peer federation operations |
| `github` | GitHub integration |
| `gitlab` | GitLab integration |
| `jira` | Jira import/sync |
| `linear` | Linear import/sync |

### 6.8 Molecules and Chemistry

| Command | Description |
|---------|-------------|
| `cook` | Execute a formula (create molecule from template) |
| `pour` | Pour a formula into an existing issue |
| `wisp` | Ephemeral issue management (`create`, `list`, `gc`) |
| `mol` | Molecule operations (`show`, `squash`, `burn`, `current`, `ready`, `stale`, `progress`, `distill`, `bond`, `seed`, `last-activity`) |
| `swarm` | Multi-agent swarm coordination |
| `formula` | Formula management |

### 6.9 Agent Coordination

| Command | Description |
|---------|-------------|
| `agent` | Agent lifecycle (`state`, `heartbeat`, `show`) |
| `slot` | Slot management (`set`, `clear`, `show`) |
| `state` | State management (`set-state`, `list`) |

### 6.10 Memory System

| Command | Description |
|---------|-------------|
| `remember` | Store a persistent memory (key-value in config table under `kv.memory.<slug>`) |
| `memories` | List all stored memories |
| `forget` | Delete a memory by key |
| `recall` | Retrieve a specific memory |

---

## 7. Key Commands in Detail

### 7.1 bd create

```
Use:     create [title]
Aliases: new
Args:    MinimumNArgs(0)  -- allows no args when using --file
```

**Notable flags (40+):**

| Flag | Description |
|------|-------------|
| `--file` / `-f` | Batch create from markdown file |
| `--title` | Alternative to positional argument |
| `--silent` | Output only the issue ID (scripting) |
| `--dry-run` | Preview without creating |
| `--priority` / `-p` | Priority 0-4 (supports "P1" format) |
| `--type` / `-t` | Issue type. Aliases: `enhancement`/`feat` -> `feature`, `dec`/`adr` -> `decision`, `mr` -> `merge-request` |
| `--description` / `-d` | Issue description |
| `--design` | Design notes |
| `--acceptance` | Acceptance criteria |
| `--notes` | Additional notes |
| `--assignee` / `-a` | Assignee username |
| `--labels` / `-l` | Labels (comma-separated) |
| `--id` | Explicit issue ID (e.g., `bd-42`) |
| `--parent` | Parent issue ID (generates hierarchical child ID) |
| `--no-inherit-labels` | Do not inherit labels from parent |
| `--deps` | Dependencies (`type:id` or bare `id`). Types: `blocks`, `related`, `parent-child`, `discovered-from` |
| `--waits-for` | Spawner issue ID for fanout gate dependency |
| `--waits-for-gate` | Gate type: `all-children` (default) or `any-children` |
| `--force` | Create even if prefix does not match database |
| `--repo` | Target repository (overrides auto-routing) |
| `--rig` | Create in a different rig (e.g., `--rig beads`) |
| `--prefix` | Create in rig by prefix (e.g., `--prefix bd-`) |
| `--estimate` / `-e` | Time estimate in minutes |
| `--ephemeral` | Ephemeral issue (subject to TTL compaction) |
| `--no-history` | Skip Dolt commit history (permanent agent beads) |
| `--mol-type` | Molecule type: `swarm`, `patrol`, `work` |
| `--wisp-type` | Wisp TTL type: `heartbeat`, `ping`, `patrol`, `gc_report`, `recovery`, `error`, `escalation` |
| `--validate` | Validate description sections against template |
| `--agent-rig` | Agent rig name (requires `--type=agent`) |
| `--event-category` | Event category (requires `--type=event`) |
| `--event-actor` | Event actor URI (requires `--type=event`) |
| `--event-target` | Event target URI (requires `--type=event`) |
| `--event-payload` | Event JSON data (requires `--type=event`) |
| `--due` | Due date. Formats: `+6h`, `+1d`, `+2w`, `tomorrow`, `next monday`, `2025-01-15` |
| `--defer` | Defer until date (hidden from `bd ready` until then). Same formats as `--due` |
| `--metadata` | Custom metadata JSON or `@file.json` to read from file |
| `--skills` | Required skills (appended to description) |
| `--context` | Additional context (appended to description) |
| `--spec-id` | Link to specification document |
| `--external-ref` | External reference (e.g., `gh-9`, `jira-ABC`) |

**Routing logic:**

1. If `--id` has a prefix matching a route in `routes.jsonl`, auto-routes to
   that rig's database.
2. If `--rig` or `--prefix` is set, opens the target rig's store directly via
   `routing.ResolveBeadsDirForRig()`.
3. Otherwise, detects user role via `routing.DetectUserRole()` and consults
   `routing.RoutingConfig` (mode, default repo, maintainer repo, contributor
   repo) to determine target repository.
4. If routed to a different repo, opens a separate store for the target,
   creates the issue there, and commits.

**Post-create operations:**

- Adds `parent-child` dependency if `--parent` was specified.
- Inherits labels from parent (unless `--no-inherit-labels`).
- Adds user-specified labels.
- Auto-adds `role_type:` and `rig:` labels for agent beads (when `gt:agent` label present).
- Adds dependencies from `--deps`.
- Adds `waits-for` dependency from `--waits-for`.
- Commits all post-create writes to Dolt.
- Runs create hook via `hookRunner`.
- Sets last-touched ID for implicit close.

### 7.2 bd ready

```
Use:   ready
Short: Show ready work (open, no active blockers)
```

**Key semantics:** Uses `store.GetReadyWork()` which applies blocker-aware
semantics (dependency graph traversal). This is fundamentally different from
`bd list --status open` which only checks the stored status field.
`GetReadyWork` excludes issues that are transitively blocked by open
dependencies, even if their own status is "open".

**Flags:**

| Flag | Default | Description |
|------|---------|-------------|
| `--limit` / `-n` | 10 | Maximum issues to return |
| `--priority` / `-p` | 0 | Filter by priority (supports P0 via `Changed()`) |
| `--assignee` / `-a` | `""` | Filter by assignee |
| `--unassigned` / `-u` | false | Only unassigned issues |
| `--sort` / `-s` | `"priority"` | Sort: `priority`, `hybrid`, `oldest` |
| `--label` / `-l` | `[]` | Labels filter (AND: must have ALL) |
| `--label-any` | `[]` | Labels filter (OR: must have at least one) |
| `--type` / `-t` | `""` | Issue type filter |
| `--mol` | `""` | Filter to steps within a specific molecule |
| `--parent` | `""` | Filter to descendants of this epic/bead |
| `--mol-type` | `""` | Molecule type: `swarm`, `patrol`, `work` |
| `--pretty` | true | Tree format with status/priority symbols |
| `--plain` | false | Plain numbered list |
| `--include-deferred` | false | Include deferred issues |
| `--include-ephemeral` | false | Include ephemeral issues (wisps) |
| `--gated` | false | Find molecules ready for gate-resume dispatch |
| `--rig` | `""` | Query a different rig's database |
| `--metadata-field` | nil | Filter by metadata key=value (repeatable) |
| `--has-metadata-key` | `""` | Filter issues with this metadata key set |

**Directory-aware label scoping:** When no labels are explicitly provided,
checks `config.GetDirectoryLabels()` for directory-level label defaults
(GH#541).

**JSON output:** Returns `[]*IssueWithCounts` with labels, dependencies,
dependency counts, comment counts, and computed parent.

### 7.3 bd close / bd done

```
Use:     close [id...]
Aliases: done
Args:    MinimumNArgs(0)  -- closes last-touched if no ID given
```

**Flags:**

| Flag | Description |
|------|-------------|
| `--reason` / `--resolution` / `-m` / `--comment` | Close reason (default: "Closed") |
| `--force` | Force close even with open children |
| `--continue` | Advance to next molecule step |
| `--no-auto` | Skip automatic follow-up actions |
| `--suggest-next` | Suggest next ready issue after closing |
| `--claim-next` | Auto-claim next ready issue |
| `--session` | Session ID (falls back to `$CLAUDE_SESSION_ID`) |

**Desire-path:** `bd done <id> <message>` treats the last positional argument
as the reason when no reason flag was provided.

**Close guards:**

1. **Gate satisfaction** -- If the issue has gate dependencies (`gh:pr`,
   `gh:run`, `timer`, `bead`), verifies the gate condition is met.
2. **Epic close guard** -- Rejects closing an epic with open children unless
   `--force` is set.
3. **Blocker check** -- Warns if closing an issue that blocks other open issues.

### 7.4 bd list

```
Use:   list
Short: List issues with optional filters
```

The most flag-rich command in the CLI (50+ flags). Default behavior excludes
closed, pinned, gate, and infra-type issues.

**Key flags:**

| Flag | Description |
|------|-------------|
| `--tree` | Tree display (default) |
| `--watch` | 2-second polling refresh |
| `--format` | Output format: `digraph`, `dot`, `template` |
| `--parent` | Filter to descendants (recursive, max depth 10) |
| `--all` | Include closed issues |
| `--status` | Filter by status |
| `--type` | Filter by issue type |
| `--assignee` | Filter by assignee |
| `--labels` | AND label filter |
| `--label-any` | OR label filter |
| `--sort` | Sort field |
| `--reverse` | Reverse sort order |
| `--long` | Extended output with descriptions |

**JSON output:** Returns `[]*IssueWithCounts`.

### 7.5 bd query

```
Use:   query [expression]
Short: Query issues using a simple query language
```

AST-based query language parsed by `internal/query.Parse()`.

**Operators:** `=`, `!=`, `>`, `>=`, `<`, `<=`

**Boolean operators (case-insensitive):** `AND`, `OR`, `NOT`, `()`

**Supported fields:**

| Field | Description |
|-------|-------------|
| `status` | Stored status (open, in_progress, blocked, deferred, closed) |
| `priority` | Priority level 0-4 |
| `type` | Issue type |
| `assignee` | Assigned user (`"none"` for unassigned) |
| `owner` | Issue owner |
| `label` | Issue label (`"none"` for unlabeled) |
| `title` | Contains search |
| `description` | Contains search (`"none"` for empty) |
| `notes` | Contains search |
| `created` | Creation timestamp |
| `updated` | Last update timestamp |
| `closed` | Close timestamp |
| `id` | Issue ID (supports wildcards: `bd-*`) |
| `spec` | Spec ID (supports wildcards) |
| `pinned` | Boolean |
| `ephemeral` | Boolean |
| `template` | Boolean |
| `parent` | Parent issue ID |
| `mol_type` | Molecule type |

**Date values:**

- Relative durations: `7d` (7 days ago), `24h` (24 hours ago), `2w` (2 weeks ago)
- Absolute dates: `2025-01-15`, `2025-01-15T10:00:00Z`
- Natural language: `tomorrow`, `"next monday"`, `"in 3 days"`

**Examples:**

```
bd query "status=open AND priority>1"
bd query "(status=open OR status=blocked) AND priority<2"
bd query "type=bug AND label=urgent"
bd query "NOT status=closed"
bd query "assignee=none AND type=task"
bd query "created>30d AND status!=closed"
```

**Flags:** `--limit`, `--all`, `--long`, `--sort`, `--reverse`, `--parse-only`
(show parsed AST without executing).

### 7.6 bd flatten

```
Use:   flatten
Short: Squash all Dolt history into a single commit
```

Nuclear option. Implements the Tim Sehn recipe:

1. Create branch `flatten-tmp` from current state
2. Checkout `flatten-tmp`
3. `dolt reset --soft <initial-commit-hash>` (preserves all data in working set)
4. `dolt add .` + `dolt commit` (single snapshot commit)
5. Checkout `main`
6. `dolt reset --hard flatten-tmp` (swap main to flattened)
7. `dolt branch -D flatten-tmp` (cleanup)
8. `dolt gc` (reclaim space from old history)

Irreversible. All commit history is lost. Requires `--force` to execute
(without it, only previews commit count and disk usage).

### 7.7 bd gc

```
Use:   gc
Short: Garbage collect: decay old issues, compact Dolt commits, run Dolt GC
```

Three phases in sequence:

1. **DECAY** -- Delete closed issues older than N days (default 90). Skips
   pinned issues. Filterable via `--older-than`.
2. **COMPACT** -- Report Dolt commit count (delegates to `bd compact` for
   squashing old commits).
3. **DOLT GC** -- Run `dolt gc` subprocess to reclaim disk space. Measures
   freed space.

**Flags:** `--dry-run`, `--force`, `--older-than <days>`, `--skip-decay`,
`--skip-dolt`.

### 7.8 bd remember / memories / forget / recall

Persistent key-value memory system stored in the config table under
`kv.memory.<slug>` keys.

- `bd remember "<insight>"` -- Stores a memory. Auto-generates a URL-friendly
  slug from the first ~8 words of the content (lowercased, non-alphanumeric
  replaced with hyphens, capped at 60 chars). Override with `--key`.
- `bd memories` -- Lists all stored memories.
- `bd forget <key>` -- Deletes a memory.
- `bd recall <key>` -- Retrieves a specific memory.

Memories are injected at prime time (`bd prime`) so agents have them in every
session without manual loading.

---

## 8. Auto-Commit System

Controlled by `--dolt-auto-commit` flag or `dolt.auto-commit` config key.

### Modes:

| Mode | Behavior |
|------|----------|
| `off` | Default. No automatic Dolt commits. Changes go to working set. |
| `on` | After each write command, creates a Dolt commit via `DOLT_COMMIT -Am`. |
| `batch` | Defers commits. Changes accumulate in the working set until explicit `bd dolt commit`. |

### Implementation:

- `commandDidWrite` is an `atomic.Bool` set by any command that performs a write.
- `commandDidExplicitDoltCommit` prevents redundant auto-commit when the command
  already committed (e.g., transactional operations).
- In `PersistentPostRun`, if `commandDidWrite` is true and no explicit commit
  was made, `maybeAutoCommit()` fires.
- In batch mode, `SIGTERM`/`SIGHUP` handlers call `flushBatchCommitOnShutdown()`
  which uses a fresh context with 5-second timeout to call `store.CommitPending()`.

### Commit message format:

Generated by `formatDoltAutoCommitMessage()`:
```
bd: <command> by <actor> [<issue-ids>]
```

---

## 9. Auto-Push System

Automatically pushes to the Dolt remote named `origin` after write commands.

### State tracking:

State file: `.beads/push-state.json` (local file, not in Dolt, to avoid merge
conflicts on multi-machine setups -- GH#2466).

```json
{
  "last_push": "2026-03-17T10:30:00Z",
  "last_commit": "abc123def456..."
}
```

### Enable logic:

- If `dolt.auto-push` is explicitly configured, uses that value.
- Otherwise, auto-enables when a Dolt remote named `origin` exists.

### Debounce:

5-minute minimum interval between pushes. Change detection compares the current
Dolt commit hash against the last-pushed hash.

### Skipped for:

- Read-only commands (GH#2191)
- When store is closed or nil
- When no remote named `origin` exists

---

## 10. Config System

Three-tier configuration with layered precedence.

### Tier 1: YAML Config Files

Read by viper before the database is opened. Precedence (highest to lowest):

| Priority | Location | Notes |
|----------|----------|-------|
| Highest | `$BEADS_DIR/config.yaml` | Env var override |
| High | `.beads/config.yaml` (project) | Walk up from CWD |
| Medium | `~/.config/bd/config.yaml` | XDG user config |
| Low | `~/.beads/config.yaml` | Legacy user config |

Additionally, `config.local.yaml` is merged on top of the primary project-level
config file, allowing gitignored local overrides.

Environment variable prefix: `BD_`. All config keys are available as `BD_<KEY>`
(dots replaced with underscores, uppercased).

**YAML-only keys** (must be in YAML because they are read before DB opens):

- `routing.mode`, `routing.default`, `routing.maintainer`, `routing.contributor`
- `sync.git-remote`
- `dolt.auto-commit`, `dolt.auto-push`
- `issue-prefix`
- `json` (default output format)
- `readonly`
- Various `create.*`, `validation.*`, `hints.*` keys

### Tier 2: Git Config

The `beads.role` key is stored in git config (`git config beads.role`), used for
contributor/maintainer routing detection.

### Tier 3: Database Config Table

Stored in the `config` table within the Dolt database. Accessed via
`store.GetConfig()` / `store.SetConfig()`. Used for:

- `issue_prefix` -- The prefix for generated issue IDs
- `allowed_prefixes` -- Comma-separated list of allowed prefixes
- `status.custom` -- Custom status states
- `types.custom` -- Custom issue types
- `doctor.suppress.*` -- Suppress specific doctor warnings
- `jira.*`, `linear.*`, `github.*`, `gitlab.*` -- Integration settings
- `kv.*` -- Key-value storage (memories, etc.)

### Config Commands:

```
bd config set <key> <value>
bd config get <key>
bd config list
bd config unset <key>
bd config validate
```

YAML-only keys are automatically routed to `config.SetYamlConfig()` instead of
the database.

---

## 11. metadata.json Schema

Located at `.beads/metadata.json`. The canonical marker for an initialized beads
directory. Managed by `internal/configfile/`.

```json
{
  "database": "beads.db",
  "dolt_mode": "embedded",
  "dolt_server_host": "127.0.0.1",
  "dolt_server_port": 3307,
  "dolt_server_user": "root",
  "dolt_database": "beads",
  "dolt_server_tls": false,
  "dolt_data_dir": "",
  "dolt_remotesapi_port": 8080,
  "project_id": "550e8400-e29b-41d4-a716-446655440000",
  "stale_closed_issues_days": 0,
  "deletions_retention_days": 3
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `database` | string | `"beads.db"` | Database filename |
| `dolt_mode` | string | `"embedded"` | `"embedded"` (in-process) or `"server"` (external SQL server) |
| `dolt_server_host` | string | `"127.0.0.1"` | Server hostname |
| `dolt_server_port` | int | `3307` | MySQL-compatible port |
| `dolt_server_user` | string | `"root"` | MySQL user |
| `dolt_database` | string | `"beads"` | SQL database name |
| `dolt_server_tls` | bool | `false` | Enable TLS (required for Hosted Dolt) |
| `dolt_data_dir` | string | `""` | Custom Dolt data directory (absolute path; default: `.beads/dolt`) |
| `dolt_remotesapi_port` | int | `8080` | Dolt remotesapi port for federation |
| `project_id` | string | UUID v4 | Generated at `bd init` time. Used for workspace identity validation |
| `stale_closed_issues_days` | int | `0` | Threshold for stale closed issue warnings (0 = disabled) |
| `deletions_retention_days` | int | `3` | How long to keep soft-deleted issues before hard purge |

Password is set via `BEADS_DOLT_PASSWORD` env var (not stored in JSON for
security).

---

## 12. Graceful Shutdown

Signal handling in `setupGracefulShutdown()`:

1. Listens for `SIGINT`, `SIGTERM`, `SIGHUP` on a buffered channel.
2. On first signal: calls `flushBatchCommitOnShutdown()` (commits pending batch
   writes with 5-second timeout), then cancels the root context.
3. On second signal: calls `os.Exit(1)` immediately.
4. When the context is done (normal exit), stops signal notification.

This ensures that long-running batch operations (e.g., molecule execution with
dozens of creates) do not lose uncommitted work when the process receives a
termination signal.

---

## 13. Owner Attribution

Separate from actor (who executed the command), owner tracks the human
responsible for an issue. Used for HOP CV (curriculum vitae) chains.

Priority: `$GIT_AUTHOR_EMAIL` > `git config user.email` > `""` (empty).

Set automatically on `bd create` via `getOwner()`.
