import 'package:el_race/chat/chat.dart';
import 'package:el_race/core/constants/app_images.dart';
import 'package:el_race/ui/chat/chat_ui.dart';
import 'package:el_race/ui/navigation/glass_route_navigation.dart';
import 'package:el_race/ui/presentation/camera/camera_selection_screen.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Centered chat / call / camera strip — appears near the bottom when expanded.
class HomeFloatingCommsBar extends StatelessWidget {
  const HomeFloatingCommsBar({
    super.key,
    required this.expandProgress,
  });

  final double expandProgress;

  static const _showThreshold = 0.72;

  Future<void> _openChat(BuildContext context) async {
    await openGlassSubScreen(
      context,
      routeName: '/chat_list',
      shell: GlassSubScreenShell.chat,
      child: const ChatShellScreen(),
    );
  }

  void _openCall(BuildContext context) {
    HomeBloc.get(context).add(const ChangeCurrentIndex(index: 0));
  }

  Future<void> _openCamera(BuildContext context) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => const CameraSelectionScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ((expandProgress - _showThreshold) / (1 - _showThreshold))
        .clamp(0.0, 1.0);
    if (t <= 0) return const SizedBox.shrink();

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset + 10.h,
      child: IgnorePointer(
        ignoring: t < 0.15,
        child: Opacity(
          opacity: Curves.easeOutCubic.transform(t),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14.h),
            child: Center(
              child: IntrinsicWidth(
                child: HomeGlassTheme.glassSurface(
                  borderRadius: BorderRadius.circular(999),
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: ChatUnreadBadgeService.instance.count,
                        builder: (context, unread, _) {
                          return _CommsIcon(
                            asset: AppImages.chatIconNew,
                            onTap: () => _openChat(context),
                            badgeCount: unread,
                          );
                        },
                      ),
                      _divider(),
                      _CommsIcon(
                        asset: AppImages.callIcon,
                        onTap: () => _openCall(context),
                      ),
                      _divider(),
                      _CommsIcon(
                        asset: AppImages.chatIcon,
                        onTap: () => _openCamera(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28.h,
      margin: EdgeInsets.symmetric(horizontal: 5.w),
      color: Colors.white.withValues(alpha: 0.55),
    );
  }
}

class _CommsIcon extends StatelessWidget {
  const _CommsIcon({
    required this.asset,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String asset;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Image.asset(
                asset,
                width: 28.w,
                height: 28.w,
                fit: BoxFit.contain,
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -6.w,
                  top: -4.h,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: badgeCount > 9 ? 4.w : 0,
                      vertical: 1.h,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16.w,
                      minHeight: 16.w,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF04D57),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
