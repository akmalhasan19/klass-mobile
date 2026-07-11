import 'package:klass_app/core/storage/secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<String?> read(String key) async {
    if (_store.containsKey(key)) {
      return _store[key];
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
