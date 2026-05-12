#!/usr/bin/env bash
# Coverage-lock test for preflight.sh.
# Asserts: prints checklist on stdout, --out writes to file, contains
# expected section headers, errors on unknown flag.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PRE="$SCRIPT_DIR/preflight.sh"

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

# 1. Default: prints checklist on stdout.
out="$(bash "$PRE" 2>/dev/null)"
grep -q -i '^# Preflight' <<<"$out" || fail "should print Preflight header"
grep -q '^## Files / paths' <<<"$out" || fail "should print Files section"
grep -q '^## Libraries / methods' <<<"$out" || fail "should print Libraries section"
grep -q '^## Schema' <<<"$out" || fail "should print Schema section"
grep -q '^## Env / config' <<<"$out" || fail "should print Env section"
grep -q '^## Docs / claims' <<<"$out" || fail "should print Docs section"
grep -q '^## Test / build' <<<"$out" || fail "should print Test section"
grep -q '\- \[ \]' <<<"$out" || fail "should include unchecked checklist items"

# 2. --out writes to file.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-preflight.XXXXXX")"
target="$tmp/preflight.md"
bash "$PRE" --out "$target" >/dev/null
[[ -f "$target" ]] || fail "--out should create the target file"
grep -q '^# Preflight' "$target" || fail "--out content missing header"
rm -rf "$tmp"

# 3. --out refuses overwrite without --force.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-preflight.XXXXXX")"
target="$tmp/preflight.md"
bash "$PRE" --out "$target" >/dev/null
if bash "$PRE" --out "$target" 2>/dev/null; then
	fail "--out should refuse to overwrite without --force"
fi
rm -rf "$tmp"

# 4. --out --force overwrites.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-preflight.XXXXXX")"
target="$tmp/preflight.md"
bash "$PRE" --out "$target" >/dev/null
echo "MUTATED" >>"$target"
bash "$PRE" --out "$target" --force >/dev/null
grep -q "MUTATED" "$target" && fail "--force should overwrite"
rm -rf "$tmp"

# 5. --help.
out="$(bash "$PRE" --help 2>/dev/null)"
grep -q -i 'usage' <<<"$out" || fail "--help should print usage"

# 6. Unknown flag.
if bash "$PRE" --bogus 2>/dev/null; then
	fail "unknown flag should error"
fi

printf 'ok\n'
