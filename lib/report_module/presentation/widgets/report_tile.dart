import 'package:el_race/report_module/core/constants/colors.dart';
import 'package:el_race/report_module/core/constants/text_styles.dart';
import 'package:el_race/report_module/data/models/report_model.dart';
import 'package:el_race/report_module/data/provider/reports_provider.dart';
import 'package:el_race/report_module/presentation/screens/report_detail/report_detail.dart';
import 'package:el_race/report_module/data/models/report_detail_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportTile extends StatefulWidget {
  final ReportModel report;
  final String folderName;
  final ValueChanged<String> onMenuSelected;
  const ReportTile(
      {super.key,
      required this.report,
      required this.onMenuSelected,
      required this.folderName});

  @override
  State<ReportTile> createState() => _ReportTileState();
}

class _ReportTileState extends State<ReportTile> {
  // Hoisted out of build() (was constructed inline in a FutureBuilder,
  // re-firing getReportDetail on every rebuild of this tile — e.g. any
  // scroll-driven rebuild of the surrounding list). Per
  // FIX_IMPLEMENTATION_PLAN.md Phase 5.2.
  late final Future<ReportDetailModel?> _reportDetailFuture;

  @override
  void initState() {
    super.initState();
    _reportDetailFuture = reportProvider.getReportDetail(widget.report);
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final folderName = widget.folderName;
    final onMenuSelected = widget.onMenuSelected;
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ReportDetailScreen(
                      report: report,
                      folderName: folderName,
                    )));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: CustomColors.containerColor),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        report.name,
                        style: CustomTextStyle.reportTitle,
                      ),
                    ),
                    InkWell(
                      child: PopupMenuButton<String>(
                        tooltip: 'More options',
                        icon: const Icon(Icons.more_vert_rounded),
                        onSelected: onMenuSelected,
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                Text(
                  DateFormat("dd MMM yyyy HH:mma").format(report.createdAt),
                  style: CustomTextStyle.smallGrey,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FutureBuilder<ReportDetailModel?>(
                        future: _reportDetailFuture,
                        builder: (context, snapshot) {
                          return Container(
                            decoration: BoxDecoration(
                              color: CustomColors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 2, horizontal: 12),
                            child: Text(
                              "Images : ${snapshot.data?.reportItems.length ?? 0}",
                              style: CustomTextStyle.smallWhite,
                            ),
                          );
                        }),
                  ],
                )
              ],
            ),
            // Positioned(
            //     right: 0,
            //     top: 0,
            //     child: )
          ],
        ),
      ),
    );
  }
}
