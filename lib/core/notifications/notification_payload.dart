import 'dart:convert';

class NotificationPayload {
  const NotificationPayload({
    required this.raw,
    this.nv = '',
    this.nid = '',
    this.inboxId = '',
    this.type = '',
    this.category = '',
    this.action = '',
    this.model = '',
    this.resId = '',
    this.screen = '',
    this.params = const {},
  });

  final Map<String, dynamic> raw;
  final String nv;
  final String nid;
  final String inboxId;
  final String type;
  final String category;
  final String action;
  final String model;
  final String resId;
  final String screen;
  final Map<String, dynamic> params;

  bool get isContract => nv.isNotEmpty;

  factory NotificationPayload.fromData(Map<String, dynamic> data) {
    final nv = _text(data['nv']);
    if (nv.isNotEmpty) {
      return NotificationPayload(
        raw: data,
        nv: nv,
        nid: _text(data['nid']),
        inboxId: _text(data['inbox_id']),
        type: _text(data['type']),
        category: _text(data['category']),
        action: _text(data['action']).toLowerCase(),
        model: _text(data['model']),
        resId: _text(data['res_id']),
        screen: _text(data['screen']),
        params: _params(data['params']),
      );
    }
    return NotificationPayload._legacy(data);
  }

  factory NotificationPayload._legacy(Map<String, dynamic> data) {
    final category = _text(data['category']).toLowerCase();
    final type = _text(data['type']).toLowerCase();
    var model = _text(data['model']);
    var resId = _first(data, const ['res_id', 'record_id', 'request_id', 'expense_sheet_id']);
    var action = '';
    var screen = _text(data['screen']);
    final chatId = _first(data, const ['chat_id', 'chatId']);

    if (category == 'chat' || category == 'chat_message' || chatId.isNotEmpty) {
      action = 'open_chat';
    } else if (category == 'circular' ||
        category == 'announcement' ||
        model == 'odx.announcement') {
      action = 'open_screen';
      screen = 'circulars';
      resId = resId.isEmpty ? _text(data['id']) : resId;
    } else if (category == 'labor_transfer' || model == 'elrace.labor.transfer') {
      action = 'open_record';
      model = 'elrace.labor.transfer';
      resId = _first(data, const ['id', 'record_id', 'res_id']);
    } else if (category == 'task' ||
        category == 'ticket' ||
        data.containsKey('task_id') ||
        data.containsKey('taskId') ||
        data.containsKey('is_firebase_task')) {
      final taskId = _first(data, const ['task_id', 'taskId', 'res_id', 'record_id']);
      if (_bool(data['is_firebase_task']) && taskId.isNotEmpty) {
        action = 'open_record';
        model = 'firestore.todo';
        resId = taskId;
      } else {
        action = 'open_screen';
        screen = 'tasks';
      }
    } else if (_text(data['click_action']).toUpperCase() == 'OPEN_RECORD' ||
        (model.isNotEmpty && resId.isNotEmpty)) {
      action = 'open_record';
      if (resId.isEmpty) {
        resId = _text(data['id']);
      }
    }

    return NotificationPayload(
      raw: data,
      type: type,
      category: category,
      action: action,
      model: model,
      resId: resId,
      screen: screen,
      params: _params(data['params']),
    );
  }

  static String _text(dynamic value) => (value ?? '').toString().trim();

  static String _first(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = _text(data[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    final text = _text(value).toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'y';
  }

  static Map<String, dynamic> _params(dynamic value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    final text = _text(value);
    if (text.isEmpty) return const {};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return decoded.map((key, item) => MapEntry(key.toString(), item));
      }
    } catch (_) {}
    return const {};
  }
}
