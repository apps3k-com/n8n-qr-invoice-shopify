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
# `gh pr new` is a hidden built-in alias for `gh pr create` — match both so it can't bypass.
printf '%s' "$CMD" | grep -qE 'gh[[:space:]]+pr[[:space:]]+(create|new)' || exit 0

# Catch every base form: --base <x>, --base=<x>, -B <x>, -B=<x>.
BASE=$(printf '%s' "$CMD" \
  | grep -oE '(--base[[:space:]]+|--base=|-B[[:space:]]+|-B=)[^[:space:]]+' \
  | head -1 \
  | sed -E 's/^(--base[[:space:]]+|--base=|-B[[:space:]]+|-B=)//' || true)
if [ -n "$BASE" ] && ! printf ',%s,' "$(printf '%s' "$ALLOWED" | tr -d '[:space:]')" | grep -Fq ",${BASE},"; then
  echo "BLOCKED: PRs must target one of [$ALLOWED] (got base '$BASE')." >&2
  exit 2
fi

# GitHub issue link: the PR BODY must close its work item with a keyword
# (Closes/Fixes/Resolves #N) so GitHub auto-closes the issue on merge and the
# Project's built-in workflow moves it to Done. An inline --body/-b (incl. multi-line)
# is inspected; a body supplied via file/editor falls through to the reminder.
# Toggle with WORKFLOW_REQUIRE_ISSUE_REF (default: true).
if [ "${WORKFLOW_REQUIRE_ISSUE_REF:-true}" = "true" ] \
   && ! printf '%s' "$CMD" | grep -qE '(--body-file|(^|[[:space:]])-F)([[:space:]]|=)'; then
  # Extract the --body / -b value with perl in slurp mode (-0777) so a MULTI-LINE
  # quoted body is captured whole (grep is line-based and would only see line 1).
  # Forms: --body "x" / --body 'x' / --body=x / -b "x" / -b 'x' / -b=x / -bx.
  BODY=$(printf '%s' "$CMD" | perl -0777 -ne '
    if (/(?:^|\s)--body(?:=|\s+)"([^"]*)"/)          { print $1; exit }
    if (/(?:^|\s)--body(?:=|\s+)\x27([^\x27]*)\x27/) { print $1; exit }
    if (/(?:^|\s)--body=(\S+)/)                       { print $1; exit }
    if (/(?:^|\s)-b\s*"([^"]*)"/)                     { print $1; exit }
    if (/(?:^|\s)-b\s*\x27([^\x27]*)\x27/)            { print $1; exit }
    if (/(?:^|\s)-b=?(\S+)/)                          { print $1; exit }' 2>/dev/null || true)
  if [ -n "$BODY" ] && ! printf '%s' "$BODY" | grep -qiE '(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]]+#[0-9]+'; then
    echo "BLOCKED: the PR body must link its issue with a closing keyword, e.g. 'Closes #123'. Mention secondary issues without a keyword." >&2
    exit 2
  fi
fi

jq -n '{"systemMessage":"PR checklist: self-review done (fix issues from earlier steps too); PR body links its issue (Closes #N); Conventional Commit title; local gates green (typecheck, tests, docstring-coverage). After opening, see the CodeRabbit review through to resolution before handing back."}'
exit 0
