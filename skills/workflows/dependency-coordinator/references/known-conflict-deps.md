# Known Conflict-Prone Transitive Dependencies

Reference table for the `dependency-coordinator` skill. Lists shared transitives that frequently cause cross-package version drift in real-world monorepos, with the version each ecosystem typically wants and the recommended pin to resolve conflicts.

Update this list as new conflicts are discovered. Cite source PRs/issues where possible.

## TypeScript / Node.js (pnpm / npm / yarn)

| Dep | Pulled by | Common drift | Recommended pin (2026-Q2) | Rationale |
|---|---|---|---|---|
| `esbuild` | vite, drizzle-kit, vitest, tsx, @vercel/* | 0.19 (drizzle-kit ~0.24) vs 0.21 (vite ^5.4) vs 0.25 (some chains) | `0.21.5` | Compatible with vite 5.4 (most demanding consumer); drizzle-kit and vitest accept it via their loose ranges. |
| `typescript` | every package's devDeps | 5.0 vs 5.4 vs 5.5 vs 5.7 | `^5.5.0` | Stable enough to land in most projects; lower bounds avoid breaking changes from 5.0 era. |
| `@types/node` | every Node devDep | 18 vs 20 vs 22 | `^20.0.0` | Matches Node 20 LTS; avoids the v18 TextDecoder/v22 ESM gotchas. |
| `@types/react` / `@types/react-dom` | react devDeps | 18 vs 19 (drift creates phantom JSX type errors) | match major to react version | Pin both together; never mismatch majors. |
| `zod` | @anthropic-ai/sdk (peers ^3.25 \|\| ^4), trpc (^3 only), various validators | 3.23 vs 3.24 vs 3.25 vs 4.0 | `3.25.0` (or `4.0.0` if no v3-only consumers) | Most modern Anthropic SDKs require ^3.25; if a peer wants strict v3, pin to 3.25 highest patch. |
| `react`/`react-dom` | UI packages | 18 vs 19 | `^18.3.0` (or `^19.0.0` if all consumers updated) | Pin together with @types/react. |
| `eslint` | dev tooling | 8 vs 9 (flat config break) | `^9.0.0` for greenfield, `^8.57.0` for projects with non-flat configs | Migration cost is non-trivial; check existing configs first. |
| `prettier` | dev tooling | 2 vs 3 (trailing-comma default change) | `^3.0.0` | Greenfield projects only; existing codebases need a one-time format pass to migrate. |
| `tslib` | TS helpers | minor versions occasionally drift | `^2.6.0` | Rare conflict source but worth a pin for fully reproducible builds. |
| `undici` | fetch polyfill | drifts wildly across @anthropic-ai/sdk, openai, googleapis | leave unpinned unless you see test flakiness | Most consumers vendor it internally; pinning often breaks more than it fixes. |

### Vite-specific

| Dep | Pulled by | Pin |
|---|---|---|
| `rollup` | vite | match what vite wants (don't override unless you see drift) |
| `postcss` | vite, tailwindcss | `^8.4.0` |
| `autoprefixer` | postcss-pipeline | `^10.4.0` |

### React-specific peer-dep tension

When any package depends on `@anthropic-ai/sdk@^0.92`, the SDK peers `zod ^3.25 || ^4`. If you also have legacy code on `zod@3.23`, pnpm warns about the unmet peer. Resolution: bump zod to 3.25.0 across the workspace, OR pin `zod` in the override block.

## Python (Poetry / uv / pip)

| Dep | Pulled by | Common drift | Recommended pin |
|---|---|---|---|
| `pydantic` | FastAPI v0.100+ requires v2; legacy code/sqlmodel sometimes pins v1 | 1.x vs 2.x | `^2.5.0` for greenfield |
| `httpx` | FastAPI test client, openai SDK, anthropic SDK | 0.24 vs 0.25 vs 0.27 | `^0.27.0` |
| `sqlalchemy` | ORM choice | 1.4 vs 2.0 | `^2.0.0` for greenfield |
| `python-multipart` | FastAPI form parsing | 0.0.x volatile | pin to whatever FastAPI wants |
| `anyio` | async test framework backend | 3.x vs 4.x | `^4.0.0` |
| `typing-extensions` | py<3.11 polyfills | many minor | `^4.10.0` |

## Go (go.mod)

| Dep | Common drift | Recommended pin |
|---|---|---|
| `golang.org/x/sys` | every CGO consumer | latest stable |
| `golang.org/x/net` | http/2 implementations | latest stable |
| `github.com/stretchr/testify` | test assertion lib | `^1.9.0` |

Note: Go module resolution is generally cleaner than JS/TS — drift is rare. Pin only when reproducibility matters for security audits.

## Rust (Cargo.toml)

| Dep | Common drift | Recommended pin |
|---|---|---|
| `tokio` | async runtime | `^1.35.0` |
| `serde` / `serde_json` | serialization | match versions across sub-crates |
| `reqwest` | http client | `^0.12.0` (post-rustls migration) |

## Process for adding a new entry

When the audit-from-build process surfaces a new conflict-prone dep:

1. Document the failure mode (e.g. "vite 5.4 + drizzle-kit 0.24 → esbuild postinstall fails with version mismatch").
2. Determine the most demanding consumer's required range.
3. Pick a pin that satisfies all consumers.
4. Add the row to the appropriate section above with a date stamp in the rationale column.
5. Test the pin in a fresh workspace before adding (no template-following mistakes).

## Sources

- This skill was extracted from a real multi-agent build (the Bazaar gauntlet, 2026-04-30) where 5 parallel agents wrote independent package.json files and produced an esbuild postinstall failure on `pnpm install`. The fix was `pnpm.overrides: { esbuild: "0.21.5" }`. That incident is documented in `docs/qa/skill-ecosystem-audit-2026-04-30.md` finding F-2.
