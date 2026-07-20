import 'package:flutter/material.dart';
import 'package:klass_app/core/config/app_colors.dart';

class ClarificationSummaryCard extends StatelessWidget {
  final String suggestedPrompt;
  final int answeredCount;
  final int totalQuestions;
  final bool isGenerating;
  final VoidCallback onGenerate;
  final VoidCallback onEdit;
  final String? generateLabel;
  final String? editLabel;

  const ClarificationSummaryCard({
    super.key,
    required this.suggestedPrompt,
    required this.answeredCount,
    required this.totalQuestions,
    required this.isGenerating,
    required this.onGenerate,
    required this.onEdit,
    this.generateLabel,
    this.editLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isIndonesian = Localizations.localeOf(context).languageCode == 'id';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('💡', style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  generateLabel ??
                      (isIndonesian ? 'Prompt yang disempurnakan:' : 'Enhanced prompt:'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '"$suggestedPrompt"',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          if (totalQuestions > 0) ...[
            const SizedBox(height: 10),
            Text(
              isIndonesian
                  ? '$answeredCount dari $totalQuestions pertanyaan terjawab'
                  : '$answeredCount of $totalQuestions questions answered',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isGenerating ? null : onGenerate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.3),
              ),
              child: isGenerating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      generateLabel ??
                          (isIndonesian ? 'Generate dengan Prompt Ini' : 'Generate with This Prompt'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isGenerating ? null : onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                editLabel ??
                    (isIndonesian ? 'Edit Prompt Ini' : 'Edit This Prompt'),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: const BorderSide(color: AppColors.border, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
