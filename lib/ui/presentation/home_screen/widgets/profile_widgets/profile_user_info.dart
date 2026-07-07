import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
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
        _raw('job_title') ??
        _raw('job_name');
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
    final branches = _data?.userBranches?.allowedBranch;
    final branchId = _data?.branchId;
    if (branches != null && branchId != null) {
      for (final item in branches) {
        if (item is List && item.length > 1 && item[0] == branchId) {
          return _clean(item[1]?.toString());
        }
      }
    }
    return _raw('branch_name') ?? _raw('branch');
  }

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
