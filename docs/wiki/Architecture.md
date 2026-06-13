# Shopify to QR Invoice Automation — Architecture

> _Technical reference, migrated from the former root `CLAUDE.md`. The **workflow /
> process** sections below (issue flow, git-worktree flow, Linear `TUF-` IDs) are
> **superseded** by the apps3k common workflow in `AGENTS.md` (main-only,
> plane.so work-item IDs) — keep them only as historical n8n/build context. The
> n8n architecture, data-flow and integration detail remain authoritative._

## 1. Project Overview

Automated workflow system that generates Swiss QR-Bills for Shopify orders requiring invoice payment. The system monitors order creation via webhooks, downloads original invoices, generates QR payment slips using the qr-invoice.cloud API, merges PDFs, and distributes them via email (Shop orders) or Slack (POS orders).

**Primary Goal:** Eliminate manual invoice processing by automating QR-Bill generation for all invoice-based payments.

**Scope:**
- Tuftinglove Shopify Store (Shop + POS orders)
- Swiss QR-Bill standard (ISO 20022)
- Integration with Google Drive, Gmail, Slack, Notion

**Key URLs:**
- n8n Workflow: https://n8n.apps3k.com/workflow/EtqPDBEYAI6Lh90a
- Linear Project: https://linear.app/apps3k/project/shopify-to-qr-invoice-50cc91e54907
- Data Table: https://n8n.apps3k.com/projects/wiccQiXgVR9SJMbF/datatables/j0FGBDQgzLbj4ftc
- Google Drive Folder: https://drive.google.com/drive/folders/1aVQbY2IaM1NQQzd_4p3EoHmP5F6bFZLr

---

## 2. Architecture

### Workflow Trigger
```
Shopify Webhook (orders/create)
    ↓
n8n Webhook Receiver
    ↓
Order Processing Pipeline
```

### Main Flow (Order Create)
```
[Webhook] → [Detect Order Type] → [Download Original Invoice]
                                          ↓
                    ┌─────────────────────┴─────────────────────┐
                    ↓                                           ↓
            [Invoice Payment]                           [Non-Invoice Payment]
                    ↓                                           ↓
        [Calculate QRR Reference]                    [Upload to Google Drive]
                    ↓                                           ↓
        [Map Debtor Address]                          [Update Shopify Metafields]
                    ↓                                           ↓
        [Generate QR Payment Part]                    [Log to Data Table]
                    ↓
        [Merge PDFs]
                    ↓
        [Upload to Google Drive]
                    ↓
        [Update Shopify Metafields]
                    ↓
    ┌───────────────┴───────────────┐
    ↓                               ↓
[Shop Order]                   [POS Order]
    ↓                               ↓
[Send Email]               [Send Slack Notification]
    ↓                               ↓
[Log to Data Table]        [Log to Data Table]
```

### Secondary Flow (Order Update)
```
[Webhook orders/updated] → [Analyze Changes]
                                  ↓
            ┌─────────────────────┼─────────────────────┐
            ↓                     ↓                     ↓
      [Payment Received]    [Order Cancelled]     [Amount Changed]
            ↓                     ↓                     ↓
      [Update Metafield]   [Update Data Table]   [Regenerate Invoice]
            ↓                     ↓
      [Slack Notification] [Slack Notification]
```

---

## 3. Key Entities

### Shopify Order Types

| Type | Detection | QR-Bill Required |
|------|-----------|------------------|
| Shop Order + Invoice | `payment_gateway_names` contains "Invoice" or "Rechnung" | ✅ Yes |
| Shop Order + Other | `payment_gateway_names` does NOT contain "Invoice" | ❌ No (archive only) |
| POS Order + Receipt | `payment_terms.payment_terms_type === "receipt"` | ✅ Yes |
| POS Order + Paid | `financial_status === "paid"` | ❌ No (archive only) |

### QR-Bill Components

| Component | Source | Format |
|-----------|--------|--------|
| **Creditor** | Static | Studio3000 GmbH, Bachstrasse 33, 5034 Suhr, CH |
| **IBAN** | Static | CH423000523078572701L (QR-IBAN, IID 30005) |
| **Reference Type** | Static | QRR (27-digit with Modulo 10 check digit) |
| **QRR Reference** | Calculated | `YYYYMMDD` + `OrderNumber` padded to 26 digits + check digit |
| **Amount** | Order | `total_price` |
| **Currency** | Order | CHF or EUR |
| **Debtor** | Order | `billing_address` mapped to structured format |

### Shopify Custom Metafields

| Metafield | Namespace.Key | Type | Description |
|-----------|---------------|------|-------------|
| QR Invoice URL | `custom.qr_invoice` | file_reference | Merged PDF with QR payment slip |
| Due Date | `custom.qr_invoice_due_date` | date | Order date + 30 days |
| Payment Date | `custom.qr_invoice_payment_date` | date | Set when payment received |
| Google Drive Link | `custom.qr_invoice_gdrive_link` | url | Public share URL |

### Data Table Schema: `[TL] QR Invoice Mapping`

| Column | Type | Description |
|--------|------|-------------|
| order_id | String | Shopify Order ID |
| order_number | String | Order number without # |
| order_name | String | Order name with # |
| source | String | "shop" or "pos" |
| is_invoice | Boolean | True if invoice payment |
| qrr_reference | String | 27-digit QR reference |
| gdrive_file_id | String | Google Drive file ID |
| gdrive_share_url | String | Public share URL |
| shopify_metafield_id | String | Metafield ID for updates |
| email_sent | Boolean | Email sent flag |
| email_sent_at | DateTime | Email timestamp |
| slack_notified | Boolean | Slack notification flag |
| status | String | pending/completed/paid/cancelled/failed |
| error_message | String | Error details if failed |
| created_at | DateTime | Creation timestamp |
| updated_at | DateTime | Last update timestamp |

### External APIs

| API | Purpose | Documentation |
|-----|---------|---------------|
| qr-invoice.cloud | Generate QR payment parts | https://rest.qr-invoice.cloud/swagger-ui/index.html |
| Shopify Admin API | Order data, Metafields | https://shopify.dev/docs/api/admin-rest |
| Google Drive API | PDF storage, Share links | Via n8n Google Drive node |

---

## 4. Rules

### Tool Usage

1. **ALWAYS** use `n8n-railway` MCP tools when:
   - Searching for nodes (`search_nodes`)
   - Getting node documentation (`get_node`)
   - Validating workflows (`validate_workflow`, `n8n_validate_workflow`)
   - Creating/updating workflows (`n8n_create_workflow`, `n8n_update_partial_workflow`)
   - Testing workflows (`n8n_test_workflow`)

2. **ALWAYS** use Shopify skill (`/mnt/skills/user/shopify/SKILL.md`) when:
   - Working with Shopify API endpoints
   - Configuring Shopify nodes
   - Understanding order/metafield structures

3. **ALWAYS** use n8n documentation skills when:
   - Writing Code node JavaScript (`/mnt/skills/user/n8n-code-javascript/SKILL.md`)
   - Understanding expression syntax (`/mnt/skills/user/n8n-expression-syntax/SKILL.md`)
   - Configuring nodes (`/mnt/skills/user/n8n-node-configuration/SKILL.md`)

### Verification Requirements

1. **NEVER assume** node properties or API parameters
2. **ALWAYS fact-check** against:
   - n8n node documentation via `get_node` tool
   - Shopify API documentation via web search
   - qr-invoice.cloud Swagger documentation
3. **ASK when in doubt** - clarifying questions are preferred over incorrect implementations

### Code Standards

1. Use `Run Once for Each Item` mode for Code nodes processing individual items
2. Use `Run Once for All Items` mode only when explicitly needed for aggregation
3. Always preserve `_meta` objects through the pipeline for data continuity
4. Use `$input.item.json` for current item, `$('NodeName').item.json` for specific node reference
5. Handle errors gracefully with try/catch and meaningful error messages

---

## 5. Project Management

> **HISTORICAL — superseded by the root `AGENTS.md` (and `Conventions`).**
> Everything in this section (Linear project/issues, the *Issue Workflow* and the
> *Git Worktree Workflow*, and the "NEVER work on main" rules below) reflects the
> **old** Linear + dev/worktree process. The current workflow is **main-only**:
> short-lived `feature/<scope>` off `main` → PR to `main`; tracking is **plane.so**
> (not Linear); the owner merges. The text below is kept only for historical
> traceability of the original build.

### Linear Project

**Project:** Shopify to QR Invoice  
**URL:** https://linear.app/apps3k/project/shopify-to-qr-invoice-50cc91e54907  
**Team:** Tuftinglove

### Issue Workflow

```
┌──────────┐     ┌─────────────┐     ┌───────────┐     ┌──────┐
│ Backlog  │ ──► │ In Progress │ ──► │ In Review │ ──► │ Done │
└──────────┘     └─────────────┘     └───────────┘     └──────┘
     ▲                  │                   │              │
     │                  │                   │              │
   CREATE            WORKING             COMPLETED      HUMAN ONLY
```

### Status Rules

| Action | Status Change | Who |
|--------|---------------|-----|
| Create new issue | → **Backlog** | AI/Human |
| Start working on issue | Backlog → **In Progress** | AI/Human |
| Implementation complete | In Progress → **In Review** | AI/Human |
| Final approval | In Review → **Done** | ⚠️ **HUMAN ONLY** |

### Git Worktree Workflow

**CRITICAL RULE:** Each Linear issue MUST have its own dedicated git worktree.

#### Worktree Creation

When starting work on a Linear issue:

1. **ALWAYS** create a new worktree for the issue:
   ```bash
   git worktree add ../n8n-qr-invoice-shopify-TUF-XXX -b feature/TUF-XXX
   cd ../n8n-qr-invoice-shopify-TUF-XXX
   ```

2. **Naming convention:** `feature/TUF-XXX` where XXX is the issue number

3. **Directory structure:**
   ```
   n8n-qr-invoice-shopify/          # Main worktree (main branch)
   n8n-qr-invoice-shopify-TUF-105/  # Issue TUF-105 worktree
   n8n-qr-invoice-shopify-TUF-106/  # Issue TUF-106 worktree
   ```

4. **Claude Code settings:** Project settings in `.claude/settings.json` are tracked in Git and automatically available in all worktrees. Local settings (`.claude/settings.local.json`) are gitignored and worktree-specific.

#### Worktree Workflow

1. **Start issue** → Create worktree → Move to "In Progress"
2. **Work on issue** → Commit changes in worktree
3. **Complete work** → Move to "In Review" → Push branch
4. **User approval** → User moves to "Done" → **AI merges worktree to main**

#### Merge Process

When user moves issue to "Done":

1. **Switch to main worktree:**
   ```bash
   cd /Users/bvk/Documents/Coding/tuftinglove/n8n-qr-invoice-shopify
   ```

2. **Merge the feature branch:**
   ```bash
   git merge feature/TUF-XXX
   ```

3. **Push to remote:**
   ```bash
   git push origin main
   ```

4. **Clean up worktree:**
   ```bash
   git worktree remove ../n8n-qr-invoice-shopify-TUF-XXX
   git branch -d feature/TUF-XXX
   ```

#### Rules

- **NEVER** work directly on main branch
- **NEVER** merge to main until user moves issue to "Done"
- **ALWAYS** create commits with meaningful messages referencing the issue (e.g., "TUF-105: Download original invoice from Shopify")
- **ALWAYS** verify worktree is clean before merging

### Issue Creation Rules

1. **ALWAYS** create issues in status `Backlog`
2. **NEVER** create issues in status `Triage`
3. **NEVER** change status to `Done` - this is reserved for human approval
4. Include comprehensive agent instructions in issue description
5. Link related issues in description (dependencies)
6. Use label `Feature` for new functionality

### Current Issues

| Issue | Title | Step |
|-------|-------|------|
| TUF-105 | Original-Rechnung von Shopify abrufen | 1a |
| TUF-106 | POS-Order ohne Billing Address | 1b |
| TUF-107 | Invoice/Non-Invoice Order Routing | 2a |
| TUF-108 | QRR-Referenz Berechnung | 2b |
| TUF-109 | Debtor-Daten Mapping | 2c |
| TUF-110 | QR-Zahlteil API Generation | 2d |
| TUF-111 | PDF Merge | 3 |
| TUF-112 | Shopify Metafields Upload | 3.1 |
| TUF-113 | Google Drive Upload | 3.2 |
| TUF-114 | Email-Versand | 3.3 |
| TUF-115 | POS Slack Notification | 3.4 |
| TUF-116 | Data Table Logging | 3.5 |
| TUF-117 | Order Update Workflow | 4 |

---

## Quick Reference

### QRR Reference Calculation

```javascript
// Modulo 10 recursive algorithm
function calculateMod10Recursive(ref) {
  const table = [0, 9, 4, 6, 8, 2, 7, 1, 3, 5];
  let carry = 0;
  for (const char of ref) {
    carry = table[(carry + parseInt(char, 10)) % 10];
  }
  return (10 - carry) % 10;
}

// Build QRR: YYYYMMDD + OrderNumber (padded to 26 digits) + check digit
const baseRef = dateStr + orderNumber;
const paddedRef = baseRef.padStart(26, '0');
const checkDigit = calculateMod10Recursive(paddedRef);
const qrrReference = paddedRef + checkDigit; // 27 digits
```

### Invoice Download URL Pattern

```
https://www.tuftinglove.com/apps/download-pdf/orders/20013e86ca78142b8cfa/{order_id}/{order_name}.pdf
```

### Creditor Information (Static)

```json
{
  "iban": "CH423000523078572701L",
  "creditor": {
    "addressType": "STRUCTURED",
    "name": "Studio3000 GmbH",
    "streetName": "Bachstrasse",
    "houseNumber": "33",
    "postalCode": "5034",
    "city": "Suhr",
    "country": "CH"
  }
}
```