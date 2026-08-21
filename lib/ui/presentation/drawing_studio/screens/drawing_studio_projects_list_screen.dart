import 'package:el_race/core/drawing_studio/drawing_studio_api_client.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_project.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_route_names.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/drawing_studio/widgets/drawing_studio_chrome_header.dart';
import 'package:el_race/ui/presentation/drawing_studio/widgets/drawing_studio_project_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full projects list — `GET /projects?limit=20`.
class DrawingStudioProjectsListScreen extends StatefulWidget {
  const DrawingStudioProjectsListScreen({super.key});

  @override
  State<DrawingStudioProjectsListScreen> createState() =>
      _DrawingStudioProjectsListScreenState();
}

class _DrawingStudioProjectsListScreenState
    extends State<DrawingStudioProjectsListScreen> {
  final _api = DrawingStudioApiClient();
  bool _loading = true;
  String? _error;
  List<DrawingStudioProject> _projects = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final projects = await _api.listProjects(limit: 20);
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loading = false;
      });
    } on DrawingStudioApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load projects.';
        _loading = false;
      });
    }
  }

  void _openProject(DrawingStudioProject project) {
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
          const DrawingStudioChromeHeader(),
          const DrawingStudioHeadingCard(title: 'All projects'),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.usp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF5A6A82),
                ),
              ),
              SizedBox(height: 14.uh),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_projects.isEmpty) {
      return Center(
        child: Text(
          'No projects yet. Create one from the studio home.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13.usp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF7A849C),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16.w, 10.uh, 16.w, 28.uh),
        itemCount: _projects.length,
        separatorBuilder: (_, __) => SizedBox(height: 8.uh),
        itemBuilder: (context, index) {
          final project = _projects[index];
          return DrawingStudioProjectTile(
            project: project,
            onTap: () => _openProject(project),
          );
        },
      ),
    );
  }
}
