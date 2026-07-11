import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:klass_app/features/auth/data/auth_repository.dart';
import 'package:klass_app/features/auth/providers/auth_providers.dart';
import 'package:klass_app/features/auth/providers/auth_state.dart';

class AuthNotifier extends AsyncNotifier<AuthState> {
  late final AuthRepository _repository;

  @override
  Future<AuthState> build() async {
    _repository = ref.read(authRepositoryProvider);
    return _buildInitialState();
  }

  Future<AuthState> _buildInitialState() async {
    final isLoggedIn = await _repository.isLoggedIn();
    if (!isLoggedIn) {
      return const AuthState(isGuest: true);
    }

    final user = await _repository.getCachedUser();
    final role = AuthRepository.resolveAppRole(user?['role']);
    return AuthState(
      user: user,
      role: role,
      isGuest: false,
    );
  }

  Future<void> login(String email, String password, {CancelToken? cancelToken}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await _repository.login(email, password, cancelToken: cancelToken);
      if (user == null) {
        throw Exception('Login failed');
      }
      final role = AuthRepository.resolveAppRole(user['role']);
      return AuthState(user: user, role: role, isGuest: false);
    });
  }

  Future<void> register(
    String name,
    String email,
    String password, {
    String role = 'teacher',
    CancelToken? cancelToken,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await _repository.register(
        name,
        email,
        password,
        role: role,
        cancelToken: cancelToken,
      );
      if (user == null) {
        throw Exception('Registration failed');
      }
      final resolvedRole = AuthRepository.resolveAppRole(user['role']);
      return AuthState(user: user, role: resolvedRole, isGuest: false);
    });
  }

  Future<void> logout({CancelToken? cancelToken}) async {
    await _repository.logout(cancelToken: cancelToken);
    state = const AsyncData(AuthState(isGuest: true));
  }

  Future<void> refreshUser({CancelToken? cancelToken}) async {
    final currentUser = state.value;
    if (currentUser == null || currentUser.isGuest) return;

    state = await AsyncValue.guard(() async {
      final user = await _repository.getMe(cancelToken: cancelToken);
      if (user == null) {
        return currentUser;
      }
      final role = AuthRepository.resolveAppRole(user['role']);
      return AuthState(user: user, role: role, isGuest: false);
    });
  }

  Future<String?> uploadAvatar(String filePath, {CancelToken? cancelToken}) async {
    final avatarUrl = await _repository.uploadAvatar(filePath, cancelToken: cancelToken);
    if (avatarUrl != null) {
      await refreshUser();
    }
    return avatarUrl;
  }

  Future<String?> getSecurityQuestion(String email, {CancelToken? cancelToken}) async {
    return await _repository.getSecurityQuestion(email, cancelToken: cancelToken);
  }

  Future<bool> verifyAndResetPassword(
    String email,
    String securityAnswer,
    String newPassword, {
    CancelToken? cancelToken,
  }) async {
    return await _repository.verifyAndResetPassword(
      email,
      securityAnswer,
      newPassword,
      cancelToken: cancelToken,
    );
  }
}
