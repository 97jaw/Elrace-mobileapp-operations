import 'package:el_race/core/app_globals.dart';
import 'package:el_race/providers/profile_box_provider.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_widgets/profile_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Listens to [ProfileBoxProvider] and opens the profile bottom sheet
/// instead of the legacy side drawer.
class ProfileSheetHost extends StatefulWidget {
  const ProfileSheetHost({super.key});

  @override
  State<ProfileSheetHost> createState() => _ProfileSheetHostState();
}

class _ProfileSheetHostState extends State<ProfileSheetHost> {
  ProfileBoxProvider? _provider;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider = context.read<ProfileBoxProvider>();
      _provider!.addListener(_onProviderChanged);
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    if (!mounted || _provider == null || _sheetOpen) return;
    if (!_provider!.isProfileVisible) return;

    _provider!.hideProfileBox();

    final sheetContext = navKey.currentContext;
    if (sheetContext == null) return;

    _sheetOpen = true;
    ProfileBottomSheet.show(sheetContext).whenComplete(() {
      if (mounted) _sheetOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Backward-compatible alias for existing imports.
typedef ProfileBoxWithSlideAnimation = ProfileSheetHost;
