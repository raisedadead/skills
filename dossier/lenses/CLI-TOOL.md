# Lens — CLI tool

For shell-callable binaries — Go / Rust / Node / Python / Bash —
where flag parsing, exit-code matrix, and stdout/stderr shape
form the contract.

## Surface vocabulary

- **Unit:** subcommand / flag (`tool init --dry-run`, `tool migrate up`).
- **Output:** stdout text (golden), stderr text, exit code, side-effect on filesystem / network.
- **Contract:** flag set + exit-code matrix + stdout shape (plain / JSON / TSV) + `--help` text.

## Gate menu (select per phase)

These are gate candidates, not defaults. Copy only selected gates into
`PLAN.md` / `SPEC.md`; leave the rest as context.

- **Exit-code matrix.** Documented and tested: 0=ok, 1=runtime, 2=usage (or 64=usage per `sysexits.h`). Meta-gate parses help text + asserts coverage.
- **`--help` available on every subcommand.** Walk subcommand tree; assert `--help` exits 0.
- **`--version` deterministic.** Returns single line `name X.Y.Z`; meta-gate regex.
- **No-color sentinel honoured.** `NO_COLOR=1` env disables ANSI; meta-gate runs `--help` under `NO_COLOR=1`, regex no escape codes in stdout.
- **JSON output mode round-trips.** `--json` output parses back into the same object; meta-gate via `tool ... --json | jq -e .`.
- **No mutating side-effects under `--dry-run`.** Tested via filesystem snapshot before/after.
- **Stable error messages.** Specific error strings frozen as goldens; meta-gate compares.

## Output rebaseline specifics

| Step            | Command                                   |
| --------------- | ----------------------------------------- |
| Build           | `go build -o ./bin/tool ./cmd/tool`       |
| Unbaselined run | `bats tests/golden/`                      |
| Read failures   | bats prints diff against golden text      |
| Accept goldens  | `BATS_UPDATE_GOLDEN=1 bats tests/golden/` |
| Scoped          | `bats tests/golden/init-dry-run.bats`     |

Goldens: `tests/golden/*.txt` (stdout) + `tests/golden/*.err` (stderr) + `tests/golden/*.exit` (exit code).

Alternative runners: `cargo test`, `pytest`, `pnpm exec vitest`,
`shellspec`, `cram`. Pattern is identical — runner reads the
golden, diffs against actual.

## Probe specifics

- File: `_probe-<slug>.bats` (or `_probe_<slug>_test.go`)
- Runner: `bats --tap tests/_probe-<slug>.bats`
- Dump shape: `printf "PROBE %s=%s\n" key value >&3` (bats fd 3 is the original stdout).
- Common dump targets: `$status`, `${#output}`, first/last line, env that the tool sees, `$BASH_ENV`, `$XDG_*`.

## Stack footguns

- **TTY detection in tests.** Tool prints differently to a pipe vs TTY. → in tests, use `expect`-style PTY (`empty`, `script`) or assert pipe-mode explicitly.
- **`exit 1` swallowed by `set -e` in the test wrapper.** → use `run` (bats) / `Run()` (testscript) so non-zero is captured, not propagated.
- **Locale-dependent sorting.** `LC_ALL=C` in test env or output drifts on different machines.
- **Path quoting in error messages.** Hostname / cwd appears in golden → flake on different machines. → strip in golden comparator (sed before diff).
- **Subprocess fork before flag parse.** Tool spawns helper before `--help` short-circuits → `--help` is slow / has side effects. → parse flags first.
- **Stdout / stderr interleaving.** Tests assume strict order; in real run they interleave. → assert stdout vs stderr separately.
- **Newline at EOF drift.** Editor strips trailing newline from golden; runner emits with newline. → `printf "%s" > golden.txt` not `echo`.
- **Argv vs flags ambiguity.** `tool foo -v` vs `tool -v foo` — flag library treats positional differently. → freeze in golden.

## Phase shape hint (optional)

Typical sub-phases for a CLI phase:

- P0 — golden test scaffold (bats / testscript / cram)
- P1 — `--help` + `--version` + exit-code matrix gates
- P2 — subcommand surface freeze (every subcommand has golden)
- P3 — feature work (per-flag TDD rounds with golden)
- P4 — completion script generation + golden
- P5 — release / cut + closeout
