import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/Email%20Approval/data/it_hardware_request_repository.dart';
import 'package:el_race/ui/presentation/Email%20Approval/models/it_hardware_request.dart';
import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ItHardwareRequestDetailsScreen extends StatefulWidget {
  const ItHardwareRequestDetailsScreen({
    super.key,
    required this.requestId,
    required this.repository,
  });

  final String requestId;
  final ItHardwareRequestRepository repository;

  @override
  State<ItHardwareRequestDetailsScreen> createState() =>
      _ItHardwareRequestDetailsScreenState();
}

class _ItHardwareRequestDetailsScreenState
    extends State<ItHardwareRequestDetailsScreen> {
  late final ItHardwareRequestFlow _flow;
  late Future<ItHardwareRequest> _requestFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _flow = ItHardwareRequestFlow(widget.repository);
    _requestFuture = _flow.load(widget.requestId);
  }

  void _retry() {
    setState(() {
      _requestFuture = _flow.load(widget.requestId);
    });
  }

  Future<String?> _requestRejectComment() async {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final value = controller.text.trim();
          return AlertDialog(
            title: const Text('Reject Comment'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 50,
              minLines: 3,
              maxLines: 4,
              onChanged: (_) => setDialogState(() {}),
              decoration: const InputDecoration(
                hintText: 'Enter the reason for rejection...',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: value.isEmpty
                    ? null
                    : () => Navigator.of(dialogContext).pop(value),
                child: const Text('Reject'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return comment;
  }

  Future<void> _runAction({required bool approve}) async {
    String? rejectComment;
    if (!approve) {
      rejectComment = await _requestRejectComment();
      if (rejectComment == null || rejectComment.trim().isEmpty) return;
    }

    setState(() => _submitting = true);
    try {
      final completed = approve
          ? await _flow.approve(widget.requestId)
          : await _flow.reject(
              widget.requestId,
              comment: rejectComment!.trim(),
            );
      if (!mounted) return;
      if (completed) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ItHardwareRequest>(
      future: _requestFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildShell(
            title: 'IT Hardware Request',
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildShell(
            title: 'IT Hardware Request',
            child: _LoadError(
              message: snapshot.error?.toString() ??
                  'Unable to load the IT hardware request.',
              onRetry: _retry,
            ),
          );
        }

        return _buildRequest(snapshot.requireData);
      },
    );
  }

  Widget _buildShell({required String title, required Widget child}) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ApprovalsOverviewTheme.overlay,
      child: Scaffold(
        backgroundColor: ApprovalsOverviewTheme.screenBase,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: ApprovalsOverviewTheme.screenGradient,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ContextualGlassChromeHeader(
                  title: title,
                  showBack: true,
                  onLightSurface: true,
                  transparentGlassBar: false,
                  scrimTopOpacity: 0,
                ),
                Expanded(child: child),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequest(ItHardwareRequest request) {
    final employeeInformation = [
      _ItDetailItem('Request Type', request.requestType),
      _ItDetailItem('Request Date', request.requestDate),
      _ItDetailItem('Requester', request.requester),
      _ItDetailItem('Requester Department', request.requesterDepartment),
    ];
    final hardwareUser = [
      _ItDetailItem('Hardware User', request.hardwareUser),
      _ItDetailItem('Employee ID', request.employeeId),
      _ItDetailItem('Department', request.department),
      _ItDetailItem('Current Approver', request.currentApprover),
      _ItDetailItem('Project', request.project),
      _ItDetailItem('Project Manager', request.projectManager),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ApprovalsOverviewTheme.overlay,
      child: Scaffold(
        backgroundColor: ApprovalsOverviewTheme.screenBase,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: ApprovalsOverviewTheme.screenGradient,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ContextualGlassChromeHeader(
                  title: request.requestNumber.isNotEmpty
                      ? request.requestNumber
                      : 'IT Hardware Request',
                  showBack: true,
                  onLightSurface: true,
                  transparentGlassBar: false,
                  scrimTopOpacity: 0,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16.tw,
                      4.th,
                      16.tw,
                      82.th + context.systemBottomInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _RequestHeader(request: request),
                        SizedBox(height: 8.th),
                        _ItDetailsSection(
                          title: 'Employee Information',
                          items: employeeInformation,
                        ),
                        SizedBox(height: 8.th),
                        _ItDetailsSection(
                          title: 'Hardware User',
                          items: hardwareUser,
                        ),
                        SizedBox(height: 8.th),
                        _HardwareLinesSection(lines: request.lines),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16.tw,
              right: 16.tw,
              bottom: context.systemBottomInset + 8.th,
              child: _DecisionBar(
                submitting: _submitting,
                onReject: () => _runAction(approve: false),
                onApprove: () => _runAction(approve: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.tw),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40.tsp,
              color: ApprovalsOverviewTheme.itRequest,
            ),
            SizedBox(height: 12.th),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.tsp,
                color: ApprovalsOverviewTheme.textSoft,
              ),
            ),
            SizedBox(height: 14.th),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestHeader extends StatelessWidget {
  const _RequestHeader({required this.request});

  final ItHardwareRequest request;

  @override
  Widget build(BuildContext context) {
    final displayName = request.hardwareUser.isNotEmpty
        ? request.hardwareUser
        : request.requester;

    return OverviewGlassPanel(
      fillAlpha: 0.88,
      blurSigma: 10,
      radius: 16,
      padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 8.th),
      child: Row(
        children: [
          ApprovalDisplayHelpers.buildCircleAvatar(
            imageData: request.imageUrl,
            size: 62.tw,
            initials: displayName,
          ),
          SizedBox(width: 12.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isEmpty ? 'Hardware User' : displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15.tsp,
                    fontWeight: FontWeight.w700,
                    color: ApprovalsOverviewTheme.textDark,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 6.th),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.tw,
                    vertical: 5.th,
                  ),
                  decoration: BoxDecoration(
                    color: ApprovalsOverviewTheme.itRequest,
                    borderRadius: BorderRadius.circular(16.tr),
                  ),
                  child: Text(
                    request.requestType.isEmpty
                        ? 'IT Hardware Request'
                        : request.requestType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10.tsp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItDetailsSection extends StatelessWidget {
  const _ItDetailsSection({required this.title, required this.items});

  final String title;
  final List<_ItDetailItem> items;

  @override
  Widget build(BuildContext context) {
    final visible = items
        .where((item) => item.value.trim().isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    return OverviewGlassPanel(
      fillAlpha: 0.9,
      blurSigma: 8,
      radius: 16,
      padding: EdgeInsets.fromLTRB(14.tw, 12.th, 14.tw, 12.th),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title),
          SizedBox(height: 10.th),
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = 8.tw;
              final cellWidth = (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: 8.th,
                children: [
                  for (final item in visible)
                    SizedBox(
                      width: cellWidth,
                      child: _ItDetailCell(item: item),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HardwareLinesSection extends StatelessWidget {
  const _HardwareLinesSection({required this.lines});

  final List<ItHardwareRequestLine> lines;

  String _quantity(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return OverviewGlassPanel(
      fillAlpha: 0.9,
      blurSigma: 8,
      radius: 16,
      padding: EdgeInsets.fromLTRB(14.tw, 12.th, 14.tw, 12.th),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Requested Hardware Items'),
          SizedBox(height: 10.th),
          if (lines.isEmpty)
            Text(
              'No requested hardware items.',
              style: GoogleFonts.poppins(
                fontSize: 11.tsp,
                color: ApprovalsOverviewTheme.textSoft,
              ),
            )
          else
            for (var index = 0; index < lines.length; index++) ...[
              _HardwareLineCard(
                index: index + 1,
                line: lines[index],
                quantity: _quantity(lines[index].quantity),
              ),
              if (index != lines.length - 1) SizedBox(height: 8.th),
            ],
        ],
      ),
    );
  }
}

class _HardwareLineCard extends StatelessWidget {
  const _HardwareLineCard({
    required this.index,
    required this.line,
    required this.quantity,
  });

  final int index;
  final ItHardwareRequestLine line;
  final String quantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.tw),
      decoration: BoxDecoration(
        color: ApprovalsOverviewTheme.screenTintLight.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12.tr),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Item $index',
            style: GoogleFonts.poppins(
              fontSize: 9.tsp,
              fontWeight: FontWeight.w700,
              color: ApprovalsOverviewTheme.itRequest,
            ),
          ),
          SizedBox(height: 8.th),
          _LineValue(label: 'Item', value: line.item),
          _LineValue(label: 'Quantity', value: quantity),
          _LineValue(label: 'Specifications', value: line.specifications),
          _LineValue(label: 'Reason', value: line.reason, last: true),
        ],
      ),
    );
  }
}

class _LineValue extends StatelessWidget {
  const _LineValue({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 6.th),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92.tw,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9.tsp,
                fontWeight: FontWeight.w500,
                color: ApprovalsOverviewTheme.textSoft,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: GoogleFonts.poppins(
                fontSize: 10.tsp,
                fontWeight: FontWeight.w600,
                color: ApprovalsOverviewTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 10.tsp,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        color: ApprovalsOverviewTheme.screenDeep,
      ),
    );
  }
}

class _ItDetailCell extends StatelessWidget {
  const _ItDetailCell({required this.item});

  final _ItDetailItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 68.th),
      padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 10.th),
      decoration: BoxDecoration(
        color: ApprovalsOverviewTheme.screenTintLight.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12.tr),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 9.tsp,
              fontWeight: FontWeight.w500,
              color: ApprovalsOverviewTheme.textSoft,
            ),
          ),
          SizedBox(height: 4.th),
          Text(
            item.value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12.tsp,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: ApprovalsOverviewTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionBar extends StatelessWidget {
  const _DecisionBar({
    required this.submitting,
    required this.onReject,
    required this.onApprove,
  });

  final bool submitting;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    return OverviewGlassPanel(
      fillAlpha: 0.82,
      blurSigma: 14,
      radius: 20,
      padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 6.th),
      child: Row(
        children: [
          Expanded(
            child: _DecisionButton(
              label: 'Reject',
              icon: Icons.close_rounded,
              foreground: const Color(0xFFC62828),
              background: const Color(0xFFF7D6D8),
              onTap: submitting ? null : onReject,
            ),
          ),
          SizedBox(width: 8.tw),
          Expanded(
            child: _DecisionButton(
              label: 'Approve',
              icon: Icons.check_rounded,
              foreground: const Color(0xFF168A50),
              background: const Color(0xFFD7EFE2),
              onTap: submitting ? null : onApprove,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14.tr),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.tr),
        child: SizedBox(
          height: 48.th,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28.tw,
                height: 28.tw,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: foreground.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, size: 17.tsp, color: foreground),
              ),
              SizedBox(width: 8.tw),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItDetailItem {
  const _ItDetailItem(this.label, this.value);

  final String label;
  final String value;
}
