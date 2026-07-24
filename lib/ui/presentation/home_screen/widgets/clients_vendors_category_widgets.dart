import 'dart:math' as math;

import 'package:el_race/core/clients_vendors/clients_vendors_route_names.dart';
import 'package:el_race/core/home/home_widget_visibility.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_api_client.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

const _kCvAssetRoot = 'assets/images/clients_vendors';

/// Shared height so Client / Vendors&Subs cards align.
const double _kCvCardHeight = 182;

/// Parsed view of the `clients` widget's `{is_authorized, metrics: {...}}`
/// payload (see ClientsVendorsWidgetService.get_clients_payload on the
/// backend). "-" placeholders when data hasn't loaded yet or the user isn't
/// authorized (metrics comes back empty in that case, by design).
class _ClientsMetrics {
  const _ClientsMetrics({
    required this.activeCount,
    required this.receivables,
    required this.overdueInvoices,
    required this.agreementsExpiring,
  });

  final String activeCount;
  final String receivables;
  final int overdueInvoices;
  final int agreementsExpiring;

  static const _empty = _ClientsMetrics(
    activeCount: '-',
    receivables: '-',
    overdueInvoices: 0,
    agreementsExpiring: 0,
  );

  factory _ClientsMetrics.fromRaw(Map<String, dynamic>? raw) {
    final metrics = raw?['metrics'];
    if (metrics is! Map) return _empty;
    return _ClientsMetrics(
      activeCount: (metrics['active_count'] ?? '-').toString(),
      receivables: (metrics['receivables'] ?? '-').toString(),
      overdueInvoices: (metrics['overdue_invoices'] as num?)?.toInt() ?? 0,
      agreementsExpiring:
          (metrics['agreements_expiring'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClientsVendorsCategoryClientsCard extends StatefulWidget {
  const ClientsVendorsCategoryClientsCard({
    super.key,
    this.tabletCompact = false,
  });

  final bool tabletCompact;

  @override
  State<ClientsVendorsCategoryClientsCard> createState() =>
      _ClientsVendorsCategoryClientsCardState();
}

class _ClientsVendorsCategoryClientsCardState
    extends State<ClientsVendorsCategoryClientsCard> {
  @override
  void initState() {
    super.initState();
    _loadIfNeeded();
  }

  Future<void> _loadIfNeeded() async {
    if (HomeWidgetSessionCache.clientsRaw != null) return;
    await HomeWidgetApiClient.refreshIfStale(
      onlyCodes: const {HomeWidgetCode.clients},
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _ClientsMetrics.fromRaw(HomeWidgetSessionCache.clientsRaw);

    // Design panel: 130°, #138A00@49% | #0F0C08@92% | #FF0000@20% | #000000@49%
    // Colors match the design-preview card after those stops composite on white
    // (sage → pale pink). Using raw #0F0C08@92% mid-card caused the bright
    // sheen / black edge in the app screenshot.
    return _ClientsVendorsHeroCard(
      onTap: () =>
          Navigator.of(context).pushNamed(ClientsVendorsRouteNames.clients),
      baseColor: Colors.white,
      washGradient: _cssAngleGradient(
        130,
        [
          _cvOverWhite(0x138A00, 0.49), // #138A00 @ 49%
          Color(0xFFC8D6BE), // soft mid (preview sampling)
          _cvOverWhite(0xFF0000, 0.20), // #FF0000 @ 20%
          Color(0xFFE8D4D0), // soft trailing pink-gray (preview)
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ),
      // Back → front: Police, Al Ain, Eagle (1st↔3rd swapped)
      artStack: const [
        'assets/images/clients_vendors/abu-dhabi-police.png',
        'assets/images/clients_vendors/alain-fc.png',
        'assets/images/clients_vendors/uae-emblem-cutout.png',
      ],
      artAnchorLeft: true,
      artLeftFactor: 0.32,
      artWidthFactor: 0.28,
      artHeightFactor: 0.76,
      artCenterVertically: true,
      artVerticalOffset: 2,
      artOpacity: 0.40,
      artStackOffsetFactor: 0.55, // wider gap between stacked logos
      artFadeLeft: false,
      label: 'CLIENTS',
      labelColor: const Color(0xFF0A5C12),
      activeCount: metrics.activeCount,
      activeCountColor: Colors.white,
      leftStatLabel: 'RECEIVABLES',
      leftStatValue: metrics.receivables,
      rightStatLabel: null,
      rightStatValue: null,
      statLabelColor: const Color(0x99000000),
      statValueColor: const Color(0xFF111111),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '▲ ${metrics.overdueInvoices} overdue invoices',
            style: GoogleFonts.poppins(
              fontSize: 12.5.usp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE53935),
              height: 1.2,
            ),
          ),
          SizedBox(height: 4.uh),
          Text(
            '${metrics.agreementsExpiring} agreements expiring',
            style: GoogleFonts.poppins(
              fontSize: 12.5.usp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111111),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorsMetrics {
  const _VendorsMetrics({
    required this.activeCount,
    required this.payables,
    required this.retentionHeld,
    required this.lpoValuePct,
    required this.invoicesPendingApproval,
    required this.mrPending,
    required this.agreementExpiringDays,
  });

  final String activeCount;
  final String payables;
  final String retentionHeld;
  final int lpoValuePct;
  final int invoicesPendingApproval;
  final int mrPending;
  final int agreementExpiringDays;

  static const _empty = _VendorsMetrics(
    activeCount: '-',
    payables: '-',
    retentionHeld: '-',
    lpoValuePct: 0,
    invoicesPendingApproval: 0,
    mrPending: 0,
    agreementExpiringDays: 0,
  );

  factory _VendorsMetrics.fromRaw(Map<String, dynamic>? raw) {
    final metrics = raw?['metrics'];
    if (metrics is! Map) return _empty;
    return _VendorsMetrics(
      activeCount: (metrics['active_count'] ?? '-').toString(),
      payables: (metrics['payables'] ?? '-').toString(),
      retentionHeld: (metrics['retention_held'] ?? '-').toString(),
      lpoValuePct: (metrics['lpo_value_pct'] as num?)?.toInt() ?? 0,
      invoicesPendingApproval:
          (metrics['invoices_pending_approval'] as num?)?.toInt() ?? 0,
      mrPending: (metrics['mr_pending'] as num?)?.toInt() ?? 0,
      agreementExpiringDays:
          (metrics['agreement_expiring_days'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Merged Vendors + Sub-Contractors home card (opens Vendors screen).
class ClientsVendorsCategoryVendorsCard extends StatefulWidget {
  const ClientsVendorsCategoryVendorsCard({
    super.key,
    this.tabletCompact = false,
  });

  final bool tabletCompact;

  @override
  State<ClientsVendorsCategoryVendorsCard> createState() =>
      _ClientsVendorsCategoryVendorsCardState();
}

class _ClientsVendorsCategoryVendorsCardState
    extends State<ClientsVendorsCategoryVendorsCard> {
  @override
  void initState() {
    super.initState();
    _loadIfNeeded();
  }

  Future<void> _loadIfNeeded() async {
    if (HomeWidgetSessionCache.vendorsRaw != null) return;
    await HomeWidgetApiClient.refreshIfStale(
      onlyCodes: const {HomeWidgetCode.vendors},
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _VendorsMetrics.fromRaw(HomeWidgetSessionCache.vendorsRaw);

    // Spec base 160° #252A6B → #100F30
    // Design panel wash 180° #F2ECEE @ 88% → #977DFF @ 49%
    return _ClientsVendorsHeroCard(
      onTap: () =>
          Navigator.of(context).pushNamed(ClientsVendorsRouteNames.vendors),
      baseGradient: _cssAngleGradient(
        160,
        const [
          Color(0xFF252A6B),
          Color(0xFF100F30),
        ],
      ),
      washGradient: _cssAngleGradient(
        180,
        const [
          Color(0xB3F2ECEE),
          Color(0x7D977DFF),
        ],
      ),
      artAsset: '$_kCvAssetRoot/dubai-skyline-cutout.png',
      artRight: -16,
      artWidthFactor: 0.52,
      artHeightFactor: 1.05,
      artCenterVertically: true,
      artOpacity: 0.28,
      label: 'VENDORS & SUBS',
      labelColor: const Color(0xFF3E50A8),
      activeCount: metrics.activeCount,
      leftStatLabel: 'PAYABLES',
      leftStatValue: metrics.payables,
      rightStatLabel: 'RETENTION',
      rightStatValue: metrics.retentionHeld,
      footer: Text.rich(
        TextSpan(
          style: GoogleFonts.poppins(
            fontSize: 12.5.usp,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
          children: [
            TextSpan(
              text: '▼ ${metrics.lpoValuePct}% LPO',
              style: const TextStyle(color: Color(0xFFC7D2FE)),
            ),
            const TextSpan(
              text: '  ·  ',
              style: TextStyle(color: Color(0x73FFFFFF)),
            ),
            TextSpan(
              text: '${metrics.invoicesPendingApproval} invoices pending',
              style: const TextStyle(color: Color(0xFFFDE68A)),
            ),
            const TextSpan(
              text: '  ·  ',
              style: TextStyle(color: Color(0x73FFFFFF)),
            ),
            TextSpan(
              text: '${metrics.mrPending} MR · ${metrics.agreementExpiringDays}d',
              style: const TextStyle(color: Color(0xFFFDBA74)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Composite [hex] RGB over white at [opacity] (0–1) — matches design-tool canvas.
Color _cvOverWhite(int hex, double opacity) {
  final r = (hex >> 16) & 0xff;
  final g = (hex >> 8) & 0xff;
  final b = hex & 0xff;
  int ch(int c) => (c * opacity + 255 * (1 - opacity)).round();
  return Color.fromARGB(255, ch(r), ch(g), ch(b));
}

LinearGradient _cssAngleGradient(
  double degrees,
  List<Color> colors, {
  List<double>? stops,
}) {
  final radians = (degrees - 90) * math.pi / 180;
  final x = math.cos(radians);
  final y = math.sin(radians);
  return LinearGradient(
    begin: Alignment(-x, -y),
    end: Alignment(x, y),
    colors: colors,
    stops: stops,
  );
}

class _ClientsVendorsHeroCard extends StatelessWidget {
  const _ClientsVendorsHeroCard({
    required this.onTap,
    required this.artOpacity,
    required this.label,
    required this.labelColor,
    required this.activeCount,
    required this.leftStatLabel,
    required this.leftStatValue,
    required this.footer,
    this.rightStatLabel,
    this.rightStatValue,
    this.artAsset,
    this.artStack,
    this.baseColor,
    this.baseGradient,
    this.washGradient,
    this.showDotTexture = false,
    this.artRight = 0,
    this.artLeftFactor,
    this.artAnchorLeft = false,
    this.artWidthFactor = 0.55,
    this.artHeightFactor = 1.0,
    this.artVerticalOffset = 0,
    this.artCenterVertically = false,
    this.artStackOffsetFactor = 0.20,
    this.artFadeLeft = true,
    this.activeCountColor = Colors.white,
    this.statLabelColor,
    this.statValueColor = Colors.white,
    this.dividerColor,
  });

  final VoidCallback onTap;
  final Color? baseColor;
  final LinearGradient? baseGradient;
  final LinearGradient? washGradient;
  final bool showDotTexture;
  final String? artAsset;
  final List<String>? artStack;
  final double artOpacity;
  final double artRight;
  final double? artLeftFactor;
  final bool artAnchorLeft;
  final double artWidthFactor;
  final double artHeightFactor;
  final double artVerticalOffset;
  final bool artCenterVertically;
  final double artStackOffsetFactor;
  final bool artFadeLeft;
  final String label;
  final Color labelColor;
  final String activeCount;
  final Color activeCountColor;
  final String leftStatLabel;
  final String leftStatValue;
  final String? rightStatLabel;
  final String? rightStatValue;
  final Color? statLabelColor;
  final Color statValueColor;
  final Color? dividerColor;
  final Widget footer;

  List<String> get _artLayers {
    if (artStack != null && artStack!.isNotEmpty) return artStack!;
    if (artAsset != null) return [artAsset!];
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final layers = _artLayers;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = ResponsiveBreakpoints.shellHeight(
          constraints,
          design: _kCvCardHeight,
        );
        return SizedBox(
      height: h,
      width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26.ur),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26.ur),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (baseColor != null)
                  Positioned.fill(
                    child: ColoredBox(color: baseColor!),
                  ),
                if (baseGradient != null)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: baseGradient),
                    ),
                  ),
                if (washGradient != null)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: washGradient),
                    ),
                  ),
                if (showDotTexture)
                  Positioned.fill(
                    child: CustomPaint(painter: _DotTexturePainter()),
                  ),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardH = constraints.maxHeight;
                      final cardW = constraints.maxWidth;
                      final h = cardH * artHeightFactor;
                      final w = cardW * artWidthFactor;

                      final double top;
                      if (artCenterVertically) {
                        top = (cardH - h) / 2 + artVerticalOffset.uh;
                      } else {
                        top = artVerticalOffset.uh;
                      }

                      // Back layers first. Left-anchored stack grows rightward
                      // so all logos stay on-card; right-anchored grows leftward.
                      final count = layers.length;
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          for (var i = 0; i < count; i++)
                            Positioned(
                              left: artAnchorLeft
                                  ? (cardW * (artLeftFactor ?? 0.4)) +
                                      (i * artStackOffsetFactor * w)
                                  : null,
                              right: artAnchorLeft
                                  ? null
                                  : artRight.w -
                                      ((count - 1 - i) *
                                          artStackOffsetFactor *
                                          w),
                              top: top,
                              width: w,
                              height: h,
                              child: Opacity(
                                opacity: artOpacity *
                                    (0.72 + (0.28 * (i + 1) / count)),
                                child: artFadeLeft
                                    ? ShaderMask(
                                        blendMode: BlendMode.dstIn,
                                        shaderCallback: (bounds) {
                                          return const LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Colors.transparent,
                                              Colors.transparent,
                                              Colors.white,
                                              Colors.white,
                                            ],
                                            stops: [0.0, 0.08, 0.40, 1.0],
                                          ).createShader(bounds);
                                        },
                                        child: Image.asset(
                                          layers[i],
                                          fit: BoxFit.contain,
                                          alignment: Alignment.center,
                                          filterQuality: FilterQuality.high,
                                        ),
                                      )
                                    : Image.asset(
                                        layers[i],
                                        fit: BoxFit.contain,
                                        alignment: Alignment.center,
                                        filterQuality: FilterQuality.high,
                                      ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(20.w),
                  // MainAxisSize.min column — safe to scaleDown on phone & tablet
                  // so footer/metadata never overflow the fixed card height.
                  child: _cvScaleDownContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 11.usp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.88,
                            color: labelColor,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 4.uh),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$activeCount ',
                                style: GoogleFonts.poppins(
                                  fontSize: 21.usp,
                                  fontWeight: FontWeight.w800,
                                  color: activeCountColor,
                                  height: 1.1,
                                ),
                              ),
                              TextSpan(
                                text: 'Active',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.usp,
                                  fontWeight: FontWeight.w600,
                                  color: activeCountColor,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.uh),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _StatColumn(
                                label: leftStatLabel,
                                value: leftStatValue,
                                valueSize: 19.usp,
                                valueWeight: FontWeight.w800,
                                labelColor: statLabelColor,
                                valueColor: statValueColor,
                              ),
                            ),
                            if (rightStatLabel != null &&
                                rightStatValue != null) ...[
                              Container(
                                width: 1,
                                height: 36.uh,
                                margin: EdgeInsets.only(right: 22.w),
                                color: dividerColor ??
                                    Colors.white.withValues(alpha: 0.15),
                              ),
                              Expanded(
                                child: _StatColumn(
                                  label: rightStatLabel!,
                                  value: rightStatValue!,
                                  valueSize: 15.usp,
                                  valueWeight: FontWeight.w700,
                                  labelColor: statLabelColor,
                                  valueColor: statValueColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 14.uh),
                        footer,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        );
      },
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.valueSize,
    required this.valueWeight,
    this.labelColor,
    this.valueColor = Colors.white,
  });

  final String label;
  final String value;
  final double valueSize;
  final FontWeight valueWeight;
  final Color? labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.usp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: labelColor ?? Colors.white.withValues(alpha: 0.55),
            height: 1.1,
          ),
        ),
        SizedBox(height: 4.uh),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: valueSize,
            fontWeight: valueWeight,
            color: valueColor,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _DotTexturePainter extends CustomPainter {
  const _DotTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    const step = 14.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Scale-down guard for CV cards (MainAxisSize.min content, no Spacer).
/// Child lays out at natural size, then shrinks uniformly if taller/wider
/// than the card — no RenderFlex overflow on phone or tablet.
Widget _cvScaleDownContent({required Widget child}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: constraints.maxWidth,
          child: child,
        ),
      );
    },
  );
}
