import 'dart:io';

import 'package:el_race/core/services/update_service.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    super.key,
    required this.result,
    this.isRtl = false,
  });

  final UpdateCheckResult result;
  final bool isRtl;

  static Future<bool> showIfNeeded(
    BuildContext context,
    UpdateCheckResult result, {
    bool isRtl = false,
  }) async {
    if (!result.forceUpdate && !result.optionalUpdate) return false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !result.forceUpdate,
      builder: (_) => UpdateDialog(result: result, isRtl: isRtl),
    );

    return result.forceUpdate;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isArabic = locale.languageCode == 'ar';
    final isForce = result.forceUpdate;
    final title = isArabic
        ? (isForce ? 'تحديث إلزامي' : 'تحديث متاح')
        : (isForce ? 'Required Update' : 'Update Available');
    final message = _resolveMessage(isArabic);
    final updateLabel = isArabic ? 'تحديث الآن' : 'Update Now';
    final laterLabel = isArabic ? 'لاحقاً' : 'Later';

    return PopScope(
      canPop: !isForce,
      child: Directionality(
        textDirection:
            isArabic || isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 30.tw),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.tr),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(22.tw, 22.th, 22.tw, 18.th),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58.tr,
                  height: 58.tr,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEFEF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFD7D8)),
                  ),
                  child: Icon(
                    Icons.system_update_alt_rounded,
                    size: 31.tr,
                    color: const Color(0xFFBA1719),
                  ),
                ),
                SizedBox(height: 14.th),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 17.tsp,
                    fontWeight: FontWeight.w700,
                    color: appFontColor,
                  ),
                ),
                SizedBox(height: 8.th),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF55596A),
                    height: 1.45,
                  ),
                ),
                if (result.latestVersion != null) ...[
                  SizedBox(height: 12.th),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.tw,
                      vertical: 5.th,
                    ),
                    decoration: BoxDecoration(
                      color: appFontColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'v${result.latestVersion}',
                      style: GoogleFonts.poppins(
                        fontSize: 12.tsp,
                        fontWeight: FontWeight.w600,
                        color: appFontColor,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 22.th),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openStore(context),
                    icon: const Icon(Icons.open_in_new_rounded, size: 19),
                    label: Text(updateLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appFontColor,
                      foregroundColor: Colors.white,
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
                  ),
                ),
                if (!isForce) ...[
                  SizedBox(height: 8.th),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      laterLabel,
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
    );
  }

  String _resolveMessage(bool isArabic) {
    if (isArabic && (result.updateMessageAr?.trim().isNotEmpty ?? false)) {
      return result.updateMessageAr!.trim();
    }
    if (!isArabic && (result.updateMessageEn?.trim().isNotEmpty ?? false)) {
      return result.updateMessageEn!.trim();
    }

    if (result.forceUpdate) {
      return isArabic
          ? 'يتوفر إصدار جديد من التطبيق. يرجى التحديث للمتابعة.'
          : 'A new app version is available. Please update to continue.';
    }
    return isArabic
        ? 'يتوفر إصدار جديد من التطبيق لتحسين الأداء والاستقرار.'
        : 'A new app version is available with performance and stability improvements.';
  }

  Future<void> _openStore(BuildContext context) async {
    final urls = _candidateStoreUrls();
    for (final rawUrl in urls) {
      final uri = Uri.tryParse(rawUrl);
      if (uri == null) continue;
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!result.forceUpdate && context.mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the store. Please try again.'),
        ),
      );
    }
  }

  List<String> _candidateStoreUrls() {
    final configuredUrl = result.updateUrl?.trim();
    final urls = <String>[
      if (configuredUrl != null && configuredUrl.isNotEmpty) configuredUrl,
    ];

    if (Platform.isIOS) {
      urls.addAll(const [
        'itms-apps://apps.apple.com/ae/app/el-race-cont-operations/id6748855825',
        'https://apps.apple.com/ae/app/el-race-cont-operations/id6748855825',
      ]);
    } else {
      urls.addAll(const [
        'market://details?id=ae.elrace.mobile',
        'https://play.google.com/store/apps/details?id=ae.elrace.mobile',
      ]);
    }

    return urls;
  }
}
