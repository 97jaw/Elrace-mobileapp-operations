# Purchase Management — Full Contract

## Overview

The **Purchase Management** module (previously "LPO") is a read-only, role-scoped mobile hub exposing analytics, statistics, lists, detail review, and search across:

1. **Material Requisitions (MR)** — `purchase.requisition` (custom `RCC-MR-*` series)
2. **RFQ / Local Purchase Orders (LPO)** — `purchase.order` (`RCC-RFQ-*`, `RCC-PO-*`)
3. **Invoice Receiving** — `account.move` vendor bills (the "Invoice Receiving List")

Workflow actions (confirm, department-approve, reject) remain in the existing tier-review Email Approval flow (`/api/record/tier_review`). No write/create/unlink operations are performed by the Purchase Management API.

---

## Roles & Capabilities

### Login payload additions

The following fields are injected into the `/api/login` response alongside existing booleans (`is_hr_manager`, `is_pm`, …):

| JSON field | Type | Notes |
|---|---|---|
| `is_purchase_rep` | bool | Purchase Representative |
| `is_purchase_manager` | bool | Purchase Manager (department approver) |
| `is_doc_controller` | bool | Document Controller (invoice receiving) |
| `purchase_scope` | string | `"own"` / `"department"` / `"all"` / `"receiving"` / `"none"` |

Also merged into `role_capabilities` map:
- `x_is_purchase_rep`
- `x_is_purchase_manager`
- `x_is_doc_controller`

### Role source (Odoo)

Resolved from `emp_mobile_conf.role_line_ids` role codes OR from explicit boolean fields on `hr.employee` (`x_is_purchase_rep`, `x_is_purchase_manager`, `x_is_doc_controller`). Both paths are supported by the controller; the explicit field takes priority.

### Scope matrix

| Role | MR tab | RFQ/PO tab | Invoice Receiving tab | Record scope |
|---|---|---|---|---|
| **Purchase Representative** | ✓ (own) | ✓ (own) | — | Records where employee = purchase_rep / requested_by |
| **Purchase Manager** | ✓ (dept / all) | ✓ (dept / all) | ✓ (dept / all) | Department domain or company-wide |
| **Document Controller** | — | read context | ✓ (own assignments) | Invoices where doc_controller = employee |
| Unauthorized | — | — | — | `is_authorized: false` returned |

---

## Domain States

### MR / Purchase Requisition

| Odoo `state` | Mobile display label |
|---|---|
| `draft` | `NEW` |
| `in_progress` | `WAITING DEPARTMENT APPROVAL` |
| `waiting_ir` | `WAITING IR APPROVAL` |
| `approved` | `APPROVED` |
| `rfq_created` | `RFQ CREATED` |
| `received` | `RECEIVED` |
| `rejected` | `REJECT` |

### RFQ / PO (`purchase.order`)

| Odoo `state` | Mobile display label |
|---|---|
| `draft` | `RFQ` |
| `sent` | `RFQ SENT` |
| `to approve` | `WAITING APPROVAL` |
| `purchase` | `PURCHASE ORDER` |
| `done` | `RECEIVED` |
| `cancel` | `CANCELLED` |

### Invoice Receiving (`account.move`)

| Odoo `state` | Mobile display label |
|---|---|
| `draft` | `DRAFT` |
| `posted` | `CONFIRMED` |
| `cancel` | `CANCELLED` |

---

## Home Widget (unchanged API key)

Source: `POST /api/widgets/lpo/data` (backward-compatible; optionally alias to `/widgets/purchase/data`).

Response shape (unchanged — `LpoWidgetRecord`):

```json
{
  "result": {
    "status": "success",
    "data": {
      "is_authorized": true,
      "total_amount": 84213.50,
      "total_display": "AED 84K",
      "pending_count": 3,
      "approved_count": 12,
      "month_label": "June 2026",
      "title_line": "Purchase Management · June 2026",
      "delta_percentage": 12.0,
      "delta_direction": "up",
      "previous_total_display": "75K",
      "trend_label": "▲ 12% vs May · AED 75K",
      "scope": "department"
    }
  }
}
```

Card label "LOCAL PURCHASE ORDERS" → updated to "PURCHASE MANAGEMENT" on the Flutter side; the `title_line` can also carry a custom backend label.

---

## API Endpoints

All routes:
- Type: JSON-RPC (`{ "jsonrpc": "2.0", "params": { … } }`)
- Auth: `auth="user"` (Bearer token enforced by session)
- Method: POST
- CSRF: disabled (mobile app)
- Reference implementation: `doc/backend/purchase_api.py`

---

### `POST /api/purchase/overview`

Role-scoped KPI dashboard data for the hub screen.

**Request:** `{}` (empty params)

**Response:**

```json
{
  "success": true,
  "is_authorized": true,
  "available_tabs": ["mr", "rfq", "invoice"],
  "scope": "department",
  "month_label": "June 2026",
  "total_amount": 84213.50,
  "total_display": "AED 84K",
  "pending_count": 3,
  "approved_count": 12,
  "trend_label": "▲ 12% vs May · AED 75K",
  "delta_percentage": 12.0,
  "previous_total_display": "AED 75K",
  "mr_counts": {
    "NEW": 2,
    "WAITING DEPARTMENT APPROVAL": 5,
    "APPROVED": 3,
    "RFQ CREATED": 4
  },
  "po_state_counts": {
    "rfq": 3,
    "rfq_sent": 1,
    "purchase_order": 8
  },
  "invoice_counts": {
    "DRAFT": 4,
    "CONFIRMED": 10,
    "CANCELLED": 1
  }
}
```

**Unauthorized response:**
```json
{ "success": true, "is_authorized": false, "available_tabs": [] }
```

---

### `POST /api/purchase/requisitions`

Paginated MR list.

**Request params:**

| Field | Type | Notes |
|---|---|---|
| `page` | int | Default 1 |
| `limit` | int | Default 10 |
| `keyword` | string | Search name / requester / department |
| `status` | string | Optional — mobile display label (e.g. `"NEW"`, `"APPROVED"`) |

**Response (one item):**

```json
{
  "id": 38324,
  "name": "RCC-MR-38324",
  "requester": "Mohamed Imran Haneef Abdul Malik",
  "requester_photo": "/web/image/hr.employee/123/image_128",
  "department": "Mechanical",
  "project": "[00185] RCC Projects / SKMC SKSP ...",
  "wo_po": "SKMC SKSP – Emergency Phase II – M C U (Renovation)",
  "request_date": "24/08/2026 11:11",
  "deadline": "",
  "state": "WAITING DEPARTMENT APPROVAL",
  "odoo_state": "in_progress",
  "priority": "normal",
  "my_role": "requester",
  "proposed_vendor": "JABER AL JALLAF CENTERAL AIR CONDITIONE CONTRACTING",
  "project_manager": "Taher Talal Qasem Abusharqia"
}
```

---

### `POST /api/purchase/requisition_details`

Full MR detail.

**Request params:** `{ "mr_id": 38324 }`

**Response** includes all header fields + `lines[]` (product, qty, UOM, scheduled date) + `attachments[]` + `linked_rfqs[]` + `approval_trail[]`.

Key header fields mirror the ERP form:
`name`, `state`, `requester_name`, `department`, `wo_po`, `req_ou`, `operating_unit`, `req_resp`, `mr_type`, `request_date`, `received_date`, `deadline`, `analytic_account`, `project_manager`, `priority`, `proposed_vendor`, `quotation_ref`, `task_job_order_user`, `delivery_address`, `line_common_vendor`, `requester_manager`.

---

### `POST /api/purchase/rfqs`

Paginated RFQ/PO list.

**Request params:** `page`, `limit`, `keyword`, `status` (mobile label)

**Response (one item):**

```json
{
  "id": 40191,
  "name": "RCC-RFQ-40191",
  "partner_id": "DESERT HORIZON GENERAL TRANSPORTING",
  "client_photo": "/web/image/res.partner/456/image_128",
  "project": "Zakhir Majlis",
  "requested_by": "Iftikhar Anwar Muhammad Anwar",
  "requested_by_user_photo": "/web/image/hr.employee/789/image_128",
  "requester_manager": "Ahmed Ismail Tantawi",
  "date_order": "24/06/2026 12:00",
  "amount_total": 735.00,
  "amount_display": "AED 735",
  "state": "RFQ",
  "odoo_state": "draft",
  "currency": "AED",
  "department": "Civil",
  "attachments": []
}
```

**Detail:** reuses `GET /api/get_rfq_details` (existing endpoint, params `rfq_id`).

---

### `POST /api/purchase/invoice_receiving`

Paginated Invoice Receiving list (vendor bills).

**Request params:** `page`, `limit` (default 15), `keyword`, `status`

**Response (one item):**

```json
{
  "id": 1971,
  "invoice_no": "AITS24-01971",
  "lpo_no": "RCC-PO-8188",
  "invoice_date": "08/01/2023",
  "invoicing_date": "22/05/2024",
  "amount": 1260.00,
  "amount_display": "AED 1.3K",
  "state": "CONFIRMED",
  "currency": "AED",
  "partner": "AITS TRADING"
}
```

---

### `POST /api/purchase/invoice_receiving_details`

Full vendor bill detail.

**Request params:** `{ "invoice_id": 1971 }`

**Response** includes `invoice_no`, `lpo_no`, `lpo_id`, `invoice_date`, `due_date`, `partner`, `partner_photo`, `amount_untaxed`, `amount_tax`, `amount_total`, `amount_display`, `currency`, `state`, `payment_state`, `narration`, `lines[]`, `attachments[]` (with `file_content_base64` for the Print/LPO button).

---

## Caching

| Route | TTL | Key |
|---|---|---|
| `/api/purchase/overview` | 15 min | `(employee_id, scope, month)` |
| `/api/purchase/requisitions` | 5 min | `(employee_id, scope, page, keyword, status)` |
| `/api/purchase/rfqs` | 5 min | `(employee_id, scope, page, keyword, status)` |
| `/api/purchase/invoice_receiving` | 5 min | `(employee_id, scope, page, keyword, status)` |

Cache invalidated on `purchase.order`, `purchase.requisition`, `account.move` create/write/unlink for any record in the user's scope.

---

## Audit Log

Every `/api/purchase/overview` fetch writes a row to `purchase.mobile.access.log` (create the model if it doesn't exist, or use a lightweight log table):

| Column | Value |
|---|---|
| `employee_id` | `emp.id` |
| `route` | `/api/purchase/overview` |
| `scope` | `purchase_scope` |
| `timestamp` | `datetime.utcnow()` |

---

## Widget: LPO / Purchase Management card

### Frontend visual (v7 — unchanged)
- Full-width deep-navy gradient card `#1E2A4A → #243454`
- Three-column stat: Total (white) · Open/Pending (orange `#F59E3D`) · Closed/Approved (green `#4ADE80`)
- Trend line in light blue `#7FC0FF`
- Tap → opens `PurchaseManagementHubScreen`

### Backend business logic
- **Source model:** `purchase.order`
- **Period:** current calendar month
- **Total:** `sum(amount_total)` in scope
- **Pending:** states `draft`, `sent`, `to approve`
- **Approved:** states `purchase`, `done`
- **Cancelled:** never counted
- **MoM delta:** `(current − previous) / previous × 100`, signed; "New month" if no previous data
- **Currency:** server converts to AED; frontend always receives pre-formatted `total_display`

---

## Acceptance Criteria

- Totals match Odoo Purchase module reports for the same period and scope.
- State mappings for MR / PO / Invoice are documented above and must be confirmed once during initial config — not scattered in code.
- `available_tabs` accurately reflects the role: unauthorized users receive `[]` and `is_authorized: false`.
- Purchase role flags (`is_purchase_rep`, etc.) appear in the login response and in `role_capabilities`.
- Scope isolation tested: a Purchase Rep cannot see another rep's records.
- Invoice Receiving detail returns `file_content_base64` for attached documents.
- Audit log rows are written for every overview fetch.
- Card renders with navy gradient + diagonal beams, matching v7 design.

---

## Build Order & Dependencies

- `purchase.order` — standard Odoo module ✓
- `purchase.requisition` — confirm exact model name on the target installation (may be custom `rcc.purchase.request` or similar)
- `account.move` — standard Odoo accounting ✓
- `emp.mobile.conf` — existing custom model (role lines)
- `tier.review` — for approval trail in MR details

Develop in parallel with other category APIs. Role flag injection into the login controller is a shared dependency — do this first.
