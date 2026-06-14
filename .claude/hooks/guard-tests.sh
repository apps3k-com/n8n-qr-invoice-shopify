#!/usr/bin/env bash
# Smoke tests for the git guards. Runs each hook against a sample tool command (as the
# harness would feed it on stdin) and asserts the exit code (2 = blocked, 0 = allowed).
# Not wired into CI (CI runs Vitest); run manually: bash .claude/hooks/guard-tests.sh
#
# PROTECTED_BRANCH is set to the CURRENT branch so the "on the protected branch" guards
# (HEAD resolution, local merge) are exercised without having to be on `main`.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
PB="$(git branch --show-current 2>/dev/null)"; PB="${PB:-main}"   # show-current is empty (not an error) in detached HEAD
export PROTECTED_BRANCH="$PB"
# Isolate from any ambient workflow env so results are deterministic: PR base
# then defaults to PB, and the work-item prefix accepts any [ABC-123].
unset WORKFLOW_PR_BASES WORKFLOW_TASK_ID_PREFIX 2>/dev/null || true
fail=0

# check <hook> <expected-exit> <command> <label>
check() {
  local hook="$1" want="$2" cmd="$3" label="$4" got
  printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$cmd" | jq -Rs .)" \
    | bash "$DIR/$hook" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq "$want" ]; then
    printf '  ok   [%s] %s (exit %s)\n' "$hook" "$label" "$got"
  else
    printf '  FAIL [%s] %s — expected exit %s, got %s\n' "$hook" "$label" "$want" "$got"
    fail=1
  fi
}

echo "PROTECTED_BRANCH=$PB"

# push-guard (2 = blocked)
check push-guard.sh 2 "git push origin HEAD"          "push HEAD to protected (implicit dest, P1 fix)"
check push-guard.sh 2 "git push origin @"             "push @ to protected (implicit dest)"
check push-guard.sh 2 "git push origin $PB"           "push protected explicitly"
check push-guard.sh 2 "git push origin HEAD:$PB"      "push HEAD:protected"
check push-guard.sh 2 "git push --force origin topic" "force push"
check push-guard.sh 0 "git push origin some-feature"  "push a feature branch (allowed)"
check push-guard.sh 0 "git push origin HEAD:other"    "push HEAD to a non-protected branch (allowed)"
check push-guard.sh 2 "git -c k=v push origin HEAD"   "push HEAD behind -c global option"
check push-guard.sh 2 "git --git-dir .git push origin $PB" "push protected behind --git-dir value option"
check push-guard.sh 2 "git --no-pager push origin $PB"    "push protected behind --no-pager flag"
check push-guard.sh 0 "git --help push"                   "git --help push is informational, not a push (no false block)"
check push-guard.sh 2 "(git -c k=v push origin $PB)"      "push protected inside a subshell"
check push-guard.sh 2 " git push origin $PB"              "push protected with leading whitespace"
check push-guard.sh 2 "git push HEAD:$PB"                 "refspec-first (no remote) to protected — first token must not be shifted away (critical fix)"
check push-guard.sh 0 "git push HEAD:other-branch"        "refspec-first to a non-protected branch (allowed)"

# merge-guard (2 = blocked while on the protected branch)
check merge-guard.sh 2 "git merge feature"                "merge on protected"
check merge-guard.sh 2 "git -c user.name=x merge feature" "merge behind -c global option (P2 fix)"
check merge-guard.sh 2 "git -C . merge feature"           "merge behind -C global option (P2 fix)"
check merge-guard.sh 2 "git --git-dir .git merge feature" "merge behind --git-dir value option (P1 r2)"
check merge-guard.sh 0 "git --help merge"                 "git --help merge is informational, not a merge (no false block)"
check merge-guard.sh 2 "(git -c k=v merge feature)"       "merge protected inside a subshell"
check merge-guard.sh 2 " git merge feature"              "merge protected with leading whitespace"
check merge-guard.sh 0 "git merge --abort"               "merge --abort (allowed)"
check merge-guard.sh 0 "git merge-base a b"              "merge-base is not a merge (allowed)"

# branch-name-guard (2 = rejected name, 0 = accepted)
check branch-name-guard.sh 0 "git checkout -b feature/x"  "prefixed branch (allowed)"
check branch-name-guard.sh 0 "git switch -c fix/y"        "prefixed branch via switch (allowed)"
check branch-name-guard.sh 2 "git checkout -b main"       "reserved name 'main' (blocked)"
check branch-name-guard.sh 2 "git checkout -b staging"    "reserved name 'staging' (blocked)"
check branch-name-guard.sh 2 "git branch hotfix"          "bare name without prefix (blocked)"
check branch-name-guard.sh 0 "git checkout -b release/v1.2.0" "semver release branch (allowed)"
check branch-name-guard.sh 2 "git checkout -b release/foo" "non-semver release branch (blocked)"
check branch-name-guard.sh 0 "git branch"                 "branch listing (no name, allowed)"
check branch-name-guard.sh 2 "git -c k=v checkout -b main" "reserved name behind -c global option (can't bypass)"
check branch-name-guard.sh 2 "git --git-dir .git switch -c staging" "reserved name behind --git-dir option (can't bypass)"

# commit-guard (2 = on the protected branch; pass-throughs = 0)
check commit-guard.sh 2 "git commit -m \"feat: x\""       "commit on protected (blocked)"
check commit-guard.sh 2 "git commit --amend --no-edit"    "amend on protected still blocked (protected check precedes amend pass-through)"
check commit-guard.sh 0 "git status"                      "not a commit (allowed)"

# pr-validate (base must be allowed; a bracketed work-item ID is required)
check pr-validate.sh 0 "gh pr create --base $PB --title \"feat: x [AB-1]\""  "PR to allowed base with [ID] (allowed)"
check pr-validate.sh 2 "gh pr create --base nope --title \"feat: x [AB-1]\"" "PR to disallowed base (blocked)"
check pr-validate.sh 2 "gh pr create --base $PB --title \"feat: x\""         "PR without bracketed [ID] (blocked)"
check pr-validate.sh 2 "gh --repo o/r pr create --base nope --title \"x [AB-1]\"" "gh global flag can't bypass base check (blocked)"
check pr-validate.sh 2 "gh -Ro/r pr create --base nope --title \"x [AB-1]\"" "glued -Ro/r short flag can't bypass base check (blocked)"
check pr-validate.sh 2 "gh pr create --base $PB --title \"feat: x [AB-1] [AB-2]\"" "two IDs in the title (blocked — exactly one required)"
check pr-validate.sh 2 "gh pr create --base $PB --title \"feat: x\" --body \"relates [AB-1]\"" "ID only in --body, not title (blocked)"
check pr-validate.sh 0 "gh pr create --base $PB -t \"feat: x [AB-1]\""       "short -t title form with one [ID] (allowed)"
check pr-validate.sh 2 "gh pr view 1 && gh -Ro/r pr create --base nope --title \"x [AB-1]\"" "chained: the 2nd 'gh pr create' segment is still checked (global normalize)"
check pr-validate.sh 0 "gh pr view 9"                                        "gh pr view is not create (allowed)"

# pr-merge-guard (the agent never merges; 2 = blocked)
check pr-merge-guard.sh 2 "gh pr merge 9 --squash"        "gh pr merge (blocked)"
check pr-merge-guard.sh 2 "gh --repo o/r pr merge 9"      "gh global flag can't bypass merge guard (blocked)"
check pr-merge-guard.sh 2 "gh -Ro/r pr merge 9"          "glued -Ro/r short flag can't bypass merge guard (blocked)"
check pr-merge-guard.sh 2 "gh pr view 1 && gh -Ro/r pr merge 9" "chained: the 2nd 'gh pr merge' segment is still caught (global normalize)"
check pr-merge-guard.sh 0 "gh pr create --base $PB --title \"x [AB-1]\"" "gh pr create is not merge (allowed)"
check pr-merge-guard.sh 0 "gh pr view 9"                  "gh pr view is not merge (allowed)"

if [ "$fail" -eq 0 ]; then echo "ALL GUARD TESTS PASSED"; else echo "SOME GUARD TESTS FAILED"; fi
exit "$fail"
