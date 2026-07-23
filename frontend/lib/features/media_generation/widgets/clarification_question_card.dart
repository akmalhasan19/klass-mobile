import 'package:flutter/material.dart';
import 'package:klass_app/core/config/app_colors.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
import 'package:klass_app/features/media_generation/models/clarification_gap.dart';
import 'package:klass_app/features/media_generation/widgets/clarification_suggestion_chip.dart';
import 'package:klass_app/features/media_generation/widgets/clarification_progress_indicator.dart';

class ClarificationQuestionCard extends StatefulWidget {
  final ClarificationGap gap;
  final String? currentAnswer;
  final ValueChanged<String> onAnswer;
  final int currentQuestionIndex;
  final int totalQuestions;
  final VoidCallback? onSkipAll;

  const ClarificationQuestionCard({
    super.key,
    required this.gap,
    this.currentAnswer,
    required this.onAnswer,
    this.currentQuestionIndex = 0,
    this.totalQuestions = 0,
    this.onSkipAll,
  });

  @override
  State<ClarificationQuestionCard> createState() => _ClarificationQuestionCardState();
}

class _ClarificationQuestionCardState extends State<ClarificationQuestionCard>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  String? _selectedChipValue;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();

    if (widget.currentAnswer != null) {
      final isChipOption = widget.gap.suggestions.any(
        (s) => s.value == widget.currentAnswer,
      );
      if (isChipOption) {
        _selectedChipValue = widget.currentAnswer;
        _textController.text = '';
      } else {
        _textController.text = widget.currentAnswer!;
      }
    }

    // Auto-focus TextField when there are no suggestion chips (text input only)
    if (widget.gap.suggestions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(ClarificationQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gap.fieldId != widget.gap.fieldId) {
      _selectedChipValue = null;
      _textController.clear();
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onChipSelected(String value) {
    setState(() {
      _selectedChipValue = value;
      _textController.clear();
    });
    _focusNode.unfocus();
  }

  void _onTextSubmitted() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _selectedChipValue = null;
    });
    widget.onAnswer(text);
  }

  @override
  Widget build(BuildContext context) {
    final gap = widget.gap;
    final loc = AppLocalizations.of(context)!;

    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 250),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.totalQuestions > 0) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClarificationProgressIndicator(
                          currentQuestion: widget.currentQuestionIndex,
                          totalQuestions: widget.totalQuestions,
                        ),
                      ),
                      if (widget.onSkipAll != null)
                        TextButton(
                          onPressed: widget.onSkipAll,
                          child: const Text(
                            'Skip',
                            style: TextStyle(
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
              ],
              Text(
                gap.question,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
              if (gap.suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: gap.suggestions.map((suggestion) {
                    return ClarificationSuggestionChip(
                      label: suggestion.label,
                      isSelected: _selectedChipValue == suggestion.value,
                      onTap: () => _onChipSelected(suggestion.value),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: loc.clarificationInputHint,
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                onSubmitted: (_) => _onTextSubmitted(),
              ),
              const SizedBox(height: 24),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _textController,
                builder: (context, value, child) {
                  final hasText = value.text.trim().isNotEmpty;
                  final canSubmit = hasText || _selectedChipValue != null;
                  
                  return SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      key: const Key('clarification_submit_button'),
                      onPressed: canSubmit ? () {
                        if (hasText) {
                          _onTextSubmitted();
                        } else if (_selectedChipValue != null) {
                          widget.onAnswer(_selectedChipValue!);
                        }
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        disabledBackgroundColor: AppColors.border,
                        disabledForegroundColor: AppColors.textMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: canSubmit ? LinearGradient(
                            colors: [AppColors.primary.withValues(alpha: 0.5), AppColors.primary],
                          ) : null,
                          color: canSubmit ? null : AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
