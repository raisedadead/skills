# Post-commit back-pressure hook

Optional `PostToolUse` hook on Bash. After a `git commit` lands, the hook runs a project-supplied test runner against the commit's changed files. Silent on green; verbose stderr + exit `2` on red so the runtime injects the failure into the agent's next turn.

Closes the "all green at task_done, red at phase boundary" gap that the article calls out: success silent, failure verbose, fed straight back into the loop.

Script: `scripts/post-commit-test.py`. Python 3 stdlib only. Standalone — no kernel-side or personal-config dependencies.

## Default OFF

The hook does nothing unless a project supplies `.scratchpad/dossier/test-runner.sh`. That keeps the harness opt-in per project even when wired globally. A sample shim:

```bash
#!/usr/bin/env bash
# .scratchpad/dossier/test-runner.sh
# $@ = changed paths in the last commit.
set -euo pipefail

if [[ "$#" -eq 0 ]]; then
  exit 0
fi

pnpm exec vitest run --related "$@" --reporter=basic
```

Variations per stack (one per lens) — pick the narrow-test command from `TDD.md` and scope it to `$@`:

```bash
# Go
go test -run "" -count=1 $(echo "$@" | xargs -n1 dirname | sort -u)

# Python
pytest --rootdir="$(git rev-parse --show-toplevel)" "$@"

# Rust
cargo test --no-fail-fast
```

The runner's exit code is what matters: `0` → silent green, anything else → red.

## Behavior

The hook fires when **all** hold:

- `tool_name` is `Bash`.
- Command contains a `git commit` somewhere in a `&&` / `;` / `|` chain.
- A `.git/` directory is reachable from cwd (walks up).
- `.scratchpad/dossier/test-runner.sh` exists and is readable.

The runner is invoked with the output of:

```bash
git diff --name-only HEAD~1 HEAD
```

On the initial commit (no `HEAD~1`), the path list is empty; the runner should treat that as "run nothing" or "run all" — operator's choice.

Exit codes from the hook:

| code | meaning                                                                             |
| ---- | ----------------------------------------------------------------------------------- |
| `0`  | Green (runner returned `0`), missing runner, missing repo, non-commit Bash, bypass. |
| `2`  | Red (runner returned non-zero). Stderr carries the failure + a pointer to this doc. |

## Claude Code wiring

Project-local `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 <skill-dir>/scripts/post-commit-test.py"
          }
        ]
      }
    ]
  }
}
```

Replace `<skill-dir>` with the installed dossier path. Stderr from the hook is injected into the agent's next turn, closing the back-pressure loop.

## OpenCode wiring

OpenCode `PostToolCall`:

```jsonc
{
  "hooks": {
    "PostToolCall": [
      {
        "match": { "tool": "Bash" },
        "command": ["python3", "<skill-dir>/scripts/post-commit-test.py"]
      }
    ]
  }
}
```

## Codex / generic runtime

For runtimes without a native post-tool hook, run the hook as a local commit hook (`.git/hooks/post-commit`) that synthesises the JSON event:

```bash
#!/usr/bin/env bash
# .git/hooks/post-commit
event="$(jq -nc --arg cmd "$(history 1 | sed 's/^[ 0-9]*//')" \
        '{tool_name:"Bash", tool_input:{command:$cmd}}')"
printf '%s' "$event" | python3 <skill-dir>/scripts/post-commit-test.py
```

The agent-facing back-pressure is lost in this fallback (no JSON event surface), but the developer sees the red signal locally.

## Bypass

`DOSSIER_POST_COMMIT_TEST=off` disables the hook for the current invocation. Use only with rationale logged in `AUDIT.md` (Detail section) or `SPEC.md §B`.

## Verify the hook

Self-contained smoke test:

```bash
bash <skill-dir>/scripts/test-post-commit-test.sh
```

Exits `0` on `ok`. Exercises green / red / no-runner / non-commit / non-Bash / bypass / malformed-JSON / changed-files argument passing / compound commands.
