import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../firebase/firebase_session.dart';
import '../models/timesheet_approval.dart';

/// Owns the top-level `timesheet_approvals` collection and its Storage PDFs.
class TimesheetApprovalRepository {
  static TimesheetApprovalRepository? _instance;
  static TimesheetApprovalRepository get instance =>
      _instance ??= TimesheetApprovalRepository._();

  TimesheetApprovalRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('timesheet_approvals');

  String storagePath(String ownerUid, String docId) =>
      'timesheet_approvals/$ownerUid/$docId/original.pdf';

  Future<T> _withAuth<T>(Future<T> Function() action) =>
      FirebaseSession.instance.run(action);

  /// Creates the approval: doc id → PDF upload → Firestore create.
  Future<TimesheetApproval> create({
    required File pdfFile,
    required String ownerName,
    required String fileName,
    required String projectId,
    required String projectName,
    required int pageCount,
    required List<({String uid, String name})> recipients,
    required List<TimesheetApprovalCell> cells,
  }) {
    if (recipients.isEmpty || recipients.length > 2) {
      throw ArgumentError('Select 1 or 2 approvers');
    }

    return _withAuth(() async {
      final ownerUid = FirebaseAuth.instance.currentUser?.uid;
      if (ownerUid == null || ownerUid.isEmpty) {
        throw Exception('Firebase auth required');
      }

      final docId = _uuid.v4();
      final path = storagePath(ownerUid, docId);
      final bytes = await pdfFile.readAsBytes();
      await _storage.ref(path).putData(
            bytes,
            SettableMetadata(
              contentType: 'application/pdf',
              customMetadata: {'ownerUid': ownerUid, 'docId': docId},
            ),
          );

      final approverUids = recipients.map((r) => r.uid).toList();
      final approvers = <String, TimesheetApproverEntry>{};
      for (var i = 0; i < recipients.length; i++) {
        final recipient = recipients[i];
        approvers[recipient.uid] = TimesheetApproverEntry(
          role: i == 0
              ? TimesheetApproverRole.siteEngineer
              : TimesheetApproverRole.projectsManager,
          name: recipient.name,
          status: TimesheetApproverStatus.pending,
        );
      }

      final draft = TimesheetApproval(
        id: docId,
        ownerUid: ownerUid,
        ownerName: ownerName,
        fileName: fileName,
        projectId: projectId,
        projectName: projectName,
        pageCount: pageCount,
        pdfPath: path,
        approvers: approvers,
        approverUids: approverUids,
        pendingUids: List<String>.from(approverUids),
        status: TimesheetApprovalStatus.pending,
        cells: cells,
        createdAt: DateTime.now(),
      );

      await _collection.doc(docId).set(draft.toFirestore());
      return draft;
    });
  }

  Stream<List<TimesheetApproval>> watchMine(
    String ownerUid, {
    int? limit,
  }) {
    if (ownerUid.isEmpty) {
      return Stream.value(const <TimesheetApproval>[]);
    }
    Query<Map<String, dynamic>> query = _collection
        .where('owner_uid', isEqualTo: ownerUid)
        .orderBy('created_at', descending: true);
    if (limit != null && limit > 0) {
      query = query.limit(limit);
    }
    return query
        .snapshots()
        .map((snap) => snap.docs.map(TimesheetApproval.fromFirestore).toList())
        .handleError((error, _) {
      debugPrint('TimesheetApproval watchMine: $error');
    });
  }

  Stream<List<TimesheetApproval>> watchPendingFor(String uid) {
    if (uid.isEmpty) {
      return Stream.value(const <TimesheetApproval>[]);
    }
    return _collection
        .where('pending_uids', arrayContains: uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TimesheetApproval.fromFirestore).toList())
        .handleError((error, _) {
      debugPrint('TimesheetApproval watchPendingFor: $error');
    });
  }

  Stream<int> watchPendingCountFor(String uid) {
    return watchPendingFor(uid).map((list) => list.length);
  }

  /// Aggregate count for the home badge (not a full document download).
  Future<int> countPendingFor(String uid) {
    if (uid.isEmpty) return Future.value(0);
    return _withAuth(() async {
      final snap = await _collection
          .where('pending_uids', arrayContains: uid)
          .count()
          .get();
      return snap.count ?? 0;
    });
  }

  Future<TimesheetApproval?> getById(String id) {
    return _withAuth(() async {
      final snap = await _collection.doc(id).get();
      if (!snap.exists) return null;
      return TimesheetApproval.fromFirestore(snap);
    });
  }

  Future<Uint8List> downloadPdf(String path) {
    return _withAuth(() async {
      final data = await _storage.ref(path).getData();
      if (data == null || data.isEmpty) {
        throw Exception('PDF not found');
      }
      return data;
    });
  }

  /// Approves or rejects as the signed-in user, in a transaction.
  Future<TimesheetApproval> act({
    required String id,
    required bool approve,
  }) {
    return _withAuth(() async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        throw Exception('Firebase auth required');
      }

      return _firestore.runTransaction((tx) async {
        final ref = _collection.doc(id);
        final snap = await tx.get(ref);
        if (!snap.exists) {
          throw Exception('Timesheet approval not found');
        }
        final current = TimesheetApproval.fromFirestore(snap);
        if (!current.pendingUids.contains(uid)) {
          throw Exception('You are no longer asked to act on this timesheet');
        }
        final mine = current.approvers[uid];
        if (mine == null) {
          throw Exception('You are not an approver on this timesheet');
        }

        final actedAt = DateTime.now();
        final nextMine = mine.copyWith(
          status: approve
              ? TimesheetApproverStatus.approved
              : TimesheetApproverStatus.rejected,
          actedAt: actedAt,
        );

        final List<String> nextPending;
        final TimesheetApprovalStatus nextStatus;
        if (approve) {
          nextPending =
              current.pendingUids.where((other) => other != uid).toList();
          nextStatus = nextPending.isEmpty
              ? TimesheetApprovalStatus.approved
              : TimesheetApprovalStatus.pending;
        } else {
          nextPending = const <String>[];
          nextStatus = TimesheetApprovalStatus.rejected;
        }

        // Write only this user's entry so the other approver's acted_at is
        // untouched (rules require affectedKeys().hasOnly([uid()])).
        tx.update(ref, {
          'approvers.$uid': {
            'role': nextMine.role.toJson(),
            'name': nextMine.name,
            'status': nextMine.status.toJson(),
            'acted_at': Timestamp.fromDate(actedAt),
          },
          'pending_uids': nextPending,
          'status': nextStatus.toJson(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        final nextApprovers = Map<String, TimesheetApproverEntry>.from(
          current.approvers,
        )..[uid] = nextMine;

        return TimesheetApproval(
          id: current.id,
          ownerUid: current.ownerUid,
          ownerName: current.ownerName,
          fileName: current.fileName,
          projectId: current.projectId,
          projectName: current.projectName,
          pageCount: current.pageCount,
          pdfPath: current.pdfPath,
          approvers: nextApprovers,
          approverUids: current.approverUids,
          pendingUids: nextPending,
          status: nextStatus,
          cells: current.cells,
          createdAt: current.createdAt,
          updatedAt: DateTime.now(),
        );
      });
    });
  }
}
