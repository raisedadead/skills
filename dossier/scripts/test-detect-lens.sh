#!/usr/bin/env bash
# Coverage-lock test for detect-lens.sh.
# Asserts heuristic mapping repo signals -> lens recommendation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECT="$SCRIPT_DIR/detect-lens.sh"

fail() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

mkfix() {
	mktemp -d "${TMPDIR:-/tmp}/dossier-detect-lens.XXXXXX"
}

q() {
	bash "$DETECT" --quiet "$1" 2>/dev/null
}

# 1. Empty dir -> generic.
tmp="$(mkfix)"
[[ "$(q "$tmp")" == "generic" ]] || fail "empty dir should be generic"
rm -rf "$tmp"

# 2. *.tf -> infra (strongest).
tmp="$(mkfix)"
touch "$tmp/main.tf"
[[ "$(q "$tmp")" == "infra" ]] || fail "*.tf should be infra"
rm -rf "$tmp"

# 2b. *.tofu -> infra.
tmp="$(mkfix)"
touch "$tmp/main.tofu"
[[ "$(q "$tmp")" == "infra" ]] || fail "*.tofu should be infra"
rm -rf "$tmp"

# 3. Cargo.toml + [[bin]] -> cli.
tmp="$(mkfix)"
printf '[package]\nname = "x"\n[[bin]]\nname = "x"\n' >"$tmp/Cargo.toml"
[[ "$(q "$tmp")" == "cli" ]] || fail "Cargo [[bin]] should be cli"
rm -rf "$tmp"

# 4. Cargo.toml + [lib] -> lib.
tmp="$(mkfix)"
printf '[package]\nname = "x"\n[lib]\nname = "x"\n' >"$tmp/Cargo.toml"
[[ "$(q "$tmp")" == "lib" ]] || fail "Cargo [lib] should be lib"
rm -rf "$tmp"

# 5. go.mod -> backend (default; user overrides for cli).
tmp="$(mkfix)"
printf 'module x\ngo 1.22\n' >"$tmp/go.mod"
[[ "$(q "$tmp")" == "backend" ]] || fail "go.mod should be backend"
rm -rf "$tmp"

# 6. package.json + next dep -> web.
tmp="$(mkfix)"
printf '{"dependencies":{"next":"14"}}\n' >"$tmp/package.json"
[[ "$(q "$tmp")" == "web" ]] || fail "next dep should be web"
rm -rf "$tmp"

# 6b. package.json + react dep -> web.
tmp="$(mkfix)"
printf '{"dependencies":{"react":"18"}}\n' >"$tmp/package.json"
[[ "$(q "$tmp")" == "web" ]] || fail "react dep should be web"
rm -rf "$tmp"

# 7. package.json + express dep -> backend.
tmp="$(mkfix)"
printf '{"dependencies":{"express":"4"}}\n' >"$tmp/package.json"
[[ "$(q "$tmp")" == "backend" ]] || fail "express dep should be backend"
rm -rf "$tmp"

# 7b. package.json + fastify dep -> backend.
tmp="$(mkfix)"
printf '{"dependencies":{"fastify":"4"}}\n' >"$tmp/package.json"
[[ "$(q "$tmp")" == "backend" ]] || fail "fastify dep should be backend"
rm -rf "$tmp"

# 8. package.json + bin field -> cli.
tmp="$(mkfix)"
printf '{"bin":{"x":"./x.js"}}\n' >"$tmp/package.json"
[[ "$(q "$tmp")" == "cli" ]] || fail "bin field should be cli"
rm -rf "$tmp"

# 9. package.json bare -> lib.
tmp="$(mkfix)"
printf '{"name":"x","main":"index.js"}\n' >"$tmp/package.json"
[[ "$(q "$tmp")" == "lib" ]] || fail "bare package.json should be lib"
rm -rf "$tmp"

# 10. pyproject + fastapi -> backend.
tmp="$(mkfix)"
printf '[project]\nname="x"\ndependencies=["fastapi"]\n' >"$tmp/pyproject.toml"
[[ "$(q "$tmp")" == "backend" ]] || fail "pyproject fastapi should be backend"
rm -rf "$tmp"

# 11. pyproject + sklearn -> ml.
tmp="$(mkfix)"
printf '[project]\nname="x"\ndependencies=["scikit-learn"]\n' >"$tmp/pyproject.toml"
[[ "$(q "$tmp")" == "ml" ]] || fail "pyproject sklearn should be ml"
rm -rf "$tmp"

# 12. pyproject + airflow -> data.
tmp="$(mkfix)"
printf '[project]\nname="x"\ndependencies=["apache-airflow"]\n' >"$tmp/pyproject.toml"
[[ "$(q "$tmp")" == "data" ]] || fail "pyproject airflow should be data"
rm -rf "$tmp"

# 12b. dbt_project.yml -> data.
tmp="$(mkfix)"
printf 'name: x\n' >"$tmp/dbt_project.yml"
[[ "$(q "$tmp")" == "data" ]] || fail "dbt_project.yml should be data"
rm -rf "$tmp"

# 13. pyproject + scripts entry -> cli.
tmp="$(mkfix)"
printf '[project]\nname="x"\n[project.scripts]\nx="x:main"\n' >"$tmp/pyproject.toml"
[[ "$(q "$tmp")" == "cli" ]] || fail "pyproject scripts entry should be cli"
rm -rf "$tmp"

# 14. *.ipynb only -> ml.
tmp="$(mkfix)"
touch "$tmp/notebook.ipynb"
[[ "$(q "$tmp")" == "ml" ]] || fail "*.ipynb should be ml"
rm -rf "$tmp"

# 15. android/ + ios/ -> mobile.
tmp="$(mkfix)"
mkdir "$tmp/android" "$tmp/ios"
[[ "$(q "$tmp")" == "mobile" ]] || fail "android+ios should be mobile"
rm -rf "$tmp"

# 16. Default (no --quiet) prints lens + confidence + signals + override hint.
tmp="$(mkfix)"
touch "$tmp/main.tf"
out="$(bash "$DETECT" "$tmp" 2>/dev/null)"
grep -q '^lens: infra$' <<<"$out" || fail "default output missing 'lens: infra'"
grep -q '^confidence: ' <<<"$out" || fail "default output missing confidence line"
grep -q '^signals: ' <<<"$out" || fail "default output missing signals line"
grep -q '^override: ' <<<"$out" || fail "default output missing override hint"
rm -rf "$tmp"

# 17. Confidence levels — high for terraform, low for empty.
# (capture-first, not pipe-into-grep-q: grep -q exits on first match and
# SIGPIPEs the producer; pipefail then propagates 141.)
tmp="$(mkfix)"
touch "$tmp/main.tf"
out="$(bash "$DETECT" "$tmp" 2>/dev/null)"
grep -q '^confidence: high$' <<<"$out" ||
	fail "terraform should be high confidence"
rm -rf "$tmp"

tmp="$(mkfix)"
out="$(bash "$DETECT" "$tmp" 2>/dev/null)"
grep -q '^confidence: low$' <<<"$out" ||
	fail "empty dir should be low confidence"
rm -rf "$tmp"

# 18. Bad project root -> non-zero exit.
if bash "$DETECT" /no/such/path/xyz 2>/dev/null; then
	fail "missing project root should error"
fi

# 19. Unknown flag -> non-zero exit.
if bash "$DETECT" --bogus 2>/dev/null; then
	fail "unknown flag should error"
fi

# 20. --help prints usage and exits 0.
out="$(bash "$DETECT" --help 2>/dev/null)"
grep -q -i "usage" <<<"$out" || fail "--help should print usage"

printf 'ok\n'
