import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../controllers/freelancer_hiring_flow_controller.dart';
import 'freelancer_suggestions_screen.dart';
import 'task_posting_screen.dart';

class HiringModeScreen extends StatelessWidget {
  final FreelancerHiringFlowController controller;

  const HiringModeScreen({super.key, required this.controller});

  void _selectModeAndProceed(BuildContext context, HiringMode mode) {
    controller.selectMode(mode);

    if (mode == HiringMode.autoSuggest) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FreelancerSuggestionsScreen(controller: controller),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaskPostingScreen(controller: controller),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pilih Metode'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bagaimana Anda ingin menemukan freelancer?',
              style: TextStyle(
                fontFamily: 'Mona_Sans',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 32),
            _ModeCard(
              title: 'Pencarian Otomatis',
              description: 'AI kami akan mencarikan 5 freelancer terbaik yang sedang aktif dan berpengalaman membuat tipe materi ini. Lebih cepat dan instan.',
              icon: Icons.auto_awesome_rounded,
              color: AppColors.primary,
              onTap: () => _selectModeAndProceed(context, HiringMode.autoSuggest),
            ),
            const SizedBox(height: 16),
            _ModeCard(
              title: 'Posting Secara Publik',
              description: 'Buka lowongan untuk task ini secara publik. Biarkan seluruh freelancer melihat dan mengajukan penawaran. Anda merespon penawar yang masuk nanti.',
              icon: Icons.public_rounded,
              color: const Color(0xFFD97706),
              onTap: () => _selectModeAndProceed(context, HiringMode.manualTask),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}
