import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Skeleton loader untuk Project Suggestion Card.
class ProjectSuggestionSkeleton extends StatelessWidget {
  final String ratio; // 'ppt', 'infographic', 'square'

  const ProjectSuggestionSkeleton({
    super.key,
    this.ratio = 'ppt',
  });

  double get _aspectRatio {
    switch (ratio) {
      case 'ppt':
        return 16 / 9;
      case 'infographic':
        return 9 / 16;
      case 'square':
        return 1 / 1;
      default:
        return 16 / 9;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ratio == 'infographic' ? 120 : (ratio == 'square' ? 180 : 280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Preview image skeleton
          Flexible(
            child: AspectRatio(
              aspectRatio: _aspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: AppColors.border.withValues(alpha: 0.25),
                ),
                child: ShimmerEffect(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Project info skeleton
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title skeleton
                Container(
                  width: 140,
                  height: 16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: AppColors.border.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(height: 8),
                // Author skeleton
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: AppColors.border.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader untuk Freelancer Card.
class FreelancerSkeleton extends StatelessWidget {
  const FreelancerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.border.withValues(alpha: 0.25),
          ),
          child: ShimmerEffect(
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 70,
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: AppColors.border.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

/// Efek animasi shimmer sederhana untuk skeleton.
class ShimmerEffect extends StatefulWidget {
  final Widget child;
  const ShimmerEffect({super.key, required this.child});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.3),
                Colors.white.withValues(alpha: 0.0),
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlidingGradientTransform(offset: _animation.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({
    required this.offset,
  });

  final double offset;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * offset, 0.0, 0.0);
  }
}
