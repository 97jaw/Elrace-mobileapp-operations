import 'package:el_race/ui/presentation/Email%20Approval/Approval.dart';
import 'package:el_race/ui/presentation/Email%20Approval/data/it_hardware_request_repository.dart';
import 'package:el_race/ui/presentation/Email%20Approval/models/it_hardware_request.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/it_hardware_request_details_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/it_hardware_request_fixture.dart';

void main() {
  group('ItHardwareRequest', () {
    test('keeps request identity and hardware lines typed', () {
      final request = neutralItHardwareRequestFixture;

      expect(request.id, 'request-101');
      expect(request.requestNumber, 'REQ/TEST/101');
      expect(request.lines, hasLength(1));
      expect(request.lines.single.item, 'Laptop');
      expect(request.lines.single.quantity, 1);
      expect(request.lines.single.specifications, isNotEmpty);
      expect(request.lines.single.reason, isNotEmpty);
    });

    test('pending repository fails explicitly instead of returning demo data',
        () async {
      const repository = PendingItHardwareRequestRepository();

      expect(await repository.fetchWaiting(), isEmpty);
      await expectLater(
        repository.fetchById('request-101'),
        throwsA(isA<ItHardwareRequestApiUnavailable>()),
      );
    });
  });

  group('ItHardwareRequestFlow', () {
    test('loads details by requestId', () async {
      final repository = _FakeItHardwareRequestRepository();
      final flow = ItHardwareRequestFlow(repository);

      final request = await flow.load('request-101');

      expect(repository.fetchedRequestId, 'request-101');
      expect(request.lines.single.item, 'Laptop');
    });

    test('requires and forwards a reject comment', () async {
      final repository = _FakeItHardwareRequestRepository();
      final flow = ItHardwareRequestFlow(repository);

      expect(
        () => flow.reject('request-101', comment: '  '),
        throwsArgumentError,
      );

      await flow.reject(
        'request-101',
        comment: '  Missing required specifications  ',
      );

      expect(repository.rejectedRequestId, 'request-101');
      expect(repository.rejectComment, 'Missing required specifications');
    });
  });

  test('details screen is configured with requestId and repository', () {
    const screen = ItHardwareRequestDetailsScreen(
      requestId: 'request-101',
      repository: PendingItHardwareRequestRepository(),
    );

    expect(screen.requestId, 'request-101');
    expect(screen.repository, isA<PendingItHardwareRequestRepository>());
  });

  test('waiting approvals screen remains constructible', () {
    expect(const ApprovalsScreen(), isA<ApprovalsScreen>());
  });
}

class _FakeItHardwareRequestRepository implements ItHardwareRequestRepository {
  String? fetchedRequestId;
  String? rejectedRequestId;
  String? rejectComment;

  @override
  Future<List<Map<String, dynamic>>> fetchWaiting() async => const [];

  @override
  Future<ItHardwareRequest> fetchById(String requestId) async {
    fetchedRequestId = requestId;
    return neutralItHardwareRequestFixture;
  }

  @override
  Future<bool> approve(String requestId) async => false;

  @override
  Future<bool> reject(String requestId, {required String comment}) async {
    rejectedRequestId = requestId;
    rejectComment = comment;
    return false;
  }
}
