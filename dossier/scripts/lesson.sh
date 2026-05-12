#!/usr/bin/env bash
# lesson.sh — append, list, or retire dossier lessons.
#
# Usage:
#   bash lesson.sh [--root <dir>] [--lessons-home <path>] "<lesson text>"
#   bash lesson.sh [--root <dir>] [--lessons-home <path>] --list
#   bash lesson.sh [--root <dir>] [--lessons-home <path>] --retire <Lid>
#
# Default file: <root>/.scratchpad/dossier/.lessons.md
# Override with --lessons-home <path> for a kernel-wide store.
# (When --lessons-home is set, --root is ignored for path resolution.)
#
# Rows are markdown table rows so the file stays human-readable and
# greppable. IDs are monotonic L<N>. Pipe characters in the lesson
# text are escaped to keep table cells intact.
#
# Exits 1 on missing args / unknown id, 2 on unknown flag.

set -euo pipefail

ROOT="."
LESSONS_HOME=""
ACTION="append"
RETIRE_ID=""
MSG=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--root)
		ROOT="${2:?--root requires a value}"
		shift 2
		;;
	--lessons-home)
		LESSONS_HOME="${2:?--lessons-home requires a value}"
		shift 2
		;;
	--list)
		ACTION="list"
		shift
		;;
	--retire)
		ACTION="retire"
		RETIRE_ID="${2:?--retire requires an id}"
		shift 2
		;;
	-h | --help)
		sed -n '2,17p' "$0"
		exit 0
		;;
	--*)
		printf 'error: unknown flag: %s\n' "$1" >&2
		exit 2
		;;
	*)
		if [[ -n "$MSG" ]]; then
			printf 'error: unexpected positional: %s\n' "$1" >&2
			exit 2
		fi
		MSG="$1"
		shift
		;;
	esac
done

if [[ -n "$LESSONS_HOME" ]]; then
	FILE="$LESSONS_HOME"
else
	FILE="$ROOT/.scratchpad/dossier/.lessons.md"
fi

ensure_file() {
	if [[ ! -f "$FILE" ]]; then
		mkdir -p "$(dirname "$FILE")"
		# shellcheck disable=SC2016 # backticks are literal markdown code spans
		{
			printf '# Dossier lessons\n\n'
			printf 'Append-only log of failure -> rule observations. Each row earned by\n'
			printf 'an actual past failure. Use `lesson.sh --retire <Lid>` to drop a\n'
			printf 'row when its rule is no longer needed.\n\n'
			printf '| id | date | lesson |\n'
			printf '| -- | ---- | ------ |\n'
		} >"$FILE"
	fi
}

next_id() {
	if [[ ! -f "$FILE" ]]; then
		printf 'L1'
		return
	fi
	# Take max numeric id from existing L<n> rows and add 1.
	awk -F'|' '
    /^\| L[0-9]+ \|/ {
      gsub(/^ +| +$/, "", $2)
      n = substr($2, 2) + 0
      if (n > max) max = n
    }
    END { print "L" (max + 1) }
  ' "$FILE"
}

escape_pipe() {
	# Replace literal pipe with HTML entity so the markdown table cell
	# stays a single field. Renderers display it as `|`; awk -F'|' sees
	# none.
	printf '%s' "$1" | sed 's/|/\&#124;/g'
}

case "$ACTION" in
append)
	if [[ -z "$MSG" ]]; then
		printf 'error: lesson text required (or use --list / --retire)\n' >&2
		exit 1
	fi
	ensure_file
	id=$(next_id)
	date=$(date +%Y-%m-%d)
	safe=$(escape_pipe "$MSG")
	printf '| %s | %s | %s |\n' "$id" "$date" "$safe" >>"$FILE"
	printf 'added: %s — %s\n' "$id" "$MSG"
	;;
list)
	[[ -f "$FILE" ]] || exit 0
	grep -E '^\| L[0-9]+ \|' "$FILE" || true
	;;
retire)
	if [[ ! -f "$FILE" ]]; then
		printf 'error: no lessons file at %s\n' "$FILE" >&2
		exit 1
	fi
	if ! grep -qE "^\| ${RETIRE_ID} \|" "$FILE"; then
		printf 'error: id %s not found in %s\n' "$RETIRE_ID" "$FILE" >&2
		exit 1
	fi
	tmp=$(mktemp "${TMPDIR:-/tmp}/dossier-lesson-retire.XXXXXX")
	grep -vE "^\| ${RETIRE_ID} \|" "$FILE" >"$tmp"
	mv "$tmp" "$FILE"
	printf 'retired: %s\n' "$RETIRE_ID"
	;;
esac
