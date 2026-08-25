# Hub Chat — Firebase rules & indexes (Step 3)

Project: **`elrace-new`**

This document is for the Hub team. **Do not deploy shared Firebase rules from Hub** without mobile/Firebase owner approval.

---

## Source of truth (mobile repo)

| Asset | Repo path | Deployed via |
|-------|-----------|--------------|
| Firestore rules | `firestore.rules` | `firebase deploy --only firestore:rules --project elrace-new` |
| Firestore indexes | `firestore.indexes.json` | `firebase deploy --only firestore:indexes --project elrace-new` |
| Realtime Database rules | `database.rules.json` | `firebase deploy --only database --project elrace-new` |
| Storage rules | `storage.rules` | `firebase deploy --only storage --project elrace-new` |

Mobile/Firebase owner maintains and deploys all of the above.

---

## Production snapshot (verified)

### Firestore composite indexes

CLI check (`firebase firestore:indexes --project elrace-new`):

```json
{
  "indexes": [],
  "fieldOverrides": []
}
```

Chat uses single-field indexes only (auto-created by Firestore):

- `userChats/{uid}/chats` → `orderBy('updated_at')`
- `chats/{chatId}/messages` → `orderBy('created_at')`
- `users` → optional `where('company_id')`, `where('x_stamp_user')`
- `chats` → `where('type', isEqualTo: 'role')`

No composite index file is required today.

### Realtime Database

- URL: `https://elrace-new-default-rtdb.firebaseio.com`
- Chat paths (mobile + Hub must use the same):
  - `presence/{uid}` → `{ online, lastChanged }`
  - `typing/{chatId}/{uid}` → `true` while typing; **delete** when stopped

**Note:** Mobile uses **RTDB** for presence/typing. A legacy `presence/{userId}` block also exists in Firestore rules but is not the active chat presence store.

---

## Current rule posture (important for Hub)

### Firestore — chat-related (checked-in `firestore.rules`)

| Path | Read | Write | Hub note |
|------|------|-------|----------|
| `chats/{chatId}` | **Members / dm_pair only** | Create: deterministic id+type+self; Update: members (immutable type/dm_pair/member_ids except proven role self-add / group admin) | G2 hardened |
| `chats/{chatId}/messages/{messageId}` | **Members only** | Create: member + sender + allowed type/keys + fresh `created_at`; Update: immutable type/created_at/client_msg_id; signing pending→pending/signed by current signer | G2 hardened |
| `chats/{chatId}/members/{memberId}` | **Members only** | Self / DM peer bootstrap / proven role claim / group admin; delete self or group admin only | G2 hardened |
| `userChats/{userId}/chats/{chatId}` | Owner only | Owner **or** chat member with allowlisted peer fields only | G2 hardened |
| `users/{userId}` | Any signed-in user | Owner only | Unchanged |

### Storage — chat media (`storage.rules`)

| Path | Read | Write |
|------|------|-------|
| `chat_media/{chatId}/{messageId}/{fileName}` | **Chat members only** | **Members only** + size/type limits |
| Other `chat_media/**` shapes | Denied | Denied |

### RTDB — recommended (`database.rules.json`)

| Path | Read | Write |
|------|------|-------|
| `presence/{uid}` | Any signed-in | Own uid only; payload `{ online: bool, lastChanged: number }` |
| `typing/{chatId}/{uid}` | Any signed-in | Own uid only; boolean `true` or delete |

## Emulator rule tests

```bash
cd Elrace-mobileapp-operations
npm --prefix firebase/rules-tests install
firebase emulators:exec --project elrace-new --only firestore,database,storage \
  "npm --prefix firebase/rules-tests test"
```

Covers Hub Phase 2 + **G2** denials: non-member message R/W, unrelated role-chat read, sender spoofing, foreign member add/delete, unproven role self-join, peer `userChats` field allowlist, deterministic DM ids, immutable chat `type`/`member_ids`/`dm_pair`, message type/keys/timestamps, immutable message fields, signing transitions, presence `lastChanged` required, typing `true` or delete, Storage path/membership.

`npm audit` on `firebase/rules-tests` is clean via lockfile overrides for Mocha transitive deps.

## Pre-production hardening checklist (mobile owner)

Before enabling Hub Chat in production, mobile/Firebase owner will review:

- [x] Only chat **members** can read `chats/{chatId}/messages`
- [x] Only chat **members** can create messages
- [x] `sender_id` must equal `request.auth.uid` on message create
- [x] Members subcollection updates limited to legitimate participants
- [x] `userChats` cross-user writes limited to valid chat participants (keep DM inbox behavior)
- [x] RTDB: user can write only own `presence/{uid}` and `typing/{chatId}/{uid}` with valid payloads
- [x] Storage: `chat_media` requires chat membership + canonical path
- [x] Signable-document field updates remain limited to authorized signer
- [ ] **Mobile regression** after any rule change (DM, role, support, project, media, signing)
- [ ] Staging deploy only + reversible rollback confirmation


---

## Deploy commands (owner only)

```bash
cd Elrace-mobileapp-operations

# Firestore rules + indexes
firebase deploy --project elrace-new --only firestore:rules,firestore:indexes

# Realtime Database rules
firebase deploy --project elrace-new --only database

# Storage rules
firebase deploy --project elrace-new --only storage
```

Compare Console vs repo before deploy:

- Firebase Console → Firestore → Rules / Indexes
- Firebase Console → Realtime Database → Rules
- Firebase Console → Storage → Rules

---

## What Hub should assume today

1. Use the **same paths** as mobile (see `docs/hub_chat_firebase_sync.md`).
2. Rules are **G2-hardened** and **deployed** to `elrace-new` (`75be3f0`). Hub Chat is **enabled** for Hub production use.
3. No extra composite Firestore indexes are needed for baseline chat.
4. RTDB rules file is versioned in repo; owner deploys to staging only with rollback ready.
5. Emulator suite: `firebase/rules-tests` (see commands above).

---

## Related docs

- Chat sync overview: `docs/hub_chat_firebase_sync.md`
- Hub Odoo token (Step 2): `elrace_backend_apis/docs/HUB_FIREBASE_CUSTOM_TOKEN.md` (Odoo repo)
