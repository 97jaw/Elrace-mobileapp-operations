import 'package:el_race/ui/chat/widgets/chat_sub_app_glass_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Glass logo bar + optional title row that sits **on the screen's own background**.
///
/// Do not use [ChatUnifiedHeaderBackdrop] here — apply a light transparent scrim
/// so the parent gradient/surface shows through (Project Management, Petty Cash, etc.).
class ContextualGlassChromeHeader extends StatelessWidget {
  const ContextualGlassChromeHeader({
    super.key,
    this.title,
    this.showBack = false,
    this.onBack,
    this.trailing = const [],
    this.bottom,
    this.tabsHeight,
    this.titleTrailing,
    this.onLightSurface = false,
    this.scrimColor,
    this.scrimTopOpacity,
    this.transparentGlassBar = false,
    this.logoOpacity,
  });

  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> trailing;
  final Widget? bottom;
  final double? tabsHeight;
  final Widget? titleTrailing;
  final bool onLightSurface;

  /// Override scrim tint; defaults to white on dark surfaces, black on light.
  final Color? scrimColor;

  /// Top scrim strength (0–1). Defaults: 0.16 dark surfaces, 0.10 light.
  final double? scrimTopOpacity;

  /// Transparent glass pill — parent gradient shows through the top-right bar.
  final bool transparentGlassBar;

  /// Logo opacity in the top-left (default 0.55 on dark surfaces, 1.0 on light).
  final double? logoOpacity;

  static double titleRowHeight = 48;

  static double extent(
    BuildContext context, {
    String? title,
    double bottomHeight = 0,
    bool showBack = false,
  }) {
    final titleH = (title != null && title.trim().isNotEmpty) || showBack
        ? titleRowHeight.h
        : 0.0;
    return SubAppGlassAppBar.extent(context) + titleH + bottomHeight;
  }

  static Widget homeTrailing({
    required VoidCallback onPressed,
    String tooltip = 'Home',
    Color iconColor = Colors.white,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(
        Icons.home_rounded,
        color: iconColor,
        size: 22.sp,
      ),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: 32.w,
        minHeight: 32.w,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabStripH = tabsHeight;
    final hasTitle = title != null && title!.trim().isNotEmpty;
    final showTitleRow = hasTitle || showBack || titleTrailing != null;
    final titleColor = onLightSurface ? const Color(0xFF1E2365) : Colors.white;
    final iconColor = titleColor;

    final chrome = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: SubAppGlassAppBar.extent(context),
          child: SubAppGlassAppBar(
            // Dark hubs: clear glass + light icons. Light hubs: soft frost + dark icons.
            transparentPill: transparentGlassBar && !onLightSurface,
            lightSurfaceTransparentPill:
                transparentGlassBar && onLightSurface,
            logoOpacity: logoOpacity ?? (onLightSurface ? 1.0 : 0.55),
          ),
        ),
        if (showTitleRow)
          SizedBox(
            height: titleRowHeight.h,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 4.h),
              child: Row(
                children: [
                  if (showBack)
                    IconButton(
                      onPressed: onBack ??
                          () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: iconColor,
                        size: 18.sp,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: 32.w,
                        minHeight: 32.w,
                      ),
                    ),
                  if (hasTitle)
                    Expanded(
                      child: Text(
                        title!,
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else if (showBack || titleTrailing != null)
                    const Spacer(),
                  if (titleTrailing != null) titleTrailing!,
                  if (trailing.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: trailing),
                ],
              ),
            ),
          ),
        if (bottom != null)
          tabStripH != null
              ? SizedBox(
                  height: tabStripH,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 6.h),
                    child: bottom!,
                  ),
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 2.h),
                  child: bottom!,
                ),
      ],
    );

    final tint = scrimColor ??
        (onLightSurface ? Colors.black : Colors.black);
    final topAlpha = transparentGlassBar
        ? 0.0
        : (scrimTopOpacity ?? (onLightSurface ? 0.10 : 0.16));

    if (transparentGlassBar) {
      return chrome;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint.withValues(alpha: topAlpha),
            tint.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: chrome,
    );
  }
}

/// Column shell: contextual glass header + body on a shared [background].
class ContextualGlassShell extends StatelessWidget {
  const ContextualGlassShell({
    super.key,
    required this.body,
    required this.background,
    this.title,
    this.showBack = true,
    this.onBack,
    this.trailing = const [],
    this.titleTrailing,
    this.headerBottom,
    this.onLightSurface = false,
    this.scrimColor,
    this.scrimTopOpacity,
  });

  final String? title;
  final Widget body;
  final Decoration background;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> trailing;
  final Widget? titleTrailing;
  final Widget? headerBottom;
  final bool onLightSurface;
  final Color? scrimColor;
  final double? scrimTopOpacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContextualGlassChromeHeader(
            title: title,
            showBack: showBack,
            onBack: onBack,
            trailing: trailing,
            titleTrailing: titleTrailing,
            bottom: headerBottom,
            onLightSurface: onLightSurface,
            scrimColor: scrimColor,
            scrimTopOpacity: scrimTopOpacity,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
