DateTime? tmDateTimeFromJson(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final raw = value.toString().trim();
  if (raw.isEmpty || raw.toLowerCase() == 'false') return null;
  return DateTime.tryParse(raw);
}

String tmStringFromJson(Object? value) {
  if (value == null) return '';
  final raw = value.toString();
  return raw.toLowerCase() == 'false' ? '' : raw;
}

int tmIntFromJson(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? tmIntOrNullFromJson(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double tmDoubleFromJson(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool tmBoolFromJson(Object? value) {
  if (value is bool) return value;
  final raw = value?.toString().toLowerCase().trim();
  return raw == 'true' || raw == '1' || raw == 'yes';
}

List<String> tmStringListFromJson(Object? value) {
  if (value is List) {
    return value.map((item) => tmStringFromJson(item)).toList();
  }
  return const [];
}

List<int> tmIntListFromJson(Object? value) {
  if (value is List) {
    return value.map((item) => tmIntFromJson(item)).toList();
  }
  return const [];
}

String? tmDateTimeToJson(DateTime? value) => value?.toIso8601String();
