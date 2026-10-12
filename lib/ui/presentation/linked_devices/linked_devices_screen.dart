import 'package:el_race/core/services/device_details_headers.dart';
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
  static const _green = Color(0xFF2E7D32);
  static const _cardColor = Color(0xFFF7F9FC);
  static const _cardBorder = Color(0xFFE1E7F0);

  /// Rows shown on the screen; the rest open in the "See all" sheet.
  static const _previewCount = 3;

  final _repo = const LinkedDevicesRepository();

  LinkedDevicesData? _data;
  bool _isLoading = true;
  bool _isBusy = false;
  String? _error;
  String _localDeviceName = '';

  @override
  void initState() {
    super.initState();
    _load();
    DeviceDetailsHeaders.get().then((headers) {
      final name = headers['X-Device-Name'] ?? '';
      if (mounted &&
          name.isNotEmpty &&
          !name.toLowerCase().startsWith('unknown')) {
        setState(() => _localDeviceName = name);
      }
    });
  }

  List<LinkedDevice> get _allDevices {
    final data = _data;
    if (data == null) return const [];
    return [if (data.current != null) data.current!, ...data.others];
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

  static const _genericAppNames = {'mobile app', 'iphone', 'android phone'};

  String _title(LinkedDevice d) {
    final name = d.name.trim();
    final generic = name.isEmpty ||
        name.toLowerCase().startsWith('unknown') ||
        (!d.isWeb && _genericAppNames.contains(name.toLowerCase()));
    if (d.current && generic && _localDeviceName.isNotEmpty) {
      return _localDeviceName;
    }
    if (name.isNotEmpty && !name.toLowerCase().startsWith('unknown')) {
      return name;
    }
    return d.isWeb ? 'Web browser' : 'Mobile app';
  }

  String _platform(LinkedDevice d) {
    if (d.isWeb) {
      final browser = d.browser.isNotEmpty ? d.browser : 'Odoo web';
      return d.os.isNotEmpty ? '$browser (${d.os})' : browser;
    }
    return d.os.isNotEmpty ? 'El Race app (${d.os})' : 'El Race app';
  }

  String _formatTime(DateTime at) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final time = DateFormat.jm().format(at);
    if (day == today) return 'today at $time';
    if (today.difference(day).inDays == 1) return 'yesterday at $time';
    return '${DateFormat('d MMM yyyy').format(at)} at $time';
  }

  String _lastActive(LinkedDevice d) {
    if (d.current) return 'Active now';
    final at = d.lastActiveAt;
    if (at == null) return '';
    if (DateTime.now().difference(at).inMinutes < 15) return 'Active recently';
    return 'Last active ${_formatTime(at)}';
  }

  String _rowSubtitle(LinkedDevice d) {
    final active = _lastActive(d);
    if (d.current) return 'This device · $active';
    return active.isNotEmpty ? active : _platform(d);
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

  // ---------------------------------------------------------------- widgets

  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.tw, 0, 4.tw, 8.th),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13.tsp,
          fontWeight: FontWeight.w600,
          color: _textSecondary,
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.tr),
        color: _cardColor,
        border: Border.all(color: _cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 1,
        indent: 66.tw,
        color: _cardBorder,
      );

  Widget _deviceRow(LinkedDevice d, {required VoidCallback onTap}) {
    final accent = d.current ? _green : _navy;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.tw, 12.th, 10.tw, 12.th),
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
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.th),
                  Text(
                    _rowSubtitle(d),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5.tsp,
                      fontWeight: d.current ? FontWeight.w600 : FontWeight.w400,
                      color: d.current ? _green : _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _textSecondary.withValues(alpha: 0.6),
              size: 22.tsp,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _deviceRows(List<LinkedDevice> devices) {
    final rows = <Widget>[];
    for (var i = 0; i < devices.length; i++) {
      if (i > 0) rows.add(_divider());
      rows.add(_deviceRow(
        devices[i],
        onTap: () => _showDeviceSheet(devices[i]),
      ));
    }
    return rows;
  }

  Widget _seeAllRow(int total) {
    return InkWell(
      onTap: _showAllSheet,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 13.th),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'See all ($total)',
                style: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  fontWeight: FontWeight.w600,
                  color: _navy,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_up_rounded, color: _navy, size: 22.tsp),
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    final count = _allDevices.length;
    final caption = _data == null
        ? 'See where your account is signed in.'
        : count == 1
            ? '1 device signed in to your account.'
            : '$count devices signed in to your account.';
    return Container(
      padding: EdgeInsets.fromLTRB(16.tw, 18.th, 16.tw, 16.th),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18.tr),
        color: _cardColor,
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/png/linked_devices.png',
            height: 72.th,
            fit: BoxFit.contain,
          ),
          SizedBox(height: 12.th),
          Text(
            'Linked devices',
            style: GoogleFonts.poppins(
              fontSize: 16.tsp,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 4.th),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.tsp,
              color: _textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutOthersButton() {
    return OutlinedButton.icon(
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

  Widget _footnote(String text) {
    return Padding(
      padding: EdgeInsets.fromLTRB(6.tw, 8.th, 6.tw, 0),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11.5.tsp,
          color: _textSecondary,
          height: 1.4,
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- sheets

  Widget _sheetFrame({
    required ScrollController controller,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.tr)),
      ),
      child: ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          14.tw,
          10.th,
          14.tw,
          context.systemBottomInset + 24.th,
        ),
        children: [
          Center(
            child: Container(
              width: 40.tw,
              height: 4.th,
              decoration: BoxDecoration(
                color: _cardBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          SizedBox(height: 14.th),
          ...children,
        ],
      ),
    );
  }

  Widget _sheetTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.th),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 16.tsp,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
      ),
    );
  }

  Future<void> _showDraggable({
    required double initialSize,
    required List<Widget> Function(BuildContext sheetContext) children,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: initialSize,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        builder: (_, controller) => _sheetFrame(
          controller: controller,
          children: children(sheetContext),
        ),
      ),
    );
  }

  void _showAllSheet() {
    final devices = _allDevices;
    _showDraggable(
      initialSize: 0.7,
      children: (sheetContext) => [
        _sheetTitle('All linked devices'),
        _card(
          children: [
            for (var i = 0; i < devices.length; i++) ...[
              if (i > 0) _divider(),
              _deviceRow(
                devices[i],
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showDeviceSheet(devices[i]);
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 13.th),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13.tsp, color: _textPrimary),
          ),
          SizedBox(width: 12.tw),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                color: _textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceSheet(LinkedDevice d) {
    final accent = d.current ? _green : _navy;
    final details = <MapEntry<String, String>>[
      MapEntry('Activity', _lastActive(d).isNotEmpty ? _lastActive(d) : '—'),
      MapEntry('Platform', _platform(d)),
      if (!d.isWeb && d.appVersion.isNotEmpty)
        MapEntry('App version', d.appVersion),
      if (d.loginAt != null) MapEntry('Signed in', _formatTime(d.loginAt!)),
    ];
    _showDraggable(
      initialSize: 0.55,
      children: (sheetContext) => [
        Center(
          child: Container(
            width: 56.tw,
            height: 56.tw,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
            ),
            child: Icon(_icon(d), color: accent, size: 28.tsp),
          ),
        ),
        SizedBox(height: 10.th),
        _sheetTitle(_title(d)),
        _sectionLabel('Device status'),
        _card(
          children: [
            for (var i = 0; i < details.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, thickness: 1, color: _cardBorder),
              _detailRow(details[i].key, details[i].value),
            ],
          ],
        ),
        SizedBox(height: 16.th),
        if (d.current)
          _footnote('This is the device you are using now. To sign out here, '
              'use Log out in your profile.')
        else
          _card(
            children: [
              InkWell(
                onTap: _isBusy
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        _logoutDevice(d);
                      },
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 14.th),
                  child: Center(
                    child: Text(
                      'Log out device',
                      style: GoogleFonts.poppins(
                        fontSize: 14.tsp,
                        fontWeight: FontWeight.w600,
                        color: _danger,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ------------------------------------------------------------------- body

  Widget _buildBody() {
    final devices = _allDevices;
    final preview = devices.take(_previewCount).toList();
    final hasOthers = _data?.others.isNotEmpty ?? false;
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
          _headerCard(),
          SizedBox(height: 18.th),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.only(top: 32.th),
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (_error != null) _errorBanner(_error!),
          if (!_isLoading && _data != null) ...[
            _sectionLabel('Linked devices'),
            _card(
              children: [
                ..._deviceRows(preview),
                if (devices.length > _previewCount) ...[
                  const Divider(height: 1, thickness: 1, color: _cardBorder),
                  _seeAllRow(devices.length),
                ],
              ],
            ),
            _footnote(hasOthers
                ? 'Tap a device to see its details or log it out.'
                : 'You are not signed in on any other device.'),
            if (hasOthers) ...[
              SizedBox(height: 18.th),
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
            roundedBottom: false,
            showBackButton: false,
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
