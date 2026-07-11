import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:klass_app/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final initialAppState = await loadInitialAppState();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    ProviderScope(
      child: KlassApp(
        initialRole: initialAppState.role,
        initialIsGuest: initialAppState.isGuest,
        initialLocale: initialAppState.locale,
      ),
    ),
  );
}
