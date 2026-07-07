# Face recognition — phases

## Phase A (shipped in app — labor JPEG match)

- Foreman captures **labor** face on Add timesheet.
- Match roster = project **labors** from `/api/timesheet/labor_list`.
- Each labor has `image_url` + `has_profile_image` from Odoo.
- On-device pixel similarity vs HR photo; manual pick if no match.

## Phase B (backend ready — mobile next)

### Odoo + APIs (implemented in `odoo14-clients`)

| Piece | Description |
|-------|-------------|
| `face_embedding_service` | `POST /embed` → 512-dim embedding (MobileFaceNet ONNX) |
| `emp_mobile_conf` | Stores embedding on `hr.employee`; async job + cron |
| `POST /api/face_db/version` | Poll DB version |
| `POST /api/face_db/embeddings` | Download all ready embeddings + `in_foreman_team` |

### Mobile work (DONE — see `Site_Management_Face_Recognition_Mobile_PhaseB_TASKS.md`)

1. On Add timesheet: call `face_db/version`, sync `face_db/embeddings` if needed.
2. Cache embeddings locally per foreman.
3. After capture: cosine match crop embedding vs labor vectors (same model as server).
4. Fallback: Phase A JPEG match when Phase B off; manual pick always available.
5. Pilot threshold 0.40 + production 0.75; timing + JSONL pilot logs.

Verification (V.1–V.3) **deferred** until you run test cases.

## Phase C (mobile core DONE)

| Piece | Location |
|-------|----------|
| Multipart API | `face_enrollment_api.dart` |
| Repository + DB refresh | `face_enrollment_repository.dart` |
| Facade | `face_enrollment_service.dart` |
| PM hook | `PmWorkerEnrol(odooEmployeeId: …)` |

Dedicated enrollment UI → your upcoming UI pass (`Site_Management_Face_Recognition_Mobile_PhaseC_TASKS.md`).
