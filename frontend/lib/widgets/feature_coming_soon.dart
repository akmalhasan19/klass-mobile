import 'package:flutter/material.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
import '../config/app_colors.dart';

class FeatureComingSoon extends StatelessWidget {
  final String title;
  final String description;
  final String featureName;
  final String featureDescription;
  final IconData icon;
  final IconData previewIcon;

  const FeatureComingSoon({
    super.key,
    this.title = 'A New Chapter for Your Library',
    this.description = 'We’re busy building this feature for you. It’ll be ready in a future update! Our curators are currently indexing new collections to enhance your experience.',
    this.featureName = 'Enhanced Archiving',
    this.featureDescription = 'Intelligent cross-referencing for your sources.',
    this.icon = Icons.menu_book_rounded,
    this.previewIcon = Icons.history_edu_rounded,
  });

  /// Menampilkan modal "Feature Coming Soon" sebagai dialog di tengah layar.
  static Future<void> show(BuildContext context, {
    String? title,
    String? description,
    String? featureName,
    String? featureDescription,
    IconData? icon,
    IconData? previewIcon,
  }) {
    final localizations = AppLocalizations.of(context);

    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: FeatureComingSoon(
          title: title ?? localizations?.featureComingSoonDefaultTitle ?? 'A New Chapter for Your Library',
          description: description ?? localizations?.featureComingSoonDefaultDescription ?? 'We’re busy building this feature for you. It’ll be ready in a future update! Our curators are currently indexing new collections to enhance your experience.',
          featureName: featureName ?? localizations?.featureComingSoonDefaultFeatureName ?? 'Enhanced Archiving',
          featureDescription: featureDescription ?? localizations?.featureComingSoonDefaultFeatureDescription ?? 'Intelligent cross-referencing for your sources.',
          icon: icon ?? Icons.menu_book_rounded,
          previewIcon: previewIcon ?? Icons.history_edu_rounded,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopBar(context),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusChip(),
                  const SizedBox(height: 24),
                  _buildVisualIcon(),
                  const SizedBox(height: 32),
                  _buildTextContent(),
                  const SizedBox(height: 24),
                  _buildPreviewCard(),
                  const SizedBox(height: 32),
                  _buildActionButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: AppColors.primary),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
            ),
          ),
          Expanded(
            child: Text(
              localizations?.featureComingSoonHeader ?? 'Upcoming Feature',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    return Builder(
      builder: (context) {
        final localizations = AppLocalizations.of(context);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            localizations?.featureComingSoonBadge ?? 'COMING SOON',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
        );
      },
    );
  }

  Widget _buildVisualIcon() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
          ),
          Icon(
            icon,
            size: 60,
            color: AppColors.primary,
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            description,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              previewIcon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  featureName,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  featureDescription,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return ElevatedButton(
      onPressed: () => Navigator.pop(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        elevation: 0,
      ),
      child: Text(
        localizations?.featureComingSoonDismiss ?? 'Got it!',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
