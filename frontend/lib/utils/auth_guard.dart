import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';

/// Intercepts restricted feature actions. 
/// If the user is unauthenticated, navigates them to the LoginScreen and returns false.
/// If authenticated, returns true.
Future<bool> requireAuth(BuildContext context) async {
  final authService = AuthService();
  final isLoggedIn = await authService.isLoggedIn();
  
  if (!isLoggedIn && context.mounted) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
    return false;
  }
  
  return true;
}
