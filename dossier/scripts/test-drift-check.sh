#!/usr/bin/env bash
# Coverage-lock test for drift-check.sh.
# Asserts phase-marker grep, in-flight §T detection, open §B count,
# advisory vs --strict exit codes, dossier path exclusions.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DRIFT="$SCRIPT_DIR/drift-check.sh"

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

mkfix() {
	local tmp
	tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-drift.XXXXXX")"
	mkdir -p "$tmp/.scratchpad/dossier"
	# Minimal SPEC.md so drift-check has something to read.
	{
		printf '# Phase 1 Spec\n\n'
		# shellcheck disable=SC2016
		printf 'Flavor: `feature-wave`\n\n'
		printf '## §G Goal\n\nstub\n\n'
		printf '## §T Tasks\n\n'
		printf '| id | status | task | finding | cites |\n'
		printf '| -- | ------ | ---- | ------- | ----- |\n'
		printf '| T1 | x | done slice | B1 | V1 |\n\n'
		printf '## §B Bugs / Findings\n\n'
		printf '| id | date | cause | fix |\n'
		printf '| -- | ---- | ----- | --- |\n'
	} >"$tmp/.scratchpad/dossier/SPEC.md"
	printf '%s' "$tmp"
}

with_active_task() {
	# Append an in-flight ~ row to §T.
	local dir="$1"
	# rewrite: insert "| T2 | ~ | active | C1 | V2 |" before §B header.
	awk '
    /^## §B/ && !done {
      print "| T2 | ~ | the active slice now | C1 | V2 |"
      print ""
      done=1
    }
    { print }
  ' "$dir/.scratchpad/dossier/SPEC.md" >"$dir/.scratchpad/dossier/SPEC.md.new"
	mv "$dir/.scratchpad/dossier/SPEC.md.new" "$dir/.scratchpad/dossier/SPEC.md"
}

with_open_bug() {
	local dir="$1"
	printf '| B1 | 2026-05-12 | nil-deref in handler | pending |\n' \
		>>"$dir/.scratchpad/dossier/SPEC.md"
}

# 1. Clean fixture (no markers, no in-flight, no open §B) -> summary 0.
tmp="$(mkfix)"
out="$(bash "$DRIFT" "$tmp" 2>/dev/null)"
grep -q '^summary: 0 drift signal' <<<"$out" || fail "clean should report 0 signals"
rm -rf "$tmp"

# 2. Phase marker in source -> reported.
tmp="$(mkfix)"
mkdir -p "$tmp/src"
printf '// Phase 1: setup\nfn main() {}\n' >"$tmp/src/foo.rs"
out="$(bash "$DRIFT" "$tmp" 2>/dev/null)"
grep -q '^phase markers: 1' <<<"$out" || fail "should report 1 phase marker"
grep -q 'src/foo.rs' <<<"$out" || fail "should cite offending file"
rm -rf "$tmp"

# 3. Marker inside dossier ledger -> ignored.
tmp="$(mkfix)"
printf '# Phase 3 plan\n- Step 2: probe\n' >"$tmp/.scratchpad/dossier/PLAN.md"
out="$(bash "$DRIFT" "$tmp" 2>/dev/null)"
grep -q '^phase markers: 0' <<<"$out" || fail "markers in PLAN.md should be ignored"
rm -rf "$tmp"

# 4. Python `# Stage 3` marker outside dossier -> reported.
tmp="$(mkfix)"
printf '# Stage 3: ready\nprint(1)\n' >"$tmp/app.py"
out="$(bash "$DRIFT" "$tmp" 2>/dev/null)"
grep -q '^phase markers: 1' <<<"$out" || fail "should catch Stage marker"
rm -rf "$tmp"

# 5. PH<N>-<X><M> audit-id form caught.
tmp="$(mkfix)"
printf '// PH3-B7: known\nconst x = 1;\n' >"$tmp/x.ts"
out="$(bash "$DRIFT" "$tmp" 2>/dev/null)"
grep -q '^phase markers: 1' <<<"$out" || fail "should catch audit-id form"
rm -rf "$tmp"

# 6. Phase string inside string literal (not in comment column) -> not caught.
tmp="$(mkfix)"
printf 'const labels = { phase1: "Phase 1: setup" };\n' >"$tmp/x.ts"
out="$(bash "$DRIFT" "$tmp" 2>/dev/null)"
grep -q '^phase markers: 0' <<<"$out" || fail "string-literal phase should not match"
rm -rf "$tmp"

# 7. In-flight §T task reported.
tmp="$(mkfix)"
with_active_task "$tmp"
out="$(bash "$DRIFT" "$tmp" 2>/dev/null)"
grep -q '^in-flight §T: 1' <<<"$out" || fail "should report 1 in-flight task"
grep -q 'T2.*the active slice now' <<<"$out" || fail "should cite in-flight row"
rm -rf "$tmp"

# 8. Open §B reported.
tmp="$(mkfix)"
with_open_bug "$tmp"
out="$(bash "$DRIFT" "$tmp" 2>/dev/null)"
grep -q '^open §B: 1' <<<"$out" || fail "should count open bug row"
rm -rf "$tmp"

# 9. Summary tallies across categories.
tmp="$(mkfix)"
with_active_task "$tmp"
with_open_bug "$tmp"
printf '// Phase 1: setup\n' >"$tmp/x.go"
out="$(bash "$DRIFT" "$tmp" 2>/dev/null)"
grep -q '^summary: 3 drift signal' <<<"$out" || fail "summary should tally 3"
rm -rf "$tmp"

# 10. Advisory exit (default) = 0 even with drift.
tmp="$(mkfix)"
printf '// Phase 1: setup\n' >"$tmp/x.go"
bash "$DRIFT" "$tmp" >/dev/null 2>&1 || fail "default mode should exit 0 even with drift"
rm -rf "$tmp"

# 11. --strict exits 3 when drift present.
tmp="$(mkfix)"
printf '// Phase 1: setup\n' >"$tmp/x.go"
set +e
bash "$DRIFT" --strict "$tmp" >/dev/null 2>&1
ec=$?
set -e
[[ "$ec" -eq 3 ]] || fail "--strict on drift should exit 3, got $ec"
rm -rf "$tmp"

# 12. --strict exits 0 on clean fixture.
tmp="$(mkfix)"
bash "$DRIFT" --strict "$tmp" >/dev/null 2>&1 || fail "--strict clean should exit 0"
rm -rf "$tmp"

# 13. Missing SPEC.md still scans for markers but skips §T/§B sections.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-drift.XXXXXX")"
printf '// Phase 1: setup\n' >"$tmp/x.go"
out="$(bash "$DRIFT" "$tmp" 2>/dev/null)"
grep -q '^phase markers: 1' <<<"$out" || fail "no-dossier mode should still grep markers"
rm -rf "$tmp"

# 14. Unknown flag -> exit 2.
if bash "$DRIFT" --bogus 2>/dev/null; then
	fail "unknown flag should error"
fi

# 15. --help.
out="$(bash "$DRIFT" --help 2>/dev/null)"
grep -q -i 'usage' <<<"$out" || fail "--help should print usage"

printf 'ok\n'
