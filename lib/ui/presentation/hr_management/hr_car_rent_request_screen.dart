import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';

import 'package:el_race/core/hr_management/network/hr_api_client.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

/// Car Rent Request — SRD §5.3 / TASKS F3.
class HrCarRentRequestScreen extends ConsumerStatefulWidget {
  const HrCarRentRequestScreen({super.key});

  static const draftKey = 'hr_draft_car_rent_v1';

  @override
  ConsumerState<HrCarRentRequestScreen> createState() =>
      _HrCarRentRequestScreenState();
}

class _HrCarRentRequestScreenState extends ConsumerState<HrCarRentRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _purpose;
  DateTime? _fromDt;
  DateTime? _toDt;
  final _pickup = TextEditingController();
  final _dropoff = TextEditingController();
  String? _vehicle;
  final _distance = TextEditingController();
  final _justification = TextEditingController();
  String? _attachmentName;

  static const _purposes = [
    'Business Trip',
    'Client Visit',
    'Site Visit',
    'Airport Pickup/Drop',
    'Other',
  ];
  static const _vehicles = ['Sedan', 'SUV', 'Van', 'Pickup', 'Any'];

  static DateTime _roundHalfHour(DateTime dt) {
    final total = dt.hour * 60 + dt.minute;
    final rounded = (total / 30).round() * 30;
    final h = (rounded ~/ 60) % 24;
    final m = rounded % 60;
    return DateTime(dt.year, dt.month, dt.day, h, m);
  }

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  void _loadDraft() {
    final raw = SharedPref().getPreferenceString(HrCarRentRequestScreen.draftKey);
    if (raw.isEmpty) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _purpose = m['purpose'] as String?;
        _pickup.text = m['pickup'] as String? ?? '';
        _dropoff.text = m['dropoff'] as String? ?? '';
        _vehicle = m['vehicle'] as String?;
        _distance.text = m['distance'] as String? ?? '';
        _justification.text = m['justification'] as String? ?? '';
        _attachmentName = m['attachment'] as String?;
        final f = m['from'] as String?;
        final t = m['to'] as String?;
        if (f != null) _fromDt = DateTime.tryParse(f);
        if (t != null) _toDt = DateTime.tryParse(t);
      });
    } catch (_) {}
  }

  Future<void> _saveDraft() async {
    final payload = {
      'purpose': _purpose,
      'from': _fromDt?.toIso8601String(),
      'to': _toDt?.toIso8601String(),
      'pickup': _pickup.text,
      'dropoff': _dropoff.text,
      'vehicle': _vehicle,
      'distance': _distance.text,
      'justification': _justification.text,
      'attachment': _attachmentName,
    };
    await SharedPref()
        .setPreferencesString(HrCarRentRequestScreen.draftKey, jsonEncode(payload));
    if (mounted) Fluttertoast.showToast(msg: 'Draft saved');
  }

  Future<void> _pickDateTime({required bool isFrom}) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final initial = isFrom ? (_fromDt ?? now) : (_toDt ?? now.add(const Duration(hours: 2)));
    final d = await showDatePicker(
      context: context,
      firstDate: isFrom ? todayStart : todayStart,
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDate: initial,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (t == null) return;
    var combined = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    combined = _roundHalfHour(combined);
    if (combined.isBefore(now) && isFrom) {
      Fluttertoast.showToast(msg: 'From cannot be in the past');
      return;
    }
    setState(() {
      if (isFrom) {
        _fromDt = combined;
      } else {
        _toDt = combined;
      }
    });
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.pickFiles();
    if (r != null && r.files.single.name.isNotEmpty) {
      setState(() => _attachmentName = r.files.single.name);
    }
  }

  Future<void> _submit(HrApiClient api) async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromDt == null || _toDt == null) {
      Fluttertoast.showToast(msg: 'Select from and to date/time');
      return;
    }
    if (!_toDt!.isAfter(_fromDt!)) {
      Fluttertoast.showToast(msg: 'End must be after start');
      return;
    }
    final dist = int.tryParse(_distance.text.trim());
    if (_distance.text.trim().isNotEmpty && (dist == null || dist < 0 || dist > 5000)) {
      Fluttertoast.showToast(msg: 'Distance 0–5000 km');
      return;
    }
    final env = await api.submitAssetRequest(
      kind: 'car_rent',
      payload: {
        'purpose': _purpose,
        'from': _fromDt!.toIso8601String(),
        'to': _toDt!.toIso8601String(),
        'pickup': _pickup.text,
        'dropoff': _dropoff.text,
        'vehicle': _vehicle,
        'distance_km': dist,
        'justification': _justification.text,
        'attachment': _attachmentName,
      },
    );
    if (!mounted) return;
    if (env.success) {
      final refNo = env.data?['reference']?.toString() ?? '';
      await SharedPref().removePreference(HrCarRentRequestScreen.draftKey);
      Fluttertoast.showToast(msg: 'Request submitted — Ref: $refNo');
      Navigator.of(context).pop();
    } else {
      Fluttertoast.showToast(msg: env.error ?? 'Submit failed');
    }
  }

  @override
  void dispose() {
    _pickup.dispose();
    _dropoff.dispose();
    _distance.dispose();
    _justification.dispose();
    super.dispose();
  }

  String _fmt(DateTime? dt) =>
      dt == null ? 'Pick' : DateFormat('dd MMM yyyy, HH:mm').format(dt);

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(hrApiClientProvider);
    return Scaffold(
      backgroundColor: HrModuleColors.surface,
      appBar: AppBar(
        backgroundColor: HrModuleColors.surface,
        foregroundColor: HrModuleColors.text,
        title: Text(
          'Car Rent Request',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.tsp),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.tw),
          children: [
            Text(
              'Request a rental vehicle for business use',
              style: HrModuleTypography.body().copyWith(fontSize: 14.tsp),
            ),
            SizedBox(height: 16.th),
            Text('Purpose *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            DropdownButtonFormField<String>(
              value: _purpose,
              items: _purposes
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _purpose = v),
              validator: (v) => v == null ? 'Required' : null,
              decoration: _decoration('Select purpose'),
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
                      OutlinedButton(
                        onPressed: () => _pickDateTime(isFrom: true),
                        child: Text(_fmt(_fromDt)),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.tw),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('To *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
                      OutlinedButton(
                        onPressed: () => _pickDateTime(isFrom: false),
                        child: Text(_fmt(_toDt)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Pickup Location *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            TextFormField(
              controller: _pickup,
              maxLength: 150,
              decoration: _decoration('Enter pickup location'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            Text('Drop-off Location *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            TextFormField(
              controller: _dropoff,
              maxLength: 150,
              decoration: _decoration('Enter drop-off location'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Vehicle Type', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            DropdownButtonFormField<String>(
              value: _vehicle,
              items: _vehicles
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _vehicle = v),
              decoration: _decoration('Any'),
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Estimated Distance (km)', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            TextFormField(
              controller: _distance,
              keyboardType: TextInputType.number,
              decoration: _decoration('0–5000'),
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            Text('Justification *', style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
            TextFormField(
              controller: _justification,
              minLines: 3,
              maxLines: 6,
              decoration: _decoration('10–500 characters'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 10) return 'At least 10 characters';
                if (t.length > 500) return 'Max 500 characters';
                return null;
              },
            ),
            SizedBox(height: HrModuleLayout.formFieldSpacingV.th),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_attachmentName ?? 'Attachment (optional)'),
            ),
            SizedBox(height: 24.th),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saveDraft,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.fromHeight(HrModuleLayout.buttonHeight.th),
                    ),
                    child: Text('Save Draft', style: TextStyle(color: HrModuleColors.primary, fontSize: 14.tsp)),
                  ),
                ),
                SizedBox(width: 12.tw),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _submit(api),
                    style: FilledButton.styleFrom(
                      backgroundColor: HrModuleColors.primary,
                      minimumSize: Size.fromHeight(HrModuleLayout.buttonHeight.th),
                    ),
                    child: Text('Submit Request', style: TextStyle(fontSize: 14.tsp)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: HrModuleColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.tr),
      ),
    );
  }
}
