# Site Management — Face recognition (Phase B)

**Site Management** is the product name; implementation lives next to the existing module:

- **Capture / Add Timesheet UI:** `lib/ui/presentation/timesheet/foreman/`
- **Shared capture service:** `lib/core/timesheet/services/face_capture_service.dart`
- **Phase B engine (this folder):** `lib/core/site_management/face_recognition/`

Phase B adds TFLite embeddings, `face_db` sync, and cosine match. It **extends** the current flow — does not replace Site Management screens.
