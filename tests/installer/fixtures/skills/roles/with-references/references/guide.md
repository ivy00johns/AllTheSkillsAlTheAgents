# With-References Guide

This is reference file one: guide.md. It documents how to use the with-references fixture skill.

## Usage

Point convert.sh at the fixtures/skills/ directory with --out pointing to a temp dir. Then check that each tool's output directory either contains a references/ subdirectory or has the content of this file inlined.

## Verification

For cursor, qwen, and kimi: look for the line `## Reference: guide` followed by this file's content. For aider and windsurf: look for a stderr line containing `skipped references for with-references`.
