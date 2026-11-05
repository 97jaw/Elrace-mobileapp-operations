import 'package:el_race/ui/presentation/attendance_checkin/utils/checkin_sheet_logic.dart';
import 'package:el_race/ui/presentation/attendance_checkin/widgets/checkin_location_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpCard(
    WidgetTester tester,
    CheckinLocationCardState state,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: CheckinLocationStatusCard(
                state: state,
                distanceMeters: 11,
                radiusMeters: 100,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('inside card', (tester) async {
    await pumpCard(tester, CheckinLocationCardState.inside);
    expect(find.text('Inside allowed area'), findsOneWidget);
    expect(find.text('Location verified'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(
      find.text('11 m away • Allowed radius 100 m'),
      findsOneWidget,
    );
  });

  testWidgets('outside card', (tester) async {
    await pumpCard(tester, CheckinLocationCardState.outside);
    expect(find.text('Outside allowed area'), findsOneWidget);
    expect(find.text('Move closer'), findsOneWidget);
  });

  testWidgets('waiting GPS card', (tester) async {
    await pumpCard(tester, CheckinLocationCardState.waitingGps);
    expect(find.text('Getting your location…'), findsOneWidget);
  });

  testWidgets('anywhere card', (tester) async {
    await pumpCard(tester, CheckinLocationCardState.anywhere);
    expect(find.text('Check-in from anywhere'), findsOneWidget);
  });

  testWidgets('no linked location card', (tester) async {
    await pumpCard(tester, CheckinLocationCardState.noLinkedLocation);
    expect(find.text('No linked location'), findsOneWidget);
  });
}
