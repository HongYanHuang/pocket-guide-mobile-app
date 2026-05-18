import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
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
    decoration: TextDecoration.none,
  );

  static const largeTitleEmphasized = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.2,
    color: PGColors.textPrimary,
    decoration: TextDecoration.none,
  );

  // Titles
  static const title1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.9,
    height: 1.25,
    color: PGColors.textPrimary,
    decoration: TextDecoration.none,
  );

  static const title2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.27,
    color: PGColors.textPrimary,
    decoration: TextDecoration.none,
  );

  static const title3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.3,
    color: PGColors.textPrimary,
    decoration: TextDecoration.none,
  );

  // Headlines
  static const headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.35,
    color: PGColors.textPrimary,
    decoration: TextDecoration.none,
  );

  // Body text
  static const body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    height: 1.41,
    color: PGColors.textPrimary,
    decoration: TextDecoration.none,
  );

  static const bodyEmphasized = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.41,
    color: PGColors.textPrimary,
    decoration: TextDecoration.none,
  );

  // Callout (slightly smaller than body)
  static const callout = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
    height: 1.38,
    color: PGColors.textPrimary,
    decoration: TextDecoration.none,
  );

  static const calloutEmphasized = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.32,
    height: 1.38,
    color: PGColors.textPrimary,
    decoration: TextDecoration.none,
  );

  // Subheadline
  static const subheadline = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
    height: 1.33,
    color: PGColors.textSecondary,
    decoration: TextDecoration.none,
  );

  static const subheadlineEmphasized = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.24,
    height: 1.33,
    color: PGColors.textSecondary,
    decoration: TextDecoration.none,
  );

  // Footnote
  static const footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    height: 1.38,
    color: PGColors.textSecondary,
    decoration: TextDecoration.none,
  );

  static const footnoteEmphasized = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.08,
    height: 1.38,
    color: PGColors.textSecondary,
    decoration: TextDecoration.none,
  );

  // Caption (smallest)
  static const caption1 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.33,
    color: PGColors.textTertiary,
    decoration: TextDecoration.none,
  );

  static const caption2 = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.07,
    height: 1.27,
    color: PGColors.textTertiary,
    decoration: TextDecoration.none,
  );

  // Button text
  static const button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.29,
    color: PGColors.white,
    decoration: TextDecoration.none,
  );

  static const buttonSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.24,
    height: 1.33,
    color: PGColors.white,
    decoration: TextDecoration.none,
  );
}

/// Rawi design system typography — Source Sans 3
/// Used exclusively by the rawi home page and its components.
class RawiTypography {
  // Section header  18 / w600 / -1%
  static TextStyle sectionTitle({Color? color}) => GoogleFonts.sourceSans3(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.18,
        color: color ?? PGColors.rawiInk,
        decoration: TextDecoration.none,
      );

  // Large card title  16 / w600 / -1%
  static TextStyle cardTitle({Color? color}) => GoogleFonts.sourceSans3(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.16,
        height: 1.25,
        color: color ?? PGColors.rawiInk,
        decoration: TextDecoration.none,
      );

  // Compact card title  14 / w600 / -1%
  static TextStyle cardTitleSmall({Color? color}) => GoogleFonts.sourceSans3(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.14,
        height: 1.2,
        color: color ?? PGColors.rawiInk,
        decoration: TextDecoration.none,
      );

  // Place / subtitle  13 / w400
  static TextStyle place({Color? color}) => GoogleFonts.sourceSans3(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color ?? PGColors.rawiInk3,
        decoration: TextDecoration.none,
      );

  // Meta row items (duration, stops, etc.)  12 / w400
  static TextStyle meta({Color? color}) => GoogleFonts.sourceSans3(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color ?? PGColors.rawiInk3,
        decoration: TextDecoration.none,
      );

  // Rating number  13 / w600
  static TextStyle ratingValue({Color? color}) => GoogleFonts.sourceSans3(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: color ?? PGColors.rawiInk,
        decoration: TextDecoration.none,
      );

  // Category chip  14 / w400 or w600 when active
  static TextStyle chip({required bool active}) => GoogleFonts.sourceSans3(
        fontSize: 14,
        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        color: active ? PGColors.rawiPaper : PGColors.rawiInk2,
        decoration: TextDecoration.none,
      );

  // City pill label  14 / w600
  static TextStyle cityPill({Color? color}) => GoogleFonts.sourceSans3(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.14,
        color: color ?? PGColors.rawiPaper,
        decoration: TextDecoration.none,
      );

  // "Narrated by" label  12 / w400
  static TextStyle narratorLabel() => GoogleFonts.sourceSans3(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: PGColors.rawiInk3,
        decoration: TextDecoration.none,
      );

  // Narrator name  13 / w500
  static TextStyle narratorName() => GoogleFonts.sourceSans3(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: PGColors.rawiInk,
        decoration: TextDecoration.none,
      );

  // CTA body text  13 / w400  centered
  static TextStyle ctaBody() => GoogleFonts.sourceSans3(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: PGColors.rawiInk3,
        decoration: TextDecoration.none,
      );
}
