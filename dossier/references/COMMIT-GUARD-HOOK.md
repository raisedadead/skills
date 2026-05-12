# Commit guard hook

Optional `PreToolUse` hook on Bash tool calls. Inspects the `command` string and blocks `git` / `gh` invocations that violate the dossier commit covenant.

Script: `scripts/commit-guard.py`. Python 3 stdlib only. Standalone — no kernel-side or personal-config dependencies. Works for any project that adopts the dossier skill.

## What it blocks

Each rule fires only on `git` or `gh` sub-commands; everything else passes through.

| id  | pattern                                           | reason                                                                 |
| --- | ------------------------------------------------- | ---------------------------------------------------------------------- |
| CG1 | `git add .` / `-A` / `--all` / `:/`               | Wildcard adds catch unrelated drift, parallel-session work, artefacts. |
| CG2 | `--no-verify` on any git command                  | Pre-commit hooks exist for a reason. If broken, fix them.              |
| CG3 | `--no-gpg-sign` / `--gpg-sign=false`              | Signing policy bypass.                                                 |
| CG4 | `git push`                                        | User-owned. Dossier stops at the commit.                               |
| CG5 | `gh pr create`                                    | User-owned. Dossier stops at the commit.                               |
| CG6 | `git reset --hard` on a dirty tree                | May destroy parallel-session WIP.                                      |
| CG7 | `git commit --amend` when HEAD is on a remote ref | Rewrites public history. Land a new commit instead.                    |
| CG8 | HEREDOC inside `git commit`                       | Triggers suspicious-token checks in commit-msg hooks.                  |
| CG9 | Backticks inside `git commit -m "..."`            | Looks like command substitution.                                       |

CG6 and CG7 probe the working tree with read-only `git` calls (`status --porcelain`, `for-each-ref`). Both have 5-second timeouts and fall back to "allow" if the probe fails.

## Behavior

Exit `0`: allow command. Exit `2`: block and feed stderr to the runtime.

Pass-through cases:

- `tool_name` other than `Bash`.
- Command string empty or whitespace-only.
- Sub-command first token is not `git` or `gh`.
- Bypass env set: `DOSSIER_COMMIT_GUARD=off`.

Chains and pipelines (`pwd && git push`, `echo x | git push`) are split on `&&`, `||`, `;`, `|` and each segment is evaluated. False positives on `|` inside a quoted commit message are acceptable because the invariant is "no banned sub-command anywhere on the line".

Block message tells the operator:

- Which rule fired (e.g. `CG1`).
- The exact command segment that triggered.
- A one-line reason citing the covenant.
- Where to find the rule list and how to bypass.

## Claude Code wiring

Project-local `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 <skill-dir>/scripts/commit-guard.py"
          }
        ]
      }
    ]
  }
}
```

Replace `<skill-dir>` with the installed dossier path (vendored, plugin-installed, or absolute). Co-installs cleanly with `tdd-gate.py` and `marker-guard.py`.

## OpenCode wiring

OpenCode exposes a `PreToolCall` hook with a near-identical payload shape. Register the script as a hook command in your OpenCode config:

```jsonc
{
  "hooks": {
    "PreToolCall": [
      {
        "match": { "tool": "Bash" },
        "command": ["python3", "<skill-dir>/scripts/commit-guard.py"]
      }
    ]
  }
}
```

The script reads the event from stdin and exits non-zero to block.

## Codex / generic runtime

For runtimes without a native PreToolUse mechanism, wrap shell calls through a thin script that pipes the JSON event into the guard:

```bash
#!/usr/bin/env bash
event="$(jq -nc --arg cmd "$*" '{tool_name:"Bash", tool_input:{command:$cmd}}')"
printf '%s' "$event" | python3 <skill-dir>/scripts/commit-guard.py || exit 2
exec "$@"
```

Wire this wrapper as the `git` / `gh` entry point in PATH ahead of the real binaries. Suitable for headless / batch runtimes.

## Bypass

`DOSSIER_COMMIT_GUARD=off` disables the guard for the current invocation. Use only with rationale logged in `AUDIT.md`. The same rationale should reference the rule id (`CG<n>`) and explain why this particular bypass is necessary.

## Verify the guard

Self-contained smoke test:

```bash
bash <skill-dir>/scripts/test-commit-guard.sh
```

Exits `0` on `ok`. Run after editing `commit-guard.py` or any rule predicate.
