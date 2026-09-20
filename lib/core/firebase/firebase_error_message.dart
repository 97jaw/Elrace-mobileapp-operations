import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

/// Turns a Firebase error into one short sentence for a SnackBar or dialog.
///
/// Firebase errors carry a full async stack trace in `toString()`. Showing that
/// raw is what produced screens of `<asynchronous suspension>` text in the UI,
/// so log the original with `debugPrint` and show this instead.
String firebaseErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Service is unreachable right now. Check your connection and try again.';
      case 'unauthenticated':
        return 'Your session expired. Please sign in again.';
      case 'permission-denied':
        return 'You do not have access to this.';
      case 'failed-precondition':
        return error.message ?? 'This is not ready yet. Try again shortly.';
      case 'not-found':
        return 'That item no longer exists.';
      case 'resource-exhausted':
        return 'Too many requests. Please wait a moment and try again.';
      case 'invalid-argument':
        return error.message ?? 'That request was not valid.';
    }
    return error.message ?? fallback;
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'unavailable':
        return 'Service is unreachable right now. Check your connection and try again.';
      case 'unauthenticated':
      case 'user-token-expired':
      case 'custom-token-expired':
      case 'invalid-custom-token':
        return 'Your session expired. Please sign in again.';
      case 'permission-denied':
      case 'unauthorized':
        return 'You do not have access to this.';
      case 'not-found':
      case 'object-not-found':
        return 'That file is no longer available.';
      case 'canceled':
        return 'Cancelled.';
      case 'retry-limit-exceeded':
        return 'Upload timed out. Check your connection and try again.';
      case 'quota-exceeded':
        return 'Storage limit reached. Contact your administrator.';
    }
    return error.message ?? fallback;
  }

  return fallback;
}
