import 'package:el_race/core/site_management/face_recognition/data/models/face_embedding_record.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';

class FaceMatchResult {
  const FaceMatchResult({
    required this.isMatch,
    required this.bestScore,
    required this.secondBestScore,
    this.best,
  });

  final bool isMatch;
  final double bestScore;
  final double secondBestScore;
  final FaceEmbeddingRecord? best;

  static const none = FaceMatchResult(
    isMatch: false,
    bestScore: 0,
    secondBestScore: 0,
  );

  /// §4.5 — second candidate within [FaceRecognitionMatch.closeSecondDelta].
  bool get hasCloseSecondCandidate {
    if (bestScore <= 0 || secondBestScore <= 0) return false;
    final gap = bestScore - secondBestScore;
    return gap >= 0 && gap < FaceRecognitionMatch.closeSecondDelta;
  }
}
