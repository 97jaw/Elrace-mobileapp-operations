import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/hr_management/data/employee_profile_models.dart';
import 'package:el_race/ui/presentation/hr_management/data/employees_profile_repository.dart';
import 'package:el_race/ui/presentation/my_actions/data/models/signature_document.dart';
import 'package:el_race/ui/presentation/my_actions/screens/signature/signature_document_viewer_screen.dart';
import 'package:el_race/ui/presentation/my_documents/screens/document_details_screen.dart';
import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/repository/firebase_notes_repository.dart';
import 'package:el_race/ui/presentation/my_notes/screens/note_detail_screen.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/map/project_analytics_screen.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Thin loaders for screens that take an object. Missing get-by-id APIs are
/// listed in the M2 commit message; this file does not add Odoo routes.
class DocumentByIdLoader extends StatefulWidget {
  const DocumentByIdLoader({super.key, required this.documentId});

  final String documentId;

  @override
  State<DocumentByIdLoader> createState() => _DocumentByIdLoaderState();
}

class _DocumentByIdLoaderState extends State<DocumentByIdLoader> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final token = SharedPref.getLoginDataOrNull()?.result?.token ?? '';
    if (token.isEmpty) return null;
    final response = await http.post(
      Uri.parse('${UrlUtil.baseUrl}get_employee_documents'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': const <String, dynamic>{},
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(response.body);
    return _findDocument(decoded, widget.documentId);
  }

  @override
  Widget build(BuildContext context) {
    return _LoaderShell<Map<String, dynamic>?>(
      future: _future,
      title: 'Document',
      emptyMessage: 'This document is not in your document list.',
      onRetry: () => setState(() => _future = _load()),
      builder: (doc) => DocumentDetailsScreen(document: doc!),
    );
  }
}

class NoteByIdLoader extends StatefulWidget {
  const NoteByIdLoader({
    super.key,
    required this.noteId,
    this.ownerId,
  });

  final String noteId;
  final String? ownerId;

  @override
  State<NoteByIdLoader> createState() => _NoteByIdLoaderState();
}

class _NoteByIdLoaderState extends State<NoteByIdLoader> {
  late Future<NoteModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<NoteModel?> _load() async {
    final repo = FirebaseNotesRepository();
    final own = await repo.getNoteById(widget.noteId);
    if (own != null) return own;
    final owner = widget.ownerId?.trim() ?? '';
    if (owner.isEmpty) return null;
    return repo.getSharedNote(ownerId: owner, noteId: widget.noteId);
  }

  @override
  Widget build(BuildContext context) {
    return _LoaderShell<NoteModel?>(
      future: _future,
      title: 'Note',
      emptyMessage: 'This note could not be opened.',
      onRetry: () => setState(() => _future = _load()),
      builder: (note) => NoteDetailScreen(note: note!),
    );
  }
}

class SignatureByIdLoader extends StatefulWidget {
  const SignatureByIdLoader({
    super.key,
    required this.documentId,
    this.pdfUrl,
    this.title,
  });

  final String documentId;
  final String? pdfUrl;
  final String? title;

  @override
  State<SignatureByIdLoader> createState() => _SignatureByIdLoaderState();
}

class _SignatureByIdLoaderState extends State<SignatureByIdLoader> {
  late Future<({String url, String title})?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({String url, String title})?> _load() async {
    final direct = widget.pdfUrl?.trim() ?? '';
    if (direct.isNotEmpty) {
      return (url: direct, title: widget.title?.trim().isNotEmpty == true ? widget.title!.trim() : 'Document');
    }
    final uid = FirebaseAuth.instance.currentUser?.uid ??
        SharedPref.getLoginDataOrNull()?.result?.data?.firebase_uid;
    if (uid == null || uid.isEmpty) return null;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('signature_documents')
        .doc(widget.documentId)
        .get();
    if (!snap.exists) return null;
    final doc = SignatureDocument.fromFirestore(snap);
    final url = (doc.signedPdfUrl ?? '').trim().isNotEmpty
        ? doc.signedPdfUrl!.trim()
        : doc.fileUrl.trim();
    if (url.isEmpty) return null;
    return (url: url, title: doc.fileName);
  }

  @override
  Widget build(BuildContext context) {
    return _LoaderShell<({String url, String title})?>(
      future: _future,
      title: 'Signature',
      emptyMessage: 'This signature document could not be opened.',
      onRetry: () => setState(() => _future = _load()),
      builder: (doc) => SignatureDocumentViewerScreen(
        pdfUrl: doc!.url,
        title: doc.title,
      ),
    );
  }
}

class ProjectByIdLoader extends StatefulWidget {
  const ProjectByIdLoader({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectByIdLoader> createState() => _ProjectByIdLoaderState();
}

class _ProjectByIdLoaderState extends State<ProjectByIdLoader> {
  late Future<ProjectModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ProjectModel?> _load() async {
    final id = int.tryParse(widget.projectId);
    if (id == null || id <= 0) return null;
    final token = SharedPref.getLoginDataOrNull()?.result?.token ?? '';
    if (token.isEmpty) return null;
    final response = await http.post(
      Uri.parse('${UrlUtil.baseUrl}v2/get_project'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {'project_id': id},
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final decoded = jsonDecode(response.body);
    final result = decoded is Map ? decoded['result'] : null;
    if (result is! Map || result['status'] != 'success') return null;
    final data = result['data'];
    if (data is! Map) return null;
    final project = ProjectModel.fromJson(Map<String, dynamic>.from(data));
    if (project.projectId <= 0) return null;
    return project;
  }

  @override
  Widget build(BuildContext context) {
    return _LoaderShell<ProjectModel?>(
      future: _future,
      title: 'Project',
      emptyMessage: 'This project could not be opened.',
      onRetry: () => setState(() => _future = _load()),
      builder: (project) => ProjectAnalyticsScreen(project: project!),
    );
  }
}

class EmployeeByIdLoader extends StatefulWidget {
  const EmployeeByIdLoader({super.key, required this.employeeId});

  final String employeeId;

  @override
  State<EmployeeByIdLoader> createState() => _EmployeeByIdLoaderState();
}

class _EmployeeByIdLoaderState extends State<EmployeeByIdLoader> {
  late Future<EmployeeProfileDetail?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<EmployeeProfileDetail?> _load() async {
    final id = int.tryParse(widget.employeeId);
    if (id == null || id <= 0) return null;
    return EmployeesProfileRepository().fetchProfile(id);
  }

  @override
  Widget build(BuildContext context) {
    return _LoaderShell<EmployeeProfileDetail?>(
      future: _future,
      title: 'Employee',
      emptyMessage: 'This employee profile could not be opened.',
      onRetry: () => setState(() => _future = _load()),
      builder: (profile) => _EmployeeSummary(profile: profile!),
    );
  }
}

class _EmployeeSummary extends StatelessWidget {
  const _EmployeeSummary({required this.profile});

  final EmployeeProfileDetail profile;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Job', profile.jobTitle ?? ''),
      ('Department', profile.department ?? ''),
      ('Section', profile.section ?? ''),
      ('Phone', profile.mobilePhone ?? ''),
      ('Email', profile.workEmail ?? ''),
    ].where((row) => row.$2.trim().isNotEmpty).toList();
    return Scaffold(
      appBar: AppBar(title: Text(profile.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(profile.empId, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final row in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(row.$1),
              subtitle: Text(row.$2),
            ),
        ],
      ),
    );
  }
}

class _LoaderShell<T> extends StatelessWidget {
  const _LoaderShell({
    required this.future,
    required this.title,
    required this.emptyMessage,
    required this.onRetry,
    required this.builder,
  });

  final Future<T> future;
  final String title;
  final String emptyMessage;
  final VoidCallback onRetry;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final value = snapshot.data;
        final missing = snapshot.hasError || value == null;
        if (missing) {
          return _MessagePage(
            title: title,
            message: emptyMessage,
            onRetry: onRetry,
          );
        }
        return builder(value);
      },
    );
  }
}

class _MessagePage extends StatelessWidget {
  const _MessagePage({
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                TextButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic>? _findDocument(dynamic node, String id) {
  if (node is Map) {
    final map = Map<String, dynamic>.from(node);
    final rowId = '${map['id'] ?? map['document_id'] ?? ''}'.trim();
    if (rowId == id && (map.containsKey('document_type') || map.containsKey('name') || map.containsKey('document_number'))) {
      return map;
    }
    for (final value in map.values) {
      final found = _findDocument(value, id);
      if (found != null) return found;
    }
  } else if (node is List) {
    for (final item in node) {
      final found = _findDocument(item, id);
      if (found != null) return found;
    }
  }
  return null;
}
