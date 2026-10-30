# 03 — Rollout, rollback and testing

## 1. Phases

| Phase | Work | Tasks | Behaviour change |
|---|---|---|---|
| 0. Prep | Confirm open decisions (matrix §5); create secrets (`elrace_notify.ingest_token`, FCM params); staging DB refresh | — | None |
| 1. Backend foundation | `elrace_notify` installed, all flags OFF | B1–B6 | **None** (verify) |
| 2. Mobile foundation release | Router, by-id loaders, device register/unregister, inbox v2 (dormant), channel handling | M1–M7 | Taps start working for legacy payloads that already carry `model` + `record_id` |
| 3. Switch on foundation | `elrace_notify.enabled=True` (no type active yet); `app_inbox_v2=True` once most users run the new build | — | Inbox v2, logout stops pushes |
| 4. Type migration waves | Activate type + `takeover`, staging first, then production | B7–B13, F1–F7 | Manager's matrix, wave by wave |
| 5. Cleanup | Remove legacy paths that have been taken over for ≥ 3 weeks | B14, M8 | None |

### Waves (phase 4)

| Wave | Types | Why first |
|---|---|---|
| A | `approval.waiting` (HR, LPO, petty cash, customer invoice), `hr.request.approved`, `hr.request.rejected` | Highest value; fixes duplicates and tap-to-approve |
| B | `purchase.lpo.issued`, `expense.petty_cash.paid`, `account.vendor_invoice` (none), `attendance.biotime_sync` (none), `hr.employee.assigned` | Small, isolated |
| C | `project.manager.assigned`, `project.member.added`, `document.expiry`, `circular.published` | Cron and fan-out — watch volume |
| D | Tasks, tickets, notes, signature (Firebase via ingest) + `server_task_notifications=True` | Needs Firebase deploy and the app flag |

## 2. Deploy steps

**Odoo** (each task/wave): branch from `origin/elrace-addons` → review diff (only listed modules, no deletions of live code, no secrets) → backup pointer branch + `pg_dump -Fc` → push to `elrace-addons` → server `git pull` → `odoo -i elrace_notify` (first time) or `-u <modules> --stop-after-init` → **restart HTTP workers** → smoke test.

**Firebase**: `firebase deploy --only functions:<names>`; secrets via `firebase functions:secrets:set` (never in code).

**App**: store release; record the build number that contains M1–M7 as the minimum for phase 3.

## 3. Rollback

| Problem | Action | Effect |
|---|---|---|
| One type misbehaves | Set that type's `takeover=False` (or `active=False`) | Legacy sender resumes at once, no deploy |
| Dispatcher problem | `elrace_notify.enabled=False` | All legacy senders resume |
| Inbox v2 problem | `elrace_notify.app_inbox_v2=False` | App returns to legacy inbox path on next resume |
| Firebase emit problem | Odoo type `takeover=False` → ingest returns `handled:false` → function uses its legacy send | No Firebase redeploy needed |
| App build problem | Server flags off; old behaviour in the new build is the legacy path | — |

## 4. Old app versions

- They still receive pushes (the `notification` block carries title/body) and keep `record_id`/`model` legacy keys.
- Their inbox (`/api/notifications`) reads the same `expo.notification.users` rows.
- They will not route taps and will still schedule local task reminders. With wave D, users of old builds may get a task reminder twice (local + server). Accept, or set a minimum app version before wave D.

## 5. Test plan

### 5.1 Automated (Odoo `TransactionCase`, in `elrace_notify/tests`)

- Flag off → `skipped_flag`; type inactive → skipped; takeover helper returns False.
- Labour recipient skipped; actor skipped; muted skipped; mandatory ignores mute.
- Dedupe: same `event_key` twice → one event `queued`, one `skipped_duplicate`.
- Template: missing placeholder renders empty; no `None`/`False` text.
- Channel `inbox` → inbox row, no delivery rows; `push` → delivery rows per active device, no inbox row; `both` → both.
- Device: token moved between users; logout clears; logged-out device gets no delivery row.
- `emit()` with a broken recipient never raises.
- Ingest: wrong token 403; valid token creates events.
- `open` preflight: allowed vs denied record.

### 5.2 Staging end-to-end (per wave)

For every type in the wave: trigger it → check recipient, device(s), channel, title, body, tap target, Notification Center row (or absence), Hub pending unchanged where `hub_category` is set.

### 5.3 Device matrix (phase 2 and wave A)

| Case | Expect |
|---|---|
| Android + iOS × foreground / background / killed | Banner rules per channel; tap opens the record |
| Logged in from sign-in screen (not splash) | Tap works without restart |
| Two phones, same user | Both receive |
| Log out on phone 1 | Phone 1 receives nothing; phone 2 still receives |
| Shared phone: A logs out, B logs in | Only B's notifications |
| Record access removed | Snackbar "no longer have access", nothing opens |
| Category muted / mandatory circular | Muted not shown; mandatory always shown |
| Labour user | Receives nothing |
| Clear All, then reopen | List empty; items still in DB (`is_hidden`) |
| Search / filter / 90 days | Works on server data |

### 5.4 Observability

`Settings → Technical → Notify Events` list view grouped by `state` and `type`. After each wave, check `failed`, `invalid_token`, `skipped_no_recipient` daily for one week.
