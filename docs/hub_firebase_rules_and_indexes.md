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
| `chats/{chatId}` | Members, role chats, legacy | Members / role join | OK for list metadata |
| `chats/{chatId}/messages/{messageId}` | Any signed-in user | Any signed-in user | **Too open for production** |
| `chats/{chatId}/members/{memberId}` | Any signed-in user | Any signed-in user | **Too open for production** |
| `userChats/{userId}/**` | Owner only | Any signed-in user can create/update | Intentional for DM inbox sync |
| `users/{userId}` | Any signed-in user | Owner only | Profile reads are open |

### Storage — chat media (`storage.rules`)

| Path | Read | Write |
|------|------|-------|
| `chat_media/**` | Any signed-in user | Any signed-in user + size/type limits |

**Gap:** no chat-membership check on Storage yet.

### RTDB — recommended (`database.rules.json`)

| Path | Read | Write |
|------|------|-------|
| `presence/{uid}` | Any signed-in | Own uid only |
| `typing/{chatId}/{uid}` | Any signed-in | Own uid only |

Deploy this file before Hub production if Console rules differ.

---

## Pre-production hardening checklist (mobile owner)

Before enabling Hub Chat in production, mobile/Firebase owner will review:

- [ ] Only chat **members** can read `chats/{chatId}/messages`
- [ ] Only chat **members** can create messages
- [ ] `sender_id` must equal `request.auth.uid` on message create
- [ ] Members subcollection updates limited to legitimate participants
- [ ] `userChats` cross-user writes limited to valid chat participants (keep DM inbox behavior)
- [ ] RTDB: user can write only own `presence/{uid}` and `typing/{chatId}/{uid}`
- [ ] Storage: `chat_media` requires chat membership (or equivalent)
- [ ] Signable-document field updates remain limited to authorized signer
- [ ] **Mobile regression** after any rule change (DM, role, support, project, media, signing)

Hub team: verify compatibility against your adapter; **do not deploy** shared rules yourselves.

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
2. Rules are **permissive** for authenticated users on messages/members/media — feature-flag Hub Chat off until hardening passes.
3. No extra composite Firestore indexes are needed for baseline chat.
4. RTDB rules file is now versioned in repo; owner should deploy if Console differs.

---

## Related docs

- Chat sync overview: `docs/hub_chat_firebase_sync.md`
- Hub Odoo token (Step 2): `elrace_backend_apis/docs/HUB_FIREBASE_CUSTOM_TOKEN.md` (Odoo repo)
