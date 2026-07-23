import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clarification_response.dart';
import '../models/clarification_gap.dart';
import '../models/chat_message.dart';
import '../data/media_generation_service.dart';
import '../data/clarification_service.dart';
import 'package:klass_app/core/providers/dio_provider.dart';

class ClarificationState {
  final String? generationId;
  final ClarificationResponse? response;
  final Map<String, String> answers;
  final List<ChatMessage> messages;
  final int currentQuestionIndex;
  final bool isSubmitting;
  final bool isGenerating;
  final String? error;
  final String originalSuggestedPrompt;

  ClarificationState({
    this.generationId,
    this.response,
    this.answers = const {},
    this.messages = const [],
    this.currentQuestionIndex = 0,
    this.isSubmitting = false,
    this.isGenerating = false,
    this.error,
    this.originalSuggestedPrompt = '',
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
    String? originalSuggestedPrompt,
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
      originalSuggestedPrompt:
          originalSuggestedPrompt ?? this.originalSuggestedPrompt,
    );
  }
}

class ClarificationNotifier extends StateNotifier<ClarificationState> {
  final MediaGenerationService _mediaGenService;
  final ClarificationService _clarificationService;

  ClarificationNotifier(this._mediaGenService, this._clarificationService) : super(ClarificationState());

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
      originalSuggestedPrompt: response.suggestedPrompt,
    );
  }

  void answerQuestion(String fieldId, String value) {
    if (state.isSubmitting || state.isGenerating) return;

    final updatedAnswers = Map<String, String>.from(state.answers)
      ..[fieldId] = value;

    final updatedMessages = List<ChatMessage>.from(state.messages)
      ..add(ChatMessage.user(value));

    if (fieldId == 'output_type' && value.toLowerCase() == 'pptx') {
      _fetchDynamicPptxGaps(updatedAnswers, updatedMessages);
      return;
    }

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

  Future<void> _fetchDynamicPptxGaps(Map<String, String> currentAnswers, List<ChatMessage> currentMessages) async {
    state = state.copyWith(isSubmitting: true, answers: currentAnswers, messages: currentMessages);

    try {
      final enrichedPrompt = _buildEnrichedPrompt(currentAnswers);
      
      final preflightResponse = await _clarificationService.preflight(
        rawPrompt: enrichedPrompt,
        preferredOutputType: 'pptx',
      );

      final newGaps = preflightResponse.gaps.where((gap) => !currentAnswers.containsKey(gap.fieldId)).toList();
      
      final updatedResponse = ClarificationResponse(
        generationId: state.response?.generationId ?? preflightResponse.generationId,
        detected: preflightResponse.detected,
        gaps: newGaps,
        suggestedPrompt: preflightResponse.suggestedPrompt,
        isReady: newGaps.isEmpty,
        totalRequiredGaps: newGaps.where((g) => g.isRequired).length,
        totalRecommendedGaps: newGaps.where((g) => !g.isRequired).length,
      );

      final nextMessages = List<ChatMessage>.from(currentMessages);
      if (newGaps.isNotEmpty) {
        nextMessages.add(ChatMessage.system('Menyesuaikan pertanyaan untuk format presentasi...'));
      } else {
        nextMessages.add(ChatMessage.system('Semua pertanyaan sudah terjawab!'));
      }

      state = state.copyWith(
        isSubmitting: false,
        response: updatedResponse,
        currentQuestionIndex: 0,
        messages: nextMessages,
      );

    } catch (e) {
      final nextIndex = state.currentQuestionIndex + 1;
      final nextMessages = List<ChatMessage>.from(currentMessages);
      if (nextIndex < state.totalGaps) {
        nextMessages.add(ChatMessage.system('Pertanyaan berikutnya...'));
      } else {
        nextMessages.add(ChatMessage.system('Semua pertanyaan sudah terjawab!'));
      }
        
      state = state.copyWith(
        isSubmitting: false,
        currentQuestionIndex: nextIndex,
        messages: nextMessages,
      );
    }
  }

  Future<void> useSuggestedPrompt() async {
    if (state.generationId == null || state.response == null) return;

    state = state.copyWith(isGenerating: true, clearError: true);

    try {
      final success = await _mediaGenService.skipClarification(
        generationId: state.generationId!,
      );

      if (!success) {
        state = state.copyWith(
          isGenerating: false,
          error: _mediaGenService.errorMessage ?? 'Gagal menggunakan prompt yang disarankan.',
        );
        return;
      }

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
      final success = await _mediaGenService.confirmGeneration(
        generationId: state.generationId!,
        enrichedPrompt: state.response!.suggestedPrompt,
        answers: state.answers,
      );

      if (!success) {
        state = state.copyWith(
          isSubmitting: false,
          error: _mediaGenService.errorMessage ?? 'Gagal mengonfirmasi generasi.',
        );
        return;
      }

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
      final success = await _mediaGenService.skipClarification(
        generationId: state.generationId!,
      );

      if (!success) {
        state = state.copyWith(
          isGenerating: false,
          error: _mediaGenService.errorMessage ?? 'Gagal melewati klarifikasi.',
        );
        return;
      }

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
    final base = state.originalSuggestedPrompt;
    if (answers.isEmpty || base.isEmpty) {
      return base;
    }

    final baseLower = base.toLowerCase();
    final slideParts = <MapEntry<int, String>>[];
    final extraParts = <String>[];

    for (final entry in answers.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) continue;

      final skipValues = {'no', 'tidak', 'none', 'skip', 'auto'};
      if (skipValues.contains(value.toLowerCase())) continue;

      if (baseLower.contains(value.toLowerCase())) continue;

      if (entry.key.startsWith('slide_')) {
        final index = int.tryParse(entry.key.replaceFirst('slide_', '')) ?? 0;
        if (index > 0) {
          slideParts.add(MapEntry(index, value));
        }
      } else if (entry.key == 'learning_objectives') {
        extraParts.add('dengan tujuan pembelajaran: $value');
      } else if (entry.key == 'target_audience') {
        extraParts.add('untuk jenjang $value');
      } else if (entry.key == 'output_type') {
        extraParts.add('dalam format ${value.toUpperCase()}');
      } else if (entry.key == 'difficulty_level') {
        extraParts.add('tingkat kesulitan $value');
      } else if (entry.key == 'question_count') {
        extraParts.add('dengan $value soal');
      } else if (entry.key == 'teaching_method') {
        extraParts.add('dengan metode ${value.replaceAll('_', ' ')}');
      } else if (entry.key == 'slide_count') {
        // already handled if user answered; skip or add explicitly
        if (!baseLower.contains('slide') && !baseLower.contains('halaman')) {
          extraParts.add('sebanyak $value slide');
        }
      } else {
        extraParts.add(value);
      }
    }

    if (slideParts.isEmpty && extraParts.isEmpty) {
      return base;
    }

    slideParts.sort((a, b) => a.key.compareTo(b.key));
    final slideLabels = slideParts
        .map((e) => e.value.contains(':')
            ? e.value.split(':').first.trim()
            : e.value)
        .where((l) => l.isNotEmpty)
        .toList();

    // Strip trailing period from base if we're appending anything
    var cleanBase = base;
    if ((extraParts.isNotEmpty || slideLabels.isNotEmpty) &&
        cleanBase.endsWith('.')) {
      cleanBase = cleanBase.substring(0, cleanBase.length - 1);
    }

    final enriched = StringBuffer(cleanBase);

    if (extraParts.isNotEmpty) {
      enriched.write(', ');
      enriched.write(extraParts.join(', '));
    }

    if (slideLabels.length >= 3) {
      enriched.write(
          '. Susunannya: ${slideLabels.sublist(0, slideLabels.length - 1).join(', ')}, serta ${slideLabels.last}');
    } else if (slideLabels.length == 2) {
      enriched.write(
          '. Susunannya: ${slideLabels[0]} serta ${slideLabels[1]}');
    } else if (slideLabels.length == 1) {
      enriched.write('. Susunannya: ${slideLabels.first}');
    }

    return enriched.toString();
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
  final dio = ref.watch(dioProvider);
  return ClarificationService(dio);
});

final clarificationProvider =
    StateNotifierProvider<ClarificationNotifier, ClarificationState>((ref) {
  final mediaGenService = ref.watch(mediaGenerationServiceProvider);
  final clarificationService = ref.watch(clarificationServiceProvider);
  return ClarificationNotifier(mediaGenService, clarificationService);
});
