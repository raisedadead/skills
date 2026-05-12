#!/usr/bin/env bash
# Coverage-lock test for close-phase.sh.
# Asserts: renders closeout file, derives phase number from SPEC,
# fills commits / findings-closed / deferred from disk, refuses
# overwrite without --force, honors --slug, errors on missing SPEC.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLOSE="$SCRIPT_DIR/close-phase.sh"

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

mkfix() {
	local tmp
	tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-close-phase.XXXXXX")"
	mkdir -p "$tmp/.scratchpad/dossier/closeout"
	# shellcheck disable=SC2016
	{
		printf '# Phase 2 Spec\n\n'
		printf 'Flavor: `migration`\n\n'
		printf '## §G Goal\n\nMigrate orders table to v2 schema\n\n'
		printf '## §T Tasks\n\n'
		printf '| id | status | task | finding | cites |\n'
		printf '| -- | ------ | ---- | ------- | ----- |\n'
		printf '| T1 | x | first slice | B1 | V1 |\n'
		printf '| T2 | x | second slice | B2 | V2 |\n\n'
		printf '## §B Bugs / Findings\n\n'
		printf '| id | date | cause | fix |\n'
		printf '| -- | ---- | ----- | --- |\n'
		printf '| B1 | 2026-05-12 | bad cast | T1 |\n'
		printf '| B2 | 2026-05-12 | stale index | pending |\n'
		printf '| B3 | 2026-05-12 | flaky retry | T2 |\n'
	} >"$tmp/.scratchpad/dossier/SPEC.md"
	# Provide the CLOSEOUT template so close-phase has something to render.
	# Test resolves SKILL_DIR via env override so it can find templates.
	printf '%s' "$tmp"
}

run_close() {
	# Run from the fixture; pass a SKILL_DIR env so script finds templates.
	local args=("$@")
	SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)" \
		bash "$CLOSE" "${args[@]}"
}

# 1. Default render — creates closeout file with phase + flavor + slug.
tmp="$(mkfix)"
out="$(run_close "$tmp" 2>&1)"
# Expect a closeout file under closeout/phase-2-*.md (glob, not ls|grep).
shopt -s nullglob
matches=("$tmp/.scratchpad/dossier/closeout/"phase-2-*.md)
shopt -u nullglob
[[ ${#matches[@]} -ge 1 ]] || fail "should create phase-2-*.md (output: $out)"
file="${matches[0]}"
grep -q '^# Phase 2 Closeout' "$file" || fail "phase number not substituted in header"
# shellcheck disable=SC2016
grep -q 'Flavor: `migration`' "$file" || fail "flavor not substituted"
rm -rf "$tmp"

# 2. --slug overrides derived slug.
tmp="$(mkfix)"
run_close --slug 'order-migration' "$tmp" >/dev/null
[[ -f "$tmp/.scratchpad/dossier/closeout/phase-2-order-migration.md" ]] ||
	fail "explicit --slug should land at phase-2-order-migration.md"
rm -rf "$tmp"

# 3. Commits Landed populated from git log.
tmp="$(mkfix)"
(
	cd "$tmp"
	git init -q
	git config user.email "test@example.com"
	git config user.name "test"
	echo a >a.txt
	git add a.txt
	git -c commit.gpgsign=false commit -q -m "feat(api): add idempotency_key"
	echo b >b.txt
	git add b.txt
	git -c commit.gpgsign=false commit -q -m "fix(db): linear migration 0042"
)
run_close --slug 'orders' "$tmp" >/dev/null
file="$tmp/.scratchpad/dossier/closeout/phase-2-orders.md"
grep -q 'feat(api): add idempotency_key' "$file" ||
	fail "commits-landed should include feat(api): subject"
grep -q 'fix(db): linear migration 0042' "$file" ||
	fail "commits-landed should include fix(db): subject"
rm -rf "$tmp"

# 4. Findings closed vs deferred distinguished from §B fix column.
tmp="$(mkfix)"
run_close --slug 'findings' "$tmp" >/dev/null
file="$tmp/.scratchpad/dossier/closeout/phase-2-findings.md"
grep -q 'B1' "$file" || fail "should mention B1 (closed)"
grep -q 'B3' "$file" || fail "should mention B3 (closed)"
grep -q 'B2.*pending' "$file" || fail "B2 should appear under deferred with pending fix"
rm -rf "$tmp"

# 5. Refuses to overwrite without --force.
tmp="$(mkfix)"
run_close --slug 'orders' "$tmp" >/dev/null
if run_close --slug 'orders' "$tmp" 2>/dev/null; then
	fail "second run without --force should error"
fi
rm -rf "$tmp"

# 6. --force overwrites.
tmp="$(mkfix)"
run_close --slug 'orders' "$tmp" >/dev/null
file="$tmp/.scratchpad/dossier/closeout/phase-2-orders.md"
echo "MUTATED" >>"$file"
run_close --slug 'orders' --force "$tmp" >/dev/null
grep -q "MUTATED" "$file" && fail "--force should overwrite mutation"
rm -rf "$tmp"

# 7. Errors if SPEC.md missing.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-close-phase.XXXXXX")"
if run_close "$tmp" 2>/dev/null; then
	fail "missing SPEC.md should exit non-zero"
fi
rm -rf "$tmp"

# 8. --help.
out="$(run_close --help 2>/dev/null)"
grep -q -i 'usage' <<<"$out" || fail "--help should print usage"

# 9. Unknown flag -> exit 2.
if run_close --bogus 2>/dev/null; then
	fail "unknown flag should error"
fi

printf 'ok\n'
