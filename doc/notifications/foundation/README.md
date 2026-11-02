# Notifications Foundation v2 — Technical Plan

**Date:** 29 October 2026
**Owner:** M Jawad (Odoo + mobile)
**Implementation:** Cursor agents (backend, mobile, Firebase)

## Why

Today a notification is defined in three places (Odoo senders, Firebase functions, the app),
stored in three inboxes, sent to two token registries, and routed on tap by hard-coded
`if/else` in Flutter. Adding a trigger or changing a text means code changes, and opening a
record on tap means a Flutter release every time.

Foundation v2 makes notifications **data-driven and centralised**:

- one dispatcher in Odoo (`elrace_notify`) that every trigger calls;
- notification types (channel, template, tap action, rules) stored as **records**, editable without deploy;
- one versioned payload contract;
- one device registry (all devices, cleared on logout);
- one server inbox (90 days, search, filter, hide-on-clear);
- a **generic router** in Flutter (`model → screen` registry).

After the foundation, a new trigger = **Odoo config row + one `emit()` call**. A Flutter release
is needed only when a notification must open a screen that does not exist yet.

## Files

| File | Purpose |
|---|---|
| `01_ARCHITECTURE.md` | Target design, data model, payload contract, flags, decisions |
| `02_TRIGGER_MATRIX.md` | Manager's revised matrix (28 Oct) mapped to type codes, sources, recipients and legacy items retired |
| `03_ROLLOUT_AND_TESTING.md` | Phases, deploy order, rollback, test plan |
| `tasks/BACKEND.md` | Cursor tasks — Odoo (`odoo14-clients`) |
| `tasks/MOBILE.md` | Cursor tasks — Flutter app (this repo) |
| `tasks/FIREBASE.md` | Cursor tasks — Cloud Functions (`functions/`, `functions-assignment/`) |

## Source documents

- `../Elrace_Notifications_Guide.pdf` — current behaviour (15 Oct)
- `../Elrace_Notifications_Inside_Outside_Updated.docx` — manager's target matrix (28 Oct) — **the target**
- `../NOTIFICATIONS_CATALOGUE_AND_TRIGGERS.md` — legacy trigger catalogue with file/line references (IDs like `HR-1`, `AP-3` are used in this plan)
- `../NOTIFICATIONS_MANAGER_REVISION_GAP.md` — gap check of target vs code

## How to run this with Cursor

1. Give each agent `01_ARCHITECTURE.md` + `02_TRIGGER_MATRIX.md` + its own task file.
   The backend agent works in `odoo14-clients`; point it to this folder by absolute path.
2. Do tasks **in order**; each task lists scope, files, and acceptance criteria.
3. One task = one branch/PR. Jawad reviews, pushes and deploys.
4. Agents must not change anything outside the task's listed scope.

## Hard rules (apply to every task)

- Odoo: branch from `origin/elrace-addons`; backups (pointer branch + `pg_dump -Fc`) before deploy;
  `odoo -u <modules>` then **restart HTTP workers**. Never merge `staging-elrace` wholesale.
- Every new behaviour ships **OFF** behind a flag; enabling is a separate, scheduled step.
- **Zero live impact on deploy.** Pushing foundation code to `elrace-addons` and upgrading must not change
  anything a current app user sees or receives: no new mute categories visible, no changed text, no changed
  logout/token behaviour, no closed endpoints — until the matching flag is switched on.
- Secrets only in System Parameters. No secrets in code, logs, or payloads.
- Do not touch v1 SSO, `elrace_hub_guard`, or Hub auth flags.
- Legacy behaviour must keep working while a type is not taken over (old app versions are in the field).
- Diffs: additive, zero deletions of live code unless the task says "retire", no secrets.
