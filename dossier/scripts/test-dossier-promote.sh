#!/usr/bin/env bash
# Coverage-lock test for dossier-promote.sh.
# Asserts: --plan creates PLAN.md, --audit creates AUDIT.md,
# both flags create both, idempotent, error if dossier missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INIT="$SCRIPT_DIR/init-dossier.sh"
PROMOTE="$SCRIPT_DIR/dossier-promote.sh"

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

mkfix() {
	local tmp
	tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-promote.XXXXXX")"
	# Start in tiered-minimal state (SPEC only, no PLAN, no AUDIT).
	bash "$INIT" --phase 1 --flavor feature-wave --lens generic "$tmp" >/dev/null
	printf '%s' "$tmp"
}

# 1. --plan creates PLAN.md.
tmp="$(mkfix)"
D="$tmp/.scratchpad/dossier"
[[ ! -f "$D/PLAN.md" ]] || fail "fixture should start without PLAN.md"
bash "$PROMOTE" --plan "$tmp" >/dev/null
[[ -f "$D/PLAN.md" ]] || fail "--plan should create PLAN.md"
rm -rf "$tmp"

# 2. --audit creates AUDIT.md.
tmp="$(mkfix)"
D="$tmp/.scratchpad/dossier"
bash "$PROMOTE" --audit "$tmp" >/dev/null
[[ -f "$D/AUDIT.md" ]] || fail "--audit should create AUDIT.md"
rm -rf "$tmp"

# 3. Both flags create both files.
tmp="$(mkfix)"
D="$tmp/.scratchpad/dossier"
bash "$PROMOTE" --plan --audit "$tmp" >/dev/null
[[ -f "$D/PLAN.md" ]] || fail "should create PLAN.md"
[[ -f "$D/AUDIT.md" ]] || fail "should create AUDIT.md"
rm -rf "$tmp"

# 4. Idempotent — re-running does not overwrite existing content.
tmp="$(mkfix)"
D="$tmp/.scratchpad/dossier"
bash "$PROMOTE" --plan "$tmp" >/dev/null
echo "MUTATED" >>"$D/PLAN.md"
bash "$PROMOTE" --plan "$tmp" >/dev/null
grep -q 'MUTATED' "$D/PLAN.md" || fail "promote should not overwrite existing PLAN.md"
rm -rf "$tmp"

# 5. Errors if no dossier exists at root.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-promote.XXXXXX")"
if bash "$PROMOTE" --plan "$tmp" 2>/dev/null; then
	fail "should error when no dossier present"
fi
rm -rf "$tmp"

# 6. Errors if no --plan or --audit given.
tmp="$(mkfix)"
if bash "$PROMOTE" "$tmp" 2>/dev/null; then
	fail "should require --plan or --audit"
fi
rm -rf "$tmp"

# 7. --help.
out="$(bash "$PROMOTE" --help 2>/dev/null)"
grep -q -i 'usage' <<<"$out" || fail "--help should print usage"

# 8. Unknown flag.
if bash "$PROMOTE" --bogus 2>/dev/null; then
	fail "unknown flag should error"
fi

printf 'ok\n'
