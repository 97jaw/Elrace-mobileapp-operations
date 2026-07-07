import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/tm_stat_tile.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Dark-contrast dashboard header with profile + team counter.
class TmDashboardHeader extends StatefulWidget {
  const TmDashboardHeader({
    super.key,
    required this.profile,
    required this.counterLabel,
    required this.counterValue,
    required this.onCounterTap,
  });

  final TimesheetLoginProfile profile;
  final String counterLabel;
  final int counterValue;
  final VoidCallback onCounterTap;

  @override
  State<TmDashboardHeader> createState() => _TmDashboardHeaderState();
}

class _TmDashboardHeaderState extends State<TmDashboardHeader> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());
  }

  @override
  void didUpdateWidget(covariant TmDashboardHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.displayName != widget.profile.displayName ||
        oldWidget.profile.fileId != widget.profile.fileId ||
        oldWidget.profile.imageUrl != widget.profile.imageUrl) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _startMarquee());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startMarquee() async {
    if (!mounted || !_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    while (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.animateTo(
        max,
        duration: Duration(
          milliseconds: (max * 14).clamp(9000, 20000).toInt(),
        ),
        curve: Curves.linear,
      );
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TimesheetModuleColors.navy,
            Color(0xFF284D7D),
            TimesheetModuleColors.primaryGradientEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
        boxShadow: TimesheetModuleShadows.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ProfileAvatar(
            key: ValueKey(widget.profile.imageUrl ?? widget.profile.fileId),
            name: widget.profile.displayName,
            imageUrl: widget.profile.imageUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 26,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Row(
                      children: [
                        Text(
                          widget.profile.displayName,
                          style: TimesheetModuleTypography.display().copyWith(
                            color: TimesheetModuleColors.surface,
                          ),
                        ),
                        const SizedBox(width: 48),
                        Text(
                          widget.profile.displayName,
                          style: TimesheetModuleTypography.display().copyWith(
                            color: TimesheetModuleColors.surface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'File ID: ${widget.profile.fileId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.surface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: TimesheetModuleColors.surface.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: widget.onCounterTap,
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: kTmStatTileMinHeight,
                  minWidth: 88,
                ),
                child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${widget.counterValue}',
                      style: TimesheetModuleTypography.h1().copyWith(
                        color: TimesheetModuleColors.surface,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIcons.usersThree(),
                          size: 14,
                          color: TimesheetModuleColors.surface.withValues(
                            alpha: 0.85,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.counterLabel,
                          style: TimesheetModuleTypography.caption().copyWith(
                            color: TimesheetModuleColors.surface.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl,
  });

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final url = imageUrl?.trim() ?? '';

    return Container(
      width: TimesheetModuleLayout.headerAvatarSize,
      height: TimesheetModuleLayout.headerAvatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: TimesheetModuleColors.surface, width: 2),
        color: TimesheetModuleColors.primaryTint,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initial(initial),
            )
          : _initial(initial),
    );
  }

  Widget _initial(String initial) {
    return Center(
      child: Text(
        initial,
        style: TimesheetModuleTypography.h2().copyWith(
          color: TimesheetModuleColors.surface,
        ),
      ),
    );
  }
}
