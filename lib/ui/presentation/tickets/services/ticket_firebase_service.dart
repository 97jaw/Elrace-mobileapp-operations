import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/tickets/data/ticket_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TicketFirebaseService {
  TicketFirebaseService._();
  static final TicketFirebaseService instance = TicketFirebaseService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _currentUid {
    final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
    if (firebaseUid != null) return firebaseUid;
    return SharedPref.getLoginData().result?.data?.firebase_uid;
  }

  Future<void> _ensureSignedIn() async {
    if (FirebaseAuth.instance.currentUser != null) return;
    final customToken =
        SharedPref.getLoginData().result?.data?.firebase_custom_token;
    if (customToken != null &&
        customToken.isNotEmpty &&
        customToken != 'false') {
      try {
        await FirebaseAuth.instance.signInWithCustomToken(customToken);
      } catch (_) {}
    }
  }

  CollectionReference<Map<String, dynamic>> _tickets(String uid) =>
      _firestore.collection('users').doc(uid).collection('tickets');

  List<TicketModel> _sortNewest(Iterable<TicketModel> items) {
    final list = items.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<List<TicketModel>> getAllTickets() async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) return [];
    final snap = await _tickets(uid).get();
    return _sortNewest(snap.docs.map(TicketModel.fromFirestore));
  }

  Stream<List<TicketModel>> streamTickets() async* {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) {
      yield const [];
      return;
    }
    yield* _tickets(uid).snapshots().map(
          (snap) => _sortNewest(snap.docs.map(TicketModel.fromFirestore)),
        );
  }

  Future<List<TicketModel>> getTicketsForTask(String parentTaskId) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) return [];
    final snap = await _tickets(uid)
        .where('parent_task_id', isEqualTo: parentTaskId)
        .get();
    return _sortNewest(snap.docs.map(TicketModel.fromFirestore));
  }

  Future<TicketModel?> getTicket(String ticketId) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) return null;
    final doc = await _tickets(uid).doc(ticketId).get();
    if (!doc.exists) return null;
    return TicketModel.fromFirestore(doc);
  }

  Future<TicketModel> createTicket({
    required String title,
    String? description,
    TicketPriority priority = TicketPriority.medium,
    TicketStatus status = TicketStatus.open,
    String? assigneeId,
    String? assigneeName,
    String? parentTaskId,
    String? parentTaskTitle,
    List<String> reportIds = const [],
  }) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) {
      throw StateError('Not signed in');
    }
    final now = DateTime.now();
    final ticket = TicketModel(
      ownerUid: uid,
      title: title.trim(),
      description: description?.trim(),
      priority: priority,
      status: status,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
      parentTaskId: parentTaskId,
      parentTaskTitle: parentTaskTitle,
      reportIds: reportIds,
      createdAt: now,
      updatedAt: now,
    );
    final ref = await _tickets(uid).add(ticket.toFirestore(ownerUid: uid));
    return ticket.copyWith(firebaseId: ref.id);
  }

  Future<void> updateTicket(TicketModel ticket) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    final id = ticket.firebaseId;
    if (uid == null || id == null) return;
    final updated = ticket.copyWith(updatedAt: DateTime.now());
    await _tickets(uid).doc(id).set(
          updated.toFirestore(ownerUid: uid),
          SetOptions(merge: true),
        );
  }

  Future<void> deleteTicket(String ticketId) async {
    await _ensureSignedIn();
    final uid = _currentUid;
    if (uid == null) return;
    await _tickets(uid).doc(ticketId).delete();
  }

  Future<void> linkReport(String ticketId, String reportId) async {
    final ticket = await getTicket(ticketId);
    if (ticket == null) return;
    if (ticket.reportIds.contains(reportId)) return;
    await updateTicket(
      ticket.copyWith(reportIds: [...ticket.reportIds, reportId]),
    );
  }

  Future<void> unlinkReport(String ticketId, String reportId) async {
    final ticket = await getTicket(ticketId);
    if (ticket == null) return;
    await updateTicket(
      ticket.copyWith(
        reportIds: ticket.reportIds.where((id) => id != reportId).toList(),
      ),
    );
  }
}
