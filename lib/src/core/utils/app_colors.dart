import 'package:flutter/material.dart';

/// Palette used by the package's internal widgets.
///
/// [iqama fork] Repointed to the Iqama design tokens so the Quran
/// reader's chrome (top bar, menu sheet, tabs, popups) matches the
/// rest of the app without per-widget overrides. Host-supplied
/// `*Style` overrides still win — these are just the sensible
/// defaults the package falls back to.
class AppColors {
  // ── Surface ─────────────────────────────────────────────────────────
  /// Iqama `surface` (#F8FAFB) — calm off-white.
  static const Color background = Color(0xFFF8FAFB);
  /// Iqama `darkBg` (#0A131C).
  static const Color darkBackground = Color(0xFF0A131C);

  // ── Text ────────────────────────────────────────────────────────────
  /// Iqama `ink` (Midnight Blue #0E1E3A).
  static const Color textColor = Color(0xFF0E1E3A);
  /// Iqama `darkTextPrimary` (#F0F4F8).
  static const Color darkTextColor = Color(0xFFF0F4F8);

  // ── Convenience accents — mirrors of Iqama tokens so internal
  // widgets can lean on the same names without re-importing host code.
  /// Iqama `teal` (#2FA4A0) — primary accent.
  static const Color teal       = Color(0xFF2FA4A0);
  /// Iqama `tealDeep` (#1F7A76).
  static const Color tealDeep   = Color(0xFF1F7A76);
  /// Iqama `tealTint` (#F0FAF9) — used for subtle hover/track surfaces.
  static const Color tealTint   = Color(0xFFF0FAF9);
  /// Iqama `divider` (#E5E9EC).
  static const Color divider    = Color(0xFFE5E9EC);
  /// Iqama `dividerSoft` (#EEF1F3).
  static const Color dividerSoft = Color(0xFFEEF1F3);
  /// Iqama `grey` (#6B7280) — secondary text.
  static const Color grey       = Color(0xFF6B7280);
  /// Iqama `greyLight` (#9AA3AF) — tertiary text.
  static const Color greyLight  = Color(0xFF9AA3AF);

  // Getters keyed off the surrounding theme's brightness.
  static Color getTextColor(bool isDarkMode) =>
      isDarkMode ? darkTextColor : textColor;
  static Color getBackgroundColor(bool isDarkMode) =>
      isDarkMode ? darkBackground : background;
}
