import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/user_project_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AgreementTileCard extends StatelessWidget {
  const AgreementTileCard({
    super.key,
    required this.agreement,
    required this.onTap,
  });

  final UserProjectModel agreement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photoUrl =
        ProjectsDashboardAggregator.normalizePhotoUrl(agreement.photoUrl);
    final agreementLabel = agreement.agreementNo?.isNotEmpty == true
        ? agreement.agreementNo!
        : '${agreement.projectId}';
    final amountFmt = NumberFormat.compactCurrency(
      locale: 'en',
      symbol: 'AED ',
      decimalDigits: 1,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 152.tw,
        margin: EdgeInsets.only(right: 10.tw),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.tr),
          border: Border.all(color: const Color(0xFF2C2F36), width: 1),
          gradient: const LinearGradient(
            colors: [Color(0xFFD6D6D6), Color(0xFFADB2BD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(12.tw),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PhotoAvatar(photoUrl: photoUrl, name: agreement.projectName),
                  const Spacer(),
                  Text(
                    '${agreement.totalProjects}',
                    style: GoogleFonts.koulen(
                      fontSize: 18.tsp,
                      color: const Color(0xFF1E2365),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.th),
              Text(
                agreementLabel,
                style: GoogleFonts.inter(
                  fontSize: 11.tsp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.th),
              Text(
                agreement.projectName,
                style: GoogleFonts.inter(
                  fontSize: 10.tsp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xB8484848),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                amountFmt.format(agreement.totalProjectsAmount),
                style: GoogleFonts.poppins(
                  fontSize: 10.tsp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E2365),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoAvatar extends StatelessWidget {
  const _PhotoAvatar({required this.photoUrl, required this.name});

  final String photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 16.tr,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {},
        child: photoUrl.isEmpty ? _initials() : null,
      );
    }
    return CircleAvatar(
      radius: 16.tr,
      backgroundColor: const Color(0xFF1E2365),
      child: _initials(),
    );
  }

  Widget _initials() {
    final parts = name.trim().split(RegExp(r'\s+'));
    final letter = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first[0].toUpperCase()
        : '?';
    return Text(
      letter,
      style: GoogleFonts.poppins(
        fontSize: 12.tsp,
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
