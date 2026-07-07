# My Projects — Group-By Hub API Contract (v2)

Mobile group-by hub and bucket drill-down use **v2** endpoints. Legacy v1 routes are unchanged for dashboard, agreements, and home widget flows.

## Data flow (current app — v1 production)

1. **Hub** — fetch portfolio projects (`get_projects` / v2 when deployed) → apply hub filters client-side → **group buckets in Flutter** (not v1 `clients/list` counts).
2. **Drill-down** — `get_partner_projects` / v2 with bucket id + same hub filters → paginated project list.
3. **Search on hub** — filters `searchName` on project/WO records before grouping; bucket counts update.

Until v2 is deployed, v1 `get_projects` only returns **in_progress** projects for the widget domain; PM names come from `manager_name` on each project row (not grouped `clients/list`).

## Data flow (target — v2 deployed)

1. **Hub** — `POST /api/v2/clients/list` with `group_by` + hub filters → bucket rows + counts (server-side).
2. **Drill-down** — `POST /api/v2/get_partner_projects` with bucket id + same hub filters.
3. **Optional bulk** — `GET /api/v2/get_projects/` with `portfolio=1` + hub filters.

Filters always apply to `project.project` records **before** aggregation or listing.

## Access domain (v2 portfolio)

| User | Domain |
|------|--------|
| Non-management | `staff_list_ids.employee_id = emp` AND `staff_list_ids.access = 'project'` |
| Management (`x_is_management`) | No staff restriction |

v1 `/api/clients/list` keeps the legacy domain: `staff_list_ids.employee_id = emp` (any access).

## Shared filter parameters

| Param | Odoo field | Notes |
|-------|------------|-------|
| `year` | `date_start` year | optional |
| `month` | `date_start` month | optional, 1–12 |
| `project_status_compute` | `project_status_compute` | e.g. `in_progress`, `completed` |
| `wo_ref_no` | `wo_ref_no` | ilike |
| `wo_type_no_office` | `wo_type_no_office` | `active` / `pending` |
| `search_name` / `name` | `name` OR `project_name_arabic` | ilike |
| `keyword` | legacy | name / wo_ref_no / agreement name |

## Endpoints

### `/api/v2/clients/list`

**Params:** `group_by` (`agreement` | `client` | `project_manager` | `city`) + hub filters above.

**Response:** Same shape as v1; `meta.api_version = 2`.

PM buckets use **employee id** from staff_list (`access=project`), not `user_id`.

### `/api/v2/get_partner_projects`

**Params:** bucket ids (`partner_id`, `project_manager_id`, `city_id`, `agreement_id`) + hub filters + `limit` / `offset`.

**Response:** Grouped by partner; each project row includes `project_manager_id`, `project_status_compute`, `wo_type_no_office`, `city_id` tuple.

### `/api/v2/get_projects/`

**Params:** `portfolio=1` (default for hub) or widget scope without portfolio; hub filters; pagination.

**Response:** Flat project list with `project_manager_id` and related v2 fields.

## Flutter wiring

| Flow | Endpoint |
|------|----------|
| Group hub buckets | Project-first: `get_projects` portfolio + client-side group (v2 `clients/list` when deployed) |
| Tap bucket → list | `get_partner_projects` / v2; synthetic buckets use `bucketName` client filter on v1 |
| Hub bulk projects | `v2/get_projects` with `portfolio=1` (fallback v1) |
| Dashboard agreements | `clients/list` (v1) |
| Map / dashboard list | `get_projects` (v1) |
| Agreement drill-down | `get_partner_projects` (v1) |

Until v2 is deployed on Odoo, the app probes v2 once per session, logs a fallback message, and uses v1 with client-side PM enrichment. Hub filters only apply server-side after v2 deploy.

Implementation: [`project_remote_datasource.dart`](../lib/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart), [`project_filter_service.py`](../../projects/elrace/odoo14-clients/elrace_backend_apis/services/project_filter_service.py).
