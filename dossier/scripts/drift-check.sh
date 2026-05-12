#!/usr/bin/env bash
# drift-check.sh — deterministic drift report for a dossier phase.
#
# Usage:
#   bash drift-check.sh [--strict] [<project-root>]
#
# Checks three drift signals:
#   1. Phase / stage / audit-id markers in source files (mirrors
#      marker-guard.py patterns). Anything outside `.scratchpad/` and
#      ledger files (PLAN/SPEC/AUDIT/LENS.md) is reported.
#   2. In-flight §T rows in SPEC.md (status `~`).
#   3. Open §B rows in SPEC.md (fix column blank or contains the word
#      "pending"; placeholder `{...}` counts as open too).
#
# Output: one block per category, then a `summary: N drift signal(s)`
# tail. Exits 0 by default (advisory); `--strict` exits 3 on any drift.
#
# Exits 2 on unknown flag.

set -euo pipefail

STRICT=0
ROOT="."

while [[ $# -gt 0 ]]; do
	case "$1" in
	--strict)
		STRICT=1
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

if [[ ! -d "$ROOT" ]]; then
	printf "error: not a directory: %s\n" "$ROOT" >&2
	exit 1
fi

SPEC="$ROOT/.scratchpad/dossier/SPEC.md"

# Combined ERE: comment-prefixed phase/stage/step+digit OR PH<n>-<X><m>.
# Mirrors dossier/scripts/marker-guard.py MARKER_PATTERNS.
PATTERN='^[[:space:]]*(//+|#+|--|/\*+|\*[^/]|<!--|;)[[:space:]].*((phase|stage|step)[[:space:]]+[0-9]+|PH[0-9]+-[A-Z][0-9]+)'

list_candidate_files() {
	local raw
	if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
		raw=$(git -C "$ROOT" ls-files)
	else
		raw=$(cd "$ROOT" && find . -type f \
			-not -path './.git/*' \
			-not -path './node_modules/*' \
			-not -path './.scratchpad/*' 2>/dev/null |
			sed 's|^\./||')
	fi
	# Excludes: anything under .scratchpad/, ledger filenames anywhere.
	printf '%s\n' "$raw" |
		grep -vE '(^|/)\.scratchpad/' |
		grep -vE '(^|/)(SPEC|PLAN|AUDIT|LENS)\.md$' || true
}

# 1. Phase markers.
marker_lines=$(mktemp "${TMPDIR:-/tmp}/dossier-drift-markers.XXXXXX")
trap 'rm -f "$marker_lines"' EXIT

phase_markers=0
while IFS= read -r f; do
	[[ -z "$f" ]] && continue
	[[ -f "$ROOT/$f" ]] || continue
	# grep -i for case-insensitive, -n for line, -H for filename.
	hits=$(grep -inHE "$PATTERN" "$ROOT/$f" 2>/dev/null || true)
	if [[ -n "$hits" ]]; then
		while IFS= read -r line; do
			[[ -z "$line" ]] && continue
			# Strip leading "$ROOT/" prefix for readability.
			printf '  %s\n' "${line#"$ROOT"/}" >>"$marker_lines"
			phase_markers=$((phase_markers + 1))
		done <<<"$hits"
	fi
done < <(list_candidate_files)

# 2. In-flight §T rows.
inflight_lines=$(mktemp "${TMPDIR:-/tmp}/dossier-drift-inflight.XXXXXX")
inflight=0
if [[ -f "$SPEC" ]]; then
	while IFS= read -r row; do
		[[ -z "$row" ]] && continue
		printf '  %s\n' "$row" >>"$inflight_lines"
		inflight=$((inflight + 1))
	done < <(awk '
    /^## §T/ { cap=1; next }
    cap && /^## / { cap=0 }
    cap && /^\| *[A-Z][0-9]+ *\| *~ *\|/ {
      n = split($0, a, "|")
      if (n >= 4) {
        id = a[2]; gsub(/^ +| +$/, "", id)
        task = a[4]; gsub(/^ +| +$/, "", task)
        print id " — " task
      }
    }
  ' "$SPEC")
fi

# 3. Open §B rows.
openbug_lines=$(mktemp "${TMPDIR:-/tmp}/dossier-drift-openbug.XXXXXX")
openbug=0
if [[ -f "$SPEC" ]]; then
	while IFS= read -r row; do
		[[ -z "$row" ]] && continue
		printf '  %s\n' "$row" >>"$openbug_lines"
		openbug=$((openbug + 1))
	done < <(awk '
    /^## §B/ { cap=1; next }
    cap && /^## / { cap=0 }
    cap && /^\| *B[0-9]+ *\|/ {
      n = split($0, a, "|")
      if (n >= 5) {
        id = a[2]; gsub(/^ +| +$/, "", id)
        cause = a[4]; gsub(/^ +| +$/, "", cause)
        fix = a[5]; gsub(/^ +| +$/, "", fix)
        # Open if fix is empty, "pending", a placeholder, or a dash.
        if (fix == "" || fix == "-" || tolower(fix) == "pending" || fix ~ /^\{.*\}$/) {
          print id ": " cause " — " (fix == "" ? "(empty)" : fix)
        }
      }
    }
  ' "$SPEC")
fi

# Cleanup tempfiles on exit.
trap 'rm -f "$marker_lines" "$inflight_lines" "$openbug_lines"' EXIT

total=$((phase_markers + inflight + openbug))

printf 'drift-check @ %s\n' "$ROOT"
printf 'phase markers: %s\n' "$phase_markers"
if [[ "$phase_markers" -gt 0 ]]; then cat "$marker_lines"; fi
printf 'in-flight §T: %s\n' "$inflight"
if [[ "$inflight" -gt 0 ]]; then cat "$inflight_lines"; fi
printf 'open §B: %s\n' "$openbug"
if [[ "$openbug" -gt 0 ]]; then cat "$openbug_lines"; fi
printf 'summary: %s drift signal(s)\n' "$total"

if [[ "$STRICT" -eq 1 && "$total" -gt 0 ]]; then
	exit 3
fi
exit 0
