import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_city_helper.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HomeGreetingSection extends StatefulWidget {
  const HomeGreetingSection({super.key});

  @override
  State<HomeGreetingSection> createState() => _HomeGreetingSectionState();
}

class _HomeGreetingSectionState extends State<HomeGreetingSection> {
  String _city = HomeCityHelper.cachedCity;

  @override
  void initState() {
    super.initState();
    _loadCity();
  }

  Future<void> _loadCity() async {
    final city = await HomeCityHelper.fetchCity();
    if (mounted) setState(() => _city = city);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _firstName() {
    final login = SharedPref.getLoginData();
    final name = login.result?.data?.name?.trim();
    if (name == null || name.isEmpty) return 'there';
    return name.split(' ').first;
  }

  TextStyle get _maroonBold => GoogleFonts.poppins(
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
        color: HomeGlassTheme.maroon,
      );

  TextStyle get _maroonRegular => GoogleFonts.poppins(
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
        color: HomeGlassTheme.maroon,
      );

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE, d MMM').format(DateTime.now());

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 16.w, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${_greeting()} ', style: _maroonBold),
                    Text(
                      '✦',
                      style: _maroonBold.copyWith(fontSize: 11.sp),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  _firstName(),
                  style: GoogleFonts.poppins(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w800,
                    color: HomeGlassTheme.textPrimary,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(dateLabel, style: _maroonRegular),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Text(
                        '·',
                        style: _maroonRegular.copyWith(
                          color: HomeGlassTheme.maroon.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    const HomeMaroonLocationMarker(size: 14),
                    SizedBox(width: 3.w),
                    Flexible(
                      child: Text(
                        _city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _maroonRegular,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: () => HomeNavigation.goToHome(context),
            child: Opacity(
              opacity: 0.38,
              child: Image.asset(
                'assets/gif/el-race-logo.gif',
                height: 72.h,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
