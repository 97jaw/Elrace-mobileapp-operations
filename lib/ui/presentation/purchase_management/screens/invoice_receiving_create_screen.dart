import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_background.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_glass_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class InvoiceReceivingCreateScreen extends StatefulWidget {
  const InvoiceReceivingCreateScreen({super.key, this.testRole});

  final PurchaseDevTestRole? testRole;

  @override
  State<InvoiceReceivingCreateScreen> createState() =>
      _InvoiceReceivingCreateScreenState();
}

class _InvoiceReceivingCreateScreenState
    extends State<InvoiceReceivingCreateScreen> {
  final _repo = PurchaseRepository();
  final _invoiceNoCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  List<LpoOption> _lpoOptions = [];
  LpoOption? _selectedLpo;
  DateTime? _invoiceDate;
  DateTime? _invoicingDate;
  bool _loadingLpos = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLpos();
  }

  @override
  void dispose() {
    _invoiceNoCtrl.dispose();
    _amountCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLpos({String keyword = ''}) async {
    setState(() {
      _loadingLpos = true;
      _error = null;
    });
    try {
      final items = await _repo.fetchLpoOptions(
        keyword: keyword,
        testRole: widget.testRole,
      );
      if (!mounted) return;
      setState(() {
        _lpoOptions = items;
        _loadingLpos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingLpos = false;
      });
    }
  }

  Future<void> _pickDate(bool invoicing) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (invoicing) {
        _invoicingDate = picked;
      } else {
        _invoiceDate = picked;
      }
    });
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (_selectedLpo == null || _invoiceNoCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Invoice No and LPO are required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
      final created = await _repo.createInvoiceReceiving(
        invoiceNo: _invoiceNoCtrl.text.trim(),
        lpoId: _selectedLpo!.id,
        invoiceDate: _fmt(_invoiceDate),
        invoicingDate: _fmt(_invoicingDate),
        amount: amount,
        remark: _remarkCtrl.text.trim(),
        testRole: widget.testRole,
      );
      if (!mounted) return;
      if (created == null) {
        setState(() {
          _error = 'Create failed. Ensure you have DC role.';
          _submitting = false;
        });
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PurchaseBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
        children: [
          PurchaseManagementGlassHeader(
            title: 'Create Invoice Receiving',
            showBack: true,
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                  _field(
                    label: 'Invoice No',
                    child: TextField(
                      controller: _invoiceNoCtrl,
                      decoration: _inputDeco('e.g. 0081-SHAM'),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _field(
                    label: 'LPO No',
                    child: _loadingLpos
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<LpoOption>(
                            value: _selectedLpo,
                            decoration: _inputDeco('Select LPO'),
                            items: _lpoOptions
                                .map(
                                  (o) => DropdownMenuItem(
                                    value: o,
                                    child: Text(
                                      '${o.name} · ${o.partner}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() {
                              _selectedLpo = v;
                              if (v != null && _amountCtrl.text.isEmpty) {
                                _amountCtrl.text = v.amount.toStringAsFixed(2);
                              }
                            }),
                          ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          label: 'Invoice Date',
                          child: OutlinedButton(
                            onPressed: () => _pickDate(false),
                            child: Text(_fmt(_invoiceDate).isEmpty
                                ? 'Pick date'
                                : _fmt(_invoiceDate)),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _field(
                          label: 'Invoicing Date',
                          child: OutlinedButton(
                            onPressed: () => _pickDate(true),
                            child: Text(_fmt(_invoicingDate).isEmpty
                                ? 'Pick date'
                                : _fmt(_invoicingDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _field(
                    label: 'Amount',
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDeco('0.00'),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _field(
                    label: 'Remark',
                    child: TextField(
                      controller: _remarkCtrl,
                      maxLines: 2,
                      decoration: _inputDeco('Optional'),
                    ),
                  ),
                  if (_error != null) ...[
                    SizedBox(height: 12.h),
                    Text(
                      _error!,
                      style: GoogleFonts.poppins(
                          color: Colors.red, fontSize: 12.sp),
                    ),
                  ],
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PurchaseTheme.accentDeep,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Save as Draft',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF8A9BB5),
          ),
        ),
        SizedBox(height: 6.h),
        child,
      ],
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Color(0xFFE0E4EE)),
        ),
      );
}
