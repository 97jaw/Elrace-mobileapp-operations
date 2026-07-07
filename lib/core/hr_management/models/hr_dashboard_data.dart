import 'package:flutter/material.dart';

/// Dashboard aggregates from `POST /api/hr/dashboard`.
class HrDashboardData {
  const HrDashboardData({
    required this.total,
    required this.pending,
    required this.approved,
    this.avgApprovalDays,
    required this.byType,
    required this.byMonth,
    required this.topRequesters,
    required this.byDepartment,
    required this.includeDepartments,
  });

  final int total;
  final int pending;
  final int approved;
  final double? avgApprovalDays;
  final List<HrDashboardTypeSlice> byType;
  final List<HrDashboardMonthBar> byMonth;
  final List<HrDashboardRequester> topRequesters;
  final List<HrDashboardDepartmentShare> byDepartment;
  final bool includeDepartments;

  factory HrDashboardData.fromJson(Map<String, dynamic> json) {
    final kpis = json['kpis'] as Map<String, dynamic>? ?? {};
    double? avg;
    final rawAvg = kpis['avg_approval_days'];
    if (rawAvg is num) {
      avg = rawAvg.toDouble();
    }

    List<T> mapList<T>(
      String key,
      T Function(Map<String, dynamic>) fromMap,
    ) {
      final raw = json[key];
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    return HrDashboardData(
      total: (kpis['total'] as num?)?.toInt() ?? 0,
      pending: (kpis['pending'] as num?)?.toInt() ?? 0,
      approved: (kpis['approved'] as num?)?.toInt() ?? 0,
      avgApprovalDays: avg,
      byType: mapList('by_type', HrDashboardTypeSlice.fromJson),
      byMonth: mapList('by_month', HrDashboardMonthBar.fromJson),
      topRequesters: mapList('top_requesters', HrDashboardRequester.fromJson),
      byDepartment:
          mapList('by_department', HrDashboardDepartmentShare.fromJson),
      includeDepartments: json['include_departments'] == true,
    );
  }

  static const empty = HrDashboardData(
    total: 0,
    pending: 0,
    approved: 0,
    byType: [],
    byMonth: [],
    topRequesters: [],
    byDepartment: [],
    includeDepartments: false,
  );
}

class HrDashboardTypeSlice {
  const HrDashboardTypeSlice({
    required this.filterType,
    required this.label,
    required this.count,
  });

  final String? filterType;
  final String label;
  final int count;

  factory HrDashboardTypeSlice.fromJson(Map<String, dynamic> json) {
    return HrDashboardTypeSlice(
      filterType: json['filter_type'] as String?,
      label: json['label'] as String? ?? 'Other',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class HrDashboardMonthBar {
  const HrDashboardMonthBar({required this.label, required this.value});

  final String label;
  final int value;

  factory HrDashboardMonthBar.fromJson(Map<String, dynamic> json) {
    return HrDashboardMonthBar(
      label: json['label'] as String? ?? '',
      value: (json['value'] as num?)?.toInt() ?? 0,
    );
  }
}

class HrDashboardRequester {
  const HrDashboardRequester({required this.name, required this.count});

  final String name;
  final int count;

  factory HrDashboardRequester.fromJson(Map<String, dynamic> json) {
    return HrDashboardRequester(
      name: json['name'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class HrDashboardDepartmentShare {
  const HrDashboardDepartmentShare({required this.label, required this.share});

  final String label;
  final double share;

  factory HrDashboardDepartmentShare.fromJson(Map<String, dynamic> json) {
    return HrDashboardDepartmentShare(
      label: json['label'] as String? ?? '',
      share: (json['share'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Pie palette aligned with dashboard theme.
const hrDashboardChartColors = [
  Color(0xFF1F3A5F),
  Color(0xFF4A6B8A),
  Color(0xFF8B2635),
  Color(0xFF00897B),
  Color(0xFFE89B4C),
  Color(0xFF6B5B95),
  Color(0xFF2E7D32),
  Color(0xFF5D4037),
];
