import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Shape accent hijau di pojok kanan atas (mereplikasi .top-right-shape
/// dari CSS Next.js) dengan blob coklat di dalamnya.
class TopRightAccent extends StatelessWidget {
  final VoidCallback? onSettingsTap;

  const TopRightAccent({super.key, this.onSettingsTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: SizedBox(
        width: 110,
        height: 143,
        child: Stack(
          children: [
            // Green shape background
            Container(
              width: 110,
              height: 143,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                ),
              ),
            ),
            // Brown blob accent
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 160,
                height: 140,
                decoration: const BoxDecoration(
                  color: AppColors.brown,
                  borderRadius: BorderRadius.all(Radius.elliptical(80, 70)),
                ),
              ),
            ),
            // Settings gear button
            if (onSettingsTap != null)
              Positioned(
                top: 62,
                right: 29,
                child: GestureDetector(
                  onTap: onSettingsTap,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      color: AppColors.textMuted,
                      size: 24,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
