import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/users/domain/staff_user.dart';

class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  static const _tokenKey = 'access_token';
  static const _userKey = 'session_user';

  String? _token;

  String? get token => _token;

  Future<void> save(String token, StaffUser user) async {
    final preferences = await SharedPreferences.getInstance();
    _token = token;
    await preferences.setString(_tokenKey, token);
    await preferences.setString(
      _userKey,
      jsonEncode({
        'id': user.id,
        'username': user.displayName,
        'email': user.email,
        'role': user.role.apiValue,
        'serviceId': user.serviceId,
        'active': user.isActive,
      }),
    );
  }

  Future<({String token, StaffUser user})?> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    final encodedUser = preferences.getString(_userKey);
    if (token == null || encodedUser == null) return null;

    try {
      final decoded = jsonDecode(encodedUser);
      if (decoded is! Map<String, dynamic>) {
        await clear();
        return null;
      }
      final user = StaffUser.fromJson(decoded);
      _token = token;
      return (token: token, user: user);
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    _token = null;
    await preferences.remove(_tokenKey);
    await preferences.remove(_userKey);
  }
}
