import 'app_type.dart';

/// Authenticated user and the app mode selected before login.
class AuthUser {
  const AuthUser({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
    required this.token,
    required this.appType,
  });

  final int userId;
  final String username;
  final String fullName;
  final int role;
  final String token;
  final AppType appType;

  factory AuthUser.fromJson(
    Map<String, dynamic> json,
    String token,
    AppType appType,
  ) {
    final userId = json['userId'];
    final username = json['username'];
    final fullName = json['fullName'];
    final role = json['role'];

    if (userId is! num ||
        username is! String ||
        fullName is! String ||
        role is! num) {
      throw const FormatException('The login response has invalid user data.');
    }

    return AuthUser(
      userId: userId.toInt(),
      username: username,
      fullName: fullName,
      role: role.toInt(),
      token: token,
      appType: appType,
    );
  }
}
