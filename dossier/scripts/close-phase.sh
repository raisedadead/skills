#!/usr/bin/env bash
# close-phase.sh — template a phase closeout note from disk state.
#
# Usage:
#   bash close-phase.sh [--slug <slug>] [--force] [--since <ref>] \
#                       [--max-commits <N>] [<project-root>]
#
# Reads .scratchpad/dossier/SPEC.md (phase, flavor, §G, §B) plus
# `git log` to render an internal closeout note at
# `.scratchpad/dossier/closeout/phase-<N>-<slug>.md`.
#
# The script fills three machine-derivable sections:
#   - Commits Landed   — from `git log --oneline`
#   - Findings Closed  — §B rows with a non-pending fix column
#   - Deferred         — §B rows still pending / placeholder / empty
#
# All other sections (Surface Delta, Behavior Delta, Verification,
# Rollout/Rollback, External Artifacts) are left as template
# placeholders for the operator to fill — those are human-judgment
# slots that a script must not invent.
#
# Refuses to overwrite an existing closeout note unless `--force`.
# Exits 1 on missing SPEC.md, 2 on unknown flag.

set -euo pipefail

SLUG=""
FORCE=0
SINCE=""
MAX_COMMITS=20
REVIEW=0
REVIEW_OUT=""
ROOT="."

while [[ $# -gt 0 ]]; do
	case "$1" in
	--slug)
		SLUG="${2:?--slug requires a value}"
		shift 2
		;;
	--force)
		FORCE=1
		shift
		;;
	--since)
		SINCE="${2:?--since requires a value}"
		shift 2
		;;
	--max-commits)
		MAX_COMMITS="${2:?--max-commits requires a value}"
		shift 2
		;;
	--review)
		REVIEW=1
		shift
		;;
	--review-out)
		REVIEW_OUT="${2:?--review-out requires a path}"
		REVIEW=1
		shift 2
		;;
	-h | --help)
		sed -n '2,22p' "$0"
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

[[ -d "$ROOT" ]] || {
	printf "error: not a directory: %s\n" "$ROOT" >&2
	exit 1
}

DOSSIER="$ROOT/.scratchpad/dossier"
SPEC="$DOSSIER/SPEC.md"
CLOSEOUT_DIR="$DOSSIER/closeout"

if [[ ! -f "$SPEC" ]]; then
	printf "error: SPEC.md missing (%s)\n" "$SPEC" >&2
	exit 1
fi

# Resolve template path. SKILL_DIR overridable for tests.
if [[ -z "${SKILL_DIR:-}" ]]; then
	SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
fi
TEMPLATE="$SKILL_DIR/assets/templates/CLOSEOUT.md.tmpl"
[[ -f "$TEMPLATE" ]] || {
	printf "error: template missing: %s\n" "$TEMPLATE" >&2
	exit 1
}

# Phase number + flavor + goal from SPEC.md.
phase=$(sed -n 's/^# Phase \([0-9][0-9]*\) Spec.*/\1/p' "$SPEC" | head -1)
phase="${phase:-?}"
# shellcheck disable=SC2016
flavor=$(sed -n 's/^Flavor: *`\([^`]*\)`.*/\1/p' "$SPEC" | head -1)
flavor="${flavor:-unknown}"
goal=$(awk '
  /^## §G/ { cap=1; next }
  cap && /^## / { cap=0 }
  cap && NF { print; exit }
' "$SPEC")

# Derive slug from goal if not explicit.
if [[ -z "$SLUG" ]]; then
	if [[ -n "$goal" ]]; then
		SLUG=$(printf '%s' "$goal" |
			tr '[:upper:]' '[:lower:]' |
			tr -cs 'a-z0-9' '-' |
			sed 's/^-//;s/-$//' |
			awk -F- '{
        out=""; n=0
        for (i=1; i<=NF; i++) if ($i != "") {
          out = (out=="" ? $i : out "-" $i); n++
          if (n >= 6) break
        }
        print out
      }')
	fi
	SLUG="${SLUG:-phase}"
fi

mkdir -p "$CLOSEOUT_DIR"
TARGET="$CLOSEOUT_DIR/phase-${phase}-${SLUG}.md"

if [[ -e "$TARGET" && "$FORCE" -ne 1 ]]; then
	printf "error: %s exists (re-run with --force to overwrite)\n" "$TARGET" >&2
	exit 1
fi

# Section bodies — write to tmpfiles so awk can splice them in.
cf=$(mktemp "${TMPDIR:-/tmp}/dossier-close-c.XXXXXX")
ff=$(mktemp "${TMPDIR:-/tmp}/dossier-close-f.XXXXXX")
df=$(mktemp "${TMPDIR:-/tmp}/dossier-close-d.XXXXXX")
trap 'rm -f "$cf" "$ff" "$df"' EXIT

# Commits Landed.
log=""
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
	if [[ -n "$SINCE" ]]; then
		log=$(git -C "$ROOT" log --oneline "$SINCE..HEAD" 2>/dev/null || true)
	else
		log=$(git -C "$ROOT" log --oneline -"$MAX_COMMITS" 2>/dev/null || true)
	fi
fi
if [[ -z "$log" ]]; then
	printf -- '- (no commits found — populate manually)\n' >"$cf"
else
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		hash=$(awk '{print $1}' <<<"$line")
		subject=$(awk '{$1=""; sub(/^ /,""); print}' <<<"$line")
		# shellcheck disable=SC2016 # backticks are literal markdown code spans
		printf -- '- `%s` — %s\n' "$hash" "$subject" >>"$cf"
	done <<<"$log"
fi

# Findings Closed + Deferred from §B.
awk '
  /^## §B/ { cap=1; next }
  cap && /^## / { cap=0 }
  cap && /^\| *B[0-9]+ *\|/ {
    n = split($0, a, "|")
    if (n >= 5) {
      id = a[2]; gsub(/^ +| +$/, "", id)
      cause = a[4]; gsub(/^ +| +$/, "", cause)
      fix = a[5]; gsub(/^ +| +$/, "", fix)
      lower=tolower(fix)
      if (fix == "" || fix == "-" || lower == "pending" || fix ~ /^\{.*\}$/) {
        print "deferred\t" id "\t" cause "\t" (fix == "" ? "(empty)" : fix)
      } else {
        print "closed\t" id "\t" cause "\t" fix
      }
    }
  }
' "$SPEC" | while IFS=$'\t' read -r kind id cause fix; do
	case "$kind" in
	closed) printf -- '- %s — %s (fix: %s)\n' "$id" "$cause" "$fix" >>"$ff" ;;
	deferred) printf -- '- %s — %s (status: %s)\n' "$id" "$cause" "$fix" >>"$df" ;;
	esac
done

# Fallback messages if any section is empty.
[[ -s "$ff" ]] || printf -- '- (no closed findings recorded)\n' >"$ff"
[[ -s "$df" ]] || printf -- '- (no deferred findings)\n' >"$df"

# Splice into template. The template has placeholder bodies under three
# section headers; awk skips those bodies and emits the rendered ones.
awk \
	-v phase="$phase" \
	-v flavor="$flavor" \
	-v slug="$SLUG" \
	-v cf="$cf" -v ff="$ff" -v df="$df" '
function dump(f,   line) {
  print ""
  while ((getline line < f) > 0) print line
  print ""
  close(f)
}
BEGIN { skip = 0 }
{
  gsub(/\{PHASE\}/, phase)
  gsub(/\{FLAVOR\}/, flavor)
  gsub(/\{slug\}/, slug)
}
/^## / {
  if (skip) skip = 0
  if ($0 == "## Commits Landed") { print; dump(cf); skip=1; next }
  if ($0 == "## Findings Closed") { print; dump(ff); skip=1; next }
  if ($0 == "## Deferred") { print; dump(df); skip=1; next }
  print; next
}
skip { next }
{ print }
' "$TEMPLATE" >"$TARGET"

printf 'create: %s\n' "$TARGET"

if [[ "$REVIEW" -eq 1 ]]; then
	# Emit a runtime-neutral review prompt the operator can hand to a
	# fresh evaluator (Claude Code Agent / OpenCode subagent / Codex
	# child task). The prompt is markdown; the host runtime decides
	# how to dispatch.
	build_review_prompt() {
		cat <<EOF
## Review prompt — phase ${phase} closeout

Hand this block to a **fresh, read-only** evaluator (different context
window from the one that wrote the closeout). The reviewer must not
edit, commit, or run mutating commands. Its job is to grade the
phase, not to fix it.

### Context to read

- \`${TARGET#"$ROOT/"}\` — closeout note just rendered
- \`.scratchpad/dossier/SPEC.md\` — canonical state, including \`§B\` ledger
- \`.scratchpad/dossier/AUDIT.md\` if present — per-finding Detail sections
- \`.scratchpad/dossier/LENS.md\` if present — stack gates + footguns
- Recent commits via \`git log --oneline -${MAX_COMMITS}\`

### Checks to run (all read-only)

1. **drift-check** — run \`bash <skill-dir>/scripts/drift-check.sh --strict ${ROOT}\`.
   Report exit code and any phase-marker / in-flight §T / open §B
   findings.
2. **Covenant invariants** — for each commit landed this phase
   (see "Commits Landed" in the closeout):
   - Subject matches \`type(scope): subject\` and is ≤ 50 chars.
   - Has a sibling test, meta-gate, or recorded-output rebaseline in
     the same commit (\`git show --stat\`).
   - No phase / stage / audit-id markers in the diff.
3. **§B reconciliation** — every \`B<n>\` row in SPEC §B with a
   non-pending fix actually has a matching commit; every \`B<n>\` row
   still pending appears in the closeout's "Deferred" section with a
   one-line rationale.
4. **Output contract** — the closeout's machine-derivable sections
   (Commits Landed, Findings Closed, Deferred) match what disk says.
   Human-judgment sections (Surface / Behavior Delta, Verification,
   Rollout / Rollback) are filled in (no \`{placeholder}\` remaining).
5. **User-owned ops** — closeout lists pending push / PR / publish /
   deploy / changeset export items if applicable; never claims those
   happened.

### Report shape

Reply with one block in this exact shape:

\`\`\`
phase ${phase} review — <PASS | FINDINGS>

drift-check: <pass | N findings>
covenant: <pass | N violations>
§B reconciliation: <pass | N mismatches>
output contract: <pass | N placeholders left>
user-owned ops: <listed | missing>

findings:
- <one-line per gap>

verdict: <ship | block | block-with-followups>
\`\`\`
EOF
	}

	prompt="$(build_review_prompt)"
	if [[ -n "$REVIEW_OUT" ]]; then
		mkdir -p "$(dirname "$REVIEW_OUT")"
		printf '%s\n' "$prompt" >"$REVIEW_OUT"
		printf 'review: %s\n' "$REVIEW_OUT"
	else
		printf '\n%s\n' "$prompt"
	fi
fi
