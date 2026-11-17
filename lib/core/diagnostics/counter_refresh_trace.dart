import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Debug-only structured trace for HD-0149 counter refresh investigation.
///
/// Every line is valid JSON after the `[HD0149]` prefix, which makes device
/// logs easy to filter and aggregate without changing refresh behavior.
class CounterRefreshTrace {
  CounterRefreshTrace._();

  static final Stopwatch _clock = Stopwatch()..start();
  static final Map<String, int> _ioCallCounts = <String, int>{};
  static int _sequence = 0;

  @visibleForTesting
  static bool forceEnabled = false;

  @visibleForTesting
  static ValueChanged<String>? testSink;

  static bool get _enabled => kDebugMode || forceEnabled;

  static Map<String, int> get ioCallCounts =>
      Map<String, int>.unmodifiable(_ioCallCounts);

  static void trigger(
    String domain,
    String trigger, {
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    _emit('trigger', domain, trigger, fields);
  }

  static void state(
    String domain,
    String status, {
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    _emit('state', domain, status, fields);
  }

  static Future<T> io<T>({
    required String domain,
    required String operation,
    required String trigger,
    required Future<T> Function() call,
    Map<String, Object?> fields = const <String, Object?>{},
  }) async {
    if (!_enabled) return call();

    final key = '$domain.$operation';
    final callNumber = (_ioCallCounts[key] ?? 0) + 1;
    _ioCallCounts[key] = callNumber;
    final stopwatch = Stopwatch()..start();
    _emit('io_start', domain, operation, <String, Object?>{
      'trigger': trigger,
      'call': callNumber,
      ...fields,
    });

    try {
      final result = await call();
      stopwatch.stop();
      _emit('io_end', domain, operation, <String, Object?>{
        'trigger': trigger,
        'call': callNumber,
        'status': 'success',
        'duration_ms': stopwatch.elapsedMilliseconds,
        ...fields,
      });
      return result;
    } catch (error) {
      stopwatch.stop();
      _emit('io_end', domain, operation, <String, Object?>{
        'trigger': trigger,
        'call': callNumber,
        'status': 'error',
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
        ...fields,
      });
      rethrow;
    }
  }

  @visibleForTesting
  static void reset() {
    _sequence = 0;
    _ioCallCounts.clear();
  }

  static void _emit(
    String kind,
    String domain,
    String name,
    Map<String, Object?> fields,
  ) {
    if (!_enabled) return;
    final payload = jsonEncode(<String, Object?>{
      'seq': ++_sequence,
      'elapsed_ms': _clock.elapsedMilliseconds,
      'kind': kind,
      'domain': domain,
      'name': name,
      ...fields,
    });
    final line = '[HD0149] $payload';
    final sink = testSink;
    if (sink != null) {
      sink(line);
    } else {
      debugPrint(line);
    }
  }
}
