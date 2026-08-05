import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_shell.dart';
import 'package:el_race/ui/presentation/todo_list/data/todo_model.dart';
import 'package:el_race/ui/presentation/todo_list/data/task_member_model.dart';
import 'package:el_race/ui/presentation/todo_list/services/todo_firebase_service.dart';
import 'package:el_race/data/services/task_notification_service.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/report_detail.dart'
    as report_detail;
import 'package:el_race/ui/presentation/tickets/providers/ticket_firebase_provider.dart';
import 'package:el_race/ui/presentation/tickets/data/ticket_model.dart';
import 'package:el_race/ui/presentation/tickets/screens/ticket_details_screen.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_nav.dart';
import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';

class TaskDetailsScreen extends StatefulWidget {
  static const routeName = '/task-details';

  final TodoModel? task;
  final String? taskId;

  const TaskDetailsScreen({Key? key, this.task, this.taskId}) : super(key: key);

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  bool _isRecording = false;
  bool _isLoading = true;
  bool _isSendingComment = false;
  bool _isLoadingMemberPhotos = false;
  TodoModel? _task;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();

  Map<int, String> _memberPhotoById = {};

  // Audio recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;

  // Audio playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingCommentId;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadTask();
    _setupAudioPlayer();
    _loadMemberPhotos();
  }

  int? _extractLeadingId(String text) {
    final match = RegExp(r'^\s*(\d+)').firstMatch(text.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  String _initialsForDisplayName(String name) {
    final cleaned = name.replaceFirst(RegExp(r'^\s*\d+\s*'), '').trim();
    final parts =
        cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String? _photoUrlForDisplayName(String name) {
    final id = _extractLeadingId(name);
    if (id == null) return null;
    return _memberPhotoById[id];
  }

  Future<void> _loadMemberPhotos() async {
    if (_isLoadingMemberPhotos) return;
    setState(() => _isLoadingMemberPhotos = true);

    try {
      final members = await TeamMembersApiService.instance.getTeamMembers();
      final map = <int, String>{};
      for (final m in members) {
        final url = m.image?.trim();
        if (url != null && url.isNotEmpty) {
          map[m.id] = url;
        }
      }
      if (!mounted) return;
      setState(() => _memberPhotoById = map);
    } catch (_) {
      // ignore (fallback to initials)
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingMemberPhotos = false);
    }
  }

  Widget _buildAvatarForName(String name, {double size = 34}) {
    final url = _photoUrlForDisplayName(name);
    final initials = _initialsForDisplayName(name);

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: ProductivityLightTheme.iconChip,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: ProductivityLightTheme.iconChip,
      child: Text(
        initials,
        style: GoogleFonts.roboto(
          fontSize: size >= 40 ? 16 : 12,
          fontWeight: FontWeight.w700,
          color: ProductivityLightTheme.inkSecondary,
        ),
      ),
    );
  }

  /// Build avatar for comment with direct photo URL
  Widget _buildCommentAvatar(String name, String? photoUrl,
      {double size = 40}) {
    final initials = _initialsForDisplayName(name);

    // First try the direct photo URL from comment
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: ProductivityLightTheme.iconChip,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    // Fallback to member photo lookup by name
    final memberUrl = _photoUrlForDisplayName(name);
    if (memberUrl != null && memberUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: ProductivityLightTheme.iconChip,
        backgroundImage: NetworkImage(memberUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    // Default to initials
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: ProductivityLightTheme.iconChip,
      child: Text(
        initials,
        style: GoogleFonts.roboto(
          fontSize: size >= 40 ? 16 : 12,
          fontWeight: FontWeight.w700,
          color: ProductivityLightTheme.inkSecondary,
        ),
      ),
    );
  }

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _playingCommentId = null;
            _isPlaying = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ==================== AUDIO RECORDING ====================

  Future<void> _startRecording() async {
    try {
      // Request microphone permission explicitly
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Microphone permission is required for voice comments'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/voice_comment_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingPath = path;
        _recordingDuration = Duration.zero;
      });

      // Update duration every second
      _updateRecordingDuration();

      print('✅ Started recording: $path');
    } catch (e) {
      print('❌ Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _updateRecordingDuration() async {
    while (_isRecording) {
      await Future.delayed(Duration(seconds: 1));
      if (_isRecording && mounted) {
        setState(() {
          _recordingDuration += Duration(seconds: 1);
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        print('✅ Recording saved: $path');
        // Show confirmation dialog
        _showVoiceCommentDialog(path);
      }
    } catch (e) {
      print('❌ Error stopping recording: $e');
      setState(() => _isRecording = false);
    }
  }

  Future<void> _cancelRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDuration = Duration.zero;
      });
    } catch (e) {
      print('❌ Error cancelling recording: $e');
      setState(() => _isRecording = false);
    }
  }

  void _showVoiceCommentDialog(String audioPath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ProductivityLightTheme.boxRadius),
        ),
        title: Text(
          'Voice comment',
          style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic_none_rounded,
                size: 48, color: Color(0xFF4C8BF5)),
            const SizedBox(height: 12),
            Text(
              'Recording: ${_formatDuration(_recordingDuration)}',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: ProductivityLightTheme.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send this voice comment?',
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: ProductivityLightTheme.inkSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Delete the recording
              File(audioPath).deleteSync();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.roboto(
                color: ProductivityLightTheme.inkMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendVoiceComment(audioPath);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4C8BF5),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'Send',
              style: GoogleFonts.roboto(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendVoiceComment(String audioPath) async {
    if (_task?.firebaseId == null) return;

    setState(() => _isSendingComment = true);
    try {
      // Upload audio to Firebase Storage
      final file = File(audioPath);
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('voice_comments')
          .child(_task!.firebaseId!)
          .child(fileName);

      // Set metadata to ensure content type is audio
      final metadata = SettableMetadata(
        contentType: 'audio/mp4',
        customMetadata: {
          'uploaded_by': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
          'task_id': _task!.firebaseId!,
        },
      );

      await storageRef.putFile(file, metadata);
      final audioUrl = await storageRef.getDownloadURL();

      // Add comment with audio URL
      await TodoFirebaseService.instance.addVoiceComment(
        _task!.firebaseId!,
        audioUrl,
        _formatDuration(_recordingDuration),
        ownerUid: _task!.ownerUid,
      );

      // Delete local file
      file.deleteSync();

      await _loadComments();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Voice comment sent!'),
            backgroundColor: Color(0xFF4C8BF5)),
      );
    } catch (e) {
      print('❌ Error sending voice comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to send voice comment'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingComment = false;
          _recordingPath = null;
          _recordingDuration = Duration.zero;
        });
      }
    }
  }

  Future<void> _playVoiceComment(String commentId, String audioUrl) async {
    try {
      if (_playingCommentId == commentId && _isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        setState(() => _playingCommentId = commentId);
        await _audioPlayer.setUrl(audioUrl);
        await _audioPlayer.play();
      }
    } catch (e) {
      print('❌ Error playing voice comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to play audio'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer.stop();
    setState(() {
      _playingCommentId = null;
      _isPlaying = false;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _loadTask() async {
    if (widget.task != null) {
      setState(() {
        _task = widget.task;
        _isLoading = false;
      });
      _loadComments();
    } else if (widget.taskId != null) {
      try {
        final task =
            await TodoFirebaseService.instance.getTodoById(widget.taskId!);
        if (mounted) {
          setState(() {
            _task = task;
            _isLoading = false;
          });
          _loadComments();
        }
      } catch (e) {
        print('❌ Error loading task: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadComments() async {
    if (_task?.firebaseId == null) return;
    try {
      final comments = await TodoFirebaseService.instance.getComments(
        _task!.firebaseId!,
        ownerUid: _task!.ownerUid,
      );
      if (mounted) {
        setState(() => _comments = comments);
      }
    } catch (e) {
      print('❌ Error loading comments: $e');
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _task?.firebaseId == null) return;

    setState(() => _isSendingComment = true);
    try {
      await TodoFirebaseService.instance.addComment(
        _task!.firebaseId!,
        content,
        ownerUid: _task!.ownerUid,
      );
      _commentController.clear();
      await _loadComments();

      // Fire new-message notification
      try {
        final senderName = TodoFirebaseService.instance.currentUserNamePublic;
        await TaskNotificationService().showTaskMessageNotification(
          taskId: _task!.firebaseId!,
          taskTitle: _task!.title,
          senderName: senderName,
          messagePreview:
              content.length > 80 ? '${content.substring(0, 80)}...' : content,
        );
      } catch (_) {}
    } catch (e) {
      print('❌ Error sending comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to send comment'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _toggleMemberCompletion(
      TaskMember member, bool isAssigned) async {
    if (_task?.firebaseId == null) return;

    final newStatus = !member.isCompleted;

    try {
      await TodoFirebaseService.instance.updateMemberStatus(
        _task!.firebaseId!,
        member.name,
        newStatus,
        isAssigned: isAssigned,
        ownerUid: _task!.ownerUid,
      );

      // Reload task to get updated data
      await _loadTask();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? '${member.firstName} marked as complete'
                : '${member.firstName} marked as incomplete',
          ),
          backgroundColor: newStatus
              ? ProductivityLightTheme.progressFill
              : ProductivityLightTheme.accentPending,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error updating member status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to update status'),
            backgroundColor: Colors.red),
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('HH:mm').format(date);
  }

  String _formatCommentTime(dynamic timestamp) {
    if (timestamp == null) return '-';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return '-';
    }
    return '${DateFormat('HH:mm').format(date)}\n${DateFormat('dd/MM/yyyy').format(date)}';
  }

  /// Get first name from full name
  String _getFirstName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return '';
    final parts = fullName.split(' ');
    return parts.first;
  }

  /// Get initials from name
  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'U';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ProductivityLightShell(
        showBack: true,
        centerTitle: true,
        title: 'Task details',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_task == null) {
      return ProductivityLightShell(
        showBack: true,
        centerTitle: true,
        title: 'Task details',
        body: Center(
          child: Text(
            'Task not found',
            style: ProductivityLightTheme.cardSubtitle,
          ),
        ),
      );
    }

    final task = _task!;

    return ProductivityLightShell(
      showBack: true,
      centerTitle: true,
      title: 'Task details',
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                _buildHeaderSection(task),
                const SizedBox(height: 12),
                if (task.description != null &&
                    task.description!.trim().isNotEmpty) ...[
                  _sectionCard(
                    title: 'Description',
                    child: Text(
                      task.description!,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        height: 1.45,
                        color: ProductivityLightTheme.inkSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildProgressCard(task),
                if (task.reportId != null && task.reportId!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildLinkedReportSection(task.reportId!),
                ],
                const SizedBox(height: 12),
                _buildLinkedTicketsSection(task),
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'Attachments',
                  child: (task.attachments != null &&
                          task.attachments!.isNotEmpty)
                      ? _buildAttachmentsList(task.attachments!)
                      : Text(
                          'No attachments',
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: ProductivityLightTheme.inkMuted,
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'Assigned members',
                  child: (task.assignedMembers != null &&
                          task.assignedMembers!.isNotEmpty)
                      ? _buildTaskMembersList(
                          task.assignedMembers!,
                          isAssigned: true,
                        )
                      : (task.assignedToName != null &&
                              task.assignedToName!.isNotEmpty)
                          ? _buildMembersList(
                              task.assignedToName!.split(', '),
                            )
                          : Text(
                              'No members assigned',
                              style: GoogleFonts.roboto(
                                fontSize: 13,
                                color: ProductivityLightTheme.inkMuted,
                              ),
                            ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'Followed up',
                  child: (task.followedUpBy != null &&
                          task.followedUpBy!.isNotEmpty)
                      ? _buildTaskMembersList(
                          task.followedUpBy!,
                          isAssigned: false,
                        )
                      : (task.followers != null && task.followers!.isNotEmpty)
                          ? _buildMembersList(task.followers!)
                          : Text(
                              'No followers',
                              style: GoogleFonts.roboto(
                                fontSize: 13,
                                color: ProductivityLightTheme.inkMuted,
                              ),
                            ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  title: 'Comments',
                  child: _comments.isNotEmpty
                      ? Column(
                          children: [
                            for (final comment in _comments) ...[
                              _buildCommentItem(comment),
                              const SizedBox(height: 12),
                            ],
                          ],
                        )
                      : Text(
                          'No comments yet',
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: ProductivityLightTheme.inkMuted,
                          ),
                        ),
                ),
                const SizedBox(height: 88),
              ],
            ),
          ),
          _buildBottomBar(task),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(TodoModel task) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      decoration: BoxDecoration(
        color: ProductivityLightTheme.card,
        borderRadius: BorderRadius.circular(ProductivityLightTheme.boxRadius),
        border: Border.all(color: ProductivityLightTheme.border),
      ),
      child: Column(
        children: [
          Text(
            task.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: ProductivityLightTheme.ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusPill(
                task.isCompleted ? 'Completed' : 'In progress',
                task.isCompleted
                    ? ProductivityLightTheme.statusCompletedBg
                    : ProductivityLightTheme.statusActiveBg,
              ),
              if (task.project != null && task.project!.trim().isNotEmpty)
                _statusPill(
                  task.project!,
                  ProductivityLightTheme.washBlue,
                ),
              if (task.department != null &&
                  task.department!.trim().isNotEmpty)
                _statusPill(
                  task.department!,
                  ProductivityLightTheme.washBlue,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _dateColumn(
                  label: 'Start date',
                  value: _formatDate(task.startDate),
                  accent: ProductivityLightTheme.accentActive,
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: ProductivityLightTheme.border,
              ),
              Expanded(
                child: _dateColumn(
                  label: 'End date',
                  value: _formatDate(task.dueDate),
                  accent: ProductivityLightTheme.accentEnded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Updated ${_formatDate(task.updatedAt)} · ${_formatTime(task.updatedAt)}',
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: ProductivityLightTheme.inkMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ProductivityLightTheme.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ProductivityLightTheme.ink,
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProductivityLightTheme.card,
        borderRadius: BorderRadius.circular(ProductivityLightTheme.boxRadius),
        border: Border.all(color: ProductivityLightTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ProductivityLightTheme.ink,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildProgressCard(TodoModel task) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProductivityLightTheme.card,
        borderRadius: BorderRadius.circular(ProductivityLightTheme.boxRadius),
        border: Border.all(color: ProductivityLightTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress',
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ProductivityLightTheme.ink,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: task.progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: ProductivityLightTheme.progressTrack,
              valueColor: const AlwaysStoppedAnimation<Color>(
                ProductivityLightTheme.progressFill,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${task.progressText} complete',
            style: GoogleFonts.roboto(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ProductivityLightTheme.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(TodoModel task) {
    return Material(
      color: ProductivityLightTheme.card,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: ProductivityLightTheme.iconChip,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: ProductivityLightTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Write a comment',
                          hintStyle: GoogleFonts.roboto(
                            color: ProductivityLightTheme.inkMuted,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                        ),
                        style: GoogleFonts.roboto(
                          color: ProductivityLightTheme.ink,
                          fontSize: 14,
                        ),
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                    if (_isRecording)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Color(0xFFE11D48),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDuration(_recordingDuration),
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: const Color(0xFFE11D48),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _cancelRecording,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: ProductivityLightTheme.inkMuted,
                            ),
                          ),
                          IconButton(
                            onPressed: _stopRecording,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFE11D48),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.stop_rounded, size: 20),
                          ),
                        ],
                      )
                    else ...[
                      IconButton(
                        onPressed: _startRecording,
                        icon: const Icon(
                          Icons.mic_none_rounded,
                          color: ProductivityLightTheme.inkSecondary,
                        ),
                      ),
                      IconButton(
                        onPressed: _isSendingComment ? null : _sendComment,
                        icon: _isSendingComment
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Color(0xFF4C8BF5),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      task.isCompleted ? null : () => _toggleComplete(task),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: task.isCompleted
                        ? ProductivityLightTheme.inkMuted
                        : const Color(0xFF4C8BF5),
                    disabledBackgroundColor: ProductivityLightTheme.inkSoft,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    task.isCompleted ? 'Completed' : 'Mark complete',
                    style: GoogleFonts.roboto(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleComplete(TodoModel task) async {
    // Prevent toggling if already completed
    if (task.isCompleted) {
      return;
    }

    try {
      final updatedTask = task.copyWith(
        isCompleted: true,
        updatedAt: DateTime.now(),
      );
      await TodoFirebaseService.instance.updateTodo(updatedTask);
      setState(() {
        _task = updatedTask;
      });

      // Fire task-completed notification
      try {
        await TaskNotificationService().showTaskCompletedNotification(
          taskId: task.firebaseId ?? '',
          taskTitle: task.title,
        );
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Task marked as complete!',
            style: GoogleFonts.roboto(),
          ),
          backgroundColor: const Color(0xFF4C8BF5),
        ),
      );
    } catch (e) {
      print('❌ Error updating task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _dateColumn({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: accent,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ProductivityLightTheme.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildMembersList(List<String> members) {
    final cleaned = members.where((m) => m.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cleaned
            .map(
              (name) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _buildMemberChip(name),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTaskMembersList(List<TaskMember> members,
      {required bool isAssigned}) {
    if (members.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: members
            .map(
              (member) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _buildTaskMemberChip(member, isAssigned: isAssigned),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTaskMemberChip(TaskMember member, {required bool isAssigned}) {
    return InkWell(
      onTap: () => _toggleMemberCompletion(member, isAssigned),
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          _buildAvatarForName(member.name, size: 44),
          if (member.isCompleted)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: ProductivityLightTheme.progressFill,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberChip(String name) {
    final trimmed = name.trim();

    return _buildAvatarForName(trimmed, size: 44);
  }

  Widget _buildAttachmentsList(List<String> attachments) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments
          .map((attachment) => InkWell(
                onTap: () => _openAttachment(attachment),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: ProductivityLightTheme.iconChip,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ProductivityLightTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.attach_file_rounded,
                        size: 16,
                        color: Color(0xFF4C8BF5),
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          attachment,
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: ProductivityLightTheme.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: ProductivityLightTheme.inkMuted,
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Future<void> _openAttachment(String attachment) async {
    try {
      Uri? uri;

      // Check if it's already a URL
      if (attachment.startsWith('http://') ||
          attachment.startsWith('https://')) {
        uri = Uri.parse(attachment);
      } else {
        // Try to get download URL from Firebase Storage
        if (_task?.firebaseId != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Opening attachment...'),
                  ],
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }

          try {
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('tasks/${_task!.firebaseId}/attachments/$attachment');
            final url = await storageRef.getDownloadURL();
            uri = Uri.parse(url);
          } catch (storageError) {
            print('❌ Firebase Storage error: $storageError');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Attachment not uploaded to storage yet'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
            return;
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Cannot open local file: $attachment'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }

      // Try to launch the URL
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open this attachment')),
          );
        }
      }
    } catch (e) {
      print('❌ Error opening attachment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Unable to open attachment')),
        );
      }
    }
  }

  Widget _buildLinkedTicketsSection(TodoModel task) {
    final taskId = task.firebaseId;
    if (taskId == null || taskId.isEmpty) {
      return const SizedBox.shrink();
    }
    return Consumer<TicketFirebaseProvider>(
      builder: (context, ticketsProvider, _) {
        final linked = ticketsProvider.ticketsForTask(taskId);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ProductivityLightTheme.card,
            borderRadius:
                BorderRadius.circular(ProductivityLightTheme.boxRadius),
            border: Border.all(color: ProductivityLightTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Tickets (${linked.length})',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ProductivityLightTheme.ink,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ProductivityNav.goAddTicket(
                        context,
                        parentTaskId: taskId,
                        parentTaskTitle: task.title,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4C8BF5),
                      textStyle: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Add ticket'),
                  ),
                ],
              ),
              if (linked.isEmpty)
                Text(
                  'No tickets linked to this task',
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: ProductivityLightTheme.inkMuted,
                  ),
                )
              else
                ...linked.map(
                  (t) => InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TicketDetailsScreen(ticketId: t.firebaseId!),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: ProductivityLightTheme.iconChip,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: ProductivityLightTheme.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: ProductivityLightTheme.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${t.status.label} · ${t.priority.label}',
                                  style: GoogleFonts.roboto(
                                    fontSize: 12,
                                    color: ProductivityLightTheme.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: ProductivityLightTheme.inkMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinkedReportSection(String reportId) {
    return FutureBuilder<ReportModel?>(
      future: _fetchReportById(reportId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ProductivityLightTheme.card,
              borderRadius:
                  BorderRadius.circular(ProductivityLightTheme.boxRadius),
              border: Border.all(color: ProductivityLightTheme.border),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF4C8BF5),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading linked report...',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: ProductivityLightTheme.inkSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        final report = snapshot.data;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ProductivityLightTheme.card,
            borderRadius:
                BorderRadius.circular(ProductivityLightTheme.boxRadius),
            border: Border.all(color: ProductivityLightTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Linked report',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ProductivityLightTheme.ink,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: report != null ? () => _openLinkedReport(report) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: ProductivityLightTheme.iconChip,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ProductivityLightTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ProductivityLightTheme.washBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          color: Color(0xFF4C8BF5),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report?.name ?? 'Report #$reportId',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: ProductivityLightTheme.ink,
                              ),
                            ),
                            if (report != null)
                              Text(
                                'Created: ${DateFormat('dd MMM yyyy').format(report.createdAt)}',
                                style: GoogleFonts.roboto(
                                  fontSize: 11,
                                  color: ProductivityLightTheme.inkMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: ProductivityLightTheme.inkMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<ReportModel?> _fetchReportById(String reportId) async {
    try {
      final reportsProvider =
          Provider.of<ReportProvider>(context, listen: false);
      // Search in cached reports first
      for (var report in reportsProvider.reports) {
        if (report.id == reportId) {
          return report;
        }
      }
      // If not found, return null (report might have been deleted)
      return null;
    } catch (e) {
      print('❌ Error fetching report: $e');
      return null;
    }
  }

  void _openLinkedReport(ReportModel report) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => report_detail.ReportDetailScreen(
          report: report,
          folderName: '', // Will be loaded inside the screen
        ),
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> commentData) {
    final name = commentData['author_name'] as String? ?? 'Unknown';
    final content = commentData['content'] as String? ?? '';
    final time = _formatCommentTime(commentData['created_at']);
    final type = commentData['type'] as String? ?? 'text';
    final audioUrl = commentData['audio_url'] as String?;
    final commentId = commentData['id'] as String? ?? '';
    final duration = commentData['duration'] as String? ?? '00:00';
    final authorPhoto = commentData['author_photo'] as String?;

    final displayName = name.isNotEmpty ? name : 'Unknown';
    final isVoice = type == 'voice' && audioUrl != null;
    final isCurrentlyPlaying = _playingCommentId == commentId && _isPlaying;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentAvatar(displayName, authorPhoto, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ProductivityLightTheme.ink,
                      ),
                    ),
                  ),
                  Text(
                    time,
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      color: ProductivityLightTheme.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (isVoice)
                GestureDetector(
                  onTap: () => _playVoiceComment(commentId, audioUrl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentlyPlaying
                          ? ProductivityLightTheme.statusActiveBg
                          : ProductivityLightTheme.iconChip,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrentlyPlaying
                            ? ProductivityLightTheme.progressFill
                            : ProductivityLightTheme.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCurrentlyPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 28,
                          color: isCurrentlyPlaying
                              ? ProductivityLightTheme.progressFill
                              : ProductivityLightTheme.inkSecondary,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice message',
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ProductivityLightTheme.ink,
                              ),
                            ),
                            Text(
                              duration,
                              style: GoogleFonts.roboto(
                                fontSize: 11,
                                color: ProductivityLightTheme.inkMuted,
                              ),
                            ),
                          ],
                        ),
                        if (isCurrentlyPlaying) ...[
                          const SizedBox(width: 12),
                          const SizedBox(
                            width: 60,
                            child: LinearProgressIndicator(
                              backgroundColor:
                                  ProductivityLightTheme.progressTrack,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ProductivityLightTheme.progressFill,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Text(
                  content,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    height: 1.4,
                    color: ProductivityLightTheme.inkSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
