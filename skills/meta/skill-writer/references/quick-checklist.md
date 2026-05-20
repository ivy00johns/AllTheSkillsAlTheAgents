# Quick Checklist

Run this before declaring a skill done. Mirrors Anthropic's Reference A "Quick checklist" (page 30 of "The Complete Guide to Building Skills for Claude"). Terse on purpose — if you want the "why", see the other references.

## Before You Start

- [ ] Identified 2-3 concrete use cases the skill must handle
- [ ] Identified the tools the skill needs (built-in: Read/Write/Edit/Bash/Grep/Glob; or MCP)
- [ ] Reviewed the frontmatter spec (`references/frontmatter-spec.md`) and at least one example skill in the same category
- [ ] Planned the folder structure (SKILL.md + which references / scripts you'll need)

## During Development

- [ ] Folder named in kebab-case
- [ ] Folder name does NOT start with `claude-` or `anthropic-` (reserved prefixes)
- [ ] `SKILL.md` file exists at the folder root, spelled exactly that way (case-sensitive)
- [ ] YAML frontmatter is delimited by `---` on its own line at top and bottom
- [ ] `name` field is kebab-case and ≤64 characters
- [ ] `description` includes both WHAT the skill does and WHEN to trigger it
- [ ] `description` is ≤200 characters (target) and never exceeds 1024 characters (ceiling)
- [ ] No `<` or `>` characters anywhere in frontmatter
- [ ] Body instructions are clear and actionable (imperative voice, numbered steps)
- [ ] Error handling included (`## Troubleshooting` or equivalent)
- [ ] At least one concrete example provided (User says / Actions / Result)
- [ ] All reference files are linked from the body with guidance on when to read them

## Before Sync (or Upload)

- [ ] Tested triggering on an obvious task ("create a skill" should fire `skill-writer`)
- [ ] Tested triggering on a paraphrased request ("I need a new agent role" should also fire `skill-writer`)
- [ ] Verified the skill does NOT trigger on unrelated topics (false-positive check)
- [ ] Functional checks pass — the skill actually produces the documented output when invoked
- [ ] Tool integration works (any MCP or shell command referenced in the body actually runs)
- [ ] No orphan reference files (every file in `references/` is linked from SKILL.md or another reference)
- [ ] Body is ≤5,000 words (or has explicit justification at the top if longer)

## After Sync

- [ ] Tested in real conversations, not just synthetic prompts
- [ ] Monitored for under-triggering (skill should have fired but didn't)
- [ ] Monitored for over-triggering (skill fired when it shouldn't have)
- [ ] Collected feedback from real use (your own or teammates')
- [ ] Iterated on the description first when triggering is wrong (description is the primary signal)
- [ ] Iterated on the body when behavior-once-triggered is wrong
- [ ] Bumped the `version` in frontmatter when shipping any user-visible change
