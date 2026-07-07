# Module 4 — Payslips | Cursor Task File

> **How to use this file:** Read top to bottom before coding. Read companion SRD: `Module_4_Payslips_SRD.docx`. Start at F.0 and work top to bottom.

---

## 0. About This Module

You are extending an **existing Flutter mobile application** for **Pandora Tech LLC**, integrated with **Odoo 14 ERP**. This task file covers **Module 4: Payslips** only.

### What this module does
Employees view their own payslips, salary breakdown (earnings/deductions/net), YTD totals, salary trend chart. Generate Annual Salary Certificate. PDF download with watermark. **HR Managers** additionally see all employees' payslips, payroll-period analytics, bulk export. **Line Managers and PMs do NOT see team payslips** — only HR Manager has team visibility.

### Sensitive nature
Payslips are **highly sensitive personal data**. Special handling patterns required (account masking, screenshot prevention, no caching beyond session).

---

## 1. Critical Rules (NEVER violate these)

| Rule | Reason |
|------|--------|
| Read SRD section before coding | SRD is source of truth |
| Never invent fields | If not in SRD, doesn't exist |
| Never hardcode colors/strings/spacing | Use design tokens |
| Reuse shared widgets | Check `/lib/core/widgets/` first |
| No `!` (bang) without justification | Null safety |
| One task = one commit | `feat(payslips): <TASK_ID> ... — SRD §<section>` |
| Empty / Loading / Error states mandatory | Every list and detail |
| **Bank account numbers MUST be masked** (last 4 digits only) | Sensitive data |
| **No payslip data in local cache beyond session** | Clear on logout |
| **Line Managers and PMs do NOT see team payslips** | Only HR Manager has team access |
| **Payslip generation/computation stays in Odoo** | Mobile is read + PDF download only |

---

## 2. Roles & View Selection

| Boolean | Personal Payslips | Team Payslips |
|---------|-------------------|---------------|
| Any user | Own only | — |
| `is_hr_manager` | Own + All employees | All employees |
| `is_management` | Own only | **NOT visible** |
| `is_pm` | Own only | **NOT visible** |

If multiple flags true, **`is_hr_manager` takes precedence**.

---

## 3. ⚠️ DEVELOPMENT-ONLY: Role Toggle

Reuse the dev role-toggle from Module 1 F.4. On the Payslips widget entry point:

- 👤 **User icon** → Employee view (P1 only)
- 💼 **HR Manager icon** → HR Manager view (tab switcher: My Payslips | All Employees)

A 'Manager' icon is intentionally NOT shown for this module — line managers see the same screens as employees (their own payslips only).

**Final release:** Remove icons, use dynamic role detection. TODO marker:

```dart
// TODO(release): Remove dev role toggle. Replace with dynamic role
// detection from login API booleans (is_hr_manager).
// Reference: Module 4 TASKS.md §3.
```

---

## 4. Design System (inherits from Module 1)

All design tokens (colors, typography, spacing) defined in Module 1 Task F.1. Reuse as-is.

### Net Pay Block — special prominent treatment
Highly prominent boxed display:
- Border: 2px solid primary color
- Background: lightBg
- Padding: 24dp
- Corner radius: 12dp
- Net pay: 32sp w700, primary color
- 'Amount in words' subline: 14sp, mutedText, italic

---

## 5. Folder Structure

```

---

## 6. Module Roadmap

| Phase | Tasks | Why |
|-------|-------|-----|
| **Foundation (F)** | F.0 → F.2 | Module-specific widgets + sensitive-data utilities |
| **Employee (P)** | P1 → P2 → P3 → P4 | Landing → detail → history → certificate |
| **HR Manager (H)** | H1 → D1 | Landing + dashboard |
| **Polish (P)** | P5 → P7 | Verification, sign-off |

### Module screens summary

| ID | Screen | SRD Section | Audience |
|----|--------|-------------|----------|
| P1 | My Payslips Landing | §2.1 | All Users |
| P2 | Payslip Detail | §2.2 | All Users |
| P3 | Full Payslip History | §2.3 | All Users |
| P4 | Annual Salary Certificate | §2.4 | All Users |
| H1 | HR Payroll Landing | §3.1 | HR Manager |
| D1 | Payroll Dashboard | §4 | HR Manager |

---

## 7. Functional Knowledge

### 7.1 Payslip data structure

| Section | Content |
|---------|---------|
| Header | Company name, employee details, pay period, pay date, working/present days |
| Earnings | List of earning lines (Basic, Housing, Transport, Mobile, Other, Overtime, Bonus, etc.) |
| Deductions | List of deduction lines (Loan, Advance, Insurance, etc.) |
| Net Pay | Computed = Gross Earnings − Total Deductions |
| Payment Info | Bank, masked account, payslip reference |
| Year-to-Date | YTD Gross / YTD Deductions / YTD Net |

### 7.2 YTD calculations

| KPI | Logic |
|-----|-------|
| YTD Earnings | Sum of gross earnings from Jan 1 to current month |
| YTD Deductions | Sum of all deduction lines from Jan 1 to current month |
| YTD Net | Sum of net pay from Jan 1 to current month |

### 7.3 Salary trend chart (P1)

Line chart of net pay across last 12 months. X-axis: month/year. Y-axis: AED. Tap a point → opens P2 for that payslip.

### 7.4 Annual Salary Certificate (P4)

Generated on-demand by Odoo report template. Inputs:
- Year (defaults to current year)
- Optional purpose (Bank Loan / Visa / Embassy / General)

Output: PDF certificate with employee details, designation, joining date, basic salary, allowances breakdown, total monthly compensation, period covered. Watermark: emp_id of generating user.

### 7.5 HR Manager view (H1)

- Tab switcher at top: 'My Payslips' (renders P1) / 'All Employees' (renders this view)
- Period selector dropdown (default: most recent closed period)
- KPI strip: Total Paid / Employees / Avg Net Pay (for selected period)
- Search bar (employee name, ID, department)
- Filter bar: by Department / by Designation / by Branch
- Employee cards: avatar, name, ID, designation+dept, net for selected period, PDF icon
- Tap card → P2 (Payslip Detail) for that employee
- Bulk download button at bottom: 'Download All Payslips for [period]'

### 7.6 Payroll Dashboard (D1) charts

1. KPI cards: Total Paid / Headcount (start→end) / Avg Net
2. Payroll Trend (12 months line)
3. Payroll by Department (horizontal bar)
4. Compensation Components donut (Basic / Housing / Transport / Other / OT+Bonus)
5. Top Deductions ranked list

### 7.7 Sensitive data patterns (MANDATORY)

| Pattern | Implementation |
|---------|----------------|
| **Account masking** | Bank account display only last 4 digits ('\*\*\*\*  \*\*\*\*  \*\*\*\*  6411'). Backend never returns full account number. |
| **Screenshot prevention** | On Android set FLAG_SECURE on P2, P4. iOS: hide screen content when app moves to background. |
| **PDF watermark** | emp_id of user generating download. |
| **Cache invalidation** | No payslip data persists beyond active session. Clear on logout. |
| **App switcher mask** | Show blank/branded splash when app moves to background while payslip open. |

### 7.8 Bulk download pattern

Per SRD assumption #4: bulk PDF download for entire payroll period is a backend bulk operation that may take seconds to minutes. Pattern (default): foreground wait with progress indicator. If response time exceeds 30 seconds, switch to backgrounded job + notification. Mark with TODO(backend) for exact pattern confirmation.

---

## 8. API Conventions

Same as Module 1 §8. Mock all responses for Phase 1. Mark with TODO(backend). Backend never returns full bank account numbers — always masked.

---

## 9. Tasks (work top to bottom)

> **Status legend:** `[TODO]` `[IN_PROGRESS]` `[DONE]` `[BLOCKED]` `[NEEDS_REVIEW]`

---

### Phase 0 — Foundation

#### `[TODO]` F.0 — Verify Module 1 foundation
Same checklist as Module 2 F.0. Complete Module 1 first if anything missing.

#### `[TODO]` F.1 — Sensitive data utilities


1. **`sensitive_data.dart`** — utilities:
   - `maskAccountNumber(String full)` → returns last 4 digits with asterisks
   - `enableScreenSecure(BuildContext context)` → sets FLAG_SECURE on Android, hides on app background on iOS
   - `disableScreenSecure(BuildContext context)` → reverses
   - `clearPayslipCache()` → invalidates payslip-related Riverpod providers
2. Add a screen-lifecycle hook so any screen that calls `enableScreenSecure` automatically calls `disableScreenSecure` on dispose.

**Definition of done:** Functions compile, manual test on Android shows screenshots blocked on a test screen.

#### `[TODO]` F.2 — Module-specific shared widgets


1. **`latest_payslip_card.dart`** — prominent card with month/year, period, net pay (large), pay date, View Details + PDF actions
2. **`ytd_kpi_strip.dart`** — three KPI cards: YTD Earnings / YTD Deductions / YTD Net
3. **`salary_trend_chart.dart`** — line chart of net pay last 12 months
4. **`earnings_section.dart`** — list of earning lines + total, label/amount rows
5. **`deductions_section.dart`** — list of deduction lines + total, same pattern
6. **`net_pay_block.dart`** — prominent boxed display per §4 of this file
7. **`masked_account_display.dart`** — uses F.1 `maskAccountNumber` utility
8. **`payroll_trend_chart.dart`** — line chart for D1
9. **`compensation_donut.dart`** — donut chart for D1

**Definition of done:** All widgets compile, render in sandbox.

---

### Phase 1 — Employee Screens

#### `[TODO]` P1 — My Payslips Landing
- **SRD section:** §2.1
- **Wireframe:** §2.1.1
- **Component spec:** §2.1.2

**Steps:**
1. Read SRD §2.1 in full
2. AsyncNotifier returning latest payslip + history (mock 6+ records)
3. Create `p1_landing_screen.dart`:
   - AppBar: 'My Payslips' + dev role toggle
   - **Latest Payslip Card** at top (use F.2 widget) with View Full Details + PDF buttons
   - **YTD KPI Strip** (use F.2 widget)
   - **Salary Trend Chart** (use F.2 widget) — taps drill into P2
   - **Payslip History List** — first 6 payslips. Each row: month/year, net, pay date, chevron. Tap → P2.
   - **'Show all N payslips'** row at bottom → opens P3
   - **Annual Salary Certificate card** at bottom → opens P4
4. Empty state: 'No payslips available yet'

**Commit:** `feat(payslips): P1 my payslips landing — SRD §2.1`

---

#### `[TODO]` P2 — Payslip Detail
- **SRD section:** §2.2
- **Wireframe:** §2.2.1
- **Component spec:** §2.2.2

**Steps:**
1. Read SRD §2.2 in full
2. **Enable screen-secure on this screen** (use F.1 utility)

4. 
   - AppBar: 'Payslip — [Month Year]' + PDF download icon
   - **Header Card:** company name, payslip title, employee details (name, ID, dept, designation), pay period, pay date, working/present days
   - **Earnings Section** (use F.2 widget) with total
   - **Deductions Section** (use F.2 widget) with total
   - **Net Pay Block** (use F.2 widget) with amount + amount in words
   - **Payment Info:** bank, masked account (use F.2 widget), reference number
   - **Year-to-Date Block:** YTD Gross / YTD Deductions / YTD Net
   - **PDF Download** button at bottom — uses watermark utility with employee's emp_id
5. **Disable screen-secure on dispose**
6. If payslip not yet released: 'This payslip is not yet available. It will be visible after pay date.'

**Commit:** `feat(payslips): P2 payslip detail — SRD §2.2`

---

#### `[TODO]` P3 — Full Payslip History
- **SRD section:** §2.3
- **Component spec:** §2.3.1

**Steps:**
1. Read SRD §2.3 in full
2. 
   - **Year filter dropdown** at top: 'All Years' (default) / individual years
   - **Yearly Summary Card** (when single year selected): Total Net Paid + Total Gross
   - **Payslip cards** sorted newest first (same design as P1 history)
   - **Pagination:** infinite scroll, 20 records per page
   - Empty state per year: 'No payslips for this period.'

**Commit:** `feat(payslips): P3 full payslip history — SRD §2.3`

---

#### `[TODO]` P4 — Annual Salary Certificate
- **SRD section:** §2.4
- **Component spec:** §2.4.1

**Steps:**
1. Read SRD §2.4 in full
2. **Enable screen-secure on this screen**
4. 
   - **Period Selector:** Year dropdown (default current year)
   - **Purpose Selector** (optional): Bank Loan / Visa / Embassy / General
   - **Generate** button — primary
   - On generate: mock API generates certificate with realistic data
   - **Preview Card** displayed inline after generation: employee name, designation, joining date, basic salary, allowances, total monthly compensation, period
   - **Download PDF** button (uses watermark utility)
   - **History list:** previously generated certificates with re-download
5. Mark TODO(backend): 'Annual Salary Certificate requires Odoo report template per SRD assumption #3'
6. **Disable screen-secure on dispose**

**Commit:** `feat(payslips): P4 annual salary certificate — SRD §2.4`

---

### Phase 2 — HR Manager Screens

#### `[TODO]` H1 — HR Payroll Landing
- **SRD section:** §3.1
- **Wireframe:** §3.1.1
- **Component spec:** §3.1.2

**Steps:**
1. Read SRD §3.1 in full
2. AsyncNotifier with period parameter, returns all employees' payslips
3. 
   - AppBar: 'Payroll' + dev role toggle
   - **View tabs at top:** 'My Payslips' (renders P1) / 'All Employees' (default for HR Manager)
   - **Period Selector:** dropdown of payroll periods (default most recent closed)
   - **KPI Strip:** Total Paid / Employees / Avg Net Pay
   - **Search bar:** employee name, ID, department
   - **Filter bar:** Department / Designation / Branch
   - **Employee Cards:** avatar, name, ID, designation+dept, net for selected period, PDF icon
   - Tap card → P2 (employee's payslip detail)
   - **Bulk Download Button** at bottom: 'Download All Payslips for [period]'
4. Bulk download: mock the operation with progress indicator. Add TODO(backend) re: foreground vs background per §7.8.
5. **Enable screen-secure on this screen** (HR sees lots of sensitive data)

**Commit:** `feat(payslips): H1 hr payroll landing — SRD §3.1`

---

#### `[TODO]` D1 — Payroll Dashboard
- **SRD section:** §4
- **Wireframe:** §4.1
- **Component spec:** §4.2

**Steps:**
1. Read SRD §4 in full
3. 
   - **Period Selector** (This Month / This Quarter / This Year default / Last Year / Custom)
   - **KPI cards:** Total Paid / Headcount (start→end) / Avg Net Pay
   - **Payroll Trend** (use F.2 widget — line chart 12 months)
   - **Payroll by Department** (horizontal bar chart) — tap to drill down
   - **Compensation Components Donut** (use F.2 widget) — Basic / Housing / Transport / Other / OT+Bonus
   - **Top Deductions** ranked list with totals + affected employee count
   - **PDF export** button — dashboard snapshot with HR Manager's emp_id watermark

**Commit:** `feat(payslips): D1 payroll dashboard — SRD §4`

---

### Phase 3 — Polish & Verification

#### `[TODO]` P5 — Sensitive data verification
- Verify FLAG_SECURE works on Android: try to take screenshot on P2, P4, H1 — should be blocked
- Verify iOS background blur on payslip screens
- Verify account number is masked on every display
- Verify cache clears on logout
- Verify PDF watermark on every export

#### `[TODO]` P6 — Component reuse audit
- All status badges use centralized maps
- No hardcoded colors/strings
- All shared widgets imported via package import

#### `[TODO]` P7 — Module 4 sign-off
- `flutter analyze` clean
- All widget tests pass
- Screenshots of every screen
- Decisions log §10 updated

---

## 10. Decisions Log

```
[YYYY-MM-DD] TASK_ID — Decision: <what>. Rationale: <why>.
```

(Initially empty)

---

## 11. Open Items / Questions for Architect

Note: SRD §7.1 lists 6 assumptions awaiting confirmation:
- Line Managers / PMs do NOT see team payslips — implemented
- No re-auth before opening payslips — implemented (relies on existing app session)
- Annual Salary Certificate requires Odoo report template — TODO(backend) marked
- Bulk PDF download UX pattern — TODO(backend) marked
- FLAG_SECURE recommended (configurable) — implemented as enabled by default
- Tap-to-reveal blur on amounts — NOT implemented in Phase 1

If architect adjusts any, track here.

---

## 12. Definition of Module Complete

- [ ] All tasks marked `[DONE]`
- [ ] `flutter analyze` passes
- [ ] No duplicate widgets
- [ ] Screen-secure enabled on P2, P4, H1
- [ ] Account number masking works everywhere
- [ ] PDF export with watermark works on P2, P4, H1, D1
- [ ] Bulk download mocked with TODO(backend)
- [ ] Dev role toggle visible and functional
- [ ] All TODO(release), TODO(backend) comments in place
- [ ] Screenshots captured (verifying FLAG_SECURE actually blocks them)
- [ ] Decisions log §10 updated

— End of Module 4 Task File —
