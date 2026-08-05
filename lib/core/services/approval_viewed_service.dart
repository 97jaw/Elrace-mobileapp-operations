import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Tracks which approval detail cards the user has opened.
///
/// Note: the home **waiting badge** is total pending items
/// ([ApprovalCountService]), not “unviewed”. This service is for UI
/// affordances (e.g. read state) and still notifies listeners so headers
/// can refresh if needed.
class ApprovalViewedService {
  static const String _viewedItemsKey = 'viewed_approval_items';

  static final Map<Object, VoidCallback> _listeners = {};

  static void addListener(Object key, VoidCallback callback) {
    _listeners[key] = callback;
  }

  static void removeListener(Object key) {
    _listeners.remove(key);
  }

  static void _notifyCountChanged() {
    for (final callback in List.of(_listeners.values)) {
      try {
        callback();
      } catch (e) {
        debugPrint('ApprovalViewedService listener failed: $e');
      }
    }
  }

  /// Normalize type names to match the backend format
  static String _normalizeType(String type) {
    final normalized = type.toLowerCase().trim();
    switch (normalized) {
      case 'pettycash':
      case 'petty_cash':
        return 'petty_cash';
      case 'hr':
      case 'human_resources':
        return 'hr';
      case 'rfq':
        return 'rfq';
      case 'invoice':
      case 'invoices':
        return 'invoice';
      default:
        return normalized;
    }
  }

  /// Mark an approval item as viewed
  static Future<void> markAsViewed(String type, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewedItems = await getViewedItems();

      final normalizedType = _normalizeType(type);
      final key = '${normalizedType}_$id';

      if (!viewedItems.contains(key)) {
        viewedItems.add(key);
        await prefs.setString(_viewedItemsKey, json.encode(viewedItems));
        _notifyCountChanged();
      }
    } catch (e) {
      debugPrint('ApprovalViewedService.markAsViewed failed: $e');
    }
  }

  static Future<List<String>> getViewedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewedString = prefs.getString(_viewedItemsKey);

      if (viewedString != null && viewedString.isNotEmpty) {
        final List<dynamic> decoded = json.decode(viewedString);
        return decoded.cast<String>();
      }
      return [];
    } catch (e) {
      debugPrint('ApprovalViewedService.getViewedItems failed: $e');
      return [];
    }
  }

  static Future<List<String>> getViewedItemsForType(String type) async {
    try {
      final allViewed = await getViewedItems();
      final prefix = '${_normalizeType(type)}_';
      return allViewed
          .where((key) => key.startsWith(prefix))
          .map((key) => key.replaceFirst(prefix, ''))
          .toList();
    } catch (e) {
      debugPrint('ApprovalViewedService.getViewedItemsForType failed: $e');
      return [];
    }
  }

  static Future<bool> isViewed(String type, String id) async {
    try {
      final viewedItems = await getViewedItems();
      final key = '${_normalizeType(type)}_$id';
      return viewedItems.contains(key);
    } catch (e) {
      debugPrint('ApprovalViewedService.isViewed failed: $e');
      return false;
    }
  }

  static Future<void> clearAllViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_viewedItemsKey);
    } catch (e) {
      debugPrint('ApprovalViewedService.clearAllViewed failed: $e');
    }
  }

  static Future<void> clearViewedForType(String type) async {
    try {
      final allViewed = await getViewedItems();
      final prefix = '${_normalizeType(type)}_';
      final filtered =
          allViewed.where((key) => !key.startsWith(prefix)).toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_viewedItemsKey, json.encode(filtered));
    } catch (e) {
      debugPrint('ApprovalViewedService.clearViewedForType failed: $e');
    }
  }
}
