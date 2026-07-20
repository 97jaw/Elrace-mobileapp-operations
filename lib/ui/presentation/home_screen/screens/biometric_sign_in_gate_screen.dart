import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shown when post-login biometric is cancelled/missed — not a logout screen.
class BiometricSignInGateScreen extends StatelessWidget {
  const BiometricSignInGateScreen({
    super.key,
    required this.onSignInWithBiometric,
  });

  final Future<void> Function() onSignInWithBiometric;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F6FA),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Image.asset(
                'assets/images/business_card/company_logo.png',
                width: 120.w,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.business,
                  size: 72.sp,
                  color: const Color(0xFF1F3A5F),
                ),
              ),
              SizedBox(height: 28.h),
              Text(
                'Authentication required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF17233A),
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Use Face ID or fingerprint to continue.\nYour session stays active — this is not a logout.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF7A8194),
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: FilledButton.icon(
                  onPressed: () => onSignInWithBiometric(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1F3A5F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: Text(
                    'Sign in with biometric',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 28.h),
            ],
          ),
        ),
      ),
    );
  }
}
