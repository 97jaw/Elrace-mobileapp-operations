import 'package:el_race/core/site_management/face_recognition/data/models/face_embedding_record.dart';

/// Result of the post-capture enrollment checks (same person + duplicate).
class FaceEnrollmentCheckReport {
  const FaceEnrollmentCheckReport({
    required this.samePersonScores,
    this.duplicateOf,
    this.duplicateScore = 0,
  });

  /// Photo key → cosine vs the reference (first) photo. Reference is omitted.
  final Map<String, double> samePersonScores;

  /// Strongest other enrolled employee across all photos, if any.
  final FaceEmbeddingRecord? duplicateOf;

  /// Mean (across photos) of the best per-photo score for [duplicateOf].
  final double duplicateScore;

  List<String> keysBelow(double minCosine) => [
        for (final e in samePersonScores.entries)
          if (e.value < minCosine) e.key,
      ];
}
