import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/providers/purchase_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Debug-only: switch officer / manager / management for domain testing.
class PurchaseDevRoleToggleBar extends ConsumerWidget {
  const PurchaseDevRoleToggleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();

    final override = ref.watch(purchaseDevRoleOverrideProvider);
    final access = ref.watch(purchaseAccessProvider);
    final notifier = ref.read(purchaseDevRoleOverrideProvider.notifier);

    void select(PurchaseDevTestRole? role) {
      notifier.setOverride(role);
      ref.invalidate(purchaseOverviewProvider);
    }

    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: PurchaseTheme.glassPanel(radius: 10.r).copyWith(
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Dev: ${override?.label ?? 'Login'} · ${access.scopeLabel.isNotEmpty ? access.scopeLabel : access.scope}',
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: PurchaseTheme.textSecondary,
              ),
            ),
          ),
          _chip(
            label: 'Officer',
            selected: override == PurchaseDevTestRole.officer,
            onTap: () => select(PurchaseDevTestRole.officer),
          ),
          SizedBox(width: 4.w),
          _chip(
            label: 'Manager',
            selected: override == PurchaseDevTestRole.manager,
            onTap: () => select(PurchaseDevTestRole.manager),
          ),
          SizedBox(width: 4.w),
          _chip(
            label: 'Mgmt',
            selected: override == PurchaseDevTestRole.management,
            onTap: () => select(PurchaseDevTestRole.management),
          ),
          SizedBox(width: 4.w),
          _chip(
            label: 'Reset',
            selected: override == null,
            onTap: () => select(null),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: selected
              ? PurchaseTheme.accentBlue
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : PurchaseTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
