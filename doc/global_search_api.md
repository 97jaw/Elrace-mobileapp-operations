# Global Search — Flutter client vs ERP backend

## Endpoint

- **URL:** `POST https://erp.elrace.com/api/global/search`
- **Body (jsonrpc):** `{ "params": { "category", "keyword", "limit", "limit_per_category" } }`
- **Implementation:** `elrace_backend_apis/controllers/misc_controller.py` → `global_search()`

## Unified search (`category=all`)

Default for the mobile app. Omit `category` or pass `"all"`.

| Param | Default | Notes |
|-------|---------|--------|
| `keyword` | required | Min 2 characters |
| `limit_per_category` | 5 | Max 10 hits per domain |

Searches in one request: `projects`, `lpo`, `petty_cash`, `my_actions`, `notes`, `documents`, `tasks`.

**Response:**

```json
{
  "status": "success",
  "data": [
    { "category": "lpo", "id": 123, "name": "PO00123", ... },
    { "category": "projects", "id": 45, "project_id": 45, "name": "Site A", ... }
  ],
  "meta": {
    "category": "all",
    "keyword": "site",
    "total_count": 12,
    "limit_per_category": 5,
    "counts_by_category": { "lpo": 3, "projects": 2, "notes": 1, ... }
  }
}
```

Every item includes `category` for grouping and navigation.

## Single-category search (legacy)

| Category | Model / notes |
|----------|----------------|
| `projects` | `project.project` — rich payload; includes `id` and `project_id` |
| `lpo` | `purchase.order`, `state=done` |
| `petty_cash` | `hr.expense.sheet` for user's petty holder |
| `my_actions` | ApprovalService — hr, rfq, invoice, ptsh |
| `notes` | `note.note` |
| `documents` | `ir.attachment` |
| `tasks` | `project.task` |

Use `limit` (default 10, max 50). Each row includes `category` in the payload.

## Response shape

Success: `{ "status": "success", "message": "...", "data": [ ... ], ...meta }` (wrapped in jsonrpc `result`).

Error: `{ "status": "error", "message": "Invalid category." }` — client maps via `_throwIfApiError` in `global_search_api_service.dart`.

## Deploy

1. Deploy `elrace_backend_apis` with `category=all` and `my_actions` in unified search.
2. Ship Flutter build that calls only `category=all` (no category chips).

## Future ERP work

1. **`/api/global/search/suggest`** — prefix only, no category.
2. **`offset`** pagination in meta.
3. Enrich notes/documents/tasks with `url`, `mimetype`, `project_id`, dates.

## Flutter integration

- UI: `lib/ui/widgets/global_search_screen.dart`, `global_search_header.dart`
- State: `GlobalSearchProvider` — `search(keyword)` only; `loadMoreForCategory` when `counts_by_category` exceeds shown rows
- API: `GlobalSearchApiService.globalSearchAll` + `globalSearchCategory` for per-category load-more (up to `limit` 50)
- Navigation opens the search screen directly (no full-screen route placeholder); skeletons show only while a query is in flight
- History: keyword-only recent queries (`global_search_history_v2`)
- Navigation: `global_search_navigation_helper.dart` (by `item.category`)
