#!/usr/bin/env bash
# PreToolUse(Bash, gh pr create) — enforce the protected-branch base; remind of PR requirements.
# Provider-neutral: blocks via exit 2 + stderr; otherwise surfaces a reminder.
set -euo pipefail
PB="${PROTECTED_BRANCH:-main}"; PB="${PB#refs/heads/}"
# Allowed PR base branches (comma-separated), overridable via WORKFLOW_PR_BASES.
# The default lives HERE (not in .claude/settings.json) so Claude Code and Codex
# behave identically — both providers run this same script. main-only: PRs target
# the protected branch (`main`).
ALLOWED="${WORKFLOW_PR_BASES:-$PB}"

CMD=$(cat | jq -r '.tool_input.command // ""')
# Normalize away gh GLOBAL options between `gh` and `pr` (e.g. `gh -R owner/repo pr
# create`, `gh --repo=owner/repo pr create`, glued short form `gh -Rowner/repo pr
# create`) so they can't bypass detection. `-R` allows a glued/spaced/`=` value;
# `--repo` requires a space or `=`. Anchored at command start / a shell separator
# so a literal `gh pr` inside an argument is not rewritten. Global (`g`) so EVERY
# `gh ... pr` segment in a chained command is canonicalized, not just the first.
CMD=$(printf '%s' "$CMD" | sed -E 's/(^[[:space:]]*|[;&|()]+[[:space:]]*)gh[[:space:]]+(((-R([[:space:]]+|=)?|--repo([[:space:]]+|=))[^[:space:]]+)[[:space:]]+)*pr/\1gh pr/g')
# gh also accepts -R/--repo AFTER the `pr` subcommand (`gh pr -R o/r create`); strip
# those too so they can't sit between `pr` and `create`. Targeted to -R/--repo (the
# value-taking flag) — NOT arbitrary text.
CMD=$(printf '%s' "$CMD" | sed -E 's/(gh[[:space:]]+pr[[:space:]]+)(((-R([[:space:]]+|=)?|--repo([[:space:]]+|=))[^[:space:]]+)[[:space:]]+)+/\1/g')
printf '%s' "$CMD" | grep -qE 'gh[[:space:]]+pr[[:space:]]+create' || exit 0

# Catch every base form: --base <x>, --base=<x>, -B <x>, -B=<x>.
BASE=$(printf '%s' "$CMD" \
  | grep -oE '(--base[[:space:]]+|--base=|-B[[:space:]]+|-B=)[^[:space:]]+' \
  | head -1 \
  | sed -E 's/^(--base[[:space:]]+|--base=|-B[[:space:]]+|-B=)//' || true)
if [ -n "$BASE" ] && ! printf ',%s,' "$(printf '%s' "$ALLOWED" | tr -d '[:space:]')" | grep -Fq ",${BASE},"; then
  echo "BLOCKED: PRs must target one of [$ALLOWED] (got base '$BASE')." >&2
  exit 2
fi

# plane.so GitHub sync: the PR TITLE must reference EXACTLY ONE main work item as
# [PREFIX-123] — plane's GitHub integration matches the bracketed ID in the title
# and syncs the PR status to that work item. Secondary items are mentioned WITHOUT
# brackets, so we count only IDs in the title (a bracketed ID in --body must not
# satisfy this). Commits keep (PREFIX-123). Prefix from WORKFLOW_TASK_ID_PREFIX
# when set; otherwise any [ABC-123] counts.
PREFIX="${WORKFLOW_TASK_ID_PREFIX:-[A-Z][A-Z0-9]+}"
# Extract the --title value: --title "x" / --title=x / -t "x" / -t x (first match).
TITLE=$(printf '%s' "$CMD" \
  | grep -oE "(--title[[:space:]]+|--title=|-t[[:space:]]+|-t=)(\"[^\"]*\"|'[^']*'|[^[:space:]]+)" \
  | head -1 \
  | sed -E "s/^(--title[[:space:]]+|--title=|-t[[:space:]]+|-t=)//; s/^[\"']//; s/[\"']$//" || true)
IDS=$(printf '%s' "$TITLE" | grep -oE "\[${PREFIX}-[0-9]+\]" | sort -u || true)
N=$(printf '%s' "$IDS" | grep -c . || true)
if [ "$N" -ne 1 ]; then
  echo "BLOCKED: the PR TITLE must reference EXACTLY ONE main plane.so work item as [${WORKFLOW_TASK_ID_PREFIX:-ABC}-123] (found $N in the title) — this links the PR for status sync. Mention any secondary items WITHOUT brackets." >&2
  exit 2
fi

jq -n '{"systemMessage":"PR checklist: self-review done (fix issues from earlier steps too); exactly one main work item as [ID] in the title (plane sync) — done; Conventional Commit title; local gates green (typecheck, tests, docstring-coverage). After opening, see the CodeRabbit review through to resolution before handing back."}'
exit 0
