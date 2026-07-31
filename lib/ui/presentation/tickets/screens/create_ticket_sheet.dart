import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_shell.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_searchable_picker.dart';
import 'package:el_race/ui/presentation/tickets/data/ticket_model.dart';
import 'package:el_race/ui/presentation/tickets/providers/ticket_firebase_provider.dart';
import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:el_race/ui/presentation/todo_list/providers/todo_firebase_provider.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CreateTicketSheet {
  /// Opens the themed full-screen create-ticket form.
  static Future<void> show(
    BuildContext context, {
    String? parentTaskId,
    String? parentTaskTitle,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CreateTicketScreen(
          parentTaskId: parentTaskId,
          parentTaskTitle: parentTaskTitle,
        ),
      ),
    );
  }
}

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({
    super.key,
    this.parentTaskId,
    this.parentTaskTitle,
  });

  final String? parentTaskId;
  final String? parentTaskTitle;

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  static const _accent = Color(0xFF4C8BF5);
  static const _fieldBorder = Color(0xFFE6E8EC);
  static const _fieldRadius = 12.0;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  TicketPriority _priority = TicketPriority.medium;
  TeamMember? _assignee;
  String? _selectedParentId;
  String? _selectedParentTitle;
  ReportModel? _selectedReport;

  List<TeamMember> _members = [];
  bool _loadingMembers = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedParentId = widget.parentTaskId;
    _selectedParentTitle = widget.parentTaskTitle;
    _loadMembers();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await TeamMembersApiService.instance.getTeamMembers();
      if (!mounted) return;
      setState(() {
        _members = members;
        _loadingMembers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMembers = false);
    }
  }

  String get _parentLabel {
    if (_selectedParentId == null) return 'Standalone (no parent)';
    return _selectedParentTitle ?? 'Selected task';
  }

  Future<void> _pickPriority() async {
    final picked = await ProductivitySearchablePicker.show<TicketPriority>(
      context,
      title: 'Priority',
      items: TicketPriority.values,
      labelOf: (p) => p.label,
      selected: _priority,
    );
    if (picked != null && mounted) setState(() => _priority = picked);
  }

  Future<void> _pickAssignee() async {
    final picked = await ProductivitySearchablePicker.show<TeamMember>(
      context,
      title: 'Assignee',
      items: _members,
      labelOf: (m) => m.name,
      selected: _assignee,
      allowClear: true,
      clearLabel: 'Unassigned',
    );
    if (!mounted) return;
    setState(() => _assignee = picked);
  }

  Future<void> _pickParentTask() async {
    final todos = context.read<TodoFirebaseProvider>().todos;
    final options =
        todos.where((t) => t.firebaseId != null).toList(growable: false);
    final current = options
        .where((t) => t.firebaseId == _selectedParentId)
        .cast<TodoModel?>()
        .firstOrNull;
    final picked = await ProductivitySearchablePicker.show<TodoModel>(
      context,
      title: 'Parent task',
      items: options,
      labelOf: (t) => t.title,
      selected: current,
      allowClear: true,
      clearLabel: 'Standalone (no parent)',
    );
    if (!mounted) return;
    setState(() {
      if (picked == null) {
        _selectedParentId = null;
        _selectedParentTitle = null;
      } else {
        _selectedParentId = picked.firebaseId;
        _selectedParentTitle = picked.title;
      }
    });
  }

  Future<void> _pickReport() async {
    final reports = context.read<ReportProvider>().reports;
    final picked = await ProductivitySearchablePicker.show<ReportModel>(
      context,
      title: 'Link report',
      items: reports,
      labelOf: (r) => r.name,
      selected: _selectedReport,
      allowClear: true,
    );
    if (!mounted) return;
    setState(() => _selectedReport = picked);
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final provider = context.read<TicketFirebaseProvider>();
    final created = await provider.createTicket(
      title: title,
      description: _descCtrl.text.trim(),
      priority: _priority,
      assigneeId: _assignee?.id.toString(),
      assigneeName: _assignee?.name,
      parentTaskId: _selectedParentId,
      parentTaskTitle: _selectedParentTitle,
      reportIds:
          _selectedReport != null ? [_selectedReport!.id] : const <String>[],
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to create ticket'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ticket created'),
        backgroundColor: Color(0xFF4C8BF5),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<ReportProvider>().reports;

    return ProductivityLightShell(
      showBack: false,
      centerTitle: true,
      title: 'Create ticket',
      titleTrailing: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(
          Icons.close_rounded,
          color: ProductivityLightTheme.ink,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                _label('Title'),
                const SizedBox(height: 8),
                _textField(
                  controller: _titleCtrl,
                  hint: 'Enter ticket title',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                _label('Description'),
                const SizedBox(height: 8),
                _textField(
                  controller: _descCtrl,
                  hint: 'Describe the issue',
                  maxLines: 4,
                ),
                const SizedBox(height: 14),
                _label('Priority'),
                const SizedBox(height: 8),
                _selectTile(
                  value: _priority.label,
                  onTap: _pickPriority,
                ),
                const SizedBox(height: 14),
                _label('Assignee'),
                const SizedBox(height: 8),
                _selectTile(
                  loading: _loadingMembers,
                  value: _assignee?.name,
                  placeholder: 'Unassigned',
                  onTap: _loadingMembers ? null : _pickAssignee,
                  onClear: _assignee == null
                      ? null
                      : () => setState(() => _assignee = null),
                ),
                const SizedBox(height: 14),
                _label('Parent task'),
                const SizedBox(height: 8),
                _selectTile(
                  value: _selectedParentId == null ? null : _parentLabel,
                  placeholder: 'Standalone (no parent)',
                  onTap: _pickParentTask,
                  onClear: _selectedParentId == null
                      ? null
                      : () => setState(() {
                            _selectedParentId = null;
                            _selectedParentTitle = null;
                          }),
                ),
                if (reports.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _label('Link report (optional)'),
                  const SizedBox(height: 8),
                  _selectTile(
                    value: _selectedReport?.name,
                    placeholder: 'None',
                    onTap: _pickReport,
                    onClear: _selectedReport == null
                        ? null
                        : () => setState(() => _selectedReport = null),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
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
                          'Create ticket',
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

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.roboto(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ProductivityLightTheme.inkSecondary,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textInputAction: textInputAction,
      style: GoogleFonts.roboto(
        fontSize: 15,
        color: ProductivityLightTheme.ink,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.roboto(
          color: ProductivityLightTheme.inkMuted,
          fontSize: 15,
        ),
        filled: true,
        fillColor: ProductivityLightTheme.iconChip,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      ),
    );
  }

  Widget _selectTile({
    required VoidCallback? onTap,
    String? value,
    String placeholder = 'Select',
    bool loading = false,
    VoidCallback? onClear,
  }) {
    final hasValue = value != null && value.trim().isNotEmpty;
    return Material(
      color: ProductivityLightTheme.iconChip,
      borderRadius: BorderRadius.circular(_fieldRadius),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(_fieldRadius),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_fieldRadius),
            border: Border.all(color: _fieldBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: loading
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Text(
                        hasValue ? value : placeholder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight:
                              hasValue ? FontWeight.w600 : FontWeight.w400,
                          color: hasValue
                              ? ProductivityLightTheme.ink
                              : ProductivityLightTheme.inkMuted,
                        ),
                      ),
              ),
              if (onClear != null && hasValue)
                IconButton(
                  onPressed: onClear,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: ProductivityLightTheme.inkMuted,
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
}
