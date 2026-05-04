
## Overview

This fixture skill exists to test the references handling contract. It ships with two reference files in its references/ directory: guide.md and glossary.md.

## Reference Handling Matrix

Different tools treat the references directory differently. The test suite verifies the following behaviors:

- **Copy alongside:** claude-code, antigravity, gemini-cli, opencode, openclaw, copilot copy references/ next to SKILL.md
- **Inline bundle:** cursor, qwen, kimi append each reference file under a Reference header in the body
- **Skip:** aider and windsurf skip references and emit a stderr note per skill

## Why This Matters

Reference files can be large. The inline-bundle strategy is used by project-scoped tools where a directory layout is impractical. The skip strategy prevents the consolidated aider and windsurf single-file outputs from becoming unmanageable.

> Additional context: see references/
