import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'signature/signature_documents_tab.dart';
import 'signature/signature_home_tab.dart';
import '../theme/signature_theme.dart';

/// Entry point for Home -> My Actions -> Signature.
class SignaturesScreen extends StatefulWidget {
  const SignaturesScreen({super.key});

  @override
  State<SignaturesScreen> createState() => _SignaturesScreenState();
}

class _SignaturesScreenState extends State<SignaturesScreen> {
  int _tabIndex = 0;
  final GlobalKey<SignatureDocumentsTabState> _documentsKey =
      GlobalKey<SignatureDocumentsTabState>();

  void _onFabPressed() {
    if (_tabIndex != 1) {
      setState(() => _tabIndex = 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _documentsKey.currentState?.startUpload();
      });
    } else {
      _documentsKey.currentState?.startUpload();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Light icons when Home (brown header); dark when Documents.
    final overlay = _tabIndex == 0
        ? const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
            statusBarColor: Colors.transparent,
          )
        : SignatureTheme.lightStatusBar;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: SignatureTheme.background,
        body: IndexedStack(
          index: _tabIndex,
          children: [
            SignatureHomeTab(onFabPressed: _onFabPressed),
            SignatureDocumentsTab(key: _documentsKey),
          ],
        ),
        bottomNavigationBar: _SignatureBottomNav(
          currentIndex: _tabIndex,
          onChanged: (index) => setState(() => _tabIndex = index),
        ),
      ),
    );
  }
}

class _SignatureBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _SignatureBottomNav({
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SignatureTheme.surface,
        border: const Border(top: BorderSide(color: SignatureTheme.divider)),
        boxShadow: [
          BoxShadow(
            color: SignatureTheme.brownDeep.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62.th,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: currentIndex == 0,
                onTap: () => onChanged(0),
              ),
              _NavItem(
                icon: Icons.folder_copy_rounded,
                label: 'Documents',
                selected: currentIndex == 1,
                onTap: () => onChanged(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? SignatureTheme.brown : SignatureTheme.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24.tsp),
            SizedBox(height: 2.th),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.tsp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
