import 'package:flutter/material.dart';

class NotificationCategoryVisual {
  const NotificationCategoryVisual({
    required this.icon,
    required this.color,
    required this.title,
  });

  final IconData icon;
  final Color color;
  final String title;
}

/// Shared category icon + color mapping for notification filters and list rows.
abstract final class NotificationCategoryTheme {
  static const NotificationCategoryVisual all = NotificationCategoryVisual(
    icon: Icons.notifications_rounded,
    color: Color(0xFF1A2248),
    title: 'All',
  );

  static const Map<String, NotificationCategoryVisual> _known = {
    'circular': NotificationCategoryVisual(
      icon: Icons.campaign_rounded,
      color: Color(0xFF455A64),
      title: 'Circulars',
    ),
    'announcement': NotificationCategoryVisual(
      icon: Icons.announcement_rounded,
      color: Color(0xFF6A1B9A),
      title: 'Announcements',
    ),
    'purchase.order': NotificationCategoryVisual(
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF6D4C41),
      title: 'Purchase Orders',
    ),
    'rfq': NotificationCategoryVisual(
      icon: Icons.request_quote_rounded,
      color: Color(0xFF5D4037),
      title: 'RFQ',
    ),
    'hr.expense.sheet': NotificationCategoryVisual(
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFFC62828),
      title: 'Expense Sheets',
    ),
    'account.move': NotificationCategoryVisual(
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF283593),
      title: 'Invoices',
    ),
    'employee.requests': NotificationCategoryVisual(
      icon: Icons.badge_rounded,
      color: Color(0xFF00897B),
      title: 'Employee Requests',
    ),
    'prayer': NotificationCategoryVisual(
      icon: Icons.mosque_rounded,
      color: Color(0xFF00695C),
      title: 'Prayer',
    ),
    'hr.attendance': NotificationCategoryVisual(
      icon: Icons.access_time_filled_rounded,
      color: Color(0xFF2E7D32),
      title: 'Attendance',
    ),
    'cloud.folder': NotificationCategoryVisual(
      icon: Icons.folder_shared_rounded,
      color: Color(0xFF0277BD),
      title: 'Shared Folders',
    ),
    'alert': NotificationCategoryVisual(
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFEF6C00),
      title: 'Safety / Alerts',
    ),
    // High-priority "red alert": the employee's home widgets changed and they
    // must re-login to see the update. Kept a strong red for contrast.
    'widget_update': NotificationCategoryVisual(
      icon: Icons.dashboard_customize_rounded,
      color: Color(0xFFD32F2F),
      title: 'Widget Update',
    ),
    'weather': NotificationCategoryVisual(
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFEF6C00),
      title: 'Safety / Alerts',
    ),
    'project_open': NotificationCategoryVisual(
      icon: Icons.apartment_rounded,
      color: Color(0xFF455A64),
      title: 'Projects',
    ),
    'project_completed': NotificationCategoryVisual(
      icon: Icons.apartment_rounded,
      color: Color(0xFF455A64),
      title: 'Projects',
    ),
    'chat_message': NotificationCategoryVisual(
      icon: Icons.chat_bubble_rounded,
      color: Color(0xFF0097A7),
      title: 'Chat',
    ),
    'task': NotificationCategoryVisual(
      icon: Icons.task_alt_rounded,
      color: Color(0xFF5C6BC0),
      title: 'Tasks',
    ),
    'ticket': NotificationCategoryVisual(
      icon: Icons.confirmation_number_rounded,
      color: Color(0xFF00838F),
      title: 'Tickets',
    ),
    'notification': NotificationCategoryVisual(
      icon: Icons.notifications_active_rounded,
      color: Color(0xFF3949AB),
      title: 'Notifications',
    ),
  };

  static NotificationCategoryVisual forKey(
    String key, {
    String? fallbackTitle,
  }) {
    final normalized = key.trim().toLowerCase();
    if (normalized.isEmpty || normalized == '__all__') return all;
    final known = _known[normalized];
    if (known != null) return known;

    return NotificationCategoryVisual(
      icon: Icons.notifications_none_rounded,
      color: const Color(0xFF546E7A),
      title: fallbackTitle ?? _humanize(normalized),
    );
  }

  static String _humanize(String value) {
    final parts = value
        .split(RegExp(r'[._-]+'))
        .where((p) => p.trim().isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .toList();
    return parts.isEmpty ? 'Notification' : parts.join(' ');
  }
}
