import 'package:flutter/material.dart';
import 'package:klass_app/core/config/app_colors.dart';
import 'package:klass_app/features/media_generation/models/clarification_gap.dart';
import 'package:klass_app/features/media_generation/widgets/clarification_suggestion_chip.dart';

class ClarificationQuestionCard extends StatefulWidget {
  final ClarificationGap gap;
  final String? currentAnswer;
  final ValueChanged<String> onAnswer;
  final String? chipOrTypeLabel;

  const ClarificationQuestionCard({
    super.key,
    required this.gap,
    this.currentAnswer,
    required this.onAnswer,
    this.chipOrTypeLabel,
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
    widget.onAnswer(value);
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
    final isIndonesian = Localizations.localeOf(context).languageCode == 'id';

    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 250),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: gap.isRequired
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      gap.isRequired
                          ? (isIndonesian ? 'Wajib' : 'Required')
                          : (isIndonesian ? 'Disarankan' : 'Recommended'),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: gap.isRequired ? AppColors.primary : AppColors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      gap.question,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              if (gap.suggestions.isNotEmpty) ...[
                const SizedBox(height: 14),
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
                const SizedBox(height: 12),
                Text(
                  widget.chipOrTypeLabel ??
                      (isIndonesian ? 'Atau ketik sendiri...' : 'Or type your own...'),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: isIndonesian ? 'Ketik jawaban...' : 'Type your answer...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                onSubmitted: (_) => _onTextSubmitted(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
