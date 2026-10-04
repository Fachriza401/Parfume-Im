import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';

/// Persists the session across app restarts using `shared_preferences`.
class SessionStore {
  SessionStore(this._preferences);

  final SharedPreferences _preferences;

  static const String _tokenKey = 'parfumim.token';
  static const String _userKey = 'parfumim.user';

  static Future<SessionStore> create() async =>
      SessionStore(await SharedPreferences.getInstance());

  String? readToken() => _preferences.getString(_tokenKey);

  AppUser? readUser() {
    final raw = _preferences.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(AuthSession session) async {
    await _preferences.setString(_tokenKey, session.token);
    await _preferences.setString(_userKey, jsonEncode(session.user.toJson()));
  }

  Future<void> saveUser(AppUser user) =>
      _preferences.setString(_userKey, jsonEncode(user.toJson()));

  Future<void> clear() async {
    await _preferences.remove(_tokenKey);
    await _preferences.remove(_userKey);
  }
}
