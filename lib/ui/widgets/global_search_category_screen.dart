import 'package:el_race/data/models/global_search_item.dart';
import 'package:el_race/providers/global_search_provider.dart';
import 'package:el_race/ui/chat/widgets/chat_unified_header_backdrop.dart';
import 'package:el_race/ui/widgets/global_search_item_builder.dart';
import 'package:el_race/ui/widgets/global_search_theme.dart';
import 'package:el_race/utils/global_search_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_translate/flutter_translate.dart';

/// Full vertical list for one global-search category (opened from "See more").
class GlobalSearchCategoryScreen extends StatefulWidget {
  const GlobalSearchCategoryScreen({
    super.key,
    required this.category,
    required this.categoryTitle,
    required this.keyword,
  });

  final String category;
  final String categoryTitle;
  final String keyword;

  @override
  State<GlobalSearchCategoryScreen> createState() =>
      _GlobalSearchCategoryScreenState();
}

class _GlobalSearchCategoryScreenState extends State<GlobalSearchCategoryScreen> {
  late final GlobalSearchItemBuilder _itemBuilder;
  List<GlobalSearchItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _itemBuilder = GlobalSearchItemBuilder(
      onTap: _navigateToDetail,
      highlight: _highlight,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<GlobalSearchProvider>().fetchCategoryList(
            category: widget.category,
            keyword: widget.keyword,
          );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _navigateToDetail(GlobalSearchItem item) {
    GlobalSearchNavigationHelper.navigateToDetail(context, item);
  }

  Widget _highlight(
    String text,
    String keyword, {
    required TextStyle style,
  }) {
    if (keyword.isEmpty) return Text(text, style: style);
    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    int indexOfKeyword;
    while ((indexOfKeyword = lowerText.indexOf(lowerKeyword, start)) != -1) {
      if (indexOfKeyword > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfKeyword)));
      }
      spans.add(TextSpan(
        text: text.substring(indexOfKeyword, indexOfKeyword + keyword.length),
        style: style.copyWith(
          backgroundColor: GlobalSearchTheme.maroon.withValues(alpha: 0.85),
          color: GlobalSearchTheme.white,
          fontWeight: FontWeight.w700,
        ),
      ));
      start = indexOfKeyword + keyword.length;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlobalSearchTheme.screenBase,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: ChatUnifiedHeaderBackdrop.layer()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CategoryGlassHeader(
                title: widget.categoryTitle,
                keyword: widget.keyword,
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(0, 8.h, 0, 24.h),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
          child: Container(
            height: 120.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              color: GlobalSearchTheme.white.withValues(alpha: 0.2),
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: GlobalSearchTheme.onGlassMuted,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 16.h),
              TextButton(
                onPressed: _load,
                child: Text(translate('search.retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          translate('search.no_results'),
          style: GoogleFonts.poppins(
            color: GlobalSearchTheme.onGlassMuted,
            fontSize: 14.sp,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(0, 8.h, 0, 24.h),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        return _itemBuilder.buildCard(_items[index], widget.keyword);
      },
    );
  }
}

class _CategoryGlassHeader extends StatelessWidget {
  const _CategoryGlassHeader({
    required this.title,
    required this.keyword,
  });

  final String title;
  final String keyword;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100.h + MediaQuery.paddingOf(context).top,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.r)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ChatUnifiedHeaderBackdrop.layer(),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
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
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (keyword.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Text(
                        keyword,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
