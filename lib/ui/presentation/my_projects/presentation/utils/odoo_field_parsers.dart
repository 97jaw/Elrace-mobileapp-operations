/// Shared parsers for Odoo JSON payloads (many2one tuples, ids, names).
abstract final class OdooFieldParsers {
  static int? parseId(dynamic value) {
    if (value == null || value == false) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is List && value.isNotEmpty) return parseId(value.first);
    if (value is Map) {
      return parseId(value['id'] ?? value['employee_id']);
    }
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  static String? parseMany2oneName(dynamic value) {
    if (value is List && value.length > 1) {
      final label = value[1]?.toString().trim();
      if (label != null && label.isNotEmpty) return label;
    }
    if (value is Map) {
      final name = value['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static int? parseMany2oneId(dynamic value) {
    return parseId(value);
  }

  static String readString(dynamic value) {
    if (value == null || value == false) return '';
    if (value is String) return value.trim();
    final fromM2o = parseMany2oneName(value);
    if (fromM2o != null) return fromM2o;
    return value.toString().trim();
  }

  static bool isNoManagerLabel(String name) {
    final n = name.trim().toLowerCase();
    return n.isEmpty ||
        n == 'no manager' ||
        n == 'false' ||
        n == 'none' ||
        n == 'unassigned';
  }
}
