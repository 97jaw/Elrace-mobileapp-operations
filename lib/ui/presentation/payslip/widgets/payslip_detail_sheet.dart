import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/payslip/models/payslip_models.dart';
import 'package:el_race/core/payslip/network/payslip_api_client.dart';
import 'package:el_race/core/payslip/payslip_json_parsers.dart';
import 'package:el_race/core/payslip/providers/payslip_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/ui/presentation/payslip/widgets/payslip_document_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Bottom-to-top payslip detail sheet (same pattern as attendance stat sheets).
Future<void> showPayslipDetailSheet(
  BuildContext context, {
  required String payslipId,
  String? title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (sheetContext) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: _PayslipDetailSheet(
        payslipId: payslipId,
        title: title ?? 'Payslip details',
      ),
    ),
  );
}

class _PayslipDetailSheet extends ConsumerStatefulWidget {
  const _PayslipDetailSheet({
    required this.payslipId,
    required this.title,
  });

  final String payslipId;
  final String title;

  @override
  ConsumerState<_PayslipDetailSheet> createState() =>
      _PayslipDetailSheetState();
}

class _PayslipDetailSheetState extends ConsumerState<_PayslipDetailSheet> {
  PayslipRecord? _record;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _record = null;
    });

    final parsedId = int.tryParse(widget.payslipId.trim());
    if (parsedId == null || parsedId <= 0) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Invalid payslip id';
      });
      return;
    }

    try {
      final PayslipApiClient client = ref.read(payslipApiClientProvider);
      final env = await client
          .fetchPayslipDetail(widget.payslipId)
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (env.success && env.data != null) {
        setState(() {
          _record = recordFromJson(env.data!);
          _loading = false;
        });
        return;
      }
      setState(() {
        _loading = false;
        _error = env.error ?? 'Could not load payslip';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F8FC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.tr)),
          ),
          child: Column(
            children: [
              SizedBox(height: 10.th),
              Container(
                width: 42.tw,
                height: 4.th,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.tw, 12.th, 8.tw, 8.th),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: HrModuleTypography.sectionHeading().copyWith(
                              fontSize: 16.tsp,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: HrModuleColors.border),
              Expanded(child: _buildBody(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.tw),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Could not load payslip',
                textAlign: TextAlign.center,
                style: HrModuleTypography.sectionHeading().copyWith(
                      fontSize: 15.tsp,
                    ),
              ),
              SizedBox(height: 8.th),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: HrModuleTypography.body(),
              ),
              SizedBox(height: 16.th),
              FilledButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final record = _record;
    if (record == null) {
      return Center(
        child: Text(
          'Payslip not found',
          style: HrModuleTypography.body(),
        ),
      );
    }
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(14.tw, 12.th, 14.tw, 28.th),
      children: [
        PayslipDocumentView(record: record),
      ],
    );
  }
}
