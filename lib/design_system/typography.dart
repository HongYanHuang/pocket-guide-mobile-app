import 'package:flutter/cupertino.dart';
import 'colors.dart';

/// Pocket Guide typography system
/// Based on iOS San Francisco font scale
class PGTypography {
  // Large titles
  static const largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.9,
    height: 1.2,
    color: PGColors.textPrimary,
  );

  static const largeTitleEmphasized = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.2,
    color: PGColors.textPrimary,
  );

  // Titles
  static const title1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.25,
    color: PGColors.textPrimary,
  );

  static const title2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.27,
    color: PGColors.textPrimary,
  );

  static const title3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.3,
    color: PGColors.textPrimary,
  );

  // Headlines
  static const headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.35,
    color: PGColors.textPrimary,
  );

  // Body text
  static const body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    height: 1.41,
    color: PGColors.textPrimary,
  );

  static const bodyEmphasized = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.41,
    color: PGColors.textPrimary,
  );

  // Callout (slightly smaller than body)
  static const callout = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
    height: 1.38,
    color: PGColors.textPrimary,
  );

  static const calloutEmphasized = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.32,
    height: 1.38,
    color: PGColors.textPrimary,
  );

  // Subheadline
  static const subheadline = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
    height: 1.33,
    color: PGColors.textSecondary,
  );

  static const subheadlineEmphasized = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.24,
    height: 1.33,
    color: PGColors.textSecondary,
  );

  // Footnote
  static const footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    height: 1.38,
    color: PGColors.textSecondary,
  );

  static const footnoteEmphasized = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.08,
    height: 1.38,
    color: PGColors.textSecondary,
  );

  // Caption (smallest)
  static const caption1 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.33,
    color: PGColors.textTertiary,
  );

  static const caption2 = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.07,
    height: 1.27,
    color: PGColors.textTertiary,
  );

  // Button text
  static const button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.29,
    color: PGColors.white,
  );

  static const buttonSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.24,
    height: 1.33,
    color: PGColors.white,
  );
}
