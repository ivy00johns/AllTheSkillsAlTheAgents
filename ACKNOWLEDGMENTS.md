# Acknowledgments

This project's multi-tool installer (`scripts/convert.sh`, `scripts/install.sh`,
and helpers under `scripts/lib/`) was informed by, and in places adapts code
from, the following upstream project. We're grateful for their work.

## msitarzewski/agency-agents

- **Repository:** https://github.com/msitarzewski/agency-agents
- **License:** MIT
- **Copyright:** Copyright (c) 2025 AgentLand Contributors

The 11-tool installer pattern (Claude Code, Copilot, Antigravity, Gemini CLI,
OpenCode, OpenClaw, Cursor, Aider, Windsurf, Qwen, Kimi) and the
canonical-source → per-tool-converter → installer pipeline architecture
originated in agency-agents. The following pieces in this repository were
adapted directly and remain close to the originals:

- The six `detect_<tool>()` one-liners in `scripts/install.sh` that probe for
  each tool's CLI or config directory.
- The terminal-redraw helper used in the interactive selection UI of
  `scripts/install.sh`.
- The `get_body()` awk script for stripping YAML frontmatter, in
  `scripts/lib/frontmatter.sh`.
- The `slugify()` pipeline (lowercase → non-alphanumeric to hyphen → collapse →
  trim) in `scripts/lib/slug.sh`.
- The split of an agent body into "soul" (persona/rules) and "agents"
  (capabilities) sections in `convert_openclaw()`, including the keyword set
  used to classify section headers.

Other parts of the installer — the Python YAML implementation of `get_field()`,
the `inline_references` mechanism, the `lib/{platform,term,frontmatter}.sh`
helpers, the lint script, and most per-tool converter bodies — are independent
implementations.

### MIT License (agency-agents)

```
MIT License

Copyright (c) 2025 AgentLand Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
