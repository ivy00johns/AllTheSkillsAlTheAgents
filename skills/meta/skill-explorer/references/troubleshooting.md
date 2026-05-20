# Skill Troubleshooting Taxonomy

Named symptoms for "why isn't my skill behaving correctly?", drawn from Anthropic's guide (Chapter 5, p.25-27). Use this reference when the user asks why a skill won't fire, fires too often, ignores its instructions, or seems slow. Each symptom below pairs a recognizable observation with its common causes and a concrete fix sequence.

## How to Use This Reference

When a user describes a skill problem, match it to one of the symptoms below by what they observe — not by what they think the cause is. Users frequently misdiagnose ("the description must be wrong") when the real cause is a different symptom ("the skill is actually firing, but its instructions are too vague to follow"). Confirm the symptom first, then walk the fix.

## Symptom: Skill Won't Upload / Sync

**What it looks like:** the skill never appears in the available-skills list. Sync, upload, or registration silently skips it, or errors with a parser complaint.

**Common causes:**

- The file is not named exactly `SKILL.md` (case-sensitive — `Skill.md`, `skill.md`, and `SKILL.MD` are all wrong)
- YAML frontmatter is malformed: missing `---` delimiters at top or bottom, unclosed quotes, bad indentation
- `name` field violates the spec: contains spaces, uppercase letters, or starts with the reserved prefix `claude-` or `anthropic-`
- File is inside a folder whose name violates the same rules

**Fix:**

1. Verify the filename is exactly `SKILL.md`
2. Open the file and confirm the frontmatter starts with `---` on its own line and ends with `---` on its own line
3. Run a YAML linter (or paste into a YAML validator) to catch unclosed quotes or indentation errors
4. Confirm the `name` field is kebab-case and not reserved
5. Re-run the sync or upload

## Symptom: Skill Doesn't Trigger

**What it looks like:** the user describes a task the skill should handle, but the model handles it itself or picks a different skill. The skill exists, syncs cleanly, but never fires.

**Common causes:**

- Description is too vague: "Helps with projects", "Assists with development" — these give the model no anchor
- Description is missing the trigger phrases users actually say (the description talks about "code review" but the user always says "review my PR")
- Description omits file-type mentions when the skill is file-type-specific (a `.tsx`-focused skill should name `.tsx`)
- Description leads with the mechanism instead of the outcome ("Uses Playwright to..." vs. "Test the UI in a real browser to...")

**Fix:**

1. Ask Claude: "When would you use the `[skill-name]` skill?" — the answer is essentially a paraphrase of the description, which makes the gap visible
2. Compare the answer against the actual phrases the user types — note any missing keywords
3. Rewrite the description leading with the outcome and the trigger phrases (see `../../skill-writer/references/description-patterns.md`)
4. Re-test with the exact phrases the user uses

## Symptom: Skill Triggers Too Often

**What it looks like:** the skill fires on tasks it has no business handling — adjacent topics, unrelated requests that share a keyword.

**Common causes:**

- Description is too broad ("Handles anything related to files" matches everything)
- No negative trigger ("Do NOT use for X") to bound the scope
- Missing specificity — the description should pin down the file types, contexts, or stages where the skill applies

**Fix:**

1. List the false-positive cases — what tasks is it firing on that it shouldn't?
2. Identify the keyword causing the over-match
3. Either narrow the description (replace "files" with "TypeScript files in `src/`") or add an explicit negative trigger ("Do NOT use for plain-text docs or markdown")
4. Re-test on both the true-positive and the false-positive cases

## Symptom: Instructions Not Followed

**What it looks like:** the skill triggers, but the model ignores parts of the body — skips steps, invents its own workflow, doesn't run the validation script.

**Common causes:**

- Instructions are too verbose — long prose buries the imperative
- Critical instructions are buried in the middle or at the bottom (the model weighs the top of the body more heavily)
- Language is ambiguous: "validate properly", "review carefully" — these don't name an action
- No `## Important` / `## Critical` header to flag must-do items

**Fix:**

1. Move critical instructions to the top of the body, directly under the title
2. Use `## Important` or `## Critical` headers to mark non-skippable steps
3. Rewrite ambiguous prose as imperative bullets ("Run `npm test` and confirm zero failures")
4. Trim verbose paragraphs — bullets and tables outperform prose for instructions
5. If the skill is long-running and the model is cutting corners, add a `## Performance Notes` block (see `../../skill-writer/references/performance-notes-pattern.md`)

## Symptom: MCP Connection Issues

**What it looks like:** the skill references an MCP tool and fails with "tool not found", "unauthorized", or silent no-ops. Only applies to skills that integrate with an MCP server.

**Common causes:**

- The MCP server is not connected in the current session
- Authentication has expired or never completed
- The tool name in SKILL.md doesn't match the actual MCP tool name (case-sensitivity matters)
- The MCP server is connected but the specific tool the skill calls is not exposed

**Fix:**

1. Confirm the MCP server is listed in the current session's available tools
2. Test the MCP tool independently of the skill — call it directly to confirm auth and connectivity
3. Compare the tool name in SKILL.md against the actual tool name byte-for-byte
4. If auth expired, re-run the MCP authentication flow
5. If the tool genuinely isn't exposed, either expose it on the server or document an alternate workflow in the skill

## Symptom: Large Context Issues

**What it looks like:** the skill is slow, responses feel degraded, or the model seems to be losing track of details mid-task.

**Common causes:**

- SKILL.md body is too large (well past the 500-line soft warning)
- Too many skills are enabled simultaneously and all of their metadata is loading
- Reference files are being inlined into the body instead of being read on demand
- The skill is loading all of `references/` up front instead of pointing the model at specific files

**Fix:**

1. Move detailed content from the body into `references/` and link rather than inline
2. Audit the body for content that's only needed in edge cases — push it to a reference
3. Recommend the user disable skills they aren't actively using (selective enablement)
4. In the body, name the specific reference file the model should read for each sub-task ("For the full validation procedure, read `references/validation-checklist.md`") instead of "see references"
