#!/usr/bin/env bash
# PreToolUse(Bash, gh pr merge) — the agent never merges PRs.
# Provider-neutral: blocks via exit 2 + stderr.
set -euo pipefail

CMD=$(cat | jq -r '.tool_input.command // ""')
# Normalize away gh GLOBAL options between `gh` and `pr` (e.g. `gh -R owner/repo pr
# merge`, `gh --repo=owner/repo pr merge`, glued short form `gh -Rowner/repo pr
# merge`) so they can't bypass detection. `-R` allows a glued/spaced/`=` value;
# `--repo` requires a space or `=`.
CMD=$(printf '%s' "$CMD" | sed -E 's/(^[[:space:]]*|[;&|()]+[[:space:]]*)gh[[:space:]]+(((-R([[:space:]]+|=)?|--repo([[:space:]]+|=))[^[:space:]]+)[[:space:]]+)*pr/\1gh pr/')
printf '%s' "$CMD" | grep -qE 'gh[[:space:]]+pr[[:space:]]+merge' || exit 0

echo "BLOCKED: the agent never merges PRs. The project owner merges after the CodeRabbit loop." >&2
exit 2
