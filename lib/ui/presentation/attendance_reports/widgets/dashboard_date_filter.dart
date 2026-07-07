import 'package:el_race/ui/presentation/attendance_reports/providers/attendance_dashboard_provider.dart';
import 'package:el_race/ui/presentation/attendance_reports/theme/attendance_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// Filter chip row — Today / This Week / This Month / Custom▾
class DashboardDateFilterBar extends StatelessWidget {
  const DashboardDateFilterBar({
    super.key,
    required this.selected,
    required this.onSelect,
    this.selectedMonthLabel,
  });

  final DashboardDateFilter selected;
  final String? selectedMonthLabel;
  final void Function(
    DashboardDateFilter filter, {
    DateTime? customFrom,
    DateTime? customTo,
    String? monthLabel,
  }) onSelect;

  static const _months = [
    'January', 'February', 'March', 'April',
    'May', 'June', 'July', 'August',
    'September', 'October', 'November', 'December',
  ];

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CustomPickerSheet(
        year: now.year,
        months: _months,
        onPickMonth: (monthIndex) {
          final from = DateTime(now.year, monthIndex + 1, 1);
          final to = DateTime(now.year, monthIndex + 2, 0);
          onSelect(
            DashboardDateFilter.custom,
            customFrom: from,
            customTo: to,
            monthLabel: _months[monthIndex],
          );
        },
        onPickDay: (day) {
          final d = DateTime(day.year, day.month, day.day);
          final label = DateFormat('d MMM').format(d);
          onSelect(
            DashboardDateFilter.custom,
            customFrom: d,
            customTo: d,
            monthLabel: label,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final f in DashboardDateFilter.values)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: f == DashboardDateFilter.custom
                  ? _CustomChip(
                      label: selected == DashboardDateFilter.custom &&
                              selectedMonthLabel != null
                          ? selectedMonthLabel!
                          : 'Custom',
                      selected: selected == DashboardDateFilter.custom,
                      onTap: () => _pickCustom(context),
                    )
                  : _FilterChip(
                      label: f.label,
                      selected: selected == f,
                      onTap: () => onSelect(f),
                    ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected
              ? AttendanceDashboardTheme.filterActive
              : const Color(0xFFDEEAFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AttendanceDashboardTheme.filterActive
                : AttendanceDashboardTheme.filterActive.withValues(alpha: 0.28),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E4DB7).withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : AttendanceDashboardTheme.filterActive,
          ),
        ),
      ),
    );
  }
}

class _CustomChip extends StatelessWidget {
  const _CustomChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected
              ? AttendanceDashboardTheme.filterActive
              : const Color(0xFFDEEAFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AttendanceDashboardTheme.filterActive
                : AttendanceDashboardTheme.filterActive.withValues(alpha: 0.28),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E4DB7).withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : AttendanceDashboardTheme.filterActive,
              ),
            ),
            SizedBox(width: 3.w),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15.sp,
              color: selected
                  ? Colors.white
                  : AttendanceDashboardTheme.filterActive,
            ),
          ],
        ),
      ),
    );
  }
}

/// Month grid, then optional day grid for the chosen month.
class _CustomPickerSheet extends StatefulWidget {
  const _CustomPickerSheet({
    required this.year,
    required this.months,
    required this.onPickMonth,
    required this.onPickDay,
  });

  final int year;
  final List<String> months;
  final void Function(int monthIndex) onPickMonth;
  final void Function(DateTime day) onPickDay;

  @override
  State<_CustomPickerSheet> createState() => _CustomPickerSheetState();
}

class _CustomPickerSheetState extends State<_CustomPickerSheet> {
  int? _selectedMonthIndex;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: _selectedMonthIndex == null
          ? _buildMonthGrid()
          : _buildDayGrid(_selectedMonthIndex!),
    );
  }

  Widget _buildMonthGrid() {
    final currentMonth = DateTime.now().month - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHandle(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Select Month — ${widget.year}',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: AttendanceDashboardTheme.filterActive,
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
          ),
          itemCount: widget.months.length,
          itemBuilder: (_, i) {
            final isActive = i == currentMonth;
            final isFuture = i > currentMonth;
            return GestureDetector(
              onTap: isFuture
                  ? null
                  : () => setState(() => _selectedMonthIndex = i),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [Color(0xFF1E4DB7), Color(0xFF2563EB)],
                        )
                      : null,
                  color: isActive
                      ? null
                      : isFuture
                          ? const Color(0xFFF9FAFB)
                          : const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(10.r),
                  border: isActive
                      ? null
                      : Border.all(
                          color: isFuture
                              ? const Color(0xFFE5E7EB)
                              : AttendanceDashboardTheme.filterActive
                                  .withValues(alpha: 0.2),
                        ),
                ),
                child: Text(
                  widget.months[i].substring(0, 3),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? Colors.white
                        : isFuture
                            ? const Color(0xFFD1D5DB)
                            : AttendanceDashboardTheme.filterActive,
                  ),
                ),
              ),
            );
          },
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildDayGrid(int monthIndex) {
    final month = monthIndex + 1;
    final daysInMonth = DateTime(widget.year, month + 1, 0).day;
    final monthName = widget.months[monthIndex];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHandle(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedMonthIndex = null),
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18.sp, color: AttendanceDashboardTheme.filterActive),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.w),
              ),
              Expanded(
                child: Text(
                  '$monthName ${widget.year}',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: AttendanceDashboardTheme.filterActive,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onPickMonth(monthIndex);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AttendanceDashboardTheme.filterActive,
                side: BorderSide(
                  color:
                      AttendanceDashboardTheme.filterActive.withValues(alpha: 0.35),
                ),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Entire month',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Or select a day',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AttendanceDashboardTheme.textSecondary,
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 6.w,
            mainAxisSpacing: 6.h,
            childAspectRatio: 1.1,
          ),
          itemCount: daysInMonth,
          itemBuilder: (_, i) {
            final day = i + 1;
            final date = DateTime(widget.year, month, day);
            final isFuture = date.isAfter(_today);
            final isToday = date == _today;

            return GestureDetector(
              onTap: isFuture
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      widget.onPickDay(date);
                    },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isFuture
                      ? const Color(0xFFF9FAFB)
                      : isToday
                          ? AttendanceDashboardTheme.filterActive
                              .withValues(alpha: 0.12)
                          : const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: isToday
                        ? AttendanceDashboardTheme.filterActive
                        : isFuture
                            ? const Color(0xFFE5E7EB)
                            : AttendanceDashboardTheme.filterActive
                                .withValues(alpha: 0.18),
                    width: isToday ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: isFuture
                        ? const Color(0xFFD1D5DB)
                        : isToday
                            ? AttendanceDashboardTheme.filterActive
                            : AttendanceDashboardTheme.filterActive,
                  ),
                ),
              ),
            );
          },
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _sheetHandle() {
    return Column(
      children: [
        SizedBox(height: 14.h),
        Container(
          width: 36.w,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(height: 14.h),
      ],
    );
  }
}
