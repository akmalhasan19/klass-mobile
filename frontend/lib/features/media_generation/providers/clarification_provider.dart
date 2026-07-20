import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clarification_response.dart';
import '../models/clarification_gap.dart';
import '../models/chat_message.dart';
import '../data/clarification_service.dart';

class ClarificationState {
  final String? generationId;
  final ClarificationResponse? response;
  final Map<String, String> answers;
  final List<ChatMessage> messages;
  final int currentQuestionIndex;
  final bool isSubmitting;
  final bool isGenerating;
  final String? error;

  ClarificationState({
    this.generationId,
    this.response,
    this.answers = const {},
    this.messages = const [],
    this.currentQuestionIndex = 0,
    this.isSubmitting = false,
    this.isGenerating = false,
    this.error,
  });

  bool get isReady => response?.isReady ?? true;

  int get totalRequiredGaps => response?.totalRequiredGaps ?? 0;

  int get answeredRequiredCount {
    if (response == null) return 0;
    return response!.gaps
        .where((gap) => gap.isRequired && answers.containsKey(gap.fieldId))
        .length;
  }

  String get suggestedPrompt => response?.suggestedPrompt ?? '';

  bool get allRequiredAnswered => answeredRequiredCount >= totalRequiredGaps;

  int get totalGaps => response?.totalGaps ?? 0;

  bool get hasGaps => response != null && response!.gaps.isNotEmpty;

  ClarificationGap? get currentGap {
    if (response == null || currentQuestionIndex >= response!.gaps.length) {
      return null;
    }
    return response!.gaps[currentQuestionIndex];
  }

  bool get isLastQuestion => currentQuestionIndex >= totalGaps - 1;

  bool get allQuestionsAnswered => currentQuestionIndex >= totalGaps;

  bool get isActive => isSubmitting || isGenerating;

  ClarificationState copyWith({
    String? generationId,
    ClarificationResponse? response,
    Map<String, String>? answers,
    List<ChatMessage>? messages,
    int? currentQuestionIndex,
    bool? isSubmitting,
    bool? isGenerating,
    String? error,
    bool clearError = false,
  }) {
    return ClarificationState(
      generationId: generationId ?? this.generationId,
      response: response ?? this.response,
      answers: answers ?? this.answers,
      messages: messages ?? this.messages,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isGenerating: isGenerating ?? this.isGenerating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ClarificationNotifier extends StateNotifier<ClarificationState> {
  final ClarificationService _service;

  ClarificationNotifier(this._service) : super(ClarificationState());

  void initialize(ClarificationResponse response) {
    if (response.generationId.isEmpty) {
      state = state.copyWith(error: 'Invalid clarification response: missing generation ID');
      return;
    }

    final messages = <ChatMessage>[];

    final topic = response.detected.topic;
    if (topic != null && topic.isNotEmpty) {
      messages.add(ChatMessage.system(
        'Saya mengerti Anda ingin membuat konten tentang $topic. '
        'Saya perlu beberapa info lagi agar hasilnya lebih baik.',
      ));
    } else {
      messages.add(ChatMessage.system(
        'Saya perlu beberapa informasi tambahan agar konten yang dihasilkan lebih sesuai.',
      ));
    }

    state = ClarificationState(
      generationId: response.generationId,
      response: response,
      messages: messages,
      currentQuestionIndex: 0,
    );
  }

  void answerQuestion(String fieldId, String value) {
    if (state.isSubmitting || state.isGenerating) return;

    final updatedAnswers = Map<String, String>.from(state.answers)
      ..[fieldId] = value;

    final updatedMessages = List<ChatMessage>.from(state.messages)
      ..add(ChatMessage.user(value));

    final nextIndex = state.currentQuestionIndex + 1;

    if (nextIndex < state.totalGaps) {
      updatedMessages.add(ChatMessage.system('Pertanyaan berikutnya...'));
    } else {
      updatedMessages.add(ChatMessage.system('Semua pertanyaan sudah terjawab!'));
    }

    final suggestedPrompt = _buildEnrichedPrompt(updatedAnswers);

    state = state.copyWith(
      answers: updatedAnswers,
      messages: updatedMessages,
      currentQuestionIndex: nextIndex,
      response: state.response != null
          ? ClarificationResponse(
              generationId: state.response!.generationId,
              detected: state.response!.detected,
              gaps: state.response!.gaps,
              suggestedPrompt: suggestedPrompt,
              isReady: state.response!.isReady,
              totalRequiredGaps: state.response!.totalRequiredGaps,
              totalRecommendedGaps: state.response!.totalRecommendedGaps,
            )
          : null,
    );
  }

  void skipQuestion() {
    if (state.isSubmitting || state.isGenerating) return;

    final nextIndex = state.currentQuestionIndex + 1;

    final updatedMessages = List<ChatMessage>.from(state.messages)
      ..add(ChatMessage.system('Pertanyaan berikutnya...'));

    state = state.copyWith(
      currentQuestionIndex: nextIndex,
      messages: updatedMessages,
    );
  }

  Future<void> useSuggestedPrompt() async {
    if (state.generationId == null || state.response == null) return;

    state = state.copyWith(isGenerating: true, clearError: true);

    try {
      await _service.skipClarification(generationId: state.generationId!);
      state = state.copyWith(isGenerating: false);
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: _humanizeError(e),
      );
    }
  }

  Future<void> confirmGeneration() async {
    if (state.generationId == null || state.response == null) return;

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      await _service.confirmGeneration(
        generationId: state.generationId!,
        enrichedPrompt: state.response!.suggestedPrompt,
        answers: state.answers,
      );
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: _humanizeError(e),
      );
    }
  }

  Future<void> skipAll() async {
    if (state.generationId == null || state.response == null) return;

    state = state.copyWith(isGenerating: true, clearError: true);

    try {
      await _service.skipClarification(generationId: state.generationId!);
      state = state.copyWith(isGenerating: false);
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        error: _humanizeError(e),
      );
    }
  }

  void editSuggestedPrompt(String newPrompt) {
    if (state.response == null) return;

    state = state.copyWith(
      response: ClarificationResponse(
        generationId: state.response!.generationId,
        detected: state.response!.detected,
        gaps: state.response!.gaps,
        suggestedPrompt: newPrompt,
        isReady: state.response!.isReady,
        totalRequiredGaps: state.response!.totalRequiredGaps,
        totalRecommendedGaps: state.response!.totalRecommendedGaps,
      ),
    );
  }

  String _buildEnrichedPrompt(Map<String, String> answers) {
    final parts = <String>[];
    final base = state.response?.suggestedPrompt ?? '';

    if (base.isNotEmpty) {
      parts.add(base);
    }

    for (final entry in answers.entries) {
      final gap = state.response?.gaps.firstWhere(
        (g) => g.fieldId == entry.key,
        orElse: () => state.response!.gaps.first,
      );
      if (gap != null && entry.value.isNotEmpty) {
        parts.add(entry.value);
      }
    }

    return parts.join(', ');
  }

  String _humanizeError(Object error) {
    final message = error.toString();
    if (message.contains('SocketException') || message.contains('Connection refused')) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
    }
    if (message.contains('timeout') || message.contains('Timeout')) {
      return 'Permintaan timeout. Silakan coba lagi.';
    }
    if (message.contains('400') || message.contains('Bad Request')) {
      return 'Data tidak valid. Silakan periksa jawaban Anda.';
    }
    if (message.contains('401') || message.contains('403')) {
      return 'Sesi Anda telah berakhir. Silakan login kembali.';
    }
    if (message.contains('500') || message.contains('Internal Server Error')) {
      return 'Terjadi kesalahan server. Silakan coba lagi nanti.';
    }
    return message.isNotEmpty ? message : 'Terjadi kesalahan yang tidak diketahui.';
  }
}

final clarificationServiceProvider = Provider<ClarificationService>((ref) {
  throw UnimplementedError(
    'clarificationServiceProvider must be overridden at app level with a Dio instance.',
  );
});

final clarificationProvider =
    StateNotifierProvider<ClarificationNotifier, ClarificationState>((ref) {
  final service = ref.watch(clarificationServiceProvider);
  return ClarificationNotifier(service);
});
