/// A popup configured in Odoo (Mobile Administration → App Notices).
class AppNotice {
  const AppNotice({
    required this.id,
    required this.type,
    required this.title,
    required this.titleAr,
    required this.message,
    required this.messageAr,
    required this.icon,
    required this.frequency,
    required this.revision,
    required this.dismissible,
    this.forceLogout = false,
    this.button,
  });

  final int id;

  /// `login` or `maintenance`.
  final String type;
  final String title;
  final String titleAr;
  final String message;
  final String messageAr;

  /// support, maintenance, info, warning, lock, update.
  final String icon;

  /// every_time, daily, once.
  final String frequency;
  final String revision;
  final bool dismissible;

  /// Maintenance only: sign the user out instead of just blocking.
  final bool forceLogout;
  final AppNoticeButton? button;

  bool get isMaintenance => type == 'maintenance';

  String titleFor(bool arabic) =>
      arabic && titleAr.trim().isNotEmpty ? titleAr : title;

  String messageFor(bool arabic) =>
      arabic && messageAr.trim().isNotEmpty ? messageAr : message;

  static AppNotice? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = int.tryParse('${raw['id']}');
    if (id == null) return null;
    final type = '${raw['type'] ?? 'login'}';
    return AppNotice(
      id: id,
      type: type,
      title: '${raw['title'] ?? ''}',
      titleAr: '${raw['title_ar'] ?? ''}',
      message: '${raw['message'] ?? ''}',
      messageAr: '${raw['message_ar'] ?? ''}',
      icon: '${raw['icon'] ?? 'info'}',
      frequency: '${raw['frequency'] ?? 'every_time'}',
      revision: '${raw['revision'] ?? ''}',
      dismissible: raw['dismissible'] != false && type != 'maintenance',
      forceLogout: type == 'maintenance' && raw['force_logout'] == true,
      button: AppNoticeButton.tryParse(raw['button']),
    );
  }

  static List<AppNotice> parseList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map(tryParse).whereType<AppNotice>().toList();
  }
}

class AppNoticeButton {
  const AppNoticeButton({
    required this.action,
    required this.value,
    required this.label,
    required this.labelAr,
  });

  /// phone, email, url.
  final String action;
  final String value;
  final String label;
  final String labelAr;

  String labelFor(bool arabic) {
    if (arabic && labelAr.trim().isNotEmpty) return labelAr;
    if (label.trim().isNotEmpty) return label;
    switch (action) {
      case 'phone':
        return arabic ? 'اتصل بالدعم' : 'Call Support';
      case 'email':
        return arabic ? 'راسل الدعم' : 'Email Support';
      default:
        return arabic ? 'فتح الرابط' : 'Open Link';
    }
  }

  Uri? get uri {
    final v = value.trim();
    if (v.isEmpty) return null;
    switch (action) {
      case 'phone':
        return Uri(scheme: 'tel', path: v.replaceAll(' ', ''));
      case 'email':
        return Uri(scheme: 'mailto', path: v);
      default:
        return Uri.tryParse(v.contains('://') ? v : 'https://$v');
    }
  }

  static AppNoticeButton? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final value = '${raw['value'] ?? ''}';
    if (value.trim().isEmpty) return null;
    return AppNoticeButton(
      action: '${raw['action'] ?? 'url'}',
      value: value,
      label: '${raw['label'] ?? ''}',
      labelAr: '${raw['label_ar'] ?? ''}',
    );
  }
}
