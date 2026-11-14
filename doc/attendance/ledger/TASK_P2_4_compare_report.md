# TASK P2_4 — Compare report

Module `elrace_attendance_ledger`, AbstractModel `elrace.attendance.compare`. Depends on P2_2.

## What it compares

For each shadow day in the range, the `hr.attendance` rows of the same employee whose `check_date` equals
`day_date` (today's rows, written by the Lambda and the mobile API).

Set on the shadow day:

| `compare_status` | When |
| --- | --- |
| `no_odoo_row` | shadow is not `off` / `holiday` / `not_yet`, and there is no `hr.attendance` row |
| `duplicate_odoo_rows` | more than one `hr.attendance` row |
| `only_odoo_row` | shadow is `off` / `holiday` / `not_yet` but an `hr.attendance` row exists (other than `absent`) |
| `match` | one row, same meaning: type maps (table below), in/out equal to the minute (or both empty) |
| `diff` | one row, anything else |

Type map shadow → `hr.attendance.x_attendance_type`: `present` → `normal` or `mobile`; `absent` →
`absent`; `leave` → any leave type (`short`, `sick`, `death`, `annual`, `maternity`, `parental`,
`compensation`); `jm_full` / `jm_half` → `jm_morning` / `jm_afternoon` / `jm_full_day`.

`compare_reason` — short, human-readable, the first that applies, e.g.:
`"Odoo has 2 rows: jm_morning, normal"`, `"Odoo absent, punches exist (gate 08:04)"`,
`"Odoo check-in 08:00 (policy), punches 07:52"`, `"Odoo missing check-out, last punch 17:12"`,
`"Odoo leave row missing (approved leave)"`, `"punch 12:40 dropped by sync window"`,
`"Odoo absent on approved leave"`. Keep the list of reasons in one dict so they can be grouped.

## Output

1. The fields on `elrace.attendance.day` (`compare_status`, `compare_reason`, `odoo_attendance_ids`).
2. A summary per day stored on a small model `elrace.attendance.compare.run` (date, counts per status, top
   10 reasons with counts, duration). One row per nightly run.
3. Log line per run: `"[Compare] 2026-11-05: match=480 diff=21 no_odoo_row=3 duplicate=12 only_odoo=0"`.

No email, no notification in this phase.

## SQL for the user (put in the task report, read-only)

```sql
SELECT day_date, compare_status, COUNT(*) FROM elrace_attendance_day
WHERE day_date >= CURRENT_DATE - 7 GROUP BY 1, 2 ORDER BY 1, 2;

SELECT compare_reason, COUNT(*) FROM elrace_attendance_day
WHERE day_date >= CURRENT_DATE - 7 AND compare_status <> 'match'
GROUP BY 1 ORDER BY 2 DESC LIMIT 30;
```

## Tests

One test per `compare_status`, and the reason text for: duplicate rows, absent with punches, missing
check-out, leave missing.
