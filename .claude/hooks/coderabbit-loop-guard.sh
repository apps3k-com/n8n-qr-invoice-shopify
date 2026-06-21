#!/usr/bin/env bash
# Stop — "no PR without the CodeRabbit loop". Block finishing while the current
# branch's OPEN PR still has pending (not-yet-reviewed) or UNRESOLVED CodeRabbit
# feedback. Provider-neutral: blocks via exit 2 + stderr (Claude Code + Codex).
#
# Safeguards (never trap a session):
#   - WORKFLOW_SKIP_CR_LOOP=1     explicit escape (owner hand-off).
#   - stop_hook_active            already continuing from a stop hook → allow.
#   - any missing tool / gh error / offline → fail-open (exit 0).
set -euo pipefail
[ "${WORKFLOW_SKIP_CR_LOOP:-}" = "1" ] && exit 0

STDIN=$(cat 2>/dev/null || echo '{}')
command -v jq >/dev/null 2>&1 || exit 0
# Avoid infinite stop loops: if we already blocked once this continuation, allow.
printf '%s' "$STDIN" | jq -e '.stop_hook_active == true' >/dev/null 2>&1 && exit 0
command -v gh >/dev/null 2>&1 || exit 0

PB="${PROTECTED_BRANCH:-main}"
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
{ [ -z "$BRANCH" ] || [ "$BRANCH" = "$PB" ]; } && exit 0

REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
[ -z "$REPO" ] && exit 0
OWNER="${REPO%%/*}"; NAME="${REPO##*/}"

PR=$(gh pr list --repo "$REPO" --head "$BRANCH" --state open --json number --jq '.[0].number' 2>/dev/null || echo "")
[ -z "$PR" ] && exit 0
URL="https://github.com/$REPO/pull/$PR"

# Has CodeRabbit posted a review or any comment yet?
posted=$( { gh api "repos/$REPO/issues/$PR/comments" --jq '[.[]|select(.user.login=="coderabbitai[bot]")]|length' 2>/dev/null;
            gh api "repos/$REPO/pulls/$PR/reviews"  --jq '[.[]|select(.user.login=="coderabbitai[bot]")]|length' 2>/dev/null; } \
          | awk '{s+=$1} END{print s+0}')
if [ "${posted:-0}" -eq 0 ]; then
  # Fail-open: only block if the API is genuinely reachable — a transient API
  # error (the counts above would be empty too) must never trap the session.
  gh api "repos/$REPO" >/dev/null 2>&1 || exit 0
  echo "BLOCKED (CodeRabbit loop): $URL is open but CodeRabbit has not reviewed yet. Monitor the PR and run the loop before finishing. Escape: WORKFLOW_SKIP_CR_LOOP=1." >&2
  exit 2
fi

# Any UNRESOLVED CodeRabbit-authored review thread?
# shellcheck disable=SC2016  # $o/$r/$n are GraphQL variables — must NOT expand in the shell
unresolved=$(gh api graphql \
  -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){nodes{isResolved comments(first:1){nodes{author{login}}}}}}}}' \
  -f o="$OWNER" -f r="$NAME" -F n="$PR" \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[]|select(.isResolved==false)|select(.comments.nodes[0].author.login=="coderabbitai[bot]")]|length' 2>/dev/null || echo 0)
if [ "${unresolved:-0}" -gt 0 ]; then
  echo "BLOCKED (CodeRabbit loop): $URL has $unresolved unresolved CodeRabbit thread(s). Fix or reject each with a reasoned reply (mention @coderabbitai) and resolve them before finishing. Escape: WORKFLOW_SKIP_CR_LOOP=1." >&2
  exit 2
fi
exit 0
