# Audit: security-agent

**Path:** skills/roles/security-agent/SKILL.md
**Version:** 1.1.0
**Category:** roles
**Verdict:** SHIP

## Scores

| Dimension | Score | Notes |
|---|---|---|
| Frontmatter compliance | 4 | All required fields. Semver valid. owns block has tight ownership (`.github/security/`, `SECURITY.md`) — appropriate for a read-only audit role. shared_read uses `*` which makes sense for an audit agent. No compatibility/metadata. Field order: disable-model-invocation before description (OK). |
| Description quality | 3 | 235 chars over 200 target. Action verbs ("Audits", "reviews", "verifies"). Three trigger contexts. Intentionally narrow ("Orchestrator-dispatched only"). Lacks keyword variants. |
| Progressive disclosure | 5 | Body 153 lines — within 150 line target. references/owasp-checklist.md 82 lines, well-organized by A01-A10. Body links references at lines 88 and 150 with explicit when-to-read. |
| Instruction clarity | 5 | Imperative voice. Numbered Process 0–6 with concrete bash commands. Step 6 includes a template for the security report. Explains the boundary with QE (line 145) and code-review-agent (line 146) — clearest role-boundary explanation across the role agents. |
| Coordination | 5 | Owns tight and non-conflicting (`.github/security/`, `SECURITY.md`). Read-only across the whole tree explicit. `composes_with` lists 5 collaborators all exist. Strong coordination rules at lines 145–146 distinguish static analysis (security) from runtime (QE) from quality (code-review). |
| Completeness | 5 | references/owasp-checklist.md exists and covers A01-A10 thoroughly. Step 0 Read Contracts present. Off-limits explicit. Template for security report in step 6. Severity reporting structure clear. |
| Anti-patterns | 5 | Clean. No hardcoded paths. WHY explained for boundaries. No emojis. |

**Average:** 4.6

## Findings

### Critical (must fix to ship)

None.

### Important (should fix)

- Description 235 chars exceeds 200-char target — SKILL.md:5 — drop redundant "Composed by orchestrator during multi-agent builds" clause.
- Missing `compatibility` string — SKILL.md frontmatter — add `compatibility: "Claude Code; requires Bash + npm/pip/govulncheck for dependency audits"`.
- Self-referential pipeline blockquote — SKILL.md:20 — "Reports to `qe-agent` via `qa-report.json`" is template-bleed; security-agent writes a security report, not qa-report.json. Reword to "Findings feed into `qe-agent`'s `security` score dimension".

### Nits (won't block ship)

- No `metadata` block.
- "Right-sizing" section not explicit — body doesn't say "skip OWASP review for prototype builds" or similar. Could add a tradeoff blockquote.
- Validation section just says "Run through owasp-checklist" — could enumerate the gate criteria more explicitly (e.g., "PASS required on A01, A02, A03, A06 for ship").
- Severity report template at line 116-137 uses inline `[bracket-placeholders]` mixed with fenced markdown — slightly off-style vs. `${PLACEHOLDER}` convention used elsewhere.

## Top 3 Concrete Fixes (rank order, with diff direction)

1. Fix self-referential pipeline blockquote — SKILL.md:20 — replace "Reports to `qe-agent` via `qa-report.json`" with "Findings feed into `qe-agent`'s `security` score dimension". Effort: small.
2. Tighten description to ≤200 chars — SKILL.md:5 — drop "Composed by orchestrator during multi-agent builds". Effort: small.
3. Add `compatibility` field — SKILL.md frontmatter — declare audit-tool requirements. Effort: small.

## Dead links / broken references

None. `references/owasp-checklist.md` exists. All `composes_with` targets exist as directories.
