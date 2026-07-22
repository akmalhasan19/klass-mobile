import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:klass_app/core/config/app_colors.dart';
import 'package:klass_app/core/network/connectivity_service.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
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

class _ClarificationScreenState extends ConsumerState<ClarificationScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  AnimationController? _summaryAnimController;
  Animation<double>? _summaryFadeAnimation;

  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _summaryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _summaryFadeAnimation = CurvedAnimation(
      parent: _summaryAnimController!,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(clarificationProvider.notifier).initialize(widget.response);
      _fadeController.forward();
      _summaryAnimController?.forward();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    _summaryAnimController?.dispose();
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

  bool _checkOffline() {
    final connectivity = ConnectivityService();
    if (!connectivity.isConnected) {
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.clarificationOfflineError),
          backgroundColor: AppColors.red,
        ),
      );
      return true;
    }
    return false;
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

  Future<void> _onGenerate() async {
    final state = ref.read(clarificationProvider);
    if (state.isSubmitting || state.isGenerating) return;

    if (_checkOffline()) return;

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

    if (_checkOffline()) return;

    final notifier = ref.read(clarificationProvider.notifier);
    await notifier.skipAll();

    if (!mounted) return;
    final newState = ref.read(clarificationProvider);
    if (newState.error == null && !newState.isGenerating) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _onRetry() async {
    setState(() => _isRetrying = true);
    final state = ref.read(clarificationProvider);
    if (state.generationId == null) {
      setState(() => _isRetrying = false);
      return;
    }

    final notifier = ref.read(clarificationProvider.notifier);
    await notifier.confirmGeneration();

    if (!mounted) return;
    setState(() => _isRetrying = false);
    final newState = ref.read(clarificationProvider);
    if (newState.error == null && !newState.isSubmitting) {
      Navigator.of(context).pop(true);
    }
  }

  void _onEdit() {
    final state = ref.read(clarificationProvider);
    final controller = TextEditingController(text: state.suggestedPrompt);
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          loc.clarificationEditPrompt,
          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: loc.clarificationInputHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              final edited = controller.text.trim();
              if (edited.isNotEmpty) {
                ref.read(clarificationProvider.notifier).editSuggestedPrompt(edited);
              }
              Navigator.pop(ctx);
            },
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(clarificationProvider);
    final loc = AppLocalizations.of(context)!;

    ref.listen<ClarificationState>(clarificationProvider, (prev, next) {
      if (next.error != null && prev?.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText(next.error!),
            duration: const Duration(seconds: 15),
            showCloseIcon: true,
            action: SnackBarAction(
              label: loc.clarificationRetry,
              onPressed: _onRetry,
            ),
          ),
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
          loc.clarificationTitle,
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
            onPressed: (state.isSubmitting || state.isGenerating) ? null : _onSkip,
            child: Text(
              loc.clarificationSkip,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: (state.isSubmitting || state.isGenerating)
                    ? AppColors.textMuted
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      ClarificationChatBubble(
                        message: ChatMessage.user(widget.originalPrompt),
                      ),
                      ...state.messages.asMap().entries.map((entry) {
                        final msg = entry.value;
                        return ClarificationChatBubble(message: msg);
                      }),
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
                            chipOrTypeLabel: loc.clarificationChipOrType,
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
                        animation: _summaryFadeAnimation,
                        summaryTitleLabel: loc.clarificationSummaryTitle,
                        summaryProgressLabel: loc.clarificationSummaryProgress(
                          state.answers.length,
                          state.totalGaps,
                        ),
                        generateLabel: loc.clarificationUsePrompt,
                        editLabel: loc.clarificationEditPrompt,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                  if (state.isSubmitting || state.isGenerating || _isRetrying)
                    Container(
                      color: Colors.black.withValues(alpha: 0.15),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
