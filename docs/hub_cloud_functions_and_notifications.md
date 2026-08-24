# Hub Chat — Cloud Functions & notifications (Step 5)

Project: **`elrace-new`**

---

## Purpose

When a chat message is saved in Firestore, **Cloud Functions** run on the Firebase server to notify other members. Hub does **not** need its own notification microservice for baseline chat push — it reuses the same functions as mobile.

**VAPID** is only needed if Hub wants **browser push notifications** when the tab is in the background.

---

## Deployed functions (verified `elrace-new`)

| Function | Trigger | Region | Chat-related |
|----------|---------|--------|--------------|
| `onNewChatMessage` | `chats/{chatId}/messages/{messageId}` created | us-central1 | **Yes** |
| `onSignableDocumentUpdated` | signable doc message updated | us-central1 | **Yes** (signing) |
| `cleanupExpiredSignableDocs` | scheduled hourly | us-central1 | **Yes** |
| `cleanupExpiredAudio` | scheduled | us-central1 | **Yes** (chat audio vacuum) |

Source: `functions/index.js`, `functions/sign_document_sync.js`, `functions/audio_vacuum.js`

---

## `onNewChatMessage` behavior (Hub must stay compatible)

**Trigger:** new doc at `chats/{chatId}/messages/{messageId}`

**Does:**
1. Reads `chats/{chatId}.member_ids`
2. Skips sender
3. Honors mute:
   - `users/{uid}.chat_notifications_muted === true` (global)
   - `userChats/{uid}/chats/{chatId}.muted === true` (per chat)
   - `chats/{chatId}/members/{uid}.muted === true` (member)
4. Collects tokens from `users/{uid}/fcm_tokens/*`
5. Sends FCM with data payload:
   - `type: chat_message`, `chat_id`, `chat_title`, `sender_id`, `message_id`, …
6. Removes invalid/unregistered tokens
7. Updates recipient `userChats/{uid}/chats/{chatId}` → `updated_at`, `has_messages: true`

**Hub implication:** store web FCM tokens in the **same path** as mobile. Same function will notify web clients.

---

## Signable documents

| Function | Role |
|----------|------|
| `onSignableDocumentUpdated` | Syncs `users/{owner}/signature_documents`, notifies next signer / requester on sign progress |
| `cleanupExpiredSignableDocs` | Hourly cleanup of expired unsigned `signable_doc` messages + Storage PDF |

Hub must use the same message fields (`sign_status`, `signature_document_id`, etc.) — see `docs/hub_chat_contract.md`.

---

## Web FCM + VAPID (optional for Hub v1)

### Required for real-time chat in open Hub tab
**No** — Firestore listeners are enough.

### Required for browser push (background / closed tab)
**Yes**

**Hub setup:**
1. Register service worker: `firebase-messaging-sw.js`
2. Request notification permission in browser
3. Call `getToken(messaging, { vapidKey: '<PUBLIC_VAPID_KEY>' })`
4. Save token to: `users/{uid}/fcm_tokens/{token}` (same as mobile)

**Where to get public VAPID key (owner):**
Firebase Console → **elrace-new** → Project settings → **Cloud Messaging** → **Web configuration** → **Key pair**

Send Hub the **public key only**. Never send service account JSON or private keys.

**Note:** Mobile repo does not store the VAPID key (Console-only). Owner must copy from Console when Hub enables web push.

---

## Hub token storage contract

```text
users/{firebase_uid}/fcm_tokens/{token}
```

Document fields (mobile convention — merge-friendly):
- `platform`: `web` | `android` | `ios`
- `updated_at`: server timestamp
- Optional: `user_agent`, `app_version`

On logout: delete the web token doc for that browser session.

---

## What Hub should NOT do

- Do not deploy or modify Cloud Functions without mobile/Firebase owner approval
- Do not create a parallel push pipeline for chat (unless explicitly scoped later)
- Do not put private FCM / service-account credentials in Hub frontend

---

## Owner deploy reference

```bash
# Chat + related (main functions codebase)
firebase deploy --project elrace-new --only \
  functions:onNewChatMessage,functions:onSignableDocumentUpdated,functions:cleanupExpiredSignableDocs,functions:cleanupExpiredAudio
```

See also: `doc/FIREBASE_GAE_AND_DEPLOY.md`

---

## Related docs

- Chat contract: `docs/hub_chat_contract.md`
- Rules: `docs/hub_firebase_rules_and_indexes.md`
