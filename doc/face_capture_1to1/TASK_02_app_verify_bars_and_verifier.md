# TASK 02 — App: verification bars from Odoo + 1:1 verifier with cohort

Side: App (Flutter, repo `Elrace-mobileapp-operations`)
Depends on: TASK 01 deployed (app must still work with `null` / missing keys)
Read first: `doc/face_capture_1to1/00_TECHNICAL_APPROACH.md` §3, `doc/FACE_CAPTURE_TECHNICAL_ANALYSIS.md` §2.5–2.6

## Context
Today `FaceMatcher.findBestMatch` ranks all roster employees and accepts the best one (1:N). We are adding a **1:1 verify** operation: score the probe against the **selected labor's** template and against a **cohort** of other employees, and decide accept/reject. This task builds the logic and the data; it does **not** change the camera UI yet (Task 03 does).

Existing pieces to reuse:
- `lib/core/site_management/face_recognition/face_recognition_config.dart` — `FaceMatchTuning` (Odoo-tunable `minScore`/`minLead` with `apply()` and range validation). Follow the same pattern.
- `lib/core/services/app_config_service.dart` — reads `/api/app/config`, caches values in `SharedPreferences`, calls `FaceMatchTuning.apply(...)` at startup (from cache) and after fetch.
- `lib/core/site_management/face_recognition/domain/face_matcher.dart` — cosine scoring, `scoreTemplatesForEmployee(...)`.
- `lib/core/site_management/face_recognition/face_recognition_service.dart` — `matchCapturePhoto(...)`, `matchImage(...)`, `_matchFromTensor(...)` (preprocess → embed → match; already computes `focusScore` for `focusEmployeeId`).
- `lib/core/site_management/face_recognition/profile_photo_face_db.dart` — builds one template per labor from the HR photo; `setLabour(...)`, `rows()`, `yourTeamOnly(...)`, quality log (`_lowResFacePx = 90`, `LOW_RES`).
- Host `lib/ui/presentation/timesheet/foreman/fm_timesheet_capture_submit_screen.dart` → `_setProfilePhotoTeam(...)` currently passes **Your Team only** to `ProfilePhotoFaceDb.setLabour`.

## Part A — Verification bars (config)
1. Add a `FaceVerifyTuning` (same style as `FaceMatchTuning`) with:

| Field | Default | Valid range | Odoo key |
|---|---|---|---|
| `minScore` | 0.30 | 0.10–0.90 | `face_verify_min_score` |
| `minLead` | 0.05 | 0.00–0.30 | `face_verify_min_lead` |
| `minScoreNoCohort` | 0.40 | 0.10–0.90 | `face_verify_min_score_no_cohort` |
| `minCohort` | 5 | 0–50 (int) | `face_verify_min_cohort` |
| `minFacePx` | 80 | 48–300 (int) | `face_verify_min_face_px` |

   - `apply(...)`: out-of-range / null / non-finite → keep default (same as `FaceMatchTuning`).
   - Read per decision (getter), so a value fetched mid-session applies without restart.
2. `AppConfigService`: parse the five keys, cache them in `SharedPreferences`, apply on startup from cache and after each fetch. Log one line with all applied values. Must tolerate the keys being absent (older backend).

## Part B — Cohort templates
1. `ProfilePhotoFaceDb` must hold templates for the **whole project labor list**, not only Your Team:
   - Keep a notion of *team members* (verification targets) vs *cohort-only members*.
   - Build queue order: team members first, then the rest.
   - Cap total members at 80 (team members always included; fill the rest from project labor in list order).
   - The existing cache, retry, 7-day expiry, quality log and `states` notifier keep working for all members.
2. Host `_setProfilePhotoTeam(...)`: pass the full project labor list plus the Your Team ids (instead of `yourTeamOnly(...)`). If Your Team is empty (PM login), all project labor are targets (same as today's fallback).
3. Expose from `ProfilePhotoFaceDb` what the verifier needs, e.g. template for one employee, and cohort rows excluding a given employee id and excluding members whose quality flag is `LOW_RES` (source face < 90 px). Keep the `LOW_RES` flag on the template so it is queryable (today it is only logged).
4. Anything that today assumes `rows()` == Your Team (e.g. sheets showing template icons, the 1:N matcher still used elsewhere) must keep working. Where 1:N matching is still called, it should only consider team members, as today.

## Part C — Verifier
1. Add a verify operation on `FaceRecognitionService`, alongside `matchCapturePhoto` / `matchImage`, taking the same image inputs (path or upright RGB + face box + landmarks) plus `targetEmployeeId`. It reuses the existing preprocess + embed path.
2. Result type `FaceVerifyResult` with at least:
   - `outcome`: `verified` | `lowScore` | `notDistinct` | `noTemplate` | `faceTooSmall` | `error`
   - `targetScore`, `cohortMaxScore` (nullable), `lead` (nullable), `cohortSize`, `usedNoCohortBar` (bool)
   - timing fields like the existing match logs
3. Decision (exactly):
```
if target has no template            -> noTemplate
if face box width (still) < minFacePx -> faceTooSmall
t = cosine(probe, target template)
C = cohort templates (exclude target, exclude LOW_RES)
if |C| >= minCohort:
    c_max = max cosine(probe, c in C); lead = t - c_max
    verified if t >= minScore and lead >= minLead
    else lowScore if t < minScore, otherwise notDistinct
else:
    verified if t >= minScoreNoCohort, else lowScore
```
4. Never return or log the cohort member's **name** in user-facing data. Debug logs may include the cohort max employee id for tuning.
5. One `debugPrint` per verify, prefixed `FaceVerify:` with target id, t, c_max, lead, |C|, outcome, timings. Also append to the existing pilot log store (`FacePilotLogStore`) the same fields.

## Do not
- Change the camera panel, cards or host decision flow (Task 03).
- Change anti-spoof, preprocessing or the TFLite model.
- Remove `FaceMatcher.findBestMatch` (still used until Task 03, and possibly elsewhere).

## Verify
1. Unit tests for the decision table in Part C (pure function over scores), covering: verified; lowScore; notDistinct; small cohort uses `minScoreNoCohort`; noTemplate; faceTooSmall; LOW_RES cohort members excluded; target never counted in cohort.
2. Unit test for `FaceVerifyTuning.apply` range handling and `AppConfigService` with keys missing / null / out of range.
3. On device: open the capture screen for a project → log shows templates building for team first, then project labor; `ProfilePhotoQuality` summary still prints.
4. Temporarily call the verifier from a debug hook (or the existing face capture sandbox `lib/ui/presentation/timesheet/face_capture_sandbox.dart`) for a known labor → `FaceVerify:` log shows sensible t / c_max / lead.
5. `flutter analyze` clean; existing tests pass.
