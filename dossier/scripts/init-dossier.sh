#!/usr/bin/env bash
# init-dossier.sh — scaffold .dossier/ for a project.
#
# Usage:
#   bash init-dossier.sh \
#     --phase <number> \
#     --lens <web|backend|cli|lib|data|infra|mobile|ml|generic> \
#     [--with-superpowers] \
#     [<project-root>]
#
# Idempotent. Re-running does not overwrite existing files.
#
# Flags:
#   --phase <N>            Phase number (substituted into templates).
#   --lens <name>          Stack lens to symlink as .dossier/LENS.md.
#                          'generic' or omit → no lens loaded.
#   --with-superpowers     Symlink .dossier/PLAN.md to the latest file
#                          under docs/superpowers/plans/ (if present).
#                          Requires obra/superpowers-style plan dir.

set -euo pipefail

PHASE="1"
LENS="generic"
WITH_SP="false"
ROOT="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)
      PHASE="${2:?--phase requires a value}"
      shift 2
      ;;
    --lens)
      LENS="${2:?--lens requires a value}"
      shift 2
      ;;
    --with-superpowers)
      WITH_SP="true"
      shift
      ;;
    -h|--help)
      sed -n '2,18p' "$0"
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
  printf "error: project root '%s' does not exist\n" "$ROOT" >&2
  exit 1
fi

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="$SKILL_DIR/assets/templates"
LENSES_DIR="$SKILL_DIR/lenses"

if [[ ! -d "$TEMPLATES_DIR" ]]; then
  printf "error: templates dir not found at %s\n" "$TEMPLATES_DIR" >&2
  exit 1
fi

mkdir -p "$ROOT/.dossier"

# Ensure .gitignore excludes .dossier/
GITIGNORE="$ROOT/.gitignore"
if [[ ! -f "$GITIGNORE" ]] || ! grep -qF ".dossier/" "$GITIGNORE"; then
  printf '\n# dossier: working notes (audit, plan, spec, lens)\n.dossier/\n' >> "$GITIGNORE"
  printf "added .dossier/ to %s\n" "$GITIGNORE"
fi

# Drop AUDIT and SPEC from templates if absent
created=0
skipped=0
for f in AUDIT SPEC; do
  TARGET="$ROOT/.dossier/${f}.md"
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
  sed "s/<N>/$PHASE/g" "$TMPL" > "$TARGET"
  printf "create: %s\n" "$TARGET"
  created=$((created + 1))
done

# PLAN — either symlink superpowers' plan, or drop the template.
PLAN_TARGET="$ROOT/.dossier/PLAN.md"
if [[ "$WITH_SP" == "true" ]]; then
  SP_DIR="$ROOT/docs/superpowers/plans"
  if [[ -d "$SP_DIR" ]]; then
    # Superpowers writes plans as YYYY-MM-DD-<feature>.md, so reverse-sort
    # by filename gives the most recent. Avoids parsing `ls` output (SC2012).
    LATEST="$(find "$SP_DIR" -maxdepth 1 -type f -name '*.md' 2>/dev/null \
      | sort -r \
      | head -n 1 || true)"
    if [[ -n "$LATEST" && -f "$LATEST" ]]; then
      if [[ -L "$PLAN_TARGET" || -f "$PLAN_TARGET" ]]; then
        printf "skip: %s already exists (superpowers plan link not replaced)\n" "$PLAN_TARGET"
      else
        ln -s "$LATEST" "$PLAN_TARGET"
        printf "link: %s -> %s\n" "$PLAN_TARGET" "$LATEST"
      fi
    else
      printf "warn: --with-superpowers given but no plan in %s; falling back to template\n" "$SP_DIR" >&2
      WITH_SP="false"
    fi
  else
    printf "warn: --with-superpowers given but %s missing; falling back to template\n" "$SP_DIR" >&2
    WITH_SP="false"
  fi
fi

if [[ "$WITH_SP" != "true" ]]; then
  TMPL="$TEMPLATES_DIR/PLAN.md.tmpl"
  if [[ -f "$PLAN_TARGET" ]]; then
    printf "skip: %s already exists\n" "$PLAN_TARGET"
    skipped=$((skipped + 1))
  elif [[ -f "$TMPL" ]]; then
    sed "s/<N>/$PHASE/g" "$TMPL" > "$PLAN_TARGET"
    printf "create: %s\n" "$PLAN_TARGET"
    created=$((created + 1))
  fi
fi

# LENS — symlink the chosen lens (skip on 'generic' / 'none').
LENS_TARGET="$ROOT/.dossier/LENS.md"
case "$LENS" in
  generic|none)
    printf "lens: none\n"
    ;;
  web)         LENS_FILE="WEB-FRONTEND.md" ;;
  backend)     LENS_FILE="BACKEND-API.md" ;;
  cli)         LENS_FILE="CLI-TOOL.md" ;;
  lib|library) LENS_FILE="LIBRARY-PACKAGE.md" ;;
  data)        LENS_FILE="DATA-PIPELINE.md" ;;
  infra|iac)   LENS_FILE="INFRA-IAC.md" ;;
  mobile)      LENS_FILE="MOBILE.md" ;;
  ml)          LENS_FILE="ML-PIPELINE.md" ;;
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
  else
    ln -s "$LENS_SRC" "$LENS_TARGET"
    printf "link: %s -> %s\n" "$LENS_TARGET" "$LENS_SRC"
  fi
fi

printf '\n'
printf "dossier ready (phase %s, lens %s, superpowers %s): created=%s skipped=%s\n" \
  "$PHASE" "$LENS" "$WITH_SP" "$created" "$skipped"
printf '\n'
printf "next:\n"
printf "  1. edit  %s/.dossier/PLAN.md   (lock decisions, list phases)\n" "$ROOT"
printf "  2. seed  %s/.dossier/AUDIT.md  (B1, B2, ... known findings)\n" "$ROOT"
printf "  3. read  %s/.dossier/SPEC.md   (covenant + invariants)\n" "$ROOT"
if [[ -n "${LENS_FILE:-}" ]]; then
  printf "  4. read  %s/.dossier/LENS.md   (stack-specific gates + footguns)\n" "$ROOT"
fi
printf "  5. on close, write .changeset/phase-%s-<slug>.md (durable)\n" "$PHASE"
