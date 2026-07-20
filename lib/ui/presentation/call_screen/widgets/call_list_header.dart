import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/chat/widgets/chat_sub_app_glass_bar.dart';
import 'package:el_race/ui/chat/widgets/chat_unified_header_backdrop.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Merged glass + navy header for the contacts (call) tab — matches chat list chrome.
class CallListHeaderDelegate extends SliverPersistentHeaderDelegate {
  CallListHeaderDelegate({
    required double topBarExtent,
    required this.searchController,
    required this.onSearchChanged,
    required this.onSearchClear,
  }) : _topBarExtent = topBarExtent;

  final double _topBarExtent;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;

  static double get contentHeight => 96.th;

  @override
  double get minExtent => _topBarExtent + contentHeight;

  @override
  double get maxExtent => _topBarExtent + contentHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: maxExtent,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20.tr),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ChatUnifiedHeaderBackdrop.layer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SubAppGlassAppBar(),
                SizedBox(
                  height: contentHeight,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.tw, 4.th, 14.tw, 10.th),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  HomeNavigation.handleSystemBack(context),
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 18.tsp,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: 32.tw,
                                minHeight: 32.tw,
                              ),
                            ),
                            SizedBox(width: 4.tw),
                            Icon(
                              Icons.contacts_rounded,
                              color: Colors.white,
                              size: 20.tsp,
                            ),
                            SizedBox(width: 8.tw),
                            Expanded(
                              child: Text(
                                translate('home.contact'),
                                style: GoogleFonts.poppins(
                                  fontSize: 17.tsp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.th),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: onSearchChanged,
                            style: TextStyle(
                              fontSize: 14.tsp,
                              color: const Color(0xFF1A2248),
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  translate('home.search_by_name_or_id'),
                              hintStyle: TextStyle(
                                fontSize: 13.tsp,
                                color: const Color(0xFF8E98A8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14.tw,
                                vertical: 10.th,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24.tr),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: const Color(0xFF6E7A92),
                                size: 22.tsp,
                              ),
                              suffixIcon: searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 20,
                                      ),
                                      onPressed: onSearchClear,
                                    )
                                  : null,
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

  @override
  bool shouldRebuild(covariant CallListHeaderDelegate oldDelegate) {
    return oldDelegate.searchController.text != searchController.text;
  }
}
