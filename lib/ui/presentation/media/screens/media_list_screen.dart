import 'dart:async';
import 'package:el_race/core/utils/responsive_breakpoints.dart';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_access.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/media_bloc.dart';
import '../data/media_model.dart';
import '../data/content_model.dart';
import '../theme/media_theme.dart';
import '../widgets/media_item_widget.dart';
import '../widgets/content_item_widget.dart';
import '../repository/i_media_repository.dart';
import '../utils/media_pdf_pages.dart';
import '../utils/media_video_preloader.dart';
import '../widgets/media_content_landing_screen.dart';
import '../widgets/media_document_viewer.dart';
import '../widgets/media_photo_viewer.dart';
import '../widgets/media_videos_landing_screen.dart';
import 'yoyo_video_player_screen.dart';

/// Toggle to roll back to legacy light UI for all media tabs.
const bool kMediaVideosLandingRedesign = true;

class MediaListScreen extends StatefulWidget {
  const MediaListScreen({super.key});

  @override
  State<MediaListScreen> createState() => _MediaListScreenState();
}

enum _MediaFilterTab {
  projectVideos,
  videos,
  photos,
  view360,
}

class _MediaListScreenState extends State<MediaListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  final bool _showSearch = false;
  late final bool _showProjectVideos =
      ProjectsDashboardAccess.canSeeProjectVideos();
  late _MediaFilterTab _activeTab = _visibleTabs.first;
  final GlobalKey _projectVideosTabKey = GlobalKey();
  final GlobalKey _videosTabKey = GlobalKey();
  final GlobalKey _photosTabKey = GlobalKey();
  final GlobalKey _view360TabKey = GlobalKey();
  int _photoCount = 0;
  int _view360Count = 0;
  int _videoCount = 0;
  int _projectVideoCount = 0;
  ContentsResponse? _cachedContents;
  MediaLoaded? _cachedMedia;

  bool _isVideoTab(_MediaFilterTab tab) =>
      tab == _MediaFilterTab.videos || tab == _MediaFilterTab.projectVideos;

  List<_MediaFilterTab> get _visibleTabs => [
        if (_showProjectVideos) _MediaFilterTab.projectVideos,
        _MediaFilterTab.videos,
        _MediaFilterTab.photos,
        _MediaFilterTab.view360,
      ];

  int _tabToIndex(_MediaFilterTab tab) => _visibleTabs.indexOf(tab);

  _MediaFilterTab _indexToTab(int index) {
    final tabs = _visibleTabs;
    if (index < 0 || index >= tabs.length) return _MediaFilterTab.videos;
    return tabs[index];
  }

  Map<String, String>? get _imageHeaders {
    final token = SharedPref.getLoginData().result?.token;
    if (token == null || token.isEmpty) return null;
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'image/*,*/*',
    };
  }

  String _safeImageUrl(String rawUrl) {
    final input = rawUrl.trim();
    if (input.isEmpty) return input;
    return Uri.encodeFull(input);
  }

  void _logPhotoLoadError({
    required String source,
    required String rawUrl,
    required Object error,
  }) {}

  Widget _buildPhotoLoadingPlaceholder(
    BuildContext context,
    ImageChunkEvent? loadingProgress,
  ) {
    final progress = loadingProgress?.expectedTotalBytes != null
        ? loadingProgress!.cumulativeBytesLoaded /
            loadingProgress.expectedTotalBytes!
        : null;

    return Container(
      color: const Color(0xFFE9E9E9),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24.tw,
            height: 24.tw,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: const Color(0xFF6E6E6E),
              value: progress,
            ),
          ),
          SizedBox(height: 6.th),
          Text(
            'Loading...',
            style: GoogleFonts.poppins(
              fontSize: 10.tsp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6E6E6E),
            ),
          ),
        ],
      ),
    );
  }

  void _setActiveTab(_MediaFilterTab tab) {
    if (_activeTab == tab) return;
    HapticFeedback.selectionClick();
    setState(() => _activeTab = tab);

    // Already-loaded data renders instantly; fetch only what is missing.
    if (_isVideoTab(tab)) {
      if (_cachedMedia == null) {
        context.read<MediaBloc>().add(const FetchMediaList());
      }
    } else if (_cachedContents == null) {
      context.read<MediaBloc>().add(const FetchContents());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? ctx;
      switch (tab) {
        case _MediaFilterTab.projectVideos:
          ctx = _projectVideosTabKey.currentContext;
          break;
        case _MediaFilterTab.videos:
          ctx = _videosTabKey.currentContext;
          break;
        case _MediaFilterTab.photos:
          ctx = _photosTabKey.currentContext;
          break;
        case _MediaFilterTab.view360:
          ctx = _view360TabKey.currentContext;
          break;
      }
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    context.read<MediaBloc>().add(const FetchMediaList());
    _loadTabCounts();
    _searchController.addListener(() {
      final text = _searchController.text.trim();
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        context.read<MediaBloc>().add(SearchMedia(text));
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    MediaVideoPreloader.disposeAll();
    super.dispose();
  }

  List<MediaModel> _filteredVideos(
    MediaLoaded state, {
    required bool favoritesOnly,
  }) {
    final q = _searchController.text.trim().toLowerCase();
    return state.mediaList.where((m) {
      if (!m.isVideo) return false;
      if (favoritesOnly) {
        if (!m.isFavorite) return false;
      } else if (m.isFavorite) {
        return false;
      }
      if (q.isEmpty) return true;

      final name = m.name.toLowerCase();
      final typeLabel = m.isImage ? 'image' : 'video';
      final id = m.id.toLowerCase();
      final url = m.url.toLowerCase();
      final s3 = (m.xWebUrl ?? '').toLowerCase();
      final ext = m.fileExtension.toLowerCase();
      return name.contains(q) ||
          typeLabel.contains(q) ||
          id.contains(q) ||
          url.contains(q) ||
          s3.contains(q) ||
          ext.contains(q);
    }).toList();
  }

  void _openVideoPlayer(
    BuildContext context,
    MediaModel media, {
    List<MediaModel>? playlist,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => YoYoVideoPlayerScreen(
          media: media,
          playlist: playlist,
        ),
      ),
    );
  }

  Future<void> _loadTabCounts() async {
    try {
      final contents = await sl.get<IMediaRepository>().getContents();
      if (!mounted || contents == null) return;
      setState(() {
        _photoCount = contents.photos.length;
        _view360Count = contents.view360.length;
        _cachedContents = contents;
      });
    } catch (_) {}
  }

  Widget _buildLegacyVideosList(List<MediaModel> list) {
    if (list.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final media = list[index];
        return MediaItemWidget(
          media: media,
          onTap: () {
            if (media.isVideo) {
              _openVideoPlayer(context, media);
            } else {
              _showMediaDetails(context, media);
            }
          },
          onLongPress: () {
            _showDeleteConfirmation(context, media.id);
          },
        );
      },
      separatorBuilder: (BuildContext context, int index) =>
          SizedBox(height: 6.tw),
    );
  }

  List<ContentModel> _filteredPhotos(ContentsResponse contents) {
    final q = _searchController.text.trim().toLowerCase();
    var photos = List<ContentModel>.from(contents.photos);
    if (q.isNotEmpty) {
      photos = photos.where((item) {
        final name = item.fileName.toLowerCase();
        final project = item.projectName.toLowerCase();
        return name.contains(q) || project.contains(q);
      }).toList();
    }
    return photos;
  }

  List<ContentModel> _filtered360(ContentsResponse contents) {
    final q = _searchController.text.trim().toLowerCase();
    var list = List<ContentModel>.from(contents.view360);
    if (q.isNotEmpty) {
      list = list.where((c) {
        final name = c.fileName.toLowerCase();
        final project = c.projectName.toLowerCase();
        return name.contains(q) || project.contains(q);
      }).toList();
    }
    return list;
  }

  Widget _buildRedesignBody(BuildContext context, MediaState state) {
    switch (_activeTab) {
      case _MediaFilterTab.projectVideos:
      case _MediaFilterTab.videos:
        return _buildVideosRedesignBody(context, state);
      case _MediaFilterTab.photos:
      case _MediaFilterTab.view360:
        return _buildContentRedesignBody(context, state);
    }
  }

  Widget _buildContentRedesignBody(BuildContext context, MediaState state) {
    if (state is MediaLoading && _cachedContents == null) {
      return const Center(
        child: CircularProgressIndicator(color: MediaTheme.white),
      );
    }

    if (state is MediaError && _cachedContents == null) {
      return _buildDarkErrorState(state.message);
    }

    final contents = state is ContentsLoaded ? state.contents : _cachedContents;

    if (contents == null) {
      context.read<MediaBloc>().add(const FetchContents());
      return const Center(
        child: CircularProgressIndicator(color: MediaTheme.white),
      );
    }

    final is360 = _activeTab == _MediaFilterTab.view360;
    final items = is360 ? _filtered360(contents) : _filteredPhotos(contents);

    return MediaContentLandingScreen(
      items: items,
      is360Mode: is360,
      imageHeaders: _imageHeaders,
      onBack: () => Navigator.of(context).pop(),
      activeTabIndex: _tabToIndex(_activeTab),
      videoCount: _videoCount,
      photoCount: _photoCount,
      view360Count: _view360Count,
      showProjectVideos: _showProjectVideos,
      projectVideoCount: _projectVideoCount,
      onTabSelected: (index) {
        _setActiveTab(_indexToTab(index));
      },
      onOpenPhoto: (content) => _openPhotoOrPdf(context, content),
      onOpen360: (_) {},
    );
  }

  Widget _buildVideosRedesignBody(BuildContext context, MediaState state) {
    final media = state is MediaLoaded ? state : _cachedMedia;

    if (media == null && state is MediaError) {
      return _buildDarkErrorState(state.message);
    }

    if (media == null) {
      if (state is! MediaLoading) {
        context.read<MediaBloc>().add(const FetchMediaList());
      }
      return const Center(
        child: CircularProgressIndicator(color: MediaTheme.white),
      );
    }

    final favoritesOnly = _activeTab == _MediaFilterTab.projectVideos;
    final videos = _filteredVideos(media, favoritesOnly: favoritesOnly);
    return MediaVideosLandingScreen(
      mediaList: videos,
      onVideoTap: (media) => _openVideoPlayer(
        context,
        media,
        playlist: videos,
      ),
      onBack: () => Navigator.of(context).pop(),
      activeTabIndex: _tabToIndex(_activeTab),
      videoCount: _videoCount,
      photoCount: _photoCount,
      view360Count: _view360Count,
      showProjectVideos: _showProjectVideos,
      projectVideoCount: _projectVideoCount,
      onTabSelected: (index) {
        _setActiveTab(_indexToTab(index));
      },
    );
  }

  Widget _buildDarkErrorState(String message) {
    return Padding(
      padding: EdgeInsets.all(32.tw),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64.tsp, color: MediaTheme.textMuted),
            SizedBox(height: 16.th),
            Text(
              'Error loading videos',
              style: GoogleFonts.poppins(
                fontSize: 18.tsp,
                fontWeight: FontWeight.w600,
                color: MediaTheme.textSecondary,
              ),
            ),
            SizedBox(height: 8.th),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14.tsp,
                color: MediaTheme.textMuted,
              ),
            ),
            SizedBox(height: 20.th),
            ElevatedButton(
              onPressed: () {
                context.read<MediaBloc>().add(const FetchMediaList());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MediaTheme.white,
                foregroundColor: MediaTheme.black,
              ),
              child: Text('Retry', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useRedesign = kMediaVideosLandingRedesign;

    return BlocConsumer<MediaBloc, MediaState>(
      listener: (context, state) {
        if (state is MediaError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.message,
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        }
        if (state is MediaActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.message,
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        }
        if (state is MediaActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Media action completed successfully',
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        }
        if (state is MediaLoaded) {
          _cachedMedia = state;
          final videos = state.mediaList.where((m) => m.isVideo).toList();
          setState(() {
            _videoCount = videos.where((m) => !m.isFavorite).length;
            _projectVideoCount = videos.where((m) => m.isFavorite).length;
          });
          MediaVideoPreloader.preloadLandingVideos(videos);
        }
        if (state is ContentsLoaded) {
          _cachedContents = state.contents;
          setState(() {
            _photoCount = state.contents.photos.length;
            _view360Count = state.contents.view360.length;
          });
        }
      },
      builder: (context, state) {
        if (useRedesign) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: MediaTheme.lightStatusBar,
            child: Scaffold(
              backgroundColor: MediaTheme.black,
              body: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(_isVideoTab(_activeTab)),
                  child: _buildRedesignBody(context, state),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: const HeaderWidget(),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 6.th, bottom: 8.th),
                  child: _buildHeader(),
                ),
              ),
              if (state is MediaLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                SliverPadding(
                  padding:
                      EdgeInsets.only(left: 16.tw, right: 16.tw, bottom: 40.th),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (state is MediaLoaded &&
                            (_activeTab == _MediaFilterTab.videos ||
                                _activeTab == _MediaFilterTab.projectVideos))
                          _buildLegacyVideosList(
                            _filteredVideos(
                              state,
                              favoritesOnly:
                                  _activeTab == _MediaFilterTab.projectVideos,
                            ),
                          )
                        else if (state is ContentsLoaded)
                          _buildContentsList(state.contents)
                        else if (state is MediaError)
                          _buildErrorState(state.message),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/png/camera.png', width: 24.tw, height: 24.tw),
            const SizedBox(width: 8),
            if (!_showSearch)
              Text(
                translate('home.media'),
                style: GoogleFonts.poppins(
                  fontSize: 22.tsp,
                  fontWeight: FontWeight.w400,
                  color: appFontColor,
                  letterSpacing: 1.5,
                ),
                overflow: TextOverflow.visible,
              )
            else
              Expanded(child: _buildInlineSearchField()),
          ],
        ),
        SizedBox(height: 10.th),
        _buildFilterTabs(),
        SizedBox(height: 14.th),
      ],
    );
  }

  Widget _buildFilterTabs() {
    const unfocusedStart = Color(0xFFD6D6D6);
    const unfocusedEnd = Color(0xFFADB2BD);
    // Provided as #1B1F26B8 (RRGGBBAA) -> Flutter uses AARRGGBB.
    const focusedStart = Color(0xB81B1F26);
    const focusedEnd = Color(0xFF717171);

    final screenWidth = MediaQuery.sizeOf(context).width;
    // Make tabs slightly smaller so a portion of the next tab is visible.
    final contentWidth =
        screenWidth - 24.tw; // header has 12.tw horizontal padding
    final tabWidth = contentWidth * 0.40;
    final effectiveTabWidth = tabWidth < 120.tw ? 120.tw : tabWidth;

    Widget buildTab({
      required _MediaFilterTab tab,
      required Widget child,
      required Key tabKey,
    }) {
      final bool isActive = _activeTab == tab;

      return InkWell(
        borderRadius: BorderRadius.circular(22.tr),
        onTap: () {
          _setActiveTab(tab);
        },
        child: Container(
          key: tabKey,
          width: effectiveTabWidth,
          height: 44.th,
          padding: EdgeInsets.symmetric(horizontal: 18.tw),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.tr),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isActive
                  ? const [focusedStart, focusedEnd]
                  : const [unfocusedStart, unfocusedEnd],
            ),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      );
    }

    Text label(String text) {
      return Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 16.tsp,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
        maxLines: null,
        overflow: TextOverflow.visible,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          if (_showProjectVideos) ...[
            buildTab(
                tab: _MediaFilterTab.projectVideos,
                tabKey: _projectVideosTabKey,
                child: label('PROJECTS')),
            SizedBox(width: 10.tw),
          ],
          buildTab(
              tab: _MediaFilterTab.videos,
              tabKey: _videosTabKey,
              child: label('VIDEOS')),
          SizedBox(width: 10.tw),
          buildTab(
              tab: _MediaFilterTab.photos,
              tabKey: _photosTabKey,
              child: label('PHOTOS')),
          SizedBox(width: 10.tw),
          buildTab(
              tab: _MediaFilterTab.view360,
              tabKey: _view360TabKey,
              child: Image.asset(
                'assets/newapp/newicon/360 degrees.png',
                width: 50.tw,
                height: 50.tw,
                fit: BoxFit.contain,
              )),
        ],
      ),
    );
  }

  // The search field is kept for future use but may be hidden in some screens.
  // ignore: unused_element
  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/png/bg_atten.png'),
          fit: BoxFit.none,
        ),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(29.tr),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.2 * 255).toInt()),
            blurRadius: 4,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Find media',
          hintStyle: GoogleFonts.poppins(
            fontSize: 12.tsp,
            color: appFontColor,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.menu, size: 18, color: appFontColor),
          ),
          suffixIcon: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.search, size: 18, color: appFontColor),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildInlineSearchField() {
    return Container(
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/png/bg_atten.png'),
          fit: BoxFit.none,
        ),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(29.tr),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.2 * 255).toInt()),
            blurRadius: 4,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Find media',
          hintStyle: GoogleFonts.poppins(
            fontSize: 12.tsp,
            color: appFontColor,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.search, size: 18, color: appFontColor),
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFilterButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildFilterButton('All', () {
          context.read<MediaBloc>().add(const FetchMediaList());
        }),
        _buildFilterButton('Images', () {
          context
              .read<MediaBloc>()
              .add(const FetchMediaByType(MediaType.image));
        }),
        _buildFilterButton('Videos', () {
          context
              .read<MediaBloc>()
              .add(const FetchMediaByType(MediaType.video));
        }),
      ],
    );
  }

  Widget _buildFilterButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: appFontColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 20.tw, vertical: 12.th),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.tr),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14.tsp,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildContentsList(ContentsResponse contents) {
    final q = _searchController.text.trim().toLowerCase();

    if (_activeTab == _MediaFilterTab.photos) {
      var photos = List<ContentModel>.from(contents.photos);

      if (q.isNotEmpty) {
        photos = photos.where((item) {
          final name = item.fileName.toLowerCase();
          final project = item.projectName.toLowerCase();
          return name.contains(q) || project.contains(q);
        }).toList();
      }

      if (photos.isEmpty) {
        return _buildEmptyState();
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          return _buildSinglePhotoCard(photos[index]);
        },
        separatorBuilder: (BuildContext context, int index) =>
            SizedBox(height: 12.th),
      );
    }

    List<ContentModel> list;
    if (_activeTab == _MediaFilterTab.view360) {
      list = contents.view360;
    } else {
      list = [];
    }

    if (q.isNotEmpty) {
      list = list.where((c) {
        final name = c.fileName.toLowerCase();
        final project = c.projectName.toLowerCase();
        return name.contains(q) || project.contains(q);
      }).toList();
    }

    if (list.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final content = list[index];
        return ContentItemWidget(
          content: content,
          onTap: () => _handleContentTap(context, content),
        );
      },
      separatorBuilder: (BuildContext context, int index) =>
          SizedBox(height: 6.tw),
    );
  }

  Widget _buildSinglePhotoCard(ContentModel content) {
    final uploadedDate = content.dateCreated == null
        ? null
        : DateFormat('dd/MM/yyyy').format(content.dateCreated!);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(28.tr),
        border: Border.all(color: const Color(0xB8484848), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 12.th),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                uploadedDate == null
                    ? 'Uploaded at --/--/----'
                    : 'Uploaded at $uploadedDate',
                style: GoogleFonts.poppins(
                  fontSize: 10.tsp,
                  color: const Color(0xFF292929),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 6.th),
            ClipRRect(
              borderRadius: BorderRadius.circular(20.tr),
              child: AspectRatio(
                aspectRatio: 16 / 7,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openPhotoOrPdf(context, content),
                    child: _isPdfContent(content)
                        ? Container(
                            color: const Color(0xFFF5F5F5),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Colors.red.shade700,
                                  size: 48.tsp,
                                ),
                                SizedBox(height: 6.th),
                                Text(
                                  content.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.tsp,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Image.network(
                            _safeImageUrl(content.displayImageUrl),
                            headers: _imageHeaders,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return _buildPhotoLoadingPlaceholder(
                                context,
                                loadingProgress,
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              _logPhotoLoadError(
                                source: 'single-card',
                                rawUrl: content.displayImageUrl,
                                error: error,
                              );
                              return Container(
                                color: Colors.white.withOpacity(0.45),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.image_outlined,
                                  color: appFontColor.withOpacity(0.6),
                                  size: 28.tsp,
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.th),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.displayName,
                        maxLines: null,
                        overflow: TextOverflow.visible,
                        style: GoogleFonts.poppins(
                          fontSize: 18.tsp,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 2.th),
                      Text(
                        content.projectName,
                        maxLines: null,
                        overflow: TextOverflow.visible,
                        style: GoogleFonts.poppins(
                          fontSize: 13.tsp,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.tw),
                Padding(
                  padding: EdgeInsets.only(top: 2.th),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12.tr),
                        onTap: () => _openPhotoOrPdf(context, content),
                        child: Container(
                          height: 22.th,
                          padding: EdgeInsets.symmetric(horizontal: 14.tw),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6E6E6E),
                            borderRadius: BorderRadius.circular(12.tr),
                          ),
                          child: Text(
                            'View',
                            style: GoogleFonts.poppins(
                              fontSize: 12.tsp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 5.tw),
                      InkWell(
                        borderRadius: BorderRadius.circular(12.tr),
                        onTap: () => _sharePhotoItem(content),
                        child: Container(
                          width: 28.tw,
                          height: 24.th,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD5D5D5),
                            borderRadius: BorderRadius.circular(12.tr),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/newapp/newicon/media_share_icon.png',
                              width: 30.tw,
                              height: 30.th,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isPdfContent(ContentModel content) => content.isPdf;

  /// Opens the file's pages as photos; items without a file fall back to the
  /// thumbnail gallery.
  Future<void> _openPhotoOrPdf(
      BuildContext context, ContentModel content) async {
    if (MediaPdfPages.canRender(content)) {
      await MediaDocumentViewer.open(
        context,
        content: content,
        headers: _imageHeaders,
      );
      return;
    }

    if (!context.mounted) return;
    final gallery = _cachedContents != null
        ? _filteredPhotos(_cachedContents!)
        : <ContentModel>[content];
    final photos = gallery.isEmpty ? [content] : gallery;
    final index = photos.indexWhere((p) => p.id == content.id);
    _showPhotoPreview(
      context,
      photos,
      initialIndex: index >= 0 ? index : 0,
    );
  }

  Future<void> _sharePhotoItem(ContentModel content) async {
    final text = '${content.fileName}\n${content.previewUrl}'.trim();
    await SharePlus.instance.share(ShareParams(text: text));
  }

  void _handleContentTap(BuildContext context, ContentModel content) async {
    if (content.is360View) {
      // Open 360 view in browser or webview
      final url = Uri.parse(content.previewUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } else {
      // Show photo in full screen
      await _openPhotoOrPdf(context, content);
    }
  }

  void _showPhotoPreview(
    BuildContext context,
    List<ContentModel> photos, {
    int initialIndex = 0,
  }) {
    if (photos.isEmpty) return;

    MediaPhotoViewer.open(
      context,
      items: photos
          .map(
            (p) => MediaPhotoViewerItem(
              imageUrl: p.displayImageUrl,
              title: p.displayName,
              subtitle: p.projectName,
            ),
          )
          .toList(),
      initialIndex: initialIndex,
      imageHeaders: _imageHeaders,
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.all(50.tw),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.perm_media_outlined,
              size: 64.tsp,
              color: Colors.grey,
            ),
            SizedBox(height: 16.th),
            Text(
              'No media files yet',
              style: GoogleFonts.poppins(
                fontSize: 18.tsp,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 8.th),
            Text(
              'Your media collection will appear here',
              style: GoogleFonts.poppins(
                fontSize: 14.tsp,
                color: Colors.grey,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Padding(
      padding: EdgeInsets.all(50.tw),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.tsp,
              color: Colors.red,
            ),
            SizedBox(height: 16.th),
            Text(
              'Error loading media',
              style: GoogleFonts.poppins(
                fontSize: 18.tsp,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 8.th),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 14.tsp,
                color: Colors.grey,
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.th),
            ElevatedButton(
              onPressed: () {
                // Retry based on current tab
                if (_activeTab == _MediaFilterTab.videos ||
                    _activeTab == _MediaFilterTab.projectVideos) {
                  context.read<MediaBloc>().add(const FetchMediaList());
                } else {
                  context.read<MediaBloc>().add(const FetchContents());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: appFontColor,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaDetails(BuildContext context, MediaModel media) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          media.name,
          style: GoogleFonts.poppins(
            letterSpacing: 1.0,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: ${media.isImage ? 'Image' : 'Video'}',
              style: GoogleFonts.poppins(
                fontSize: 14.tsp,
                color: Colors.grey[600],
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: 8.th),
            Text(
              'Created: ${media.dateCreated.day}/${media.dateCreated.month}/${media.dateCreated.year}',
              style: GoogleFonts.poppins(
                fontSize: 14.tsp,
                color: Colors.grey[600],
                letterSpacing: 1.0,
              ),
            ),
            if (media.size != null) ...[
              SizedBox(height: 8.th),
              Text(
                'Size: ${media.size!.toStringAsFixed(1)} MB',
                style: GoogleFonts.poppins(
                  fontSize: 14.tsp,
                  color: Colors.grey[600],
                  letterSpacing: 1.0,
                ),
              ),
            ],
            if (media.isVideo && media.duration != null) ...[
              SizedBox(height: 8.th),
              Text(
                'Duration: ${media.duration} seconds',
                style: GoogleFonts.poppins(
                  fontSize: 14.tsp,
                  color: Colors.grey[600],
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String mediaId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete Media',
          style: GoogleFonts.poppins(
            letterSpacing: 1.0,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this media file?',
          style: GoogleFonts.poppins(
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                letterSpacing: 1.0,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<MediaBloc>().add(DeleteMedia(mediaId));
              Navigator.of(dialogContext).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
