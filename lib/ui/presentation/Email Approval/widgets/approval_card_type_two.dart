import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:convert';
import 'package:el_race/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ApprovalCardTypeTwo extends StatelessWidget {
  final Map<dynamic, dynamic> item;
  final bool isExpanded;
  final VoidCallback onTap;

  const ApprovalCardTypeTwo({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.onTap,
  });

  // Helper method to check if image_emp is a URL or base64 data
  bool _isImageUrl(String imageData) {
    return imageData.startsWith('http://') || imageData.startsWith('https://');
  }

  // Helper widget to display employee image (URL or base64)
  Widget _buildEmployeeImage(dynamic imageEmp) {
    if (imageEmp != null &&
        imageEmp is String &&
        imageEmp.isNotEmpty &&
        imageEmp.toLowerCase() != "false") {
      if (_isImageUrl(imageEmp)) {
        // It's a URL, use Image.network
        return Image.network(
          imageEmp,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/png/profile_1.png',
              fit: BoxFit.cover,
            );
          },
        );
      } else {
        // It's base64 data, decode it
        try {
          return Image.memory(
            base64Decode(imageEmp),
            fit: BoxFit.cover,
          );
        } catch (e) {
          return Image.asset(
            'assets/png/profile_1.png',
            fit: BoxFit.cover,
          );
        }
      }
    }
    // Fallback to default image
    return Image.asset(
      'assets/png/profile_1.png',
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    String name = item["name"] ?? '';
    String type = item["type"] ?? 'ALL';
    String empName = item["approver"] ?? '';
    String location = item["location"] ?? 'N/A';
    String status = item["status"] ?? 'pending';
    String date = item["date"] ?? '';

    List<String> nameParts = name.split(' ');
    List<String> requesterParts = empName.split(" - ");
    String requesterName = requesterParts.isNotEmpty ? requesterParts[0] : '';
    String requesterRole = requesterParts.length > 1 ? requesterParts[1] : '';

    Color getStatusColor(String status) {
      switch (status.toLowerCase()) {
        case 'approved':
          return Colors.green;
        case 'rejected':
          return Colors.red;
        case 'pending':
        default:
          return Colors.orange;
      }
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 105.tw,
        width: 350.tw,
        margin: EdgeInsets.symmetric(horizontal: 10.tw),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 73.tw,
                width: 73.tw,
                padding: EdgeInsets.all(6.tw),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: _buildEmployeeImage(item["image_emp"]),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 130.tw,
                      child: Text(
                        requesterName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.visible,
                        maxLines: null,
                      ),
                    ),
                    SizedBox(height: 5.tw),
                    Text(
                      name,
                      style: TextStyle(color: greyText, fontSize: 13.tsp),
                      overflow: TextOverflow.visible,
                      maxLines: null,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 6.tw, horizontal: 8.tw),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const InfoContainer(text: 'Job Mission'),
                      SizedBox(height: 6.tw),
                      InfoContainer(text: name),
                      SizedBox(height: 6.tw),
                      InfoContainer(
                        text: date,
                        icon: Image.asset('assets/newapp/calendar.png',
                            width: 14.tw, height: 14.tw),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoContainer extends StatelessWidget {
  final String text;
  final Widget? icon;
  final double? fontSize;
  final double? width;

  const InfoContainer({
    super.key,
    required this.text,
    this.icon,
    this.fontSize,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      height: 27.tw,
      width: width ?? 120.tw,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1A1A53), width: 1),
        borderRadius: BorderRadius.circular(13.tr),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            icon!,
            SizedBox(width: 2.tw),
          ],
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: fontSize ?? 11.tsp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A1A53),
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }
}
