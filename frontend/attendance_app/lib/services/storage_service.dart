import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
class StorageService {
  static final Map<String, String> _memoryStorage = {};

  static Future<void> write({required String key, required String value}) async {
    _memoryStorage[key] = value;
  }

  static Future<String?> read({required String key}) async {
    return _memoryStorage[key];
  }

  static Future<void> delete({required String key}) async {
    _memoryStorage.remove(key);
  }
}
