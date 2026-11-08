/// Parse / format check-in and check-out times returned by Odoo.
class AttendanceServerTime {
  AttendanceServerTime._();

  /// Odoo `_to_tz` returns `yyyy-MM-dd HH:mm` (no seconds, no zone).
  static DateTime? tryParse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'false') return null;
    final normalized =
        trimmed.contains('T') ? trimmed : trimmed.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  static String formatDisplay(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}'
        ':${dateTime.minute.toString().padLeft(2, '0')}'
        ':${dateTime.second.toString().padLeft(2, '0')}';
  }

  /// Prefer the server stamp; fall back to UAE phone clock (today's behaviour).
  static String displayOrLocalFallback(String? serverRaw) {
    final parsed = tryParse(serverRaw);
    if (parsed != null) return formatDisplay(parsed);
    final uae = DateTime.now().toUtc().add(const Duration(hours: 4));
    return formatDisplay(uae);
  }

  /// Milliseconds for the 16-hour reset; server stamp when present.
  static int millisOrNow(String? serverRaw) {
    final parsed = tryParse(serverRaw);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
    return DateTime.now().millisecondsSinceEpoch;
  }
}
