import 'package:el_race/ui/presentation/my_reports/models/my_report_type.dart';

class ReportPreviewRow {
  const ReportPreviewRow({
    required this.label,
    required this.value,
    required this.status,
  });

  final String label;
  final String value;
  final String status;
}

class ReportChartPoint {
  const ReportChartPoint({required this.x, required this.y});
  final String x;
  final double y;
}

class ReportAiInsight {
  const ReportAiInsight({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class RetentionHeatRow {
  const RetentionHeatRow({
    required this.label,
    required this.values,
  });

  final String label;
  final List<int> values;
}

class ReportPreviewData {
  const ReportPreviewData({
    required this.summaryValue,
    required this.rows,
    required this.chart,
    required this.insights,
    this.heatmap = const [],
  });

  final String summaryValue;
  final List<ReportPreviewRow> rows;
  final List<ReportChartPoint> chart;
  final List<ReportAiInsight> insights;
  final List<RetentionHeatRow> heatmap;
}

abstract final class MyReportsDemoData {
  static const _defaultInsights = [
    ReportAiInsight(
      title: 'AI trend explanation',
      body:
          'This report shows a stable pattern with a mild upward trend in the selected period.',
    ),
    ReportAiInsight(
      title: 'Potential risk',
      body:
          'One segment is slightly below baseline. AI recommends monitoring it in the next cycle.',
    ),
    ReportAiInsight(
      title: 'Suggested action',
      body: 'Focus on outlier rows first, then review approvals and delayed items.',
    ),
  ];

  static ReportPreviewData forType(MyReportType type, {required String period}) {
    if (type.id == 'invoice_retention') {
      return const ReportPreviewData(
        summaryValue: 'Retention 74%',
        rows: [
          ReportPreviewRow(label: 'Project A', value: '82%', status: 'Good'),
          ReportPreviewRow(label: 'Project B', value: '71%', status: 'Watch'),
          ReportPreviewRow(label: 'Project C', value: '63%', status: 'Review'),
        ],
        chart: [
          ReportChartPoint(x: 'D1', y: 91),
          ReportChartPoint(x: 'D2', y: 79),
          ReportChartPoint(x: 'D3', y: 65),
          ReportChartPoint(x: 'D4', y: 47),
          ReportChartPoint(x: 'D5', y: 34),
        ],
        heatmap: [
          RetentionHeatRow(label: '30', values: [91, 74, 55, 47, 34]),
          RetentionHeatRow(label: '31', values: [89, 55, 41, 32, 14]),
          RetentionHeatRow(label: '01', values: [83, 72, 59, 47, 32]),
          RetentionHeatRow(label: '02', values: [72, 55, 41, 15, 7]),
          RetentionHeatRow(label: '03', values: [97, 83, 65, 47, 29]),
        ],
        insights: _defaultInsights,
      );
    }

    final baseRows = <ReportPreviewRow>[
      ReportPreviewRow(label: '${type.title} A', value: 'AED 124,000', status: 'Healthy'),
      ReportPreviewRow(label: '${type.title} B', value: 'AED 97,200', status: 'Watch'),
      ReportPreviewRow(label: '${type.title} C', value: 'AED 64,500', status: 'Needs review'),
    ];

    final chart = <ReportChartPoint>[
      const ReportChartPoint(x: 'W1', y: 36),
      const ReportChartPoint(x: 'W2', y: 52),
      const ReportChartPoint(x: 'W3', y: 49),
      const ReportChartPoint(x: 'W4', y: 71),
      const ReportChartPoint(x: 'W5', y: 67),
      const ReportChartPoint(x: 'W6', y: 78),
    ];

    final summary = switch (period) {
      'Today' => 'Today score 81',
      'Last 7 days' => '7-day score 78',
      'Last 30 days' => '30-day score 74',
      _ => 'All-time score 76',
    };

    return ReportPreviewData(
      summaryValue: summary,
      rows: baseRows,
      chart: chart,
      insights: _defaultInsights,
    );
  }
}
