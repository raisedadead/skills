#!/usr/bin/env python3
"""Claude Code PreToolUse TDD gate for dossier projects.

Reads hook JSON on stdin. Blocks implementation/config edits when an
active `.scratchpad/dossier/SPEC.md` exists and no sibling test,
meta-gate, contract, golden, or recorded output is present in the
current worktree.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

GUARDED_EXTS = {
    ".astro",
    ".c",
    ".cc",
    ".cpp",
    ".css",
    ".go",
    ".graphql",
    ".h",
    ".hcl",
    ".hpp",
    ".java",
    ".js",
    ".jsx",
    ".kt",
    ".lua",
    ".php",
    ".proto",
    ".py",
    ".rb",
    ".rs",
    ".scss",
    ".sql",
    ".svelte",
    ".swift",
    ".tf",
    ".toml",
    ".ts",
    ".tsx",
    ".vue",
    ".xml",
    ".yaml",
    ".yml",
}

GUARDED_NAMES = {
    "Dockerfile",
    "Makefile",
    "package.json",
    "pyproject.toml",
    "Cargo.toml",
    "go.mod",
    "go.work",
}

SKIP_DIRS = {
    ".git",
    ".scratchpad",
    "docs",
    "node_modules",
    "vendor",
}

TEST_DIRS = {
    "__snapshots__",
    "__tests__",
    "_meta",
    "e2e",
    "fixtures",
    "golden",
    "goldens",
    "integration",
    "spec",
    "specs",
    "test",
    "tests",
}

TEST_SUFFIXES = (
    ".bats",
    ".snap",
    ".spec.js",
    ".spec.jsx",
    ".spec.ts",
    ".spec.tsx",
    ".test.js",
    ".test.jsx",
    ".test.py",
    ".test.ts",
    ".test.tsx",
    "_spec.rb",
    "_test.go",
    "_test.py",
)

EVIDENCE_TOKENS = (
    "api-surface",
    "contract",
    "golden",
    "manifest",
    "openapi",
    "schema",
    "snapshot",
)


def run_git(root: Path, *args: str) -> list[str]:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        check=False,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        return []
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def git_root(start: Path) -> Path | None:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=start,
        check=False,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        return None
    return Path(result.stdout.strip()).resolve()


def hook_path(event: dict) -> str | None:
    tool_input = event.get("tool_input") or {}
    value = tool_input.get("file_path") or tool_input.get("path")
    return str(value) if value else None


def rel_path(root: Path, raw_path: str) -> str | None:
    path = Path(raw_path)
    if not path.is_absolute():
        path = root / path
    try:
        return path.resolve().relative_to(root).as_posix()
    except ValueError:
        return None


def parts(path: str) -> set[str]:
    return {part.lower() for part in Path(path).parts}


def is_evidence(path: str) -> bool:
    lower = path.lower()
    name = Path(lower).name
    if parts(lower) & TEST_DIRS:
        return True
    if name.endswith(TEST_SUFFIXES):
        return True
    return any(token in lower for token in EVIDENCE_TOKENS)


def is_guarded(path: str) -> bool:
    path_parts = parts(path)
    if path_parts & SKIP_DIRS:
        return False
    if is_evidence(path):
        return False
    p = Path(path)
    if p.name in GUARDED_NAMES:
        return True
    return p.suffix in GUARDED_EXTS


def changed_paths(root: Path) -> list[str]:
    paths = run_git(root, "diff", "--name-only", "HEAD")
    paths += run_git(root, "ls-files", "--others", "--exclude-standard")
    return sorted(set(paths))


def active_dossier(root: Path) -> bool:
    return (root / ".scratchpad" / "dossier" / "SPEC.md").is_file()


def block(path: str) -> int:
    print(
        "\n".join(
            [
                f"TDD gate: editing impl/config file '{path}' without",
                "a sibling test, meta-gate, contract, golden, or recorded",
                "output in the current worktree.",
                "",
                "Write or update the failing behavior test first, run the",
                "narrow test to confirm RED, then re-attempt the edit.",
                "For config/contract/output changes, add a meta-gate or",
                "recorded-output rebaseline evidence in the same diff.",
            ]
        ),
        file=sys.stderr,
    )
    return 2


def main() -> int:
    if os.environ.get("DOSSIER_TDD_GATE") == "off":
        return 0

    try:
        event = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0

    project_dir = Path(os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd())
    root = git_root(project_dir.resolve())
    if root is None or not active_dossier(root):
        return 0

    raw_path = hook_path(event)
    if not raw_path:
        return 0

    path = rel_path(root, raw_path)
    if path is None or not is_guarded(path):
        return 0

    if any(is_evidence(changed) for changed in changed_paths(root)):
        return 0

    return block(path)


if __name__ == "__main__":
    sys.exit(main())
