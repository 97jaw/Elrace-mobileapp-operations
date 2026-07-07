# Elrace Mobile — Screen 2 Widget Development Plan

> **Status (Jun 2026):** All 6 categories implemented on the v7 widget stack. Specs are **locked** for UI/behavior reference. Legacy styled-card builders in `list_view_widgets.dart` removed; reorder-mode still uses per-widget legacy previews via `_buildCustomWidget`.

## Overview

This folder contains the development plans for **14 widgets across 6 categories** as designed in the approved `screen2_v7` mockup. Each category has its own MD file with backend logic, widget model configuration, API contract, and Flutter frontend plan.

Cursor (the AI coding assistant) will handle the actual file structure, function names, and code-level implementation. These docs intentionally stay at the level of **what to build** and **what business rules apply**, not how to organize the code.

---

## The 6 categories

| File | Category | Widgets | Total widgets |
|---|---|---|---|
| `category_01_human_resource.md` | Human Resource | Attendance, HRMS, Timesheet | 3 |
| `category_02_projects.md` | Projects | My Projects, Site Management, My Reports | 3 |
| `category_03_purchase.md` | Purchase | LPO | 1 |
| `category_04_productivity.md` | Productivity | Task Management, Notes, Tickets | 3 |
| `category_05_finance.md` | Finance | Petty Cash | 1 |
| `category_06_library.md` | Library | My Documents, Media, Prayer Times | 3 |

**Two new widgets** introduced in v7 design and included in these plans:
- HRMS (Human Resource category)
- Site Management (Projects category)

---

## Layout reference

The screen 2 layout (from approved v7 design):

```
─── Human Resource ───
[Attendance] [HRMS]                  ← row 1 (2-col)
[Timesheet                       ]   ← row 2 (full)

─── Projects ───
[My Projects                     ]   ← row 1 (full)
[Site Management] [My Reports]       ← row 2 (2-col)

─── Purchase ───
[LPO                             ]   ← single row (full)

─── Productivity ───
[Task Management                 ]   ← row 1 (full)
[Notes] [Tickets]                    ← row 2 (2-col)

─── Finance ───
[Petty Cash                      ]   ← single row (full)

─── Library ───
[My Documents                    ]   ← row 1 (full)
[Media                           ]   ← row 2 (full)
[Prayer Times                    ]   ← row 3 (full)

[Glass Bottom Nav]
```

**Frontend must match v7 100%** — gradients, faded background patterns, icon containers, in-card data displays (project list, week dots, prayer times row, document thumbnails, media thumbnails), and the silver/gray base background with Elrace red watermark.

---

## Common backend pattern (across all categories)

All 14 widgets share the same architectural pattern. Per-widget specifics vary in business logic only.

### Authentication & scoping
- Middleware resolves the employee from the existing Hub auth headers (`X-Hub-User-Id`, `X-Hub-Odoo-Id`, `X-Hub-User-Type`, `X-Request-Id`).
- Client never passes `employee_id` — always resolved server-side.
- Per-widget `role_ids` check before returning data. If not authorized, return envelope with `is_authorized: false` and empty data so the frontend can render a "not authorized" placeholder without breaking layout.

### Service architecture
- **Thin controllers** — only handle auth, param extraction, service call, response formatting. Never put business logic in controllers (per established Elrace principle).
- **Service classes** — one service method per widget, named consistently. Each method receives `employee_id` and returns a structured payload.
- **Utils / middleware** — already in place; reuse, don't duplicate.

### Widget model (emp_mobile_conf)
- Each widget has a config record. The widget endpoint dispatches based on `code` → service method.
- Widget config controls visibility (`role_ids`), order (`sequence`), size (`full` / `half`), and theme.
- New: `is_hub` boolean + `hub_role_ids` Many2many already exist per prior decision. Mobile-only widgets keep `is_hub = False`.

### Caching (lazy pattern)
- All widget data goes through `hub.widget.cache`.
- Cache key composition: `(employee_id, widget_code, scope, period)` where applicable.
- TTL varies per widget (5 min for high-frequency like Notes/Tasks; 1 hour for HRMS/Documents; until-midnight for Prayer).
- No cron jobs (per established Elrace principle — cron creates performance risk). Cache is computed on first request, invalidated on model write/unlink hooks.
- Redis is a future drop-in replacement for `hub.widget.cache`; same key structure.

### API response envelope (consistent across widgets)
Every widget endpoint returns a standard envelope:
- `widget_code`
- `is_authorized` (boolean)
- `data` (the widget-specific payload)
- `cached_at` (timestamp)
- `is_stale` (true if served from a stale fallback, e.g. Prayer API down)

The frontend dispatches on `widget_code` to the right Flutter widget builder.

### Audit logging (finance widgets only)
- LPO and Petty Cash write to an audit log on every fetch with `employee_id`, `timestamp`, `scope`, optional value summary.
- All other widgets do not need audit logging.

---

## Common frontend pattern (Flutter)

### Widget rendering
- A single `WidgetHostScreen` (or equivalent) loads the user's widget list from a `/widgets/list` config endpoint (returns ordered widget codes per category).
- For each widget, a dispatcher maps `widget_code` to a Flutter widget builder.
- Each widget builder fetches its own data via the unified `/widgets/{code}/data` endpoint (or a similar batched endpoint — implementation detail Cursor will decide).

### Visual fidelity
- Every widget matches v7 design pixel-for-pixel: gradients, faded background patterns, icon containers, in-card displays.
- Design tokens (colors, gradients, border-radius 22px, shadow values, glass effect parameters) extracted from v7 HTML into a shared `WidgetTheme` class.
- Faded background patterns rendered via vector SVGs or PNGs at the documented opacity.

### State handling per widget
Every widget must handle:
- **Loading** — skeleton shimmer with the widget's base gradient (not a generic gray box).
- **Data** — normal render.
- **Empty** — same chrome, "no data yet" message in the trend slot.
- **Error** — same chrome, "couldn't load" with a retry tap target.
- **Not authorized** — placeholder card with the lock icon (for LPO and Petty Cash when role check fails).

### Refresh strategy
- Pull-to-refresh on the screen refreshes all widgets in parallel.
- Each widget has its own internal refresh-on-mount; cached responses on the backend keep this cheap.
- No widget triggers its own polling — refresh is user-driven or screen-mount-driven only.

### Tap behavior
- Tapping the card body opens the widget's module screen (existing Flutter route).
- Some widgets have additional tap targets inside the card (project rows in My Projects, doc thumbnails in My Documents, media thumbnails in Media). These are documented per widget.

---

## Suggested overall build sequence

Building in this order minimizes blocking dependencies and validates patterns progressively:

### Phase 1 — Foundation (validate the pattern)
1. **Attendance** (HR category) — simplest personal widget, validates the full stack: widget config, service, cache, frontend rendering.

### Phase 2 — Core widgets (the high-traffic ones)
2. **My Projects** (Projects category) — hero widget, validates in-card list pattern, project staff-list filtering.
3. **Task Management** (Productivity category) — validates three-column stat row pattern.
4. **Timesheet** (HR category) — extends the three-column pattern from Tasks.
5. **LPO** (Purchase category) — validates financial permission + audit log pattern.

### Phase 3 — Supporting widgets (build in parallel where teams allow)
6. **Petty Cash** (Finance category) — inherits financial-permission pattern from LPO.
7. **HRMS** (HR category) — role-scoped widget.
8. **Site Management** (Projects category) — extends HRMS scope pattern.
9. **My Reports** (Projects category) — role-driven metric resolution.
10. **Notes** (Productivity category) — simplest personal-scope.
11. **Tickets** (Productivity category) — extends Notes with priority logic.

### Phase 4 — Library (lower priority, more complex pipelines)
12. **Prayer Times** (Library category) — external API integration, daily caching.
13. **My Documents** (Library category) — fixed-thumbnail-set pattern.
14. **Media** (Library category) — most complex (S3 signed URLs, video/photo handling).

---

## Cross-category dependencies

- **`hr.employee`** with `role_line_ids` — used by every widget for scope and permission resolution.
- **`staff_list_ids` with `access == 'project'`** filter — used by My Projects, LPO (project-scoped), Media (project-scoped). Must be implemented identically everywhere.
- **`hub.widget.cache`** — shared cache table, schema documented during foundation phase, never modified mid-build.
- **AWS S3** — Media widget depends; should already be configured for Elrace.
- **Currency module** — LPO and Petty Cash both depend if multi-currency is enabled.

---

## Out of scope (deferred)

These appear across multiple category plans as deferred items:
- Real-time push updates when widget data changes (separate notification system handles this).
- In-widget action buttons (create task, submit petty cash request, upload document, etc.).
- Inline filters, search, or date selectors inside any widget.
- Custom date range selection (each widget uses its sensible default — month / week / today).
- Drag-to-reorder widgets on the screen (config-driven order only).
- Hub (web) versions of these widgets — `is_hub = False` for v1.

---

## Testing checkpoints (cross-category)

- **Pattern validation:** after Phase 1 (Attendance), confirm the full pattern works end-to-end before scaling out.
- **Permission isolation:** before any finance widget goes live, verify role checks reject unauthorized users gracefully (envelope with `is_authorized: false`).
- **Cache correctness:** after Phase 2, run a soak test — write to underlying data, confirm cache invalidates on hook within expected window.
- **Visual parity:** Flutter golden-test snapshot per widget against the v7 HTML mockup. CI fails if any widget drifts.
- **End-to-end:** simulate a typical user opening the app, verify all visible widgets load within performance budget (target: full screen 2 ready under 1.5s with cache hit, under 3s cold).

---

## File index

- `category_01_human_resource.md` — Attendance, HRMS, Timesheet
- `category_02_projects.md` — My Projects, Site Management, My Reports
- `category_03_purchase.md` — LPO
- `category_04_productivity.md` — Task Management, Notes, Tickets
- `category_05_finance.md` — Petty Cash
- `category_06_library.md` — My Documents, Media, Prayer Times

Each file is self-contained and can be handed to Cursor (or any developer) to implement that category independently. Cross-references between files are noted explicitly in each plan.
