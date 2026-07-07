import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/hr_management/routing/hr_route_names.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Hub palette — service tile styling.
abstract final class _HubPalette {
  static const Color navy = Color(0xFF161B54);
}

/// First screen inside HR Management — pick a service (hub pattern).
class HrManagementHubScreen extends ConsumerWidget {
  const HrManagementHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(hrEffectiveViewProvider);

    return HrModuleGlassShell(
      title: 'HR Management',
      accentTint: HrModuleHeaderTints.hub,
      trailing: kDebugMode
          ? [
              _HubDevViewMenu(
                current: view,
                onSelect: (v) => ref
                    .read(hrDevViewOverrideProvider.notifier)
                    .setOverride(v),
                onClear: () => ref
                    .read(hrDevViewOverrideProvider.notifier)
                    .setOverride(null),
              ),
            ]
          : const [],
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            HrModuleLayout.screenPaddingH.w,
            10.h,
            HrModuleLayout.screenPaddingH.w,
            8.h,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                view == HrEffectiveView.employee
                    ? 'Your workplace services — simple, secure, in one hub.'
                    : 'Lead your team with clarity — built for managers and HR.',
                style: HrModuleTypography.body().copyWith(
                  fontSize: 12.5.sp,
                  height: 1.35,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 10.h),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _HubServiceTile(
                        icon: Icons.folder_shared_outlined,
                        title: 'HR requests',
                        subtitle:
                            'My requests, team queue, new leave & asset requests',
                        bgGradient: const [
                          Color(0xFF283A5C),
                          Color(0xFF344864),
                          Color(0xFF3F5680),
                        ],
                        titleGradient: const [
                          Color(0xFFB8C4FF),
                          Color(0xFFFFFFFF),
                          Color(0xFFE8ECFF),
                        ],
                        onTap: () => Navigator.of(context)
                            .pushNamed(HrRouteNames.requests),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Expanded(
                      child: _HubServiceTile(
                        icon: Icons.work_outline_rounded,
                        title: 'Recruitment',
                        subtitle: view == HrEffectiveView.employee
                            ? 'Open positions and employee referrals'
                            : 'Requisitions, candidates, offers, referrals',
                        bgGradient: const [
                          Color(0xFF5A3D48),
                          Color(0xFF6B4A56),
                          Color(0xFF7D5865),
                        ],
                        titleGradient: const [
                          Color(0xFFFFD4DC),
                          Color(0xFFFFFFFF),
                          Color(0xFFF5B8C4),
                        ],
                        onTap: () => Navigator.of(context)
                            .pushNamed(HrRouteNames.recruitment),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Expanded(
                      child: _HubServiceTile(
                        icon: Icons.fact_check_outlined,
                        title: 'Performance evaluation',
                        subtitle: view == HrEffectiveView.employee
                            ? 'Personal competencies and scores'
                            : 'Evaluations, status, and HR fields',
                        bgGradient: const [
                          Color(0xFF525862),
                          Color(0xFF5E646E),
                          Color(0xFF6A707A),
                        ],
                        titleGradient: const [
                          Color(0xFFE2E4EA),
                          Color(0xFFFFFFFF),
                          Color(0xFFC8CDD9),
                        ],
                        onTap: () => Navigator.of(context)
                            .pushNamed(HrRouteNames.performance),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Expanded(
                      child: _HubServiceTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'Payslips',
                        subtitle: view == HrEffectiveView.employee
                            ? 'View, filter, and download PDF'
                            : 'Pending queue and full list',
                        bgGradient: const [
                          Color(0xFF454066),
                          Color(0xFF504B74),
                          Color(0xFF5B5680),
                        ],
                        titleGradient: const [
                          Color(0xFFD4C4FF),
                          Color(0xFFFFFFFF),
                          Color(0xFFB8A8E8),
                        ],
                        onTap: () => Navigator.of(context)
                            .pushNamed(HrRouteNames.payslips),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Expanded(
                      child: _HubServiceTile(
                        icon: Icons.campaign_outlined,
                        title: 'Circulars & announcements',
                        subtitle:
                            'Official company circulars and HR announcements',
                        bgGradient: const [
                          Color(0xFF2F5A48),
                          Color(0xFF3A6B55),
                          Color(0xFF457C62),
                        ],
                        titleGradient: const [
                          Color(0xFFD4EBE0),
                          Color(0xFFFFFFFF),
                          Color(0xFFB8DFD0),
                        ],
                        onTap: () => Navigator.of(context)
                            .pushNamed(HrRouteNames.circularAnnouncements),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubDevViewMenu extends StatelessWidget {
  const _HubDevViewMenu({
    required this.current,
    required this.onSelect,
    required this.onClear,
  });

  final HrEffectiveView current;
  final void Function(HrEffectiveView?) onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.tune_rounded,
        color: Colors.white.withValues(alpha: 0.95),
        size: 22.sp,
      ),
      color: HrModuleColors.surface,
      onSelected: (id) {
        switch (id) {
          case 'emp':
            onSelect(HrEffectiveView.employee);
            break;
          case 'mgr':
            onSelect(HrEffectiveView.manager);
            break;
          case 'hr':
            onSelect(HrEffectiveView.hrManager);
            break;
          case 'clear':
            onClear();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'emp',
          child: Text(
              'View: Employee (${current == HrEffectiveView.employee ? '✓' : ''})'),
        ),
        PopupMenuItem(
          value: 'mgr',
          child: Text(
              'View: Manager (${current == HrEffectiveView.manager ? '✓' : ''})'),
        ),
        PopupMenuItem(
          value: 'hr',
          child: Text(
              'View: HR (${current == HrEffectiveView.hrManager ? '✓' : ''})'),
        ),
        const PopupMenuItem(value: 'clear', child: Text('Clear override')),
      ],
    );
  }
}

/// Hub picker tiles — filled dark gradients (lighter than original), light text.
class _HubServiceTile extends StatelessWidget {
  const _HubServiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bgGradient,
    required this.titleGradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> bgGradient;
  final List<Color> titleGradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: bgGradient,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                offset: Offset(0, 4.h),
                blurRadius: 10,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white.withValues(alpha: 0.94),
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => LinearGradient(
                          colors: titleGradient,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HrModuleTypography.cardTitle().copyWith(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: HrModuleTypography.caption().copyWith(
                          fontSize: 11.sp,
                          height: 1.25,
                          color: Colors.white.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.65),
                  size: 22.sp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
