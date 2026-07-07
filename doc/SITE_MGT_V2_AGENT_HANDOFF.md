# SITE MGT V2 — Agent handoff (full context)

> **Purpose:** Continue Site Management (Module 6) + face recognition without re-reading the slow parent chat.  
> **User constraint:** No direct server SSH/credentials for placing `mobilefacenet.onnx`. Wants S3/AWS alternate for model delivery.  
> **Date:** 2026-05-19

---

## 1. Repositories & branches

| Repo | Path | Branch | Remote |
|------|------|--------|--------|
| Flutter app (el_race) | `/Users/mjawad/Downloads/el_race-loayBranch` | `loayBranch` (typical) | mobile app |
| Odoo addons | `/Users/mjawad/projects/elrace/odoo14-clients` | **`elrace-addons`** | production deploy branch |

**Do not use** `pre-refactor-inline-2026` — merged into `elrace-addons` and deleted locally.

---

## 2. What Site Management is

**Module 6** is split into two home cards:

| Card | Route | FM | PM |
|------|-------|----|----|
| **Timesheet** | `/timesheet` | Calendar, capture, PDF records, sync queue | Weekly stats + `PmTimesheetSubmissionsScreen` |
| **Site Management** | `/site-management` | `Fm2ProjectDetail` — reports, teams, photos, live, face enroll | `Pm2ProjectDetail` — reports, teams, live, worker enrol |

Shared: `TimesheetEntryModeScope` + `timesheetEntryModeStateProvider` set at module entry.

Face-assisted labor ID on **Add timesheet** (Timesheet card). Face enroll primary entry on Site Management (`Fm2` Enroll tab).

---

## 3. Flutter app — DONE (Phase A)

### Add timesheet UI (`lib/ui/presentation/timesheet/foreman/`)

- **`fm_timesheet_capture_submit_screen.dart`** — full-screen camera, navy chrome, project marquee, right rail (flip/flash/capture), bottom form, face + geofence pills
- **`timesheet_capture_camera_panel.dart`** — `externalChrome`, `trustLiveGate` on still capture, camera switch fix (`_cameraInitInFlight`)
- Labels above fields; Start/End show date + time on two lines; Break row overflow fixed

### Face match (Phase A — pixel match, not embeddings yet)

- **`timesheet_roster_face_matcher.dart`** — MSE vs HR JPEG from `image_url`, bearer auth for Odoo photos
- Roster = **project labors only** via `fetchLaborEmployeesForReport(projectId)` (foreman removed from match pool)
- **`timesheet_odoo_employee.dart`** — `hasProfileImage`, `faceMatchImageUrl`, fallback `https://erp.elrace.com/public/employee/image/{id}`

### Known Phase A limitation

- "No match to enrolled face photos" when HR photo missing or weak pixel match — expected until Phase B

### Flutter assets (mobile model, NOT for Odoo)

- `assets/mobilefacenet.tflite` — **REJECTED** (192-d, TC-C2 FAIL vs Lambda 512-d)
- Replace using `emp_mobile_conf/MODEL_CONVERSION.md` → `mobilefacenet_512.tflite` after TC-C2 > 0.95

### Phase B mobile — NOT STARTED

1. Poll `POST /api/face_db/version`
2. Download `POST /api/face_db/embeddings` when version changes
3. Cache per foreman; cosine match with TFLite after capture
4. Fallback: Phase A JPEG → manual pick

---

## 4. Odoo backend — DONE (inline architecture)

### Architecture (current — no microservice)

```
HR uploads image_1920 → hr.employee.write() → face_embedding_status = 'pending'
→ Nightly cron (2 AM) OR admin "Recompute" → inline ONNX in Odoo
→ store 512-dim float32 binary on hr.employee → bump face.db.version once per batch
→ Mobile: /api/face_db/version + /api/face_db/embeddings
```

**Deleted:** entire `face_embedding_service/` (never deployed).

### Module: `emp_mobile_conf` (commit on `elrace-addons`)

| Area | Path |
|------|------|
| Face fields + cron | `models/hr_employee_face_embedding.py` |
| DB version singleton | `models/face_db_version.py` |
| Inline inference | `face_inference/` (detection, quality, model, inference) |
| Model path (local file) | `models_files/mobilefacenet.onnx` ← **NOT IN GIT** |
| Nightly cron XML | `data/cron_data.xml` |
| Admin UI | `views/hr_employee_face_views.xml` |
| Bulk script | `scripts/bulk_enroll_embeddings.py` |
| Docs | `README_FACE.md` |

**Fields on `hr.employee`:**  
`face_embedding`, `face_embedding_version`, `face_embedding_updated_at`, `face_embedding_status` (none/pending/ready/failed), `face_embedding_error`, `face_embedding_retry_count`, `has_face_data` (stored computed).

**User may have added columns via SQL on live** before module upgrade — see README_FACE cleanup SQL if old `face.embedding.job` existed.

### Module: `elrace_backend_apis` (also pushed)

| Piece | Path |
|-------|------|
| Version endpoint | `controllers/face_db_controller.py` → `POST /api/face_db/version` |
| Embeddings endpoint | `POST /api/face_db/embeddings` |
| Serializer | `utils/face_db_serializer.py` — foreman scope via `x_labor_ids`, base64 vectors |
| Timesheet cards | `timesheet_controller.py` — `image_url`, `has_profile_image`, `face_embedding_status` |

Depends on `emp_mobile_conf`.

---

## 5. Live deployment status (as of handoff)

| Step | Status |
|------|--------|
| `git pull` on `elrace-addons` | Done (user) |
| Both modules installed/upgraded | Done (user) |
| pip: onnxruntime, opencv-python-headless, numpy, pillow | Done (user) |
| **Odoo restart** | **NOT done yet** (user) |
| **`mobilefacenet.onnx` on server** | **MISSING** — blocker for recompute/cron |
| Server SSH | **User does not have credentials** |
| Face recompute / embeddings | Blocked until ONNX present + restart |
| Mobile Phase B | Not started |

---

## 6. ONNX blocker & S3 alternate (for V2 agent)

### Problem

- Code loads model only from: `get_module_path('emp_mobile_conf')/models_files/mobilefacenet.onnx`
- File was **never in git** (too large / ops step)
- User cannot SCP to server without credentials

### S3 / HTTPS download — **implemented** (SITE MGT V2)

1. Upload `mobilefacenet.onnx` to S3 (e.g. public HTTPS `https://…/face/mobilefacenet.onnx`).
2. Set **`face_embedding.model_url`** manually in Odoo (**Settings → Technical → System Parameters**).
3. `emp_mobile_conf/face_inference/model.py`:
   - Local file in `models_files/` wins if present.
   - Else downloads once from HTTPS URL (atomic `.part` write, 1–50 MB size check).
   - Failures → `model_not_loaded` on employees until URL/file is fixed.
4. **Still required:** Odoo restart + outbound HTTPS from container on first recompute/cron.

**Who can do without SSH:**

- User uploads to S3 from laptop (AWS Console).
- DevOps sets `ir.config_parameter` in Odoo UI (Settings → Technical → Parameters).
- Restart Odoo after first successful download.

**Download source for the file (Mac):**

```bash
curl -L -o mobilefacenet.onnx \
  "https://huggingface.co/deepghs/insightface/resolve/main/buffalo_s/w600k_mbf.onnx"
```

Rename to `mobilefacenet.onnx`. Verify preprocessing compatibility with existing inference code `(pixel - 127.5) / 128.0` — may need tuning vs InsightFace default.

**Other alternates:**

- CI/CD pipeline on deploy: curl model into addons path (needs pipeline access, not user SSH).
- Git LFS commit on `elrace-addons` + pull on server (needs whoever runs git pull).
- Ask hosting provider / colleague with SSH to copy one file.

---

## 7. Post-deploy checklist (whoever has access)

```text
1. Place or download mobilefacenet.onnx (local path OR S3 URL approach above)
2. Restart Odoo workers / container
3. Settings → Automation → "Face Recognition: Process Pending Embeddings" → set 2 AM, Run Manually once
4. Employee form → Face Recognition → Recompute (test one employee)
5. Optional: bulk_enroll_embeddings.py in Odoo shell (off-hours)
6. Test APIs: POST /api/face_db/version, POST /api/face_db/embeddings (foreman auth)
7. Then Flutter Phase B
```

### pip (inside Odoo container)

```bash
pip install onnxruntime opencv-python-headless numpy pillow
```

### Troubleshooting

| Error | Cause |
|-------|--------|
| `model_not_loaded` | No ONNX file or download failed |
| `service_unreachable` | Old code still running — pull latest, upgrade modules |
| `no_face_detected` | Bad HR photo |
| ImportError onnxruntime | pip on wrong Python |

---

## 8. Task docs (read order for V2 agent)

| File | Content |
|------|---------|
| `doc/SITE_MGT_V2_AGENT_HANDOFF.md` | This file |
| `doc/Face_Recognition_Refactor_TASKS.md` | R.0–R.14 DONE; Phase V verification TODO |
| `doc/Module_6_Face_Recognition_Phases.md` | Phase A vs B (update microservice refs to inline) |
| `doc/Face_Recognition_Backend_TASKS.md` | Original backend tasks (partially superseded by refactor doc) |
| `emp_mobile_conf/README_FACE.md` | Ops runbook in odoo14-clients |

---

## 9. Verification phase (not done on live)

- **V.1** — upgrade modules, upload photo → pending → manual cron → ready → API returns embeddings
- **V.2** — bulk enroll ~1000 employees
- **V.3** — Flutter Phase B integration

---

## 10. Key product rules

- Foreman team scope: `hr.employee.x_labor_ids` (from `elrace_employee_profile_fix`)
- Embeddings: 512 × float32, L2-normalized, binary on DB
- `face.db.version` bumps once per nightly batch (not per employee)
- Admin recompute is synchronous + bumps version immediately
- No raw embeddings/photos in logs
- Nightly retry max 3 (`face_embedding_retry_count`)

---

## 11. Suggested first tasks for SITE MGT V2 agent

1. **Implement S3/URL model download** in `face_inference/model.py` + `ir.config_parameter` + README.
2. **Confirm live restart** and one successful recompute (coordinate with whoever has Odoo UI/server access).
3. **Update** `Module_6_Face_Recognition_Phases.md` (remove microservice wording).
4. **Flutter Phase B** — face_db sync + TFLite cosine match on Add timesheet.
5. **End-to-end test** foreman flow on staging/live.

---

## 12. Copy-paste prompt for new Cursor agent

```
You are SITE MGT V2 agent for ElRace Module 6 (Site Management + face recognition).

Read first: el_race-loayBranch/doc/SITE_MGT_V2_AGENT_HANDOFF.md

Repos:
- Flutter: /Users/mjawad/Downloads/el_race-loayBranch
- Odoo: /Users/mjawad/projects/elrace/odoo14-clients branch elrace-addons

State: Phase A Flutter timesheet+face JPEG match DONE. Backend inline face embeddings DONE and deployed to live (emp_mobile_conf + elrace_backend_apis). pip installed. Odoo NOT restarted yet. mobilefacenet.onnx NOT on server; user has NO SSH. Implement S3/HTTPS model download in emp_mobile_conf/face_inference/model.py as next priority.

Never reintroduce face_embedding_service microservice. Mobile Phase B not started.
```
