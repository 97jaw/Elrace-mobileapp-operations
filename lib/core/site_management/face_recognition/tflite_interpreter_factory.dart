import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Creates TFLite interpreters once with a safe Android policy.
///
/// **Android:** never attach an explicit [XNNPackDelegate]. Creating one with
/// [XNNPackDelegateOptions] against LiteRT 1.4.0 mis-reads the options struct
/// (`weights_cache` / path seen as `'PK'` zip bytes → `__next_prime overflow`).
/// Use plain CPU [InterpreterOptions] + `numThreads` only. Crash-loop / per-model
/// XNN prefs are cleared on startup; guard helpers remain for a future upgrade
/// but do not enable XNNPACK on Android today.
///
/// **iOS:** plain CPU path as well (no explicit XNNPACK).
abstract final class TfliteInterpreterFactory {
  static const _prefAttemptPrefix = 'tflite_xnn_attempt:';
  static const _prefDisabledPrefix = 'tflite_xnn_disabled:';
  static const _prefAttemptedLegacy = 'tflite_xnnpack_init_attempted';
  static const _prefDisabledLegacy = 'tflite_xnnpack_disabled';

  static final Map<String, String> _backendByAsset = {};

  /// Retain options for process lifetime (same isolate as the interpreter).
  static final Map<String, InterpreterOptions> _retainedOptions = {};

  static Future<void> _createChain = Future<void>.value();
  static bool _clearedStaleXnnFlags = false;

  static String get backendLabel =>
      _backendByAsset.values.isEmpty ? 'cpu' : _backendByAsset.values.last;

  static String backendFor(String assetPath) =>
      _backendByAsset[assetPath] ?? 'unknown';

  /// Build interpreter from asset. Prefer calling once per model.
  ///
  /// [preferXnnpack] is accepted for call-site compat but **ignored** — Android
  /// never creates an explicit XNNPACK delegate in this build.
  static Future<Interpreter> fromAsset(
    String assetPath, {
    List<int>? fixedInputShape,
    bool preferXnnpack = false,
    int? numThreads,
  }) {
    // preferXnnpack intentionally unused (unsafe with current LiteRT binding).
    assert(() {
      if (preferXnnpack && Platform.isAndroid) {
        debugPrint(
          'TfliteInterpreterFactory: preferXnnpack=true ignored on Android '
          '(explicit XNNPackDelegate unsafe with LiteRT 1.4.0)',
        );
      }
      return true;
    }());

    final done = Completer<Interpreter>();
    _createChain = _createChain.then((_) async {
      try {
        done.complete(
          await _fromAssetImpl(
            assetPath,
            fixedInputShape: fixedInputShape,
            numThreads: numThreads,
          ),
        );
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  /// No-op while Android never enables XNNPACK. Kept so call sites stay valid.
  static Future<void> notifyFirstInvokeOk(String assetPath) async {}

  static Future<Interpreter> _fromAssetImpl(
    String assetPath, {
    List<int>? fixedInputShape,
    int? numThreads,
  }) async {
    await _clearStaleXnnFlagsOnce();

    final threads = numThreads ?? _cpuThreads();
    _backendByAsset[assetPath] = 'cpu';
    debugPrint(
      'TfliteInterpreterFactory: CPU interpreter '
      '(xnn=never_explicit_delegate) '
      'asset=$assetPath threads=$threads',
    );
    final options = InterpreterOptions()..threads = threads;
    _retainedOptions[assetPath] = options;
    final interpreter =
        await Interpreter.fromAsset(assetPath, options: options);

    if (fixedInputShape != null) {
      _pinInputShape(interpreter, fixedInputShape);
    }
    return interpreter;
  }

  /// Clear persisted XNN attempt/disable keys so a prior crash does not leave
  /// stale state. Guard helpers below are unused until a safe upgrade.
  static Future<void> _clearStaleXnnFlagsOnce() async {
    if (_clearedStaleXnnFlags) return;
    _clearedStaleXnnFlags = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().toList(growable: false);
      var n = 0;
      for (final k in keys) {
        if (k == _prefAttemptedLegacy ||
            k == _prefDisabledLegacy ||
            k.startsWith(_prefAttemptPrefix) ||
            k.startsWith(_prefDisabledPrefix)) {
          await prefs.remove(k);
          n++;
        }
      }
      if (n > 0) {
        debugPrint(
          'TfliteInterpreterFactory: cleared $n stale xnn_attempt/disable flags',
        );
      }
    } catch (e) {
      debugPrint('TfliteInterpreterFactory: clear xnn flags failed: $e');
    }
  }

  static void _pinInputShape(Interpreter interpreter, List<int> shape) {
    final current = interpreter.getInputTensor(0).shape;
    final same = current.length == shape.length &&
        List.generate(shape.length, (i) => current[i] == shape[i])
            .every((ok) => ok);
    if (same) {
      debugPrint(
        'TfliteInterpreterFactory: input already pinned $shape',
      );
      return;
    }
    interpreter.resizeInputTensor(0, shape);
    interpreter.allocateTensors();
    debugPrint(
      'TfliteInterpreterFactory: pinned input $current → $shape '
      '(allocate once)',
    );
  }

  static int _cpuThreads() {
    final cores = Platform.numberOfProcessors;
    return math.min(2, math.max(1, cores - 1));
  }

  // ---------------------------------------------------------------------------
  // Crash-loop guard (unused — Android never enables XNNPACK). Kept for a
  // future binding upgrade that matches LiteRT's TfLiteXNNPackDelegateOptions.
  // ---------------------------------------------------------------------------

  // ignore: unused_element
  static String _attemptKey(String assetPath) =>
      '$_prefAttemptPrefix$assetPath';

  // ignore: unused_element
  static String _disabledKey(String assetPath) =>
      '$_prefDisabledPrefix$assetPath';

  /// Would gate XNNPACK create; always false today.
  // ignore: unused_element
  static Future<bool> _shouldTryXnnpack(String assetPath) async => false;
}
