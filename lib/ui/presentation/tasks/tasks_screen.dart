import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_shell.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_widgets.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_sober_card.dart';
import 'package:el_race/ui/presentation/tasks/data/task_model.dart';
import 'package:el_race/ui/presentation/tasks/logic/tasks_provider.dart';
import 'package:el_race/ui/presentation/tasks/task_details_screen.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, this.highPriorityOnly = false});

  final bool highPriorityOnly;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static bool _isHighPriority(String? priority) => priority == '1';

  /// Optional home deep-link scope only — no in-screen filter chips.
  List<TaskModel> _scoped(List<TaskModel> items) {
    if (!widget.highPriorityOnly) return items;
    return items
        .where((t) => !t.isCompleted && _isHighPriority(t.priority))
        .toList();
  }

  Future<void> _showCreateTaskSheet(
    BuildContext context,
    TasksProvider provider,
  ) async {
    if (provider.assignableUsers.isEmpty && !provider.isLoadingUsers) {
      await provider.loadAssignableUsers();
      if (provider.errorMessage != null && context.mounted) {
        Fluttertoast.showToast(
          msg: provider.errorMessage!,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    }

    final nameController = TextEditingController();
    final descController = TextEditingController();
    final commentController = TextEditingController();
    String priority = '1';
    int? selectedUserId;
    String? attachmentBase64;
    String? attachmentFilename;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickAttachment() async {
                final result = await FilePicker.pickFiles(
                  allowMultiple: false,
                  type: FileType.custom,
                  allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
                  withData: true,
                );

                if (result != null && result.files.isNotEmpty) {
                  final file = result.files.first;
                  final bytes = file.bytes ??
                      (file.path != null
                          ? await File(file.path!).readAsBytes()
                          : null);
                  if (bytes != null) {
                    setModalState(() {
                      attachmentBase64 = base64Encode(bytes);
                      attachmentFilename = file.name;
                    });
                  }
                }
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.confirmation_number_outlined,
                            color: appFontColor, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Create Ticket',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Ticket Title',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Enter ticket title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Description',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Write your description...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Comment',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add a comment (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: priority,
                            decoration: InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: '1', child: Text('High')),
                              DropdownMenuItem(
                                  value: '2', child: Text('Medium')),
                              DropdownMenuItem(
                                  value: '3', child: Text('Low')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => priority = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: provider.isLoadingUsers
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  value: selectedUserId,
                                  decoration: InputDecoration(
                                    labelText: 'Assign to',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                  ),
                                  items: provider.assignableUsers
                                      .map(
                                        (u) => DropdownMenuItem(
                                          value: u.id,
                                          child: Text(
                                            u.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) =>
                                      setModalState(() => selectedUserId = val),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickAttachment,
                            icon: const Icon(Icons.attach_file),
                            label: Text(
                              attachmentFilename ?? 'Add file',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (attachmentFilename != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setModalState(() {
                                attachmentBase64 = null;
                                attachmentFilename = null;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: provider.isCreating
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty) {
                                  Fluttertoast.showToast(
                                    msg: 'Name is required',
                                    backgroundColor: Colors.red,
                                    textColor: Colors.white,
                                  );
                                  return;
                                }

                                int? userIdToAssign = selectedUserId;
                                if (userIdToAssign == null) {
                                  final uid = SharedPref.getLoginData()
                                      .result
                                      ?.data
                                      ?.uid;
                                  if (uid != null) userIdToAssign = uid;
                                }

                                final createdTask = await provider.createTask(
                                  name: nameController.text.trim(),
                                  description: descController.text.trim(),
                                  priority: priority,
                                  userId: userIdToAssign,
                                  comment: commentController.text.trim().isEmpty
                                      ? null
                                      : commentController.text.trim(),
                                  attachmentBase64: attachmentBase64,
                                  attachmentFilename: attachmentFilename,
                                );

                                if (context.mounted) {
                                  if (createdTask != null) {
                                    Navigator.pop(context);
                                    Fluttertoast.showToast(
                                      msg:
                                          'Ticket "${createdTask.name ?? ''}" created',
                                      backgroundColor: Colors.green,
                                      textColor: Colors.white,
                                    );
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TaskDetailsScreen(
                                          task: createdTask,
                                        ),
                                      ),
                                    );
                                  } else if (provider.errorMessage != null) {
                                    Fluttertoast.showToast(
                                      msg: provider.errorMessage!,
                                      backgroundColor: Colors.red,
                                      textColor: Colors.white,
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ProductivityLightTheme.ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: provider.isCreating
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Create Ticket',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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
      },
    );

    nameController.dispose();
    descController.dispose();
    commentController.dispose();
  }

  Future<void> _showLinkReportDialog(
    BuildContext context,
    TasksProvider provider,
    TaskModel task,
  ) async {
    final reportProvider = context.read<ReportProvider>();

    if (reportProvider.reports.isEmpty) {
      Fluttertoast.showToast(
        msg: 'No reports found. Please create or load reports first.',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    final linkedIds = task.reportIds.map((r) => r.toString()).toSet();
    final availableReports = reportProvider.reports
        .where((r) => !linkedIds.contains(r.id.toString()))
        .toList();

    if (availableReports.isEmpty) {
      Fluttertoast.showToast(
        msg: 'All reports are already linked to this ticket',
        backgroundColor: Colors.blue,
        textColor: Colors.white,
      );
      return;
    }

    String? selectedReportId = availableReports.first.id.toString();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Link report'),
              content: DropdownButtonFormField<String>(
                value: selectedReportId,
                decoration: const InputDecoration(labelText: 'Report'),
                items: availableReports
                    .map((r) => DropdownMenuItem(
                          value: r.id.toString(),
                          child: Text(r.name),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setDialogState(() => selectedReportId = val),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedReportId == null
                      ? null
                      : () async {
                          final msg = await provider.linkReport(
                            taskId: task.id!,
                            reportId: selectedReportId!,
                          );
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            if (msg != null) {
                              Fluttertoast.showToast(
                                msg: msg,
                                backgroundColor: Colors.green,
                                textColor: Colors.white,
                              );
                            } else if (provider.errorMessage != null) {
                              Fluttertoast.showToast(
                                msg: provider.errorMessage!,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                              );
                            }
                          }
                        },
                  child: const Text('Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<TaskModel> _latestFive(List<TaskModel> items) {
    final sorted = List<TaskModel>.from(items)
      ..sort((a, b) {
        final aAt = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bAt.compareTo(aAt);
      });
    return sorted.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TasksProvider, ReportProvider>(
      builder: (context, tasksProvider, reportProvider, _) {
        if (tasksProvider.status == TasksStatus.initial) {
          Future.microtask(tasksProvider.loadTasks);
          Future.microtask(tasksProvider.loadAssignableUsers);
        }

        final all = tasksProvider.tasks;
        final total = all.length;
        final pending = all.where((t) => !t.isCompleted).length;
        final active = all
            .where((t) => !t.isCompleted && _isHighPriority(t.priority))
            .length;
        final ended = all.where((t) => t.isCompleted).length;
        final visible = _latestFive(_scoped(all));

        Widget body;
        switch (tasksProvider.status) {
          case TasksStatus.loading:
          case TasksStatus.initial:
            body = const Center(child: CircularProgressIndicator());
            break;
          case TasksStatus.error:
            body = _ErrorState(
              message: tasksProvider.errorMessage ?? 'Failed to load tickets.',
              onRetry: tasksProvider.loadTasks,
            );
            break;
          case TasksStatus.empty:
          case TasksStatus.loaded:
            body = RefreshIndicator(
              onRefresh: tasksProvider.refreshTasks,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(
                    child: ProductivityLightHero(
                      eyebrow: 'Get Focused',
                      title: 'Stay On Top!',
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ProductivityStatsGrid(
                      items: [
                        ProductivityStatItem(
                          label: 'Total Ticket',
                          value: total,
                          icon: Icons.confirmation_number_outlined,
                          accent: ProductivityLightTheme.accentTotal,
                          sparkHighlightStart: 3,
                          sparkHighlightEnd: 5,
                        ),
                        ProductivityStatItem(
                          label: 'Pending Ticket',
                          value: pending,
                          icon: Icons.description_outlined,
                          accent: ProductivityLightTheme.accentPending,
                          sparkHighlightStart: 5,
                          sparkHighlightEnd: 7,
                        ),
                        ProductivityStatItem(
                          label: 'Active Ticket',
                          value: active,
                          icon: Icons.priority_high_rounded,
                          accent: ProductivityLightTheme.accentActive,
                          sparkHighlightStart: 4,
                          sparkHighlightEnd: 6,
                        ),
                        ProductivityStatItem(
                          label: 'Ended Ticket',
                          value: ended,
                          icon: Icons.task_alt_outlined,
                          accent: ProductivityLightTheme.accentEnded,
                          sparkHighlightStart: 2,
                          sparkHighlightEnd: 5,
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 4),
                      child: Text(
                        'Currently Tickets',
                        style: ProductivityLightTheme.sectionLabel,
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        highPriorityOnly: widget.highPriorityOnly,
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final task = visible[index];
                          return _TicketSoberCard(
                            task: task,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TaskDetailsScreen(task: task),
                                ),
                              ).then((_) {
                                if (context.mounted) {
                                  tasksProvider.refreshTasks();
                                }
                              });
                            },
                            onAction: (value) async {
                              final id = task.id;
                              if (id == null) return;
                              switch (value) {
                                case 'link':
                                  await _showLinkReportDialog(
                                    context,
                                    tasksProvider,
                                    task,
                                  );
                                  break;
                                case 'complete':
                                  final msg =
                                      await tasksProvider.completeTask(id);
                                  if (context.mounted && msg != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg)),
                                    );
                                  }
                                  break;
                                case 'delete':
                                  final msg =
                                      await tasksProvider.deleteTask(id);
                                  if (context.mounted && msg != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg)),
                                    );
                                  }
                                  break;
                              }
                            },
                          );
                        },
                        childCount: visible.length,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 88)),
                ],
              ),
            );
            break;
        }

        return ProductivityLightShell(
          showBack: true,
          title: 'Tickets',
          body: body,
        );
      },
    );
  }
}

class _TicketSoberCard extends StatelessWidget {
  const _TicketSoberCard({
    required this.task,
    required this.onTap,
    required this.onAction,
  });

  final TaskModel task;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  Widget _initialAvatar(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEFEFEF),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: ProductivityLightTheme.ink,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    late final String statusLabel;
    late final Color statusBg;
    if (task.isCompleted) {
      statusLabel = 'Completed';
      statusBg = ProductivityLightTheme.statusCompletedBg;
    } else if (task.priority == '1') {
      statusLabel = 'High';
      statusBg = ProductivityLightTheme.statusActiveBg;
    } else {
      statusLabel = 'Open';
      statusBg = ProductivityLightTheme.statusPendingBg;
    }

    final assignee = (task.assignedUser ?? '').trim();
    final dateText = task.createdAt != null
        ? DateFormat('MMM d').format(task.createdAt!)
        : null;

    return ProductivitySoberCard(
          title: task.name ?? 'Untitled Ticket',
          statusLabel: statusLabel,
          statusBackground: statusBg,
          leadingAvatar:
              assignee.isNotEmpty ? _initialAvatar(assignee) : null,
          subtitle: assignee.isNotEmpty ? assignee : 'Unassigned',
          dateText: dateText,
          onTap: onTap,
          titleTrailing: PopupMenuButton<String>(
            tooltip: 'Ticket actions',
            padding: EdgeInsets.zero,
            onSelected: onAction,
            itemBuilder: (context) => [
              if (!task.isCompleted)
                const PopupMenuItem(value: 'link', child: Text('Link report')),
              if (!task.isCompleted)
                const PopupMenuItem(value: 'complete', child: Text('Complete')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            child: const Icon(
              Icons.more_horiz,
              color: ProductivityLightTheme.inkSoft,
            ),
          ),
        );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.highPriorityOnly = false});

  final bool highPriorityOnly;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            highPriorityOnly
                ? Icons.priority_high_rounded
                : Icons.confirmation_number_outlined,
            size: 56,
            color: ProductivityLightTheme.inkSoft,
          ),
          const SizedBox(height: 12),
          Text(
            highPriorityOnly
                ? 'No high-priority tickets'
                : 'No tickets available',
            style: ProductivityLightTheme.cardSubtitle.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: ProductivityLightTheme.cardSubtitle,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: ProductivityLightTheme.ink,
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
