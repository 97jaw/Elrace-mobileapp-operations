# Chat sync — Mobile + Web HUB

## Purpose

Mobile and Web HUB Chat must be **one shared system**: same Firebase project, same Auth users, same DB/storage — fully synced.

Not “Web also connects to Firebase,” but **Web joins the existing mobile chat backend**.

---

## Requirement summary

| Must be the same | Notes |
|------------------|--------|
| Project | Existing **`elrace-new`** (mobile chat already runs here) |
| Auth | Same users — UID `odoo_{odoo_user_id}` via Odoo custom token |
| Database | Same Firestore (`users`, `chats`, `userChats`, messages, …) |
| Presence / typing | Same Realtime Database paths |
| Media | Same Storage (`chat_media/...`) |

### Do not

- Create a separate Firebase project
- Create separate Auth / separate DB for Web
- Use Odoo Discuss (or another chat backend) as the message store
- Use different UIDs or collection names

### OK

Register a **Web app client** under the *same* `elrace-new` project (SDK config only). That does **not** create new Auth or a new DB — those stay project-level and shared with mobile.

### Success check

Send a message on mobile → it appears on Web HUB (and reverse), with no sync job and no second database.

---

## Technical summary — how HUB connects to existing `elrace-new`

### 1) Firebase client (same project)

1. In Firebase Console → project **`elrace-new`** → add a **Web app** (client config only).
2. Use that config in HUB (`apiKey`, `authDomain`, `projectId`, `databaseURL`, `storageBucket`, etc.).
3. Enable / use existing: **Auth**, **Firestore**, **Realtime Database**, **Storage**, **FCM** (already used by mobile).

### 2) Auth (same users as mobile)

#### Mobile path (existing)
1. User logs in via Odoo mobile auth.
2. Odoo returns `firebase_uid` + `firebase_custom_token`.
3. Mobile: `signInWithCustomToken(...)`.
4. Refresh: `POST /api/firebase/refresh_token` with Odoo JWT.

#### Hub path (S2S — required)
Hub browser has Sanctum/SSO session, **not** an Odoo JWT. Use:

`POST /api/hub/firebase/custom_token`  
HMAC-signed Hub backend → Odoo (see `elrace_backend_apis/docs/HUB_FIREBASE_CUSTOM_TOKEN.md`).

Returns `{ success, firebase_uid, firebase_custom_token }`.  
UID rule (mandatory): `firebase_uid = odoo_{odoo_user_id}` / `odoo_{source_id}`.

### 3) Data paths (read/write exactly these)

#### Firestore

| Path | Purpose |
|------|---------|
| `users/{uid}` | User profile |
| `userChats/{uid}/chats/{chatId}` | Inbox |
| `chats/{chatId}` | Room metadata (`member_ids`, last message, …) |
| `chats/{chatId}/members/{uid}` | Membership |
| `chats/{chatId}/messages/{messageId}` | Messages |
| `users/{uid}/fcm_tokens/{token}` | FCM tokens |

#### Chat ID formats

- DM: `dm_{minUid}_{maxUid}`
- Role: `role_{roleId}` / `role_{roleId}_branch_{branchId}`
- Support (production): `support_{normalizedGroupKey}_{userUid}` — fallback: `support_{roleId}_{userUid}`
- Project: `project_{projectId}`

Full contract (Step 4): `docs/hub_chat_contract.md`

#### Realtime Database

- `presence/{uid}` → `{ online, lastChanged }`
- `typing/{chatId}/{uid}`

#### Storage

- `chat_media/{chatId}/{messageId}/{fileName}`

### 4) Minimal Web flow

1. Odoo login → get `firebase_custom_token`
2. `signInWithCustomToken` → same Auth UID as mobile
3. Subscribe to `userChats/{uid}/chats` (inbox)
4. Open chat → subscribe to `chats/{chatId}/messages`
5. Send → write message + update chat last message + update both sides’ `userChats`
6. Presence/typing via RTDB; media via Storage path above

### 5) Contract

Mobile schema is the source of truth (field names, chat IDs, UID format).  
HUB must **reuse** it — not redesign collections or Auth.

---

## Bottom line

HUB Chat = **client of existing mobile Firebase chat** (`elrace-new`), authenticated with the **same Odoo custom tokens**, writing to the **same Firestore/RTDB/Storage**. That is what makes Mobile and Web fully synced.

**Firebase rules & indexes (Step 3):** see `docs/hub_firebase_rules_and_indexes.md`.

**Mobile chat contract (Step 4):** see `docs/hub_chat_contract.md`.

**Cloud Functions & notifications (Step 5):** see `docs/hub_cloud_functions_and_notifications.md`.

**Staging tests (Step 6):** see `docs/hub_staging_test_plan.md`.

**Full handoff summary for Hub:** see `docs/hub_chat_integration_handoff.md`.

---

## Mobile reference (this repo)

| Area | Location |
|------|----------|
| Chat module | `lib/chat/` |
| Auth | `lib/chat/services/firebase_chat_auth_service.dart` |
| Data access | `lib/chat/repositories/chat_repository.dart` |
| Integration contract | `lib/chat/examples/integration_guide.dart` |
| Firebase options | `lib/firebase_options.dart` (mobile uses **`elrace-new`**) |
