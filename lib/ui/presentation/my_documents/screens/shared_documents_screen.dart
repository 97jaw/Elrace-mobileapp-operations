import 'package:el_race/ui/presentation/my_documents/screens/share_documents_tab.dart';
import 'package:el_race/ui/presentation/my_documents/theme/shared_documents_theme.dart';
import 'package:el_race/ui/presentation/my_documents/utils/document_attachment_opener.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_glass_header.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Dedicated Shared Documents surface (Productivity home widget entry).
class SharedDocumentsScreen extends StatefulWidget {
  const SharedDocumentsScreen({super.key});

  @override
  State<SharedDocumentsScreen> createState() => _SharedDocumentsScreenState();
}

class _SharedDocumentsScreenState extends State<SharedDocumentsScreen> {
  static const _rootTitle = 'Shared Documents';

  String _chromeTitle = _rootTitle;
  VoidCallback? _exitFolder;
  Widget? _titleTrailing;

  void _handleBack() {
    final exit = _exitFolder;
    if (exit != null) {
      exit();
      return;
    }
    HomeNavigation.handleSystemBack(context);
  }

  void _onDrillChanged(String title, VoidCallback? exitFolder) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_chromeTitle == title && identical(_exitFolder, exitFolder)) return;
      setState(() {
        _chromeTitle = title;
        _exitFolder = exitFolder;
      });
    });
  }

  void _onChromeTrailingChanged(Widget? trailing) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _titleTrailing = trailing);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _exitFolder == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _exitFolder?.call();
      },
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: SharedDocumentsTheme.hubBackgroundGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProductivityGlassHeader(
                title: _chromeTitle,
                showBack: true,
                onBack: _handleBack,
                titleTrailing: _titleTrailing,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16.w,
                    8.h,
                    16.w,
                    context.systemBottomInset + 8.h,
                  ),
                  child: ShareDocumentsTab(
                    rootTitle: _rootTitle,
                    onDrillChanged: _onDrillChanged,
                    onChromeTrailingChanged: _onChromeTrailingChanged,
                    onOpenDocument: (document) =>
                        DocumentAttachmentOpener.open(context, document),
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
