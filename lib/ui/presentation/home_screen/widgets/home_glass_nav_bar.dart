import 'package:el_race/core/constants/app_images.dart';
import 'package:el_race/ui/chat/chat_ui.dart';
import 'package:el_race/ui/navigation/glass_route_navigation.dart';
import 'package:el_race/ui/presentation/camera/camera_selection_screen.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Left header glass pill: chat · call · camera.
class HomeGlassNavBar extends StatelessWidget {
  const HomeGlassNavBar({super.key});

  Future<void> _openChat(BuildContext context) async {
    await openGlassSubScreen(
      context,
      routeName: '/chat_list',
      shell: GlassSubScreenShell.chat,
      child: const ChatHomeScreen(),
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
    return HomeGlassTheme.glassSurface(
      borderRadius: BorderRadius.circular(999),
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 5.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlassNavIcon(
            asset: AppImages.chatIconNew,
            onTap: () => _openChat(context),
          ),
          _divider(),
          _GlassNavIcon(
            asset: AppImages.callIcon,
            onTap: () => _openCall(context),
          ),
          _divider(),
          _GlassNavIcon(
            asset: AppImages.chatIcon,
            onTap: () => _openCamera(context),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 22.h,
      margin: EdgeInsets.symmetric(horizontal: 2.w),
      color: Colors.white.withValues(alpha: 0.55),
    );
  }
}

class _GlassNavIcon extends StatelessWidget {
  const _GlassNavIcon({required this.asset, required this.onTap});

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          child: Image.asset(
            asset,
            width: 22.w,
            height: 22.w,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
