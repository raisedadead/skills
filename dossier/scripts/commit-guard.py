#!/usr/bin/env python3
"""Dossier commit guard — PreToolUse hook for git/gh Bash commands.

Reads a hook JSON event on stdin. When `tool_name` is `Bash`, parses
the `command` field and blocks calls that violate the commit covenant
(see `dossier/references/COMMIT-GUARD-HOOK.md`).

Rules enforced (mirrors the negative table in COVENANT.md):

  CG1  `git add .` / `-A` / `--all` / `:/`         — never wildcard add
  CG2  `--no-verify` on git commands               — never bypass hooks
  CG3  `--no-gpg-sign` on git commands             — never bypass signing
  CG4  `git push`                                  — user-owned
  CG5  `gh pr create`                              — user-owned
  CG6  `git reset --hard` on a dirty tree          — may destroy WIP
  CG7  `git commit --amend` after push (HEAD on
       any `refs/remotes/*`)                       — rewrites public history
  CG8  HEREDOC inside `git commit`                 — triggers suspicious
                                                      tokens in commit-msg hooks
  CG9  Backticks inside the `-m` value             — command substitution risk

Bypass: `DOSSIER_COMMIT_GUARD=off`. Use only with rationale logged in
AUDIT.md.

Standalone hook — no kernel / personal dependencies. Wiring docs:
`dossier/references/COMMIT-GUARD-HOOK.md` covers Claude Code, OpenCode,
and Codex configs.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys

BYPASS_ENV = "DOSSIER_COMMIT_GUARD"


def split_chain(cmd: str) -> list[str]:
    """Split a bash command on `&&`, `||`, `;`, `|` at the top level.

    Naive split (does not parse quoting). Sufficient for catching
    `pwd && git push` and `echo x | git push`. False positives on a
    `|` inside a quoted commit message are tolerated because the
    invariant is "no banned subcommand anywhere in the line".
    """
    parts = re.split(r"&&|\|\||\||;", cmd)
    return [p.strip() for p in parts if p.strip()]


def tokens(subcmd: str) -> list[str]:
    try:
        return shlex.split(subcmd, posix=True)
    except ValueError:
        return subcmd.split()


def is_git_add_wildcard(toks: list[str]) -> bool:
    if toks[:2] != ["git", "add"]:
        return False
    bad = {".", "-A", "--all", "-a", ":/"}
    return any(t in bad for t in toks[2:])


def has_no_verify(toks: list[str]) -> bool:
    return toks[:1] == ["git"] and "--no-verify" in toks


def has_no_gpg_sign(toks: list[str]) -> bool:
    if toks[:1] != ["git"]:
        return False
    if "--no-gpg-sign" in toks:
        return True
    return any(t == "--gpg-sign=false" for t in toks)


def is_git_push(toks: list[str]) -> bool:
    return toks[:2] == ["git", "push"]


def is_gh_pr_create(toks: list[str]) -> bool:
    return toks[:3] == ["gh", "pr", "create"]


def commit_message_arg(toks: list[str]) -> str | None:
    """Return the `-m` / `--message=` value of a `git commit`, else None."""
    if toks[:2] != ["git", "commit"]:
        return None
    for i, t in enumerate(toks):
        if t == "-m" and i + 1 < len(toks):
            return toks[i + 1]
        if t.startswith("-m") and len(t) > 2:
            return t[2:]
        if t.startswith("--message="):
            return t[len("--message=") :]
    return None


def commit_heredoc_or_backtick(subcmd: str, toks: list[str]) -> str | None:
    if toks[:2] != ["git", "commit"]:
        return None
    if "<<" in subcmd:
        return "heredoc"
    msg = commit_message_arg(toks)
    if msg is not None and "`" in msg:
        return "backtick"
    return None


def is_git_reset_hard(toks: list[str]) -> bool:
    return toks[:2] == ["git", "reset"] and "--hard" in toks


def is_amend(toks: list[str]) -> bool:
    return toks[:2] == ["git", "commit"] and "--amend" in toks


def working_tree_dirty() -> bool:
    try:
        out = subprocess.check_output(
            ["git", "status", "--porcelain"],
            stderr=subprocess.DEVNULL,
            timeout=5,
        )
        return bool(out.strip())
    except (
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
        FileNotFoundError,
    ):
        return False


def head_on_remote_ref() -> bool:
    try:
        out = subprocess.check_output(
            ["git", "for-each-ref", "--points-at=HEAD", "refs/remotes"],
            stderr=subprocess.DEVNULL,
            timeout=5,
        )
        return bool(out.strip())
    except (
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
        FileNotFoundError,
    ):
        return False


def evaluate(subcmd: str, toks: list[str]) -> tuple[str, str] | None:
    """Return (rule_id, message) on violation, else None."""
    if is_git_add_wildcard(toks):
        return (
            "CG1",
            "`git add .` / `git add -A` catches unrelated drift, parallel-"
            "session work, and build artefacts. Stage explicit paths.",
        )
    if has_no_verify(toks):
        return (
            "CG2",
            "`--no-verify` bypasses pre-commit hooks. If a hook is broken, "
            "fix it; do not skip it.",
        )
    if has_no_gpg_sign(toks):
        return (
            "CG3",
            "`--no-gpg-sign` bypasses signing policy. Fix the signing path "
            "instead of skipping.",
        )
    if is_git_push(toks):
        return (
            "CG4",
            "`git push` is user-owned. Stop after the commit; let the user push.",
        )
    if is_gh_pr_create(toks):
        return (
            "CG5",
            "`gh pr create` is user-owned. Stop after the commit; let the "
            "user open the PR.",
        )
    if is_git_reset_hard(toks) and working_tree_dirty():
        return (
            "CG6",
            "`git reset --hard` on a dirty tree may destroy parallel-session "
            "WIP. Use `git restore --staged` or commit first.",
        )
    if is_amend(toks) and head_on_remote_ref():
        return (
            "CG7",
            "`git commit --amend` after the commit is on a remote ref "
            "rewrites public history. Land a new commit instead.",
        )
    kind = commit_heredoc_or_backtick(subcmd, toks)
    if kind == "heredoc":
        return (
            "CG8",
            "HEREDOC in `git commit` triggers suspicious-token checks in "
            "commit-msg hooks. Use a plain quoted string or `-F <file>`.",
        )
    if kind == "backtick":
        return (
            "CG9",
            "Backticks inside `-m` look like command substitution. Use a "
            "plain quoted string or escape the message.",
        )
    return None


def block(rule_id: str, message: str, subcmd: str) -> int:
    print(
        "\n".join(
            [
                f"dossier commit guard: blocked ({rule_id}).",
                "",
                f"  command: {subcmd}",
                f"  reason:  {message}",
                "",
                "See dossier/references/COMMIT-GUARD-HOOK.md for the full",
                "rule list. Emergency bypass: DOSSIER_COMMIT_GUARD=off,",
                "with rationale logged in AUDIT.md.",
            ]
        ),
        file=sys.stderr,
    )
    return 2


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

    for sub in split_chain(cmd):
        toks = tokens(sub)
        if not toks:
            continue
        if toks[0] not in ("git", "gh"):
            continue
        hit = evaluate(sub, toks)
        if hit is not None:
            return block(hit[0], hit[1], sub)

    return 0


if __name__ == "__main__":
    sys.exit(main())
