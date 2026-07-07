import 'package:el_race/ui/chat/widgets/chat_sub_app_glass_bar.dart';
import 'package:el_race/ui/chat/widgets/chat_unified_header_backdrop.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:el_race/ui/widgets/global_search_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Glass header: back + title + light blue gradient search field.
class GlobalSearchHeader extends StatelessWidget {
  const GlobalSearchHeader({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchClear,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;

  static double extent(BuildContext context) {
    return SubAppGlassAppBar.extent(context) + 112.h;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: extent(context),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.r)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ChatUnifiedHeaderBackdrop.layer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SubAppGlassAppBar(),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 12.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  HomeNavigation.handleSystemBack(context),
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18.sp,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: 32.w,
                                minHeight: 32.w,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                translate('search.global_title'),
                                style: GoogleFonts.poppins(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14.r),
                              gradient: GlobalSearchTheme.searchBarGradient,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.75),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.18),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: searchController,
                              onChanged: onSearchChanged,
                              autofocus: true,
                              style: GoogleFonts.poppins(
                                fontSize: 14.sp,
                                color: GlobalSearchTheme.searchInputText,
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: GlobalSearchTheme.navy,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText:
                                    translate('search.global_placeholder'),
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 13.sp,
                                  color: GlobalSearchTheme.searchHintText,
                                  fontWeight: FontWeight.w500,
                                ),
                                filled: false,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 12.h,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: const Color(0xFF3B6FD4),
                                  size: 22.sp,
                                ),
                                prefixIconConstraints: BoxConstraints(
                                  minWidth: 44.w,
                                  minHeight: 40.h,
                                ),
                                suffixIcon: searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.close_rounded,
                                          size: 20.sp,
                                          color: const Color(0xFF6B7A99),
                                        ),
                                        onPressed: onSearchClear,
                                      )
                                    : null,
                                suffixIconConstraints: BoxConstraints(
                                  minWidth: 40.w,
                                  minHeight: 40.h,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
