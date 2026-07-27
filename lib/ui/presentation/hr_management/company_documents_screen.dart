import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:el_race/ui/presentation/my_documents/screens/company_documents_tab.dart';
import 'package:el_race/ui/presentation/my_documents/utils/document_attachment_opener.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_access.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// HRMS Company Documents — browse operating-unit folders and open files.
/// Gated to HR manager, management, and project manager.
class CompanyDocumentsScreen extends StatefulWidget {
  const CompanyDocumentsScreen({super.key});

  @override
  State<CompanyDocumentsScreen> createState() => _CompanyDocumentsScreenState();
}

class _CompanyDocumentsScreenState extends State<CompanyDocumentsScreen> {
  static const _rootTitle = 'Company Documents';

  String _chromeTitle = _rootTitle;
  VoidCallback? _exitFolder;

  @override
  void initState() {
    super.initState();
    if (!ProjectsDashboardAccess.canAccessCompanyDocuments()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        HomeNavigation.handleSystemBack(context);
      });
    }
  }

  void _handleBack() {
    final exit = _exitFolder;
    if (exit != null) {
      exit();
      return;
    }
    HomeNavigation.handleSystemBack(context);
  }

  void _onDrillChanged(String title, VoidCallback? exitFolder) {
    // Tab may notify while TabletContentFrame is still building the body.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_chromeTitle == title && identical(_exitFolder, exitFolder)) return;
      setState(() {
        _chromeTitle = title;
        _exitFolder = exitFolder;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ProjectsDashboardAccess.canAccessCompanyDocuments()) {
      return const HrModuleGlassShell(
        title: _rootTitle,
        accentTint: HrModuleHeaderTints.companyDocuments,
        body: SizedBox.shrink(),
      );
    }

    return PopScope(
      canPop: _exitFolder == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _exitFolder?.call();
      },
      child: HrModuleGlassShell(
        title: _chromeTitle,
        accentTint: HrModuleHeaderTints.companyDocuments,
        onBack: _handleBack,
        body: Padding(
          padding: EdgeInsets.fromLTRB(
            12.w,
            4.h,
            12.w,
            context.systemBottomInset + 8.h,
          ),
          child: CompanyDocumentsTab(
            rootTitle: _rootTitle,
            onDrillChanged: _onDrillChanged,
            onOpenDocument: (document) =>
                DocumentAttachmentOpener.open(context, document),
          ),
        ),
      ),
    );
  }
}
