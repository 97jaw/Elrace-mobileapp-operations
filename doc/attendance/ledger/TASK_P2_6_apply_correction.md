# TASK P2_6 — Apply the shadow day records to `hr.attendance` (correction from 1 Oct 2026)

Module `elrace_attendance_ledger`. Worktree `.worktrees/elrace-addons`, branch `elrace-addons`, author
M Jawad, no co-author. No commit until reviewed. Depends on P2_0 (employee sync), P2_5 (Attendance 360,
remap, mobile backfill).

## Goal

Make `hr.attendance` the corrected master: exactly ONE row per staff employee per working date, built from
the shadow day (`elrace.attendance.day`), for a closed date range (first use: 2026-10-01 → today − 2 days).
Safe to re-run any time rules change: every run is dry-run first, backed up, logged and reversible.

## Model `elrace.attendance.correction.run`

Fields: `name`, `date_from`, `date_to`, `employee_ids` (optional M2M, empty = all staff), `dry_run`,
`state` (draft / dry_run_done / applied / rolled_back / failed), `user_id`, counters (`days`, `created`,
`updated`, `deleted`, `unchanged`, `skipped`), `log_text` (plain sentences, like the employee sync log),
`line_ids` (one line per employee-day changed), `rule_version` of the shadow rows used.

Line model `elrace.attendance.correction.line`: `run_id`, `employee_id`, `day_date`, `action`
(create / update / delete_extra / unchanged / skip), `before_json` (all rows of that employee-day as they
were: every stored field incl. id, type, in/out, request, terminal, lat/lng), `after_json`, `attendance_id`
(the row kept/created), `reason`.

## Rules for one employee-day

1. Take the shadow day. Skip (action `skip`, reason) when: `state` is not `final`; day is newer than
   today − 2; `day_type` in (`not_yet`); employee has `wrong_tz`; shadow `state == error`.
2. `off` / `holiday` with no punches → there must be NO `hr.attendance` row: delete existing rows (backed up).
3. Every other day type → exactly one row. Pick the row to keep: the one the payroll engine would pick
   (latest write) — update it; delete the others. If none, create one.
4. Values written (map shadow → `hr.attendance`):
   - `present` → `x_attendance_type` = `mobile` if the in-punch is mobile, else `normal`; `check_in` /
     `check_out` from the shadow (UTC); `x_terminal` = in/out devices; GPS fields when the punch has them.
   - `absent` → `absent`, `check_in` = 08:00 local of the day (Odoo needs a check_in), no check_out.
   - `leave` → the leave type key the engine expects (`short`, `sick`, `annual`, …), `x_request_id` = the
     leave's request, `x_leave_days` as today, `check_in` 08:00 local.
   - `jm_full` / `jm_half` → `jm_full_day` / `jm_morning` / `jm_afternoon`, `x_request_id`, `x_jm_hours`,
     in/out as the shadow (policy + punches).
   - TP days → `temp_permission` with `x_tp_hours` and `x_request_id`, in/out from the punches.
   - Always set `check_date` explicitly and a new Boolean `x_corrected` = True, `x_correction_run_id`.
5. Write with `tracking_disable`, `mail_notrack`; never trigger the Lambda; respect `check_validity`
   overrides already in the codebase.
6. Batch per employee-month, commit per chunk (like the nightly cron), advisory lock so two runs never
   overlap, and the BioTime sync lease (P1) taken for the whole apply so the Lambda cannot write meanwhile.

## Dry run, apply, rollback

- `action_dry_run()` → fills counters, lines and `log_text`; writes NOTHING to `hr.attendance`.
- `action_apply()` → only from `dry_run_done`, only by `base.group_system`; re-computes (data may have changed
  since the dry run) and applies; state `applied`.
- `action_rollback()` → restores every line from `before_json`: re-create deleted rows (new ids, same values),
  revert updated rows, delete created rows; state `rolled_back`. Log it.
- Menu: **Biotime → Attendance Audit → Corrections** (tree + form with counters, log, lines; buttons Dry run /
  Apply / Rollback). System group only.

## Afterwards

- Re-run `compare.run(date_from, date_to)`: every applied day must be `match`; report any that are not.
- From then on the Lambda's backdate/EOD keep running for new days; the correction can be repeated for
  any range (e.g. weekly) until Phase 4 makes the resolver the only writer.

## Tests

- Duplicate rows for one day → one kept (the engine's pick), others deleted, before_json has all of them.
- Absent with punches in the ledger → becomes present with the right in/out.
- Leave day with an `absent` row → becomes the leave type.
- Off day with a stray row → row deleted.
- Dry run writes nothing; apply twice changes nothing the second time; rollback restores exactly.
- Days newer than today − 2 and `wrong_tz` employees are skipped.
