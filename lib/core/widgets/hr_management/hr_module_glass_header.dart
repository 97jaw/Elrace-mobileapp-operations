import 'package:el_race/ui/chat/widgets/chat_sub_app_glass_bar.dart';
import 'package:el_race/ui/chat/widgets/chat_unified_header_backdrop.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Accent tints for HR glass headers — aligned with hub service card colors.
abstract final class HrModuleHeaderTints {
  static const Color hub = Color(0xFF3F5680);
  static const Color requests = Color(0xFF3F5680);
  static const Color recruitment = Color(0xFF7D5865);
  static const Color performance = Color(0xFF6A707A);
  static const Color payslip = Color(0xFF5B5680);
  static const Color circulars = Color(0xFF457C62);
}

/// Glass logo bar + optional title row for HR Management hub and service screens.
class HrModuleGlassHeader extends StatelessWidget {
  const HrModuleGlassHeader({
    super.key,
    this.title,
    this.showBack = true,
    this.onBack,
    this.trailing = const [],
    this.bottom,
    this.tabsHeight,
    this.includeBackdrop = true,
    this.accentTint,
    this.titleTrailing,
  });

  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> trailing;
  final Widget? bottom;
  final double? tabsHeight;
  final bool includeBackdrop;
  final Color? accentTint;
  final Widget? titleTrailing;

  static double titleRowHeight = 48;

  static double extent(
    BuildContext context, {
    String? title,
    double bottomHeight = 0,
  }) {
    final titleH = (title != null && title.trim().isNotEmpty)
        ? titleRowHeight.h
        : 0.0;
    return SubAppGlassAppBar.extent(context) + titleH + bottomHeight;
  }

  @override
  Widget build(BuildContext context) {
    final tabStripH = tabsHeight ?? 0.0;
    final bottomHeight = bottom != null ? tabStripH : 0.0;
    final hasTitle = title != null && title!.trim().isNotEmpty;

    final chrome = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: SubAppGlassAppBar.extent(context),
          child: const SubAppGlassAppBar(),
        ),
        if (hasTitle)
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
                        color: Colors.white,
                        size: 18.sp,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: 32.w,
                        minHeight: 32.w,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      title!,
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (titleTrailing != null) titleTrailing!,
                  if (trailing.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: trailing),
                ],
              ),
            ),
          ),
        if (bottom != null)
          SizedBox(
            height: bottomHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8.w, 0, 8.w, 6.h),
              child: bottom!,
            ),
          ),
      ],
    );

    if (!includeBackdrop) return chrome;

    return SizedBox(
      height: extent(
        context,
        title: title,
        bottomHeight: bottomHeight,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ChatUnifiedHeaderBackdrop.layer(accentTint: accentTint),
          chrome,
        ],
      ),
    );
  }
}

/// Full-screen HR shell: glass header on top, module body below.
class HrModuleGlassShell extends StatelessWidget {
  const HrModuleGlassShell({
    super.key,
    required this.title,
    required this.body,
    this.showBack = true,
    this.onBack,
    this.trailing = const [],
    this.headerBottom,
    this.background,
    this.accentTint,
  });

  final String title;
  final Widget body;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> trailing;
  final Widget? headerBottom;
  final Decoration? background;
  final Color? accentTint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: background ??
          const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE8EBF0),
                Color(0xFFF3F5F9),
                Color(0xFFFFFFFF),
              ],
              stops: [0.0, 0.42, 1.0],
            ),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HrModuleGlassHeader(
            title: title,
            showBack: showBack,
            onBack: onBack ?? () => HomeNavigation.handleSystemBack(context),
            trailing: trailing,
            bottom: headerBottom,
            accentTint: accentTint ?? HrModuleHeaderTints.hub,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
