# Firebase tasks — Cloud Functions (`functions/`, `functions-assignment/`)

Read first: `../01_ARCHITECTURE.md` (§2, D7, §7 ingest) and `../02_TRIGGER_MATRIX.md` (§1.5, §1.8–1.10).
Principle: functions keep **detecting** Firestore events, but **delivery goes through Odoo**
(`POST /api/internal/notify/emit`). If Odoo answers `handled:false` (type not taken over) or the call
fails, the function runs its current (legacy) send — so the switch lives in Odoo config, no redeploy.

Chat (`functions/index.js onNewChatMessage`) keeps sending directly (F6 only adds payload keys).

---

### F1. Shared Odoo emit client

**Scope:** `functions/lib/odoo_notify.js` and the same module in `functions-assignment/` (copy or shared package).

- Params (follow the pattern in `functions/odoo_announcement_push.js`): `defineString("ELRACE_ODOO_BASE_URL")`, `defineSecret("ELRACE_NOTIFY_INGEST_TOKEN")` (value = Odoo `elrace_notify.ingest_token`).
- `emitViaOdoo({type, recipientUids | odooUserIds, actorUid, model, resId, values, params, eventKey})`:
  resolve Firebase uids → `users/{uid}.odoo_user_id` (helper exists: `resolveUidFromOdooUserId` in `functions-assignment/index.js`; add the reverse), POST with header `X-Notify-Token`, timeout 8 s, 1 retry on 5xx/network.
- Returns `{handled: boolean}`. Any error → `{handled:false}` and log (never throw).

### F2. Tasks — assigned, completed, comment

- `functions-assignment/index.js` `onAssignedTodoCreated`, `onAssignmentPushRequest`: `emitViaOdoo({type:'task.assigned', model:'firestore.todo', resId:<todo id>, values:{assigned_by, task_title}, eventKey:'assign:'+todoId+':'+assigneeUid})`; on `handled:false` → current send.
- `onTodoCompleted`: recipients = creator + assignees **minus** `last_completed_by_uid`; `type:'task.completed'`, `values:{completed_by, task_title}`.
- New trigger on task comments at `users/{uid}/todos/{todoId}/comments/{commentId}` (not a root `comments` collection): recipients = participants minus comment author; `type:'task.comment'`, `values:{sender, comment}` (comment truncated to 120 chars).
- Align the Android channel id with the app (`task_notifications_channel`) in the legacy send (coordinate with M7).

### F3. Task deadline scheduler

- Todos live at `users/{uid}/todos/{todoId}` (plus a root `todos` collection — confirm whether it stays in sync before relying on it). Due field: `due_date`. Use a **collection-group query** on `todos` (or the root collection if confirmed in sync) and add the collection-group index.
- `onSchedule("every 5 minutes")`: query active (not completed) todos with `due_date` in `(now+23h55m, now+24h]` and `(now+55m, now+1h]`.
- Emit `task.deadline_24h` / `task.deadline_1h` to assignee(s), `eventKey = todoId + ':' + dueAt + ':24h|1h'` (Odoo dedupe makes repeats harmless).
- Only active when Odoo has taken over the type (`handled:false` → do nothing; the app still schedules locally until `server_task_notifications` is on).
- Add the required index (collection group `todos`: `is_completed` + `due_date`) to `firestore.indexes.json`.

### F4. Tickets

New triggers on `users/{uid}/tickets/{ticketId}` (and its comments sub-collection, if any). Assignee field is `assignee_id`; status values are `open`, `in_progress`, `resolved`, `closed`:

| Event | Detect | Type |
|---|---|---|
| Assigned (create with assignee, or assignee set from empty) | `before.assignee_id` empty → `after.assignee_id` set | `ticket.assigned` |
| Reassigned | `assignee_id` changed between two non-empty values | `ticket.reassigned` |
| Updated / comment | comment created, or status changed (not to closed) | `ticket.updated` (`update_summary`) |
| Closed | `status` changed to `closed` | `ticket.closed` |

Recipients per matrix §1.9, always minus the actor. Use `model:'firestore.ticket'`, `resId:ticketId`. Retire the app-queued ticket push in `onAssignmentPushRequest` for tickets when `handled:true`. CC: no CC field exists (OD-5); recipients are creator + assignee minus actor.

### F5. Notes, signature signed, signature waiting

- `functions/notes_share_notify.js` (`users/{uid}/shared_note_refs/{noteId}`): `type:'share.note'`, `values:{sender_name}`, `model:'firestore.note'`.
- `functions/sign_document_sync.js`: on `sign_status` → signed: `type:'document.signed'` to `sender_id`, `values:{signer_name, file_name}`, `model:'firestore.signature'`, `resId: signature_document_id`. **Do not set `chat_id` in the push** (that made the app treat it as chat — catalogue issue #9).
- Same file: when `current_signer_uid` changes to a new signer (document sent / next signer), emit `approval.waiting` with `values:{request_type:'Signature', reference:file_name}`, recipient the new signer, `eventKey: docId + ':' + current_signer_index` (OD-9 — Odoo type stays inactive until confirmed).

### F6. Chat payload contract

`functions/index.js onNewChatMessage`: add `nv:"1"`, `type:"chat.direct"|"chat.group"`, `category:"chat"`, `action:"open_chat"`, `params` JSON `{chat_id, chat_type, title}`; keep existing keys. No other change.

### F7. Announcement job retirement

`functions/odoo_announcement_push.js` stays deployed for rollback. Once `circular.published` is taken over (B12), Odoo stops writing `odoo_push_jobs`, so the function idles. Remove in phase 5.
