import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../controllers/freelancer_hiring_flow_controller.dart';
import 'hiring_mode_screen.dart';

class RefinementInputScreen extends StatefulWidget {
  final FreelancerHiringFlowController controller;

  const RefinementInputScreen({super.key, required this.controller});

  @override
  State<RefinementInputScreen> createState() => _RefinementInputScreenState();
}

class _RefinementInputScreenState extends State<RefinementInputScreen> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.controller.refinementDescription);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onNext() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap tuliskan deskripsi perbaikan terlebih dahulu.')),
      );
      return;
    }

    widget.controller.setRefinementDescription(text);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HiringModeScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Perbaikan'),
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
              'Apa yang perlu diperbaiki?',
              style: TextStyle(
                fontFamily: 'Mona_Sans',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Jelaskan secara detail bagian mana dari materi yang ingin Anda ubah atau tingkatkan. Freelancer akan menggunakan instruksi ini sebagai panduan utama mereka.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _textController,
              maxLines: 8,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: 'Contoh: Buatkan ilustrasi yang lebih menarik di slide 3 dan 4, serta sesuaikan tabel di akhir agar lebih mudah dibaca...',
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton(
            onPressed: _onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: const Text(
              'Lanjutkan',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
