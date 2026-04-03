import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Card project dengan aspect ratio dinamis berdasarkan tipe project:
/// - PPT: 16:9 (lebar)
/// - Infographic: 9:16 (tinggi)
/// - Square/Quiz: 1:1
class ProjectSuggestionCard extends StatelessWidget {
  final String title;
  final String author;
  final String ratio; // 'ppt', 'infographic', 'square'
  final String? imageUrl;
  final String? imagePath;
  final String? sourceBadge;
  final VoidCallback? onTap;

  const ProjectSuggestionCard({
    super.key,
    required this.title,
    required this.author,
    required this.ratio,
    this.imageUrl,
    this.imagePath,
    this.sourceBadge,
    this.onTap,
  });

  double get _aspectRatio {
    switch (ratio) {
      case 'ppt':
        return 16 / 9;
      case 'infographic':
        return 9 / 16;
      case 'square':
        return 1 / 1;
      default:
        return 16 / 9;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: ratio == 'infographic' ? 120 : (ratio == 'square' ? 180 : 280),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview image dengan aspect ratio dinamis
            Flexible(
              child: AspectRatio(
                aspectRatio: _aspectRatio,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: AppColors.surfaceCard,
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imagePath != null)
                        Image.asset(
                          imagePath!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholderIcon(),
                        )
                      else if (imageUrl != null)
                        Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholderIcon(),
                        )
                      else
                        _placeholderIcon(),
                        
                      if (sourceBadge != null && sourceBadge!.isNotEmpty)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              sourceBadge!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Project info
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    author,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
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

  Widget _placeholderIcon() {
    return Center(
      child: Icon(
        Icons.auto_awesome,
        size: 36,
        color: AppColors.primary.withValues(alpha: 0.4),
      ),
    );
  }
}
