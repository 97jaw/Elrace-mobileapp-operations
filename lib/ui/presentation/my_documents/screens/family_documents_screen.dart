import 'dart:async';
import 'dart:convert';

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_documents/screens/document_details_screen.dart';
import 'package:el_race/ui/presentation/my_documents/screens/family_add_document_screen.dart';
import 'package:el_race/ui/presentation/my_documents/utils/document_display.dart';
import 'package:el_race/ui/presentation/my_documents/widgets/my_documents_silk_background.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_glass_header.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

const Color _greenAccent = Color(0xFF1F7A4D);
const Color _navy = Color(0xFF1E2365);

/// Dedicated Family documents hub (separate from My Documents personal flow).
class FamilyDocumentsScreen extends StatefulWidget {
  const FamilyDocumentsScreen({super.key});

  @override
  State<FamilyDocumentsScreen> createState() => _FamilyDocumentsScreenState();
}

class _FamilyDocumentsScreenState extends State<FamilyDocumentsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _documents = const [];
  String _selectedMemberKey = 'spouse';

  @override
  void initState() {
    super.initState();
    unawaited(_fetchFamilyDocuments());
  }

  static String normalizeMemberKey(dynamic raw) {
    final v = (raw ?? '').toString().trim().toLowerCase();
    if (v.isEmpty) return '';
    switch (v) {
      case 'spouse':
      case 'wife':
        return 'spouse';
      case 'child':
      case 'child_1':
      case 'children':
        return 'child_1';
      case 'child_2':
        return 'child_2';
      case 'child_3':
        return 'child_3';
      default:
        return v;
    }
  }

  static String memberDisplayLabel(String key, {String? name}) {
    final n = (name ?? '').trim();
    switch (key) {
      case 'spouse':
        return n.isEmpty ? 'Spouse' : n;
      case 'child_1':
        return n.isEmpty ? 'Child' : n;
      case 'child_2':
        return n.isEmpty ? 'Child 2' : n;
      case 'child_3':
        return n.isEmpty ? 'Child 3' : n;
      default:
        return n.isEmpty ? 'Family' : n;
    }
  }

  static String memberRelationLabel(String key) {
    switch (key) {
      case 'spouse':
        return 'Spouse';
      case 'child_1':
      case 'child_2':
      case 'child_3':
        return 'Child';
      default:
        return 'Family';
    }
  }

  List<_FamilyMemberSlot> get _memberSlots {
    // Only members that already have at least one document.
    final byKey = <String, _FamilyMemberSlot>{};

    for (final doc in _documents) {
      var key = normalizeMemberKey(
        doc['family_member'] ?? doc['_familyMemberKey'],
      );
      if (key.isEmpty) key = 'spouse'; // untagged family docs → Spouse bucket

      final name = (doc['family_member_name'] ??
              doc['person_name'] ??
              doc['family_member_label'] ??
              '')
          .toString()
          .trim();
      final photo = _pickPhotoUrl(doc);

      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = _FamilyMemberSlot(
          key: key,
          name: name.isEmpty ? null : name,
          relation: memberRelationLabel(key),
          photoUrl: photo,
        );
      } else {
        byKey[key] = _FamilyMemberSlot(
          key: key,
          name: (existing.name != null && existing.name!.isNotEmpty)
              ? existing.name
              : (name.isEmpty ? null : name),
          relation: existing.relation,
          photoUrl: (existing.photoUrl != null && existing.photoUrl!.isNotEmpty)
              ? existing.photoUrl
              : photo,
        );
      }
    }

    const order = ['spouse', 'child_1', 'child_2', 'child_3'];
    final slots = <_FamilyMemberSlot>[];
    for (final key in order) {
      final slot = byKey.remove(key);
      if (slot != null) slots.add(slot);
    }
    slots.addAll(byKey.values);
    return slots;
  }

  static String? _pickPhotoUrl(Map<String, dynamic> doc) {
    for (final key in [
      'photo_url',
      'image_url',
      'avatar',
      'photo',
      'member_photo',
      'family_member_photo',
    ]) {
      final v = doc[key];
      if (v == null || v == false) continue;
      final s = v.toString().trim();
      if (s.isEmpty || s.toLowerCase() == 'false' || s.toLowerCase() == 'null') {
        continue;
      }
      if (s.startsWith('http') || s.startsWith('data:')) return s;
    }
    return null;
  }

  List<Map<String, dynamic>> get _filteredDocs {
    if (_memberSlots.isEmpty) return const [];
    final selected = normalizeMemberKey(_selectedMemberKey);
    return _documents
        .where((d) {
          var key = normalizeMemberKey(
            d['family_member'] ?? d['_familyMemberKey'],
          );
          if (key.isEmpty) key = 'spouse';
          return key == selected;
        })
        .toList(growable: false);
  }

  bool get _hasAnyDocuments => _documents.isNotEmpty;

  _FamilyMemberSlot? get _selectedSlot {
    final slots = _memberSlots;
    if (slots.isEmpty) return null;
    return slots.firstWhere(
      (s) => s.key == _selectedMemberKey,
      orElse: () => slots.first,
    );
  }

  Future<void> _fetchFamilyDocuments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = SharedPref.getLoginData().result?.token ?? '';
      if (token.isEmpty) {
        setState(() {
          _error = 'Session expired. Please login again.';
          _loading = false;
        });
        return;
      }

      final response = await http.post(
        Uri.parse('${UrlUtil.baseUrl}get_employee_documents'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jsonrpc': '2.0',
          'params': {'family_only': true},
        }),
      );

      if (response.statusCode != 200) {
        setState(() {
          _error = 'Failed to load family documents';
          _loading = false;
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        setState(() {
          _error = 'Invalid response';
          _loading = false;
        });
        return;
      }

      final result = (decoded['result'] is Map)
          ? Map<String, dynamic>.from(decoded['result'] as Map)
          : (decoded['status'] != null)
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
      final status = (result['status'] ?? '').toString().trim().toLowerCase();
      if (!(status == 'success' || status == 'ok' || status == 'true')) {
        setState(() {
          _error = (result['message'] ?? 'Failed to load family documents')
              .toString();
          _loading = false;
        });
        return;
      }

      final mapped = _mapDocuments(result['data']);
      if (!mounted) return;
      setState(() {
        _documents = mapped;
        _loading = false;
        _error = null;
        final slots = _memberSlots;
        if (slots.isEmpty) {
          _selectedMemberKey = 'spouse';
        } else if (!slots.any((s) => s.key == _selectedMemberKey)) {
          _selectedMemberKey = slots.first.key;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _mapDocuments(dynamic data) {
    final out = <Map<String, dynamic>>[];

    void addDoc(Map<String, dynamic> map, {String? groupType}) {
      final type = (map['document_type'] ??
              map['type'] ??
              groupType ??
              map['title'] ??
              'Document')
          .toString();
      final memberKey = normalizeMemberKey(map['family_member']);
      final expiry = DocumentDisplay.pickExpiryRaw(map);
      out.add({
        ...map,
        'title': type.toUpperCase(),
        'document_type': type,
        'expiry_date': expiry ?? map['expiry_date'],
        'date_expiry': expiry ?? map['date_expiry'],
        'family_member': memberKey.isEmpty ? map['family_member'] : memberKey,
        '_familyMemberKey': memberKey,
        '_isFamily': true,
        'icon': _iconForType(type),
      });
    }

    if (data is! List) return out;
    for (final raw in data) {
      if (raw is! Map) continue;
      final group = Map<String, dynamic>.from(raw);
      final groupType =
          (group['document_type'] ?? group['type'] ?? '').toString();
      final docs = group['documents'];
      if (docs is List && docs.isNotEmpty) {
        for (final d in docs) {
          if (d is Map) {
            addDoc(Map<String, dynamic>.from(d), groupType: groupType);
          }
        }
      } else {
        addDoc(group, groupType: groupType);
      }
    }
    return out;
  }

  String _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('passport')) return 'assets/png/passport.png';
    if (t.contains('emirates') || t.contains('eid')) {
      return 'assets/png/emitates_id.png';
    }
    if (t.contains('labor') || t.contains('labour')) {
      return 'assets/png/labor-cards-icon.png';
    }
    if (t.contains('insurance') || t.contains('medical')) {
      return 'assets/png/personal-icon.png';
    }
    if (t.contains('contract')) return 'assets/png/contract-icon.png';
    if (t.contains('certificate') || t.contains('cert')) {
      return 'assets/png/certificate-icon.png';
    }
    return 'assets/png/other-documetns-icon.png';
  }

  Future<void> _openAddFlow() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FamilyAddDocumentScreen(
          initialMemberKey: _selectedMemberKey,
        ),
      ),
    );
    if (!mounted) return;
    if (added == true) {
      await _fetchFamilyDocuments();
    }
  }

  void _openDetails(Map<String, dynamic> document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentDetailsScreen(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedSlot;
    final selectedLabel = selected == null
        ? 'Family'
        : memberDisplayLabel(selected.key, name: selected.name);

    return MyDocumentsSilkBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            ProductivityGlassHeader(
              title: 'Family',
              showBack: true,
              transparentGlassBar: true,
              scrimTopOpacity: 0.08,
              trailing: [
                if (_hasAnyDocuments && !_loading)
                  Material(
                    color: _greenAccent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _openAddFlow,
                      child: SizedBox(
                        width: 36.tw,
                        height: 36.tw,
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 22.tsp,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                color: _greenAccent,
                onRefresh: _fetchFamilyDocuments,
                child: _buildBody(selectedLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String selectedLabel) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 120.th),
          const Center(child: CircularProgressIndicator(color: _greenAccent)),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(24.tw),
        children: [
          SizedBox(height: 80.th),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: const Color(0xFFC62828)),
          ),
          SizedBox(height: 12.th),
          Center(
            child: TextButton(
              onPressed: _fetchFamilyDocuments,
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: _greenAccent,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!_hasAnyDocuments) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.tw, 40.th, 16.tw, 28.th),
        children: [
          Icon(
            Icons.family_restroom_rounded,
            size: 48.tsp,
            color: const Color(0xFF9AA3AF),
          ),
          SizedBox(height: 14.th),
          Text(
            'No family documents yet',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16.tsp,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          SizedBox(height: 6.th),
          Text(
            'Add a spouse or child document to get started.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              color: const Color(0xFF7B8290),
            ),
          ),
          SizedBox(height: 16.th),
          Center(
            child: TextButton.icon(
              onPressed: _openAddFlow,
              icon: const Icon(Icons.add_rounded, color: _greenAccent),
              label: Text(
                'Add a new document',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: _greenAccent,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final docs = _filteredDocs;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.tw, 8.th, 16.tw, 28.th),
      children: [
        _buildMemberRow(),
        SizedBox(height: 18.th),
        Text(
          'Family Documents',
          style: GoogleFonts.poppins(
            fontSize: 18.tsp,
            fontWeight: FontWeight.w700,
            color: _navy,
          ),
        ),
        SizedBox(height: 4.th),
        Text(
          selectedLabel,
          style: GoogleFonts.poppins(
            fontSize: 12.tsp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF7B8290),
          ),
        ),
        SizedBox(height: 12.th),
        if (docs.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 36.th),
            child: Column(
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 42.tsp,
                  color: const Color(0xFF9AA3AF),
                ),
                SizedBox(height: 10.th),
                Text(
                  'No documents for $selectedLabel yet',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    color: const Color(0xFF7B8290),
                  ),
                ),
                SizedBox(height: 8.th),
                TextButton.icon(
                  onPressed: _openAddFlow,
                  icon: const Icon(Icons.add_rounded, color: _greenAccent),
                  label: Text(
                    'Add a new document',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: _greenAccent,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...docs.map((doc) {
            return Padding(
              padding: EdgeInsets.only(bottom: 8.th),
              child: _FamilyDocumentRow(
                document: doc,
                onTap: () => _openDetails(doc),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildMemberRow() {
    final slots = _memberSlots;
    return SizedBox(
      height: 96.th,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: slots.length,
        separatorBuilder: (_, __) => SizedBox(width: 14.tw),
        itemBuilder: (context, index) {
          final slot = slots[index];
          final selected = slot.key == _selectedMemberKey;
          final label = memberDisplayLabel(slot.key, name: slot.name);
          return InkWell(
            onTap: () => setState(() => _selectedMemberKey = slot.key),
            borderRadius: BorderRadius.circular(16.tr),
            child: SizedBox(
              width: 76.tw,
              child: Column(
                children: [
                  Container(
                    width: 58.tw,
                    height: 58.tw,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE8F0F8),
                      border: Border.all(
                        color: selected ? _greenAccent : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: _greenAccent.withValues(alpha: 0.22),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _MemberAvatar(
                      photoUrl: slot.photoUrl,
                      isSpouse: slot.key == 'spouse',
                      selected: selected,
                      initials: label,
                    ),
                  ),
                  SizedBox(height: 6.th),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11.tsp,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  Text(
                    slot.relation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 9.tsp,
                      color: const Color(0xFF7B8290),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.photoUrl,
    required this.isSpouse,
    required this.selected,
    required this.initials,
  });

  final String? photoUrl;
  final bool isSpouse;
  final bool selected;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final url = (photoUrl ?? '').trim();
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final letter = initials.trim().isNotEmpty
        ? initials.trim()[0].toUpperCase()
        : (isSpouse ? 'S' : 'C');
    return Container(
      color: const Color(0xFFE8F0F8),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: selected ? _greenAccent : const Color(0xFF7B8290),
        ),
      ),
    );
  }
}

class _FamilyMemberSlot {
  const _FamilyMemberSlot({
    required this.key,
    required this.relation,
    this.name,
    this.photoUrl,
  });

  final String key;
  final String relation;
  final String? name;
  final String? photoUrl;
}

class _FamilyDocumentRow extends StatelessWidget {
  const _FamilyDocumentRow({
    required this.document,
    required this.onTap,
  });

  final Map<String, dynamic> document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = DocumentDisplay.typeLabel(document);
    final expiry = DocumentDisplay.formatDate(
      DocumentDisplay.pickExpiryRaw(document),
    );
    final status = DocumentDisplay.status(document);
    final statusStyle = _statusStyle(status);
    final iconPath =
        (document['icon'] ?? 'assets/png/other-documetns-icon.png').toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.tr),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 12.th),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(16.tr),
            border: Border.all(color: const Color(0xFFE4E7EC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44.tw,
                height: 44.tw,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6FA),
                  borderRadius: BorderRadius.circular(12.tr),
                ),
                padding: EdgeInsets.all(6.tw),
                child: Image.asset(
                  iconPath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.description_outlined,
                    color: _navy,
                    size: 22.tsp,
                  ),
                ),
              ),
              SizedBox(width: 10.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13.tsp,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                    SizedBox(height: 3.th),
                    Text(
                      expiry == '-' ? 'Expiry N/A' : expiry,
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        color: const Color(0xFF7B8290),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 4.th),
                decoration: BoxDecoration(
                  color: statusStyle.fill,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusStyle.label,
                  style: GoogleFonts.poppins(
                    fontSize: 10.tsp,
                    fontWeight: FontWeight.w600,
                    color: statusStyle.accent,
                  ),
                ),
              ),
              SizedBox(width: 4.tw),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFF9AA3AF),
                size: 20.tsp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static ({String label, Color fill, Color accent}) _statusStyle(
    DocumentStatus status,
  ) {
    switch (status) {
      case DocumentStatus.expired:
        return (
          label: 'Expired',
          fill: const Color(0xFFFFE8E8),
          accent: const Color(0xFFC62828),
        );
      case DocumentStatus.expiring:
        return (
          label: 'Expiring Soon',
          fill: const Color(0xFFFFF1E0),
          accent: const Color(0xFFC47A12),
        );
      case DocumentStatus.valid:
        return (
          label: 'Valid',
          fill: const Color(0xFFE6F6EC),
          accent: _greenAccent,
        );
      case DocumentStatus.unknown:
        return (
          label: 'N/A',
          fill: const Color(0xFFF0F2F5),
          accent: const Color(0xFF6B7280),
        );
    }
  }
}
