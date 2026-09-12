import 'package:flutter/foundation.dart';

import '../models/app_type.dart';
import '../models/auth_user.dart';
import '../services/auth_service.dart';

enum LoginState { idle, loading, success, error }

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required this.appType, AuthService? service})
    : _service = service ?? AuthService();

  final AppType appType;
  final AuthService _service;

  LoginState state = LoginState.idle;
  AuthUser? user;
  String? errorMessage;

  bool _obscure = true;
  bool get obscure => _obscure;

  void toggleObscure() {
    _obscure = !_obscure;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    if (state == LoginState.loading) return;

    if (username.trim().isEmpty || password.isEmpty) {
      errorMessage = 'Please enter username and password.';
      state = LoginState.error;
      notifyListeners();
      return;
    }

    state = LoginState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      user = await _service.login(username.trim(), password, appType);
      state = LoginState.success;
    } on AuthException catch (error) {
      errorMessage = error.message;
      state = LoginState.error;
    } on Object catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      state = LoginState.error;
    }
    notifyListeners();
  }

  void resetError() {
    if (state == LoginState.error) {
      state = LoginState.idle;
      errorMessage = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }
}
