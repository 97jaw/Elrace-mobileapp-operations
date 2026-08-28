import 'package:el_race/core/hr_management/routing/hr_route_names.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_request/RequestEffectiveDate.dart';
import 'package:el_race/ui/presentation/my_request/RequestJobMissionPage.dart';
import 'package:el_race/ui/presentation/my_request/RequestLeavePageNew.dart';
import 'package:el_race/ui/presentation/my_request/RequestPermission.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class HrManagementMenuPage extends ConsumerWidget {
  const HrManagementMenuPage({super.key});

  Widget _pillButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: 24.w),
          padding: EdgeInsets.symmetric(vertical: 20.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFDDE1E7), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
              color: const Color(0xFF1A1A53),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final login = SharedPref.getLoginData();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const HeaderWidget(),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 30.h),
            child: Column(
              children: [
                Text(
                  'HR MANAGEMENT',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: const Color(0xFF1A1A53),
                  ),
                ),
                SizedBox(height: 20.h),
                _pillButton(
                  context: context,
                  label: 'Sick Leave',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestLeavePageNew(
                          loginResponseModel: login,
                          leaveType: 'SICK',
                        ),
                      ),
                    );
                  },
                ),
                _pillButton(
                  context: context,
                  label: 'Short Leave',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestLeavePageNew(
                          loginResponseModel: login,
                          leaveType: 'SHORT',
                        ),
                      ),
                    );
                  },
                ),
                _pillButton(
                  context: context,
                  label: 'Annual Leave',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestLeavePageNew(
                          loginResponseModel: login,
                          leaveType: 'ANNUAL',
                        ),
                      ),
                    );
                  },
                ),
                _pillButton(
                  context: context,
                  label: 'Effective Date',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EffectiveDatePage(
                          loginResponseModel: login,
                        ),
                      ),
                    );
                  },
                ),
                _pillButton(
                  context: context,
                  label: 'Temporary Permission',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestPermission(
                          loginResponseModel: login,
                        ),
                      ),
                    );
                  },
                ),
                _pillButton(
                  context: context,
                  label: 'Job Mission',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestJobMissionPage(
                          loginResponseModel: login,
                        ),
                      ),
                    );
                  },
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 8.h),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'More requests',
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A53),
                      ),
                    ),
                  ),
                ),
                _pillButton(
                  context: context,
                  label: 'Car Allowance',
                  onTap: () {
                    Navigator.of(context)
                        .pushNamed(HrRouteNames.carAllowanceRequest);
                  },
                ),
                if (kDebugMode) ...[
                  SizedBox(height: 24.h),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context)
                          .pushNamed(HrRouteNames.widgetSandbox);
                    },
                    child: Text(
                      'F.2 widget sandbox',
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A53),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
