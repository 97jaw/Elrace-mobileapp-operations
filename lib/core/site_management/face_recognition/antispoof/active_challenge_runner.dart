import 'dart:math' as math;

import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_face_classification_snapshot.dart';
import 'package:flutter/foundation.dart';

enum ActiveChallengeAction {
  blinkTwice,
  turnHeadLeft,
  turnHeadRight,
  lookUp,
  smile,
}

extension ActiveChallengeActionX on ActiveChallengeAction {
  String get instruction {
    switch (this) {
      case ActiveChallengeAction.blinkTwice:
        return 'Please blink twice';
      case ActiveChallengeAction.turnHeadLeft:
        return 'Turn your head to the left';
      case ActiveChallengeAction.turnHeadRight:
        return 'Turn your head to the right';
      case ActiveChallengeAction.lookUp:
        return 'Look up slightly';
      case ActiveChallengeAction.smile:
        return 'Please smile';
    }
  }
}

enum ChallengeRunResult {
  passed,
  failed,
  timeout,
}

class ActiveChallengeRunner {
  ActiveChallengeRunner({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  ActiveChallengeAction? _current;
  DateTime? _deadline;
  int _blinkCount = 0;
  bool _eyesWereOpen = true;

  ActiveChallengeAction startNewChallenge() {
    const pool = ActiveChallengeAction.values;
    _current = pool[_random.nextInt(pool.length)];
    _deadline = DateTime.now().add(AntispoofConfig.challengeWindow);
    _blinkCount = 0;
    _eyesWereOpen = true;
    debugPrint('AntiSpoof L2: challenge=${_current!.name}');
    return _current!;
  }

  ActiveChallengeAction? get current => _current;

  Duration? get remainingTime {
    final deadline = _deadline;
    if (deadline == null) return null;
    final left = deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Feed consecutive stream snapshots; returns outcome when decided.
  ChallengeRunResult? feed(TimesheetFaceClassificationSnapshot face) {
    final action = _current;
    final deadline = _deadline;
    if (action == null || deadline == null) return null;

    if (DateTime.now().isAfter(deadline)) {
      debugPrint('AntiSpoof L2: timeout action=${action.name}');
      return ChallengeRunResult.timeout;
    }

    if (_isSatisfied(action, face)) {
      debugPrint('AntiSpoof L2: passed action=${action.name}');
      return ChallengeRunResult.passed;
    }
    return null;
  }

  void reset() {
    _current = null;
    _deadline = null;
    _blinkCount = 0;
  }

  bool _isSatisfied(
    ActiveChallengeAction action,
    TimesheetFaceClassificationSnapshot face,
  ) {
    switch (action) {
      case ActiveChallengeAction.blinkTwice:
        return _detectBlinkTwice(face);
      case ActiveChallengeAction.turnHeadLeft:
        return (face.headEulerAngleY ?? 0) < -14;
      case ActiveChallengeAction.turnHeadRight:
        return (face.headEulerAngleY ?? 0) > 14;
      case ActiveChallengeAction.lookUp:
        return (face.headEulerAngleX ?? 0) < -12;
      case ActiveChallengeAction.smile:
        return (face.smilingProbability ?? 0) > 0.65;
    }
  }

  bool _detectBlinkTwice(TimesheetFaceClassificationSnapshot face) {
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    if (left == null || right == null) return false;
    final avg = (left + right) / 2;
    const closedThreshold = 0.28;
    const openThreshold = 0.45;

    if (_eyesWereOpen && avg < closedThreshold) {
      _eyesWereOpen = false;
    } else if (!_eyesWereOpen && avg > openThreshold) {
      _eyesWereOpen = true;
      _blinkCount++;
    }
    return _blinkCount >= 2;
  }
}
