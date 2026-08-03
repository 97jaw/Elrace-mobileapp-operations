import 'dart:async';

import 'package:flutter/material.dart';
import 'package:el_race/data/models/global_search_item.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/pettycash_details_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/hr_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/invoice_my_actions_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/my_requests_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/petty_cash_my_action_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/rfq_screen.dart';
import 'package:el_race/ui/presentation/my_actions/screens/signatures_screen.dart';
import 'package:el_race/ui/presentation/my_documents/screens/attachment_viewer_screen.dart';
import 'package:el_race/ui/presentation/my_documents/screens/my_documents_screen.dart';
import 'package:el_race/ui/presentation/my_documents/utils/document_attachment_opener.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';
import 'package:el_race/ui/presentation/my_notes/screens/my_notes_screen.dart';
import 'package:el_race/ui/presentation/tasks/task_details_screen.dart';
import 'package:el_race/ui/presentation/tasks/data/task_model.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_my_actions_navigation.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/utils/custom_navigate.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_list_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_repository_impl.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_partner_usecase.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/purchase_management_hub_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Helper class for navigating to detail screens from search results.
class GlobalSearchNavigationHelper {
  /// Navigate to the appropriate detail screen based on category.
  static void navigateToDetail(BuildContext context, GlobalSearchItem item) {
    switch (item.category) {
      case 'tasks':
        _navigateToTaskDetails(context, item);
      case 'petty_cash':
        _navigateToPettyCashDetails(context, item);
      case 'projects':
        _navigateToProjectDetails(context, item);
      case 'lpo':
        _navigateToLpoDetails(context, item);
      case 'notes':
        _navigateToNoteDetails(context, item);
      case 'documents':
        _navigateToDocumentDetails(context, item);
      case 'my_actions':
        navigateToMyAction(context, item);
      default:
        _showNotImplemented(context, item);
    }
  }

  /// My Actions cards: route by [request_type] when possible.
  static void navigateToMyAction(BuildContext context, GlobalSearchItem item) {
    final data = item.additionalData ?? const <String, dynamic>{};
    final requestType = (data['request_type'] ?? '').toString().toLowerCase();
    final id = item.id.toString();

    if (requestType.contains('petty') ||
        requestType.contains('ptsh') ||
        requestType.contains('expense')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PettyCashDetailsScreen(
            requestId: id,
            type: 'PETTY CASH',
            initialData: data,
          ),
        ),
      );
      return;
    }

    if (requestType.contains('hr')) {
      Navigator.push(
        context,
        SlideRightPageRoute(
          child: const HrScreen(),
          settings: const RouteSettings(name: '/hr'),
        ),
      );
      return;
    }

    if (requestType.contains('rfq')) {
      Navigator.push(
        context,
        SlideRightPageRoute(
          child: const RfqScreen(),
          settings: const RouteSettings(name: '/rfq'),
        ),
      );
      return;
    }

    if (requestType.contains('invoice')) {
      Navigator.push(
        context,
        SlideRightPageRoute(
          child: const InvoiceMyActionsScreen(),
          settings: const RouteSettings(name: '/invoice_my_actions'),
        ),
      );
      return;
    }

    if (requestType.contains('signature') || requestType.contains('sign')) {
      Navigator.push(
        context,
        SlideRightPageRoute(
          child: const SignaturesScreen(),
          settings: const RouteSettings(name: '/signatures'),
        ),
      );
      return;
    }

    if (requestType.contains('timesheet') || requestType.contains('time sheet')) {
      HomeMyActionsNavigation.open(context, HomeMyAction.timesheets);
      return;
    }

    if (requestType.contains('report')) {
      Navigator.pushNamed(context, TimesheetRouteNames.home);
      return;
    }

    Navigator.push(
      context,
      SlideRightPageRoute(
        child: const MyRequestsScreen(),
        settings: const RouteSettings(name: '/my_requests'),
      ),
    );
  }

  static void _navigateToTaskDetails(
    BuildContext context,
    GlobalSearchItem item,
  ) {
    try {
      final task = TaskModel(
        id: item.id,
        name: item.title,
        description: item.additionalData?['description'],
        projectId: item.additionalData?['project_id']?.toString(),
        priority: item.additionalData?['priority']?.toString(),
        stage: item.additionalData?['stage_id']?.toString() ??
            item.additionalData?['stage'],
        assignedUser: item.additionalData?['assigned_user'],
        team: item.additionalData?['team'],
        createdAt: _parseDate(item.additionalData?['create_date']),
        reportIds: item.additionalData?['x_report_ids'] ?? const [],
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaskDetailsScreen(task: task),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to task details: $e');
      _showError(context, 'Unable to open task details');
    }
  }

  static void _navigateToPettyCashDetails(
    BuildContext context,
    GlobalSearchItem item,
  ) {
    final id = item.id.toString();
    if (id.isNotEmpty && id != '0') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PettyCashDetailsScreen(
            requestId: id,
            type: 'PETTY CASH',
            initialData: item.additionalData,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      SlideRightPageRoute(
        child: const PettyCashMyActionScreen(),
        settings: const RouteSettings(name: '/petty_cash_my_actions'),
      ),
    );
  }

  static void _navigateToProjectDetails(
    BuildContext context,
    GlobalSearchItem item,
  ) {
    try {
      final data = item.additionalData ?? const <String, dynamic>{};

      int? asInt(dynamic value) {
        if (value is int) return value;
        if (value is String) return int.tryParse(value);
        return null;
      }

      final int partnerId = asInt(data['partner_id']) ?? item.id;
      final String partnerName =
          (data['partner_name'] ?? item.title).toString();
      final String partnerPhoto =
          (data['photo_url'] ?? data['partner_photo'] ?? '').toString();

      final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
      final bloc = ProjectListBloc(
        getProjectsUseCase: GetProjectsUseCase(repository: repo),
        getProjectAttachmentsUseCase:
            GetProjectAttachmentsUseCase(repository: repo),
        getProjectsByPartnerUseCase:
            GetProjectsByPartnerUseCase(repository: repo),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: bloc,
            child: ProjectListScreen(
              bloc: bloc,
              partnerId: partnerId,
              partnerName: partnerName,
              partnerPhoto: partnerPhoto,
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error navigating to project details: $e');
      _showError(context, 'Unable to open project details');
    }
  }

  static void _navigateToLpoDetails(
    BuildContext context,
    GlobalSearchItem item,
  ) {
    final id = item.id;
    if (id != 0) {
      // Open PDF directly for a known PO id; hub accessible from home card.
      Util.openLpoPdfReport(context, id);
      return;
    }
    // Fall back to the Purchase Management hub if no specific PO id.
    Navigator.push(
      context,
      SlideRightPageRoute(
        child: const PurchaseManagementHubScreen(),
        settings: const RouteSettings(name: '/purchase_management'),
      ),
    );
  }

  static void _navigateToNoteDetails(
    BuildContext context,
    GlobalSearchItem item,
  ) {
    Navigator.push(
      context,
      SlideRightPageRoute(
        child: const MyNotesScreen(),
        settings: const RouteSettings(name: '/my_notes'),
      ),
    );
  }

  static void _navigateToDocumentDetails(
    BuildContext context,
    GlobalSearchItem item,
  ) {
    final data = item.additionalData ?? const <String, dynamic>{};
    final url = (data['url'] ??
            data['public_url'] ??
            data['download_url'] ??
            data['file_url'] ??
            '')
        .toString();

    final attachmentId = DocumentAttachmentOpener.firstAttachmentId(
          Map<String, dynamic>.from(data),
        ) ??
        extractPublicAttachmentId(url);

    if (attachmentId != null) {
      unawaited(
        DocumentAttachmentOpener.openById(
          context,
          attachmentId: attachmentId,
          hintName: item.title,
        ),
      );
      return;
    }

    if (url.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttachmentViewerScreen(
            publicUrl: normalizeProjectFileUrl(url),
            title: item.title,
            attachmentType: data['mimetype']?.toString(),
            attachmentId: extractPublicAttachmentId(url),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      SlideRightPageRoute(
        child: const MyDocumentsScreen(),
        settings: const RouteSettings(name: '/my_documents'),
      ),
    );
  }

  static void _showNotImplemented(BuildContext context, GlobalSearchItem item) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Navigation to ${item.displayCategory} details coming soon!',
        ),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  static DateTime? _parseDate(dynamic dateStr) {
    if (dateStr == null) return null;
    try {
      return DateTime.parse(dateStr.toString());
    } catch (e) {
      return null;
    }
  }
}
