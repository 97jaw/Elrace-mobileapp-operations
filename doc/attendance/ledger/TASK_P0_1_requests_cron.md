# TASK P0_1 — Deactivate the broken requests cron

Repo `odoo14-clients`, branch `elrace-addons`, module `cubes_biotime`.

## Problem

`cubes_biotime/data/cron.xml` record `ir_cron_biotime_requests` ("BioTime — Employee Requests Processor
(15 min)") runs `model.cron_process_requests()` on `biotime.config`. That method does not exist (only
`backup_cron_process_requests` in `models/attendance_sync.py`), so the job errors every 15 minutes.

Do NOT point it at `backup_cron_process_requests`: JM / TP / leave rows are already written by the Lambda,
and running the old processor too would create more duplicate rows.

## Change

1. In `cron.xml`, set `<field name="active" eval="False"/>` on `ir_cron_biotime_requests` and add a
   comment: "Requests are processed by the Lambda sync; kept inactive. See attendance ledger plan."
2. Bump `cubes_biotime/__manifest__.py` version `1.0.1` → `1.0.2`.

## Deploy note (for the user)

If the cron record is `noupdate` in the database, the upgrade will not change it. After upgrading, check
Settings → Technical → Scheduled Actions → "BioTime — Employee Requests Processor (15 min)" and untick
Active by hand if needed.

## Done when

- The scheduled action is inactive after upgrade.
- No other cron in `cron.xml` changed.
