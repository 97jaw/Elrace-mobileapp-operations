import 'package:el_race/core/site_management/face_recognition/face_recognition_provider.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class PmWorkerEnrol extends ConsumerStatefulWidget {
  const PmWorkerEnrol({
    super.key,
    required this.projectId,
    /// When set, face photos upload via Odoo `register_face_images` (Phase C).
    this.odooEmployeeId,
  });

  final String projectId;
  final int? odooEmployeeId;

  @override
  ConsumerState<PmWorkerEnrol> createState() => _PmWorkerEnrolState();
}

class _PmWorkerEnrolState extends ConsumerState<PmWorkerEnrol> {
  final _nameController = TextEditingController();
  final _tradeController = TextEditingController();
  final _contactController = TextEditingController();
  final _rateController = TextEditingController();
  final Set<String> _selectedTaskIds = {};
  final List<String?> _referencePhotoPaths = List<String?>.filled(4, null);
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _tradeController.dispose();
    _contactController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync =
        ref.watch(timesheetProjectTasksProvider(widget.projectId));

    return TmScaffold(
      appBar: AppBar(
        title: Text('New Worker', style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project: ${widget.projectId}',
                style: TimesheetModuleTypography.caption()),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            _Field(controller: _nameController, label: 'Name'),
            _Field(controller: _tradeController, label: 'Trade'),
            _Field(controller: _contactController, label: 'Contact'),
            _Field(controller: _rateController, label: 'Hourly Rate'),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            const TmSectionHeader(title: 'Assign To Tasks'),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            tasksAsync.when(
              loading: () => const Padding(
                padding:
                    EdgeInsets.only(bottom: TimesheetModuleLayout.cardSpacing),
                child: LinearProgressIndicator(),
              ),
              error: (_, __) => Text(
                'Could not load tasks',
                style: TimesheetModuleTypography.caption(),
              ),
              data: (tasks) => Column(
                children: [
                  for (final task in tasks) ...[
                    CheckboxListTile(
                      value: _selectedTaskIds.contains(task.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedTaskIds.add(task.id);
                          } else {
                            _selectedTaskIds.remove(task.id);
                          }
                        });
                      },
                      title: Text(
                        task.name,
                        style: TimesheetModuleTypography.body(),
                      ),
                      subtitle: Text(
                        '${task.status} - ${task.percentComplete.toStringAsFixed(0)}%',
                        style: TimesheetModuleTypography.caption(),
                      ),
                      activeColor: TimesheetModuleColors.primary,
                      tileColor: TimesheetModuleColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          TimesheetModuleLayout.cardRadiusMd,
                        ),
                      ),
                    ),
                    const SizedBox(height: TimesheetModuleLayout.cardSpacing),
                  ],
                ],
              ),
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            const TmSectionHeader(
              title: 'Face Reference Photos (front, left, right, up)',
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            Row(
              children: [
                for (var index = 0;
                    index < _referencePhotoPaths.length;
                    index += 1) ...[
                  Expanded(
                    child: _PhotoSlot(
                      label: 'Photo ${index + 1}',
                      captured: _referencePhotoPaths[index] != null,
                      onTap: () => _captureReferencePhoto(index),
                    ),
                  ),
                  if (index != _referencePhotoPaths.length - 1)
                    const SizedBox(width: TimesheetModuleLayout.cardSpacing),
                ],
              ],
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            TmPrimaryButton(
              label: _isSaving ? 'Saving...' : 'Save Worker',
              icon: PhosphorIcons.floppyDisk(),
              onPressed: _isSaving ? null : _saveWorker,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveWorker() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Worker name is required')),
      );
      return;
    }

    if (_referencePhotoPaths.any((path) => path == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture 4 reference photos first')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final workerId = 'w_${DateTime.now().millisecondsSinceEpoch}';
    final photoUrls = _referencePhotoPaths.whereType<String>().toList();

    try {
      if (widget.odooEmployeeId != null && widget.odooEmployeeId! > 0) {
        final enroll = await ref
            .read(faceEnrollmentServiceProvider)
            .enrollFromPhotoList(
              employeeId: widget.odooEmployeeId!,
              localPaths: photoUrls,
            );
        if (!enroll.success) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                enroll.message ?? 'Face enrollment failed',
              ),
            ),
          );
          return;
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Face enrolled for employee ${widget.odooEmployeeId} '
              '(${enroll.templateCount} templates processing)',
            ),
          ),
        );
        Navigator.of(context).maybePop();
        return;
      }

      final faceResponse =
          await ref.read(timesheetFunctionsClientProvider).enrollWorkerFace(
                workerId: workerId,
                projectId: widget.projectId,
                photoUrls: photoUrls,
              );
      final worker = Worker(
        id: workerId,
        projectId: widget.projectId,
        name: name,
        trade: _tradeController.text.trim(),
        contact: _contactController.text.trim(),
        hourlyRate: double.tryParse(_rateController.text.trim()) ?? 0,
        status: 'ACTIVE',
        faceId: faceResponse['face_id']?.toString() ?? 'mock_$workerId',
        refPhotoUrls: photoUrls,
      );
      await ref.read(timesheetApiClientProvider).createWorker(worker);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Worker saved with ${_selectedTaskIds.length} task assignments',
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save worker: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _captureReferencePhoto(int index) {
    setState(() {
      _referencePhotoPaths[index] =
          'mock://${widget.projectId}/ref_${index + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reference photo ${index + 1} captured')),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TimesheetModuleLayout.cardSpacing),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: TimesheetModuleColors.surface,
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
            borderSide: const BorderSide(color: TimesheetModuleColors.divider),
          ),
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    required this.captured,
    required this.onTap,
  });

  final String label;
  final bool captured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
      onTap: onTap,
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: captured
              ? TimesheetModuleColors.navyTint
              : TimesheetModuleColors.primaryTint,
          borderRadius:
              BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
          border: Border.all(
            color: captured
                ? TimesheetModuleColors.navy
                : TimesheetModuleColors.primary,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              captured ? PhosphorIcons.checkCircle() : PhosphorIcons.camera(),
              color: captured
                  ? TimesheetModuleColors.navy
                  : TimesheetModuleColors.primary,
            ),
            const SizedBox(height: 6),
            Text(
              captured ? '$label OK' : label,
              style: TimesheetModuleTypography.caption(),
            ),
          ],
        ),
      ),
    );
  }
}
