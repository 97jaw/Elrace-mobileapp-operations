import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/recruitment/models/requisition.dart';
import 'package:el_race/core/recruitment/recruitment_job_share.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_gradient_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Share an open position externally (careers page + employee reference name).
class RecruitmentReferralScreen extends StatelessWidget {
  const RecruitmentReferralScreen({super.key, required this.requisition});

  final Requisition requisition;

  @override
  Widget build(BuildContext context) {
    final r = requisition;
    final login = SharedPref.getLoginData().result?.data;
    final referenceName =
        (login?.name ?? login?.emp_name ?? '').trim().isNotEmpty
            ? (login?.name ?? login?.emp_name ?? '').trim()
            : 'EL RACE Employee';

    return RecruitmentGradientScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HrModuleGlassHeader(
            title: 'Share position',
            accentTint: HrModuleHeaderTints.recruitment,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.tw),
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.tr),
                  decoration: BoxDecoration(
                    color: HrModuleColors.surface,
                    borderRadius:
                        BorderRadius.circular(HrModuleLayout.cardRadius.tr),
                    boxShadow: HrModuleColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.jobTitle,
                        style: HrModuleTypography.cardTitle()
                            .copyWith(fontSize: 16.tsp),
                      ),
                      SizedBox(height: 4.th),
                      Text(
                        '${r.referenceNumber} · ${r.department} · ${r.location}',
                        style: HrModuleTypography.caption()
                            .copyWith(fontSize: 12.tsp),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.th),
                Text(
                  'Share this opening with friends or colleagues.',
                  style: HrModuleTypography.body().copyWith(fontSize: 14.tsp),
                ),
                SizedBox(height: 12.th),
                Text(
                  'Reference Name: $referenceName',
                  style: HrModuleTypography.sectionHeading()
                      .copyWith(fontSize: 14.tsp),
                ),
                SizedBox(height: 8.th),
                Text(
                  'https://elrace.com/careers',
                  style: HrModuleTypography.body().copyWith(
                        fontSize: 13.tsp,
                        color: HrModuleColors.primary,
                      ),
                ),
                SizedBox(height: 28.th),
                FilledButton.icon(
                  onPressed: () =>
                      shareRecruitmentPosition(context, requisition: r),
                  icon: const Icon(Icons.ios_share),
                  style: FilledButton.styleFrom(
                    backgroundColor: HrModuleColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: Size.fromHeight(HrModuleLayout.buttonHeight.th),
                  ),
                  label: Text(
                    'Share via…',
                    style: TextStyle(fontSize: 14.tsp),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
