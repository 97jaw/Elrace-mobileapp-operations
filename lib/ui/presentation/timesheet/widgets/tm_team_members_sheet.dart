import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

abstract final class TmTeamMembersSheet {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<TimesheetTeamMember> members,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TmTeamMembersSheetBody(
        title: title,
        members: members,
      ),
    );
  }
}

class _TmTeamMembersSheetBody extends StatelessWidget {
  const _TmTeamMembersSheetBody({
    required this.title,
    required this.members,
  });

  final String title;
  final List<TimesheetTeamMember> members;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                TimesheetModuleColors.navy,
                TimesheetModuleColors.primaryGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TimesheetModuleTypography.h2().copyWith(
                          color: TimesheetModuleColors.surface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        PhosphorIcons.x(),
                        color: TimesheetModuleColors.surface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: members.isEmpty
                    ? Center(
                        child: Text(
                          'No records',
                          style: TimesheetModuleTypography.body().copyWith(
                            color: TimesheetModuleColors.surface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: members.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final member = members[index];
                          return _MemberTile(member: member);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final TimesheetTeamMember member;

  @override
  Widget build(BuildContext context) {
    final url = member.imageUrl?.trim() ?? '';
    final initial = member.name.trim().isEmpty
        ? '?'
        : member.name.trim().characters.first.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.surface.withValues(alpha: 0.12),
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        border: Border.all(
          color: TimesheetModuleColors.surface.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: TimesheetModuleColors.surface.withValues(alpha: 0.6),
              ),
              color: TimesheetModuleColors.primaryTint,
            ),
            clipBehavior: Clip.antiAlias,
            child: url.isNotEmpty
                ? Image.network(url, fit: BoxFit.cover)
                : Center(
                    child: Text(
                      initial,
                      style: TimesheetModuleTypography.h2().copyWith(
                        color: TimesheetModuleColors.surface,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TimesheetModuleTypography.cardTitle().copyWith(
                    color: TimesheetModuleColors.surface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'File ID: ${member.fileId}',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.surface.withValues(alpha: 0.8),
                  ),
                ),
                if (member.subtitle != null && member.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TimesheetModuleTypography.caption().copyWith(
                      color: TimesheetModuleColors.surface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
