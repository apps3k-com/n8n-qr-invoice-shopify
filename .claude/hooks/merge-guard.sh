#!/usr/bin/env bash
# PreToolUse(Bash, git merge) — block local merges while on the protected branch.
# Matches the `merge` subcommand token only (not `git merge-base`/`merge-tree`).
# Provider-neutral: blocks via exit 2 + stderr. Configure: PROTECTED_BRANCH (default main).
set -euo pipefail
PB="${PROTECTED_BRANCH:-main}"

CMD=$(cat | jq -r '.tool_input.command // ""')
# Normalize away git GLOBAL options between `git` and `merge` so e.g. `git -c key=val
# merge` or `git --git-dir .git merge` can't bypass the check — WITHOUT misreading
# informational options (`git --help merge` is NOT a merge). Only known global options
# are stripped: value-taking ones consume their separate-or-`=` arg; `--help`/`-h`/
# `--version` are intentionally excluded. Anchored at command start / a shell separator.
CMD=$(printf '%s' "$CMD" | sed -E 's/(^[[:space:]]*|[;&|()]+[[:space:]]*)git[[:space:]]+(((-c|-C|--git-dir|--work-tree|--namespace|--exec-path|--super-prefix|--config-env|--attr-source)([[:space:]]+|=)[^[:space:]]+|--bare|--no-pager|--paginate|--no-optional-locks|--literal-pathspecs|--no-literal-pathspecs|--glob-pathspecs|--noglob-pathspecs|--icase-pathspecs|--no-replace-objects|--no-advice|-p|-P)[[:space:]]+)*merge/\1git merge/')
printf '%s' "$CMD" | grep -qE 'git[[:space:]]+merge([[:space:]]|$)' || exit 0   # not merge-base/merge-tree
printf '%s' "$CMD" | grep -qE 'git[[:space:]]+merge[[:space:]]+--abort' && exit 0   # fixing mistakes is fine

BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ "$BRANCH" = "$PB" ]; then
  echo "BLOCKED: cannot merge into $PB locally. Use a PR: gh pr create --base $PB" >&2
  exit 2
fi
exit 0
