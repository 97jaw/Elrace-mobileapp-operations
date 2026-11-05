class CheckinBiotimeOffice {
  const CheckinBiotimeOffice({
    required this.id,
    required this.name,
    required this.code,
  });

  final int id;
  final String name;
  final String code;

  factory CheckinBiotimeOffice.fromJson(Map<String, dynamic> json) {
    return CheckinBiotimeOffice(
      id: _readInt(json['id']),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
    );
  }
}

class CheckinBiotimeTerminal {
  const CheckinBiotimeTerminal({
    required this.id,
    required this.alias,
    required this.officeId,
    required this.officeName,
  });

  final int id;
  final String alias;
  final int officeId;
  final String officeName;

  factory CheckinBiotimeTerminal.fromJson(Map<String, dynamic> json) {
    return CheckinBiotimeTerminal(
      id: _readInt(json['id']),
      alias: json['alias']?.toString() ?? '',
      officeId: _readInt(json['office_id']),
      officeName: json['office_name']?.toString() ?? '',
    );
  }
}

class CheckinAllowedProject {
  const CheckinAllowedProject({
    required this.projectId,
    required this.name,
    required this.woRefNo,
    required this.lat,
    required this.lng,
    required this.geofenceRadiusM,
    required this.accessType,
    this.hasCoordinates = true,
  });

  final int projectId;
  final String name;
  final String woRefNo;
  final double lat;
  final double lng;
  final double geofenceRadiusM;
  final String accessType;
  final bool hasCoordinates;

  factory CheckinAllowedProject.fromJson(Map<String, dynamic> json) {
    final lat = _readDouble(json['lat']);
    final lng = _readDouble(json['lng']);
    return CheckinAllowedProject(
      projectId: _readInt(json['project_id']),
      name: json['name']?.toString() ?? '',
      woRefNo: json['wo_ref_no']?.toString() ?? '',
      lat: lat,
      lng: lng,
      geofenceRadiusM: _readDouble(
        json['geofence_radius_m'],
        fallback: 100,
      ),
      accessType: json['access_type']?.toString() ?? 'staff',
      hasCoordinates: json['has_coordinates'] != false &&
          _hasValidCoordinates(lat, lng),
    );
  }
}

bool _hasValidCoordinates(double lat, double lng) {
  if (lat.abs() < 1e-6 || lng.abs() < 1e-6) return false;
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

class CheckinTodayStatus {
  const CheckinTodayStatus({
    required this.checkedIn,
    required this.checkedOut,
    required this.checkInTime,
    required this.checkOutTime,
    required this.checkInRecordId,
    required this.isToday,
    this.canCheckOut = false,
  });

  final bool checkedIn;
  final bool checkedOut;
  final bool canCheckOut;
  final String? checkInTime;
  final String? checkOutTime;
  final int? checkInRecordId;
  final bool isToday;

  factory CheckinTodayStatus.fromJson(Map<String, dynamic> json) {
    final checkedIn = json['checked_in'] == true;
    final recordId = _readIntOrNull(json['check_in_record_id']);
    final canCheckOut = json.containsKey('can_check_out')
        ? json['can_check_out'] == true
        : (checkedIn || recordId != null);
    return CheckinTodayStatus(
      checkedIn: checkedIn,
      checkedOut: json['checked_out'] == true,
      canCheckOut: canCheckOut,
      checkInTime: json['check_in_time']?.toString(),
      checkOutTime: json['check_out_time']?.toString(),
      checkInRecordId: recordId,
      isToday: json['is_today'] == true,
    );
  }

  static const empty = CheckinTodayStatus(
    checkedIn: false,
    checkedOut: false,
    canCheckOut: false,
    checkInTime: null,
    checkOutTime: null,
    checkInRecordId: null,
    isToday: false,
  );
}

class CheckinContextModel {
  const CheckinContextModel({
    required this.mobileCheckinAllowed,
    required this.biotimeOffices,
    required this.biotimeTerminals,
    required this.todayStatus,
    required this.defaultRadiusM,
    this.locationRequired = true,
    this.requireLinkedLocation = false,
    this.remote = false,
  });

  final bool mobileCheckinAllowed;
  final List<CheckinBiotimeOffice> biotimeOffices;
  final List<CheckinBiotimeTerminal> biotimeTerminals;
  final CheckinTodayStatus todayStatus;
  final double defaultRadiusM;

  /// When missing from an older server, default true (today's behaviour).
  final bool locationRequired;

  /// When `location_required` is false: if true, still block when no linked
  /// project has coordinates. Missing/old server → false (anywhere check-in).
  final bool requireLinkedLocation;

  /// Server `remote` / employee.checkin_remote — no location gates.
  final bool remote;

  bool get hasBiotimeAssignment =>
      biotimeOffices.isNotEmpty || biotimeTerminals.isNotEmpty;

  factory CheckinContextModel.fromJson(Map<String, dynamic> json) {
    final thresholds = json['thresholds'];
    final defaultRadius = thresholds is Map
        ? _readDouble(thresholds['default_radius_m'], fallback: 100)
        : 100.0;

    return CheckinContextModel(
      mobileCheckinAllowed: json['mobile_checkin_allowed'] == true,
      biotimeOffices: _mapList(
        json['biotime_offices'],
        CheckinBiotimeOffice.fromJson,
      ),
      biotimeTerminals: _mapList(
        json['biotime_terminals'],
        CheckinBiotimeTerminal.fromJson,
      ),
      todayStatus: json['today_status'] is Map
          ? CheckinTodayStatus.fromJson(
              Map<String, dynamic>.from(json['today_status'] as Map),
            )
          : CheckinTodayStatus.empty,
      defaultRadiusM: defaultRadius,
      // Missing key → true so an old server stays as strict as today.
      locationRequired: json['location_required'] != false,
      // Missing key → false so an old server keeps anywhere check-in.
      requireLinkedLocation: json['require_linked_location'] == true,
      remote: json['remote'] == true,
    );
  }
}

List<T> _mapList<T>(
  dynamic raw,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _readIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double _readDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}
