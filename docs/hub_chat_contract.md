# Hub Chat — Mobile contract confirmation (Step 4)

**Status: confirmed** — mobile production schema is authoritative. Hub must match exactly.

Project: **`elrace-new`**  
Auth UID: **`odoo_{odoo_user_id}`** (Hub: `odoo_{users.source_id}`)

---

## 1) Firestore paths (authoritative)

| Path | Purpose |
|------|---------|
| `users/{uid}` | User profile |
| `users/{uid}/fcm_tokens/{token}` | FCM device tokens |
| `userChats/{uid}/chats/{chatId}` | Inbox index per user |
| `userChats/{uid}/starred_messages/{messageId}` | Per-user starred messages |
| `chats/{chatId}` | Room metadata |
| `chats/{chatId}/members/{uid}` | Membership + mute snapshot |
| `chats/{chatId}/messages/{messageId}` | Messages |

## 2) Realtime Database paths (authoritative)

| Path | Value | Notes |
|------|-------|-------|
| `presence/{uid}` | `{ online: bool, lastChanged: number }` | Mobile uses RTDB, not Firestore |
| `typing/{chatId}/{uid}` | `true` while typing | **Delete node** when typing stops (not `false`) |

## 3) Storage paths (authoritative)

| Path | Purpose |
|------|---------|
| `chat_media/{chatId}/{messageId}/{fileName}` | Images, audio, files, signable PDFs |

---

## 4) Chat ID formats (authoritative)

### DM
```text
dm_{minUid}_{maxUid}
```
- Sort the two Firebase UIDs lexicographically; smaller first.
- Example: `dm_odoo_12_odoo_345`
- Self-chat: `dm_{uid}_{uid}` (same uid twice)

### Role group
```text
role_{roleId}
role_{roleId}_branch_{branchId}
```
- Use `_branch_{branchId}` when branch-scoped groups are enabled.

### Support (helpdesk) — **production convention**

**Primary (used by mobile UI today):**
```text
support_{normalizedGroupKey}_{userUid}
```

- `normalizedGroupKey` = source role chat id with non `[a-zA-Z0-9_]` replaced by `_`
- Mobile passes `supportGroupKey = group.id` (e.g. `role_5`, `role_5_branch_2`)
- Examples:
  - `support_role_5_odoo_123`
  - `support_role_5_branch_2_odoo_123`

**Fallback (only when no group key is provided):**
```text
support_{roleId}_{userUid}
```
- Example: `support_5_odoo_123`

Hub must resolve support chats using the **normalized group key** format when opening existing mobile support threads.

### Project group
```text
project_{projectId}
```
- `type` on chat doc = `group`

---

## 5) Chat types (`chats/{chatId}.type`)

| Value | Meaning |
|-------|---------|
| `dm` | Direct message |
| `role` | Role / department group |
| `group` | Project / site group (`project_*`) |
| `support` | User ↔ department helpdesk thread |

---

## 6) Key document fields

### `users/{uid}` (snake_case)
Common fields Hub should read/write consistently:

- `odoo_user_id`, `name`, `email`, `role_id`, `role_name`, `branch_id`, `company_id`
- `avatar_url`, `job_title`, `phone_number`, `search_keywords`
- `x_stamp_user` (bool — can stamp documents)
- `chat_notifications_muted` (bool — global chat push mute)

### `chats/{chatId}`
- `type`, `member_ids` (array of uid strings)
- `dm_pair` (DM only — sorted `[uidA, uidB]`)
- `role_id`, `branch_id`, `company_id`, `title`, `photo_url`
- `support_user_uid` (support chats — external user uid)
- `last_message`: `{ text, type, sender_id, created_at }`
- `created_at`, `updated_at`

### `chats/{chatId}/members/{uid}`
- `joined_at`, `muted`
- `role_id_snapshot`, `branch_id_snapshot`, `company_id_snapshot`
- `is_support_user` (bool — external user in support chat)

### `userChats/{uid}/chats/{chatId}`
- `type`, `title`, `updated_at`
- `peer_uid` (DM)
- `role_id`, `branch_id`, `company_id` (role/group)
- `support_user_uid`, `support_group_title` (support)
- `last_read_at` — read receipt watermark
- `pinned`, `muted`, `archived`, `has_messages`

### `chats/{chatId}/messages/{messageId}`
Core fields (all snake_case):

| Field | Notes |
|-------|-------|
| `sender_id` | Must equal `request.auth.uid` |
| `type` | `text`, `image`, `file`, `audio`, `video`, `signable_doc` |
| `text` | Text body |
| `media_url`, `media_path`, `file_name`, `file_size`, `mime_type` | Media |
| `duration_ms`, `thumb_url` | Audio/video |
| `reply_to` | `{ message_id, sender_id, text, type }` |
| `created_at`, `client_msg_id`, `status` | `status` stored as `sent` |
| `sign_zones`, `sign_status`, `signed_pdf_url`, `signed_at`, `signed_by` | Signable docs |
| `signer_uids`, `signer_names`, `current_signer_index`, `current_signer_uid` | Multi-signee |
| `expires_at`, `signature_document_id` | Signable doc lifecycle |

---

## 7) Send message flow (Hub must mirror mobile)

1. Write `chats/{chatId}/messages/{messageId}`.
2. Merge-update `chats/{chatId}`:
   - `last_message` preview
   - `updated_at`
   - ensure `member_ids` (and `dm_pair` for DMs).
3. Merge-update sender `userChats/{senderUid}/chats/{chatId}`:
   - `updated_at`, `has_messages: true`, type-specific fields.
4. For **DM**: update recipient `userChats/{peerUid}/chats/{chatId}` timestamp (sender may create recipient inbox row).
5. For **support**: update all members’ `userChats` timestamps.
6. Clear typing: delete `typing/{chatId}/{uid}` in RTDB.
7. Upload media first to `chat_media/...`, then set `media_url` on message.

Cloud Function `onNewChatMessage` handles recipient FCM + recipient `userChats` timestamp backfill for non-sender members.

---

## 8) Read / unread

- **Read watermark:** `userChats/{uid}/chats/{chatId}.last_read_at`
- **Mark read:** update `last_read_at` only (do not create doc if no messages yet).
- **Unread count:** messages in chat where `sender_id != currentUid` and `created_at > last_read_at` (skip `muted` chats).

Per-message read receipts are **not** stored in Firestore today.

---

## 9) Typing (RTDB)

**Start typing:**
```js
ref('typing/{chatId}/{uid}').set(true)
```

**Stop typing:**
```js
ref('typing/{chatId}/{uid}').remove()
```

Mobile auto-clears typing after ~3 seconds of inactivity.

---

## 10) Notifications & mute

| Setting | Location |
|---------|----------|
| Global chat mute | `users/{uid}.chat_notifications_muted === true` |
| Per-chat mute | `userChats/{uid}/chats/{chatId}.muted === true` |
| Member mute | `chats/{chatId}/members/{uid}.muted === true` |

FCM tokens: `users/{uid}/fcm_tokens/{tokenId}`  
Cloud Function `onNewChatMessage` respects all three mute levels and removes invalid tokens.

---

## 11) Inbox query

```text
userChats/{uid}/chats
  .orderBy('updated_at', 'desc')
```

Single-field index — no composite index required.

Messages query:

```text
chats/{chatId}/messages
  .orderBy('created_at', 'desc')
  .limit(pageSize)
```

---

## 12) Hub verification checklist

Before enabling Hub Chat in production, verify against mobile:

- [ ] Same `firebase_uid` / `odoo_{source_id}` after Hub S2S token
- [ ] DM id uses sorted uid pair
- [ ] Support id uses `support_{normalizedGroupKey}_{userUid}` for existing threads
- [ ] Typing uses RTDB delete-on-stop
- [ ] `last_read_at` drives unread badges
- [ ] Media uploaded under `chat_media/{chatId}/{messageId}/...`
- [ ] Mobile → Hub and Hub → Mobile message appears in same room
- [ ] Role, support, project, signable doc, image, audio flows

---

## Related docs

| Step | Doc |
|------|-----|
| Overview | `docs/hub_chat_firebase_sync.md` |
| Rules & indexes | `docs/hub_firebase_rules_and_indexes.md` |
| Hub Odoo token | `elrace_backend_apis/docs/HUB_FIREBASE_CUSTOM_TOKEN.md` |

Mobile reference code: `lib/chat/` (especially `repositories/chat_repository.dart`, `models/`).
