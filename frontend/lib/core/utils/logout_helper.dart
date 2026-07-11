import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:klass_app/app/app.dart';
import 'package:klass_app/features/auth/data/auth_service.dart';

class LogoutHelper {
  static Future<void> execute({
    required BuildContext context,
    required Dio dio,
    bool popToRoot = false,
    VoidCallback? onBeforeLogout,
  }) async {
    onBeforeLogout?.call();

    await AuthService(dio: dio).logout();

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
