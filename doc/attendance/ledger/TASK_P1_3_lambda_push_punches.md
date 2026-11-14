# TASK P1_3 — Lambda sends every BioTime transaction to the ledger

Folder `~/projects/biotime_lambda`, branch `main` (from TASK P0_3).
Depends on TASK P1_1 being installed in Odoo, and the Lambda's Odoo user being in group
"Attendance punch ingest (Lambda)".

## Change

### `odoo_client.py`

```python
def ingest_gate_punches(rows, tz_name):
    """Send raw BioTime transactions to elrace.attendance.punch. Returns the Odoo summary dict."""
    return _call(
        model  = "elrace.attendance.punch",
        method = "ingest_gate_punches",
        args   = [rows],
        kwargs = {"tz_name": tz_name},
    )
```

### `processors.py`

```python
LEDGER_BATCH = 500
LEDGER_FIELDS = ("id", "emp_code", "punch_time", "punch_state",
                 "terminal_sn", "terminal_alias", "upload_time")

def push_to_ledger(punches, tz_name, odoo):
    """Send raw punches in batches. Never raises. Returns stats dict."""
```

- Send only the `LEDGER_FIELDS` of each punch (values as BioTime returned them, untouched).
- Batches of 500. If the first batch returns `enabled: False`, stop and return `{"enabled": False}`.
- Sum `created`, `duplicates`, `rejected` (keep at most 20 rejected ids for the log).
- Catch every exception per batch, log it, continue with the next batch.

### `lambda_function.py`

1. Normal modes: right after `stats["records_fetched"] = len(all_punches)` (before grouping), call
   `ledger = proc.push_to_ledger(all_punches, tz_name, odoo)` inside `try/except` and add to `stats`:
   `ledger_created`, `ledger_duplicates`, `ledger_rejected`. If `ledger` is disabled, add nothing.
2. Gap recovery: same call on `day_punches` for each day.
3. Add a ledger line to `errors` only when `ledger_rejected > 0` ("Ledger rejected N punches: ids ...").
4. Do NOT write the new stats keys to `biotime.sync.log` (fields do not exist yet) — they stay in the
   Lambda return value and CloudWatch log only.

Everything else (`process_normal`, JM, TP, leave, absent, windows) stays exactly as deployed.

## Note on punch hours

The Lambda already fetches 00:00 to 23:59:59, so the ledger receives all punches, including the
12:00–13:00 and night ones that `group_punches` drops. That is the point: nothing is lost any more.

## Tests (`tests/test_ledger_push.py`, plain pytest with a fake `odoo` module)

1. 1200 punches → 3 calls of 500/500/200, stats summed.
2. First batch returns `enabled: False` → no further calls, stats `{"enabled": False}`.
3. Second batch raises → third batch still sent; sync result unaffected.
4. Only `LEDGER_FIELDS` are sent.

## Done when

- Invoking intraday on staging with the flag ON stores today's transactions; invoking again stores 0
  new (all duplicates).
- With the flag OFF the Lambda result and the `hr.attendance` rows are identical to `main`.
