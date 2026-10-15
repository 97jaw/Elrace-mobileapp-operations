import 'dart:async';

import 'package:el_race/core/hr_management/network/hr_api_client.dart';
import 'package:el_race/ui/presentation/hr_management/widgets/hr_request_form_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Employee chosen in the on-behalf employee picker.
class HrPickedEmployee {
  const HrPickedEmployee({
    required this.id,
    required this.name,
    this.empId = '',
    this.job = '',
    this.department = '',
    this.photo = '',
  });

  final int id;
  final String name;
  final String empId;
  final String job;
  final String department;
  final String photo;

  String get subtitle =>
      [empId, job, department].where((s) => s.trim().isNotEmpty).join(' · ');

  static HrPickedEmployee? fromJson(Map<String, dynamic> json) {
    final id = json['id'] is int
        ? json['id'] as int
        : int.tryParse('${json['id'] ?? ''}');
    if (id == null || id <= 0) return null;
    String s(String key) {
      final v = json[key];
      return v == null || v == false ? '' : '$v';
    }

    return HrPickedEmployee(
      id: id,
      name: s('name'),
      empId: s('emp_id'),
      job: s('job'),
      department: s('department'),
      photo: s('photo'),
    );
  }

  Map<String, dynamic> toDraft() => {'id': id, 'name': name};

  static HrPickedEmployee? fromDraft(Object? raw) {
    if (raw is! Map) return null;
    return fromJson(Map<String, dynamic>.from(raw));
  }
}

/// Form field that opens [showHrRequestEmployeeSheet].
class HrRequestEmployeeField extends StatelessWidget {
  const HrRequestEmployeeField({
    super.key,
    required this.api,
    required this.code,
    required this.value,
    required this.onChanged,
  });

  final HrApiClient api;
  final String code;
  final HrPickedEmployee? value;
  final ValueChanged<HrPickedEmployee> onChanged;

  @override
  Widget build(BuildContext context) {
    final picked = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HrRequestFormUi.label('Employee *'),
        InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () async {
            final result = await showHrRequestEmployeeSheet(
              context,
              api: api,
              code: code,
            );
            if (result != null) onChanged(result);
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: picked == null
                      ? Text(
                          'Select employee',
                          style: HrRequestFormUi.valueStyle()
                              .copyWith(color: Colors.grey),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              picked.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: HrRequestFormUi.valueStyle(),
                            ),
                            if (picked.subtitle.isNotEmpty)
                              Text(
                                picked.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.sp,
                                  color: HrRequestFormUi.accentGrey,
                                ),
                              ),
                          ],
                        ),
                ),
                Icon(Icons.person_search_outlined,
                    size: 20.w, color: HrRequestFormUi.accentGrey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Draggable sheet with search and paged employee list.
Future<HrPickedEmployee?> showHrRequestEmployeeSheet(
  BuildContext context, {
  required HrApiClient api,
  required String code,
}) {
  return showModalBottomSheet<HrPickedEmployee>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => _EmployeeSheet(
        api: api,
        code: code,
        scrollController: scrollController,
      ),
    ),
  );
}

class _EmployeeSheet extends StatefulWidget {
  const _EmployeeSheet({
    required this.api,
    required this.code,
    required this.scrollController,
  });

  final HrApiClient api;
  final String code;
  final ScrollController scrollController;

  @override
  State<_EmployeeSheet> createState() => _EmployeeSheetState();
}

class _EmployeeSheetState extends State<_EmployeeSheet> {
  static const _pageSize = 20;

  final _search = TextEditingController();
  Timer? _debounce;
  final List<HrPickedEmployee> _items = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.scrollController.removeListener(_onScroll);
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    final c = widget.scrollController;
    if (!c.hasClients) return;
    if (c.position.pixels >= c.position.maxScrollExtent - 200) {
      _load();
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(reset: true),
    );
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_hasMore)) return;
    final seq = ++_requestSeq;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _hasMore = true;
      }
    });
    try {
      final env = await widget.api.fetchRequestEmployees(
        code: widget.code,
        search: _search.text.trim(),
        page: page,
        limit: _pageSize,
      );
      if (!mounted || seq != _requestSeq) return;
      if (!env.success) {
        setState(() {
          _loading = false;
          _error = env.error ?? 'Could not load employees';
        });
        return;
      }
      final raw = env.data?['employees'];
      final rows = raw is List
          ? raw
              .whereType<Map>()
              .map((e) =>
                  HrPickedEmployee.fromJson(Map<String, dynamic>.from(e)))
              .whereType<HrPickedEmployee>()
              .toList()
          : <HrPickedEmployee>[];
      setState(() {
        _items.addAll(rows);
        _page = page;
        _hasMore = env.data?['has_more'] == true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _loading = false;
        _error = 'Could not load employees';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      ),
      child: Column(
        children: [
          SizedBox(height: 10.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
            child: Text(
              'Select employee',
              style: HrRequestFormUi.titleStyle(),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: HrRequestFormUi.fieldDecoration(
                'Search by name or employee ID',
              ).copyWith(
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  Widget _list() {
    if (_items.isEmpty) {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        controller: widget.scrollController,
        children: [
          SizedBox(height: 40.h),
          Center(
            child: Text(
              _error ?? 'No employees found',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: HrRequestFormUi.accentGrey,
              ),
            ),
          ),
          if (_error != null)
            Center(
              child: TextButton(
                onPressed: () => _load(reset: true),
                child: const Text('Retry'),
              ),
            ),
        ],
      );
    }
    return ListView.separated(
      controller: widget.scrollController,
      padding: EdgeInsets.only(bottom: 16.h),
      itemCount: _items.length + (_hasMore || _error != null ? 1 : 0),
      separatorBuilder: (_, __) =>
          Divider(height: 1, indent: 72.w, color: Colors.grey[200]),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          if (_error != null) {
            return Center(
              child: TextButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            );
          }
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final emp = _items[index];
        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
          leading: CircleAvatar(
            radius: 22.r,
            backgroundColor: Colors.grey[200],
            foregroundImage: emp.photo.isEmpty ? null : NetworkImage(emp.photo),
            onForegroundImageError: emp.photo.isEmpty ? null : (_, __) {},
            child: Text(
              emp.name.isEmpty ? '?' : emp.name[0].toUpperCase(),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: HrRequestFormUi.primary,
              ),
            ),
          ),
          title: Text(
            emp.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HrRequestFormUi.valueStyle(),
          ),
          subtitle: emp.subtitle.isEmpty
              ? null
              : Text(
                  emp.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    color: HrRequestFormUi.accentGrey,
                  ),
                ),
          onTap: () => Navigator.of(context).pop(emp),
        );
      },
    );
  }
}
