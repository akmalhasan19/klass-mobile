import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../services/auth_service.dart';

/// Checks if the current user has the required role.
/// Shows an "Access Restricted" dialog if the user doesn't have the required role.
///
/// Returns true if the user has the required role, false otherwise.
Future<bool> requireRole(BuildContext context, String requiredRole) async {
  final authService = AuthService();
  final role = await authService.getUserRole();

  if (role == null) return false;
  if (role == 'admin') return true; // Admin can access everything

  if (requiredRole == 'teacher' && (role == 'teacher' || role == 'user')) {
    return true;
  }
  if (requiredRole == 'freelancer' && role == 'freelancer') {
    return true;
  }

  // Show access restricted dialog
  if (context.mounted) {
    _showAccessRestrictedDialog(context, requiredRole);
  }
  return false;
}

/// Shows a dialog informing the user that the feature is restricted to a specific role.
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
