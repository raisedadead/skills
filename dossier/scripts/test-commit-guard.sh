#!/usr/bin/env bash
# Coverage-lock test for commit-guard.py.
# Asserts: blocks the 9 COVENANT.md negative-table rules that map to
# git/gh subcommands; allows clean usage; bypass env disables guard.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARD="$SCRIPT_DIR/commit-guard.py"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dossier-commit-guard.XXXXXX")"

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

# Emit a Bash-tool hook payload with the given command.
run_bash() {
	local cmd="$1"
	python3 -c '
import json, sys
print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))
' "$cmd" | python3 "$GUARD" 2>"$TMP/stderr"
}

cd "$TMP"

# Rule CG1: git add . / -A / --all / :/
for arg in "." "-A" "--all" ":/"; do
	if run_bash "git add $arg"; then
		fail "CG1 should block 'git add $arg'"
	fi
	grep -q 'CG1' "$TMP/stderr" || fail "stderr should cite CG1 for arg=$arg"
done

# Allow explicit path.
run_bash "git add src/foo.ts" || fail "git add <path> should be allowed"

# Rule CG2: --no-verify.
if run_bash 'git commit -m "feat(x): subject" --no-verify'; then
	fail "CG2 should block --no-verify"
fi
grep -q 'CG2' "$TMP/stderr" || fail "stderr should cite CG2"

# Rule CG3: --no-gpg-sign.
if run_bash 'git commit -m "feat(x): subject" --no-gpg-sign'; then
	fail "CG3 should block --no-gpg-sign"
fi
grep -q 'CG3' "$TMP/stderr" || fail "stderr should cite CG3"

# Rule CG4: git push.
if run_bash 'git push'; then
	fail "CG4 should block git push"
fi
grep -q 'CG4' "$TMP/stderr" || fail "stderr should cite CG4"

# Rule CG4 also blocks push variants.
if run_bash 'git push --force-with-lease origin main'; then
	fail "CG4 should block git push --force-with-lease"
fi

# Rule CG5: gh pr create.
if run_bash 'gh pr create --title x'; then
	fail "CG5 should block gh pr create"
fi
grep -q 'CG5' "$TMP/stderr" || fail "stderr should cite CG5"

# Rule CG6: git reset --hard on a DIRTY tree.
mkdir -p "$TMP/repo"
(
	cd "$TMP/repo"
	git init -q
	git config user.email t@t
	git config user.name t
	echo a >a.txt
	git add a.txt
	git -c commit.gpgsign=false commit -q -m "init"
	echo b >>a.txt # dirty the tree
)
# Run guard with cwd = dirty repo.
(
	cd "$TMP/repo"
	if run_bash 'git reset --hard'; then
		fail "CG6 should block git reset --hard on dirty tree"
	fi
	grep -q 'CG6' "$TMP/stderr" || fail "stderr should cite CG6"
)

# CG6 should NOT block on a clean tree.
(
	cd "$TMP/repo"
	git checkout -q -- a.txt
	# Now clean. CG6 must allow reset --hard.
	if ! run_bash 'git reset --hard'; then
		grep -q 'CG6' "$TMP/stderr" && fail "CG6 should allow on clean tree"
	fi
)

# Rule CG7: git commit --amend when HEAD is already on a remote ref.
(
	cd "$TMP/repo"
	# Fake a remote-tracking ref pointing at HEAD.
	git update-ref refs/remotes/origin/main HEAD
	if run_bash 'git commit --amend --no-edit'; then
		fail "CG7 should block amend after push"
	fi
	grep -q 'CG7' "$TMP/stderr" || fail "stderr should cite CG7"
)

# CG7 should not block amend if HEAD isn't on a remote ref.
(
	cd "$TMP/repo"
	git update-ref -d refs/remotes/origin/main
	# Now no remote ref. Amend should be allowed.
	run_bash 'git commit --amend --no-edit' || true
	grep -q 'CG7' "$TMP/stderr" && fail "CG7 should allow amend pre-push"
) || true

# Rule CG8: HEREDOC in git commit.
if run_bash $'git commit -m "$(cat <<EOF\nfeat\nEOF\n)"'; then
	fail "CG8 should block HEREDOC in commit"
fi
grep -q 'CG8' "$TMP/stderr" || fail "stderr should cite CG8"

# Rule CG9: backticks in commit -m.
# shellcheck disable=SC2016 # backticks are the literal pattern we're testing
if run_bash 'git commit -m "feat: `whoami` did it"'; then
	fail "CG9 should block backticks in -m"
fi
grep -q 'CG9' "$TMP/stderr" || fail "stderr should cite CG9"

# Allow normal Conventional Commits subjects.
run_bash 'git commit -m "feat(api): add idempotency_key"' ||
	fail "clean conventional commit should be allowed"

# Bypass env disables guard.
DOSSIER_COMMIT_GUARD=off run_bash 'git push' ||
	fail "bypass env should disable the guard"

# Non-git/gh commands pass through.
run_bash 'echo hello world' || fail "non-git commands should pass through"
run_bash 'ls -la' || fail "ls should pass through"

# Non-Bash tool calls pass through (no command field).
python3 -c '
import json
print(json.dumps({"tool_name": "Read", "tool_input": {"file_path": "x"}}))
' | python3 "$GUARD" || fail "non-Bash tool calls should pass through"

# Chained commands: bad inside an && chain still blocks.
if run_bash 'pwd && git push'; then
	fail "git push inside chain should still block"
fi

# Pipeline: bad inside a pipe still blocks.
if run_bash 'echo x | git push'; then
	fail "git push at pipeline tail should still block"
fi

printf 'ok\n'
