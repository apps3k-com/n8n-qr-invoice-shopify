# Development Setup

_This repo holds an exported n8n workflow, not a buildable app. Verify against the
n8n instance before relying on details here._

## Prerequisites

- Access to the n8n instance: **https://n8n.apps3k.com**
- The `n8n-apps3k` MCP server (for inspecting/editing/validating/testing workflows)
- [`jq`](https://jqlang.github.io/jq/) — required by the `.claude/hooks/` git
  guards; the informational hooks degrade gracefully if it's missing.
- Credentials for the connected systems (Shopify Admin API, qr-invoice.cloud,
  Gmail, Slack, Google Drive) — managed in n8n / **1Password**, never committed.

## Working on the workflow

1. Open the workflow in n8n (`QR-Rechnung.json` is the exported source of truth).
2. Make changes in n8n; **validate** (`n8n_validate_workflow`) and **test**
   (`n8n_test_workflow`) before considering it done.
3. **Re-export** the workflow JSON into this repo and commit it in the same PR so
   git matches the live instance.

## Secrets

All connection secrets live in n8n credentials / **1Password** — never in the repo.
See `Architecture` for the integration list and external API references.
