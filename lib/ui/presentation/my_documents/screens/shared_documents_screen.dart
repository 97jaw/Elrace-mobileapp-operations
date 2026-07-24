import 'package:el_race/ui/presentation/my_documents/screens/share_documents_tab.dart';
import 'package:el_race/ui/presentation/my_documents/theme/shared_documents_theme.dart';
import 'package:el_race/ui/presentation/my_documents/utils/document_attachment_opener.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_glass_header.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Dedicated Shared Documents surface (Productivity home widget entry).
class SharedDocumentsScreen extends StatelessWidget {
  const SharedDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: SharedDocumentsTheme.hubBackgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ProductivityGlassHeader(
              title: 'Shared Documents',
              showBack: true,
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  8.h,
                  16.w,
                  context.systemBottomInset + 8.h,
                ),
                child: ShareDocumentsTab(
                  onOpenDocument: (document) =>
                      DocumentAttachmentOpener.open(context, document),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
