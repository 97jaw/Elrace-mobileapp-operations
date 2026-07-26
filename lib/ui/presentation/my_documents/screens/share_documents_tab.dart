import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_documents/theme/shared_documents_theme.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class ShareDocumentsTab extends StatefulWidget {
  const ShareDocumentsTab({
    super.key,
    this.onOpenDocument,
  });

  final Future<void> Function(Map<String, dynamic> document)? onOpenDocument;

  @override
  State<ShareDocumentsTab> createState() => _ShareDocumentsTabState();
}

class _ShareDocumentsTabState extends State<ShareDocumentsTab> {
  bool _isLoadingFolders = false;
  bool _isLoadingFolderContents = false;
  bool _isCreatingFolder = false;
  bool _isAddingUser = false;
  bool _isCreateDialogOpen = false;
  bool _isAddUserDialogOpen = false;
  String? _error;
  String? _folderOpenError;

  List<Map<String, dynamic>> _folders = <Map<String, dynamic>>[];

  Map<String, dynamic>? _selectedFolder;
  List<_SharedAttachment> _selectedFolderAttachments = const [];

  @override
  void initState() {
    super.initState();
    _fetchSharedFolders();
  }

  String _normalizeToken(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }

  Map<String, dynamic> _extractResultEnvelope(dynamic decoded) {
    if (decoded is Map && decoded['result'] is Map) {
      return Map<String, dynamic>.from(decoded['result'] as Map);
    }
    if (decoded is Map && decoded['status'] != null) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  bool _isSuccessEnvelope(Map<String, dynamic> envelope) {
    final status = _normalizeToken(envelope['status']);
    return status == 'success' || status == 'ok' || status == 'true';
  }

  Future<http.Response> _sendJsonRpcGet(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> params,
  ) async {
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = jsonEncode({
        'jsonrpc': '2.0',
        'params': params,
      });

    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  Future<http.Response> _sendJsonRpcPost(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> params,
  ) {
    return http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'jsonrpc': '2.0',
        'params': params,
      }),
    );
  }

  dynamic _folderIdFrom(Map<String, dynamic> folder) {
    final raw = folder['id'] ?? folder['folder_id'] ?? folder['folderId'];
    if (raw == null) return null;
    final parsed = int.tryParse(raw.toString());
    return parsed ?? raw;
  }

  String _folderNameFrom(Map<String, dynamic> folder) {
    final raw = folder['name'] ?? folder['folder_name'] ?? folder['title'];
    final value = (raw ?? '').toString().trim();
    return value.isEmpty ? 'Folder' : value;
  }

  String _folderNameForUi(Map<String, dynamic> folder) {
    final value = _folderNameFrom(folder);
    if (value.length <= 15) return value;
    return '${value.substring(0, 12)}...';
  }

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<void> _fetchSharedFolders({dynamic focusFolderId}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingFolders = true;
      _error = null;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      final url = Uri.parse('https://erp.elrace.com/api/cloud/shared_folders');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      var response = await _sendJsonRpcGet(url, headers, <String, dynamic>{});

      if (response.statusCode == 400 ||
          response.statusCode == 404 ||
          response.statusCode == 405) {
        response = await http.get(
          url,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load shared folders (HTTP ${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);
      final envelope = _extractResultEnvelope(decoded);
      if (!_isSuccessEnvelope(envelope)) {
        throw Exception(
          envelope['message']?.toString() ??
              (decoded is Map ? decoded['error']?.toString() : null) ??
              'Failed to load shared folders',
        );
      }

      final rawData = envelope['data'] ??
          (decoded is Map && decoded['data'] is List ? decoded['data'] : null);
      if (rawData is! List) {
        throw Exception('Invalid shared folders response format');
      }

      final folders = _toMapList(rawData)
          .map((folder) {
            final mapped = Map<String, dynamic>.from(folder);
            mapped['id'] = _folderIdFrom(folder);
            mapped['name'] = _folderNameFrom(folder);
            mapped['allowed_users'] = _toMapList(folder['allowed_users']);
            mapped['activities'] = _toMapList(folder['activities']);
            return mapped;
          })
          .where((folder) => folder['id'] != null)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _folders = folders;
        if (_selectedFolder != null && folders.isNotEmpty) {
          final selectedId = _folderIdFrom(_selectedFolder!);
          final selectedIndex = folders.indexWhere(
            (f) => _folderIdFrom(f).toString() == selectedId.toString(),
          );
          if (selectedIndex >= 0) {
            final refreshed = folders[selectedIndex];
            _selectedFolder = {
              ...refreshed,
              'attachments':
                  (_selectedFolder?['attachments'] ?? refreshed['attachments']),
            };
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFolders = false;
        });
      }
    }
  }

  Map<String, dynamic>? get _activeFolder => _selectedFolder;

  List<Map<String, dynamic>> get _currentAllowedUsers {
    final folder = _activeFolder;
    if (folder == null) return const <Map<String, dynamic>>[];
    return _toMapList(folder['allowed_users']);
  }

  List<Map<String, dynamic>> get _currentActivities {
    final folder = _activeFolder;
    if (folder == null) return const <Map<String, dynamic>>[];
    return _toMapList(folder['activities']);
  }

  List<_SharedAttachment> _extractAttachments(Map<String, dynamic> folder) {
    final folderName = _folderNameFrom(folder);
    final folderId = _folderIdFrom(folder);
    debugPrint(
      '[SharedDocuments] Extract attachments for folder: '
      'id=$folderId, name=$folderName',
    );

    final rawCandidates = [
      folder['attachments'],
      folder['files'],
      folder['documents'],
      folder['folder_attachments'],
    ];

    const candidateNames = [
      'attachments',
      'files',
      'documents',
      'folder_attachments',
    ];

    List<Map<String, dynamic>> source = const <Map<String, dynamic>>[];
    String selectedSourceName = 'none';
    for (var i = 0; i < rawCandidates.length; i++) {
      final candidate = rawCandidates[i];
      final mapped = _toMapList(candidate);
      debugPrint(
        '[SharedDocuments] Candidate ${candidateNames[i]} count=${mapped.length}',
      );
      if (mapped.isNotEmpty) {
        source = mapped;
        selectedSourceName = candidateNames[i];
        break;
      }
    }

    debugPrint(
      '[SharedDocuments] Selected source: $selectedSourceName, '
      'files=${source.length}',
    );

    final attachments = source.map((item) {
      final id = int.tryParse(
              (item['id'] ?? item['attachment_id'] ?? item['file_id'] ?? '')
                  .toString()) ??
          0;
      final name =
          (item['name'] ?? item['filename'] ?? item['file_name'] ?? 'File')
              .toString();
      final fileUrl =
          (item['file_url'] ?? item['url'] ?? item['download_url'] ?? '')
              .toString();

      return _SharedAttachment(
        id: id,
        name: name,
        fileUrl: fileUrl,
        raw: Map<String, dynamic>.from(item),
      );
    }).toList(growable: false);

    for (final file in attachments) {
      debugPrint(
        '[SharedDocuments] File -> id=${file.id}, '
        'name=${file.name}, url=${file.fileUrl}',
      );
    }

    return attachments;
  }

  Future<Map<String, dynamic>> _fetchSharedFolderDetails(
    Map<String, dynamic> baseFolder, {
    int limit = 10,
    int offset = 0,
  }) async {
    final token = SharedPref.getLoginData().result?.token ?? '';
    if (token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final folderId = _folderIdFrom(baseFolder);
    if (folderId == null) {
      throw Exception('Invalid folder id');
    }

    final url = Uri.parse('https://erp.elrace.com/api/cloud/folder/details');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final params = {
      'folder_id': folderId,
      'limit': limit,
      'offset': offset,
    };

    debugPrint(
      '[SharedDocuments] Fetch folder details: folder_id=$folderId, '
      'limit=$limit, offset=$offset',
    );

    var response = await _sendJsonRpcGet(url, headers, params);
    if (response.statusCode == 400 ||
        response.statusCode == 404 ||
        response.statusCode == 405) {
      response = await _sendJsonRpcPost(url, headers, params);
    }

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load shared folder details (HTTP ${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final envelope = _extractResultEnvelope(decoded);
    if (!_isSuccessEnvelope(envelope)) {
      throw Exception(
        envelope['message']?.toString() ??
            (decoded is Map ? decoded['error']?.toString() : null) ??
            'Failed to load shared folder details',
      );
    }

    final folderPayload = envelope['folder'] is Map
        ? Map<String, dynamic>.from(envelope['folder'] as Map)
        : <String, dynamic>{};

    final detailedFolder = {
      ...baseFolder,
      ...folderPayload,
      'id':
          _folderIdFrom(folderPayload.isNotEmpty ? folderPayload : baseFolder),
      'name': _folderNameFrom(
          folderPayload.isNotEmpty ? folderPayload : baseFolder),
      'attachments': _toMapList(envelope['attachments']),
      'allowed_users': _toMapList(envelope['allowed_users']),
      'activities': _toMapList(envelope['activities']),
    };

    debugPrint(
      '[SharedDocuments] Folder details loaded: '
      'attachments=${_toMapList(detailedFolder['attachments']).length}, '
      'allowed_users=${_toMapList(detailedFolder['allowed_users']).length}',
    );

    return detailedFolder;
  }

  Future<void> _openFolder(Map<String, dynamic> folder) async {
    if (!mounted) return;

    final folderId = _folderIdFrom(folder);
    final folderName = _folderNameFrom(folder);
    debugPrint(
      '[SharedDocuments] Open folder requested: id=$folderId, name=$folderName',
    );

    setState(() {
      _isLoadingFolderContents = true;
      _selectedFolder = folder;
      _selectedFolderAttachments = const [];
      _folderOpenError = null;
    });

    try {
      final detailedFolder = await _fetchSharedFolderDetails(
        folder,
        limit: 10,
        offset: 0,
      );

      if (!mounted) return;
      debugPrint(
        '[SharedDocuments] Folder details response applied: '
        'id=${_folderIdFrom(detailedFolder)}, '
        'name=${_folderNameFrom(detailedFolder)}',
      );

      final extracted = _extractAttachments(detailedFolder);
      setState(() {
        _selectedFolder = detailedFolder;
        _selectedFolderAttachments = extracted;
        _folderOpenError = null;
      });

      final selectedIndex = _folders.indexWhere(
        (f) => _folderIdFrom(f).toString() == folderId.toString(),
      );
      if (selectedIndex >= 0) {
        _folders[selectedIndex] = {
          ..._folders[selectedIndex],
          'allowed_users': _toMapList(detailedFolder['allowed_users']),
          'attachments': _toMapList(detailedFolder['attachments']),
        };
      }

      debugPrint(
        '[SharedDocuments] Open folder completed: '
        'attachments=${_selectedFolderAttachments.length}',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _folderOpenError = e.toString();
        });
      }
      _showSnackMessage(e.toString());
      debugPrint('[SharedDocuments] Open folder failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFolderContents = false;
        });
      }
    }
  }

  void _goBackToFolders() {
    if (!mounted) return;
    setState(() {
      _selectedFolder = null;
      _selectedFolderAttachments = const [];
      _folderOpenError = null;
      _error = null;
    });
  }

  Future<void> _openAttachment(_SharedAttachment attachment) async {
    final callback = widget.onOpenDocument;
    if (callback == null) return;

    final map = Map<String, dynamic>.from(attachment.raw)
      ..['name'] = attachment.name
      ..['title'] = attachment.name
      ..['file_url'] = attachment.fileUrl
      ..['attachment_ids'] = [
        {
          'attachment_id': attachment.id,
        }
      ];

    await callback(map);
  }

  void _showSnackMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCreateFolderDialog() async {
    if (_isCreateDialogOpen) return;
    _isCreateDialogOpen = true;

    final nameController = TextEditingController();
    var isDialogActive = true;
    try {
      final draft = await showDialog<_CreateFolderDraft>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) {
          final pickedAttachments = <_CreateFolderAttachment>[];
          var isPickingFiles = false;
          var nameLength = 0;

          return StatefulBuilder(
            builder: (context, setLocalState) {
              Future<void> pickAttachments() async {
                if (!isDialogActive) return;
                setLocalState(() {
                  isPickingFiles = true;
                });

                try {
                  final result = await FilePicker.pickFiles(
                    allowMultiple: true,
                    withData: true,
                  );

                  if (!isDialogActive) return;
                  if (result == null) return;

                  for (final file in result.files) {
                    final filename = file.name.trim();
                    if (filename.isEmpty) continue;

                    final existing = pickedAttachments.any(
                      (e) => e.filename.toLowerCase() == filename.toLowerCase(),
                    );
                    if (existing) continue;

                    List<int>? bytes = file.bytes;
                    if ((bytes == null || bytes.isEmpty) && file.path != null) {
                      bytes = await File(file.path!).readAsBytes();
                    }
                    if (bytes == null || bytes.isEmpty) continue;

                    pickedAttachments.add(
                      _CreateFolderAttachment(
                        filename: filename,
                        base64File: base64Encode(bytes),
                      ),
                    );
                  }

                  if (context.mounted && isDialogActive) {
                    setLocalState(() {});
                  }
                } finally {
                  if (context.mounted && isDialogActive) {
                    setLocalState(() {
                      isPickingFiles = false;
                    });
                  }
                }
              }

              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding:
                    EdgeInsets.symmetric(horizontal: 16.tw, vertical: 24.th),
                child: Container(
                  width: 360.tw,
                  decoration: SharedDocumentsTheme.sheetDecoration(radius: 22.tr),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(18.tw, 12.th, 18.tw, 18.th),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: InkWell(
                            onTap: () {
                              isDialogActive = false;
                              if (Navigator.canPop(ctx)) {
                                Navigator.pop(ctx);
                              }
                            },
                            borderRadius: BorderRadius.circular(20.tr),
                            child: Container(
                              width: 36.tw,
                              height: 36.tw,
                              decoration: BoxDecoration(
                                color: SharedDocumentsTheme.hubBackground,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: SharedDocumentsTheme.border,
                                ),
                              ),
                              child: Icon(
                                Icons.close,
                                color: SharedDocumentsTheme.textPrimary,
                                size: 20.tsp,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 4.th),
                        Text(
                          'Create folder',
                          style: GoogleFonts.poppins(
                            fontSize: 22.tsp,
                            fontWeight: FontWeight.w700,
                            color: SharedDocumentsTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4.th),
                        Text(
                          'Name it and optionally attach files',
                          style: GoogleFonts.poppins(
                            fontSize: 12.tsp,
                            fontWeight: FontWeight.w500,
                            color: SharedDocumentsTheme.textMuted,
                          ),
                        ),
                        SizedBox(height: 16.th),
                        Container(
                          height: 44.th,
                          decoration: BoxDecoration(
                            color: SharedDocumentsTheme.hubBackground,
                            borderRadius: BorderRadius.circular(14.tr),
                            border: Border.all(
                              color: SharedDocumentsTheme.border,
                            ),
                          ),
                          child: TextField(
                            controller: nameController,
                            textAlign: TextAlign.center,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(15),
                            ],
                            onChanged: (value) {
                              setLocalState(() {
                                nameLength = value.length;
                              });
                            },
                            style: GoogleFonts.poppins(
                              fontSize: 14.tsp,
                              fontWeight: FontWeight.w600,
                              color: SharedDocumentsTheme.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Folder name',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 14.tsp,
                                fontWeight: FontWeight.w500,
                                color: SharedDocumentsTheme.textMuted,
                              ),
                              border: InputBorder.none,
                              counterText: '',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.tw,
                                vertical: 10.th,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 4.th),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            nameLength >= 15
                                ? 'Reached max: 15 characters'
                                : '${15 - nameLength} characters left',
                            style: GoogleFonts.poppins(
                              fontSize: 10.tsp,
                              fontWeight: FontWeight.w500,
                              color: nameLength >= 15
                                  ? SharedDocumentsTheme.danger
                                  : SharedDocumentsTheme.textMuted,
                            ),
                          ),
                        ),
                        SizedBox(height: 12.th),
                        InkWell(
                          onTap: isPickingFiles ? null : pickAttachments,
                          borderRadius: BorderRadius.circular(12.tr),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.tw, vertical: 6.th),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.upload_file_rounded,
                                  size: 20.tsp,
                                  color: SharedDocumentsTheme.accent,
                                ),
                                SizedBox(width: 6.tw),
                                Text(
                                  isPickingFiles
                                      ? 'Attaching…'
                                      : 'Attach files',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.tsp,
                                    fontWeight: FontWeight.w600,
                                    color: SharedDocumentsTheme.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (pickedAttachments.isNotEmpty) ...[
                          SizedBox(height: 4.th),
                          Text(
                            '${pickedAttachments.length} file(s) selected',
                            style: GoogleFonts.poppins(
                              fontSize: 11.tsp,
                              color: SharedDocumentsTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        SizedBox(height: 16.th),
                        SizedBox(
                          width: double.infinity,
                          height: 46.th,
                          child: ElevatedButton(
                            onPressed: () {
                              final value = nameController.text.trim();
                              if (value.isEmpty) {
                                _showSnackMessage('Please enter folder name');
                                return;
                              }

                              if (value.length > 15) {
                                _showSnackMessage(
                                    'Folder name must be 15 characters max');
                                return;
                              }

                              isDialogActive = false;
                              Navigator.pop(
                                ctx,
                                _CreateFolderDraft(
                                  folderName: value,
                                  attachments: pickedAttachments.toList(
                                      growable: false),
                                ),
                              );
                            },
                            style: SharedDocumentsTheme.softFilledButton(
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'Create',
                              style: GoogleFonts.poppins(
                                fontSize: 15.tsp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      isDialogActive = false;

      if (draft == null || draft.folderName.trim().isEmpty) return;
      await _createFolder(
        draft.folderName.trim(),
        attachments: draft.attachments,
      );
    } finally {
      nameController.dispose();
      _isCreateDialogOpen = false;
    }
  }

  Future<void> _createFolder(
    String folderName, {
    List<_CreateFolderAttachment> attachments =
        const <_CreateFolderAttachment>[],
  }) async {
    if (!mounted) return;
    setState(() {
      _isCreatingFolder = true;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      final url = Uri.parse('https://erp.elrace.com/api/cloud/folder/create');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'name': folderName,
          if (attachments.isNotEmpty)
            'attachments': attachments
                .map((a) => {
                      'filename': a.filename,
                      'file': a.base64File,
                    })
                .toList(growable: false),
        },
      });

      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to create folder (HTTP ${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);
      final envelope = _extractResultEnvelope(decoded);
      if (!_isSuccessEnvelope(envelope)) {
        throw Exception(
          envelope['message']?.toString() ??
              (decoded is Map ? decoded['error']?.toString() : null) ??
              'Failed to create folder',
        );
      }

      _showSnackMessage(
        attachments.isEmpty
            ? 'Folder created successfully'
            : 'Folder and attachments created successfully',
      );
      await _fetchSharedFolders();
    } catch (e) {
      _showSnackMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingFolder = false;
        });
      }
    }
  }

  Future<void> _showAddUserDialog() async {
    final folder = _activeFolder;
    if (folder == null || _isAddUserDialogOpen) return;

    _isAddUserDialogOpen = true;
    try {
      final members = await TeamMembersApiService.instance.getTeamMembers();
      final existingIds = _currentAllowedUsers
          .map((u) => int.tryParse(
              (u['employee_id'] ?? u['emp_id'] ?? u['id']).toString()))
          .whereType<int>()
          .toSet();

      final selectedEmployeeIds = await showDialog<List<int>>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) {
          final searchController = TextEditingController();
          final selected = <int>{};
          var query = '';

          List<TeamMember> filtered() {
            final q = query.trim().toLowerCase();
            if (q.isEmpty) return members;
            return members.where((m) {
              final n = m.name.toLowerCase();
              final p = (m.phone ?? '').toLowerCase();
              return n.contains(q) || p.contains(q);
            }).toList(growable: false);
          }

          return StatefulBuilder(
            builder: (context, setLocalState) {
              final results = filtered();

              return Dialog(
                insetPadding:
                    EdgeInsets.symmetric(horizontal: 10.tw, vertical: 14.th),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.tr),
                ),
                child: SizedBox(
                  height: 640.th,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.tw, 12.th, 14.tw, 16.th),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(10.tr),
                            child: Container(
                              width: 34.tw,
                              height: 34.tw,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.tr),
                                border: Border.all(
                                  color: const Color(0xFFD95959),
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                Icons.close,
                                size: 18.tsp,
                                color: const Color(0xFFD95959),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8.th),
                        TextField(
                          controller: searchController,
                          onChanged: (value) {
                            setLocalState(() {
                              query = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search Phone Number',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 13.tsp,
                              color: const Color(0xFFA1A1A1),
                            ),
                            suffixIcon: Icon(
                              Icons.search,
                              color: const Color(0xFF8A8A8A),
                              size: 22.tsp,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14.tw,
                              vertical: 10.th,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22.tr),
                              borderSide: const BorderSide(
                                color: Color(0xFFB7B7B7),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22.tr),
                              borderSide: const BorderSide(
                                color: Color(0xFFB7B7B7),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22.tr),
                              borderSide: const BorderSide(
                                color: Color(0xFF9C9C9C),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 10.th),
                        Expanded(
                          child: ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, __) => SizedBox(height: 8.th),
                            itemBuilder: (context, index) {
                              final m = results[index];
                              final employeeId = m.employeeId ?? m.id;
                              final isExisting =
                                  existingIds.contains(employeeId);
                              final isSelected = selected.contains(employeeId);

                              return Row(
                                children: [
                                  CircleAvatar(
                                    radius: 17.tr,
                                    backgroundColor: const Color(0xFFE4E4E9),
                                    backgroundImage: (m.image != null &&
                                            m.image!.trim().isNotEmpty)
                                        ? NetworkImage(m.image!)
                                        : null,
                                    child: (m.image == null ||
                                            m.image!.trim().isEmpty)
                                        ? Text(
                                            _userInitial(m.name),
                                            style: GoogleFonts.poppins(
                                              fontSize: 11.tsp,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF565656),
                                            ),
                                          )
                                        : null,
                                  ),
                                  SizedBox(width: 12.tw),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14.tsp,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF222222),
                                          ),
                                        ),
                                        Text(
                                          (m.phone ?? '-'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.tsp,
                                            color: const Color(0xFF8B8B8B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    onTap: isExisting
                                        ? null
                                        : () {
                                            setLocalState(() {
                                              if (isSelected) {
                                                selected.remove(employeeId);
                                              } else {
                                                selected.add(employeeId);
                                              }
                                            });
                                          },
                                    borderRadius: BorderRadius.circular(9.tr),
                                    child: Container(
                                      width: 34.tw,
                                      height: 34.tw,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(9.tr),
                                        color: isSelected
                                            ? const Color(0xFF8B1A2B)
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: isExisting
                                              ? const Color(0xFFB4B4B4)
                                              : const Color(0xFFA9A9A9),
                                          width: 1.4,
                                        ),
                                      ),
                                      child: isSelected
                                          ? Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 20.tsp,
                                            )
                                          : null,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 10.th),
                        InkWell(
                          onTap: selected.isEmpty
                              ? null
                              : () => Navigator.pop(
                                    ctx,
                                    selected.toList(growable: false),
                                  ),
                          borderRadius: BorderRadius.circular(22.tr),
                          child: Ink(
                            width: 125.tw,
                            height: 42.th,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22.tr),
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFFA8324A),
                                  Color(0xFF8B1A2B),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'ADD',
                                style: GoogleFonts.poppins(
                                  fontSize: 24.tsp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (selectedEmployeeIds == null || selectedEmployeeIds.isEmpty) return;
      await _addUsersToFolder(folder, selectedEmployeeIds);
    } finally {
      _isAddUserDialogOpen = false;
    }
  }

  Future<void> _addUsersToFolder(
    Map<String, dynamic> folder,
    List<int> employeeIds,
  ) async {
    final folderId = _folderIdFrom(folder);
    if (folderId == null || !mounted) return;

    setState(() {
      _isAddingUser = true;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      final url = Uri.parse('https://erp.elrace.com/api/cloud/folder/add_user');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      var successCount = 0;
      final failed = <int>[];

      for (final employeeId in employeeIds) {
        final body = jsonEncode({
          'jsonrpc': '2.0',
          'params': {
            'folder_id': folderId,
            'employee_id': employeeId,
          },
        });

        try {
          final response = await http.post(url, headers: headers, body: body);
          if (response.statusCode != 200) {
            failed.add(employeeId);
            continue;
          }

          final decoded = jsonDecode(response.body);
          final envelope = _extractResultEnvelope(decoded);
          if (_isSuccessEnvelope(envelope)) {
            successCount++;
          } else {
            failed.add(employeeId);
          }
        } catch (_) {
          failed.add(employeeId);
        }
      }

      await _fetchSharedFolders(focusFolderId: folderId);

      if (successCount > 0 && failed.isEmpty) {
        _showSnackMessage('Users added successfully');
      } else if (successCount > 0) {
        _showSnackMessage('$successCount users added, ${failed.length} failed');
      } else {
        _showSnackMessage('Failed to add selected users');
      }
    } catch (e) {
      _showSnackMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isAddingUser = false;
        });
      }
    }
  }

  Future<void> _addUserToFolder(
      Map<String, dynamic> folder, int employeeId) async {
    final folderId = _folderIdFrom(folder);
    if (folderId == null || !mounted) return;

    setState(() {
      _isAddingUser = true;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      final url = Uri.parse('https://erp.elrace.com/api/cloud/folder/add_user');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'folder_id': folderId,
          'employee_id': employeeId,
        },
      });

      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode != 200) {
        throw Exception('Failed to add user (HTTP ${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);
      final envelope = _extractResultEnvelope(decoded);
      if (!_isSuccessEnvelope(envelope)) {
        throw Exception(
          envelope['message']?.toString() ??
              (decoded is Map ? decoded['error']?.toString() : null) ??
              'Failed to add user',
        );
      }

      _showSnackMessage('User added successfully');
      await _fetchSharedFolders(focusFolderId: folderId);
    } catch (e) {
      _showSnackMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isAddingUser = false;
        });
      }
    }
  }

  String _userNameFrom(Map<String, dynamic> user) {
    final raw = (user['name'] ??
            user['employee_name'] ??
            user['display_name'] ??
            'User')
        .toString()
        .trim();
    return raw.isEmpty ? 'User' : raw;
  }

  String? _userAvatarUrlFrom(Map<String, dynamic> user) {
    final candidates = [
      user['image_1920'],
      user['image_url'],
      user['avatar'],
      user['photo'],
    ];
    for (final value in candidates) {
      final url = value?.toString().trim() ?? '';
      if (url.isNotEmpty) return url;
    }
    return null;
  }

  String _userInitial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed.substring(0, 1).toUpperCase();
  }

  String _activityTime(Map<String, dynamic> activity) {
    final raw = (activity['time'] ??
            activity['create_date'] ??
            activity['created_at'] ??
            activity['date'] ??
            activity['timestamp'] ??
            '')
        .toString()
        .trim();

    if (raw.isEmpty) return '';

    final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return raw;

    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return raw;
  }

  String _activityMessage(Map<String, dynamic> activity) {
    final direct = (activity['message'] ?? activity['description'] ?? '')
        .toString()
        .trim();
    if (direct.isNotEmpty) return direct;

    final actor = (activity['user_name'] ??
            activity['employee_name'] ??
            activity['name'] ??
            'User')
        .toString()
        .trim();
    final action =
        (activity['action'] ?? activity['type'] ?? 'updated').toString().trim();
    final target = (activity['document_name'] ??
            activity['file_name'] ??
            activity['target'] ??
            'folder')
        .toString()
        .trim();

    return '$actor $action $target'.trim();
  }

  int _folderFileCount(Map<String, dynamic> folder) {
    final attachments = _toMapList(folder['attachments']);
    if (attachments.isNotEmpty) return attachments.length;
    final raw = folder['file_count'] ??
        folder['attachment_count'] ??
        folder['files_count'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    IconData? icon,
    String? assetPath,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.th, horizontal: 12.tw),
      child: Column(
        children: [
          if (assetPath != null)
            Image.asset(
              assetPath,
              width: 88.tw,
              height: 88.tw,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                icon ?? Icons.folder_off_rounded,
                size: 56.tsp,
                color: SharedDocumentsTheme.accentMuted,
              ),
            )
          else
            Icon(
              icon ?? Icons.folder_off_rounded,
              size: 56.tsp,
              color: SharedDocumentsTheme.accentMuted,
            ),
          SizedBox(height: 12.th),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15.tsp,
              fontWeight: FontWeight.w700,
              color: SharedDocumentsTheme.textPrimary,
            ),
          ),
          SizedBox(height: 6.th),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.tsp,
              fontWeight: FontWeight.w500,
              color: SharedDocumentsTheme.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoldersList() {
    if (_folders.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: 16.th),
        child: _buildEmptyState(
          title: 'No shared folders',
          subtitle: 'Create a folder to start sharing documents.',
          assetPath: 'assets/newapp/Share Document file.png',
          icon: Icons.folder_shared_outlined,
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < _folders.length; index++) ...[
          if (index > 0) SizedBox(height: 10.th),
          Builder(
            builder: (context) {
              final folder = _folders[index];
              final users = _toMapList(folder['allowed_users']);
              return _SharedFolderCard(
                title: _folderNameForUi(folder),
                users: users,
                fileCount: _folderFileCount(folder),
                onTap: () => _openFolder(folder),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildOpenedFolderView() {
    final folder = _selectedFolder;
    if (folder == null) return const SizedBox.shrink();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(bottom: 8.th),
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 10.th),
          child: Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _goBackToFolders,
                  borderRadius: BorderRadius.circular(20.tr),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.tw, vertical: 8.th),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20.tr),
                      border: Border.all(color: SharedDocumentsTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 14.tsp,
                          color: SharedDocumentsTheme.accent,
                        ),
                        SizedBox(width: 6.tw),
                        Text(
                          'All folders',
                          style: GoogleFonts.poppins(
                            fontSize: 12.tsp,
                            fontWeight: FontWeight.w600,
                            color: SharedDocumentsTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10.tw),
              Expanded(
                child: Text(
                  _folderNameForUi(folder),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16.tsp,
                    fontWeight: FontWeight.w700,
                    color: SharedDocumentsTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(12.tw, 12.th, 12.tw, 8.th),
          decoration: SharedDocumentsTheme.glassCard(radius: 18.tr),
          child: _buildGivenAccessSection(),
        ),
        SizedBox(height: 12.th),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: 220.th),
          padding: EdgeInsets.fromLTRB(12.tw, 12.th, 12.tw, 12.th),
          decoration: SharedDocumentsTheme.glassCard(radius: 18.tr),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Files',
                style: GoogleFonts.poppins(
                  fontSize: 14.tsp,
                  fontWeight: FontWeight.w700,
                  color: SharedDocumentsTheme.textPrimary,
                ),
              ),
              SizedBox(height: 8.th),
              SizedBox(
                height: 280.th,
                child: _buildFilesSectionBody(),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.th),
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(12.tw, 12.th, 12.tw, 12.th),
          decoration: SharedDocumentsTheme.glassCard(radius: 18.tr),
          child: _buildRecentActivitySection(),
        ),
      ],
    );
  }

  /// Files body without Expanded wrapper (used inside opened-folder card).
  Widget _buildFilesSectionBody() {
    if (_isLoadingFolderContents) {
      return const Center(
        child: CircularProgressIndicator(color: SharedDocumentsTheme.accent),
      );
    }

    if (_folderOpenError != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.tw),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 36.tsp,
                color: SharedDocumentsTheme.danger,
              ),
              SizedBox(height: 8.th),
              Text(
                'Couldn’t open this folder',
                style: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  fontWeight: FontWeight.w700,
                  color: SharedDocumentsTheme.textPrimary,
                ),
              ),
              SizedBox(height: 10.th),
              OutlinedButton(
                onPressed: _selectedFolder == null
                    ? null
                    : () => _openFolder(_selectedFolder!),
                style: SharedDocumentsTheme.softOutlinedButton(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedFolderAttachments.isEmpty) {
      return _buildEmptyState(
        title: 'No files yet',
        subtitle: 'Files added to this folder will show up here.',
        assetPath: 'assets/newapp/Share Document file.png',
        icon: Icons.insert_drive_file_outlined,
      );
    }

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${_selectedFolderAttachments.length} files',
            style: GoogleFonts.poppins(
              fontSize: 12.tsp,
              fontWeight: FontWeight.w600,
              color: SharedDocumentsTheme.textSecondary,
            ),
          ),
        ),
        SizedBox(height: 8.th),
        Expanded(
          child: GridView.builder(
            itemCount: _selectedFolderAttachments.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10.tw,
              mainAxisSpacing: 10.th,
              mainAxisExtent: 140.th,
            ),
            itemBuilder: (context, index) {
              final item = _selectedFolderAttachments[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14.tr),
                  onTap: () => _openAttachment(item),
                  child: Container(
                    decoration: BoxDecoration(
                      color: SharedDocumentsTheme.hubBackground,
                      borderRadius: BorderRadius.circular(14.tr),
                      border: Border.all(color: SharedDocumentsTheme.border),
                    ),
                    padding: EdgeInsets.fromLTRB(8.tw, 10.th, 8.tw, 8.th),
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.asset(
                            'assets/newapp/pdf.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(height: 6.th),
                        Text(
                          item.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11.tsp,
                            fontWeight: FontWeight.w600,
                            color: SharedDocumentsTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGivenAccessSection() {
    final users = _currentAllowedUsers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Given access',
          style: GoogleFonts.poppins(
            fontSize: 14.tsp,
            fontWeight: FontWeight.w700,
            color: SharedDocumentsTheme.textPrimary,
          ),
        ),
        SizedBox(height: 12.th),
        SizedBox(
          height: 72.th,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: users.length + 1,
            separatorBuilder: (_, __) => SizedBox(width: 10.tw),
            itemBuilder: (context, index) {
              if (index == 0) {
                return InkWell(
                  onTap: _isAddingUser ? null : _showAddUserDialog,
                  borderRadius: BorderRadius.circular(28.tr),
                  child: SizedBox(
                    width: 52.tw,
                    height: 52.tw,
                    child: CustomPaint(
                      painter: _DashedCirclePainter(
                        color: SharedDocumentsTheme.accent,
                      ),
                      child: Center(
                        child: _isAddingUser
                            ? SizedBox(
                                width: 16.tw,
                                height: 16.tw,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: SharedDocumentsTheme.accent,
                                ),
                              )
                            : Icon(
                                Icons.add,
                                color: SharedDocumentsTheme.accent,
                                size: 24.tsp,
                              ),
                      ),
                    ),
                  ),
                );
              }

              final user = users[index - 1];
              final name = _userNameFrom(user);
              final avatarUrl = _userAvatarUrlFrom(user);

              return CircleAvatar(
                radius: 26.tr,
                backgroundColor: SharedDocumentsTheme.border,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        _userInitial(name),
                        style: GoogleFonts.poppins(
                          fontSize: 14.tsp,
                          fontWeight: FontWeight.w700,
                          color: SharedDocumentsTheme.textPrimary,
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    final activities = _currentActivities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent activity',
          style: GoogleFonts.poppins(
            fontSize: 14.tsp,
            fontWeight: FontWeight.w700,
            color: SharedDocumentsTheme.textPrimary,
          ),
        ),
        SizedBox(height: 10.th),
        if (activities.isEmpty)
          _buildEmptyState(
            icon: Icons.history_toggle_off_rounded,
            title: 'No recent activity',
            subtitle: 'Folder actions will appear here once available.',
          )
        else
          Column(
            children:
                activities.take(6).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final activity = entry.value;
              final message = _activityMessage(activity);
              final time = _activityTime(activity);
              final actorName = (activity['user_name'] ??
                      activity['employee_name'] ??
                      activity['name'] ??
                      'U')
                  .toString();
              final avatarUrl = _userAvatarUrlFrom(activity);

              return Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 4.tw, vertical: 10.th),
                decoration: BoxDecoration(
                  border: index == activities.take(6).length - 1
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: SharedDocumentsTheme.border,
                            width: 1.tw,
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16.tr,
                      backgroundColor: SharedDocumentsTheme.hubBackground,
                      backgroundImage:
                          avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? Text(
                              _userInitial(actorName),
                              style: GoogleFonts.poppins(
                                fontSize: 11.tsp,
                                fontWeight: FontWeight.w700,
                                color: SharedDocumentsTheme.textSecondary,
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 10.tw),
                    Expanded(
                      child: Text(
                        message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13.tsp,
                          fontWeight: FontWeight.w500,
                          color: SharedDocumentsTheme.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.tw),
                    Text(
                      time,
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        fontWeight: FontWeight.w500,
                        color: SharedDocumentsTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(growable: false),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedFolder == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selectedFolder != null) {
          _goBackToFolders();
        }
      },
      child: Builder(
        builder: (context) {
          if (_isLoadingFolders && _folders.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                color: SharedDocumentsTheme.accent,
              ),
            );
          }

          if (_error != null && _folders.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.tw),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: SharedDocumentsTheme.danger,
                        fontSize: 12.tsp,
                      ),
                    ),
                    SizedBox(height: 12.th),
                    OutlinedButton(
                      onPressed: _fetchSharedFolders,
                      style: SharedDocumentsTheme.softOutlinedButton(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_selectedFolder != null) {
            return _buildOpenedFolderView();
          }

          return Stack(
            children: [
              ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(top: 4.th, bottom: 12.th),
                children: [
                  Row(
                    children: [
                      Text(
                        'Folders (${_folders.length})',
                        style: GoogleFonts.poppins(
                          fontSize: 14.tsp,
                          fontWeight: FontWeight.w600,
                          color: SharedDocumentsTheme.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: _isCreatingFolder
                            ? null
                            : _showCreateFolderDialog,
                        style: SharedDocumentsTheme.softOutlinedButton(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14.tw,
                            vertical: 8.th,
                          ),
                        ),
                        child: _isCreatingFolder
                            ? SizedBox(
                                width: 14.tw,
                                height: 14.tw,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: SharedDocumentsTheme.accent,
                                ),
                              )
                            : Text(
                                'Create folder',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.tsp,
                                  color: SharedDocumentsTheme.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.th),
                  _buildFoldersList(),
                ],
              ),
              if (_isLoadingFolders && _folders.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.35),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: SharedDocumentsTheme.accent,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SharedFolderCard extends StatelessWidget {
  const _SharedFolderCard({
    required this.title,
    required this.users,
    required this.fileCount,
    required this.onTap,
  });

  final String title;
  final List<Map<String, dynamic>> users;
  final int fileCount;
  final VoidCallback onTap;

  String? _avatarFrom(Map<String, dynamic> user) {
    final candidates = [
      user['image_1920'],
      user['image_url'],
      user['avatar'],
      user['photo'],
    ];

    for (final value in candidates) {
      final url = value?.toString().trim() ?? '';
      if (url.isNotEmpty) return url;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final visibleUsers = users.take(3).toList(growable: false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.tr),
        child: Container(
          decoration: SharedDocumentsTheme.glassCard(radius: 16.tr),
          padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 12.th),
          child: Row(
            children: [
              Image.asset(
                'assets/newapp/shared_documents_folder.png',
                width: 44.tw,
                height: 44.tw,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/newapp/shared_folder_new_image.png',
                  width: 44.tw,
                  height: 44.tw,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(width: 12.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14.tsp,
                        fontWeight: FontWeight.w700,
                        color: SharedDocumentsTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.th),
                    Text(
                      fileCount == 1 ? '1 file' : '$fileCount files',
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        fontWeight: FontWeight.w500,
                        color: SharedDocumentsTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (visibleUsers.isNotEmpty) ...[
                SizedBox(width: 8.tw),
                SizedBox(
                  height: 28.th,
                  width: 28.tw + (visibleUsers.length - 1) * 16.tw,
                  child: Stack(
                    children: [
                      for (var i = 0; i < visibleUsers.length; i++)
                        Positioned(
                          left: i * 16.tw,
                          child: CircleAvatar(
                            radius: 13.tr,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 11.tr,
                              backgroundImage:
                                  _avatarFrom(visibleUsers[i]) != null
                                      ? NetworkImage(
                                          _avatarFrom(visibleUsers[i])!)
                                      : null,
                              backgroundColor:
                                  SharedDocumentsTheme.hubBackground,
                              child: _avatarFrom(visibleUsers[i]) == null
                                  ? Text(
                                      ((visibleUsers[i]['name'] ?? 'U')
                                              .toString()
                                              .trim()
                                              .isNotEmpty
                                          ? (visibleUsers[i]['name']
                                              .toString()
                                              .trim()
                                              .substring(0, 1)
                                              .toUpperCase())
                                          : 'U'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.tsp,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            SharedDocumentsTheme.textSecondary,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              SizedBox(width: 6.tw),
              Icon(
                Icons.chevron_right_rounded,
                color: SharedDocumentsTheme.accentMuted,
                size: 22.tsp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedAttachment {
  const _SharedAttachment({
    required this.id,
    required this.name,
    required this.fileUrl,
    required this.raw,
  });

  final int id;
  final String name;
  final String fileUrl;
  final Map<String, dynamic> raw;
}

class _CreateFolderAttachment {
  const _CreateFolderAttachment({
    required this.filename,
    required this.base64File,
  });

  final String filename;
  final String base64File;
}

class _CreateFolderDraft {
  const _CreateFolderDraft({
    required this.folderName,
    required this.attachments,
  });

  final String folderName;
  final List<_CreateFolderAttachment> attachments;
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 1.8;
    const dashCount = 26;
    const gapFactor = 0.48;
    const dashSweep = (2 * 3.141592653589793 / dashCount) * gapFactor;
    const step = 2 * 3.141592653589793 / dashCount;

    for (int i = 0; i < dashCount; i++) {
      final start = i * step;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashSweep,
        false,
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
