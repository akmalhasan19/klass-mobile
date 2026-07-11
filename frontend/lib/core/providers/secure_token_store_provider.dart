import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:klass_app/core/storage/secure_token_store.dart';

final secureTokenStoreProvider = Provider<SecureTokenStore>((ref) {
  return SecureTokenStore();
});
