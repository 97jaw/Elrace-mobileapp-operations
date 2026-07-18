import 'dart:async';

import 'package:el_race/core/utils/app_orientations.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_loading_placeholders.dart';
import 'package:el_race/utils/custom_navigate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Skeleton layout while a glass-bar sub-screen mounts.
enum GlassSubScreenShell {
  search,
  list,
  chat,
  contacts,
}

/// Optional in-screen overlay skeleton (use inside a screen's body, not as a
/// full-route replacement). Route navigation shows [child] immediately.
class GlassRouteLoadingShell extends StatelessWidget {
  const GlassRouteLoadingShell({
    super.key,
    required this.shell,
    required this.child,
    this.showOverlay = false,
  });

  final GlassSubScreenShell shell;
  final Widget child;

  /// When true, stacks a shimmer over [child] (same layout chrome stays visible).
  final bool showOverlay;

  @override
  Widget build(BuildContext context) {
    if (!showOverlay) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned.fill(
          child: _GlassPlaceholderBody(shell: shell),
        ),
      ],
    );
  }
}

class _GlassPlaceholderBody extends StatelessWidget {
  const _GlassPlaceholderBody({required this.shell});

  final GlassSubScreenShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: switch (shell) {
        GlassSubScreenShell.search => _buildSearchPlaceholder(context),
        GlassSubScreenShell.chat => _buildChatPlaceholder(context),
        GlassSubScreenShell.list => GlassContactsListPlaceholder(
            padding: EdgeInsets.all(16.tw),
          ),
        GlassSubScreenShell.contacts => GlassContactsListPlaceholder(
            padding: EdgeInsets.all(16.tw),
          ),
      },
    );
  }

  Widget _buildSearchPlaceholder(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.tw, 16.th, 16.tw, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TmShimmerBox(
            width: double.infinity,
            height: 48,
            borderRadius: 24,
          ),
          SizedBox(height: 16.th),
          Row(
            children: List.generate(
              4,
              (i) => Padding(
                padding: EdgeInsets.only(right: 8.tw),
                child: TmShimmerBox(width: 72.tw, height: 32, borderRadius: 16),
              ),
            ),
          ),
          SizedBox(height: 20.th),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              separatorBuilder: (_, __) => SizedBox(height: 12.th),
              itemBuilder: (_, __) => const TmShimmerBox(
                width: double.infinity,
                height: 72,
                borderRadius: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPlaceholder(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 56.th;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: top + 100.th,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF161B54), Color(0xFF2A3568)],
            ),
          ),
          padding: EdgeInsets.fromLTRB(16.tw, top + 8.th, 16.tw, 12.th),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TmShimmerBox(width: 36.tw, height: 36, borderRadius: 18),
                  SizedBox(width: 12.tw),
                  TmShimmerBox(width: 120.tw, height: 18, borderRadius: 8),
                ],
              ),
              SizedBox(height: 14.th),
              const TmShimmerBox(
                width: double.infinity,
                height: 40,
                borderRadius: 20,
              ),
            ],
          ),
        ),
        Expanded(
          child: GlassContactsListPlaceholder(
            padding: EdgeInsets.fromLTRB(16.tw, 12.th, 16.tw, 0),
            itemCount: 8,
          ),
        ),
      ],
    );
  }
}

/// Reusable contacts / list row skeleton (call screen + route shells).
class GlassContactsListPlaceholder extends StatelessWidget {
  const GlassContactsListPlaceholder({
    super.key,
    this.padding,
    this.itemCount = 8,
  });

  final EdgeInsetsGeometry? padding;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding ?? EdgeInsets.all(16.tw),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: 12.th),
      itemBuilder: (_, __) => Container(
        height: 88.th,
        padding: EdgeInsets.all(12.tw),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Row(
          children: [
            TmShimmerBox(width: 48.tw, height: 48.tw, borderRadius: 24),
            SizedBox(width: 12.tw),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TmShimmerBox(width: double.infinity, height: 14.th),
                  SizedBox(height: 8.th),
                  TmShimmerBox(width: 120.tw, height: 10.th),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final Map<String, bool> _routeOpeningLocks = {};

/// Opens a sub-screen from the glass header with slide transition.
/// The destination screen is shown immediately; use in-screen skeletons for data.
Future<T?> openGlassSubScreen<T>(
  BuildContext context, {
  required Widget child,
  required String routeName,
  GlassSubScreenShell shell = GlassSubScreenShell.list,
  bool replace = false,
}) async {
  if (!SharedPref.isUserAuthenticated()) return null;

  final current = ModalRoute.of(context)?.settings.name;
  if (current == routeName) return null;

  if (_routeOpeningLocks[routeName] == true) return null;
  _routeOpeningLocks[routeName] = true;

  try {
    // Don't block the push on orientation unlock — run it in parallel.
    unawaited(AppOrientations.allowTabletRotation());

    final route = SlideRightPageRoute<T>(
      child: child,
      settings: RouteSettings(name: routeName),
    );

    if (replace) {
      return Navigator.pushReplacement(context, route);
    }
    return Navigator.push(context, route);
  } finally {
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      _routeOpeningLocks[routeName] = false;
    });
  }
}
