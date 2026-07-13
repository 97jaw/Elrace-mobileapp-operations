import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:el_race/ui/presentation/home_screen/widgets/home_city_helper.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_widgets/profile_sheet_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/profile_widgets/profile_user_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _kBusinessCardAssetRoot = 'assets/images/business_card';
const _kCompanyLogoAsset = '$_kBusinessCardAssetRoot/company_logo.png';
const _kShareLogoHeight = 56.0;
const _kCardGray = Color(0xFFE2E8EB);
const _kContactNavy = Color(0xFF1B3A5C);
const _kJobGray = Color(0xFF8A8A8A);

class BusinessCardScreen extends StatefulWidget {
  const BusinessCardScreen({super.key});

  @override
  State<BusinessCardScreen> createState() => _BusinessCardScreenState();
}

class _BusinessCardScreenState extends State<BusinessCardScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _cardCaptureKey = GlobalKey();
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _showBack = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOut,
    );
    _flipController.addListener(() {
      if (!mounted) return;
      final nowBack = _flipAnimation.value >= 0.5;
      if (nowBack != _showBack) setState(() => _showBack = nowBack);
    });
    HomeCityHelper.fetchCity().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleSide() {
    if (_flipController.isAnimating) return;
    if (_showBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  static void _noop() {}

  Future<void> _shareCard() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    const pixelRatio = 3.0;

    try {
      if (!mounted) return;
      await precacheImage(const AssetImage(_kCompanyLogoAsset), context);
      await _precacheBusinessCardAssets(context);

      // Rebuild without the Swap button before capture.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final boundary = _cardCaptureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return;

      final composited = await _compositeCompanyLogoOnCard(
        cardPng: byteData.buffer.asUint8List(),
        pixelRatio: pixelRatio,
      );
      if (composited == null) return;

      final dir = await getTemporaryDirectory();
      final side = _showBack ? 'back' : 'front';
      final file = File('${dir.path}/elrace_business_card_$side.png');
      await file.writeAsBytes(composited);

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

  Future<Uint8List?> _compositeCompanyLogoOnCard({
    required Uint8List cardPng,
    required double pixelRatio,
  }) async {
    final cardCodec = await ui.instantiateImageCodec(cardPng);
    final cardFrame = await cardCodec.getNextFrame();
    final cardImage = cardFrame.image;

    final logoBytes =
        (await rootBundle.load(_kCompanyLogoAsset)).buffer.asUint8List();
    final logoCodec = await ui.instantiateImageCodec(logoBytes);
    final logoFrame = await logoCodec.getNextFrame();
    final logoImage = logoFrame.image;

    const logoAspect = 749 / 349;
    final logoHeight = _kShareLogoHeight * pixelRatio;
    final logoWidth = logoHeight * logoAspect;
    final padRight = 10.w * pixelRatio;
    final padBottom = 10.h * pixelRatio;

    final canvasW = cardImage.width.toDouble();
    final canvasH = cardImage.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(cardImage, Offset.zero, Paint());

    final dest = Rect.fromLTWH(
      canvasW - padRight - logoWidth,
      canvasH - padBottom - logoHeight,
      logoWidth,
      logoHeight,
    );
    paintImage(
      canvas: canvas,
      rect: dest,
      image: logoImage,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final outImage = await picture.toImage(cardImage.width, cardImage.height);
    final outData = await outImage.toByteData(format: ui.ImageByteFormat.png);

    cardImage.dispose();
    logoImage.dispose();
    outImage.dispose();

    return outData?.buffer.asUint8List();
  }

  Future<void> _precacheBusinessCardAssets(BuildContext context) async {
    const assets = <String>[
      '$_kBusinessCardAssetRoot/bc_pattern.png',
      '$_kBusinessCardAssetRoot/mail.png',
      '$_kBusinessCardAssetRoot/phone.png',
      '$_kBusinessCardAssetRoot/location.png',
      '$_kBusinessCardAssetRoot/website.png',
    ];
    for (final path in assets) {
      await precacheImage(AssetImage(path), context);
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
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _sharing ? null : _shareCard,
            icon: _sharing
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.ios_share_rounded, size: 22.sp),
            tooltip: 'Share',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: AnimatedBuilder(
              animation: _flipAnimation,
              builder: (context, _) {
                final t = _flipAnimation.value;
                final angle = t * math.pi;
                final isUnder = t >= 0.5;
                final scale = 1.0 - (math.sin(angle).abs() * 0.04);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(angle)
                        ..scale(scale),
                      child: _BusinessCardFrame(
                        child: RepaintBoundary(
                          key: _cardCaptureKey,
                          child: isUnder
                              ? Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(math.pi),
                                  child: const _BackCardView(
                                    showSwap: false,
                                    onSwap: _noop,
                                  ),
                                )
                              : const _FrontCardView(
                                  showSwap: false,
                                  onSwap: _noop,
                                ),
                        ),
                      ),
                    ),
                    _BusinessCardFrame(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            right: 10.w,
                            bottom: 10.h,
                            child: _SwapButton(onPressed: _toggleSide),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessCardFrame extends StatelessWidget {
  const _BusinessCardFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 48.w;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      child: AspectRatio(
        aspectRatio: 0.57,
        child: child,
      ),
    );
  }
}

class _FrontCardView extends StatelessWidget {
  const _FrontCardView({
    required this.onSwap,
    required this.showSwap,
  });

  final VoidCallback onSwap;
  final bool showSwap;

  @override
  Widget build(BuildContext context) {
    final name = ProfileUserInfo.displayName();
    final jobTitle =
        ProfileUserInfo.displayOrDash(ProfileUserInfo.displayJobTitle());
    final email = ProfileUserInfo.displayOrDash(ProfileUserInfo.displayEmail());
    final phone = ProfileUserInfo.displayOrDash(ProfileUserInfo.displayPhone());
    final location =
        ProfileUserInfo.displayOrDash(ProfileUserInfo.displayLocation());
    final website = ProfileUserInfo.displayWebsite();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padH = constraints.maxWidth * 0.11;

          return Column(
            children: [
              Expanded(
                flex: 58,
                child: ColoredBox(
                  color: Colors.white,
                  child: LayoutBuilder(
                    builder: (context, whiteConstraints) {
                      final whiteH = whiteConstraints.maxHeight;
                      final patternH = whiteH * 0.46;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: patternH,
                            child: Image.asset(
                              '$_kBusinessCardAssetRoot/bc_pattern.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: padH,
                              ),
                              child: Center(
                                child: _IdentityBlock(
                                  name: name,
                                  jobTitle: jobTitle,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                flex: 42,
                child: ColoredBox(
                  color: _kCardGray,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      padH,
                      14.h,
                      padH,
                      36.h,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ContactRow(
                          iconPath: '$_kBusinessCardAssetRoot/mail.png',
                          label: email,
                        ),
                        _ContactRow(
                          iconPath: '$_kBusinessCardAssetRoot/phone.png',
                          label: phone,
                        ),
                        _ContactRow(
                          iconPath: '$_kBusinessCardAssetRoot/location.png',
                          label: location,
                        ),
                        _ContactRow(
                          iconPath: '$_kBusinessCardAssetRoot/website.png',
                          label: website,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BackCardView extends StatelessWidget {
  const _BackCardView({
    required this.onSwap,
    required this.showSwap,
  });

  final VoidCallback onSwap;
  final bool showSwap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: Image.asset(
        '$_kBusinessCardAssetRoot/back_template.jpeg',
        fit: BoxFit.cover,
      ),
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({
    required this.name,
    required this.jobTitle,
  });

  final String name;
  final String jobTitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NameText(name: name),
        SizedBox(height: 5.h),
        _JobTitleText(title: jobTitle),
        SizedBox(height: 8.h),
        const _AccentDividerLine(),
      ],
    );
  }
}

class _AccentDividerLine extends StatelessWidget {
  const _AccentDividerLine();

  @override
  Widget build(BuildContext context) {
    final redHeight = 5.h;
    final blackHeight = 1.8.h;

    return SizedBox(
      width: double.infinity,
      height: redHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46.w,
            height: redHeight,
            color: const Color(0xFFC62828),
          ),
          Expanded(
            child: Container(
              height: blackHeight,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _NameText extends StatelessWidget {
  const _NameText({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final fontSize = name.length > 28 ? 16.sp : 18.sp;
    final baseStyle = TextStyle(
      fontSize: fontSize,
      color: Colors.black,
      height: 1.15,
      letterSpacing: -0.2,
    );

    Widget text;
    if (parts.length <= 1) {
      text = Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: baseStyle.copyWith(fontWeight: FontWeight.w700),
      );
    } else {
      final first = parts.first;
      final rest = parts.sublist(1).join(' ');
      text = Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            TextSpan(
              text: '$first ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: rest,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return SizedBox(
      width: double.infinity,
      child: text,
    );
  }
}

class _JobTitleText extends StatelessWidget {
  const _JobTitleText({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.sp,
          color: _kJobGray,
          fontWeight: FontWeight.w400,
          height: 1.15,
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.iconPath,
    required this.label,
  });

  final String iconPath;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 16.w,
          height: 16.w,
          child: Image.asset(
            iconPath,
            fit: BoxFit.contain,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: _kContactNavy,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ProfileSheetTheme.navy.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 16.sp),
              SizedBox(width: 4.w),
              Text(
                'Swap',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
