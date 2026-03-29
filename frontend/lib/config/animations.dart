import 'package:flutter/material.dart';

/// Staggered Fade Transition — mereplikasi transisi "premium" Klass.
/// Deskripsi:
/// 1. Widget lama memudar (fade out) pada paruh pertama durasi (0.0 -> 0.5).
/// 2. Widget baru memudar (fade in) pada paruh kedua durasi (0.5 -> 1.0).
class StaggeredFadeTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const StaggeredFadeTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final val = animation.value;
        
        // Kita perlu tahu apakah 'child' ini adalah yang masuk atau yang keluar.
        // Di AnimatedSwitcher, 'animation' untuk widget yang masuk berjalan 0 -> 1.
        // Sedangkan untuk widget yang keluar berjalan 1 -> 0 (jika menggunakan default).
        
        // Namun, jika kita ingin kontrol penuh, kita bisa menggunakan status:
        final bool isIncoming = animation.status == AnimationStatus.forward || 
                                animation.status == AnimationStatus.completed;

        double opacity = 0.0;
        
        if (isIncoming) {
          // Fade in selama 0.5 -> 1.0 (dalam skala 0 -> 1)
          opacity = ((val - 0.5) * 2).clamp(0.0, 1.0);
        } else {
          // Fade out selama 1.0 -> 0.5 (dalam skala 1 -> 0 dari AnimatedSwitcher)
          // Saat AnimatedSwitcher membuang widget, animation.value turun dari 1 ke 0.
          // Kita ingin fade out di 1.0 -> 0.5 (paruh pertama transisi global).
          opacity = ((val - 0.5) * 2).clamp(0.0, 1.0);
          // Wait, logic ini agak membingungkan jika menggunakan AnimatedSwitcher bawaan.
        }

        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
    );
  }
}

/// Helper function untuk flightShuttleBuilder di Hero
Widget buildStaggeredFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final val = animation.value;
      final isPush = flightDirection == HeroFlightDirection.push;

      double fromOpacity;
      double toOpacity;

      if (isPush) {
        // Push: val 0.0 -> 1.0
        fromOpacity = (1.0 - (val * 2)).clamp(0.0, 1.0);
        toOpacity = ((val - 0.5) * 2).clamp(0.0, 1.0);
      } else {
        // Pop: val 1.0 -> 0.0
        // fromWidget (Settings) starts visible (val=1) and fades out by val=0.5
        fromOpacity = ((val - 0.5) * 2).clamp(0.0, 1.0);
        // toWidget (Home) starts invisible (val=1) and fades in after val=0.5
        toOpacity = (1.0 - (val * 2)).clamp(0.0, 1.0);
      }

      // Kita butuh widget asal dan tujuan. Hero memberikan konteks, 
      // tetapi widget yang sedang terbang biasanya sudah disediakan oleh sistem.
      // Namun, untuk kustomisasi fade cross-over, kita seringkali membungkus 
      // dari konteks toHeroContext.widget
      
      final toWidget = (toHeroContext.widget as Hero).child;
      final fromWidget = (fromHeroContext.widget as Hero).child;

      return Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: fromOpacity,
              child: fromWidget,
            ),
            Opacity(
              opacity: toOpacity,
              child: toWidget,
            ),
          ],
        ),
      );
    },
  );
}
