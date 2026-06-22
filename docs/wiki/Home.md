# n8n-qr-invoice-shopify — Documentation

**Single source of truth for the documentation of this automation.** Docs live in
**`docs/wiki/`** in this repo (PR-reviewed, versioned with the code) and are
**published to this GitHub Wiki automatically** on merge to `main`.

This is an n8n automation that generates **Swiss QR-Bills** for Shopify orders
requiring invoice payment (webhook → download invoice → qr-invoice.cloud →
merge PDFs → distribute via email/Slack). The workflow runs in the n8n instance;
this repo holds the exported workflow JSON (`QR-Rechnung.json`) + these docs.

## How this is organized
- **Technical documentation — English** (the development language): see the
  sidebar →
- **[Architecture](Architecture)** is the full technical reference (workflow
  trigger, data flow, integrations, data tables), migrated from the former root
  `CLAUDE.md`.

## Conventions
- **`docs/wiki/` in the repo is the source of truth** — this GitHub Wiki is a
  generated, read-only mirror. **Don't edit wiki pages directly**; edit
  `docs/wiki/**` via a pull request.
- Don't duplicate doc bodies in the task tracker (GitHub Projects) — that holds *tasks*.
- **Agent-runtime instructions stay in the repo** (`CLAUDE.md` / `AGENTS.md`) and
  stay slim; they point here for depth.
