# Attendance ledger — Phase 0 + Phase 1

Design and full phase plan: https://claude.ai/artifact/VnYdD3J4Md7XKjncijpAbg

Goal of these two phases: capture every attendance punch (BioTime gate + mobile) exactly once in a new
ledger, without changing anything that payroll, HR or the mobile user sees today.

## Where the work goes

| Repo | Branch |
| --- | --- |
| `odoo14-clients` | `elrace-addons` (no new branch) |
| `Elrace-mobileapp-operations` | no app change in Phase 0/1; existing branches untouched |
| `biotime_lambda` | `main`, created in TASK_P0_3 from the deployed copy of 4 Nov |

## Tasks, in order

| Task | Repo | What | Behaviour change |
| --- | --- | --- | --- |
| [TASK_P0_1](TASK_P0_1_requests_cron.md) | Odoo | Deactivate the broken `cron_process_requests` scheduled action | None (it errors today) |
| [TASK_P0_2](TASK_P0_2_duplicate_report.sql) | DB, read-only | Size the duplicate rows | None |
| [TASK_P0_3](TASK_P0_3_lambda_git_secrets.md) | Lambda | Put the deployed code in git, remove hard-coded Odoo credentials | None, after the password is rotated |
| [TASK_P1_1](TASK_P1_1_odoo_punch_ledger.md) | Odoo | New module `elrace_attendance_ledger`: punch model + ingest method + flag | None (flag OFF) |
| [TASK_P1_2](TASK_P1_2_mobile_api_punch.md) | Odoo | Mobile check-in / check-out also store a punch | None (flag OFF; never blocks check-in) |
| [TASK_P1_3](TASK_P1_3_lambda_push_punches.md) | Lambda | Send every BioTime transaction to the ledger | None (flag OFF; never fails the sync) |

## Rules for every task

- Odoo work on `elrace-addons` only. Do not create, switch or delete branches. The user commits and pushes.
- New behaviour behind `ir.config_parameter` `attendance.ledger_enabled` (default `False`).
- Do not change how `hr.attendance` rows are created, updated or read in this phase.
- No new menus or screens. No secrets in code or XML.
- A ledger failure must never fail a mobile check-in or a Lambda sync: catch, log, continue.

## Phase 1 exit gate

For 5 working days with the flag ON: every BioTime transaction and every mobile tap is in
`elrace.attendance.punch` exactly once (check with the queries at the end of TASK_P1_1).
