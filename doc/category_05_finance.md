# Finance — Widget Development Plan

## Overview

This category contains a single widget surfacing the employee's petty cash balance and utilization. Like Purchase, it is finance-sensitive and requires strict permission scoping.

**Widgets in this category**
1. Petty Cash (full width, single row)

**Frontend reference:** `screen2_v7` — Finance section. Card uses near-black gradient with the giant faded dirham symbol (د.إ) bottom-right.

---

## Widget model configuration (emp_mobile_conf)

| Field | Petty Cash |
|---|---|
| code | `petty_cash` |
| name | Petty Cash |
| category | `finance` |
| sequence | 1 |
| size | `full` |
| icon | wallet |
| theme_color | charcoal (#2A2D35) |
| is_active | True |
| role_ids | Site engineers, project managers, finance, general managers |

---

## Widget 1: Petty Cash

### Frontend (must match v7)
- Full-width card with min-height 140px
- Gradient: `#3A3D45 → #2A2D35 → #1F2229 → #181B22` (deep charcoal) with subtle green radial highlight top-right
- **Giant faded dirham symbol "د.إ"** at the bottom-right corner (opacity ~0.18, large size — ~38px font)
- Curved ring decoration top-right (white at low opacity — replicates the original Petty Cash theme)
- Green gradient icon container top-right with wallet icon
- Top label "Balance" in light gray, title "Petty Cash"
- **Two-column stat row** separated by faint vertical white divider:
  - Available: "AED 2,450" (white)
  - Spent: "AED 550" (orange `#F59E3D`)
- Trend in light blue at bottom: "18% utilized this month"

### Backend business logic

#### Data source options (confirm during build)
Petty Cash in Elrace is likely tracked through one of these:
- **Option A:** A dedicated custom model (e.g. `elrace.petty.cash` with `request`, `approval`, `expense` records). Most likely — confirm in the existing codebase.
- **Option B:** Standard Odoo `hr.expense` filtered by a "petty cash" expense category.
- **Option C:** `account.move` entries against a petty-cash journal.

Use whichever is already in production. Do not introduce a new model.

#### Personal vs scoped balance
- **Site engineers / supervisors** → their personal petty cash allocation (one balance per employee).
- **Project managers** → if Elrace tracks petty cash per project, show the manager's total project petty cash; otherwise their personal allocation.
- **Finance / general managers** → option to view aggregated company-wide balance (display the company total or the user's personal if they have an allocation themselves — default to personal, with the module showing the aggregate).

The widget always shows ONE balance number — never tries to show multiple balances side by side. Frontend stays clean.

#### Calculations
- **Available balance:** initial allocation + any top-ups − approved expenses so far (running total). All in AED.
- **Spent this month:** sum of approved expenses in current month for the same scope.
- **Utilization %:** `(spent_this_month / monthly_allocation) × 100`, capped at 100% display-wise (if user overspends, show 100% in trend but flag in subtitle).
- **Currency formatting:** always AED. Show full number with thousands separator (`2,450` not `2K`) — small enough to read fully.

#### Special states
- **Empty:** no allocation yet → show "AED 0" / "AED 0" with subtitle "No allocation set" (replaces the trend line).
- **Overspent (negative balance):** show negative number in red, subtitle "⚠ Overspent" in red, utilization shown as ">100%".
- **Pending approvals:** if there are pending petty cash requests, optionally show "+1 pending request" inline (sub-line below the trend, in amber). Configurable on/off in widget settings.

### Edge cases
- Top-ups recorded mid-month: counted toward `available` but not toward `spent` (spent only counts actual expenses).
- Refunds / reversals: treated as negative expenses (reduce spent).
- Currency conversion: if an expense is in non-AED, convert at the expense `date` rate.
- Multi-allocation employees (rare): sum them and show one balance.
- Month boundary: at the 1st, `spent_this_month` resets to 0, `available` carries over.

### API contract (data only)
- Input: employee from middleware → scope resolved server-side.
- Output payload: `available_amount` (raw number), `available_display` (formatted: "AED 2,450"), `spent_amount` (raw), `spent_display` ("AED 550"), `utilization_pct` (integer, can exceed 100), `pending_requests_count` (optional, 0 if none), `status_flag` ("normal" / "low" / "overspent" / "empty"), `scope` ("personal" / "project" / "company").

### Tap behavior (frontend)
Opens Petty Cash module:
- Shows full transaction log (expenses, top-ups, approvals)
- Action button to submit a new petty cash request
- If user has approval authority over others' requests, shows pending approvals section

### Caching
Lazy cache keyed by `(employee_id, widget_code, scope, current_month)`. TTL: 15 minutes. Invalidated on petty cash model create/write/unlink for any record involving the employee's allocation.

### Acceptance criteria
- Balance matches Odoo Petty Cash reports for the same period and scope.
- Currency formatting consistent (always AED, comma thousands separator).
- All four status flags (`normal` / `low` / `overspent` / `empty`) render distinct, appropriate visual states without breaking layout.
- Card renders identically to v7 including the giant dirham symbol, curved ring, and green icon container.

---

## Permission rules (specific to Finance)

Like LPO, this widget shows financial data, so:

- If the requesting employee has none of the allowed roles, return widget envelope with `is_authorized: false` and empty data. Frontend renders a "Not authorized" placeholder so layout integrity is preserved.
- Audit log: every fetch of Petty Cash widget data should write to the access-log table with `employee_id`, `timestamp`, `scope`, `value_shown` (so finance can verify what users saw and when).
- Never log raw amounts in regular application logs — only in the dedicated audit table with appropriate access restrictions.

---

## Sequencing & dependencies

### Dependencies
- Existing petty cash model (confirm Option A/B/C during build kickoff).
- `res.currency` for conversion if multi-currency expenses are possible.
- Existing role_line_ids structure on `hr.employee`.

### Build order
This widget can be developed **in parallel with LPO** since both share the financial-permission pattern. Recommend building LPO first if the petty cash model is custom and needs more investigation — the LPO build confirms the permission and audit-logging patterns first, which Petty Cash then inherits.

### Testing checkpoints
- Verify scope resolution per role across at least 4 roles.
- Verify all 4 status flags (`normal` / `low` / `overspent` / `empty`) trigger correctly.
- Verify currency conversion if multi-currency expenses exist.
- Verify pending-request inline indicator if that feature is enabled.
- Verify audit log writes on every fetch.
- Postman: fetch as authorized roles, unauthorized employee (envelope with `is_authorized: false`), employee with no allocation, employee with overspent balance.
- Flutter golden test for the card matching v7 exactly, including the giant dirham symbol positioning and the curved ring.

### Out of scope (for this iteration)
- In-widget action to submit a petty cash request (only summary; submission lives in the module).
- Multi-month historical trend (only current month shown).
- Per-category expense breakdown (lives in the module).
- Notifications when balance falls below threshold (separate notification system handles this).
- Approval inbox preview inside the widget (lives in the module).
