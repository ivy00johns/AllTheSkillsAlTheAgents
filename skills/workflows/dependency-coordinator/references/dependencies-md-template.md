# DEPENDENCIES.md Template

Template for the `DEPENDENCIES.md` file the `dependency-coordinator` skill emits at workspace root. Fill in placeholders and ship alongside the root `package.json`.

```markdown
# Workspace Dependency Policy

This file documents the version pinning policy for the {{PROJECT_NAME}} monorepo. All workspace packages inherit these pins via the root manifest's overrides/resolutions block. Implementation agents working in `apps/*` or `packages/*` MUST follow this policy.

## Pinned versions

| Dependency | Pin | Rationale | Set on |
|---|---|---|---|
| `<dep-name>` | `<exact-or-range>` | <one-sentence reason — usually "most demanding consumer pins this version" or "compatibility with X" or "incident on YYYY-MM-DD"> | YYYY-MM-DD |

## Per-package boundaries

| Package | Owns deps for | Cannot modify (inherited from root) |
|---|---|---|
| `apps/api` | fastify, route plugins, app-level deps | esbuild, typescript, @types/node, zod |
| `apps/web` | react, vite-plugin-*, ui deps | esbuild, typescript, @types/node, zod |
| `packages/contracts` | zod (allowed — used as primary export), schema deps | typescript |
| ... | ... | ... |

## Escalation procedure

If an agent needs a dep that conflicts with a pinned version:

1. **Don't modify the root manifest.** That's not the agent's role.
2. Surface the conflict to the orchestrator with: which dep, which version is needed, why the current pin doesn't work.
3. The orchestrator either updates the pin (with a new entry in this file) or rejects the new dep in favor of an alternative.
4. The orchestrator updates `dependency-coordinator`'s output and re-dispatches affected agents with new templates.

## Migration playbook (bumping a pin)

When a pin needs to bump (security advisory, new feature required by a consumer):

1. **Verify the new version satisfies every current consumer** by running `pnpm why <dep>` (or equivalent) and checking each consumer's range.
2. Update the root manifest's overrides block.
3. Run `pnpm install --frozen-lockfile=false` to regenerate the lockfile.
4. Run `pnpm -r run typecheck && pnpm -r run test` to verify no consumer broke.
5. Append a new row to the "Pinned versions" table above with the new pin, rationale, and date.
6. Commit as `chore(deps): bump <dep> from <old> to <new> — <rationale>`.

## Why this file exists

Five parallel agents writing independent package manifests produced a real production failure during the Bazaar build (2026-04-30): conflicting transitive esbuild versions caused `pnpm install` to error during postinstall. The fix was a `pnpm.overrides` block — but reactive. This file makes the policy proactive and auditable. See `docs/qa/skill-ecosystem-audit-2026-04-30.md` finding F-2 for the full incident.
```
