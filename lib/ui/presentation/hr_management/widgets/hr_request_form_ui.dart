import 'package:el_race/core/hr_management/network/hr_api_client.dart';
import 'package:el_race/ui/widgets/header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Shared look matching [RequestLeavePageNew] (HeaderWidget + white card).
abstract final class HrRequestFormUi {
  static const Color primary = Color(0xFF151544);
  static const Color accentGrey = Color(0xFF5E5E5E);
  static const Color pageBg = Color(0xFFF5F5F5);

  static TextStyle titleStyle() => GoogleFonts.poppins(
        fontSize: 18.sp,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.5,
        color: primary,
      );

  static TextStyle fieldLabelStyle() => GoogleFonts.poppins(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
      );

  static TextStyle valueStyle() => GoogleFonts.poppins(
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        color: primary,
      );

  static InputDecoration fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: accentGrey),
      ),
    );
  }

  static Widget label(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(text, style: fieldLabelStyle()),
    );
  }

  /// Overflow-safe dropdown (fixes RenderFlex yellow/black stripe).
  static Widget dropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required String hint,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item.value,
              child: DefaultTextStyle.merge(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: item.child,
              ),
            ),
          )
          .toList(),
      selectedItemBuilder: (context) => items
          .map(
            (item) => Align(
              alignment: Alignment.centerLeft,
              child: DefaultTextStyle.merge(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: item.child,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
      decoration: fieldDecoration(hint),
      icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
    );
  }

  static Widget dateButton({
    required String labelText,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label(labelText),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatDate(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle().copyWith(
                      color: date == null ? Colors.grey : primary,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today_outlined,
                    size: 18.w, color: accentGrey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget readonlyRow(String title, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Expanded(child: Text(title, style: fieldLabelStyle())),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: valueStyle(),
            ),
          ),
        ],
      ),
    );
  }

  static Widget submitButton({
    required VoidCallback? onPressed,
    required bool loading,
    String label = 'SUBMIT',
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
          ),
          elevation: 2,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  static Widget secondaryButton({
    required VoidCallback onPressed,
    String label = 'SAVE DRAFT',
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44.h,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: Colors.grey[300]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static String formatDate(DateTime? d) {
    if (d == null) return 'Pick date';
    return DateFormat('dd MMM yyyy').format(d);
  }

  static String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static Future<DateTime?> pickDate(
    BuildContext context, {
    DateTime? initial,
    DateTime? first,
    DateTime? last,
  }) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: first ?? now.subtract(const Duration(days: 365)),
      lastDate: last ?? now.add(const Duration(days: 365 * 2)),
    );
  }

  static Future<bool> submit({
    required HrApiClient api,
    required String code,
    required Map<String, dynamic> fields,
    String? description,
  }) async {
    final env = await api.submitHrRequest(
      code: code,
      fields: fields,
      description: description,
    );
    if (env.success) {
      final refNo = env.data?['reference']?.toString() ?? '';
      Fluttertoast.showToast(
        msg: refNo.isEmpty ? 'Request submitted' : 'Request submitted — $refNo',
      );
      return true;
    }
    Fluttertoast.showToast(msg: env.error ?? 'Submit failed');
    return false;
  }
}

/// Page chrome matching sick / annual leave request screens.
class HrLegacyRequestFormShell extends StatelessWidget {
  const HrLegacyRequestFormShell({
    super.key,
    required this.title,
    required this.formKey,
    required this.children,
    required this.onSubmit,
    this.onSaveDraft,
    this.submitting = false,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onSubmit;
  final VoidCallback? onSaveDraft;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HrRequestFormUi.pageBg,
      appBar: const HeaderWidget(),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Text(title.toUpperCase(), style: HrRequestFormUi.titleStyle()),
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20.w),
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...children,
                        SizedBox(height: 24.h),
                        if (onSaveDraft != null) ...[
                          HrRequestFormUi.secondaryButton(onPressed: onSaveDraft!),
                          SizedBox(height: 10.h),
                        ],
                        HrRequestFormUi.submitButton(
                          onPressed: onSubmit,
                          loading: submitting,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}
