import 'package:flutter/cupertino.dart';
import 'colors.dart';

/// Pocket Guide spacing and layout system
class PGSpacing {
  // Base spacing unit (4px)
  static const double unit = 4.0;

  // Spacing scale
  static const double xs = unit;          // 4px
  static const double s = unit * 2;       // 8px
  static const double m = unit * 3;       // 12px
  static const double l = unit * 4;       // 16px
  static const double xl = unit * 6;      // 24px
  static const double xxl = unit * 8;     // 32px
  static const double xxxl = unit * 12;   // 48px

  // Edge insets (common padding patterns)
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingS = EdgeInsets.all(s);
  static const EdgeInsets paddingM = EdgeInsets.all(m);
  static const EdgeInsets paddingL = EdgeInsets.all(l);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);
  static const EdgeInsets paddingXXL = EdgeInsets.all(xxl);

  // Horizontal padding
  static const EdgeInsets horizontalS = EdgeInsets.symmetric(horizontal: s);
  static const EdgeInsets horizontalM = EdgeInsets.symmetric(horizontal: m);
  static const EdgeInsets horizontalL = EdgeInsets.symmetric(horizontal: l);
  static const EdgeInsets horizontalXL = EdgeInsets.symmetric(horizontal: xl);

  // Vertical padding
  static const EdgeInsets verticalS = EdgeInsets.symmetric(vertical: s);
  static const EdgeInsets verticalM = EdgeInsets.symmetric(vertical: m);
  static const EdgeInsets verticalL = EdgeInsets.symmetric(vertical: l);
  static const EdgeInsets verticalXL = EdgeInsets.symmetric(vertical: xl);

  // Screen padding (safe area aware)
  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: l,
    vertical: l,
  );

  // Section spacing (between major sections)
  static const double sectionSpacing = xxl;

  // Item spacing (between list items)
  static const double itemSpacing = m;
}

/// Border radius constants
class PGRadius {
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  // Common border radius
  static final BorderRadius radiusXS = BorderRadius.circular(xs);
  static final BorderRadius radiusS = BorderRadius.circular(s);
  static final BorderRadius radiusM = BorderRadius.circular(m);
  static final BorderRadius radiusL = BorderRadius.circular(l);
  static final BorderRadius radiusXL = BorderRadius.circular(xl);
  static final BorderRadius radiusXXL = BorderRadius.circular(xxl);

  // iOS-style bottom sheet
  static final BorderRadius bottomSheet = BorderRadius.only(
    topLeft: Radius.circular(l),
    topRight: Radius.circular(l),
  );
}

/// Shadows (subtle, iOS-style)
class PGShadows {
  // Subtle shadow for cards
  static List<BoxShadow> card = [
    BoxShadow(
      color: PGColors.shadowLight,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  // Medium shadow for elevated elements
  static List<BoxShadow> elevated = [
    BoxShadow(
      color: PGColors.shadowMedium,
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  // Strong shadow for modals/overlays
  static List<BoxShadow> modal = [
    BoxShadow(
      color: PGColors.shadowDark,
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  // No shadow
  static List<BoxShadow> none = [];
}

/// Common durations for animations
class PGDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}
