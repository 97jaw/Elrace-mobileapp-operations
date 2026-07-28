import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_city_helper.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';

class ProfileDetailItem {
  const ProfileDetailItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class ProfileUserInfo {
  ProfileUserInfo._();

  static Data? get _data => SharedPref.getLoginData().result?.data;

  static Map<String, dynamic>? _rawDataMap() {
    try {
      final loginJson = SharedPref.sharedPreferences.getString('loginResponse') ??
          SharedPref.sharedPreferences.getString('LOGIN_RESPONSE');
      if (loginJson == null || loginJson.isEmpty) return null;
      final decoded = jsonDecode(loginJson) as Map<String, dynamic>;
      final data = decoded['result']?['data'];
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  static String? _clean(String? value) {
    if (value == null) return null;
    final text = value.trim();
    if (text.isEmpty ||
        text.toLowerCase() == 'false' ||
        text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  static String? _raw(String key) {
    final raw = _rawDataMap();
    if (raw == null) return null;
    return _clean(raw[key]?.toString());
  }

  static String? _readFirst(Iterable<String> keys) {
    for (final key in keys) {
      final v = _raw(key);
      if (v != null) return v;
    }
    return null;
  }

  static String displayName() {
    final data = _data;
    final candidates = [
      data?.emp_name,
      data?.name,
      data?.partnerDisplayName,
      data?.username,
    ];
    for (final c in candidates) {
      final v = _clean(c);
      if (v != null) return v;
    }
    return translate('profile.name_not_available');
  }

  static String? displayUsername() => _clean(_data?.username);

  static String? displayJobTitle() {
    return _clean(_data?.jobTitle) ??
        _clean(_data?.designation) ??
        _clean(_data?.job_id) ??
        _raw('job_title') ??
        _raw('job_name') ??
        _raw('job_id');
  }

  static String? displayJobId() => _clean(_data?.job_id);

  static String? displayFileId() =>
      _clean(_data?.emp_profile_id) ?? _raw('file_id');

  static String? displayEmployeeId() => _clean(_data?.emp_id);

  static String? displayDepartment() {
    final hrms = _data?.defaultWidgets?.data?.hrmsWidget?.hrmsRecord;
    return _clean(hrms?.departmentName) ??
        _raw('department_name') ??
        _raw('department') ??
        _raw('department_id');
  }

  static String? displaySection() {
    final hrms = _data?.defaultWidgets?.data?.hrmsWidget?.hrmsRecord;
    return _clean(hrms?.sectionName) ??
        _raw('section_name') ??
        _raw('section') ??
        _raw('section_id');
  }

  static String? displayCompany() {
    final current = _data?.userCompanies?.currentCompany;
    if (current != null && current.length > 1) {
      return _clean(current[1]?.toString());
    }
    return _raw('company_name') ?? _raw('company');
  }

  static String? displayBranch() {
    final fromModel = _clean(_data?.branch);
    if (fromModel != null) return fromModel;

    final branches = _data?.userBranches?.allowedBranch;
    final branchId = _data?.branchId;
    if (branches != null && branchId != null) {
      for (final item in branches) {
        if (item is List && item.length > 1 && item[0] == branchId) {
          return _clean(item[1]?.toString());
        }
      }
    }
    return _readFirst(['branch_name', 'branch', 'city', 'city_name']);
  }

  static String? displayEmail() {
    final fromModel = _clean(_data?.email);
    if (fromModel != null) return fromModel;

    final fromRaw = _readFirst([
      'email',
      'work_email',
      'personal_email',
      'official_email',
      'mail',
    ]);
    if (fromRaw != null) return fromRaw;

    final username = displayUsername();
    if (username != null && username.contains('@')) return username;
    return null;
  }

  static String? displayPhone() {
    final fromModel = _clean(_data?.phone);
    if (fromModel != null) return fromModel;

    return _readFirst([
      'phone',
      'phone_number',
      'mobile_phone',
      'mobile',
      'mobile_number',
      'work_phone',
      'emp_phone',
      'telephone',
    ]);
  }

  /// Prefer mobile-specific fields for the business-card mobile row.
  static String? displayMobile() {
    return _readFirst([
          'mobile_phone',
          'mobile',
          'mobile_number',
          'emp_phone',
        ]) ??
        displayPhone();
  }

  /// Office / landline row; falls back to company main line.
  static String displayLandline() {
    return _readFirst([
          'work_phone',
          'office_phone',
          'telephone',
          'company_phone',
          'landline',
        ]) ??
        '600 500 722';
  }

  static String? displayLocation() {
    return displayBranch() ??
        _readFirst(['location', 'location_name']) ??
        _homeCityFallback();
  }

  static String? _homeCityFallback() {
    final city = HomeCityHelper.cachedCity.trim();
    if (city.isEmpty || city == '...') return null;
    return city;
  }

  static String displayWebsite() => 'www.elrace.com';

  static String? displayLeaveBalance() {
    final v = _clean(_data?.leaveBalance);
    if (v != null) return v;
    return _clean(SharedPref.getCachedLeaveBalance(fallback: ''));
  }

  static String displayOrDash(String? value) => _clean(value) ?? '—';

  static String displayDepartmentSection() {
    final dept = displayDepartment();
    final section = displaySection();
    if (dept != null && section != null) return '$dept - $section';
    if (dept != null) return dept;
    if (section != null) return section;
    return '—';
  }

  static String displayLeaveBalanceLabel() {
    final v = displayLeaveBalance();
    if (v == null) return '—';
    final lower = v.toLowerCase();
    if (lower.contains('day') || lower.contains('leave')) return v;
    return '$v days';
  }

  static bool get isActive => _data?.qr_status == true;

  static List<ProfileDetailItem> detailItems() {
    final items = <ProfileDetailItem>[];

    void add(String label, String? value, IconData icon) {
      final v = _clean(value);
      if (v == null) return;
      items.add(ProfileDetailItem(label: label, value: v, icon: icon));
    }

    add('File ID', displayFileId(), Icons.badge_outlined);
    add('Employee ID', displayEmployeeId(), Icons.perm_identity_outlined);
    add('Job ID', displayJobId(), Icons.work_outline_rounded);
    add('Job Title', displayJobTitle(), Icons.business_center_outlined);
    add('Department', displayDepartment(), Icons.apartment_rounded);
    add('Section', displaySection(), Icons.account_tree_outlined);
    add('Company', displayCompany(), Icons.domain_outlined);
    add('Branch', displayBranch(), Icons.location_city_outlined);
    add('Leave Balance', displayLeaveBalance(), Icons.beach_access_outlined);

    final username = displayUsername();
    if (username != null) {
      add('Username', username, Icons.alternate_email_rounded);
    }

    return items;
  }
}
