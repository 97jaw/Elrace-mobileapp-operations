# Projects — Widget Development Plan

## Overview

This category surfaces project portfolio status, site-level operations, and personal performance metrics. It contains the visual hero of screen 2 (My Projects) and two supporting widgets.

**Widgets in this category**
1. My Projects (full width, hero of section)
2. Site Management (half width — left of row 2)
3. My Reports (half width — right of row 2)

**Frontend reference:** `screen2_v7` — Projects section. Must match the approved design, especially the in-card project list with progress bars on My Projects.

---

## Widget model configuration (emp_mobile_conf)

| Field | My Projects | Site Management | My Reports |
|---|---|---|---|
| code | `my_projects` | `site_management` | `my_reports` |
| name | My Projects | Site Management | My Reports |
| category | `projects` | `projects` | `projects` |
| sequence | 1 | 2 | 3 |
| size | `full` | `half` | `half` |
| icon | building-blueprint | hard-hat | chart-line |
| theme_color | gray-navy (#1A2A4F) | amber (#F59E3D) | dark-red (#E63946) |
| is_active | True | True | True |
| role_ids | Project managers, engineers | Site engineers, supervisors | All (data scoped per role) |

---

## Widget 1: My Projects

### Frontend (must match v7)
- Full-width card with min-height 200px
- Gradient: `#ECEFF4 → #D5DAE2 → #B8C2CF → #A0AABA` (gray) with white highlight top-left
- Concentric circles pattern faded top-right (4 rings, white at opacity ~0.35)
- Navy gradient icon container top-right with building/blueprint icon
- Top label "Active Projects", title "My Projects · 8"
- **In-card project list** — top 3 projects shown as rows separated by faint horizontal lines:
  - Color-coded bullet (green/orange/red based on progress)
  - Project name
  - Progress bar (gradient matching bullet color)
  - Percentage on the right
- Each row is tappable → opens that specific project

### Backend business logic
- **Source models:** `project.project`, `project.task`.
- **"My Projects" definition (critical Elrace-specific rule):**
  - Projects where the current employee is in `staff_list_ids` with `access == 'project'`
  - This is **not** `project.user_id` — Elrace uses a custom staff-list with access roles. `project_manager_id` parameters expect employee IDs, not user IDs (per existing Elrace conventions).
- **Total count:** number of active projects matching the rule above.
- **Progress per project:** percentage of `project.task` records with `stage_id` in "done" stage out of total tasks. If a project has no tasks, fall back to a manual `progress` field on `project.project` if present, otherwise 0%.
- **Top 3 selection:** sort projects by priority (urgent/high first) then by due date ascending. If no priority field is used, sort by `date_start` descending so most recently active appear first.
- **Color rule per row:**
  - ≥ 70% → high (green)
  - 30–69% → mid (orange)
  - < 30% → low (red)
  - Override: if project is overdue (past `date` and not closed), always show as low (red) regardless of percentage.
- **"+ X more projects"** link appears when total > 3.

### Edge cases
- Employee with no projects assigned: return empty `top_projects` array and `total = 0`, frontend shows "No projects yet" state with same card chrome.
- Project with no tasks: progress = 0% but project still shown in count.
- Overdue projects: always red, even if 90% done — drives attention to schedule risk.
- Project name truncation: backend returns full name; frontend truncates with ellipsis at ~20 chars.

### API contract (data only)
- Input: employee from middleware.
- Output payload: `total_active`, `due_this_week_count`, `top_projects[]` where each entry has `id`, `name`, `progress_pct`, `status_color` (high/mid/low), `is_overdue`.
- Sort: backend handles sorting; frontend trusts the order returned.

### Tap behavior (frontend)
- Tapping a row in the in-card list opens that specific project's detail screen.
- Tapping the card header or "+ X more" opens the full Projects list module.

### Caching
Lazy cache keyed by `(employee_id, widget_code)`. TTL: 15 minutes. Invalidated on `project.project` and `project.task` create/write/unlink where the employee is in the staff list.

### Acceptance criteria
- Project list inside card matches actual Odoo backend project list for the employee.
- Color rules correctly applied including the overdue override.
- Hero card renders identically to v7 mock including the concentric circles pattern and gradient depth.

---

## Widget 2: Site Management

### Frontend (must match v7)
- Half-width card on left of second row
- Gradient: `#FFF1D9 → #FFE0B0 → #FFCC85 → #F4A460` (amber/orange) with white highlight top-right
- Blueprint grid pattern faded bottom-right (white at opacity ~0.65) including a small house silhouette
- Orange gradient icon container top-right with hard-hat icon
- Top label "Sites", title "Site Management"
- Big number "3" (active sites)
- Trend in amber: "Active sites · 47 workers"
- Three location chips below: "Al Ain", "Mafraq", "+1" (semi-transparent white)

### Backend business logic
- **Source models:** Elrace site model (existing — likely `elrace.site` or a project-related model), `hr.employee` assigned to sites.
- **Visibility scope:** for site engineers and supervisors → only their assigned sites; for project managers → sites under their projects; for general managers → all active sites.
- **Active sites count:** count of sites where `active = True` and that have at least one ongoing project / status not "closed".
- **Total workers across sites:** distinct count of employees currently assigned to any site in scope.
- **Top 2 site names:** sites with the most workers (or alphabetical fallback) — shown as chips; remainder collapsed into "+N".

### Edge cases
- User assigned to no sites: empty state with same chrome, message "No sites assigned".
- Site with no workers yet: still counted as a site, contributes 0 to workers.
- Employee assigned to multiple sites: counted once in worker total (distinct).
- Closed/archived sites: never counted.

### API contract (data only)
- Input: employee from middleware → resolves scope automatically.
- Output payload: `active_sites_count`, `total_workers`, `top_sites[]` (max 2 with names), `extra_sites_count` (number beyond top 2), `scope`.

### Tap behavior
Opens Site Management module — list of sites with worker assignments and project links.

### Caching
Lazy cache keyed by `(employee_id, widget_code, scope)`. TTL: 30 minutes. Invalidated on site model changes and worker assignment changes.

### Acceptance criteria
- Site count and worker count match the underlying Odoo site records for the user's scope.
- Amber gradient + blueprint pattern render identically to v7.
- Empty state handled gracefully.

---

## Widget 3: My Reports

### Frontend (must match v7)
- Half-width card on right of second row, beside Site Management
- Background: dark navy `#1A1F2E → #2A2D40 → #1A1F2E` with the red financial chart pattern faded behind a 0.5–0.92 navy overlay (same look as original)
- Red icon container top-right with chart-line-up icon
- Top label "Performance", title "My Reports"
- Big number "+8.4%" (current performance metric)
- Trend in light-red: "▲ vs last month"
- Subtle small text bottom: "Updated 2h ago · Live"

### Backend business logic
- **Source:** depends on user role and Elrace's existing reporting setup.
  - **For project managers / managers:** financial KPI (P&L percentage, revenue vs budget) — use level-1 children of root P&L node with `abs()` for accounting sign conventions (per existing Elrace P&L traversal rules).
  - **For site engineers:** task completion rate (tasks closed this month / tasks closed last month).
  - **For HR managers:** workforce metric (attendance rate, productivity index).
  - **For employees:** personal task completion rate.
- **Computation rule:** `(current_period_value − previous_period_value) / previous_period_value × 100`, rounded to one decimal.
- **Direction:** positive % shown with ▲, negative with ▼.
- **Updated_at:** timestamp of last KPI computation (last cache write).

### Edge cases
- No data for previous period (new employee, new role): return null and frontend shows "—" with subtitle "Awaiting first report".
- Division by zero (previous = 0, current > 0): show "New" instead of percentage.
- KPI configured to "no comparison" for some roles: show absolute value (e.g., "AED 1.2M") without trend.

### API contract (data only)
- Input: employee from middleware → role + metric type resolved server-side, never accepted from client.
- Output payload: `metric_label`, `value` (string formatted for display), `trend_direction` (up/down/neutral/new), `previous_period_label`, `updated_at` (relative format on the backend: "2h ago"), `metric_type` (financial / task / workforce / personal).

### Tap behavior
Opens role-specific Reports module:
- Manager → financial reports
- Engineer → project & task reports
- HR → workforce reports
- Employee → personal performance

### Caching
Lazy cache keyed by `(employee_id, widget_code, metric_type, current_period)`. TTL: 1 hour. Invalidated on relevant source data changes (account.move for financial, project.task for task-based, hr.attendance for workforce).

### Acceptance criteria
- Correct metric type chosen automatically per role (no client toggle).
- Percentage calculation matches the underlying report module values.
- Edge cases (no previous data, zero baseline) render correctly without crashing.
- Dark navy + red chart pattern renders identically to v7.

---

## Common to all 3 widgets

### Shared dependencies
- `project.project` and `project.task` (My Projects depends heavily, others indirectly).
- Elrace site model (Site Management depends).
- Role-based scoping via existing role_line_ids on hr.employee.

### Sequencing (build order)
1. **My Projects first** — hero widget, most-asked-about, anchors the section visually and validates the in-card list pattern (used later by Documents and Media).
2. **Site Management second** — extends the listing pattern with location chips.
3. **My Reports last** — most variable per role, benefits from My Projects' caching pattern being already established.

### Testing checkpoints
- Verify `staff_list_ids` with `access == 'project'` filter is used in My Projects (not `project.user_id` — common mistake).
- Verify role-aware scoping in Site Management and My Reports across at least 4 roles.
- Postman scenarios: zero projects, all-overdue projects, 100-project portfolio (test pagination of top 3), mixed-priority sorting.
- Flutter golden tests for each card; verify progress-bar color thresholds at exactly 30% and 70%.

### Out of scope (for this iteration)
- Drag-to-reorder projects inside the My Projects card.
- Filter / search inside the widget (lives in the module).
- Custom metric selection in My Reports (role-driven default only).
- Project images / thumbnails inside the in-card list (only color bullet + name + bar in this iteration).
