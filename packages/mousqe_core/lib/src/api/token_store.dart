import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// مخزن آمن للتوكن و`device_uuid` — [SYNC-PROTOCOL.md §8](../../../../docs/SYNC-PROTOCOL.md)
/// البند 10: التوكن في مخزن آمن، و`device_uuid` ثابت مدى عمر التثبيت.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'mousqe.token';
  static const _deviceUuidKey = 'mousqe.device_uuid';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  /// يُقرأ إن وُجد، وإلا يُنشأ ويُكتب فوراً — نفسه طوال عمر التثبيت.
  Future<String> deviceUuid() async {
    final existing = await _storage.read(key: _deviceUuidKey);
    if (existing != null) {
      return existing;
    }

    final generated = const Uuid().v4();
    await _storage.write(key: _deviceUuidKey, value: generated);
    return generated;
  }
}
