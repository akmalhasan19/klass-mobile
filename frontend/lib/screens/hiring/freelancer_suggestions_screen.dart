import 'package:flutter/material.dart';

import '../../config/app_colors.dart';
import '../../controllers/freelancer_hiring_flow_controller.dart';
import '../../services/media_generation_service.dart';

class FreelancerSuggestionsScreen extends StatefulWidget {
  final FreelancerHiringFlowController controller;

  const FreelancerSuggestionsScreen({super.key, required this.controller});

  @override
  State<FreelancerSuggestionsScreen> createState() => _FreelancerSuggestionsScreenState();
}

class _FreelancerSuggestionsScreenState extends State<FreelancerSuggestionsScreen> {
  List<FreelancerSuggestion>? _suggestions;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    final results = await widget.controller.apiService.suggestFreelancers(widget.controller.generationId);
    if (mounted) {
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    }
  }

  void _confirmSelection(FreelancerSuggestion freelancer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pilihan', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        content: Text('Anda yakin ingin menugaskan perbaikan ini kepada ${freelancer.name}? Instruksi yang telah Anda buat akan dikirim langsung padanya.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _submitHire(freelancer.id);
            },
            child: const Text('Ya, Tugaskan'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitHire(int freelancerId) async {
    widget.controller.selectFreelancer(freelancerId);
    final success = await widget.controller.submitHiring();

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task berhasil terbuat! Freelancer akan segera mengerjakannya.')),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.controller.errorMessage ?? 'Gagal membuat task')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rekomendasi Terbaik'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _suggestions == null || _suggestions!.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text('Tidak Ada Freelancer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text('Sayangnya AI kami belum menemukan freelancer yang tepat saat ini. Silakan coba posting manual task.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _suggestions!.length,
      itemBuilder: (context, index) {
        final suggestion = _suggestions![index];
        final matchPercentage = (suggestion.matchScore * 100).toInt();
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Text(suggestion.name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(suggestion.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.orange, size: 16),
                              const SizedBox(width: 4),
                              Text('${suggestion.rating} (${(suggestion.successRate * 100).toInt()}% sukses)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          )
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                      child: Text('$matchPercentage% Cocok', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.controller.isLoading ? null : () => _confirmSelection(suggestion),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: widget.controller.isLoading && widget.controller.selectedFreelancerId == suggestion.id
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Pilih & Tugaskan'),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
