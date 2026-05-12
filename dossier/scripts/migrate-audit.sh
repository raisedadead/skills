#!/usr/bin/env bash
# migrate-audit.sh — port legacy AUDIT.md §B rows into SPEC.md §B.
#
# Usage:
#   bash migrate-audit.sh [--dry-run] [<project-root>]
#
# Old dossiers carried two parallel finding tables: AUDIT.md §B (rich,
# eight columns) and SPEC.md §B (compact, four columns). SPEC.md §B is
# now the canonical ledger; AUDIT.md keeps only per-finding Detail
# sections.
#
# This script reads AUDIT.md, extracts every `B<n>` row not already
# present in SPEC.md §B, and appends a compact row to SPEC.md §B with:
#   id    = AUDIT.id
#   date  = today (YYYY-MM-DD)
#   cause = AUDIT.symptom (5th column of AUDIT §B)
#   fix   = AUDIT.fix (7th column) or 'pending' if absent
#
# Idempotent. Re-running adds nothing if SPEC already lists every id.
#
# Exits 0 on success / no-op, 1 if SPEC.md missing, 2 on unknown flag.

set -euo pipefail

DRY=0
ROOT="."

while [[ $# -gt 0 ]]; do
	case "$1" in
	--dry-run)
		DRY=1
		shift
		;;
	-h | --help)
		sed -n '2,20p' "$0"
		exit 0
		;;
	--*)
		printf 'error: unknown flag: %s\n' "$1" >&2
		exit 2
		;;
	*)
		ROOT="$1"
		shift
		;;
	esac
done

[[ -d "$ROOT" ]] || {
	printf "error: not a directory: %s\n" "$ROOT" >&2
	exit 1
}

DOSSIER="$ROOT/.scratchpad/dossier"
SPEC="$DOSSIER/SPEC.md"
AUDIT="$DOSSIER/AUDIT.md"

if [[ ! -f "$SPEC" ]]; then
	printf "error: SPEC.md missing (%s)\n" "$SPEC" >&2
	exit 1
fi

if [[ ! -f "$AUDIT" ]]; then
	printf "no AUDIT.md at %s — nothing to migrate\n" "$AUDIT"
	exit 0
fi

# Collect existing B-ids in SPEC §B.
existing_ids=$(awk '
  /^## §B/ { cap=1; next }
  cap && /^## / { cap=0 }
  cap && /^\| *B[0-9]+ *\|/ {
    n = split($0, a, "|")
    if (n >= 2) {
      id = a[2]; gsub(/^ +| +$/, "", id)
      print id
    }
  }
' "$SPEC")

is_in_spec() {
	local id="$1"
	grep -qx "$id" <<<"$existing_ids"
}

# Extract AUDIT §B rows (id, symptom, fix) into TSV.
audit_rows=$(awk '
  /^## §B/ { cap=1; next }
  cap && /^## / { cap=0 }
  cap && /^\| *B[0-9]+ *\|/ {
    n = split($0, a, "|")
    if (n >= 8) {
      id = a[2]; gsub(/^ +| +$/, "", id)
      symptom = a[6]; gsub(/^ +| +$/, "", symptom)
      fix = a[8]; gsub(/^ +| +$/, "", fix)
      if (fix == "" || fix == "-") fix = "pending"
      print id "\t" symptom "\t" fix
    }
  }
' "$AUDIT")

if [[ -z "$audit_rows" ]]; then
	printf "no §B rows found in %s — nothing to migrate\n" "$AUDIT"
	exit 0
fi

date_str=$(date +%Y-%m-%d)

new_rows=""
while IFS=$'\t' read -r id symptom fix; do
	[[ -z "$id" ]] && continue
	if is_in_spec "$id"; then
		if [[ "$DRY" -eq 1 ]]; then
			printf "skip: %s already in SPEC §B\n" "$id"
		fi
		continue
	fi
	if [[ "$DRY" -eq 1 ]]; then
		printf "would add: %s | %s | %s | %s\n" "$id" "$date_str" "$symptom" "$fix"
	else
		new_rows+="| $id | $date_str | $symptom | $fix |"$'\n'
	fi
done <<<"$audit_rows"

if [[ "$DRY" -eq 1 ]]; then
	exit 0
fi

if [[ -z "$new_rows" ]]; then
	printf "no new ids to port — SPEC §B already current\n"
	exit 0
fi

# Append new rows to SPEC.md. If §B has no table header yet, add one.
if ! grep -q '^| id | date | cause | fix |' "$SPEC"; then
	{
		printf '\n'
		printf '| id | date | cause | fix |\n'
		printf '| -- | ---- | ----- | --- |\n'
	} >>"$SPEC"
fi
printf '%s' "$new_rows" >>"$SPEC"

n=$(printf '%s' "$new_rows" | wc -l | tr -d ' ')
printf 'ported %s row(s) into %s\n' "$n" "$SPEC"
