# Module 5 — Staff Attendance Reports | Cursor Task File

> **How to use this file:** Read top to bottom before coding. Read companion SRD: `Module_5_Attendance_Reports_SRD.docx`. Start at F.0 and work top to bottom.

---

## 0. About This Module

You are extending an **existing Flutter mobile application** for **Pandora Tech LLC**, integrated with **Odoo 14 ERP**. This task file covers **Module 5: Staff Attendance Reports** only.

### What this module does
Read-only attendance reporting. Sources data from Odoo `hr.attendance` (populated by biometric devices, manual entries, etc. on the Odoo side). Three views:
- **Employee:** own attendance — calendar, list, summary, daily detail
- **Manager:** team attendance with today snapshot, period summaries
- **HR Manager:** company-wide with department filters

### What it DOESN'T do (Phase 1)
- Mobile check-in / check-out from app (NOT in scope)
- Geofencing (NOT in scope)
- Biometric integration on mobile (NOT in scope)
- Attendance corrections (those route through Module 1 HR Requests, not here)

---

## 1. Critical Rules (NEVER violate these)

| Rule | Reason |
|------|--------|
| Read SRD section before coding | SRD is source of truth |
| Never invent fields | If not in SRD, doesn't exist |
| Never hardcode colors/strings/spacing | Use design tokens |
| Reuse shared widgets | Check `/lib/core/widgets/` first |
| No `!` (bang) without justification | Null safety |
| One task = one commit | `feat(attendance): <TASK_ID> ... — SRD §<section>` |
| Empty / Loading / Error states mandatory | Every list and detail |
| **NO check-in/out functionality in Phase 1** | Read-only reporting only |
| **Status determination computed by backend** | Mobile reads `day_status` field, never computes it |

---

## 2. Roles & View Selection

| Boolean | View | Scope |
|---------|------|-------|
| None | Employee | Own attendance only |
| `is_management` | Manager | Team — direct reports |
| `is_pm` | Manager | Project team |
| `is_hr_manager` | HR Manager | All employees, dept + branch + designation filters |

If multiple flags true, **`is_hr_manager` takes precedence**.

---

## 3. ⚠️ DEVELOPMENT-ONLY: Role Toggle

Reuse dev role-toggle from Module 1 F.4. On Attendance widget entry point:

- 👤 User → Employee (E1)
- 👨‍💼 Manager → Manager (M1)
- 💼 HR Manager → HR Manager (M1 with extended scope)

**Final release:** Remove icons, dynamic role detection. TODO marker:

```dart
// TODO(release): Remove dev role toggle. Replace with dynamic role
// detection from login API booleans (is_hr_manager, is_management, is_pm).
// Reference: Module 5 TASKS.md §3.
```

---

## 4. Design System (inherits from Module 1)

Tokens defined in Module 1 F.1. Reuse as-is.

### Day Status Icons & Colors (centralized in this module)

Add to `/lib/core/theme/status_colors.dart` as `dayStatusColors`:

| Status | Icon | Color | Definition |
|--------|------|-------|------------|
| PRESENT | ● | success `#2E7D5B` | Checked in within grace period, worked required hours |
| LATE | ⚠ | warning `#C77700` | Checked in after grace period |
| EARLY DEPARTURE | ⏱ | warning `#C77700` | Checked out before scheduled time |
| ABSENT | ✗ | danger `#8B2635` | No check-in for working day |
| ON LEAVE | ☆ | primary `#1F3A5F` | Approved leave from Module 1 |
| JOB MISSION | ✈ | primary `#1F3A5F` | Approved Job Mission |
| OFF DAY | □ | mutedText `#6B7280` | Weekly off |
| HOLIDAY | ⊞ | mutedText `#6B7280` | Public holiday |

**Backend owns status determination.** Mobile reads `day_status` field from API and renders icon+color. Mobile NEVER computes status from raw punches.

### Calendar visual spec
- Month grid layout: 7 columns (Sun start)
- Day cell: status icon + day number, both centered vertically
- Future days within current month: empty cell, no icon
- Today: extra ring/border around the cell
- Tap day → opens E2 daily detail (bottom sheet or full screen)

---

## 5. Folder Structure

```

---

## 6. Module Roadmap

| Phase | Tasks | Why |
|-------|-------|-----|
| **Foundation (F)** | F.0 → F.2 | Calendar widget, day cells, KPI strip |
| **Employee (E)** | E1 → E2 | Landing + daily detail |
| **Manager (M)** | M1 → M2 | Today + period view, employee detail |
| **Dashboard (D)** | D1 | Analytics |
| **HR (H)** | H1 | HR-specific extensions |
| **Polish (P)** | P1 → P3 | Verification, sign-off |

### Module screens summary

| ID | Screen | SRD Section | Audience |
|----|--------|-------------|----------|
| E1 | My Attendance Landing | §2.1 | All Users |
| E2 | Daily Attendance Detail | §2.2 | All Users |
| M1 | Team Attendance Landing | §3.1 | Manager, HR Manager |
| M2 | Employee Attendance Detail (Manager) | §3.2 | Manager, HR Manager |
| D1 | Attendance Dashboard | §4 | Manager, HR Manager |

---

## 7. Functional Knowledge

### 7.1 Counter computation rules (defined by backend)

| Counter | Logic |
|---------|-------|
| Attendance % | (Worked Days ÷ Working Days) × 100. Worked = PRESENT + LATE. |
| Late Count | Days with status LATE in period |
| Total OT | Sum of overtime hours across working days |
| Worked Hours | Sum of (check-out − check-in − breaks) |
| Required Hours | Sum of scheduled working hours |
| Absent Days | Days with status ABSENT |

**On Leave days are NOT counted in attendance %** (excluded from numerator AND denominator) per SRD assumption #4.

### 7.2 Today card (E1 top)

Shows live status for current day:
- Status (Present / Absent / On Leave / Off Day)
- Check-in time (or '—' if not yet)
- Check-out time (or '—  (Not yet)' if not yet)
- **Live worked-time counter** — computed by mobile from check-in if not yet checked out. Updates every minute.

### 7.3 Calendar view (E1)

Month grid. Each day shows status icon + day number. Tap day → E2.

Navigation: chevrons left/right or month picker. Default: current month.

### 7.4 List view (E1)

Daily rows in chronological order: date, day name, check-in, check-out, worked hours, status badge.

### 7.5 Summary view (E1)

Same KPIs as the strip but expanded with totals and averages over the selected period.

### 7.6 Daily detail (E2)

Bottom sheet OR full screen. Shows:
- Day name + date header
- Status badge
- Punch records (chronological list with icons)
- Summary: Worked Hours / Break Time / Total / Required / Late By / Overtime
- Notes (if any)
- **Linked Leave / Mission card** if status is ON LEAVE or JOB MISSION — links to Module 1 request detail

### 7.7 Manager Today tab (M1)

Real-time team view for current day. Auto-refresh every 5 minutes (or pull-to-refresh).

KPI strip: Present (count + total) / Late / Absent / On Leave / Not Checked Out.

'Not Checked Out' = employees who checked in but haven't checked out yet (useful at end of day).

### 7.8 Manager Team period tab (M1)

Period-based aggregate: Team Att % / Total Late / Total OT / Total Absences.

Sort options: Most attendance issues first (default) / Alphabetical / Most OT / Highest att %.

Per-employee summary row: avatar, name, att %, late count, OT, absences. Tap → M2.

### 7.9 Dashboard charts (D1)

1. KPI cards: Team Att % / Total Late / Total OT
2. Daily Attendance Trend (line chart)
3. Status Distribution (donut: Present / Leave / Late / Absent)
4. Top Punctual (top 3 by att % + zero late)
5. Attendance Concerns (att < 90% or excessive late)
6. Department Comparison (HR Manager only — horizontal bars)

---

## 8. API Conventions

Same as Module 1 §8. Mock all responses. Each day in the calendar payload includes a `day_status` field — backend determines the status. Mobile never computes status from raw punches.

---

## 9. Tasks (work top to bottom)

> **Status legend:** `[TODO]` `[IN_PROGRESS]` `[DONE]` `[BLOCKED]` `[NEEDS_REVIEW]`

---

### Phase 0 — Foundation

#### `[TODO]` F.0 — Verify Module 1 foundation
Same checklist. Complete Module 1 first if anything missing.

Add `table_calendar` package to pubspec if not present.

#### `[TODO]` F.1 — Day status colors + icons
- Add `dayStatusColors` map to `/lib/core/theme/status_colors.dart` per §4 of this file
- Create helper `Icon dayStatusIcon(String dayStatus)` returning the correct icon glyph

#### `[TODO]` F.2 — Module-specific shared widgets


1. **`today_card.dart`** — date header, status, check-in/out times, live worked counter (use a Timer.periodic to update)
2. **`attendance_kpi_strip.dart`** — 6 KPI cards in 2 rows of 3: Att % / Late / OT / Worked Hrs / Required Hrs / Absent
3. **`day_cell.dart`** — single calendar day cell: status icon + day number, today highlighted, tappable
4. **`attendance_calendar.dart`** — month grid using `table_calendar` or custom build, uses day_cell, month navigator on top
5. **`attendance_list.dart`** — daily rows: date, day, check-in, check-out, worked, status badge
6. **`attendance_summary.dart`** — expanded period summary with totals + averages
7. **`punch_records_list.dart`** — chronological list of punches with icons (check-in, lunch out/in, check-out)
8. **`status_distribution_donut.dart`** — donut chart: Present / Leave / Late / Absent
9. **`attendance_trend_chart.dart`** — line chart for D1
10. **`department_comparison_chart.dart`** — horizontal bar chart for D1 HR view

**Definition of done:** All widgets compile, render in sandbox, follow design system.

---

### Phase 1 — Employee Screens

#### `[TODO]` E1 — My Attendance Landing
- **SRD section:** §2.1
- **Wireframe:** §2.1.1
- **Component spec:** §2.1.2

**Steps:**
1. Read SRD §2.1 in full
2.AsyncNotifier returning current day + month grid + KPIs
3. Mock data: full month with realistic mix of statuses (about 18-20 PRESENT, 1-2 LATE, 1 ABSENT, 1-2 LEAVE, weekends as OFF_DAY)
4. Create `e1_landing_screen.dart`:
   - AppBar: 'My Attendance' + dev role toggle
   - **Today Card** (use F.2 widget) — top of screen, prominent
   - **Monthly KPI Strip** (use F.2 widget) — current month default
   - **Sub-tabs:** Calendar (default) | List | Summary
   - **Calendar tab:** month nav + attendance_calendar widget. Tap day → E2 bottom sheet
   - **List tab:** daily rows from attendance_list
   - **Summary tab:** attendance_summary widget
   - **Legend** below calendar: visual reference for icon meanings
   - **Export Monthly Report** button at bottom — PDF with employee's emp_id watermark

**Commit:** `feat(attendance): E1 my attendance landing — SRD §2.1`

---

#### `[TODO]` E2 — Daily Attendance Detail
- **SRD section:** §2.2
- **Wireframe:** §2.2.1
- **Component spec:** §2.2.2

**Steps:**
1. Read SRD §2.2 in full
2. AsyncNotifier with date parameter
3. 
   - Renders as bottom sheet (drag handle on top) by default; fallback to full screen on tablet
   - Day name + date header
   - **Status badge** (large)
   - **Punch Records** (use F.2 widget) — chronological list with check-in, lunch out/in, check-out, etc.
   - **Summary section** — Worked Hours / Break / Total / Required / Late By / OT
   - **Notes** (read-only, mail.thread display)
   - **Linked Leave / Mission card** — if status is ON LEAVE or JOB MISSION, show card with link → opens Module 1 request detail. Otherwise hide.
4. Empty case: future date or off day with no data → 'No attendance data for this day'

**Commit:** `feat(attendance): E2 daily attendance detail — SRD §2.2`

---

### Phase 2 — Manager Screens

#### `[TODO]` M1 — Team Attendance Landing
- **SRD section:** §3.1
- **Wireframe:** §3.1.1
- **Component spec:** §3.1.2

**Steps:**
1. Read SRD §3.1 in full
2.  AsyncNotifier returning today's snapshot, scoped by role
3.  AsyncNotifier returning period summary
4. 
   - AppBar + dev role toggle
   - **View Switcher:** Dashboard | Team
   - **Tabs:** Today (default) | Team | My Own (renders E1)
   - **Today Tab:**
     - 'TODAY · [date]' header
     - **KPI strip:** Present (count + total) / Late / Absent / On Leave / Not Checked Out
     - **Status filter chips:** All / Late / Absent / On Leave
     - **Employee cards:** avatar, name, status badge, status-specific sub-text:
       - PRESENT → 'Check-in: 08:42 AM'
       - LATE → 'Check-in: 09:18 AM (18m late)'
       - ON LEAVE → 'Annual Leave (12 May → 16 May)'
       - ABSENT → 'No check-in recorded'
     - Tap card → M2
   - **Team Tab:** see Section 3.3 of SRD — period-based view
   - **Auto-refresh** every 5 minutes (use Timer.periodic, cancel on dispose)
5. Pull-to-refresh on the list

**Commit:** `feat(attendance): M1 team attendance landing — SRD §3.1`

---

#### `[TODO]` M2 — Employee Attendance Detail (Manager)
- **SRD section:** §3.2
- **Wireframe:** §3.2.1
- **Component spec:** §3.2.2

**Steps:**
1. Read SRD §3.2 in full
2. Build as a thin wrapper around E1's body
3. Add **EmployeeInfoCard** at the top (use shared widget from Module 1)
4. Add **period selector** dropdown to switch months / custom ranges
5. Same KPI strip, same Calendar/List/Summary tabs as E1, scoped to that employee
6. **Export Report** button uses **manager's** emp_id watermark
7. Tap day in calendar → E2 daily detail (with that employee's data)

**Commit:** `feat(attendance): M2 employee attendance detail manager — SRD §3.2`

---

### Phase 3 — Dashboard

#### `[TODO]` D1 — Attendance Dashboard
- **SRD section:** §4
- **Wireframe:** §4.1
- **Component spec:** §4.2

**Steps:**
1. Read SRD §4 in full
2. Create `attendance_dashboard_provider.dart`
3. Create `d1_dashboard_screen.dart`:
   - **Period Selector:** This Week / This Month default / Last Month / This Quarter / This Year / Custom
   - **KPI cards:** Team Att % / Total Late / Total OT
   - **Daily Attendance Trend** (use F.2 widget — line chart of att % per day)
   - **Status Distribution Donut** (use F.2 widget)
   - **Top Punctual Employees** — top 3, tap → M2
   - **Attendance Concerns** — < 90% att or excessive late, tap → M2
   - **Department Comparison** (HR Manager only — use F.2 widget)
   - **PDF export** with emp_id watermark

**Commit:** `feat(attendance): D1 attendance dashboard — SRD §4`

---

### Phase 4 — HR Manager Extensions

#### `[TODO]` H1 — HR Manager extensions
- **SRD section:** §5

**Steps:**
1. On M1 'Team' tab for HR Manager: enable department, branch, designation filters
2. Show all employees company-wide
3. **Aggregate Period Report** button on M1 (HR only): bulk PDF for all employees for chosen period — backend operation, mock with progress indicator + TODO(backend) per §7.8 of Module 4
4. Department drill-down on dashboard chart should filter the team list

**Commit:** `feat(attendance): H1 hr manager extensions — SRD §5`

---

### Phase 5 — Polish & Verification

#### `[TODO]` P1 — Cross-screen verification
- Switch through Employee / Manager / HR Manager via dev toggle
- Verify calendar renders all 8 statuses correctly with mock data
- Verify Today tab auto-refreshes (test with 1-min refresh during dev)
- Verify pull-to-refresh
- Verify linked leave/mission card on E2 navigates to Module 1
- Verify all PDF exports

#### `[TODO]` P2 — Component reuse audit
- Confirm no duplicate calendar widgets (use a single attendance_calendar)
- All status badges + day status icons via centralized maps
- All shared widgets imported via package import

#### `[TODO]` P3 — Module 5 sign-off
- `flutter analyze` clean
- All widget tests pass
- Screenshots of every screen and tab
- Decisions log §10 updated

---

## 10. Decisions Log

```
[YYYY-MM-DD] TASK_ID — Decision: <what>. Rationale: <why>.
```

(Initially empty)

---

## 11. Open Items / Questions for Architect

Note: SRD §8.1 lists 6 assumptions awaiting confirmation:
- Mobile check-in/out OUT of scope — implemented as read-only
- Attendance corrections route through HR Requests — NOT in this module
- Status determination computed by backend — implemented (mobile reads day_status)
- On Leave days NOT counted in att % — implemented per assumption
- Aggregate period report bulk export — TODO(backend) marked
- Today tab refresh interval 5 min — implemented (configurable)

If architect adjusts, track here.

---

## 12. Definition of Module Complete

- [ ] All tasks marked `[DONE]`
- [ ] `flutter analyze` passes
- [ ] No duplicate calendar widgets
- [ ] All 8 day statuses render correctly with their icons + colors
- [ ] PDF export with watermark works on E1, M2, D1
- [ ] Today tab auto-refreshes
- [ ] Linked leave/mission card on E2 navigates to Module 1
- [ ] Dev role toggle visible and functional
- [ ] All TODO(release), TODO(backend) comments in place
- [ ] Screenshots captured (per status, per role, per tab)
- [ ] Decisions log §10 updated

— End of Module 5 Task File —
