import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

enum _QuickDatePreset { today, week, month, custom }

class LpoSmartFilterSheet {
  LpoSmartFilterSheet._();

  static Future<LpoListFilters?> show({
    required BuildContext context,
    required LpoListFilters initial,
  }) {
    return showModalBottomSheet<LpoListFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LpoSmartFilterBody(initial: initial),
    );
  }
}

class _LpoSmartFilterBody extends StatefulWidget {
  const _LpoSmartFilterBody({required this.initial});

  final LpoListFilters initial;

  @override
  State<_LpoSmartFilterBody> createState() => _LpoSmartFilterBodyState();
}

class _LpoSmartFilterBodyState extends State<_LpoSmartFilterBody> {
  late final TextEditingController _referenceCtrl;
  late final TextEditingController _vendorCtrl;
  late final TextEditingController _projectCtrl;
  late final TextEditingController _requestedByCtrl;
  late final TextEditingController _projectManagerCtrl;
  late final TextEditingController _originCtrl;
  late final TextEditingController _cityCtrl;

  _QuickDatePreset? _preset;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _referenceCtrl = TextEditingController(text: f.reference);
    _vendorCtrl = TextEditingController(text: f.vendor);
    _projectCtrl = TextEditingController(text: f.project);
    _requestedByCtrl = TextEditingController(text: f.requestedBy);
    _projectManagerCtrl = TextEditingController(text: f.projectManager);
    _originCtrl = TextEditingController(text: f.origin);
    _cityCtrl = TextEditingController(text: f.city);
    if (f.dateFrom.isNotEmpty) {
      _from = DateTime.tryParse(f.dateFrom);
    }
    if (f.dateTo.isNotEmpty) {
      _to = DateTime.tryParse(f.dateTo);
    }
    if (_from != null || _to != null) {
      _preset = _QuickDatePreset.custom;
    }
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    _vendorCtrl.dispose();
    _projectCtrl.dispose();
    _requestedByCtrl.dispose();
    _projectManagerCtrl.dispose();
    _originCtrl.dispose();
    _cityCtrl.dispose();
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

  LpoListFilters _buildFilters() {
    return LpoListFilters(
      dateFrom: _from != null ? _fmt(_from!) : '',
      dateTo: _to != null ? _fmt(_to!) : '',
      vendor: _vendorCtrl.text.trim(),
      project: _projectCtrl.text.trim(),
      requestedBy: _requestedByCtrl.text.trim(),
      projectManager: _projectManagerCtrl.text.trim(),
      origin: _originCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      reference: _referenceCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
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
                        _vendorCtrl.clear();
                        _projectCtrl.clear();
                        _requestedByCtrl.clear();
                        _projectManagerCtrl.clear();
                        _originCtrl.clear();
                        _cityCtrl.clear();
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
                    _sectionTitle('Search fields'),
                    _field('Reference / Origin', _referenceCtrl, 'RCC-RFQ-40565'),
                    _field('Vendor', _vendorCtrl, 'Vendor name'),
                    _field('Project', _projectCtrl, 'Project title'),
                    _field('Requested By', _requestedByCtrl, 'Employee name'),
                    _field('Project Manager', _projectManagerCtrl, 'Manager name'),
                    _field('Origin', _originCtrl, 'MR / origin reference'),
                    _field('City', _cityCtrl, 'City name'),
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
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.poppins(fontSize: 12.sp),
          hintStyle: GoogleFonts.poppins(
            fontSize: 12.sp,
            color: PurchaseTheme.textMuted,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.9),
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
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        ),
      ),
    );
  }
}
