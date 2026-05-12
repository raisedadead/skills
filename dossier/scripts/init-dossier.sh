#!/usr/bin/env bash
# init-dossier.sh - scaffold .scratchpad/dossier/ for a project.
#
# Usage:
#   bash init-dossier.sh \
#     --phase <N> \
#     --flavor <feature-wave|bug-sweep|migration|refactor-wave|release-hardening|rescue> \
#     --lens <web|backend|cli|lib|data|infra|mobile|ml|generic> \
#     [--phases <N>] [--tasks <N>] [--findings <N>] [--legacy] \
#     [<project-root>]
#
# Tiered open. The default footprint is small:
#
#   - SPEC.md + closeout/ — always created.
#   - PLAN.md            — created when --phases > 1, --tasks > 8, the
#                          flavor is migration / release-hardening, or
#                          --legacy is set.
#   - AUDIT.md           — created when --findings > 5, the flavor is
#                          bug-sweep / migration / release-hardening, or
#                          --legacy is set.
#   - closeout/TEMPLATE  — rendered for migration / release-hardening
#                          (or --legacy).
#   - LENS.md            — symlinked when --lens != generic.
#
# Idempotent. Re-running does not overwrite existing files. Grow a
# tiered dossier later with `dossier-promote.sh --plan|--audit`.

set -euo pipefail

PHASE="1"
FLAVOR="feature-wave"
LENS="generic"
PHASES=1
TASKS=0
FINDINGS=0
LEGACY=0
LESSONS_HOME=""
LESSONS_RECENT=5
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
	--phases)
		PHASES="${2:?--phases requires a value}"
		shift 2
		;;
	--tasks)
		TASKS="${2:?--tasks requires a value}"
		shift 2
		;;
	--findings)
		FINDINGS="${2:?--findings requires a value}"
		shift 2
		;;
	--legacy)
		LEGACY=1
		shift
		;;
	--lessons-home)
		LESSONS_HOME="${2:?--lessons-home requires a value}"
		shift 2
		;;
	--lessons-recent)
		LESSONS_RECENT="${2:?--lessons-recent requires a value}"
		shift 2
		;;
	-h | --help)
		sed -n '2,26p' "$0"
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

# Decide which ledgers to materialize based on flavor + escalators.
want_plan=0
want_audit=0
want_closeout=0

case "$FLAVOR" in
migration | release-hardening)
	want_plan=1
	want_audit=1
	want_closeout=1
	;;
bug-sweep)
	want_audit=1
	;;
esac

if [[ "$PHASES" -gt 1 || "$TASKS" -gt 8 ]]; then
	want_plan=1
fi
if [[ "$FINDINGS" -gt 5 ]]; then
	want_audit=1
fi
if [[ "$LEGACY" -eq 1 ]]; then
	want_plan=1
	want_audit=1
	want_closeout=1
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

render_if_wanted() {
	# $1 = name (no extension), $2 = wanted-flag (0/1)
	local name="$1" wanted="$2"
	local target="$DOSSIER_DIR/${name}.md"
	local tmpl="$TEMPLATES_DIR/${name}.md.tmpl"
	if [[ "$wanted" -eq 0 ]]; then
		printf "skip: %s (not requested by flavor / escalators)\n" "$target"
		skipped=$((skipped + 1))
		return
	fi
	if [[ ! -f "$tmpl" ]]; then
		printf "warn: template missing: %s\n" "$tmpl" >&2
		return
	fi
	if [[ -f "$target" ]]; then
		printf "skip: %s already exists\n" "$target"
		skipped=$((skipped + 1))
		return
	fi
	render_template "$tmpl" "$target"
	printf "create: %s\n" "$target"
	created=$((created + 1))
}

# SPEC.md is always created.
render_if_wanted SPEC 1
render_if_wanted PLAN "$want_plan"
render_if_wanted AUDIT "$want_audit"

# Internal closeout template.
CLOSEOUT_TEMPLATE="$CLOSEOUT_DIR/TEMPLATE.md"
TMPL="$TEMPLATES_DIR/CLOSEOUT.md.tmpl"
if [[ "$want_closeout" -eq 0 ]]; then
	printf "skip: %s (flavor '%s' renders closeout on demand)\n" "$CLOSEOUT_TEMPLATE" "$FLAVOR"
	skipped=$((skipped + 1))
elif [[ -f "$CLOSEOUT_TEMPLATE" ]]; then
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

# Bring forward recent lessons (per-project default, optional kernel-wide home).
SPEC_TARGET="$DOSSIER_DIR/SPEC.md"
lessons_file=""
if [[ -n "$LESSONS_HOME" && -f "$LESSONS_HOME" ]]; then
	lessons_file="$LESSONS_HOME"
elif [[ -f "$DOSSIER_DIR/.lessons.md" ]]; then
	lessons_file="$DOSSIER_DIR/.lessons.md"
fi

if [[ -n "$lessons_file" && -f "$SPEC_TARGET" ]]; then
	# Last N lesson rows, oldest-first to newest-first stays as on disk.
	lesson_rows=$(grep -E '^\| L[0-9]+ \|' "$lessons_file" | tail -n "$LESSONS_RECENT" || true)
	if [[ -n "$lesson_rows" ]] && ! grep -q '^## Lessons brought forward' "$SPEC_TARGET"; then
		# shellcheck disable=SC2016 # backticks are literal markdown code spans
		{
			printf '\n## Lessons brought forward\n\n'
			printf 'Recent observations from `%s`. Promote any to a `C<n>` row in §C\n' "$lessons_file"
			printf 'if the lesson should constrain this phase. Retire stale entries\n'
			printf 'with `bash <skill-dir>/scripts/lesson.sh --retire <Lid>`.\n\n'
			while IFS= read -r row; do
				# Extract id and text from `| L<n> | date | text |`
				id=$(awk -F'|' '{gsub(/^ +| +$/, "", $2); print $2}' <<<"$row")
				text=$(awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}' <<<"$row")
				printf -- '- [ ] %s — %s\n' "$id" "$text"
			done <<<"$lesson_rows"
		} >>"$SPEC_TARGET"
		n=$(printf '%s\n' "$lesson_rows" | wc -l | tr -d ' ')
		printf 'lessons: surfaced %s entries into SPEC.md\n' "$n"
	fi
fi

printf '\n'
printf "dossier ready (phase %s, flavor %s, lens %s): created=%s skipped=%s\n" \
	"$PHASE" "$FLAVOR" "$LENS" "$created" "$skipped"

# Footer guidance — adapt to what was actually rendered.
printf '\n'
printf "next:\n"
step=1
printf "  %s. fill  %s/SPEC.md   (§G/§C/§I/§V/§T/§B)\n" "$step" "$DOSSIER_DIR"
step=$((step + 1))
if [[ "$want_plan" -eq 1 ]]; then
	printf "  %s. edit  %s/PLAN.md   (lock decisions, list phases)\n" "$step" "$DOSSIER_DIR"
	step=$((step + 1))
else
	printf "  -. (PLAN.md not created; if scope grows: bash dossier-promote.sh --plan)\n"
fi
if [[ "$want_audit" -eq 1 ]]; then
	printf "  %s. seed  %s/AUDIT.md  (B1, B2, ... known findings)\n" "$step" "$DOSSIER_DIR"
	step=$((step + 1))
else
	printf "  -. (AUDIT.md not created; if findings exceed §B capacity: bash dossier-promote.sh --audit)\n"
fi
if [[ -n "${LENS_FILE:-}" ]]; then
	printf "  %s. read  %s/LENS.md   (stack-specific gates + footguns)\n" "$step" "$DOSSIER_DIR"
	step=$((step + 1))
fi
printf "  %s. on close, run bash close-phase.sh to render closeout note\n" "$step"
