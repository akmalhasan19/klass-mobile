import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klass_app/core/storage/secure_token_store.dart';
import 'package:klass_app/features/auth/data/auth_api.dart';

class AuthRepository {
  final AuthApi _api;
  final SecureTokenStore _tokenStore;

  AuthRepository({
    required AuthApi api,
    required SecureTokenStore tokenStore,
  })  : _api = api,
        _tokenStore = tokenStore;

  static String? normalizeRoleValue(dynamic role) {
    if (role == null) return null;

    final normalizedRole = role.toString().trim().toLowerCase();
    if (normalizedRole.isEmpty) return null;

    return normalizedRole;
  }

  static String resolveAppRole(dynamic role) {
    return normalizeRoleValue(role) == 'freelancer' ? 'freelancer' : 'teacher';
  }

  static String? getRoleFromUserData(Map<String, dynamic>? user) {
    return normalizeRoleValue(user?['role']);
  }

  Future<Map<String, dynamic>?> login(
    String email,
    String password, {
    CancelToken? cancelToken,
  }) async {
    final data = await _api.login(email, password, cancelToken: cancelToken);
    final token = data['token'] ?? data['access_token'];
    if (token != null) {
      await _tokenStore.write(token);
      if (data['user'] != null) {
        await _tokenStore.writeUserData(data['user'] as Map<String, dynamic>);
      }
      return data['user'] as Map<String, dynamic>?;
    }
    return null;
  }

  Future<Map<String, dynamic>?> register(
    String name,
    String email,
    String password, {
    String role = 'teacher',
    CancelToken? cancelToken,
  }) async {
    final data = await _api.register(
      name,
      email,
      password,
      role: role,
      cancelToken: cancelToken,
    );
    final token = data['token'] ?? data['access_token'];
    if (token != null) {
      await _tokenStore.write(token);
      if (data['user'] != null) {
        await _tokenStore.writeUserData(data['user'] as Map<String, dynamic>);
      }
      return data['user'] as Map<String, dynamic>?;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getMe({CancelToken? cancelToken}) async {
    final user = await _api.getMe(cancelToken: cancelToken);
    await _tokenStore.writeUserData(user);
    return user;
  }

  Future<void> logout({CancelToken? cancelToken}) async {
    try {
      await _api.logout(cancelToken: cancelToken);
    } catch (_) {
      // Ignore error if logout fails (e.g., token already invalid)
    } finally {
      await _tokenStore.clearAll();

      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();
      for (final key in allKeys) {
        if (key.startsWith('api_cache_')) {
          await prefs.remove(key);
        }
      }
    }
  }

  Future<String?> getSecurityQuestion(String email, {CancelToken? cancelToken}) async {
    return await _api.getSecurityQuestion(email, cancelToken: cancelToken);
  }

  Future<bool> verifyAndResetPassword(
    String email,
    String securityAnswer,
    String newPassword, {
    CancelToken? cancelToken,
  }) async {
    return await _api.verifyAndResetPassword(
      email,
      securityAnswer,
      newPassword,
      cancelToken: cancelToken,
    );
  }

  Future<String?> uploadAvatar(String filePath, {CancelToken? cancelToken}) async {
    final avatarUrl = await _api.uploadAvatar(filePath, cancelToken: cancelToken);
    if (avatarUrl != null) {
      final me = await getMe();
      if (me != null) {
        me['avatar_url'] = avatarUrl;
        await _tokenStore.writeUserData(me);
      }
    }
    return avatarUrl;
  }

  Future<bool> isLoggedIn() async {
    return await _tokenStore.read() != null;
  }

  Future<String?> getUserRole() async {
    final user = await _tokenStore.readUserData();
    if (user != null) {
      return normalizeRoleValue(user['role']);
    }
    return null;
  }

  Future<bool> isTeacher() async {
    final role = await getUserRole();
    return role == 'teacher' || role == 'user' || role == 'admin';
  }

  Future<bool> isFreelancer() async {
    final role = await getUserRole();
    return role == 'freelancer';
  }

  Future<Map<String, dynamic>?> getCachedUser() async {
    return await _tokenStore.readUserData();
  }
}
