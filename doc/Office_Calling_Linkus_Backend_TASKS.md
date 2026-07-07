# Office Calling (Linkus SDK) — Backend | Cursor Task File

> **How to use this file:** Read it top to bottom before touching any code. Then read the companion document: `linkus-sdk-guide-appliance-edition-en.pdf`. Then start at Task F.0 and work top to bottom. Never skip ahead. Update task status as you go.

---

## 0. About This Work

You are extending the existing **`elrace_backend_apis`** module (Odoo) for **Pandora Tech LLC**. This task file covers the **BACKEND** half of integrating in-app office calling via the **Yeastar Linkus SDK**.

### The feature in one sentence
The company runs a Yeastar P-Series PBX (office phone system). Staff have PBX extensions. We want the existing Flutter mobile app to make and receive office calls — turning the app into a softphone extension on that PBX.

### Backend responsibility (this file)
The mobile app cannot talk to the PBX directly for authentication — that would expose secret credentials. The backend is the secure broker:
1. Holds the PBX `AccessID` / `AccessKey` secrets (never exposed to the app)
2. Exchanges them for a PBX `access_token`
3. Requests a per-extension **login signature** from the PBX
4. Returns ONLY the login signature + connection info to the app
5. Maintains the mapping between app users and PBX extensions

### Mobile responsibility (separate task file)
The Flutter app uses the login signature to log into the Linkus SDK and make/receive calls. Covered in `Office_Calling_Linkus_Mobile_TASKS.md`.

---

## 1. ⚠️ CRITICAL PRECONDITION — verify before ANY code

The Linkus SDK has hard requirements. If these are not met, **the entire feature is blocked** and there is no point writing code.

| Requirement | Needed |
|-------------|--------|
| PBX Firmware | `37.12.0.23` or later |
| PBX Plan / License | **Ultimate Plan (UP)** — mandatory |
| Linkus SDK enabled on PBX | Toggle in PBX web portal: Integrations > Linkus SDK |
| Push certificates bound on PBX | Firebase (Android) + APNs (iOS) — for incoming call notifications |
| AccessID + AccessKey | Generated in PBX web portal: Integrations > Linkus SDK |

**Task F.0 below is to confirm all of these. Do not proceed past F.0 until confirmed by the PBX administrator.**

---

## 2. Critical Rules (NEVER violate these)

| Rule | Reason |
|------|--------|
| **AccessID / AccessKey NEVER leave the backend** | They are master credentials. If leaked, anyone can impersonate any extension. |
| **The app receives ONLY the login signature** | Per-extension, optionally time-limited. Safe to send to the device. |
| **AccessID/AccessKey stored in Odoo System Parameters or env, never in code** | Secrets must not be committed to git. |
| **access_token has a short life — handle refresh** | Token expires (~1800s). Use refresh_token before it expires. |
| **Map app user to extension server-side** | The app must never choose its own extension — backend decides based on the authenticated user. |
| **All endpoints require the app's existing Bearer auth** | Reuse the existing mobile auth. A user can only get a signature for THEIR OWN extension. |
| **One commit per task** | Format: `feat(office-call): <TASK_ID> <description>` |
| **Never log signatures, tokens, AccessKey** | Sensitive. Log only metadata. |

---

## 3. Architecture

```
PBX ADMIN (one-time, manual)
   Enables Linkus SDK in PBX portal
   Generates AccessID + AccessKey
   Binds Firebase + APNs push certificates
        │
        ▼
BACKEND (elrace_backend_apis) stores AccessID/AccessKey as secrets
        │
        ▼
─────────────────────────────────────────────────────────────
RUNTIME — when a user wants to enable calling on the app:

  Mobile app  ──(Bearer auth)──►  Backend: POST /api/office_call/credentials
        │                              │
        │                              ▼
        │                    Backend resolves user → extension
        │                              │
        │                              ▼
        │                    Backend → PBX OpenAPI:
        │                      1. POST /openapi/v1.0/get_token
        │                         (AccessID + AccessKey → access_token)
        │                      2. POST /openapi/v1.0/sign/create
        │                         (access_token + extension → login signature)
        │                              │
        │                              ▼
        │                    Backend caches access_token (until expiry)
        │                              │
        ◄──────────────────────────────┘
   Response: { extension, signature, pbx_lan_ip, pbx_lan_port,
               pbx_public_ip, pbx_public_port }
        │
        ▼
  App logs into Linkus SDK with the signature (mobile task file)
─────────────────────────────────────────────────────────────
```

---

## 4. Module Structure

```
elrace_backend_apis/
├── __manifest__.py
├── models/
│   ├── __init__.py
│   ├── res_users.py            ← NEW: add pbx_extension field (the mapping)
│   └── pbx_config.py           ← NEW: optional — PBX config helper model
├── controllers/
│   ├── __init__.py
│   └── office_call_controller.py   ← NEW: /api/office_call/* endpoints
├── services/
│   ├── __init__.py
│   ├── pbx_openapi_client.py   ← NEW: talks to Yeastar PBX OpenAPI
│   └── pbx_token_cache.py      ← NEW: caches access_token, handles refresh
├── data/
│   └── pbx_config_params.xml   ← NEW: System Parameter definitions (no secrets)
└── README.md                    ← UPDATE
```

Secrets (`AccessID`, `AccessKey`) are stored as Odoo `ir.config_parameter` values set manually by an admin — NOT in the XML, NOT in git.

---

## 5. Functional Knowledge

### 5.1 PBX OpenAPI — the two calls the backend makes

**Call 1 — Get access token**
```
POST {pbx_base_url}/openapi/v1.0/get_token
Content-Type: application/json
{ "username": "<AccessID>", "password": "<AccessKey>" }

Response:
{ "errcode": 0, "errmsg": "SUCCESS",
  "access_token": "...", "access_token_expire_time": 1800,
  "refresh_token": "...", "refresh_token_expire_time": 86400 }
```

**Call 2 — Create login signature for an extension**
```
POST {pbx_base_url}/openapi/v1.0/sign/create?access_token=<access_token>
Content-Type: application/json
{ "username": "<extension_number>", "sign_type": "sdk", "expire_time": 0 }

Response:
{ "errcode": 0, "errmsg": "SUCCESS", "data": { "sign": "<login_signature>" } }
```
`expire_time: 0` = signature never expires. Consider a real expiry for security (see §5.4).

### 5.2 Token lifecycle
- `access_token` lives ~1800 seconds (30 min)
- `refresh_token` lives ~86400 seconds (24 h)
- Backend should CACHE the access_token and reuse it across requests (don't call get_token every time)
- When access_token is near expiry, use refresh_token to get a fresh pair
- If refresh_token also expired, fall back to full get_token with AccessID/AccessKey

### 5.3 User → extension mapping
- Each app user must be linked to exactly one PBX extension number
- Add a field `pbx_extension` on `res.users` (or on the employee/contact model the app already uses for users)
- Also useful: `pbx_call_access` selection — 'internal_only' vs 'anywhere' (see §5.5)
- The signature request uses this extension; the app NEVER sends its own extension

### 5.4 Signature expiry strategy
- `expire_time: 0` (never expires) is simplest but least secure
- Recommended: issue signatures with a finite expiry (e.g., 12 hours) and let the app re-request when needed
- The app should call /credentials again when its signature is rejected/expired
- Decision to confirm with architect — default to 12h expiry

### 5.5 Mixed connection access (internal vs anywhere)
The company has two user types:
- **Internal-only users** — use the app for calls only inside the office network. They connect to the PBX **LAN IP** (`localeIp`).
- **Anywhere users** — can call from outside the office. They connect to the PBX **public IP** (`remoteIp`).

The backend stores both PBX addresses and, based on the user's `pbx_call_access` value, returns the appropriate connection info. For 'anywhere' users return both LAN + public so the SDK can pick whichever reachable; for 'internal_only' return only LAN.

### 5.6 What the /credentials endpoint returns
```json
{
  "success": true,
  "data": {
    "extension": "1001",
    "display_name": "Ahmed Al-Rashid",
    "signature": "<linkus sdk login signature>",
    "pbx_lan_ip": "192.168.5.150",
    "pbx_lan_port": 5060,
    "pbx_public_ip": "203.0.113.10",
    "pbx_public_port": 5060,
    "access_mode": "anywhere",
    "signature_expires_at": "2026-05-25T20:00:00Z"
  }
}
```
For internal_only users, public IP fields are null.

---

## 6. Tasks (work top to bottom)

> **Status legend:** `[TODO]` `[IN_PROGRESS]` `[DONE]` `[BLOCKED]` `[NEEDS_REVIEW]`

---

### Phase 0 — Preconditions

#### `[TODO]` F.0 — Verify PBX preconditions ⚠️ BLOCKER
With the PBX administrator, confirm and record in §10:
- [ ] PBX firmware is `37.12.0.23` or later
- [ ] PBX has **Ultimate Plan (UP)** license
- [ ] Linkus SDK is ENABLED in PBX portal (Integrations > Linkus SDK)
- [ ] `AccessID` and `AccessKey` generated and provided securely
- [ ] Firebase push certificate bound on PBX (for Android incoming calls)
- [ ] APNs push certificate bound on PBX (for iOS incoming calls)
- [ ] PBX LAN IP + port recorded
- [ ] PBX public IP + port recorded (if anywhere-access is needed)
- [ ] PBX OpenAPI base URL recorded

**If ANY of the first three are not met → STOP. The feature cannot be built. Report to the architect.**

**Definition of done:** All items confirmed and recorded. AccessID/AccessKey received securely (not via chat/email in plaintext ideally).

#### `[TODO]` F.1 — Store PBX secrets and config
- Add System Parameters via admin UI (NOT in git):
  - `pbx.access_id` — the AccessID (secret)
  - `pbx.access_key` — the AccessKey (secret)
- Add config parameters via `data/pbx_config_params.xml` (safe, non-secret):
  - `pbx.base_url` — OpenAPI base URL
  - `pbx.lan_ip`, `pbx.lan_port`
  - `pbx.public_ip`, `pbx.public_port`
  - `pbx.signature_expiry_seconds` — default 43200 (12h)
- Document in README how an admin sets the secret parameters

**Definition of done:** Config readable via `ir.config_parameter`. Secrets set manually, not in code.

---

### Phase 1 — User-Extension Mapping

#### `[TODO]` M.1 — Add pbx_extension field
- Decide which model represents an app user (likely `res.users` or the existing user model the mobile app authenticates against — confirm in F.0)
- Add fields:
  - `pbx_extension` (Char) — the PBX extension number for this user
  - `pbx_call_access` (Selection: 'internal_only', 'anywhere') — default 'internal_only'
  - `pbx_call_enabled` (Boolean) — whether calling is enabled for this user, default False
- Add to the user form view (admin only) so HR/admin can set extensions
- Add a list filter "Has PBX Extension"

**Definition of done:** Admin can assign an extension + access mode to a user.

#### `[TODO]` M.2 — Bulk extension assignment helper
- The company has existing users + existing extensions but no mapping
- Provide a way to bulk-assign — either:
  - A CSV import (extension, user_email) → sets pbx_extension, OR
  - A simple admin server action
- Document the process in README
- This is a one-time data setup, but make it repeatable

**Definition of done:** Admin can map all existing users to extensions in one operation.

---

### Phase 2 — PBX OpenAPI Client

#### `[TODO]` P.1 — PBX OpenAPI client service
- Create `services/pbx_openapi_client.py`
- Method `get_token() -> dict`:
  - Reads AccessID/AccessKey from System Parameters
  - POSTs to `{base_url}/openapi/v1.0/get_token`
  - Returns access_token, refresh_token, and their expiry times
  - Raises a clear exception on errcode != 0
- Method `refresh_token(refresh_token) -> dict`:
  - Uses refresh_token to get a new token pair
- Method `create_signature(access_token, extension, expire_time) -> str`:
  - POSTs to `{base_url}/openapi/v1.0/sign/create?access_token=...`
  - Returns the signature string
  - Raises clear exception on failure
- All HTTP calls: timeout 10s, handle network errors gracefully
- Never log AccessKey, tokens, or signatures

**Definition of done:** Each method works against the real PBX. Manual test: get_token returns a token, create_signature returns a signature for a known extension.

#### `[TODO]` P.2 — Token cache service
- Create `services/pbx_token_cache.py`
- Caches the current access_token + refresh_token + expiry timestamps
  - Store in `ir.config_parameter` or a small dedicated model — NOT in memory only (Odoo has multiple workers)
- Method `get_valid_access_token() -> str`:
  1. If cached access_token still valid (with a safety margin, e.g., 60s) → return it
  2. Else if refresh_token still valid → refresh, cache new pair, return
  3. Else → full get_token, cache, return
- Thread-safe enough for Odoo's multi-worker model (use a row lock when refreshing)

**Definition of done:** Repeated calls reuse the cached token. Token auto-refreshes near expiry. Verified by forcing expiry in a test.

---

### Phase 3 — Mobile-Facing Endpoint

#### `[TODO]` A.1 — POST /api/office_call/credentials
- Create `controllers/office_call_controller.py`
- Endpoint: `POST /api/office_call/credentials`
- Auth: the app's existing Bearer token (reuse existing decorator/middleware)
- Logic:
  1. Resolve the authenticated user
  2. Check `pbx_call_enabled` — if False → 403 with message "Calling not enabled for this account"
  3. Read the user's `pbx_extension` — if empty → 409 with message "No extension assigned"
  4. Get a valid access_token from the token cache service
  5. Call `create_signature(access_token, extension, expiry)`
  6. Build the response per §5.6 — include LAN always, public only if access_mode = 'anywhere'
  7. Return the response
- Handle PBX errors gracefully → 503 with retry guidance
- Never include AccessID/AccessKey in the response

**Definition of done:** Endpoint returns a valid signature + connection info for the authenticated user. Tested with an internal_only user and an anywhere user — connection fields differ correctly.

#### `[TODO]` A.2 — POST /api/office_call/refresh_signature
- Same as A.1 but intended for when the app's signature expired
- Can literally reuse A.1's logic — provide this as a separate route for clarity, or document that the app just calls /credentials again
- Decision: if A.1 is idempotent and cheap, a separate endpoint may be unnecessary. Confirm and either implement or document.

**Definition of done:** App has a clear way to get a fresh signature when the old one expires.

#### `[TODO]` A.3 — GET /api/office_call/directory
- The app shows a call button on chat. To call someone, the app needs that person's extension.
- Endpoint: `GET /api/office_call/directory`
- Returns the list of users who have `pbx_extension` set and `pbx_call_enabled = true`:
  ```json
  { "success": true, "data": [
    { "user_id": 12, "display_name": "Ahmed Al-Rashid", "extension": "1001" },
    ...
  ] }
  ```
- The app uses this to resolve "the person in this chat" → their extension
- Auth: existing Bearer token
- Consider caching — this list changes rarely

**Definition of done:** App can fetch the directory and map a chat participant to an extension.

#### `[TODO]` A.4 — Error handling and security review
- All endpoints return standard error envelopes (401 / 403 / 409 / 503)
- Confirm: a user can only ever get a signature for THEIR OWN extension — never another user's
- Confirm: AccessID/AccessKey never appear in any response or log
- Rate limit `/credentials` (e.g., 20/min/user) — signatures shouldn't be requested in a loop

**Definition of done:** Security review checklist passed. No credential leakage. Users isolated.

---

### Phase 4 — Verification

#### `[TODO]` V.1 — End-to-end backend test
- With a real test user mapped to a real test extension:
  - Call `/api/office_call/credentials` → get signature + connection info
  - Verify the signature is non-empty
  - Verify token caching: call again → second call should NOT hit get_token (check logs)
  - Call `/api/office_call/directory` → returns mapped users
- Hand the signature to the mobile team for their integration test

**Definition of done:** Backend produces a usable signature. Mobile team can log into the SDK with it.

#### `[TODO]` V.2 — Token refresh test
- Force the cached access_token to be expired
- Call `/credentials` → backend should auto-refresh and still succeed
- Force both tokens expired → backend should full re-auth and succeed

**Definition of done:** Token lifecycle is robust.

#### `[TODO]` V.3 — Access-mode test
- Internal_only user → response has LAN fields, public fields null
- Anywhere user → response has both LAN and public fields

**Definition of done:** Connection info correctly differentiated by access mode.

---

### Phase 5 — Documentation

#### `[TODO]` H.1 — Update README
- Document the new endpoints with request/response examples
- Document how an admin sets PBX secrets (System Parameters)
- Document the bulk extension assignment process
- Document the token-cache behavior
- Note the PBX preconditions (Ultimate Plan, firmware)

**Definition of done:** README complete. Another developer could operate the feature from it.

---

## 7. Anti-patterns (do NOT do these)

| Anti-pattern | Why wrong | Do instead |
|--------------|-----------|-----------|
| Returning AccessID/AccessKey to the app | Master credential leak — total compromise | App gets only the per-extension signature |
| Calling get_token on every request | Slow, hammers the PBX | Cache the access_token, refresh near expiry |
| Letting the app send its own extension | A user could request a signature for someone else's extension | Backend resolves extension from the authenticated user |
| Storing secrets in git / XML data files | Secrets end up in version control | System Parameters set manually by admin |
| Logging signatures or tokens | Sensitive data in logs | Log only metadata (user id, success/fail) |
| expire_time 0 everywhere | Signatures never expire — long-lived risk | Finite expiry; app re-requests |
| Building before F.0 confirmed | Wasted work if PBX lacks Ultimate Plan | F.0 is a hard gate |

---

## 8. Definition of Backend Complete

- [ ] F.0 preconditions all confirmed
- [ ] PBX secrets stored securely, not in git
- [ ] User → extension mapping field + bulk assignment done
- [ ] PBX OpenAPI client works (get_token, refresh, create_signature)
- [ ] Token cache works and auto-refreshes
- [ ] /api/office_call/credentials returns signature + connection info
- [ ] /api/office_call/directory returns mappable user list
- [ ] Internal vs anywhere access correctly differentiated
- [ ] Security review passed — no credential leakage, users isolated
- [ ] Mobile team confirmed they can log into the SDK with the signature
- [ ] README updated
- [ ] Decisions Log §10 complete

---

## 9. Open Questions for Architect / PBX Admin

- Confirm PBX firmware + Ultimate Plan (F.0 — blocker)
- Which model represents the app user (res.users? a custom model?)
- Signature expiry: finite (recommended 12h) or never-expire?
- Is a separate /refresh_signature endpoint wanted, or just re-call /credentials?
- Should the directory endpoint be filtered (e.g., only same-department users) or all users?

---

## 10. Decisions Log

```
[YYYY-MM-DD] TASK_ID — Decision: <what>. Rationale: <why>.
```

### F.0 confirmations (fill in)
- [ ] PBX firmware: __________
- [ ] Ultimate Plan: YES / NO
- [ ] Linkus SDK enabled: YES / NO
- [ ] PBX OpenAPI base URL: __________
- [ ] PBX LAN IP : port: __________
- [ ] PBX public IP : port: __________
- [ ] App user model: __________
- [ ] Signature expiry policy: __________

— End of Backend Task File —
