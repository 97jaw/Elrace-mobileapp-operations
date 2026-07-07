import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_documents_breadcrumb.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_kind_heading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showProjectDocumentsBreadcrumbSheet(
  BuildContext parentContext, {
  required List<ProjectDocumentsBreadcrumb> trail,
}) {
  return showDialog<void>(
    context: parentContext,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => ProjectDocumentsBreadcrumbSheet(
      trail: trail,
      parentContext: parentContext,
    ),
  );
}

class ProjectDocumentsBreadcrumbSheet extends StatelessWidget {
  const ProjectDocumentsBreadcrumbSheet({
    super.key,
    required this.trail,
    required this.parentContext,
  });

  final List<ProjectDocumentsBreadcrumb> trail;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 48.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 360.w, maxHeight: 480.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ProjectsDashboardTheme.navy.withValues(alpha: 0.92),
              ProjectsDashboardTheme.navy.withValues(alpha: 0.78),
              ProjectsDashboardTheme.greyDeep.withValues(alpha: 0.88),
            ],
          ),
          border: Border.all(
            color: ProjectsDashboardTheme.white.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(18.w, 16.h, 12.w, 10.h),
                child: Row(
                  children: [
                    Icon(
                      Icons.route_rounded,
                      size: 20.sp,
                      color: ProjectsDashboardTheme.white.withValues(alpha: 0.9),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Path hierarchy',
                        style: GoogleFonts.poppins(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: ProjectsDashboardTheme.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: ProjectsDashboardTheme.white.withValues(alpha: 0.8),
                        size: 22.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: ProjectsDashboardTheme.white.withValues(alpha: 0.12),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 18.h),
                  child: Column(
                    children: [
                      for (var i = 0; i < trail.length; i++)
                        _BreadcrumbNode(
                          item: trail[i],
                          isFirst: i == 0,
                          isLast: i == trail.length - 1,
                          isCurrent: i == trail.length - 1,
                          onTap: i == trail.length - 1
                              ? null
                              : () {
                                  final targetIndex = i;
                                  final navContext = parentContext;
                                  final trailCopy =
                                      List<ProjectDocumentsBreadcrumb>.from(
                                    trail,
                                  );
                                  Navigator.of(context).pop();
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) {
                                      if (!navContext.mounted) return;
                                      ProjectDocumentsBreadcrumb.navigateTo(
                                        navContext,
                                        trail: trailCopy,
                                        targetIndex: targetIndex,
                                      );
                                    },
                                  );
                                },
                        ),
                    ],
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

class _BreadcrumbNode extends StatelessWidget {
  const _BreadcrumbNode({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.isCurrent,
    this.onTap,
  });

  final ProjectDocumentsBreadcrumb item;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34.w,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: ProjectsDashboardTheme.white.withValues(alpha: 0.22),
                    ),
                  ),
                _NodeDot(isCurrent: isCurrent),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: ProjectsDashboardTheme.white.withValues(alpha: 0.22),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12.h),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      color: isCurrent
                          ? ProjectsDashboardTheme.white.withValues(alpha: 0.14)
                          : onTap != null
                              ? ProjectsDashboardTheme.white.withValues(alpha: 0.06)
                              : Colors.transparent,
                      border: Border.all(
                        color: isCurrent
                            ? ProjectsDashboardTheme.white.withValues(alpha: 0.28)
                            : ProjectsDashboardTheme.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        _NodeIcon(item: item, isCurrent: isCurrent),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13.sp,
                              fontWeight:
                                  isCurrent ? FontWeight.w600 : FontWeight.w500,
                              color: ProjectsDashboardTheme.white.withValues(
                                alpha: isCurrent ? 1 : 0.88,
                              ),
                            ),
                          ),
                        ),
                        if (onTap != null)
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18.sp,
                            color: ProjectsDashboardTheme.white.withValues(alpha: 0.5),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeDot extends StatelessWidget {
  const _NodeDot({required this.isCurrent});

  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10.w,
      height: 10.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrent
            ? ProjectsDashboardTheme.maroonSoft
            : ProjectsDashboardTheme.white.withValues(alpha: 0.35),
        border: Border.all(
          color: ProjectsDashboardTheme.white.withValues(alpha: 0.65),
          width: 1.5,
        ),
      ),
    );
  }
}

class _NodeIcon extends StatelessWidget {
  const _NodeIcon({required this.item, required this.isCurrent});

  final ProjectDocumentsBreadcrumb item;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final size = isCurrent ? 26.0 : 22.0;

    return switch (item.type) {
      ProjectDocumentsBreadcrumbType.home => Icon(
          Icons.home_rounded,
          size: size.sp,
          color: ProjectsDashboardTheme.white.withValues(alpha: 0.92),
        ),
      ProjectDocumentsBreadcrumbType.kind when item.kind != null =>
        ProjectDocumentsIcons.image(kind: item.kind, size: size),
      ProjectDocumentsBreadcrumbType.project => Icon(
          Icons.work_outline_rounded,
          size: size.sp,
          color: ProjectsDashboardTheme.white.withValues(alpha: 0.88),
        ),
      ProjectDocumentsBreadcrumbType.uploader => Icon(
          Icons.person_rounded,
          size: size.sp,
          color: ProjectsDashboardTheme.white.withValues(alpha: 0.88),
        ),
      ProjectDocumentsBreadcrumbType.sharePointFolder ||
      ProjectDocumentsBreadcrumbType.kind =>
        ProjectDocumentsIcons.image(
          kind: ProjectDocumentHubKind.cloud,
          isFolder: true,
          size: size,
        ),
    };
  }
}
