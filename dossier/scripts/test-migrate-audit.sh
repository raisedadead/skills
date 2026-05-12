#!/usr/bin/env bash
# Coverage-lock test for migrate-audit.sh.
# Asserts: AUDIT.md §B rows ported into SPEC.md §B, duplicates skipped,
# --dry-run prints intent without writing, errors on bad state.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MIGRATE="$SCRIPT_DIR/migrate-audit.sh"

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

mkfix_full() {
	# Both SPEC.md and AUDIT.md present; AUDIT has §B rows.
	local tmp
	tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-migrate.XXXXXX")"
	mkdir -p "$tmp/.scratchpad/dossier"
	# shellcheck disable=SC2016
	{
		printf '# Phase 1 Spec\n\n'
		printf 'Flavor: `feature-wave`\n\n'
		printf '## §G Goal\n\nstub\n\n'
		printf '## §B Bugs / Findings\n\n'
		printf '| id | date | cause | fix |\n'
		printf '| -- | ---- | ----- | --- |\n'
		printf '| B3 | 2026-05-01 | existing row | pending |\n'
	} >"$tmp/.scratchpad/dossier/SPEC.md"
	{
		printf '# Audit Ledger — Phase 1\n\n'
		# shellcheck disable=SC2016
		printf 'Flavor: `feature-wave`\n\n'
		printf '## §B Findings\n\n'
		printf '| id | status | sev | surface | symptom / need | repro | fix | commit |\n'
		printf '| -- | ------ | --- | ------- | -------------- | ----- | --- | ------ |\n'
		printf '| B1 | . | S2 | api | nil ptr on retry | curl ... | - | - |\n'
		printf '| B2 | x | S3 | docs | stale link | manual | T2 | abc1234 |\n'
		printf '| B3 | ~ | S2 | api | already-in-SPEC | - | - | - |\n'
	} >"$tmp/.scratchpad/dossier/AUDIT.md"
	printf '%s' "$tmp"
}

# 1. Ports new rows into SPEC §B; skips duplicates by id.
tmp="$(mkfix_full)"
bash "$MIGRATE" "$tmp" >/dev/null
spec="$tmp/.scratchpad/dossier/SPEC.md"
grep -q '| B1 |' "$spec" || fail "B1 should be ported into SPEC §B"
grep -q '| B2 |' "$spec" || fail "B2 should be ported into SPEC §B"
# B3 already present — count occurrences in §B; should be 1, not 2.
n=$(awk '/^## §B/{cap=1} cap && /^\| B3 \|/{n++} END{print n+0}' "$spec")
[[ "$n" -eq 1 ]] || fail "B3 should not be duplicated (count=$n)"
rm -rf "$tmp"

# 2. Ported rows carry a date and cause derived from AUDIT symptom.
tmp="$(mkfix_full)"
bash "$MIGRATE" "$tmp" >/dev/null
spec="$tmp/.scratchpad/dossier/SPEC.md"
grep -qE '\| B1 \| [0-9]{4}-[0-9]{2}-[0-9]{2} \| nil ptr on retry' "$spec" ||
	fail "B1 row should carry ISO date and symptom-as-cause"
rm -rf "$tmp"

# 3. --dry-run prints intent without writing.
tmp="$(mkfix_full)"
spec="$tmp/.scratchpad/dossier/SPEC.md"
sha_before=$(shasum "$spec" | awk '{print $1}')
out="$(bash "$MIGRATE" --dry-run "$tmp" 2>/dev/null)"
sha_after=$(shasum "$spec" | awk '{print $1}')
[[ "$sha_before" == "$sha_after" ]] || fail "--dry-run should not modify SPEC.md"
grep -q 'would add: B1' <<<"$out" || fail "--dry-run should report B1 as would-add"
grep -q 'would add: B2' <<<"$out" || fail "--dry-run should report B2 as would-add"
grep -q 'skip: B3' <<<"$out" || fail "--dry-run should report B3 as already-present"
rm -rf "$tmp"

# 4. No AUDIT.md -> no-op exit 0.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-migrate.XXXXXX")"
mkdir -p "$tmp/.scratchpad/dossier"
printf '# Phase 1 Spec\n\n## §B Bugs / Findings\n\n' >"$tmp/.scratchpad/dossier/SPEC.md"
bash "$MIGRATE" "$tmp" >/dev/null || fail "no AUDIT.md should still exit 0"
rm -rf "$tmp"

# 5. No SPEC.md -> exit 1.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-migrate.XXXXXX")"
mkdir -p "$tmp/.scratchpad/dossier"
printf '# Audit\n## §B Findings\n' >"$tmp/.scratchpad/dossier/AUDIT.md"
if bash "$MIGRATE" "$tmp" 2>/dev/null; then
	fail "missing SPEC.md should error"
fi
rm -rf "$tmp"

# 6. AUDIT.md without a §B table -> no-op.
tmp="$(mktemp -d "${TMPDIR:-/tmp}/dossier-migrate.XXXXXX")"
mkdir -p "$tmp/.scratchpad/dossier"
printf '# Phase 1 Spec\n\n## §B Bugs / Findings\n\n' >"$tmp/.scratchpad/dossier/SPEC.md"
printf '# Audit\n\nNo table here.\n' >"$tmp/.scratchpad/dossier/AUDIT.md"
bash "$MIGRATE" "$tmp" >/dev/null || fail "AUDIT.md without §B should still exit 0"
rm -rf "$tmp"

# 7. --help.
out="$(bash "$MIGRATE" --help 2>/dev/null)"
grep -q -i 'usage' <<<"$out" || fail "--help should print usage"

# 8. Unknown flag.
if bash "$MIGRATE" --bogus 2>/dev/null; then
	fail "unknown flag should error"
fi

printf 'ok\n'
