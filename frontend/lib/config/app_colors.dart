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

  // Light Theme Surface colors
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFF1F5F9);
  static const Color surfaceCard = Color(0xFFFFFFFF);

  // Text colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);

  // Borders
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Accent colors
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
}
