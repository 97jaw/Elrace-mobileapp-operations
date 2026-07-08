import 'dart:convert';
import 'dart:typed_data';

import 'package:el_race/core/app_globals.dart';
import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Notification/notification_mute_settings_screen.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_widgets/profile_logout_helper.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_widgets/profile_sheet_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_widgets/profile_user_info.dart';
import 'package:el_race/ui/presentation/qr_code/data/repository.dart';
import 'package:el_race/ui/presentation/qr_code/qr_scanner_screen.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfileBottomSheet {
  ProfileBottomSheet._();

  static Future<void> show(BuildContext context) {
    final sheetContext = navKey.currentContext ?? context;
    return showModalBottomSheet<void>(
      context: sheetContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: ProfileSheetTheme.navy.withValues(alpha: 0.22),
      useRootNavigator: true,
      builder: (_) => const _ProfileBottomSheetBody(),
    );
  }
}

class _ProfileBottomSheetBody extends StatefulWidget {
  const _ProfileBottomSheetBody();

  @override
  State<_ProfileBottomSheetBody> createState() =>
      _ProfileBottomSheetBodyState();
}

class _ProfileBottomSheetBodyState extends State<_ProfileBottomSheetBody> {
  final QrCodeRepository _qrCodeRepository = QrCodeRepository();
  Uint8List? _qrCodeData;
  bool _isLoadingQr = true;
  String? _qrErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadQrCode();
  }

  Future<void> _loadQrCode() async {
    setState(() {
      _isLoadingQr = true;
      _qrErrorMessage = null;
    });

    try {
      final qrData = await _qrCodeRepository.getQrCodeImageDirect();
      if (!mounted) return;

      if (qrData != null && qrData.isNotEmpty) {
        setState(() {
          _qrCodeData = qrData;
          _isLoadingQr = false;
        });
      } else {
        setState(() {
          _qrCodeData = null;
          _isLoadingQr = false;
          _qrErrorMessage = 'QR code not available. Check your connection.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingQr = false;
        _qrCodeData = null;
        _qrErrorMessage = 'Unable to load QR code. Check your connection.';
      });
    }
  }

  ImageProvider _profileImage() {
    final imageData = SharedPref().getUserBase64Image();
    if (imageData.isEmpty) {
      return const AssetImage('assets/png/profile_1.png');
    }
    if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
      return NetworkImage(imageData);
    }
    if (Util.isValidBase64(imageData)) {
      try {
        return MemoryImage(base64Decode(imageData));
      } catch (_) {
        return const AssetImage('assets/png/profile_1.png');
      }
    }
    return const AssetImage('assets/png/profile_1.png');
  }

  void _openNotificationSettings() {
    Navigator.of(context).pop();
    final hostContext = navKey.currentContext ?? context;
    Navigator.of(hostContext).push(
      MaterialPageRoute(
        builder: (_) => const NotificationMuteSettingsScreen(),
      ),
    );
  }

  void _openLinkedDevices() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Linked Devices',
          style: TextStyle(
            color: ProfileSheetTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18.sp,
          ),
        ),
        content: Text(
          'Linked Devices management is coming soon.',
          style: TextStyle(
            color: ProfileSheetTheme.textSecondary,
            fontSize: 14.sp,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: ProfileSheetTheme.navySoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openBusinessCard() {
    Navigator.of(context).pop();
    final hostContext = navKey.currentContext ?? context;
    Navigator.of(hostContext).push(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
  }

  Future<void> _logout() async {
    // Capture root context before closing the sheet — after pop(), this widget
    // is unmounted and its BuildContext must not be used for logout.
    final rootContext = navKey.currentContext ?? context;
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await ProfileLogoutHelper.confirmAndLogout(rootContext);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: ProfileSheetTheme.sheetBackground,
                ),
              ),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: ProfileSheetTheme.metallicOverlay,
                  ),
                ),
              ),
              Column(
                children: [
                  SizedBox(height: 10.h),
                  Container(
                    width: 42.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: ProfileSheetTheme.silver.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
                    child: Row(
                      children: [
                        SizedBox(width: 40.w),
                        Expanded(
                          child: Text(
                            'My Profile',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              color: ProfileSheetTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        _CircleIconButton(
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      clipBehavior: Clip.none,
                      padding: EdgeInsets.fromLTRB(
                        20.w,
                        0,
                        20.w,
                        bottomInset + 20.h,
                      ),
                      children: [
                        _ProfileIdentityCard(
                          name: ProfileUserInfo.displayName(),
                          image: _profileImage(),
                          isActive: ProfileUserInfo.isActive,
                          fileId: ProfileUserInfo.displayOrDash(
                            ProfileUserInfo.displayEmployeeId(),
                          ),
                          designation: ProfileUserInfo.displayOrDash(
                            ProfileUserInfo.displayJobId(),
                          ),
                          departmentSection:
                              ProfileUserInfo.displayDepartmentSection(),
                          isLoadingQr: _isLoadingQr,
                          qrData: _qrCodeData,
                          qrErrorMessage: _qrErrorMessage,
                          onRetryQr: _loadQrCode,
                          onBusinessCard: _openBusinessCard,
                        ),
                        SizedBox(height: 16.h),
                        _SettingsCard(
                          onNotificationSettings: _openNotificationSettings,
                          onLinkedDevices: _openLinkedDevices,
                          onLogout: _logout,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Reference layout: overlapping avatar header + badges + QR + footer row.
class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({
    required this.name,
    required this.image,
    required this.isActive,
    required this.fileId,
    required this.designation,
    required this.departmentSection,
    required this.isLoadingQr,
    required this.qrData,
    required this.qrErrorMessage,
    required this.onRetryQr,
    required this.onBusinessCard,
  });

  final String name;
  final ImageProvider image;
  final bool isActive;
  final String fileId;
  final String designation;
  final String departmentSection;
  final bool isLoadingQr;
  final Uint8List? qrData;
  final String? qrErrorMessage;
  final VoidCallback onRetryQr;
  final VoidCallback onBusinessCard;

  static const _avatarSize = 96.0;

  @override
  Widget build(BuildContext context) {
    final cardRadius = BorderRadius.circular(28.r);
    final avatarTopInset = (_avatarSize / 2).h;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: EdgeInsets.only(top: avatarTopInset),
          child: ClipRRect(
            borderRadius: cardRadius,
            child: AdaptiveGlassLayer(
              borderRadius: cardRadius,
              sigma: 18,
              fallbackColor: const Color(0xFFC4959F).withValues(alpha: 0.88),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: cardRadius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.78),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ProfileSheetTheme.navy.withValues(alpha: 0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        18.w,
                        avatarTopInset + 8.h,
                        18.w,
                        18.h,
                      ),
                      decoration: const BoxDecoration(
                        gradient: ProfileSheetTheme.profileHeaderGradient,
                      ),
                      child: Column(
                        children: [
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.25,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          _BadgePairRow(
                            left: _InlineFadedBadge(
                              label: 'File ID',
                              value: fileId,
                            ),
                            right: _InlineFadedBadge(
                              label: 'Designation',
                              value: designation,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
                      decoration: const BoxDecoration(
                        gradient: ProfileSheetTheme.profileCardGradient,
                      ),
                      child: Column(
                        children: [
                          _FooterInfoSection(
                            departmentSection: departmentSection,
                            onQrLink: onBusinessCard,
                          ),
                          SizedBox(height: 14.h),
                          Center(
                            child: _QrFrame(
                              isLoading: isLoadingQr,
                              qrData: qrData,
                              isActive: isActive,
                            ),
                          ),
                          if (qrErrorMessage != null) ...[
                            SizedBox(height: 10.h),
                            Text(
                              qrErrorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: ProfileSheetTheme.accentRed,
                              ),
                            ),
                            TextButton(
                              onPressed: onRetryQr,
                              child: Text(
                                'Retry',
                                style: TextStyle(
                                  color: ProfileSheetTheme.navySoft,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: 14.h),
                          SizedBox(
                            width: 230.w,
                            child: _BusinessCardButton(
                              onTap: onBusinessCard,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          child: _ProfileAvatar(image: image, isActive: isActive),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.image,
    required this.isActive,
  });

  final ImageProvider image;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    const size = _ProfileIdentityCard._avatarSize;

    return SizedBox(
      width: size.w,
      height: size.w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size.w,
            height: size.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: ProfileSheetTheme.navy.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Padding(
              padding: EdgeInsets.all(3.w),
              child: CircleAvatar(
                radius: (size / 2 - 7).r,
                backgroundImage: image,
              ),
            ),
          ),
          Positioned(
            right: 6.w,
            bottom: 6.w,
            child: Container(
              width: 18.w,
              height: 18.w,
              decoration: BoxDecoration(
                color: isActive
                    ? ProfileSheetTheme.messengerOnline
                    : ProfileSheetTheme.messengerOffline,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgePairRow extends StatelessWidget {
  const _BadgePairRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: 10.w),
        Expanded(child: right),
      ],
    );
  }
}

class _InlineFadedBadge extends StatelessWidget {
  const _InlineFadedBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.34),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterInfoSection extends StatelessWidget {
  const _FooterInfoSection({
    required this.departmentSection,
    required this.onQrLink,
  });

  final String departmentSection;
  final VoidCallback onQrLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 10.h),
      decoration: BoxDecoration(
        gradient: ProfileSheetTheme.maroonInfoSection,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.36),
        ),
      ),
      child: Column(
        children: [
          _BadgePairRow(
            left: _InfoBadge(
              label: 'Dept - Section',
              value: departmentSection,
            ),
            right: _QrLinkBadge(onTap: onQrLink),
          ),
        ],
      ),
    );
  }
}

class _QrLinkBadge extends StatelessWidget {
  const _QrLinkBadge({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: ProfileSheetTheme.maroonPale.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: ProfileSheetTheme.navy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'QR Link',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.sp,
              color: ProfileSheetTheme.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                size: 18.sp,
                color: ProfileSheetTheme.maroon,
              ),
              SizedBox(width: 4.w),
              Text(
                'Scan QR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: ProfileSheetTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

class _BusinessCardButton extends StatelessWidget {
  const _BusinessCardButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.badge_outlined, size: 16.sp),
      label: const Text('Business Card'),
      style: FilledButton.styleFrom(
        backgroundColor: ProfileSheetTheme.navy,
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, 44.h),
        textStyle: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: ProfileSheetTheme.maroonPale.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: ProfileSheetTheme.navy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.sp,
              color: ProfileSheetTheme.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.sp,
              color: ProfileSheetTheme.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrFrame extends StatelessWidget {
  const _QrFrame({
    required this.isLoading,
    required this.qrData,
    required this.isActive,
  });

  final bool isLoading;
  final Uint8List? qrData;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230.w,
      height: 230.w,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isActive
              ? ProfileSheetTheme.activeGreen.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.95),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: ProfileSheetTheme.navy.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildContent(),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                gradient: ProfileSheetTheme.qrOverlay,
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.14),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: ProfileSheetTheme.navySoft,
        ),
      );
    }

    if (qrData != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Image.memory(
          qrData!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.qr_code_2_rounded,
          size: 52.sp,
          color: ProfileSheetTheme.textMuted.withValues(alpha: 0.6),
        ),
        SizedBox(height: 8.h),
        Text(
          'No QR available',
          style: TextStyle(
            fontSize: 12.sp,
            color: ProfileSheetTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.onNotificationSettings,
    required this.onLinkedDevices,
    required this.onLogout,
  });

  final VoidCallback onNotificationSettings;
  final VoidCallback onLinkedDevices;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ProfileSheetTheme.glassCard(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notification Settings',
            subtitle: 'Alerts, mute & preferences',
            onTap: onNotificationSettings,
          ),
          _SettingsDivider(),
          _SettingsTile(
            icon: Icons.devices_rounded,
            title: 'Linked Devices',
            subtitle: 'Manage connected devices',
            onTap: onLinkedDevices,
            showChevron: false,
          ),
          _SettingsDivider(),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            onTap: onLogout,
            titleColor: ProfileSheetTheme.accentRed,
            iconBackground: const Color(0xFFFFEEF0),
            iconColor: ProfileSheetTheme.accentRed,
            showChevron: false,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
    this.iconBackground,
    this.iconColor,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconBackground;
  final Color? iconColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: iconBackground ??
                      ProfileSheetTheme.maroonPale.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 22.sp,
                  color: iconColor ?? ProfileSheetTheme.maroon,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: titleColor ?? ProfileSheetTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: ProfileSheetTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: ProfileSheetTheme.textMuted,
                  size: 22.sp,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 72.w,
      endIndent: 14.w,
      color: ProfileSheetTheme.silver.withValues(alpha: 0.55),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: BackdropFilter(
        filter: HomeGlassTheme.glassBlur,
        child: Material(
          color: Colors.white.withValues(alpha: 0.78),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 40.w,
              height: 40.w,
              child: Icon(
                icon,
                size: 22.sp,
                color: ProfileSheetTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
