# TASK P2_0 — BioTime employee sync: BioTime is the master list

Module `cubes_biotime` (+ a call into `elrace_attendance_ledger`). Worktree `.worktrees/elrace-addons`,
branch `elrace-addons`, no commit until reviewed. Do this BEFORE P2_5 / P2_6 are applied on live data.

## Goal

After IT cleans BioTime, one button makes Odoo's `biotime.employee` list EQUAL to BioTime's: same codes,
same people, nothing extra, every active staff member linked to the right Odoo employee — with a dry run
first and a report of everything that changed or needs a human.

## What the current method does (`biotime.config.action_get_all_employees`) — and its gaps

1. Upsert only: creates/updates, **never deletes** codes that no longer exist in BioTime → stale rows stay.
2. **Overwrites `odoo_employee_id` on every run** with the automatic match (`emp_code` stripped of zeros →
   `hr.employee.emp_id`). A link fixed by hand in Odoo is reset on the next sync — to empty if no match.
3. The match only finds **active** employees, `limit=1`; duplicate `emp_id` in Odoo silently picks one.
4. If BioTime's `emp_code` and Odoo's `emp_id` disagree (e.g. code 3698 = "hazem shat" in BioTime, but Odoo
   file 3698 = "Mukesh Kumar Ramsawrup"), it links the WRONG person and nobody is told.
5. Writes `x_device_location` on `hr.employee` for every row on every run (heavy, noisy).
6. Recursive paging, errors swallowed: a failure on page 7 stops silently and leaves a half sync.
7. No unique keys, no log, no report.

## New method `action_sync_employees(dry_run=True)` on `biotime.config`

Keep the old method (do not delete), add a new button "Sync Employees (BioTime = master)" next to it,
`base.group_system` only, and a result wizard/report.

1. **Fetch everything first**: `/personnel/api/employees/?page=N&page_size=500` in a loop until `next` is
   empty. Any HTTP/parse error → abort, change nothing, show the error. Keep the raw rows (id, emp_code,
   first_name, last_name, department, position, hire_date, and any active/resigned field the API returns —
   check the real response and use it if present).
2. **Upsert by BioTime id** (`employee_id` char) within this config: update `name`, `emp_code`.
3. **Delete** `biotime.employee` rows of this config whose BioTime id is not in the fetched list (BioTime is
   master). Before unlink, write each deleted row to a log (see 7). Punches in the ledger keep their
   `emp_code`, so nothing else is lost.
4. **Linking rules** (per row):
   - New field `link_locked` (Boolean). Set it automatically when a user changes `odoo_employee_id` by hand
     (override `write` when the change does not come from the sync context). Locked links are never changed by
     the sync.
   - Otherwise auto-match: normalise both sides (`lstrip('0')`) — `emp_code` vs `hr.employee.emp_id`, search
     **active and archived**; exactly one match → link; archived match → link but report "employee archived";
     zero or several → leave empty and report.
   - **Name check**: if the linked employee's name and the BioTime name share no word (case/space-insensitive),
     report "name mismatch" (this catches 3698). Do not auto-change it — a human decides and locks the link.
5. **Constraints**: SQL unique (`biotime_id`, `employee_id`) and (`biotime_id`, `emp_code`). If existing data
   breaks them, the sync's delete/upsert must clean that first (in dry run: report it).
6. **Stop writing `x_device_location`** in the new method (leave the old method as is).
7. **Log + report**: new model `biotime.employee.sync.log` (date, user, dry_run, counts, lines). Lines:
   created, updated (field: old → new), deleted, linked, unlinked, locked-kept, name mismatch, no Odoo match,
   several Odoo matches, archived employee, Odoo employee linked to more than one code, and **active Odoo staff
   (`is_labor = False`) with no BioTime code** (they have no gate attendance). Show it as a list view of
   lines grouped by type; export to Excel works out of the box.
8. **After a real (non-dry) run**: call
   `env['elrace.attendance.punch'].remap_gate_punches(emp_codes=<codes whose link changed>)` if that method
   exists (P2_5), then queue `resolve_range` for the affected employees/dates. Guard with `if` so the sync
   works before P2_5 is deployed.

## Tests

- Fake API pages (2 pages) → rows created/updated; a row missing from BioTime is deleted and logged.
- API error on page 2 → nothing changed.
- Manual link → `link_locked` set → next sync keeps it.
- `000001833` matches `emp_id` `1833`; archived employee matched and reported.
- Name mismatch reported, link not changed.
- Dry run changes nothing but produces the same report lines.
- Duplicate code rows cleaned on the real run.

## Run on live (user)

1. Dry run → review the report with IT (fix names/codes in BioTime or Odoo; lock manual links).
2. Real run → report again must show 0 deleted / 0 conflicts on a second dry run.
3. Then the ledger remap + rebuild (P2_5) and the backfill from 1 Oct.
