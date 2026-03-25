import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Custom clipper to draw the fluid "Layer 1" shape with concave flares
/// at the top-left and bottom-right, seamlessly merging with the screen edges.
class TopRightFluidClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    double w = size.width;
    double h = size.height;
    double rc = 30.0; // Radius for concave flares
    double rv = 45.0; // Radius for convex bottom-left corner

    // Start at top-left flare, where it meets the top edge of the screen
    path.moveTo(0, 0);

    // Concave curve down-right to the main left vertical edge
    path.quadraticBezierTo(rc, 0, rc, rc);

    // Straight vertical line down to the bottom-left convex corner
    path.lineTo(rc, h - rc - rv);

    // Convex curve for the main bottom-left corner
    path.quadraticBezierTo(rc, h - rc, rc + rv, h - rc);

    // Straight horizontal line right to the bottom-right flare
    path.lineTo(w - rc, h - rc);

    // Concave curve down-right to the right edge
    path.quadraticBezierTo(w, h - rc, w, h);

    // Line up along the right edge to top-right
    path.lineTo(w, 0);

    // Close path (line back to top-left flare)
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

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
      // Increased width and height to accommodate the rc=30 flares
      child: SizedBox(
        width: 140, // 110 + 30
        height: 173, // 143 + 30
        child: Stack(
          children: [
            // Fluid green shape background and brown blob combined
            ClipPath(
              clipper: TopRightFluidClipper(),
              child: Container(
                width: 140,
                height: 173,
                color: AppColors.primary,
                child: Stack(
                  children: [
                    // Brown blob accent (now clipped by Layer 1)
                    Positioned(
                      top: -60,
                      right: -35, // Posisinya digeser lebih ke kanan
                      child: Container(
                        width: 160,
                        height: 140,
                        decoration: const BoxDecoration(
                          color: AppColors.brown,
                          borderRadius: BorderRadius.all(Radius.elliptical(80, 70)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Settings gear button
            if (onSettingsTap != null)
              Positioned(
                top: 62,
                right: 29, // Same physical distance from right edge
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
