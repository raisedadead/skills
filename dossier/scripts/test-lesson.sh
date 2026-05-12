#!/usr/bin/env bash
# Coverage-lock test for lesson.sh.
# Asserts: append creates the lessons file, IDs are monotonic, --list
# prints entries, --retire removes by id, --lessons-home redirects
# target file, errors on bad input.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LESSON="$SCRIPT_DIR/lesson.sh"

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

mkfix() {
	mktemp -d "${TMPDIR:-/tmp}/dossier-lesson.XXXXXX"
}

# 1. Append creates file with header + first L1 entry.
tmp="$(mkfix)"
bash "$LESSON" --root "$tmp" "first lesson" >/dev/null
target="$tmp/.scratchpad/dossier/.lessons.md"
[[ -f "$target" ]] || fail "append should create lessons file"
grep -q '^# Dossier lessons' "$target" || fail "should write header"
grep -q '| L1 |.*first lesson' "$target" || fail "should write L1 row"
rm -rf "$tmp"

# 2. IDs increment monotonically.
tmp="$(mkfix)"
bash "$LESSON" --root "$tmp" "one" >/dev/null
bash "$LESSON" --root "$tmp" "two" >/dev/null
bash "$LESSON" --root "$tmp" "three" >/dev/null
target="$tmp/.scratchpad/dossier/.lessons.md"
grep -q '| L1 |.*one' "$target" || fail "L1 missing"
grep -q '| L2 |.*two' "$target" || fail "L2 missing"
grep -q '| L3 |.*three' "$target" || fail "L3 missing"
rm -rf "$tmp"

# 3. --list prints lesson rows.
tmp="$(mkfix)"
bash "$LESSON" --root "$tmp" "alpha" >/dev/null
bash "$LESSON" --root "$tmp" "beta" >/dev/null
out="$(bash "$LESSON" --root "$tmp" --list 2>/dev/null)"
grep -q 'L1.*alpha' <<<"$out" || fail "--list should show L1"
grep -q 'L2.*beta' <<<"$out" || fail "--list should show L2"
rm -rf "$tmp"

# 4. --list on missing file -> empty output, exit 0.
tmp="$(mkfix)"
out="$(bash "$LESSON" --root "$tmp" --list 2>/dev/null)"
[[ -z "$out" ]] || fail "--list on missing should print empty"
rm -rf "$tmp"

# 5. --retire removes by id.
tmp="$(mkfix)"
bash "$LESSON" --root "$tmp" "a" >/dev/null
bash "$LESSON" --root "$tmp" "b" >/dev/null
bash "$LESSON" --root "$tmp" "c" >/dev/null
bash "$LESSON" --root "$tmp" --retire L2 >/dev/null
target="$tmp/.scratchpad/dossier/.lessons.md"
grep -q '| L2 |' "$target" && fail "L2 should be removed"
grep -q '| L1 |' "$target" || fail "L1 should remain"
grep -q '| L3 |' "$target" || fail "L3 should remain"
rm -rf "$tmp"

# 6. --retire unknown id -> exit non-zero.
tmp="$(mkfix)"
bash "$LESSON" --root "$tmp" "x" >/dev/null
if bash "$LESSON" --root "$tmp" --retire L99 2>/dev/null; then
	fail "retire unknown should error"
fi
rm -rf "$tmp"

# 7. --lessons-home redirects to that path.
tmp="$(mkfix)"
home="$tmp/global-lessons.md"
bash "$LESSON" --lessons-home "$home" "global one" >/dev/null
[[ -f "$home" ]] || fail "--lessons-home should write to chosen path"
grep -q 'global one' "$home" || fail "--lessons-home content missing"
# Default location must NOT also be created.
[[ -f "$tmp/.scratchpad/dossier/.lessons.md" ]] && fail "default file should not exist when --lessons-home used"
rm -rf "$tmp"

# 8. Dates are ISO YYYY-MM-DD.
tmp="$(mkfix)"
bash "$LESSON" --root "$tmp" "dated" >/dev/null
target="$tmp/.scratchpad/dossier/.lessons.md"
grep -qE '\| L1 \| [0-9]{4}-[0-9]{2}-[0-9]{2} \|' "$target" ||
	fail "row should carry ISO date"
rm -rf "$tmp"

# 9. --help.
out="$(bash "$LESSON" --help 2>/dev/null)"
grep -q -i 'usage' <<<"$out" || fail "--help should print usage"

# 10. Unknown flag.
if bash "$LESSON" --bogus 2>/dev/null; then
	fail "unknown flag should error"
fi

# 11. No message and no action -> error.
tmp="$(mkfix)"
if bash "$LESSON" --root "$tmp" 2>/dev/null; then
	fail "missing message + no action should error"
fi
rm -rf "$tmp"

# 12. Pipe characters in lesson text escape so table stays valid.
tmp="$(mkfix)"
bash "$LESSON" --root "$tmp" "uses | pipe character" >/dev/null
target="$tmp/.scratchpad/dossier/.lessons.md"
# Final row should still have exactly 4 |-cells (id|date|lesson + framing pipes = 4 |s)
last=$(grep '^| L1 |' "$target")
nbar=$(awk -F'|' '{print NF-1}' <<<"$last")
[[ "$nbar" -eq 4 ]] || fail "pipe in lesson should be escaped (cells: $nbar)"
rm -rf "$tmp"

printf 'ok\n'
