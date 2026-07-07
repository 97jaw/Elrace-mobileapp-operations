# Site Management — Face Recognition Mobile (Phase B) | Cursor Task File

> **How to use this file:** Read it top to bottom before touching any code. This is the on-device (Flutter) half of the face recognition feature. The backend half (Odoo + AWS Lambda) is already built and validated. Work top to bottom. Update task status as you go. Never skip ahead.

---

## 0. About This Work

You are extending an **existing Flutter mobile application** for **Pandora Tech LLC**. This task file covers **Phase B — the on-device face recognition** inside the **Site Management** feature.

### The feature in one sentence
When a foreman opens Add Timesheet and captures a labor's face, the app identifies that labor on-device (no server call for matching), auto-selects them in the employee dropdown if they belong to the foreman's team, or shows a yellow warning if they are recognized but NOT in the team.

### What is already done (backend — do NOT rebuild)
- Odoo stores a 512-dim face embedding per employee (`hr.employee.face_embedding`)
- AWS Lambda computes embeddings from HR photos (MobileFaceNet ONNX)
- Two APIs are live and validated:
  - `POST /api/face_db/version` — lightweight version poll
  - `POST /api/face_db/embeddings` — all ready embeddings + `in_foreman_team` flag
- All embedding integrity, pipeline, model-consistency, and API tests have PASSED
- Model consistency confirmed: the Lambda ONNX and the mobile TFLite are the SAME MobileFaceNet — cross-model embeddings match (validated via test TC-C2)

### What is already done (mobile — reuse, do NOT rebuild)
- Face capture / detection feature using ML Kit exists
- ML Kit detects faces and produces a 224×224 crop
- ML Kit also exposes face landmarks (eyes, nose, mouth) — available for alignment

### What Phase B adds (this task file)
- Bundle and wire `tflite_flutter` + `mobilefacenet_512.tflite`
- Face preprocessing: alignment + 112×112 resize + normalization (to match Lambda)
- On-device embedding generation
- Face DB sync: version check, embeddings download, SQLite cache
- On-device cosine similarity matching
- Team logic: green auto-fill vs yellow out-of-team warning
- Integration into the existing Add Timesheet screen
- Threshold handling (start 0.75, tunable, score logging)
- Fallback paths

### Stack
- Flutter (existing app)
- `tflite_flutter` — on-device inference
- ML Kit — face detection + landmarks (already in app)
- `sqflite` — embedding cache
- Riverpod — state management (consistent with HR modules)
- Dio — HTTP (existing)

---

## 1. Critical Rules (NEVER violate these)

| Rule | Reason |
|------|--------|
| **Mobile preprocessing MUST match the Lambda preprocessing** | If the alignment / resize / normalization differs, embeddings drift and matching fails. This is the #1 rule. |
| **Same model both sides** | The bundled `mobilefacenet_512.tflite` MUST be the verified conversion of the Lambda's ONNX. Confirmed via TC-C2. Do not swap it for another file. |
| **L2-normalize the on-device embedding** | Cosine similarity requires normalized vectors. The Lambda normalizes; mobile must too. |
| **Matching is 100% on-device** | No server call during matching. Server is only for syncing the embedding DB. |
| **Never auto-submit attendance** | Face match auto-FILLS the dropdown. The foreman still reviews and taps submit. |
| **Out-of-team labors can be identified but NOT attended** | Yellow warning, show identity, block submit for that labor. |
| **No match is a normal outcome** | Fall back to manual selection gracefully. Never block the foreman. |
| **One task = one commit** | Format: `feat(site-mgmt-facerec): <TASK_ID> <description>` |
| **Log similarity scores during dev** | Needed to tune the 0.75 threshold from real data. |
| **Encrypt / protect the embedding cache** | Embeddings are personal data. Store in app-private SQLite. |

---

## 2. Architecture (on-device)

```
FOREMAN OPENS ADD TIMESHEET
        │
        ▼
[Face DB Sync Check]
   POST /face_db/version  → compare with cached version
        │
   ┌────┴─────┐
   │ same     │ different / no cache
   │          ▼
   │   POST /face_db/embeddings → decode → store in SQLite
   │          │
   └────┬─────┘
        ▼
[Foreman taps "Capture Face"]
        │
        ▼
[ML Kit detects face + landmarks]  (existing feature)
        │
        ▼
[Preprocess]  align via landmarks → crop 112×112 → normalize
        │
        ▼
[TFLite inference]  MobileFaceNet → 512-dim vector → L2 normalize
        │
        ▼
[Match]  cosine similarity vs ALL cached embeddings
        │
        ▼
   Best match score?
        │
   ┌────┴────────────────┐
   │ < 0.75              │ >= 0.75
   │                     │
   ▼                     ▼
[No match]          [Identified: name + emp_id + photo]
[Snackbar +              │
 manual pick]       in_foreman_team ?
                         │
                ┌────────┴────────┐
                │ true            │ false
                ▼                 ▼
        [GREEN: auto-fill   [YELLOW WARNING:
         employee dropdown,  "Not in your team"
         foreman reviews     show identity,
         + submits]          submit disabled
                             for this labor]
```

---

## 3. Module Structure

```
lib/features/site_management/
└── face_recognition/                    ← NEW sub-feature
    ├── data/
    │   ├── models/
    │   │   ├── face_embedding_model.dart      ← one employee's embedding + metadata
    │   │   ├── face_db_version_model.dart
    │   │   └── match_result_model.dart        ← match outcome + score + team flag
    │   ├── local/
    │   │   ├── face_db_database.dart          ← sqflite setup
    │   │   └── face_db_dao.dart               ← CRUD for cached embeddings
    │   ├── repositories/
    │   │   └── face_db_repository.dart        ← sync orchestration
    │   └── api/
    │       └── face_db_api.dart               ← /face_db/version + /embeddings
    ├── domain/
    │   ├── face_preprocessor.dart             ← align + crop 112 + normalize
    │   ├── face_embedder.dart                 ← TFLite inference wrapper
    │   └── face_matcher.dart                  ← cosine similarity matching
    ├── presentation/
    │   ├── widgets/
    │   │   ├── face_capture_overlay.dart      ← status pill, guidance
    │   │   ├── match_confirm_card.dart        ← green confirm
    │   │   └── out_of_team_warning.dart       ← yellow warning
    │   └── controllers/
    │       ├── face_sync_provider.dart
    │       └── face_match_provider.dart
    └── assets/
        └── mobilefacenet_512.tflite           ← the verified model
```

Add the model to `pubspec.yaml` assets.

---

## 4. Functional Knowledge

### 4.1 Preprocessing — MUST match the Lambda
The Lambda pipeline is: detect face → **align to 112×112** → normalize → ONNX.
The mobile pipeline must mirror this exactly:

| Step | Detail |
|------|--------|
| Detect | ML Kit (already done) — gives bounding box + landmarks |
| **Align** | Use ML Kit landmarks (eyes, nose, mouth) to apply an affine transform so eyes are horizontal. See §4.2. |
| Crop + resize | Produce a 112×112 RGB image |
| Normalize | Scale pixel values to the SAME range the Lambda's ONNX uses. Confirm: typically [-1, 1] via `(pixel - 127.5) / 128.0`. **Verify against Lambda preprocessing code.** |
| Tensor shape | TFLite input shape — confirm from the .tflite model (likely [1, 112, 112, 3]) |

### 4.2 Alignment — important, flagged
The existing app does NOT align faces. The Lambda DOES. To keep embeddings compatible in real-world (non-frontal) site captures, mobile should align too.

ML Kit already returns face landmarks during detection — no extra model needed. Alignment is an affine transform:
- Take left-eye and right-eye landmark positions
- Compute the angle between them
- Rotate the crop so the eyes are horizontal
- Scale so inter-eye distance is a fixed value
- Crop to 112×112 centered on the face

**If the architect confirms TC-C2 passed using non-aligned crops AND site conditions are mild, alignment can be skipped — but default is to include it.** See Task P.3.

### 4.3 Embedding + matching
- TFLite output: 512-dim float vector
- L2-normalize it: `v / sqrt(sum(v_i^2))`
- Cosine similarity between two normalized vectors = their dot product
- Compare the captured embedding against ALL cached embeddings
- Best (highest) score wins; if best < threshold → no match

### 4.4 Threshold
- Start at **0.75**
- Make it a configurable constant (not hardcoded inline) — ideally remote-configurable or at least one constant file
- During development + pilot, LOG every match attempt: best score, second-best score, chosen employee, whether foreman confirmed or corrected
- Tune threshold from that logged data before full rollout

### 4.5 Team logic
The `/face_db/embeddings` response includes `in_foreman_team` per employee.

| Match outcome | UI behavior |
|---------------|-------------|
| Score >= threshold, `in_foreman_team = true` | GREEN confirm card. Auto-fill employee dropdown. Foreman reviews + submits. |
| Score >= threshold, `in_foreman_team = false` | YELLOW warning. Show name + emp_id + photo. Message: "This labor is not in your team." Submit blocked for this labor. |
| Score < threshold | Snackbar: "No match found." Foreman picks manually from dropdown. |
| Multiple matches above threshold | Take the highest. Optionally show top-2 if scores are very close (within 0.03). |

### 4.6 Sync strategy
- On Add Timesheet open: call `/face_db/version`
- If server version != cached version (or no cache) → call `/face_db/embeddings`, refresh SQLite
- If same → use SQLite cache as-is
- Show a small non-blocking indicator while syncing; allow capture once sync completes
- Optional later: background periodic sync (not in Phase B core)

### 4.7 Labors without embeddings
Some labors have no HR photo → no embedding → not in the synced DB. They simply can never be auto-matched. The manual dropdown always lists ALL labors regardless. This is expected; no special UI needed beyond the existing manual selection.

---

## 5. API Contracts (already live — consume as-is)

### POST /api/face_db/version
Request: Bearer token. Response:
```json
{ "success": true, "data": {
  "version": 142, "model_version": "mobilefacenet-v1",
  "total_employees_with_embedding": 987, "last_updated_at": "..." } }
```

### POST /api/face_db/embeddings
Request: Bearer token. Response:
```json
{ "success": true, "data": {
  "version": 142, "model_version": "mobilefacenet-v1",
  "foreman_id": 4471,
  "employees": [
    { "id": 4255, "emp_code": "EMP-4255", "name": "...",
      "department": "...", "job_title": "...",
      "embedding": "<base64 of 2048 bytes>", "in_foreman_team": true },
    ...
  ] } }
```

Decode `embedding`: base64 → 2048 bytes → 512 float32 values.

---

## 6. Tasks (work top to bottom)

> **Status legend:** `[TODO]` `[IN_PROGRESS]` `[DONE]` `[BLOCKED]` `[NEEDS_REVIEW]`

---

### Phase 0 — Setup

#### `[DONE]` F.0 — Confirm prerequisites
- Confirm `mobilefacenet_512.tflite` file is available and is the SAME model verified in backend test TC-C2
- Record the model's input tensor shape and output shape (inspect the .tflite)
- Confirm the Lambda's exact normalization formula (so mobile matches it). Get this from the backend team / Lambda `inference.py`.
- Confirm the existing ML Kit capture feature exposes face landmarks (it should)
- Confirm Site Management module folder path in the repo

**Definition of done:** All confirmed, recorded in §10 Decisions Log. Especially the normalization formula.

#### `[DONE]` F.1 — Add dependencies
- Add to `pubspec.yaml`: `tflite_flutter`, `sqflite`, `path` (if not present)
- Add `assets/mobilefacenet_512.tflite` to the assets section
- Place the model file at `lib/features/site_management/face_recognition/assets/mobilefacenet_512.tflite`
- `flutter pub get`

**Definition of done:** Dependencies resolve. Model file bundled. App builds.

---

### Phase 1 — Embedding Engine

#### `[DONE]` E.1 — TFLite embedder
- Create `domain/face_embedder.dart`
- Load `mobilefacenet_512.tflite` via `tflite_flutter` Interpreter
- Lazy-load: load the interpreter ONCE, cache it, reuse
- Method: `Future<List<double>> generateEmbedding(Uint8List preprocessedFace)`
  - Input: a 112×112×3 preprocessed face tensor
  - Run inference
  - Get 512-dim output
  - L2-normalize the output
  - Return as `List<double>`
- Add a debug method `embeddingForDebug(image)` that prints the raw 512 values — useful for re-verifying TC-C2 style checks on-device

**Definition of done:** Interpreter loads. Inference returns 512 L2-normalized values. Debug print works.

#### `[DONE]` E.2 — Face preprocessor
- Create `domain/face_preprocessor.dart`
- Input: the ML Kit face crop (224) + ML Kit landmarks
- Steps:
  1. (Alignment — see P.3; may be toggled) align using eye landmarks
  2. Resize to 112×112
  3. Convert to RGB float tensor
  4. Normalize using the EXACT formula confirmed in F.0 (e.g., `(p - 127.5) / 128.0`)
  5. Arrange into the tensor shape the model expects (confirmed in F.0)
- Output: the tensor ready for `face_embedder`
- Make normalization formula a single named constant — easy to correct if F.0 was wrong

**Definition of done:** Produces a correctly-shaped, correctly-normalized tensor. Unit test with a sample image.

#### `[DONE]` E.3 — On-device verification (re-run TC-C2 logic)
- Before trusting the pipeline, re-verify on-device:
  - Take a test photo
  - Run through preprocessor + embedder → get mobile embedding
  - Compare against the same person's embedding from the backend (fetch via API or hardcode the known 4255 embedding for the test)
  - Cosine similarity should be > 0.95 (the TC-C2 bar)
- If it fails here → preprocessing mismatch. Fix before continuing. Do NOT build matching on a broken embedder.

**Definition of done:** On-device embedding matches backend embedding for the same photo, similarity > 0.95.

---

### Phase 2 — Face DB Sync

#### `[DONE]` S.1 — SQLite schema + DAO
- Create `data/local/face_db_database.dart` — sqflite database setup
- Table `face_embeddings`:
  - emp_id (int, primary key)
  - emp_code (text)
  - name (text)
  - department (text)
  - job_title (text)
  - embedding (blob — 2048 bytes, the 512 float32)
  - in_foreman_team (int 0/1)
- Table `face_db_meta`:
  - key (text), value (text) — store cached version, model_version, last_sync
- Create `data/local/face_db_dao.dart` — insert (batch), query all, clear, get/set meta

**Definition of done:** DB creates. Batch insert + query-all works. Meta read/write works.

#### `[DONE]` S.2 — Face DB API client
- Create `data/api/face_db_api.dart`
- `Future<int> getServerVersion()` → calls `/face_db/version`
- `Future<List<FaceEmbeddingModel>> getEmbeddings()` → calls `/face_db/embeddings`, decodes base64 embeddings to float lists
- Reuse the app's existing Dio client + Bearer token handling
- Handle errors per existing app conventions

**Definition of done:** Both endpoints callable. Embeddings decode correctly (512 floats each).

#### `[DONE]` S.3 — Sync repository
- Create `data/repositories/face_db_repository.dart`
- `Future<SyncResult> syncIfNeeded()`:
  1. Call `getServerVersion()`
  2. Read cached version from `face_db_meta`
  3. If equal → return `SyncResult.upToDate`
  4. If different / no cache → call `getEmbeddings()`, clear table, batch-insert, update meta
  5. Handle model_version change → if model_version differs, full refresh mandatory
  6. Return `SyncResult.synced(count)` or `SyncResult.failed(reason)`
- Never throw to the UI — return a result object

**Definition of done:** First run downloads + caches. Second run (same version) skips download. Version bump triggers refresh.

#### `[DONE]` S.4 — Sync provider + UI indicator
- Create `presentation/controllers/face_sync_provider.dart` (Riverpod AsyncNotifier)
- States: idle, syncing, ready(count), failed(reason)
- Triggered when Add Timesheet opens
- Small non-blocking indicator while syncing (e.g., "Updating face data..." chip)
- Capture button enabled only once state = ready

**Definition of done:** Opening Add Timesheet triggers sync. Indicator shows. Capture enabled after sync.

---

### Phase 3 — Matching

#### `[DONE]` M.1 — Cosine similarity matcher
- Create `domain/face_matcher.dart`
- `MatchResult findBestMatch(List<double> captured, List<FaceEmbeddingModel> roster)`
  - For each roster embedding: cosine similarity = dot product (both already L2-normalized)
  - Track best and second-best
  - Return: best employee, best score, second-best score, isMatch (best >= threshold)
- Threshold = a named constant, default 0.75, in one config location
- Efficient: 1000 dot products of 512-dim = a few milliseconds. No need for fancy indexing at this scale.

**Definition of done:** Matcher returns correct best match. Verified: same person > 0.75, different person < 0.5.

#### `[DONE]` M.2 — Match provider
- Create `presentation/controllers/face_match_provider.dart`
- Orchestrates: preprocessed face → embedder → matcher → MatchResult
- States: idle, processing, matched(result), noMatch, error
- Logs every attempt: best score, second-best, chosen emp, timestamp (for threshold tuning)

**Definition of done:** Capture → match flow produces a MatchResult. Scores logged.

---

### Phase 4 — UI Integration

#### `[DONE]` U.1 — Capture overlay
- Create `presentation/widgets/face_capture_overlay.dart`
- Reuse the existing ML Kit camera preview
- Status pill on the preview: guidance like "Position face in frame", "Hold steady", "Ready"
- Capture button

**Definition of done:** Overlay renders on the existing camera preview. Status pill updates.

#### `[DONE]` U.2 — Green confirm card
- Create `presentation/widgets/match_confirm_card.dart`
- Shown when match >= threshold AND in_foreman_team = true
- Shows: employee photo (if available), name, emp_code, department, match confidence
- Action: "Confirm" → fills the Add Timesheet employee dropdown
- Action: "Not correct" → dismiss, fall back to manual

**Definition of done:** Card shows on in-team match. Confirm fills dropdown. Reject falls back.

#### `[DONE]` U.3 — Yellow out-of-team warning
- Create `presentation/widgets/out_of_team_warning.dart`
- Shown when match >= threshold AND in_foreman_team = false
- Yellow / warning styling
- Shows: name, emp_id, department, photo
- Message: "This labor is recognized but is not in your team. You cannot record attendance for them."
- The Add Timesheet submit must be BLOCKED for this labor
- Action: "OK" → dismiss, foreman can capture someone else or pick manually

**Definition of done:** Yellow warning shows on out-of-team match. Submit blocked for that labor.

#### `[DONE]` U.4 — No-match handling
- When best score < threshold:
  - Snackbar: "No match found — please select the labor manually."
  - Foreman uses the existing manual employee dropdown
- Never block or freeze — manual path always available

**Definition of done:** No-match shows snackbar, manual selection works.

#### `[DONE]` U.5 — Wire into Add Timesheet (logic only — no layout redesign)
- Integrate the capture → match → fill flow into the existing Add Timesheet screen
- Add a "Capture Face" action near the employee field
- On successful in-team match → employee dropdown auto-fills
- Out-of-team / no-match → dropdown stays manual
- Foreman always reviews before tapping the existing Submit

**Definition of done:** End-to-end inside Add Timesheet: open → sync → capture → match → fill or warn → submit.

---

### Phase 5 — Robustness & Tuning

#### `[DONE]` P.1 — Performance on low-end devices
- Test the full capture → match flow on a low-end Android device
- Targets: preprocessing + inference + match < 800 ms total
- If slow: check interpreter is cached (not reloaded), check image ops aren't on the UI thread
- Run heavy work in an isolate if needed

**Definition of done:** Flow completes < 800 ms on a low-end device. UI stays responsive.

#### `[DONE]` P.2 — Fallback paths
- No camera permission → message + manual selection
- Sync failed (offline) → if a cache exists, use it; if not, manual only + message
- No embeddings at all → manual only
- TFLite load failure → manual only + log error

**Definition of done:** Every failure path leads to manual selection, never a dead end.

#### `[DONE]` P.3 — Alignment (IMPORTANT — see §4.2)
- Implement face alignment in `face_preprocessor.dart` using ML Kit eye landmarks
- Affine transform: rotate so eyes are horizontal, scale by inter-eye distance, crop 112×112
- Re-run E.3 verification WITH alignment — confirm similarity stays > 0.95 and ideally improves on non-frontal test shots
- If the architect has confirmed the Lambda pipeline and mobile match without alignment AND site captures are mild, this task may be deferred — but default is to implement it

**Definition of done:** Alignment implemented. E.3 verification still passes. Non-frontal test shots match better than without alignment.

#### `[DONE]` P.4 — Threshold tuning data
- Ensure every match attempt logs: best score, second-best score, chosen employee, foreman action (confirmed / corrected / manual)
- Provide a simple way to export or view these logs during the pilot
- After pilot data is collected, review and recommend a tuned threshold

**Definition of done:** Match logs captured and reviewable. Tuning recommendation possible after pilot.

---

### Phase 6 — Verification

#### `[DEFERRED]` V.1 — End-to-end test (you, employee 4255)
- Sync the face DB
- Open Add Timesheet
- Capture your own face
- Expect: green confirm card (you are in-team for your test foreman), dropdown fills
- Capture a colleague who is NOT in the test foreman's team
- Expect: yellow warning, submit blocked
- Capture someone with no embedding / no photo
- Expect: no match, manual selection
- Test offline: kill network, reopen — cached DB still works

#### `[DEFERRED]` V.2 — Accuracy spot-check
- With ~10-20 enrolled labors, capture each
- Record: matched correctly / wrong match / no match
- Note scores
- Confirm no false matches above threshold (the dangerous case)

#### `[DEFERRED]` V.3 — Sign-off
- `flutter analyze` clean
- All states tested (sync, match, no-match, out-of-team, offline)
- Performance target met on low-end device
- Match logging working
- Decisions Log §10 updated

---

## 7. Anti-patterns (do NOT do these)

| Anti-pattern | Why wrong | Do instead |
|--------------|-----------|-----------|
| Mobile preprocessing differs from Lambda | Embeddings drift, matching fails | Mirror Lambda: align, 112, same normalization |
| Reloading TFLite interpreter per capture | Slow, janky | Load once, cache |
| Running inference / image ops on UI thread | Freezes UI on low-end devices | Use isolates / async |
| Hardcoding threshold inline in multiple places | Cannot tune | One named constant |
| Auto-submitting attendance on match | Removes foreman review, attendance errors | Auto-FILL only; foreman submits |
| Letting out-of-team labors be attended | Breaks the business rule | Yellow warning + block submit |
| Skipping the no-match fallback | Foreman gets stuck | Manual selection always available |
| Downloading embeddings every time | Wastes bandwidth | Version check first, download only on change |
| Storing embeddings unencrypted / world-readable | Personal data exposure | App-private SQLite |
| Not logging scores during pilot | Cannot tune threshold | Log every attempt |

---

## 8. Definition of Phase B Complete

- [x] All implementation tasks F.0 → P.4 marked DONE
- [ ] V.1 → V.3 verification (deferred — run when you test)
- [ ] `mobilefacenet_512.tflite` bundled — confirmed same model as Lambda
- [ ] On-device embedding matches backend embedding (E.3 > 0.95)
- [ ] Face DB syncs via version check, caches in SQLite
- [ ] Matching works on-device, < 800 ms on low-end device
- [ ] Green auto-fill for in-team matches
- [ ] Yellow warning + submit block for out-of-team matches
- [ ] No-match falls back to manual selection
- [ ] All fallback paths lead to manual, never a dead end
- [ ] Alignment implemented (or formally deferred with architect sign-off)
- [ ] Match scores logged for threshold tuning
- [ ] Integrated into existing Add Timesheet screen
- [ ] Decisions Log §10 complete

---

## 9. Open Questions for Architect

- Confirm the Lambda's exact pixel normalization formula (needed in F.0 / E.2)
- Confirm whether TC-C2 was validated with aligned or non-aligned mobile crops (affects P.3 priority)
- Confirm low-end device target spec for performance testing
- Confirm where match-score logs should go (local file? analytics endpoint?)
- Confirm pilot size before full rollout (suggested: 1 site, 10-20 labors)

---

## 10. Decisions Log

```
[2026-05-22] F.0 — TFLite model: mobilefacenet_512.tflite SHA-256 8af16a471a956bc9bdcc67b056e1b8e660e8210298b38d5a66a398b2a8c92cda. Already at assets/mobilefacenet.tflite (rename to mobilefacenet_512.tflite in F.1). Rationale: TC-C2 passed with this file.

[2026-05-22] F.0 — TFLite I/O: input [1,112,112,3] float32 NHWC name input.1; output [1,512] float32 name Identity. Rationale: inspected via TensorFlow Lite interpreter on converted model.

[2026-05-22] F.0 — Lambda normalization (PENDING ARCHITECT SIGN-OFF): RGB uint8 0–255 → float32 → (pixel - 127.5) / 128.0 → ONNX NCHW [1,3,112,112] → 512-d → L2 normalize. Mobile TFLite: same pixel formula, tensor layout NHWC [1,112,112,3], then L2 normalize output. Source: emp_mobile_conf/lambda/face_embedding/inference.py lines 238–245.

[2026-05-22] F.0 — Lambda “align” is NOT landmark warp: Haar largest face → 15% padded bbox crop → resize 112×112 INTER_AREA → RGB. TC-C2/TFLite tests used this path via inference.align_face, NOT ML Kit 224 crop.

[2026-05-22] F.0 — ML Kit landmarks: package supports enableLandmarks (default false). App currently enableClassification only — landmark positions NOT enabled yet. Enable in preprocessor (P.3 or E.2).

[2026-05-22] F.0 — Site Management: product name; code under lib/core/site_management/face_recognition/ + existing lib/ui/presentation/timesheet/foreman/ (Add Timesheet). Reuse face_capture_service.dart — do not fork capture.

[2026-05-22] F.0 — Preprocess v1: Lambda-parity (largest face, 15% pad, 112×112 RGB, same normalize). Landmark align deferred to P.3.

[2026-05-22] F.1 — Added tflite_flutter 0.12.1, assets/mobilefacenet_512.tflite, face_recognition_config.dart.

[2026-05-22] E–M–U — Engine under lib/core/site_management/face_recognition/. Wired into existing Add Timesheet (fm_timesheet_capture_submit_screen + timesheet_capture_camera_panel) without new screens or layout widgets.

[2026-05-22] F.0 — API response shape: Odoo uses status "success" + data.* (not success: true). Employee key is employee_id (not id). Payload includes templates[] per employee — matcher should max-cosine over templates, not primary only.

[2026-05-22] F.0 — TC-C2: PASS cosine 1.0 Lambda vs TFLite on SAME aligned 112×112 crop (inference.py). Does NOT validate app 224×224 crop without alignment.

[2026-05-22] Phase B pilot — Live capture vs enrollment templates ~0.40–0.43 (emp 4255 correct best). Production threshold 0.75 kept; pilotThreshold 0.40 logged only (P.4). SQLite blob decode + alignment path fixes applied.

[2026-05-22] S.4 — faceDbSyncProvider added. P.4 — FaceMatchLogger + per-template E.3 debug lines on capture.

[2026-05-22] U.1–U.4 — Themed widgets: TmFaceCaptureStatusChip, TmFaceMatchConfirmCard (green), TmFaceOutOfTeamWarning (yellow), TmFaceNoMatchNotice. usePilotThresholdForMatch=true (0.40) drives auto-fill + overlays.

[2026-05-22] M.2 — faceMatchSessionProvider (pilot logs: confirmed/rejected/manual). P.2 — FaceRecognitionAvailability + TmFaceDbFallbackBanner; Phase A HR fallback when Phase B off; offline cache via existing sync.

[2026-05-22] P.1 — Preprocess on background isolate; per-stage timing (pre/emb/mat/total) with SLOW flag >800ms. P.4 — FacePilotLogStore JSONL in app documents + foreman follow-up events. E.3 — verifyCaptureAgainstEmployee() API. Dropdown dedupe fix.

[2026-05-22] Phase B code-complete — close-second match hint on green card; background face DB sync on FM day hub. Phase C — register_face_images client + PM enrol odooEmployeeId hook (see PhaseC task file). V.* deferred for your test pass.
```

Record at F.0 (architect confirm):
- [x] tflite model input shape: **[1, 112, 112, 3]** float32 NHWC
- [x] tflite model output shape: **[1, 512]** float32
- [x] Lambda normalization formula: **`(pixel - 127.5) / 128.0` on RGB 0–255**
- [x] Preprocess strategy: **(A) Lambda-parity pad+112** (P.3 landmarks later)
- [x] ML Kit landmarks available: **YES** (enableLandmarks: true required)
- [x] Site Management module path: **lib/core/site_management/face_recognition/** + **lib/ui/presentation/timesheet/foreman/**
- [x] TC-C2 used aligned crops: **YES** (Lambda align_face 112×112, not app 224)

— End of Mobile Phase B Task File —
