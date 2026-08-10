import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Calls Cloud Function `processNoteAi` (us-central1, same as Whisper).
class NotesAiService {
  NotesAiService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> processNoteAi({
    required String noteId,
    required String mode,
    String? targetLanguage,
  }) async {
    try {
      final callable = _functions.httpsCallable('processNoteAi');
      final result = await callable.call(<String, dynamic>{
        'noteId': noteId,
        'mode': mode,
        if (targetLanguage != null) 'targetLanguage': targetLanguage,
      });
      final data = result.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {};
    } catch (e) {
      debugPrint('❌ NotesAiService.processNoteAi failed: $e');
      rethrow;
    }
  }
}
