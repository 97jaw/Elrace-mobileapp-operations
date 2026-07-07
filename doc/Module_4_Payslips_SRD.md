**HR MANAGEMENT MOBILE APPLICATION**

**Module 4: Payslips**

*Software Requirements Specification*

  ----------------------- ----------------------- -----------------------
                                                  

  ----------------------- ----------------------- -----------------------

  -----------------------------------------------------------------------
  **Field**               **Detail**
  ----------------------- -----------------------------------------------
  Project                 HR Management Mobile Application

  Module                  Module 4 --- Payslips

  Backend                 Odoo 14 ERP (HR module)

  Frontend                Flutter (existing app, widget integration)

  Document Type           Software Requirements Specification (SRD)

  Version                 1.0

  Prepared By             Pandora Tech LLC

  Audience                Mobile Development Team

  Phase                   Phase 1 --- Layout & Design Requirements

  Approach                Option C --- Best-judgment defaults with
                          flagged assumptions
  -----------------------------------------------------------------------

**1. Document Overview**

**1.1 Purpose**

This document defines the design and layout requirements for the
Payslips module within the Pandora HR Management mobile application. The
module gives employees secure access to their salary slips and year-end
documents, with optional analytical visibility for managers and HR
Managers.

**1.2 Scope**

  -----------------------------------------------------------------------
  **Aspect**              **Phase 1 Position**
  ----------------------- -----------------------------------------------
  **In Scope**            Employee payslip listing and detail, full
                          earnings/deductions/net breakdown, YTD totals,
                          salary trend chart, PDF download with
                          watermark, Annual Salary Certificate.

  **Out of Scope**        Payroll editing, payslip generation/computation
                          (remains in Odoo). End-of-Service calculation.
                          Loan-specific payment schedules (referenced
                          from payslips but managed in Loans module).

  **PDF Export**          Yes --- Per-payslip PDF and Salary Certificate
                          PDF, both with emp_id watermark.

  **Sensitivity**         Payslips are personally sensitive. Section 6
                          details additional protective patterns. No
                          re-authentication PIN in Phase 1 (relies on
                          existing app auth) --- flagged as assumption.

  **Theme / Auth /        Inherits from foundation: light theme, online
  Notifications /         only, English only.
  Connectivity /          
  Language**              
  -----------------------------------------------------------------------

**1.3 Roles & View Selection**

  -----------------------------------------------------------------------
  **Role Flag**      **View Rendered**     **Visibility Scope**
  ------------------ --------------------- ------------------------------
  Any user           Employee View         Own payslips only --- every
                                           user sees their own payroll,
                                           regardless of management flag.

  is_hr_manager      HR Manager View       All employees\' payslips,
                     (additional)          payroll-period analytics, mass
                                           PDF export. Accessed via a
                                           separate tab or sub-section.

  is_management /    No team payslip       Managers and Project Managers
  is_pm              access                see their own payslips only.
                                           Team payslip access is HR
                                           Manager exclusive.
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Line Managers and Project Managers do NOT see their team members\'    |
| payslips. Salary information is HR-Manager-confidential by default.   |
| If your policy permits department managers to view their team\'s      |
| payroll (rare but possible), confirm and we\'ll add a Team Payslips   |
| tab to their view.                                                    |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| No additional re-authentication or biometric prompt before opening    |
| payslips in Phase 1. The module relies on the existing app session.   |
| If you want a PIN/biometric gate before payslip access (common in HR  |
| apps to prevent shoulder-surfing), confirm and we\'ll add the prompt  |
| to Screen P1.                                                         |
+-----------------------------------------------------------------------+

**2. Employee View**

**2.1 Screen P1 --- Payslips Landing**

Entry point for the employee. Shows the most recent payslip prominently
with quick access to history, year-to-date totals, and salary trend.

**2.1.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← My Payslips ⋮ │                                                   |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ LATEST PAYSLIP │ │                                                |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ April 2026 │ │                                                    |
|                                                                       |
| │ │ Period: 01 Apr → 30 Apr 2026 │ │                                  |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ Net Pay │ │                                                       |
|                                                                       |
| │ │ ╔══════════════════╗ │ │                                          |
|                                                                       |
| │ │ ║ AED 18,750.00 ║ │ │                                             |
|                                                                       |
| │ │ ╚══════════════════╝ │ │                                          |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ Paid on 30 Apr 2026 │ │                                           |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ \[ View Full Details \] \[ ⤓ PDF \] │ │                           |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ YTD Earnings │ │ YTD Deduct. │ │ YTD Net │ │                      |
|                                                                       |
| │ │ AED 80,000 │ │ AED 5,000 │ │ AED 75,000 │ │                       |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ SALARY TREND │                                                      |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Net Pay (AED, last 12 months) │ │                                 |
|                                                                       |
| │ │ ┃ │ │                                                             |
|                                                                       |
| │ │ 20k ┃ ●─●─●─●─●─●─●─●─●─●─●─● │ │                                 |
|                                                                       |
| │ │ 15k ┃ │ │                                                         |
|                                                                       |
| │ │ 10k ┃ │ │                                                         |
|                                                                       |
| │ │ 5k ┃ │ │                                                          |
|                                                                       |
| │ │ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━ │ │                                  |
|                                                                       |
| │ │ May Jun Jul Aug Sep Oct Nov Dec \... │ │                          |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ PAYSLIP HISTORY │                                                   |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ March 2026 Net: AED 18,500 │ │                                    |
|                                                                       |
| │ │ Paid 31 Mar 2026 › │ │                                            |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ February 2026 Net: AED 18,500 │ │                                 |
|                                                                       |
| │ │ Paid 28 Feb 2026 › │ │                                            |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ January 2026 Net: AED 18,500 │ │                                  |
|                                                                       |
| │ │ Paid 31 Jan 2026 › │ │                                            |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ Show all 24 payslips \] │                                        |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 📜 Annual Salary Certificate │ │                                  |
|                                                                       |
| │ │ Issue and download │ │                                            |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**2.1.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Latest Payslip Prominent card at top showing: payroll period (month +
  Card**           year), period dates, net pay in large display, payment
                   date, and two actions: View Full Details (opens P2)
                   and PDF download (with emp_id watermark).

  **YTD KPI        Three counters: YTD Earnings (sum of gross from Jan 1
  Strip**          to current), YTD Deductions (sum of deductions), YTD
                   Net (sum of net pay). Currency: AED.

  **Salary Trend   Line chart of net pay across the last 12 months.
  Chart**          X-axis: month/year. Y-axis: AED. Data points tappable
                   to open the corresponding payslip.

  **Payslip        Cards for the last 6 payslips by default. Each card
  History List**   shows: month/year, net pay, payment date, chevron. Tap
                   opens P2.

  **Show All**     Tappable row at the bottom of the history list. Opens
                   P3 (Full Payslip History).

  **Annual Salary  Tappable card at the bottom. Opens P4 (Salary
  Certificate**    Certificate). Visible all year --- backend determines
                   if a certificate is available.
  -----------------------------------------------------------------------

**2.2 Screen P2 --- Payslip Detail**

Single payslip view with full earnings, deductions, and net breakdown.
Read-only. PDF export available with emp_id watermark.

**2.2.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Payslip --- April 2026 ⤓ │                                        |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Pandora Tech LLC │ │                                              |
|                                                                       |
| │ │ Payslip --- April 2026 │ │                                        |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ Employee: M Jawad │ │                                             |
|                                                                       |
| │ │ Emp ID: EMP-4471 │ │                                              |
|                                                                       |
| │ │ Department: Engineering │ │                                       |
|                                                                       |
| │ │ Designation: Software Architect │ │                               |
|                                                                       |
| │ │ Pay Period: 01 Apr → 30 Apr 2026 │ │                              |
|                                                                       |
| │ │ Pay Date: 30 Apr 2026 │ │                                         |
|                                                                       |
| │ │ Working Days: 22 │ │                                              |
|                                                                       |
| │ │ Days Present: 22 │ │                                              |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ EARNINGS │                                                          |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Basic Salary AED 12,000.00 │                                        |
|                                                                       |
| │ Housing Allowance AED 4,000.00 │                                    |
|                                                                       |
| │ Transport Allowance AED 1,500.00 │                                  |
|                                                                       |
| │ Mobile Allowance AED 300.00 │                                       |
|                                                                       |
| │ Other Allowance AED 200.00 │                                        |
|                                                                       |
| │ Overtime AED 750.00 │                                               |
|                                                                       |
| │ Bonus AED 500.00 │                                                  |
|                                                                       |
| │ ───────────────────────────────────────────── │                     |
|                                                                       |
| │ Gross Earnings AED 19,250.00 │                                      |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ DEDUCTIONS │                                                        |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Loan Repayment AED 400.00 │                                         |
|                                                                       |
| │ Salary Advance AED 100.00 │                                         |
|                                                                       |
| │ Insurance AED 0.00 │                                                |
|                                                                       |
| │ ───────────────────────────────────────────── │                     |
|                                                                       |
| │ Total Deductions AED 500.00 │                                       |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ╔════════════════════════════════════════════════╗ │                |
|                                                                       |
| │ ║ ║ │                                                               |
|                                                                       |
| │ ║ NET PAY AED 18,750.00 ║ │                                         |
|                                                                       |
| │ ║ ║ │                                                               |
|                                                                       |
| │ ║ Eighteen Thousand Seven Hundred Fifty Dirhams ║ │                 |
|                                                                       |
| │ ╚════════════════════════════════════════════════╝ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ PAYMENT INFO │                                                      |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Bank: Emirates NBD │                                                |
|                                                                       |
| │ Account: \*\*\*\* \*\*\*\* \*\*\*\* 6411 │                          |
|                                                                       |
| │ Reference: PAY/2026/04/4471 │                                       |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ YEAR-TO-DATE │                                                      |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ YTD Gross: AED 80,000.00 │                                          |
|                                                                       |
| │ YTD Deductions: AED 5,000.00 │                                      |
|                                                                       |
| │ YTD Net: AED 75,000.00 │                                            |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ ⤓ Download PDF \] │                                              |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**2.2.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Header Card**  Company name, payslip month/year title, employee
                   details (name, ID, department, designation), pay
                   period, pay date, working/present days. Visually
                   styled to match the printed payslip format.

  **Earnings       List of earning lines as label/amount rows. Lines
  Section**        visible only if non-zero (or always visible for fixed
                   components --- backend-driven). Total row is bold and
                   visually separated.

  **Deductions     Same pattern as Earnings.
  Section**        

  **Net Pay        Highly prominent boxed display with the net pay amount
  Block**          and amount in words. Primary color border and slightly
                   larger font.

  **Payment Info** Bank name, masked account number (last 4 digits
                   visible), payslip reference number.

  **Year-to-Date   Three rows: YTD Gross, YTD Deductions, YTD Net.
  Block**          

  **PDF Download** Header icon + bottom button. Both download the same
                   PDF with emp_id watermark.

  **Loading        Skeleton placeholders for all sections during fetch.
  State**          

  **Error State**  Inline error with retry. If payslip is not yet
                   released: \'This payslip is not yet available. It will
                   be visible after pay date.\'
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **Display of Sensitive Numbers**                                      |
|                                                                       |
| Bank account numbers are masked (last 4 digits only). Full account    |
| number is never displayed in the mobile app or in the API response.   |
| Backend must return only masked values to the mobile client.          |
+-----------------------------------------------------------------------+

**2.3 Screen P3 --- Full Payslip History**

Lists all payslips available to the user, with year filter and search.

**2.3.1 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Year Filter**  Dropdown at the top: \'All Years\' (default), then
                   individual years. List re-fetches on change.

  **Yearly Summary Above the list when a single year is selected: \'Total
  Card**           Net Paid 2025: AED 220,000\', \'Total Gross 2025: AED
                   235,000\'.

  **Payslip Card** Same design as P1 history cards. Sorted newest first.

  **Pagination**   Infinite scroll, 20 records per page.

  **Empty State**  If no payslips: \'No payslips for this period.\'
  -----------------------------------------------------------------------

**2.4 Screen P4 --- Annual Salary Certificate**

View and download an official salary certificate covering a chosen
period.

**2.4.1 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Period         Year dropdown --- defaults to current year. Optional
  Selector**       purpose dropdown (Bank Loan / Visa / Embassy /
                   General).

  **Generate       Primary button. Backend generates the PDF certificate
  Action**         on demand.

  **Preview Card** After generation, the certificate is displayed inline
                   with download action. Includes employee name,
                   designation, joining date, basic salary, allowances
                   breakdown, total monthly compensation, period covered.

  **Download PDF** Includes emp_id watermark.

  **History**      List of previously generated certificates with
                   re-download option.
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| The Annual Salary Certificate is generated on-demand by an Odoo       |
| report template. If your Odoo backend does not currently have a       |
| salary certificate template, this becomes a backend deliverable for   |
| Phase 1.                                                              |
+-----------------------------------------------------------------------+

**3. HR Manager View**

HR Managers see all employee payslips with payroll-period analytics.
This view is in addition to their own personal payslip access (which
uses the same Employee screens as everyone else).

**3.1 Screen H1 --- HR Payroll Landing**

**3.1.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Payroll ⋮ │                                                       |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────┐ ┌──────────────────────┐ │                 |
|                                                                       |
| │ │ 👤 My Payslips │ │ 👥 All Employees │ │                           |
|                                                                       |
| │ └──────────────────────┘ └──────────────────────┘ │                 |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ PAYROLL PERIOD: April 2026 ▼ │                                      |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ Total Paid │ │ Employees │ │ Avg Net Pay │ │                      |
|                                                                       |
| │ │ AED 4.2M │ │ 128 │ │ AED 32,800 │ │                               |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 🔍 Search by employee name, ID, or department │ │                 |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ All \] \[ By Department ▼ \] \[ By Designation ▼ \] │            |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 M Jawad EMP-4471 │ │                                           |
|                                                                       |
| │ │ Software Architect · Engineering │ │                              |
|                                                                       |
| │ │ Net: AED 18,750 › ⤓ │ │                                           |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Ahmed Al-Rashid EMP-3201 │ │                                   |
|                                                                       |
| │ │ Sales Manager · Sales │ │                                         |
|                                                                       |
| │ │ Net: AED 24,500 › ⤓ │ │                                           |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \... │                                                              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ ⤓ Download All Payslips for April 2026 \] │                      |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**3.1.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **View Tabs**    Two large buttons: \'My Payslips\' (renders Employee
                   P1) and \'All Employees\' (renders this HR view).

  **Period         Dropdown of payroll periods (months). Default: most
  Selector**       recent closed period. Affects all KPIs and the list.

  **KPI Strip**    Total Paid (sum of net pay across all employees in
                   period), Employees (count of employees with payslips
                   in period), Avg Net Pay (mean).

  **Search Bar**   Search by employee name, employee ID, or department.

  **Filter Bar**   Dropdowns: by Department, by Designation, by Branch /
                   Location.

  **Employee       Avatar, name, employee ID, designation + department,
  Card**           net pay for selected period, chevron to open detail,
                   PDF download icon.

  **Tap Behavior** Tapping the card opens P2 (Payslip Detail) for that
                   employee.

  **Bulk           Bottom button: \'Download All Payslips for
  Download**       \[period\]\'. Triggers backend bulk PDF generation.
                   The HR Manager receives a notification when ready.
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Bulk PDF download for an entire payroll period is a backend bulk      |
| operation that may take seconds to minutes depending on company size. |
| The mobile app initiates the request and either waits with a progress |
| indicator or backgrounds the operation. Confirm the backend\'s        |
| preferred pattern.                                                    |
+-----------------------------------------------------------------------+

**4. HR Manager Payroll Dashboard**

Optional analytical view available to HR Managers via the overflow menu
on H1. Surfaces payroll-period analytics and trends.

**4.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Payroll Dashboard This Year ▼ ⤓ │                                 |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ Total Paid │ │ Headcount │ │ Avg Net │ │                          |
|                                                                       |
| │ │ AED 50.4M │ │ 128 → 134 │ │ AED 32,800 │ │                        |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ PAYROLL TREND (12 months) │                                         |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ AED M │ │                                                         |
|                                                                       |
| │ │ 5┃ ●─●─●─●─●─●─●─●─●─●─●─● │ │                                    |
|                                                                       |
| │ │ 4┃ │ │                                                            |
|                                                                       |
| │ │ 3┃ │ │                                                            |
|                                                                       |
| │ │ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━ │ │                                  |
|                                                                       |
| │ │ May Jun Jul Aug Sep Oct Nov Dec \... │ │                          |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ PAYROLL BY DEPARTMENT │                                             |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Sales ▆▆▆▆▆▆▆▆▆▆▆▆ AED 1.4M │                                       |
|                                                                       |
| │ Marketing ▆▆▆▆▆▆▆ AED 0.7M │                                        |
|                                                                       |
| │ Engineering ▆▆▆▆▆▆▆▆▆▆ AED 1.1M │                                   |
|                                                                       |
| │ Operations ▆▆▆▆▆▆▆▆ AED 0.9M │                                      |
|                                                                       |
| │ F&B ▆▆▆▆▆▆▆▆▆▆▆ AED 1.3M │                                          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ COMPENSATION COMPONENTS (Apr 2026) │                                |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ ╭─────╮ │ │                                                       |
|                                                                       |
| │ │ ╱ ╲ ■ Basic Salary 62% │ │                                        |
|                                                                       |
| │ │ │ ◯◯ │ ■ Housing 18% │ │                                          |
|                                                                       |
| │ │ │ ◯◯◯ │ ■ Transport 7% │ │                                        |
|                                                                       |
| │ │ ╲ ╱ ■ Other 8% │ │                                                |
|                                                                       |
| │ │ ╰─────╯ ■ Overtime/Bonus 5% │ │                                   |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ TOP DEDUCTIONS │                                                    |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ 1. Loan Repayments AED 28,000 (38 employees) │                      |
|                                                                       |
| │ 2. Salary Advances AED 8,500 (12 employees) │                       |
|                                                                       |
| │ 3. Insurance AED 4,200 (128 employees) │                            |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**4.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**      **Specification**
  ------------------ ----------------------------------------------------
  **Period           This Month, This Quarter, This Year (default), Last
  Selector**         Year, Custom Range.

  **KPI Cards**      Total Paid (sum of net across period), Headcount
                     (start → end), Avg Net Pay.

  **Payroll Trend**  Line chart of total monthly net pay across the
                     period.

  **Payroll by       Horizontal bar chart, one row per department. Tap
  Department**       row to drill down.

  **Compensation     Donut chart breaking down total payroll into Basic,
  Components**       Housing, Transport, Other, OT/Bonus.

  **Top Deductions** Ranked list of deduction categories with total and
                     number of affected employees.

  **Export PDF**     Dashboard PDF snapshot with HR Manager\'s emp_id
                     watermark.
  -----------------------------------------------------------------------

**5. Screen Inventory & Navigation**

**5.1 Screen Inventory**

  -------------------------------------------------------------------------
  **Screen    **Screen Name**            **Audience**   **Notes**
  ID**                                                  
  ----------- -------------------------- -------------- -------------------
  **P1**      My Payslips Landing        All Users      Primary entry

  **P2**      Payslip Detail             All Users      Read-only with PDF

  **P3**      Full Payslip History       All Users      Year filter, all
                                                        records

  **P4**      Annual Salary Certificate  All Users      Generate + download

  **H1**      HR Payroll Landing         HR Manager     All employees

  **D1**      Payroll Dashboard          HR Manager     Analytics
  -------------------------------------------------------------------------

**5.2 Navigation Flow**

+-----------------------------------------------------------------------+
| \[ Main App Home \]                                                   |
|                                                                       |
| │                                                                     |
|                                                                       |
| Tap \'Payslips\' widget                                               |
|                                                                       |
| │                                                                     |
|                                                                       |
| ┌───────┴────────┐                                                    |
|                                                                       |
| │ Role detection │                                                    |
|                                                                       |
| └───┬────────┬───┘                                                    |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| Any user HR Manager                                                   |
|                                                                       |
| ▼ ▼                                                                   |
|                                                                       |
| ┌──────┐ ┌──────────────┐                                             |
|                                                                       |
| │ P1 │ │ Tab Switcher │                                               |
|                                                                       |
| └──┬───┘ └─┬─────────┬──┘                                             |
|                                                                       |
| │ │ │                                                                 |
|                                                                       |
| ┌─────┼─────┐ ▼ ▼                                                     |
|                                                                       |
| ▼ ▼ ▼ P1 H1                                                           |
|                                                                       |
| \[P2\] \[P3\] \[P4\] (Own) │                                          |
|                                                                       |
| │ ├─► \[D1 Dashboard\]                                                |
|                                                                       |
| ▼ │                                                                   |
|                                                                       |
| (PDF) └─► Tap row ─► P2                                               |
+-----------------------------------------------------------------------+

**5.3 Backend API Touchpoints**

  ------------------------------------------------------------------------
  **Capability**     **Used By**                          **Status**
  ------------------ ------------------------------------ ----------------
  **Get my payslips  P1, P3                               To define
  list**                                                  

  **Get payslip      P2                                   To define
  detail**                                                

  **Get YTD totals** P1                                   To define

  **Get salary trend P1                                   To define
  (12 months)**                                           

  **Generate salary  P4                                   To define (Odoo
  certificate**                                           report template)

  **Download payslip P1, P2                               To define
  PDF with                                                
  watermark**                                             

  **Get all          H1                                   To define
  employees\'                                             
  payslips for                                            
  period (HR)**                                           

  **Bulk download    H1                                   To define
  payslips for                                            
  period**                                                

  **Get payroll      D1                                   To define
  dashboard data**                                        
  ------------------------------------------------------------------------

**6. Sensitive-Data Handling Patterns**

Payroll data is highly sensitive. Phase 1 establishes the following
patterns to protect it on mobile, even though the underlying
authentication is delegated to the existing app.

  -----------------------------------------------------------------------
  **Pattern**        **Specification**
  ------------------ ----------------------------------------------------
  **Account Number   Bank account numbers display only last 4 digits
  Masking**          (e.g., \'\*\*\*\* \*\*\*\* \*\*\*\* 6411\'). Backend
                     never returns the full account number to the mobile
                     client.

  **Screenshot       On Android, set FLAG_SECURE on payslip screens (P2,
  Behavior**         P4) to prevent screenshots in app switcher and
                     screen recordings. iOS equivalent: secure text entry
                     in screen recording detection. Implementation note
                     for the mobile team.

  **PDF Watermark**  Every downloaded payslip and salary certificate
                     carries the emp_id watermark of the user generating
                     the export. Discourages unauthorized sharing.

  **Cache            Payslip data must not persist in local cache beyond
  Invalidation**     the active session. On logout, clear all payslip
                     cache.

  **Recent Tab in    On iOS, mask the screen with a blank or branded
  App Switcher**     splash when the app moves to background while a
                     payslip is open.

  **Tap-to-Reveal    Optional UX: blur amounts in the payslip list (P1)
  (Optional)**       until the user taps to reveal. Useful in shared
                     screen contexts. Phase 1 does not mandate this ---
                     flagged for confirmation.
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| FLAG_SECURE / screen recording prevention is recommended but adds     |
| friction (legitimate uses of screenshot also blocked). Confirm        |
| whether the company prefers this protection enabled by default or     |
| only on explicit setting toggle.                                      |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Optional \'tap-to-reveal\' blur on amounts in P1 is not implemented   |
| in Phase 1 by default. If you want this, confirm and we\'ll add it as |
| a setting.                                                            |
+-----------------------------------------------------------------------+

**7. Sign-off & Open Items**

**7.1 Assumptions Recap**

  ---------------------------------------------------------------------------
  **\#**   **Assumption**                                        **Status**
  -------- ----------------------------------------------------- ------------
  **1**    Line Managers and Project Managers do NOT see team    Pending
           payslips. Only HR Manager has team payslip access.    

  **2**    No additional re-authentication / PIN before opening  Pending
           payslips. Relies on existing app session.             

  **3**    Annual Salary Certificate is generated on-demand by   Pending
           an Odoo report template (must exist or be created in  
           backoffice).                                          

  **4**    Bulk PDF download for entire payroll period is a      Pending
           backend bulk operation; UX pattern (foreground wait   
           vs background notification) to be confirmed.          

  **5**    FLAG_SECURE / screen recording prevention is          Pending
           recommended but its activation is configurable.       

  **6**    Tap-to-reveal blur on amounts is not implemented by   Pending
           default in Phase 1.                                   
  ---------------------------------------------------------------------------

**7.2 Open Items Owned by Backend**

- Payslip data structure: list of earning lines and deduction lines with
  their order and visibility rules

- Whether earning/deduction lines are dynamic per employee or templated
  per company

- Salary certificate PDF template (must exist in Odoo)

- Payslip PDF template (existing in Odoo, plus watermark overlay)

- Bulk PDF generation operation (pattern: synchronous response or job +
  notification)

- Period definitions and edge cases (bonuses, gratuity, EOSB)

- Loan installment schedule reference from payslip

- Currency rounding rules and \'amount in words\' generation logic

*--- End of Module 4 ---*
