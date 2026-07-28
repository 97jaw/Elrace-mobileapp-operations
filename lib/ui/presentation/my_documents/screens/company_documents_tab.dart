import 'dart:convert';

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_documents/widgets/documents_list_tiles.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class CompanyDocumentsTab extends StatefulWidget {
  const CompanyDocumentsTab({
    super.key,
    this.onAddDocument,
    this.onOpenDocument,
    this.rootTitle = 'Company Documents',
    this.onDrillChanged,
  });

  final VoidCallback? onAddDocument;
  final Future<void> Function(Map<String, dynamic> document)? onOpenDocument;
  final String rootTitle;
  final DocumentsDrillChanged? onDrillChanged;

  @override
  State<CompanyDocumentsTab> createState() => _CompanyDocumentsTabState();
}

class _CompanyDocumentsTabState extends State<CompanyDocumentsTab> {
  bool _isLoading = false;
  bool _isLoadingFolderContents = false;
  String? _error;
  String? _folderOpenError;

  List<_CompanyFolder> _folders = const [];
  _CompanyFolder? _selectedFolder;
  List<_CompanyAttachment> _selectedFolderAttachments = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifyDrill();
    });
    _fetchCompanyFolders();
  }

  @override
  void dispose() {
    // Avoid parent setState during deactivate/dispose.
    super.dispose();
  }

  void _notifyDrill() {
    final folder = _selectedFolder;
    final title = folder?.name ?? widget.rootTitle;
    final exit = folder == null ? null : _goBackToFolders;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onDrillChanged?.call(title, exit);
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

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  Future<dynamic> _sendJsonRpcGet(
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

  Future<void> _fetchCompanyFolders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _folderOpenError = null;
      _selectedFolder = null;
      _selectedFolderAttachments = const [];
    });
    _notifyDrill();

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      final url = Uri.parse('https://erp.elrace.com/api/company/folders');
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
            'Failed to load company folders (HTTP ${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);
      final envelope = _extractResultEnvelope(decoded);
      if (!_isSuccessEnvelope(envelope)) {
        throw Exception(
          envelope['message']?.toString() ??
              (decoded is Map ? decoded['error']?.toString() : null) ??
              'Failed to load company folders',
        );
      }

      final rawData = envelope['data'] ??
          (decoded is Map && decoded['data'] is List ? decoded['data'] : null);
      if (rawData is! List) {
        throw Exception('Invalid folders response format');
      }

      final mapped = rawData
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(
            (m) => _CompanyFolder(
              id: _toInt(m['id']),
              name: (m['name'] ?? 'Folder').toString(),
              totalFiles: _toInt(m['total_files']),
            ),
          )
          .where((f) => f.id > 0)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _folders = mapped;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openFolder(_CompanyFolder folder) async {
    if (!mounted) return;
    setState(() {
      _isLoadingFolderContents = true;
      _folderOpenError = null;
      _error = null;
      _selectedFolder = folder;
      _selectedFolderAttachments = const [];
    });
    _notifyDrill();

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      final url =
          Uri.parse('https://erp.elrace.com/api/company/folder/contents');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response =
          await _sendJsonRpcGet(url, headers, {'unit_id': folder.id});

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load folder contents (HTTP ${response.statusCode})');
      }

      final decoded = jsonDecode(response.body);
      final envelope = _extractResultEnvelope(decoded);
      if (!_isSuccessEnvelope(envelope)) {
        throw Exception(
          envelope['message']?.toString() ??
              (decoded is Map ? decoded['error']?.toString() : null) ??
              'Failed to load folder contents',
        );
      }

      final data = envelope['data'];
      if (data is! Map) {
        throw Exception('Invalid folder contents response format');
      }

      final rawAttachments = data['attachments'];
      final attachments = (rawAttachments is List)
          ? rawAttachments
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .map(
                (m) => _CompanyAttachment(
                  id: _toInt(m['id']),
                  name: (m['name'] ?? 'File').toString(),
                  mimetype: (m['mimetype'] ?? '').toString(),
                  createdAt: (m['create_date'] ?? '').toString(),
                  fileUrl: (m['file_url'] ?? '').toString(),
                  raw: m,
                ),
              )
              .where((a) => a.id > 0)
              .toList(growable: false)
          : const <_CompanyAttachment>[];

      if (!mounted) return;
      setState(() {
        _selectedFolderAttachments = attachments;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _folderOpenError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFolderContents = false;
        });
      }
    }
  }

  int get _totalFilesAcrossFolders {
    var total = 0;
    for (final folder in _folders) {
      total += folder.totalFiles;
    }
    return total;
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
  }

  Future<void> _openAttachment(_CompanyAttachment attachment) async {
    final callback = widget.onOpenDocument;
    if (callback == null) return;

    final map = Map<String, dynamic>.from(attachment.raw)
      ..['name'] = attachment.name
      ..['title'] = attachment.name
      ..['attachment_ids'] = [
        {
          'attachment_id': attachment.id,
        }
      ];

    await callback(map);
  }

  Widget _buildFoldersList() {
    if (_folders.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40.th),
        child: Column(
          children: [
            Icon(
              Icons.folder_off_rounded,
              size: 46.tsp,
              color: const Color(0xFF98A0AE),
            ),
            SizedBox(height: 10.th),
            Text(
              'No company folders',
              style: GoogleFonts.poppins(
                fontSize: 14.tsp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3B4352),
              ),
            ),
            SizedBox(height: 6.th),
            Text(
              'Folders will appear here once available.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.tsp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF7B8290),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _folders.length; i++) ...[
          if (i > 0) SizedBox(height: 10.th),
          DocumentsFolderTile(
            title: _folders[i].name,
            fileCount: _folders[i].totalFiles,
            onTap: () {
              if (_isLoadingFolderContents) return;
              _openFolder(_folders[i]);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildFolderContents() {
    if (_isLoadingFolderContents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_folderOpenError != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.tw),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 44.tsp,
                color: const Color(0xFFBA1719),
              ),
              SizedBox(height: 12.th),
              Text(
                'Couldn’t load folder files',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14.tsp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3B4352),
                ),
              ),
              SizedBox(height: 6.th),
              Text(
                _folderOpenError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF7B8290),
                  fontSize: 12.tsp,
                ),
              ),
              SizedBox(height: 14.th),
              OutlinedButton(
                onPressed: _selectedFolder == null
                    ? null
                    : () => _openFolder(_selectedFolder!),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedFolderAttachments.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.tw),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 42.tsp,
                color: const Color(0xFF98A0AE),
              ),
              SizedBox(height: 10.th),
              Text(
                'No files in this folder',
                style: GoogleFonts.poppins(
                  fontSize: 14.tsp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3B4352),
                ),
              ),
              SizedBox(height: 6.th),
              Text(
                'Files added to this operating unit will show up here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12.tsp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF7B8290),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(top: 4.th, bottom: 12.th),
      itemCount: _selectedFolderAttachments.length + 1,
      separatorBuilder: (_, __) => SizedBox(height: 10.th),
      itemBuilder: (context, index) {
        if (index == 0) {
          return DocumentsSectionHeader(
            title: 'Files',
            subtitle:
                '${_selectedFolderAttachments.length} file${_selectedFolderAttachments.length == 1 ? '' : 's'}',
          );
        }
        final item = _selectedFolderAttachments[index - 1];
        return DocumentsFileRow(
          fileName: item.name,
          updatedLabel: item.createdAt.isEmpty ? null : item.createdAt,
          onTap: () => _openAttachment(item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _folders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _folders.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.tw),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 44.tsp,
                color: const Color(0xFFBA1719),
              ),
              SizedBox(height: 12.th),
              Text(
                'Couldn’t load company documents',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14.tsp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3B4352),
                ),
              ),
              SizedBox(height: 6.th),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF7B8290),
                  fontSize: 12.tsp,
                ),
              ),
              SizedBox(height: 14.th),
              OutlinedButton(
                onPressed: _fetchCompanyFolders,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedFolder != null) {
      return _buildFolderContents();
    }

    return Stack(
      children: [
        ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(top: 4.th, bottom: 12.th),
          children: [
            DocumentsSectionHeader(
              title: 'Folders',
              subtitle: _folders.isEmpty
                  ? 'No folders available'
                  : '${_folders.length} folder${_folders.length == 1 ? '' : 's'} · $_totalFilesAcrossFolders files',
              trailing: IconButton(
                onPressed: _isLoading ? null : _fetchCompanyFolders,
                icon: _isLoading
                    ? SizedBox(
                        width: 18.tw,
                        height: 18.tw,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                color: const Color(0xFF27304E),
                tooltip: 'Refresh',
              ),
            ),
            _buildFoldersList(),
          ],
        ),
        if (_isLoadingFolderContents)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.08),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }
}

class _CompanyFolder {
  const _CompanyFolder({
    required this.id,
    required this.name,
    required this.totalFiles,
  });

  final int id;
  final String name;
  final int totalFiles;
}

class _CompanyAttachment {
  const _CompanyAttachment({
    required this.id,
    required this.name,
    required this.mimetype,
    required this.createdAt,
    required this.fileUrl,
    required this.raw,
  });

  final int id;
  final String name;
  final String mimetype;
  final String createdAt;
  final String fileUrl;
  final Map<String, dynamic> raw;
}
