import 'dart:async';
import 'dart:ui' as ui;

import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/core/constants/app_images.dart';
import 'package:el_race/ui/navigation/glass_route_navigation.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:el_race/ui/presentation/call_screen/call_screen.dart';
import 'package:el_race/ui/presentation/camera/camera_selection_screen.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/ui/presentation/qr_survey/screens/qr_survey_content_wrapper.dart';
import 'package:el_race/ui/chat/chat_ui.dart';
import 'package:el_race/chat/chat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_translate/flutter_translate.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const List<Widget> screens = [
    CallScreen(),
    HomeScreenPage(),
    SizedBox(),
    QrSurveyContentWrapper(), // QR Survey screen (no icon in bottom nav)
  ];

  // Phase 0 instrumentation: proves/disproves the full-rebuild-per-tab-switch
  // theory with a real count before Phase 1 changes this to an IndexedStack.
  // No behavior change — logging only.
  int _tabBuildCount = 0;

  Future<bool> _onWillPop() async {
    // Show confirmation dialog
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          translate('common.exit_app_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(translate('common.exit_app_message')),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              translate('common.cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              translate('common.exit'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = HomeBloc.get(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // If not on home tab, go back to home tab instead of exiting
        if (bloc.currentIndex != HomeNavigation.homeTabIndex) {
          HomeNavigation.handleSystemBack(context);
          return;
        }

        final shouldPop = await _onWillPop();
        if (shouldPop) {
          // Close the app properly instead of navigating to a black screen
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBody: true,
        bottomNavigationBar: const SizedBox.shrink(),
        body: BlocBuilder<HomeBloc, HomeState>(
          // ChangeIndexLoading() is emitted immediately before every
          // ChangeIndexSuccess() (see HomeBloc.changeCurrentIndex /
          // changeBottomNavVisiblity) with no visual meaning of its own —
          // grepped all usages, nothing else listens for it. Skipping it
          // halves the rebuilds per tab tap.
          buildWhen: (prev, curr) =>
              curr is ChangeIndexSuccess || curr is HomeInitial,
          builder: (context, state) {
            final index = HomeBloc.get(context).currentIndex;
            _tabBuildCount++;
            debugPrint(
                '🔁 [main_screens] IndexedStack index=$index evaluated (build #$_tabBuildCount, state=$state)');
            // IndexedStack keeps every tab's widget subtree mounted for the
            // life of MainScreen instead of disposing/recreating it on every
            // tab switch (previously: screens[index], which unmounts the
            // outgoing screen and reruns initState + API calls on the
            // incoming one every single tap).
            //
            // Regression found in testing: a raw IndexedStack builds every
            // child up front, including tabs the user has never opened.
            // CallScreen (index 0) was never built at all under the old
            // screens[index] code unless the user tapped the Call tab — its
            // NestedScrollView + SliverFillRemaining(hasScrollBody: false)
            // empty-state has a pre-existing Flutter layout bug ("RenderViewport
            // does not support returning intrinsic dimensions") that was
            // dormant until something actually built that widget. Eagerly
            // building it on every login surfaced that bug immediately.
            // _LazyIndexedStack restores "don't build until first shown"
            // while keeping "don't rebuild once built" — the fallback this
            // plan's own Phase 1 notes anticipated needing.
            return _LazyIndexedStack(
              index: index,
              children: screens,
            );
          },
        ),
      ),
    );
  }
}

/// Builds each child the first time its index is selected, then keeps it
/// mounted (via IndexedStack) so later switches don't rebuild it. Unlike a
/// raw IndexedStack, tabs that have never been visited are not built at all.
class _LazyIndexedStack extends StatefulWidget {
  const _LazyIndexedStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  final Set<int> _built = {};

  @override
  Widget build(BuildContext context) {
    _built.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _built.contains(i) ? widget.children[i] : const SizedBox.shrink(),
      ],
    );
  }
}

class CustomBottomNavBar extends StatefulWidget {
  final bool isMain;
  const CustomBottomNavBar({super.key, this.isMain = true});

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  StreamSubscription<int>? _unreadSub;
  StreamSubscription? _authSub;
  Timer? _retryTimer;
  int _totalUnread = 0;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  /// Try to subscribe to unread count. If chat module isn't ready yet,
  /// set up retries via auth state changes + periodic timer + chatEnabledNotifier.
  void _startListening() {
    if (_trySubscribe()) return; // Success on first try

    // Listen to ChatModuleHelper — fires the moment chat becomes enabled
    ChatModuleHelper.instance.chatEnabledNotifier.addListener(_onChatEnabled);

    // Auth listener: retry when user signs in
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && _unreadSub == null) {
        if (_trySubscribe()) {
          _cancelRetries();
        }
      }
    });

    // Periodic retry every 2s as fallback
    _retryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_trySubscribe()) {
        _cancelRetries();
      }
      if (timer.tick >= 60) {
        // print('⚠️ BottomNav: Gave up retrying after 2 min');
        _cancelRetries();
      }
    });
  }

  void _onChatEnabled() {
    if (ChatModuleHelper.instance.isChatEnabled && _unreadSub == null) {
      // print('🔔 BottomNav: chatEnabledNotifier fired — trying subscribe');
      if (_trySubscribe()) {
        _cancelRetries();
      }
    }
  }

  /// Attempt to subscribe. Returns true if successful.
  /// Only requires Firebase Auth uid — ChatRepository uses it directly.
  bool _trySubscribe() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return false;
    }

    _unreadSub?.cancel();
    _unreadSub = ChatRepository.instance.subscribeToTotalUnreadCount().listen(
      (count) {
        // print('🔔 BottomNav: Received unread count = $count');
        if (mounted && count != _totalUnread) {
          setState(() => _totalUnread = count);
        }
      },
      onError: (e) {
        // print('⚠️ BottomNav: Unread count error: $e');
      },
    );
    // print('✅ BottomNav: Subscribed to unread count (uid=$uid)');
    return true;
  }

  void _cancelRetries() {
    _authSub?.cancel();
    _authSub = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    ChatModuleHelper.instance.chatEnabledNotifier
        .removeListener(_onChatEnabled);
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    _cancelRetries();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMain = widget.isMain;
    return BlocBuilder<HomeBloc, HomeState>(builder: (ctx, state) {
      var bloc = HomeBloc.get(ctx);
      if (bloc.enableBottomNav == false) return const SizedBox.shrink();
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(
              left: 16.0, right: 16.0, bottom: 20.0, top: 10.0),
          child: AdaptiveGlassLayer(
            borderRadius: BorderRadius.circular(70.r),
            sigma: 10,
            fallbackColor: Colors.white.withValues(alpha: 0.85),
            child: Container(
              height: 60.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(70.r),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2), width: 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Chat button
                    _buildNavItem(
                      context,
                      index: 3,
                      isMain: isMain,
                      icon: AppImages.chatIconNew,
                      badgeCount: _totalUnread,
                    ),
                    _buildNavItem(
                      context,
                      index: 0,
                      isMain: isMain,
                      icon: AppImages.callIcon,
                    ),
                    _buildNavItem(
                      context,
                      index: 2,
                      isMain: isMain,
                      icon: AppImages.chatIcon,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    });
  }

  Widget _buildNavItem(BuildContext context,
      {required int index,
      dynamic icon,
      required bool isMain,
      bool isIconData = false,
      int badgeCount = 0}) {
    final bloc = HomeBloc.get(context);
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () async {
        if (isMain) {
          if (index == 2) {
            // Open camera
            await _openCamera(context);
            return;
          }
          if (index == 3) {
            // Open chat list. Do NOT zero the badge here — opening the list
            // does not mark chats read; unread stream will update after
            // individual chats call markChatRead.
            await openGlassSubScreen(
              context,
              routeName: '/chat_list',
              shell: GlassSubScreenShell.chat,
              child: const ChatShellScreen(),
            );
            return;
          }
          bloc.add(ChangeCurrentIndex(index: index));
        } else {
          if (index == 2) {
            // Keep secondary-screen behavior consistent with main nav.
            await _openCamera(context);
            return;
          }

          if (index == 3) {
            // Open chat list. Keep badge driven by unread stream only.
            await openGlassSubScreen(
              context,
              routeName: '/chat_list',
              shell: GlassSubScreenShell.chat,
              child: const ChatShellScreen(),
            );
            return;
          }

          bloc.add(ChangeCurrentIndex(index: index));
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const MainScreen(),
            ),
            (route) => false,
          );
        }
      },
      icon: SizedBox(
        height: 60.h,
        child: Center(
          child: badgeCount > 0
              ? Badge(
                  label: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFFF04D57),
                  child: isIconData
                      ? Icon(icon as IconData,
                          size: 30,
                          color: bloc.currentIndex == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.6))
                      : Image.asset(
                          icon as String,
                          width: 30.w,
                        ),
                )
              : isIconData
                  ? Icon(icon as IconData,
                      size: 30,
                      color: bloc.currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.6))
                  : Image.asset(
                      icon as String,
                      width: 30.w,
                    ),
        ),
      ),
    );
  }

  Future<void> _openCamera(BuildContext context) async {
    // Open the Camera Selection Screen in fullscreen
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CameraSelectionScreen(),
          fullscreenDialog: true,
        ),
      );
    }
  }
}
