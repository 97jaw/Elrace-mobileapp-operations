import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:el_race/services/api_client.dart';
import 'package:el_race/ui/presentation/qr_code/data/qr_login_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const challenge = 'rcc_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  final now = DateTime.utc(2026, 8, 20, 12);

  String payload({
    Object? version = 2,
    String type = 'rcc_hub_login',
    String code = challenge,
    DateTime? expiresAt,
  }) {
    return jsonEncode(<String, dynamic>{
      'type': type,
      'version': version,
      'challenge': code,
      'expires_at':
          (expiresAt ?? now.add(const Duration(seconds: 60))).toIso8601String(),
    });
  }

  QrLoginService service(
    FakeQrApprovalTransport transport, {
    String? token = 'odoo-jwt',
  }) {
    return QrLoginService(
      transport: transport,
      sessionTokenProvider: () => token,
      clock: () => now,
      retryDelay: (_) async {},
    );
  }

  test('accepts v2 payload and approves only its public challenge', () async {
    final transport = FakeQrApprovalTransport(<dynamic>[
      relayResponse(<String, dynamic>{
        'status': 'success',
        'message': 'Approved',
        'token': 'must-not-reach-mobile-caller',
      }),
    ]);

    final result = await service(transport).loginWithQrCode(payload());

    expect(result['success'], isTrue);
    expect(result, isNot(contains('data')));
    expect(result.values, isNot(contains('must-not-reach-mobile-caller')));
    expect(transport.challenges, <String>[challenge]);
  });

  test(
    'production transport sends exactly the code body to Odoo relay',
    () async {
      final apiClient = RecordingApiClient();
      final transport = OdooQrApprovalTransport(apiClient: apiClient);

      await transport.approve(challenge);

      expect(apiClient.path, 'hub/qr-login');
      expect(apiClient.data, <String, dynamic>{'code': challenge});
      expect(apiClient.data, isNot(contains('odoo_id')));
    },
  );

  test('rejects unknown version without contacting Odoo', () async {
    final transport = FakeQrApprovalTransport(<dynamic>[]);

    final result =
        await service(transport).loginWithQrCode(payload(version: 1));

    expect(result['success'], isFalse);
    expect(result['code'], 'UNSUPPORTED_VERSION');
    expect(transport.challenges, isEmpty);
  });

  test('rejects legacy plain text and URL payloads', () async {
    for (final raw in <String>[
      challenge,
      'https://rcc.sawatech.ae/api/auth/login-with-code/$challenge',
      jsonEncode(<String, dynamic>{'code': challenge}),
    ]) {
      final transport = FakeQrApprovalTransport(<dynamic>[]);
      final result = await service(transport).loginWithQrCode(raw);

      expect(result['success'], isFalse);
      expect(transport.challenges, isEmpty);
    }
  });

  test('rejects payloads with unexpected sensitive fields', () async {
    final transport = FakeQrApprovalTransport(<dynamic>[]);
    final raw = jsonEncode(<String, dynamic>{
      'type': 'rcc_hub_login',
      'version': 2,
      'challenge': challenge,
      'expires_at': now.add(const Duration(seconds: 60)).toIso8601String(),
      'token': 'must-not-be-accepted',
    });

    final result = await service(transport).loginWithQrCode(raw);

    expect(result['success'], isFalse);
    expect(result['code'], 'INVALID_QR');
    expect(transport.challenges, isEmpty);
  });

  test('requires expires_at to include an explicit timezone', () async {
    final transport = FakeQrApprovalTransport(<dynamic>[]);
    final raw = jsonEncode(<String, dynamic>{
      'type': 'rcc_hub_login',
      'version': 2,
      'challenge': challenge,
      'expires_at': '2026-08-20T12:01:00',
    });

    final result = await service(transport).loginWithQrCode(raw);

    expect(result['success'], isFalse);
    expect(result['code'], 'INVALID_EXPIRY');
    expect(transport.challenges, isEmpty);
  });

  test('rejects QR expired beyond the clock-skew allowance', () async {
    final transport = FakeQrApprovalTransport(<dynamic>[]);

    final result = await service(transport).loginWithQrCode(
      payload(expiresAt: now.subtract(const Duration(seconds: 31))),
    );

    expect(result['success'], isFalse);
    expect(result['code'], 'EXPIRED');
    expect(transport.challenges, isEmpty);
  });

  test(
    'allows small device clock skew and lets Odoo be authoritative',
    () async {
      final transport = FakeQrApprovalTransport(<dynamic>[
        relayResponse(<String, dynamic>{'status': 'success'}),
      ]);

      final result = await service(transport).loginWithQrCode(
        payload(expiresAt: now.subtract(const Duration(seconds: 20))),
      );

      expect(result['success'], isTrue);
      expect(transport.challenges, <String>[challenge]);
    },
  );

  test('requires an authenticated mobile session before approval', () async {
    final transport = FakeQrApprovalTransport(<dynamic>[]);

    final result = await service(
      transport,
      token: '',
    ).loginWithQrCode(payload());

    expect(result['success'], isFalse);
    expect(result['code'], 'AUTH_REQUIRED');
    expect(transport.challenges, isEmpty);
  });

  test('does not treat JSON-RPC error inside HTTP 200 as success', () async {
    final transport = FakeQrApprovalTransport(<dynamic>[
      relayResponse(<String, dynamic>{
        'status': 'error',
        'message': 'Missing Authorization token',
        'code': 'MISSING_TOKEN',
      }),
    ]);

    final result = await service(transport).loginWithQrCode(payload());

    expect(result['success'], isFalse);
    expect(result['code'], 'MISSING_TOKEN');
  });

  test('reports expired and already-used relay responses clearly', () async {
    final expired = FakeQrApprovalTransport(<dynamic>[
      relayResponse(<String, dynamic>{
        'status': 'error',
        'code': 'CODE_EXPIRED',
      }, statusCode: 410),
    ]);
    final used = FakeQrApprovalTransport(<dynamic>[
      relayResponse(<String, dynamic>{
        'status': 'error',
        'code': 'ALREADY_USED',
      }, statusCode: 409),
    ]);

    expect(
      (await service(expired).loginWithQrCode(payload()))['code'],
      'CODE_EXPIRED',
    );
    expect(
      (await service(used).loginWithQrCode(payload()))['code'],
      'ALREADY_USED',
    );
  });

  test(
    'retries one transient failure and never duplicates a normal success',
    () async {
      final transient = DioException(
        requestOptions: RequestOptions(path: '/api/hub/qr-login'),
        type: DioExceptionType.connectionTimeout,
      );
      final transport = FakeQrApprovalTransport(<dynamic>[
        transient,
        relayResponse(<String, dynamic>{'status': 'success'}),
      ]);

      final result = await service(transport).loginWithQrCode(payload());

      expect(result['success'], isTrue);
      expect(transport.challenges, <String>[challenge, challenge]);

      final normal = FakeQrApprovalTransport(<dynamic>[
        relayResponse(<String, dynamic>{'status': 'success'}),
      ]);
      await service(normal).loginWithQrCode(payload());
      expect(normal.challenges, <String>[challenge]);
    },
  );

  test('cancelled approval is not retried', () async {
    final cancelled = DioException(
      requestOptions: RequestOptions(path: '/api/hub/qr-login'),
      type: DioExceptionType.cancel,
    );
    final transport = FakeQrApprovalTransport(<dynamic>[cancelled]);

    final result = await service(transport).loginWithQrCode(payload());

    expect(result['success'], isFalse);
    expect(result['code'], 'CANCELLED');
    expect(transport.challenges, <String>[challenge]);
  });
}

Response<dynamic> relayResponse(
  Map<String, dynamic> result, {
  int statusCode = 200,
}) {
  return Response<dynamic>(
    data: <String, dynamic>{'jsonrpc': '2.0', 'id': null, 'result': result},
    statusCode: statusCode,
    requestOptions: RequestOptions(path: '/api/hub/qr-login'),
  );
}

class FakeQrApprovalTransport implements QrApprovalTransport {
  FakeQrApprovalTransport(this.outcomes);

  final List<dynamic> outcomes;
  final List<String> challenges = <String>[];

  @override
  Future<Response<dynamic>> approve(
    String challenge, {
    CancelToken? cancelToken,
  }) async {
    challenges.add(challenge);
    final outcome = outcomes.removeAt(0);
    if (outcome is DioException) throw outcome;
    return outcome as Response<dynamic>;
  }
}

class RecordingApiClient extends ApiClient {
  RecordingApiClient() : super(baseUrl: 'https://erp.elrace.com/api/');

  String? path;
  dynamic data;

  @override
  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) async {
    this.path = path;
    this.data = data;
    return Response<dynamic>(
      data: <String, dynamic>{},
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}
