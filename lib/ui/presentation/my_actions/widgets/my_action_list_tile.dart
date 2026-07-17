import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_action_employee_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MyActionListTile extends StatelessWidget {
  const MyActionListTile({
    super.key,
    required this.item,
    required this.theme,
    required this.onTap,
    this.compact = false,
    this.subtitle,
  });

  final MyActionItem item;
  final MyActionsModuleTheme theme;
  final VoidCallback onTap;
  final bool compact;
  final String? subtitle;

  String get _title {
    if (item.reference?.trim().isNotEmpty == true) return item.reference!.trim();
    if (item.name.trim().isNotEmpty) return item.name.trim();
    return 'Request #${item.id}';
  }

  String get _subtitle {
    if (subtitle != null && subtitle!.trim().isNotEmpty) return subtitle!.trim();
    if (item.requestType?.trim().isNotEmpty == true) {
      return item.requestType!.trim();
    }
    if (item.project?.trim().isNotEmpty == true) return item.project!.trim();
    return item.employeeName.trim().isNotEmpty
        ? item.employeeName.trim()
        : 'Request';
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
    if (parsed == null) return raw.trim();
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = MyActionsModuleTheme.statusColor(item.status);
    final dateLabel = _formatDate(item.date);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 16.tr : 20.tr),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14.tw : 16.tw,
            vertical: compact ? 12.th : 14.th,
          ),
          decoration: theme.glassCard(radius: compact ? 16 : 20),
          child: Row(
            children: [
              MyActionEmployeeAvatar.circle(
                imageUrl: item.employeeImage,
                statusColor: statusColor,
                fallbackTint: theme.tint,
                fallbackIcon: theme.primary.withValues(alpha: 0.65),
              ),
              SizedBox(width: 12.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.cardTitle.copyWith(
                        fontSize: compact ? 14.tsp : 15.tsp,
                      ),
                    ),
                    SizedBox(height: 3.th),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.cardSubtitle,
                    ),
                    if (dateLabel.isNotEmpty) ...[
                      SizedBox(height: 2.th),
                      Text(
                        dateLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          color: MyActionsModuleTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.tw),
              _StatusPill(status: item.status, color: statusColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = status.trim().isEmpty ? 'Pending' : status.trim();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 5.th),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10.tsp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
