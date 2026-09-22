/// Site Management — Phase B face recognition (on-device).
///
/// Product: **Site Management** (UI under `lib/ui/presentation/timesheet/`).
/// Do not build a parallel timesheet-only stack; wire into existing Add Timesheet flow.
library;

/// Lambda ONNX / mobile TFLite preprocessing (see inference.py).
abstract final class FaceRecognitionPreprocess {
  static const double normMean = 127.5;
  static const double normStd = 128.0;

  /// RGB 0–255 → `(pixel - normMean) / normStd` (~[-1, 1]).
  static double normalizePixel(double rgb0to255) =>
      (rgb0to255 - normMean) / normStd;

  /// TFLite model input (verified F.0 / TC-C2).
  static const int inputHeight = 112;
  static const int inputWidth = 112;
  static const int inputChannels = 3;

  /// Lambda uses ~15% pad on max(w,h); mobile mirrors this (not 22% capture pad).
  static const double lambdaPadFraction = 0.15;

  /// P.3 — align eyes horizontal via ML Kit landmarks before 112×112 resize.
  static const bool useLandmarkAlignment = true;
}

/// P.1 — performance targets and tuning flags.
abstract final class FaceRecognitionPerformance {
  /// Decode + crop + resize on a background isolate (TFLite stays on main).
  static const bool useIsolateForPreprocess = true;

  /// Pilot target: preprocess + embed + match (logged, not enforced).
  static const int targetTotalMs = 800;
}

abstract final class FaceRecognitionModel {
  static const String assetPath = 'assets/mobilefacenet_512.tflite';
  static const int embeddingDim = 512;
}

abstract final class FaceRecognitionMatch {
  static const double defaultThreshold = 0.75;
  static const double idealThreshold = 0.80;

  /// Add-to-list after still capture — pilot bar (iOS + Android, same).
  /// Product request: 15% so genuine weak stills still detect (no "No Face").
  static const double pilotThreshold = 0.15;

  /// Soft still accept when live preview already locked the same employee.
  static const double pilotSoftCaptureThreshold = 0.15;

  /// Stream score floor before auto-shutter (same as match bar).
  static const double pilotAutoCaptureMinScore = 0.15;

  /// Name badge floor — same as match so badge ⇒ eligible to detect.
  static const double pilotDisplayThreshold = 0.15;

  /// Minimum winner gap to show employee name on live preview.
  static const double minDisplayWinnerMargin = 0.02;

  /// Best must beat 2nd-best employee by this before roster add.
  /// Aligned with display margin so a shown name can also detect.
  static const double minWinnerMargin = 0.02;

  /// Set false to revert UI + matcher to [defaultThreshold].
  static const bool usePilotThresholdForMatch = true;

  static double get activeMatchThreshold => usePilotThresholdForMatch
      ? pilotThreshold
      : defaultThreshold;

  static double get activeDisplayThreshold => usePilotThresholdForMatch
      ? pilotDisplayThreshold
      : defaultThreshold;

  /// TC-C2 / E.3 bar: same photo vs stored embedding.
  static const double verificationMinCosine = 0.95;

  /// Close second match — optional UI hint.
  static const double closeSecondDelta = 0.05;
}
