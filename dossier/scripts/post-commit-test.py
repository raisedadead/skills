#!/usr/bin/env python3
"""Dossier post-commit back-pressure hook.

Reads a hook JSON event on stdin. When the event is a `Bash` tool call
whose command contains a `git commit`, run the project-supplied
`.scratchpad/dossier/test-runner.sh` against the last commit's changed
files.

Silent on green; verbose stderr + exit 2 on red. Exit 2 in a
PostToolUse context surfaces the failure back to the runtime so the
agent's next turn sees the regression — back-pressure as defined in
the harness-engineering article.

The runner is **operator-authored** and project-specific. The dossier
hook just decides when to invoke it. A sample shim:

    #!/usr/bin/env bash
    # .scratchpad/dossier/test-runner.sh
    # $@ = changed paths in the last commit.
    pnpm exec vitest run --related "$@" --reporter=basic

If the runner script is absent, the hook exits 0 silently. That keeps
the hook opt-in per project even when installed globally.

Bypass: `DOSSIER_POST_COMMIT_TEST=off`.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

BYPASS_ENV = "DOSSIER_POST_COMMIT_TEST"
RUNNER_REL = Path(".scratchpad/dossier/test-runner.sh")


def split_chain(cmd: str) -> list[str]:
    parts = re.split(r"&&|\|\||\||;", cmd)
    return [p.strip() for p in parts if p.strip()]


def looks_like_git_commit(cmd: str) -> bool:
    for sub in split_chain(cmd):
        toks = sub.split()
        if toks[:2] == ["git", "commit"]:
            return True
    return False


def find_repo_root(start: Path) -> Path | None:
    cur = start.resolve()
    while True:
        if (cur / ".git").exists():
            return cur
        if cur.parent == cur:
            return None
        cur = cur.parent


def changed_files(repo: Path) -> list[str]:
    """Return paths changed in the last commit. Empty list on failure
    or on the initial commit (no HEAD~1)."""
    try:
        out = subprocess.check_output(
            ["git", "-C", str(repo), "diff", "--name-only", "HEAD~1", "HEAD"],
            stderr=subprocess.DEVNULL,
            timeout=10,
        ).decode("utf-8", "replace")
    except (
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
        FileNotFoundError,
    ):
        return []
    return [line for line in out.splitlines() if line.strip()]


def run_runner(runner: Path, repo: Path, paths: list[str]) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            ["bash", str(runner), *paths],
            cwd=str(repo),
            capture_output=True,
            text=True,
            timeout=600,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError) as exc:
        return 1, f"post-commit-test: runner failed to launch: {exc}"
    combined = ""
    if proc.stdout:
        combined += proc.stdout
    if proc.stderr:
        combined += proc.stderr
    return proc.returncode, combined


def main() -> int:
    if os.environ.get(BYPASS_ENV) == "off":
        return 0

    try:
        event = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0

    if event.get("tool_name") != "Bash":
        return 0

    cmd = (event.get("tool_input") or {}).get("command")
    if not isinstance(cmd, str) or not cmd.strip():
        return 0

    if not looks_like_git_commit(cmd):
        return 0

    repo = find_repo_root(Path.cwd())
    if repo is None:
        return 0

    runner = repo / RUNNER_REL
    if not runner.is_file():
        return 0

    paths = changed_files(repo)
    rc, out = run_runner(runner, repo, paths)
    if rc == 0:
        return 0

    print(
        "\n".join(
            [
                "post-commit-test: red",
                f"  runner: {runner}",
                f"  changed paths: {len(paths)}",
                "",
                out.rstrip(),
                "",
                "See dossier/references/POST-COMMIT-HOOK.md.",
                "Emergency bypass: DOSSIER_POST_COMMIT_TEST=off (rationale in AUDIT.md).",
            ]
        ),
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
