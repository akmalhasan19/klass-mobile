import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:klass_app/core/config/app_colors.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
import 'package:klass_app/features/media_generation/providers/clarification_provider.dart';
import 'package:klass_app/features/media_generation/widgets/clarification_question_card.dart';
import 'package:klass_app/features/media_generation/widgets/clarification_progress_indicator.dart';

class InlineClarificationWidget extends ConsumerStatefulWidget {
  const InlineClarificationWidget({super.key});

  @override
  ConsumerState<InlineClarificationWidget> createState() => _InlineClarificationWidgetState();
}

class _InlineClarificationWidgetState extends ConsumerState<InlineClarificationWidget> {

  void _onAnswer(String value) {
    final state = ref.read(clarificationProvider);
    final currentGap = state.currentGap;
    if (currentGap == null) return;

    ref.read(clarificationProvider.notifier).answerQuestion(
          currentGap.fieldId,
          value,
        );
    
    // Check if we reached the end
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newState = ref.read(clarificationProvider);
      if (newState.allQuestionsAnswered && !newState.isActive) {
        ref.read(clarificationProvider.notifier).confirmGeneration();
      }
    });
  }

  void _onSkipAll() {
    ref.read(clarificationProvider.notifier).skipAll();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clarificationProvider);
    final loc = AppLocalizations.of(context)!;
    
    if (state.isActive) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    
    if (state.currentGap == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ClarificationProgressIndicator(
                    currentQuestion: state.currentQuestionIndex,
                    totalQuestions: state.totalGaps,
                  ),
                ),
                TextButton(
                  onPressed: _onSkipAll,
                  child: Text(
                    loc.clarificationSkip,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                children: <Widget>[
                  ...previousChildren,
                  ?currentChild,
                ],
              );
            },
            transitionBuilder: (Widget child, Animation<double> animation) {
              final isEntering = child.key == ValueKey(state.currentGap?.fieldId);
              final offsetAnimation = Tween<Offset>(
                begin: isEntering ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
                end: Offset.zero,
              ).animate(animation);
              
              return SlideTransition(
                position: offsetAnimation,
                child: child,
              );
            },
            child: ClarificationQuestionCard(
              key: ValueKey(state.currentGap!.fieldId),
              gap: state.currentGap!,
              currentAnswer: state.answers[state.currentGap!.fieldId],
              onAnswer: _onAnswer,
              chipOrTypeLabel: loc.clarificationChipOrType,
            ),
          ),
        ],
      ),
    );
  }
}
