/// Field rules for maternity, parental, and bereavement leave.
/// Matches Odoo `employee.requests` (elrace_leave_modification).
enum SpecialLeaveKind { maternity, parental, death }

abstract final class SpecialLeaveRules {
  static const int deathFirstDays = 5;
  static const int deathSecondDays = 3;

  static String apiType(SpecialLeaveKind kind) {
    switch (kind) {
      case SpecialLeaveKind.maternity:
        return 'maternity';
      case SpecialLeaveKind.parental:
        return 'parental';
      case SpecialLeaveKind.death:
        return 'death';
    }
  }

  static String title(SpecialLeaveKind kind) {
    switch (kind) {
      case SpecialLeaveKind.maternity:
        return 'Maternity leave';
      case SpecialLeaveKind.parental:
        return 'Parental leave';
      case SpecialLeaveKind.death:
        return 'Bereavement leave';
    }
  }

  static String notice(SpecialLeaveKind kind) {
    switch (kind) {
      case SpecialLeaveKind.maternity:
        return 'A discharge report is required. Duration cannot exceed your maternity balance.';
      case SpecialLeaveKind.parental:
        return 'A birth attachment is required.';
      case SpecialLeaveKind.death:
        return 'First degree (spouse) is 5 days. Second degree is 3 days. A death certificate is required.';
    }
  }

  static String? attachmentLabel(SpecialLeaveKind kind) {
    switch (kind) {
      case SpecialLeaveKind.maternity:
        return 'Discharge report';
      case SpecialLeaveKind.parental:
        return 'Birth attachment';
      case SpecialLeaveKind.death:
        return 'Death certificate';
    }
  }

  static int pastWindowDays(SpecialLeaveKind kind) {
    switch (kind) {
      case SpecialLeaveKind.death:
      case SpecialLeaveKind.parental:
        return 365;
      case SpecialLeaveKind.maternity:
        return 5;
    }
  }

  /// Bereavement duration is fixed by the relative. Other types use [entered].
  static int? durationFor({
    required SpecialLeaveKind kind,
    String? relative,
    int? entered,
  }) {
    if (kind == SpecialLeaveKind.death) {
      if (relative == 'first') return deathFirstDays;
      if (relative == 'second') return deathSecondDays;
      return null;
    }
    return entered;
  }

  static DateTime? endDate(DateTime start, int duration) {
    if (duration < 1) return null;
    final day = DateTime(start.year, start.month, start.day);
    return day.add(Duration(days: duration - 1));
  }

  static String? validate({
    required SpecialLeaveKind kind,
    required DateTime? start,
    required int? duration,
    String? relative,
    required bool hasAttachment,
  }) {
    if (start == null) return 'Start date is required.';
    if (kind == SpecialLeaveKind.death &&
        (relative == null || relative.isEmpty)) {
      return 'Select the deceased relative.';
    }
    if (duration == null || duration < 1) return 'Duration is required.';
    final attachment = attachmentLabel(kind);
    if (attachment != null && !hasAttachment) {
      return '$attachment is required.';
    }
    return null;
  }
}
