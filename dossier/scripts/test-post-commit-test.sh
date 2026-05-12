#!/usr/bin/env bash
# Coverage-lock test for post-commit-test.py.
# Asserts: silent on green runner; emits stderr + exit 2 on red runner;
# silent when no runner present; ignores non-git-commit bash; ignores
# non-Bash tool events; bypass env disables.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/post-commit-test.py"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dossier-post-commit.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

# Build a git repo for the cwd-context of the hook.
build_repo() {
	local dir="$1"
	mkdir -p "$dir"
	(
		cd "$dir"
		git init -q
		git config user.email t@t
		git config user.name t
		echo a >a.txt
		git add a.txt
		git -c commit.gpgsign=false commit -q -m "init"
	)
}

# Build a project-supplied test-runner.sh that exits with $1.
install_runner() {
	local dir="$1" exit_code="$2" extra="${3:-}"
	mkdir -p "$dir/.scratchpad/dossier"
	cat >"$dir/.scratchpad/dossier/test-runner.sh" <<EOF
#!/usr/bin/env bash
${extra}
exit ${exit_code}
EOF
	chmod +x "$dir/.scratchpad/dossier/test-runner.sh"
}

# Run hook with a Bash event for "git commit".
run_commit_event() {
	local cwd="$1" cmd="${2:-git commit -m hello}"
	python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))
' "$cmd" | (cd "$cwd" && python3 "$HOOK") 2>"$TMP/stderr"
}

# 1. Silent on green runner.
build_repo "$TMP/r1"
install_runner "$TMP/r1" 0
run_commit_event "$TMP/r1" || fail "green runner should exit 0"
[[ -s "$TMP/stderr" ]] && fail "green runner should be silent on stderr"

# 2. Red runner -> exit 2 + verbose stderr.
build_repo "$TMP/r2"
install_runner "$TMP/r2" 1 "printf 'TESTS FAILED: regression in unit X\n' >&2"
if run_commit_event "$TMP/r2"; then
	fail "red runner should exit non-zero"
fi
grep -q 'post-commit-test:' "$TMP/stderr" || fail "stderr should cite the hook"
grep -q 'TESTS FAILED' "$TMP/stderr" || fail "stderr should forward runner output"

# 3. No runner present -> silent exit 0.
build_repo "$TMP/r3"
# (no install_runner)
mkdir -p "$TMP/r3/.scratchpad/dossier"
run_commit_event "$TMP/r3" || fail "missing runner should still exit 0"
[[ -s "$TMP/stderr" ]] && fail "missing runner should be silent"

# 4. Ignores non-git-commit Bash commands.
build_repo "$TMP/r4"
install_runner "$TMP/r4" 1 "printf 'should not be invoked\n' >&2"
run_commit_event "$TMP/r4" "ls -la" || fail "ls should not trigger hook"
grep -q 'should not be invoked' "$TMP/stderr" && fail "non-commit command should not run runner"

# 5. Ignores non-Bash tool events.
python3 -c '
import json
print(json.dumps({"tool_name": "Read", "tool_input": {"file_path": "x"}}))
' | (cd "$TMP/r4" && python3 "$HOOK") || fail "non-Bash tool should be ignored"

# 6. Bypass env disables hook.
build_repo "$TMP/r5"
install_runner "$TMP/r5" 1 "printf 'TESTS FAILED\n' >&2"
DOSSIER_POST_COMMIT_TEST=off run_commit_event "$TMP/r5" ||
	fail "bypass env should disable hook"

# 7. Hook tolerates malformed JSON (passes through).
echo "not json" | python3 "$HOOK" || fail "malformed JSON should pass through"

# 8. Hook passes runner the list of changed files in the last commit.
build_repo "$TMP/r6"
# Add a second commit so HEAD~1 exists.
(
	cd "$TMP/r6"
	echo b >b.txt
	git add b.txt
	git -c commit.gpgsign=false commit -q -m "second"
)
# Runner writes its args to a file we then inspect.
install_runner "$TMP/r6" 0 'printf "%s\n" "$@" > .scratchpad/dossier/runner-args.log'
run_commit_event "$TMP/r6" || fail "runner with args should exit 0"
grep -qx 'b.txt' "$TMP/r6/.scratchpad/dossier/runner-args.log" ||
	fail "runner should receive changed-file 'b.txt' as arg"

# 9. Compound git commands containing `git commit` still trigger.
build_repo "$TMP/r7"
install_runner "$TMP/r7" 1 "printf 'COMPOUND FAILED\n' >&2"
if run_commit_event "$TMP/r7" "git add foo && git commit -m bar"; then
	fail "compound containing git commit should still trigger and fail"
fi
grep -q 'COMPOUND FAILED' "$TMP/stderr" || fail "compound should run runner"

printf 'ok\n'
