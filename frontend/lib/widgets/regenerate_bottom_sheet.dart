import 'package:flutter/material.dart';

import '../config/app_colors.dart';
import '../services/media_generation_service.dart';

class RegenerateBottomSheet extends StatefulWidget {
  final MediaGenerationService service;
  final String parentGenerationId;
  final String originalPrompt;
  final VoidCallback onSuccess;

  const RegenerateBottomSheet({
    super.key,
    required this.service,
    required this.parentGenerationId,
    required this.originalPrompt,
    required this.onSuccess,
  });

  @override
  State<RegenerateBottomSheet> createState() => _RegenerateBottomSheetState();

  static Future<void> show(
    BuildContext context, {
    required MediaGenerationService service,
    required String parentGenerationId,
    required String originalPrompt,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RegenerateBottomSheet(
        service: service,
        parentGenerationId: parentGenerationId,
        originalPrompt: originalPrompt,
        onSuccess: onSuccess,
      ),
    );
  }
}

class _RegenerateBottomSheetState extends State<RegenerateBottomSheet> {
  final TextEditingController _additionalPromptController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _additionalPromptController.dispose();
    super.dispose();
  }

  Future<void> _submitRegeneration() async {
    final additionalPrompt = _additionalPromptController.text.trim();
    if (additionalPrompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tuliskan konteks tambahan terlebih dahulu.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await widget.service.regenerateWithPrompt(
      widget.parentGenerationId,
      additionalPrompt,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      Navigator.pop(context);
      widget.onSuccess();
    } else {
      final errorMsg = widget.service.errorMessage ?? 'Gagal melakukan regenerasi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add padding for keyboard avoidance
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final locale = Localizations.localeOf(context);
    final isIndonesian = locale.languageCode == 'id';

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isIndonesian ? 'Regenerasi Media' : 'Regenerate Media',
                style: const TextStyle(
                  fontFamily: 'Mona_Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isIndonesian ? 'Prompt Original:' : 'Original Prompt:',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(
              widget.originalPrompt,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textMuted,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isIndonesian ? 'Konteks/Revisi Tambahan:' : 'Additional Context/Revision:',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _additionalPromptController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: isIndonesian ? 'Contoh: Buat bahasanya lebih sederhana untuk anak SMP...' : 'E.g. Make the language simpler for middle school students...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRegeneration,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.3),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      isIndonesian ? 'Kirim Permintaan' : 'Submit Request',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
