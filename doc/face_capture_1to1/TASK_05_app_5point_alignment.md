# TASK 05 — App: 5-point face alignment (probe + profile template)

Side: App (Flutter)
Depends on: TASK 03 (verification in place, so the effect is measurable in `FaceVerify:` logs)
Read first: `doc/FACE_CAPTURE_TECHNICAL_ANALYSIS.md` §2.4 and §3.3

## Context
The embedding model is InsightFace MobileFaceNet (`assets/mobilefacenet_512.tflite`, from `w600k_mbf.onnx`). InsightFace models are trained on faces warped with a **5-point similarity transform** to a fixed 112×112 reference. Today `face_preprocessor.dart` crops the box with 15 % padding and only rotates so the eyes are level. That input differs from training and compresses scores (genuine 0.39–0.54 in pilot logs). Aligning both the camera probe and the profile-photo template the standard way should raise genuine scores and widen the gap to other people.

## Files
- `lib/core/site_management/face_recognition/domain/face_preprocessor.dart` (chip building: `useLandmarkAlignment`, eye-based rotation, `_chipFromBoundingBox`, `buildChip112FromFile`, `buildInputTensorFromCaptureAsync`)
- `lib/core/site_management/face_recognition/face_recognition_config.dart` (`FaceRecognitionPreprocess`)
- `lib/core/site_management/face_recognition/profile_photo_face_db.dart` (`_pipelineVersion = 'mobilefacenet512-profile-v2'`, `_embed` uses `relaxedQuality: true` detection)
- `lib/core/timesheet/services/face_capture_service.dart` (ML Kit options; landmarks are enabled)

## Change
1. Add 5-point alignment to the preprocessor:
   - Reference points for 112×112 (ArcFace standard), in image coordinates:
     ```
     (38.2946, 51.6963)  image-left eye
     (73.5318, 51.5014)  image-right eye
     (56.0252, 71.7366)  nose tip
     (41.5493, 92.3655)  image-left mouth corner
     (70.7299, 92.2041)  image-right mouth corner
     ```
   - Source points from ML Kit landmarks: both eyes, `noseBase`, both mouth corners.
   - **Gotcha:** ML Kit `leftEye`/`leftMouth` are the *subject's* left (usually image-right). Do not map by name. Assign image-left / image-right by **x coordinate** (smaller x = image-left), for eyes and for mouth corners separately.
   - Estimate a **similarity transform** (rotation + uniform scale + translation, 4 DOF) by least squares (Umeyama), then warp the upright RGB source into 112×112 with bilinear sampling. Pixels outside the source → black (0).
   - Normalisation after warp unchanged: `(x − 127.5) / 128`.
2. Fallback: if any of the 5 landmarks is missing or the estimated scale is degenerate, use today's method (eye rotation + 15 % pad), and log `FacePreprocess: align fallback`.
3. Apply to **both** paths: live/still probe and the profile-photo template build. Confirm the template build's ML Kit detection returns landmarks with `relaxedQuality: true`; if not, enable them for that call.
4. Bump the profile template pipeline version (`_pipelineVersion`) so cached templates built with the old crop are rebuilt (e.g. `mobilefacenet512-profile-v3`). Old and new templates must never be compared with each other.
5. Keep a constant flag (e.g. `FaceRecognitionPreprocess.useFivePointAlignment = true`) to switch back to the old crop in one line if needed. Switching must also switch the pipeline version.
6. Anti-spoof crops (MiniFASNet 2.7× / 4.0× box crops) are **separate** and must not change.

## Do not
- Change the TFLite model, embedding size or normalisation constants.
- Change anti-spoof preprocessing.
- Change verification bars in code — they are tuned in Odoo after measuring.

## Verify
1. Unit test the transform: synthetic landmarks equal to the reference → identity warp; landmarks rotated/scaled/translated → warped points land within 1 px of the reference.
2. Unit test the left/right assignment with ML Kit-style labels swapped.
3. Determinism: same image twice → cosine ≥ 0.99.
4. On device, capture 10 known labors before and after (pilot log store / `FaceVerify:` lines): record target score and lead per labor. Expected: genuine target scores go **up** and leads over the cohort widen. Share the before/after table — Odoo bars (`elrace.face_verify_*`) are re-tuned from it.
5. Profile template cache rebuilds once after install (log shows the new pipeline version), then is reused.
6. Timing: preprocess stays within today's range on a low-end Android (log `pre…ms`).
