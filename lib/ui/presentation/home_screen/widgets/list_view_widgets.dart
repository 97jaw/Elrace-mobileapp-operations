import 'package:el_race/core/home/home_widget_visibility.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/hr_management/routing/hr_route_names.dart';
import 'package:el_race/ui/presentation/PettyCash/PettyCashScreen.dart';
import 'package:el_race/ui/presentation/home_screen/data/widget_model.dart';
import 'package:el_race/ui/presentation/home_screen/services/widget_service.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/card_tile.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/custom_bullet_point.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/hr_category_section_header.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/clients_vendors_category_section_header.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/clients_vendors_category_widgets.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/projects_category_section_header.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/finance_category_section_header.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/finance_category_widgets.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/purchase_category_section_header.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/purchase_category_widgets.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/productivity_category_section_header.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/productivity_category_widgets.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/library_category_section_header.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/coming_soon_category_section_header.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/coming_soon_category_widgets.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/library_category_widgets.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/projects_category_widgets.dart';
import 'package:el_race/ui/presentation/hr_management/hr_management_entry_screen.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/human_resource_category_widgets.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/tilting_card.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/purchase_management_hub_screen.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/parayer_widgets/parayer_widget.dart';
import 'package:el_race/ui/presentation/media/screens/media_list_screen.dart';
import 'package:el_race/ui/presentation/my_documents/screens/my_documents_screen.dart';
import 'package:el_race/ui/presentation/my_notes/screens/my_notes_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/my_project.dart';
import 'package:el_race/ui/presentation/tasks/logic/tasks_provider.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_productivity_navigation.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/utils/custom_navigate.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/utils/orientation_helper.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../bloc/home_bloc.dart';

/// Which home-widget categories to render on tablet split panes.
///
/// Section 2 / Section 3 assignment can be refined later; current split is a
/// temporary even split of category groups.
enum HomeTabletWidgetsPane {
  /// HR + Projects + Clients/Vendors
  section3,
  /// Purchase + Productivity + Finance + Library + Coming Soon
  section2,
  /// Full categorized list (phone / single-column)
  all,
}

class ListViewWidgets extends StatefulWidget {
  const ListViewWidgets({
    super.key,
    this.hideFeaturedHeader = false,
    this.tabletPane = HomeTabletWidgetsPane.all,
  });

  final bool hideFeaturedHeader;

  /// When not [HomeTabletWidgetsPane.all], only that tablet pane's categories.
  final HomeTabletWidgetsPane tabletPane;

  @override
  State<ListViewWidgets> createState() => _ListViewWidgetsState();
}

class _ListViewWidgetsState extends State<ListViewWidgets> {
  List<WidgetModel> activeWidgets = [];
  bool isLoading = true;
  DateTime now = DateTime.now();
  @override
  void initState() {
    super.initState();
    _loadActiveWidgets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadActiveWidgets();
  }

  Future<void> _loadActiveWidgets() async {
    final widgets = await WidgetService.getActiveWidgets();
    if (mounted) {
      setState(() {
        // Filter out my_notes widget
        activeWidgets = widgets
            .where((w) => w.id != 'my_notes' && w.id != 'prayer')
            .toList();
        isLoading = false;
      });
    }
  }

  void _reorderWidgets(int oldIndex, int newIndex) {
    // Provide strong haptic feedback for reordering
    HapticFeedback.mediumImpact();

    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final widget = activeWidgets.removeAt(oldIndex);
      activeWidgets.insert(newIndex, widget);
      // حفظ الترتيب الجديد
      WidgetService.saveActiveWidgets(activeWidgets);
    });
    // Stronger confirmation vibration if available
    _vibrateConfirm();
  }

  void _vibrateConfirm() async {
    try {
      // Use strong haptic impact as confirmation
      HapticFeedback.heavyImpact();
    } catch (_) {
      HapticFeedback.vibrate();
    }
  }

  Widget _buildCustomWidget(WidgetModel widget) {
    final bloc = HomeBloc.get(context);
    final isReorderMode = bloc.isReorderMode;

    switch (widget.id) {
      case 'petty_cash':
        return _buildPettyCashWidget(isReorderMode: isReorderMode);
      case 'lpo':
        return _buildLPOWidget(isReorderMode: isReorderMode);
      case 'documents':
        return _buildDocumentsWidget(isReorderMode: isReorderMode);
      case 'my_notes':
        return _buildMyNotesWidget(isReorderMode: isReorderMode);
      case 'todo_list':
        return _buildTodoListWidget(isReorderMode: isReorderMode);
      case 'projects':
        return _buildProjectsWidget(isReorderMode: isReorderMode);
      case 'my_request':
        return _buildMyRequestWidget(isReorderMode: isReorderMode);
      case 'site_management':
        return _buildSiteManagementWidget(isReorderMode: isReorderMode);
      case 'time_sheet':
        return _buildTimesheetWidget(isReorderMode: isReorderMode);
      case 'media':
        return _buildMediaWidget(isReorderMode: isReorderMode);
      case 'attendance':
        return _buildAttendanceWidget(isReorderMode: isReorderMode);
      case 'prayer':
        return const IgnorePointer(child: ParayerWidget());
      // QR widget removed from home screen - only available in sidebar
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPettyCashWidget({bool isReorderMode = false}) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23.r),
        child: Stack(
          children: [
            GrayCardComponent(
              onClick: isReorderMode
                  ? null
                  : () => Util.pushPage(const PettyCashScreen(), context),
              cardTitle: translate('home.petty_cash'),
              titleColor: Colors.white,
              backgroundImagePath:
                  'assets/newapp/petty_cach_widget_background.png',
              childWidget: const SizedBox.shrink(),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Transform.translate(
                    offset: Offset(-12.w, 30.h),
                    child: Opacity(
                      opacity: 0.28,
                      child: Image.asset(
                        'assets/newapp/d_for_petty_Cach.png',
                        height: 30.h,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLPOWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final lpoTotal =
        widgetData?.lpoWidget?.recordMap?['total']?.toString() ?? '0';
    final isDisabled = widgetData?.lpoWidget?.isDisabled == true;

    return GrayCardComponent(
      onClick: (isReorderMode || isDisabled)
          ? null
          : () => Util.pushPage(const PurchaseManagementHubScreen(), context),
      cardTitle: translate('home.lpo'),
      titleColor: Colors.white,
      backgroundImagePath: 'assets/newapp/Lpo_background_widget.png',
      topPadding: true,
      childWidget: SizedBox(),

      // childWidget: Padding(
      //   padding: EdgeInsets.only(
      //     left: 210.w,
      //   ),
      //   child: Image.asset(
      //     'assets/png/lpo.png',
      //     width: SizeConfig().getWidth(140),
      //     height: SizeConfig().getHeight(140),
      //   ),
      // ),
    );
  }

  Widget _buildDocumentsWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final docsCount =
        widgetData?.myDocumentsWidget?.recordCount?.toString() ?? '0';
    final isDisabled = widgetData?.myDocumentsWidget?.isDisabled == true;

    return Stack(
      children: [
        GrayCardComponent(
          onClick: (isReorderMode || isDisabled)
              ? null
              : () => Util.pushPage(const MyDocumentsScreen(), context),
          cardTitle: translate(''),
          titleColor: Colors.white,
          backgroundImagePath: 'assets/newapp/newicon/my Document (1).png',
          backgroundFit: BoxFit.fill,
          childWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 40.h),
                child: const SizedBox(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyNotesWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final notesData = widgetData?.myNotesWidget?.recordMap;
    final totalNotes =
        ((notesData?['saved_count'] ?? 0) + (notesData?['draft_count'] ?? 0))
            .toString();
    final isDisabled = widgetData?.myNotesWidget?.isDisabled == true;

    return Stack(
      children: [
        GrayCardComponent(
          cardTitle: translate('home.my_notes'),
          backgroundImagePath: 'assets/png/blue_card.png',
          onClick: (isReorderMode || isDisabled)
              ? null
              : () => Navigator.push(
                    context,
                    SlideRightPageRoute(child: const MyNotesScreen()),
                  ),
          childWidget: const SizedBox.shrink(),
        ),
        Positioned(
          right: 6.w,
          top: 30.h,
          child: Opacity(
            opacity: 0.20,
            child: Image.asset('assets/png/notes_icon.png'),
          ),
        ),
        Positioned(
          right: 10.w,
          top: 10.w,
          child: CountWidget(
            count: totalNotes,
            countColor: Colors.black,
            containerColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTodoListWidget({bool isReorderMode = false}) {
    return Consumer<TasksProvider>(
      builder: (context, tasksProvider, child) {
        if (tasksProvider.status == TasksStatus.initial) {
          Future.microtask(() => tasksProvider.loadTasks());
        }

        final isLoading = tasksProvider.status == TasksStatus.loading ||
            tasksProvider.status == TasksStatus.initial;
        final hasError = tasksProvider.status == TasksStatus.error;
        final todoCount = hasError
            ? '!'
            : isLoading
                ? '...'
                : tasksProvider.tasks.length.toString();

        return Stack(
          children: [
            GrayCardComponent(
              cardTitle: "Task Managment",
              titleColor: Colors.white,
              backgroundImagePath:
                  'assets/newapp/task_managment_widget_backdround.png',
              onClick: isReorderMode
                  ? null
                  : () {
                      if (hasError) {
                        // Show error message in a snackbar when tapped
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tasksProvider.errorMessage ??
                                'Failed to load tasks'),
                            action: SnackBarAction(
                              label: 'Retry',
                              onPressed: () => tasksProvider.loadTasks(),
                            ),
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      } else {
                        HomeProductivityNavigation.openTaskManagement(context);
                      }
                    },
              childWidget: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : hasError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.white.withOpacity(0.5),
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to retry',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
            ),
            /*
            Positioned(
              right: 10.w,
              top: 10.w,
              child: CountWidget(
                count: todoCount,
                countColor: Colors.black,
                containerColor: hasError ? Colors.red.shade100 : Colors.white,
              ),
            ),
            */
          ],
        );
      },
    );
  }

  Widget _buildProjectsWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final projectsData = widgetData?.myProjectsWidget?.recordMap;
    final totalProjects = projectsData?['total_projects']?.toString() ?? '0';
    final delayedProjects =
        projectsData?['delayed_projects']?.toString() ?? '0';
    final isDisabled = widgetData?.myProjectsWidget?.isDisabled == true;

    return ClipRRect(
      borderRadius: BorderRadius.circular(23.r),
      child: Stack(
        children: [
          GrayCardComponent(
            cardTitle: translate('home.projects'),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFD6D6D6),
                Color(0xFFADB2BD),
              ],
            ),
            onClick: (isReorderMode || isDisabled)
                ? null
                : () => Util.pushPage(const MyProject(), context),
            childWidget: Directionality(
              textDirection: TextDirection.ltr,
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: 72.h),
                  child: SizedBox(
                    width: 190.w,
                    child: Column(
                      children: [
                        CustomBulletPoint(
                          text: translate('home.In_progress'),
                          textColor: Colors.black,
                          countColor: Colors.white,
                          count: totalProjects,
                          containerColor: Colors.white,
                        ),
                        SizedBox(height: 4.h),
                        CustomBulletPoint(
                          text: translate('home.Delay'),
                          textColor: Colors.black,
                          countColor: Colors.black,
                          count: delayedProjects,
                          containerColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerRight,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Transform.translate(
                      offset: Offset(50.w, 40.h),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xB81B1F26), // #1B1F26 with 0.72 opacity
                            Color(0xFF717171),
                          ],
                        ).createShader(bounds),
                        child: Opacity(
                          opacity: 0.16,
                          child: Image.asset(
                            'assets/newapp/Ellipse 106.png',
                            height: 260.h,
                            fit: BoxFit.contain,
                            color: Colors.white,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(10.w, 5.h),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xB81B1F26), // #1B1F26 with 0.72 opacity
                            Color(0xFF717171),
                          ],
                        ).createShader(bounds),
                        child: Opacity(
                          opacity: 0.16,
                          child: Image.asset(
                            'assets/newapp/Ellipse 105.png',
                            height: 230.h,
                            fit: BoxFit.contain,
                            color: Colors.white,
                            colorBlendMode: BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRequestWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final requestData = widgetData?.myRequestWidget?.recordMap;
    final totalRequests =
        requestData?['total_requests_count']?.toString() ?? '0';
    final waitingApproval =
        requestData?['waiting_for_approval_count']?.toString() ?? '0';
    final isDisabled = widgetData?.myRequestWidget?.isDisabled == true;

    return ClipRRect(
      borderRadius: BorderRadius.circular(23.r),
      child: Stack(
        children: [
          GrayCardComponent(
            cardTitle: 'HR Management',
            backgroundImagePath: 'assets/newapp/blue_widget_background.png',
            backgroundFit: BoxFit.fill,
            onClick: (isReorderMode || isDisabled)
                ? null
                : () => Util.pushPage(const HrManagementEntryScreen(), context),
            childWidget: const SizedBox.shrink(),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerRight,
                child: Opacity(
                  opacity: 0.35,
                  child: Image.asset(
                    'assets/newapp/R.png',
                    height: 220.h,
                    fit: BoxFit.contain,
                    color: const Color.fromARGB(255, 138, 188, 226),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteManagementWidget({bool isReorderMode = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(23.r),
      child: Stack(
        children: [
          GrayCardComponent(
            cardTitle: 'Site Management',
            titleColor: Colors.white,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1F3A5F),
                Color(0xFF8B2635),
                Color(0xFF5D1522),
              ],
            ),
            onClick: isReorderMode
                ? null
                : () => Navigator.of(context).pushNamed(
                      TimesheetRouteNames.siteManagementHome,
                    ),
            childWidget: const SizedBox.shrink(),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 18.w),
                  child: Icon(
                    Icons.engineering_outlined,
                    size: 96.w,
                    color: const Color(0xFFFFFFFF).withValues(alpha: 0.38),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimesheetWidget({bool isReorderMode = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(23.r),
      child: Stack(
        children: [
          GrayCardComponent(
            cardTitle: 'Timesheet',
            titleColor: const Color(0xFF7A3E00),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFAF6EC),
                Color(0xFFF5F0E0),
                Color(0xFFE8E0CC),
                Color(0xFFDBD2B5),
              ],
            ),
            onClick: isReorderMode
                ? null
                : () => Navigator.of(context).pushNamed(
                      TimesheetRouteNames.home,
                    ),
            childWidget: const SizedBox.shrink(),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 18.w),
                  child: Icon(
                    Icons.schedule_rounded,
                    size: 96.w,
                    color: const Color(0xFFD4A82A).withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaWidget({bool isReorderMode = false}) {
    final loginData = SharedPref.getLoginData();
    final widgetData = loginData.result?.data?.defaultWidgets?.data;
    final mediaData = widgetData?.mediaWidget?.recordMap;
    final mediaCount = mediaData?['media_count']?.toString() ?? '0';
    // final filesCount = mediaData?['files']?.toString() ?? '0';
    final isDisabled = widgetData?.mediaWidget?.isDisabled == true;

    return Stack(
      children: [
        GrayCardComponent(
          // Keep base component untouched; hide its title for this card only.
          cardTitle: '',
          backgroundImagePath: 'assets/newapp/media_widget_background.png',
          onClick: (isReorderMode || isDisabled)
              ? null
              : () => Util.pushPage(const MediaListScreen(), context),
          childWidget: Directionality(
            textDirection: TextDirection.ltr,
            child: DefaultTextStyle(
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              child: Padding(
                padding: EdgeInsets.only(top: 80.h),
                child: SizedBox(
                  width: SizeConfig().getWidth(190),
                  height: SizeConfig().getHeight(80),
                  child: const Column(
                    children: [
                      /*
                      CustomBulletPoint(
                        text: translate('home.videos'),
                        textColor: Colors.black,
                        countColor: Colors.black,
                        count: mediaCount,
                        containerColor: Colors.white,
                      ),
                      */
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 36.w,
          top: 16,
          child: Text(
            translate('home.media').toUpperCase(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.9,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceWidget({bool isReorderMode = false}) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (cxt, state) {
        var bloc = HomeBloc.get(cxt);
        final monthAbbrev = bloc.monthName.length >= 3
            ? bloc.monthName.substring(0, 3).toUpperCase()
            : bloc.monthName.toUpperCase();
        final widgetData =
            SharedPref.getLoginData().result?.data?.defaultWidgets?.data;
        final isDisabled = widgetData?.attendanceWidget?.isDisabled == true;

        return ClipRRect(
          borderRadius: BorderRadius.circular(23.r),
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              GrayCardComponent(
                cardTitle: translate('home.attendance'),
                backgroundImagePath: 'assets/newapp/blue_widget_background.png',
                onClick: (isReorderMode || isDisabled)
                    ? null
                    : () => Navigator.of(context)
                        .pushNamed(HrRouteNames.attendanceReports),
                childWidget: const SizedBox.shrink(),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: SvgPicture.asset(
                    'assets/svg/attendance-effect.svg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Opacity(
                      opacity: 1,
                      child: Image(
                        image: AssetImage(
                          'assets/newapp/finger-print_svgrepo.com.png',
                        ),
                        fit: BoxFit.contain,
                        color: Color(0xFFFFFFFF),
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8.w,
                top: 6.h,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 92.w,
                      height: 31.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: const Color(0xFFe1edf5).withOpacity(0.42),
                          width: 0.9,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.62),
                            const Color(0xFFe1edf5).withOpacity(0.34),
                            const Color(0xFFe1edf5).withOpacity(0.18),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                          BoxShadow(
                            color: const Color(0xFFe1edf5).withOpacity(0.40),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 7.w,
                            right: 7.w,
                            top: 2.h,
                            child: Container(
                              height: 7.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.r),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.52),
                                    const Color(0xFFe1edf5).withOpacity(0.1),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 11.w),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_month_outlined,
                                    size: 13.sp,
                                    color: const Color(0xFF2B2F6B),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    monthAbbrev,
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF2B2F6B),
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.15,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Phone keeps side-by-side rows; tablet columns scale phone-designed cards
  /// into the narrow pane without ScreenUtil overflow.
  bool get _isTabletPane =>
      widget.tabletPane != HomeTabletWidgetsPane.all;

  static const double _halfDesignWidth = 175;
  static const double _fullDesignWidth = 360;

  Widget _scaleToHeight(
    Widget card,
    double height, {
    double? designHeight,
    double? designWidth,
  }) {
    if (!_isTabletPane) {
      return SizedBox(height: height, width: double.infinity, child: card);
    }
    final isHalf = (designWidth ?? _halfDesignWidth) <= 200;
    final srcDesignW =
        designWidth ?? (isHalf ? _halfDesignWidth : _fullDesignWidth);
    final srcDesignH = designHeight ?? 140;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        // Source box scaled uniformly by scaleWidth (both axes) so the card
        // keeps the exact phone aspect ratio and internal proportions —
        // `.w`/`.sp` content lays out exactly as on a phone, then the whole
        // card scales down to the pane width.
        final srcW = srcDesignW * ScreenUtil().scaleWidth;
        final srcH = srcDesignH * ScreenUtil().scaleWidth;
        final visualH = maxW * (srcDesignH / srcDesignW);

        return SizedBox(
          width: maxW,
          height: visualH,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: srcW,
              height: srcH,
              child: card,
            ),
          ),
        );
      },
    );
  }

  Widget _pairCards(
    List<Widget> cards, {
    double designHeight = 140,
  }) {
    if (cards.isEmpty) return const SizedBox.shrink();
    if (cards.length == 1) {
      return _scaleToHeight(
        cards.first,
        designHeight.h,
        designWidth: _halfDesignWidth,
        designHeight: designHeight,
      );
    }
    // Phone + tablet: side-by-side half cards (Attendance|HRMS, Notes|Tickets, …)
    if (_isTabletPane) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            Expanded(
              child: _scaleToHeight(
                cards[i],
                designHeight.h,
                designWidth: _halfDesignWidth,
                designHeight: designHeight,
              ),
            ),
            if (i != cards.length - 1) const SizedBox(width: 10),
          ],
        ],
      );
    }
    return SizedBox(
      height: designHeight.h,
      child: Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i != cards.length - 1) SizedBox(width: 10.w),
          ],
        ],
      ),
    );
  }

  Widget _fullWidthCard(
    Widget card, {
    double? height,
    double? designHeight,
  }) {
    return _scaleToHeight(
      card,
      height ?? 140.h,
      designHeight: designHeight ?? 140,
      designWidth: _fullDesignWidth,
    );
  }

  Widget _buildCategorizedWidgets() {
    final visibility = HomeWidgetVisibility.fromLoginPref();
    final pane = widget.tabletPane;
    final showSection3 = pane == HomeTabletWidgetsPane.all ||
        pane == HomeTabletWidgetsPane.section3;
    final showSection2 = pane == HomeTabletWidgetsPane.all ||
        pane == HomeTabletWidgetsPane.section2;
    final tabletCompact = _isTabletPane;

    final children = <Widget>[];

    if (showSection3 && visibility.hasVisibleHr) {
      if (!widget.hideFeaturedHeader) {
        children.add(
          Padding(
            padding: EdgeInsets.only(bottom: _isTabletPane ? 10 : 10.h),
            child: const HrCategorySectionHeader(),
          ),
        );
      }
      if (visibility.isVisible(HomeWidgetCode.attendance) ||
          visibility.isVisible(HomeWidgetCode.hrms)) {
        final cards = <Widget>[
          if (visibility.isVisible(HomeWidgetCode.attendance))
            HrCategoryAttendanceCard(
              tabletCompact: tabletCompact,
            ),
          if (visibility.isVisible(HomeWidgetCode.hrms))
            HrCategoryHrmsCard(tabletCompact: tabletCompact),
        ];
        children.add(_pairCards(cards));
        children.add(SizedBox(height: _isTabletPane ? 10 : 10.h));
      }
      if (visibility.isVisible(HomeWidgetCode.timesheet)) {
        children.add(
          _fullWidthCard(
            HrCategoryTimesheetCard(tabletCompact: tabletCompact),
          ),
        );
      }
      children.add(SizedBox(height: _isTabletPane ? 14 : 14.h));
    }

    if (showSection3 && visibility.hasVisibleProjects) {
      children.addAll([
        const ProjectsCategorySectionHeader(),
        SizedBox(height: _isTabletPane ? 10 : 10.h),
      ]);
      if (visibility.isVisible(HomeWidgetCode.myProjects)) {
        children.addAll([
          _fullWidthCard(
            ProjectsCategoryMyProjectsCard(tabletCompact: tabletCompact),
          ),
          SizedBox(height: _isTabletPane ? 10 : 10.h),
        ]);
      }
      if (visibility.isVisible(HomeWidgetCode.siteManagement) ||
          visibility.isVisible(HomeWidgetCode.myReports)) {
        final cards = <Widget>[
          if (visibility.isVisible(HomeWidgetCode.siteManagement))
            ProjectsCategorySiteManagementCard(tabletCompact: tabletCompact),
          if (visibility.isVisible(HomeWidgetCode.myReports))
            ProjectsCategoryMyReportsCard(tabletCompact: tabletCompact),
        ];
        children.add(_pairCards(cards));
      }
      children.add(SizedBox(height: _isTabletPane ? 14 : 14.h));
    }

    if (showSection3 && visibility.hasVisibleClientsVendors) {
      children.add(const ClientsVendorsCategorySectionHeader());
      children.add(SizedBox(height: _isTabletPane ? 10 : 10.h));
      if (visibility.isVisible(HomeWidgetCode.clients)) {
        children.add(
          _fullWidthCard(
            ClientsVendorsCategoryClientsCard(tabletCompact: tabletCompact),
            designHeight: 182,
          ),
        );
        children.add(SizedBox(height: _isTabletPane ? 14 : 14.h));
      }
      if (visibility.isVisible(HomeWidgetCode.vendors)) {
        children.add(
          _fullWidthCard(
            ClientsVendorsCategoryVendorsCard(tabletCompact: tabletCompact),
            designHeight: 182,
          ),
        );
        children.add(SizedBox(height: _isTabletPane ? 14 : 14.h));
      }
      children.add(SizedBox(height: _isTabletPane ? 6 : 6.h));
    }

    if (showSection2 && visibility.hasVisiblePurchase) {
      children.addAll([
        const PurchaseCategorySectionHeader(),
        SizedBox(height: _isTabletPane ? 10 : 10.h),
        _fullWidthCard(
          PurchaseCategoryLpoCard(tabletCompact: tabletCompact),
        ),
        SizedBox(height: _isTabletPane ? 14 : 14.h),
      ]);
    }

    if (showSection2 && visibility.hasVisibleProductivity) {
      children.addAll([
        const ProductivityCategorySectionHeader(),
        SizedBox(height: _isTabletPane ? 10 : 10.h),
      ]);
      if (visibility.isVisible(HomeWidgetCode.taskManagement)) {
        children.add(
          _fullWidthCard(
            ProductivityCategoryTaskManagementCard(
              tabletCompact: tabletCompact,
            ),
          ),
        );
        children.add(SizedBox(height: _isTabletPane ? 10 : 10.h));
      }
      if (visibility.isVisible(HomeWidgetCode.sharedDocuments) ||
          visibility.isVisible(HomeWidgetCode.notes)) {
        final cards = <Widget>[
          if (visibility.isVisible(HomeWidgetCode.sharedDocuments))
            ProductivityCategorySharedDocumentsCard(
              tabletCompact: tabletCompact,
            ),
          if (visibility.isVisible(HomeWidgetCode.notes))
            ProductivityCategoryNotesCard(tabletCompact: tabletCompact),
        ];
        children.add(_pairCards(cards));
      }
      children.add(SizedBox(height: _isTabletPane ? 14 : 14.h));
    }

    if (showSection2 && visibility.hasVisibleFinance) {
      children.addAll([
        const FinanceCategorySectionHeader(),
        SizedBox(height: _isTabletPane ? 10 : 10.h),
        _fullWidthCard(
          FinanceCategoryPettyCashCard(tabletCompact: tabletCompact),
        ),
        SizedBox(height: _isTabletPane ? 14 : 14.h),
      ]);
    }

    if (showSection2) {
      final showDocs = visibility.isVisible(HomeWidgetCode.myDocuments);
      final showMedia = visibility.isVisible(HomeWidgetCode.media);
      if (showDocs || showMedia) {
        children.addAll([
          const LibraryCategorySectionHeader(),
          SizedBox(height: _isTabletPane ? 10 : 10.h),
        ]);
        if (showDocs) {
          children.addAll([
            _fullWidthCard(
              LibraryCategoryMyDocumentsCard(tabletCompact: tabletCompact),
            ),
            SizedBox(height: _isTabletPane ? 10 : 10.h),
          ]);
        }
        if (showMedia) {
          children.addAll([
            _fullWidthCard(
              LibraryCategoryMediaCard(tabletCompact: tabletCompact),
            ),
            SizedBox(height: _isTabletPane ? 10 : 10.h),
          ]);
        }
      }
      // Prayer Times is always-on (not role-gated in the wizard).
      children.add(
        _fullWidthCard(
          LibraryCategoryPrayerTimesCard(tabletCompact: tabletCompact),
          height: _isTabletPane ? 236 : 220.h,
          designHeight: 220,
        ),
      );
      children.add(SizedBox(height: _isTabletPane ? 14 : 14.h));

      children.addAll([
        const ComingSoonCategorySectionHeader(),
        SizedBox(height: _isTabletPane ? 10 : 10.h),
        _fullWidthCard(
          ComingSoonCategoryElraceAiCard(tabletCompact: tabletCompact),
          height: _isTabletPane ? 178 : 170.h,
          designHeight: 170,
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = HomeBloc.get(context);

    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (previous, current) => current is ReorderModeChanged,
      builder: (context, state) {
        return Opacity(
          opacity: !SharedPref.isUserAuthenticated() ? .5 : 1,
          child: IgnorePointer(
            ignoring: !SharedPref.isUserAuthenticated(),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // Show active widgets from edit widgets
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (bloc.isReorderMode)
                  // عرض ReorderableListView عند تفعيل وضع إعادة الترتيب
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: activeWidgets.length,
                    onReorder: _reorderWidgets,
                    proxyDecorator: (child, index, animation) {
                      // Custom decorator to remove white frame and improve visual feedback
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final double elevation = Tween<double>(
                            begin: 0.0,
                            end: 8.0,
                          ).evaluate(animation);
                          final double scale = Tween<double>(
                            begin: 1.0,
                            end: 1.05,
                          ).evaluate(animation);

                          return Transform.scale(
                            scale: scale,
                            child: Material(
                              elevation: elevation + 6,
                              color: Colors.transparent,
                              shadowColor: Colors.black.withOpacity(0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      final widget = activeWidgets[index];
                      return TiltingCard(
                        key: ValueKey(widget.id),
                        child: Column(
                          children: [
                            _buildCustomWidget(widget),
                            const SizedBox(height: 10),
                          ],
                        ),
                      );
                    },
                  )
                else
                  _buildCategorizedWidgets(),

                // إضافة مساحة إضافية في الأسفل عندما يكون في وضع التعديل
                if (bloc.isReorderMode) SizedBox(height: 100.h),
              ],
            ),
          ),
        );
      },
    );
  }
}
