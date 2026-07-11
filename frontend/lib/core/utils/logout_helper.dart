import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:klass_app/app/app.dart';
import 'package:klass_app/features/auth/providers/auth_providers.dart';

class LogoutHelper {
  static Future<void> execute({
    required BuildContext context,
    required WidgetRef ref,
    bool popToRoot = false,
    VoidCallback? onBeforeLogout,
  }) async {
    onBeforeLogout?.call();

    final authNotifier = ref.read(authProvider.notifier);
    await authNotifier.logout();

    if (!context.mounted) return;

    if (popToRoot) {
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
    }

    if (context.mounted) {
      await KlassApp.mainShellKey.currentState?.reloadRole();
    }
  }
}
