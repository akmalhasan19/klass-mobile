import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../controllers/freelancer_hiring_flow_controller.dart';

class TaskPostingScreen extends StatefulWidget {
  final FreelancerHiringFlowController controller;

  const TaskPostingScreen({super.key, required this.controller});

  @override
  State<TaskPostingScreen> createState() => _TaskPostingScreenState();
}

class _TaskPostingScreenState extends State<TaskPostingScreen> {

  Future<void> _submitPosting() async {
    final success = await widget.controller.submitHiring();

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task berhasil diposting publik terbuka agar dibid freelancer.')),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.errorMessage ?? 'Gagal memposting task')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Review Posting Publik'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Konfirmasi Publikasi Task Baru',
                style: TextStyle(
                  fontFamily: 'Mona_Sans',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cek kembali instruksi Anda. Semua freelancer di marketplace Klass akan bisa melihat dan mengirim proposal untuk bekerja pada proyek ini.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('INSTRUKSI REVISI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Text(widget.controller.refinementDescription, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text('BIAYA EKSPEKTASI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    const Text('Sistem akan menyarankan bid sekitar Rp50.000. Freelancer dapat menawar.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.controller.isLoading ? null : _submitPosting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: widget.controller.isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Post Task ke Publik', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      );
  }
}
