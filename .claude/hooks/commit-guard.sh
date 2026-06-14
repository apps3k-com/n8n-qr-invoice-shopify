#!/usr/bin/env bash
# PreToolUse(Bash, git commit) — protected-branch guard + Conventional Commits
# + optional plane.so work-item ID. The Conventional-Commit and task-id checks
# run on the extracted -m MESSAGE, never the whole command line. Editor commits
# (no inline message) are blocked only when a task-id prefix is enforced.
#
# Provider-neutral: blocks via exit code 2 + stderr, honored by Claude Code and
# Codex. Shared by .claude/settings.json and .codex/hooks.json. Configure via env:
#   PROTECTED_BRANCH         (default: main)
#   WORKFLOW_TASK_ID_PREFIX  (e.g. APP; unset/empty = skip the task-id check)
set -euo pipefail
PB="${PROTECTED_BRANCH:-main}"

CMD=$(cat | jq -r '.tool_input.command // ""')
printf '%s' "$CMD" | grep -qE 'git[[:space:]]+commit([[:space:]]|$)' || exit 0

BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ "$BRANCH" = "$PB" ]; then
  echo "BLOCKED: never commit directly on '$PB'. Create a feature branch: git switch -c feature/<scope>" >&2
  exit 2
fi

# Message checks apply only to an inline -m message; -F/--file/--amend and
# templated messages can't be parsed here and are passed through. Detect these
# flags ONLY in the part BEFORE the first -m/--message, so option-like text inside
# the message (e.g. `git commit -m "fix --file handling"`) can't force a bypass.
PRE_MSG=$(printf '%s' "$CMD" | sed -E 's/(^|[[:space:]])(--message|-m)([[:space:]]|=).*//')
if printf '%s' "$PRE_MSG" | grep -qE '(^|[[:space:]])(--amend|(-F|--file)(=|[[:space:]]|$))'; then
  exit 0
fi
# Extract the message from any -m / --message form, including combined short
# flags (-m "x", -m'x', -m"x", -mx, -am "x", -sam 'x', --message "x",
# --message=x). \x27 = single quote, to keep this perl single-quoted.
MSG=$(printf '%s' "$CMD" | perl -ne '
  if (/(?:^|\s)--message(?:=|\s+)("([^"]*)"|\x27([^\x27]*)\x27|\S+)/
      || /(?:^|\s)-[A-Za-z]*m\s*("([^"]*)"|\x27([^\x27]*)\x27|\S+)/) {
    my $r = $1; $r =~ s/^["\x27]//; $r =~ s/["\x27]$//; print $r; exit;
  }')
if [ -z "$MSG" ]; then
  # No inline message → composed in an editor, which a PreToolUse hook cannot
  # inspect. When a task-id prefix is enforced, require an explicit -m so the
  # Conventional-Commit + task-id checks stay enforceable.
  if [ -n "${WORKFLOW_TASK_ID_PREFIX:-}" ]; then
    echo "BLOCKED: editor commits can't be validated. Use: git commit -m \"<type>(scope): subject (${WORKFLOW_TASK_ID_PREFIX}-NNN)\"" >&2
    exit 2
  fi
  exit 0
fi

# Conventional Commits (on the message).
if ! printf '%s' "$MSG" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|chore|ci|build|revert)(\(.+\))?!?:[[:space:]].+'; then
  echo "BLOCKED: commit message must follow Conventional Commits: type(scope): description." >&2
  echo "  Types: feat fix docs style refactor perf test chore ci build revert" >&2
  echo "  Got: $MSG" >&2
  exit 2
fi

# plane.so work-item ID (on the message, not the whole command).
if [ -n "${WORKFLOW_TASK_ID_PREFIX:-}" ] \
   && ! printf '%s' "$MSG" | grep -qE "${WORKFLOW_TASK_ID_PREFIX}-[0-9]+"; then
  echo "BLOCKED: commit message must reference the plane.so work-item ID (${WORKFLOW_TASK_ID_PREFIX}-NNN)." >&2
  exit 2
fi
exit 0
