import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../services/media_generation_service.dart';

class MediaGenerationStatusCard extends StatelessWidget {
  const MediaGenerationStatusCard({
    super.key,
    required this.service,
    this.onRefreshStatus,
  });

  final MediaGenerationService service;
  final Future<void> Function()? onRefreshStatus;

  @override
  Widget build(BuildContext context) {
    if (!service.hasVisibleState) {
      return const SizedBox.shrink();
    }

    final locale = Localizations.localeOf(context);
    final isIndonesian = locale.languageCode == 'id';
    final resource = service.resource;
    final status = service.currentStatus ?? 'queued';
    final deliveryPayload = service.deliveryPayload;
    final artifact = service.artifact;
    final publication = service.publication;
    final theme = _resolveTheme(service.state, status);

    final title = _resolveTitle(
      isIndonesian: isIndonesian,
      state: service.state,
      status: status,
      deliveryPayload: deliveryPayload,
      publication: publication,
      artifact: artifact,
    );
    final subtitle = _resolveSubtitle(
      isIndonesian: isIndonesian,
      state: service.state,
      status: status,
      deliveryPayload: deliveryPayload,
      resource: resource,
      service: service,
    );
    final generationId = service.generationId;
    final retryable = _boolAt(resource, ['error', 'retryable']) ?? false;
    final outputType = (_stringAt(deliveryPayload, ['artifact', 'output_type']) ?? _stringAt(resource, ['resolved_output_type']) ?? _stringAt(resource, ['preferred_output_type']) ?? 'auto').toUpperCase();
    final filename = _stringAt(deliveryPayload, ['artifact', 'filename']) ?? _fileNameFromUrl(_stringAt(deliveryPayload, ['artifact', 'file_url'])) ?? _fileNameFromUrl(_stringAt(artifact, ['file_url']));
    final recommendedNextSteps = _stringListAt(deliveryPayload, ['recommended_next_steps']);
    final teacherMessage = _stringAt(deliveryPayload, ['teacher_message']);
    final fallbackTriggered = _boolAt(deliveryPayload, ['fallback', 'triggered']) ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: theme.shadow,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatusBadge(
                      label: _statusBadgeLabel(isIndonesian: isIndonesian, state: service.state, status: status),
                      backgroundColor: theme.badgeBackground,
                      textColor: theme.badgeText,
                    ),
                    _StatusBadge(
                      label: outputType,
                      backgroundColor: Colors.white.withValues(alpha: 0.88),
                      textColor: AppColors.textPrimary,
                    ),
                    if (generationId != null)
                      _StatusBadge(
                        label: '#${generationId.substring(0, generationId.length > 8 ? 8 : generationId.length)}',
                        backgroundColor: Colors.white.withValues(alpha: 0.74),
                        textColor: AppColors.textMuted,
                      ),
                  ],
                ),
              ),
              if (service.isLoading || service.isInProgress)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.badgeText),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Mona_Sans',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          if (service.isLoading || service.isInProgress) ...[
            const SizedBox(height: 18),
            _ProgressTrack(
              isIndonesian: isIndonesian,
              status: status,
            ),
            const SizedBox(height: 14),
            Text(
              isIndonesian
                  ? 'Polling otomatis berjalan setiap 4 detik sampai status terminal.'
                  : 'Automatic polling runs every 4 seconds until a terminal status is reached.',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
          if (service.isSuccess) ...[
            const SizedBox(height: 18),
            _DetailPanel(
              icon: Icons.description_rounded,
              title: isIndonesian ? 'Artifact final' : 'Final artifact',
              description: filename != null
                  ? '$filename${_stringAt(deliveryPayload, ['artifact', 'mime_type']) != null ? ' • ${_stringAt(deliveryPayload, ['artifact', 'mime_type'])}' : ''}'
                  : (_stringAt(deliveryPayload, ['artifact', 'file_url']) ?? _stringAt(artifact, ['file_url']) ?? (isIndonesian ? 'File siap dibuka dari hasil akhir backend.' : 'The file is ready from the final backend payload.')),
            ),
            if (teacherMessage != null && teacherMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailPanel(
                icon: Icons.auto_awesome_rounded,
                title: isIndonesian ? 'Ringkasan AI' : 'AI summary',
                description: teacherMessage,
              ),
            ],
            if (recommendedNextSteps.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailPanel(
                icon: Icons.checklist_rounded,
                title: isIndonesian ? 'Langkah berikutnya' : 'Recommended next steps',
                description: recommendedNextSteps.take(2).join('\n'),
              ),
            ],
            if (fallbackTriggered) ...[
              const SizedBox(height: 12),
              _NoticeBanner(
                color: AppColors.amber,
                message: isIndonesian
                    ? 'Backend memakai fallback delivery response, tetapi artifact final tetap berhasil dihydrate.'
                    : 'The backend used a fallback delivery response, but the final artifact was still hydrated successfully.',
              ),
            ],
          ],
          if (service.isError) ...[
            const SizedBox(height: 18),
            _NoticeBanner(
              color: AppColors.red,
              message: service.errorMessage ?? (isIndonesian ? 'Terjadi kegagalan pada media generation.' : 'Media generation failed.'),
            ),
            if (retryable) ...[
              const SizedBox(height: 12),
              Text(
                isIndonesian
                    ? 'Backend menandai kegagalan ini sebagai retryable.'
                    : 'The backend marked this failure as retryable.',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (service.canRefreshStatus && onRefreshStatus != null && !_isTerminalFailure(resource)) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async => onRefreshStatus?.call(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isIndonesian ? 'Periksa status lagi' : 'Check status again'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  bool _isTerminalFailure(Map<String, dynamic>? resource) {
    return _stringAt(resource, ['status']) == 'failed' && ((_boolAt(resource, ['status_meta', 'is_terminal']) ?? false));
  }

  String _resolveTitle({
    required bool isIndonesian,
    required MediaGenerationViewState state,
    required String status,
    required Map<String, dynamic>? deliveryPayload,
    required Map<String, dynamic>? publication,
    required Map<String, dynamic>? artifact,
  }) {
    if (state == MediaGenerationViewState.success) {
      return _stringAt(deliveryPayload, ['title'])
          ?? _stringAt(deliveryPayload, ['artifact', 'title'])
          ?? _stringAt(publication, ['recommended_project', 'title'])
          ?? _stringAt(publication, ['topic', 'title'])
          ?? _fileNameFromUrl(_stringAt(artifact, ['file_url']))
          ?? (isIndonesian ? 'Media pembelajaran siap digunakan' : 'Learning material is ready');
    }

    if (state == MediaGenerationViewState.error) {
      return isIndonesian ? 'Media generation membutuhkan perhatian' : 'Media generation needs attention';
    }

    return _progressHeadline(isIndonesian: isIndonesian, status: status);
  }

  String _resolveSubtitle({
    required bool isIndonesian,
    required MediaGenerationViewState state,
    required String status,
    required Map<String, dynamic>? deliveryPayload,
    required Map<String, dynamic>? resource,
    required MediaGenerationService service,
  }) {
    if (state == MediaGenerationViewState.success) {
      return _stringAt(deliveryPayload, ['preview_summary'])
          ?? _stringAt(deliveryPayload, ['teacher_message'])
          ?? (isIndonesian
              ? 'Payload akhir dari backend sudah masuk dan siap dipakai untuk kartu hasil.'
              : 'The final backend payload has been hydrated and is ready for the result card.');
    }

    if (state == MediaGenerationViewState.error) {
      return service.submittedPrompt != null
          ? (isIndonesian
              ? 'Prompt: ${service.submittedPrompt}'
              : 'Prompt: ${service.submittedPrompt}')
          : (_stringAt(resource, ['prompt']) ?? (isIndonesian ? 'Periksa status generation dan coba lagi bila diperlukan.' : 'Review the generation status and try again if needed.'));
    }

    final prompt = service.submittedPrompt ?? _stringAt(resource, ['prompt']);
    final statusCopy = _progressSubtitle(isIndonesian: isIndonesian, status: status);

    if (prompt == null || prompt.isEmpty) {
      return statusCopy;
    }

    return '$statusCopy\n\n${isIndonesian ? 'Prompt' : 'Prompt'}: $prompt';
  }

  String _statusBadgeLabel({
    required bool isIndonesian,
    required MediaGenerationViewState state,
    required String status,
  }) {
    switch (state) {
      case MediaGenerationViewState.loading:
        return isIndonesian ? 'Mengirim' : 'Submitting';
      case MediaGenerationViewState.inProgress:
        return _statusLabel(isIndonesian: isIndonesian, status: status);
      case MediaGenerationViewState.success:
        return isIndonesian ? 'Siap' : 'Ready';
      case MediaGenerationViewState.error:
        return isIndonesian ? 'Gagal' : 'Failed';
      case MediaGenerationViewState.idle:
        return '';
    }
  }

  String _statusLabel({required bool isIndonesian, required String status}) {
    return switch (status) {
      'queued' => isIndonesian ? 'Dalam antrean' : 'Queued',
      'interpreting' => isIndonesian ? 'Memahami prompt' : 'Understanding prompt',
      'classified' => isIndonesian ? 'Menentukan format' : 'Deciding format',
      'generating' => isIndonesian ? 'Menghasilkan file' : 'Generating file',
      'uploading' => isIndonesian ? 'Mengunggah artifact' : 'Uploading artifact',
      'publishing' => isIndonesian ? 'Mempublikasikan hasil' : 'Publishing result',
      'completed' => isIndonesian ? 'Selesai' : 'Completed',
      'failed' => isIndonesian ? 'Gagal' : 'Failed',
      _ => status,
    };
  }

  String _progressHeadline({required bool isIndonesian, required String status}) {
    switch (status) {
      case 'queued':
      case 'interpreting':
        return isIndonesian ? 'Prompt sedang dipahami' : 'Understanding your prompt';
      case 'classified':
        return isIndonesian ? 'Format akhir sedang diputuskan' : 'Deciding the final format';
      case 'generating':
      case 'uploading':
        return isIndonesian ? 'Artifact sedang dibuat' : 'Generating the artifact';
      case 'publishing':
        return isIndonesian ? 'Hasil sedang dipublikasikan' : 'Publishing the final result';
      default:
        return isIndonesian ? 'Media generation sedang berjalan' : 'Media generation is in progress';
    }
  }

  String _progressSubtitle({required bool isIndonesian, required String status}) {
    return switch (status) {
      'queued' => isIndonesian ? 'Permintaan sudah diterima backend dan menunggu worker queue.' : 'The request was accepted by the backend and is waiting for the queue worker.',
      'interpreting' => isIndonesian ? 'LLM sedang menyusun interpretasi prompt sebelum generation spec dibuat.' : 'The LLM is interpreting the prompt before the generation spec is built.',
      'classified' => isIndonesian ? 'Backend sedang memutuskan output type terbaik untuk artifact ini.' : 'The backend is deciding the best output type for this artifact.',
      'generating' => isIndonesian ? 'Service generator sedang merender file akhir.' : 'The generator service is rendering the final file.',
      'uploading' => isIndonesian ? 'Artifact sedang divalidasi dan diunggah ke storage.' : 'The artifact is being validated and uploaded to storage.',
      'publishing' => isIndonesian ? 'Entity workspace dan homepage sedang dihydrate dari hasil publish.' : 'Workspace and homepage entities are being hydrated from the published result.',
      _ => isIndonesian ? 'Status terbaru akan tampil otomatis setelah polling berikutnya.' : 'The latest status will appear automatically after the next poll.',
    };
  }

  _CardTheme _resolveTheme(MediaGenerationViewState state, String status) {
    if (state == MediaGenerationViewState.error) {
      return const _CardTheme(
        background: Color(0xFFFFF4F4),
        border: Color(0xFFF8C4C4),
        shadow: Color(0x14EF4444),
        badgeBackground: Color(0xFFEF4444),
        badgeText: Colors.white,
      );
    }

    if (state == MediaGenerationViewState.success) {
      return const _CardTheme(
        background: Color(0xFFF3FBF4),
        border: Color(0xFFCDE7D1),
        shadow: Color(0x14529F60),
        badgeBackground: Color(0xFF2F855A),
        badgeText: Colors.white,
      );
    }

    if (status == 'publishing') {
      return const _CardTheme(
        background: Color(0xFFFFF8EE),
        border: Color(0xFFF4D8A9),
        shadow: Color(0x14D97706),
        badgeBackground: Color(0xFFD97706),
        badgeText: Colors.white,
      );
    }

    return const _CardTheme(
      background: Color(0xFFF4FAF4),
      border: Color(0xFFD4E8D6),
      shadow: Color(0x12529F60),
      badgeBackground: Color(0xFF529F60),
      badgeText: Colors.white,
    );
  }

  String? _fileNameFromUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments ?? const <String>[];

    if (segments.isEmpty) {
      return null;
    }

    return segments.last;
  }

  String? _stringAt(Map<String, dynamic>? source, List<String> path) {
    dynamic current = source;

    for (final segment in path) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
        continue;
      }

      if (current is Map) {
        current = current[segment];
        continue;
      }

      return null;
    }

    if (current == null) {
      return null;
    }

    final value = current.toString().trim();
    return value.isEmpty ? null : value;
  }

  bool? _boolAt(Map<String, dynamic>? source, List<String> path) {
    dynamic current = source;

    for (final segment in path) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
        continue;
      }

      if (current is Map) {
        current = current[segment];
        continue;
      }

      return null;
    }

    if (current is bool) {
      return current;
    }

    return null;
  }

  List<String> _stringListAt(Map<String, dynamic>? source, List<String> path) {
    dynamic current = source;

    for (final segment in path) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
        continue;
      }

      if (current is Map) {
        current = current[segment];
        continue;
      }

      return const [];
    }

    if (current is! List) {
      return const [];
    }

    return current
        .where((item) => item != null)
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class _CardTheme {
  const _CardTheme({
    required this.background,
    required this.border,
    required this.shadow,
    required this.badgeBackground,
    required this.badgeText,
  });

  final Color background;
  final Color border;
  final Color shadow;
  final Color badgeBackground;
  final Color badgeText;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({
    required this.isIndonesian,
    required this.status,
  });

  final bool isIndonesian;
  final String status;

  @override
  Widget build(BuildContext context) {
    final steps = [
      isIndonesian ? 'Memahami prompt' : 'Understanding prompt',
      isIndonesian ? 'Menentukan format' : 'Deciding format',
      isIndonesian ? 'Membuat file' : 'Generating file',
      isIndonesian ? 'Publikasi hasil' : 'Publishing result',
    ];
    final currentStep = _currentStep(status);

    return Column(
      children: List.generate(steps.length, (index) {
        final isDone = index < currentStep;
        final isCurrent = index == currentStep;

        return Padding(
          padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 10),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isDone || isCurrent ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDone || isCurrent ? AppColors.primary : AppColors.border,
                    width: 1.8,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : isCurrent
                        ? const Padding(
                            padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                          )
                        : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  steps[index],
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                    color: isCurrent || isDone ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  int _currentStep(String status) {
    switch (status) {
      case 'classified':
        return 1;
      case 'generating':
      case 'uploading':
        return 2;
      case 'publishing':
      case 'completed':
      case 'failed':
        return 3;
      case 'queued':
      case 'interpreting':
      default:
        return 0;
    }
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.5,
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

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.color,
    required this.message,
  });

  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.5,
        ),
      ),
    );
  }
}