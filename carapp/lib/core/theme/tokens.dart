import 'package:flutter/material.dart';

/// Design tokens, mirrored from the mockups. Change them here only.
class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF1D4ED8);
  static const primaryDark = Color(0xFF1E40AF);
  static const primarySoft = Color(0xFFEAF0FF);

  // Ink
  static const ink = Color(0xFF0D0F12);
  static const inkSecondary = Color(0xFF4A5059);
  static const inkMuted = Color(0xFF5D636B);

  // Surfaces
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF3F5F9);
  static const border = Color(0xFFE3E7EE);
  static const borderStrong = Color(0xFFC9D1DE);
  static const placeholder = Color(0xFFE3E7EE);

  // Feed (dark, over video)
  static const feedBackground = Color(0xFF0D0F12);
  static const feedVideoPlaceholder = Color(0xFF1B1F25);
  static const glassFill = Color(0x29FFFFFF); // ~16% white
  static const glassBorder = Color(0x47FFFFFF); // ~28% white
  static const onFeedSecondary = Color(0xFFC4C9D1);

  // Status
  static const success = Color(0xFF22C55E);
  static const successSoft = Color(0xFFDCFCE7);
  static const warningSoft = Color(0xFFFFF6E5);
  static const danger = Color(0xFFB42318);
}

class AppSpacing {
  AppSpacing._();

  static const xxs = 4.0;
  static const xs = 6.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Horizontal page padding used on every screen.
  static const page = 16.0;
}

class AppRadius {
  AppRadius._();

  static const s = 10.0;
  static const m = 14.0;
  static const l = 16.0;
  static const xl = 20.0;
  static const sheet = 28.0;
  static const pill = 999.0;
}

class AppSizes {
  AppSizes._();

  static const buttonHeight = 54.0;
  static const inputHeight = 48.0;
  static const chipHeight = 36.0;
  static const navBarHeight = 84.0;
  static const minTouch = 44.0;
}

class AppFonts {
  AppFonts._();

  /// null = system font. Swap in a bundled family later if we want one.
  static const String? display = null;
  static const String? body = null;
}
