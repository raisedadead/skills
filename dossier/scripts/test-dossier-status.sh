#!/usr/bin/env bash
# Coverage-lock test for dossier-status.sh.
# Asserts: parses SPEC.md, identifies active §T row, counts open §B,
# resolves lens symlink, errors on missing dossier.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS="$SCRIPT_DIR/dossier-status.sh"

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

mkfix() {
	mktemp -d "${TMPDIR:-/tmp}/dossier-status.XXXXXX"
}

write_spec() {
	# $1 = dossier-root, $2 = active-row-status (.|~|x), $3 = number of B rows
	local dir="$1" status="$2" bcount="$3"
	mkdir -p "$dir"
	# shellcheck disable=SC2016 # backticks in printf are literal markdown code spans
	{
		printf '# Phase 2 Spec\n\n'
		printf 'Flavor: `feature-wave`\n\n'
		printf '## §G Goal\n\n'
		printf 'ship checkout idempotency\n\n'
		printf '## §C Constraints\n\n- foo\n\n'
		printf '## §I Interfaces\n\n- bar\n\n'
		printf '## §V Invariants\n\n- V1: baz\n\n'
		printf '## §T Tasks\n\n'
		printf '| id | status | task | finding | cites |\n'
		printf '| -- | ------ | ---- | ------- | ----- |\n'
		printf '| T1 | x | landed earlier slice | B1 | V1 |\n'
		printf '| T2 | %s | the active slice now | C1 | V2 |\n' "$status"
		printf '| T3 | . | future slice | - | V3 |\n\n'
		printf '## §B Bugs / Findings\n\n'
		printf '| id | date | cause | fix |\n'
		printf '| -- | ---- | ----- | --- |\n'
		local i
		for ((i = 1; i <= bcount; i++)); do
			printf '| B%d | 2026-05-12 | root cause %d | pending |\n' "$i" "$i"
		done
	} >"$dir/SPEC.md"
}

# 1. Missing dossier -> exit 1.
tmp="$(mkfix)"
if bash "$STATUS" "$tmp" 2>/dev/null; then
	fail "missing dossier should exit non-zero"
fi
rm -rf "$tmp"

# 2. Basic banner shape (phase + flavor + goal + active + open-§B).
tmp="$(mkfix)"
write_spec "$tmp/.scratchpad/dossier" "~" 3
out="$(bash "$STATUS" "$tmp" 2>/dev/null)"
grep -q '^phase 2 / feature-wave' <<<"$out" || fail "phase/flavor line missing"
grep -q '^goal: ship checkout idempotency' <<<"$out" || fail "goal line missing"
grep -q '^active: T2 — the active slice now' <<<"$out" || fail "active row missing"
grep -q '^open §B: 3' <<<"$out" || fail "open §B count missing (expected 3)"
rm -rf "$tmp"

# 3. No active row (all . or x) -> active line says <none>.
tmp="$(mkfix)"
write_spec "$tmp/.scratchpad/dossier" "." 1
out="$(bash "$STATUS" "$tmp" 2>/dev/null)"
grep -q '^active: <none>' <<<"$out" || fail "no-active should show <none>"
rm -rf "$tmp"

# 4. Lens symlink resolves to lowercase name.
tmp="$(mkfix)"
write_spec "$tmp/.scratchpad/dossier" "~" 0
mkdir -p "$tmp/lenses"
printf '# Web frontend lens\n' >"$tmp/lenses/WEB-FRONTEND.md"
ln -s "$tmp/lenses/WEB-FRONTEND.md" "$tmp/.scratchpad/dossier/LENS.md"
out="$(bash "$STATUS" "$tmp" 2>/dev/null)"
grep -q 'lens: web-frontend' <<<"$out" || fail "lens name should resolve"
grep -q '^open §B: 0' <<<"$out" || fail "open §B should be 0"
rm -rf "$tmp"

# 5. No LENS.md -> lens: none.
tmp="$(mkfix)"
write_spec "$tmp/.scratchpad/dossier" "~" 0
out="$(bash "$STATUS" "$tmp" 2>/dev/null)"
grep -q 'lens: none' <<<"$out" || fail "missing LENS should print 'lens: none'"
rm -rf "$tmp"

# 6. Banner is bounded length (≤12 lines incl. fences).
tmp="$(mkfix)"
write_spec "$tmp/.scratchpad/dossier" "~" 3
out="$(bash "$STATUS" "$tmp" 2>/dev/null)"
n="$(wc -l <<<"$out" | tr -d ' ')"
[[ "$n" -le 12 ]] || fail "banner too long: $n lines"
rm -rf "$tmp"

# 7. --help works.
out="$(bash "$STATUS" --help 2>/dev/null)"
grep -q -i 'usage' <<<"$out" || fail "--help should print usage"

# 8. Unknown flag -> exit 2.
if bash "$STATUS" --bogus 2>/dev/null; then
	fail "unknown flag should error"
fi

printf 'ok\n'
