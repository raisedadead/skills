# Lens — Library / package

For distributed libraries / SDKs — npm / PyPI / crates.io / Maven /
Go modules — where the public API surface IS the contract and
semver governs every release.

## Surface vocabulary

- **Unit:** exported symbol (function / class / type / constant).
- **Output:** public API surface — `dist/index.d.ts`, `*.api.md`, `cargo public-api`, Go `golang.org/x/tools/cmd/apidiff`, Java `jdiff`.
- **Contract:** exported symbol set + signatures + documented behaviour + supported runtime / engine versions.

## Gate menu (select per phase)

These are gate candidates, not defaults. Copy only selected gates into
`PLAN.md` / `SPEC.md`; leave the rest as context.

- **Public API surface freeze.** `api-surface.json` (or equivalent) committed; CI regenerates and `git diff --exit-code`. Diff → fail. Updates land with the breaking commit.
- **Semver gate.** Meta-gate inspects the diff: any removed export → reject unless release metadata bumps `major`. Any added export → require `minor`. Other → `patch`.
- **No internal symbol exported.** Walk `index.ts` / `lib.rs` re-exports; meta-gate rejects re-exports of names matching `_*`, `internal*`.
- **Type-only exports flagged.** TS: meta-gate regex on `export type` vs `export const` to catch accidental runtime export.
- **No `process.env` reads in library code.** Library shouldn't depend on env; meta-gate greps for offenders (allowlist tests).
- **No `console.log` in library code.** Logging via injected logger; meta-gate greps offenders.
- **Engines / runtime range pinned.** `package.json#engines.node`, `Cargo.toml` `rust-version`, `pyproject.toml` `requires-python` — meta-gate asserts presence + floor.
- **`exports` map covers every entrypoint.** Meta-gate cross-references `package.json#exports` keys vs files in `dist/`.

## Output rebaseline specifics

| Step             | Command                                                    |
| ---------------- | ---------------------------------------------------------- |
| Build            | `pnpm build` / `cargo build --release`                     |
| Regenerate       | `api-extractor run --local` / `cargo public-api > api.txt` |
| Unbaselined diff | `git diff api-surface.json` / `git diff api.txt`           |
| Read failures    | added / removed exports listed                             |
| Accept           | stage the regenerated artefact                             |

Goldens: `api-surface.json`, `api.txt`, `*.api.md` (api-extractor),
`docs/api/*` for rendered docs.

## Probe specifics

- File: `_probe-<slug>.spec.ts` / `_probe_<slug>_test.go` / `tests/test_probe_<slug>.py`
- Runner: `pnpm exec vitest run _probe-<slug> --reporter=verbose`
- Dump shape: import the public symbol, log its actual signature / type / behaviour.
- Common dump targets: `Object.keys(default)`, `typeof exported`, what's actually re-exported from a barrel file, what TypeScript resolves a generic to.

## Stack footguns

- **Barrel re-export drift.** `index.ts` re-exports `*` — adding any internal symbol leaks. → list re-exports explicitly.
- **TS `declare module` augmentation in dist.** Library augments user's globals → users break. → ship augmentations behind opt-in import path.
- **Default vs named export confusion.** Tooling treats them differently across CJS/ESM. → prefer named exports; meta-gate on `default` use.
- **ESM/CJS dual-package hazard.** Two copies of the library in user's tree (one ESM, one CJS); state diverges. → ship one format, or use `package.json#exports` correctly.
- **`peerDependencies` drift.** Library imports a peer-dep transitively; works in own repo with its own version, fails in user's repo. → CI test against the lowest peer-dep range.
- **Type narrowing escapes.** TS infers loose type that user can't narrow. → freeze inferred types via `expectTypeOf` tests.
- **Side-effectful import.** Library import has runtime side effect (`window.X = ...`). → meta-gate on top-level statements in entrypoint.
- **License field drift.** `package.json#license` differs from `LICENSE` file. → meta-gate.

## Phase shape hint (optional)

Typical sub-phases for a library phase:

- P0 — API surface baseline freeze
- P1 — meta-gates (semver, engines, exports map, no-internals)
- P2 — type-test scaffold (`expectTypeOf`, `tsd`, `compile-fail`)
- P3 — feature work (per-export TDD rounds)
- P4 — docs regeneration + API reference freeze
- P5 — semver bump decision + closeout
