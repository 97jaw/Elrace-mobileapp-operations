import 'package:el_race/core/constants/app_images.dart';
import 'package:el_race/ui/chat/chat_ui.dart';
import 'package:el_race/ui/navigation/glass_route_navigation.dart';
import 'package:el_race/ui/presentation/camera/camera_selection_screen.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Left header control: 3-dot glass pill expanding to chat / call / camera.
class HomeExpandableNavMenu extends StatefulWidget {
  const HomeExpandableNavMenu({super.key});

  @override
  State<HomeExpandableNavMenu> createState() => _HomeExpandableNavMenuState();
}

class _HomeExpandableNavMenuState extends State<HomeExpandableNavMenu> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  void _collapse() {
    if (_expanded) setState(() => _expanded = false);
  }

  Future<void> _openChat() async {
    _collapse();
    if (!mounted) return;
    await openGlassSubScreen(
      context,
      routeName: '/chat_list',
      shell: GlassSubScreenShell.chat,
      child: const ChatHomeScreen(),
    );
  }

  void _openCall() {
    _collapse();
    final bloc = HomeBloc.get(context);
    bloc.add(const ChangeCurrentIndex(index: 0));
  }

  Future<void> _openCamera() async {
    _collapse();
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => const CameraSelectionScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: _expanded ? 8 : 0,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.none,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(
          minWidth: 44.w,
          maxWidth: _expanded ? 210.w : 44.w,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: 0.58),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.88),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
          ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _expanded ? 8.w : 2.w,
            vertical: 6.h,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DotToggle(expanded: _expanded, onTap: _toggle),
              if (_expanded) ...[
                SizedBox(width: 4.w),
                _NavIconButton(
                  asset: AppImages.chatIconNew,
                  onTap: _openChat,
                ),
                _NavIconButton(
                  asset: AppImages.callIcon,
                  onTap: _openCall,
                ),
                _NavIconButton(
                  asset: AppImages.chatIcon,
                  onTap: _openCamera,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DotToggle extends StatelessWidget {
  const _DotToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 36.w,
        height: 36.w,
        child: Icon(
          expanded ? Icons.close_rounded : Icons.more_horiz_rounded,
          size: 22.sp,
          color: HomeGlassTheme.maroon,
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({required this.asset, required this.onTap});

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
        child: Image.asset(
          asset,
          width: 22.w,
          height: 22.w,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
