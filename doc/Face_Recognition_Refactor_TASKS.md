# Face Recognition — Refactor to Inline + Nightly Cron | Cursor Task File

> **Context:** You previously built a microservice-based face recognition backend per the original task file. That code has NOT been deployed yet. Architecture is changing to a simpler inline approach. This file replaces the original task file going forward.

> **How to use this file:** Read it top to bottom. The architecture changes are significant but the scope is smaller. Work top to bottom. Update status as you go.

---

## 0. What's Changing and Why

### Old architecture (what you built, but never deployed)
- Separate `face_embedding_service/` microservice (FastAPI, Docker)
- Odoo calls microservice via HTTP for each embedding
- `face.embedding.job` queue model with cron every 1 minute
- Real-time-ish processing of photo uploads

### New architecture (what we're moving to)
- **No microservice.** Inference happens inside Odoo itself.
- ONNX model loaded once into Odoo Python memory, cached.
- **Single nightly cron at 2 AM** processes all pending embeddings in a batch.
- New/changed photos sit as 'pending' during the day, get computed overnight.
- Odoo support team handles urgent/manual cases via the existing admin "Recompute" button.

### Why
- We have ~1000 employees with rarely-changing photos.
- New employees doing attendance their first hour after photo upload is not a real scenario.
- One service is simpler to deploy, monitor, and operate than two.
- No HTTP between processes = no network failure modes.
- Odoo support team confirmed they can handle manual edge cases.

---

## 1. Critical Rules (NEVER violate these)

| Rule | Reason |
|------|--------|
| **No microservice in any form** | Reverting that entire approach. Delete cleanly. |
| **Inference code lives in emp_mobile_conf** | One module, one place to find face recognition logic. |
| **Same model file as before (MobileFaceNet ONNX)** | Identity preserved; existing model bundling is correct. |
| **L2-normalize embeddings before storing** | Required for mobile cosine similarity to work. |
| **Binary storage (np.float32.tobytes())** | Faster reads, smaller storage. |
| **Same 512-dim float vector output** | Mobile contract is unchanged — embeddings on the wire look identical. |
| **Don't break elrace_backend_apis endpoints** | These are independent. Touch only if necessary. |
| **One commit per task** | Format: `refactor(face-rec): <TASK_ID> <description>` |
| **Never log raw embeddings or photo bytes** | Same privacy rule as before. |

---

## 2. New Architecture (in detail)

```
HR uploads photo via Odoo
        │
        ▼
[emp_mobile_conf hr.employee.write() hook]
        │
        ▼
Marks face_embedding_status = 'pending'
That's all. No job created, no cron scheduled inline.
        │
        ▼
   ... waits until 2 AM ...
        │
        ▼
[Nightly cron — face.embedding.processor]
        │
        ▼
Find all employees where status IN ('pending', 'failed')
        │
        ▼
For each (in batches of 50):
  1. Load image_1920
  2. Call inline face_inference.generate_embedding(image_bytes)
  3. Store embedding (binary blob)
  4. Update status
  5. Log result
        │
        ▼
After batch complete: face.db.version.bump()
        │
        ▼
Mobile clients see new version → re-sync next time foreman opens app
```

### Key differences from old build
- **No HTTP calls.** Direct Python function call.
- **No job queue model.** Just a status field on employee.
- **No 1-minute cron.** Single nightly run.
- **No microservice.** ONNX runs inside Odoo's Python process.

---

## 3. Module Structure (target state)

```
emp_mobile_conf/
├── __manifest__.py
├── models/
│   ├── __init__.py
│   ├── hr_employee.py             ← SIMPLIFIED (write hook just marks pending)
│   └── face_db_version.py         ← UNCHANGED
├── data/
│   ├── ir_config_data.xml         ← REMOVE service URL config (no longer needed)
│   └── cron_data.xml              ← NEW: define the nightly cron
├── face_inference/                ← NEW directory (inline inference)
│   ├── __init__.py
│   ├── model.py                   ← ONNX loader + singleton cache
│   ├── face_detection.py          ← Detection + alignment (from old microservice)
│   ├── quality_check.py           ← Quality scoring (from old microservice)
│   └── inference.py               ← Main entry point: generate_embedding(image_bytes)
├── models_files/                  ← NEW directory (renamed from old microservice)
│   └── mobilefacenet.onnx         ← MOVED HERE from face_embedding_service/
├── scripts/
│   └── bulk_enroll_embeddings.py  ← UPDATED to use inline inference
├── migrations/
│   └── 14.0.X.Y.Z/
│       └── post-migration.py
├── views/
│   └── hr_employee_views.xml      ← KEEP (admin tab, recompute button)
└── README.md                       ← UPDATE
```

```
elrace_backend_apis/
├── (No structural changes — endpoints work as-is)
└── README.md                       ← UPDATE to remove microservice references
```

```
face_embedding_service/             ← DELETE ENTIRELY
```

---

## 4. Functional Knowledge (recap of unchanged details)

### 4.1 Embedding model
- MobileFaceNet ONNX format
- 112×112 RGB input, 512-dim L2-normalized output
- ~50-200ms per inference on CPU

### 4.2 Storage format (unchanged)
```python
embedding = model.predict(face_crop)        # shape (512,), float32
embedding = embedding / np.linalg.norm(embedding)
binary_blob = embedding.astype(np.float32).tobytes()  # 2048 bytes
```

### 4.3 Quality thresholds (unchanged)
Same as before: face detected (exactly 1), size ≥ 80px, pose < 30°, sharpness > 100.

### 4.4 Status transitions
- `none` → no photo uploaded yet
- `pending` → photo uploaded, waiting for nightly cron to process
- `ready` → embedding successfully computed
- `failed` → quality check or inference failed; will retry next cron run (with limit)

### 4.5 Nightly cron behavior
- Runs at **2:00 AM server time**
- Processes ALL employees with status in ('pending', 'failed') with retry_count < 3
- Batches of 50 with database commits between batches
- Logs progress every batch
- Bumps face.db.version ONCE at the end (not per employee)
- Total expected duration: ~5 minutes for first run with 1000 employees, then near-zero for subsequent nights

### 4.6 Manual override (Odoo support team workflow)
- Admin opens employee form
- Goes to "Face Recognition" tab
- Clicks "Recompute Embedding" button
- Runs **synchronously** (waits 1-2 seconds, shows result immediately)
- Useful for urgent cases without waiting for nightly cron

---

## 5. Tasks (work top to bottom)

> **Status legend:** `[TODO]` `[IN_PROGRESS]` `[DONE]` `[BLOCKED]` `[NEEDS_REVIEW]`

---

### Phase R — Refactor

#### `[DONE]` R.0 — Pre-flight check
Before changing anything:
- Confirm none of the previously built code has been deployed to staging or production yet
- If anything WAS deployed (microservice container, modules upgraded), stop and tell me before continuing
- Take a git snapshot / branch named `pre-refactor-inline-2026` from current state
- List all files in `face_embedding_service/` for confirmation before deletion

**Definition of done:** Confirmation that nothing was deployed. Snapshot branch created. File list of microservice noted.

---

#### `[DONE]` R.1 — Move ONNX model file
- Move `face_embedding_service/app/models/mobilefacenet.onnx` to `emp_mobile_conf/models_files/mobilefacenet.onnx`
- Verify SHA256 checksum after move (should be identical to before)
- Update any references in `emp_mobile_conf` to point to new path

**Note:** Use `models_files/` (not `models/`) to avoid collision with Odoo's models/ Python directory.

**Definition of done:** File at new location, checksum verified, no broken references.

---

#### `[DONE]` R.2 — Port face detection + alignment into emp_mobile_conf
- Create directory `emp_mobile_conf/face_inference/`
- Add `__init__.py`
- Copy logic from old microservice `app/face_detection.py` into new `face_inference/face_detection.py`
- Same public API: `detect_faces(image_bytes) -> list[FaceBox]` and `align_face(image, face_box) -> np.ndarray`
- Keep all unit tests the original microservice had — port them to `emp_mobile_conf/tests/test_face_detection.py`
- Run tests; confirm all pass

**Definition of done:** Detection + alignment work inside emp_mobile_conf. Tests pass.

---

#### `[TODO]` R.3 — Port quality checking into emp_mobile_conf
- Same pattern as R.2 for `quality_check.py`
- Create `emp_mobile_conf/face_inference/quality_check.py`
- Port tests to `emp_mobile_conf/tests/test_quality_check.py`

**Definition of done:** Quality scoring works inside emp_mobile_conf. Tests pass.

---

#### `[TODO]` R.4 — Port model loading + inference (with singleton caching)
- Create `emp_mobile_conf/face_inference/model.py`:
  - Module-level `_model_instance = None`
  - Function `get_model()` returns the loaded ONNX session, lazy-loads on first call
  - Model file path resolved via Odoo's `addons` module path lookup, NOT hardcoded
- Create `emp_mobile_conf/face_inference/inference.py`:
  - Main entry point: `generate_embedding(image_bytes: bytes) -> dict`
  - Returns: `{"status": "success", "embedding": np.ndarray, "model_version": str, ...}`
  - OR: `{"status": "failed", "error": str}`
  - Internally calls detection → quality check → alignment → model.predict → L2 normalize
- Make sure model loads ONCE per Odoo worker process, then reused for all subsequent calls
- Add log message on first load: "MobileFaceNet model loaded (took X ms)"

**Definition of done:** Calling `generate_embedding(bytes)` twice — first call ~1-3 sec (model load), second call ~100-300 ms (cached). Behavior identical to old microservice.

---

#### `[DONE]` R.5 — Update emp_mobile_conf dependencies
- Open `emp_mobile_conf/__manifest__.py`
- **Remove** `queue_job` from depends (no longer using job queue)
- Document required Python packages in `README.md`:
  - `onnxruntime` (or `onnxruntime-cpu` for explicit CPU-only)
  - `opencv-python-headless` (no GUI deps)
  - `numpy`
  - `pillow`
- These must be installed in Odoo's Python environment (NOT via Odoo addons — these are PyPI packages)
- Document the install command for the Odoo support team in README

**Definition of done:** Manifest updated, README documents Python package requirements.

---

#### `[DONE]` R.6 — Simplify hr.employee.write() hook
- Open `emp_mobile_conf/models/hr_employee.py`
- Find the existing `write()` override that triggered the microservice job
- **Replace** with this much simpler logic:
  - When `image_1920` is in vals:
    - If new image is provided → set `face_embedding_status = 'pending'`
    - If image was removed (None) → set `face_embedding_status = 'none'`, clear `face_embedding` field, bump version
  - That's it. **No job creation. No cron scheduling. No HTTP call.**
- The nightly cron picks up 'pending' employees automatically
- Keep all existing fields (face_embedding, face_embedding_status, etc.) — no schema changes

**Definition of done:** Updating an employee photo sets status='pending' and returns immediately. No errors, no slowness, no microservice call.

---

#### `[DONE]` R.7 — Delete face.embedding.job model and 1-minute cron
- Delete the `face.embedding.job` model entirely (file and registration)
- Delete the 1-minute cron from `emp_mobile_conf/data/cron_data.xml` (or wherever it was defined)
- Search the entire codebase for any remaining references to `face.embedding.job` — remove all
- If a migration is needed because the model was previously created on dev DB → write a migration script that drops the table

**Definition of done:** No trace of face.embedding.job anywhere. Codebase is clean.

---

#### `[TODO]` R.8 — Create nightly cron (the new one)
- Create or update `emp_mobile_conf/data/cron_data.xml`
- Define an `ir.cron` record:
  - **Name:** "Face Recognition: Process Pending Embeddings"
  - **Model:** `hr.employee`
  - **Method:** `_cron_process_pending_embeddings`
  - **Interval:** Every 1 day
  - **Next Call:** Today at 2:00 AM (server time)
  - **Active:** True
- Implement `_cron_process_pending_embeddings` on `hr.employee`:
  - Find employees with status in ('pending', 'failed') AND retry_count < 3 (add retry_count field if not already present)
  - Process in batches of 50
  - For each: call `emp_mobile_conf.face_inference.inference.generate_embedding(image_bytes)`
  - On success: store embedding, set status='ready', clear retry_count
  - On failure: set status='failed', increment retry_count, store error message
  - Commit transaction every 50 (use `self.env.cr.commit()` with care)
  - Log progress: "Processed N employees: X ready, Y failed, Z deferred"
  - At the end, call `face.db.version.bump()` ONCE
- Wrap the whole thing in try/except — never let one bad photo crash the entire cron

**Definition of done:** Manually trigger the cron from Odoo UI ("Run Manually"). Confirm it processes all pending employees, updates status, and bumps version once.

---

#### `[DONE]` R.9 — Update bulk enrollment script
- Open `emp_mobile_conf/scripts/bulk_enroll_embeddings.py`
- Refactor to use the new inline inference (not HTTP to microservice)
- Logic is identical to R.8 cron, just runs once over ALL employees with image_1920 (not filtered by status)
- Add clear progress output: "Processing employee 42 of 1000..."
- Document in README: this is run ONCE after deploy, then nightly cron handles the rest

**Definition of done:** Script runs cleanly on dev DB. Existing test photos get embeddings. Output is informative.

---

#### `[DONE]` R.10 — Update admin "Recompute" button
- Open `emp_mobile_conf/views/hr_employee_views.xml`
- Find the existing "Recompute Embedding" button on the Face Recognition tab
- Update its action to:
  - Run `generate_embedding` **synchronously** for this single employee
  - Display result immediately (success toast or failure message)
  - Update face.db.version on success
- This is the Odoo support team's tool for handling urgent cases without waiting for nightly cron
- Restrict button visibility to admin / HR Manager groups only

**Definition of done:** Admin clicks button → waits 1-3 seconds (first call may be longer due to model load) → status updates immediately → success/error message shown.

---

#### `[TODO]` R.11 — Remove microservice service URL config
- Open `emp_mobile_conf/data/ir_config_data.xml` (or wherever the service URL was defined)
- **Remove** these config parameters:
  - `face_embedding_service.url`
  - `face_embedding_service.timeout_seconds`
  - `face_embedding_service.retry_attempts`
- These are no longer needed (no microservice to call)
- If there's an upgrade migration concern (parameters exist in dev DB), add a cleanup in post-migration script

**Definition of done:** Config parameters removed from XML. Dev DB cleaned up.

---

#### `[DONE]` R.12 — Delete face_embedding_service directory
- Confirm with the user one more time that the microservice was never deployed
- After confirmation: delete the entire `face_embedding_service/` directory (Dockerfile, app/, tests/, requirements.txt, README.md, everything)
- Remove any references to it in deployment configs (docker-compose.yml, CI/CD scripts, etc.) if any exist
- Commit with message: `refactor(face-rec): R.12 remove unused face_embedding_service microservice`

**Definition of done:** Directory gone. No deployment configs reference it. Git log shows clean removal.

---

#### `[DONE]` R.13 — Verify elrace_backend_apis endpoints still work
- Endpoints in this module were independent of how embeddings are computed
- They read `face_embedding` field from `hr.employee` regardless of how it got there
- **No code changes expected here.** Just verify:
  - `/api/face_db/version` still returns correct version
  - `/api/face_db/embeddings` still returns embeddings for ready employees
  - Both endpoints still respect auth + rate limits

**Definition of done:** Both endpoints work end-to-end after refactor. No regression.

---

#### `[DONE]` R.14 — Update READMEs
Three READMEs to update:

**`emp_mobile_conf/README.md`:**
- Remove all mentions of microservice
- Add section "Face Recognition (Inline)" explaining the architecture
- Document Python package requirements (onnxruntime, opencv-python-headless, numpy, pillow)
- Document the nightly cron and how to trigger it manually
- Document the "Recompute" button for support team
- Document the bulk enrollment script for initial migration

**`elrace_backend_apis/README.md`:**
- Remove any mention of microservice as a dependency
- Update only if endpoints documentation referenced it

**`face_recognition_runbook.md` (operations runbook — if it exists):**
- Update for inline architecture
- "How to recompute" → click button in admin form
- "How to investigate failures" → check hr.employee.face_embedding_error field
- "How to upgrade the model" → replace ONNX file, restart Odoo, run bulk_enroll
- Remove all microservice-specific troubleshooting

**Definition of done:** All three docs updated. No leftover microservice references.

---

### Phase V — Verification

#### `[TODO]` V.1 — Full integration test on dev
- Reset dev DB to clean state (or clean test scenario)
- Install/upgrade `emp_mobile_conf` and `elrace_backend_apis` modules
- Verify Odoo starts cleanly (model should NOT load yet — lazy)
- Upload a photo for test employee #1 via Odoo UI
- Verify status='pending' immediately
- Manually trigger nightly cron from Odoo UI
- Verify:
  - Model loads (~1-3 second delay on first call)
  - Status transitions to 'ready'
  - Embedding stored as binary
  - face.db.version incremented
- Upload photo for test employee #2
- Verify status='pending'
- Manually trigger cron again
- Verify model is FAST this time (cached)
- Call `/api/face_db/version` → returns new version
- Call `/api/face_db/embeddings` → returns both embeddings

**Definition of done:** End-to-end works. First model load slow (expected), subsequent fast.

---

#### `[TODO]` V.2 — Failure path test
- Upload an obviously bad photo (e.g., a landscape with no face, or two faces)
- Wait for cron (or trigger manually)
- Verify:
  - Status='failed'
  - face_embedding_error populated with reason
  - retry_count incremented
- Run cron 2 more times
- Verify retry_count reaches 3 then stops being retried
- Verify other (good) photos in the same batch still process correctly
- Verify cron didn't crash

**Definition of done:** Failures isolated, retried up to limit, then deferred. Good employees not impacted.

---

#### `[TODO]` V.3 — Bulk enrollment dry run
- Take ~50 sample employee records with photos on dev
- Run `bulk_enroll_embeddings.py`
- Verify all process correctly
- Check timing: should be ~15-25 seconds (50 × ~300ms)
- Verify face.db.version bumped once at the end (not 50 times)

**Definition of done:** Script works on representative scale.

---

#### `[TODO]` V.4 — Admin recompute button test
- Use an employee with status='failed'
- Click "Recompute Embedding" in admin tab
- Verify:
  - Button works synchronously (1-3 sec wait)
  - Status updates immediately
  - Success/failure message shown
  - face.db.version bumped

**Definition of done:** Manual override works as expected. Odoo support team workflow validated.

---

### Phase D — Deployment Prep

#### `[TODO]` D.1 — Pre-deployment checklist
Before deploying to staging:
- [ ] All Phase R tasks DONE
- [ ] All Phase V tasks pass
- [ ] Python packages list documented for support team (onnxruntime etc.)
- [ ] Bulk enrollment script tested
- [ ] Admin button tested
- [ ] No lingering references to microservice anywhere
- [ ] Updated READMEs reviewed
- [ ] Backup plan documented

**Definition of done:** Checklist all checked.

---

#### `[TODO]` D.2 — Staging deployment
- Coordinate with Odoo support team
- Install required Python packages in Odoo's environment
- Upgrade `emp_mobile_conf` module
- Verify Odoo starts cleanly
- Run bulk enrollment script on staging
- Verify success rate ≥ 95%
- Sample API calls work
- Wait one nightly cycle (or trigger cron manually)
- Verify ongoing processing works

**Definition of done:** Staging fully functional. Support team verified.

---

#### `[TODO]` D.3 — Production deployment
- Off-hours window
- Same steps as D.2 for production
- Monitor for 24 hours
- Watch first nightly cron run carefully (logs)
- Confirm with mobile team that they can fetch embeddings

**Definition of done:** Production stable. Mobile team verified. No incidents in first 48 hours.

---

## 6. Anti-patterns (do NOT do these during refactor)

| Anti-pattern | Why wrong | Do this instead |
|--------------|-----------|-----------------|
| Keeping the microservice "just in case" | Dead code rots, confuses future devs | Delete cleanly |
| Loading the ONNX model in module `__init__.py` | Slows down EVERY Odoo restart, even if face recognition isn't used | Lazy load on first inference call |
| Calling generate_embedding() inside write() | Slows HR UI to 1-3 seconds per photo upload | Just mark pending, let nightly cron handle |
| Running cron more frequently to "be safe" | Defeats the simplification | Once nightly is fine; admin button for urgent cases |
| Hardcoding the ONNX model file path | Breaks across environments | Resolve via Odoo addons path API |
| Committing every employee (not every 50) | Slow due to transaction overhead | Batch commits every 50 |
| Bumping face.db.version after every employee | Mobile clients re-sync constantly | Bump ONCE at end of cron run |
| Forgetting to handle "no photo" case | Status stays 'pending' forever if photo deleted | When image removed, set status='none', clear embedding |
| Not testing first model load time | Surprise slowness in production | Validate on dev: first call slow, rest fast |

---

## 7. Decisions Log

```
[YYYY-MM-DD] TASK_ID — Decision: <what>. Rationale: <why>.
```

Initial entries to add at start:
- Architecture refactor from microservice to inline + nightly cron
- Rationale: ~1000 employees, rare photo changes, simpler ops, no urgency requirement
- Microservice never deployed — refactoring uncommitted code, no rollback needed

```
[2026-05-21] R.0 — Decision: face_embedding_service not on origin/elrace-addons; all face-rec files local untracked only. Rationale: git ls-files empty; remote path missing; no docker/k8s deploy config; no .onnx in repo.
[2026-05-21] R.0 — Decision: Snapshot branch pre-refactor-inline-2026 created locally on odoo14-clients (elrace-addons).
```
- Cron runs at 2 AM server time (off-hours)
- Recompute button is synchronous for support team manual cases
- Retry limit: 3 attempts per failed embedding before stopping

---

## 8. Definition of Refactor Complete

- [ ] All R tasks (R.0 → R.14) marked DONE
- [ ] All V tasks (V.1 → V.4) pass
- [ ] face_embedding_service/ directory deleted
- [ ] No leftover references to microservice anywhere in codebase
- [ ] emp_mobile_conf has all inference code internally
- [ ] Nightly cron defined and tested
- [ ] Admin synchronous button works
- [ ] elrace_backend_apis endpoints unchanged and still working
- [ ] All three READMEs updated
- [ ] flutter / mobile team contract unchanged (same API responses)
- [ ] Decisions Log updated

---

## 9. Estimated Effort

| Phase | Tasks | Effort |
|-------|-------|--------|
| R — Refactor | R.0 → R.14 | ~1 working day |
| V — Verification | V.1 → V.4 | ~0.5 day |
| D — Deployment | D.1 → D.3 | ~0.5 day (varies by ops process) |
| **Total** | | **~2 working days** |

This is dramatically less than the original build (which was ~7 days) because:
- ONNX inference code is already written (just moving it)
- Database schema doesn't change
- API endpoints don't change
- No new microservice to operate

---

— End of Refactor Task File —
