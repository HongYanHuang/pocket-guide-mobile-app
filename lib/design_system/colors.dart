import 'package:flutter/cupertino.dart';

/// Pocket Guide minimalist color system
/// Black & White with Dark Green accent
class PGColors {
  // Brand color - Dark Green
  static const brand = Color(0xFF1B4332);        // Deep forest green
  static const brandLight = Color(0xFF2D6A4F);   // Lighter green for hover/pressed
  static const brandDark = Color(0xFF081C15);    // Very dark green

  // Grayscale (Black to White)
  static const black = Color(0xFF000000);
  static const gray900 = Color(0xFF1A1A1A);      // Almost black
  static const gray800 = Color(0xFF2E2E2E);      // Very dark gray
  static const gray700 = Color(0xFF424242);      // Dark gray
  static const gray600 = Color(0xFF616161);      // Medium-dark gray
  static const gray500 = Color(0xFF9E9E9E);      // Medium gray
  static const gray400 = Color(0xFFBDBDBD);      // Light-medium gray
  static const gray300 = Color(0xFFE0E0E0);      // Light gray
  static const gray200 = Color(0xFFEEEEEE);      // Very light gray
  static const gray100 = Color(0xFFF5F5F5);      // Almost white
  static const white = Color(0xFFFFFFFF);

  // Semantic colors
  static const background = white;               // Main background
  static const surface = white;                  // Cards, elevated surfaces
  static const surfaceElevated = gray100;        // Slightly elevated surfaces

  // Text colors
  static const textPrimary = black;              // Main text
  static const textSecondary = gray600;          // Secondary text
  static const textTertiary = gray500;           // Tertiary text/hints
  static const textInverse = white;              // Text on dark backgrounds

  // Borders & Dividers
  static const border = gray300;                 // Default borders
  static const divider = gray200;                // Subtle dividers
  static const dividerDark = gray400;            // More visible dividers

  // Interactive states
  static const pressedOverlay = Color(0x0A000000);     // 4% black
  static const hoverOverlay = Color(0x05000000);       // 2% black
  static const focusOverlay = Color(0x1F000000);       // 12% black

  // Feedback colors (minimal, subtle)
  static const success = Color(0xFF2E7D32);      // Muted green
  static const successLight = Color(0xFFE8F5E9); // Light green background
  static const error = Color(0xFFC62828);        // Muted red
  static const errorLight = Color(0xFFFFEBEE);   // Light red background
  static const warning = Color(0xFFEF6C00);      // Muted orange
  static const warningLight = Color(0xFFFFF3E0); // Light orange background
  static const info = gray700;                   // Just use gray

  // Shadows (subtle, iOS-style)
  static const shadowLight = Color(0x0A000000);  // Very subtle
  static const shadowMedium = Color(0x14000000); // Subtle
  static const shadowDark = Color(0x1F000000);   // Visible but soft
}
