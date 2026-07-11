import 'package:dio/dio.dart';
import 'package:klass_app/core/config/api_config.dart';

class AuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  Future<Map<String, dynamic>> login(String email, String password, {CancelToken? cancelToken}) async {
    final response = await _dio.post(
      ApiConfig.v('/auth/login'),
      data: {
        'email': email,
        'password': password,
      },
      cancelToken: cancelToken,
    );

    final payload = response.data as Map<String, dynamic>;
    return (payload['data'] as Map?)?.cast<String, dynamic>() ?? payload;
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password, {
    String role = 'teacher',
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post(
      ApiConfig.v('/auth/register'),
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
        'role': role,
      },
      cancelToken: cancelToken,
    );

    final payload = response.data as Map<String, dynamic>;
    return (payload['data'] as Map?)?.cast<String, dynamic>() ?? payload;
  }

  Future<Map<String, dynamic>> getMe({CancelToken? cancelToken}) async {
    final response = await _dio.get(
      ApiConfig.v('/auth/me'),
      cancelToken: cancelToken,
    );

    return response.data['data'] ?? response.data;
  }

  Future<void> logout({CancelToken? cancelToken}) async {
    await _dio.post(
      ApiConfig.v('/auth/logout'),
      cancelToken: cancelToken,
    );
  }

  Future<String?> getSecurityQuestion(String email, {CancelToken? cancelToken}) async {
    final response = await _dio.post(
      ApiConfig.v('/auth/get-security-question'),
      data: {'email': email},
      cancelToken: cancelToken,
    );

    final payload = response.data as Map<String, dynamic>;
    final data = payload['data'] ?? payload;
    return data['security_question'];
  }

  Future<bool> verifyAndResetPassword(
    String email,
    String securityAnswer,
    String newPassword, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post(
      ApiConfig.v('/auth/verify-and-reset-password'),
      data: {
        'email': email,
        'security_answer': securityAnswer,
        'new_password': newPassword,
      },
      cancelToken: cancelToken,
    );

    return response.statusCode == 200;
  }

  Future<String?> uploadAvatar(String filePath, {CancelToken? cancelToken}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    final response = await _dio.post(
      ApiConfig.v('/user/avatar'),
      data: formData,
      cancelToken: cancelToken,
    );

    final payload = response.data as Map<String, dynamic>;
    final data = (payload['data'] as Map?)?.cast<String, dynamic>() ?? payload;
    return data['avatar_url'];
  }
}
