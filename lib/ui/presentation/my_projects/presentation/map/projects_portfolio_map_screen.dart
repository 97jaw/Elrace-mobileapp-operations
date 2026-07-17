import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:math' as math;

import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_repository_impl.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_filters_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_partner_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/map/portfolio_project_status.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/map/project_analytics_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/map/project_map_coordinate_resolver.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_pagination.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_dialog.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class ProjectsPortfolioMapScreen extends StatefulWidget {
  const ProjectsPortfolioMapScreen({super.key});

  @override
  State<ProjectsPortfolioMapScreen> createState() =>
      _ProjectsPortfolioMapScreenState();
}

class _ProjectsPortfolioMapScreenState extends State<ProjectsPortfolioMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _showSearch = false;
  String _searchQuery = '';
  double _mapZoom = 6.8;
  String? _error;
  List<ProjectEntity> _all = [];
  ProjectEntity? _focusedProject;
  List<_SupervisorPlacement> _focusedSupervisorPlacements = const [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (_searchQuery == q) return;
    setState(() => _searchQuery = q);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitToProjects());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ProjectRemoteDataSource().fetchProjects(
        maxItems: kProjectsMapMaxProjects,
      );
      if (!mounted) return;
      setState(() {
        _all = raw;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitToProjects());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<ProjectEntity> get _visible {
    return _all.where((p) {
      if (!hasRealCoordinates(p)) return false;
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<ProjectEntity> get _notVisible =>
      _all.where((p) => !hasRealCoordinates(p)).toList();

  DateTime? _parseDate(String value) {
    if (value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
    try {
      return DateFormat('yyyy-MM-dd').parse(value);
    } catch (_) {
      return null;
    }
  }

  List<ProjectEntity> _highlightedProjects() {
    final threshold = DateTime.now().subtract(const Duration(days: 92));
    final items = _visible.where((p) {
      final d = _parseDate(p.date);
      return d != null && d.isAfter(threshold);
    }).toList();
    items.sort((a, b) {
      final ad = _parseDate(a.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = _parseDate(b.date) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return items.take(8).toList();
  }

  ProjectListBloc _buildBloc() {
    final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
    return ProjectListBloc(
      getProjectsUseCase: GetProjectsUseCase(repository: repo),
      getProjectAttachmentsUseCase:
          GetProjectAttachmentsUseCase(repository: repo),
      getProjectsByPartnerUseCase:
          GetProjectsByPartnerUseCase(repository: repo),
      getProjectsByFiltersUseCase:
          GetProjectsByFiltersUseCase(repository: repo),
    );
  }

  String _money(ProjectEntity p) {
    final custom = p.budgetLabel?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final fmt = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    return fmt.format(p.woAmount);
  }

  String _progressText(ProjectEntity p) {
    final progress = p.totalProgress;
    if (progress == null) return 'N/A';
    if (progress % 1 == 0) return '${progress.toStringAsFixed(0)}%';
    return '${progress.toStringAsFixed(1)}%';
  }

  void _fitToProjects() {
    final pts =
        _visible.map((p) => resolveProjectLatLng(p)).toList(growable: false);
    if (pts.isEmpty) {
      _mapController.move(uaeMapInitialCenter(), uaeMapInitialZoom());
      return;
    }
    if (pts.length == 1) {
      _mapController.move(pts.first, 13.5);
      return;
    }

    final bounds = LatLngBounds.fromPoints(pts);
    final latSpan = (bounds.north - bounds.south).abs();
    final lngSpan = (bounds.east - bounds.west).abs();

    // Very tiny/flat bounds can produce invalid zoom in flutter_map internals.
    if (latSpan < 1e-6 || lngSpan < 1e-6) {
      _mapController.move(pts.first, 12.5);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(30, 90, 30, 180),
      ),
    );
  }

  void _showNotVisibleProjectsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final notVisible = _notVisible;
        return AlertDialog(
          title: const Text('Not Visible Projects'),
          content: SizedBox(
            width: 330,
            child: notVisible.isEmpty
                ? const Text('All projects already have real coordinates.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: notVisible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      title: Text(
                        notVisible[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _openDetailSheet(ProjectEntity project) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.58,
          minChildSize: 0.36,
          maxChildSize: 0.9,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.tr)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 18,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: EdgeInsets.fromLTRB(18.tw, 12.th, 18.tw, 22.th),
                children: [
                  Center(
                    child: Container(
                      width: 40.tw,
                      height: 4.th,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4.tr),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.th),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22.tr,
                        backgroundColor: const Color(0xFFE7ECFF),
                        backgroundImage: (project.clientImageUrl != null &&
                                project.clientImageUrl!.isNotEmpty)
                            ? NetworkImage(project.clientImageUrl!)
                            : null,
                        child: (project.clientImageUrl == null ||
                                project.clientImageUrl!.isEmpty)
                            ? Icon(
                                Icons.apartment_rounded,
                                size: 24.tsp,
                                color: const Color(0xFF1E2365),
                              )
                            : null,
                      ),
                      SizedBox(width: 10.tw),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 16.tsp,
                                fontWeight: FontWeight.w700,
                                color: appFontColor,
                              ),
                            ),
                            Text(
                              'Agreement ${project.agreementId} · WO ${project.woRefNo}',
                              style: GoogleFonts.poppins(
                                fontSize: 11.tsp,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.th),
                  Wrap(
                    spacing: 8.tw,
                    runSpacing: 8.th,
                    children: [
                      _badge(
                        label: project.projectStatus.isEmpty
                            ? 'Status N/A'
                            : project.projectStatus,
                        color: const Color(0xFF1565C0),
                        icon: Icons.flag_circle_rounded,
                      ),
                      _badge(
                        label: 'Progress ${_progressText(project)}',
                        color: const Color(0xFF6A1B9A),
                        icon: Icons.insights_rounded,
                      ),
                    ],
                  ),
                  SizedBox(height: 12.th),
                  _managerTableRow(project),
                  _tableRow('Amount', _money(project)),
                  _tableRow(
                    'Start date',
                    project.dateStart.trim().isEmpty ? '—' : project.dateStart,
                  ),
                  _tableRow(
                    'Date',
                    project.date.trim().isEmpty ? '—' : project.date,
                  ),
                  SizedBox(height: 16.th),
                  _gradientActionButton(
                    icon: Icons.cloud_queue_rounded,
                    title: 'Documents',
                    colors: const [
                      Color(0xFF11998E),
                      Color(0xFF38EF7D),
                    ],
                    onTap: () {
                      Navigator.pop(ctx);
                      ProjectDocumentsDialog.show(
                        context,
                        projectId: project.projectId,
                        bloc: _buildBloc(),
                      );
                    },
                  ),
                  SizedBox(height: 10.th),
                  _gradientActionButton(
                    icon: Icons.analytics_rounded,
                    title: 'View Project Analytics',
                    colors: const [
                      Color(0xFF6A11CB),
                      Color(0xFF2575FC),
                      Color(0xFF00C6FF),
                    ],
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectAnalyticsScreen(project: project),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleProjectLongPress(ProjectEntity project) async {
    if (_focusedProject?.projectId == project.projectId) {
      setState(() {
        _focusedProject = null;
        _focusedSupervisorPlacements = const [];
      });
      return;
    }
    final center = resolveProjectLatLng(project);
    final placements = _buildSupervisorPlacements(project, center);
    _mapController.move(center, 16.2);
    setState(() {
      _focusedProject = project;
      _focusedSupervisorPlacements = placements;
      _mapZoom = 16.2;
    });
  }

  List<_SupervisorPlacement> _buildSupervisorPlacements(
    ProjectEntity project,
    LatLng center,
  ) {
    final active = project.supervisors
        .where((s) =>
            s.employeeName.trim().isNotEmpty &&
            !_isSupervisorInactive(s.status))
        .toList(growable: false);
    if (active.isEmpty) return const [];

    final step = 360.0 / active.length;
    return List<_SupervisorPlacement>.generate(active.length, (i) {
      final radius = math.min(480, 120 + (i % 3) * 130 + (i ~/ 3) * 25);
      final bearing = -90 + (i * step) + (i.isEven ? 9 : -9);
      final point = _offsetFromCenter(center, radius.toDouble(), bearing);
      return _SupervisorPlacement(
        supervisor: active[i],
        point: point,
        distanceMeters: radius,
      );
    }, growable: false);
  }

  bool _isSupervisorInactive(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'inactive' ||
        normalized == 'off_duty' ||
        normalized == 'terminated';
  }

  LatLng _offsetFromCenter(LatLng center, double meters, double bearingDeg) {
    const earthRadius = 6378137.0;
    final bearing = bearingDeg * math.pi / 180.0;
    final lat1 = center.latitude * math.pi / 180.0;
    final lon1 = center.longitude * math.pi / 180.0;
    final angDist = meters / earthRadius;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angDist) +
          math.cos(lat1) * math.sin(angDist) * math.cos(bearing),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(bearing) * math.sin(angDist) * math.cos(lat1),
          math.cos(angDist) - math.sin(lat1) * math.sin(lat2),
        );
    return LatLng(lat2 * 180.0 / math.pi, lon2 * 180.0 / math.pi);
  }

  Widget _badge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 7.th),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24.tr),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.tsp, color: color),
          SizedBox(width: 6.tw),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10.tsp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.th),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(10.tr),
        border: Border.all(color: const Color(0xFFE6EAF3)),
      ),
      child: Row(
        children: [
          Container(
            width: 110.tw,
            padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 10.th),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10.tr),
                bottomLeft: Radius.circular(10.tr),
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.tsp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E2365),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 10.th),
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 11.tsp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _managerTableRow(ProjectEntity project) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.th),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(10.tr),
        border: Border.all(color: const Color(0xFFE6EAF3)),
      ),
      child: Row(
        children: [
          Container(
            width: 110.tw,
            padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 10.th),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10.tr),
                bottomLeft: Radius.circular(10.tr),
              ),
            ),
            child: Text(
              'Manager',
              style: GoogleFonts.poppins(
                fontSize: 11.tsp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E2365),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 8.th),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12.tr,
                    backgroundColor: const Color(0xFFE7ECFF),
                    backgroundImage:
                        (project.managerPhoto != null && project.managerPhoto!.isNotEmpty)
                            ? NetworkImage(project.managerPhoto!)
                            : null,
                    child: (project.managerPhoto == null || project.managerPhoto!.isEmpty)
                        ? const Icon(Icons.person_rounded, size: 14)
                        : null,
                  ),
                  SizedBox(width: 8.tw),
                  Expanded(
                    child: Text(
                      project.projectManagerName ?? '—',
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientActionButton({
    required IconData icon,
    required String title,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.tr),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.tr),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 12.th),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20.tsp),
                SizedBox(width: 8.tw),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12.tsp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18.tsp),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassCard(Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14.tr),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final markers = <Marker>[
      for (final p in visible)
        Marker(
          point: resolveProjectLatLng(p),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () => _openDetailSheet(p),
            onLongPress: () => _handleProjectLongPress(p),
            child: _ProjectMapPin(
              color: const Color(0xFF1E2365),
              imageUrl: p.clientImageUrl,
            ),
          ),
        ),
      if (_mapZoom >= 14.5)
        for (final s in _focusedSupervisorPlacements)
          Marker(
            point: s.point,
            width: 150,
            height: 50,
            child: _SupervisorMapAvatar(
              supervisor: s.supervisor,
              distanceMeters: s.distanceMeters,
            ),
          ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Stack(
        children: [
          Positioned.fill(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.tw),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: uaeMapInitialCenter(),
                          initialZoom: uaeMapInitialZoom(),
                          onPositionChanged: (position, _) {
                            final z = position.zoom;
                            if ((_mapZoom - z).abs() > 0.05) {
                              setState(() => _mapZoom = z);
                            }
                          },
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'ae.elrace.mobile',
                          ),
                          MarkerLayer(markers: markers),
                          if (_focusedProject != null && _mapZoom >= 14.5)
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: resolveProjectLatLng(_focusedProject!),
                                  radius: 500,
                                  useRadiusInMeter: true,
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.13),
                                  borderColor: const Color(0xFF1D4ED8),
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                          RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                '© OpenStreetMap',
                                onTap: () async {
                                  final u = Uri.parse(
                                    'https://www.openstreetmap.org/copyright',
                                  );
                                  if (await canLaunchUrl(u)) {
                                    await launchUrl(
                                      u,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                              TextSourceAttribution(
                                '© CARTO',
                                onTap: () async {
                                  final u = Uri.parse('https://carto.com/legal/');
                                  if (await canLaunchUrl(u)) {
                                    await launchUrl(
                                      u,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.tw, 8.th, 12.tw, 0),
              child: Column(
                children: [
                  _glassCard(
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 8.th),
                      child: Row(
                        children: [
                          _MapToolbarIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onPressed: () => Navigator.pop(context),
                          ),
                          SizedBox(width: 6.tw),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Projects map',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16.tsp,
                                    fontWeight: FontWeight.w700,
                                    color: appFontColor,
                                  ),
                                ),
                                Text(
                                  'UAE · Coordinate-based view',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.tsp,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _MapToolbarIconButton(
                            icon: _showSearch
                                ? Icons.search_off_rounded
                                : Icons.search_rounded,
                            onPressed: () => setState(() {
                              _showSearch = !_showSearch;
                              if (!_showSearch) _searchController.clear();
                            }),
                          ),
                          SizedBox(width: 6.tw),
                          _MapToolbarIconButton(
                            icon: Icons.center_focus_strong_rounded,
                            onPressed: _fitToProjects,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showSearch) ...[
                    SizedBox(height: 8.th),
                    _glassCard(
                      TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search project name...',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 12.tsp,
                            color: const Color(0xFF9CA3AF),
                          ),
                          border: InputBorder.none,
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () => _searchController.clear(),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12.tw, vertical: 11.th),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  _PortfolioSummaryPanel(
                    visible: visible,
                    totalCount: _all.length,
                    notVisibleCount: _notVisible.length,
                    highlighted: _highlightedProjects(),
                    onHighlightedTap: _openDetailSheet,
                    onNotVisibleTap: _showNotVisibleProjectsDialog,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioSummaryPanel extends StatelessWidget {
  const _PortfolioSummaryPanel({
    required this.visible,
    required this.totalCount,
    required this.notVisibleCount,
    required this.highlighted,
    required this.onHighlightedTap,
    required this.onNotVisibleTap,
  });

  final List<ProjectEntity> visible;
  final int totalCount;
  final int notVisibleCount;
  final List<ProjectEntity> highlighted;
  final void Function(ProjectEntity) onHighlightedTap;
  final VoidCallback onNotVisibleTap;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final totalAed = visible.fold<double>(0, (sum, p) => sum + p.woAmount);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.tr)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14.tw, 10.th, 14.tw, 14.th),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Projects overview',
              style: GoogleFonts.poppins(
                fontSize: 14.tsp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            SizedBox(height: 8.th),
            Row(
              children: [
                _statChip('Visible', '${visible.length}', Icons.map_outlined),
                SizedBox(width: 8.tw),
                _statChip('Total', '$totalCount', Icons.apartment),
                SizedBox(width: 8.tw),
                _statChip('Amount', fmt.format(totalAed), Icons.payments_outlined),
              ],
            ),
            SizedBox(height: 8.th),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onNotVisibleTap,
                borderRadius: BorderRadius.circular(12.tr),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.tr),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF4E5), Color(0xFFFFE0B2)],
                    ),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_off_rounded, color: Color(0xFFEF6C00)),
                      SizedBox(width: 8.tw),
                      Expanded(
                        child: Text(
                          'Not Visible ($notVisibleCount)',
                          style: GoogleFonts.poppins(
                            fontSize: 12.tsp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.th),
            Text(
              'Highlighted projects',
              style: GoogleFonts.poppins(
                fontSize: 12.tsp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF374151),
              ),
            ),
            SizedBox(height: 6.th),
            SizedBox(
              height: 92.th,
              child: highlighted.isEmpty
                  ? Center(
                      child: Text(
                        'No projects updated in the last 3 months',
                        style: GoogleFonts.poppins(fontSize: 11.tsp, color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: highlighted.length,
                      separatorBuilder: (_, __) => SizedBox(width: 8.tw),
                      itemBuilder: (_, i) {
                        final p = highlighted[i];
                        return GestureDetector(
                          onTap: () => onHighlightedTap(p),
                          child: Container(
                            width: 210.tw,
                            padding: EdgeInsets.all(10.tw),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.tr),
                              border: Border.all(color: const Color(0xFFDCE3F2)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18.tr,
                                  backgroundColor: const Color(0xFFE9EEF9),
                                  backgroundImage: (p.clientImageUrl != null &&
                                          p.clientImageUrl!.isNotEmpty)
                                      ? NetworkImage(p.clientImageUrl!)
                                      : null,
                                  child: (p.clientImageUrl == null ||
                                          p.clientImageUrl!.isEmpty)
                                      ? const Icon(Icons.apartment_rounded)
                                      : null,
                                ),
                                SizedBox(width: 8.tw),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11.tsp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 4.th),
                                      Text(
                                        p.date.isEmpty ? '—' : p.date,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10.tsp,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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

  Widget _statChip(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF1E2365)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapToolbarIconButton extends StatelessWidget {
  const _MapToolbarIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.tr),
        side: BorderSide(color: const Color(0xFF1E2365).withValues(alpha: 0.08)),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.tr),
        child: SizedBox(
          width: 42.tw,
          height: 42.tw,
          child: Icon(icon, size: 20.tsp, color: const Color(0xFF1E2365)),
        ),
      ),
    );
  }
}

class _ProjectMapPin extends StatelessWidget {
  const _ProjectMapPin({
    required this.color,
    required this.imageUrl,
  });

  final Color color;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: Colors.white,
          child: imageUrl == null || imageUrl!.isEmpty
              ? Icon(Icons.apartment_rounded, color: color, size: 14)
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.apartment_rounded, color: color, size: 14),
                ),
        ),
      ),
    );
  }
}

class _SupervisorPlacement {
  final ProjectSupervisorEntity supervisor;
  final LatLng point;
  final int distanceMeters;

  const _SupervisorPlacement({
    required this.supervisor,
    required this.point,
    required this.distanceMeters,
  });
}

class _SupervisorMapAvatar extends StatelessWidget {
  const _SupervisorMapAvatar({
    required this.supervisor,
    required this.distanceMeters,
  });

  final ProjectSupervisorEntity supervisor;
  final int distanceMeters;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF1E3A8A), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: (supervisor.photo != null && supervisor.photo!.isNotEmpty)
                ? Image.network(
                    supervisor.photo!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded),
                  )
                : const Icon(Icons.person_rounded),
          ),
        ),
        SizedBox(width: 4.tw),
        Container(
          constraints: BoxConstraints(maxWidth: 105.tw),
          padding: EdgeInsets.symmetric(horizontal: 7.tw, vertical: 3.th),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(14.tr),
            border: Border.all(color: const Color(0xFFC7D2FE)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  supervisor.employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 8.5.tsp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
              SizedBox(width: 4.tw),
              Text(
                '${distanceMeters}m',
                style: GoogleFonts.poppins(
                  fontSize: 7.5.tsp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
