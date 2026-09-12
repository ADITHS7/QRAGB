import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_constants.dart';
import '../models/app_type.dart';
import '../models/auth_user.dart';
import 'auth_storage.dart';

/// Authenticates a user against the supplied `/Auth/login` contract.
class AuthService {
  AuthService({AuthStorage? storage, http.Client? client})
    : _storage = storage ?? AuthStorage(),
      _client = client ?? http.Client();

  final AuthStorage _storage;
  final http.Client _client;

  Future<AuthUser> login(
    String username,
    String password,
    AppType appType,
  ) async {
    try {
      final request = http.Request('POST', AppConstants.loginUri)
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..headers['Accept'] = 'application/json'
        ..bodyBytes = utf8.encode(
          jsonEncode(<String, String>{
            'username': username,
            'password': password,
          }),
        );

      final streamed = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamed);

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException catch (error) {
        throw AuthException(
          'The login server returned invalid JSON.',
          cause: error,
        );
      }

      if (decoded is! Map) {
        throw const AuthException(
          'The login server returned an unexpected response.',
        );
      }

      final body = Map<String, dynamic>.from(decoded);
      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'];
        final token = body['token'];
        if (data is! Map || token is! String || token.isEmpty) {
          throw const AuthException(
            'The login response is missing session data.',
          );
        }

        final user = AuthUser.fromJson(
          Map<String, dynamic>.from(data),
          token,
          appType,
        );
        await _storage.saveSelectedType(appType);
        await _storage.saveSession(user);
        return user;
      }

      final message = body['message'];
      throw AuthException(
        message is String && message.trim().isNotEmpty
            ? message.trim()
            : 'Login failed.',
        statusCode: response.statusCode,
      );
    } on AuthException {
      rethrow;
    } on TimeoutException catch (error) {
      throw AuthException('The login request timed out.', cause: error);
    } on Object catch (error) {
      throw AuthException(
        'Could not reach the login server. Check the device is on the same network.',
        cause: error,
      );
    }
  }

  void close() => _client.close();
}

class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}
