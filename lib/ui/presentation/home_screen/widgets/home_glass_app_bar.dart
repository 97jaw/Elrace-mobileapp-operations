import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';
import 'dart:async';

import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/core/services/approval_count_service.dart';
import 'package:el_race/core/services/approval_viewed_service.dart';
import 'package:el_race/core/services/badge_refresh_service.dart';
import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_widgets/profile_bottom_sheet.dart';
import 'package:el_race/ui/chat/chat_ui.dart';
import 'package:el_race/ui/presentation/Email Approval/Approval.dart';
import 'package:el_race/ui/presentation/Notification/notification_screen.dart';
import 'package:el_race/ui/presentation/camera/camera_selection_screen.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/signin/sign_in_screen.dart';
import 'package:el_race/ui/navigation/glass_route_navigation.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/glass_tap_icon.dart';
import 'package:el_race/ui/widgets/global_search_screen.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

class HomeGlassAppBar extends StatefulWidget {
  const HomeGlassAppBar({
    super.key,
    this.hideLeadingActionIcons = false,
    this.omitOuterPadding = false,
    this.compactTrailing = false,
    this.transparentPill = false,
    this.lightSurfaceTransparentPill = false,
    this.expandProgress = 0,
    this.mergedMode = false,
  });

  /// When true, hides chat / call / camera (for chat and other sub-app screens).
  final bool hideLeadingActionIcons;

  /// When true, parent supplies horizontal inset (e.g. logo + bar row on chat).
  final bool omitOuterPadding;

  /// Tight pill (~half header): smaller icons and even gaps (chat sub-screens).
  final bool compactTrailing;

  /// No white frost fill — parent gradient shows through (Petty Cash, etc.).
  final bool transparentPill;

  /// Soft frosted pill on light screens — slightly see-through, dark icons.
  final bool lightSurfaceTransparentPill;

  /// 0 = collapsed home; 1 = widgets panel fully expanded (logo left, comms out).
  final double expandProgress;

  /// Flat toolbar row inside the merged widgets panel (no glass pill).
  final bool mergedMode;

  @override
  State<HomeGlassAppBar> createState() => _HomeGlassAppBarState();
}

class _HomeGlassAppBarState extends State<HomeGlassAppBar> {
  String _imageBase64 = '';
  // Seed from warm cache so sub-screens (Waiting / Notifications) don't flash 0.
  int _notificationCount = NotificationStorageService.memoryBadgeCount;
  int _approvalCount = ApprovalCountService.cachedCountOrZero;
  bool _profileOpening = false;
  Timer? _notificationPollTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadNotificationCountLocal();
    _loadApprovalCount();
    ApprovalViewedService.addListener(this, () {
      if (mounted) _loadApprovalCount();
    });
    ApprovalCountService.addListener(this, () {
      if (mounted) _loadApprovalCount();
    });
    NotificationStorageService.addCountListener(this, () {
      if (mounted) _loadNotificationCountLocal();
    });
    // Resume badge refresh: ResumeCoordinator runs one shared server sync,
    // then this callback re-reads the warm local/cached values (no duplicate
    // API calls per header widget anymore).
    BadgeRefreshService.addListener(this, () {
      if (!mounted) return;
      _loadNotificationCountLocal();
      _loadApprovalCount();
    });

    // Poll notification counter every 5 seconds (iOS often misses FCM Dart wake).
    _notificationPollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadNotificationCount(),
    );
  }

  @override
  void dispose() {
    _notificationPollTimer?.cancel();
    BadgeRefreshService.removeListener(this);
    ApprovalViewedService.removeListener(this);
    ApprovalCountService.removeListener(this);
    NotificationStorageService.removeCountListener(this);
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (!SharedPref.isUserAuthenticated()) return;
    final data = SharedPref.getLoginData();
    if (mounted) {
      setState(() => _imageBase64 = data.result?.data?.image_url ?? '');
    }
  }

  Future<void> _loadNotificationCount() async {
    // Sync from Odoo so iOS badge updates even when FCM did not wake Dart.
    final count = await NotificationStorageService.syncBadgeFromServer();
    if (mounted) setState(() => _notificationCount = count);
  }

  Future<void> _loadNotificationCountLocal() async {
    final count = await NotificationStorageService.getBadgeCount();
    if (mounted) setState(() => _notificationCount = count);
  }

  Future<void> _loadApprovalCount() async {
    final count = await ApprovalCountService.getTotalApprovalCount();
    if (mounted) setState(() => _approvalCount = count);
  }

  bool _isValidBase64(String str) {
    try {
      if (str.trim().isEmpty || str.length % 4 != 0) return false;
      base64Decode(str);
      return true;
    } catch (_) {
      return false;
    }
  }

  Widget _profileImage(String imageData) {
    if (imageData.isEmpty) {
      return Image.asset('assets/png/profile_1.png', fit: BoxFit.cover);
    }
    if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
      return Image.network(
        imageData,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Image.asset('assets/png/profile_1.png', fit: BoxFit.cover),
      );
    }
    if (_isValidBase64(imageData)) {
      try {
        return Image.memory(base64Decode(imageData), fit: BoxFit.cover);
      } catch (_) {}
    }
    return Image.asset('assets/png/profile_1.png', fit: BoxFit.cover);
  }

  Future<void> _openChat() async {
    await openGlassSubScreen(
      context,
      routeName: '/chat_list',
      shell: GlassSubScreenShell.chat,
      child: const ChatShellScreen(),
    );
  }

  void _openCall() {
    HomeBloc.get(context).add(const ChangeCurrentIndex(index: 0));
  }

  Future<void> _openCamera() async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => const CameraSelectionScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _openProfile() {
    if (!SharedPref.isUserAuthenticated()) {
      Util.pushPage(const SignInScreen(), context);
      return;
    }
    if (_profileOpening) return;
    setState(() => _profileOpening = true);
    ProfileBottomSheet.show(context).whenComplete(() {
      if (mounted) setState(() => _profileOpening = false);
    });
  }

  List<Widget> _compactTrailingActions({
    required double iconSize,
    required double iconGlyph,
    required double gap,
    required double profileSize,
    bool lightIcons = false,
  }) {
    return [
      _GlassWellIcon(
        icon: Icons.search_rounded,
        size: iconSize,
        iconSize: iconGlyph,
        lightIcons: lightIcons,
        onTap: () {
          openGlassSubScreen(
            context,
            routeName: '/global_search',
            shell: GlassSubScreenShell.search,
            child: const GlobalSearchScreen(),
          );
        },
      ),
      SizedBox(width: gap),
      _GlassWellBadgeIcon(
        icon: Icons.assignment_outlined,
        count: _approvalCount,
        size: iconSize,
        iconSize: iconGlyph,
        lightIcons: lightIcons,
        onTap: () async {
          final name = ModalRoute.of(context)?.settings.name;
          await openGlassSubScreen(
            context,
            routeName: '/approvals',
            shell: GlassSubScreenShell.list,
            replace: name == '/notifications',
            child: const ApprovalsScreen(),
          );
          await _loadApprovalCount();
        },
      ),
      SizedBox(width: gap),
      _GlassWellBadgeIcon(
        icon: Icons.notifications_outlined,
        count: _notificationCount,
        size: iconSize,
        iconSize: iconGlyph,
        lightIcons: lightIcons,
        onTap: () async {
          final name = ModalRoute.of(context)?.settings.name;
          await openGlassSubScreen(
            context,
            routeName: '/notifications',
            shell: GlassSubScreenShell.list,
            replace: name == '/approvals',
            child: const NotificationScreen(),
          );
          await _loadNotificationCount();
        },
      ),
      SizedBox(width: gap),
      GlassTapIcon(
        onTap: _openProfile,
        child: Container(
          width: profileSize,
          height: profileSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.8,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4A90D9), Color(0xFF2563EB)],
            ),
          ),
          child: _profileOpening
              ? Center(
                  child: SizedBox(
                    width: profileSize * 0.45,
                    height: profileSize * 0.45,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : ClipOval(child: _profileImage(_imageBase64)),
        ),
      ),
    ];
  }

  Widget _leadingLogo(double opacity) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: EdgeInsets.only(right: 8.tw),
        child: Image.asset(
          'assets/gif/el-race-logo.gif',
          height: 36.th,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _mergedToolbar({
    required double iconSize,
    required double iconGlyph,
    required double profileSize,
    required double gap,
    required double logoHeight,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.tw, 4.th, 16.tw, 8.th),
      child: Row(
        children: [
          Image.asset(
            'assets/gif/el-race-logo.gif',
            height: logoHeight,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          _GlassWellIcon(
            icon: Icons.search_rounded,
            size: iconSize,
            iconSize: iconGlyph,
            onTap: () {
              openGlassSubScreen(
                context,
                routeName: '/global_search',
                shell: GlassSubScreenShell.search,
                child: const GlobalSearchScreen(),
              );
            },
          ),
          SizedBox(width: gap),
          _GlassWellBadgeIcon(
            icon: Icons.assignment_outlined,
            count: _approvalCount,
            size: iconSize,
            iconSize: iconGlyph,
            onTap: () async {
              final name = ModalRoute.of(context)?.settings.name;
              await openGlassSubScreen(
                context,
                routeName: '/approvals',
                shell: GlassSubScreenShell.list,
                replace: name == '/notifications',
                child: const ApprovalsScreen(),
              );
              await _loadApprovalCount();
            },
          ),
          SizedBox(width: gap),
          _GlassWellBadgeIcon(
            icon: Icons.notifications_outlined,
            count: _notificationCount,
            size: iconSize,
            iconSize: iconGlyph,
            onTap: () async {
              final name = ModalRoute.of(context)?.settings.name;
              await openGlassSubScreen(
                context,
                routeName: '/notifications',
                shell: GlassSubScreenShell.list,
                replace: name == '/approvals',
                child: const NotificationScreen(),
              );
              await _loadNotificationCount();
            },
          ),
          SizedBox(width: gap),
          GlassTapIcon(
            onTap: _openProfile,
            child: Container(
              width: profileSize,
              height: profileSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.95),
                  width: 2,
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4A90D9), Color(0xFF2563EB)],
                ),
              ),
              child: _profileOpening
                  ? Center(
                      child: SizedBox(
                        width: profileSize * 0.45,
                        height: profileSize * 0.45,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : ClipOval(child: _profileImage(_imageBase64)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barRow({
    required bool compact,
    required double expand,
    required bool showComms,
    required bool showLogo,
    required double iconSize,
    required double iconGlyph,
    required double gap,
    required double profileSize,
    required double hPad,
    required double vPad,
  }) {
    final lightIcons = widget.transparentPill;
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment:
          compact ? MainAxisAlignment.spaceEvenly : MainAxisAlignment.start,
      children: [
        if (showLogo) _leadingLogo(1),
        if (showComms) ...[
          Expanded(
            flex: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _GlassWellIcon(
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: _openChat,
                  size: iconSize,
                  iconSize: iconGlyph,
                  lightIcons: lightIcons,
                ),
                _GlassWellIcon(
                  icon: Icons.phone_rounded,
                  onTap: _openCall,
                  size: iconSize,
                  iconSize: iconGlyph,
                  lightIcons: lightIcons,
                ),
                _GlassWellIcon(
                  icon: Icons.photo_camera_outlined,
                  onTap: _openCamera,
                  size: iconSize,
                  iconSize: iconGlyph,
                  lightIcons: lightIcons,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.tw),
            child: _BarDivider(),
          ),
        ],
        if (compact && widget.hideLeadingActionIcons)
          ..._compactTrailingActions(
            iconSize: iconSize,
            iconGlyph: iconGlyph,
            gap: gap,
            profileSize: profileSize,
            lightIcons: lightIcons,
          )
        else
          Expanded(
            flex: widget.hideLeadingActionIcons || !showComms ? 10 : 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _GlassWellIcon(
                  icon: Icons.search_rounded,
                  size: iconSize,
                  iconSize: iconGlyph,
                  lightIcons: lightIcons,
                  onTap: () {
                    openGlassSubScreen(
                      context,
                      routeName: '/global_search',
                      shell: GlassSubScreenShell.search,
                      child: const GlobalSearchScreen(),
                    );
                  },
                ),
                _GlassWellBadgeIcon(
                  icon: Icons.assignment_outlined,
                  count: _approvalCount,
                  size: iconSize,
                  iconSize: iconGlyph,
                  lightIcons: lightIcons,
                  onTap: () async {
                    final name = ModalRoute.of(context)?.settings.name;
                    await openGlassSubScreen(
                      context,
                      routeName: '/approvals',
                      shell: GlassSubScreenShell.list,
                      replace: name == '/notifications',
                      child: const ApprovalsScreen(),
                    );
                    await _loadApprovalCount();
                  },
                ),
                _GlassWellBadgeIcon(
                  icon: Icons.notifications_outlined,
                  count: _notificationCount,
                  size: iconSize,
                  iconSize: iconGlyph,
                  lightIcons: lightIcons,
                  onTap: () async {
                    final name = ModalRoute.of(context)?.settings.name;
                    await openGlassSubScreen(
                      context,
                      routeName: '/notifications',
                      shell: GlassSubScreenShell.list,
                      replace: name == '/approvals',
                      child: const NotificationScreen(),
                    );
                    await _loadNotificationCount();
                  },
                ),
              ],
            ),
          ),
        if (!compact) ...[
          SizedBox(width: gap),
          GlassTapIcon(
            onTap: _openProfile,
            child: Container(
              width: profileSize,
              height: profileSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.95),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4A90D9), Color(0xFF2563EB)],
                ),
              ),
              child: _profileOpening
                  ? Center(
                      child: SizedBox(
                        width: profileSize * 0.45,
                        height: profileSize * 0.45,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : ClipOval(child: _profileImage(_imageBase64)),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compactTrailing;
    final iconSize = compact ? 34.tw : 38.tw;
    final iconGlyph = compact ? 18.tsp : 20.tsp;
    final profileSize = compact ? 32.tw : 36.tw;
    final hPad = compact ? 8.tw : 10.tw;
    final vPad = compact ? 6.th : 7.th;
    final gap = compact ? 7.tw : 6.tw;

    if (widget.mergedMode) {
      return _mergedToolbar(
        iconSize: 44.tw,
        iconGlyph: 22.tsp,
        profileSize: 40.tw,
        gap: 8.tw,
        logoHeight: 46.th,
      );
    }

    final expand = widget.expandProgress.clamp(0.0, 1.0);
    // Mutually exclusive — avoids Row overflow during transition.
    final showComms = !widget.hideLeadingActionIcons && expand < 0.40;
    final showLogo = expand >= 0.68;

    final lightSoftPill = widget.lightSurfaceTransparentPill;
    final bar = widget.transparentPill
        ? Container(
            padding: EdgeInsets.fromLTRB(
              hPad,
              compact ? 7.th : vPad,
              hPad,
              vPad,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withValues(alpha: 0.14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: _barRow(
              compact: compact,
              expand: expand,
              showComms: showComms,
              showLogo: showLogo,
              iconSize: iconSize,
              iconGlyph: iconGlyph,
              gap: gap,
              profileSize: profileSize,
              hPad: hPad,
              vPad: vPad,
            ),
          )
        : ClipRRect(
        borderRadius: BorderRadius.circular(999),
        // Compact sub-app pills must not clip red badges on waiting/bell icons.
        clipBehavior: Clip.none,
        child: AdaptiveGlassLayer(
          borderRadius: BorderRadius.circular(999),
          sigma: lightSoftPill ? 18 : 25,
          fallbackColor: Colors.white.withValues(
            alpha: lightSoftPill ? 0.42 : 0.78,
          ),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              hPad,
              compact ? 7.th : vPad,
              hPad,
              vPad,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: lightSoftPill ? 0.45 : 0.72),
                  Colors.white.withValues(alpha: lightSoftPill ? 0.28 : 0.48),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: lightSoftPill ? 0.55 : 0.90,
                ),
                width: lightSoftPill ? 1 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: lightSoftPill ? 0.04 : 0.08,
                  ),
                  blurRadius: lightSoftPill ? 12 : 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _barRow(
              compact: compact,
              expand: expand,
              showComms: showComms,
              showLogo: showLogo,
              iconSize: iconSize,
              iconGlyph: iconGlyph,
              gap: gap,
              profileSize: profileSize,
              hPad: hPad,
              vPad: vPad,
            ),
          ),
        ),
      );

    if (widget.omitOuterPadding) return bar;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.tw),
      child: bar,
    );
  }
}

class _BarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22.th,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _GlassWellIcon extends StatelessWidget {
  const _GlassWellIcon({
    required this.icon,
    required this.onTap,
    this.size,
    this.iconSize,
    this.lightIcons = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double? size;
  final double? iconSize;
  final bool lightIcons;

  @override
  Widget build(BuildContext context) {
    final well = size ?? 38.tw;
    final glyph = iconSize ?? 20.tsp;
    return GlassTapIcon(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: well,
          height: well,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lightIcons
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.42),
            border: Border.all(
              color: lightIcons
                  ? Colors.white.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.80),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: glyph,
            color: lightIcons
                ? Colors.white
                : HomeGlassTheme.textPrimary.withValues(alpha: 0.88),
          ),
        ),
      ),
    );
  }
}

class _GlassWellBadgeIcon extends StatelessWidget {
  const _GlassWellBadgeIcon({
    required this.icon,
    required this.count,
    required this.onTap,
    this.size,
    this.iconSize,
    this.lightIcons = false,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final double? size;
  final double? iconSize;
  final bool lightIcons;

  @override
  Widget build(BuildContext context) {
    final well = size ?? 38.tw;
    final glyph = iconSize ?? 20.tsp;
    return GlassTapIcon(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: well,
          height: well,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lightIcons
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.42),
            border: Border.all(
              color: lightIcons
                  ? Colors.white.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.80),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: glyph,
                color: lightIcons
                    ? Colors.white
                    : HomeGlassTheme.textPrimary.withValues(alpha: 0.88),
              ),
              if (count > 0)
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: count > 9 ? 4.tw : 0,
                      vertical: 2.th,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16.tw,
                      minHeight: 16.tw,
                    ),
                    decoration: BoxDecoration(
                      color: HomeGlassTheme.accentRed,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: HomeGlassTheme.accentRed
                              .withValues(alpha: 0.35),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.tsp,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
