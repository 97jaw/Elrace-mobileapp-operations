import 'dart:ui';

import 'package:el_race/resources/app_colors.dart';
import 'package:el_race/ui/chat/widgets/chat_unified_header_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Employee row styled like the chat list — white card, gold avatar ring, inline actions.
class EmployeeContactTile extends StatelessWidget {
  const EmployeeContactTile({
    super.key,
    required this.imageUrl,
    required this.displayName,
    required this.department,
    required this.job,
    required this.empId,
    required this.isExpanded,
    required this.onTap,
    required this.onCall,
    required this.onWhatsApp,
    required this.onEmail,
    this.canCall = true,
    this.showDivider = true,
  });

  final String imageUrl;
  final String displayName;
  final String department;
  final String job;
  final String empId;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onEmail;
  /// True only when contact has company `mobile_phone`.
  final bool canCall;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (department.isNotEmpty) department,
      if (job.isNotEmpty) job,
      if (empId.isNotEmpty) empId,
    ];

    return Material(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatar(),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF171717),
                            height: 1.2,
                          ),
                        ),
                        if (subtitleParts.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            subtitleParts.join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8B8B8B),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _ContactMeChip(expanded: isExpanded),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            sizeCurve: Curves.easeInOut,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
              child: _ContactActionsRow(
                onCall: onCall,
                onWhatsApp: onWhatsApp,
                onEmail: onEmail,
                canCall: canCall,
              ),
            ),
          ),
          if (showDivider)
            Padding(
              padding: EdgeInsets.only(left: 68.w),
              child: const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFE5E5E5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final hasImage = imageUrl.isNotEmpty && imageUrl != 'null';
    return Container(
      padding: EdgeInsets.all(1.5.w),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ChatSurfaceTheme.accentGold,
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 24.r,
        backgroundColor: const Color(0xFFECECEC),
        backgroundImage:
            hasImage ? NetworkImage(imageUrl) : null,
        child: !hasImage
            ? Text(
                _initials(displayName),
                style: TextStyle(
                  color: const Color(0xFF2E2E2E),
                  fontWeight: FontWeight.w700,
                  fontSize: 14.sp,
                ),
              )
            : null,
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class _ContactMeChip extends StatelessWidget {
  const _ContactMeChip({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.35),
          width: 1,
        ),
        color: expanded
            ? AppColors.primaryColor.withValues(alpha: 0.08)
            : Colors.transparent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            translate('home.contact_me'),
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryColor,
            ),
          ),
          SizedBox(width: 4.w),
          Icon(
            expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 18.sp,
            color: AppColors.primaryColor,
          ),
        ],
      ),
    );
  }
}

class _ContactActionsRow extends StatelessWidget {
  const _ContactActionsRow({
    required this.onCall,
    required this.onWhatsApp,
    required this.onEmail,
    required this.canCall,
  });

  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback onEmail;
  final bool canCall;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryColor.withValues(alpha: 0.06),
                ChatSurfaceTheme.dateChipFill,
              ],
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: AppColors.primaryColor.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionButton(
                asset: 'assets/png/call.png',
                label: 'Call',
                onTap: canCall ? onCall : null,
                enabled: canCall,
              ),
              _ActionButton(
                asset: 'assets/png/whatsapp.png',
                label: 'WhatsApp',
                onTap: onWhatsApp,
              ),
              _ActionButton(
                asset: 'assets/png/email.png',
                label: 'Email',
                onTap: onEmail,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.asset,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String asset;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? AppColors.primaryColor
        : AppColors.primaryColor.withValues(alpha: 0.35);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: ChatSurfaceTheme.accentGold
                      .withValues(alpha: enabled ? 0.6 : 0.25),
                  width: 1.2,
                ),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: Image.asset(
                  asset,
                  color: color,
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Parses API name format into a display name.
String formatEmployeeDisplayName(String rawName) {
  final nameParts = rawName.split(' ');
  final nameOnly = nameParts.length > 1 ? nameParts.sublist(1) : nameParts;
  if (nameOnly.length > 1) {
    return '${nameOnly.first} ${nameOnly.last}';
  }
  return nameOnly.isNotEmpty ? nameOnly[0] : rawName;
}
