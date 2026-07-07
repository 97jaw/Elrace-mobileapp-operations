class ProjectScurvePoint {
  final int week;
  final double planned;
  final double actual;

  const ProjectScurvePoint({
    required this.week,
    required this.planned,
    required this.actual,
  });

  factory ProjectScurvePoint.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return ProjectScurvePoint(
      week: (json['week'] as num?)?.toInt() ?? 0,
      planned: toDouble(json['planned']),
      actual: toDouble(json['actual']),
    );
  }
}

class ProjectScurveKpi {
  final double planned;
  final double actual;
  final double variance;
  final double spi;
  final String status;

  const ProjectScurveKpi({
    required this.planned,
    required this.actual,
    required this.variance,
    required this.spi,
    required this.status,
  });

  factory ProjectScurveKpi.fromJson(Map<String, dynamic>? json) {
    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return ProjectScurveKpi(
      planned: toDouble(json?['planned']),
      actual: toDouble(json?['actual']),
      variance: toDouble(json?['variance']),
      spi: toDouble(json?['spi']),
      status: json?['status']?.toString() ?? 'n/a',
    );
  }
}

class ProjectScurveForecast {
  final double eacWeek;
  final String expectedCompletion;

  const ProjectScurveForecast({
    required this.eacWeek,
    required this.expectedCompletion,
  });

  factory ProjectScurveForecast.fromJson(Map<String, dynamic>? json) {
    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    return ProjectScurveForecast(
      eacWeek: toDouble(json?['eac_week']),
      expectedCompletion: json?['expected_completion']?.toString() ?? '—',
    );
  }
}

class ProjectScurveData {
  final String projectName;
  final int totalWeeks;
  final int currentWeek;
  final int rangeStart;
  final int rangeEnd;
  final List<ProjectScurvePoint> series;
  final ProjectScurveKpi kpis;
  final ProjectScurveForecast forecast;

  const ProjectScurveData({
    required this.projectName,
    required this.totalWeeks,
    required this.currentWeek,
    required this.rangeStart,
    required this.rangeEnd,
    required this.series,
    required this.kpis,
    required this.forecast,
  });

  factory ProjectScurveData.empty({String projectName = ''}) {
    return ProjectScurveData(
      projectName: projectName,
      totalWeeks: 0,
      currentWeek: 0,
      rangeStart: 1,
      rangeEnd: 0,
      series: const [],
      kpis: const ProjectScurveKpi(
        planned: 0,
        actual: 0,
        variance: 0,
        spi: 0,
        status: 'n/a',
      ),
      forecast: const ProjectScurveForecast(
        eacWeek: 0,
        expectedCompletion: '—',
      ),
    );
  }

  factory ProjectScurveData.fromJson(Map<String, dynamic> json) {
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawSeries = (json['series'] as List?) ?? const [];
    return ProjectScurveData(
      projectName: json['project']?.toString() ?? '',
      totalWeeks: (meta['total_weeks'] as num?)?.toInt() ?? 0,
      currentWeek: (meta['current_week'] as num?)?.toInt() ?? 0,
      rangeStart: (meta['range_start'] as num?)?.toInt() ?? 1,
      rangeEnd: (meta['range_end'] as num?)?.toInt() ?? 0,
      series: rawSeries
          .whereType<Map>()
          .map((e) => ProjectScurvePoint.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      kpis: ProjectScurveKpi.fromJson(
        (json['kpis'] as Map?)?.cast<String, dynamic>(),
      ),
      forecast: ProjectScurveForecast.fromJson(
        (json['forecast'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}
