import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';

import '../../theme/signature_theme.dart';

/// A single stat card ("Needs My Signature" / "Waiting for Others") shown
/// at the top of the Signature -> Home tab, DocuSign-style.
class SignatureStatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const SignatureStatCard({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16.th, horizontal: 12.tw),
          decoration: SignatureTheme.statCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8.tr),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.tr),
                ),
                child: Icon(icon, color: accent, size: 20.tsp),
              ),
              SizedBox(height: 12.th),
              Text('$count', style: SignatureTheme.statValue),
              SizedBox(height: 2.th),
              Text(
                label,
                style: SignatureTheme.statLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
