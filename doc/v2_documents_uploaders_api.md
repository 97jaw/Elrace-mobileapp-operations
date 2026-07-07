# v2 Documents — Uploaders API

Implemented in `elrace_backend_apis` (`project_documents_service.py`, `project_controller.py`).

## Endpoints

### `GET /api/v2/documents/uploaders`

Paginated staff with project document upload activity (WO + Estimation attachments).

**Params** (JSON-RPC body): hub filters (`year`, `month`, `project_status_compute`, `wo_ref_no`, `wo_type_no_office`, `name`), `keyword`, `limit`, `offset`.

**Response `data.uploaders[]`:**

| Field | Type | Description |
|-------|------|-------------|
| `employee_id` | int | `hr.employee` id |
| `name` | string | Display name |
| `designation` | string | Job title |
| `photo_url` | string | `/public/employee/image/{id}` |
| `total_uploads` | int | Attachment count in scope |
| `last_uploaded_at` | ISO datetime | Latest `create_date` |
| `project_count` | int | Distinct projects with uploads |

**Scope:** portfolio projects (same `staff_list_ids` rules as other v2 document routes).

**Aggregation:** group `project.attachment` files by `create_uid` → `hr.employee`.

---

### `GET /api/v2/documents/uploader_projects`

Projects where a given employee uploaded documents.

**Params:** `employee_id` (required), hub filters, `keyword`, `limit`, `offset`.

**Response:** `data.projects[]` — same shape as `folder_projects`.

---

### Extended filters

Optional `uploader_id` (int, `hr.employee` id) on:

- `GET /api/v2/documents/files`
- `GET /api/v2/documents/project_files`

File items may include `uploader_id` when resolvable from `create_uid`.

---

## Deploy

1. Update `elrace_backend_apis` module on Odoo server
2. Restart Odoo / upgrade module if required
3. Verify: `GET /api/v2/documents/uploaders` returns 200 (not 404)

**Note:** SharePoint per-file uploaders are not included until Graph metadata is integrated; WO/Estimation Odoo attachments are fully supported.
