import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:el_race/ui/presentation/home_screen/widgets/home_city_helper.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_widgets/profile_sheet_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_widgets/profile_user_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _kTemplateAsset = 'assets/png/background-BC.png';
const _kNavy = Color(0xFF1A2B56);
const _kRed = Color(0xFFC41E3A);
const _kDivider = Color(0xFFD0D5DB);

class BusinessCardScreen extends StatefulWidget {
  const BusinessCardScreen({super.key});

  @override
  State<BusinessCardScreen> createState() => _BusinessCardScreenState();
}

class _BusinessCardScreenState extends State<BusinessCardScreen> {
  final GlobalKey _captureKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    HomeCityHelper.fetchCity().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _shareCard() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      if (!mounted) return;
      await precacheImage(const AssetImage(_kTemplateAsset), context);
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/elrace_business_card.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;
      final box = context.findRenderObject();
      final origin = box is RenderBox
          ? (box.localToGlobal(Offset.zero) & box.size)
          : const Rect.fromLTWH(0, 0, 1, 1);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          sharePositionOrigin: origin,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: ProfileSheetTheme.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Business Card',
          style: TextStyle(fontSize: 17.tsp, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _sharing ? null : _shareCard,
            icon: _sharing
                ? SizedBox(
                    width: 20.tw,
                    height: 20.tw,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.ios_share_rounded, size: 22.tsp),
            tooltip: 'Share',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.tw, vertical: 20.th),
            child: _CardFrame(captureKey: _captureKey),
          ),
        ),
      ),
    );
  }
}

class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.captureKey});

  final GlobalKey captureKey;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width - 56.tw;
    final maxH = MediaQuery.sizeOf(context).height * 0.74;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
      child: AspectRatio(
        aspectRatio: 900 / 1600,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.tr),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.tr),
            child: RepaintBoundary(
              key: captureKey,
              child: const _BusinessCard(),
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard();

  @override
  Widget build(BuildContext context) {
    final name = ProfileUserInfo.displayName();
    final jobTitle =
        ProfileUserInfo.displayOrDash(ProfileUserInfo.displayJobTitle());
    final email = ProfileUserInfo.displayOrDash(ProfileUserInfo.displayEmail());
    final mobile =
        ProfileUserInfo.displayOrDash(ProfileUserInfo.displayMobile());
    final landline = ProfileUserInfo.displayLandline();
    final website = ProfileUserInfo.displayWebsite();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // background-BC.png white plate + left ribbon: keep content clear of
        // the navy accent and inset a bit more from the left.
        final firstNameSize = (w * 0.082).clamp(23.0, 31.0);
        final restNameSize = (w * 0.044).clamp(13.5, 16.5);
        final titleSize = (w * 0.031).clamp(10.5, 12.5);
        final contactSize = (w * 0.034).clamp(11.5, 13.5);
        final iconSize = (w * 0.050).clamp(16.0, 20.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _kTemplateAsset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),

            // Details block inside white plate — extra left margin.
            Positioned(
              left: w * 0.175,
              right: w * 0.10,
              top: h * 0.49,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NameBlock(
                    name: name,
                    firstSize: firstNameSize,
                    restSize: restNameSize,
                  ),
                  SizedBox(height: h * 0.011),
                  Container(
                    width: w * 0.17,
                    height: 1.5,
                    color: _kRed,
                  ),
                  SizedBox(height: h * 0.009),
                  Text(
                    jobTitle == '—' ? jobTitle : '$jobTitle |',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w500,
                      color: _kRed,
                      height: 1.2,
                      letterSpacing: 0.15,
                    ),
                  ),
                  SizedBox(height: h * 0.034),
                  _ContactList(
                    email: email,
                    mobile: mobile,
                    landline: landline,
                    website: website,
                    iconSize: iconSize,
                    textSize: contactSize,
                    rowHeight: (h * 0.048).clamp(30.0, 38.0),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NameBlock extends StatelessWidget {
  const _NameBlock({
    required this.name,
    required this.firstSize,
    required this.restSize,
  });

  final String name;
  final double firstSize;
  final double restSize;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.isEmpty ? name : parts.first;
    final rest = parts.length <= 1 ? '' : parts.sublist(1).join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.playfairDisplay(
            fontSize: firstSize,
            fontWeight: FontWeight.w700,
            color: _kNavy,
            height: 1.02,
            letterSpacing: -0.3,
          ),
        ),
        if (rest.isNotEmpty) ...[
          SizedBox(height: 4.th),
          Text(
            rest,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.playfairDisplay(
              fontSize: restSize,
              fontWeight: FontWeight.w500,
              color: _kNavy,
              height: 1.18,
            ),
          ),
        ],
      ],
    );
  }
}

class _ContactList extends StatelessWidget {
  const _ContactList({
    required this.email,
    required this.mobile,
    required this.landline,
    required this.website,
    required this.iconSize,
    required this.textSize,
    required this.rowHeight,
  });

  final String email;
  final String mobile;
  final String landline;
  final String website;
  final double iconSize;
  final double textSize;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String)>[
      (Icons.email_outlined, email),
      (Icons.smartphone_rounded, mobile),
      (Icons.phone_rounded, landline),
      (Icons.language_rounded, website),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++)
          SizedBox(
            height: rowHeight,
            child: _ContactRow(
              icon: rows[i].$1,
              label: rows[i].$2,
              iconSize: iconSize,
              textSize: textSize,
              showDivider: i < rows.length - 1,
            ),
          ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.iconSize,
    required this.textSize,
    required this.showDivider,
  });

  final IconData icon;
  final String label;
  final double iconSize;
  final double textSize;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: const BoxDecoration(
                  color: _kNavy,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: iconSize * 0.52,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 11.tw),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: textSize,
                    fontWeight: FontWeight.w500,
                    color: _kNavy,
                    height: 1.15,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, thickness: 0.7, color: _kDivider),
      ],
    );
  }
}
