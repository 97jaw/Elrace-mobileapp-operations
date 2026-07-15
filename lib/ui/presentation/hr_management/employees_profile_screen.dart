import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:el_race/ui/presentation/call_screen/data/model.dart';
import 'package:el_race/ui/presentation/call_screen/data/repository.dart';
import 'package:el_race/ui/presentation/call_screen/widgets/employee_contact_tile.dart';
import 'package:el_race/ui/presentation/hr_management/data/employee_profile_models.dart';
import 'package:el_race/ui/presentation/hr_management/data/employees_profile_repository.dart';
import 'package:el_race/ui/presentation/hr_management/widgets/employee_profile_more_info.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_access.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class _ProfilePalette {
  static const Color accent = Color(0xFF1F3A6E);
  static const Color accentSoft = Color(0xFF3B6FB0);
  static const Color ink = Color(0xFF1A237E);
  static const Color navy = Color(0xFF1A237E);
  static const Color muted = Color(0xFF6B7794);
  static const Color teal = Color(0xFF2B7A78);
  static const Color panel = Color(0xFFF8FAFD);
  static const Color line = Color(0xFFD5DCEC);
  static const Color softHeader = Color(0xFFEEF1F8);
  static const Color glassWhite = Color(0xFFF8FBFF);
}

/// Slow single-line marquee when text exceeds available width.
class _MarqueeText extends StatefulWidget {
  const _MarqueeText({
    required this.text,
    required this.style,
    this.textDirection,
  });

  final String text;
  final TextStyle style;
  final TextDirection? textDirection;

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _overflow = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _measure(BoxConstraints constraints) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: widget.textDirection ?? TextDirection.ltr,
    )..layout();
    final overflow = (painter.width - constraints.maxWidth).clamp(0.0, 9999.0);
    if ((overflow - _overflow).abs() <= 0.5) return;
    _overflow = overflow;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_overflow > 0) {
        final secs = (6 + _overflow / 28).clamp(6, 16).toInt();
        _controller.duration = Duration(seconds: secs);
        if (!_controller.isAnimating) {
          _controller.repeat(reverse: true);
        }
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _measure(constraints);
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final dx = _overflow <= 0 ? 0.0 : -_overflow * _controller.value;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              );
            },
            child: Text(
              widget.text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textDirection: widget.textDirection,
              style: widget.style,
            ),
          ),
        );
      },
    );
  }
}

class _SearchIndex {
  _SearchIndex(this.employee)
      : displayName = formatEmployeeDisplayName(employee.name ?? ''),
        fileId = (employee.empId ?? employee.id?.toString() ?? '').trim(),
        department = (employee.department ?? '').trim(),
        designation = _jobLabel(employee.jobId),
        photoUrl = (employee.profilePhotoUrl ?? '').trim(),
        odooEmployeeId = employee.employeeId,
        _haystack = _buildHaystack(employee);

  final Employee employee;
  final String displayName;
  final String fileId;
  final String department;
  final String designation;
  final String photoUrl;
  final int? odooEmployeeId;
  final String _haystack;

  static String _jobLabel(dynamic job) {
    if (job == null) return '';
    if (job is List && job.isNotEmpty) return '${job.last}'.trim();
    final s = '$job'.trim();
    if (s.isEmpty || s == 'null' || s == 'false') return '';
    return s;
  }

  static String _buildHaystack(Employee e) {
    final name = formatEmployeeDisplayName(e.name ?? '').toLowerCase();
    final raw = (e.name ?? '').toLowerCase();
    final file = (e.empId ?? e.id?.toString() ?? '').toLowerCase();
    final dept = (e.department ?? '').toLowerCase();
    final job = _jobLabel(e.jobId).toLowerCase();
    return '$name $raw $file $dept $job';
  }

  bool matches(String q) => _haystack.contains(q);

  bool startsWithNameOrFile(String q) {
    final name = displayName.toLowerCase();
    final file = fileId.toLowerCase();
    return name.startsWith(q) ||
        file.startsWith(q) ||
        name.split(RegExp(r'\s+')).any((p) => p.startsWith(q));
  }
}

/// Returns true when query is long enough to search.
bool _queryIsActive(String raw) {
  final q = raw.trim();
  if (q.isEmpty) return false;
  final numeric = RegExp(r'^\d+$').hasMatch(q);
  if (numeric) return q.length >= 2;
  return q.length >= 3;
}

class EmployeesProfileScreen extends StatefulWidget {
  const EmployeesProfileScreen({super.key});

  @override
  State<EmployeesProfileScreen> createState() => _EmployeesProfileScreenState();
}

class _EmployeesProfileScreenState extends State<EmployeesProfileScreen> {
  final _repo = sl.get<ContactRepo>();
  final _profileRepo = EmployeesProfileRepository();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  List<_SearchIndex> _all = const [];
  List<_SearchIndex> _results = const [];
  _SearchIndex? _selected;
  EmployeeProfileDetail? _profile;
  bool _loading = true;
  bool _profileLoading = false;
  String? _error;
  String? _profileError;
  String _query = '';

  static const int _maxSuggestions = 40;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
    if (!ProjectsDashboardAccess.isManagementUser()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        HomeNavigation.handleSystemBack(context);
      });
      return;
    }
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _repo.getEmployeeList();
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Unable to load employee profiles';
        });
        return;
      }
      final model = employeeModelFromJson(response.body);
      final employees = model.result?.employees ?? const <Employee>[];
      final indexed = employees.map(_SearchIndex.new).toList(growable: false);
      setState(() {
        _all = indexed;
        _loading = false;
        _filter(_query);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load employee profiles';
      });
    }
  }

  void _onQueryChanged() {
    final q = _searchController.text;
    if (q == _query) return;
    _query = q;
    _filter(q);
  }

  void _filter(String raw) {
    if (!_queryIsActive(raw)) {
      setState(() => _results = const []);
      return;
    }
    final q = raw.trim().toLowerCase();
    final starts = <_SearchIndex>[];
    final contains = <_SearchIndex>[];
    for (final item in _all) {
      if (!item.matches(q)) continue;
      if (item.startsWithNameOrFile(q)) {
        starts.add(item);
      } else {
        contains.add(item);
      }
    }
    final merged = <_SearchIndex>[
      ...starts.take(_maxSuggestions),
      ...contains.take(
        (_maxSuggestions - starts.length).clamp(0, _maxSuggestions),
      ),
    ];
    setState(() => _results = merged);
  }

  Future<void> _openProfile(_SearchIndex item) async {
    _searchFocus.unfocus();
    setState(() {
      _selected = item;
      _profile = null;
      _profileError = null;
      _profileLoading = true;
    });

    final odooId = item.odooEmployeeId;
    if (odooId == null) {
      setState(() {
        _profileLoading = false;
        _profileError = 'Missing employee id for profile';
      });
      return;
    }

    try {
      final detail = await _profileRepo.fetchProfile(odooId);
      if (!mounted || _selected != item) return;
      setState(() {
        _profile = detail;
        _profileLoading = false;
      });
    } catch (e) {
      if (!mounted || _selected != item) return;
      setState(() {
        _profileLoading = false;
        _profileError = 'Unable to load full profile';
      });
    }
  }

  void _backToSearch() {
    setState(() {
      _selected = null;
      _profile = null;
      _profileError = null;
      _profileLoading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ProjectsDashboardAccess.isManagementUser()) {
      return HrModuleGlassShell(
        title: 'Employees Profile',
        accentTint: HrModuleHeaderTints.employeesProfile,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Text(
              'This service is available to management users only.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: _ProfilePalette.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return HrModuleGlassShell(
      title: 'Employees Profile',
      accentTint: HrModuleHeaderTints.employeesProfile,
      onBack: _selected != null
          ? _backToSearch
          : () => HomeNavigation.handleSystemBack(context),
      background: const BoxDecoration(color: Colors.white),
      body: Material(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _selected != null
                ? _ProfileDetailView(
                    key: ValueKey('profile-${_selected!.fileId}'),
                    listItem: _selected!,
                    profile: _profile,
                    loading: _profileLoading,
                    error: _profileError,
                    onRetry: () => _openProfile(_selected!),
                  )
                : _SearchPane(
                    key: const ValueKey('search'),
                    loading: _loading,
                    error: _error,
                    query: _query,
                    results: _results,
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onRetry: _loadEmployees,
                    onSelect: _openProfile,
                  ),
          ),
        ),
      ),
    );
  }
}

class _SearchPane extends StatelessWidget {
  const _SearchPane({
    super.key,
    required this.loading,
    required this.error,
    required this.query,
    required this.results,
    required this.controller,
    required this.focusNode,
    required this.onRetry,
    required this.onSelect,
  });

  final bool loading;
  final String? error;
  final String query;
  final List<_SearchIndex> results;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onRetry;
  final ValueChanged<_SearchIndex> onSelect;

  @override
  Widget build(BuildContext context) {
    final hasQuery = _queryIsActive(query);

    final searchHeader = Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            style: GoogleFonts.poppins(
              fontSize: hasQuery ? 14.sp : 16.sp,
              fontWeight: FontWeight.w700,
              color: _ProfilePalette.accent,
              height: 1.3,
            ),
            child: const Text(
              'Search Profiles by Name / File id',
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: hasQuery ? 10.h : 14.h),
          _GlassSearchField(
            controller: controller,
            focusNode: focusNode,
            enabled: !loading && error == null,
          ),
        ],
      ),
    );

    return SizedBox.expand(
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: hasQuery ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: !hasQuery,
                child: Padding(
                  padding: EdgeInsets.only(top: 118.h),
                  child: !hasQuery
                      ? const SizedBox.shrink()
                      : results.isEmpty
                          ? Center(
                              child: Text(
                                'No profiles match “${query.trim()}”',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.sp,
                                  color: _ProfilePalette.muted,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 20.h),
                              itemCount: results.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: 8.h),
                              itemBuilder: (context, index) {
                                final item = results[index];
                                return _SuggestionCard(
                                  item: item,
                                  onTap: () => onSelect(item),
                                );
                              },
                            ),
                ),
              ),
            ),
          ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: hasQuery ? Alignment.topCenter : Alignment.center,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(top: hasQuery ? 12.h : 0),
              child: searchHeader,
            ),
          ),
          if (!hasQuery)
            Positioned(
              left: 0,
              right: 0,
              bottom: 28.h,
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _ProfilePalette.accent,
                        strokeWidth: 2.4,
                      ),
                    )
                  : error != null
                      ? Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.sp,
                                  color: _ProfilePalette.muted,
                                ),
                              ),
                              TextButton(
                                onPressed: onRetry,
                                child: Text(
                                  'Retry',
                                  style: GoogleFonts.poppins(
                                    color: _ProfilePalette.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          'Type at least 3 letters (or 2 digits for file id)',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5.sp,
                            color: _ProfilePalette.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
            ),
        ],
      ),
    );
  }
}

class _GlassSearchField extends StatelessWidget {
  const _GlassSearchField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18.r),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _ProfilePalette.glassWhite,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: _ProfilePalette.accent.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: _ProfilePalette.accent.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: Offset(0, 6.h),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: false,
          textInputAction: TextInputAction.search,
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: _ProfilePalette.ink,
          ),
          cursorColor: _ProfilePalette.accent,
          decoration: InputDecoration(
            hintText: 'Type name or file id',
            hintStyle: GoogleFonts.poppins(
              fontSize: 13.5.sp,
              color: _ProfilePalette.muted.withValues(alpha: 0.85),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: _ProfilePalette.accentSoft,
              size: 22.sp,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  tooltip: 'Clear',
                  onPressed: controller.clear,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20.sp,
                    color: _ProfilePalette.muted,
                  ),
                );
              },
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 8.w,
              vertical: 14.h,
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.item,
    required this.onTap,
  });

  final _SearchIndex item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            color: Colors.white,
            border: Border.all(
              color: _ProfilePalette.accent.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: Offset(0, 3.h),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                _Avatar(url: item.photoUrl, name: item.displayName, radius: 26),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: _ProfilePalette.ink,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        [
                          if (item.designation.isNotEmpty) item.designation,
                          if (item.department.isNotEmpty) item.department,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5.sp,
                          color: _ProfilePalette.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.fileId.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _ProfilePalette.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            'File ID ${item.fileId}',
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: _ProfilePalette.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _ProfilePalette.accent.withValues(alpha: 0.55),
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

class _ProfileDetailView extends StatelessWidget {
  const _ProfileDetailView({
    super.key,
    required this.listItem,
    required this.profile,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final _SearchIndex listItem;
  final EmployeeProfileDetail? profile;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final name = profile?.name.isNotEmpty == true
        ? profile!.name
        : listItem.displayName;
    final arabic = profile?.arabicName;
    final fileId = profile?.empId.isNotEmpty == true
        ? profile!.empId
        : listItem.fileId;
    final photo = (profile?.profilePhotoUrl ?? listItem.photoUrl).trim();
    final job = profile?.jobTitle?.trim().isNotEmpty == true
        ? profile!.jobTitle!
        : listItem.designation;
    final position = profile?.positionType?.trim() ?? '';
    final department = profile?.department?.trim() ?? '';
    final section = profile?.section?.trim() ?? '';

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 6.h, 12.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(
            photoUrl: photo,
            name: name,
            arabicName: arabic,
            fileId: fileId,
            jobTitle: job,
            positionType: position,
            department: department,
            section: section,
          ),
          SizedBox(height: 8.h),
          if (loading)
            const Expanded(child: Center(child: _KpiShimmer()))
          else if (error != null)
            Expanded(child: Center(child: _ErrorBlock(message: error!, onRetry: onRetry)))
          else if (profile != null) ...[
            Expanded(
              flex: 5,
              child: _KpiTable(kpis: profile!.kpis),
            ),
            SizedBox(height: 8.h),
            Expanded(
              flex: 6,
              child: _InfoTable(info: profile!.info),
            ),
            SizedBox(height: 8.h),
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: ElevatedButton(
                onPressed: () {
                  final id = profile?.employeeId ?? listItem.odooEmployeeId;
                  if (id == null || id <= 0) return;
                  showEmployeeProfileMoreInfo(
                    context: context,
                    employeeId: id,
                    employeeName: name,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ProfilePalette.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'Request more info',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.photoUrl,
    required this.name,
    required this.arabicName,
    required this.fileId,
    required this.jobTitle,
    required this.positionType,
    required this.department,
    required this.section,
  });

  final String photoUrl;
  final String name;
  final String? arabicName;
  final String fileId;
  final String jobTitle;
  final String positionType;
  final String department;
  final String section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: _ProfilePalette.panel,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _ProfilePalette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Avatar(url: photoUrl, name: name, radius: 30),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MarqueeText(
                  text: name,
                  style: GoogleFonts.poppins(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: _ProfilePalette.navy,
                    height: 1.2,
                  ),
                ),
                if (arabicName != null && arabicName!.trim().isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  _MarqueeText(
                    text: arabicName!.trim(),
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: _ProfilePalette.teal,
                    ),
                  ),
                ],
                SizedBox(height: 8.h),
                SizedBox(
                  height: 28.h,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (jobTitle.isNotEmpty) ...[
                        Center(
                          child: Text(
                            jobTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w600,
                              color: _ProfilePalette.ink,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6.w),
                          child: Center(
                            child: Text(
                              ':',
                              style: GoogleFonts.poppins(
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w600,
                                color: _ProfilePalette.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (fileId.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(right: 6.w),
                          child: _Chip(
                            label: 'File ID $fileId',
                            fg: _ProfilePalette.accent,
                            bg: _ProfilePalette.accent.withValues(alpha: 0.1),
                          ),
                        ),
                      if (positionType.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(right: 6.w),
                          child: _Chip(
                            label: positionType.toUpperCase(),
                            fg: Colors.white,
                            bg: _positionColor(positionType),
                          ),
                        ),
                      if (department.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(right: 6.w),
                          child: _Chip(
                            label: department,
                            fg: _ProfilePalette.navy,
                            bg: const Color(0xFFDDE8F6),
                          ),
                        ),
                      if (section.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(right: 6.w),
                          child: _Chip(
                            label: section,
                            fg: _ProfilePalette.navy,
                            bg: const Color(0xFFE4EEF8),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _positionColor(String type) {
    switch (type.toLowerCase()) {
      case 'staff':
        return const Color(0xFF2563EB);
      case 'labor':
        return const Color(0xFF0F766E);
      case 'manager':
        return const Color(0xFF1D4ED8);
      default:
        return _ProfilePalette.accent;
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.fg,
    required this.bg,
  });

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _KpiTable extends StatelessWidget {
  const _KpiTable({required this.kpis});

  final EmployeeProfileKpis kpis;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Working Days', kpis.workingDays),
      ('Leave Balance', kpis.leaveBalance),
      ('Sick Leave', kpis.sickLeave),
      (
        'Temp Permission',
        kpis.tempPermission.subtitle == null ||
                kpis.tempPermission.subtitle!.isEmpty
            ? kpis.tempPermission.value
            : '${kpis.tempPermission.value}  (${kpis.tempPermission.subtitle})',
      ),
      (
        'Annual / Short',
        kpis.annualShort.subtitle == null || kpis.annualShort.subtitle!.isEmpty
            ? kpis.annualShort.value
            : '${kpis.annualShort.value}  (${kpis.annualShort.subtitle})',
      ),
      ('Expired Documents', kpis.expiredDocuments),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _ProfilePalette.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            color: _ProfilePalette.softHeader,
            child: Text(
              'KPI SUMMARY',
              style: GoogleFonts.poppins(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: _ProfilePalette.navy,
              ),
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        rows[i].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: _ProfilePalette.ink,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 16.h,
                      color: _ProfilePalette.line,
                    ),
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: EdgeInsets.only(left: 10.w),
                        child: Text(
                          rows[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: _ProfilePalette.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < rows.length - 1)
              const Divider(height: 1, color: _ProfilePalette.line),
          ],
        ],
      ),
    );
  }
}

class _InfoTable extends StatelessWidget {
  const _InfoTable({required this.info});

  final EmployeeProfileInfo info;

  @override
  Widget build(BuildContext context) {
    final education = [
      if ((info.education ?? '').trim().isNotEmpty) info.education!.trim(),
      if ((info.graduationYear ?? '').trim().isNotEmpty)
        info.graduationYear!.trim(),
    ].join(' · ');
    final country = (info.country ?? '').trim();
    final flag = _flagEmoji(info.countryCode);
    final countryVal = country.isEmpty
        ? '—'
        : (flag == null ? country : '$flag  $country');

    final cells = [
      ('Direct Manager', info.directManager ?? '—'),
      ('Joining date', info.joiningDate ?? '—'),
      ('Evaluation', info.evaluation?.toString() ?? '—'),
      ('Education', education.isEmpty ? '—' : education),
      (
        'Experience',
        (info.experienceYears ?? '').trim().isEmpty
            ? '—'
            : '${info.experienceYears} years',
      ),
      ('Visa Co.', info.visaCo ?? '—'),
      ('Email', info.email ?? '—'),
      ('Country', countryVal),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _ProfilePalette.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            color: _ProfilePalette.softHeader,
            child: Text(
              'INFORMATION',
              style: GoogleFonts.poppins(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: _ProfilePalette.navy,
              ),
            ),
          ),
          for (var i = 0; i < cells.length; i += 2)
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _InfoCell(
                            label: cells[i].$1,
                            value: cells[i].$2,
                          ),
                        ),
                        Container(width: 1, color: _ProfilePalette.line),
                        Expanded(
                          child: i + 1 < cells.length
                              ? _InfoCell(
                                  label: cells[i + 1].$1,
                                  value: cells[i + 1].$2,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  if (i + 2 < cells.length)
                    const Divider(height: 1, color: _ProfilePalette.line),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String? _flagEmoji(String? code) {
    if (code == null || code.trim().length != 2) return null;
    final c = code.trim().toUpperCase();
    final first = c.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final second = c.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCodes([first, second]);
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: _ProfilePalette.muted,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: _ProfilePalette.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiShimmer extends StatelessWidget {
  const _KpiShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(
          color: _ProfilePalette.accent,
          strokeWidth: 2.4,
        ),
        SizedBox(height: 10.h),
        Text(
          'Loading profile details…',
          style: GoogleFonts.poppins(
            fontSize: 12.5.sp,
            color: _ProfilePalette.muted,
          ),
        ),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
            color: _ProfilePalette.muted,
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'Retry',
            style: GoogleFonts.poppins(
              color: _ProfilePalette.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.name,
    required this.radius,
  });

  final String url;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return CircleAvatar(
      radius: radius.r,
      backgroundColor: _ProfilePalette.accent.withValues(alpha: 0.12),
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      onBackgroundImageError: url.isNotEmpty ? (_, __) {} : null,
      child: url.isEmpty
          ? Text(
              initials,
              style: GoogleFonts.poppins(
                fontSize: (radius * 0.55).sp,
                fontWeight: FontWeight.w700,
                color: _ProfilePalette.accent,
              ),
            )
          : null,
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return '?';
    if (list.length == 1) {
      return list.first.length >= 2
          ? list.first.substring(0, 2).toUpperCase()
          : list.first.toUpperCase();
    }
    return ('${list.first[0]}${list[1][0]}').toUpperCase();
  }
}
