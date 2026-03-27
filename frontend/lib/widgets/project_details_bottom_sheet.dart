import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'project_confirmation_bottom_sheet.dart';

class ProjectDetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> project;
  final Function(String)? onRecreate;

  const ProjectDetailsBottomSheet({
    super.key,
    required this.project,
    this.onRecreate,
  });

  @override
  Widget build(BuildContext context) {
    // Determine image source
    final String imageSource = project['imagePath'] ?? project['image'] ?? '';
    final bool isNetworkImage = imageSource.startsWith('http');

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // shrink-wrap to content
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Content area (scrollable if needed)
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Image
                  if (imageSource.isNotEmpty)
                    Container(
                      width: double.infinity,
                      height: 200, // Fixed height for hero image
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppColors.surfaceLight,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: isNetworkImage
                          ? Image.network(
                              imageSource,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _placeholderIcon(),
                            )
                          : Image.asset(
                              imageSource,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _placeholderIcon(),
                            ),
                    ),
                  
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    project['title'] ?? 'Review Project',
                    style: const TextStyle(
                      fontFamily: 'Mona_Sans',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Overview Section
                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Text(
                    project['description'] ?? 'No description provided.',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tags
                  if (project['tags'] != null && (project['tags'] as List).isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (project['tags'] as List<String>).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ] else ...[
                    const SizedBox(height: 8),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      // Recreate Button (Secondary)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            if (onRecreate != null) {
                              onRecreate!(project['description'] ?? '');
                            }
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppColors.border, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Recreate',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Use as it is Button (Primary)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Open confirmation modal without closing current one
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) {
                                return ProjectConfirmationBottomSheet(
                                  project: project,
                                );
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Use as it is',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderIcon() {
    return Center(
      child: Icon(
        Icons.auto_awesome,
        size: 48,
        color: AppColors.primary.withValues(alpha: 0.4),
      ),
    );
  }
}
