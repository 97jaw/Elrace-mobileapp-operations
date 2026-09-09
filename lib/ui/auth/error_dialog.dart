import 'package:el_race/services/uaepass_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

/// UAE PASS error popup — matches approved mockup (warning icon, red X close).
class ErrorDialog {
  static String messageFor(AuthFailureType? type) {
    switch (type) {
      case AuthFailureType.existingOnly:
        return translate('uaepass.errors.existing_users_only');
      case AuthFailureType.unverified:
        return translate('uaepass.errors.unverified');
      case AuthFailureType.cancelled:
        return translate('uaepass.errors.cancelled');
      case AuthFailureType.noSession:
        return translate('uaepass.errors.session_not_received');
      case AuthFailureType.generic:
      case null:
        return translate('uaepass.errors.generic');
    }
  }

  static Future<void> showForFailure(
    BuildContext context,
    AuthFailureType? failureType,
  ) {
    return show(
      context,
      message: messageFor(failureType),
    );
  }

  static Future<void> show(BuildContext context, {required String message}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 44, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade700,
                      size: 56,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(dialogContext).pop(),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
