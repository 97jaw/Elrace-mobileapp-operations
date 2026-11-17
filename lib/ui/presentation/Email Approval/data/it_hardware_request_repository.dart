import 'package:el_race/ui/presentation/Email%20Approval/models/it_hardware_request.dart';

abstract interface class ItHardwareRequestRepository {
  Future<List<Map<String, dynamic>>> fetchWaiting();

  Future<ItHardwareRequest> fetchById(String requestId);

  Future<bool> approve(String requestId);

  Future<bool> reject(String requestId, {required String comment});
}

final class ItHardwareRequestFlow {
  const ItHardwareRequestFlow(this._repository);

  final ItHardwareRequestRepository _repository;

  Future<ItHardwareRequest> load(String requestId) {
    return _repository.fetchById(requestId);
  }

  Future<bool> approve(String requestId) {
    return _repository.approve(requestId);
  }

  Future<bool> reject(String requestId, {required String comment}) {
    final normalized = comment.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
          comment, 'comment', 'Reject comment is required');
    }
    return _repository.reject(requestId, comment: normalized);
  }
}

class ItHardwareRequestApiUnavailable implements Exception {
  const ItHardwareRequestApiUnavailable();

  @override
  String toString() => 'IT Request API is not available yet.';
}

final class PendingItHardwareRequestRepository
    implements ItHardwareRequestRepository {
  const PendingItHardwareRequestRepository();

  @override
  Future<List<Map<String, dynamic>>> fetchWaiting() async => const [];

  @override
  Future<ItHardwareRequest> fetchById(String requestId) {
    return Future<ItHardwareRequest>.error(
      const ItHardwareRequestApiUnavailable(),
    );
  }

  @override
  Future<bool> approve(String requestId) {
    return Future<bool>.error(const ItHardwareRequestApiUnavailable());
  }

  @override
  Future<bool> reject(String requestId, {required String comment}) {
    return Future<bool>.error(const ItHardwareRequestApiUnavailable());
  }
}
