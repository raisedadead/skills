#!/usr/bin/env bash
# init-dossier.sh - scaffold .scratchpad/dossier/ for a project.
#
# Usage:
#   bash init-dossier.sh \
#     --phase <number> \
#     --flavor <feature-wave|bug-sweep|migration|refactor-wave|release-hardening|rescue> \
#     --lens <web|backend|cli|lib|data|infra|mobile|ml|generic> \
#     [<project-root>]
#
# Idempotent. Re-running does not overwrite existing files.
#
# Flags:
#   --phase <N>            Phase number (substituted into <PHASE> placeholders).
#   --flavor <name>        Full dossier flavor preset.
#   --lens <name>          Stack lens to symlink as .scratchpad/dossier/LENS.md.
#                          'generic' or omit -> no lens loaded.

set -euo pipefail

PHASE="1"
FLAVOR="feature-wave"
LENS="generic"
ROOT="."

while [[ $# -gt 0 ]]; do
	case "$1" in
	--phase)
		PHASE="${2:?--phase requires a value}"
		shift 2
		;;
	--flavor)
		FLAVOR="${2:?--flavor requires a value}"
		shift 2
		;;
	--lens)
		LENS="${2:?--lens requires a value}"
		shift 2
		;;
	-h | --help)
		sed -n '2,17p' "$0"
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

case "$FLAVOR" in
feature-wave | bug-sweep | migration | refactor-wave | release-hardening | rescue) ;;
*)
	printf "error: unknown flavor '%s' (feature-wave|bug-sweep|migration|refactor-wave|release-hardening|rescue)\n" "$FLAVOR" >&2
	exit 2
	;;
esac

if [[ ! -d "$ROOT" ]]; then
	printf "error: project root '%s' does not exist\n" "$ROOT" >&2
	exit 1
fi

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="$SKILL_DIR/assets/templates"
LENSES_DIR="$SKILL_DIR/lenses"
DOSSIER_DIR="$ROOT/.scratchpad/dossier"
CLOSEOUT_DIR="$DOSSIER_DIR/closeout"

if [[ ! -d "$TEMPLATES_DIR" ]]; then
	printf "error: templates dir not found at %s\n" "$TEMPLATES_DIR" >&2
	exit 1
fi

mkdir -p "$CLOSEOUT_DIR"

# Ensure .gitignore excludes the internal scratchpad.
GITIGNORE="$ROOT/.gitignore"
if [[ ! -f "$GITIGNORE" ]] || ! grep -qF ".scratchpad/" "$GITIGNORE"; then
	printf '\n# dossier: internal scratchpad theater tooling\n.scratchpad/\n' >>"$GITIGNORE"
	printf "added .scratchpad/ to %s\n" "$GITIGNORE"
fi

render_template() {
	local template="$1"
	local target="$2"
	sed \
		-e "s/{PHASE}/$PHASE/g" \
		-e "s/{FLAVOR}/$FLAVOR/g" \
		"$template" >"$target"
}

created=0
skipped=0

# Drop SPEC and AUDIT from templates if absent.
for f in SPEC AUDIT; do
	TARGET="$DOSSIER_DIR/${f}.md"
	TMPL="$TEMPLATES_DIR/${f}.md.tmpl"
	if [[ ! -f "$TMPL" ]]; then
		printf "warn: template missing: %s\n" "$TMPL" >&2
		continue
	fi
	if [[ -f "$TARGET" ]]; then
		printf "skip: %s already exists\n" "$TARGET"
		skipped=$((skipped + 1))
		continue
	fi
	render_template "$TMPL" "$TARGET"
	printf "create: %s\n" "$TARGET"
	created=$((created + 1))
done

# PLAN - drop the template if absent.
PLAN_TARGET="$DOSSIER_DIR/PLAN.md"
TMPL="$TEMPLATES_DIR/PLAN.md.tmpl"
if [[ -f "$PLAN_TARGET" ]]; then
	printf "skip: %s already exists\n" "$PLAN_TARGET"
	skipped=$((skipped + 1))
elif [[ -f "$TMPL" ]]; then
	render_template "$TMPL" "$PLAN_TARGET"
	printf "create: %s\n" "$PLAN_TARGET"
	created=$((created + 1))
fi

# Internal closeout template. The phase closeout itself is written at close.
CLOSEOUT_TEMPLATE="$CLOSEOUT_DIR/TEMPLATE.md"
TMPL="$TEMPLATES_DIR/CLOSEOUT.md.tmpl"
if [[ -f "$CLOSEOUT_TEMPLATE" ]]; then
	printf "skip: %s already exists\n" "$CLOSEOUT_TEMPLATE"
	skipped=$((skipped + 1))
elif [[ -f "$TMPL" ]]; then
	render_template "$TMPL" "$CLOSEOUT_TEMPLATE"
	printf "create: %s\n" "$CLOSEOUT_TEMPLATE"
	created=$((created + 1))
fi

# LENS - symlink the chosen lens (skip on 'generic' / 'none').
LENS_TARGET="$DOSSIER_DIR/LENS.md"
case "$LENS" in
generic | none)
	printf "lens: none\n"
	;;
web) LENS_FILE="WEB-FRONTEND.md" ;;
backend) LENS_FILE="BACKEND-API.md" ;;
cli) LENS_FILE="CLI-TOOL.md" ;;
lib | library) LENS_FILE="LIBRARY-PACKAGE.md" ;;
data) LENS_FILE="DATA-PIPELINE.md" ;;
infra | iac) LENS_FILE="INFRA-IAC.md" ;;
mobile) LENS_FILE="MOBILE.md" ;;
ml) LENS_FILE="ML-PIPELINE.md" ;;
*)
	printf "error: unknown lens '%s' (web|backend|cli|lib|data|infra|mobile|ml|generic)\n" "$LENS" >&2
	exit 2
	;;
esac

if [[ -n "${LENS_FILE:-}" ]]; then
	LENS_SRC="$LENSES_DIR/$LENS_FILE"
	if [[ ! -f "$LENS_SRC" ]]; then
		printf "warn: lens file missing: %s\n" "$LENS_SRC" >&2
	elif [[ -L "$LENS_TARGET" || -f "$LENS_TARGET" ]]; then
		printf "skip: %s already exists\n" "$LENS_TARGET"
		skipped=$((skipped + 1))
	else
		ln -s "$LENS_SRC" "$LENS_TARGET"
		printf "link: %s -> %s\n" "$LENS_TARGET" "$LENS_SRC"
	fi
fi

printf '\n'
printf "dossier ready (phase %s, flavor %s, lens %s): created=%s skipped=%s\n" \
	"$PHASE" "$FLAVOR" "$LENS" "$created" "$skipped"
printf '\n'
printf "next:\n"
printf "  1. edit  %s/PLAN.md   (lock decisions, list phases)\n" "$DOSSIER_DIR"
printf "  2. fill  %s/SPEC.md   (§G/§C/§I/§V/§T/§B)\n" "$DOSSIER_DIR"
printf "  3. seed  %s/AUDIT.md  (B1, B2, ... known findings)\n" "$DOSSIER_DIR"
closeout_step=4
if [[ -n "${LENS_FILE:-}" ]]; then
	printf "  4. read  %s/LENS.md   (stack-specific gates + footguns)\n" "$DOSSIER_DIR"
	closeout_step=5
fi
printf "  %s. on close, write %s/phase-%s-{slug}.md\n" "$closeout_step" "$CLOSEOUT_DIR" "$PHASE"
