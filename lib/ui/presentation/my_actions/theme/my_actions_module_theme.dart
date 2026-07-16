import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

enum MyActionFilter { all, pending, approved, rejected }

enum MyActionsModule { hr, rfq, pettyCash, invoice, signature, myRequests }

class MyActionsModuleTheme {
  const MyActionsModuleTheme({
    required this.primary,
    required this.deep,
    required this.soft,
    required this.wash,
    required this.tint,
    required this.gradient,
    required this.title,
    required this.iconAsset,
  });

  final Color primary;
  final Color deep;
  final Color soft;
  final Color wash;
  final Color tint;
  final LinearGradient gradient;
  final String title;
  final String iconAsset;

  static const Color white = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1B1F2E);
  static const Color textMuted = Color(0xFF8E95A3);
  static const Color textOnGradient = Color(0xFFFFFFFF);
  static const Color pending = Color(0xFFF5A623);
  static const Color approved = Color(0xFF2EAE6D);
  static const Color rejected = Color(0xFFE04B4B);

  static const SystemUiOverlayStyle lightOnGradient = SystemUiOverlayStyle(
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    statusBarColor: Colors.transparent,
  );

  static MyActionsModuleTheme of(MyActionsModule module) {
    switch (module) {
      case MyActionsModule.hr:
        return const MyActionsModuleTheme(
          primary: Color(0xFFD21B2E),
          deep: Color(0xFFB91525),
          soft: Color(0xFFF8D7DA),
          wash: Color(0xFFFFF5F6),
          tint: Color(0xFFFFEBEE),
          title: 'HR Actions',
          iconAsset: 'assets/newapp/newicon/hr.png',
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFCF2234),
              Color(0xFFE8626F),
              Color(0xFFF4B4BA),
              Color(0xFFFCE8EA),
              Color(0xFFFFFAFA),
              Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.18, 0.38, 0.58, 0.78, 1.0],
          ),
        );
      case MyActionsModule.rfq:
        return const MyActionsModuleTheme(
          primary: Color(0xFFBD9B2E),
          deep: Color(0xFF9A7D24),
          soft: Color(0xFFF5EDC4),
          wash: Color(0xFFFFFBEB),
          tint: Color(0xFFFFF8E8),
          title: 'RFQ Actions',
          iconAsset: 'assets/newapp/newicon/rfq.png',
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD4AF37),
              Color(0xFFE8CF6B),
              Color(0xFFF5E6A8),
              Color(0xFFFBF3D4),
              Color(0xFFFFFBEB),
              Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.18, 0.38, 0.58, 0.78, 1.0],
          ),
        );
      case MyActionsModule.pettyCash:
        return const MyActionsModuleTheme(
          primary: Color(0xFF1A5C3A),
          deep: Color(0xFF0F3D24),
          soft: Color(0xFFB8D4C4),
          wash: Color(0xFFE8F2EC),
          tint: Color(0xFFF0F7F3),
          title: 'Petty Cash Actions',
          iconAsset: 'assets/newapp/newicon/Cash.png',
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F3D24),
              Color(0xFF1A5C3A),
              Color(0xFF2D6B4A),
              Color(0xFF6B9A7A),
              Color(0xFFB8D4C4),
              Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.18, 0.38, 0.58, 0.78, 1.0],
          ),
        );
      case MyActionsModule.invoice:
        return const MyActionsModuleTheme(
          primary: Color(0xFFD4562A),
          deep: Color(0xFFAF4522),
          soft: Color(0xFFFAD4C6),
          wash: Color(0xFFFFF5F0),
          tint: Color(0xFFFFF0EA),
          title: 'Invoice Actions',
          iconAsset: 'assets/newapp/newicon/Invoice.png',
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD4562A),
              Color(0xFFE88662),
              Color(0xFFF4B8A4),
              Color(0xFFFADED2),
              Color(0xFFFFF5F0),
              Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.18, 0.38, 0.58, 0.78, 1.0],
          ),
        );
      case MyActionsModule.signature:
        return const MyActionsModuleTheme(
          primary: Color(0xFF7B5EA7),
          deep: Color(0xFF624984),
          soft: Color(0xFFDDD0F0),
          wash: Color(0xFFF5F0FF),
          tint: Color(0xFFF3EDFA),
          title: 'Signature Actions',
          iconAsset: 'assets/png/signarute-frame.png',
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7B5EA7),
              Color(0xFF9E84C0),
              Color(0xFFC4B4DC),
              Color(0xFFE4DCF2),
              Color(0xFFF5F0FF),
              Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.18, 0.38, 0.58, 0.78, 1.0],
          ),
        );
      case MyActionsModule.myRequests:
        return const MyActionsModuleTheme(
          primary: Color(0xFF3D6B9A),
          deep: Color(0xFF2F5478),
          soft: Color(0xFFD0E0F0),
          wash: Color(0xFFF0F4FF),
          tint: Color(0xFFE8EEF8),
          title: 'My Requests',
          iconAsset: 'assets/newapp/newicon/my_action_my_request.png',
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF3D6B9A),
              Color(0xFF6289B0),
              Color(0xFF96B2D0),
              Color(0xFFD0E0F0),
              Color(0xFFF0F4FF),
              Color(0xFFFFFFFF),
            ],
            stops: [0.0, 0.18, 0.38, 0.58, 0.78, 1.0],
          ),
        );
    }
  }

  static MyActionsType? apiTypeFor(MyActionsModule module) {
    switch (module) {
      case MyActionsModule.hr:
        return MyActionsType.hr;
      case MyActionsModule.rfq:
        return MyActionsType.rfq;
      case MyActionsModule.pettyCash:
        return MyActionsType.ptsh;
      case MyActionsModule.invoice:
        return MyActionsType.invoice;
      case MyActionsModule.signature:
        return MyActionsType.signatures;
      case MyActionsModule.myRequests:
        return null;
    }
  }

  static String companyLogoAsset() {
    final id = SharedPref.getSelectedCompany();
    return id == 1 ? 'assets/newapp/logo.png' : 'assets/newapp/logo2.png';
  }

  static String slogan({required int pending, required int total}) {
    if (total == 0) return 'No activity yet — you\'re all clear';
    if (pending == 0) return 'All caught up — nothing needs action';
    if (pending == 1) return '1 item needs your attention';
    return '$pending items need your attention';
  }

  static bool matchesFilter(String status, MyActionFilter filter) {
    final s = status.trim().toLowerCase();
    switch (filter) {
      case MyActionFilter.all:
        return true;
      case MyActionFilter.pending:
        return s.isEmpty ||
            s == 'pending' ||
            s == 'draft' ||
            s == 'submitted' ||
            s == 'to approve';
      case MyActionFilter.approved:
        // Legacy ERP often returns "approve" (no trailing d).
        return s == 'approve' ||
            s == 'approved' ||
            s == 'signed' ||
            s == 'done' ||
            s == 'validate' ||
            s == 'validate2';
      case MyActionFilter.rejected:
        return s == 'rejected' ||
            s == 'refused' ||
            s == 'cancel' ||
            s == 'cancelled' ||
            s == 'canceled';
    }
  }

  static Color statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'approve':
      case 'approved':
      case 'signed':
      case 'done':
      case 'validate':
      case 'validate2':
        return approved;
      case 'rejected':
      case 'refused':
      case 'cancel':
      case 'cancelled':
      case 'canceled':
        return rejected;
      default:
        return pending;
    }
  }

  BoxDecoration glassCard({double radius = 22}) {
    return BoxDecoration(
      color: white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(radius.r),
      border: Border.all(color: white, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: deep.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  BoxDecoration statCard() {
    return BoxDecoration(
      color: white,
      borderRadius: BorderRadius.circular(20.r),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  TextStyle get heroTitle => GoogleFonts.poppins(
        fontSize: 28.sp,
        fontWeight: FontWeight.w700,
        color: textOnGradient,
        height: 1.15,
      );

  TextStyle get heroSlogan => GoogleFonts.poppins(
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        color: textOnGradient.withValues(alpha: 0.9),
        height: 1.35,
      );

  TextStyle get sectionTitle => GoogleFonts.poppins(
        fontSize: 17.sp,
        fontWeight: FontWeight.w700,
        color: textDark,
      );

  TextStyle get cardTitle => GoogleFonts.poppins(
        fontSize: 15.sp,
        fontWeight: FontWeight.w600,
        color: textDark,
      );

  TextStyle get cardSubtitle => GoogleFonts.poppins(
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
        color: textMuted,
      );
}
