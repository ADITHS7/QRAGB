import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_type.dart';
import '../models/auth_user.dart';

/// Persistence for the selected mode and the authenticated session.
///
/// Passwords are never stored. The existing app uses a LAN HTTP API, so this
/// keeps the storage boundary small and replaceable if secure token storage is
/// required later.
class AuthStorage {
  static const _selectedTypeKey = 'selected_app_type';
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _usernameKey = 'auth_username';
  static const _fullNameKey = 'auth_full_name';
  static const _roleKey = 'auth_role';
  static const _sessionTypeKey = 'auth_session_app_type';

  Future<void> saveSelectedType(AppType type) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_selectedTypeKey, type.storageValue);
  }

  Future<AppType?> readSelectedType() async {
    final preferences = await SharedPreferences.getInstance();
    return AppType.fromStorage(preferences.getString(_selectedTypeKey));
  }

  Future<void> saveSession(AuthUser user) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_tokenKey, user.token),
      preferences.setInt(_userIdKey, user.userId),
      preferences.setString(_usernameKey, user.username),
      preferences.setString(_fullNameKey, user.fullName),
      preferences.setInt(_roleKey, user.role),
      preferences.setString(_sessionTypeKey, user.appType.storageValue),
    ]);
  }

  Future<AuthUser?> readSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    final userId = preferences.getInt(_userIdKey);
    final username = preferences.getString(_usernameKey);
    final fullName = preferences.getString(_fullNameKey);
    final role = preferences.getInt(_roleKey);
    final appType = AppType.fromStorage(preferences.getString(_sessionTypeKey));

    if (token == null ||
        userId == null ||
        username == null ||
        fullName == null ||
        role == null ||
        appType == null) {
      return null;
    }

    return AuthUser(
      userId: userId,
      username: username,
      fullName: fullName,
      role: role,
      token: token,
      appType: appType,
    );
  }

  Future<void> clearSession() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_tokenKey),
      preferences.remove(_userIdKey),
      preferences.remove(_usernameKey),
      preferences.remove(_fullNameKey),
      preferences.remove(_roleKey),
      preferences.remove(_sessionTypeKey),
    ]);
  }

  Future<void> clearAll() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_selectedTypeKey);
    await clearSession();
  }
}
