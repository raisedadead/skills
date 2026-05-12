#!/usr/bin/env bash
# dossier-promote.sh — materialize PLAN.md / AUDIT.md in a tiered dossier.
#
# Usage:
#   bash dossier-promote.sh [--plan] [--audit] [<project-root>]
#
# init-dossier.sh defaults to a tiered shape (SPEC.md only for small
# work). When scope grows — more phases, more findings — promote the
# dossier to materialize the missing ledger files.
#
#   --plan   Render PLAN.md if absent.
#   --audit  Render AUDIT.md if absent.
#
# Idempotent: existing files are never overwritten. At least one of
# `--plan` / `--audit` must be supplied.
#
# Reads phase and flavor placeholders from SPEC.md (`# Phase N Spec` +
# `Flavor: ...`) so the new ledger lines up with the current dossier.
#
# Exits 1 on missing SPEC.md or absent flags, 2 on unknown flag.

set -euo pipefail

WANT_PLAN=0
WANT_AUDIT=0
ROOT="."

while [[ $# -gt 0 ]]; do
	case "$1" in
	--plan)
		WANT_PLAN=1
		shift
		;;
	--audit)
		WANT_AUDIT=1
		shift
		;;
	-h | --help)
		sed -n '2,21p' "$0"
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

if [[ "$WANT_PLAN" -eq 0 && "$WANT_AUDIT" -eq 0 ]]; then
	printf 'error: supply at least one of --plan / --audit\n' >&2
	exit 1
fi

[[ -d "$ROOT" ]] || {
	printf "error: not a directory: %s\n" "$ROOT" >&2
	exit 1
}

DOSSIER="$ROOT/.scratchpad/dossier"
SPEC="$DOSSIER/SPEC.md"

if [[ ! -f "$SPEC" ]]; then
	printf "error: no dossier at %s (no SPEC.md)\n" "$DOSSIER" >&2
	exit 1
fi

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="$SKILL_DIR/assets/templates"

[[ -d "$TEMPLATES_DIR" ]] || {
	printf "error: templates dir not found: %s\n" "$TEMPLATES_DIR" >&2
	exit 1
}

# Read phase + flavor from SPEC so promoted files share the headers.
phase=$(sed -n 's/^# Phase \([0-9][0-9]*\) Spec.*/\1/p' "$SPEC" | head -1)
phase="${phase:-1}"
# shellcheck disable=SC2016
flavor=$(sed -n 's/^Flavor: *`\([^`]*\)`.*/\1/p' "$SPEC" | head -1)
flavor="${flavor:-feature-wave}"

render_template() {
	local template="$1"
	local target="$2"
	sed \
		-e "s/{PHASE}/$phase/g" \
		-e "s/{FLAVOR}/$flavor/g" \
		"$template" >"$target"
}

promote() {
	# $1 = ledger name (PLAN | AUDIT)
	local name="$1"
	local target="$DOSSIER/${name}.md"
	local tmpl="$TEMPLATES_DIR/${name}.md.tmpl"
	if [[ -f "$target" ]]; then
		printf "skip: %s already exists\n" "$target"
		return
	fi
	if [[ ! -f "$tmpl" ]]; then
		printf "error: template missing: %s\n" "$tmpl" >&2
		return 1
	fi
	render_template "$tmpl" "$target"
	printf "create: %s\n" "$target"
}

if [[ "$WANT_PLAN" -eq 1 ]]; then promote PLAN; fi
if [[ "$WANT_AUDIT" -eq 1 ]]; then promote AUDIT; fi
