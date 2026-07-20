import 'package:flutter/material.dart';
import 'package:klass_app/core/config/app_colors.dart';

class ClarificationProgressIndicator extends StatelessWidget {
  final int currentQuestion;
  final int totalQuestions;

  const ClarificationProgressIndicator({
    super.key,
    required this.currentQuestion,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    if (totalQuestions == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(totalQuestions, (index) {
                final isActive = index < currentQuestion;
                final isCurrent = index == currentQuestion;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 3,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : isCurrent
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$currentQuestion / $totalQuestions',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
