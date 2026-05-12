#!/usr/bin/env bash
# preflight.sh — emit the premise-check checklist.
#
# Usage:
#   bash preflight.sh [--out <path>] [--force]
#
# Prints a markdown checklist of assumption categories that should be
# verified before writing PLAN.md. Each unchecked item is a probe
# the operator owes the dossier — file path exists, library exposes
# method, schema column present, env var set, doc claim current.
#
# Default: prints to stdout. `--out <path>` writes to a file; refuses
# to overwrite unless `--force`.
#
# Exits 2 on unknown flag, 1 on overwrite collision.

set -euo pipefail

OUT=""
FORCE=0

while [[ $# -gt 0 ]]; do
	case "$1" in
	--out)
		OUT="${2:?--out requires a path}"
		shift 2
		;;
	--force)
		FORCE=1
		shift
		;;
	-h | --help)
		sed -n '2,16p' "$0"
		exit 0
		;;
	--*)
		printf 'error: unknown flag: %s\n' "$1" >&2
		exit 2
		;;
	*)
		printf 'error: unexpected arg: %s\n' "$1" >&2
		exit 2
		;;
	esac
done

emit() {
	cat <<'EOF'
# Preflight — verify before PLAN.md

Each row is an assumption the plan would rest on. Probe each item
empirically before writing PLAN.md. Replace `[ ]` with `[x]` after
probing. Record any gap as a `C<n>` row in AUDIT.md and reference it
from §C in SPEC.md.

Five minutes of probing prevents three hours of debugging the wrong
tree (CORE.md lifecycle step 0).

## Files / paths

- [ ] {path} exists           (ls / find)
- [ ] {path} has expected structure (Read / head)
- [ ] no parallel-session WIP at {path}    (git status)

## Libraries / methods

- [ ] {library} exposes {symbol}({signature}) (grep / docs)
- [ ] {library} version >= {X.Y}              (lockfile / manifest)
- [ ] no breaking change between current and target version

## Schema

- [ ] table {name} has column {col} type {type}     (\d / DESCRIBE)
- [ ] index {name} exists on column {col}
- [ ] migration {N} latest applied                  (migration log)

## Env / config

- [ ] env var {VAR} is set in {env}                 (printenv / .env scan)
- [ ] secret store carries key {name}               (1Password / sops / vault)
- [ ] config flag {name} reachable from this code path

## Docs / claims

- [ ] doc claim "{quote}" is current                (Read the source doc)
- [ ] external API contract for {endpoint} matches v{N} (vendor docs / Postman)
- [ ] ADR / CONTEXT.md vocabulary used in plan + tests + subjects

## Test / build

- [ ] test runner `{cmd}` runs locally              (run it once now)
- [ ] coverage / lint threshold {N%} unchanged before edits
- [ ] golden / snapshot baseline current             (no stale rebaselines)

---

If any row stays `[ ]` when PLAN.md drafting begins, file the gap as a
`C<n>` row in AUDIT.md with a one-line probe plan, and cite it under
§C in SPEC.md.
EOF
}

if [[ -z "$OUT" ]]; then
	emit
	exit 0
fi

if [[ -e "$OUT" && "$FORCE" -ne 1 ]]; then
	printf "error: %s exists (re-run with --force)\n" "$OUT" >&2
	exit 1
fi

mkdir -p "$(dirname "$OUT")"
emit >"$OUT"
printf 'create: %s\n' "$OUT"
