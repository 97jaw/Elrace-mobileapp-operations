# TASK 01 — Backend: expose face verification bars in `/api/app/config`

Side: Backend (Odoo 14, repo `odoo14-clients`, branch `elrace-addons`, module `elrace_backend_apis`)
Depends on: nothing
Read first: `doc/face_capture_1to1/00_TECHNICAL_APPROACH.md` §3

## Context
The mobile app is moving the timesheet capture camera to 1:1 face verification. Its accept/reject bars must be tunable from Odoo without an app release. `/api/app/config` already returns `face_match_min_score` and `face_match_min_lead` read from `ir.config_parameter` (`elrace.face_match_min_score`, `elrace.face_match_min_lead`). Add five more keys the same way.

## Where
`elrace_backend_apis/controllers/auth_controller.py` → `get_app_config()` (route `/api/app/config`, `type='json'`, `auth='none'`). The existing loop over `('face_match_min_score', 'face_match_min_lead')` is the pattern to follow.

## Change
1. Return these keys in the response, each read from `ir.config_parameter` key `elrace.<name>`:

| Response key | Type | Notes |
|---|---|---|
| `face_verify_min_score` | float or `null` | |
| `face_verify_min_lead` | float or `null` | |
| `face_verify_min_score_no_cohort` | float or `null` | |
| `face_verify_min_cohort` | int or `null` | parse as int; reject non-integers → `null` |
| `face_verify_min_face_px` | int or `null` | parse as int; reject non-integers → `null` |

2. Rules (same as existing keys):
   - Missing / empty / unparsable parameter → `null` (app keeps its own default). Log a warning on unparsable.
   - Do **not** clamp or validate ranges on the server; the app validates ranges.
   - Keep `face_match_min_score` and `face_match_min_lead` exactly as they are (older app builds use them).
3. Refactor the existing float loop into a small helper if it keeps the code clean (e.g. `_config_number(key, cast)`), but do not change the response shape of existing keys.
4. Do not create the parameters with values (no data XML). Empty = app defaults. HR/admin sets them in Settings → Technical → System Parameters when tuning.
5. Bump `__manifest__.py` version `1.0.15` → `1.0.16`.

## Do not
- Change auth on `/api/app/config`.
- Touch `pandora_project_timesheets_apis`.

## Verify
1. Upgrade the module.
2. Call `GET /api/app/config` (JSON-RPC body `{}`) with no parameters set → all five new keys are `null`.
3. Set `elrace.face_verify_min_score = 0.32`, `elrace.face_verify_min_cohort = 6` → response shows `0.32` and `6`.
4. Set `elrace.face_verify_min_cohort = abc` → `null`, warning in the log, other keys unaffected.
5. Existing keys `isTestMode`, `splash_video_url`, `face_match_min_score`, `face_match_min_lead`, notices — unchanged.
