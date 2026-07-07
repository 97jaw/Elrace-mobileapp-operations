/// Standard API envelope — TASKS §8.1 (aligned with SRD §7.3 TBD).
class HrApiEnvelope<T> {
  const HrApiEnvelope({
    required this.success,
    this.data,
    this.error,
    this.uiStatus,
  });

  final bool success;
  final T? data;
  final String? error;
  final String? uiStatus;

  factory HrApiEnvelope.fromJson(
    Map<String, dynamic> json,
    T? Function(Object? raw)? parseData,
  ) {
    return HrApiEnvelope<T>(
      success: json['success'] == true,
      data: parseData != null ? parseData(json['data']) : json['data'] as T?,
      error: json['error']?.toString(),
      uiStatus: json['ui_status']?.toString(),
    );
  }
}
