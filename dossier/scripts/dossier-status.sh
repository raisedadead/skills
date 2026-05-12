#!/usr/bin/env bash
# dossier-status.sh — render compact dossier state from disk.
#
# Usage:
#   bash dossier-status.sh [<project-root>]
#
# Reads .scratchpad/dossier/SPEC.md (and LENS.md if present) and prints
# a fixed-shape banner. Survives compact/handoff: if session memory is
# gone, this is the source of truth.
#
# Output (≤12 lines including fences):
#   ---
#   dossier @ <root>
#   phase <N> / <flavor> / lens: <name>
#   goal: <§G line>
#   active: <T-id> — <task text>   (or <none>)
#   open §B: <count>
#   recent:
#     <up to 5 git oneline commits>
#   ---
#
# Exits 0 on success, 1 if SPEC.md missing, 2 on unknown flag.

set -euo pipefail

ROOT="."

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		sed -n '2,22p' "$0"
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

DOSSIER="$ROOT/.scratchpad/dossier"
SPEC="$DOSSIER/SPEC.md"

if [[ ! -f "$SPEC" ]]; then
	printf "error: not in a dossier (no %s)\n" "$SPEC" >&2
	exit 1
fi

# Phase number from "# Phase N Spec" header.
phase=$(sed -n 's/^# Phase \([0-9][0-9]*\) Spec.*/\1/p' "$SPEC" | head -1)
phase="${phase:-?}"

# Flavor from "Flavor: `xxx`" line (backticks are literal markdown, not subst).
# shellcheck disable=SC2016
flavor=$(sed -n 's/^Flavor: *`\([^`]*\)`.*/\1/p' "$SPEC" | head -1)
flavor="${flavor:-?}"

# Goal: first non-empty content line under `## §G`.
goal=$(awk '
  /^## §G/ { cap=1; next }
  cap && /^## / { cap=0 }
  cap && NF { print; exit }
' "$SPEC")
goal="${goal:-<unset>}"

# Active task: first row in §T with status ~ — pulls id + task text.
active=$(awk '
  /^## §T/ { cap=1; next }
  cap && /^## / { cap=0 }
  cap && /^\| *[A-Z][0-9]+ *\| *~ *\|/ {
    n = split($0, a, "|")
    if (n >= 4) {
      id = a[2]; gsub(/^ +| +$/, "", id)
      task = a[4]; gsub(/^ +| +$/, "", task)
      print id " — " task
      exit
    }
  }
' "$SPEC")
active="${active:-<none>}"

# Open §B count: rows matching `| Bxx |` after the §B header.
open_b=$(awk '
  /^## §B/ { cap=1; next }
  cap && /^## / { cap=0 }
  cap && /^\| *B[0-9]+ *\|/ { n++ }
  END { print n+0 }
' "$SPEC")

# Lens: resolve symlink basename if present.
lens="none"
if [[ -L "$DOSSIER/LENS.md" ]]; then
	target=$(readlink "$DOSSIER/LENS.md")
	lens=$(basename "$target" .md | tr '[:upper:]' '[:lower:]')
elif [[ -f "$DOSSIER/LENS.md" ]]; then
	lens="custom"
fi

# Recent commits — at most 5, best-effort.
recent=""
if [[ -d "$ROOT/.git" ]] || git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
	recent=$(git -C "$ROOT" log --oneline -5 2>/dev/null || true)
fi

printf -- '---\n'
printf 'dossier @ %s\n' "$ROOT"
printf 'phase %s / %s / lens: %s\n' "$phase" "$flavor" "$lens"
printf 'goal: %s\n' "$goal"
printf 'active: %s\n' "$active"
printf 'open §B: %s\n' "$open_b"
if [[ -n "$recent" ]]; then
	printf 'recent:\n'
	while IFS= read -r line; do
		printf '  %s\n' "$line"
	done <<<"$recent"
fi
printf -- '---\n'
