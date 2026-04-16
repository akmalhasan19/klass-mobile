import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../services/media_generation_service.dart';

class MediaGenerationStatusCard extends StatelessWidget {
  const MediaGenerationStatusCard({
    super.key,
    required this.service,
    this.onRefreshStatus,
    this.onDownload,
    this.onRegenerate,
    this.onHireFreelancer,
  });

  final MediaGenerationService service;
  final Future<void> Function()? onRefreshStatus;
  final Future<void> Function()? onDownload;
  final Future<void> Function()? onRegenerate;
  final Future<void> Function()? onHireFreelancer;

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
    final recommendedNextSteps = _stringListAt(deliveryPayload, ['recommended_next_steps']);
    final teacherMessage = _stringAt(deliveryPayload, ['teacher_message']);
    final fallbackTriggered = _boolAt(deliveryPayload, ['fallback', 'triggered']) ?? false;
    final artifactUrl = _stringAt(deliveryPayload, ['artifact', 'file_url']) ?? _stringAt(artifact, ['file_url']);
    final actionSummary = _stringAt(deliveryPayload, ['preview_summary']) ?? teacherMessage;

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
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _StatusBadge(
                      label: title,
                      backgroundColor: Colors.white.withValues(alpha: 0.88),
                      textColor: AppColors.textPrimary,
                    ),
                    _StatusBadge(
                      label: _statusBadgeLabel(isIndonesian: isIndonesian, state: service.state, status: status),
                      backgroundColor: theme.badgeBackground,
                      textColor: theme.badgeText,
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
                const SizedBox(
                  width: 22,
                  height: 22,
                ),
            ],
          ),
          if (service.isLoading || service.isInProgress) ...[
            const SizedBox(height: 32),
            Center(
              child: _MediaGenerationGeometricLoader(
                isIndonesian: isIndonesian,
                status: status,
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
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
          ],
          if (service.isSuccess) ...[
            const SizedBox(height: 18),
            _ActionCluster(
              isIndonesian: isIndonesian,
              canAct: artifactUrl != null && artifactUrl.isNotEmpty,
              onDownload: onDownload,
              onRegenerate: onRegenerate,
              onHireFreelancer: onHireFreelancer,
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
            if (actionSummary != null && actionSummary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                actionSummary,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ],
          if (service.isError) ...[
            const SizedBox(height: 18),
            _CompletionHeroPanel(
              icon: Icons.error_rounded,
              iconColor: AppColors.red,
              iconBackground: const Color(0xFFFEE2E2),
              eyebrow: isIndonesian ? 'PERLU TINJAUAN' : 'NEEDS REVIEW',
              title: isIndonesian ? 'Generation belum selesai dengan sukses' : 'Generation did not finish successfully',
              subtitle: isIndonesian
                  ? 'Status gagal ditampilkan dengan payload aman dari backend agar guru tahu apa yang perlu dilakukan selanjutnya.'
                  : 'The failed state is rendered from the backend-safe payload so teachers know what to do next.',
            ),
            const SizedBox(height: 12),
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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


class _MediaGenerationGeometricLoader extends StatefulWidget {
  const _MediaGenerationGeometricLoader({
    required this.isIndonesian,
    required this.status,
  });

  final bool isIndonesian;
  final String status;

  @override
  State<_MediaGenerationGeometricLoader> createState() => _MediaGenerationGeometricLoaderState();
}

class _MediaGenerationGeometricLoaderState extends State<_MediaGenerationGeometricLoader> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _textController;
  int _textIndex = 0;

  final List<String> _idMessages = [
    'Menyusun silabus...',
    'Mengumpulkan poin kunci...',
    'Finalisasi tata letak...',
  ];

  final List<String> _enMessages = [
    'Structuring syllabus...',
    'Gathering key points...',
    'Finalizing layout...',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _textIndex = (_textIndex + 1) % _idMessages.length;
          });
          _textController.forward(from: 0);
        }
      });
    _textController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.isIndonesian ? _idMessages : _enMessages;
    final primaryColor = const Color(0xFF09AA81);
    final highlightColor = const Color(0xFFD1FAE5);

    // Sequence delays from reference
    final delays = [
      0.0, 0.2, 0.4, // Row 1
      0.1, 0.3, 0.5, // Row 2
      0.2, 0.4, 0.6 // Row 3
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              final isPrimary = index % 2 == 0;
              final delay = delays[index];

              return AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  // Normalize the animation with delay
                  double t = (_pulseController.value - (delay / 2.0));
                  if (t < 0) t += 1.0;
                  if (t > 1) t -= 1.0;

                  // Pulse curve: 0 -> 1 -> 0 matching 0%, 50%, 100%
                  final double pulse = t < 0.5 ? t * 2 : (1.0 - t) * 2;
                  final double opacity = 0.3 + (pulse * 0.7);
                  final double scale = 0.98 + (pulse * 0.04);

                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isPrimary ? primaryColor : highlightColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: _textController,
          builder: (context, child) {
            // Fade in and out matching the CSS @keyframes text-cycle
            double opacity = 1.0;
            if (_textController.value < 0.1) {
              opacity = _textController.value / 0.1;
            } else if (_textController.value > 0.9) {
              opacity = (1.0 - _textController.value) / 0.1;
            }

            return Opacity(
              opacity: opacity,
              child: Text(
                messages[_textIndex],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Mona_Sans',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          widget.isIndonesian ? 'Mengkurasi materi pembelajaran khusus Anda.' : 'Curating your customized learning material.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
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

class _CompletionHeroPanel extends StatelessWidget {
  const _CompletionHeroPanel({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
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

class _ActionCluster extends StatelessWidget {
  const _ActionCluster({
    required this.isIndonesian,
    required this.canAct,
    required this.onDownload,
    required this.onRegenerate,
    required this.onHireFreelancer,
  });

  final bool isIndonesian;
  final bool canAct;
  final Future<void> Function()? onDownload;
  final Future<void> Function()? onRegenerate;
  final Future<void> Function()? onHireFreelancer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canAct && onDownload != null ? () async => onDownload?.call() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              shadowColor: AppColors.primary.withValues(alpha: 0.25),
            ),
            icon: const Icon(Icons.download_rounded),
            label: Text(
              isIndonesian ? 'Unduh File' : 'Download File',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canAct && onRegenerate != null ? () async => onRegenerate?.call() : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2), width: 1.6),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                icon: const Icon(Icons.autorenew_rounded),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    isIndonesian ? 'Regenerasi' : 'Regenerate',
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canAct && onHireFreelancer != null ? () async => onHireFreelancer?.call() : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD97706),
                  side: const BorderSide(color: Color(0xFFF4D8A9), width: 1.6),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                icon: const Icon(Icons.work_outline_rounded),
                label: LayoutBuilder(
                  builder: (context, constraints) {
                    return FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                        child: Text(
                          isIndonesian ? 'Sewa Freelancer' : 'Hire Freelancer',
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}