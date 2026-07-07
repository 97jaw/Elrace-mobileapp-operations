import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_group_list_cache.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_cached_image.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_dashboard_shimmer.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_glass_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Themed list for Project Manager / Client / City group-by pickers.
class ProjectsGroupPickerScreen extends StatefulWidget {
  const ProjectsGroupPickerScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.groupBy,
    required this.onItemTap,
    this.onHome,
  });

  final String title;
  final IconData icon;
  final String groupBy;
  final ValueChanged<ProjectManagerFilterItem> onItemTap;
  final VoidCallback? onHome;

  @override
  State<ProjectsGroupPickerScreen> createState() =>
      _ProjectsGroupPickerScreenState();
}

class _ProjectsGroupPickerScreenState extends State<ProjectsGroupPickerScreen> {
  bool _isLoading = true;
  String? _error;
  List<ProjectManagerFilterItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = ProjectsGroupListCache.instance.get(widget.groupBy);
      if (cached != null && cached.isNotEmpty) {
        setState(() {
          _items = cached;
          _isLoading = false;
          _error = null;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ProjectRemoteDataSource()
          .fetchClientsGroupedList(groupBy: widget.groupBy);
      ProjectsGroupListCache.instance.put(widget.groupBy, data);
      if (!mounted) return;
      setState(() {
        _items = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _isLoading = false;
      });
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('handshake') ||
        msg.contains('connection') ||
        msg.contains('terminated') ||
        msg.contains('socket')) {
      return 'Connection interrupted. Check network or VPN, then retry.';
    }
    return e.toString();
  }

  String _lastUpdateText(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) {
      return 'Last updates recently';
    }
    final parsed = DateTime.tryParse(rawDate.trim());
    if (parsed == null) return 'Last updates recently';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = today.difference(date).inDays;
    if (diff <= 0) return 'Last updates today';
    if (diff == 1) return 'Last updates yesterday';
    return 'Last updates ${DateFormat('dd/MM/yyyy').format(parsed)}';
  }

  void _goHome() {
    if (widget.onHome != null) {
      widget.onHome!();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: ProjectsDashboardTheme.screenGradient,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProjectsGlassChromeHeader(
              title: widget.title,
              showBack: true,
              titleTrailing: ProjectsGlassChromeHeader.homeTrailing(
                onPressed: _goHome,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemCount: 8,
                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                      itemBuilder: (_, __) => const ProjectsProjectRowShimmer(),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: ProjectsDashboardTheme.white,
                                    fontSize: 13.sp,
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                TextButton.icon(
                                  onPressed: () => _load(forceRefresh: true),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: ProjectsDashboardTheme.white,
                                  ),
                                  label: Text(
                                    'Retry',
                                    style: GoogleFonts.poppins(
                                      color: ProjectsDashboardTheme.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16.w,
                            0,
                            16.w,
                            24.h,
                          ),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => SizedBox(height: 10.h),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(
                                milliseconds: 240 + (index % 8) * 28,
                              ),
                              curve: Curves.easeOutCubic,
                              builder: (context, t, child) => Opacity(
                                opacity: t,
                                child: Transform.translate(
                                  offset: Offset(0, 10 * (1 - t)),
                                  child: child,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => widget.onItemTap(item),
                                  borderRadius: BorderRadius.circular(16.r),
                                  child: Container(
                                    padding: EdgeInsets.all(12.w),
                                    decoration: ProjectsDashboardTheme
                                        .frostedPanel(radius: 16),
                                    child: Row(
                                      children: [
                                        _PickerAvatar(
                                          name: item.name,
                                          photoUrl: item.photoUrl,
                                        ),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: ProjectsDashboardTheme
                                                      .white,
                                                ),
                                              ),
                                              SizedBox(height: 2.h),
                                              Text(
                                                _lastUpdateText(
                                                  item.lastUpdate,
                                                ),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12.sp,
                                                  color: ProjectsDashboardTheme
                                                      .greyPanel,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                            vertical: 8.h,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: ProjectsDashboardTheme
                                                .maroonAccentGradient,
                                            borderRadius:
                                                BorderRadius.circular(12.r),
                                            border: Border.all(
                                              color: ProjectsDashboardTheme
                                                  .white
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Text(
                                            '${item.projectCount}',
                                            style: GoogleFonts.koulen(
                                              fontSize: 16.sp,
                                              color: ProjectsDashboardTheme
                                                  .white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerAvatar extends StatelessWidget {
  const _PickerAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      return ClipOval(
        child: ProjectsCachedImage(
          url: photoUrl!,
          width: 52.w,
          height: 52.w,
          fit: BoxFit.cover,
        ),
      );
    }

    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 26.r,
      backgroundColor: ProjectsDashboardTheme.navy.withValues(alpha: 0.85),
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: ProjectsDashboardTheme.white,
        ),
      ),
    );
  }
}
