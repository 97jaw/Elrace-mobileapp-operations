import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:el_race/chat/models/chat.dart';
import 'package:el_race/chat/repositories/chat_repository.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Resolves project staff to Firebase chat UIDs for DM / group setup.
class TimesheetChatResolve {
  TimesheetChatResolve._();

  static final _users = FirebaseFirestore.instance.collection('users');

  static Future<String?> firebaseUidForEmployee(
    int employeeId, {
    int? odooUserId,
  }) async {
    if (employeeId <= 0 && (odooUserId == null || odooUserId! <= 0)) {
      return null;
    }
    try {
      if (odooUserId != null && odooUserId > 0) {
        final byOdoo = await _users
            .where('odoo_user_id', isEqualTo: odooUserId)
            .limit(1)
            .get();
        if (byOdoo.docs.isNotEmpty) return byOdoo.docs.first.id;
      }

      final byInt = await _users
          .where('employee_id', isEqualTo: employeeId)
          .limit(1)
          .get();
      if (byInt.docs.isNotEmpty) return byInt.docs.first.id;

      final byStr = await _users
          .where('employee_id', isEqualTo: employeeId.toString())
          .limit(1)
          .get();
      if (byStr.docs.isNotEmpty) return byStr.docs.first.id;
    } catch (e) {
      // Permission or index — caller may still open chat by name search elsewhere.
      assert(() {
        // ignore: avoid_print
        print('TimesheetChatResolve: employee_id lookup failed: $e');
        return true;
      }());
    }
    return null;
  }

  static Future<String?> dmChatIdForMember(TimesheetTeamMember member) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return null;

    final peerUid = await firebaseUidForEmployee(
      member.employeeId,
      odooUserId: member.odooUserId,
    );
    if (peerUid == null || peerUid.isEmpty) return null;

    return Chat.generateDmChatId(currentUid, peerUid);
  }

  static Future<String> ensureDmForMember(TimesheetTeamMember member) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) throw Exception('Not signed in');

    final peerUid = await firebaseUidForEmployee(
      member.employeeId,
      odooUserId: member.odooUserId,
    );
    if (peerUid == null || peerUid.isEmpty) {
      throw Exception(
        '${member.name} is not registered in chat yet',
      );
    }

    return ChatRepository.instance.createOrGetDmChat(
      otherUid: peerUid,
      otherName: member.name,
      currentUserName: FirebaseAuth.instance.currentUser?.displayName ?? 'Me',
    );
  }

  static Future<List<String>> firebaseUidsForStaff(
    List<TimesheetTeamMember> staff,
  ) async {
    final uids = <String>{};
    final self = FirebaseAuth.instance.currentUser?.uid;
    if (self != null) uids.add(self);

    for (final member in staff) {
      final uid = await firebaseUidForEmployee(
        member.employeeId,
        odooUserId: member.odooUserId,
      );
      if (uid != null && uid.isNotEmpty) uids.add(uid);
    }
    return uids.toList();
  }
}
