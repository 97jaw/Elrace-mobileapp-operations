import 'dart:async';

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';

import '../../../../../chat/models/chat_user.dart';
import '../../../../../chat/repositories/user_repository.dart';
import '../../theme/signature_theme.dart';

/// Multi-select user search for the "Request signatures" upload flow.
/// Returns a [List<ChatUser>] in the order selected (signing order).
class RecipientPickerScreen extends StatefulWidget {
  const RecipientPickerScreen({super.key});

  @override
  State<RecipientPickerScreen> createState() => _RecipientPickerScreenState();
}

class _RecipientPickerScreenState extends State<RecipientPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<ChatUser> _results = [];
  final List<ChatUser> _selected = [];
  bool _isSearching = false;
  String _message = 'Search and select signees in signing order';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _message = 'Search and select signees in signing order';
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

    setState(() => _isSearching = true);
    try {
      final result = await UserRepository.instance.searchUsers(query: trimmed);
      if (!mounted) return;
      setState(() {
        _results = result.users;
        _isSearching = false;
        _message = result.users.isEmpty ? 'No matching users found' : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _message = 'Search error, please try again';
      });
    }
  }

  void _toggle(ChatUser user) {
    setState(() {
      final idx = _selected.indexWhere((u) => u.uid == user.uid);
      if (idx >= 0) {
        _selected.removeAt(idx);
      } else {
        _selected.add(user);
      }
    });
  }

  bool _isSelected(ChatUser user) =>
      _selected.any((u) => u.uid == user.uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SignatureTheme.background,
      appBar: AppBar(
        backgroundColor: SignatureTheme.surface,
        foregroundColor: SignatureTheme.textDark,
        elevation: 0,
        systemOverlayStyle: SignatureTheme.lightStatusBar,
        title: Text('Select Signees', style: SignatureTheme.appBarTitle),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, List<ChatUser>.from(_selected)),
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
          Padding(
            padding: EdgeInsets.all(16.tr),
            child: TextField(
              controller: _searchController,
              onChanged: _onChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search for colleagues...',
                hintStyle: SignatureTheme.cardSubtitle,
                prefixIcon:
                    const Icon(Icons.search, color: SignatureTheme.brown),
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.tr),
                  borderSide:
                      const BorderSide(color: SignatureTheme.khaki, width: 1.5),
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
                  return InputChip(
                    label: Text('${index + 1}. ${user.name}'),
                    onDeleted: () => _toggle(user),
                    backgroundColor: SignatureTheme.khakiLight,
                    deleteIconColor: SignatureTheme.brownDeep,
                  );
                },
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: SignatureTheme.brown),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.tr),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search_rounded,
                  size: 56.tsp, color: SignatureTheme.khaki),
              SizedBox(height: 12.th),
              Text(_message,
                  textAlign: TextAlign.center,
                  style: SignatureTheme.cardSubtitle),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.tw, vertical: 8.th),
      itemCount: _results.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.th),
      itemBuilder: (context, index) {
        final user = _results[index];
        final selected = _isSelected(user);
        return _RecipientTile(
          user: user,
          selected: selected,
          onTap: () => _toggle(user),
        );
      },
    );
  }
}

class _RecipientTile extends StatelessWidget {
  final ChatUser user;
  final bool selected;
  final VoidCallback onTap;

  const _RecipientTile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.tr),
      child: Container(
        padding: EdgeInsets.all(12.tr),
        decoration: SignatureTheme.card(radius: 16).copyWith(
          border: Border.all(
            color: selected ? SignatureTheme.khaki : SignatureTheme.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22.tr,
              backgroundColor: SignatureTheme.khakiLight,
              backgroundImage:
                  user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null
                  ? Text(
                      _initials(user.name),
                      style: const TextStyle(
                        color: SignatureTheme.brownDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 12.tw),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: SignatureTheme.cardTitle),
                  if (user.email != null)
                    Text(user.email!, style: SignatureTheme.cardSubtitle),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? SignatureTheme.signed : SignatureTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
