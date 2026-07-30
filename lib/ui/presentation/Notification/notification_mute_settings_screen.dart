import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/data/services/prayer_audio_service.dart';
import 'package:el_race/data/services/prayer_background_service.dart';
import 'package:el_race/data/services/prayer_notification_service.dart';
import 'package:el_race/data/services/task_notification_service.dart';
import 'package:el_race/ui/presentation/Notification/model/notification_category_listview_model.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/widgets/glass_sub_app_screen_header.dart';
import 'package:el_race/ui/widgets/global_search_theme.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationMuteSettingsScreen extends StatefulWidget {
  const NotificationMuteSettingsScreen({super.key});

  @override
  State<NotificationMuteSettingsScreen> createState() =>
      _NotificationMuteSettingsScreenState();
}

class _NotificationMuteSettingsScreenState
    extends State<NotificationMuteSettingsScreen> {
  static const Map<String, _CategoryUiMeta> _knownCategories = {
    'waiting': _CategoryUiMeta(
      title: 'Waiting / Approvals',
      icon: Icons.hourglass_top_rounded,
      color: Color(0xFFEF6C00),
    ),
    'alert': _CategoryUiMeta(
      title: 'Safety / Alerts',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFEF6C00),
    ),
    'weather': _CategoryUiMeta(
      title: 'Safety / Alerts',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFEF6C00),
    ),
    'project_open': _CategoryUiMeta(
      title: 'Projects',
      icon: Icons.apartment_rounded,
      color: Color(0xFF455A64),
    ),
    'project_completed': _CategoryUiMeta(
      title: 'Projects',
      icon: Icons.apartment_rounded,
      color: Color(0xFF455A64),
    ),
    'prayer': _CategoryUiMeta(
      title: 'Prayer / Adhan',
      icon: Icons.mosque_rounded,
      color: Color(0xFF00695C),
    ),
    'chat_message': _CategoryUiMeta(
      title: 'Chat',
      icon: Icons.chat_bubble_rounded,
      color: Color(0xFF0097A7),
    ),
    'share': _CategoryUiMeta(
      title: 'Share',
      icon: Icons.share_rounded,
      color: Color(0xFF0277BD),
    ),
    'cloud.folder': _CategoryUiMeta(
      title: 'Share',
      icon: Icons.folder_shared_rounded,
      color: Color(0xFF0277BD),
    ),
    'task': _CategoryUiMeta(
      title: 'Tasks',
      icon: Icons.task_alt_rounded,
      color: Color(0xFF5C6BC0),
    ),
    'ticket': _CategoryUiMeta(
      title: 'Tickets',
      icon: Icons.confirmation_number_outlined,
      color: Color(0xFF8B4B9F),
    ),
    'announcement': _CategoryUiMeta(
      title: 'Announcements',
      icon: Icons.announcement_rounded,
      color: Color(0xFF6A1B9A),
    ),
    'circular': _CategoryUiMeta(
      title: 'Circulars',
      icon: Icons.campaign_rounded,
      color: Color(0xFF455A64),
    ),
    'hr.attendance': _CategoryUiMeta(
      title: 'Attendance',
      icon: Icons.access_time_filled_rounded,
      color: Color(0xFF2E7D32),
    ),
  };

  /// Only these are local (not Odoo categories). Everything else comes from API.
  static const List<String> _localOnlyCategories = <String>[
    'chat_message',
    'prayer',
    'task',
    'ticket',
  ];

  /// Display order for mute rows (unknown codes go after these).
  static const List<String> _displayOrder = <String>[
    'waiting',
    'alert',
    'project_open',
    'prayer',
    'chat_message',
    'share',
    'cloud.folder',
    'task',
    'ticket',
    'announcement',
    'circular',
  ];

  /// Covered by the shared `waiting` mute switch — hide duplicate rows.
  static const Set<String> _waitingCoveredModels = <String>{
    'employee.requests',
    'account.move',
    'purchase.order',
    'hr.expense.sheet',
  };

  /// Covered by the shared `alert` mute — summer / weather / safety.
  static const Set<String> _alertCoveredModels = <String>{
    'weather',
    'safety',
    'summer',
  };

  /// Covered by the shared Projects mute (`project_open`).
  static const Set<String> _projectCoveredModels = <String>{
    'project_completed',
  };

  List<NotificationCategoryModel> _categories =
      const <NotificationCategoryModel>[];
  final Set<String> _savingModels = <String>{};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Always hit the network so newly disabled Odoo categories disappear.
    _loadSettings(forceRefresh: true);
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  String _humanizeModel(String model) {
    final text = model.trim();
    if (text.isEmpty) return 'Notification';
    final parts = text
        .split(RegExp(r'[._-]'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) => _capitalize(part.trim()))
        .toList(growable: false);

    if (parts.isEmpty) {
      return 'Notification';
    }
    return parts.join(' ');
  }

  NotificationCategoryModel _toCategoryModel(
    String model,
    bool muted, {
    String? apiTitle,
  }) {
    final key = model.trim().toLowerCase();
    final meta = _knownCategories[key];

    // Use API-provided title first, then hardcoded meta, then humanized model
    final title = (apiTitle != null && apiTitle.trim().isNotEmpty)
        ? apiTitle.trim()
        : meta?.title ?? _humanizeModel(key);

    return NotificationCategoryModel(
      model: key,
      title: title,
      icon: meta?.icon ?? Icons.notifications_active_rounded,
      color: meta?.color ?? const Color(0xFF1565C0),
      muted: muted,
    );
  }

  bool _isLocalOnlyCategory(String model) {
    final key = model.trim().toLowerCase();
    return _localOnlyCategories.contains(key);
  }

  int _sortIndex(String key) {
    final idx = _displayOrder.indexOf(key);
    return idx >= 0 ? idx : _displayOrder.length + 1;
  }

  Future<void> _loadSettings({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final settings = await NotificationStorageService.getMuteSettings(
        forceRefresh: forceRefresh,
      );

      final categories =
          await NotificationStorageService.getNotificationCategories(
        forceRefresh: forceRefresh,
      );

      // Build list from *active* API categories only.
      // Do NOT re-add keys from preferences — inactive categories still have
      // preference rows and would keep showing after admin disables them.
      final apiTitles = <String, String>{};
      final merged = <String, bool>{};
      final hasWaiting = categories.any(
        (c) => c.model.trim().toLowerCase() == 'waiting',
      );
      final hasAlert = categories.any(
        (c) => c.model.trim().toLowerCase() == 'alert',
      );
      final hasProjectOpen = categories.any(
        (c) => c.model.trim().toLowerCase() == 'project_open',
      );
      for (final category in categories) {
        final key = category.model.trim().toLowerCase();
        if (key.isEmpty) continue;
        apiTitles[key] = category.title;
        // Adhan is merged into Prayer — drop standalone row.
        if (key == 'adhan') continue;
        // One Waiting switch covers all approval models.
        if (hasWaiting && _waitingCoveredModels.contains(key)) continue;
        // Safety / Alerts covers weather, summer, safety.
        if (hasAlert && _alertCoveredModels.contains(key)) continue;
        // Projects assigned mute also covers completed.
        if (hasProjectOpen && _projectCoveredModels.contains(key)) continue;
        merged[key] = settings[key] ?? false;
      }

      // Local-only: chat, prayer, tasks.
      for (final localKey in _localOnlyCategories) {
        if (!merged.containsKey(localKey)) {
          merged[localKey] = settings[localKey] ?? false;
        }
      }

      // Hive is the only source of truth for azan (OS schedule + AudioPlayer).
      // Never OR prefs into Hive — that re-mutes after a successful local unmute
      // when Odoo/SharedPrefs still have prayer=true.
      final hiveMuted = await HiveService.isPrayerSoundMuted();
      merged['prayer'] = hiveMuted;
      await NotificationStorageService.setLocalMuteSetting('prayer', hiveMuted);
      await NotificationStorageService.setLocalMuteSetting('adhan', hiveMuted);

      String? titleFor(String key) {
        if (key == 'prayer') return 'Prayer / Adhan';
        if (key == 'chat_message') return 'Chat';
        if (key == 'task') return 'Tasks';
        if (key == 'ticket') return 'Tickets';
        if (key == 'share' || key == 'cloud.folder') {
          return apiTitles[key]?.trim().isNotEmpty == true
              ? apiTitles[key]
              : 'Share';
        }
        if (key == 'waiting') {
          return apiTitles[key]?.trim().isNotEmpty == true
              ? apiTitles[key]
              : 'Waiting / Approvals';
        }
        if (key == 'alert') {
          return 'Safety / Alerts';
        }
        if (key == 'project_open' || key == 'project_completed') {
          return 'Projects';
        }
        return apiTitles[key];
      }

      final categoryModels = merged.entries
          .where((entry) => entry.key != 'adhan')
          .map((entry) => _toCategoryModel(
                entry.key,
                entry.value,
                apiTitle: titleFor(entry.key),
              ))
          .toList(growable: false)
        ..sort((a, b) {
          final byOrder = _sortIndex(a.model).compareTo(_sortIndex(b.model));
          if (byOrder != 0) return byOrder;
          return a.title.compareTo(b.title);
        });

      if (!mounted) return;
      setState(() {
        _categories = categoryModels;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _setCategoryMuted(String model, bool muted) {
    setState(() {
      _categories = _categories
          .map((category) => category.model == model
              ? category.copyWith(muted: muted)
              : category)
          .toList(growable: false);
    });
  }

  Future<void> _toggleMute(
    NotificationCategoryModel category,
    bool muted,
  ) async {
    final model = category.model;
    final previous = category.muted;
    final isLocalOnly = _isLocalOnlyCategory(model);
    final isPrayer = model == 'prayer' || model == 'adhan';

    _setCategoryMuted(model, muted);
    setState(() {
      _savingModels.add(model);
    });

    try {
      // Prayer / Adhan: Hive + cancel/reschedule MUST run even if API fails.
      if (isPrayer) {
        await HiveService.setPrayerSoundMuted(muted);
        if (muted) {
          await PrayerNotificationService().cancelAllPendingAdhan();
          try {
            await PrayerAudioService().stopAdhan();
          } catch (_) {}
        } else {
          try {
            await PrayerAudioService().rescheduleBackgroundNotifications();
          } catch (_) {}
          try {
            await PrayerBackgroundService.reschedule();
          } catch (_) {}
        }
        // Prefer API sync; if it fails, keep local mute keys.
        try {
          await NotificationStorageService.setMuteSetting('prayer', muted);
        } catch (_) {
          await NotificationStorageService.setLocalMuteSetting('prayer', muted);
        }
        await NotificationStorageService.setLocalMuteSetting('adhan', muted);
        if (mounted) {
          try {
            context.read<HomeBloc>().add(const LoadPrayerMuteStateEvent());
          } catch (_) {}
        }
      } else if (isLocalOnly) {
        await NotificationStorageService.setLocalMuteSetting(model, muted);
        if (model == 'task' && muted) {
          await TaskNotificationService().cancelAllPendingTaskNotifications();
        }
      } else {
        await NotificationStorageService.setMuteSetting(model, muted);
        if (model == 'task' && muted) {
          await TaskNotificationService().cancelAllPendingTaskNotifications();
        }
      }
    } catch (e) {
      if (mounted) {
        _setCategoryMuted(model, previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update mute: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingModels.remove(model);
        });
      }
    }
  }

  Widget _buildCategoryTile(NotificationCategoryModel category) {
    final isSaving = _savingModels.contains(category.model);

    return Container(
      margin: EdgeInsets.only(bottom: 10.th),
      padding: EdgeInsets.fromLTRB(12.tw, 10.th, 10.tw, 10.th),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.tr),
        color: category.muted
            ? category.color.withValues(alpha: 0.08)
            : const Color(0xFFF7F9FC),
        border: Border.all(
          color: category.muted
              ? category.color.withValues(alpha: 0.5)
              : const Color(0xFFE1E7F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38.tw,
            height: 38.tw,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: category.color.withValues(alpha: 0.14),
            ),
            child: Icon(category.icon, color: category.color, size: 21.tsp),
          ),
          SizedBox(width: 10.tw),
          Expanded(
            child: Text(
              category.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111D3A),
              ),
            ),
          ),
          if (isSaving)
            SizedBox(
              width: 18.tw,
              height: 18.tw,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: category.color,
              ),
            )
          else
            Switch.adaptive(
              value: !category.muted,
              activeColor: const Color(0xFF43A047),
              activeTrackColor: const Color(0xFFA5D6A7),
              inactiveThumbColor: const Color(0xFFE53935),
              inactiveTrackColor: const Color(0xFFEF9A9A),
              onChanged: (value) => _toggleMute(category, !value),
            ),
        ],
      ),
    );
  }

  List<Widget> _headerActions() {
    return [
      if (!_isLoading)
        GlassSubAppHeaderIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh',
          onPressed: () => _loadSettings(forceRefresh: true),
        ),
    ];
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _loadSettings(forceRefresh: true),
      color: appFontColor,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          14.tw,
          10.th,
          14.tw,
          context.systemBottomInset + 24.th,
        ),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          if (_error != null)
            Container(
              margin: EdgeInsets.only(bottom: 10.th),
              padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.tr),
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.poppins(
                  color: Colors.red.shade700,
                  fontSize: 11.tsp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (_categories.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 26.th),
              child: Center(
                child: Text(
                  'No notification categories available.',
                  style: GoogleFonts.poppins(
                    fontSize: 12.tsp,
                    color: const Color(0xFF5F6F89),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            ..._categories.map(_buildCategoryTile),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: GlobalSearchTheme.screenBase,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassSubAppScreenHeader(
              title: 'Mute Notifications',
              titleIcon: Icons.settings_outlined,
              roundedBottom: false,
              trailing: _headerActions(),
            ),
            GlassSubAppContentSheet(
              showHandle: false,
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryUiMeta {
  final String title;
  final IconData icon;
  final Color color;

  const _CategoryUiMeta({
    required this.title,
    required this.icon,
    required this.color,
  });
}
