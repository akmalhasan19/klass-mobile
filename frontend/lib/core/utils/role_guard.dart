import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:klass_app/core/config/app_colors.dart';
import 'package:klass_app/features/auth/providers/auth_providers.dart';

Future<bool> requireRole(BuildContext context, WidgetRef ref, String requiredRole) async {
  final authState = ref.read(authProvider);
  if (!authState.hasValue) return false;

  final role = authState.value!.role;
  if (role == 'admin') return true;

  if (requiredRole == 'teacher' && (role == 'teacher' || role == 'user')) {
    return true;
  }
  if (requiredRole == 'freelancer' && role == 'freelancer') {
    return true;
  }

  if (context.mounted) {
    _showAccessRestrictedDialog(context, requiredRole);
  }
  return false;
}

void _showAccessRestrictedDialog(BuildContext context, String requiredRole) {
  final roleLabel = requiredRole == 'teacher' ? 'Teacher' : 'Freelancer';
  final roleIcon = requiredRole == 'teacher' 
      ? Icons.school_rounded 
      : Icons.work_rounded;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              roleIcon,
              size: 32,
              color: AppColors.red,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Akses Terbatas',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fitur ini hanya tersedia untuk akun $roleLabel. '
            'Silakan login dengan akun $roleLabel untuk mengakses fitur ini.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Mengerti',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
