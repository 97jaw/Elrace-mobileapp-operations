import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/linked_devices/linked_devices_repository.dart';
import 'package:el_race/ui/widgets/glass_sub_app_screen_header.dart';
import 'package:el_race/ui/widgets/global_search_theme.dart';
import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  static const _textPrimary = Color(0xFF111D3A);
  static const _textSecondary = Color(0xFF5F6F89);
  static const _danger = Color(0xFFBA1719);
  static const _navy = Color(0xFF0B387A);

  final _repo = const LinkedDevicesRepository();

  LinkedDevicesData? _data;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      if (_data == null) _isLoading = true;
    });
    try {
      final data = await _repo.fetch();
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _message(Object e) => e is LinkedDevicesException
      ? e.message
      : 'Could not load your devices. Check your connection and try again.';

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(action, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _isBusy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is LinkedDevicesException
              ? e.message
              : 'Could not log out the device. Please try again.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _logoutDevice(LinkedDevice device) async {
    final ok = await _confirm(
      title: 'Log out device?',
      message: '${_title(device)} will be signed out of your account.',
      action: 'Log out',
    );
    if (!ok) return;
    await _run(() => _repo.logout(device), 'Device logged out.');
  }

  Future<void> _logoutOthers() async {
    final ok = await _confirm(
      title: 'Log out all other devices?',
      message: 'Every device except this phone will be signed out of your '
          'account.',
      action: 'Log out all',
    );
    if (!ok) return;
    await _run(_repo.logoutOthers, 'All other devices logged out.');
  }

  String _title(LinkedDevice d) {
    if (d.name.isNotEmpty) return d.name;
    return d.isWeb ? 'Web browser' : 'Mobile app';
  }

  String _subtitle(LinkedDevice d) {
    final parts = <String>[
      if (d.isWeb) 'Odoo web' else 'El Race app',
      if (d.isWeb && d.browser.isNotEmpty && d.browser != d.name) d.browser,
      if (d.os.isNotEmpty) d.os,
      if (!d.isWeb && d.appVersion.isNotEmpty) 'v${d.appVersion}',
    ];
    return parts.join(' · ');
  }

  String _lastActive(LinkedDevice d) {
    if (d.current) return 'Active now';
    final at = d.lastActiveAt;
    if (at == null) return '';
    final now = DateTime.now();
    final diff = now.difference(at);
    if (diff.inMinutes < 15) return 'Active recently';
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final time = DateFormat.jm().format(at);
    if (day == today) return 'Last active today at $time';
    if (today.difference(day).inDays == 1) {
      return 'Last active yesterday at $time';
    }
    return 'Last active ${DateFormat('d MMM').format(at)} at $time';
  }

  IconData _icon(LinkedDevice d) {
    if (!d.isWeb) {
      return d.os.toLowerCase().startsWith('ios')
          ? Icons.phone_iphone_rounded
          : Icons.phone_android_rounded;
    }
    switch (d.deviceType) {
      case 'mobile':
        return Icons.smartphone_rounded;
      case 'tablet':
        return Icons.tablet_mac_rounded;
      default:
        return Icons.laptop_mac_rounded;
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.tw, 6.th, 4.tw, 8.th),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11.tsp,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: _textSecondary,
        ),
      ),
    );
  }

  Widget _deviceTile(LinkedDevice d) {
    final accent = d.current ? const Color(0xFF2E7D32) : _navy;
    return Container(
      margin: EdgeInsets.only(bottom: 10.th),
      padding: EdgeInsets.fromLTRB(12.tw, 12.th, 6.tw, 12.th),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.tr),
        color: const Color(0xFFF7F9FC),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42.tw,
            height: 42.tw,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
            ),
            child: Icon(_icon(d), color: accent, size: 22.tsp),
          ),
          SizedBox(width: 12.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(d),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14.tsp,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                SizedBox(height: 2.th),
                Text(
                  _subtitle(d),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5.tsp,
                    color: _textSecondary,
                  ),
                ),
                if (_lastActive(d).isNotEmpty) ...[
                  SizedBox(height: 2.th),
                  Text(
                    _lastActive(d),
                    style: GoogleFonts.poppins(
                      fontSize: 11.5.tsp,
                      fontWeight: d.current ? FontWeight.w600 : FontWeight.w400,
                      color: d.current ? accent : _textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!d.current)
            TextButton(
              onPressed: _isBusy ? null : () => _logoutDevice(d),
              style: TextButton.styleFrom(foregroundColor: _danger),
              child: Text(
                'Log out',
                style: GoogleFonts.poppins(
                  fontSize: 12.5.tsp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _logoutOthersButton() {
    return Padding(
      padding: EdgeInsets.only(top: 6.th, bottom: 4.th),
      child: OutlinedButton.icon(
        onPressed: _isBusy ? null : _logoutOthers,
        icon: _isBusy
            ? SizedBox(
                width: 16.tw,
                height: 16.tw,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _danger,
                ),
              )
            : const Icon(Icons.logout_rounded),
        label: Text(
          'Log out all other devices',
          style: GoogleFonts.poppins(
            fontSize: 13.tsp,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _danger,
          side: BorderSide(color: _danger.withValues(alpha: 0.5)),
          padding: EdgeInsets.symmetric(vertical: 12.th),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.tr),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.th),
      padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.tr),
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(
          color: Colors.red.shade700,
          fontSize: 11.tsp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _emptyOthers() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 18.th, horizontal: 8.tw),
      child: Text(
        'You are not signed in on any other device.',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(fontSize: 12.tsp, color: _textSecondary),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final data = _data;
    return RefreshIndicator(
      onRefresh: _load,
      color: appFontColor,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          14.tw,
          12.th,
          14.tw,
          context.systemBottomInset + 24.th,
        ),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          if (_error != null) _errorBanner(_error!),
          if (data != null) ...[
            if (data.current != null) ...[
              _sectionLabel('This device'),
              _deviceTile(data.current!),
              SizedBox(height: 8.th),
            ],
            _sectionLabel('Other devices'),
            if (data.others.isEmpty)
              _emptyOthers()
            else ...[
              ...data.others.map(_deviceTile),
              _logoutOthersButton(),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlobalSearchTheme.screenBase,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassSubAppScreenHeader(
            title: 'Linked Devices',
            titleIcon: Icons.devices_rounded,
            roundedBottom: false,
            trailing: [
              if (!_isLoading)
                GlassSubAppHeaderIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh',
                  onPressed: _load,
                ),
            ],
          ),
          GlassSubAppContentSheet(
            showHandle: false,
            child: _buildBody(),
          ),
        ],
      ),
    );
  }
}
