**HR MANAGEMENT MOBILE APPLICATION**

**Module 5: Staff Attendance Reports**

*Software Requirements Specification*

  ----------------------- ----------------------- -----------------------
                                                  

  ----------------------- ----------------------- -----------------------

  -----------------------------------------------------------------------
  **Field**               **Detail**
  ----------------------- -----------------------------------------------
  Project                 HR Management Mobile Application

  Module                  Module 5 --- Staff Attendance Reports

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

This document defines the design and layout requirements for the Staff
Attendance Reports module within the Pandora HR Management mobile
application. The module gives employees, managers, and HR Managers
visibility into attendance records sourced from Odoo (hr.attendance) ---
including check-in/out times, total worked hours, late arrivals, early
leaves, absences, and overtime.

**1.2 Scope**

  -----------------------------------------------------------------------
  **Aspect**              **Phase 1 Position**
  ----------------------- -----------------------------------------------
  **In Scope**            Read-only attendance reports --- daily, monthly
                          calendar, period summaries. Employee, Manager,
                          and HR Manager views. KPIs (attendance %, late
                          count, OT hours), charts, PDF export with
                          watermark.

  **Out of Scope**        Mobile check-in / check-out (punching from
                          app). Geofencing. Biometric integration on
                          mobile. Attendance correction requests (assumed
                          routed through HR Requests module instead).

  **Source**              Odoo hr.attendance (populated by biometric
                          devices, manual entries, or other integrations
                          on the Odoo side).

  **PDF Export**          Yes --- Period reports as PDF with emp_id
                          watermark.

  **Theme / Auth /        Inherits from foundation: light theme, online
  Notifications /         only, English only.
  Connectivity /          
  Language**              
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Mobile check-in/out from the app is OUT of scope for Phase 1 ---      |
| module is read-only reporting. If you want employees to punch in/out  |
| from mobile (with or without geofencing), confirm and we\'ll add that |
| as a separate sub-module.                                             |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Attendance corrections (e.g., \'I forgot to check out, please         |
| correct\') are routed through the existing HR Requests submission     |
| flow as a new request type, not handled in this module. If a          |
| dedicated correction flow is needed within attendance, flag it for    |
| Phase 2.                                                              |
+-----------------------------------------------------------------------+

**1.3 Roles & View Selection**

  -----------------------------------------------------------------------
  **Role Flag**      **View Rendered**     **Visibility Scope**
  ------------------ --------------------- ------------------------------
  None of the        Employee View         Own attendance records only.
  manager flags                            

  is_management /    Manager View          Team attendance --- direct
  is_pm                                    reports / project team. Plus
                                           own attendance (via tab).

  is_hr_manager      HR Manager View       All employees company-wide.
                                           Department and location
                                           filters. Aggregate analytics.
  -----------------------------------------------------------------------

**2. Employee View**

**2.1 Screen E1 --- My Attendance Landing**

Default landing for the employee. Shows today\'s status, current month
KPIs, and the calendar view.

**2.1.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← My Attendance ⋮ │                                                 |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ TODAY · Saturday, 09 May 2026 │ │                                 |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ Status: ✓ Present │ │                                             |
|                                                                       |
| │ │ Check-in: 08:54 AM │ │                                            |
|                                                                       |
| │ │ Check-out: --- (Not yet) │ │                                      |
|                                                                       |
| │ │ Worked Today: 3h 42m (so far) │ │                                 |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ THIS MONTH (May 2026) │                                             |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ Attendance │ │ Late │ │ Total OT │ │                              |
|                                                                       |
| │ │ 96% │ │ 2 days │ │ 4h 30m │ │                                     |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ Worked Hours │ │ Required Hrs │ │ Absent Days │ │                 |
|                                                                       |
| │ │ 178h 30m │ │ 184h │ │ 1 day │ │                                   |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌─────────────────────────────────────────────────┐ │               |
|                                                                       |
| │ │ Calendar │ List │ Summary │ │                                     |
|                                                                       |
| │ └─────────────────────────────────────────────────┘ │               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ◄ May 2026 ► │                                                      |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Sun Mon Tue Wed Thu Fri Sat │                                       |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ● ● ● ● ☆ □ │                                                       |
|                                                                       |
| │ 1 2 3 4 5 6 7 │                                                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ● ● ⚠ ● ● ☆ □ │                                                     |
|                                                                       |
| │ 8 9 10 11 12 13 14 │                                                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ● ● ● ● ✗ ☆ □ │                                                     |
|                                                                       |
| │ 15 16 17 18 19 20 21 │                                              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ● ● ● │                                                             |
|                                                                       |
| │ 22 23 24 │                                                          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Legend: ● Present ⚠ Late ✗ Absent ☆ Leave □ Off │                   |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ ⤓ Export Monthly Report \] │                                     |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**2.1.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Today Card**   Date, day name, current status (Present / Absent / On
                   Leave / Off Day), check-in time, check-out time (---
                   if not yet), live worked-time counter (computed by
                   mobile from check-in if not yet checked out).

  **Monthly KPI    Two rows of three counters: Attendance % (worked days
  Strip**          ÷ working days × 100), Late count, Total OT, Worked
                   Hours, Required Hours, Absent Days. All for the
                   current calendar month by default.

  **Sub-tabs**     Calendar (default), List, Summary.

  **Calendar       Standard month grid with month navigator at the top.
  View**           Each day cell shows a status icon + day number. Tap a
                   day to open the Daily Detail bottom sheet (E2).

  **Day Cell       Color-coded glyphs: Present (●, success green), Late
  Status Icons**   (⚠, warning amber), Absent (✗, danger red), On Leave
                   (☆, primary blue), Off Day / Weekend / Holiday (□,
                   muted gray). Future days within the current month
                   appear without an icon.

  **List View**    Daily rows in chronological order with: date, day
                   name, check-in, check-out, worked hours, status badge.

  **Summary View** Same stats as the KPI strip but expanded into rows
                   with totals and averages.

  **Export Monthly Bottom button. Generates a PDF for the displayed month
  Report**         with emp_id watermark.
  -----------------------------------------------------------------------

**2.2 Screen E2 --- Daily Attendance Detail**

Bottom sheet or full screen that opens when an employee taps a day in
the calendar. Shows complete punch information for that day.

**2.2.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ─── Drag handle ─── │                                               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Tuesday, 06 May 2026 │                                              |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ STATUS │                                                            |
|                                                                       |
| │ \[ ⚠ LATE ARRIVAL \] │                                              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ PUNCH RECORDS │                                                     |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ● Check-in 09:18 AM │                                               |
|                                                                       |
| │ ◐ Lunch out 01:00 PM │                                              |
|                                                                       |
| │ ◑ Lunch in 01:48 PM │                                               |
|                                                                       |
| │ ● Check-out 06:30 PM │                                              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ SUMMARY │                                                           |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Worked Hours 8h 24m │                                               |
|                                                                       |
| │ Break Time 48m │                                                    |
|                                                                       |
| │ Total Hours 9h 12m │                                                |
|                                                                       |
| │ Required Hours 8h 00m │                                             |
|                                                                       |
| │ Late By 18m │                                                       |
|                                                                       |
| │ Overtime 0h 24m │                                                   |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ NOTES │                                                             |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ No notes for this day │                                             |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**2.2.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Header**       Day, date, drag handle if presented as bottom sheet.

  **Status Badge** Single badge representing the day\'s overall status:
                   Present, Late Arrival, Early Departure, Late + Early,
                   Absent, On Leave, Off Day.

  **Punch          Vertical list of all punches recorded for the day, in
  Records**        chronological order. Icons indicate punch type
                   (check-in, check-out, lunch in/out, break in/out).

  **Summary**      Two-column field/value list of computed totals: Worked
                   Hours, Break Time, Total Hours, Required Hours, Late
                   By, Overtime.

  **Notes**        Display Odoo-side notes attached to the attendance
                   record (e.g., supervisor note explaining a late
                   arrival). Read-only in Phase 1.

  **Linked Leave / If the day\'s status is \'On Leave\' or \'Job
  Mission**        Mission\', show a card linking to the underlying HR
                   Request. Tap opens the Module 1 Request Detail screen.
  -----------------------------------------------------------------------

**3. Manager View**

**3.1 Screen M1 --- Team Attendance Landing**

**3.1.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Attendance ⋮ │                                                    |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌────────────────────┐ ┌────────────────────┐ │                     |
|                                                                       |
| │ │ 📊 Dashboard │ │ 📋 Team │ │                                      |
|                                                                       |
| │ └────────────────────┘ └────────────────────┘ │                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌─────────────────────────────────────────────────┐ │               |
|                                                                       |
| │ │ Today │ Team │ My Own │ │                                         |
|                                                                       |
| │ └─────────────────────────────────────────────────┘ │               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ TODAY · 09 May 2026 │                                               |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ Present │ │ Late │ │ Absent │ │                                   |
|                                                                       |
| │ │ 18 / 20 │ │ 3 │ │ 1 │ │                                           |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ │                                 |
|                                                                       |
| │ │ On Leave │ │ Not Checked │ │                                      |
|                                                                       |
| │ │ 1 │ │ Out: 14 │ │                                                 |
|                                                                       |
| │ └──────────────┘ └──────────────┘ │                                 |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ All \] \[ Late \] \[ Absent \] \[ On Leave \] │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Sarah Ahmed ✓ PRESENT │ │                                      |
|                                                                       |
| │ │ Check-in: 08:42 AM │ │                                            |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Omar Khalid ⚠ LATE │ │                                         |
|                                                                       |
| │ │ Check-in: 09:18 AM (18m late) │ │                                 |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Layla Mohammed ☆ ON LEAVE │ │                                  |
|                                                                       |
| │ │ Annual Leave (12 May → 16 May) │ │                                |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Yousef Ibrahim ✗ ABSENT │ │                                    |
|                                                                       |
| │ │ No check-in recorded │ │                                          |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**3.1.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **View           Toggle between Dashboard (Section 4) and Team list
  Switcher**       (default).

  **Tabs**         Three tabs: Today (default), Team (period-based view),
                   My Own (renders Employee E1).

  **Today Tab**    Real-time view of team attendance for the current day.
                   Auto-refreshes every 5 minutes or on pull-to-refresh.

  **Today KPI      Five counters: Present (count + total), Late, Absent,
  Strip**          On Leave, Not Checked Out (employees who checked in
                   but haven\'t checked out yet --- useful for end-of-day
                   visibility).

  **Status Filter  All, Late, Absent, On Leave. Filters the list below.
  Chips**          

  **Employee Card  Avatar, name, status badge, status-specific sub-text
  (Today)**        (e.g., check-in time, late by minutes, leave
                   type/dates, \'No check-in recorded\').

  **Tap Behavior** Tapping an employee card opens M2 (Employee Attendance
                   Detail).
  -----------------------------------------------------------------------

**3.2 Screen M2 --- Employee Attendance Detail (Manager)**

Manager-facing view of a single employee\'s attendance. Reuses the
Employee landing layout (Calendar / List / Summary tabs) prefixed with
an Employee Info card.

**3.2.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Attendance --- Sarah Ahmed ⤓ │                                    |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Sarah Ahmed │ │                                                |
|                                                                       |
| │ │ Software Engineer · Engineering │ │                               |
|                                                                       |
| │ │ Emp ID: EMP-3201 │ │                                              |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ THIS MONTH (May 2026) ▼ │                                           |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ Attendance │ │ Late │ │ Total OT │ │                              |
|                                                                       |
| │ │ 100% │ │ 1 day │ │ 6h 15m │ │                                     |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌─────────────────────────────────────────────────┐ │               |
|                                                                       |
| │ │ Calendar │ List │ Summary │ │                                     |
|                                                                       |
| │ └─────────────────────────────────────────────────┘ │               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ◄ May 2026 ► │                                                      |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ \... (Calendar grid as in E1) │                                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ ⤓ Export Report \] │                                             |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**3.2.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Employee Info  Avatar, name, position, department, employee ID. Same
  Card**           component used in Module 1 M3.

  **Period         Dropdown to switch between months / custom ranges.
  Selector**       

  **KPI Strip**    Same as E1.1.2.

  **Calendar /     Identical to E1 with the data scoped to this employee.
  List / Summary** 

  **Export         PDF export with the manager\'s emp_id as watermark.
  Report**         
  -----------------------------------------------------------------------

**3.3 Manager Team Period Tab**

The \'Team\' tab on M1 (alongside \'Today\' and \'My Own\') provides a
period-based aggregate view of the team.

**3.3.1 Layout**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Period         This Week, This Month (default), Last Month, This
  Selector**       Quarter, Custom Range.

  **Team KPIs**    Team Attendance % (avg across all members), Total Late
                   incidents (sum), Total OT (sum), Total Absences (sum).

  **Sort Options** Most attendance issues first (default), Alphabetical,
                   Most OT, Highest attendance %.

  **Employee Row** Per-employee summary row: avatar, name, attendance %,
                   late count, OT total, absence count. Tap opens M2.
  -----------------------------------------------------------------------

**4. Manager Attendance Dashboard**

Visual analytics view available to Manager and HR Manager. Accessed via
the Dashboard button on M1.

**4.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Attendance Dashboard This Month ▼ ⤓ │                             |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ Team Att % │ │ Total Late │ │ Total OT │ │                        |
|                                                                       |
| │ │ 94.2% │ │ 42 │ │ 186h │ │                                         |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ DAILY ATTENDANCE TREND │                                            |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ % ┃ │ │                                                           |
|                                                                       |
| │ │100┃ ●●●●●●●●●●●●●●●●●●●●●●●●●● │ │                                |
|                                                                       |
| │ │ 90┃ │ │                                                           |
|                                                                       |
| │ │ 80┃ │ │                                                           |
|                                                                       |
| │ │ ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━ │ │                                  |
|                                                                       |
| │ │ 01 05 09 13 17 21 25 29 │ │                                       |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ STATUS DISTRIBUTION │                                               |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ ╭─────╮ │ │                                                       |
|                                                                       |
| │ │ ╱ ╲ ■ Present 82% │ │                                             |
|                                                                       |
| │ │ │ ◯◯ │ ■ Leave 10% │ │                                            |
|                                                                       |
| │ │ │ ◯◯◯ │ ■ Late 5% │ │                                             |
|                                                                       |
| │ │ ╲ ╱ ■ Absent 3% │ │                                               |
|                                                                       |
| │ │ ╰─────╯ │ │                                                       |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ TOP PUNCTUAL EMPLOYEES │                                            |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ 1. Sarah Ahmed 100% 0 late › │                                      |
|                                                                       |
| │ 2. Layla Mohammed 100% 0 late › │                                   |
|                                                                       |
| │ 3. Fatima Hassan 98% 1 late › │                                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ATTENDANCE CONCERNS │                                               |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ 1. Omar Khalid 85% 8 late, 2 absent › │                             |
|                                                                       |
| │ 2. Yousef Ibrahim 88% 5 late, 1 absent › │                          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ DEPARTMENT COMPARISON (HR Manager only) │                           |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Sales ▆▆▆▆▆▆▆▆▆▆▆ 96% │                                             |
|                                                                       |
| │ Marketing ▆▆▆▆▆▆▆▆▆ 94% │                                           |
|                                                                       |
| │ Engineering ▆▆▆▆▆▆▆▆▆▆▆▆ 97% │                                      |
|                                                                       |
| │ Operations ▆▆▆▆▆▆▆▆ 92% │                                           |
|                                                                       |
| │ F&B ▆▆▆▆▆▆▆▆▆▆ 93% │                                                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**4.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**      **Specification**
  ------------------ ----------------------------------------------------
  **Period           This Week, This Month (default), Last Month, This
  Selector**         Quarter, This Year, Custom Range. All KPIs and
                     charts update on change.

  **KPI Cards**      Team Attendance % (mean), Total Late (sum of late
                     incidents in period), Total OT (sum of OT hours).

  **Daily Attendance Line chart of team attendance % per day across the
  Trend**            period. Helps spot dips (e.g., post-holiday drops,
                     system outages).

  **Status           Donut chart of employee-days by status: Present,
  Distribution**     Leave, Late, Absent. Shows at-a-glance composition.

  **Top Punctual     Top 3 by combined attendance % and zero/low late
  Employees**        incidents. Tap row to drill into M2.

  **Attendance       Employees with attendance below threshold (e.g., \<
  Concerns**         90%) or excessive late incidents. Tap row to drill
                     into M2.

  **Department       HR Manager only. Horizontal bar chart of attendance
  Comparison**       % by department. Tap a row to filter the team list
                     by that department.

  **Export PDF**     Snapshot of the entire dashboard with the user\'s
                     emp_id watermark.
  -----------------------------------------------------------------------

**5. HR Manager Additional Capabilities**

HR Managers extend the Manager view with company-wide visibility and
additional filters.

  -----------------------------------------------------------------------
  **Capability**     **Specification**
  ------------------ ----------------------------------------------------
  **Company-wide     On M1 \'Team\' tab, the list shows all employees
  View**             company-wide. Department, branch, and designation
                     filters are enabled in the filter sheet.

  **Branch /         HR Manager exclusive filter. Useful for multi-branch
  Location Filter**  companies (e.g., UAE branches vs Riyadh).

  **Aggregate Period Bulk PDF export covering all employees for a chosen
  Report**           period. Backend generates as a single PDF or zip of
                     individual reports. Watermark uses HR Manager\'s
                     emp_id.

  **Department       Department comparison chart on the dashboard is
  Drill-Down**       interactive --- tap to filter the team list.
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Aggregate period report (bulk PDF for all employees) is a             |
| backend-generated bulk operation. If the operation takes long, the    |
| mobile UX should background the job and notify when ready (consistent |
| with Module 4 bulk payslip download). Confirm preferred pattern.      |
+-----------------------------------------------------------------------+

**6. Screen Inventory & Navigation**

**6.1 Screen Inventory**

  -------------------------------------------------------------------------
  **Screen    **Screen Name**            **Audience**   **Notes**
  ID**                                                  
  ----------- -------------------------- -------------- -------------------
  **E1**      My Attendance Landing      All Users      Calendar / List /
                                                        Summary tabs

  **E2**      Daily Attendance Detail    All Users      Bottom sheet or
                                                        full screen

  **M1**      Team Attendance Landing    Manager, HR    Today / Team / My
                                         Manager        Own tabs

  **M2**      Employee Attendance Detail Manager, HR    Per-employee
              (Manager)                  Manager        detailed view

  **D1**      Attendance Dashboard       Manager, HR    Charts and
                                         Manager        analytics
  -------------------------------------------------------------------------

**6.2 Navigation Flow**

+-----------------------------------------------------------------------+
| \[ Main App Home \]                                                   |
|                                                                       |
| │                                                                     |
|                                                                       |
| Tap \'Attendance\' widget                                             |
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
| Employee Manager / HR Manager                                         |
|                                                                       |
| ▼ ▼                                                                   |
|                                                                       |
| ┌──────┐ ┌──────┐                                                     |
|                                                                       |
| │ E1 │ │ M1 │ ── Tab: My Own ─► E1                                    |
|                                                                       |
| └──┬───┘ └──┬───┘                                                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| Tap day ├─► \[D1 Dashboard\]                                          |
|                                                                       |
| ▼ │                                                                   |
|                                                                       |
| ┌──────┐ ├─► Tap employee ─► \[M2\]                                   |
|                                                                       |
| │ E2 │ │ │                                                            |
|                                                                       |
| └──────┘ │ Tap day                                                    |
|                                                                       |
| │ ▼                                                                   |
|                                                                       |
| │ \[E2\]                                                              |
|                                                                       |
| └─► PDF export                                                        |
+-----------------------------------------------------------------------+

**6.3 Backend API Touchpoints**

  ------------------------------------------------------------------------
  **Capability**     **Used By**                          **Status**
  ------------------ ------------------------------------ ----------------
  **Get my           E1                                   To define
  attendance for                                          
  period**                                                

  **Get my today     E1 Today card                        To define
  status (live)**                                         

  **Get daily        E2                                   To define
  attendance                                              
  detail**                                                

  **Get team         M1 Today tab                         To define
  attendance ---                                          
  today snapshot**                                        

  **Get team         M1 Team tab                          To define
  attendance ---                                          
  period summary**                                        

  **Get employee     M2                                   To define
  attendance for                                          
  period (manager)**                                      

  **Get attendance   D1                                   To define
  dashboard data**                                        

  **Export period    E1, M2, D1                           To define
  report PDF with                                         
  watermark**                                             

  **Bulk export      M1 (HR Manager)                      To define
  aggregate period                                        
  report (HR)**                                           
  ------------------------------------------------------------------------

**7. Status & Visual Reference**

**7.1 Day Status Mapping**

  ------------------------------------------------------------------------
  **Status**        **Icon**   **Color**   **Definition**
  ---------------- ----------- ----------- -------------------------------
  **PRESENT**         **●**    Green       Employee checked in within
                                           grace period and worked the
                                           required hours.

  **LATE**            **⚠**    Amber       Employee checked in after the
                                           grace period.

  **EARLY             **⏱**    Amber       Employee checked out before
  DEPARTURE**                              scheduled time without approved
                                           permission.

  **ABSENT**          **✗**    Red         No check-in recorded for a
                                           working day.

  **ON LEAVE**        **☆**    Blue        Day covered by an approved
                                           leave request from Module 1.

  **JOB MISSION**     **✈**    Blue        Day covered by an approved Job
                                           Mission request.

  **OFF DAY**           □      Gray        Weekly off day per the
                                           employee\'s roster.

  **HOLIDAY**           ⊞      Gray        Public holiday.
  ------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **Backend Ownership**                                                 |
|                                                                       |
| Status determination per day is owned by the backend, which combines  |
| hr.attendance records with leave records (hr.leave), public holiday   |
| calendars, and employee work schedules. The mobile app consumes a     |
| normalized \'day_status\' field per day in the API response and       |
| renders the icon/color accordingly.                                   |
+-----------------------------------------------------------------------+

**7.2 Counter Computation Rules**

  -----------------------------------------------------------------------
  **Counter**        **Computation**
  ------------------ ----------------------------------------------------
  **Attendance %**   (Worked Days ÷ Working Days) × 100. Worked Days =
                     days with status PRESENT or LATE. Working Days =
                     scheduled working days in the period excluding off
                     days and holidays. On Leave days are typically NOT
                     counted as worked but also NOT counted in the
                     denominator (subject to backend policy).

  **Late Count**     Number of days with status LATE within the period.

  **Total OT**       Sum of overtime hours across all working days in the
                     period. OT computation rules (start threshold,
                     multiplier) owned by backend.

  **Worked Hours**   Sum of (check-out − check-in − breaks) across the
                     period.

  **Required Hours** Sum of scheduled working hours across working days
                     in the period.

  **Absent Days**    Number of days with status ABSENT within the period.
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Whether \'On Leave\' days count as working days in attendance % is a  |
| policy decision. Default: NOT counted (excluded from both numerator   |
| and denominator). If your policy treats leave as worked days for the  |
| % calculation, confirm and we\'ll adjust the rule.                    |
+-----------------------------------------------------------------------+

**8. Sign-off & Open Items**

**8.1 Assumptions Recap**

  ---------------------------------------------------------------------------
  **\#**   **Assumption**                                        **Status**
  -------- ----------------------------------------------------- ------------
  **1**    Mobile check-in / check-out is OUT of scope for       Pending
           Phase 1. Module is read-only reporting only.          

  **2**    Attendance corrections route through HR Requests as a Pending
           request type, not handled here.                       

  **3**    Status determination logic (Present / Late / Absent / Pending
           On Leave / Off / Holiday) is computed by backend.     

  **4**    On Leave days are NOT counted in attendance %         Pending
           calculation (excluded from numerator and              
           denominator).                                         

  **5**    Aggregate period report PDF for HR Manager is         Pending
           backend-generated; UX pattern (foreground vs          
           background) to confirm.                               

  **6**    Today tab auto-refreshes every 5 minutes. Confirm if  Pending
           a different polling interval is preferred.            
  ---------------------------------------------------------------------------

**8.2 Open Items Owned by Backend**

- Status normalization per day combining hr.attendance, hr.leave,
  holiday calendar, and work schedule

- Late grace period configuration (per company / per shift)

- OT computation rules (threshold, multipliers, day-type variations)

- Punch type taxonomy: are lunch in/out and break in/out separate
  punches in Odoo or computed?

- Attendance % calculation policy on leave days, half-days, and partial
  days

- Live \'today\' API endpoint shape and refresh frequency

- PDF report templates: per-employee monthly + aggregate company-wide

- Multi-shift handling (split shifts, night shifts crossing midnight)

*--- End of Module 5 ---*
