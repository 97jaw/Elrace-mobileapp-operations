import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared “rejected / restart validation” UI for waiting form views.
class ApprovalRejectedBanner extends StatelessWidget {
  const ApprovalRejectedBanner({
    super.key,
    this.message =
        'This request was rejected. Restart validation before approving again.',
  });

  final String message;

  static const String defaultMessage =
      'This request was rejected. Restart validation before approving again.';

  /// True when form payload indicates a rejected tier/request.
  static bool isRejected(Map<String, dynamic> formData) {
    final rejectedRaw = formData['rejected'];
    if (rejectedRaw == true || rejectedRaw == 1 || rejectedRaw == '1') {
      return true;
    }
    if (rejectedRaw is String &&
        rejectedRaw.trim().toLowerCase() == 'true') {
      return true;
    }

    final status = '${formData['status'] ?? formData['state'] ?? ''}'
        .trim()
        .toLowerCase();
    if (status == 'rejected' ||
        status == 'refuse' ||
        status == 'refused' ||
        status == 'reject') {
      return true;
    }

    final canApprove = formData['can_approve'];
    if (canApprove == false || canApprove == 0 || canApprove == '0') {
      final reason = '${formData['status_message'] ?? ''}'.toLowerCase();
      if (reason.contains('reject') || reason.contains('restart validation')) {
        return true;
      }
    }
    return false;
  }

  static String messageFromForm(Map<String, dynamic> formData) {
    final custom = '${formData['status_message'] ?? ''}'.trim();
    if (custom.isNotEmpty &&
        custom.toLowerCase() != 'false' &&
        custom.toLowerCase() != 'null') {
      return custom;
    }
    return defaultMessage;
  }

  static bool messageLooksRejected(String message) {
    final m = message.toLowerCase();
    return m.contains('restart validation') ||
        m.contains('was rejected') ||
        m.contains('already rejected');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 8.th),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFC62828), Color(0xFFE53935)],
            ),
            borderRadius: BorderRadius.circular(10.tr),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC62828).withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.block_rounded, color: Colors.white, size: 18.tsp),
              SizedBox(width: 8.tw),
              Expanded(
                child: Text(
                  'REJECTED',
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.th),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12.tr),
            border: Border.all(color: const Color(0xFFFFB74D)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: const Color(0xFFEF6C00),
                size: 20.tsp,
              ),
              SizedBox(width: 8.tw),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 12.tsp,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: const Color(0xFF5D4037),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Centered result popup for approve/reject outcomes (success or info/error).
Future<void> showApprovalMessagePopup(
  BuildContext context, {
  required String message,
  bool isSuccess = false,
  bool isWarning = false,
}) {
  final title = isSuccess
      ? 'Success'
      : (isWarning || ApprovalRejectedBanner.messageLooksRejected(message)
          ? 'Notice'
          : 'Unable to proceed');
  final icon = isSuccess
      ? Icons.check_circle_rounded
      : (isWarning || ApprovalRejectedBanner.messageLooksRejected(message)
          ? Icons.warning_amber_rounded
          : Icons.error_outline_rounded);
  final color = isSuccess
      ? const Color(0xFF2E7D32)
      : (isWarning || ApprovalRejectedBanner.messageLooksRejected(message)
          ? const Color(0xFFEF6C00)
          : const Color(0xFFC62828));

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        title: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A237E),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message.trim().isEmpty ? 'Something went wrong.' : message.trim(),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: const Color(0xFF37474F),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      );
    },
  );
}
