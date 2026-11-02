import 'package:el_race/core/notifications/notification_payload.dart';
import 'package:el_race/core/notifications/notification_record_loaders.dart';
import 'package:el_race/core/timesheet/providers/labor_transfer_providers.dart';
import 'package:el_race/core/timesheet/services/labor_transfer_roster_refresh.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/invoice_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/pettycash_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/rfq_details_screen.dart';
import 'package:el_race/ui/presentation/hr_management/hr_circular_announcements_screen.dart';
import 'package:el_race/ui/presentation/hr_management/hr_request_detail_screen.dart';
import 'package:el_race/ui/presentation/tasks/tasks_screen.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/task_details.dart'
    as firebase_task_details;
import 'package:el_race/ui/presentation/tickets/screens/ticket_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationRouteRegistry {
  static Widget? pageFor(NotificationPayload payload) {
    if (payload.action == 'open_screen') {
      return _screen(payload);
    }
    if (payload.action != 'open_record') return null;
    switch (payload.model) {
      case 'employee.requests':
        if (payload.resId.isEmpty) return null;
        return HrRequestDetailScreen(
          requestId: payload.resId,
          managerContext: payload.params['manager'] == true,
        );
      case 'purchase.order':
        if (payload.resId.isEmpty) return null;
        return RfqDetailsScreen(
          requestId: payload.resId,
          type: (payload.params['type'] ?? 'RFQ').toString(),
        );
      case 'hr.expense.sheet':
        if (payload.resId.isEmpty) return null;
        return PettyCashDetailsScreen(
          requestId: payload.resId,
          type: (payload.params['type'] ?? 'PETTY CASH').toString(),
        );
      case 'account.move':
        if (payload.resId.isEmpty) return null;
        return InvoiceDetailsScreen(
          requestId: payload.resId,
          type: (payload.params['type'] ?? 'INVOICE').toString(),
        );
      case 'firestore.todo':
        if (payload.resId.isEmpty) return null;
        return firebase_task_details.TaskDetailsScreen(taskId: payload.resId);
      case 'firestore.ticket':
        if (payload.resId.isEmpty) return null;
        return TicketDetailsScreen(ticketId: payload.resId);
      case 'hr.employee.document':
        if (payload.resId.isEmpty) return null;
        return DocumentByIdLoader(documentId: payload.resId);
      case 'firestore.note':
        if (payload.resId.isEmpty) return null;
        return NoteByIdLoader(
          noteId: payload.resId,
          ownerId: payload.params['owner_id']?.toString(),
        );
      case 'firestore.signature':
        if (payload.resId.isEmpty) return null;
        return SignatureByIdLoader(
          documentId: payload.resId,
          pdfUrl: payload.params['pdf_url']?.toString(),
          title: payload.params['title']?.toString(),
        );
      case 'project.project':
        if (payload.resId.isEmpty) return null;
        return ProjectByIdLoader(projectId: payload.resId);
      case 'it.hardware.request':
        // No IT request screen exists yet, so the tap stays on the
        // Notification Center.
        return null;
      case 'hr.employee':
        if (payload.resId.isEmpty) return null;
        return EmployeeByIdLoader(employeeId: payload.resId);
      default:
        return null;
    }
  }

  static Widget? _screen(NotificationPayload payload) {
    switch (payload.screen) {
      case 'circulars':
        final isAnnouncement = payload.category == 'announcement' ||
            payload.params['tab']?.toString() == 'announcement';
        final recordId = int.tryParse(payload.resId);
        return HrCircularAnnouncementsScreen(
          initialTabIndex: isAnnouncement ? 1 : 0,
          autoOpenItemId: recordId,
          autoOpenCategory: isAnnouncement ? 'announcement' : 'circular',
        );
      case 'tasks':
        return const TasksScreen();
      default:
        return null;
    }
  }

  static void beforeLaborOpen(BuildContext context, NotificationPayload payload) {
    if (payload.model != 'elrace.labor.transfer') return;
    final transferId = int.tryParse(payload.resId);
    if (transferId == null || transferId <= 0) return;
    final state = (payload.raw['state'] ?? '').toString().trim().toLowerCase();
    try {
      final container = ProviderScope.containerOf(context);
      container.invalidate(laborTransferCountsProvider);
      if (state == 'approved' || state == 'rejected') {
        // ignore: discarded_futures
        LaborTransferRosterRefresh.afterTeamChange(container);
      }
    } catch (_) {}
  }
}
