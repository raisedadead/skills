#!/usr/bin/env bash
# detect-lens.sh — sniff a project root and recommend a dossier lens.
#
# Usage:
#   bash detect-lens.sh [--quiet] [<project-root>]
#
# Heuristic (first match wins):
#   *.tf | *.tofu                            -> infra        (high)
#   Cargo.toml + [[bin]]                     -> cli          (high)
#   Cargo.toml + [lib]                       -> lib          (high)
#   Cargo.toml (else)                        -> lib          (med)
#   go.mod                                   -> backend      (med)
#   package.json + web framework dep         -> web          (high)
#   package.json + backend framework dep     -> backend      (high)
#   package.json + "bin" field               -> cli          (med)
#   package.json (else)                      -> lib          (low)
#   pyproject/setup + data pipeline lib      -> data         (high)
#   dbt_project.yml                          -> data         (high)
#   pyproject/setup + python web framework   -> backend      (high)
#   pyproject/setup + ml lib                 -> ml           (high)
#   pyproject/setup + scripts/entry_points   -> cli          (med)
#   pyproject/setup (else)                   -> lib          (low)
#   *.ipynb anywhere                         -> ml           (med)
#   android/ + ios/                          -> mobile       (high)
#   (no signal)                              -> generic      (low)
#
# Output (default):
#   lens: <name>
#   confidence: <low|med|high>
#   signals: <comma-separated>
#   override: bash init-dossier.sh --lens <name>
#
# Output (--quiet): bare lens name on stdout.
#
# Exits 0 on success, 1 on bad project root, 2 on unknown flag.
# Advisory only — override at init with --lens=<name>.

set -euo pipefail

QUIET=0
ROOT="."

while [[ $# -gt 0 ]]; do
	case "$1" in
	--quiet)
		QUIET=1
		shift
		;;
	-h | --help)
		sed -n '2,33p' "$0"
		exit 0
		;;
	--*)
		printf 'error: unknown flag: %s\n' "$1" >&2
		exit 2
		;;
	*)
		ROOT="$1"
		shift
		;;
	esac
done

if [[ ! -d "$ROOT" ]]; then
	printf "error: not a directory: %s\n" "$ROOT" >&2
	exit 1
fi

lens="generic"
confidence="low"
signals=()

has_glob() {
	# Glob match anywhere under ROOT, capped at depth 3 for speed.
	find "$ROOT" -maxdepth 3 -name "$1" -print -quit 2>/dev/null | grep -q .
}

file_grep() {
	# Substring grep in a single file under ROOT.
	local rel="$1" pat="$2"
	[[ -f "$ROOT/$rel" ]] && grep -qE "$pat" "$ROOT/$rel" 2>/dev/null
}

py_grep() {
	# Substring grep across any python project descriptor.
	local pat="$1" p
	for p in pyproject.toml setup.py setup.cfg requirements.txt requirements-dev.txt; do
		if [[ -f "$ROOT/$p" ]] && grep -qE "$pat" "$ROOT/$p" 2>/dev/null; then
			return 0
		fi
	done
	return 1
}

set_lens() {
	lens="$1"
	confidence="$2"
	signals+=("$3")
}

# 1. Infra wins outright — terraform/tofu signal trumps everything else.
if has_glob '*.tf' || has_glob '*.tofu'; then
	set_lens infra high "terraform/tofu"

# 2. Rust.
elif [[ -f "$ROOT/Cargo.toml" ]]; then
	signals+=("Cargo.toml")
	if grep -q '\[\[bin\]\]' "$ROOT/Cargo.toml" 2>/dev/null; then
		set_lens cli high "[[bin]]"
	elif grep -q '\[lib\]' "$ROOT/Cargo.toml" 2>/dev/null; then
		set_lens lib high "[lib]"
	else
		lens=lib
		confidence=med
	fi

# 3. Go.
elif [[ -f "$ROOT/go.mod" ]]; then
	set_lens backend med "go.mod"

# 4. Node / JS / TS.
elif [[ -f "$ROOT/package.json" ]]; then
	signals+=("package.json")
	if file_grep package.json '"(next|nuxt|@sveltejs/kit|astro|remix|vite|react|vue|svelte|solid-js|qwik)"'; then
		set_lens web high "web framework"
	elif file_grep package.json '"(express|fastify|hono|koa|@nestjs/core|@hapi/hapi|polka)"'; then
		set_lens backend high "backend framework"
	elif file_grep package.json '"bin"[[:space:]]*:'; then
		set_lens cli med "bin field"
	else
		lens=lib
		confidence=low
	fi

# 5. Python.
elif [[ -f "$ROOT/pyproject.toml" ]] || [[ -f "$ROOT/setup.py" ]] || [[ -f "$ROOT/setup.cfg" ]] || [[ -f "$ROOT/dbt_project.yml" ]]; then
	signals+=("python project")
	if py_grep '(apache-airflow|dagster|prefect|dbt-core|mage-ai|kedro)' || [[ -f "$ROOT/dbt_project.yml" ]]; then
		set_lens data high "data pipeline lib"
	elif py_grep '(fastapi|flask|django|starlette|sanic|aiohttp|litestar)'; then
		set_lens backend high "python web framework"
	elif py_grep '(numpy|pandas|scikit-learn|sklearn|torch|tensorflow|jax|transformers|xgboost|lightgbm)'; then
		set_lens ml high "ml lib"
	elif py_grep '(\[project\.scripts\]|entry_points|console_scripts)'; then
		set_lens cli med "scripts entry"
	else
		lens=lib
		confidence=low
	fi

# 6. Pure notebook repo.
elif has_glob '*.ipynb'; then
	set_lens ml med "notebook"

# 7. React Native / Flutter / native combo.
elif [[ -d "$ROOT/android" && -d "$ROOT/ios" ]]; then
	set_lens mobile high "android+ios"
fi

if [[ "$QUIET" -eq 1 ]]; then
	printf '%s\n' "$lens"
else
	printf 'lens: %s\n' "$lens"
	printf 'confidence: %s\n' "$confidence"
	if [[ ${#signals[@]} -gt 0 ]]; then
		joined=$(
			IFS=','
			printf '%s' "${signals[*]}"
		)
		printf 'signals: %s\n' "$joined"
	else
		printf 'signals: none\n'
	fi
	printf 'override: bash init-dossier.sh --lens <web|backend|cli|lib|data|infra|mobile|ml|generic>\n'
fi
