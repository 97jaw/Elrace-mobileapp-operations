import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_my_actions_navigation.dart';
import 'package:el_race/ui/presentation/my_actions/data/repositories/signature_actions_repository.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:el_race/ui/presentation/my_actions/theme/signature_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class _ActionItem {
  const _ActionItem({
    required this.action,
    required this.label,
    required this.iconAsset,
    required this.badgeColor,
    required this.iconColor,
  });

  final HomeMyAction action;
  final String label;
  final String iconAsset;
  final Color badgeColor;
  final Color iconColor;
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

  /// Same chip size as check-in / prayer dual-strip icons.
  static double _chipSize(BuildContext context) =>
      ResponsiveBreakpoints.isTabletScreen ? 48.w : 36.w;

  static double _glyphSize(BuildContext context) =>
      ResponsiveBreakpoints.isTabletScreen ? 18.w : 15.w;

  static List<_ActionItem> get _items {
    final hr = MyActionsModuleTheme.of(MyActionsModule.hr);
    final rfq = MyActionsModuleTheme.of(MyActionsModule.rfq);
    final petty = MyActionsModuleTheme.of(MyActionsModule.pettyCash);
    final invoice = MyActionsModuleTheme.of(MyActionsModule.invoice);
    final requests = MyActionsModuleTheme.of(MyActionsModule.myRequests);
    // Clean white / soft faded chip fill for every action.
    const sharedBadge = Color(0xF7FFFFFF);
    return [
      _ActionItem(
        action: HomeMyAction.hr,
        label: 'HR',
        iconAsset: hr.iconAsset,
        badgeColor: sharedBadge,
        iconColor: hr.primary,
      ),
      _ActionItem(
        action: HomeMyAction.rfq,
        label: 'RFQ',
        iconAsset: rfq.iconAsset,
        badgeColor: sharedBadge,
        iconColor: rfq.primary,
      ),
      _ActionItem(
        action: HomeMyAction.pettyCash,
        label: 'Petty Cash',
        iconAsset: petty.iconAsset,
        badgeColor: sharedBadge,
        iconColor: petty.primary,
      ),
      _ActionItem(
        action: HomeMyAction.invoice,
        label: 'Invoice',
        iconAsset: invoice.iconAsset,
        badgeColor: sharedBadge,
        iconColor: invoice.primary,
      ),
      _ActionItem(
        action: HomeMyAction.signature,
        label: 'Signature',
        iconAsset: 'assets/png/signarute-frame.png',
        badgeColor: sharedBadge,
        iconColor: SignatureTheme.brown,
      ),
      _ActionItem(
        action: HomeMyAction.myRequests,
        label: 'My Requests',
        iconAsset: requests.iconAsset,
        badgeColor: sharedBadge,
        iconColor: requests.primary,
      ),
    ];
  }

  static double estimatedHeight(
    BuildContext context, {
    bool compact = false,
    bool dense = false,
    bool showTitle = true,
    bool inGlass = true,
  }) {
    final chip = ResponsiveBreakpoints.isTabletScreen ? 48.0 : 36.0;
    if (dense) {
      final glassPad = inGlass ? 16.h : 0.0;
      final titleBlock = showTitle ? 22.h : 0.0;
      final row = chip.w + 4.h + 18.h;
      return glassPad + titleBlock + row + 2.h + _responsiveDenseTop(context);
    }
    final glassPad = inGlass ? 22.h : 0.0;
    final titleBlock = showTitle ? (compact ? 26.h : 30.h) : 0.0;
    final label = compact ? 22.h : 24.h;
    final row = chip.w + 5.h + label;
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

    final items = _items;
    final tileSize = _chipSize(context);
    final iconSize = _glyphSize(context);
    final tileWidth = dense ? 58.w : (compact ? 64.w : 70.w);
    final gap = dense ? 6.w : (compact ? 8.w : 10.w);
    final labelHeight = dense ? 16.h : (compact ? 20.h : 22.h);
    final labelGap = dense ? 4.h : 5.h;
    final iconsRowHeight = tileSize + labelGap + labelHeight;

    final iconsRow = LayoutBuilder(
      builder: (context, constraints) {
        final row = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (items[i].action == HomeMyAction.signature)
                StreamBuilder<int>(
                  stream: SignatureActionsRepository.instance
                      .watchNeedsMySignatureCount(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return _MyActionTile(
                      iconAsset: items[i].iconAsset,
                      label: items[i].label,
                      badgeColor: items[i].badgeColor,
                      iconColor: items[i].iconColor,
                      tileSize: tileSize,
                      iconSize: iconSize,
                      tileWidth: tileWidth,
                      labelGap: labelGap,
                      labelFontSize: dense ? 9.sp : 10.sp,
                      labelMaxLines: dense ? 1 : 2,
                      badgeCount: count,
                      onTap: () => HomeMyActionsNavigation.open(
                        context,
                        items[i].action,
                      ),
                    );
                  },
                )
              else
                _MyActionTile(
                  iconAsset: items[i].iconAsset,
                  label: items[i].label,
                  badgeColor: items[i].badgeColor,
                  iconColor: items[i].iconColor,
                  tileSize: tileSize,
                  iconSize: iconSize,
                  tileWidth: tileWidth,
                  labelGap: labelGap,
                  labelFontSize: dense ? 9.sp : 10.sp,
                  labelMaxLines: dense ? 1 : 2,
                  onTap: () =>
                      HomeMyActionsNavigation.open(context, items[i].action),
                ),
              if (i != items.length - 1) SizedBox(width: gap),
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
    const tileSize = 36.0;
    const iconSize = 15.0;
    const gap = 8.0;
    const labelGap = 4.0;
    const labelFontSize = 10.0;
    final items = _items;

    final tiles = <Widget>[
      for (var i = 0; i < items.length; i++) ...[
        if (expandToWidth)
          Expanded(
            child: _MyActionTile(
              iconAsset: items[i].iconAsset,
              label: items[i].label,
              badgeColor: items[i].badgeColor,
              iconColor: items[i].iconColor,
              tileSize: tileSize,
              iconSize: iconSize,
              tileWidth: double.infinity,
              labelGap: labelGap,
              labelFontSize: labelFontSize,
              labelMaxLines: 1,
              crisp: true,
              onTap: () =>
                  HomeMyActionsNavigation.open(context, items[i].action),
            ),
          )
        else
          _MyActionTile(
            iconAsset: items[i].iconAsset,
            label: items[i].label,
            badgeColor: items[i].badgeColor,
            iconColor: items[i].iconColor,
            tileSize: tileSize,
            iconSize: iconSize,
            tileWidth: 58,
            labelGap: labelGap,
            labelFontSize: labelFontSize,
            labelMaxLines: 1,
            crisp: true,
            onTap: () =>
                HomeMyActionsNavigation.open(context, items[i].action),
          ),
        if (i != items.length - 1) const SizedBox(width: gap),
      ],
    ];

    return HomeGlassTheme.widgetsStyleSurface(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      shadowOffset: const Offset(0, 4),
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
    required this.badgeColor,
    required this.iconColor,
    required this.tileSize,
    required this.iconSize,
    required this.tileWidth,
    required this.labelGap,
    required this.labelFontSize,
    required this.labelMaxLines,
    required this.onTap,
    this.badgeCount = 0,
    this.crisp = false,
  });

  final String iconAsset;
  final String label;
  final Color badgeColor;
  final Color iconColor;
  final double tileSize;
  final double iconSize;
  final double tileWidth;
  final double labelGap;
  final double labelFontSize;
  final int labelMaxLines;
  final VoidCallback onTap;
  final int badgeCount;
  final bool crisp;

  @override
  Widget build(BuildContext context) {
    // Match check-in / prayer icon chip radius (10.ur).
    final chipRadius = BorderRadius.circular(crisp ? 10.0 : 10.ur);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cachePx = (iconSize * dpr).round().clamp(32, 128);

    final iconTile = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: chipRadius,
        color: badgeColor,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        width: tileSize,
        height: tileSize,
        child: Padding(
          // Equal inset from all four sides so the glyph is centered cleanly.
          padding: EdgeInsets.all((tileSize - iconSize) / 2),
          child: Image.asset(
            iconAsset,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            color: iconColor,
            colorBlendMode: BlendMode.srcIn,
            cacheWidth: cachePx,
            cacheHeight: cachePx,
          ),
        ),
      ),
    );

    Widget tileWithBadge(Widget child) {
      if (badgeCount <= 0) return child;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE04B4B),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tileWithBadge(iconTile),
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
        borderRadius: chipRadius,
        onTap: onTap,
        child: SizedBox(
          width: tileWidth.isFinite ? tileWidth : null,
          child: body,
        ),
      ),
    );
  }
}
