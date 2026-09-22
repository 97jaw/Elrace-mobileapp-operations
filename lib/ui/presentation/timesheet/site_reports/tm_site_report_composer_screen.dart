import 'dart:io';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/report_module/data/report_pdf_templates.dart';
import 'package:el_race/report_module/data/services/pdf_service.dart';
import 'package:el_race/report_module/presentation/screens/report_photos/multi_capture_camera_screen.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/models/tm_site_photo_draft.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/models/tm_site_report_composer_result.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/widgets/tm_report_format_sheet.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/widgets/tm_report_generation_sheet.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/widgets/tm_site_photo_description_carousel.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/widgets/tm_site_report_company_app_bar.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

/// New or edit report: capture/upload → describe → format → generate → return PDF URL.
///
/// Flat Site Report mode: set [useDefaultFolder] true and omit [folder];
/// create goes through `/api/site_reports/create` (hidden default folder).
class TmSiteReportComposerScreen extends StatefulWidget {
  const TmSiteReportComposerScreen({
    super.key,
    this.folder,
    this.projectName = '',
    this.locationHint = '',
    this.useDefaultFolder = false,
    this.existingReport,
  }) : assert(
          useDefaultFolder || folder != null || existingReport != null,
          'folder is required unless useDefaultFolder or editing an existing report',
        );

  final FolderModel? folder;
  final String projectName;
  /// Default photo location label (flat mode); falls back to [projectName].
  final String locationHint;
  final bool useDefaultFolder;
  final ReportModel? existingReport;

  bool get isEditMode => existingReport != null;

  String get _effectiveLocation {
    final hint = locationHint.trim();
    if (hint.isNotEmpty) return hint;
    return projectName.trim();
  }

  @override
  State<TmSiteReportComposerScreen> createState() =>
      _TmSiteReportComposerScreenState();
}

class _TmSiteReportComposerScreenState extends State<TmSiteReportComposerScreen> {
  final _titleController = TextEditingController();
  final _pdfNameController = TextEditingController();
  final _picker = ImagePicker();
  final List<TmSitePhotoDraft> _drafts = [];
  ReportModel? _report;
  bool _showEditor = false;
  int _editorStartIndex = 0;
  bool _loadingExisting = false;

  ReportProvider get _provider =>
      Provider.of<ReportProvider>(context, listen: false);

  List<TmSitePhotoDraft> get _activeDrafts =>
      _drafts.where((d) => !d.pendingDelete).toList();

  @override
  void initState() {
    super.initState();
    final now = DateFormat('dd MMM yyyy · HH:mm').format(DateTime.now());
    if (widget.existingReport != null) {
      _report = widget.existingReport;
      _titleController.text = widget.existingReport!.name;
      _pdfNameController.text = widget.existingReport!.name;
      _loadExistingItems();
    } else {
      _titleController.text = now;
      _pdfNameController.text = 'Site report $now';
    }
  }

  Future<void> _loadExistingItems() async {
    setState(() => _loadingExisting = true);
    final detail =
        await _provider.fetchReportDetailFromApi(widget.existingReport!.id);
    if (mounted && detail != null) {
      setState(() {
        for (final item in detail.reportItems) {
          if (item.type == 'image' && item.image.trim().isNotEmpty) {
            _drafts.add(TmSitePhotoDraft.fromServer(item));
          }
        }
        _showEditor = _drafts.isNotEmpty;
      });
    }
    if (mounted) setState(() => _loadingExisting = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pdfNameController.dispose();
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  void _addDraftFiles(Iterable<File> files) {
    if (files.isEmpty) return;
    final start = _activeDrafts.length;
    final location = widget._effectiveLocation;
    setState(() {
      for (final f in files) {
        _drafts.add(
          TmSitePhotoDraft.local(file: f, location: location),
        );
      }
      _showEditor = true;
      _editorStartIndex = start;
    });
  }

  Future<void> _pickCamera() async {
    final paths = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => const MultiCaptureCameraScreen()),
    );
    if (paths == null || paths.isEmpty) return;
    _addDraftFiles(paths.map(File.new));
  }

  Future<void> _pickGallery() async {
    final files = await _picker.pickMultiImage(imageQuality: 75);
    if (files.isEmpty) return;
    _addDraftFiles(files.map((f) => File(f.path)));
  }

  void _removeDraft(int visibleIndex) {
    final draft = _activeDrafts[visibleIndex];
    if (draft.isServer) {
      setState(() => draft.pendingDelete = true);
      return;
    }
    setState(() {
      draft.dispose();
      _drafts.remove(draft);
      if (_activeDrafts.isEmpty) _showEditor = false;
    });
  }

  Future<bool> _ensureReport() async {
    if (_report != null) return true;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _toast('Enter a report title');
      return false;
    }
    final ReportModel? created;
    if (widget.useDefaultFolder || widget.folder == null) {
      created = await _provider.createSiteReport(title: title);
    } else {
      created = await _provider.createReport(
        title: title,
        folderID: widget.folder!.id,
        companyName: CompanyRepository.company?.companyName,
      );
    }
    if (created == null) {
      _toast('Could not create report');
      return false;
    }
    _report = created;
    return true;
  }

  String get _folderIdForUpload {
    final fromReport = _report?.folderId.trim() ?? '';
    if (fromReport.isNotEmpty) return fromReport;
    return widget.folder?.id ?? '';
  }

  Future<void> _startGenerate() async {
    if (_activeDrafts.length < 3) {
      _toast('Add at least 3 photos before generating');
      return;
    }
    final pdfName = _pdfNameController.text.trim();
    if (pdfName.isEmpty) {
      _toast('Enter a PDF file name');
      return;
    }

    final defaultTemplate = _report?.reportType?.trim();
    final choice = await TmReportFormatSheet.show(
      context,
      photoCount: _activeDrafts.length,
      initialTemplateId: (defaultTemplate != null &&
              defaultTemplate.isNotEmpty &&
              ReportPdfTemplates.options.any((o) => o.id == defaultTemplate))
          ? defaultTemplate
          : ReportPdfTemplates.defaultId,
    );
    if (choice == null || !mounted) return;

    TmSiteReportComposerResult? result;
    final success = await TmReportGenerationSheet.run(
      context,
      work: (notify) async {
        result = await _runGeneration(
          notify: notify,
          pdfName: pdfName,
          templateId: choice.templateId,
        );
        return result != null;
      },
    );

    if (success && result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<TmSiteReportComposerResult?> _runGeneration({
    required TmReportGenerationNotifier notify,
    required String pdfName,
    required String templateId,
  }) async {
    try {
      notify(
        progress: 0.05,
        status: 'Preparing report…',
        visual: TmReportGenerationVisual.preparing,
      );

      if (!await _ensureReport()) return null;
      final report = _report!;

      final title = _titleController.text.trim();
      if (title.isNotEmpty && title != report.name) {
        await _provider.updateReport(name: title, reportId: report.id);
      }

      notify(
        progress: 0.12,
        status: 'Syncing photos…',
        visual: TmReportGenerationVisual.uploadingPhotos,
      );

      for (final draft in _drafts) {
        if (draft.pendingDelete && draft.serverItemId != null) {
          await _provider.deleteReportItem(
            reportId: report.id,
            itemId: draft.serverItemId!,
          );
          continue;
        }
        if (draft.pendingDelete) continue;

        final fallbackLocation = widget._effectiveLocation;
        final location = draft.locationController.text.trim().isNotEmpty
            ? draft.locationController.text.trim()
            : fallbackLocation;
        final description = draft.descriptionController.text.trim();
        final uploadFile = await draft.effectiveFileForUpload();

        if (draft.serverItemId != null) {
          await _provider.updateReportItem(
            reportId: report.id,
            itemId: draft.serverItemId!,
            description: description,
            location: location,
            imageFile: uploadFile,
          );
        } else if (uploadFile != null) {
          await _provider.addReportItem(
            reportId: report.id,
            imageFile: uploadFile,
            location: location,
            description: description,
          );
        }
      }

      notify(
        progress: 0.55,
        status: 'Loading report data…',
        visual: TmReportGenerationVisual.preparing,
      );

      final detail = await _provider.fetchReportDetailFromApi(report.id);
      if (detail == null || detail.reportItems.length < 3) {
        debugPrint(
            '❌ Site report generation aborted: detail missing or less than 3 items (reportId=${report.id})');
        return null;
      }

      notify(
        progress: 0.72,
        status: 'Generating PDF…',
        visual: TmReportGenerationVisual.generatingPdf,
      );

      final pdfProjectLabel = widget.projectName.trim().isNotEmpty
          ? widget.projectName
          : (widget._effectiveLocation.isNotEmpty
              ? widget._effectiveLocation
              : 'Site Report');

      final pdfBytes = await PdfService().generateReportPdf(
        report: detail,
        projectName: pdfProjectLabel,
        companyName: CompanyRepository.company?.companyName,
        templateType: templateId,
      );

      notify(
        progress: 0.85,
        status: 'Uploading to cloud…',
        visual: TmReportGenerationVisual.uploadingCloud,
      );

      final folderId = _folderIdForUpload;
      if (folderId.isEmpty) {
        debugPrint('❌ Site report generation aborted: empty folderId');
        return null;
      }

      final uploaded = await _provider.uploadReportPdf(
        empId: ReportProvider.empID,
        pdfBytes: pdfBytes,
        reportId: report.id,
        folderId: folderId,
        fileName: pdfName,
        onProgress: (uploadProgress) {
          notify(
            progress: 0.85 + (uploadProgress * 0.14),
            status: 'Uploading to cloud…',
            visual: TmReportGenerationVisual.uploadingCloud,
          );
        },
      );

      if (uploaded == null || uploaded.reportLink.trim().isEmpty) {
        debugPrint(
            '❌ Site report generation aborted: uploadReportPdf returned empty link');
        return null;
      }

      await _provider.persistReportType(report.id, templateId);

      notify(
        progress: 1,
        status: 'Completed',
        visual: TmReportGenerationVisual.done,
      );

      return TmSiteReportComposerResult(
        reportId: report.id,
        pdfUrl: uploaded.reportLink,
        pdfTitle: pdfName,
        templateId: templateId,
      );
    } catch (e, st) {
      debugPrint('❌ _runGeneration failed: $e\n$st');
      rethrow;
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return TmSiteReportGlassShell(
        title: widget.isEditMode ? 'Edit report' : 'New site report',
        body: const TimesheetLoadingState(
          style: TimesheetLoadingStyle.gallery,
        ),
      );
    }

    final active = _activeDrafts;
    final hasPhotos = active.isNotEmpty;

    return TmSiteReportGlassShell(
      title: widget.isEditMode ? 'Edit report photos' : 'New site report',
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(
                bottom: TimesheetModuleLayout.sectionGap,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TimesheetModuleLayout.screenPaddingH,
                    TimesheetModuleLayout.cardSpacing,
                    TimesheetModuleLayout.screenPaddingH,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Report title',
                        style: TimesheetModuleTypography.caption().copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _titleController,
                        style: TimesheetModuleTypography.body(),
                        decoration: _fieldDecoration('Title for this report'),
                      ),
                      const SizedBox(height: TimesheetModuleLayout.cardSpacing),
                      Text(
                        'PDF file name',
                        style: TimesheetModuleTypography.caption().copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _pdfNameController,
                        style: TimesheetModuleTypography.body(),
                        decoration: _fieldDecoration('Name on generated PDF'),
                      ),
                      const SizedBox(height: TimesheetModuleLayout.cardSpacing),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stackButtons = constraints.maxWidth < 340;
                          final capture = TmSecondaryButton(
                            label: stackButtons ? 'Capture' : 'Multi capture',
                            icon: PhosphorIcons.camera(),
                            onPressed: _pickCamera,
                          );
                          final upload = TmSecondaryButton(
                            label: 'Upload',
                            icon: PhosphorIcons.upload(),
                            onPressed: _pickGallery,
                          );
                          if (stackButtons) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                capture,
                                const SizedBox(height: 10),
                                upload,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: capture),
                              const SizedBox(width: 10),
                              Expanded(child: upload),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${active.length} photo(s) · minimum 3 · descriptions optional',
                        style: TimesheetModuleTypography.caption(),
                      ),
                    ],
                  ),
                ),
                if (!hasPhotos)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: TimesheetEmptyState(
                      message: widget.isEditMode
                          ? 'No photos yet. Capture or upload, then generate the PDF.'
                          : 'Capture or upload at least 3 photos, then generate the report.',
                    ),
                  )
                else if (_showEditor) ...[
                  const SizedBox(height: TimesheetModuleLayout.cardSpacing),
                  TmSitePhotoDescriptionCarousel(
                    drafts: active,
                    projectName: widget.projectName,
                    initialIndex:
                        _editorStartIndex.clamp(0, active.length - 1),
                    onRemove: _removeDraft,
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TimesheetModuleLayout.screenPaddingH,
                    ),
                    child: TmSecondaryButton(
                      label: 'Review photos',
                      icon: PhosphorIcons.notePencil(),
                      onPressed: () => setState(() => _showEditor = true),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(
                TimesheetModuleLayout.screenPaddingH,
              ),
              child: TmPrimaryButton(
                label: widget.isEditMode
                    ? 'Regenerate PDF'
                    : 'Generate report',
                icon: PhosphorIcons.filePdf(),
                onPressed: hasPhotos ? _startGenerate : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TimesheetModuleTypography.body().copyWith(
        color: TimesheetModuleColors.mutedText,
      ),
      filled: true,
      fillColor: TimesheetModuleColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          TimesheetModuleLayout.cardRadiusMd,
        ),
        borderSide: const BorderSide(color: TimesheetModuleColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(
          TimesheetModuleLayout.cardRadiusMd,
        ),
        borderSide: const BorderSide(color: TimesheetModuleColors.divider),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
