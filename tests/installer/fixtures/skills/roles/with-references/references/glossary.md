# With-References Glossary

This is reference file two: glossary.md. It provides a glossary of terms for the with-references fixture skill.

## Terms

**copy-alongside:** The converter copies the entire references/ directory next to the per-skill output file. Used by claude-code, antigravity, gemini-cli, opencode, openclaw, and copilot.

**inline-bundle:** The converter reads each reference file and appends its content to the body under a `## Reference: <filename>` header. Used by cursor, qwen, and kimi.

**skip:** The converter ignores references entirely and emits a stderr note. Used by aider and windsurf to prevent file bloat.
