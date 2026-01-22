import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceUserId {
  static const _key = 'device_user_id';

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    final existing = prefs.getString(_key);
    if (existing != null) {
      return existing;
    }

    final uuid = const Uuid().v4();
    await prefs.setString(_key, uuid);

    return uuid;
  }
}
