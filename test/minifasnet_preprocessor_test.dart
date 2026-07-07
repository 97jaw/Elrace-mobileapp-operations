import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/minifasnet_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'dart:ui';

void main() {
  test('MiniFASNet preprocessor produces 80x80x3 float buffer', () {
    const preprocessor = MinifasnetPreprocessor();
    final source = img.Image(width: 640, height: 480);
    for (var y = 100; y < 300; y++) {
      for (var x = 200; x < 400; x++) {
        source.setPixelRgb(x, y, 120, 90, 70);
      }
    }
    const face = Rect.fromLTWH(200, 100, 200, 200);
    final v2 = preprocessor.buildInput(
      source: source,
      faceBox: face,
      cropScale: AntispoofConfig.modelV2CropScale,
    );
    final v1 = preprocessor.buildInput(
      source: source,
      faceBox: face,
      cropScale: AntispoofConfig.modelV1SeCropScale,
    );
    expect(v2, isNotNull);
    expect(v1, isNotNull);
    expect(v2!.length, 1 * 80 * 80 * 3);
    expect(v1!.length, 1 * 80 * 80 * 3);
    expect(v2.every((v) => v >= 0 && v <= 255), isTrue);
  });
}
