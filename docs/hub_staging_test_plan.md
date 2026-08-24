# Hub Chat — Staging test plan (Step 6)

Provide **two staging users** who exist on **both Mobile and Hub** with a valid Odoo link.

---

## Required per test user

| Field | Example |
|-------|---------|
| Hub login | SSO or QR (normal Hub auth) |
| Mobile login | Same employee, active mobile account |
| Hub `users.source_id` | Odoo `res.users.id` e.g. `123` |
| Expected Firebase UID | `odoo_123` |
| Permission | DM, role group, support, project chats |

---

## Test user template (fill and send to Hub)

### User A
- Name:
- Hub email/login:
- Mobile login:
- `source_id`:
- Firebase UID:
- Role/branch (for role chat):

### User B
- Name:
- Hub email/login:
- Mobile login:
- `source_id`:
- Firebase UID:
- Role/branch:

---

## Test matrix (Hub + mobile owner run together)

| # | Scenario | Pass |
|---|----------|------|
| 1 | Mobile → Hub text message | ☐ |
| 2 | Hub → Mobile text message | ☐ |
| 3 | Image upload both directions | ☐ |
| 4 | Audio / file both directions | ☐ |
| 5 | Signable document send + sign | ☐ |
| 6 | Read/unread (`last_read_at`) | ☐ |
| 7 | Presence online/offline | ☐ |
| 8 | Typing indicator | ☐ |
| 9 | Push notification (mobile) | ☐ |
| 10 | Push notification (Hub web, if VAPID enabled) | ☐ |
| 11 | Logout / account switch (no token bleed) | ☐ |
| 12 | Microsoft SSO + QR login before/after chat | ☐ |
| 13 | DM room id matches `dm_{min}_{max}` | ☐ |
| 14 | Support room opens existing mobile thread | ☐ |

---

## Gate

Hub Chat feature flag stays **OFF** until Steps 1–5 pass and this matrix is green on staging.

Owner: **Elrace mobile/Firebase/Odoo team** supplies users; **Hub team** runs Hub-side tests.
