import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:klass_app/core/providers/dio_provider.dart';
import 'package:klass_app/core/providers/secure_token_store_provider.dart';
import 'package:klass_app/features/auth/data/auth_api.dart';
import 'package:klass_app/features/auth/data/auth_repository.dart';
import 'package:klass_app/features/auth/providers/auth_notifier.dart';
import 'package:klass_app/features/auth/providers/auth_state.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(authApiProvider),
    tokenStore: ref.watch(secureTokenStoreProvider),
  );
});

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
