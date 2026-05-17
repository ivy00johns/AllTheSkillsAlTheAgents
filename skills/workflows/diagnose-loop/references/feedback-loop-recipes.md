# Feedback Loop Recipes

Concrete construction snippets for each of the ten ranked methods in Phase 1. The order matches the SKILL.md — cheapest first. Pick the cheapest method that actually reproduces the bug; don't reach for fuzz testing when an existing failing test would do.

Each recipe answers three questions: when to use it, what the loop looks like, and how to make it deterministic.

## 1. Existing failing test

**When:** The CI failure or local test run already surfaced the bug. This is free signal — use it.

**Loop:**

```bash
# Run only the failing test, fail fast, show full output
npx vitest run path/to/file.test.ts -t "exact test name"
pytest tests/test_module.py::TestClass::test_case -x -vv
go test ./pkg/foo -run TestSpecificCase -v -count=1
cargo test --package my_crate test_name -- --exact --nocapture
```

**Sharpen:** Disable other tests in the file. Add `--bail` / `-x` so the run stops on first failure. If the test depends on a fixture, inline the minimum fixture rather than loading the full suite.

## 2. New failing test that captures the bug

**When:** No existing test covers the bug — but the codebase has a test harness.

**Loop:** Write the smallest possible test that asserts the *expected* behavior. Watch it fail. Now you have a Phase 1 loop and a Phase 5 regression test in one artifact.

```ts
// vitest / jest
it("returns 404 when the user is soft-deleted", async () => {
  const user = await createUser({ deletedAt: new Date() });
  const res = await fetch(`/api/users/${user.id}`);
  expect(res.status).toBe(404); // currently returns 200 — that's the bug
});
```

**Sharpen:** No mocks unless absolutely required. The test should fail because of the bug, not because of a brittle mock.

## 3. `curl` / HTTP request that reproduces

**When:** Bug is in an HTTP handler, webhook, or any request-response API.

**Loop:** Save the request as a shell script so it replays in one line. Pipe through `jq` to extract just the field that's wrong.

```bash
#!/usr/bin/env bash
# repro.sh — exit 0 if fixed, exit 1 if bug present
set -euo pipefail
response=$(curl -fsS -X POST http://localhost:3000/api/orders \
  -H 'content-type: application/json' \
  -d '{"sku":"WIDGET-1","qty":2}')
echo "$response" | jq -e '.total == 19.98' > /dev/null
```

**Sharpen:** Use `-f` so curl exits non-zero on 5xx. Capture the request from production with `mitmproxy` or browser devtools "copy as curl" and trim it down.

## 4. CLI command + `diff` against known-good output

**When:** Tool emits text — formatter, compiler, code generator, build artifact, log output.

**Loop:** Golden-file testing. Commit the known-good output once, then diff.

```bash
#!/usr/bin/env bash
set -euo pipefail
./bin/my-tool fixtures/input.txt > /tmp/actual.txt
diff -u fixtures/expected.txt /tmp/actual.txt
```

**Sharpen:** Normalize timestamps, absolute paths, and random IDs before diffing (`sed 's/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/DATE/g'`). Nondeterministic fields are the most common source of noise.

## 5. Headless browser script (Playwright / Puppeteer)

**When:** UI bug, hydration mismatch, client-side state issue, browser-only API.

**Loop:** Compose with the `playwright` skill. Minimal repro script:

```ts
import { chromium } from "playwright";
const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto("http://localhost:3000/checkout");
await page.click('button[data-testid="apply-coupon"]');
await page.fill('input[name="coupon"]', "BLACKFRIDAY");
const total = await page.textContent('[data-testid="total"]');
if (total !== "$80.00") {
  console.error(`bug: total was ${total}`);
  process.exit(1);
}
await browser.close();
```

**Sharpen:** Run headless. Disable animations (`prefers-reduced-motion`). Use `data-testid` selectors so the loop isn't sensitive to copy changes.

## 6. Trace / log replay

**When:** Bug only fires in production, where you can't attach a debugger.

**Loop:** Capture the request payload (and any relevant headers/context) from production logs, save it as a fixture, replay against local code.

```bash
# fixture captured from prod
cat fixtures/prod-request-2026-05-15.json | node scripts/replay.js
```

The replay script imports the production code path directly — skip the HTTP layer if the bug is below it.

**Sharpen:** Strip PII before committing the fixture. Replay against a database snapshot that matches the production state at failure time.

## 7. Throwaway harness script in the repo's language

**When:** The bug is in a library module, pure function, or non-HTTP code path. No test harness exists or setting one up is overkill.

**Loop:** A 20-line file that imports the buggy module and exercises it directly.

```python
# scratch/repro.py
from myapp.pricing import calculate_total
items = [{"sku": "A", "qty": 3, "price": 9.99}]
result = calculate_total(items, tax_rate=0.08)
assert result == 32.37, f"bug: got {result}"
```

```bash
python scratch/repro.py && echo PASS || echo FAIL
```

**Sharpen:** Delete the file when you're done, or rename it to a proper test in Phase 5. Don't let scratch files accumulate.

## 8. Property-based / fuzz test

**When:** Bug is data-dependent and the failing input isn't known. Symptoms: "it works for most inputs but sometimes throws," parser bugs, edge cases in date/timezone/locale handling.

**Loop:** Let the framework search for failing inputs.

```python
# hypothesis
from hypothesis import given, strategies as st
@given(st.lists(st.integers(min_value=0, max_value=1_000_000), min_size=1))
def test_median_never_throws(xs):
    median(xs)  # currently raises ZeroDivisionError on certain inputs
```

```js
// fast-check
fc.assert(fc.property(fc.string(), (s) => parseUrl(s) !== undefined));
```

**Sharpen:** Once the framework finds a minimal failing case, copy it into a normal unit test — that becomes Phase 5's regression test.

## 9. `git bisect`

**When:** Bug is recent. A "good" commit exists where it didn't happen. The codebase is large enough that reading every diff would take longer than bisecting.

**Loop:** The bisect script *is* the loop.

```bash
git bisect start
git bisect bad HEAD
git bisect good v2.3.0
git bisect run ./repro.sh   # uses recipe #3 or #7 as the loop
```

**Sharpen:** Make `repro.sh` exit 0 on pass, 1 on fail, 125 on "skip this commit" (e.g., the codebase doesn't build at that revision). Bisect handles the rest.

## 10. Differential testing against a reference implementation

**When:** "Correct" is defined by another implementation — protocol parsers, compilers, math libraries, anything with a spec or an existing tool.

**Loop:** Feed the same input to both implementations, diff the output.

```bash
for input in fixtures/*.json; do
  ours=$(./bin/our-parser "$input")
  theirs=$(jq . "$input")  # reference
  diff <(echo "$ours") <(echo "$theirs") || { echo "diverged on $input"; exit 1; }
done
```

**Sharpen:** Start with inputs you know both implementations handle, then expand to corpus inputs. The first divergence is usually the bug.

## Last resort — human-in-the-loop

When no automated loop is reachable (physical hardware, paid third-party UI, manual approval step), fall back to `scripts/hitl-loop.template.sh`. The agent prompts the user to perform a step, the user runs it, the agent reads the output. Slow, but better than guessing.

This is genuinely a last resort — exhaust methods 1–10 first. Humans are slow loops with high variance, which is the opposite of what Phase 1 needs.
