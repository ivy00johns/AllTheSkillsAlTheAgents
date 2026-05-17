# The Process — Phases In Detail

Detailed instructions for each of the four phases of a deep dive.

## Phase 1: Orient

Read the Deep Research document first. Extract:

- What the project is and why it exists
- Key architectural claims to verify against the code
- Community perception vs. what the code actually does
- The project's position in its ecosystem/landscape

Then gather hard numbers from the repo:

```bash
# Lines of code by language
find <repo> -type f \( -name "*.ts" -o -name "*.go" -o -name "*.py" -o -name "*.rs" \) | xargs wc -l 2>/dev/null | tail -1
# Or use tokei/cloc/scc if available

# Git stats
git -C <repo> log --oneline | wc -l          # commits
git -C <repo> shortlog -sn | head -5          # top contributors
git -C <repo> log --format=%ai | tail -1       # first commit
ls <repo>/src/**/*.{ts,go,py,rs} 2>/dev/null | wc -l  # source files
```

These numbers go into the "By the Numbers" table in `01-project-overview.md`. Be precise — the stats anchor the entire deep dive and readers trust them.

## Phase 2: Map the Architecture

Start from the entry points and trace inward:

- CLI entry point (main.go, index.ts, __main__.py, etc.)
- How commands route to subsystems
- The data model (schemas, types, database tables)
- How components communicate (IPC, messages, shared state, events)

Use parallel subagents when possible — dispatch 3-4 agents to explore different subsystems simultaneously. Each agent traces one major area:

```text
Agent 1: Data model + storage layer
Agent 2: Core business logic / engine
Agent 3: CLI + external interfaces
Agent 4: Agent/worker/plugin system (if applicable)
```

The goal is a mental model of the architecture that you can explain in ~200 lines of markdown, with a mermaid diagram (using the `mermaid-charts` skill) showing how the major pieces connect.

## Phase 3: Deep Dive Each Subsystem

For each major subsystem (typically 6-10), produce a focused document covering:

- **What it does** — purpose and responsibilities
- **How it works** — key data structures, algorithms, patterns
- **Key files** — where to look in the code (with paths)
- **Design decisions** — why it's built this way, not another way
- **Gotchas** — non-obvious behavior, edge cases, known issues

Read the actual code. Don't summarize from comments or READMEs alone — trace execution paths, read the tests, look at error handling. The value of a deep dive is discovering what the docs don't tell you.

## Phase 4: Compare and Assess

The final 2-3 documents provide the strategic view:

**Comparison document** — How does this project compare to a reference project (typically the user's own project or another tool in the same domain) and any other projects in the analysis scope? Ask the user which reference project to compare against if it isn't obvious. Use a table format:

| Dimension | This Project | Reference Project | Notes |
|-----------|-------------|-------------------|-------|
| Scale     | Xk LoC      | Yk LoC            | ...   |

Focus on what each project has that the other lacks — this is where the insight lives.

**Convergence/frontier document** — What is genuinely novel here? What is table stakes? What would a combined system look like? This is the document that makes the deep dive worth doing — it surfaces the ideas worth stealing and the integration opportunities worth pursuing.
