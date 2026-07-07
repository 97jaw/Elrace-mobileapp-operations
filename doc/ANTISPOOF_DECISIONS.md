# Anti-Spoof Decisions Log (§9)

## F.0 — License (2026-05-25)

- **License name:** Apache License 2.0
- **Source:** [minivision-ai/Silent-Face-Anti-Spoofing](https://github.com/minivision-ai/Silent-Face-Anti-Spoofing) (Copyright 2020 Minivision)
- **Commercial use permitted:** YES — Apache-2.0 allows use in proprietary commercial products with NOTICE preservation.
- **Conclusion:** GO
- **Weights used:** yakhyo/face-anti-spoofing ONNX releases (same architecture; converted to TFLite in-repo)

## F.1 — Model specs

| Model | Asset | Input | Crop scale | Classes | SHA256 |
|-------|-------|-------|------------|---------|--------|
| MiniFASNetV2 | `assets/antispoof/minifasnet_v2_2.7_80x80.tflite` | 80×80×3 float32 NHWC, 0–255 | 2.7 | 3 logits → softmax; index **1 = live** | `ec7d4de1488c0cd16c7ba483acf080206e34d9a9c47d47bde5a683963b351d4f` |
| MiniFASNetV1SE | `assets/antispoof/minifasnet_v1se_4.0_80x80.tflite` | 80×80×3 float32 NHWC, 0–255 | 4.0 | same | `02f12c07ac80d2adc3495921bd62700ff5c530c9ce0104f23e15c56e67b671a2` |

Regenerate: `python3.11 scripts/convert_minifasnet_to_tflite.py` (see `.venv_antispoof`).

## F.2 — Integration points

- **Capture UI:** `TimesheetCaptureCameraPanel` (Add timesheet + AT2)
- **Insert gate:** After ML Kit `quality.canCapture`, before `_runStreamEmbeddingPreview` / `matchCapturePhoto`
- **ML Kit:** `enableClassification: true` — eyes, euler X/Y/Z, `smilingProbability`
- **State:** `HybridLivenessGate` (exported as `TimesheetLivenessGate`); `LivenessAttemptLog` on draft (local only; backend Layer 4 skipped per request)

## F.3 — Hybrid hardening (2026-05-21)

- **Tier 1:** Multi-frame MiniFASNet (4/5), print+replay sum threshold, temporal PAD heuristics; shutter re-check.
- **Tier 2:** Mandatory AWS Rekognition Face Liveness every check-in via Firebase callables (`createFaceLivenessSession`, `getFaceLivenessSessionResults`).
- **Policy:** Block on failure — no `flagged` pass-through; capture only when `fullyPassed`.
- **Setup:** See `doc/AWS_FACE_LIVENESS_SETUP.md`.
