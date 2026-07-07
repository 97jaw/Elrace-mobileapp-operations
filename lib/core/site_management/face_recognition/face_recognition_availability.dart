import 'package:el_race/core/site_management/face_recognition/data/repositories/face_db_repository.dart';

/// P.2 — why embedding match is or is not available.
enum FaceRecognitionAvailability {
  ready,
  offlineCache,
  syncFailed,
  noEmbeddings,
  engineFailed,
  notInitialized,
}

extension FaceSyncResultAvailability on FaceSyncResult {
  FaceRecognitionAvailability toAvailability({required bool engineReady}) {
    if (engineReady) {
      if (status == FaceSyncStatus.failed &&
          message != null &&
          message!.startsWith('offline_cache')) {
        return FaceRecognitionAvailability.offlineCache;
      }
      return FaceRecognitionAvailability.ready;
    }
    if (status == FaceSyncStatus.empty) {
      return FaceRecognitionAvailability.noEmbeddings;
    }
    if (status == FaceSyncStatus.failed &&
        message != null &&
        message!.startsWith('offline_cache')) {
      return FaceRecognitionAvailability.offlineCache;
    }
    if (status == FaceSyncStatus.failed) {
      return FaceRecognitionAvailability.syncFailed;
    }
    return FaceRecognitionAvailability.notInitialized;
  }
}

extension FaceRecognitionAvailabilityMessage on FaceRecognitionAvailability {
  String get userMessage {
    switch (this) {
      case FaceRecognitionAvailability.ready:
        return 'Embedding match ready';
      case FaceRecognitionAvailability.offlineCache:
        return 'Offline — using cached face data';
      case FaceRecognitionAvailability.syncFailed:
        return 'Face data sync failed — pick employee manually';
      case FaceRecognitionAvailability.noEmbeddings:
        return 'No enrolled faces on server — manual pick only';
      case FaceRecognitionAvailability.engineFailed:
        return 'Face engine unavailable — manual pick only';
      case FaceRecognitionAvailability.notInitialized:
        return 'Face data loading…';
    }
  }
}
