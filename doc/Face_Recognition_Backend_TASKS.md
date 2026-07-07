# Face Recognition — Backend | Cursor Task File

> **Status (2026-05-20):** Phase 0–3 scaffold implemented in `odoo14-clients`. Mobile Phase B integration is next.

---

## Implementation summary (done in repo)

| Component | Path | Status |
|-----------|------|--------|
| Embedding microservice | `odoo14-clients/face_embedding_service/` | F.1, E.1–E.4 scaffold |
| Odoo face fields + jobs | `emp_mobile_conf/models/hr_employee_face_embedding.py` | M.2–M.5 |
| Version singleton + cache | `emp_mobile_conf/models/face_db_version.py` | M.2 |
| Cron queue (no queue_job) | `emp_mobile_conf/data/face_embedding_config.xml` | M.5 |
| API version | `POST /api/face_db/version` | A.2 |
| API embeddings | `POST /api/face_db/embeddings` | A.3–A.4 |
| Serializer | `elrace_backend_apis/utils/face_db_serializer.py` | A.3 |
| Bulk script | `emp_mobile_conf/scripts/bulk_enroll_embeddings.py` | M.7 |
| Labor `image_url` | `timesheet_controller._timesheet_employee_card` | Always URL + `has_profile_image` |

---

## §11 Decisions Log

```
[2026-05-20] F.0 — queue_job: NO. Using ir.cron + face.embedding.job model (1 min).
[2026-05-20] F.0 — Foreman-to-labor field: hr.employee.x_labor_ids (elrace_employee_profile_fix).
[2026-05-20] F.0 — Async: mandatory via face.embedding.job + cron (not synchronous write).
[2026-05-20] A.2 — Mobile API style: POST jsonrpc + Bearer (matches existing elrace_backend_apis).
[2026-05-20] M.3 — Phase A labor_list still returns image_url for JPEG match until mobile uses embeddings API.
```

### Prerequisites
- [x] queue_job available: **NO** (using: `ir.cron` + `face.embedding.job`)
- [x] Foreman-to-labor field: **`x_labor_ids`**
- [ ] Photo update frequency: _TBD_
- [ ] Microservice deployment: _TBD_ (default localhost:8000)
- [ ] Monitoring stack: _TBD_
- [x] Failed embedding retry: **3 attempts** (1m / 5m / 30m backoff)
- [ ] Existing rate-limiting middleware: _TBD_

---

## Deploy order

1. Deploy **face_embedding_service** + place `mobilefacenet.onnx` in `app/models/`
2. Set Odoo parameter `face_embedding_service.url`
3. Upgrade **emp_mobile_conf** → upgrade **elrace_backend_apis**
4. Run `bulk_enroll_embeddings.py` on staging
5. Verify `POST /api/face_db/version` and `POST /api/face_db/embeddings`
6. **Then** mobile: sync embeddings + on-device cosine match (Phase B app work)

---

## Mobile next (after backend verified)

See `Module_6_Face_Recognition_Phases.md` — replace Phase A pixel match with:

1. Poll `/api/face_db/version` on Add timesheet open
2. If stale → download `/api/face_db/embeddings`
3. Match capture crop vs cached 512-dim vectors (cosine similarity)
4. Keep manual employee pick as fallback

---

_Full task checklist (F.0–H.3) unchanged below — mark items DONE as you verify on staging._
