# Timesheet Face Capture — 1:1 Verification (Technical Approach)

Date: 2026-10-15
Status: approved direction, ready for Cursor tasks
Related: `doc/FACE_CAPTURE_TECHNICAL_ANALYSIS.md` (the "as-is" analysis)

---

## 1. Decision

Move the foreman capture camera from **identification (1:N)** — "who is this among my team?" — to **verification (1:1)** — "is this the labor I selected?".

- Template source stays **HR profile photo, one per person**. No enrollment.
- The camera **never shows another person's name**. Outcome is only: *verified* / *doesn't match {selected labor}* / *already attended*.
- A **background cohort** (other employees' profile photos) is used only to judge how distinctive the score is. Cohort members are never accepted or named.
- All verification bars come from **Odoo config** (`/api/app/config`), so they can be tuned without an app release.

Why: 1:1 removes the structural "stranger always has a closest team member" problem, removes the hard-coded red-card bars, and is simpler to explain and support. Known trade-offs (single-photo quality, look-alikes, foreman must select the labor) are accepted and mitigated below.

---

## 2. Before vs after

| Area | Today (1:N) | After (1:1) |
|---|---|---|
| Who is compared | Whole Your Team; best one wins | Only the **selected labor**; others used as cohort |
| Accept rule | best ≥ `minScore` (0.15) and best − 2nd ≥ `minLead` (0.02); plus `softAccept` / `clearInTeamWinner` bypasses | target ≥ `verifyMinScore` **and** target − max(cohort) ≥ `verifyMinLead`; no bypasses |
| Only one person in set | Lead check skipped → any face ≥ 0.15 accepted | Cohort too small → stricter `verifyMinScoreNoCohort` |
| Red card | "Wrong person — {other labor's name}", hard-coded 0.25 / 0.08 | **"Doesn't match {selected}"**, no other name, no hard-coded bars |
| Yellow "not in your team" | Dead code in profile mode | Removed |
| No-match notice | Shows closest person's name | No name |
| Project camera (no labor pre-selected) | Point and identify | Labor picker strip; auto-advance to next labor after a verified capture |
| Live preview badge | Shows best match name | Shows **selected labor** name only when verified; otherwise neutral "Verifying…" |
| Anti-spoof, burst, replay check | — | **Unchanged** |
| Blue "already attended" | — | Unchanged (list check) |
| Face crop | 15 % pad + eye-line rotation | **5-point similarity alignment** (InsightFace standard) on probe and template |
| Profile photo download | `/public/employee/image/<id>` (no auth) | New authenticated route for face matching |
| Submit payload | No face data | Per-employee verification audit (score, lead, cohort size, liveness) stored on the timesheet line |

---

## 3. Verification rule

```
t      = cosine(probe, template[selected])          # selected labor's profile template
C      = templates of all other employees in the cohort (never the selected one)
c_max  = max cosine(probe, c) for c in C            # 0 if C empty
lead   = t - c_max

if template[selected] missing        -> NO_TEMPLATE  (manual add, "photo not available")
if |C| >= verifyMinCohort:
    accept = t >= verifyMinScore and lead >= verifyMinLead
else:
    accept = t >= verifyMinScoreNoCohort
reject reason = LOW_SCORE (t below bar) | NOT_DISTINCT (lead below bar)
```

### Cohort
- Source: **project labor list** (`/api/timesheet/labor_list`, already loaded by the host) — the whole list, not only Your Team. These templates are built by the existing `ProfilePhotoFaceDb` pipeline (same download, cache, embedding).
- Build order: Your Team first (so verification is ready fast), rest of project labor after.
- Cap: 80 members. If the project has more, take Your Team + the first members up to the cap.
- Excluded from cohort: the selected labor, and templates flagged `LOW_RES` (face < 90 px in the source photo) — low-res photos are "hub" vectors that score high against everyone and would unfairly block genuine labors.

### Starting defaults (Odoo-tunable)

| Odoo parameter (`ir.config_parameter`) | App key in `/api/app/config` | Default | Valid range |
|---|---|---|---|
| `elrace.face_verify_min_score` | `face_verify_min_score` | 0.30 | 0.10–0.90 |
| `elrace.face_verify_min_lead` | `face_verify_min_lead` | 0.05 | 0.00–0.30 |
| `elrace.face_verify_min_score_no_cohort` | `face_verify_min_score_no_cohort` | 0.40 | 0.10–0.90 |
| `elrace.face_verify_min_cohort` | `face_verify_min_cohort` | 5 | 0–50 (int) |
| `elrace.face_verify_min_face_px` | `face_verify_min_face_px` | 80 | 48–300 (int) |

**Assumption (flagged):** defaults are derived from the pilot logs in the analysis doc (genuine 0.34–0.54, cohort leads 0.03–0.13). They are a starting point only. After Task 05 (alignment) genuine scores are expected to rise, so the bars must be re-tuned from pilot logs at that point.

`face_verify_min_face_px` default 80 = today's behaviour (no change). Raise it later if far-away captures cause rejects.

Existing `elrace.face_match_min_score` / `elrace.face_match_min_lead` stay in the API for backward compatibility with older app builds; the new build does not use them for capture.

---

## 4. UX flow (after)

### Labor camera (opened from dashboard for one labor — `expectedEmployeeId` set)
1. Camera opens for **Ahmed**. Live badge: "Verifying Ahmed…" (neutral).
2. Verified on the live stream (3 stable hits) → green badge "Ahmed ✓".
3. Capture (existing burst + shutter anti-spoof) → still verified → green card, added.
4. Still not verified → held card **"Doesn't match Ahmed"** with **Try again** / **Pick another labor**.
5. No profile template for Ahmed → card "Ahmed's photo isn't available for face match" + manual add (existing manual flow).

### Project camera (opened from day hub / project dates — no labor pre-selected)
1. A horizontal **labor picker strip** shows Your Team labors not yet captured (photo, name, file id, template state).
2. First uncaptured labor is selected automatically.
3. Same verify flow as above for the selected labor.
4. After a verified capture → **auto-advance** to the next uncaptured labor (keeps morning gate fast).
5. Foreman can tap any labor in the strip to switch target at any time.
6. Already-captured labors are shown as done and cannot be selected.

---

## 5. Task list (Cursor)

Run in order, one at a time, verify before continuing.

| # | Task | Side | Depends on |
|---|---|---|---|
| 01 | Expose verification bars in `/api/app/config` | Backend | — |
| 02 | App: read verification bars + 1:1 verifier with cohort | App | 01 |
| 03 | App: camera panel decision flow → 1:1 (remove naming, bypasses, yellow) | App | 02 |
| 04 | App: project camera labor picker + auto-advance | App | 03 |
| 05 | App: 5-point face alignment (probe + template) | App | 03 |
| 06 | Authenticated face image route + app download switch | Backend + App | — (any time) |
| 07 | Verification audit on timesheet submit | Backend + App | 03 |

Tasks 01–04 deliver the new behaviour. 05 improves accuracy. 06–07 close security / audit gaps and can run in parallel on the backend.

---

## 6. Out of scope / not changed

- Anti-spoof (MiniFASNet burst, temporal checks, AWS liveness flag) — unchanged.
- Enrollment flow (`register_face_images`, Lambda, SQLite face DB) — left as is, unused by capture.
- `/public/employee/image/<id>` itself — **not modified** (module `pandora_project_timesheets_apis` is off-limits, and many screens use it for avatars). Closing it for avatars is a separate security decision; see Task 06 notes.
- `/api/register_face_images` having no auth — separate security item, not part of this change.

---

## 7. Acceptance criteria (whole change)

1. The capture camera never displays a name other than the selected labor.
2. A person who is not the selected labor is rejected with "Doesn't match {name}"; the selected labor is accepted.
3. With a team of one (or only one template ready), a stranger is not accepted at the default bars.
4. Changing any `elrace.face_verify_*` parameter in Odoo takes effect on the next app config fetch, without a release.
5. Project camera: picker strip works; auto-advance after each verified capture; captured labors marked done.
6. Anti-spoof behaviour, the blue "already attended" card and submit rules are unchanged.
7. Works on iPhone, iPad, Android phone and Android tablet, front and back camera, as today.
