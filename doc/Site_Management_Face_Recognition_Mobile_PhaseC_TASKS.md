# Site Management — Face Recognition Mobile (Phase C) | Task File

> **Enrollment** — upload multi-pose JPEGs to Odoo; Lambda writes embeddings; mobile refreshes face DB.
> **UI polish deferred** — core API wired; PM enrol accepts optional `odooEmployeeId`.

---

## Status

| Task | Status |
|------|--------|
| C.1 — `FaceEnrollmentApi` multipart `register_face_images` | DONE |
| C.2 — `FaceEnrollmentRepository` + post-upload `forceRefresh` | DONE |
| C.3 — `FaceEnrollmentService.enrollFromPhotoList` | DONE |
| C.4 — Riverpod `faceEnrollmentServiceProvider` | DONE |
| C.5 — PM worker enrol path when `odooEmployeeId` set | DONE |
| C.6 — Dedicated enrollment UI (camera poses, HR picker) | DEFERRED (your UI pass) |

---

## API (live on Odoo)

`POST /api/register_face_images` — fields: `employee_id`, files `front_image`, `left_image`, `right_image`, `up_image`, `down_image` (≥4 required).

See `emp_mobile_conf/README_FACE_ENROLLMENT.md` on the Odoo repo.

---

## Mobile usage (no new screen)

```dart
final result = await ref.read(faceEnrollmentServiceProvider).enrollFromPhotoList(
  employeeId: 4255,
  localPaths: [frontPath, leftPath, rightPath, upPath],
);
```

Route PM enrol with Odoo id:

```dart
PmWorkerEnrol(projectId: '...', odooEmployeeId: 4255)
```

After success, local SQLite face DB is force-refreshed on next sync.

---

## Definition of Phase C complete (code)

- [x] Multipart enrollment client
- [x] Refresh face DB after upload
- [x] Optional wire from existing PM enrol
- [ ] Full enrollment UX (deferred to your UI changes)

---

## Changelog

```
[2026-05-22] C.1–C.5 — Enrollment stack under lib/core/site_management/face_recognition/
```
