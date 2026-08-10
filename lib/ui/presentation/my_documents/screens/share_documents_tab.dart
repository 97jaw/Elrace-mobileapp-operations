import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_documents/theme/shared_documents_theme.dart';
import 'package:el_race/ui/presentation/my_documents/widgets/documents_list_tiles.dart';
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
    this.rootTitle = 'Shared Documents',
    this.onDrillChanged,
    this.onChromeTrailingChanged,
  });

  final Future<void> Function(Map<String, dynamic> document)? onOpenDocument;
  final String rootTitle;
  final DocumentsDrillChanged? onDrillChanged;
  final ValueChanged<Widget?>? onChromeTrailingChanged;

  @override
  State<ShareDocumentsTab> createState() => _ShareDocumentsTabState();
}

class _ShareDocumentsTabState extends State<ShareDocumentsTab> {
  bool _isLoadingFolders = false;
  bool _isLoadingFolderContents = false;
  bool _isCreatingFolder = false;
  bool _isAddingUser = false;
  bool _isRemovingUser = false;
  bool _isAddingAttachments = false;
  bool _isCreateDialogOpen = false;
  bool _isAddUserDialogOpen = false;
  String? _error;
  String? _folderOpenError;

  List<Map<String, dynamic>> _folders = <Map<String, dynamic>>[];

  /// Survives list-API refreshes that omit / zero `file_count`.
  final Map<String, int> _knownFileCounts = <String, int>{};

  Map<String, dynamic>? _selectedFolder;
  List<_SharedAttachment> _selectedFolderAttachments = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifyDrill();
      _notifyChromeTrailing();
    });
    _fetchSharedFolders();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _notifyDrill() {
    final folder = _selectedFolder;
    final title =
        folder == null ? widget.rootTitle : _folderNameForUi(folder);
    final exit = folder == null ? null : _goBackToFolders;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onDrillChanged?.call(title, exit);
    });
  }

  Widget _buildChromeAddButton({
    required VoidCallback? onTap,
    required bool busy,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: 4.tw),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(20.tr),
          child: Container(
            width: 36.tw,
            height: 36.tw,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SharedDocumentsTheme.accent.withValues(alpha: 0.12),
              border: Border.all(
                color: SharedDocumentsTheme.accent.withValues(alpha: 0.35),
              ),
            ),
            child: busy
                ? Padding(
                    padding: EdgeInsets.all(8.tw),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SharedDocumentsTheme.accent,
                    ),
                  )
                : Icon(
                    Icons.add_rounded,
                    color: SharedDocumentsTheme.accent,
                    size: 22.tsp,
                  ),
          ),
        ),
      ),
    );
  }

  void _notifyChromeTrailing() {
    final trailing = _selectedFolder == null
        ? _buildChromeAddButton(
            onTap: _showCreateFolderDialog,
            busy: _isCreatingFolder,
          )
        : _buildChromeAddButton(
            onTap: _addAttachmentsToOpenedFolder,
            busy: _isAddingAttachments || _isLoadingFolderContents,
          );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChromeTrailingChanged?.call(trailing);
    });
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

  /// Prefer the non-empty users list. Details API historically returned the
  /// wrong relation and could wipe members that the list API already had.
  List<Map<String, dynamic>> _resolveAllowedUsers({
    required List<Map<String, dynamic>> primary,
    required List<Map<String, dynamic>> fallback,
  }) {
    if (primary.isNotEmpty) return primary;
    return fallback;
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

      final previousById = <String, Map<String, dynamic>>{
        for (final f in _folders)
          _folderIdFrom(f).toString(): Map<String, dynamic>.from(f),
      };

      final folders = _toMapList(rawData)
          .map((folder) {
            final mapped = Map<String, dynamic>.from(folder);
            mapped['id'] = _folderIdFrom(folder);
            mapped['name'] = _folderNameFrom(folder);
            mapped['allowed_users'] = _toMapList(folder['allowed_users']);
            mapped['activities'] = _toMapList(folder['activities']);

            final idKey = mapped['id']?.toString() ?? '';
            final prev = previousById[idKey];
            final listCount = _folderFileCountFromPayload(mapped);
            final prevCount = prev == null ? 0 : _folderFileCountFromPayload(prev);
            final cached = _knownFileCounts[idKey] ?? 0;

            // Prefer any positive signal; never let a stale API zero wipe a
            // count we already learned from opening the folder.
            final best = [listCount, prevCount, cached]
                .fold<int>(0, (a, b) => a > b ? a : b);
            if (best > 0) {
              mapped['file_count'] = best;
              mapped['attachment_count'] = best;
              _rememberFileCount(idKey, best);
              if (_toMapList(mapped['attachments']).isEmpty &&
                  prev != null &&
                  _toMapList(prev['attachments']).isNotEmpty) {
                mapped['attachments'] = prev['attachments'];
              }
            }
            return mapped;
          })
          .where((folder) => folder['id'] != null)
          .toList();

      // Newest first (higher id = more recently created).
      folders.sort((a, b) {
        final aId = int.tryParse(_folderIdFrom(a).toString()) ?? 0;
        final bId = int.tryParse(_folderIdFrom(b).toString()) ?? 0;
        return bId.compareTo(aId);
      });

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
            final mergedUsers = _resolveAllowedUsers(
              primary: _toMapList(refreshed['allowed_users']),
              fallback: _toMapList(_selectedFolder?['allowed_users']),
            );
            _selectedFolder = {
              ...refreshed,
              'allowed_users': mergedUsers,
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

    final detailsUsers = _toMapList(envelope['allowed_users']);
    final payloadUsers = _toMapList(folderPayload['allowed_users']);
    final baseUsers = _toMapList(baseFolder['allowed_users']);
    final resolvedUsers = _resolveAllowedUsers(
      primary: detailsUsers.isNotEmpty ? detailsUsers : payloadUsers,
      fallback: baseUsers,
    );

    final detailsAttachments = _toMapList(envelope['attachments']);
    final payloadAttachments = _toMapList(
      folderPayload['attachments'] ??
          folderPayload['files'] ??
          folderPayload['documents'],
    );

    final detailedFolder = {
      ...baseFolder,
      ...folderPayload,
      'id':
          _folderIdFrom(folderPayload.isNotEmpty ? folderPayload : baseFolder),
      'name': _folderNameFrom(
          folderPayload.isNotEmpty ? folderPayload : baseFolder),
      'attachments': detailsAttachments.isNotEmpty
          ? detailsAttachments
          : payloadAttachments,
      'allowed_users': resolvedUsers,
      'activities': _toMapList(envelope['activities']),
    };

    final attachmentsLen =
        _toMapList(detailedFolder['attachments']).length;
    final totalHint = _readPositiveInt(
          envelope['total'] ??
              envelope['total_count'] ??
              envelope['attachment_count'] ??
              envelope['file_count'] ??
              folderPayload['file_count'] ??
              folderPayload['attachment_count'] ??
              folderPayload['total_files'] ??
              folderPayload['document_count'],
        ) ??
        attachmentsLen;
    if (totalHint > 0) {
      detailedFolder['file_count'] = totalHint;
      detailedFolder['attachment_count'] = totalHint;
    }

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
    _notifyDrill();
    _notifyChromeTrailing();

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
      final detailsCount = _folderFileCountFromPayload(detailedFolder);
      final count = detailsCount > extracted.length
          ? detailsCount
          : extracted.length;

      setState(() {
        _selectedFolder = {
          ...detailedFolder,
          'file_count': count,
          'attachment_count': count,
        };
        _selectedFolderAttachments = extracted;
        _folderOpenError = null;
      });

      final selectedIndex = _folders.indexWhere(
        (f) => _folderIdFrom(f).toString() == folderId.toString(),
      );
      if (selectedIndex >= 0) {
        final detailsUsers = _toMapList(detailedFolder['allowed_users']);
        final previousCount = _folderFileCount(_folders[selectedIndex]);
        final stableCount = count > previousCount ? count : previousCount;
        _rememberFileCount(folderId, stableCount);
        _folders[selectedIndex] = {
          ..._folders[selectedIndex],
          // Never overwrite list avatars with an empty details payload.
          if (detailsUsers.isNotEmpty) 'allowed_users': detailsUsers,
          'attachments': _toMapList(detailedFolder['attachments']),
          'file_count': stableCount,
          'attachment_count': stableCount,
        };
      } else {
        _rememberFileCount(folderId, count);
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
        _notifyChromeTrailing();
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
    _notifyDrill();
    _notifyChromeTrailing();
    // Do not refetch list on back — shared_folders often returns file_count=0
    // and was wiping counters learned while inside the folder. Member changes
    // already refresh via their own success paths.
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
    try {
      final draft = await showDialog<_CreateFolderDraft>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) {
          var nameLength = 0;

          return StatefulBuilder(
            builder: (context, setLocalState) {
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
                          'Name the folder, then add files inside it',
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

                              Navigator.pop(
                                ctx,
                                _CreateFolderDraft(folderName: value),
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

      if (draft == null || draft.folderName.trim().isEmpty) return;
      await _createFolder(draft.folderName.trim());
    } finally {
      nameController.dispose();
      _isCreateDialogOpen = false;
    }
  }

  Future<void> _createFolder(String folderName) async {
    if (!mounted) return;
    setState(() {
      _isCreatingFolder = true;
    });
    _notifyChromeTrailing();

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

      _showSnackMessage('Folder created successfully');
      await _fetchSharedFolders();

      // Always open the new folder so attachments can be added inside it.
      dynamic createdId;
      final data = envelope['data'];
      if (data is Map) {
        createdId = data['id'] ?? data['folder_id'];
      }
      createdId ??= envelope['id'];

      Map<String, dynamic>? match;
      if (createdId != null) {
        for (final f in _folders) {
          if (_folderIdFrom(f).toString() == createdId.toString()) {
            match = f;
            break;
          }
        }
      }
      if (match == null) {
        for (final f in _folders) {
          if (_folderNameFrom(f).toLowerCase() == folderName.toLowerCase()) {
            match = f;
            break;
          }
        }
      }
      // Fallback: open from create response even if list refresh lagged.
      match ??= createdId == null
          ? null
          : <String, dynamic>{
              'id': createdId,
              'name': folderName,
              'allowed_users': const <Map<String, dynamic>>[],
            };

      if (match != null && mounted) {
        await _openFolder(match);
      }
    } catch (e) {
      _showSnackMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingFolder = false;
        });
        _notifyChromeTrailing();
      }
    }
  }

  Future<List<_FolderUploadAttachment>> _pickFolderAttachments() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return const [];

    final picked = <_FolderUploadAttachment>[];
    for (final file in result.files) {
      final filename = file.name.trim();
      if (filename.isEmpty) continue;

      final existing = picked.any(
        (e) => e.filename.toLowerCase() == filename.toLowerCase(),
      );
      if (existing) continue;

      List<int>? bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) continue;

      picked.add(
        _FolderUploadAttachment(
          filename: filename,
          base64File: base64Encode(bytes),
        ),
      );
    }
    return picked;
  }

  Future<void> _addAttachmentsToOpenedFolder() async {
    final folder = _activeFolder;
    if (folder == null || _isAddingAttachments) return;

    final picked = await _pickFolderAttachments();
    if (picked.isEmpty) return;

    final folderId = _folderIdFrom(folder);
    if (folderId == null) return;

    if (!mounted) return;
    setState(() {
      _isAddingAttachments = true;
    });
    _notifyChromeTrailing();

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      final url =
          Uri.parse('https://erp.elrace.com/api/cloud/folder/add_attachment');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'folder_id': folderId,
          'attachments': picked
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
            'Failed to upload attachments (HTTP ${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);
      final envelope = _extractResultEnvelope(decoded);
      if (!_isSuccessEnvelope(envelope)) {
        throw Exception(
          envelope['message']?.toString() ??
              (decoded is Map ? decoded['error']?.toString() : null) ??
              'Failed to upload attachments',
        );
      }

      _showSnackMessage(
        picked.length == 1
            ? 'Attachment uploaded successfully'
            : '${picked.length} attachments uploaded successfully',
      );
      // Optimistic bump so folder tiles stay correct even if details are paged.
      final current = _folderFileCount(folder);
      _rememberFileCount(folderId, current + picked.length);
      final idx = _folders.indexWhere(
        (f) => _folderIdFrom(f).toString() == folderId.toString(),
      );
      if (idx >= 0) {
        final next = current + picked.length;
        _folders[idx] = {
          ..._folders[idx],
          'file_count': next,
          'attachment_count': next,
        };
      }
      await _openFolder(folder);
    } catch (e) {
      _showSnackMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isAddingAttachments = false;
        });
        _notifyChromeTrailing();
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
          .map(_employeeIdFromUser)
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
      // Re-open so Given access / Files stay in sync with details API.
      if (_selectedFolder != null) {
        await _openFolder(_selectedFolder!);
      }

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
      if (_selectedFolder != null) {
        await _openFolder(_selectedFolder!);
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

  int? _employeeIdFromUser(Map<String, dynamic> user) {
    final raw = user['employee_id'] ?? user['emp_id'];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  int? _userIdFromUser(Map<String, dynamic> user) {
    final raw = user['id'] ?? user['user_id'];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  Future<void> _confirmRemoveUser(Map<String, dynamic> user) async {
    if (_isRemovingUser || _isAddingUser) return;

    final name = _userNameFrom(user);
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.tr),
          ),
          title: Text(
            'Remove access',
            style: GoogleFonts.poppins(
              fontSize: 16.tsp,
              fontWeight: FontWeight.w700,
              color: SharedDocumentsTheme.textPrimary,
            ),
          ),
          content: Text(
            'Remove $name from this shared folder?',
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              color: SharedDocumentsTheme.textSecondary,
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: SharedDocumentsTheme.textMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Remove',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: SharedDocumentsTheme.danger,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    await _removeUserFromFolder(user);
  }

  Future<void> _removeUserFromFolder(Map<String, dynamic> user) async {
    final folder = _activeFolder;
    final folderId = folder == null ? null : _folderIdFrom(folder);
    if (folderId == null || !mounted) return;

    final employeeId = _employeeIdFromUser(user);
    final userId = _userIdFromUser(user);
    if (employeeId == null && userId == null) {
      _showSnackMessage('Could not identify this member');
      return;
    }

    setState(() {
      _isRemovingUser = true;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      final url =
          Uri.parse('https://erp.elrace.com/api/cloud/folder/remove_user');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final params = <String, dynamic>{
        'folder_id': folderId,
        if (employeeId != null) 'employee_id': employeeId,
        if (userId != null) 'user_id': userId,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'jsonrpc': '2.0',
          'params': params,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to remove user (HTTP ${response.statusCode})',
        );
      }

      final decoded = jsonDecode(response.body);
      final envelope = _extractResultEnvelope(decoded);
      if (!_isSuccessEnvelope(envelope)) {
        throw Exception(
          envelope['message']?.toString() ??
              (decoded is Map ? decoded['error']?.toString() : null) ??
              'Failed to remove user',
        );
      }

      _showSnackMessage('Access removed');
      await _fetchSharedFolders(focusFolderId: folderId);
      if (_selectedFolder != null) {
        await _openFolder(_selectedFolder!);
      }
    } catch (e) {
      _showSnackMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isRemovingUser = false;
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

  int? _readPositiveInt(dynamic raw) {
    if (raw == null) return null;
    final value = raw is int ? raw : int.tryParse(raw.toString());
    if (value == null || value <= 0) return null;
    return value;
  }

  void _rememberFileCount(dynamic folderId, int count) {
    if (folderId == null || count <= 0) return;
    final key = folderId.toString();
    final existing = _knownFileCounts[key] ?? 0;
    if (count >= existing) {
      _knownFileCounts[key] = count;
    }
  }

  /// Count from folder payload only (no cache) — used while merging list API.
  int _folderFileCountFromPayload(Map<String, dynamic> folder) {
    for (final key in const [
      'attachments',
      'files',
      'documents',
      'folder_attachments',
    ]) {
      final list = _toMapList(folder[key]);
      if (list.isNotEmpty) return list.length;
    }
    return _readPositiveInt(
          folder['file_count'] ??
              folder['attachment_count'] ??
              folder['files_count'] ??
              folder['total_files'] ??
              folder['document_count'],
        ) ??
        0;
  }

  int _folderFileCount(Map<String, dynamic> folder) {
    final idKey = _folderIdFrom(folder)?.toString();
    final cached = idKey == null ? 0 : (_knownFileCounts[idKey] ?? 0);
    final fromPayload = _folderFileCountFromPayload(folder);
    if (cached > fromPayload) return cached;
    if (fromPayload > 0 && idKey != null) {
      _rememberFileCount(idKey, fromPayload);
    }
    return fromPayload > cached ? fromPayload : cached;
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    IconData? icon,
    String? assetPath,
    String? actionLabel,
    VoidCallback? onAction,
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
          if (actionLabel != null) ...[
            SizedBox(height: 14.th),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: Icon(Icons.attach_file_rounded, size: 16.tsp),
              label: Text(actionLabel),
              style: SharedDocumentsTheme.softOutlinedButton(),
            ),
          ],
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
              return DocumentsFolderTile(
                title: _folderNameForUi(folder),
                fileCount: _folderFileCount(folder),
                trailingMeta: users.isEmpty
                    ? null
                    : '${users.length} member${users.length == 1 ? '' : 's'}',
                leading: Image.asset(
                  'assets/newapp/shared_documents_folder.png',
                  width: 48.tw,
                  height: 48.tw,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.folder_shared_rounded,
                    size: 36.tsp,
                    color: SharedDocumentsTheme.textPrimary,
                  ),
                ),
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
        DocumentsSectionHeader(
          title: 'Given access',
          subtitle: '${_currentAllowedUsers.length} people',
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(12.tw, 12.th, 12.tw, 8.th),
          decoration: documentsFrostedTileDecoration(),
          child: _buildGivenAccessAvatarsOnly(),
        ),
        SizedBox(height: 14.th),
        DocumentsSectionHeader(
          title: 'Files',
          subtitle: _isLoadingFolderContents
              ? 'Loading…'
              : '${_selectedFolderAttachments.length} file${_selectedFolderAttachments.length == 1 ? '' : 's'}',
        ),
        _buildFilesListSection(),
      ],
    );
  }

  Widget _buildGivenAccessAvatarsOnly() {
    final users = _currentAllowedUsers;

    return SizedBox(
      height: 78.th,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: users.length + 1,
        separatorBuilder: (_, __) => SizedBox(width: 10.tw),
        itemBuilder: (context, index) {
          if (index == 0) {
            return InkWell(
              onTap: (_isAddingUser || _isRemovingUser)
                  ? null
                  : _showAddUserDialog,
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

          return Tooltip(
            message: 'Tap to remove $name',
            child: InkWell(
              onTap: (_isRemovingUser || _isAddingUser)
                  ? null
                  : () => _confirmRemoveUser(user),
              borderRadius: BorderRadius.circular(28.tr),
              child: SizedBox(
                width: 56.tw,
                height: 62.th,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 4.th,
                      left: 2.tw,
                      child: CircleAvatar(
                        radius: 26.tr,
                        backgroundColor: SharedDocumentsTheme.border,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
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
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 20.tw,
                        height: 20.tw,
                        decoration: BoxDecoration(
                          color: SharedDocumentsTheme.danger,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 12.tsp,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilesListSection() {
    if (_isLoadingFolderContents) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40.th),
        child: const Center(
          child: CircularProgressIndicator(color: SharedDocumentsTheme.accent),
        ),
      );
    }

    if (_folderOpenError != null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 24.th),
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
      );
    }

    if (_selectedFolderAttachments.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: 8.th),
        child: _buildEmptyState(
          title: 'No files yet',
          subtitle: 'Tap + to upload attachments into this folder.',
          assetPath: 'assets/newapp/Share Document file.png',
          icon: Icons.insert_drive_file_outlined,
          actionLabel: _isAddingAttachments ? 'Uploading…' : 'Add attachment',
          onAction: _isAddingAttachments ? null : _addAttachmentsToOpenedFolder,
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _selectedFolderAttachments.length; i++) ...[
          if (i > 0) SizedBox(height: 10.th),
          DocumentsFileRow(
            fileName: _selectedFolderAttachments[i].name,
            onTap: () => _openAttachment(_selectedFolderAttachments[i]),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
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
                DocumentsSectionHeader(
                  title: 'Folders',
                  subtitle:
                      '${_folders.length} folder${_folders.length == 1 ? '' : 's'}',
                ),
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

class _FolderUploadAttachment {
  const _FolderUploadAttachment({
    required this.filename,
    required this.base64File,
  });

  final String filename;
  final String base64File;
}

class _CreateFolderDraft {
  const _CreateFolderDraft({
    required this.folderName,
  });

  final String folderName;
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
