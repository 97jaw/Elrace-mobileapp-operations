import 'dart:math' as math;

import 'package:el_race/core/site_management/face_recognition/data/models/face_embedding_record.dart';
import 'package:flutter/foundation.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_match_result.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';

class FaceMatcher {
  FaceMatcher({double? threshold})
      : threshold = threshold ?? FaceRecognitionMatch.activeMatchThreshold;

  final double threshold;

  FaceMatchResult findBestMatch(
    List<double> captured,
    List<FaceEmbeddingRecord> roster,
  ) {
    if (roster.isEmpty) {
      return FaceMatchResult.none;
    }
    final probe = _l2Normalize(captured);
    var bestScore = -1.0;
    var secondBest = -1.0;
    FaceEmbeddingRecord? best;

    // Max cosine per employee across enrollment templates (user.face.image).
    final perEmployee = <int, double>{};
    for (final row in roster) {
      if (row.embedding.length != FaceRecognitionModel.embeddingDim) continue;
      final score = _dot(probe, _l2Normalize(row.embedding));
      final prev = perEmployee[row.employeeId];
      if (prev == null || score > prev) {
        perEmployee[row.employeeId] = score;
      }
    }
    if (perEmployee.isEmpty) {
      final dim = roster.isNotEmpty ? roster.first.embedding.length : 0;
      debugPrint(
        'FaceRecognition: no scorable cache rows (expected '
        '${FaceRecognitionModel.embeddingDim} dims, first=$dim)',
      );
    }
    for (final row in roster) {
      final score = perEmployee[row.employeeId];
      if (score == null) continue;
      if (score > bestScore) {
        secondBest = bestScore;
        bestScore = score;
        best = row;
      } else if (score > secondBest) {
        secondBest = score;
      }
    }

    return FaceMatchResult(
      isMatch: bestScore >= threshold,
      bestScore: bestScore < 0 ? 0 : bestScore,
      secondBestScore: secondBest < 0 ? 0 : secondBest,
      best: best,
    );
  }

  List<double> _l2Normalize(List<double> vec) {
    var sum = 0.0;
    for (final v in vec) {
      sum += v * v;
    }
    final n = math.sqrt(sum);
    if (n < 1e-9) return vec;
    return vec.map((v) => v / n).toList();
  }

  double _dot(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    var s = 0.0;
    for (var i = 0; i < n; i++) {
      s += a[i] * b[i];
    }
    return s;
  }

  /// E.3 — per-template scores for one employee (debug / verification).
  List<({String? pose, int? faceImageId, double score})> scoreTemplatesForEmployee(
    List<double> captured,
    List<FaceEmbeddingRecord> roster,
    int employeeId,
  ) {
    final probe = _l2Normalize(captured);
    final out = <({String? pose, int? faceImageId, double score})>[];
    for (final row in roster) {
      if (row.employeeId != employeeId) continue;
      if (row.embedding.length != FaceRecognitionModel.embeddingDim) continue;
      out.add((
        pose: row.pose,
        faceImageId: row.faceImageId,
        score: _dot(probe, _l2Normalize(row.embedding)),
      ));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }
}
