import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

enum ProjectsViewMode { dashboard, maps }

class ProjectsViewSwitchRow extends StatelessWidget {
  const ProjectsViewSwitchRow({
    super.key,
    required this.mode,
    required this.centerPhotoUrl,
    required this.centerFallbackName,
    required this.onDashboardTap,
    required this.onMapsTap,
    this.dashboardLabel,
    this.mapsLabel,
  });

  final ProjectsViewMode mode;
  final String centerPhotoUrl;
  final String centerFallbackName;
  final VoidCallback onDashboardTap;
  final VoidCallback onMapsTap;
  final String? dashboardLabel;
  final String? mapsLabel;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF1E2365);
    const inactiveBorder = Color(0xFF9CA3AF);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.tw, vertical: 4.th),
      child: Row(
        children: [
          _ModeButton(
            icon: Icons.dashboard_rounded,
            label: dashboardLabel ?? 'Dashboard',
            isActive: mode == ProjectsViewMode.dashboard,
            activeColor: activeColor,
            inactiveBorder: inactiveBorder,
            onTap: onDashboardTap,
          ),
          Expanded(
            child: Center(
              child: _CenterLogo(
                photoUrl: centerPhotoUrl,
                fallbackName: centerFallbackName,
              ),
            ),
          ),
          _ModeButton(
            icon: Icons.map_rounded,
            label: mapsLabel ?? 'Maps',
            isActive: mode == ProjectsViewMode.maps,
            activeColor: activeColor,
            inactiveBorder: inactiveBorder,
            onTap: onMapsTap,
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveBorder,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveBorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.tr),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.tw,
            height: 40.tw,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? activeColor : Colors.transparent,
              border: Border.all(
                color: isActive ? activeColor : inactiveBorder,
                width: 1.4,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: activeColor.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 20.tsp,
              color: isActive ? Colors.white : activeColor,
            ),
          ),
          SizedBox(height: 4.th),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10.tsp,
              fontWeight: FontWeight.w600,
              color: isActive ? activeColor : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterLogo extends StatelessWidget {
  const _CenterLogo({
    required this.photoUrl,
    required this.fallbackName,
  });

  final String photoUrl;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    const ringColor = Color(0xFF1E2365);
    final initials = _initials(fallbackName);

    Widget avatarChild;
    if (photoUrl.isNotEmpty) {
      avatarChild = ClipOval(
        child: Image.network(
          photoUrl,
          width: 56.tw,
          height: 56.tw,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _InitialsAvatar(initials: initials),
        ),
      );
    } else {
      avatarChild = _InitialsAvatar(initials: initials);
    }

    return Container(
      padding: EdgeInsets.all(3.tw),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor.withOpacity(0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: avatarChild,
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28.tr,
      backgroundColor: const Color(0xFF1E2365),
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize: 18.tsp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
