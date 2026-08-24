# Hub Chat integration — complete Elrace handoff

**To:** Hub team  
**From:** Elrace (Mobile / Firebase / Odoo)  
**Date:** August 2026  
**Firebase project:** `elrace-new` (shared with mobile — **same Auth, same DB, fully synced**)

This is the **complete response** to your 7 integration requests. Hub Chat joins the **existing mobile Firebase chat backend**. We are **not** creating a separate Firebase project, Auth realm, or message database.

**Gate:** Keep Hub Chat **feature-flagged off** until the staging test matrix (Section 6) passes.

**Security:** This document contains **public client configuration only**. No HMAC secrets, service accounts, Odoo JWTs, or private keys are included.

---

## Executive summary

| # | Your request | Status |
|---|--------------|--------|
| 1 | Firebase Web SDK config (`elrace-new`) | **Done** — see Section 1 |
| 2 | Hub S2S Firebase custom-token endpoint | **Done** — see Section 2 |
| 3 | Firebase rules & indexes | **Done** — see Section 3 |
| 4 | Mobile chat contract confirmation | **Confirmed** — see Section 4 |
| 5 | Cloud Functions & web notifications (VAPID) | **Done** — see Section 5 |
| 6 | Staging test users | **Template** — Elrace to fill names (Section 6) |
| 7 | Deployment ownership | **Agreed** — see Section 7 |

---

## 1) Firebase Web configuration

### Requirement
Genuine Web app under **`elrace-new`**. Do **not** use Flutter’s web config (`elrace-578e7`).

### Done
- Web app name: **Elrace Hub**
- Authorized domains: **`hub.elrace.com`** + Hub staging hostname
- Same project as Android/iOS mobile chat

### Public SDK config (use in Hub)


firebaseConfig = {
  apiKey: "AIzaSyAKFq4N_bhk_6K17hsdjzuQpmtIGKO4pVE",
  authDomain: "elrace-new.firebaseapp.com",
  projectId: "elrace-new",
  databaseURL: "https://elrace-new-default-rtdb.firebaseio.com",
  storageBucket: "elrace-new.firebasestorage.app",
  messagingSenderId: "392748487890",
  appId: "1:392748487890:web:873807d27483101e0f490b",
  measurementId: "G-WG1RJM00KS"
};
```

| Field | Value |
|-------|--------|
| `projectId` | `elrace-new` |
| `messagingSenderId` | `392748487890` |
| `databaseURL` | `https://elrace-new-default-rtdb.firebaseio.com` |

**Important:** Registering a Web **client** does not create new Auth or DB — mobile and Hub share project-level Firebase resources.

---

## 2) Secure Firebase custom-token endpoint for Hub

### Requirement
Hub browser has Sanctum/SSO session, **not** Odoo JWT. Hub backend must call Odoo server-to-server.

### Done — production endpoint

| Field | Value |
|-------|--------|
| URL | `POST https://erp.elrace.com/api/hub/firebase/custom_token` |
| Method | `POST` |
| Content-Type | `application/json` |
| Caller | **Hub backend only** (never browser / JS bundle) |
| Auth | HMAC — shared Hub SSO secret (same family as Hub SSO; server-side only) |

### Flow
1. Hub user authenticated (Microsoft SSO / QR)
2. Hub backend reads `users.source_id` (= Odoo `res.users.id`)
3. Hub backend signs request with HMAC secret
4. Odoo validates signature + timestamp + nonce
5. Odoo returns `firebase_uid` + `firebase_custom_token` for `odoo_{source_id}` only
6. Hub backend returns token to browser
7. Browser: `signInWithCustomToken(auth, firebase_custom_token)`

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `X-Hub-Timestamp` | yes | Unix seconds (UTC) |
| `X-Hub-Nonce` | yes | Unique per request (≤ 128 chars) |
| `X-Hub-Signature` | yes | Hex HMAC-SHA256 |

### Signature canonical string (exact newlines)

```text
hub.firebase.custom_token
{odoo_user_id}
{timestamp}
{nonce}
```

```text
X-Hub-Signature = hex(HMAC_SHA256(hub_sso_hmac_secret_bytes, canonical))
```

Use the same Hub SSO HMAC secret already configured with Odoo (`elrace.hub_sso_hmac_secret` / `x_hub_sso_hmac_secret`). **Never** put this secret in Hub frontend, mobile app, Git, or chat.

### Request body

```json
{
  "odoo_user_id": 123
}
```

`odoo_user_id` **must** equal authenticated Hub user’s `source_id`. Browser must not select arbitrary ids.

### Success response (`200`)

```json
{
  "status": "success",
  "success": true,
  "firebase_uid": "odoo_123",
  "firebase_custom_token": "<one-time Firebase custom token>",
  "token_expires_in_seconds": 3600
}
```

Hub must verify: `firebase_uid === "odoo_" + source_id`.

### Error responses

| HTTP | `message` | Meaning |
|------|-----------|---------|
| 400 | missing headers / invalid body | Bad request |
| 401 | `invalid_signature` | HMAC mismatch |
| 401 | `expired_request` | Timestamp skew > 60s |
| 401 | `replay_detected` | Nonce reused |
| 404 | `user_not_found` | Unknown/inactive Odoo user |
| 503 | not configured | HMAC / Firebase Admin missing |

### Token behavior
- Firebase custom token TTL: ~**1 hour** → Hub backend should re-request when expired
- Timestamp skew window: **60 seconds**
- Nonce: single-use (~5 min store)

### Mobile-only path (unchanged, not for Hub browser)
`POST https://erp.elrace.com/api/firebase/refresh_token` with Odoo mobile JWT.

---

## 3) Firebase rules and indexes

### Repo source of truth (mobile repo)

| Asset | File | Deploy command |
|-------|------|----------------|
| Firestore rules | `firestore.rules` | `firebase deploy --only firestore:rules --project elrace-new` |
| Firestore indexes | `firestore.indexes.json` | `firebase deploy --only firestore:indexes --project elrace-new` |
| RTDB rules | `database.rules.json` | `firebase deploy --only database --project elrace-new` |
| Storage rules | `storage.rules` | `firebase deploy --only storage --project elrace-new` |

### Production indexes
**None** (composite list empty). Chat uses single-field indexes only (`updated_at`, `created_at`, etc.) — auto-created by Firestore.

### RTDB rules (deployed)

```json
{
  "rules": {
    "presence": {
      "$uid": {
        ".read": "auth != null",
        ".write": "auth != null && auth.uid == $uid"
      }
    },
    "typing": {
      "$chatId": {
        "$uid": {
          ".read": "auth != null",
          ".write": "auth != null && auth.uid == $uid"
        }
      }
    },
    ".read": false,
    ".write": false
  }
}
```

### Pre-production hardening (mobile owner, before Hub prod)

Current checked-in Firestore chat rules are **permissive** (any signed-in user can write messages/members). Before production activation we will:

- Restrict message read/write to chat members
- Enforce `sender_id == request.auth.uid` on create
- Limit cross-user `userChats` writes to legitimate participants
- Add Storage membership checks for `chat_media`
- Run **mobile regression** after any rule change

**Hub must not deploy shared Firebase rules** without Elrace approval.

---

## 4) Mobile chat contract — confirmed

### Firestore paths (authoritative)

```text
users/{uid}
users/{uid}/fcm_tokens/{token}
userChats/{uid}/chats/{chatId}
userChats/{uid}/starred_messages/{messageId}
chats/{chatId}
chats/{chatId}/members/{uid}
chats/{chatId}/messages/{messageId}
```

### Realtime Database (authoritative — not Firestore)

```text
presence/{uid}              → { online, lastChanged }
typing/{chatId}/{uid}       → true while typing; DELETE when stopped
```

### Storage (authoritative)

```text
chat_media/{chatId}/{messageId}/{fileName}
```

### Chat ID formats

| Type | Format | Example |
|------|--------|---------|
| DM | `dm_{minUid}_{maxUid}` | `dm_odoo_12_odoo_345` |
| Role | `role_{roleId}` | `role_5` |
| Role (branch) | `role_{roleId}_branch_{branchId}` | `role_5_branch_2` |
| Support (production) | `support_{normalizedGroupKey}_{userUid}` | `support_role_5_odoo_123` |
| Support (fallback) | `support_{roleId}_{userUid}` | `support_5_odoo_123` |
| Project | `project_{projectId}` | `project_15106` |

**Support note:** Mobile passes `supportGroupKey = roleChatId` (e.g. `role_5`), normalized to alphanumeric + underscore. Hub must open existing support threads using this format.

### Chat types (`chats/{chatId}.type`)
`dm` | `role` | `group` | `support`

### Key fields (snake_case)

**Message:** `sender_id`, `type` (`text`|`image`|`file`|`audio`|`video`|`signable_doc`), `text`, `media_url`, `created_at`, `client_msg_id`, `reply_to`, signable-doc fields (`sign_status`, `signature_document_id`, …)

**userChats:** `updated_at`, `last_read_at`, `has_messages`, `pinned`, `muted`, `archived`, `peer_uid`, `support_user_uid`, `support_group_title`

**Read/unread:** compare message `created_at` vs `userChats/{uid}/chats/{chatId}.last_read_at`

### Send message flow (Hub must mirror mobile)
1. Write `chats/{chatId}/messages/{messageId}`
2. Update `chats/{chatId}` → `last_message`, `updated_at`, `member_ids`
3. Update sender `userChats/{senderUid}/chats/{chatId}`
4. DM: update recipient `userChats` (sender may create recipient inbox row)
5. Support: update all members’ `userChats`
6. Upload media to `chat_media/...` first, then set `media_url`
7. Clear typing: delete `typing/{chatId}/{uid}` in RTDB

---

## 5) Cloud Functions and chat notifications

### Deployed and active in `elrace-new` (verified)

| Function | Trigger | Region | Purpose |
|----------|---------|--------|---------|
| `onNewChatMessage` | `chats/{chatId}/messages/{messageId}` created | us-central1 | Chat FCM push |
| `onSignableDocumentUpdated` | signable message updated | us-central1 | Sign sync + notify |
| `cleanupExpiredSignableDocs` | scheduled hourly | us-central1 | Expired unsigned docs |
| `cleanupExpiredAudio` | scheduled | us-central1 | Audio/media vacuum |

Source: mobile repo `functions/index.js`, `functions/sign_document_sync.js`, `functions/audio_vacuum.js`

### `onNewChatMessage` behavior
- Reads `chats/{chatId}.member_ids`, skips sender
- Honors mute: `users/{uid}.chat_notifications_muted`, `userChats/.../muted`, `members/{uid}.muted`
- Sends FCM to `users/{uid}/fcm_tokens/*`
- Removes invalid/unregistered tokens
- Updates recipient `userChats/{uid}/chats/{chatId}` → `updated_at`, `has_messages: true`
- FCM data payload includes: `type: chat_message`, `chat_id`, `chat_title`, `sender_id`, `message_id`, …

**Hub:** store web FCM tokens at the **same path** as mobile → same function notifies Hub browsers.

### Web FCM + VAPID (required for Hub browser push)

Real-time chat in an **open tab** works via Firestore listeners (no VAPID needed).

**Background browser notifications** require VAPID + service worker.

#### Step A — VAPID public key (Firebase Console)

1. Open: [Firebase Console → elrace-new → Cloud Messaging](https://console.firebase.google.com/project/elrace-new/settings/cloudmessaging)
2. Scroll to **Web configuration** → **Web Push certificates**
3. Click **Generate key pair** (if none exists)
4. Copy the **Key pair** public string (starts with `B...`)

> **Owner note:** VAPID public key is visible only in Firebase Console (not retrievable via CLI). Elrace will paste the active public key in the shared credentials channel when Hub starts web push integration. **Never share the private key.**

#### Step B — Hub browser setup

1. Add service worker `firebase-messaging-sw.js` at site root
2. Request notification permission
3. Get token:

```javascript
import { getMessaging, getToken } from "firebase/messaging";

const messaging = getMessaging();
const token = await getToken(messaging, {
  vapidKey: "<VAPID_PUBLIC_KEY_FROM_CONSOLE>",
});
```

4. Save token to Firestore:

```text
users/{firebase_uid}/fcm_tokens/{token}
```

Suggested fields: `{ platform: "web", updated_at: serverTimestamp(), user_agent: "..." }`

5. On logout: delete that token document

#### Step C — Service worker (minimal)

```javascript
// firebase-messaging-sw.js
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAKFq4N_bhk_6K17hsdjzuQpmtIGKO4pVE",
  authDomain: "elrace-new.firebaseapp.com",
  projectId: "elrace-new",
  messagingSenderId: "392748487890",
  appId: "1:392748487890:web:873807d27483101e0f490b",
});

const messaging = firebase.messaging();
messaging.onBackgroundMessage((payload) => {
  const n = payload.notification || {};
  self.registration.showNotification(n.title || 'New message', {
    body: n.body,
    data: payload.data,
  });
});
```

**Hub must not modify or deploy Cloud Functions** without Elrace approval.

---

## 6) Staging test users

Elrace will provide **two users** with mobile + Hub accounts. Fill before joint testing:

### User A
| Field | Value |
|-------|--------|
| Name | _TBD_ |
| Hub login | _TBD_ |
| Mobile login | _TBD_ |
| `source_id` (Odoo user id) | _TBD_ |
| Firebase UID | `odoo_{source_id}` |
| Role/branch | _TBD_ |

### User B
| Field | Value |
|-------|--------|
| Name | _TBD_ |
| Hub login | _TBD_ |
| Mobile login | _TBD_ |
| `source_id` | _TBD_ |
| Firebase UID | `odoo_{source_id}` |
| Role/branch | _TBD_ |

### Test matrix

| # | Scenario | Pass |
|---|----------|------|
| 1 | Mobile → Hub text | ☐ |
| 2 | Hub → Mobile text | ☐ |
| 3 | Image both directions | ☐ |
| 4 | Audio / file both directions | ☐ |
| 5 | Signable document | ☐ |
| 6 | Read/unread (`last_read_at`) | ☐ |
| 7 | Presence | ☐ |
| 8 | Typing (RTDB delete-on-stop) | ☐ |
| 9 | Mobile push notification | ☐ |
| 10 | Hub web push (VAPID) | ☐ |
| 11 | Logout / account switch | ☐ |
| 12 | SSO + QR before/after chat | ☐ |
| 13 | DM id `dm_{min}_{max}` | ☐ |
| 14 | Support opens existing mobile thread | ☐ |

---

## 7) Deployment responsibility — agreed

### Hub team
- Hub backend Firebase-session bridge (Sanctum → Odoo HMAC → custom token)
- Firebase Web client (`Elrace Hub` app config above)
- Hub Firestore / RTDB / Storage adapter matching Section 4
- Hub chat UI integration
- Web FCM service worker + VAPID (Section 5)
- Hub tests, feature flags, monitoring, rollback
- Preserve Microsoft SSO, QR Login, existing Hub notifications

### Elrace team (mobile / Firebase / Odoo)
- Mobile application + regression
- Odoo token service (Section 2) + Firebase Admin
- Shared Firebase rules, indexes, RTDB rules (Section 3)
- Cloud Functions (Section 5)
- Rule hardening before Hub production
- Staging users (Section 6)
- VAPID public key handoff via secure channel when Hub starts web push

---

## Quick start checklist for Hub

- [ ] Initialize Firebase with Section 1 config (`elrace-new`)
- [ ] Implement Hub backend → Odoo HMAC → `/api/hub/firebase/custom_token`
- [ ] Browser `signInWithCustomToken` → UID `odoo_{source_id}`
- [ ] Subscribe inbox: `userChats/{uid}/chats` orderBy `updated_at`
- [ ] Messages: `chats/{chatId}/messages` orderBy `created_at`
- [ ] Presence/typing via RTDB paths in Section 4
- [ ] Media upload: `chat_media/{chatId}/{messageId}/{fileName}`
- [ ] Web push: VAPID + service worker (Section 5)
- [ ] Feature flag OFF until Section 6 matrix passes

---

## Bottom line

Hub Chat = **client of existing mobile Firebase chat** in `elrace-new`. Same users, same rooms, same messages, same notifications infrastructure. No second database. No sync job.

**Questions:** contact Elrace mobile/Firebase/Odoo owner.
