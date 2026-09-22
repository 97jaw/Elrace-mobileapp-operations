import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Creates TFLite interpreters once with a safe Android XNNPACK policy.
///
/// Native SIGSEGV in `TfLiteXNNPackDelegateCreateWithThreadpool` (seen on
/// MediaTek / Samsung XCover7) cannot be caught in Dart. Strategy:
/// 1. Default / fallback = plain CPU interpreter (always works).
/// 2. Crash-loop guard: persist `attempted` before each XNNPACK create; clear
///    only after that create succeeds. If still set on next launch, permanently
///    skip XNNPACK for this install.
/// 3. Chipset denylist (MediaTek / XCover) as belt-and-suspenders.
/// 4. Explicit `numThreads` (never rely on auto threadpool sizing).
abstract final class TfliteInterpreterFactory {
  static const _prefAttempted = 'tflite_xnnpack_init_attempted';
  static const _prefDisabled = 'tflite_xnnpack_disabled';

  static bool? _useXnnpack;
  static String _backendLabel = 'cpu';

  /// Serialize creates so parallel FaceEmbedder / MiniFASNet loads cannot
  /// clear the crash-loop flag while another create is in-flight.
  static Future<void> _createChain = Future<void>.value();

  static String get backendLabel => _backendLabel;

  /// Build interpreter from asset. Prefer calling once per model (Task 0).
  ///
  /// [fixedInputShape] pins dims once after create so XNNPACK is never
  /// re-applied via resize+allocate mid-session.
  static Future<Interpreter> fromAsset(
    String assetPath, {
    List<int>? fixedInputShape,
    /// When false, never attach XNNPACK (MiniFASNet / PAD). LiteRT+XNNPACK on
    /// these graphs was re-logging `Replacing 65…` and costing mid-session.
    bool preferXnnpack = true,
  }) {
    final done = Completer<Interpreter>();
    _createChain = _createChain.then((_) async {
      try {
        done.complete(
          await _fromAssetImpl(
            assetPath,
            fixedInputShape: fixedInputShape,
            preferXnnpack: preferXnnpack,
          ),
        );
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  static Future<Interpreter> _fromAssetImpl(
    String assetPath, {
    List<int>? fixedInputShape,
    bool preferXnnpack = true,
  }) async {
    final threads = _cpuThreads();
    final tryXnn = preferXnnpack && await _shouldTryXnnpack();

    late final Interpreter interpreter;
    if (!tryXnn) {
      _backendLabel = preferXnnpack ? 'cpu' : 'cpu_forced';
      debugPrint(
        'TfliteInterpreterFactory: CPU interpreter '
        '(xnn=${preferXnnpack ? "skipped_policy" : "disabled_for_model"}) '
        'asset=$assetPath threads=$threads',
      );
      interpreter = await Interpreter.fromAsset(
        assetPath,
        options: InterpreterOptions()..threads = threads,
      );
    } else {
      // Persist BEFORE native create — SIGSEGV cannot be caught.
      await _setAttempted(true);

      try {
        final options = InterpreterOptions()..threads = threads;
        options.addDelegate(
          XNNPackDelegate(
            options: XNNPackDelegateOptions(numThreads: threads),
          ),
        );
        interpreter = await Interpreter.fromAsset(
          assetPath,
          options: options,
        );
        await _setAttempted(false);
        _backendLabel = 'xnnpack';
        debugPrint(
          'TfliteInterpreterFactory: XNNPACK interpreter ok '
          'asset=$assetPath threads=$threads',
        );
      } catch (e, st) {
        debugPrint(
          'TfliteInterpreterFactory: XNNPACK failed, CPU fallback: $e\n$st',
        );
        await _disableXnnpackPermanently(reason: 'dart_exception');
        _backendLabel = 'cpu_fallback';
        interpreter = await Interpreter.fromAsset(
          assetPath,
          options: InterpreterOptions()..threads = threads,
        );
      }
    }

    if (fixedInputShape != null) {
      _pinInputShape(interpreter, fixedInputShape);
    }
    return interpreter;
  }

  /// Pin once. Subsequent frames must never resize (that re-applies XNNPACK).
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

  static Future<bool> _shouldTryXnnpack() async {
    if (_useXnnpack != null) return _useXnnpack!;
    if (!Platform.isAndroid) {
      _useXnnpack = false;
      return false;
    }

    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool(_prefDisabled) == true) {
      debugPrint('TfliteInterpreterFactory: XNNPACK permanently disabled');
      _useXnnpack = false;
      return false;
    }

    // Previous launch crashed mid-create.
    if (prefs.getBool(_prefAttempted) == true) {
      await _disableXnnpackPermanently(reason: 'crash_loop_guard');
      _useXnnpack = false;
      return false;
    }

    if (await _isKnownBadChipset()) {
      debugPrint(
        'TfliteInterpreterFactory: XNNPACK skipped (chipset denylist)',
      );
      _useXnnpack = false;
      return false;
    }

    _useXnnpack = true;
    return true;
  }

  static Future<void> _setAttempted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAttempted, value);
  }

  static Future<void> _disableXnnpackPermanently({
    required String reason,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDisabled, true);
    await prefs.setBool(_prefAttempted, false);
    _useXnnpack = false;
    debugPrint('TfliteInterpreterFactory: XNNPACK disabled ($reason)');
  }

  static Future<bool> _isKnownBadChipset() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final blob = [
        info.board,
        info.hardware,
        info.device,
        info.model,
        info.product,
        info.brand,
        info.manufacturer,
      ].join(' ').toLowerCase();
      const bad = [
        'mt6',
        'mt8',
        'mediatek',
        'helio',
        'dimensity',
        'xcover',
      ];
      return bad.any(blob.contains);
    } catch (_) {
      return false;
    }
  }
}
