import 'package:flutter/material.dart';

/// Warna-warna utama aplikasi Klass.
/// Diambil dari desain Next.js asli.
class AppColors {
  AppColors._();

  // Primary Green (dari #529F60)
  static const Color primary = Color(0xFF529F60);
  static const Color primaryDark = Color(0xFF458A52);
  static const Color primaryLight = Color(0x1A529F60); // 10% opacity

  // Brown Accent (dari #794517 — Creator Tools / Settings)
  static const Color brown = Color(0xFF794517);
  static const Color brownLight = Color(0xFF8B5E3C);

  // Dark Theme Surface colors
  static const Color background = Color(0xFF0F1117);
  static const Color surface = Color(0xFF181B23);
  static const Color surfaceLight = Color(0xFF1E222D);
  static const Color surfaceCard = Color(0xFF232836);

  // Text colors
  static const Color textPrimary = Color(0xFFE8ECF4);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Borders
  static const Color border = Color(0xFF2A2F3C);
  static const Color borderLight = Color(0xFF353A48);

  // Accent colors
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
}
