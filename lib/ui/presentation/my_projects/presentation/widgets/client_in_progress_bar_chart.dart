import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/client_in_progress_grouper.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/client_projects_bottom_sheet.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_dashboard_shimmer.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_year_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bar row height (count label + bar + logo) — must fit tallest column.
double get _kChartContentHeight => 168.th;

class ClientInProgressBarChart extends StatelessWidget {
  const ClientInProgressBarChart({
    super.key,
    required this.clients,
    required this.title,
    required this.selectedYear,
    required this.availableYears,
    required this.onYearChanged,
    this.isLoading = false,
    this.yearPickerTitle = 'Select year',
    this.yearAllLabel = 'All',
  });

  final List<ClientInProgressBarData> clients;
  final String title;
  final int? selectedYear;
  final List<int> availableYears;
  final ValueChanged<int?> onYearChanged;
  final bool isLoading;
  final String yearPickerTitle;
  final String yearAllLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.tw, 8.th, 16.tw, 0),
      padding: EdgeInsets.fromLTRB(14.tw, 12.th, 14.tw, 10.th),
      decoration: ProjectsDashboardTheme.frostedPanel(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14.tsp,
                    fontWeight: FontWeight.w700,
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
              ),
              _YearPickerTrigger(
                years: availableYears,
                selectedYear: selectedYear,
                pickerTitle: yearPickerTitle,
                allLabel: yearAllLabel,
                onChanged: onYearChanged,
              ),
            ],
          ),
          SizedBox(height: 10.th),
          SizedBox(
            height: _kChartContentHeight,
            width: double.infinity,
            child: isLoading
                ? const ProjectsChartShimmer()
                : clients.isEmpty
                    ? Center(
                        child: Text(
                          '—',
                          style: GoogleFonts.poppins(
                            fontSize: 13.tsp,
                            color: ProjectsDashboardTheme.greyPanel,
                          ),
                        ),
                      )
                    : _ChartBody(
                        height: _kChartContentHeight,
                        clients: clients,
                      ),
          ),
        ],
      ),
    );
  }
}

class _YearPickerTrigger extends StatelessWidget {
  const _YearPickerTrigger({
    required this.years,
    required this.selectedYear,
    required this.pickerTitle,
    required this.onChanged,
    required this.allLabel,
  });

  final List<int> years;
  final int? selectedYear;
  final String pickerTitle;
  final ValueChanged<int?> onChanged;
  final String allLabel;

  Future<void> _openPicker(BuildContext context) async {
    final picked = await ProjectsYearPickerSheet.show(
      context,
      years: years,
      selectedYear: selectedYear,
      title: pickerTitle,
      allLabel: allLabel,
    );
    if (picked == null) return;
    if (picked == kProjectsYearPickerAll) {
      onChanged(null);
      return;
    }
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final items = years.isNotEmpty ? years : [DateTime.now().year];
    final displayLabel = selectedYear == null
        ? allLabel
        : (items.contains(selectedYear!)
            ? '${selectedYear!}'
            : '${items.first}');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPicker(context),
        borderRadius: BorderRadius.circular(20.tr),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 6.th),
          decoration: ProjectsDashboardTheme.dropdownChipDecoration(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayLabel,
                style: GoogleFonts.poppins(
                  fontSize: 12.tsp,
                  fontWeight: FontWeight.w600,
                  color: ProjectsDashboardTheme.white,
                ),
              ),
              SizedBox(width: 2.tw),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20.tsp,
                color: ProjectsDashboardTheme.white.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartBody extends StatelessWidget {
  const _ChartBody({
    required this.height,
    required this.clients,
  });

  final double height;
  final List<ClientInProgressBarData> clients;

  static const double _logoSize = 34;
  static const double _barAreaMax = 86;

  @override
  Widget build(BuildContext context) {
    final maxCount = clients.map((c) => c.projectCount).reduce(
          (a, b) => a > b ? a : b,
        );

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: clients.length,
      separatorBuilder: (_, __) => SizedBox(width: 12.tw),
      itemBuilder: (context, index) {
        final client = clients[index];
        final ratio = maxCount > 0 ? client.projectCount / maxCount : 0.0;
        final barHeight = (_barAreaMax.th * ratio).clamp(14.th, _barAreaMax.th);

        return GestureDetector(
          onTap: () => showClientProjectsBottomSheet(
            context: context,
            client: client,
          ),
          child: SizedBox(
            width: 52.tw,
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${client.projectCount}',
                  style: GoogleFonts.koulen(
                    fontSize: 11.tsp,
                    height: 1.1,
                    color: ProjectsDashboardTheme.white,
                  ),
                  maxLines: 1,
                ),
                SizedBox(height: 4.th),
                _MaroonBar(height: barHeight),
                SizedBox(height: 5.th),
                SizedBox(
                  width: _logoSize.tw,
                  height: _logoSize.tw,
                  child: _ClientLogoAvatar(
                    name: client.clientName,
                    photoUrl: client.logoUrl,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MaroonBar extends StatelessWidget {
  const _MaroonBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26.tw,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.tr)),
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            ProjectsDashboardTheme.maroon.withValues(alpha: 0.85),
            ProjectsDashboardTheme.maroonLight.withValues(alpha: 0.95),
            ProjectsDashboardTheme.maroonSoft,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: ProjectsDashboardTheme.maroon.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _ClientLogoAvatar extends StatelessWidget {
  const _ClientLogoAvatar({
    required this.name,
    required this.photoUrl,
  });

  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    Widget child;
    if (photoUrl.isNotEmpty) {
      child = ClipOval(
        child: Image.network(
          photoUrl,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(initial),
        ),
      );
    } else {
      child = _initials(initial);
    }

    return Container(
      padding: EdgeInsets.all(2.tw),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ProjectsDashboardTheme.white.withValues(alpha: 0.65),
          width: 1.8,
        ),
      ),
      child: child,
    );
  }

  Widget _initials(String letter) {
    return CircleAvatar(
      backgroundColor: ProjectsDashboardTheme.navy.withValues(alpha: 0.85),
      child: FittedBox(
        child: Text(
          letter,
          style: GoogleFonts.poppins(
            fontSize: 14.tsp,
            fontWeight: FontWeight.w700,
            color: ProjectsDashboardTheme.white,
          ),
        ),
      ),
    );
  }
}
