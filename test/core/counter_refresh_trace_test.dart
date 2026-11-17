import 'dart:convert';

import 'package:el_race/core/diagnostics/counter_refresh_trace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    CounterRefreshTrace.forceEnabled = true;
    CounterRefreshTrace.reset();
  });

  tearDown(() {
    CounterRefreshTrace.testSink = null;
    CounterRefreshTrace.forceEnabled = false;
  });

  test('records trigger order and I/O call counts without sensitive values',
      () async {
    final lines = <String>[];
    CounterRefreshTrace.testSink = lines.add;

    CounterRefreshTrace.trigger('waiting', 'app_resume');
    final result = await CounterRefreshTrace.io<int>(
      domain: 'waiting',
      operation: 'GET /api/my_approvals_grouped',
      trigger: 'app_resume',
      fields: const <String, Object?>{'category': 'hr'},
      call: () async => 3,
    );

    expect(result, 3);
    expect(lines, hasLength(3));
    expect(
      CounterRefreshTrace.ioCallCounts['waiting.GET /api/my_approvals_grouped'],
      1,
    );

    final payloads = lines
        .map((line) => jsonDecode(line.substring('[HD0149] '.length)))
        .cast<Map<String, dynamic>>()
        .toList();
    expect(payloads.map((entry) => entry['seq']), <int>[1, 2, 3]);
    expect(payloads.last['status'], 'success');
    expect(payloads.last['duration_ms'], isA<int>());
    expect(lines.join(), isNot(contains('Authorization')));
  });

  test('records failed I/O status and rethrows the original error', () async {
    final lines = <String>[];
    CounterRefreshTrace.testSink = lines.add;

    await expectLater(
      CounterRefreshTrace.io<void>(
        domain: 'notification_bell',
        operation: 'GET /notifications',
        trigger: 'header_poll',
        call: () => Future<void>.error(StateError('offline')),
      ),
      throwsStateError,
    );

    final payload = jsonDecode(lines.last.substring('[HD0149] '.length))
        as Map<String, dynamic>;
    expect(payload['status'], 'error');
    expect(payload['error_type'], 'StateError');
    expect(lines.join(), isNot(contains('offline')));
  });
}
