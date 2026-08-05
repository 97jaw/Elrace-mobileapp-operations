# Sync Odoo employees → Firestore chat users

## Preferred: Odoo cron (production)

**Primary sync lives in Odoo**, not this script.

- Module: `elrace_backend_apis`
- Docs: `elrace_backend_apis/docs/CHAT_USER_FIRESTORE_SYNC.md`
- Credentials: already on `operating.unit` id 6 (`x_service_account_json` / `x_project_id`) — same as FCM
- Cron: **Chat: Sync Odoo users → Firestore profiles** (daily)
- Admin dry-run / apply: `POST /api/chat/users/sync` (system admin) or Odoo shell:

```python
env['chat.user.firestore.sync'].run_sync(dry_run=True)
env['chat.user.firestore.sync'].run_sync(dry_run=False)
```

Use this Node script only as a **manual fallback** (laptop, DM title heal, offline JSON).

---

## Fallback: Node Admin SDK script

One-time / manual privileged sync so every employee with an Odoo login gets a
`users/odoo_{res.users.id}` profile with **person name** + **public avatar**.

Client apps cannot fix peer profiles (Firestore rules: self-write only).

### Prerequisites

1. Firebase service account JSON for project `elrace-new`  
   (Firebase Console → Project settings → Service accounts → Generate new private key)  
   Or reuse a key you already have locally — never commit it.
2. Either Odoo JSON-RPC credentials, or a pre-exported employees JSON file

### Environment

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/elrace-new-adminsdk.json

# Option A — live Odoo
export ODOO_URL=https://erp.elrace.com
export ODOO_DB=your_db_name
export ODOO_USERNAME=admin@example.com   # or ODOO_LOGIN
export ODOO_PASSWORD='***'

# Option B — offline export (skips Odoo)
# export ODOO_EMPLOYEES_JSON=./employees.json

# Optional
# export ERP_PUBLIC_BASE=https://erp.elrace.com
```

### Employees JSON shape (Option B)

Array of objects (or `{ "employees": [ ... ] }`):

```json
[
  {
    "id": 123,
    "name": "Jane Doe",
    "emp_id": "E0042",
    "user_id": [456, "jane.doe"],
    "work_email": "jane@elrace.com",
    "mobile_phone": "+9715...",
    "job_id": [10, "Engineer"],
    "company_id": [1, "Elrace"]
  }
]
```

`user_id` must resolve to `res.users.id` (Firestore uid = `odoo_{id}`).

### Commands

From `functions/`:

```bash
# 1) Dry-run audit (default) — counts missing name/avatar vs Odoo
npm run sync:chat-users

# 1b) Firestore-only audit (no Odoo credentials)
npm run sync:chat-users:firestore-audit

# 2) Apply profile merges (does not wipe fcm_tokens)
npm run sync:chat-users:apply

# 3) Apply + heal DM list titles (empty / "User" / role-like)
npm run sync:chat-users:apply-heal

# Or directly:
node scripts/sync_odoo_chat_users.js --dry-run
node scripts/sync_odoo_chat_users.js --firestore-audit-only
node scripts/sync_odoo_chat_users.js --apply
node scripts/sync_odoo_chat_users.js --apply --heal-dm-titles
node scripts/sync_odoo_chat_users.js --heal-dm-titles --apply --heal-only
```

### Fields written (merge)

| Field | Source |
|---|---|
| `name` | `hr.employee.name` (person, not job title) |
| `avatar_url` | `{ERP}/public/employee/image/{employee.id}` |
| `odoo_user_id` | `employee.user_id` |
| `employee_id` | `hr.employee.id` |
| `emp_id` | badge string when present |
| `email` / `work_email` | `work_email` |
| `phone` / `mobile_phone` | mobile/work phone |
| `job_title` | `job_id` name |
| `company_id` | employee company |
| `search_keywords` | derived from name + email |
| `updated_at` | server timestamp |

### Safety

- Merge only — existing `fcm_tokens` and unrelated fields are kept
- No Firestore security rule changes
- Default mode is dry-run; writes require `--apply`

### After sync

Login continues to upsert the signed-in user via `UserRepository.upsertUser`
(`emp_name` + public employee image). Prefer the Odoo cron for ongoing completeness.

### Deferred follow-ups (not in this script)

- Cloud Function mute: honor global `chat_message` mute and per-chat `UserChat.muted`
- Avoid duplicate foreground notifications (FCM + local)
- Files hub: aggregate attachments across all chats (or rename “All chats” UI)
