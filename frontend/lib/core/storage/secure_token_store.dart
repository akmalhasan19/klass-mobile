import 'dart:convert';
import 'package:klass_app/core/storage/secure_storage.dart';

class SecureTokenStore {
  final SecureStorage _storage;

  SecureTokenStore({SecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorageImpl();

  static const String authTokenKey = 'auth_token';
  static const String userDataKey = 'user_data';

  Future<void> write(String token) => _storage.write(authTokenKey, token);

  Future<String?> read() => _storage.read(authTokenKey);

  Future<void> delete() => _storage.delete(authTokenKey);

  Future<void> writeUserData(Map<String, dynamic> userData) =>
      _storage.write(userDataKey, jsonEncode(userData));

  Future<Map<String, dynamic>?> readUserData() async {
    final raw = await _storage.read(userDataKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> deleteUserData() => _storage.delete(userDataKey);

  Future<void> clearAll() async {
    await delete();
    await deleteUserData();
  }
}
