import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class PurchaseDraftInvoiceRow extends StatelessWidget {
  const PurchaseDraftInvoiceRow({
    super.key,
    required this.item,
    this.selected = false,
    this.onTap,
    this.compact = false,
  });

  final DraftInvoiceItem item;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final decoration = selected
        ? BoxDecoration(
            gradient: LinearGradient(
              colors: [
                PurchaseTheme.accentDeep.withValues(alpha: 0.12),
                PurchaseTheme.accentBlue.withValues(alpha: 0.08),
              ],
            ),
            border: Border(
              left: BorderSide(color: PurchaseTheme.accentBlue, width: 3.tw),
            ),
          )
        : BoxDecoration(
            color: Colors.white.withValues(alpha: compact ? 0.35 : 0.5),
            border: compact
                ? Border(
                    bottom: BorderSide(
                      color: PurchaseTheme.accentBlue.withValues(alpha: 0.12),
                    ),
                  )
                : null,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: compact ? 0 : 12.tw,
            vertical: compact ? 0 : 6.th,
          ),
          padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 12.th),
          decoration: decoration,
          child: Row(
            children: [
              _VendorAvatar(name: item.vendor, photoUrl: item.vendorPhoto),
              SizedBox(width: 12.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.vendor.isNotEmpty ? item.vendor : '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13.tsp,
                        fontWeight: FontWeight.w600,
                        color: PurchaseTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.th),
                    Text(
                      item.invoiceId,
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        color: PurchaseTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.tw, vertical: 3.th),
                    decoration: BoxDecoration(
                      gradient: PurchaseTheme.urgentAccentGradient,
                      borderRadius: BorderRadius.circular(8.tr),
                      border: Border.all(
                        color: PurchaseTheme.pendingBadge.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      item.state,
                      style: GoogleFonts.poppins(
                        fontSize: 9.tsp,
                        fontWeight: FontWeight.w700,
                        color: PurchaseTheme.pendingBadge,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.th),
                  Text(
                    item.timeAgo.isNotEmpty ? item.timeAgo : item.createDate,
                    style: GoogleFonts.poppins(
                      fontSize: 10.tsp,
                      color: PurchaseTheme.textMuted,
                    ),
                  ),
                  SizedBox(height: 2.th),
                  Text(
                    item.formattedAmount,
                    style: GoogleFonts.poppins(
                      fontSize: 13.tsp,
                      fontWeight: FontWeight.w700,
                      color: PurchaseTheme.accentDeep,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorAvatar extends StatelessWidget {
  const _VendorAvatar({required this.name, required this.photoUrl});

  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final url = PurchaseAvatar.sanitizeUrl(photoUrl);
    if (url != null) {
      return CircleAvatar(
        radius: 20.tr,
        backgroundColor: const Color(0xFFE8F4FC),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: 40.tr,
            height: 40.tr,
            fit: BoxFit.cover,
            placeholder: (_, __) => _initialAvatar(initial),
            errorWidget: (_, __, ___) => _initialAvatar(initial),
          ),
        ),
      );
    }
    return _initialAvatar(initial);
  }

  Widget _initialAvatar(String initial) {
    return CircleAvatar(
      radius: 20.tr,
      backgroundColor: PurchaseTheme.accentBlue.withValues(alpha: 0.25),
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: 14.tsp,
          fontWeight: FontWeight.w700,
          color: PurchaseTheme.accentDeep,
        ),
      ),
    );
  }
}

/// Reusable employee/partner avatar for purchase lists & detail.
class PurchaseAvatar extends StatelessWidget {
  const PurchaseAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    this.radius = 18,
  });

  final String name;
  final String photoUrl;
  final double radius;

  static String? sanitizeUrl(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower == 'false' || lower == 'null' || lower == 'none') return null;
    if (lower.contains('/image/false') || lower.endsWith('/false')) {
      return null;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final url = sanitizeUrl(photoUrl);
    if (url != null) {
      return CircleAvatar(
        radius: radius.tr,
        backgroundColor: const Color(0xFFE8F4FC),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: radius.tr * 2,
            height: radius.tr * 2,
            fit: BoxFit.cover,
            placeholder: (_, __) => _fallback(initial),
            errorWidget: (_, __, ___) => _fallback(initial),
          ),
        ),
      );
    }
    return _fallback(initial);
  }

  Widget _fallback(String initial) {
    return CircleAvatar(
      radius: radius.tr,
      backgroundColor: PurchaseTheme.accentBlue.withValues(alpha: 0.22),
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: (radius * 0.7).tsp,
          fontWeight: FontWeight.w700,
          color: PurchaseTheme.accentDeep,
        ),
      ),
    );
  }
}
