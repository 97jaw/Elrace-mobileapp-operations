import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/task_notification_service.dart';
import 'package:el_race/report_module/data/models/folder_model.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_shell.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_searchable_picker.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/services/task_options_api_service.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/services/teams_api_service.dart';
import 'package:el_race/ui/presentation/todo_list/data/task_member_model.dart';
import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:el_race/ui/presentation/todo_list/services/todo_firebase_service.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  static const _accent = Color(0xFF4C8BF5);
  static const _fieldBorder = Color(0xFFE6E8EC);
  static const _fieldRadius = 12.0;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final TextEditingController _daysController;

  double _daysValue = 5;
  DateTime _startDate = DateTime.now();

  DateTime get _endDate =>
      _startDate.add(Duration(days: _daysValue.toInt().clamp(0, 365)));

  List<ProjectOption> _projects = [];
  ProjectOption? _selectedProject;
  bool _isLoadingProjects = true;

  List<String> _departments = [];
  String? _selectedDepartment;
  bool _isLoadingDepartments = true;
  /// Extra departments chosen via "+" beyond the first 5.
  final List<String> _extraDepartmentChips = [];

  static const _deptChipPalettes = <(Color bg, Color fg)>[
    (Color(0xFFEEF4FF), Color(0xFF4C8BF5)),
    (Color(0xFFE8F8EF), Color(0xFF16A34A)),
    (Color(0xFFFFEBEE), Color(0xFFE11D48)),
    (Color(0xFFFFF4E5), Color(0xFFD97706)),
    (Color(0xFFE8F1FF), Color(0xFF2563EB)),
    (Color(0xFFF3E8FF), Color(0xFF7C3AED)),
    (Color(0xFFE0F7FA), Color(0xFF0891B2)),
  ];

  List<TeamMember> _allMembers = [];
  final List<TeamMember> _selectedMembers = [];
  final List<TeamMember> _selectedFollowers = [];
  bool _isLoadingMembers = true;

  final List<File> _attachments = [];
  final _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  List<FolderModel> _folders = [];
  List<ReportModel> _reportsForSelectedFolder = [];
  FolderModel? _selectedFolder;
  ReportModel? _selectedReport;
  bool _isLoadingFolders = true;
  bool _isLoadingReports = false;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _daysController =
        TextEditingController(text: _daysValue.toInt().toString());
    _loadData();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    if (_isRecording) {
      _audioRecorder.stop();
    }
    _audioRecorder.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      TaskOptionsApiService.getProjects(),
      TeamsApiService.getUniqueDepartments(),
      TeamMembersApiService.instance.getTeamMembers(forceRefresh: true),
    ]);
    if (!mounted) return;
    setState(() {
      _projects = results[0] as List<ProjectOption>;
      _departments = results[1] as List<String>;
      _allMembers = results[2] as List<TeamMember>;
      _isLoadingProjects = false;
      _isLoadingDepartments = false;
      _isLoadingMembers = false;
    });
    await _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      final reportsProvider = context.read<ReportProvider>();
      final loginData = SharedPref.getLoginDataOrNull();
      if (loginData != null) {
        final baseUrl =
            loginData.result?.data?.webBaseUrl ?? 'https://erp.elrace.com';
        await reportsProvider.init(base: baseUrl);
      }
      await reportsProvider.fetchAllFolders();
      if (!mounted) return;
      setState(() {
        _folders = reportsProvider.folders;
        _isLoadingFolders = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingFolders = false);
    }
  }

  Future<void> _loadReportsForFolder(String folderId) async {
    setState(() {
      _isLoadingReports = true;
      _selectedReport = null;
      _reportsForSelectedFolder = [];
    });
    try {
      final reportsProvider = context.read<ReportProvider>();
      await reportsProvider.fetchAllReports(folderID: folderId);
      if (!mounted) return;
      setState(() {
        _reportsForSelectedFolder = reportsProvider.reports;
        _isLoadingReports = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingReports = false);
    }
  }

  String _formatDate(DateTime date) =>
      DateFormat('dd MMM yyyy').format(date).toUpperCase();

  /// Whether [member] is the logged-in user (id + name, same rules as
  /// TodoFirebaseService assignment matching).
  bool _isCurrentUserAssignee(TaskMember member) {
    final data = SharedPref.getLoginData().result?.data;
    final myIds = <String?>[
      data?.odoo_user_id?.toString(),
      data?.uid?.toString(),
      data?.employee_id?.toString(),
      data?.emp_id?.toString(),
      data?.emp_profile_id?.toString(),
      data?.firebase_uid,
    ]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.toLowerCase() != 'false')
        .toSet();
    for (final id in [data?.odoo_user_id?.toString(), data?.uid?.toString()]) {
      final clean = id?.trim();
      if (clean != null &&
          clean.isNotEmpty &&
          clean.toLowerCase() != 'false') {
        myIds.add('odoo_$clean');
      }
    }

    final memberIds = <String>{};
    final oId = member.odooId?.trim();
    if (oId != null && oId.isNotEmpty) memberIds.add(oId);
    final uId = member.userId?.trim();
    if (uId != null && uId.isNotEmpty) {
      memberIds.add(uId);
      memberIds.add('odoo_$uId');
    }
    if (memberIds.any(myIds.contains)) return true;

    final myNames = <String?>[
      data?.name,
      data?.emp_name,
      data?.username,
      data?.partnerDisplayName,
    ]
        .whereType<String>()
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty && e != 'false')
        .toSet();
    final memberName = member.name.trim().toLowerCase();
    return memberName.isNotEmpty && myNames.contains(memberName);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submitTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a task title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String? assignedToName;
      if (_selectedMembers.isNotEmpty) {
        assignedToName = _selectedMembers.map((m) => m.name).join(', ');
      }

      List<TaskMember>? assignedMembers;
      if (_selectedMembers.isNotEmpty) {
        assignedMembers = _selectedMembers.map((m) {
          final empId = (m.employeeId != null && m.employeeId! > 0)
              ? m.employeeId.toString()
              : m.id.toString();
          final oUserId = (m.odooUserId != null && m.odooUserId! > 0)
              ? m.odooUserId.toString()
              : null;
          return TaskMember(
            name: m.name,
            odooId: empId,
            userId: oUserId,
            isCompleted: false,
          );
        }).toList();
      }

      List<String>? followers;
      List<TaskMember>? followedUpBy;
      if (_selectedFollowers.isNotEmpty) {
        followers = _selectedFollowers.map((m) => m.name).toList();
        followedUpBy = _selectedFollowers
            .map(
              (m) => TaskMember(
                name: m.name,
                odooId: (m.employeeId != null && m.employeeId! > 0)
                    ? m.employeeId.toString()
                    : m.id.toString(),
                userId: (m.odooUserId != null && m.odooUserId! > 0)
                    ? m.odooUserId.toString()
                    : null,
                isCompleted: false,
              ),
            )
            .toList();
      }

      List<String>? attachments;
      if (_attachments.isNotEmpty) {
        attachments = _attachments.map((f) => f.path.split('/').last).toList();
      }

      final todo = TodoModel(
        title: title,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        department: _selectedDepartment,
        startDate: _startDate,
        dueDate: _endDate,
        assignedToName: assignedToName,
        assignedMembers: assignedMembers,
        followers: followers,
        followedUpBy: followedUpBy,
        attachments: attachments,
        reportId: _selectedReport?.id,
        isCompleted: false,
        isImportant: false,
        isMyDay: false,
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docId = await TodoFirebaseService.instance.insertTodo(todo);

      try {
        final notifService = TaskNotificationService();
        // Assignees get FCM via Cloud Function when their path copy is written
        // (skipped for the creator's own uid). Always local-notify when this
        // task is for the current user (no assignees = personal, or self in list).
        final assignsToMe = assignedMembers == null ||
            assignedMembers.isEmpty ||
            assignedMembers.any(_isCurrentUserAssignee);
        if (assignsToMe) {
          await notifService.showNewTaskNotification(
            taskId: docId,
            taskTitle: title,
            assignedBy: null,
          );
        }
        await notifService.scheduleDeadlineReminders(
          taskId: docId,
          taskTitle: title,
          dueDate: _endDate,
        );
      } catch (e) {
        debugPrint('Task notification error (non-blocking): $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProductivityLightShell(
      showBack: false,
      centerTitle: true,
      title: 'Create task',
      titleTrailing: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.close_rounded, color: ProductivityLightTheme.ink),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                _label('Task title'),
                const SizedBox(height: 8),
                _textField(
                  controller: _titleController,
                  hint: 'Enter task title',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                _label('Project'),
                const SizedBox(height: 8),
                _selectTile(
                  loading: _isLoadingProjects,
                  value: _selectedProject?.name,
                  placeholder: 'Select project',
                  onTap: _pickProject,
                  onClear: _selectedProject == null
                      ? null
                      : () => setState(() => _selectedProject = null),
                ),
                const SizedBox(height: 14),
                _label('Department'),
                const SizedBox(height: 8),
                _buildDepartmentChips(),
                const SizedBox(height: 14),
                _label('Add member'),
                const SizedBox(height: 8),
                _membersRow(
                  loading: _isLoadingMembers,
                  selected: _selectedMembers,
                  onAdd: () => _showMemberPicker(isFollower: false),
                  onRemove: (m) => setState(() => _selectedMembers.remove(m)),
                ),
                const SizedBox(height: 14),
                _label('Linked report (optional)'),
                const SizedBox(height: 8),
                _selectTile(
                  loading: _isLoadingFolders,
                  value: _selectedFolder?.name,
                  placeholder: 'Select folder',
                  onTap: _pickFolder,
                  onClear: _selectedFolder == null
                      ? null
                      : () => setState(() {
                            _selectedFolder = null;
                            _selectedReport = null;
                            _reportsForSelectedFolder = [];
                          }),
                ),
                if (_selectedFolder != null) ...[
                  const SizedBox(height: 10),
                  _selectTile(
                    loading: _isLoadingReports,
                    value: _selectedReport?.name,
                    placeholder: 'Select report',
                    onTap: _pickReport,
                    onClear: _selectedReport == null
                        ? null
                        : () => setState(() => _selectedReport = null),
                  ),
                ],
                const SizedBox(height: 14),
                _buildDescriptionSection(),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Days'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _daysController,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: _fieldDecoration(hint: '5'),
                            onChanged: (v) {
                              if (v.isEmpty) return;
                              setState(() {
                                _daysValue = double.tryParse(v) ?? 5;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Start date'),
                          const SizedBox(height: 8),
                          _dateTimeTile(
                            value: _formatDate(_startDate),
                            onTap: _pickStartDate,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End date',
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE11D48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _dateTimeTile(
                            value: _formatDate(_endDate),
                            onTap: null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _label('Following by'),
                const SizedBox(height: 8),
                _membersRow(
                  loading: _isLoadingMembers,
                  selected: _selectedFollowers,
                  onAdd: () => _showMemberPicker(isFollower: true),
                  onRemove: (m) => setState(() => _selectedFollowers.remove(m)),
                ),
                const SizedBox(height: 14),
                _label('Attachments'),
                const SizedBox(height: 8),
                _attachmentsRow(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _accent.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Create task',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── UI helpers ──────────────────────────────────────────────────────────

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ProductivityLightTheme.ink,
        ),
      );

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.roboto(
        color: ProductivityLightTheme.inkMuted,
        fontSize: 14,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: _fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: _accent, width: 1.4),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction: textInputAction,
      style: GoogleFonts.roboto(fontSize: 15, color: ProductivityLightTheme.ink),
      decoration: _fieldDecoration(hint: hint),
    );
  }

  Widget _dateTimeTile({required String value, VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_fieldRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_fieldRadius),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_fieldRadius),
            border: Border.all(color: _fieldBorder),
          ),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.roboto(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: onTap == null
                  ? ProductivityLightTheme.inkMuted
                  : ProductivityLightTheme.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectTile({
    required bool loading,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    if (loading) {
      return Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_fieldRadius),
          border: Border.all(color: _fieldBorder),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final hasValue = value != null && value.trim().isNotEmpty;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_fieldRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_fieldRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_fieldRadius),
            border: Border.all(color: _fieldBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue ? value : placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    color: hasValue
                        ? ProductivityLightTheme.ink
                        : ProductivityLightTheme.inkMuted,
                  ),
                ),
              ),
              if (hasValue && onClear != null)
                InkWell(
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: ProductivityLightTheme.inkMuted,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: ProductivityLightTheme.inkMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_fieldRadius),
        border: Border.all(color: _fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _label('Description')),
              _toolImageBtn(
                'assets/png/paragraphIcon.png',
                _formatAlignLeft,
                tooltip: 'Paragraph',
              ),
              const SizedBox(width: 6),
              _toolBtn(
                Icons.format_list_bulleted,
                _formatBulletList,
                tooltip: 'Bullets',
              ),
              const SizedBox(width: 6),
              _toolBtn(
                Icons.format_list_numbered,
                _formatNumberedList,
                tooltip: 'Numbered',
              ),
              const SizedBox(width: 6),
              _toolImageBtn(
                'assets/png/mic_icon.png',
                _toggleVoiceNote,
                tooltip: _isRecording ? 'Stop recording' : 'Voice note',
                active: _isRecording,
              ),
              const SizedBox(width: 6),
              _toolBtn(
                Icons.document_scanner_outlined,
                _scanDocumentToAttachments,
                tooltip: 'Scan document',
              ),
            ],
          ),
          if (_isRecording) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record,
                      size: 14, color: Color(0xFFE11D48)),
                  const SizedBox(width: 8),
                  Text(
                    'Recording ${_formatDuration(_recordingDuration)} — tap mic to stop',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 5,
            minLines: 3,
            onChanged: _handleDescriptionChange,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: ProductivityLightTheme.ink,
            ),
            decoration: InputDecoration(
              hintText: 'Write your description…',
              hintStyle: GoogleFonts.roboto(
                fontSize: 14,
                color: ProductivityLightTheme.inkMuted,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolBtn(
    IconData icon,
    VoidCallback onTap, {
    String? tooltip,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: active
            ? const Color(0xFFFFEBEE)
            : ProductivityLightTheme.iconChip,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              size: 18,
              color: active
                  ? const Color(0xFFE11D48)
                  : ProductivityLightTheme.inkSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolImageBtn(
    String asset,
    VoidCallback onTap, {
    String? tooltip,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: active
            ? const Color(0xFFFFEBEE)
            : ProductivityLightTheme.iconChip,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                color: active ? const Color(0xFFE11D48) : null,
                colorBlendMode: active ? BlendMode.srcIn : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggleVoiceNote() async {
    if (_isRecording) {
      await _stopVoiceNote();
    } else {
      await _startVoiceNote();
    }
  }

  Future<void> _startVoiceNote() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission is required'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: openAppSettings,
            ),
          ),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/task_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordingDuration += const Duration(seconds: 1));
      });

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopVoiceNote() async {
    try {
      final path = await _audioRecorder.stop();
      _recordingTimer?.cancel();
      _recordingTimer = null;
      setState(() => _isRecording = false);

      if (path == null || path.isEmpty) return;
      final file = File(path);
      if (!await file.exists()) return;

      setState(() => _attachments.add(file));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Voice note added (${_formatDuration(_recordingDuration)})',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _recordingTimer?.cancel();
      setState(() => _isRecording = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scanDocumentToAttachments() async {
    try {
      final pictures = await CunningDocumentScanner.getPictures(
        noOfPages: 5,
        isGalleryImportAllowed: true,
      );
      if (pictures == null || pictures.isEmpty || !mounted) return;

      setState(() {
        for (final path in pictures) {
          final file = File(path);
          if (file.existsSync()) _attachments.add(file);
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${pictures.length} scanned page${pictures.length == 1 ? '' : 's'} added',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan cancelled or failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _membersRow({
    required bool loading,
    required List<TeamMember> selected,
    required VoidCallback onAdd,
    required ValueChanged<TeamMember> onRemove,
  }) {
    if (loading) {
      return const SizedBox(
        height: 44,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _addSquare(onAdd),
          const SizedBox(width: 10),
          ...selected.map(
            (m) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _participantChip(m, () => onRemove(m)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _addSquare(_pickAttachment),
          const SizedBox(width: 10),
          ..._attachments.asMap().entries.map((e) {
            final file = e.value;
            final ext = file.path.split('.').last.toLowerCase();
            final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _fieldBorder),
                      color: Colors.white,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isImage
                        ? Image.file(file, fit: BoxFit.cover)
                        : Icon(
                            ext == 'pdf'
                                ? Icons.picture_as_pdf
                                : Icons.insert_drive_file,
                            color: ext == 'pdf'
                                ? Colors.red
                                : ProductivityLightTheme.inkMuted,
                          ),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: InkWell(
                      onTap: () => setState(() => _attachments.removeAt(e.key)),
                      child: const CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.close, size: 11, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _addSquare(VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accent, width: 1.4),
          ),
          child: const Icon(Icons.add_rounded, color: _accent, size: 24),
        ),
      ),
    );
  }

  Widget _participantChip(TeamMember member, VoidCallback onRemove) {
    final name = _memberDisplayName(member.name);
    final image = _memberImageProvider(member.image);
    return Container(
      height: 44,
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      decoration: BoxDecoration(
        color: ProductivityLightTheme.iconChip,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _fieldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _accent.withValues(alpha: 0.12),
            backgroundImage: image,
            onBackgroundImageError: image == null ? null : (_, __) {},
            child: image == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w700,
                      color: _accent,
                      fontSize: 13,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: Text(
              name.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: ProductivityLightTheme.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Description format tools (same as previous screen) ──────────────────

  void _formatAlignLeft() => setState(() {});

  void _handleDescriptionChange(String value) {
    if (!value.endsWith('\n')) return;
    final lines = value.split('\n');
    if (lines.length < 2) return;
    final previousLine = lines[lines.length - 2].trim();
    if (previousLine.startsWith('• ')) {
      final newText = '$value• ';
      _descriptionController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      return;
    }
    final numberMatch = RegExp(r'^(\d+)\.\s').firstMatch(previousLine);
    if (numberMatch != null) {
      final nextNumber = int.parse(numberMatch.group(1)!) + 1;
      final newText = '$value$nextNumber. ';
      _descriptionController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  void _formatBulletList() {
    final text = _descriptionController.text;
    if (text.isEmpty) return;
    final formatted = text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((line) {
          final trimmed = line.trim();
          if (trimmed.startsWith('• ')) return trimmed;
          if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
            return '• ${trimmed.replaceFirst(RegExp(r'^\d+\.\s'), '')}';
          }
          return '• $trimmed';
        })
        .join('\n');
    _descriptionController.text = formatted;
    _descriptionController.selection =
        TextSelection.collapsed(offset: formatted.length);
  }

  void _formatNumberedList() {
    final text = _descriptionController.text;
    if (text.isEmpty) return;
    var number = 1;
    final formatted = text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .map((line) {
          final trimmed = line.trim();
          if (trimmed.startsWith('• ')) {
            return '${number++}. ${trimmed.substring(2)}';
          }
          if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
            return '${number++}. ${trimmed.replaceFirst(RegExp(r'^\d+\.\s'), '')}';
          }
          return '${number++}. $trimmed';
        })
        .join('\n');
    _descriptionController.text = formatted;
    _descriptionController.selection =
        TextSelection.collapsed(offset: formatted.length);
  }

  // ── Pickers ─────────────────────────────────────────────────────────────

  Widget _buildDepartmentChips() {
    if (_isLoadingDepartments) {
      return const SizedBox(
        height: 40,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final primary = _departments.take(5).toList();
    final visible = <String>[
      ...primary,
      ..._extraDepartmentChips.where((d) => !primary.contains(d)),
    ];
    // Keep selected dept visible even if outside first 5 / extras.
    if (_selectedDepartment != null &&
        !visible.contains(_selectedDepartment)) {
      visible.add(_selectedDepartment!);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _deptChip(
          label: 'All',
          selected: _selectedDepartment == null,
          palette: _deptChipPalettes[0],
          onTap: () => setState(() => _selectedDepartment = null),
        ),
        for (var i = 0; i < visible.length; i++)
          _deptChip(
            label: visible[i],
            selected: _selectedDepartment == visible[i],
            palette: _deptChipPalettes[(i + 1) % _deptChipPalettes.length],
            onTap: () => setState(() => _selectedDepartment = visible[i]),
          ),
        _deptAddChip(onTap: _pickDepartment),
      ],
    );
  }

  Widget _deptChip({
    required String label,
    required bool selected,
    required (Color, Color) palette,
    required VoidCallback onTap,
  }) {
    final (bg, fg) = palette;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? ProductivityLightTheme.ink : fg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _deptAddChip({required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accent, width: 1.4),
          ),
          child: const Icon(Icons.add_rounded, color: _accent, size: 22),
        ),
      ),
    );
  }

  Future<void> _pickProject() async {
    final picked = await ProductivitySearchablePicker.show<ProjectOption>(
      context,
      title: 'Select project',
      items: _projects,
      labelOf: (p) => p.name,
      selected: _selectedProject,
      allowClear: true,
    );
    if (!mounted) return;
    setState(() => _selectedProject = picked);
  }

  Future<void> _pickDepartment() async {
    final picked = await ProductivitySearchablePicker.show<String>(
      context,
      title: 'All departments',
      items: _departments,
      labelOf: (d) => d,
      selected: _selectedDepartment,
      allowClear: true,
      clearLabel: 'All',
    );
    if (!mounted) return;
    setState(() {
      _selectedDepartment = picked;
      if (picked != null &&
          !_departments.take(5).contains(picked) &&
          !_extraDepartmentChips.contains(picked)) {
        _extraDepartmentChips.add(picked);
      }
    });
  }

  Future<void> _pickFolder() async {
    final picked = await ProductivitySearchablePicker.show<FolderModel>(
      context,
      title: 'Select folder',
      items: _folders,
      labelOf: (f) => f.name,
      selected: _selectedFolder,
      allowClear: true,
    );
    if (!mounted) return;
    setState(() => _selectedFolder = picked);
    if (picked != null) {
      await _loadReportsForFolder(picked.id);
    } else {
      setState(() {
        _selectedReport = null;
        _reportsForSelectedFolder = [];
      });
    }
  }

  Future<void> _pickReport() async {
    final picked = await ProductivitySearchablePicker.show<ReportModel>(
      context,
      title: 'Select report',
      items: _reportsForSelectedFolder,
      labelOf: (r) => r.name,
      selected: _selectedReport,
      allowClear: true,
    );
    if (!mounted) return;
    setState(() => _selectedReport = picked);
  }

  void _showMemberPicker({required bool isFollower}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => _MemberPickerSheet(
        title: isFollower ? 'Select followers' : 'Select participants',
        members: _allMembers,
        selectedMembers: isFollower ? _selectedFollowers : _selectedMembers,
        imageProviderFor: _memberImageProvider,
        displayNameFor: _memberDisplayName,
        onChanged: (next) {
          setState(() {
            if (isFollower) {
              _selectedFollowers
                ..clear()
                ..addAll(next);
            } else {
              _selectedMembers
                ..clear()
                ..addAll(next);
            }
          });
        },
      ),
    );
  }

  Future<void> _pickAttachment() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ProductivityLightTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ProductivityLightTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _accent),
              title: const Text('Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final image =
                    await _imagePicker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  setState(() => _attachments.add(File(image.path)));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(context);
                final image =
                    await _imagePicker.pickImage(source: ImageSource.camera);
                if (image != null) {
                  setState(() => _attachments.add(File(image.path)));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Colors.orange),
              title: const Text('File / PDF'),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.pickFiles();
                if (result?.files.single.path != null) {
                  setState(
                    () => _attachments.add(File(result!.files.single.path!)),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _memberDisplayName(String rawName) {
    final cleaned =
        rawName.replaceFirst(RegExp(r'^\s*\d+\s*[-:|#]*\s*'), '').trim();
    final parts =
        cleaned.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return rawName.trim();
    if (parts.length == 1) return parts.first;
    return '${parts[0]} ${parts[1]}';
  }

  ImageProvider? _memberImageProvider(String? rawImage) {
    if (rawImage == null) return null;
    final value = rawImage.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('data:image')) {
      final commaIndex = value.indexOf(',');
      if (commaIndex == -1) return null;
      final bytes = _decodeBase64Safe(value.substring(commaIndex + 1).trim());
      return bytes != null ? MemoryImage(bytes) : null;
    }
    if (_looksLikeBase64(value)) {
      final bytes = _decodeBase64Safe(value);
      return bytes != null ? MemoryImage(bytes) : null;
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return NetworkImage(value);
    }
    if (value.startsWith('//')) return NetworkImage('https:$value');
    if (value.startsWith('/')) {
      return NetworkImage('https://erp.elrace.com$value');
    }
    return NetworkImage('https://erp.elrace.com/$value');
  }

  Uint8List? _decodeBase64Safe(String value) {
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeBase64(String value) {
    if (value.length < 64 || value.contains(' ')) return false;
    final normalized = value.replaceAll('\n', '').replaceAll('\r', '');
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(normalized);
  }
}

class _MemberPickerSheet extends StatefulWidget {
  const _MemberPickerSheet({
    required this.title,
    required this.members,
    required this.selectedMembers,
    required this.onChanged,
    required this.imageProviderFor,
    required this.displayNameFor,
  });

  final String title;
  final List<TeamMember> members;
  final List<TeamMember> selectedMembers;
  final ValueChanged<List<TeamMember>> onChanged;
  final ImageProvider? Function(String? raw) imageProviderFor;
  final String Function(String raw) displayNameFor;

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  static const _accent = Color(0xFF4C8BF5);
  final _searchController = TextEditingController();
  late List<TeamMember> _filtered;
  late List<TeamMember> _selected;

  @override
  void initState() {
    super.initState();
    _filtered = List<TeamMember>.from(widget.members);
    _selected = List<TeamMember>.from(widget.selectedMembers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List<TeamMember>.from(widget.members)
          : widget.members.where((m) {
              final name = widget.displayNameFor(m.name).toLowerCase();
              return name.contains(q) ||
                  m.name.toLowerCase().contains(q) ||
                  (m.department ?? '').toLowerCase().contains(q);
            }).toList();
    });
  }

  void _toggle(TeamMember member) {
    setState(() {
      final i = _selected.indexWhere((m) => m.id == member.id);
      if (i >= 0) {
        _selected.removeAt(i);
      } else {
        _selected.add(member);
      }
    });
    widget.onChanged(List<TeamMember>.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.68,
        minChildSize: 0.42,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: ProductivityLightTheme.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ProductivityLightTheme.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (q) {
                      setState(() {});
                      _filter(q);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name or department',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: ProductivityLightTheme.iconChip,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final member = _filtered[index];
                      final selected =
                          _selected.any((m) => m.id == member.id);
                      final name = widget.displayNameFor(member.name);
                      final image = widget.imageProviderFor(member.image);
                      return ListTile(
                        onTap: () => _toggle(member),
                        leading: CircleAvatar(
                          backgroundColor: _accent.withValues(alpha: 0.12),
                          backgroundImage: image,
                          onBackgroundImageError:
                              image == null ? null : (_, __) {},
                          child: image == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _accent,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(name),
                        subtitle:
                            (member.department?.trim().isNotEmpty ?? false)
                                ? Text(member.department!.trim())
                                : null,
                        trailing: Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: selected
                              ? _accent
                              : ProductivityLightTheme.border,
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text(
                          _selected.isEmpty
                              ? 'Done'
                              : 'Done · ${_selected.length}',
                          style: GoogleFonts.roboto(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
