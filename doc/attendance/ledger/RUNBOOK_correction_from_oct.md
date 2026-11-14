# Runbook — from "IT done" to corrected attendance since 1 Oct 2026

Run top to bottom. Each step says how to check it before the next one.

## 0. Ready before IT says done
- [ ] P2_0 fix deployed (archived match not linked, final state in log header) — `-u cubes_biotime`.
- [ ] P2_5 (Attendance 360 + `remap_gate_punches` + `backfill_mobile_punches`) deployed — `-u elrace_attendance_ledger`.
- [ ] P2_6 (corrections) deployed — `-u elrace_attendance_ledger`.
- [ ] Lambda with `ledger_only` deployed (commit 789de1c or later).
- [ ] DB backup: `pg_dump -Fc <db> > before_correction_$(date +%F).dump`

## 1. Employee sync (after IT confirms BioTime is clean)
1. Biotime Config → Sync Employees → **dry run**. Read: DELETED, NEEDS ATTENTION, EX-EMPLOYEE STILL IN BIOTIME.
2. Fix the few wrong links by hand in Biotime → Employees (they lock automatically).
3. **Real run**. 4. Dry run again → 0 deleted, only accepted items left.
5. Check uniques: `SELECT conname FROM pg_constraint WHERE conrelid='biotime_employee'::regclass AND contype='u';`
   (2 rows; if not, `-u cubes_biotime` once more).

## 2. Ledger backfill 1 Oct → 3 Nov (gate, ledger only — hr.attendance untouched)
```bash
for D in $(python3 -c "import datetime as d;s=d.date(2026,10,1);print(' '.join(str(s+d.timedelta(i)) for i in range((d.date(2026,11,3)-s).days+1)))"); do
  aws lambda invoke --function-name biotime-attendance-sync --region eu-north-1 --cli-read-timeout 310 \
    --cli-binary-format raw-in-base64-out \
    --payload "{\"mode\":\"manual\",\"ledger_only\":true,\"from_date\":\"$D\",\"to_date\":\"$D\",\"is_labor\":false,\"biotime_config_id\":1,\"server_url\":\"http://rcc-erp.dyndns.org:8081\",\"tz\":\"Asia/Dubai\"}" \
    /tmp/bf_$D.json >/dev/null && echo "$D $(python3 -c "import json;s=json.load(open('/tmp/bf_$D.json'));print(s.get('status'),s.get('stats',{}).get('ledger_created'),s.get('stats',{}).get('ledger_rejected'))")"
  sleep 2
done
```
Check: every day `success`/`partial`, `ledger_created` > 0 on working days, `ledger_rejected` 0. A `skipped`
day (lease busy) → run that day again.

## 3. Mobile backfill + remap (odoo shell, then commit)
```python
from datetime import date
P = env['elrace.attendance.punch']
print(P.backfill_mobile_punches(date(2026,10,1), date.today()))
print(P.remap_gate_punches(date_from=date(2026,10,1)))
env.cr.commit()
```

## 4. Shadow rebuild + compare (odoo shell, chunked)
```python
from datetime import date, timedelta
R = env['elrace.attendance.resolver']; C = env['elrace.attendance.compare']
staff = env['hr.employee'].search([('is_labor','=',False),('active','=',True)])
d, end = date(2026,10,1), date.today() - timedelta(days=1)
while d <= end:
    e = min(d + timedelta(days=6), end)
    for i in range(0, len(staff), 100):
        R.resolve_range(staff[i:i+100], d, e); env.cr.commit()
    print(d, e, C.run(d, e)); env.cr.commit()
    d = e + timedelta(days=1)
```
Then HR: Biotime → Attendance Audit → Daily Attendance → filter **Needs Attention**, group by Compare Reason.

## 5. Correction (P2_6)
1. Biotime → Attendance Audit → Corrections → New: 2026-10-01 → today − 2 → **Dry run**. Read the log.
2. **Apply**. 3. Compare again for the range → every applied day `match`.
4. If anything is wrong: **Rollback**, fix the rule/data, repeat from step 4.

## 6. After
- Nightly shadow + compare keep running; repeat a correction weekly (or any time rules change).
- Monitor 5 working days, then the manager/HR audit (D1–D9) → Phase 4.
