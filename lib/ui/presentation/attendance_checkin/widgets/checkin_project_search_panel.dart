import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact right-side project search panel inside the map area.
class CheckinProjectSearchPanel extends StatefulWidget {
  const CheckinProjectSearchPanel({
    super.key,
    required this.projects,
    required this.selectedProjectId,
    required this.onProjectSelected,
    required this.onClose,
  });

  final List<CheckinAllowedProject> projects;
  final int? selectedProjectId;
  final ValueChanged<CheckinAllowedProject> onProjectSelected;
  final VoidCallback onClose;

  @override
  State<CheckinProjectSearchPanel> createState() =>
      _CheckinProjectSearchPanelState();
}

class _CheckinProjectSearchPanelState extends State<CheckinProjectSearchPanel> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocus = FocusNode();

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  List<CheckinAllowedProject> get _filtered {
    final q = _queryController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.projects;
    return widget.projects.where((project) {
      return project.name.toLowerCase().contains(q) ||
          project.woRefNo.toLowerCase().contains(q) ||
          project.projectId.toString().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Material(
      color: Colors.white.withValues(alpha: 0.97),
      elevation: 10,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(14.r),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 10.h, 4.w, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Projects',
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: HomeGlassTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close,
                    size: 20.sp,
                    color: HomeGlassTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 8.h),
            child: TextField(
              controller: _queryController,
              focusNode: _queryFocus,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: HomeGlassTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Name or number',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  color: HomeGlassTheme.textSecondary,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18.sp,
                  color: HomeGlassTheme.textSecondary,
                ),
                filled: true,
                fillColor: const Color(0xFFF3F5F8),
                contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No projects found',
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        color: HomeGlassTheme.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.only(bottom: 8.h),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      indent: 12.w,
                      endIndent: 12.w,
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) {
                      final project = filtered[index];
                      final isSelected =
                          project.projectId == widget.selectedProjectId;
                      return InkWell(
                        onTap: () {
                          widget.onProjectSelected(project);
                          widget.onClose();
                        },
                        child: Container(
                          color: isSelected
                              ? HomeGlassTheme.maroon.withValues(alpha: 0.05)
                              : null,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: HomeGlassTheme.textPrimary,
                                ),
                              ),
                              if (project.woRefNo.isNotEmpty) ...[
                                SizedBox(height: 2.h),
                                Text(
                                  project.woRefNo,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.sp,
                                    color: HomeGlassTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
