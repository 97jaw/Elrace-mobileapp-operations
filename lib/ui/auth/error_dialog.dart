import 'package:el_race/services/uaepass_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

/// UAE PASS error popup — matches approved mockup (warning triangle, red X close).
///
/// All failure types share the same fixed dialog width so short and long
/// messages look consistent.
class ErrorDialog {
  /// Shared popup width as a fraction of screen width (aligned with sign-in fields).
  static const double _widthFactor = 0.78;
  static const double _minWidth = 280;
  static const double _maxWidth = 340;

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

  static double _dialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return (screenWidth * _widthFactor).clamp(_minWidth, _maxWidth);
  }

  static Future<void> show(BuildContext context, {required String message}) {
    final dialogWidth = _dialogWidth(context);
    final horizontalInset =
        ((MediaQuery.sizeOf(context).width - dialogWidth) / 2)
            .clamp(16.0, 48.0);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Align(
          alignment: const Alignment(0, -0.08),
          child: Dialog(
            backgroundColor: Colors.white,
            elevation: 10,
            insetPadding: EdgeInsets.symmetric(horizontal: horizontalInset),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF222222), width: 0.8),
            ),
            child: SizedBox(
              width: dialogWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const _WarningTriangleIcon(size: 72),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.45,
                              color: Color(0xFF111111),
                              fontWeight: FontWeight.w700,
                            ),
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
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE31E24),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Yellow warning triangle with rounded corners and an explicit **black** "!".
///
/// Material [Icons.warning_rounded] punches a transparent hole for "!", which
/// reads as white on a white dialog — that does not match the approved mockup.
class _WarningTriangleIcon extends StatelessWidget {
  const _WarningTriangleIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WarningTrianglePainter(),
      ),
    );
  }
}

class _WarningTrianglePainter extends CustomPainter {
  static const Color _fillYellow = Color(0xFFF6C344);
  static const Color _borderYellow = Color(0xFFF0B429);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cornerRadius = w * 0.12;

    final top = Offset(w * 0.50, h * 0.10);
    final bottomRight = Offset(w * 0.90, h * 0.88);
    final bottomLeft = Offset(w * 0.10, h * 0.88);

    final triangle =
        _roundedTriangle(top, bottomRight, bottomLeft, cornerRadius);

    final fill = Paint()
      ..color = _fillYellow
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final stroke = Paint()
      ..color = _borderYellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawPath(triangle, fill);
    canvas.drawPath(triangle, stroke);

    final bar = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final barWidth = w * 0.11;
    final barLeft = (w - barWidth) / 2;
    canvas.drawRRect(
      RRect.fromLTRBR(
        barLeft,
        h * 0.32,
        barLeft + barWidth,
        h * 0.60,
        Radius.circular(barWidth / 2),
      ),
      bar,
    );

    canvas.drawCircle(
      Offset(w / 2, h * 0.72),
      barWidth * 0.58,
      bar,
    );
  }

  /// Builds an equilateral-ish triangle with rounded corners (no black edge).
  Path _roundedTriangle(Offset a, Offset b, Offset c, double radius) {
    Offset inset(Offset from, Offset to, double r) {
      final d = to - from;
      final len = d.distance;
      if (len == 0) return from;
      final t = (r / len).clamp(0.0, 0.45);
      return from + d * t;
    }

    final aToBStart = inset(a, b, radius);
    final aToBEnd = inset(b, a, radius);
    final bToCStart = inset(b, c, radius);
    final bToCEnd = inset(c, b, radius);
    final cToAStart = inset(c, a, radius);
    final cToAEnd = inset(a, c, radius);

    return Path()
      ..moveTo(aToBStart.dx, aToBStart.dy)
      ..lineTo(aToBEnd.dx, aToBEnd.dy)
      ..quadraticBezierTo(b.dx, b.dy, bToCStart.dx, bToCStart.dy)
      ..lineTo(bToCEnd.dx, bToCEnd.dy)
      ..quadraticBezierTo(c.dx, c.dy, cToAStart.dx, cToAStart.dy)
      ..lineTo(cToAEnd.dx, cToAEnd.dy)
      ..quadraticBezierTo(a.dx, a.dy, aToBStart.dx, aToBStart.dy)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
