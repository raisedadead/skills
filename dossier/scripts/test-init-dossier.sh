#!/usr/bin/env bash
# Coverage-lock test for init-dossier.sh.
#
# Asserts the tiered-open default:
#   - Always create SPEC.md + closeout/.
#   - PLAN.md created when --phases > 1, --tasks > 8, flavor in
#     {migration, release-hardening}, or --legacy.
#   - AUDIT.md created when --findings > 5, flavor in
#     {bug-sweep, migration, release-hardening}, or --legacy.
#   - closeout/TEMPLATE.md rendered for migration / release-hardening
#     (or --legacy).
#   - Lens symlink wired only when --lens != generic.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INIT="$SCRIPT_DIR/init-dossier.sh"

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

run_init() {
	local tmp
	tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-init.XXXXXX")"
	bash "$INIT" "$@" "$tmp" >/dev/null
	printf '%s\n' "$tmp"
}

assert_file() { [[ -f "$1" ]] || fail "expected file present: $1"; }
assert_absent() { [[ ! -e "$1" ]] || fail "expected absent: $1"; }
assert_symlink() { [[ -L "$1" ]] || fail "expected symlink: $1"; }

# 1. Default feature-wave with no escalators -> SPEC.md only (no PLAN, no AUDIT, no closeout TEMPLATE).
tmp="$(run_init --phase 1 --flavor feature-wave --lens generic)"
D="$tmp/.scratchpad/dossier"
assert_file "$D/SPEC.md"
assert_absent "$D/PLAN.md"
assert_absent "$D/AUDIT.md"
assert_absent "$D/closeout/TEMPLATE.md"
assert_absent "$D/LENS.md"
rm -rf "$tmp"

# 2. --phases > 1 triggers PLAN.md (but not AUDIT).
tmp="$(run_init --phase 1 --phases 3 --flavor feature-wave --lens generic)"
D="$tmp/.scratchpad/dossier"
assert_file "$D/SPEC.md"
assert_file "$D/PLAN.md"
assert_absent "$D/AUDIT.md"
rm -rf "$tmp"

# 3. --tasks > 8 also triggers PLAN.md.
tmp="$(run_init --phase 1 --tasks 12 --flavor feature-wave --lens generic)"
D="$tmp/.scratchpad/dossier"
assert_file "$D/PLAN.md"
assert_absent "$D/AUDIT.md"
rm -rf "$tmp"

# 4. --findings > 5 triggers AUDIT.md (but not PLAN).
tmp="$(run_init --phase 1 --findings 7 --flavor feature-wave --lens generic)"
D="$tmp/.scratchpad/dossier"
assert_file "$D/SPEC.md"
assert_absent "$D/PLAN.md"
assert_file "$D/AUDIT.md"
rm -rf "$tmp"

# 5. bug-sweep flavor auto-spawns AUDIT.md (no PLAN).
tmp="$(run_init --phase 1 --flavor bug-sweep --lens generic)"
D="$tmp/.scratchpad/dossier"
assert_file "$D/SPEC.md"
assert_file "$D/AUDIT.md"
assert_absent "$D/PLAN.md"
assert_absent "$D/closeout/TEMPLATE.md"
rm -rf "$tmp"

# 6. migration flavor spawns all four (PLAN + AUDIT + closeout TEMPLATE).
tmp="$(run_init --phase 1 --flavor migration --lens generic)"
D="$tmp/.scratchpad/dossier"
assert_file "$D/SPEC.md"
assert_file "$D/PLAN.md"
assert_file "$D/AUDIT.md"
assert_file "$D/closeout/TEMPLATE.md"
rm -rf "$tmp"

# 7. release-hardening also spawns all four.
tmp="$(run_init --phase 1 --flavor release-hardening --lens generic)"
D="$tmp/.scratchpad/dossier"
assert_file "$D/PLAN.md"
assert_file "$D/AUDIT.md"
assert_file "$D/closeout/TEMPLATE.md"
rm -rf "$tmp"

# 8. refactor-wave is minimal — SPEC only.
tmp="$(run_init --phase 1 --flavor refactor-wave --lens generic)"
D="$tmp/.scratchpad/dossier"
assert_file "$D/SPEC.md"
assert_absent "$D/PLAN.md"
assert_absent "$D/AUDIT.md"
rm -rf "$tmp"

# 9. rescue is minimal — SPEC only by default.
tmp="$(run_init --phase 1 --flavor rescue --lens generic)"
D="$tmp/.scratchpad/dossier"
assert_file "$D/SPEC.md"
assert_absent "$D/PLAN.md"
rm -rf "$tmp"

# 10. --legacy forces full 4-file shape regardless of flavor / escalators.
tmp="$(run_init --phase 1 --flavor feature-wave --lens generic --legacy)"
D="$tmp/.scratchpad/dossier"
assert_file "$D/SPEC.md"
assert_file "$D/PLAN.md"
assert_file "$D/AUDIT.md"
assert_file "$D/closeout/TEMPLATE.md"
rm -rf "$tmp"

# 11. Lens symlink wiring (lens != generic).
tmp="$(run_init --phase 1 --flavor feature-wave --lens backend)"
D="$tmp/.scratchpad/dossier"
assert_symlink "$D/LENS.md"
rm -rf "$tmp"

# 12. Lens = generic -> no LENS.md.
tmp="$(run_init --phase 1 --flavor feature-wave --lens generic)"
D="$tmp/.scratchpad/dossier"
assert_absent "$D/LENS.md"
rm -rf "$tmp"

# 13. Combined escalators (phases + findings) spawn both PLAN and AUDIT.
tmp="$(run_init --phase 1 --phases 2 --findings 9 --flavor feature-wave --lens generic)"
D="$tmp/.scratchpad/dossier"
assert_file "$D/PLAN.md"
assert_file "$D/AUDIT.md"
rm -rf "$tmp"

# 14. Re-running init does not overwrite SPEC.md.
tmp="$(run_init --phase 1 --flavor feature-wave --lens generic)"
D="$tmp/.scratchpad/dossier"
echo "MUTATED" >>"$D/SPEC.md"
bash "$INIT" --phase 1 --flavor feature-wave --lens generic "$tmp" >/dev/null
grep -q "MUTATED" "$D/SPEC.md" || fail "re-run should not overwrite SPEC.md"
rm -rf "$tmp"

# 15. Unknown flavor -> exit 2.
if bash "$INIT" --phase 1 --flavor bogus --lens generic /tmp/nonexistent-xxxx 2>/dev/null; then
	fail "unknown flavor should error"
fi

# 16. Bad project root -> exit 1.
if bash "$INIT" --phase 1 --flavor feature-wave --lens generic /no/such/path-xyz 2>/dev/null; then
	fail "missing project root should error"
fi

# 17. --help works.
out="$(bash "$INIT" --help 2>/dev/null)"
grep -q -i 'usage' <<<"$out" || fail "--help should print usage"

printf 'ok\n'
