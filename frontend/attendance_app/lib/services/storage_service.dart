import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> write({required String key, required String value}) async {
    await _prefs.setString(key, value);
  }

  static Future<String?> read({required String key}) async {
    return _prefs.getString(key);
  }

  static Future<void> delete({required String key}) async {
    await _prefs.remove(key);
  }
}
