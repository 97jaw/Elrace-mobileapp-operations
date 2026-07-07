# Productivity — Widget Development Plan

## Overview

This category surfaces the user's personal productivity surface — daily tasks, quick notes, and support tickets. All three are personal-scope widgets (data tied to the requesting employee, no cross-employee aggregation).

**Widgets in this category**
1. Task Management (full width, row 1)
2. Notes (half width, row 2 left)
3. Tickets (half width, row 2 right)

**Frontend reference:** `screen2_v7` — Productivity section. Task Management uses bright blue, Notes uses warm peach, Tickets uses deep purple.

---

## Widget model configuration (emp_mobile_conf)

| Field | Task Management | Notes | Tickets |
|---|---|---|---|
| code | `task_management` | `notes` | `tickets` |
| name | Task Management | Notes | Tickets |
| category | `productivity` | `productivity` | `productivity` |
| sequence | 1 | 2 | 3 |
| size | `full` | `half` | `half` |
| icon | check-circle | pencil-note | ticket |
| theme_color | bright-blue (#2D7FF0) | peach (#E8B398) | purple (#8B4B9F) |
| is_active | True | True | True |
| role_ids | All employees | All employees | All employees |

---

## Widget 1: Task Management

### Frontend (must match v7)
- Full-width card with min-height 150px
- Gradient: `#4A8FF5 → #2D7FF0 → #1E6BE0 → #1858C0` (bright blue) with white highlight top-right
- Faded checkmark pattern bottom-right (white at opacity ~0.4)
- Glass icon container top-right (white at low opacity) with checklist icon
- Top label "Today" in light text, title "Task Management"
- **Three-column stat row** separated by faint vertical white dividers:
  - Open: "12" (white)
  - In Progress: "5" (yellow `#F4C842`)
  - Done: "3" (light-green `#4ADE80`)
- Bottom text with clock emoji: "⏰ 2 tasks due today"

### Backend business logic
- **Source models:** `project.task` (Odoo's task model).
- **Personal scope:** tasks where `user_ids` (assignees) contains the current employee's user, or `user_id` if single-assignee tasks. Always scoped to the requesting employee — no cross-user data.
- **State mapping:**
  - **Open** → tasks in stages classified as "to-do" or "open" (configurable list of `project.task.type` IDs, stored in widget config or `ir.config_parameter`).
  - **In Progress** → stages classified as "in progress".
  - **Done** → stages classified as "done" or "closed".
- **Due today:** tasks with `date_deadline.date() == today.date()` AND status not done.
- **"Today" label vs counts:** label is contextual ("Today"); the counts are *all* open/in-progress/done tasks for the employee, not just today's. This is intentional — the widget gives a "where am I" summary, not a daily-only view.
- **Optional refinement:** if business prefers, the three counts can be filtered to "tasks active in last 7 days" instead of all-time. Configurable.

### Edge cases
- New employee with no tasks: all counts zero, no "due today" line. Card still renders with same chrome.
- Task with no assignee (orphaned): never appears in any employee's widget.
- Multi-assignee tasks: appear in widgets of all assignees.
- Sub-tasks: counted independently from their parent (unless config flag set to roll-up).
- Stage configuration missing for an employee's project: that project's tasks counted as "Open" by default.

### API contract (data only)
- Input: employee from middleware.
- Output payload: `open_count`, `in_progress_count`, `done_count`, `due_today_count`, `due_today_message` (pre-formatted string for display, handles 0/1/many variants: "No tasks due today" / "1 task due today" / "2 tasks due today").

### Tap behavior (frontend)
- Tapping the card opens Task Management module with the user's full list.
- Tapping individual stat columns (Open/In Progress/Done) opens the module pre-filtered to that state.

### Caching
Lazy cache keyed by `(employee_id, widget_code)`. TTL: 10 minutes. Invalidated on `project.task` create/write/unlink where the employee is an assignee.

### Acceptance criteria
- Counts match what the user sees inside the Tasks module when filtering by themselves.
- Stage classification is consistent and documented.
- "Due today" handles 0/1/many phrasing correctly.
- Card renders identically to v7 including the checkmark pattern.

---

## Widget 2: Notes

### Frontend (must match v7)
- Half-width card left of row 2
- Gradient: radial `#FFD8B8 → #F5C5A8 → #E8B398 → #C8957D` (warm peach) with subtle white highlight
- Notebook-line pattern faded across the card (dark lines at opacity ~0.2 to evoke ruled paper)
- Dark-peach glass icon container top-right with pencil-note icon
- Top label "Quick capture" in dark peach, title "Notes"
- Big number "8" (total notes for the user)
- Trend in dark peach: "Last: Site review" (title of most recent note, truncated to ~20 chars)

### Backend business logic
- **Source model:** `note.note` if installed (Odoo's standard notes module), otherwise a custom Elrace notes model. Pick the one already in use — do not introduce a third.
- **Personal scope:** notes where `user_id == current_user` or `create_uid == current_user`. Always personal.
- **Total count:** count of active (non-archived) notes for the user.
- **Most recent note title:** `name` (or `memo` text first line) of the note with highest `write_date`. Truncated server-side to a configurable character limit (default 20).
- **If no notes:** return `total = 0` and `last_note_title = null`. Frontend shows "No notes yet" in the trend slot.

### Edge cases
- Note with empty title (auto-saved blank): use first line of body text, or "(untitled)" if body is also empty.
- Note marked as private (if the model supports it): always shown to its owner — privacy is between users, not from the owner.
- Note attached to a project: still counted personally; project relevance is a future filter.
- HTML-rich note content: strip tags server-side before sending the title preview.

### API contract (data only)
- Input: employee from middleware → user resolved.
- Output payload: `total_count`, `last_note_title` (already truncated and tag-stripped), `last_note_id` (so tapping the trend line can deep-link), `last_updated_at` (relative format e.g. "2h ago").

### Tap behavior (frontend)
- Tapping the card opens Notes module with the user's full list, sorted by most recent.
- Tapping the trend line opens the specific most-recent note (uses `last_note_id`).

### Caching
Lazy cache keyed by `(employee_id, widget_code)`. TTL: 5 minutes (notes update frequently). Invalidated on note model create/write/unlink for the user.

### Acceptance criteria
- Count matches the Notes module for the user.
- Title preview correctly handles HTML, empty titles, and long titles.
- Peach gradient + notebook lines render identically to v7.

---

## Widget 3: Tickets

### Frontend (must match v7)
- Half-width card right of row 2
- Gradient: `#A065B5 → #8B4B9F → #6B2C7F → #4F1F60` (deep purple) with light purple highlight top-left
- Ticket cutout silhouette pattern faded bottom-right (white at opacity ~0.3 — recognizable as a ticket shape)
- Glass icon container top-right with ticket icon
- Top label "Support" in light purple, title "Tickets"
- Big number "7" (open tickets for the user)
- Trend in light red `#FF6B7A`: "3 high priority"

### Backend business logic
- **Source model:** `helpdesk.ticket` if the Helpdesk module is installed, otherwise the existing Elrace ticket model (likely a custom one — confirm during build).
- **Personal scope:** tickets created by the current user OR assigned to them. Both buckets relevant — a user wants to see "my tickets" (raised + assigned).
- **Total count:** count of open tickets (state not in "done" / "cancelled" / "closed").
- **High priority count:** tickets where `priority` is high (typically `'2'` or `'3'` in Odoo's standard 0-3 priority scale — confirm with the actual ticket model).
- **Trend message:**
  - If 0 high priority → "All on track" (in green).
  - If 1 high priority → "1 high priority" (in red).
  - If > 1 → "N high priority" (in red).

### Edge cases
- User with no tickets at all: count = 0, trend hidden.
- Ticket re-opened after being closed: counted again as open.
- Ticket assigned to a team rather than a person: counted if the user is a member of that team (depends on whether team assignment is in use).
- Internal vs customer-facing tickets: both counted by default unless the model has a clear flag and product requires filtering.

### API contract (data only)
- Input: employee from middleware.
- Output payload: `total_open`, `high_priority_count`, `trend_message` (pre-formatted), `trend_color` (red/green/neutral).

### Tap behavior (frontend)
- Tapping the card opens Tickets module with the user's tickets, sorted by priority then date.
- Tapping the trend line (high priority) opens module pre-filtered to high priority only.

### Caching
Lazy cache keyed by `(employee_id, widget_code)`. TTL: 5 minutes. Invalidated on ticket model create/write/unlink where the user is creator or assignee.

### Acceptance criteria
- Counts match the tickets the user sees in the Tickets module with their personal filter.
- Priority threshold for "high" is documented and consistent.
- Card renders identically to v7 including the ticket-cutout pattern.

---

## Common to all 3 widgets

### Shared characteristics
- All three are **personal-scope** — no cross-user data, no role-based scope variation.
- All three share short cache TTLs (5–10 minutes) because the data updates frequently as the user works.
- All three open their respective modules on tap with the user's personal filter pre-applied.

### Shared dependencies
- `hr.employee` (resolved from middleware).
- `res.users` (linked to hr.employee).
- Task/Notes/Tickets models (confirm which ones are installed in the Elrace database during initial setup).

### Sequencing (build order)
1. **Notes first** — simplest single-count widget, validates the personal-scope pattern.
2. **Tickets second** — adds the priority dimension.
3. **Task Management last** — most complex with three-column stats and stage classification.

### Testing checkpoints
- Each widget tested with: zero data, 1 item, 100 items, mixed states/priorities.
- Verify personal scope isolation — fetch as User A, never see User B's data even via API tampering.
- Cache invalidation correctness — create a task, fetch widget, confirm count updated within TTL window (or immediately on cache invalidation hook).
- Flutter golden tests against v7 for all three cards.

### Out of scope (for this iteration)
- Inline task creation from the widget (the card is a summary, not an input).
- Search inside the widget.
- Filtering by project / category inside the widget.
- Pinned or favorite tasks/notes/tickets surfaced specifically (only counts and most-recent).
- Notifications / push integration when counts change (separate notification system handles this).
