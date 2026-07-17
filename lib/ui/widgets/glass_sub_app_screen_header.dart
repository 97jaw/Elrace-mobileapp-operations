import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/chat/widgets/chat_sub_app_glass_bar.dart';
import 'package:el_race/ui/chat/widgets/chat_unified_header_backdrop.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:el_race/ui/widgets/global_search_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared glass + navy header for sub-screens opened from the home glass bar.
class GlassSubAppScreenHeader extends StatelessWidget {
  const GlassSubAppScreenHeader({
    super.key,
    this.title = '',
    this.titleIcon,
    this.trailing = const [],
    this.bottom,
    this.showTitleRow = true,
    this.tabsHeight,
    this.roundedBottom = true,
  });

  final String title;
  final IconData? titleIcon;
  final List<Widget> trailing;
  final Widget? bottom;

  /// When false, only the top glass bar + optional [bottom] tabs are shown.
  final bool showTitleRow;

  /// Height reserved for [bottom] tab strip (defaults to [headerTabsHeight]).
  final double? tabsHeight;

  /// Rounded bottom edge on the header (off when body uses [mergedGradient]).
  final bool roundedBottom;

  static double titleRowHeight = 52;
  static double headerTabsHeight = 80;

  static double extent(
    BuildContext context, {
    double bottomHeight = 0,
    bool showTitleRow = true,
  }) {
    final titleH = showTitleRow ? titleRowHeight.th : 0.0;
    return SubAppGlassAppBar.extent(context) + titleH + bottomHeight;
  }

  @override
  Widget build(BuildContext context) {
    final tabStripH = tabsHeight ?? headerTabsHeight.th;
    final bottomHeight = bottom != null ? tabStripH : 0.0;

    final header = SizedBox(
      height: extent(
        context,
        bottomHeight: bottomHeight,
        showTitleRow: showTitleRow,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ChatUnifiedHeaderBackdrop.layer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: SubAppGlassAppBar.extent(context),
                child: const SubAppGlassAppBar(),
              ),
              if (showTitleRow)
                SizedBox(
                  height: titleRowHeight.th,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.tw, 2.th, 8.tw, 4.th),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              HomeNavigation.handleSystemBack(context),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18.tsp,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: 32.tw,
                            minHeight: 32.tw,
                          ),
                        ),
                        if (titleIcon != null) ...[
                          Icon(
                            titleIcon,
                            color: Colors.white,
                            size: 20.tsp,
                          ),
                          SizedBox(width: 6.tw),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 16.tsp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (trailing.isNotEmpty)
                          Flexible(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: trailing,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (bottom != null)
                SizedBox(
                  height: tabStripH,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(6.tw, 4.th, 6.tw, 2.th),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: bottom!,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (!roundedBottom || bottom != null) return header;
    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.tr)),
      child: header,
    );
  }
}

/// Icon-only glass chip for compact category filters (no label).
class GlassHeaderIconChip extends StatelessWidget {
  const GlassHeaderIconChip({
    super.key,
    required this.icon,
    required this.color,
    required this.isSelected,
    this.badgeCount = 0,
    this.showDot = false,
    this.onTap,
    this.size = 46,
    this.faded = false,
  });

  final IconData icon;
  final Color color;
  final bool isSelected;
  final int badgeCount;
  final bool showDot;
  final VoidCallback? onTap;
  final double size;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final showCount = badgeCount > 0;
    final chipColor = faded ? color.withValues(alpha: 0.55) : color;
    final iconColor = faded
        ? Colors.white.withValues(alpha: 0.82)
        : (isSelected ? Colors.white : color);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size.tw,
            height: size.tw,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.tr),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: faded ? 0.55 : 1.0)
                    : Colors.white.withValues(alpha: 0.45),
                width: 1.1,
              ),
              boxShadow: isSelected && !faded
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Container(
              margin: const EdgeInsets.all(1.2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.tr),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected
                      ? [
                          chipColor,
                          chipColor.withValues(alpha: faded ? 0.45 : 0.82),
                        ]
                      : [
                          Colors.white.withValues(alpha: faded ? 0.14 : 0.22),
                          Colors.white.withValues(alpha: faded ? 0.06 : 0.08),
                        ],
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 22.tsp,
                  color: iconColor,
                ),
              ),
            ),
          ),
          if (showCount)
            Positioned(
              top: -2.th,
              right: -2.tw,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 5.tw, vertical: 2.th),
                constraints: BoxConstraints(minWidth: 16.tw),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(10.tr),
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.tsp,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            )
          else if (showDot)
            Positioned(
              top: 2.th,
              right: 2.tw,
              child: Container(
                width: 9.tw,
                height: 9.tw,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Category / settings tab in the glass header (icon tile + optional badge + label).
class GlassHeaderBadgeTab extends StatelessWidget {
  const GlassHeaderBadgeTab({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    this.badgeCount = 0,
    this.showDot = false,
    this.onTap,
    this.tileWidth = 68,
  });

  final Widget icon;
  final String label;
  final bool isSelected;
  final int badgeCount;
  final bool showDot;
  final VoidCallback? onTap;
  final double tileWidth;

  @override
  Widget build(BuildContext context) {
    final showCount = badgeCount > 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: tileWidth.tw,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: tileWidth.tw,
                  height: 56.th,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.tr),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      width: 1.1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Container(
                    margin: EdgeInsets.all(1.2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.tr),
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                    child: Center(child: icon),
                  ),
                ),
                if (showCount)
                  Positioned(
                    top: 2.th,
                    right: 2.tw,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 5.tw,
                        vertical: 2.th,
                      ),
                      constraints: BoxConstraints(minWidth: 17.tw),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(10.tr),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5.tsp,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  )
                else if (showDot)
                  Positioned(
                    top: 4.th,
                    right: 4.tw,
                    child: Container(
                      width: 9.tw,
                      height: 9.tw,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 3.th),
            SizedBox(
              width: tileWidth.tw,
              height: 11.th,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 9.tsp,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? const Color(0xFF141B3A)
                        : Colors.white.withValues(alpha: 0.92),
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Body below the glass header — optional drag handle or navy→white fade merge.
class GlassSubAppContentSheet extends StatelessWidget {
  const GlassSubAppContentSheet({
    super.key,
    required this.child,
    this.showHandle = true,
    this.mergedGradient = false,
    this.backgroundColor = Colors.white,
  });

  final Widget child;
  final bool showHandle;

  /// Fades from header navy into white (no hard sheet edge).
  final bool mergedGradient;

  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (mergedGradient) {
      return Expanded(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                GlobalSearchTheme.screenBase,
                Color(0xFF2A3568),
                Color(0xFFDCE1EE),
                Colors.white,
              ],
              stops: [0.0, 0.05, 0.12, 0.2],
            ),
          ),
          child: child,
        ),
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHandle)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.only(top: 9, bottom: 8),
              alignment: Alignment.center,
              child: Container(
                width: 70,
                height: 4,
                decoration: BoxDecoration(
                  color: Color(0xFFE5E5E5),
                  borderRadius: BorderRadius.all(Radius.circular(99)),
                ),
              ),
            ),
          Expanded(
            child: Container(
              color: backgroundColor,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Header action button (settings, etc.) styled for glass chrome.
class GlassSubAppHeaderIconButton extends StatelessWidget {
  const GlassSubAppHeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 22.tsp),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: 36.tw, minHeight: 36.tw),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
