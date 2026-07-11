import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStorage {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class FlutterSecureStorageImpl implements SecureStorage {
  final FlutterSecureStorage _storage;

  FlutterSecureStorageImpl({
    FlutterSecureStorage? storage,
    AndroidOptions? androidOptions,
    IOSOptions? iosOptions,
  }) : _storage = storage ?? FlutterSecureStorage(
          aOptions: androidOptions ?? const AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: iosOptions ?? const IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        );

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
