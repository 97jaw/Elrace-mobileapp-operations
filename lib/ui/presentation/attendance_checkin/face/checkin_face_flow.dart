import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';

/// Pure decisions for whether face verification runs (unit-tested).
abstract final class CheckinFaceFlow {
  static bool shouldVerify(CheckinContextModel? context) =>
      context?.faceRequired == true;

  static bool shouldWarmTemplate(CheckinContextModel? context) =>
      shouldVerify(context);
}
