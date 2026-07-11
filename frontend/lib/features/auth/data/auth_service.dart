import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:klass_app/core/config/api_config.dart';
import 'package:klass_app/core/network/api_service.dart';
import 'package:klass_app/core/storage/secure_token_store.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final SecureTokenStore _tokenStore;

  AuthService({SecureTokenStore? tokenStore})
    : _tokenStore = tokenStore ?? SecureTokenStore();

  static String? normalizeRoleValue(dynamic role) {
    if (role == null) {
      return null;
    }

    final normalizedRole = role.toString().trim().toLowerCase();
    if (normalizedRole.isEmpty) {
      return null;
    }

    return normalizedRole;
  }

  static String resolveAppRole(dynamic role) {
    return normalizeRoleValue(role) == 'freelancer' ? 'freelancer' : 'teacher';
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiService.dio.post(ApiConfig.v('/auth/login'), data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final payload = response.data as Map<String, dynamic>;
        final data = (payload['data'] as Map?)?.cast<String, dynamic>() ?? payload;
        final token = data['token'] ?? data['access_token'];
        if (token != null) {
          await _tokenStore.write(token);
          if (data['user'] != null) {
            await _tokenStore.writeUserData(data['user'] as Map<String, dynamic>);
          }
          return true;
        }
      }
      return false;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? data['message'] : null;
      throw Exception(msg ?? 'Login failed');
    }
  }

  Future<bool> register(String name, String email, String password, {String role = 'teacher'}) async {
    try {
      final response = await _apiService.dio.post(ApiConfig.v('/auth/register'), data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
        'role': role,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final payload = response.data as Map<String, dynamic>;
        final data = (payload['data'] as Map?)?.cast<String, dynamic>() ?? payload;
        final token = data['token'] ?? data['access_token'];
        if (token != null) {
          await _tokenStore.write(token);
          if (data['user'] != null) {
            await _tokenStore.writeUserData(data['user'] as Map<String, dynamic>);
          }
          return true;
        }
      }
      return false;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? data['message'] : null;
      throw Exception(msg ?? 'Registration failed');
    }
  }

  Future<String?> getSecurityQuestion(String email) async {
    try {
      final response = await _apiService.dio.post(ApiConfig.v('/auth/get-security-question'), data: {
        'email': email,
      });
      if (response.statusCode == 200) {
        final payload = response.data as Map<String, dynamic>;
        final data = payload['data'] ?? payload;
        return data['security_question'];
      }
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? data['message'] : null;
      throw Exception(msg ?? 'Failed to get security question');
    }
  }

  Future<bool> verifyAndResetPassword(String email, String securityAnswer, String newPassword) async {
    try {
      final response = await _apiService.dio.post(ApiConfig.v('/auth/verify-and-reset-password'), data: {
        'email': email,
        'security_answer': securityAnswer,
        'new_password': newPassword,
      });
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? data['message'] : null;
      throw Exception(msg ?? 'Failed to reset password');
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.dio.post(ApiConfig.v('/auth/logout'));
    } catch (_) {
      // Ignore error if logout fails (e.g., token already invalid)
    } finally {
      await _tokenStore.clearAll();

      // Clear auth-scoped API cache so stale user data doesn't survive logout.
      // App preferences such as locale are intentionally preserved.
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();
      for (final key in allKeys) {
        if (key.startsWith('api_cache_')) {
          await prefs.remove(key);
        }
      }
    }
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final response = await _apiService.dio.get(ApiConfig.v('/auth/me'));
      if (response.statusCode == 200) {
        final user = response.data['data'] ?? response.data;
        await _tokenStore.writeUserData(user as Map<String, dynamic>);
        return user;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    return await _tokenStore.read() != null;
  }

  // ─── Role Helpers ────────────────────────────────────────────

  /// Returns the user's role from cached user data.
  /// Possible values: 'teacher', 'freelancer', 'admin', 'user' (legacy).
  Future<String?> getUserRole() async {
    final user = await _tokenStore.readUserData();
    if (user != null) {
      return normalizeRoleValue(user['role']);
    }
    return null;
  }

  /// Returns the user's role synchronously from a cached user map.
  static String? getRoleFromUserData(Map<String, dynamic>? user) {
    return normalizeRoleValue(user?['role']);
  }

  /// Checks if user is a teacher (or legacy 'user' role).
  Future<bool> isTeacher() async {
    final role = await getUserRole();
    return role == 'teacher' || role == 'user' || role == 'admin';
  }

  /// Checks if user is a freelancer.
  Future<bool> isFreelancer() async {
    final role = await getUserRole();
    return role == 'freelancer';
  }

  Future<String?> uploadAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        // Backend expects file field name "file"
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await _apiService.dio.post(
        ApiConfig.v('/user/avatar'),
        data: formData,
      );

      if (response.statusCode == 200) {
        final payload = response.data as Map<String, dynamic>;
        final data = (payload['data'] as Map?)?.cast<String, dynamic>() ?? payload;
        if (data['avatar_url'] != null) {
          // Update cached user data
          final me = await getMe();
          if (me != null) {
            me['avatar_url'] = data['avatar_url'];
            await _tokenStore.writeUserData(me);
          }
          return data['avatar_url'];
        }
      }
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? data['message'] : null;
      throw Exception(msg ?? 'Failed to upload avatar');
    }
  }
}

