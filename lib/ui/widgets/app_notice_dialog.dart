import 'package:el_race/core/app_notices/app_notice.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compact popup for login notices and maintenance (same size for both).
///
/// Maintenance cannot be dismissed; [onRetry] returns true once maintenance
/// is over, which closes the popup.
class AppNoticeDialog extends StatefulWidget {
  const AppNoticeDialog({super.key, required this.notice, this.onRetry});

  final AppNotice notice;
  final Future<bool> Function()? onRetry;

  static Future<void> show(
    BuildContext context,
    AppNotice notice, {
    Future<bool> Function()? onRetry,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: notice.dismissible,
      useRootNavigator: true,
      builder: (_) => AppNoticeDialog(notice: notice, onRetry: onRetry),
    );
  }

  @override
  State<AppNoticeDialog> createState() => _AppNoticeDialogState();
}

class _AppNoticeDialogState extends State<AppNoticeDialog> {
  bool _checking = false;
  bool _stillDown = false;

  AppNotice get notice => widget.notice;

  ({IconData icon, Color color, Color tint}) get _style {
    switch (notice.icon) {
      case 'support':
        return (
          icon: PhosphorIconsDuotone.headset,
          color: const Color(0xFF0E7490),
          tint: const Color(0xFFE0F7FA),
        );
      case 'maintenance':
        return (
          icon: PhosphorIconsDuotone.wrench,
          color: const Color(0xFFB45309),
          tint: const Color(0xFFFFF4E5),
        );
      case 'warning':
        return (
          icon: PhosphorIconsDuotone.warningCircle,
          color: const Color(0xFFBA1719),
          tint: const Color(0xFFFFEFEF),
        );
      case 'lock':
        return (
          icon: PhosphorIconsDuotone.lockKey,
          color: const Color(0xFF6D28D9),
          tint: const Color(0xFFF1EAFE),
        );
      case 'update':
        return (
          icon: PhosphorIconsDuotone.arrowsClockwise,
          color: const Color(0xFF047857),
          tint: const Color(0xFFE7F8F1),
        );
      default:
        return (
          icon: PhosphorIconsDuotone.info,
          color: const Color(0xFF1D4ED8),
          tint: const Color(0xFFEAF1FF),
        );
    }
  }

  Future<void> _retry() async {
    final onRetry = widget.onRetry;
    if (onRetry == null) return;
    setState(() {
      _checking = true;
      _stillDown = false;
    });
    final cleared = await onRetry();
    if (!mounted) return;
    if (cleared) {
      Navigator.of(context, rootNavigator: true).pop();
      return;
    }
    setState(() {
      _checking = false;
      _stillDown = true;
    });
  }

  Future<void> _openButton(AppNoticeButton button) async {
    final uri = button.uri;
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(button.value)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final style = _style;
    final button = notice.button;
    final isMaintenance = notice.isMaintenance;
    final retryLabel = arabic ? 'إعادة المحاولة' : 'Try Again';
    final closeLabel = arabic ? 'حسناً' : 'OK';
    final stillDownLabel = arabic
        ? 'لا يزال التطبيق تحت الصيانة.'
        : 'The app is still under maintenance.';

    final primaryLabel = button != null
        ? button.labelFor(arabic)
        : (isMaintenance ? retryLabel : closeLabel);
    final VoidCallback? primaryAction = _checking
        ? null
        : button != null
            ? () => _openButton(button)
            : isMaintenance
                ? _retry
                : () => Navigator.of(context, rootNavigator: true).pop();

    final String? secondaryLabel = button == null
        ? null
        : (isMaintenance ? retryLabel : closeLabel);
    final VoidCallback? secondaryAction = _checking
        ? null
        : isMaintenance
            ? _retry
            : () => Navigator.of(context, rootNavigator: true).pop();

    return PopScope(
      canPop: notice.dismissible,
      child: Directionality(
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 30.tw),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.tr),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: EdgeInsets.fromLTRB(22.tw, 24.th, 22.tw, 16.th),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64.tr,
                    height: 64.tr,
                    decoration: BoxDecoration(
                      color: style.tint,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: style.color.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        style.icon,
                        size: 34.tr,
                        color: style.color,
                        duotoneSecondaryOpacity: 0.28,
                      ),
                    ),
                  ),
                  SizedBox(height: 14.th),
                  Text(
                    notice.titleFor(arabic),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 17.tsp,
                      fontWeight: FontWeight.w700,
                      color: appFontColor,
                    ),
                  ),
                  SizedBox(height: 8.th),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.35,
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        notice.messageFor(arabic),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13.tsp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF55596A),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                  if (_stillDown) ...[
                    SizedBox(height: 10.th),
                    Text(
                      stillDownLabel,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12.tsp,
                        fontWeight: FontWeight.w500,
                        color: style.color,
                      ),
                    ),
                  ],
                  SizedBox(height: 20.th),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: primaryAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appFontColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            appFontColor.withValues(alpha: 0.5),
                        padding: EdgeInsets.symmetric(vertical: 13.th),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.tr),
                        ),
                        elevation: 0,
                        textStyle: GoogleFonts.poppins(
                          fontSize: 14.tsp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: _checking && button == null
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(primaryLabel),
                    ),
                  ),
                  if (secondaryLabel != null) ...[
                    SizedBox(height: 6.th),
                    TextButton(
                      onPressed: secondaryAction,
                      child: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              secondaryLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 13.tsp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF747789),
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
