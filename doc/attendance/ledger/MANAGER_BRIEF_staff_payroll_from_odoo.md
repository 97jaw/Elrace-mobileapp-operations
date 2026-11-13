# Road to Staff Payroll from Odoo — flow, progress and decisions

*Prepared by M Jawad · 5 Nov 2026*

## Purpose

Run staff payroll from Odoo attendance instead of the BioTime report. Today HR exports BioTime and prepares
payroll by hand because Odoo attendance cannot be trusted: one employee can have several rows for the same
day, some punches never reach Odoo, gate and mobile records overwrite each other, and leave or job-mission
days are sometimes stored as absent. The goal is **one trusted attendance record per employee per day**,
built from every source, that payroll can read directly.

## The new flow

```
 BioTime gates ──(Lambda, every 15 min)──┐
                                          ├──► Punch Ledger ──► Day Resolver ──► Attendance 360 (1 row / employee / day)
 Mobile app check-in/out ─────────────────┘        (raw, every punch      │            │
                                                     stored once)          │            ├──► Compare with Odoo attendance (daily)
 JM / TP requests, approved leaves,                                       │            └──► Correction run ──► hr.attendance (corrected)
 public holidays, work schedules ─────────────────────────────────────────┘                                        │
                                                                                                                   ▼
                                                                                                         Payroll (later phase)
```

- **Punch Ledger** — every gate and mobile punch, stored once, never edited.
- **Day Resolver** — builds the day from punches + requests + leaves + holidays with fixed rules
  (leave → job mission → holiday/off → half-day JM → punches → absent).
- **Attendance 360** — one screen for HR: employee, project, schedule, every punch with device/GPS, requests,
  leave, what Odoo currently holds, and the payroll effect (amounts visible to payroll managers only).
- **Compare** — every night the shadow day is compared with Odoo attendance; every difference has a reason.
- **Correction run** — writes the corrected day into `hr.attendance` with dry run, full backup and rollback.

## Phases

| Phase | What | Status |
| --- | --- | --- |
| 0 Prepare | Security fixes, duplicate report, broken cron removed | Done |
| 1 Capture | Punch ledger for gate + mobile | Live since 4–5 Nov |
| 2 Shadow | Day resolver, nightly compare, Attendance 360 screens, employee sync, correction tool | Live (built 4–5 Nov) |
| 2b Correct history | Clean BioTime employee list → backfill punches from 1 Oct → corrected `hr.attendance` from 1 Oct | Waiting for IT to finish BioTime cleanup |
| 3 Audit | Manager + HR confirm the rules (D1–D9 below) | Next |
| 4 Switch | Resolver becomes the only writer of attendance; mobile shows gate punches immediately | After one month of matching data |
| 5 Payroll | Month lock, HR review queue, payroll reads final records only | After switch |

## What we found and fixed this week

| Finding | Impact | Fix |
| --- | --- | --- |
| Hub guard blocked the BioTime sync from 31 Oct | Gate attendance stopped reaching Odoo | Sync moved to Odoo's standard API with an API key; missed days re-synced |
| Staging database still ran the live BioTime sync | Two syncs at once created duplicate rows | Staging jobs disabled; one-sync-at-a-time lock added |
| 37 employees with a wrong timezone | Same day saved under the previous date; ~1,000 duplicate rows since October | Timezones fixed, duplicates removed |
| User-record limit blocked API logins | Sync and service logins failed | Limit rule switched off for Users |
| Employee sync never removed old codes and overwrote manual links | Wrong or missing employee for some gate punches | New sync: BioTime is master, full log, manual links locked, chatter |

First comparison after fixes (4 Nov): 309 days match, 15 differ, 71 staff have no Odoo record (mostly not
registered in BioTime), 0 duplicates.

## Decisions needed (HR / management)

| # | Question | Proposed default |
| --- | --- | --- |
| D1 | When does a working day start and end? | 04:00 to 04:00 Dubai |
| D2 | Time spent outside during the day (gate out/in) — count or ignore? | Shown, not deducted |
| D3 | Check-in without check-out | HR review |
| D4 | Punches on an approved leave day | Leave stays, flagged |
| D5 | Temporary permission | Excuses late/early minutes inside its window only |
| D6 | May office staff with a gate device use mobile check-in? | No |
| D7 | Day of the month attendance is locked for payroll | HR to set |
| D8 | ~75 active staff without a BioTime code | HR to classify: gate / mobile / exempt |
| D9 | Correct October history in Odoo? | Yes — Odoo attendance corrected from 1 Oct (payroll already paid from BioTime) |

## What I need

1. A short session with you and HR on D1–D9.
2. IT to finish the BioTime employee cleanup (list sent).
3. Confirmation that the sync using Odoo's API with an API key is acceptable from the security side.
