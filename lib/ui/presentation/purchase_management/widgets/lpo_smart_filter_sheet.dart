import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_filter_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

enum _QuickDatePreset { today, week, month, custom }

class LpoSmartFilterSheet {
  LpoSmartFilterSheet._();

  static Future<PurchaseListFilters?> show({
    required BuildContext context,
    required PurchaseListFilters initial,
    required PurchaseRepository repository,
    PurchaseDevTestRole? testRole,
  }) {
    return showModalBottomSheet<PurchaseListFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LpoSmartFilterBody(
        initial: initial,
        repository: repository,
        testRole: testRole,
      ),
    );
  }
}

class _LpoSmartFilterBody extends StatefulWidget {
  const _LpoSmartFilterBody({
    required this.initial,
    required this.repository,
    this.testRole,
  });

  final PurchaseListFilters initial;
  final PurchaseRepository repository;
  final PurchaseDevTestRole? testRole;

  @override
  State<_LpoSmartFilterBody> createState() => _LpoSmartFilterBodyState();
}

class _LpoSmartFilterBodyState extends State<_LpoSmartFilterBody> {
  late final TextEditingController _referenceCtrl;
  late final TextEditingController _originCtrl;

  _QuickDatePreset? _preset;
  DateTime? _from;
  DateTime? _to;

  List<int> _vendorIds = [];
  List<int> _materialTypeIds = [];
  List<int> _cityIds = [];
  List<int> _projectManagerIds = [];
  List<int> _years = [];

  final Map<int, String> _labelCache = {};

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _referenceCtrl = TextEditingController(text: f.reference);
    _originCtrl = TextEditingController(text: f.origin);
    _vendorIds = List<int>.from(f.vendorIds);
    _materialTypeIds = List<int>.from(f.materialTypeIds);
    _cityIds = List<int>.from(f.cityIds);
    _projectManagerIds = List<int>.from(f.projectManagerIds);
    _years = List<int>.from(f.years);
    if (f.dateFrom.isNotEmpty) _from = DateTime.tryParse(f.dateFrom);
    if (f.dateTo.isNotEmpty) _to = DateTime.tryParse(f.dateTo);
    if (_from != null || _to != null) _preset = _QuickDatePreset.custom;
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    _originCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  void _applyPreset(_QuickDatePreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _preset = preset;
      switch (preset) {
        case _QuickDatePreset.today:
          _from = today;
          _to = today;
        case _QuickDatePreset.week:
          _from = today.subtract(Duration(days: today.weekday - 1));
          _to = today;
        case _QuickDatePreset.month:
          _from = DateTime(today.year, today.month, 1);
          _to = today;
        case _QuickDatePreset.custom:
          _from ??= today.subtract(const Duration(days: 7));
          _to ??= today;
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? (_from ?? DateTime.now()) : (_to ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2018),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _preset = _QuickDatePreset.custom;
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  void _cacheLabels(List<PurchaseFilterOption> options) {
    for (final option in options) {
      _labelCache[option.id] = option.label;
    }
  }

  Future<List<PurchaseFilterOption>> _fetchOptions(
    String kind,
    String search,
  ) async {
    final opts = await widget.repository.fetchPurchaseFilterOptions(
      search: search,
      kind: kind,
      testRole: widget.testRole,
    );
    final list = switch (kind) {
      'material_types' => opts.materialTypes,
      'vendors' => opts.vendors,
      'project_managers' => opts.projectManagers,
      'cities' => opts.cities,
      'years' => opts.years,
      _ => <PurchaseFilterOption>[],
    };
    if (search.isEmpty) _cacheLabels(list);
    return list;
  }

  String _selectedDisplay(List<int> ids) {
    if (ids.isEmpty) return '';
    final labels = ids
        .map((id) => _labelCache[id])
        .whereType<String>()
        .where((l) => l.isNotEmpty)
        .toList();
    if (labels.isEmpty) return '${ids.length} selected';
    if (labels.length <= 3) return labels.join(', ');
    return '${labels.take(3).join(', ')} +${labels.length - 3}';
  }

  Future<void> _openPicker({
    required String title,
    required String kind,
    required List<int> selected,
    required void Function(List<int>) onApply,
    bool coloredChips = false,
  }) async {
    final result = await PurchaseFilterPickerDialog.show(
      context,
      title: title,
      selectedIds: selected,
      coloredChips: coloredChips,
      fetchOptions: (search) => _fetchOptions(kind, search),
    );
    if (result == null) return;
    setState(() => onApply(result));
  }

  PurchaseListFilters _buildFilters() {
    return PurchaseListFilters(
      dateFrom: _from != null ? _fmt(_from!) : '',
      dateTo: _to != null ? _fmt(_to!) : '',
      origin: _originCtrl.text.trim(),
      reference: _referenceCtrl.text.trim(),
      vendorIds: _vendorIds,
      materialTypeIds: _materialTypeIds,
      cityIds: _cityIds,
      projectManagerIds: _projectManagerIds,
      years: _years,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.poppins(fontSize: 12.sp),
      hintStyle: GoogleFonts.poppins(
        fontSize: 12.sp,
        color: PurchaseTheme.textMuted,
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.9),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(
          color: PurchaseTheme.textMuted.withValues(alpha: 0.2),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: BorderSide(
          color: PurchaseTheme.textMuted.withValues(alpha: 0.2),
        ),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        decoration: BoxDecoration(
          color: PurchaseTheme.hubBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: PurchaseTheme.textMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18.w, 14.h, 12.w, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Smart Filters',
                      style: GoogleFonts.poppins(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: PurchaseTheme.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _preset = null;
                        _from = null;
                        _to = null;
                        _referenceCtrl.clear();
                        _originCtrl.clear();
                        _vendorIds = [];
                        _materialTypeIds = [];
                        _cityIds = [];
                        _projectManagerIds = [];
                        _years = [];
                        _labelCache.clear();
                      });
                    },
                    child: Text(
                      'Reset',
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: PurchaseTheme.accentDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('Quick dates'),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _quickChip('Today', _QuickDatePreset.today),
                        _quickChip('This Week', _QuickDatePreset.week),
                        _quickChip('This Month', _QuickDatePreset.month),
                        _quickChip('Custom', _QuickDatePreset.custom),
                      ],
                    ),
                    if (_preset == _QuickDatePreset.custom ||
                        _from != null ||
                        _to != null) ...[
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Expanded(
                            child: _dateTile(
                              label: 'From',
                              value: _from != null ? _fmt(_from!) : 'Select',
                              onTap: () => _pickDate(isFrom: true),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: _dateTile(
                              label: 'To',
                              value: _to != null ? _fmt(_to!) : 'Select',
                              onTap: () => _pickDate(isFrom: false),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 14.h),
                    _sectionTitle('Selection filters'),
                    _selectionField(
                      label: 'Tags',
                      hint: 'Choose material tags',
                      display: _selectedDisplay(_materialTypeIds),
                      onTap: () => _openPicker(
                        title: 'Tags',
                        kind: 'material_types',
                        selected: _materialTypeIds,
                        coloredChips: true,
                        onApply: (ids) => _materialTypeIds = ids,
                      ),
                    ),
                    _selectionField(
                      label: 'Vendor',
                      hint: 'Choose vendors',
                      display: _selectedDisplay(_vendorIds),
                      onTap: () => _openPicker(
                        title: 'Vendor',
                        kind: 'vendors',
                        selected: _vendorIds,
                        onApply: (ids) => _vendorIds = ids,
                      ),
                    ),
                    _selectionField(
                      label: 'Project Manager',
                      hint: 'Choose project managers',
                      display: _selectedDisplay(_projectManagerIds),
                      onTap: () => _openPicker(
                        title: 'Project Manager',
                        kind: 'project_managers',
                        selected: _projectManagerIds,
                        onApply: (ids) => _projectManagerIds = ids,
                      ),
                    ),
                    _selectionField(
                      label: 'City',
                      hint: 'Choose cities',
                      display: _selectedDisplay(_cityIds),
                      onTap: () => _openPicker(
                        title: 'City',
                        kind: 'cities',
                        selected: _cityIds,
                        onApply: (ids) => _cityIds = ids,
                      ),
                    ),
                    _selectionField(
                      label: 'Year',
                      hint: 'Choose years',
                      display: _selectedDisplay(_years),
                      onTap: () => _openPicker(
                        title: 'Year',
                        kind: 'years',
                        selected: _years,
                        onApply: (ids) => _years = ids,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    _sectionTitle('Text search'),
                    _field('Reference', _referenceCtrl, 'RCC-RFQ-40565'),
                    _field('Origin', _originCtrl, 'MR / origin reference'),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 20.h),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: PurchaseTheme.accentBlue,
                  minimumSize: Size(double.infinity, 46.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: () => Navigator.pop(context, _buildFilters()),
                child: Text(
                  'Apply Filters',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: PurchaseTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _selectionField({
    required String label,
    required String hint,
    required String display,
    required VoidCallback onTap,
  }) {
    final hasValue = display.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: InputDecorator(
          decoration: _inputDecoration(
            label: label,
            hint: hasValue ? null : hint,
            suffixIcon: Icon(
              Icons.chevron_right_rounded,
              color: PurchaseTheme.textMuted,
              size: 22.sp,
            ),
          ),
          child: Text(
            hasValue ? display : hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 13.sp,
              fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
              color: hasValue
                  ? PurchaseTheme.textPrimary
                  : PurchaseTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickChip(String label, _QuickDatePreset preset) {
    final selected = _preset == preset;
    return GestureDetector(
      onTap: () => _applyPreset(preset),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected
              ? PurchaseTheme.accentBlue
              : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? PurchaseTheme.accentBlue
                : PurchaseTheme.accentBlue.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : PurchaseTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: PurchaseTheme.textMuted.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                color: PurchaseTheme.textMuted,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: PurchaseTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.poppins(fontSize: 13.sp, color: PurchaseTheme.textPrimary),
        decoration: _inputDecoration(label: label, hint: hint),
      ),
    );
  }
}
