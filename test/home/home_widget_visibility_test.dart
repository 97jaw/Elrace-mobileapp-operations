import 'package:el_race/core/home/home_widget_visibility.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter_test/flutter_test.dart';

WidgetsData _widgets({
  bool mediaDisabled = false,
  bool attendanceDisabled = false,
}) {
  return WidgetsData(
    attendanceWidget: WidgetInfo(isDisabled: attendanceDisabled),
    mediaWidget: WidgetInfo(isDisabled: mediaDisabled),
  );
}

void main() {
  group('HomeWidgetVisibility', () {
    test('hides media when is_disabled is true', () {
      final v = HomeWidgetVisibility(_widgets(mediaDisabled: true));
      expect(v.isVisible(HomeWidgetCode.media), isFalse);
    });

    test('shows media when is_disabled is false', () {
      final v = HomeWidgetVisibility(_widgets(mediaDisabled: false));
      expect(v.isVisible(HomeWidgetCode.media), isTrue);
      expect(v.hasVisibleLibrary, isTrue);
    });

    test('defaults to visible when widget info is missing', () {
      const v = HomeWidgetVisibility(null);
      expect(v.isVisible(HomeWidgetCode.media), isTrue);
    });

    test('clients vendors category respects is_disabled when configured', () {
      final v = HomeWidgetVisibility(
        WidgetsData(
          clientsWidget: WidgetInfo(isDisabled: false),
          vendorsWidget: WidgetInfo(isDisabled: true),
          subContractorsWidget: WidgetInfo(isDisabled: true),
        ),
      );
      expect(v.hasVisibleClientsVendors, isTrue);
      expect(v.isVisible(HomeWidgetCode.clients), isTrue);
      expect(v.isVisible(HomeWidgetCode.vendors), isFalse);
    });
  });
}
