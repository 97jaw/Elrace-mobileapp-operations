/// Normalizes Odoo project status for Site Management lists.
abstract final class TimesheetProjectStatus {
  static bool isInProgress(String status) {
    final s = status.trim().toLowerCase();
    if (s.isEmpty) return true;
    if (_completedTokens.any(s.contains)) return false;
    if (_inProgressTokens.any(s.contains)) return true;
    return !s.contains('close') && !s.contains('cancel');
  }

  static bool isCompleted(String status) {
    final s = status.trim().toLowerCase();
    if (s.isEmpty) return false;
    return _completedTokens.any(s.contains);
  }

  static const _inProgressTokens = [
    'in_progress',
    'in progress',
    'progress',
    'open',
    'active',
    'ongoing',
    'running',
  ];

  static const _completedTokens = [
    'complete',
    'completed',
    'done',
    'closed',
    'cancel',
    'cancelled',
  ];
}
