import 'package:el_race/core/site_management/face_recognition/data/models/face_embedding_record.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';

class FaceMatchResult {
  const FaceMatchResult({
    required this.isMatch,
    required this.bestScore,
    required this.secondBestScore,
    this.best,
  });

  /// Confident match: score ≥ active threshold and clear margin vs 2nd employee.
  final bool isMatch;
  final double bestScore;
  final double secondBestScore;
  final FaceEmbeddingRecord? best;

  static const none = FaceMatchResult(
    isMatch: false,
    bestScore: 0,
    secondBestScore: 0,
  );

  /// Show name badge (green/yellow) — softer than auto-accept.
  bool get passesDisplayThreshold {
    if (best == null || bestScore <= 0) return false;
    if (bestScore < FaceRecognitionMatch.activeDisplayThreshold) return false;
    if (secondBestScore <= 0) return true;
    return winnerMargin >= FaceRecognitionMatch.minDisplayWinnerMargin;
  }

  /// Gap between best and 2nd-best **employee**.
  double get winnerMargin {
    if (bestScore <= 0) return 0;
    if (secondBestScore <= 0) return bestScore;
    return bestScore - secondBestScore;
  }

  bool get hasClearWinnerMargin =>
      secondBestScore <= 0 ||
      winnerMargin >= FaceRecognitionMatch.minWinnerMargin;

  /// §4.5 — second candidate within [FaceRecognitionMatch.closeSecondDelta].
  bool get hasCloseSecondCandidate {
    if (bestScore <= 0 || secondBestScore <= 0) return false;
    final gap = bestScore - secondBestScore;
    return gap >= 0 && gap < FaceRecognitionMatch.closeSecondDelta;
  }
}
