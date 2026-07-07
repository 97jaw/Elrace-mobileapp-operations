class TimesheetApiEnvelope<T> {
  const TimesheetApiEnvelope({
    required this.success,
    required this.data,
    required this.error,
    required this.uiStatus,
  });

  final bool success;
  final T? data;
  final String? error;
  final String uiStatus;

  factory TimesheetApiEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Object? raw) parseData,
  ) {
    return TimesheetApiEnvelope<T>(
      success: json['success'] == true,
      data: parseData(json['data']),
      error: json['error']?.toString(),
      uiStatus: json['ui_status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson(Object? Function(T? data) dataToJson) {
    return {
      'success': success,
      'data': dataToJson(data),
      'error': error,
      'ui_status': uiStatus,
    };
  }
}
