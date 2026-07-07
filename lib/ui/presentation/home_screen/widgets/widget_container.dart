import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/screens/custom_swipe_button.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/list_view_widgets.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/my_actions_section.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/orientation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

class WidgetContainer extends StatelessWidget {
  const WidgetContainer({super.key});

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = SharedPref.isUserAuthenticated();
    final loginData = SharedPref.getLoginData();
    final isCheckInWidgetDisabled =
        loginData.result?.data?.defaultWidgets?.data?.checkinWidget?.isDisabled ==
            true;
    final isSwipeEnabled = isAuthenticated && !isCheckInWidgetDisabled;

    return Container(
      //width: ScreenUtil().screenWidth,
      width: double.infinity,
      decoration: BoxDecoration(
        color: white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, -8), // shadow بس من فوق
          ),
        ],
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20.r),
          topLeft: Radius.circular(20.r),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: SizeConfig().getWidth(20)),
            child: Column(
              children: [
                SizedBox(height: 15.h),

                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: SizeConfig().getWidth(20)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        translate('home.my_widgets'),
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF484848),
                        ),
                      ),
                      /* GestureDetector(
                        onTap: () =>
                            Util.pushPage(const EditWidgetsScreen(), context),
                        child: Text(
                          translate('home.edit'),
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF858585),
                          ),
                        ),
                      ),
                      */
                    ],
                  ),
                ),

                Opacity(
                  opacity: isSwipeEnabled ? 1 : 0.5,
                  child: SizedBox(
                    width: double.infinity,
                    height: 190.h,
                    child: Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: 6.h),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23.r),
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: Image(
                                image: AssetImage(
                                  'assets/newapp/widgets_background.png',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                            const Positioned.fill(
                              child: IgnorePointer(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Image(
                                    image: AssetImage(
                                      'assets/newapp/vector_curved_forswip_widget.png',
                                    ),
                                    fit: BoxFit.fitHeight,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: 32.h, horizontal: 35.w),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Swipe button
                                  IgnorePointer(
                                    ignoring: !isSwipeEnabled,
                                    child: const CustomSwipeButton(),
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

                SizedBox(height: 14.h),
              ],
            ),
          ),
          const MyActionsSection(),
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: SizeConfig().getWidth(20)),
            child: Column(
              children: [
                SizedBox(height: 10.w),
                const ListViewWidgets(),

                // prayer times card
              ],
            ),
          ),
        ],
      ),
      );
  }
}
