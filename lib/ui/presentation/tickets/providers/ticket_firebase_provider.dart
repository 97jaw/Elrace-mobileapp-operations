import 'dart:async';

import 'package:el_race/ui/presentation/tickets/data/ticket_model.dart';
import 'package:el_race/ui/presentation/tickets/services/ticket_firebase_service.dart';
import 'package:flutter/foundation.dart';

class TicketFirebaseProvider extends ChangeNotifier {
  final TicketFirebaseService _service = TicketFirebaseService.instance;

  List<TicketModel> _tickets = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<TicketModel>>? _sub;

  List<TicketModel> get tickets => _tickets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get openCount =>
      _tickets.where((t) => t.status == TicketStatus.open).length;
  int get inProgressCount =>
      _tickets.where((t) => t.status == TicketStatus.inProgress).length;
  int get closedCount =>
      _tickets.where((t) => t.status.isTerminal).length;

  Future<void> loadTickets() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _tickets = await _service.getAllTickets();
      _listen();
    } catch (e) {
      _errorMessage = 'Failed to load tickets: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  void _listen() {
    _sub?.cancel();
    _sub = _service.streamTickets().listen(
      (items) {
        _tickets = items;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = 'Live ticket updates failed';
        notifyListeners();
      },
    );
  }

  List<TicketModel> ticketsForTask(String parentTaskId) {
    return _tickets
        .where((t) => t.parentTaskId == parentTaskId)
        .toList();
  }

  Future<TicketModel?> createTicket({
    required String title,
    String? description,
    TicketPriority priority = TicketPriority.medium,
    String? assigneeId,
    String? assigneeName,
    String? parentTaskId,
    String? parentTaskTitle,
    List<String> reportIds = const [],
  }) async {
    try {
      final created = await _service.createTicket(
        title: title,
        description: description,
        priority: priority,
        assigneeId: assigneeId,
        assigneeName: assigneeName,
        parentTaskId: parentTaskId,
        parentTaskTitle: parentTaskTitle,
        reportIds: reportIds,
      );
      await loadTickets();
      return created;
    } catch (e) {
      _errorMessage = 'Failed to create ticket: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateTicket(TicketModel ticket) async {
    try {
      await _service.updateTicket(ticket);
      await loadTickets();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update ticket: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTicket(String ticketId) async {
    try {
      await _service.deleteTicket(ticketId);
      await loadTickets();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete ticket: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> linkReport(String ticketId, String reportId) async {
    try {
      await _service.linkReport(ticketId, reportId);
      await loadTickets();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to link report: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> unlinkReport(String ticketId, String reportId) async {
    try {
      await _service.unlinkReport(ticketId, reportId);
      await loadTickets();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to unlink report: $e';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
