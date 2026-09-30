import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/widgets.dart';

/// Tablet layout rules for the media screens. Phones keep the original
/// stacked hero + draggable sheet layout untouched.
abstract final class MediaLayout {
  /// Side panel width for the tablet landscape split view.
  static const double sidePanelMinWidth = 360;
  static const double sidePanelMaxWidth = 460;

  /// Gallery content stops stretching past this width on wide sheets.
  static const double galleryMaxWidth = 900;

  /// Player controls stop stretching past this width.
  static const double playerControlsMaxWidth = 760;

  /// Landscape tablets show the hero beside a fixed gallery panel instead of
  /// a draggable sheet covering most of a short, wide screen.
  static bool useSplitView(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ResponsiveBreakpoints.useTabletLayout(context) &&
        size.width > size.height;
  }

  static double sidePanelWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 0.36;
    return width.clamp(sidePanelMinWidth, sidePanelMaxWidth);
  }

  /// Masonry columns from the width actually available, so the split panel
  /// stays at two while wide portrait sheets get three or four.
  static int gridColumns(double availableWidth) {
    if (availableWidth >= 840) return 4;
    if (availableWidth >= 560) return 3;
    return 2;
  }

  /// Horizontal inset that centers content within [maxWidth].
  static double centeredInset(double availableWidth, double maxWidth) {
    if (availableWidth <= maxWidth) return 0;
    return (availableWidth - maxWidth) / 2;
  }
}
