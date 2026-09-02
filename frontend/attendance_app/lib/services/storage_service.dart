import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static late FlutterSecureStorage _storage;

  static Future<void> init() async {
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
      webOptions: WebOptions(
        dbName: 'attendance_storage',
        publicKey: 'attendance_app_key',
      ),
    );
  }

  static Future<void> write({
    required String key,
    required String value,
  }) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('StorageService write error: $e');
    }
  }

  static Future<String?> read({required String key}) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('StorageService read error: $e');
      return null;
    }
  }

  static Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('StorageService delete error: $e');
    }
  }
}
