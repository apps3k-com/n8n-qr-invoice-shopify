# AGENTS.md — n8n-qr-invoice-shopify

> **No hallucination.** Every assumption, plan, review and diagnosis is verified
> against the real workflow, the live n8n instance and connected third-party
> systems — never guessed. If a source is missing, **ask** instead of inventing.

**n8n-qr-invoice-shopify** — an n8n automation that generates Swiss QR-Bills for
Shopify orders requiring invoice payment (webhook → download invoice → qr-invoice.cloud
→ merge PDFs → email/Slack). The workflow lives in the n8n instance; this repo holds
the exported workflow JSON + docs. Repo: `apps3k-com/n8n-qr-invoice-shopify`.

## Core rules (apps3k common workflow)

- **Language:** chat with the user = German. Code, comments, commits, PRs = English.
- **Memory:** only **apps3k-memory** (`https://mcp-auth.apps3k.com/mcp/apps3k-memory`).
  Search it before any work; if a memory references a plane.so work item, read it. Store
  after each step. If the MCP is down, tell the user, cache memories and add them
  later. Never store secrets (only 1Password paths).
- **Diagnose before assuming:** inspect the n8n executions / logs and the
  third-party systems (Shopify, qr-invoice.cloud, Gmail, Slack) before claiming a cause.
- **Never** merge a PR to `main` or change the live workflow on production yourself
  without sign-off. **Never** delete or modify production data.
- **Hooks enforce this workflow:** Claude → `.claude/hooks/`, Codex → `.codex/hooks/`.

## Git workflow (main-only)

- One long-lived branch: **`main`**. Short-lived `feature/<scope>` (or `fix/`,
  `chore/`, `docs/`) branch from `main`; the PR targets `main`.
  (Supersedes the older Linear `TUF-` / git-worktree flow described in the wiki.)
- **Conventional Commits.** Every commit and PR description carries the plane.so
  **work-item ID**; the PR title references the main work item as `[<ID>]`.
- **Self-review before a PR:** fix every issue found, including ones from earlier steps.
- **CodeRabbit** reviews PRs against `main`: implement valid feedback + confirm,
  reject invalid with reasoning, always mention `@coderabbitai`; push valid learnings
  to apps3k-memory.
- The PR to `main` is merged by the owner, not the agent.

## Working with the n8n workflow

- The exported workflow is `QR-Rechnung.json`. Edit the workflow in n8n (via the
  `n8n-apps3k` MCP), validate (`n8n_validate_workflow`), test, then re-export the
  JSON into this repo in the same PR so git and the instance stay in sync.

## Detail references (read on demand — do not duplicate here)

| Topic | Where |
|---|---|
| Architecture, data flow, integrations, data tables | GitHub Wiki → `docs/wiki/Architecture.md` |
| Code/commit/test conventions | GitHub Wiki → `docs/wiki/Conventions.md` |
| Local / n8n setup | GitHub Wiki → `docs/wiki/Development-Setup.md` |
