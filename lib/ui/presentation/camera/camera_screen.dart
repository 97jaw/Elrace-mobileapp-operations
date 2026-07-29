import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({super.key, required this.camera});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  String _currentDate = '';
  String _currentTime = '';
  String _currentLocation = '';

  @override
  void initState() {
    super.initState();

    // Avoid ResolutionPreset.max on iOS — btp2 pixel format breaks Metal preview.
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.ultraHigh,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.jpeg,
    );

    _initializeControllerFuture = _controller.initialize();

    _updateTime();
    _updateLocation();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentDate = DateFormat('dd/MM/yyyy').format(now);
      _currentTime = DateFormat('hh:mm a').format(now);
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _updateTime();
    });
  }

  Future<void> _updateLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _currentLocation = '';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _currentLocation =
              place.locality ?? place.subAdministrativeArea ?? '';
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error getting location: $e');
      setState(() {
        _currentLocation = '';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final file = await _controller.takePicture();

      if (!mounted) return;

      final composedPath = await _composeWithOverlay(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: ${composedPath ?? file.path}')),
      );
    } catch (e) {
      // ignore: avoid_print
      print('Camera error: $e');
    }
  }

  Future<String?> _composeWithOverlay(String imagePath) async {
    try {
      // ignore: avoid_print
      print('🎨 Starting to compose overlay on image...');
      // ignore: avoid_print
      print('⏰ Time: $_currentTime');
      // ignore: avoid_print
      print('📅 Date: $_currentDate');
      // ignore: avoid_print
      print('📍 Location: $_currentLocation');

      final bytes = await File(imagePath).readAsBytes();
      final baseImage = img.decodeImage(bytes);
      if (baseImage == null) {
        // ignore: avoid_print
        print('❌ Failed to decode image');
        return imagePath;
      }

      // ignore: avoid_print
      print('✅ Image decoded: ${baseImage.width}x${baseImage.height}');

      final int padding = (baseImage.width * 0.04).toInt();
      final int fontSize = (baseImage.width * 0.045).toInt();
      final shadowOffset = 2;
      final lineHeight = (fontSize * 1.4).toInt();

      final timeTextWidth = _currentTime.length * (fontSize * 0.55).toInt();
      final dateTextWidth = _currentDate.length * (fontSize * 0.55).toInt();
      final locationTextWidth =
          _currentLocation.length * (fontSize * 0.55).toInt();

      int maxTextWidth = timeTextWidth;
      if (dateTextWidth > maxTextWidth) maxTextWidth = dateTextWidth;
      if (locationTextWidth > maxTextWidth) maxTextWidth = locationTextWidth;

      int currentY = baseImage.height -
          padding -
          (lineHeight * (_currentLocation.isNotEmpty ? 3 : 2));

      final timeX = baseImage.width - padding - maxTextWidth;
      img.drawString(
        baseImage,
        _currentTime,
        font: img.arial14,
        x: timeX + shadowOffset,
        y: currentY + shadowOffset,
        color: img.ColorRgb8(40, 40, 40),
      );
      img.drawString(
        baseImage,
        _currentTime,
        font: img.arial14,
        x: timeX,
        y: currentY,
        color: img.ColorRgb8(255, 255, 255),
      );

      currentY += lineHeight;
      final dateX = baseImage.width - padding - maxTextWidth;
      img.drawString(
        baseImage,
        _currentDate,
        font: img.arial14,
        x: dateX + shadowOffset,
        y: currentY + shadowOffset,
        color: img.ColorRgb8(40, 40, 40),
      );
      img.drawString(
        baseImage,
        _currentDate,
        font: img.arial14,
        x: dateX,
        y: currentY,
        color: img.ColorRgb8(255, 255, 255),
      );

      if (_currentLocation.isNotEmpty) {
        currentY += lineHeight;
        final locationX = baseImage.width - padding - maxTextWidth;
        img.drawString(
          baseImage,
          _currentLocation,
          font: img.arial14,
          x: locationX + shadowOffset,
          y: currentY + shadowOffset,
          color: img.ColorRgb8(40, 40, 40),
        );
        img.drawString(
          baseImage,
          _currentLocation,
          font: img.arial14,
          x: locationX,
          y: currentY,
          color: img.ColorRgb8(255, 255, 255),
        );
      }

      final composedFile = File(imagePath);
      composedFile.writeAsBytesSync(img.encodeJpg(baseImage, quality: 95));

      // ignore: avoid_print
      print('✅ Image saved with overlay: $imagePath');
      return composedFile.path;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error composing image: $e');
      return imagePath;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder(
        future: _initializeControllerFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return Stack(
            children: [
              /// ================================
              /// REAL CAMERA PREVIEW (FULL FIT)
              /// ================================
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.previewSize!.height,
                    height: _controller.value.previewSize!.width,
                    child: CameraPreview(_controller),
                  ),
                ),
              ),

              /// ================================
              /// TOP GLASS BAR (PERFECT MATCH)
              /// ================================
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 175.th,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                  ),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.tw, vertical: 20.th),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Image.asset(
                          'assets/logo/rcc2.png',
                          height: 42.th,
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),

              /// ================================
              /// BOTTOM GLASS CONTAINER (FULL FOOTER)
              /// ================================
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BottomDock(
                  extra: 0,
                  liftWithKeyboard: false,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: Container(
                      width: double.infinity,
                      height: screenHeight * 0.28,
                      padding: EdgeInsets.symmetric(
                        horizontal: 30.tw,
                        vertical: 20.th,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _currentTime,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.tsp,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w300,
                                    height: 1.15,
                                  ),
                                ),
                                SizedBox(height: 1.th),
                                Text(
                                  _currentDate,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.tsp,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w300,
                                    height: 1.15,
                                  ),
                                ),
                                if (_currentLocation.isNotEmpty) ...[
                                  SizedBox(height: 1.th),
                                  Text(
                                    _currentLocation,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.tsp,
                                      color: Colors.white.withOpacity(0.85),
                                      fontWeight: FontWeight.w300,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _takePicture,
                            child: Container(
                              width: 55.tw,
                              height: 55.tw,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 60.tw,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 20.th),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _glassButton('SCAN'),
                              _glassButton('PHOTO'),
                            ],
                          ),
                        ],
                      ),
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

  Widget _glassButton(String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30.tr),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 36.tw, vertical: 12.th),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.30),
            borderRadius: BorderRadius.circular(30.tr),
            border: Border.all(
              color: Colors.white.withOpacity(0.20),
              width: 1.2,
            ),
          ),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 17.tsp,
              letterSpacing: 1.4,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
