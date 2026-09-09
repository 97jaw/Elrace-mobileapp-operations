import 'package:intl/intl.dart';

enum DocumentStatus { valid, expiring, expired, unknown }

/// Shared display helpers for My Documents list + details.
abstract final class DocumentDisplay {
  static String typeLabel(Map<String, dynamic> document) {
    final raw = (document['title'] ??
            document['document_type'] ??
            document['type'] ??
            '')
        .toString()
        .trim();
    if (raw.isEmpty || raw == '-') return 'Document';
    return _toTitleCase(raw.replaceAll('_', ' '));
  }

  static String documentNumber(Map<String, dynamic> document) {
    for (final key in [
      'document_number',
      'eid_no',
      'passport_no',
      'id_number',
      'document_no',
      'number',
      // Odoo `name` is usually the document number (not a file name).
      'name',
    ]) {
      final v = document[key];
      if (v == null || v == false) continue;
      final s = v.toString().trim();
      if (s.isEmpty || s.toLowerCase() == 'null' || s == '-') continue;
      if (key == 'name' && _looksLikeFileName(s)) continue;
      return s;
    }
    return '-';
  }

  /// Pulls expiry from any known / fuzzy key on the record map.
  static dynamic pickExpiryRaw(Map<String, dynamic> document) {
    const preferred = [
      'expiry_date',
      'date_expiry',
      'expiry',
      'eid_expiry_date',
      'passport_expiry_date',
      'visa_expiry_date',
    ];
    for (final key in preferred) {
      final v = document[key];
      if (_hasDateValue(v)) return v;
    }
    for (final entry in document.entries) {
      final k = entry.key.toString().toLowerCase();
      if ((k.contains('expiry') || k.contains('expire')) &&
          _hasDateValue(entry.value)) {
        return entry.value;
      }
    }
    return null;
  }

  static dynamic pickIssueRaw(Map<String, dynamic> document) {
    const preferred = ['issue_date', 'date_issue', 'issue'];
    for (final key in preferred) {
      final v = document[key];
      if (_hasDateValue(v)) return v;
    }
    return null;
  }

  static String formatDate(dynamic raw) {
    final parsed = parseDate(raw);
    if (parsed == null) {
      if (!_hasDateValue(raw)) return '-';
      final s = raw.toString().trim();
      return s.isEmpty ? '-' : s;
    }
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  static DateTime? parseDate(dynamic raw) {
    if (!_hasDateValue(raw)) return null;
    var s = raw.toString().trim();
    final lower = s.toLowerCase();
    if (lower == 'false' || lower == 'null' || lower == 'none') return null;
    if (s.contains('T')) s = s.split('T').first;
    if (s.contains(' ')) s = s.split(' ').first;

    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    for (final pattern in [
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'MM/dd/yyyy',
    ]) {
      try {
        return DateFormat(pattern).parseStrict(s);
      } catch (_) {}
    }
    return null;
  }

  static DocumentStatus status(Map<String, dynamic> document) {
    // Always prefer computing from the actual expiry value when present.
    final parsed = parseDate(pickExpiryRaw(document));
    if (parsed != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiry = DateTime(parsed.year, parsed.month, parsed.day);
      final days = expiry.difference(today).inDays;
      if (days < 0) return DocumentStatus.expired;
      if (days <= 30) return DocumentStatus.expiring;
      return DocumentStatus.valid;
    }

    final rawStatus = (document['status'] ?? '').toString().trim().toLowerCase();
    switch (rawStatus) {
      case 'valid':
        return DocumentStatus.valid;
      case 'expiring':
      case 'expiry_soon':
      case 'expiring_soon':
        return DocumentStatus.expiring;
      case 'expired':
        return DocumentStatus.expired;
      default:
        return DocumentStatus.unknown;
    }
  }

  /// Days until expiry (negative = already expired). Null when no date.
  static int? daysUntilExpiry(Map<String, dynamic> document) {
    final parsed = parseDate(pickExpiryRaw(document));
    if (parsed == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(parsed.year, parsed.month, parsed.day);
    return expiry.difference(today).inDays;
  }

  /// e.g. "120 days left", "Expired 5 days ago", or "Expiry N/A".
  static String expiryCountdownLabel(Map<String, dynamic> document) {
    final days = daysUntilExpiry(document);
    if (days == null) return 'Expiry N/A';
    if (days < 0) {
      final ago = -days;
      return ago == 1 ? 'Expired 1 day ago' : 'Expired $ago days ago';
    }
    return days == 1 ? '1 day left' : '$days days left';
  }

  static dynamic pickWriteDateRaw(Map<String, dynamic> document) {
    const preferred = [
      'write_date',
      'updated_at',
      'writeDate',
      'last_update',
      'create_date',
      'request_date',
    ];
    for (final key in preferred) {
      final v = document[key];
      if (_hasDateValue(v)) return v;
    }
    for (final entry in document.entries) {
      final k = entry.key.toString().toLowerCase();
      if ((k.contains('write_date') ||
              k == 'updated' ||
              k.contains('updated_at')) &&
          _hasDateValue(entry.value)) {
        return entry.value;
      }
    }
    return null;
  }

  /// e.g. "12 Aug 2026" for the Updated line; null if missing.
  static String? formatUpdatedShort(Map<String, dynamic> document) {
    final parsed = parseDate(pickWriteDateRaw(document));
    if (parsed == null) return null;
    return DateFormat('d MMM yyyy').format(parsed);
  }

  static bool _hasDateValue(dynamic v) {
    if (v == null || v == false) return false;
    final s = v.toString().trim();
    if (s.isEmpty) return false;
    final lower = s.toLowerCase();
    return lower != 'false' && lower != 'null' && lower != 'none' && s != '-';
  }

  static bool _looksLikeFileName(String value) {
    final lower = value.toLowerCase();
    return RegExp(r'\.(pdf|png|jpe?g|gif|webp|heic|doc|docx)$').hasMatch(lower);
  }

  static String _toTitleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.length == 1
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
