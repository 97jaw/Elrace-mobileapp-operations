import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ApprovalAvatarKind {
  employee,
  vendor,
  pettyCashRequester,
  pettyCashHolder,
}

abstract final class ApprovalDisplayHelpers {
  static const _erpBaseUrl = 'https://erp.elrace.com';

  static String pickString(
    Map<dynamic, dynamic> item,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      if (!item.containsKey(key)) continue;
      final value = item[key];
      final resolved = pickPersonName(value);
      if (resolved.isNotEmpty) return resolved;
    }
    return fallback;
  }

  static String pickPersonName(dynamic value) {
    if (value == null || value == false || value == true) return '';
    if (value is Map) {
      final map = value.cast<dynamic, dynamic>();
      for (final key in const [
        'name',
        'display_name',
        'employee_name',
        'requester_name',
        'holder_name',
      ]) {
        final nested = _safeScalar(map[key]);
        if (nested.isNotEmpty) return nested;
      }
      return '';
    }
    return _safeScalar(value);
  }

  static String _safeScalar(dynamic value) {
    if (value == null || value == false || value == true) return '';
    if (value is List) {
      for (final item in value) {
        final nested = _safeScalar(item);
        if (nested.isNotEmpty) return nested;
      }
      return '';
    }
    if (value is Map) {
      for (final key in const [
        'url',
        'src',
        'image',
        'image_url',
        'image_emp',
        'avatar',
        'photo',
      ]) {
        final nested = _safeScalar(value[key]);
        if (nested.isNotEmpty) return nested;
      }
      return '';
    }
    final text = value.toString().trim();
    if (text.isEmpty) return '';
    // Handle backend odd serialization patterns like:
    // "['https://...']" or "('https://...',)".
    if ((text.startsWith('[') && text.endsWith(']')) ||
        (text.startsWith('(') && text.endsWith(')'))) {
      final extracted = RegExp(r'https?://[^,\]\)' '"]+').firstMatch(text);
      if (extracted != null) {
        final url = extracted.group(0)?.trim() ?? '';
        if (url.isNotEmpty) return url;
      }
    }
    final lower = text.toLowerCase();
    if (lower == 'null' || lower == 'false' || lower == 'true') return '';
    return text;
  }

  static int? _readOdooId(dynamic value) {
    if (value == null || value == false) return null;
    if (value is num) {
      final id = value.toInt();
      return id > 0 ? id : null;
    }
    if (value is List && value.isNotEmpty) {
      return _readOdooId(value.first);
    }
    if (value is Map) {
      return _readOdooId(value['id']);
    }
    final parsed = int.tryParse(value.toString().trim());
    if (parsed != null && parsed > 0) return parsed;
    return null;
  }

  static String partnerImageFromRecord(Map<dynamic, dynamic> item) {
    for (final key in const [
      'partner_id',
      'vendor_id',
      'client_id',
      'supplier_id',
    ]) {
      final id = _readOdooId(item[key]);
      if (id != null) {
        return '$_erpBaseUrl/public/partner/image/$id';
      }
    }

    for (final key in const ['vendor', 'partner', 'client', 'supplier']) {
      final nested = item[key];
      if (nested is Map) {
        final nestedMap = nested.cast<dynamic, dynamic>();
        final nestedId = _readOdooId(nestedMap['id']);
        if (nestedId != null) {
          return '$_erpBaseUrl/public/partner/image/$nestedId';
        }
      }
    }

    return '';
  }

  static bool isInvalidImageValue(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'false' || normalized == 'null') {
      return true;
    }
    if (normalized.endsWith('/false') ||
        normalized.contains('/image/false') ||
        normalized.contains('employee/image/false') ||
        normalized.contains('partner/image/false')) {
      return true;
    }
    return false;
  }

  static String normalizeImageUrl(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty || isInvalidImageValue(trimmed)) return '';

    if (trimmed.startsWith('https:/') && !trimmed.startsWith('https://')) {
      trimmed = trimmed.replaceFirst('https:/', 'https://');
    } else if (trimmed.startsWith('http:/') && !trimmed.startsWith('http://')) {
      trimmed = trimmed.replaceFirst('http:/', 'http://');
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (trimmed.startsWith('/')) {
      return '$_erpBaseUrl$trimmed';
    }

    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return '$_erpBaseUrl/public/employee/image/$trimmed';
    }

    if (trimmed.startsWith('public/') ||
        trimmed.startsWith('employee/') ||
        trimmed.startsWith('partner/')) {
      return '$_erpBaseUrl/$trimmed';
    }

    return trimmed;
  }

  static String pickImageUrl(
    Map<dynamic, dynamic> item,
    ApprovalAvatarKind kind,
  ) {
    final keys = switch (kind) {
      ApprovalAvatarKind.vendor => const [
          'client_photo_url',
          'vendor_photo_url',
          'client_image_url',
          'vendor_image_url',
          'client_image',
          'vendor_image',
          'reviewer_image',
          'employeeImageUrl',
          'client_photo',
          'vendor_photo',
          'partner_image_url',
          'partner_image',
          'vendor_image_url',
          'client_image_url',
          'vendor_image',
          'client_image',
          'partner_image',
          'image_url',
          'photo_url',
          'avatar',
          'photo',
        ],
      ApprovalAvatarKind.pettyCashHolder => const [
          'holder_image_url',
          'pettycash_holder_image_url',
          'pettycash_holder_image',
          'holder_image',
          'holder_img',
          'pettycash_holder_avatar',
        ],
      ApprovalAvatarKind.pettyCashRequester ||
      ApprovalAvatarKind.employee =>
        const [
          'employeeImageUrl',
          'reviewer_image',
          'emp_image_url',
          'requester_image',
          'employee_image',
          'emp_image',
          'image_emp',
          'employee_img',
          'image',
          'avatar',
          'photo',
          'profile_image',
        ],
    };

    for (final key in keys) {
      final candidate = _safeScalar(item[key]);
      if (candidate.isNotEmpty && !isInvalidImageValue(candidate)) {
        return candidate;
      }
    }

    if (kind == ApprovalAvatarKind.pettyCashHolder) {
      for (final nestedKey in const [
        'pettycash_holder',
        'holder',
        'holder_name',
      ]) {
        final nested = item[nestedKey];
        if (nested is Map) {
          final image = _safeScalar(nested['image_emp']);
          if (image.isNotEmpty && !isInvalidImageValue(image)) {
            return image;
          }
        }
      }
    }

    if (kind == ApprovalAvatarKind.vendor) {
      for (final nestedKey in const ['vendor', 'partner', 'client']) {
        final nested = item[nestedKey];
        if (nested is Map) {
          final nestedPhoto = pickImageUrl(
            nested.cast<dynamic, dynamic>(),
            ApprovalAvatarKind.vendor,
          );
          if (nestedPhoto.isNotEmpty) return nestedPhoto;
        }
      }

      final partnerPhoto = partnerImageFromRecord(item);
      if (partnerPhoto.isNotEmpty) return partnerPhoto;
    }

    if (kind == ApprovalAvatarKind.employee ||
        kind == ApprovalAvatarKind.pettyCashRequester) {
      final employeeId = _readOdooId(
        item['employee_id'] ??
            item['emp_id'] ??
            item['requester_id'] ??
            item['user_id'],
      );
      if (employeeId != null) {
        return '$_erpBaseUrl/public/employee/image/$employeeId';
      }
    }

    return '';
  }

  static String formatAmountWithAed(
    dynamic raw, {
    String fallback = '0',
    bool includeAed = true,
  }) {
    final text = _safeScalar(raw);
    if (text.isEmpty) {
      return includeAed ? '$fallback AED' : fallback;
    }

    final cleaned = text.replaceAll(RegExp(r'[^0-9.\-]'), '');
    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      if (text.toUpperCase().contains('AED')) return text;
      return includeAed ? '$text AED' : text;
    }

    final formatted = parsed % 1 == 0
        ? NumberFormat('#,##0', 'en_US').format(parsed)
        : NumberFormat('#,##0.##', 'en_US').format(parsed);
    return includeAed ? '$formatted AED' : formatted;
  }

  static Widget buildCircleAvatar({
    required String imageData,
    required double size,
    String? initials,
  }) {
    Widget placeholder() {
      if (initials != null && initials.trim().isNotEmpty) {
        return Container(
          width: size,
          height: size,
          color: const Color(0xFFE8EDF5),
          alignment: Alignment.center,
          child: Text(
            initials.trim().characters.first.toUpperCase(),
            style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4A607A),
            ),
          ),
        );
      }

      return Container(
        width: size,
        height: size,
        color: const Color(0xFFE8EDF5),
        alignment: Alignment.center,
        child: Icon(
          Icons.person_rounded,
          size: size * 0.52,
          color: const Color(0xFF6B7280),
        ),
      );
    }

    final trimmed = imageData.trim();
    if (trimmed.isEmpty || isInvalidImageValue(trimmed)) {
      return ClipOval(child: placeholder());
    }

    final normalizedUrl = normalizeImageUrl(trimmed);
    if (normalizedUrl.startsWith('http://') ||
        normalizedUrl.startsWith('https://')) {
      final token = SharedPref.getLoginData().result?.token;
      final headers = <String, String>{'Accept': 'image/*,*/*;q=0.8'};
      if (_safeScalar(token).isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      return ClipOval(
        child: Image.network(
          normalizedUrl,
          fit: BoxFit.cover,
          width: size,
          height: size,
          headers: headers,
          errorBuilder: (_, __, ___) => placeholder(),
        ),
      );
    }

    try {
      var base64String = trimmed;
      if (trimmed.contains('base64,')) {
        base64String = trimmed.split('base64,').last;
      }
      final bytes = base64Decode(base64String);
      return ClipOval(
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => placeholder(),
        ),
      );
    } catch (_) {
      return ClipOval(child: placeholder());
    }
  }
}
