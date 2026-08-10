import 'dart:math' as math;

import 'package:el_race/ui/presentation/my_notes/bloc/notes_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/repository/firebase_notes_repository.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_chat_resolve.dart';
import 'package:el_race/ui/presentation/todo_list/services/team_members_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared Folders–style view-only share sheet for a note.
Future<NoteModel?> showNotesShareSheet(
  BuildContext context, {
  required NoteModel note,
}) {
  return showModalBottomSheet<NoteModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NotesTheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (ctx) => BlocProvider.value(
      value: context.read<NotesBloc>(),
      child: _NotesShareSheetBody(note: note),
    ),
  );
}

class _NotesShareSheetBody extends StatefulWidget {
  final NoteModel note;

  const _NotesShareSheetBody({required this.note});

  @override
  State<_NotesShareSheetBody> createState() => _NotesShareSheetBodyState();
}

class _NotesShareSheetBodyState extends State<_NotesShareSheetBody> {
  late NoteModel _note;
  final _repo = FirebaseNotesRepository();
  bool _loadingMembers = false;
  List<TeamMember> _team = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
  }

  Future<void> _openPicker() async {
    setState(() {
      _loadingMembers = true;
      _error = null;
    });
    try {
      final members = await TeamMembersApiService.instance.getTeamMembers();
      if (!mounted) return;
      setState(() {
        _team = members;
        _loadingMembers = false;
      });
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: NotesTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        builder: (ctx) {
          return _NotesShareMemberPicker(
            members: _team,
            sharedWith: _note.sharedWith,
            onSelected: (m) async {
              Navigator.pop(ctx);
              await _addMember(m);
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMembers = false;
        _error = '$e';
      });
    }
  }

  Future<void> _addMember(TeamMember m) async {
    final empId = m.employeeId ?? m.id;
    final uid = await TimesheetChatResolve.firebaseUidForEmployee(
      empId,
      odooUserId: m.odooUserId,
    );
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${m.name} is not registered in the app yet'),
          backgroundColor: NotesTheme.pureBlack,
        ),
      );
      return;
    }
    try {
      final updated = await _repo.shareNoteWith(
        noteId: _note.id,
        member: NoteSharedMember(
          uid: uid,
          employeeId: empId,
          name: m.name,
          avatarUrl: m.image,
        ),
      );
      if (!mounted) return;
      setState(() => _note = updated);
      context.read<NotesBloc>().add(UpdateNote(updated));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share failed: $e'),
          backgroundColor: NotesTheme.pureBlack,
        ),
      );
    }
  }

  Future<void> _removeMember(NoteSharedMember member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NotesTheme.surface,
        title: Text(
          'Remove access?',
          style: GoogleFonts.poppins(color: NotesTheme.textPrimary),
        ),
        content: Text(
          'Remove ${member.name} from this note?',
          style: GoogleFonts.poppins(
            color: NotesTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: NotesTheme.textPrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final updated = await _repo.unshareNoteWith(
        noteId: _note.id,
        uid: member.uid,
      );
      if (!mounted) return;
      setState(() => _note = updated);
      context.read<NotesBloc>().add(UpdateNote(updated));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Remove failed: $e'),
          backgroundColor: NotesTheme.pureBlack,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, bottom + 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: NotesTheme.textPrimary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Share note',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: NotesTheme.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'View only — recipients can open the note but cannot edit.',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Given access',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: NotesTheme.textPrimary.withValues(alpha: 0.7),
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            height: 64.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._note.sharedWith.map((m) {
                  return Padding(
                    padding: EdgeInsets.only(right: 10.w),
                    child: GestureDetector(
                      onTap: () => _removeMember(m),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 20.r,
                            backgroundImage: m.avatarUrl != null
                                ? NetworkImage(m.avatarUrl!)
                                : null,
                            child: m.avatarUrl == null
                                ? Text(
                                    m.name.isNotEmpty ? m.name[0] : '?',
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                          SizedBox(height: 4.h),
                          SizedBox(
                            width: 56.w,
                            child: Text(
                              m.name.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 10.sp,
                                color: NotesTheme.textPrimary
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: _loadingMembers ? null : _openPicker,
                  child: Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: NotesTheme.bronze,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _loadingMembers
                        ? Padding(
                            padding: EdgeInsets.all(10.w),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: NotesTheme.bronze,
                            ),
                          )
                        : Icon(Icons.add, color: NotesTheme.bronze, size: 20.sp),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 11.sp),
            ),
          ],
          SizedBox(height: 16.h),
          TextButton(
            onPressed: () => Navigator.pop(context, _note),
            child: Text(
              'Done',
              style: GoogleFonts.poppins(
                color: NotesTheme.bronze,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesShareMemberPicker extends StatefulWidget {
  final List<TeamMember> members;
  final List<NoteSharedMember> sharedWith;
  final ValueChanged<TeamMember> onSelected;

  const _NotesShareMemberPicker({
    required this.members,
    required this.sharedWith,
    required this.onSelected,
  });

  @override
  State<_NotesShareMemberPicker> createState() =>
      _NotesShareMemberPickerState();
}

class _NotesShareMemberPickerState extends State<_NotesShareMemberPicker> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool _alreadyHasAccess(TeamMember m) {
    return widget.sharedWith.any(
      (s) =>
          (s.employeeId != null && s.employeeId == m.employeeId) ||
          s.name == m.name,
    );
  }

  List<TeamMember> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.members;
    return widget.members.where((m) {
      final haystack = [
        m.name,
        m.email ?? '',
        m.jobPosition ?? '',
        m.department ?? '',
        m.phone ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final screenH = media.size.height;
    final topSafe = media.padding.top;
    // Cap sheet well below full screen; shrink further when keyboard is up.
    final ideal = screenH * 0.58;
    final available = screenH - keyboard - topSafe - 12;
    final sheetHeight = math.min(ideal, available);

    final filtered = _filtered;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: sheetHeight,
          child: Material(
            color: NotesTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 12.h),
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: NotesTheme.textPrimary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
                  child: Text(
                    'Add people',
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: NotesTheme.textPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    autofocus: false,
                    style: GoogleFonts.poppins(
                      color: NotesTheme.textPrimary,
                      fontSize: 14.sp,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                    onTap: () {
                      // Keyboard only when user explicitly taps search.
                      if (!_searchFocus.hasFocus) {
                        _searchFocus.requestFocus();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or role',
                      hintStyle: GoogleFonts.poppins(
                        color: NotesTheme.textPrimary.withValues(alpha: 0.35),
                        fontSize: 13.sp,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: NotesTheme.textPrimary.withValues(alpha: 0.45),
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: NotesTheme.textPrimary
                                    .withValues(alpha: 0.45),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: NotesTheme.glassFill,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: NotesTheme.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: NotesTheme.glassBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide:
                            const BorderSide(color: NotesTheme.bronze),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            _query.isEmpty
                                ? 'No team members found'
                                : 'No matches for “$_query”',
                            style: GoogleFonts.poppins(
                              color: NotesTheme.textPrimary
                                  .withValues(alpha: 0.5),
                              fontSize: 13.sp,
                            ),
                          ),
                        )
                      : ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final m = filtered[i];
                            final already = _alreadyHasAccess(m);
                            return ListTile(
                              enabled: !already,
                              leading: CircleAvatar(
                                backgroundImage: m.image != null
                                    ? NetworkImage(m.image!)
                                    : null,
                                child: m.image == null
                                    ? Text(
                                        m.name.isNotEmpty ? m.name[0] : '?',
                                      )
                                    : null,
                              ),
                              title: Text(
                                m.name,
                                style: GoogleFonts.poppins(
                                  color: NotesTheme.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                already
                                    ? 'Already has access'
                                    : (m.jobPosition ?? m.email ?? ''),
                                style: GoogleFonts.poppins(
                                  color: NotesTheme.textPrimary
                                      .withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                              onTap: already
                                  ? null
                                  : () => widget.onSelected(m),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
