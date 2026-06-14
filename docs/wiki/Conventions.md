# Conventions

_Source: `AGENTS.md` / `CLAUDE.md` / `.claude/hooks/`. These are the binding
rules; this page is the human-readable summary._

## Language
- Chat with the user: **German**. Code, comments, commits, PRs: **English**.

## Git workflow (main-only)
- One long-lived branch **`main`**; short-lived `feature/<scope>` (or `fix/`,
  `chore/`, `docs/`) branches off `main`, PR targets `main`.
- Never commit/push/merge `main` directly; the **owner** merges PRs.
- Supersedes the older Linear `TUF-` / git-worktree flow still described in
  `Architecture` (kept only as historical context).

## Commits & PRs
- **Conventional Commits** (`type(scope): subject`).
- Every commit and PR carries the plane.so **work-item ID**; the **PR title**
  references the main work item in **square brackets** `[<ID>]` (links the PR for
  status sync).
- Enforced by `.claude/hooks/` (commit-guard, push-guard, pr-validate, …).

## n8n workflow sync
- Edit the workflow in n8n (via the `n8n-apps3k` MCP), validate + test, then
  re-export `QR-Rechnung.json` into the repo in the **same PR** so git and the
  live instance stay in sync.

## Review
- **Self-review before every PR.** **CodeRabbit** reviews PRs to `main`; address
  valid feedback, reject invalid with reasoning, always mention `@coderabbitai`.
