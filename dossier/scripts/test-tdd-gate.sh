#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GATE="$SCRIPT_DIR/tdd-gate.py"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dossier-tdd-gate.XXXXXX")"

cleanup() {
	rm -rf "$TMP"
}
trap cleanup EXIT

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

run_gate() {
	local path="$1"
	printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}\n' "$path" |
		CLAUDE_PROJECT_DIR="$TMP" python3 "$GATE" 2>"$TMP/stderr"
}

cd "$TMP"
git init -q
git config user.email "dossier@example.invalid"
git config user.name "dossier test"
mkdir -p .scratchpad/dossier src
printf '# spec\n' >.scratchpad/dossier/SPEC.md
printf 'export const value = 1;\n' >src/app.ts
git add src/app.ts
git commit -qm "test: seed repo"

if run_gate "src/app.ts"; then
	fail "impl edit without evidence should block"
fi
grep -q "TDD gate" "$TMP/stderr" || fail "block message missing"

mkdir -p tests
printf 'test("value", () => {});\n' >tests/app.test.ts
run_gate "src/app.ts" || fail "untracked test evidence should allow impl edit"

rm tests/app.test.ts
mkdir -p src/_meta
printf 'test("config floor", () => {});\n' >src/_meta/config.test.ts
run_gate "src/app.ts" || fail "meta-gate evidence should allow impl edit"

printf '{"tool_name":"Write","tool_input":{"file_path":"tests/app.test.ts"}}\n' |
	CLAUDE_PROJECT_DIR="$TMP" python3 "$GATE" || fail "test file write should allow"

rm .scratchpad/dossier/SPEC.md
if ! run_gate "src/app.ts"; then
	fail "inactive dossier should allow edit"
fi

printf 'ok\n'
