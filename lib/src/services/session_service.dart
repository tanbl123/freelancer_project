import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static final SessionService instance = SessionService._();
  SessionService._();

  static const _keyUid = 'logged_in_uid';

  Future<void> saveUserId(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUid, uid);
  }

  Future<String?> getSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUid);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUid);
  }
}
