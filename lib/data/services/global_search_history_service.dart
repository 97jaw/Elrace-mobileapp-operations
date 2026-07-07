import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';

/// Persists recent global search queries (keyword-only, unified search).
class GlobalSearchHistoryService {
  static const _storageKey = 'global_search_history_v2';
  static const int _maxRecent = 12;

  static const List<String> defaultShortcuts = [
    'LPO',
    'Project',
    'Expense',
    'Approval',
    'Document',
    'Task',
  ];

  static List<String> getRecent() {
    return List<String>.from(_loadList());
  }

  static Future<void> addQuery(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.length < 2) return;

    final list = _loadList();
    list.removeWhere((q) => q.toLowerCase() == trimmed.toLowerCase());
    list.insert(0, trimmed);
    if (list.length > _maxRecent) {
      list.removeRange(_maxRecent, list.length);
    }
    await SharedPref().setPreferencesString(_storageKey, jsonEncode(list));
  }

  /// Server prefix suggestions — returns empty until ERP exposes `/api/global/search/suggest`.
  static Future<List<String>> fetchServerSuggestions({
    required String prefix,
  }) async {
    if (prefix.trim().length < 2) return const [];
    return const [];
  }

  static List<String> getShortcuts() => List<String>.from(defaultShortcuts);

  static List<String> _loadList() {
    try {
      final raw = SharedPref().getPreferenceString(_storageKey);
      if (raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
