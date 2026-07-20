import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:klass_app/core/config/app_colors.dart';
import 'package:klass_app/features/media_generation/models/clarification_response.dart';
import 'package:klass_app/features/media_generation/models/chat_message.dart';
import 'package:klass_app/features/media_generation/providers/clarification_provider.dart';
import 'package:klass_app/features/media_generation/widgets/clarification_chat_bubble.dart';
import 'package:klass_app/features/media_generation/widgets/clarification_progress_indicator.dart';
import 'package:klass_app/features/media_generation/widgets/clarification_question_card.dart';
import 'package:klass_app/features/media_generation/widgets/clarification_summary_card.dart';

class ClarificationScreen extends ConsumerStatefulWidget {
  final ClarificationResponse response;
  final String originalPrompt;

  const ClarificationScreen({
    super.key,
    required this.response,
    required this.originalPrompt,
  });

  @override
  ConsumerState<ClarificationScreen> createState() => _ClarificationScreenState();
}

class _ClarificationScreenState extends ConsumerState<ClarificationScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clarificationProvider.notifier).initialize(widget.response);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onAnswer(String value) {
    final state = ref.read(clarificationProvider);
    final currentGap = state.currentGap;
    if (currentGap == null) return;

    ref.read(clarificationProvider.notifier).answerQuestion(
          currentGap.fieldId,
          value,
        );
    _scrollToBottom();
  }

  void _onTextSubmit() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _onAnswer(text);
  }

  Future<void> _onGenerate() async {
    final state = ref.read(clarificationProvider);
    if (state.isSubmitting || state.isGenerating) return;

    final notifier = ref.read(clarificationProvider.notifier);
    await notifier.confirmGeneration();

    if (!mounted) return;
    final newState = ref.read(clarificationProvider);
    if (newState.error == null && !newState.isSubmitting) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _onSkip() async {
    final state = ref.read(clarificationProvider);
    if (state.isSubmitting || state.isGenerating) return;

    final notifier = ref.read(clarificationProvider.notifier);
    await notifier.skipAll();

    if (!mounted) return;
    final newState = ref.read(clarificationProvider);
    if (newState.error == null && !newState.isGenerating) {
      Navigator.of(context).pop(true);
    }
  }

  void _onEdit() {
    final state = ref.read(clarificationProvider);
    final controller = TextEditingController(text: state.suggestedPrompt);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Edit Prompt',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Edit prompt...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              final edited = controller.text.trim();
              if (edited.isNotEmpty) {
                ref.read(clarificationProvider.notifier).editSuggestedPrompt(edited);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clarificationProvider);
    final isIndonesian = Localizations.localeOf(context).languageCode == 'id';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    ref.listen<ClarificationState>(clarificationProvider, (prev, next) {
      if (next.error != null && prev?.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          isIndonesian ? 'Clarifikasi Prompt' : 'Clarify Prompt',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _onSkip,
            child: Text(
              isIndonesian ? 'Lewati' : 'Skip',
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
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ClarificationChatBubble(
                  message: _userPromptMessage(widget.originalPrompt),
                ),
                ...state.messages.map(
                  (msg) => ClarificationChatBubble(message: msg),
                ),
                if (state.hasGaps && !state.allQuestionsAnswered) ...[
                  const SizedBox(height: 8),
                  ClarificationProgressIndicator(
                    currentQuestion: state.currentQuestionIndex,
                    totalQuestions: state.totalGaps,
                  ),
                  const SizedBox(height: 4),
                  if (state.currentGap != null)
                    ClarificationQuestionCard(
                      key: ValueKey(state.currentGap!.fieldId),
                      gap: state.currentGap!,
                      currentAnswer: state.answers[state.currentGap!.fieldId],
                      onAnswer: _onAnswer,
                      chipOrTypeLabel: isIndonesian
                          ? 'Atau ketik sendiri...'
                          : 'Or type your own...',
                    ),
                ],
                const SizedBox(height: 12),
                ClarificationSummaryCard(
                  suggestedPrompt: state.suggestedPrompt.isNotEmpty
                      ? state.suggestedPrompt
                      : widget.originalPrompt,
                  answeredCount: state.answers.length,
                  totalQuestions: state.totalGaps,
                  isGenerating: state.isGenerating,
                  onGenerate: _onGenerate,
                  onEdit: _onEdit,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: bottomInset + 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _textFocusNode,
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: isIndonesian ? 'Ketik jawaban...' : 'Type your answer...',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    onSubmitted: (_) => _onTextSubmit(),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: _onTextSubmit,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ChatMessage _userPromptMessage(String prompt) {
    return ChatMessage.user(prompt);
  }
}
