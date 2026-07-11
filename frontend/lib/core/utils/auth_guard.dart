import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:klass_app/features/auth/providers/auth_providers.dart';
import 'package:klass_app/features/auth/screens/login_screen.dart';

Future<bool> requireAuth(BuildContext context, WidgetRef ref) async {
  final authState = ref.read(authProvider);
  final isLoggedIn = authState.hasValue && !authState.value!.isGuest;
  
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
