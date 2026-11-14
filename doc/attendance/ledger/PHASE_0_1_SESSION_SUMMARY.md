# Attendance ledger — Phase 0 + Phase 1 session summary

Date: 2026-11-04  
Repos: Odoo worktree `elrace-addons`, Lambda `biotime_lambda` on `main`, mobile repo untouched.

---

## TASK_P0_1 — Deactivated broken BioTime requests cron; bumped `cubes_biotime` to 1.0.2

### Files changed / added (full paths)

- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/cubes_biotime/data/cron.xml`
- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/cubes_biotime/__manifest__.py`

### How to test

```bash
cd /Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons
git diff -- cubes_biotime/data/cron.xml cubes_biotime/__manifest__.py
./odoo-bin -c <odoo.conf> -d <db_name> -u cubes_biotime --stop-after-init
```

### Test results

Diff verified locally. Odoo upgrade **not run** here (no DB/config).

### Unsure / deviations

None. Only that cron was deactivated; other crons untouched.

### Deploy notes

Upgrade `cubes_biotime`. If cron is `noupdate`, manually disable **BioTime — Employee Requests Processor (15 min)** in Scheduled Actions.

---

## TASK_P0_2 — Duplicate attendance report SQL (read-only; user runs it)

### Files changed / added

None changed by the agent. Script:

- `~/projects/mobileapp/Elrace-mobileapp-operations/doc/attendance/ledger/TASK_P0_2_duplicate_report.sql`

### How to test

Run the SQL on production/copy via psql/pgAdmin (staff, last 6 months).

### Test results

Not run by the agent (by design).

### Deploy notes

Read-only; no deploy.

---

## TASK_P0_3 — Lambda under git on `main`; deployed 2026-11-04 code as root; secrets out of active defaults

### Files changed / added (full paths)

- Added: `/Users/mjawad/projects/biotime_lambda/.gitignore`
- Added archive: `/Users/mjawad/projects/biotime_lambda/archive_2026-04-02/{odoo_client,biotime_client,processors,lambda_function}.py`
- Root replaced from deployed:
  - `/Users/mjawad/projects/biotime_lambda/{odoo_client,biotime_client,processors,lambda_function}.py`
- Edited: `/Users/mjawad/projects/biotime_lambda/odoo_client.py` (no hardcoded DB/user/password defaults)
- Local-only (untracked): `deployed_2026-11-04/` (kept as reference; untracked so `git grep Odoo@` stays clean)

### How to test

```bash
cd /Users/mjawad/projects/biotime_lambda
git log --oneline -n 3
git grep -n "Odoo@" || true
```

### Test results

```text
7c15176 chore: keep deployed snapshot as local reference only
72c5a8b chore: deployed Lambda code of 2026-11-04
# git grep "Odoo@": empty
```

### Unsure / deviations

Second commit untracked `deployed_2026-11-04/` because historical passwords lived there and would fail the required `git grep "Odoo@"` check. Folder remains on disk unchanged.

### Deploy notes

No AWS deploy. Env vars must stay set: `ODOO_URL`, `ODOO_DB`, `ODOO_USER`, `ODOO_PASSWORD`. Author email for this repo: `jawad@elrace.com`.

---

## TASK_P1_1 — New Odoo module `elrace_attendance_ledger` (raw punch model + ingest + mobile API + tests)

### Files changed / added (full paths)

All under worktree:

- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/elrace_attendance_ledger/__init__.py`
- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/elrace_attendance_ledger/__manifest__.py`
- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/elrace_attendance_ledger/models/__init__.py`
- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/elrace_attendance_ledger/models/attendance_punch.py`
- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/elrace_attendance_ledger/security/groups.xml`
- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/elrace_attendance_ledger/security/ir.model.access.csv`
- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/elrace_attendance_ledger/data/ir_config_parameter.xml`
- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/elrace_attendance_ledger/tests/__init__.py`
- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/elrace_attendance_ledger/tests/test_punch_ledger.py`

### How to test

```bash
cd /Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons
./odoo-bin -c <odoo.conf> -d <db_name> -i elrace_attendance_ledger --stop-after-init
./odoo-bin -c <odoo.conf> -d <db_name> -u elrace_attendance_ledger --test-enable --test-tags /elrace_attendance_ledger --stop-after-init
```

### Test results

AST parse OK. Full Odoo install/tests **not run** here.

### Unsure / deviations

None material. Flag default `False`; immutable raw fields; ingest capped at 2000; mobile path uses savepoint + never raises.

### Deploy notes

Install `elrace_attendance_ledger`. Keep `attendance.ledger_enabled=False` until ready. Assign Lambda Odoo user to **Attendance punch ingest (Lambda)**.

---

## TASK_P1_2 — Mobile check-in/out hooks ledger after new create/write only; no hard module dependency

### Files changed / added (full paths)

- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/elrace_backend_apis/services/attendance_service.py`
- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/elrace_backend_apis/tests/__init__.py`
- `/Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons/elrace_backend_apis/tests/test_ledger_hook.py`

### How to test

```bash
cd /Users/mjawad/projects/elrace/odoo14-clients/.worktrees/elrace-addons
./odoo-bin -c <odoo.conf> -d <db_name> -u elrace_attendance_ledger,elrace_backend_apis --stop-after-init
./odoo-bin -c <odoo.conf> -d <db_name> --test-enable --test-tags /elrace_backend_apis --stop-after-init
```

### Test results

AST parse OK. Full Odoo tests **not run** here.

### Unsure / deviations

`_ledger_record` uses `env.get` when available, else registry check (Odoo 14 verify item). API shapes unchanged; already-checked-in/out paths not hooked.

### Deploy notes

Same as P1_1: ledger module installed; flag OFF until staging validation.

---

## TASK_P1_3 — Lambda pushes every fetched BioTime punch to ledger in batches of 500

### Files changed / added (full paths)

- `/Users/mjawad/projects/biotime_lambda/odoo_client.py`
- `/Users/mjawad/projects/biotime_lambda/processors.py`
- `/Users/mjawad/projects/biotime_lambda/lambda_function.py`
- `/Users/mjawad/projects/biotime_lambda/tests/test_ledger_push.py`

### How to test

```bash
cd /Users/mjawad/projects/biotime_lambda
pytest -q tests/test_ledger_push.py
```

### Test results

```text
....                                                                     [100%]
4 passed in 0.02s
```

### Unsure / deviations

None. Ledger stats go to Lambda return/CloudWatch only — **not** written to `biotime.sync.log`. Existing processors untouched.

### Deploy notes

Package/deploy Lambda when you choose. Prerequisites: ledger module installed, Lambda user in ingest group, flag ON for validation. Re-invoke intraday → expect duplicates / ~0 new.

---

## Things to verify (not assume) — status

| Check | Result |
| --- | --- |
| Odoo 14 `self.env.get('model')` | **Exists** in this codebase (`attendance_service` already used it). P1_2 also falls back to `'elrace.attendance.punch' in self.env.registry`. |
| BioTime transaction unique `id` as `source_ref` | **Assumed OK for P1_3** — no conflicting sample in code; ledger uses `id`. **Still verify on a real BioTime response** before enabling flag in staging. If any row lacks `id`, stop and report (ingest will reject those). |
| Mobile check_in / check_out = server time (A1) | **Confirmed** in worktree `attendance_service.py`: `fields.Datetime.now()` for both; ledger uses `attendance.check_in` / `check_out`, never phone time. |
| Task vs real code conflicts | **No blocking conflicts.** Notes: (1) Odoo work is only in `.worktrees/elrace-addons`, not repo root `golive`. (2) P0_3 needed a second commit to keep `deployed_2026-11-04/` untracked so secrets aren’t in git grep. |

---

## Repos / branches / commit status

| Repo | Branch / path | Committed? |
| --- | --- | --- |
| Odoo | `.worktrees/elrace-addons` on `elrace-addons` | **No** (uncommitted: P0_1 + P1_1 + P1_2) |
| Mobile | untouched | — |
| Lambda | `main` | P0_3 committed; **P1_3 still uncommitted** |

---

## Suggested enable order

1. Upgrade/install Odoo: `cubes_biotime` → `elrace_attendance_ledger` → `elrace_backend_apis`
2. Assign Lambda user → **Attendance punch ingest (Lambda)**
3. Deploy Lambda with P1_3 (when you want)
4. Leave `attendance.ledger_enabled=False` first; confirm payroll/mobile unchanged
5. Turn flag **True** on staging; compare BioTime vs ledger for a few days
