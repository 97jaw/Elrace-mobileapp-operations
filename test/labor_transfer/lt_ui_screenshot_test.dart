import 'dart:io';
import 'dart:ui' as ui;

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/labor_transfer_models.dart';
import 'package:el_race/ui/presentation/timesheet/labor_transfer/lt_direction_chip.dart';

import 'package:el_race/ui/presentation/timesheet/labor_transfer/lt_person_avatar.dart';
import 'package:el_race/ui/presentation/timesheet/labor_transfer/lt_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Visual QA frames for LT3 polish.
/// `flutter test test/labor_transfer/lt_ui_screenshot_test.dart`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final outDir = Directory('doc/labor_transfer/screenshots');

  setUpAll(() {
    if (!outDir.existsSync()) outDir.createSync(recursive: true);
  });

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Size size,
    required Widget child,
  }) async {
    final binding = tester.binding;
    await binding.setSurfaceSize(size);
    addTearDown(() async {
      await binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: SizedBox(
              width: size.width,
              height: size.height,
              child: RepaintBoundary(
                key: const ValueKey('shot'),
                child: Material(
                  color: TimesheetModuleColors.warmGradientEnd,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final element = tester.element(find.byKey(const ValueKey('shot')));
    final boundary = element.renderObject! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${outDir.path}/$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('captures all LT polish frames', (tester) async {
    const devices = [
      ('android360', Size(360, 740)),
      ('iphone', Size(390, 844)),
      ('ipad', Size(768, 1024)),
    ];

    for (final (id, size) in devices) {
      await shoot(
        tester,
        name: 'list_my_requests_$id',
        size: size,
        child: const _ListFrame(tab: 'My requests', showDirection: true),
      );
      await shoot(
        tester,
        name: 'list_to_approve_$id',
        size: size,
        child: const _ListFrame(tab: 'To approve', showDirection: false),
      );
      await shoot(
        tester,
        name: 'new_labors_disabled_$id',
        size: size,
        child: const _NewFrame(
          tab: 'Labors',
          selectedLabors: 0,
          selectedForeman: null,
          canSubmit: false,
        ),
      );
      await shoot(
        tester,
        name: 'new_foreman_enabled_$id',
        size: size,
        child: const _NewFrame(
          tab: 'Transfer Foreman',
          selectedLabors: 2,
          selectedForeman: 'Ahmed Hassan',
          canSubmit: true,
        ),
      );
      await shoot(
        tester,
        name: 'detail_$id',
        size: size,
        child: const _DetailFrame(),
      );
    }
  });
}

class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.title,
    required this.tabs,
    required this.selectedTab,
    required this.body,
    this.trailing,
    this.bottom,
  });

  final String title;
  final List<String> tabs;
  final String selectedTab;
  final Widget body;
  final Widget? trailing;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: TimesheetModuleColors.warmGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Row(
              children: [
                Icon(PhosphorIcons.caretLeft(), color: TimesheetModuleColors.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: TimesheetModuleColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (final t in tabs)
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            t,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: t == selectedTab
                                  ? TimesheetModuleColors.accent
                                  : TimesheetModuleColors.warmMuted,
                            ),
                          ),
                        ),
                        Container(
                          height: 2.5,
                          color: t == selectedTab
                              ? TimesheetModuleColors.accent
                              : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: body),
          if (bottom != null) bottom!,
        ],
      ),
    );
  }
}

class _ListFrame extends StatelessWidget {
  const _ListFrame({required this.tab, required this.showDirection});
  final String tab;
  final bool showDirection;

  @override
  Widget build(BuildContext context) {
    return _Chrome(
      title: 'Labor transfer',
      trailing: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.plusCircle(),
                size: 18, color: TimesheetModuleColors.accent),
            const SizedBox(width: 4),
            const Text(
              'Create',
              style: TextStyle(
                color: TimesheetModuleColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      tabs: const ['My requests', 'To approve'],
      selectedTab: tab,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _card(
            '2 labors',
            'Ahmed Hassan',
            'Karim Nasser',
            LaborTransferState.pending,
            LtTransferDirection.sent,
          ),
          const SizedBox(height: 12),
          _card(
            '1 labor',
            'You',
            'Omar Saleh',
            LaborTransferState.approved,
            LtTransferDirection.incoming,
          ),
        ],
      ),
    );
  }

  Widget _card(
    String count,
    String to,
    String from,
    LaborTransferState state,
    LtTransferDirection dir,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.glassSurface,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        border: Border.all(color: TimesheetModuleColors.glassBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  count,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: TimesheetModuleColors.ink,
                  ),
                ),
              ),
              LtStatusChip(state: state),
            ],
          ),
          const SizedBox(height: 10),
          _line('To:', to),
          const SizedBox(height: 6),
          _line('From:', from),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '19 Oct 2026 · 14:30',
                  style: TextStyle(
                    color: TimesheetModuleColors.mutedText,
                    fontSize: 12,
                  ),
                ),
              ),
              if (showDirection) LtDirectionChip(direction: dir),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String prefix, String name) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            prefix,
            style: const TextStyle(
              color: TimesheetModuleColors.warmMuted,
              fontSize: 13,
            ),
          ),
        ),
        LtPersonAvatar(name: name, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: TimesheetModuleColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _NewFrame extends StatelessWidget {
  const _NewFrame({
    required this.tab,
    required this.selectedLabors,
    required this.selectedForeman,
    required this.canSubmit,
  });

  final String tab;
  final int selectedLabors;
  final String? selectedForeman;
  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    final isLabors = tab == 'Labors';
    return _Chrome(
      title: 'New Transfer',
      tabs: const ['Labors', 'Transfer Foreman'],
      selectedTab: tab,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              isLabors
                  ? '$selectedLabors selected'
                  : (selectedForeman == null
                      ? 'Selected: None'
                      : 'Selected: $selectedForeman'),
              style: const TextStyle(
                color: TimesheetModuleColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: isLabors
                  ? const [
                      _LaborRow(
                          name: 'Ravi Kumar',
                          sub: 'E-1021',
                          selected: true),
                      _LaborRow(
                          name: 'Sunil Patel',
                          sub: 'E-1044',
                          selected: true),
                      _LaborRow(
                        name: 'Team member',
                        sub: 'E-1100 · Already in your team',
                        selected: false,
                        dim: true,
                      ),
                    ]
                  : const [
                      _ForemanRow(name: 'Ahmed Hassan', selected: true),
                      _ForemanRow(name: 'Omar Saleh', selected: false),
                    ],
            ),
          ),
        ],
      ),
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: _SubmitBar(enabled: canSubmit, label: 'Submit Transfer'),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.enabled, required this.label});
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: TimesheetModuleLayout.buttonHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: enabled ? TimesheetModuleColors.warmButtonGradient : null,
        color: enabled ? null : TimesheetModuleColors.glassBorder,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.paperPlaneTilt(),
            size: 18,
            color: enabled
                ? Colors.white
                : TimesheetModuleColors.warmMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: enabled
                  ? Colors.white
                  : TimesheetModuleColors.warmMuted,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _LaborRow extends StatelessWidget {
  const _LaborRow({
    required this.name,
    required this.sub,
    required this.selected,
    this.dim = false,
  });

  final String name;
  final String sub;
  final bool selected;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.45 : 1,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: LtPersonAvatar(name: name, size: 40),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: TimesheetModuleColors.ink,
          ),
        ),
        subtitle: Text(
          sub,
          style: const TextStyle(
            fontSize: 12,
            color: TimesheetModuleColors.warmMuted,
          ),
        ),
        trailing: Icon(
          selected
              ? PhosphorIcons.checkSquare(PhosphorIconsStyle.fill)
              : PhosphorIcons.square(),
          color: selected
              ? TimesheetModuleColors.accent
              : TimesheetModuleColors.warmMuted,
        ),
      ),
    );
  }
}

class _ForemanRow extends StatelessWidget {
  const _ForemanRow({required this.name, required this.selected});
  final String name;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: LtPersonAvatar(name: name, size: 40),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: TimesheetModuleColors.ink,
        ),
      ),
      trailing: Icon(
        selected
            ? PhosphorIcons.radioButton(PhosphorIconsStyle.fill)
            : PhosphorIcons.circle(),
        color: selected
            ? TimesheetModuleColors.accent
            : TimesheetModuleColors.warmMuted,
      ),
    );
  }
}

class _DetailFrame extends StatelessWidget {
  const _DetailFrame();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: TimesheetModuleColors.warmGradient,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
            child: Row(
              children: [
                Icon(PhosphorIcons.caretLeft(),
                    color: TimesheetModuleColors.ink),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'LT/2026/0001',
                    style: TextStyle(
                      color: TimesheetModuleColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: LtStatusChip(state: LaborTransferState.pending),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: TimesheetModuleColors.glassSurface,
                    borderRadius: BorderRadius.circular(
                      TimesheetModuleLayout.cardRadiusMd,
                    ),
                    border:
                        Border.all(color: TimesheetModuleColors.glassBorder),
                  ),
                  child: const Column(
                    children: [
                      _Info('Requester', 'Karim Nasser'),
                      SizedBox(height: 8),
                      _Info('Target', 'Ahmed Hassan'),
                      SizedBox(height: 8),
                      _Info('Approver', 'Site Manager'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Labors (2)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: TimesheetModuleColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                _labor('Ravi Kumar'),
                const SizedBox(height: 8),
                _labor('Sunil Patel'),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _SubmitBar(enabled: true, label: 'Approve'),
          ),
        ],
      ),
    );
  }

  Widget _labor(String name) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.surface,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusSm),
        border: Border.all(color: TimesheetModuleColors.glassBorder),
      ),
      child: Row(
        children: [
          LtPersonAvatar(name: name, size: 40),
          const SizedBox(width: 10),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: TimesheetModuleColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(
              color: TimesheetModuleColors.warmMuted,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: TimesheetModuleColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
