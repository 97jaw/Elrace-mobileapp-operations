import 'package:cached_network_image/cached_network_image.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/material.dart';

abstract final class CheckinEmployeeAvatar {
  static String? imageUrl() {
    final data = SharedPref.getLoginData().result?.data;
    final fromLogin = data?.image_url;
    if (fromLogin != null && fromLogin.isNotEmpty) return fromLogin;

    final employeeId = data?.employee_id;
    if (employeeId != null && employeeId > 0) {
      return 'https://erp.elrace.com/public/employee/image/$employeeId';
    }
    return null;
  }

  static Widget marker({double size = 44}) {
    final url = imageUrl();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => _fallback(size),
              errorWidget: (_, __, ___) => _fallback(size),
            )
          : _fallback(size),
    );
  }

  static Widget _fallback(double size) {
    return Container(
      color: const Color(0xFF2563EB),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }
}
