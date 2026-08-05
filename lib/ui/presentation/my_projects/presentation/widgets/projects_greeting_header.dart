import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';

import 'package:el_race/core/services/badge_refresh_service.dart';
import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Notification/notification_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/utils/custom_navigate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Greeting-style header (replaces [HeaderWidget] on Projects dashboard).
class ProjectsGreetingHeader extends StatefulWidget {
  const ProjectsGreetingHeader({super.key});

  @override
  State<ProjectsGreetingHeader> createState() => _ProjectsGreetingHeaderState();
}

class _ProjectsGreetingHeaderState extends State<ProjectsGreetingHeader> {
  int _notificationCount = 0;
  bool _openingNotifications = false;
  String _userName = '';
  String _imageData = '';

  @override
  void initState() {
    super.initState();
    _notificationCount = NotificationStorageService.memoryBadgeCount;
    NotificationStorageService.addCountListener(this, () {
      _loadNotificationCount();
    });
    // Resume badge refresh — shared server sync happens in ResumeCoordinator;
    // this just re-reads the warm local count.
    BadgeRefreshService.addListener(this, () {
      if (mounted) _loadNotificationCount();
    });
    _loadUser();
    _loadNotificationCount();
  }

  @override
  void dispose() {
    BadgeRefreshService.removeListener(this);
    NotificationStorageService.removeCountListener(this);
    super.dispose();
  }

  void _loadUser() {
    if (!SharedPref.isUserAuthenticated()) return;
    final data = SharedPref.getLoginData().result?.data;
    _userName = data?.name?.trim() ?? data?.emp_name?.trim() ?? 'User';
    _imageData = data?.image_url?.toString() ?? '';
  }

  Future<void> _loadNotificationCount() async {
    final count = await NotificationStorageService.getTotalCount();
    if (!mounted) return;
    setState(() => _notificationCount = count);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  Future<void> _openNotifications() async {
    if (!SharedPref.isUserAuthenticated() || _openingNotifications) return;
    _openingNotifications = true;
    try {
      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName == '/notifications') return;

      await Navigator.push(
        context,
        SlideRightPageRoute(
          child: const NotificationScreen(),
          settings: const RouteSettings(name: '/notifications'),
        ),
      );
      await _loadNotificationCount();
    } finally {
      _openingNotifications = false;
    }
  }

  Widget _profileAvatar() {
    const fallback = 'assets/png/profile_1.png';
    if (_imageData.isEmpty) {
      return CircleAvatar(
        radius: 24.tr,
        backgroundImage: const AssetImage(fallback),
      );
    }
    if (_imageData.startsWith('http')) {
      return CircleAvatar(
        radius: 24.tr,
        backgroundImage: NetworkImage(_imageData),
        onBackgroundImageError: (_, __) {},
      );
    }
    try {
      if (_imageData.length % 4 == 0) {
        return CircleAvatar(
          radius: 24.tr,
          backgroundImage: MemoryImage(base64Decode(_imageData)),
        );
      }
    } catch (_) {}
    return CircleAvatar(
      radius: 24.tr,
      backgroundImage: const AssetImage(fallback),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMMM, yyyy').format(DateTime.now());
    final firstName = _userName.split(' ').first;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.tw, 8.th, 16.tw, 12.th),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 20.tsp,
                      color: ProjectsDashboardTheme.white,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(text: '${_greeting()} '),
                      TextSpan(
                        text: firstName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 2.th),
                Text(
                  dateLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    color: ProjectsDashboardTheme.greyPanel.withValues(
                      alpha: 0.85,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openNotifications,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44.tw,
                  height: 44.tw,
                  decoration: BoxDecoration(
                    color: ProjectsDashboardTheme.greyDark.withValues(
                      alpha: 0.65,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ProjectsDashboardTheme.maroon.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 26.tsp,
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
                if (_notificationCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: _NotificationCountBadge(count: _notificationCount),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10.tw),
          _profileAvatar(),
        ],
      ),
    );
  }
}

class _NotificationCountBadge extends StatelessWidget {
  const _NotificationCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    final wide = label.length > 1;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 6.tw : 0,
        vertical: 3.th,
      ),
      constraints: BoxConstraints(
        minWidth: 20.tw,
        minHeight: 20.tw,
      ),
      decoration: BoxDecoration(
        gradient: ProjectsDashboardTheme.maroonAccentGradient,
        shape: BoxShape.circle,
        border: Border.all(
          color: ProjectsDashboardTheme.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ProjectsDashboardTheme.maroon.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: ProjectsDashboardTheme.white,
          fontSize: 10.tsp,
          fontWeight: FontWeight.w800,
          height: 1,
          letterSpacing: -0.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
