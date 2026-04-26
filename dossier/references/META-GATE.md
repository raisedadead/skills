# Meta-gate ratchet — defense-in-depth invariants

A **meta-gate** is a unit-test-level assertion that introspects
source files (not behaviour) to enforce a structural invariant.
Together with a config / source artefact it forms
defense-in-depth: lowering the artefact fails the meta-test;
removing the meta-test loses coverage; you cannot silently
weaken either.

Meta-gates work in any test runner that can read files at test
time. The pattern is the same across stacks; only the runner
changes.

## Pattern

```ts
// example: vitest meta-gate
import { readFileSync } from "node:fs";
import { describe, expect, test } from "vitest";

const SRC = readFileSync("src/styles/showcase.css", "utf8");

describe("css-token-discipline", () => {
  test("no hex literals in showcase.css (carve-out: block comments)", () => {
    const stripped = SRC.replace(/\/\*[\s\S]*?\*\//g, "");
    const offenders = stripped.match(/#[0-9a-fA-F]{3,8}\b/g) ?? [];
    expect(offenders).toEqual([]);
  });
});
```

Properties (regardless of stack):

- **Fast** (millis). No DOM, no network, no fixtures.
- **Source of truth: the source file.** No fixture drift.
- **Failures name the offender directly.**

## Five families (with cross-stack examples)

### 1. Threshold / config gates

Read a config file, assert a numeric floor.

```ts
// vitest — coverage threshold floor
const FLOOR = { statements: 85, branches: 80, functions: 85, lines: 85 };
const CFG = readFileSync("vitest.config.ts", "utf8");
for (const [k, min] of Object.entries(FLOOR)) {
  test(`${k} threshold >= ${min}`, () => {
    const m = CFG.match(new RegExp(`${k}:\\s*(\\d+)`));
    expect(Number(m![1])).toBeGreaterThanOrEqual(min);
  });
}
```

```python
# pytest — pyproject coverage floor
import re, pathlib, pytest
CFG = pathlib.Path("pyproject.toml").read_text()
@pytest.mark.parametrize("key,floor", [("fail_under", 85)])
def test_cov_floor(key, floor):
    m = re.search(rf"{key}\s*=\s*(\d+)", CFG)
    assert m and int(m.group(1)) >= floor
```

### 2. Drift gates (allowlist / blocklist ratchet)

Track an `READY` ⊆ `REQUIRED` ratchet. Every time a contract
ships, append to `READY` in the **same commit**.

```ts
const REQUIRED = [
  "toggle",
  "input",
  "select",
  "modal",
  "tooltip",
  "data-table",
];
const READY: string[] = []; // grows commit by commit

test("READY ⊆ REQUIRED", () => {
  expect(READY.every((s) => REQUIRED.includes(s))).toBe(true);
});

for (const slug of READY) {
  test(`'${slug}' has a behavioural spec`, () => {
    expect(() =>
      readFileSync(`tests/behavioural/${slug}.spec.ts`),
    ).not.toThrow();
  });
}

for (const slug of REQUIRED.filter((s) => !READY.includes(s))) {
  test.todo(`pending behavioural spec for '${slug}'`);
}
```

Same shape applies to: backend route allowlist, CLI subcommand
matrix, terraform module list, dbt model coverage, public API
exports.

### 3. Source-pattern gates (no offender of pattern X)

```ts
// every showcase tab button must declare type=button
const FILES = glob.sync("src/showcase/**/*.astro");
const offenders: string[] = [];
for (const f of FILES) {
  const src = readFileSync(f, "utf8");
  const matches =
    src.match(/<button[^>]*class="[^"]*showcase__tab[^"]*"[^>]*>/g) ?? [];
  for (const m of matches) {
    if (!/type=["']button["']/.test(m)) offenders.push(`${f}: ${m}`);
  }
}
test("every .showcase__tab declares type=button", () => {
  expect(offenders).toEqual([]);
});
```

```go
// no `panic(` outside _test.go
func TestNoPanicInProd(t *testing.T) {
    var offenders []string
    filepath.Walk(".", func(p string, fi os.FileInfo, _ error) error {
        if !strings.HasSuffix(p, ".go") || strings.HasSuffix(p, "_test.go") { return nil }
        b, _ := os.ReadFile(p)
        if bytes.Contains(b, []byte("panic(")) { offenders = append(offenders, p) }
        return nil
    })
    if len(offenders) > 0 { t.Fatalf("panic in prod: %v", offenders) }
}
```

### 4. Surface / contract gates

Pin a public-API surface (or schema, OpenAPI, dbt manifest).
The rule is "no diff vs frozen". Diff appears → meta-gate
fails → fix or update the frozen artefact in the same commit.

```ts
// library — public API freeze
const FROZEN = readFileSync("api-surface.json", "utf8");
const CURRENT = JSON.stringify(extractPublicAPI("dist/index.d.ts"), null, 2);
test("public API surface frozen", () => {
  expect(CURRENT).toEqual(FROZEN); // diff names the addition / removal
});
```

```yaml
# backend — OpenAPI freeze (in CI)
- run: make openapi
- run: git diff --exit-code openapi.v2.yaml
```

```bash
# data pipeline — schema freeze
dbt compile --target ci
git diff --exit-code target/manifest.json
```

### 5. Dependency / supply-chain gates

```ts
// no version range — exact pins only
const PKG = JSON.parse(readFileSync("package.json", "utf8"));
const offenders = Object.entries({
  ...PKG.dependencies,
  ...PKG.devDependencies,
}).filter(([_, v]) => /^[\^~*]/.test(v as string));
test("dependencies are exact-pinned", () => {
  expect(offenders).toEqual([]);
});
```

```python
# requirements — only `==` allowed
import pathlib, re
REQ = pathlib.Path("requirements.txt").read_text()
offenders = [l for l in REQ.splitlines()
             if l and not l.startswith("#") and "==" not in l]
def test_pinned(): assert offenders == []
```

```hcl
# terraform — provider version pinned
# tested via test that greps `versions.tf` for `version = "~> N"` patterns
```

## Why this works as the TDD-gate sibling

When you Edit a non-impl file (config, threshold, structural
file, frozen artefact), the PreToolUse TDD gate blocks because
no component / unit test exists. The meta-gate IS the sibling:
it asserts the rule the artefact encodes. Land both in the same
commit.

## When NOT to use a meta-gate

- The rule is behaviour, not structure. → write a behavioural test.
- The rule depends on runtime state. → use a probe (see `PROBE-PATTERN.md`).
- The rule is checked by an existing linter / formatter / type
  checker. → don't duplicate. Configure the existing tool and
  add a meta-gate only on the tool's config.
- The rule needs cross-system data (DB, network). → that's an
  integration test, not a meta-gate.

## Inventory hint

Track meta-gates in a single source-of-truth list (in `SPEC.md`
or a `_meta/index.md`). Lets future agents discover what's
ratcheted before reverting an "obvious" simplification.
