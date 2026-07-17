import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:async';

import 'package:el_race/ui/presentation/Attendace_list/repository/attendance_repository.dart';
import 'package:el_race/ui/presentation/attendance_reports/models/attendance_record_item.dart';
import 'package:el_race/ui/presentation/attendance_reports/theme/attendance_dashboard_theme.dart';
import 'package:el_race/ui/presentation/attendance_reports/utils/attendance_format_utils.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_network_avatar.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

const _kPrimary = Color(0xFF1E4DB7);
const _kSkyLight = Color(0xFFEEF4FF);
const _kSkyMid = Color(0xFFDEEAFF);

/// Opens a bottom-to-top draggable sheet for stat-box filtered records.
Future<void> showAttendanceStatRecordsSheet(
  BuildContext context, {
  required String attendanceType,
  required DateTime dateFrom,
  required DateTime dateTo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _StatRecordsSheet(
      attendanceType: attendanceType,
      dateFrom: dateFrom,
      dateTo: dateTo,
      title: attendanceStatSheetTitle(attendanceType),
    ),
  );
}

class _StatRecordsSheet extends StatefulWidget {
  const _StatRecordsSheet({
    required this.attendanceType,
    required this.dateFrom,
    required this.dateTo,
    required this.title,
  });

  final String attendanceType;
  final DateTime dateFrom;
  final DateTime dateTo;
  final String title;

  @override
  State<_StatRecordsSheet> createState() => _StatRecordsSheetState();
}

class _StatRecordsSheetState extends State<_StatRecordsSheet> {
  static const _pageSize = 50;

  final _repo = sl.get<AttendanceRepo>();
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();

  String _keyword = '';
  Timer? _debounce;

  List<AttendanceRecordItem> _records = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _offset = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _keyword = _searchCtrl.text.trim();
      _load(reset: true);
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 180 &&
        !_loading &&
        _hasMore) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _offset = 0;
      _hasMore = true;
    }
    if (!_hasMore && !reset) return;

    setState(() {
      _loading = true;
      _error = null;
      if (reset) _records = [];
    });

    try {
      final fmt = DateFormat('yyyy-MM-dd');
      final raw = await _repo.getAttendanceRecords(
        dateFrom: fmt.format(widget.dateFrom),
        dateTo: fmt.format(widget.dateTo),
        keyword: _keyword.isEmpty ? null : _keyword,
        attendanceType:
            widget.attendanceType == 'all' ? null : widget.attendanceType,
        limit: _pageSize,
        offset: _offset,
      );

      final rawList = (raw['records'] as List? ?? [])
          .map((e) => AttendanceRecordItem.fromMap(
              Map<String, dynamic>.from(e as Map)))
          .toList();

      // Deduplicate: for same employee + same check_date keep only the record
      // with the most worked hours (handles duplicate hr.attendance rows from backend).
      final deduped = <String, AttendanceRecordItem>{};
      for (final rec in rawList) {
        final key = '${rec.employeeId}_${rec.checkDate.year}-${rec.checkDate.month}-${rec.checkDate.day}';
        final existing = deduped[key];
        if (existing == null || rec.workedHours > existing.workedHours) {
          deduped[key] = rec;
        }
      }
      final list = deduped.values.toList();

      final total = (raw['total'] as int?) ?? 0;

      if (!mounted) return;
      setState(() {
        _total = total;
        _offset += list.length;
        _records = reset ? list : [..._records, ...list];
        _hasMore = _records.length < total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, dragScroll) {
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_kSkyLight, Color(0xFFF8FAFF), Colors.white],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.tr)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(height: 10.th),
              Container(
                width: 40.tw,
                height: 4.th,
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              SizedBox(height: 14.th),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.tw),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 17.tsp,
                          fontWeight: FontWeight.w800,
                          color: _kPrimary,
                        ),
                      ),
                    ),
                    if (_total > 0)
                      Text(
                        '$_total',
                        style: TextStyle(
                          fontSize: 12.tsp,
                          fontWeight: FontWeight.w700,
                          color: AttendanceDashboardTheme.textMuted,
                        ),
                      ),
                    SizedBox(width: 8.tw),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32.tw,
                        height: 32.tw,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _kPrimary.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Icon(Icons.close_rounded,
                            size: 18.tsp, color: _kPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.th),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.tw),
                child: _SheetSearchField(controller: _searchCtrl),
              ),
              SizedBox(height: 10.th),
              if (_error != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18.tw),
                  child: _SheetErrorBanner(
                    message: _error!,
                    onRetry: () => _load(reset: true),
                  ),
                ),
              Expanded(
                child: _loading && _records.isEmpty
                    ? const _SheetSkeletonList()
                    : _records.isEmpty
                        ? const _SheetEmptyState()
                        : RefreshIndicator(
                            color: _kPrimary,
                            onRefresh: () => _load(reset: true),
                            child: ListView.separated(
                              controller: _scroll,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(18.tw, 4.th, 18.tw, 28.th),
                              itemCount:
                                  _records.length + (_loading ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: 12.th),
                              itemBuilder: (_, i) {
                                if (i >= _records.length) {
                                  return Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(12.th),
                                      child: SizedBox(
                                        width: 22.tw,
                                        height: 22.tw,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _kPrimary,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return _SheetRecordRow(record: _records[i]);
                              },
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── One row: date tag + glassy record card (date tag on every row) ──────────

class _SheetRecordRow extends StatelessWidget {
  const _SheetRecordRow({required this.record});
  final AttendanceRecordItem record;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BlueDateTag(date: record.checkDate),
          SizedBox(width: 10.tw),
          Expanded(child: _GlassRecordCard(record: record)),
        ],
      ),
    );
  }
}

class _BlueDateTag extends StatelessWidget {
  const _BlueDateTag({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46.tw,
      padding: EdgeInsets.symmetric(vertical: 8.th, horizontal: 4.tw),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _kSkyMid,
            Colors.white.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(10.tr),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('MMM').format(date),
            style: TextStyle(
              fontSize: 9.tsp,
              fontWeight: FontWeight.w700,
              color: _kPrimary.withValues(alpha: 0.65),
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 2.th),
          Text(
            DateFormat('dd').format(date),
            style: TextStyle(
              fontSize: 18.tsp,
              fontWeight: FontWeight.w900,
              color: _kPrimary,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassRecordCard extends StatelessWidget {
  const _GlassRecordCard({required this.record});
  final AttendanceRecordItem record;

  @override
  Widget build(BuildContext context) {
    final badge = attendanceRecordBadge(
      record.dayStatus,
      record.attendanceType,
      record.statusClock,
    );
    final detailRows = attendanceRecordDetailRows(record);
    final timeLabel = formatAttendanceClock(record.checkIn);
    final dateLabel = record.requestDate != null
        ? formatAttendanceDateTime(record.requestDate!)
        : formatAttendanceDate(record.checkIn);

    return Container(
      padding: EdgeInsets.fromLTRB(12.tw, 12.th, 12.tw, 12.th),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.96),
            _kSkyLight.withValues(alpha: 0.88),
            _kSkyMid.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(14.tr),
        border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GlassIconCircle(
                child: AttendanceNetworkAvatar(
                  radius: 15.tr,
                  imageUrl: record.employeeImageUrl,
                  fallback: Text(
                    record.employeeName.isNotEmpty
                        ? record.employeeName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 10.tsp,
                      fontWeight: FontWeight.w800,
                      color: _kPrimary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.employeeName,
                      style: TextStyle(
                        fontSize: 12.tsp,
                        fontWeight: FontWeight.w700,
                        color: AttendanceDashboardTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (record.empIdCode != null &&
                        record.empIdCode!.trim().isNotEmpty)
                      Text(
                        record.empIdCode!.trim(),
                        style: TextStyle(
                          fontSize: 10.tsp,
                          fontWeight: FontWeight.w500,
                          color: AttendanceDashboardTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (record.needsReview)
                _GlassIconCircle(
                  size: 28,
                  child: Icon(Icons.flag_rounded,
                      size: 14.tsp, color: const Color(0xFFDB2777)),
                ),
            ],
          ),
          SizedBox(height: 8.th),
          Row(
            children: [
              _CategoryBadge(badge: badge),
              if (record.hasRequestRef) ...[
                SizedBox(width: 6.tw),
                Flexible(
                  child: _RequestRefBadge(label: record.requestRefLabel),
                ),
              ],
            ],
          ),
          if (detailRows.isNotEmpty) ...[
            SizedBox(height: 8.th),
            _GlassDetailPanel(rows: detailRows),
          ],
          SizedBox(height: 8.th),
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GlassIconCircle(
                    size: 22,
                    child: Icon(Icons.schedule_rounded,
                        size: 12.tsp, color: _kPrimary.withValues(alpha: 0.7)),
                  ),
                  SizedBox(width: 6.tw),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 11.tsp,
                      color: AttendanceDashboardTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 11.tsp,
                  color: AttendanceDashboardTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlassIconCircle extends StatelessWidget {
  const _GlassIconCircle({required this.child, this.size = 34});
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.tw,
      height: size.tw,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95),
            _kSkyMid.withValues(alpha: 0.7),
          ],
        ),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _RequestRefBadge extends StatelessWidget {
  const _RequestRefBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 4.th),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kPrimary.withValues(alpha: 0.12),
            _kPrimary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(8.tr),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tag_rounded, size: 12.tsp, color: _kPrimary),
          SizedBox(width: 4.tw),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.tsp,
              fontWeight: FontWeight.w700,
              color: _kPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassDetailPanel extends StatelessWidget {
  const _GlassDetailPanel({required this.rows});
  final List<AttendanceRecordDetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10.tr),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: _kPrimary.withValues(alpha: 0.06),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 7.th),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      rows[i].label,
                      style: TextStyle(
                        fontSize: 10.tsp,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Text(
                      rows[i].value,
                      style: TextStyle(
                        fontSize: 10.tsp,
                        fontWeight: FontWeight.w600,
                        color: AttendanceDashboardTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.badge});
  final AttendanceRecordBadge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 3.th),
      decoration: BoxDecoration(
        color: badge.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: badge.color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.tw,
            height: 6.tw,
            decoration: BoxDecoration(
              color: badge.color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 5.tw),
          Text(
            badge.label,
            style: TextStyle(
              fontSize: 11.tsp,
              fontWeight: FontWeight.w700,
              color: badge.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSearchField extends StatelessWidget {
  const _SheetSearchField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14.tr),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Search employee…',
          hintStyle: TextStyle(
            color: AttendanceDashboardTheme.textMuted,
            fontSize: 13.tsp,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20.tsp,
            color: _kPrimary.withValues(alpha: 0.5),
          ),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 14.tw, vertical: 13.th),
        ),
      ),
    );
  }
}

class _SheetEmptyState extends StatelessWidget {
  const _SheetEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded,
              size: 48.tsp, color: _kPrimary.withValues(alpha: 0.2)),
          SizedBox(height: 10.th),
          Text(
            'No records found',
            style: TextStyle(
              fontSize: 14.tsp,
              fontWeight: FontWeight.w700,
              color: AttendanceDashboardTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetErrorBanner extends StatelessWidget {
  const _SheetErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.th),
      padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 8.th),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10.tr),
        border: Border.all(
          color: const Color(0xFFDC2626).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11.tsp, color: const Color(0xFFDC2626)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SheetSkeletonList extends StatefulWidget {
  const _SheetSkeletonList();

  @override
  State<_SheetSkeletonList> createState() => _SheetSkeletonListState();
}

class _SheetSkeletonListState extends State<_SheetSkeletonList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.8).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ListView.separated(
        padding: EdgeInsets.fromLTRB(18.tw, 8.th, 18.tw, 24.th),
        itemCount: 5,
        separatorBuilder: (_, __) => SizedBox(height: 12.th),
        itemBuilder: (_, __) => Row(
          children: [
            Container(
              width: 46.tw,
              height: 52.th,
              decoration: BoxDecoration(
                color: _kSkyMid.withValues(alpha: _anim.value),
                borderRadius: BorderRadius.circular(10.tr),
              ),
            ),
            SizedBox(width: 10.tw),
            Expanded(
              child: Container(
                height: 88.th,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: _anim.value),
                  borderRadius: BorderRadius.circular(14.tr),
                  border: Border.all(
                    color: _kPrimary.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
