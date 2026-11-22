import 'package:intl/intl.dart';

/// Pure display rules for the home mid-section check-in card.
///
/// "In HH:MM" is elapsed time since check-in (not remaining of an 8h shift).
/// Absent / placeholder times from the API render as "-".
class HomeCheckInDisplay {
  const HomeCheckInDisplay({
    required this.checkedIn,
    required this.status,
    required this.time,
    required this.sub,
  });

  final bool checkedIn;
  final String status;
  final String time;
  final String sub;

  static const String dash = '-';

  static bool isBlankClock(String? raw) {
    if (raw == null) return true;
    final t = raw.trim();
    if (t.isEmpty) return true;
    final lower = t.toLowerCase();
    return t == dash ||
        t == '--:--' ||
        t == '00:00:00' ||
        lower == 'false' ||
        lower == 'null';
  }

  static String formatDuration(Duration d) {
    final totalMinutes = d.inMinutes < 0 ? 0 : d.inMinutes;
    final h = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final m = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String formatClock(String raw) {
    if (isBlankClock(raw)) return dash;
    final parts = raw.trim().split(':');
    if (parts.length >= 2) {
      final hour = parts[0].padLeft(2, '0');
      final minute = parts[1].padLeft(2, '0');
      return '$hour:$minute';
    }
    return raw.trim();
  }

  static HomeCheckInDisplay resolve({
    required bool isCheckedIn,
    required DateTime? checkInAt,
    required String checkOutDisplayTime,
    required DateTime now,
  }) {
    final hasCheckOut = !isBlankClock(checkOutDisplayTime);

    if (checkInAt != null && (isCheckedIn || hasCheckOut)) {
      final elapsed = now.difference(checkInAt);
      if (isCheckedIn && !hasCheckOut) {
        return HomeCheckInDisplay(
          checkedIn: true,
          status: 'Checked in',
          time: DateFormat('HH:mm').format(checkInAt),
          sub: 'In ${formatDuration(elapsed)}',
        );
      }
      return HomeCheckInDisplay(
        checkedIn: false,
        status: hasCheckOut ? 'Checked out' : 'Check In',
        time: DateFormat('HH:mm').format(checkInAt),
        sub: hasCheckOut ? 'Out ${formatClock(checkOutDisplayTime)}' : 'In $dash',
      );
    }

    return const HomeCheckInDisplay(
      checkedIn: false,
      status: 'Check In',
      time: dash,
      sub: 'In $dash',
    );
  }
}
