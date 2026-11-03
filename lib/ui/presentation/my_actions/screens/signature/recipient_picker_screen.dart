import 'dart:async';

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../../chat/models/chat_user.dart';
import '../../../../../chat/repositories/user_repository.dart';
import '../../data/user_stamp_assets.dart';
import '../../theme/signature_theme.dart';

/// Single-select user search for the "Request signatures" upload flow.
/// Returns a [List<ChatUser>] of one person. Timesheet mode ([maxSignees] 2)
/// returns up to two people in signing order: Site Engineer, Projects Manager.
///
/// When [stampNeeded] is true, loads **all** stamp users immediately (no
/// search required). Search only filters that list. The logged-in stamp user
/// is always included when their login has `x_stamp_user`.
class RecipientPickerScreen extends StatefulWidget {
  final bool stampNeeded;

  /// Timesheet mode caps the list at 2. Null keeps the normal single select.
  final int? maxSignees;

  /// When true (timesheet approval), the foreman cannot pick themself.
  final bool blockCurrentUser;

  const RecipientPickerScreen({
    super.key,
    this.stampNeeded = false,
    this.maxSignees,
    this.blockCurrentUser = false,
  });

  @override
  State<RecipientPickerScreen> createState() => _RecipientPickerScreenState();
}

class _RecipientPickerScreenState extends State<RecipientPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  /// Full stamp directory when [stampNeeded]; unused for normal search mode.
  List<ChatUser> _allStampUsers = [];
  List<ChatUser> _results = [];
  final List<ChatUser> _selected = [];
  bool _isLoading = false;
  late String _message;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// Only timesheet mode picks more than one signee.
  bool get _multiSelect => (widget.maxSignees ?? 1) > 1;

  String get _searchHint => _multiSelect
      ? 'First signee is Site Engineer, second is Projects Manager'
      : 'Search and select one signee';

  @override
  void initState() {
    super.initState();
    if (widget.stampNeeded) {
      _message = _multiSelect
          ? 'Select stamp users: Site Engineer, then Projects Manager'
          : 'Select one stamp user';
      _loadAllStampUsers();
    } else {
      _message = _searchHint;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllStampUsers() async {
    setState(() => _isLoading = true);
    try {
      final users =
          await UserRepository.instance.listStampUsers(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _allStampUsers = users;
        _results = users;
        _isLoading = false;
        _message = users.isEmpty
            ? (UserStampAssets.isStampUser
                ? 'No stamp users found yet.'
                : 'Your login is not marked as stamp user. '
                    'Confirm emp_id is in the stamp list, or ask backend to '
                    'return x_stamp_user on login.')
            : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'Failed to load stamp users. Try again.';
      });
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (widget.stampNeeded) {
        _filterStampUsers(query);
      } else {
        _search(query);
      }
    });
  }

  void _filterStampUsers(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      setState(() {
        _results = _allStampUsers;
        _message = _allStampUsers.isEmpty
            ? (UserStampAssets.isStampUser
                ? 'No stamp users found yet.'
                : 'Your login is not marked as stamp user.')
            : '';
      });
      return;
    }
    final filtered = _allStampUsers.where((user) {
      final name = user.name.toLowerCase();
      final email = (user.email ?? '').toLowerCase();
      final emp = user.employeeId?.toString() ?? '';
      final odoo = user.odooUserId.toString();
      return name.contains(trimmed) ||
          email.contains(trimmed) ||
          emp.contains(trimmed) ||
          odoo.contains(trimmed);
    }).toList();
    setState(() {
      _results = filtered;
      _message = filtered.isEmpty ? 'No matching stamp users' : '';
    });
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _message = _searchHint;
      });
      return;
    }
    if (trimmed.length < 2) {
      setState(() {
        _results = [];
        _message = 'Enter at least 2 characters';
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await UserRepository.instance.searchUsers(query: trimmed);
      if (!mounted) return;
      setState(() {
        _results = result.users;
        _isLoading = false;
        _message = result.users.isEmpty ? 'No matching users found' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _message = 'Search error, please try again';
      });
    }
  }

  void _toggle(ChatUser user) {
    final idx = _selected.indexWhere((u) => u.uid == user.uid);
    if (idx < 0) {
      if (widget.blockCurrentUser && _isMe(user)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot pick yourself as an approver'),
          ),
        );
        return;
      }
      final max = widget.maxSignees;
      if (max != null && _selected.length >= max) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Select at most $max signees')),
        );
        return;
      }
    }
    setState(() {
      if (!_multiSelect) {
        // Normal "+" flow: one signee. Tapping another person replaces them.
        _selected.clear();
        if (idx < 0) _selected.add(user);
      } else if (idx >= 0) {
        _selected.removeAt(idx);
      } else {
        _selected.add(user);
      }
    });
  }

  void _done() {
    Navigator.pop(context, List<ChatUser>.from(_selected));
  }

  bool _isSelected(ChatUser user) =>
      _selected.any((u) => u.uid == user.uid);

  bool _isMe(ChatUser user) {
    final authUid = _currentUid;
    if (authUid != null && user.uid == authUid) return true;
    final login = SharedPref.getLoginData().result?.data;
    final loginFb = login?.firebase_uid?.trim();
    if (loginFb != null && loginFb.isNotEmpty && user.uid == loginFb) {
      return true;
    }
    final odooId = login?.odoo_user_id;
    if (odooId != null && odooId > 0) {
      if (user.uid == 'odoo_$odooId') return true;
      if (user.odooUserId == odooId) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SignatureTheme.background,
      appBar: AppBar(
        backgroundColor: SignatureTheme.surface,
        foregroundColor: SignatureTheme.textDark,
        elevation: 0,
        systemOverlayStyle: SignatureTheme.lightStatusBar,
        title: Text(
          widget.stampNeeded
              ? (_multiSelect ? 'Select Stamp Signees' : 'Select Stamp Signee')
              : (_multiSelect ? 'Select Signees' : 'Select Signee'),
          style: SignatureTheme.appBarTitle,
        ),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty ? null : _done,
            child: Text(
              'Done (${_selected.length})',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _selected.isEmpty
                    ? SignatureTheme.textMuted
                    : SignatureTheme.brown,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.stampNeeded)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16.tw, vertical: 10.th),
              color: SignatureTheme.khakiLight,
              child: Text(
                'Stamp signees load automatically. You appear first if you are '
                'a stamp user. Optional search filters by name, email, or emp id.',
                style: SignatureTheme.cardSubtitle,
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.tw, 12.th, 16.tw, 8.th),
            child: TextField(
              controller: _searchController,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: widget.stampNeeded
                    ? 'Filter stamp users (optional)'
                    : 'Search by name or email',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: SignatureTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.tr),
                  borderSide: const BorderSide(color: SignatureTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.tr),
                  borderSide: const BorderSide(color: SignatureTheme.divider),
                ),
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            SizedBox(
              height: 44.th,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.tw),
                itemCount: _selected.length,
                separatorBuilder: (_, __) => SizedBox(width: 8.tw),
                itemBuilder: (context, index) {
                  final user = _selected[index];
                  return Chip(
                    label: Text(
                      '${_multiSelect ? '${index + 1}. ' : ''}'
                      '${_isMe(user) ? '${user.name} (You)' : user.name}',
                    ),
                    onDeleted: () => _toggle(user),
                    backgroundColor: SignatureTheme.khakiLight,
                  );
                },
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.tr),
                          child: Text(
                            _message,
                            textAlign: TextAlign.center,
                            style: SignatureTheme.cardSubtitle,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final user = _results[index];
                          final selected = _isSelected(user);
                          final me = _isMe(user);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: SignatureTheme.khakiLight,
                              child: Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: SignatureTheme.brownDeep,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(me ? '${user.name} (You)' : user.name),
                            subtitle: Text(user.email ?? user.uid),
                            trailing: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: selected
                                  ? SignatureTheme.brown
                                  : SignatureTheme.textMuted,
                            ),
                            onTap: () => _toggle(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
