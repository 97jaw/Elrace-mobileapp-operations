import 'package:el_race/core/drawing_studio/drawing_studio_access.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_api_client.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_project.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_route_names.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_token_storage.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/drawing_studio/widgets/drawing_studio_chrome_header.dart';
import 'package:el_race/ui/presentation/drawing_studio/widgets/drawing_studio_coming_soon_dialog.dart';
import 'package:el_race/ui/presentation/drawing_studio/widgets/drawing_studio_password_sheet.dart';
import 'package:el_race/ui/presentation/drawing_studio/widgets/drawing_studio_project_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// AI Drawing Studio home — modes + recent projects (`GET /projects?limit=3`).
class DrawingStudioAuthorizeScreen extends StatefulWidget {
  const DrawingStudioAuthorizeScreen({super.key});

  @override
  State<DrawingStudioAuthorizeScreen> createState() =>
      _DrawingStudioAuthorizeScreenState();
}

class _DrawingStudioAuthorizeScreenState
    extends State<DrawingStudioAuthorizeScreen> {
  final _api = DrawingStudioApiClient();

  bool _checkingSession = true;
  bool _authorized = false;

  bool _loadingProjects = false;
  String? _projectsError;
  List<DrawingStudioProject> _recentProjects = const [];

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final hasSession = await DrawingStudioTokenStorage.instance.hasSession();
    if (!mounted) return;
    setState(() {
      _authorized = hasSession;
      _checkingSession = false;
    });
    if (hasSession) {
      await _loadRecentProjects();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureAuthorized();
      });
    }
  }

  Future<bool> _ensureAuthorized() async {
    if (_authorized) return true;

    final email = DrawingStudioAccess.cognitoEmail();
    if (email == null) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cognito email is missing. Contact your administrator.'),
        ),
      );
      return false;
    }

    final ok = await showDrawingStudioAuthorizeDialog(
      context: context,
      email: email,
    );
    if (!mounted) return false;
    if (ok == true) {
      setState(() => _authorized = true);
      await _loadRecentProjects();
      return true;
    }
    return false;
  }

  Future<void> _loadRecentProjects() async {
    setState(() {
      _loadingProjects = true;
      _projectsError = null;
    });
    try {
      final projects = await _api.listProjects(limit: 3);
      if (!mounted) return;
      setState(() {
        _recentProjects = projects;
        _loadingProjects = false;
      });
    } on DrawingStudioApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _projectsError = e.message;
        _loadingProjects = false;
        if (e.statusCode == 401) {
          _authorized = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _projectsError = 'Unable to load recent projects.';
        _loadingProjects = false;
      });
    }
  }

  Future<void> _onOptionTap(int index) async {
    final ok = await _ensureAuthorized();
    if (!ok || !mounted) return;

    if (index == 2) {
      await showDrawingStudioComingSoonDialog(
        context: context,
        title: '2D / Image upload',
        message:
            'Image upload will open here soon. Form and AI Creation are available now.',
      );
      return;
    }

    final route = index == 0
        ? DrawingStudioRouteNames.form
        : DrawingStudioRouteNames.aiCreation;
    Navigator.of(context).pushNamed(route);
  }

  Future<void> _onViewAll() async {
    final ok = await _ensureAuthorized();
    if (!ok || !mounted) return;
    Navigator.of(context).pushNamed(DrawingStudioRouteNames.projectsList);
  }

  Future<void> _onOpenProject(DrawingStudioProject project) async {
    final ok = await _ensureAuthorized();
    if (!ok || !mounted) return;
    Navigator.of(context).pushNamed(
      DrawingStudioRouteNames.projectDetail,
      arguments: project,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawingStudioChromeHeader(
            trailing: (!_authorized && !_checkingSession)
                ? [
                    TextButton(
                      onPressed: _ensureAuthorized,
                      child: Text(
                        'Authorize',
                        style: GoogleFonts.poppins(
                          fontSize: 12.usp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A2A4F),
                        ),
                      ),
                    ),
                  ]
                : const [],
          ),
          const DrawingStudioHeadingCard(
            title: 'Elrace AI Drawing Studio',
            subtitle: 'Create · Generate · Open folder',
          ),
          Expanded(
            child: _checkingSession
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      final ok = await _ensureAuthorized();
                      if (ok) await _loadRecentProjects();
                    },
                    child: _buildBody(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 28.uh),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OptionCard(
            icon: Icons.assignment_outlined,
            iconColor: const Color(0xFF7C3AED),
            title: 'Build via Form',
            sloganLine1: 'Create a drawing project',
            sloganLine2: 'with structured fields.',
            onTap: () => _onOptionTap(0),
          ),
          SizedBox(height: 10.uh),
          _OptionCard(
            icon: Icons.auto_awesome_outlined,
            iconColor: const Color(0xFF0D9488),
            title: 'AI Creation',
            sloganLine1: 'Describe what you need',
            sloganLine2: 'and let AI generate it.',
            onTap: () => _onOptionTap(1),
          ),
          SizedBox(height: 10.uh),
          _OptionCard(
            icon: Icons.image_outlined,
            iconColor: const Color(0xFF2563EB),
            title: '2D / Image upload',
            sloganLine1: 'Upload a 2D drawing',
            sloganLine2: 'or image to start from.',
            onTap: () => _onOptionTap(2),
          ),
          SizedBox(height: 26.uh),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent projects',
                  style: GoogleFonts.poppins(
                    fontSize: 15.usp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A2A4F),
                  ),
                ),
              ),
              TextButton(
                onPressed: _onViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View all',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5.usp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3E7BFA),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.uh),
          _buildRecentSection(),
        ],
      ),
    );
  }

  Widget _buildRecentSection() {
    if (!_authorized) {
      return _EmptyRecent(
        message: 'Authorize to see your recent projects.',
        actionLabel: 'Authorize',
        onAction: _ensureAuthorized,
      );
    }
    if (_loadingProjects) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 28.uh),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_projectsError != null) {
      return _EmptyRecent(
        message: _projectsError!,
        actionLabel: 'Retry',
        onAction: _loadRecentProjects,
      );
    }
    if (_recentProjects.isEmpty) {
      return const _EmptyRecent(
        message: 'No projects yet. Start with Form, AI, or Image upload.',
      );
    }

    return Column(
      children: [
        for (final project in _recentProjects)
          Padding(
            padding: EdgeInsets.only(bottom: 8.uh),
            child: DrawingStudioProjectTile(
              project: project,
              onTap: () => _onOpenProject(project),
            ),
          ),
      ],
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 22.uh),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.ur),
        border: Border.all(color: const Color(0xFFE4E8F0)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5.usp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7A849C),
              height: 1.35,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 10.uh),
            TextButton(
              onPressed: () => onAction!(),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.sloganLine1,
    required this.sloganLine2,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String sloganLine1;
  final String sloganLine2;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14.ur),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.ur),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.uh),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.ur),
            border: Border.all(color: const Color(0xFFE4E8F0)),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 26.usp),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14.usp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A2A4F),
                      ),
                    ),
                    SizedBox(height: 3.uh),
                    Text(
                      sloganLine1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5.usp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF7A849C),
                        height: 1.3,
                      ),
                    ),
                    Text(
                      sloganLine2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5.usp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF7A849C),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFFB0BAC8),
                size: 22.usp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
