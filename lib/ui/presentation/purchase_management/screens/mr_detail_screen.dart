import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_status.dart';
import 'package:el_race/ui/presentation/purchase_management/providers/purchase_providers.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_background.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_draft_invoice_row.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_glass_header.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lightweight MR detail — status stepper, key fields, attachments only.
class MrDetailScreen extends ConsumerWidget {
  const MrDetailScreen({super.key, required this.mrId});

  final int mrId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(mrDetailProvider(mrId));
    return PurchaseBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: detailAsync.when(
          loading: () => Column(
          children: [
            PurchaseManagementGlassHeader(
              title: translate('home.purchase.mr_detail_title'),
              showBack: true,
              onBack: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: PurchaseTheme.accentBlue,
                ),
              ),
            ),
          ],
        ),
        error: (e, _) => Column(
          children: [
            PurchaseManagementGlassHeader(
              title: translate('home.purchase.mr_detail_title'),
              showBack: true,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: Text(
                  e.toString(),
                  style: GoogleFonts.poppins(color: Colors.red, fontSize: 13.tsp),
                ),
              ),
            ),
          ],
        ),
        data: (detail) {
          if (detail == null) {
            return Column(
              children: [
                PurchaseManagementGlassHeader(
                  title: translate('home.purchase.mr_detail_title'),
                  showBack: true,
                  onBack: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Center(child: Text('Not found')),
                ),
              ],
            );
          }
          return _MrSummaryContent(detail: detail);
        },
        ),
      ),
    );
  }
}

class _MrSummaryContent extends StatelessWidget {
  const _MrSummaryContent({required this.detail});

  final MrDetail detail;

  @override
  Widget build(BuildContext context) {
    final status = mrStatusFromApi(detail.state);
    return Column(
      children: [
        PurchaseManagementGlassHeader(
          title: detail.name,
          showBack: true,
          onBack: () => Navigator.pop(context),
          titleTrailing: PurchaseStatusChip(
            label: status.label,
            color: status.color,
          ),
        ),
        _MrStatusStepper(current: status),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(14.tw),
            children: [
              _SectionCard(
                title: 'SUMMARY',
                children: [
                  _PersonRow(
                    label: 'Requester',
                    name: detail.requesterName,
                    photoUrl: detail.requesterPhoto,
                  ),
                  _Row(label: 'Department', value: detail.department),
                  _Row(label: 'W.O / P.O', value: detail.woPo),
                  _Row(label: 'Request Date', value: detail.requestDate),
                  _Row(label: 'Deadline', value: detail.deadline),
                  _PersonRow(
                    label: 'Project Manager',
                    name: detail.projectManager,
                    photoUrl: detail.projectManagerPhoto,
                  ),
                  _Row(label: 'Priority', value: detail.priority.toUpperCase()),
                  _Row(label: 'Proposed Vendor', value: detail.proposedVendor),
                  _Row(label: 'Requester Manager', value: detail.requesterManager),
                ],
              ),
              if (detail.approvalTrail.isNotEmpty) ...[
                SizedBox(height: 12.th),
                Text(
                  'APPROVAL STATUS',
                  style: GoogleFonts.poppins(
                    fontSize: 11.tsp,
                    fontWeight: FontWeight.w700,
                    color: PurchaseTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 8.th),
                ...detail.approvalTrail.map((s) => _ApprovalRow(step: s)),
              ],
              if (detail.attachments.isNotEmpty) ...[
                SizedBox(height: 12.th),
                Text(
                  'ATTACHMENTS',
                  style: GoogleFonts.poppins(
                    fontSize: 11.tsp,
                    fontWeight: FontWeight.w700,
                    color: PurchaseTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 8.th),
                ...detail.attachments.map((a) => _AttachmentRow(file: a)),
              ],
              SizedBox(height: 24.th),
            ],
          ),
        ),
      ],
    );
  }
}

class _MrStatusStepper extends StatelessWidget {
  const _MrStatusStepper({required this.current});
  final MrStatus current;

  @override
  Widget build(BuildContext context) {
    const steps = mrStepLabels;
    final currentStep = current.stepIndex;
    return Container(
      color: PurchaseTheme.accentBlue.withValues(alpha: 0.12),
      padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isDone = currentStep > i;
          final isActive = currentStep == i;
          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 10.tw,
                  height: 10.tw,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? const Color(0xFF4ADE80)
                        : isActive
                            ? PurchaseTheme.accentBlue
                            : PurchaseTheme.textMuted.withValues(alpha: 0.4),
                  ),
                ),
                SizedBox(height: 4.th),
                Text(
                  steps[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 7.5.tsp,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isActive
                        ? PurchaseTheme.textPrimary
                        : PurchaseTheme.textMuted,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.tw),
      decoration: PurchaseTheme.glassPanel(radius: 12.tr),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10.tsp,
              fontWeight: FontWeight.w700,
              color: PurchaseTheme.textMuted,
            ),
          ),
          SizedBox(height: 10.th),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 8.th),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.tw,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.tsp,
                color: PurchaseTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11.5.tsp,
                color: PurchaseTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.label,
    required this.name,
    required this.photoUrl,
  });

  final String label;
  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    if (name.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 10.th),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120.tw,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.tsp,
                color: PurchaseTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          PurchaseAvatar(name: name, photoUrl: photoUrl, radius: 16),
          SizedBox(width: 10.tw),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 11.5.tsp,
                fontWeight: FontWeight.w600,
                color: PurchaseTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalRow extends StatelessWidget {
  const _ApprovalRow({required this.step});
  final MrApprovalStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 6.th),
      padding: EdgeInsets.all(12.tw),
      decoration: PurchaseTheme.glassPanel(radius: 10.tr),
      child: Row(
        children: [
          Icon(
            step.status.toLowerCase().contains('pending')
                ? Icons.radio_button_unchecked
                : Icons.check_circle_outline,
            color: PurchaseTheme.accentBlue,
            size: 18.tsp,
          ),
          SizedBox(width: 10.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.reviewer,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 12.tsp)),
                if (step.date.isNotEmpty)
                  Text(step.date,
                      style: GoogleFonts.poppins(
                          fontSize: 10.tsp, color: PurchaseTheme.textMuted)),
              ],
            ),
          ),
          Text(step.status,
              style: GoogleFonts.poppins(
                  fontSize: 10.tsp, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.file});
  final MrAttachment file;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 6.th),
      padding: EdgeInsets.all(12.tw),
      decoration: PurchaseTheme.glassPanel(radius: 10.tr),
      child: Row(
        children: [
          Icon(Icons.attach_file, size: 20.tsp, color: PurchaseTheme.accentBlue),
          SizedBox(width: 10.tw),
          Expanded(child: Text(file.name, style: GoogleFonts.poppins(fontSize: 12.tsp))),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () async {
              final uri = Uri.tryParse(file.url);
              if (uri != null) await launchUrl(uri);
            },
          ),
        ],
      ),
    );
  }
}
