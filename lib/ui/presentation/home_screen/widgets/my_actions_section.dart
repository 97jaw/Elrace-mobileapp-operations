import 'dart:ui';

import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_my_actions_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class _ActionItem {
  const _ActionItem({
    required this.action,
    required this.label,
    required this.iconAsset,
    required this.tint,
  });

  final HomeMyAction action;
  final String label;
  final String iconAsset;
  final Color tint;
}

class MyActionsSection extends StatelessWidget {
  const MyActionsSection({
    super.key,
    this.compact = false,
    this.dense = false,
    this.showTitle = true,
    this.inGlass = true,
    this.dockMode = false,
    this.expandToWidth = false,
  });

  final bool compact;
  /// Tighter layout on main home — sits closer to the widgets panel.
  final bool dense;
  final bool showTitle;
  final bool inGlass;

  /// macOS-style floating dock: compact icons in a centered glass pill.
  final bool dockMode;

  /// When true with [dockMode], dock stretches to parent width (tablet mid).
  final bool expandToWidth;

  static const _items = [
    _ActionItem(
      action: HomeMyAction.hr,
      label: 'HR',
      iconAsset: 'assets/newapp/newicon/hr.png',
      tint: Color(0xFFE8F4FC),
    ),
    _ActionItem(
      action: HomeMyAction.rfq,
      label: 'RFQ',
      iconAsset: 'assets/newapp/newicon/rfq.png',
      tint: Color(0xFFF0F4FF),
    ),
    _ActionItem(
      action: HomeMyAction.pettyCash,
      label: 'Petty Cash',
      iconAsset: 'assets/newapp/newicon/Cash.png',
      tint: Color(0xFFFFF8E8),
    ),
    _ActionItem(
      action: HomeMyAction.invoice,
      label: 'Invoice',
      iconAsset: 'assets/newapp/newicon/Invoice.png',
      tint: Color(0xFFFFF5F0),
    ),
    _ActionItem(
      action: HomeMyAction.signature,
      label: 'Signature',
      iconAsset: 'assets/png/signarute-frame.png',
      tint: Color(0xFFF5F0FF),
    ),
    _ActionItem(
      action: HomeMyAction.myRequests,
      label: 'My Requests',
      iconAsset: 'assets/newapp/newicon/my_action_my_request.png',
      tint: Color(0xFFF0F4FF),
    ),
  ];

  static double estimatedHeight(
    BuildContext context, {
    bool compact = false,
    bool dense = false,
    bool showTitle = true,
    bool inGlass = true,
  }) {
    if (dense) {
      final glassPad = inGlass ? 16.h : 0.0;
      final titleBlock = showTitle ? 22.h : 0.0;
      final row = 48.w + 4.h + 18.h;
      return glassPad + titleBlock + row + 2.h + _responsiveDenseTop(context);
    }
    final glassPad = inGlass ? 22.h : 0.0;
    final titleBlock = showTitle ? (compact ? 26.h : 30.h) : 0.0;
    final tile = compact ? 56.w : 64.w;
    final label = compact ? 22.h : 24.h;
    final row = tile + 5.h + label;
    return glassPad + titleBlock + row + 4.h;
  }

  static double _responsiveDenseTop(BuildContext context) {
    return (2.h).clamp(2.0, 6.0);
  }

  @override
  Widget build(BuildContext context) {
    if (dockMode) {
      return _buildDock(context);
    }

    final tileSize = dense ? 46.w : (compact ? 54.w : 64.w);
    final iconSize = dense ? 23.w : (compact ? 27.w : 32.w);
    final tileWidth = dense ? 62.w : (compact ? 70.w : 76.w);
    final gap = dense ? 5.w : (compact ? 6.w : 8.w);
    final labelHeight = dense ? 17.h : (compact ? 21.h : 24.h);
    final labelGap = dense ? 4.h : 5.h;
    final iconsRowHeight = tileSize + labelGap + labelHeight;

    final iconsRow = LayoutBuilder(
      builder: (context, constraints) {
        final row = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              _MyActionTile(
                iconAsset: _items[i].iconAsset,
                label: _items[i].label,
                tint: _items[i].tint,
                tileSize: tileSize,
                iconSize: iconSize,
                tileWidth: tileWidth,
                labelGap: labelGap,
                labelFontSize: dense ? 9.sp : 10.sp,
                labelMaxLines: dense ? 1 : 2,
                onTap: () =>
                    HomeMyActionsNavigation.open(context, _items[i].action),
              ),
              if (i != _items.length - 1) SizedBox(width: gap),
            ],
          ],
        );

        return ClipRect(
          child: SizedBox(
            height: iconsRowHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Align(
                  alignment: Alignment.center,
                  child: row,
                ),
              ),
            ),
          ),
        );
      },
    );

    final titleBlock = showTitle
        ? Padding(
            padding: EdgeInsets.only(
              bottom: dense ? 6.h : (compact ? 8.h : 10.h),
            ),
            child: Text(
              'My Actions',
              style: GoogleFonts.poppins(
                fontSize: dense ? 14.sp : (compact ? 15.sp : 16.sp),
                fontWeight: FontWeight.w700,
                color: HomeGlassTheme.textPrimary,
              ),
            ),
          )
        : null;

    if (!inGlass) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (titleBlock != null) titleBlock,
            iconsRow,
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16.w,
        dense ? _responsiveDenseTop(context) : 0,
        16.w,
        dense ? 0 : 4.h,
      ),
      child: HomeGlassTheme.glassSurface(
        borderRadius: BorderRadius.circular(dense ? 16.r : 18.r),
        padding: EdgeInsets.fromLTRB(
          dense ? 10.w : 12.w,
          dense ? 8.h : 12.h,
          0,
          dense ? 8.h : 10.h,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (titleBlock != null)
              Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: titleBlock,
              ),
            iconsRow,
          ],
        ),
      ),
    );
  }

  Widget _buildDock(BuildContext context) {
    // Crisp raw pixels — no ScreenUtil, no backdrop blur (blur looked soft).
    const tileSize = 44.0;
    const iconSize = 26.0;
    const gap = 6.0;
    const labelGap = 4.0;
    const labelFontSize = 10.0;

    final tiles = <Widget>[
      for (var i = 0; i < _items.length; i++) ...[
        if (expandToWidth)
          Expanded(
            child: _MyActionTile(
              iconAsset: _items[i].iconAsset,
              label: _items[i].label,
              tint: _items[i].tint,
              tileSize: tileSize,
              iconSize: iconSize,
              tileWidth: double.infinity,
              labelGap: labelGap,
              labelFontSize: labelFontSize,
              labelMaxLines: 1,
              crisp: true,
              onTap: () =>
                  HomeMyActionsNavigation.open(context, _items[i].action),
            ),
          )
        else
          _MyActionTile(
            iconAsset: _items[i].iconAsset,
            label: _items[i].label,
            tint: _items[i].tint,
            tileSize: tileSize,
            iconSize: iconSize,
            tileWidth: 58,
            labelGap: labelGap,
            labelFontSize: labelFontSize,
            labelMaxLines: 1,
            crisp: true,
            onTap: () =>
                HomeMyActionsNavigation.open(context, _items[i].action),
          ),
        if (i != _items.length - 1) const SizedBox(width: gap),
      ],
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B2A4A).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: expandToWidth
          ? Row(children: tiles)
          : ClipRect(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: tiles,
                ),
              ),
            ),
    );
  }
}

class _MyActionTile extends StatelessWidget {
  const _MyActionTile({
    required this.iconAsset,
    required this.label,
    required this.tint,
    required this.tileSize,
    required this.iconSize,
    required this.tileWidth,
    required this.labelGap,
    required this.labelFontSize,
    required this.labelMaxLines,
    required this.onTap,
    this.crisp = false,
  });

  final String iconAsset;
  final String label;
  final Color tint;
  final double tileSize;
  final double iconSize;
  final double tileWidth;
  final double labelGap;
  final double labelFontSize;
  final int labelMaxLines;
  final VoidCallback onTap;
  /// Dock mode: solid tiles, high-quality icons (no backdrop blur).
  final bool crisp;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(crisp ? 14.0 : 16.r);

    final iconTile = Container(
      width: tileSize,
      height: tileSize,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: crisp ? Colors.white : null,
        border: crisp
            ? Border.all(color: const Color(0xFFE8ECF2), width: 1)
            : null,
        gradient: crisp
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tint.withValues(alpha: 0.65),
                  tint.withValues(alpha: 0.28),
                ],
              )
            : null,
        boxShadow: crisp
            ? [
                BoxShadow(
                  color: const Color(0xFF1B2A4A).withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Image.asset(
          iconAsset,
          width: iconSize,
          height: iconSize,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
        ),
      ),
    );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (crisp)
          iconTile
        else
          ClipRRect(
            borderRadius: borderRadius,
            child: AdaptiveGlassLayer(
              borderRadius: borderRadius,
              sigma: 6,
              fallbackColor: Colors.white.withValues(alpha: 0.92),
              fallbackBorder: Border.all(color: Colors.white, width: 1.1),
              child: Container(
                width: tileSize,
                height: tileSize,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B2A4A).withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tint.withValues(alpha: 0.55),
                        tint.withValues(alpha: 0.22),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Center(
                    child: Image.asset(
                      iconAsset,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
        SizedBox(height: labelGap),
        Text(
          label,
          maxLines: labelMaxLines,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: labelFontSize,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: HomeGlassTheme.textPrimary,
          ),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: SizedBox(
          width: tileWidth.isFinite ? tileWidth : null,
          child: body,
        ),
      ),
    );
  }
}
