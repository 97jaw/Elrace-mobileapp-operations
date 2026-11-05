import 'package:el_race/core/site_management/face_recognition/profile_photo_face_db.dart';
import 'package:el_race/ui/presentation/attendance_checkin/face/checkin_face_flow.dart';
import 'package:el_race/ui/presentation/attendance_checkin/face/checkin_success_screen.dart';
import 'package:el_race/ui/presentation/attendance_checkin/face/self_face_template_service.dart';
import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

CheckinContextModel _ctx({bool face = false}) {
  return CheckinContextModel(
    mobileCheckinAllowed: true,
    biotimeOffices: const [],
    biotimeTerminals: const [],
    todayStatus: CheckinTodayStatus.empty,
    defaultRadiusM: 100,
    faceRequired: face,
  );
}

void main() {
  group('CheckinFaceFlow', () {
    test('shouldVerify follows face_required', () {
      expect(CheckinFaceFlow.shouldVerify(_ctx(face: false)), isFalse);
      expect(CheckinFaceFlow.shouldVerify(_ctx(face: true)), isTrue);
      expect(CheckinFaceFlow.shouldVerify(null), isFalse);
    });
  });

  group('SelfFaceTemplateService', () {
    test('templateDb is ProfilePhotoFaceDb.self, not instance', () {
      final db = SelfFaceTemplateService.instance.templateDb();
      expect(identical(db, ProfilePhotoFaceDb.self), isTrue);
      expect(identical(db, ProfilePhotoFaceDb.instance), isFalse);
    });
  });

  group('CheckinSuccessScreen Done', () {
    testWidgets('popToRoot returns to first route', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Text('home')),
        ),
      );
      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => CheckinSuccessScreen.popToRoot(ctx),
              child: const Text('done'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('done'), findsOneWidget);
      await tester.tap(find.text('done'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.text('done'), findsNothing);
    });
  });

  group('CheckinContextModel.face_required', () {
    test('parses face_required and profile_photo_url', () {
      final model = CheckinContextModel.fromJson({
        'mobile_checkin_allowed': true,
        'face_required': true,
        'profile_photo_url': 'https://erp.elrace.com/public/user/image/1',
        'biotime_offices': const [],
        'biotime_terminals': const [],
      });
      expect(model.faceRequired, isTrue);
      expect(model.profilePhotoUrl, contains('public/user/image'));
    });
  });
}
