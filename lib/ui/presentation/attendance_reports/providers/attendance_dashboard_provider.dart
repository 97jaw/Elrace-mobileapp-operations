import 'dart:async';

import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/ui/presentation/Attendace_list/repository/attendance_repository.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Filter enum
// ─────────────────────────────────────────────────────────────────────────────

enum DashboardDateFilter { today, thisWeek, thisMonth, custom }

extension DashboardDateFilterLabel on DashboardDateFilter {
  String get label {
    switch (this) {
      case DashboardDateFilter.today:
        return 'Today';
      case DashboardDateFilter.thisWeek:
        return 'This Week';
      case DashboardDateFilter.thisMonth:
        return 'This Month';
      case DashboardDateFilter.custom:
        return 'Custom';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// State model
// ─────────────────────────────────────────────────────────────────────────────

class AttendanceDashboardStats {
  const AttendanceDashboardStats({
    required this.total,
    required this.onTime,
    required this.late,
    required this.absent,
    required this.jmTp,
    required this.leaves,
    required this.review,
    required this.dateFrom,
    required this.dateTo,
  });

  final int total;
  final int onTime;
  final int late;
  final int absent;
  final int jmTp;
  final int leaves;
  final int review;
  final DateTime dateFrom;
  final DateTime dateTo;

  factory AttendanceDashboardStats.fromMap(Map<String, dynamic> m) {
    int readInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '0') ?? 0;

    DateTime readDate(dynamic v) {
      if (v == null) return DateTime.now();
      final s = v.toString().trim();
      if (s.isEmpty) return DateTime.now();
      final parsed = DateTime.tryParse(s);
      if (parsed != null) return parsed;
      try {
        return DateFormat('yyyy-MM-dd').parse(s);
      } catch (_) {
        return DateTime.now();
      }
    }

    return AttendanceDashboardStats(
      total: readInt(m['total']),
      onTime: readInt(m['on_time']),
      late: readInt(m['late']),
      absent: readInt(m['absent']),
      jmTp: readInt(m['jm_tp']),
      leaves: readInt(m['leaves']),
      review: readInt(m['review']),
      dateFrom: readDate(m['date_from']),
      dateTo: readDate(m['date_to']),
    );
  }

  static AttendanceDashboardStats zero(DateTime from, DateTime to) =>
      AttendanceDashboardStats(
        total: 0,
        onTime: 0,
        late: 0,
        absent: 0,
        jmTp: 0,
        leaves: 0,
        review: 0,
        dateFrom: from,
        dateTo: to,
      );
}

const _unset = Object();

class AttendanceDashboardState {
  const AttendanceDashboardState({
    required this.filter,
    required this.dateFrom,
    required this.dateTo,
    this.stats,
    this.loading = false,
    this.error,
    this.selectedMonthLabel,
  });

  final DashboardDateFilter filter;
  final DateTime dateFrom;
  final DateTime dateTo;
  final AttendanceDashboardStats? stats;
  final bool loading;
  final String? error;
  /// Label shown on the Custom chip when a specific month/day is selected.
  final String? selectedMonthLabel;

  bool get hasData => stats != null;

  AttendanceDashboardState copyWith({
    DashboardDateFilter? filter,
    DateTime? dateFrom,
    DateTime? dateTo,
    AttendanceDashboardStats? stats,
    bool? loading,
    Object? error = _unset,
    Object? selectedMonthLabel = _unset,
  }) {
    return AttendanceDashboardState(
      filter: filter ?? this.filter,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      stats: stats ?? this.stats,
      loading: loading ?? this.loading,
      error: identical(error, _unset) ? this.error : error as String?,
      selectedMonthLabel: identical(selectedMonthLabel, _unset)
          ? this.selectedMonthLabel
          : selectedMonthLabel as String?,
    );
  }

  static AttendanceDashboardState initial() {
    final range = _dateRangeFor(DashboardDateFilter.today);
    return AttendanceDashboardState(
      filter: DashboardDateFilter.today,
      dateFrom: range.$1,
      dateTo: range.$2,
      loading: true,
    );
  }
}

(DateTime, DateTime) _dateRangeFor(
  DashboardDateFilter filter, {
  DateTime? customFrom,
  DateTime? customTo,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  switch (filter) {
    case DashboardDateFilter.today:
      return (today, today);
    case DashboardDateFilter.thisWeek:
      final weekday = now.weekday == DateTime.sunday ? 7 : now.weekday;
      return (today.subtract(Duration(days: weekday - 1)), today);
    case DashboardDateFilter.thisMonth:
      return (DateTime(now.year, now.month, 1), today);
    case DashboardDateFilter.custom:
      final from = customFrom ?? DateTime(now.year, now.month, 1);
      final to = customTo ?? DateTime(from.year, from.month + 1, 0);
      return (from, to);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

final attendanceDashboardProvider =
    AsyncNotifierProvider<AttendanceDashboardNotifier, AttendanceDashboardState>(
  AttendanceDashboardNotifier.new,
);

class AttendanceDashboardNotifier
    extends AsyncNotifier<AttendanceDashboardState> {
  int _requestSeq = 0;

  @override
  Future<AttendanceDashboardState> build() async {
    // Rebuild + reset when login session changes (logout / re-login).
    ref.watch(loginSessionRevisionProvider);
    // Reset sequence so in-flight requests from the previous session are ignored.
    _requestSeq = 0;
    // Return initial loading state immediately; the actual fetch is triggered by
    // a microtask so it never races with the build() return value.
    Future.microtask(_triggerInitialLoad);
    return AttendanceDashboardState.initial();
  }

  Future<void> _triggerInitialLoad() async {
    // Only load if we're still in the initial (no stats) state.
    final current = state.asData?.value;
    if (current?.stats != null) return;
    await applyFilter(DashboardDateFilter.today);
  }

  /// Called from initState as an extra safety net (no-op if data already loaded).
  Future<void> ensureTodayLoaded() async {
    final current = state.asData?.value;
    if (current?.stats != null && !state.hasError) return;
    // Don't override if user already manually selected a different filter.
    if (current != null && current.filter != DashboardDateFilter.today && current.stats != null) return;
    await applyFilter(DashboardDateFilter.today);
  }

  Future<void> applyFilter(
    DashboardDateFilter filter, {
    DateTime? customFrom,
    DateTime? customTo,
    String? monthLabel,
  }) async {
    final range = _dateRangeFor(
      filter,
      customFrom: customFrom,
      customTo: customTo,
    );

    final prev = state.asData?.value ?? AttendanceDashboardState.initial();
    final next = prev.copyWith(
      filter: filter,
      dateFrom: range.$1,
      dateTo: range.$2,
      loading: true,
      error: null,
      selectedMonthLabel:
          filter == DashboardDateFilter.custom ? monthLabel : null,
    );

    await _commitFetch(next);
  }

  Future<void> refresh() async {
    final prev = state.asData?.value ?? AttendanceDashboardState.initial();
    await _commitFetch(prev.copyWith(loading: true, error: null));
  }

  Future<void> _commitFetch(AttendanceDashboardState pending) async {
    state = AsyncData(pending);
    final seq = ++_requestSeq;
    try {
      final repo = sl.get<AttendanceRepo>();
      final result = await _fetch(repo, pending);
      if (seq != _requestSeq) return;
      state = AsyncData(result);
    } catch (e, st) {
      if (seq != _requestSeq) return;
      debugPrint('[ATTENDANCE_DASHBOARD] fetch failed: $e\n$st');
      state = AsyncData(
        pending.copyWith(loading: false, error: e.toString()),
      );
    }
  }

  Future<AttendanceDashboardState> _fetch(
    AttendanceRepo repo,
    AttendanceDashboardState s,
  ) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final rawMap = await repo.getDashboardStats(
      dateFrom: fmt.format(s.dateFrom),
      dateTo: fmt.format(s.dateTo),
    );
    final stats = AttendanceDashboardStats.fromMap(rawMap);
    if (kDebugMode) {
      debugPrint(
        '[ATTENDANCE_DASHBOARD] ${s.filter.name} '
        '${fmt.format(s.dateFrom)}→${fmt.format(s.dateTo)} '
        'total=${stats.total}',
      );
    }
    return s.copyWith(stats: stats, loading: false, error: null);
  }
}
