import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/lpo/screens/lpo_pdf_viewer_screen.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact print icon → menu: **Print** (invoice report) or
/// **Supporting Document** (merge all supporting PDFs in-app).
class InvoicePrintMenuButton extends StatefulWidget {
  const InvoicePrintMenuButton({
    super.key,
    required this.invoiceId,
    this.title,
    this.color = PurchaseTheme.accentDeep,
    this.backgroundColor,
    this.iconSize,
    this.buttonSize,
  });

  final int invoiceId;
  final String? title;
  final Color color;
  final Color? backgroundColor;
  final double? iconSize;
  final double? buttonSize;

  @override
  State<InvoicePrintMenuButton> createState() => _InvoicePrintMenuButtonState();
}

class _InvoicePrintMenuButtonState extends State<InvoicePrintMenuButton> {
  final _repo = PurchaseRepository();
  bool _busy = false;

  Future<void> _openPrint() async {
    setState(() => _busy = true);
    try {
      final url = await _repo.fetchInvoiceReportUrl(widget.invoiceId);
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        _toast('Invoice print is not available.');
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LpoPdfViewerScreen(
            pdfUrl: url,
            title: widget.title ?? 'Invoice Print',
          ),
        ),
      );
    } catch (e) {
      if (mounted) _toast('Could not open invoice print.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSupportingDocuments() async {
    setState(() => _busy = true);
    try {
      final parts =
          await _repo.fetchInvoiceSupportingDocumentPdfBytes(widget.invoiceId);
      if (!mounted) return;
      if (parts.isEmpty) {
        _toast('No supporting PDF document to show.');
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LpoPdfViewerScreen(
            pdfByteParts: parts,
            title: widget.title ?? 'Supporting Documents',
          ),
        ),
      );
    } catch (e) {
      if (mounted) _toast('Could not open supporting documents.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.buttonSize ?? 34.tw;
    final iconSize = widget.iconSize ?? 18.tsp;
    final bg = widget.backgroundColor ?? widget.color.withValues(alpha: 0.12);

    return PopupMenuButton<_InvoicePrintAction>(
      enabled: !_busy && widget.invoiceId > 0,
      tooltip: 'Print options',
      offset: Offset(0, size),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.tr)),
      onSelected: (action) {
        if (action == _InvoicePrintAction.print) {
          _openPrint();
        } else {
          _openSupportingDocuments();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _InvoicePrintAction.print,
          child: Text(
            'Print',
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        PopupMenuItem(
          value: _InvoicePrintAction.supportingDocument,
          child: Text(
            'Supporting Document',
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10.tr),
        ),
        child: _busy
            ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.color,
                ),
              )
            : Icon(
                Icons.print_outlined,
                size: iconSize,
                color: widget.color,
              ),
      ),
    );
  }
}

enum _InvoicePrintAction { print, supportingDocument }
