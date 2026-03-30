import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiService.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final payload = response.data as Map<String, dynamic>;
        final data = (payload['data'] as Map?)?.cast<String, dynamic>() ?? payload;
        final token = data['token'] ?? data['access_token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          // Optional: Save user data
          if (data['user'] != null) {
            await prefs.setString('user_data', jsonEncode(data['user']));
          }
          return true;
        }
      }
      return false;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Login failed');
    }
  }

  Future<bool> register(String name, String email, String password) async {
    try {
      final response = await _apiService.dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final payload = response.data as Map<String, dynamic>;
        final data = (payload['data'] as Map?)?.cast<String, dynamic>() ?? payload;
        final token = data['token'] ?? data['access_token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          if (data['user'] != null) {
            await prefs.setString('user_data', jsonEncode(data['user']));
          }
          return true;
        }
      }
      return false;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Registration failed');
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.dio.post('/auth/logout');
    } catch (_) {
      // Ignore error if logout fails (e.g., token already invalid)
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
    }
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final response = await _apiService.dio.get('/auth/me');
      if (response.statusCode == 200) {
        final user = response.data['data'] ?? response.data; // adjust based on API structure
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(user));
        return user;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') != null;
  }

  Future<String?> uploadAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        // Backend expects file field name "file"
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await _apiService.dio.post(
        '/user/avatar',
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
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_data', jsonEncode(me));
          }
          return data['avatar_url'];
        }
      }
      return null;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to upload avatar');
    }
  }
}
