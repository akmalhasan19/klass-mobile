import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/generation_history_service.dart';

class GenerationHistoryScreen extends StatefulWidget {
  const GenerationHistoryScreen({super.key, required this.generationId});

  final String generationId;

  @override
  State<GenerationHistoryScreen> createState() => _GenerationHistoryScreenState();
}

class _GenerationHistoryScreenState extends State<GenerationHistoryScreen> {
  final GenerationHistoryService _service = GenerationHistoryService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _fetchHistory();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchHistory() async {
    await _service.getHistoryForGeneration(widget.generationId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Riwayat Generasi',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_service.viewState) {
      case HistoryViewState.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Memuat riwayat generasi...',
                style: TextStyle(fontFamily: 'Inter', color: AppColors.textMuted),
              ),
            ],
          ),
        );
      case HistoryViewState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Gagal memuat riwayat',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _service.errorMessage ?? 'Terjadi kesalahan tidak dikenal.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Inter', color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _fetchHistory,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      case HistoryViewState.success:
        if (_service.generationHistory.isEmpty) {
          return const Center(
            child: Text(
              'Tidak ada riwayat generasi ditemukan.',
              style: TextStyle(fontFamily: 'Inter', color: AppColors.textMuted),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _service.generationHistory.length,
          itemBuilder: (context, index) {
            final reversedIndex = _service.generationHistory.length - 1 - index;
            final generation = _service.generationHistory[reversedIndex];
            return _buildHistoryItem(generation, index == 0);
          },
        );
      case HistoryViewState.idle:
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHistoryItem(Map<String, dynamic> generation, bool isLatest) {
    final createdAt = generation['created_at'] != null 
        ? DateTime.parse(generation['created_at']) 
        : DateTime.now();
    final status = generation['status'] ?? 'unknown';
    final prompt = generation['prompt'] ?? '-';
    final outputType = generation['preferred_output_type'] ?? 'auto';
    final isRegeneration = generation['is_regeneration'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLatest ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
          width: isLatest ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatRelativeTime(createdAt),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    outputType.toString().toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (isRegeneration) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  const Text(
                    'Regenerasi',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              prompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _onDetailsTap(generation['id']),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: const Text('Lihat Detail'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _onDetailsTap(String id) {
    // For now, we just show a snackbar. 
    // In a real app, this could navigate back or show a detailed dialog.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Menampilkan detail untuk: $id')),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'completed':
        color = AppColors.primary;
        icon = Icons.check_circle_rounded;
        label = 'Selesai';
        break;
      case 'failed':
        color = AppColors.red;
        icon = Icons.cancel_rounded;
        label = 'Gagal';
        break;
      case 'processing':
      case 'queued':
      case 'interpreting':
      case 'generating':
        color = Colors.orange;
        icon = Icons.schedule_rounded;
        label = 'Proses';
        break;
      default:
        color = AppColors.textMuted;
        icon = Icons.help_outline_rounded;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
