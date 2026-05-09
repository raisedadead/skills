#!/usr/bin/env bash
# Coverage-lock test for init-dossier.sh.
# Asserts:
#   - feature-wave / bug-sweep / refactor-wave / rescue skip closeout TEMPLATE.md
#   - migration / release-hardening render closeout TEMPLATE.md
#   - lens symlink only created when --lens != generic
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INIT="$SCRIPT_DIR/init-dossier.sh"

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

run_init() {
	local flavor="$1"
	local lens="$2"
	local tmp
	tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-init.XXXXXX")"
	bash "$INIT" --phase 1 --flavor "$flavor" --lens "$lens" "$tmp" >/dev/null
	printf '%s\n' "$tmp"
}

assert_file() {
	[[ -f "$1" ]] || fail "expected file present: $1"
}

assert_absent() {
	[[ ! -e "$1" ]] || fail "expected absent: $1"
}

assert_symlink() {
	[[ -L "$1" ]] || fail "expected symlink: $1"
}

# Skip-closeout flavors.
for flavor in feature-wave bug-sweep refactor-wave rescue; do
	tmp="$(run_init "$flavor" generic)"
	assert_file "$tmp/.scratchpad/dossier/PLAN.md"
	assert_file "$tmp/.scratchpad/dossier/SPEC.md"
	assert_file "$tmp/.scratchpad/dossier/AUDIT.md"
	assert_absent "$tmp/.scratchpad/dossier/closeout/TEMPLATE.md"
	assert_absent "$tmp/.scratchpad/dossier/LENS.md"
	rm -rf "$tmp"
done

# Render-closeout flavors.
for flavor in migration release-hardening; do
	tmp="$(run_init "$flavor" generic)"
	assert_file "$tmp/.scratchpad/dossier/closeout/TEMPLATE.md"
	rm -rf "$tmp"
done

# Lens symlink wiring.
tmp="$(run_init feature-wave backend)"
assert_symlink "$tmp/.scratchpad/dossier/LENS.md"
rm -rf "$tmp"

printf 'ok\n'
