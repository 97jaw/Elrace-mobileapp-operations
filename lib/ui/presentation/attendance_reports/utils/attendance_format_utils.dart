import 'package:intl/intl.dart';

/// Compact number formatter: 0–999 shown as-is, ≥1 000 → K, ≥1 000 000 → M.
String formatK(int n) {
  if (n >= 1000000) {
    final d = n / 1000000;
    return '${d == d.truncate() ? d.toInt() : d.toStringAsFixed(1)}M';
  }
  if (n >= 1000) {
    final d = n / 1000;
    return '${d == d.truncate() ? d.toInt() : d.toStringAsFixed(1)}K';
  }
  return n.toString();
}

extension FormatKExtension on int {
  String get kFormatted => formatK(this);
}

/// Clock row in record lists — e.g. "10:30am".
String formatAttendanceClock(DateTime dt) {
  return DateFormat('h:mma').format(dt).toLowerCase();
}

/// 12-hour time with space — e.g. "4 pm", "10:30 am".
String formatAttendanceTime(DateTime dt) {
  final raw = DateFormat('h:mm a').format(dt).toLowerCase();
  return raw.replaceAll(' am', ' am').replaceAll(' pm', ' pm');
}

/// Date as dd/MM/yyyy — matches Odoo request screens.
String formatAttendanceDate(DateTime dt) {
  return DateFormat('dd/MM/yyyy').format(dt);
}

/// Request timestamp — dd/MM/yyyy HH:mm:ss (24h).
String formatAttendanceDateTime(DateTime dt) {
  return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt);
}

DateTime? parseAttendanceDateTime(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  if (s.isEmpty) return null;
  // API returns Dubai-local wall clock without timezone offset.
  final norm = s.contains('T') ? s : s.replaceFirst(' ', 'T');
  final parsed = DateTime.tryParse(norm);
  if (parsed == null) return null;
  return DateTime(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
  );
}

/// Human label for Odoo selection keys.
String humanizeOdooKey(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  return raw
      .trim()
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) =>
          w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}
